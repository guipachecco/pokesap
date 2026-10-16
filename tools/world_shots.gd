extends Node
## Tira capturas de tela das regiões em vários pontos e nos 3 zooms de câmera
## (precisa de janela, não headless). godot --path . tools/world_shots.tscn -- <pasta>

const SPOTS := [
	["ilha", "casa", Vector2i(23, 13)],
	["ilha", "campo", Vector2i(12, 16)],
	["ilha", "brejo", Vector2i(17, 23)],
	["ilha", "praia", Vector2i(40, 20)],
	["ilha", "cais", Vector2i(23, 30)],
	["manguezal", "mangue_cais", Vector2i(7, 24)],
	["manguezal", "mangue_cabana", Vector2i(20, 19)],
	["manguezal", "mangue_passarela", Vector2i(20, 10)],
]

var out_dir := "user://world_shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	UI.setup_input()
	UI.setup_theme()
	Game.new_game()
	Game.add_creature(Creature.create("mico", 5))
	Game.flags["starter"] = true
	Game.flags["registro_ok"] = true
	Game.campfires["ilha:casa"] = true
	var t0 := Time.get_ticks_msec()
	var ow := Overworld.new()
	ow.encounters_enabled = false
	add_child(ow)
	print("ilha montada em %d ms" % (Time.get_ticks_msec() - t0))
	ow.busy = true
	for s in SPOTS:
		if ow.region_id != s[0]:
			t0 = Time.get_ticks_msec()
			ow.load_region(s[0], s[2])
			print("%s montado em %d ms" % [s[0], Time.get_ticks_msec() - t0])
		ow.place_player(s[2], Vector2i.DOWN)
		ow.camera.reset_smoothing()
		await get_tree().create_timer(0.3).timeout
		await _shot(s[1])
	ow.load_region("ilha", Vector2i(23, 14))
	for z in [1, 3]:
		Settings.set_camera_zoom(z)
		await get_tree().create_timer(0.3).timeout
		await _shot("zoom_%d" % z)
	Settings.set_camera_zoom(2)
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(960, 640, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out_dir, name])
