extends Node
## Roda golpes de verdade entre pares de criaturas e salva uma folha de quadros de cada
## golpe (preparação, avanço, impacto, recuperação) para conferência. Precisa de janela.
## godot --path . tools/battle_shots.tscn -- <pasta_de_saida>

## [atacante, defensor, golpe]
const CASES := [
	["jiboia", "mico", "bote"],
	["jiboia", "sapo", "constricao"],
	["jiboia", "capivara", "constricao"],
	["arara", "besouro", "rasante"],
	["arara", "jiboia", "ventania"],
	["mico", "arara", "arranhao"],
	["mico", "tucano", "coice"],
	["sapo", "morfo", "lingua"],
	["sapo", "aranha", "toxina"],
	["aranha", "perereca", "presas_venenosas"],
	["aranha", "quati", "teia"],
	["caranguejo", "capivara", "pinca"],
	["caranguejo", "jacare", "bolhas"],
	["poraque", "caranguejo", "choque"],
	["poraque", "tatu", "descarga"],
	["besouro", "quati", "chifre"],
	["morfo", "besouro", "rajada_asas"],
	["tatu", "jacare", "tremor"],
	["capivara", "mico", "banho_lama"],
	["caranguejo", "aranha", "carapaca"],
	["jacare", "capivara", "rolamento"],
	["tucano", "aranha", "bico_broca"],
	["quati", "morfo", "mordida"],
	["perereca", "aranha", "bolhas"],
]

var out_dir := "user://battle_shots"
var errors := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	UI.setup_input()
	UI.setup_theme()
	seed(7)
	var only: Array = args.slice(1)
	for cs in CASES:
		if not only.is_empty() and not cs[0] in only:
			continue
		await _case(cs[0], cs[1], cs[2])
	print("\n%s (%d problemas)" % ["TUDO OK" if errors == 0 else "FALHOU", errors])
	get_tree().quit(1 if errors else 0)


func _case(att: String, def: String, move: String) -> void:
	Game.new_game()
	var me := Creature.create(att, 20)
	me.moves = [{"id": move, "pp": 30}]
	Game.add_creature(me)
	var foe := Creature.create(def, 20)
	var b := Battle.new()
	add_child(b)
	b.prepare(foe, "brejo" if def in ["sapo", "perereca", "jiboia", "poraque"] else "campo")
	b.msg.hide()
	await get_tree().create_timer(0.3).timeout
	var frames: Array[Image] = []
	var running := [true]
	var hp0 := foe.hp
	var st0 := foe.statuses.size() + me.statuses.size()
	_capture(frames, running)
	_auto_ok(b, running)
	await b._use_move(me, foe, move, 0)
	running[0] = false
	await get_tree().create_timer(0.1).timeout
	var m: Dictionary = DB.MOVES[move]
	var changed := foe.hp < hp0 or foe.statuses.size() + me.statuses.size() > st0 or me.stages.values().any(func(v): return v != 0) or foe.stages.values().any(func(v): return v != 0)
	print("%-11s %-17s em %-11s PS %d -> %d  efeitos %s / %s  %s" % [att, move, def, hp0, foe.hp, me.statuses.keys(), foe.statuses.keys(), "ok" if changed else "SEM EFEITO"])
	_sheet(frames, "%s_%s" % [att, move])
	b.queue_free()
	await get_tree().process_frame


## Avança as mensagens sozinho (como se apertasse Z).
func _auto_ok(b: Battle, running: Array) -> void:
	while running[0]:
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(b) and b.msg.waiting:
			var ev := InputEventAction.new()
			ev.action = "ok"
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().process_frame
			var up := InputEventAction.new()
			up.action = "ok"
			Input.parse_input_event(up)


## O cursor do mouse não deve mexer nos menus durante o teste.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		get_viewport().set_input_as_handled()


func _capture(frames: Array[Image], running: Array) -> void:
	while running[0] and frames.size() < 40:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(480, 320, Image.INTERPOLATE_NEAREST)
		frames.append(img)
		await get_tree().create_timer(0.07).timeout


## Junta até 12 quadros espaçados numa folha 4x3 (a 1x).
func _sheet(frames: Array[Image], name: String) -> void:
	if frames.is_empty():
		errors += 1
		return
	var n := mini(12, frames.size())
	var sheet := Image.create(480 * 4, 320 * 3, false, Image.FORMAT_RGBA8)
	for i in n:
		var idx := int(i * (frames.size() - 1) / maxf(1.0, n - 1))
		var f: Image = frames[idx]
		f.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(f, Rect2i(0, 0, 480, 320), Vector2i((i % 4) * 480, (i / 4) * 320))
	sheet.resize(480 * 2, 320 * 3 / 2, Image.INTERPOLATE_NEAREST)
	sheet.save_png("%s/%s.png" % [out_dir, name])
