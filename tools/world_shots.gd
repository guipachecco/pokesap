extends Node
## Tira capturas de tela da ilha em vários pontos (precisa de janela, não headless).
## godot --path . tools/world_shots.tscn -- <pasta_de_saida>

const SPOTS := {
	"casa": Vector2i(23, 13),
	"campo": Vector2i(12, 16),
	"brejo": Vector2i(17, 23),
	"praia": Vector2i(40, 20),
	"bosque": Vector2i(34, 14),
	"sul": Vector2i(23, 29),
}

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
	var t0 := Time.get_ticks_msec()
	var ow := Overworld.new()
	ow.encounters_enabled = false
	add_child(ow)
	print("ilha montada em %d ms" % (Time.get_ticks_msec() - t0))
	ow.busy = true
	for name in SPOTS:
		var p: Vector2i = SPOTS[name]
		ow.player_tile = p
		ow.player.position = ow._tile_to_px(p)
		ow.camera.reset_smoothing()
		await get_tree().create_timer(0.3).timeout
		await _shot(name)
	# caminhada na diagonal (quadros da animação)
	ow.busy = false
	ow.player_tile = SPOTS.casa + Vector2i(-2, 3)
	ow.player.position = ow._tile_to_px(ow.player_tile)
	Input.action_press("right")
	Input.action_press("down")
	await get_tree().create_timer(0.12).timeout
	await _shot("andando")
	Input.action_release("right")
	Input.action_release("down")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(960, 640, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out_dir, name])
