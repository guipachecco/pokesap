class_name SaveGuard
extends RefCounted
## Protege o save de quem está jogando durante os testes: stash() move os arquivos de
## save para cópias ao lado (.guardado) e restore() devolve. Como as cópias ficam no
## disco, mesmo um teste interrompido no meio não perde o save: o próximo stash()
## devolve primeiro o que tinha ficado guardado.

const SUFFIX := ".guardado"


static func _paths() -> Array:
	return [Game.SAVE_PATH, Game.SAVE_PATH + ".bak"]


static func stash() -> void:
	restore()  # sobrou de um teste interrompido? devolve antes de guardar de novo
	for p in _paths():
		if FileAccess.file_exists(p):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(p), ProjectSettings.globalize_path(p + SUFFIX))


## Fim do teste: apaga os saves que o teste criou e devolve os do jogador.
static func finish() -> void:
	for p in _paths():
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	restore()


static func restore() -> void:
	var any := false
	for p in _paths():
		if FileAccess.file_exists(p + SUFFIX):
			any = true
	if not any:
		return
	for p in _paths():
		var g := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(g)  # save criado pelo teste
		if FileAccess.file_exists(p + SUFFIX):
			DirAccess.rename_absolute(g + SUFFIX, g)
