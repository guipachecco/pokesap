class_name MessageBox
extends Panel
## Caixa de texto com efeito máquina de escrever e paginação (2 linhas por página).
## Use: await box.say("texto")

signal _advance

const CHAR_DELAY := 0.016
const LINES_PER_PAGE := 2

var label: Label
var arrow: Label
var typing := false
var waiting := false
var text_width := 0.0  # 0 = largura total
var _blink := 0.0


func _init(rect := Rect2(4, 244, 472, 72)) -> void:
	position = rect.position
	size = rect.size
	add_theme_stylebox_override("panel", UI.box_style())
	label = UI.label("", Vector2(14, 12), UI.NORMAL, UI.TEXT)
	label.add_theme_constant_override("line_spacing", 2)
	add_child(label)
	arrow = UI.label("▼", Vector2(rect.size.x - 24, rect.size.y - 26), UI.NORMAL, UI.RED)
	arrow.hide()
	add_child(arrow)


func _process(delta: float) -> void:
	if waiting:
		_blink += delta
		arrow.visible = true
		arrow.position.y = size.y - 26 + (2 if fmod(_blink, 0.6) < 0.3 else 0)


## Quebra o texto em linhas que cabem na largura (respeita \n).
func _wrap(text: String) -> Array:
	var max_w := (text_width if text_width > 0.0 else size.x - 40.0)
	var lines: Array = []
	for para in text.split("\n"):
		var cur := ""
		for word in para.split(" "):
			var tryit := word if cur == "" else cur + " " + word
			if UI.text_width(tryit) <= max_w or cur == "":
				cur = tryit
			else:
				lines.append(cur)
				cur = word
		lines.append(cur)
	return lines


## Mostra texto. Se wait=true, espera o jogador apertar OK (em cada página).
func say(text: String, wait := true) -> void:
	show()
	var lines := _wrap(text)
	var page := 0
	while page * LINES_PER_PAGE < lines.size():
		var chunk := "\n".join(PackedStringArray(lines.slice(page * LINES_PER_PAGE, (page + 1) * LINES_PER_PAGE)))
		var last := (page + 1) * LINES_PER_PAGE >= lines.size()
		await _type(chunk)
		if wait or not last:
			_blink = 0.0
			waiting = true
			await _advance
			arrow.hide()
		page += 1


func _type(chunk: String) -> void:
	label.text = chunk
	label.visible_characters = 0
	typing = true
	var n := chunk.length()
	while typing and label.visible_characters < n:
		label.visible_characters += 1
		await get_tree().create_timer(CHAR_DELAY).timeout
	label.visible_characters = -1
	typing = false


## Mostra texto e espera um tempo fixo (sem tecla).
func flash(text: String, seconds := 0.9) -> void:
	await say(text, false)
	await get_tree().create_timer(seconds).timeout


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ok") or event.is_action_pressed("cancel"):
		if typing:
			typing = false
			get_viewport().set_input_as_handled()
		elif waiting:
			waiting = false
			get_viewport().set_input_as_handled()
			_advance.emit.call_deferred()
