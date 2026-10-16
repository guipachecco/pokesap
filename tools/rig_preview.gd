extends Node
## Folha de conferência das poses das criaturas (ampliada 3x).
## godot --headless --path . tools/rig_preview.tscn -- saida.png especie [especie...]

const POSES := [
	{}, {"blink": 1, "bob": -1}, {"coil": 1, "claw": 1}, {"reach": 1, "jaw": 1}, {"reach": 1, "claw": -1, "sting": 1},
	{"wing": 2, "coil": 0.8}, {"tongue": 1, "jaw": 1, "reach": 0.3}, {"hurt": 1}, {"down": 1},
	{"view": "front"}, {"view": "front", "blink": 1}, {"view": "front", "jaw": 1}, {"reach": 1, "wrap": 1, "squeeze": 1},
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://rigs.png"
	var species: Array = args.slice(1) if args.size() > 1 else CreatureRigs.SPECIES_WITH_RIG
	var cols := POSES.size()
	var sheet := Image.create(cols * 96 * 3, species.size() * 80 * 3 + species.size() * 40 * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("d8e8d0"))
	var t0 := Time.get_ticks_msec()
	var frames := 0
	for si in species.size():
		for pi in cols:
			var img := CreatureArt.render(CreatureRigs.build(species[si], POSES[pi]))
			frames += 1
			img.resize(96 * 3, 80 * 3, Image.INTERPOLATE_NEAREST)
			sheet.blend_rect(img, Rect2i(0, 0, 96 * 3, 80 * 3), Vector2i(pi * 96 * 3, si * 120 * 3))
		var icon := CreatureArt.render(CreatureRigs.build(species[si], {}), 0.5, Vector2i(48, 40))
		frames += 1
		icon.resize(48 * 3, 40 * 3, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(icon, Rect2i(0, 0, 48 * 3, 40 * 3), Vector2i(0, si * 120 * 3 + 80 * 3))
	print("%d quadros em %d ms" % [frames, Time.get_ticks_msec() - t0])
	sheet.save_png(out)
	get_tree().quit()
