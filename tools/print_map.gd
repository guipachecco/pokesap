extends SceneTree
## Imprime a grade de uma região: godot --headless --path . -s tools/print_map.gd


func _init() -> void:
	var m := IslandMap.new()
	var s := "    "
	for x in m.w:
		s += str(x % 10)
	print(s)
	for y in m.h:
		print("%3d " % y + "".join(PackedStringArray(m.grid[y])))
	quit()
