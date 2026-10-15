class_name HPBar
extends Control
## Barra de PS (verde/amarelo/vermelho) ou de experiência.

var exp_mode := false
var ratio := 1.0:
	set(v):
		ratio = clampf(v, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("404858"))
	var inner := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	draw_rect(inner, Color("e8e8e0") if exp_mode else Color("586070"))
	var c := Color("48a8f8")
	if not exp_mode:
		c = Color("58d068") if ratio > 0.5 else (Color("f8c838") if ratio > 0.2 else Color("f05848"))
	if ratio > 0.0:
		var w := maxf(1.0, inner.size.x * ratio)
		draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), c)
		draw_rect(Rect2(inner.position, Vector2(w, 1)), c.lightened(0.35))
