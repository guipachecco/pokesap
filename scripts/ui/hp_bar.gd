class_name HPBar
extends Control
## Barra de PS (verde/amarelo/vermelho) ou de experiência, em pixel art.

var exp_mode := false
var ratio := 1.0:
	set(v):
		ratio = clampf(v, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var w := floorf(size.x)
	var h := floorf(size.y)
	# contorno com cantos recortados
	draw_rect(Rect2(1, 0, w - 2, h), UI.INK)
	draw_rect(Rect2(0, 1, w, h - 2), UI.INK)
	var inner := Rect2(1, 1, w - 2, h - 2)
	draw_rect(inner, Color("e9dcc0") if exp_mode else Color("6b5a52"))
	var c := Color("5ab8f8")
	if not exp_mode:
		c = Color("62d058") if ratio > 0.5 else (Color("f8c838") if ratio > 0.2 else Color("f05a48"))
	if ratio > 0.0:
		var fw := maxf(1.0, roundf(inner.size.x * ratio))
		draw_rect(Rect2(inner.position, Vector2(fw, inner.size.y)), c)
		if inner.size.y >= 3:
			draw_rect(Rect2(inner.position, Vector2(fw, 1)), c.lightened(0.45))
			draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(fw, 1)), c.darkened(0.25))
