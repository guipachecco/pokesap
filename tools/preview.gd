extends Node
## Gera uma folha com sprites, ícones, fonte e fundos para conferência.
## godot --headless --path . tools/preview.tscn -- saida.png


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://preview.png"
	var sheet := Image.create(960, 760, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("efe6cf"))
	var i := 0
	for id in DB.species_ids_by_num():
		var img: Image = Art.animal(id).get_image()
		img.resize(128, 128, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, 128, 128), Vector2i((i % 7) * 136 + 4, (i / 7) * 136 + 4))
		i += 1
	var x := 4
	for t in DB.CLASSES:
		var img: Image = Art.type_icon(t).get_image()
		img.resize(64, 64, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, 64, 64), Vector2i(x, 280))
		x += 68
	for k in Art.ICONS:
		var img: Image = Art.icon(k).get_image()
		img.resize(64, 64, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, 64, 64), Vector2i(x, 280))
		x += 68
		if x > 900:
			x = 4
	var y := 420
	for z in ["campo", "brejo", "praia"]:
		var bg: Image = Art.battle_bg(z).get_image()
		sheet.blend_rect(bg, Rect2i(0, 0, 240, 160), Vector2i(4 + ["campo", "brejo", "praia"].find(z) * 248, y))
	var p: Image = Art.panel_texture(Color("fff6e0"), Color("3b2a2a")).get_image()
	p.resize(48, 56, Image.INTERPOLATE_NEAREST)
	sheet.blend_rect(p, Rect2i(0, 0, 48, 56), Vector2i(760, 420))
	sheet.save_png(out)
	# amostra da fonte num viewport real
	get_tree().quit()
