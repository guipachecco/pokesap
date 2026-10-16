extends Node
## Gera as spritesheets das criaturas (assets/creatures/<id>.png + .json) a partir dos rigs.
## godot --headless --path . tools/bake_creatures.tscn [-- especie ...]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var ids: Array = args if args.size() > 0 else CreatureRigs.SPECIES_WITH_RIG
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CreatureSprites.DIR))
	for id in ids:
		var t0 := Time.get_ticks_msec()
		var err := CreatureSprites.save_baked(id)
		print("%s: %s em %d ms" % [id, "ok" if err == OK else "ERRO %d" % err, Time.get_ticks_msec() - t0])
	get_tree().quit()
