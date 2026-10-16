class_name CreatureView
extends Node2D
## Uma criatura na batalha: toca as animações da spritesheet (parada, andando, golpes,
## dano, esquiva, derrota), avança até o alvo nos golpes de contato, pisca ao levar
## dano e mostra os efeitos de estado. A posição do nó é o ponto dos pés.
## Use: await view.play("bite", alvo_global, true)  e  view.impact (sinal do acerto).

signal impact
signal finished

const FLASH_SHADER := """
shader_type canvas_item;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = mix(c.rgb * tint.rgb, flash_color.rgb, flash);
	COLOR = vec4(rgb, c.a) * COLOR;
}
"""

static var _shader: Shader

var species := ""
var facing_right := false
var body: Sprite2D
var status_fx: StatusFX
var _set: Dictionary
var _anim := ""
var _frame := 0
var _t := 0.0
var _home := Vector2.ZERO
var _dash := Vector2.ZERO
var _dashing := false
var _impact_sent := false
var _mat: ShaderMaterial


func _init() -> void:
	scale = Vector2(2, 2)
	body = Sprite2D.new()
	body.centered = false
	body.offset = -CreatureSprites.ANCHOR
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLASH_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	body.material = _mat
	add_child(body)
	status_fx = StatusFX.new()
	status_fx.view = self
	add_child(status_fx)


func set_species(id: String, right := false) -> void:
	species = id
	facing_right = right
	body.flip_h = right
	_set = CreatureSprites.get_set(id)
	_mat.set_shader_parameter("flash", 0.0)
	_mat.set_shader_parameter("tint", Color.WHITE)
	_start("idle")


func has_anim(name: String) -> bool:
	return _set.meta.anims.has(name)


func _start(name: String) -> void:
	if not has_anim(name):
		name = "idle"
	_anim = name
	_frame = 0
	_t = 0.0
	_impact_sent = false
	_show_frame()


func _anim_data() -> Dictionary:
	return _set.meta.anims[_anim]


func _show_frame() -> void:
	var a := _anim_data()
	body.texture = _set.frames[int(a.frames[_frame])]


## Toca uma animação até o fim (as em loop voltam na hora). Com dash, avança na
## direção do alvo conforme o quanto a pose está esticada (reach).
func play(name: String, target_global := Vector2.ZERO, contact := false) -> void:
	_start(name)
	_home = position
	_dashing = contact and _anim_data().get("dash", false) and target_global != Vector2.ZERO
	if _dashing:
		var parent := get_parent()
		var to: Vector2 = (parent as Node2D).to_local(target_global) if parent is Node2D else target_global
		var d: Vector2 = to - position
		# para um pouco antes do alvo
		_dash = d - d.normalized() * 70.0
	if _anim_data().get("loop", false):
		return
	await finished
	position = _home


func _process(delta: float) -> void:
	if _set.is_empty():
		return
	var a := _anim_data()
	var n: int = a.frames.size()
	_t += delta
	var dur: float = a.durations[_frame]
	while _t >= dur:
		_t -= dur
		_frame += 1
		if _frame >= n:
			if a.get("loop", false):
				_frame = 0
			else:
				_frame = n - 1
				_finish()
				return
		_show_frame()
		dur = a.durations[_frame]
		if _frame == int(a.get("impact", -1)) and not _impact_sent:
			_impact_sent = true
			impact.emit()
	if _dashing:
		var r0: float = a.reach[_frame]
		var r1: float = a.reach[mini(_frame + 1, n - 1)]
		var r := lerpf(r0, r1, clampf(_t / dur, 0.0, 1.0))
		position = (_home + _dash * r).round()


func _finish() -> void:
	if not _impact_sent and int(_anim_data().get("impact", -1)) >= 0:
		_impact_sent = true
		impact.emit()
	var was := _anim
	_dashing = false
	if was != "defeat":
		_start("idle")
	finished.emit()


## Pisca de uma cor (branco ao levar dano).
func flash(col := Color.WHITE, times := 2) -> void:
	_mat.set_shader_parameter("flash_color", col)
	for i in times:
		_mat.set_shader_parameter("flash", 0.85)
		await get_tree().create_timer(0.05).timeout
		_mat.set_shader_parameter("flash", 0.0)
		await get_tree().create_timer(0.06).timeout


func set_tint(c: Color) -> void:
	_mat.set_shader_parameter("tint", c)


