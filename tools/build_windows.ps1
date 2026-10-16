# Gera a versão do Pokesap para Windows em build/windows e o pacote dist/Pokesap-windows.zip.
#
#   powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1 [-Godot caminho\Godot.exe]
#
# Com os "export templates" do Godot instalados (Editor > Gerenciar Modelos de
# Exportação), gera um Pokesap.exe de release. Sem eles, gera o Pokesap.pck (o jogo)
# e usa o próprio executável do Godot renomeado como Pokesap.exe: o Godot abre
# sozinho o .pck de mesmo nome que estiver ao lado dele.
param(
	[string]$Godot = "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Test-Path $Godot)) { throw "Godot não encontrado em '$Godot'. Use -Godot caminho\do\Godot.exe" }
$console = $Godot -replace "\.exe$", "_console.exe"
if (-not (Test-Path $console)) { $console = $Godot }
$out = Join-Path $root "build\windows"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null

Write-Host "Importando recursos..."
& $console --headless --path $root --import | Out-Null

$version = ($Godot | Select-String -Pattern "v(\d+\.\d+(\.\d+)?)-(\w+)").Matches[0]
$templates = Join-Path $env:APPDATA ("Godot\export_templates\{0}.{1}" -f $version.Groups[1].Value, $version.Groups[3].Value)
if (Test-Path (Join-Path $templates "windows_release_x86_64.exe")) {
	Write-Host "Exportando executável de release (export templates encontrados)..."
	& $console --headless --path $root --export-release "Windows Desktop" (Join-Path $out "Pokesap.exe") | Out-Null
} else {
	Write-Host "Export templates não instalados: exportando Pokesap.pck + executável do Godot."
	& $console --headless --path $root --export-pack "Windows Desktop" (Join-Path $out "Pokesap.pck") | Out-Null
	Copy-Item $Godot (Join-Path $out "Pokesap.exe")
}
if (-not (Test-Path (Join-Path $out "Pokesap.exe"))) { throw "Pokesap.exe não foi gerado." }

# instalador simples: copia para a pasta do usuário e cria atalhos
@'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar.ps1"
pause
'@ | Set-Content (Join-Path $out "instalar.bat") -Encoding ascii
@'
$dest = Join-Path $env:LOCALAPPDATA "Programs\Pokesap"
New-Item -ItemType Directory -Force $dest | Out-Null
Get-ChildItem $PSScriptRoot -File | Where-Object { $_.Name -notlike "instalar*" } | Copy-Item -Destination $dest -Force
$shell = New-Object -ComObject WScript.Shell
foreach ($dir in @([Environment]::GetFolderPath("Desktop"), (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"))) {
	$lnk = $shell.CreateShortcut((Join-Path $dir "Pokesap.lnk"))
	$lnk.TargetPath = Join-Path $dest "Pokesap.exe"
	$lnk.WorkingDirectory = $dest
	$lnk.Save()
}
Write-Host "Pokesap instalado em $dest. Abra pelo atalho na Área de Trabalho ou no Menu Iniciar."
'@ | Set-Content (Join-Path $out "instalar.ps1") -Encoding utf8
@'
$dest = Join-Path $env:LOCALAPPDATA "Programs\Pokesap"
Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path ([Environment]::GetFolderPath("Desktop")) "Pokesap.lnk") -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Pokesap.lnk") -ErrorAction SilentlyContinue
Write-Host "Pokesap removido. Os saves continuam em %APPDATA%\Godot\app_userdata\Pokesap."
'@ | Set-Content (Join-Path $out "desinstalar.ps1") -Encoding utf8
@'
POKESAP - versao para Windows

Jogar sem instalar: abra Pokesap.exe (o Pokesap.pck precisa ficar na mesma pasta).
Instalar: de dois cliques em instalar.bat. Ele copia o jogo para
  %LOCALAPPDATA%\Programs\Pokesap
e cria atalhos na Area de Trabalho e no Menu Iniciar.
Desinstalar: botao direito em desinstalar.ps1 > Executar com o PowerShell.

Controles: WASD/setas andam (Shift corre), Z/Enter/Espaco confirmam, X/Esc voltam,
Enter/Esc/C abrem o menu. Nos dialogos tambem da para clicar na caixa de texto.
Configuracoes (tela inicial ou menu > OPCOES): janela, sem bordas, tela cheia,
resolucao, brilho, qualidade e distancia da camera.
Saves e configuracoes ficam em %APPDATA%\Godot\app_userdata\Pokesap.
'@ | Set-Content (Join-Path $out "LEIA-ME.txt") -Encoding ascii

Write-Host "Verificando a versão gerada..."
$p = Start-Process -FilePath (Join-Path $out "Pokesap.exe") -ArgumentList "--", "--verificar" -WorkingDirectory $out -PassThru
if (-not $p.WaitForExit(180000)) { $p.Kill(); throw "A verificação do executável não terminou (travou ou não abriu)." }
if ($p.ExitCode -ne 0) { throw "A verificação do executável falhou (código $($p.ExitCode))." }
Write-Host "Verificação OK."

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force $dist | Out-Null
$zip = Join-Path $dist "Pokesap-windows.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $out "*") -DestinationPath $zip
Write-Host "Pronto: $out e $zip"
