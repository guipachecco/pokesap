class_name MessageBox
extends Panel
## Caixa de texto com efeito máquina de escrever. Use: await box.say("texto")

signal _advance

const CHAR_DELAY := 0.016

var label: Label
var arrow: Label
var typing := false
var waiting := false
var _blink := 0.0


func _init(rect := Rect2(4, 244, 472, 72)) -> void:
	position = rect.position
	size = rect.size
	add_theme_stylebox_override("panel", UI.box_style())
	label = UI.label("", Vector2(14, 9), 14, UI.TEXT, rect.size.x - 36)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size.y = rect.size.y - 16
	label.add_theme_constant_override("line_spacing", 2)
	add_child(label)
	arrow = UI.label("▼", Vector2(rect.size.x - 24, rect.size.y - 24), 12, Color("e05040"))
	arrow.hide()
	add_child(arrow)


func _process(delta: float) -> void:
	if waiting:
		_blink += delta
		arrow.visible = fmod(_blink, 0.6) < 0.4


## Mostra texto. Se wait=true, espera o jogador apertar OK.
func say(text: String, wait := true) -> void:
	show()
	label.text = text
	label.visible_characters = 0
	typing = true
	var n := text.length()
	while typing and label.visible_characters < n:
		label.visible_characters += 1
		await get_tree().create_timer(CHAR_DELAY).timeout
	label.visible_characters = -1
	typing = false
	if wait:
		_blink = 0.0
		waiting = true
		await _advance
		arrow.hide()


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