## Ponto do corpo em coordenadas globais (boca, cabeça, centro), já espelhado.
func point_global(name: String) -> Vector2:
	var p := CreatureSprites.point(species, name) - CreatureSprites.ANCHOR
	if facing_right:
		p.x = -p.x
	return to_global(p)


func set_statuses(st: Dictionary) -> void:
	status_fx.statuses = st.keys()
	set_tint(Color(0.7, 0.9, 1.0) if st.has("congelado") else Color.WHITE)


# ---------------------------------------------------------------- efeitos de estado

class StatusFX extends Node2D:
	## Desenha os efeitos de estado em volta da criatura (em pixels do quadro).
	var view: CreatureView
	var statuses: Array = []
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if not statuses.is_empty():
			queue_redraw()
		elif _t > 0.0:
			queue_redraw()
			_t = 0.0

	func _p(name: String) -> Vector2:
		var p := CreatureSprites.point(view.species, name) - CreatureSprites.ANCHOR
		if view.facing_right:
			p.x = -p.x
		return p

	func _px(p: Vector2, c: Color, s := 1.0) -> void:
		draw_rect(Rect2(p.floor(), Vector2(s, s)), c)

	func _draw() -> void:
		var c := _p("center")
		var h := _p("head")
		for id in statuses:
			match id:
				"veneno":
					for i in 4:
						var ph := fmod(_t * 0.8 + i * 0.27, 1.0)
						var p := c + Vector2(-10 + i * 7, 6 - ph * 26)
						var col := Color(0.62, 0.3, 0.8, 1.0 - ph)
						draw_rect(Rect2(p.floor(), Vector2(2, 2)), col)
						_px(p + Vector2(0, -1), Color(0.85, 0.65, 1.0, 1.0 - ph))
				"queimadura":
					for i in 3:
						var fl := fmod(_t * 6 + i * 2.1, 3.0)
						var p := c + Vector2(-8 + i * 8, 14)
						draw_rect(Rect2(p + Vector2(0, -fl), Vector2(2, 3 + fl)), Color(1.0, 0.45, 0.15, 0.85))
						_px(p + Vector2(0, -fl - 1), Color(1.0, 0.85, 0.3))
				"lento":
					for i in 3:
						var ph := fmod(_t * 0.5 + i * 0.33, 1.0)
						var p := c + Vector2(-12 + i * 10, 4 + ph * 12)
						draw_rect(Rect2(p.floor(), Vector2(1, 2)), Color(0.45, 0.65, 1.0, 1.0 - ph))
				"congelado":
					for i in 6:
						var a := i * TAU / 6.0 + _t * 0.3
						var p := c + Vector2(cos(a) * 18, sin(a) * 12)
						_px(p, Color(0.85, 0.97, 1.0))
						_px(p + Vector2(1, 0), Color(0.6, 0.9, 1.0))
				"atordoado":
					for i in 3:
						var a := _t * 4.0 + i * TAU / 3.0
						var p := h + Vector2(cos(a) * 9, -8 + sin(a) * 3)
						var col := Color(1.0, 0.9, 0.3)
						_px(p, col)
						_px(p + Vector2(-1, 0), col)
						_px(p + Vector2(1, 0), col)
						_px(p + Vector2(0, -1), col)
						_px(p + Vector2(0, 1), col)
				"preso":
					var g := Color(0.3, 0.7, 0.3, 0.9)
					for i in 3:
						var y := 14.0 - i * 6.0
						for x in range(-16, 17, 2):
							var yy := y + sin((x + i * 3) * 0.4 + _t * 2.0) * 1.5
							_px(c + Vector2(x, yy), g)
				"escudo":
					var col := Color(0.65, 0.85, 1.0, 0.55 + 0.25 * sin(_t * 4.0))
					for i in 48:
						var a := i * TAU / 48.0
						var p := c + Vector2(cos(a) * 26, sin(a) * 24 - 4)
						_px(p, col)
					_px(c + Vector2(-14, -20), Color(1, 1, 1, 0.8), 2)
				"regeneracao":
					for i in 3:
						var ph := fmod(_t * 0.7 + i * 0.33, 1.0)
						var p := c + Vector2(-10 + i * 10, 2 - ph * 24)
						var col := Color(0.4, 0.9, 0.4, 1.0 - ph)
						draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), col)
						draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), col)
