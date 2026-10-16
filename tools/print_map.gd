extends Node
## Imprime a grade de uma região (já com casas, fogueiras, placas e móveis):
##   godot --headless --path . tools/print_map.tscn -- [região]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if not args.is_empty() else "ilha"
	var m := Regions.map(id)
	var s := "    "
	for x in m.w:
		s += str(x % 10)
	print(s)
	for y in m.h:
		print("%3d " % y + "".join(PackedStringArray(m.grid[y])))
	get_tree().quit()
