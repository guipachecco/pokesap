extends Node
## (autoload Settings) Configurações gráficas: carrega e salva em user://settings.cfg,
## aplica o modo de exibição, a resolução, a escala, o VSync e o brilho, e avisa o
## jogo (sinal changed) quando a qualidade do cenário muda.

signal changed

const PATH := "user://settings.cfg"
const BASE := Vector2i(480, 320)  # resolução interna do jogo
const MODES := ["janela", "sem_bordas", "tela_cheia"]
const MODE_NAMES := {"janela": "JANELA", "sem_bordas": "SEM BORDAS", "tela_cheia": "TELA CHEIA"}
const QUALITY_NAMES := {"baixa": "BAIXA", "media": "MÉDIA", "alta": "ALTA", "personalizada": "PERSONALIZADA"}
const PRESETS := {
	"baixa": {"detail": 0, "shadows": false, "animations": false},
	"media": {"detail": 1, "shadows": true, "animations": true},
	"alta": {"detail": 2, "shadows": true, "animations": true},
}
const DETAIL_NAMES := ["BAIXO", "MÉDIO", "ALTO"]
const MIN_BRIGHTNESS := 0.5
const MAX_BRIGHTNESS := 1.5
const DEFAULTS := {
	"mode": "janela",
	"scale": 3,              # janela = 480x320 vezes este número
	"pixel_perfect": true,   # escala inteira (pixels nítidos) ou preencher a tela
	"vsync": true,
	"brightness": 1.0,
	"detail": 2,             # detalhes do cenário: 0 baixo, 1 médio, 2 alto
	"shadows": true,
	"animations": true,      # água, grama balançando, borboletas, piscar
}

var mode: String = DEFAULTS.mode
var scale: int = DEFAULTS.scale
var pixel_perfect: bool = DEFAULTS.pixel_perfect
var vsync: bool = DEFAULTS.vsync
var brightness: float = DEFAULTS.brightness
var detail: int = DEFAULTS.detail
var shadows: bool = DEFAULTS.shadows
var animations: bool = DEFAULTS.animations

var _bright_layer: CanvasLayer
var _bright_rect: ColorRect

const BRIGHTNESS_SHADER := """
shader_type canvas_item;
uniform float brightness = 1.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	// abaixo de 1 escurece por igual; acima de 1 clareia mais as partes escuras,
	// assim as cores claras não estouram e os detalhes continuam visíveis
	c = brightness < 1.0 ? c * brightness : vec3(1.0) - (vec3(1.0) - c) / brightness;
	COLOR = vec4(c, 1.0);
}
"""


func _ready() -> void:
	_bright_layer = CanvasLayer.new()
	_bright_layer.layer = 100
	add_child(_bright_layer)
	_bright_rect = ColorRect.new()
	_bright_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bright_rect.position = Vector2.ZERO
	_bright_rect.size = Vector2(BASE)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = BRIGHTNESS_SHADER
	_bright_rect.material = mat
	_bright_layer.add_child(_bright_rect)
	load_settings()
	if not _is_testing():
		apply_display()
	apply_brightness()


func _is_testing() -> bool:
	return DisplayServer.get_name() == "headless"


# ---------------------------------------------------------------- qualidade

func quality() -> String:
	for q in PRESETS:
		var p: Dictionary = PRESETS[q]
		if p.detail == detail and p.shadows == shadows and p.animations == animations:
			return q
	return "personalizada"


func set_quality(q: String) -> void:
	if not PRESETS.has(q):
		return
	var p: Dictionary = PRESETS[q]
	detail = p.detail
	shadows = p.shadows
	animations = p.animations
	changed.emit()


func set_detail(v: int) -> void:
	detail = clampi(v, 0, 2)
	changed.emit()


func set_shadows(v: bool) -> void:
	shadows = v
	changed.emit()


func set_animations(v: bool) -> void:
	animations = v
	changed.emit()


# ---------------------------------------------------------------- brilho

func set_brightness(v: float) -> void:
	brightness = clampf(snappedf(v, 0.05), MIN_BRIGHTNESS, MAX_BRIGHTNESS)
	apply_brightness()


func apply_brightness() -> void:
	# em 100% o filtro fica desligado (nenhum custo)
	_bright_layer.visible = not is_equal_approx(brightness, 1.0)
	(_bright_rect.material as ShaderMaterial).set_shader_parameter("brightness", brightness)


# ---------------------------------------------------------------- exibição

## Escalas de janela que cabem na área útil do monitor (sem contar a barra de tarefas).
func available_scales() -> Array[int]:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var out: Array[int] = []
	for s in range(1, 9):
		# margem para a barra de título da janela
		if BASE.x * s <= usable.size.x and BASE.y * s + 40 <= usable.size.y:
			out.append(s)
	if out.is_empty():
		out.append(1)
	return out


func screen_size() -> Vector2i:
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


func resolution_text(s := scale) -> String:
	return "%dx%d" % [BASE.x * s, BASE.y * s]


func apply_display() -> void:
	var win := get_window()
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_perfect else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	match mode:
		"tela_cheia":
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		"sem_bordas":
			win.mode = Window.MODE_FULLSCREEN
		_:
			if win.mode != Window.MODE_WINDOWED:
				win.mode = Window.MODE_WINDOWED
			win.borderless = false
			win.unresizable = false
			var scales := available_scales()
			if not scale in scales:
				scale = scales.max()
			win.size = BASE * scale
			win.move_to_center()


# ---------------------------------------------------------------- salvar / carregar

func snapshot() -> Dictionary:
	return {"mode": mode, "scale": scale, "pixel_perfect": pixel_perfect, "vsync": vsync,
		"brightness": brightness, "detail": detail, "shadows": shadows, "animations": animations}


func restore(d: Dictionary) -> void:
	mode = d.get("mode", DEFAULTS.mode)
	scale = d.get("scale", DEFAULTS.scale)
	pixel_perfect = d.get("pixel_perfect", DEFAULTS.pixel_perfect)
	vsync = d.get("vsync", DEFAULTS.vsync)
	brightness = d.get("brightness", DEFAULTS.brightness)
	detail = d.get("detail", DEFAULTS.detail)
	shadows = d.get("shadows", DEFAULTS.shadows)
	animations = d.get("animations", DEFAULTS.animations)
	_validate()


func reset_defaults() -> void:
	restore(DEFAULTS)


func save_settings() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("exibicao", "modo", mode)
	cfg.set_value("exibicao", "escala_janela", scale)
	cfg.set_value("exibicao", "pixels_nitidos", pixel_perfect)
	cfg.set_value("exibicao", "vsync", vsync)
	cfg.set_value("imagem", "brilho", brightness)
	cfg.set_value("qualidade", "detalhes", detail)
	cfg.set_value("qualidade", "sombras", shadows)
	cfg.set_value("qualidade", "animacoes", animations)
	return cfg.save(PATH) == OK


## Lê o arquivo. Se não existir ou tiver valores inválidos, usa os padrões.
func load_settings() -> void:
	reset_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mode = str(cfg.get_value("exibicao", "modo", DEFAULTS.mode))
	scale = _to_int(cfg.get_value("exibicao", "escala_janela", DEFAULTS.scale), DEFAULTS.scale)
	pixel_perfect = _to_bool(cfg.get_value("exibicao", "pixels_nitidos", DEFAULTS.pixel_perfect), DEFAULTS.pixel_perfect)
	vsync = _to_bool(cfg.get_value("exibicao", "vsync", DEFAULTS.vsync), DEFAULTS.vsync)
	var b = cfg.get_value("imagem", "brilho", DEFAULTS.brightness)
	brightness = float(b) if typeof(b) in [TYPE_FLOAT, TYPE_INT] else DEFAULTS.brightness
	detail = _to_int(cfg.get_value("qualidade", "detalhes", DEFAULTS.detail), DEFAULTS.detail)
	shadows = _to_bool(cfg.get_value("qualidade", "sombras", DEFAULTS.shadows), DEFAULTS.shadows)
	animations = _to_bool(cfg.get_value("qualidade", "animacoes", DEFAULTS.animations), DEFAULTS.animations)
	_validate()


func _validate() -> void:
	if not mode in MODES:
		mode = DEFAULTS.mode
	if scale < 1 or scale > 8:
		scale = DEFAULTS.scale
	if is_nan(brightness) or brightness < MIN_BRIGHTNESS or brightness > MAX_BRIGHTNESS:
		brightness = DEFAULTS.brightness
	if detail < 0 or detail > 2:
		detail = DEFAULTS.detail


func _to_int(v, fallback: int) -> int:
	return int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else fallback


func _to_bool(v, fallback: bool) -> bool:
	return v if typeof(v) == TYPE_BOOL else fallback
