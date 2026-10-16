class_name PlayerHud
extends Panel
## Painel do aventureiro (aparece com o menu de pausa): nível, barra de XP, XP que
## falta, kwanzas e a próxima recompensa de nível.

var _lvl: Label
var _xp: Label
var _bar: HPBar
var _kz: Label
var _next: Label


func _init() -> void:
	position = Vector2(150, 6)
	size = Vector2(164, 92)
	add_theme_stylebox_override("panel", Art.panel_style(UI.CREAM, UI.INK))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI.label("AVENTUREIRO", Vector2(10, 6), UI.SMALL, UI.TEXT_MUTED))
	var badge := UI.panel(Rect2(104, 4, 52, 20), UI.ACCENT, UI.INK)
	_lvl = UI.shadow_label("", Vector2(6, 2), UI.SMALL)
	badge.add_child(_lvl)
	add_child(badge)
	_bar = HPBar.new()
	_bar.exp_mode = true
	_bar.position = Vector2(10, 28)
	_bar.size = Vector2(144, 7)
	add_child(_bar)
	_xp = UI.label("", Vector2(10, 38), UI.SMALL, UI.BLUE, 144)
	add_child(_xp)
	add_child(UI.sprite_rect(Icons.geral("kwanza", 16), Vector2(8, 52)))
	_kz = UI.label("", Vector2(28, 53), UI.SMALL, UI.TEXT, 130)
	add_child(_kz)
	_next = UI.label("", Vector2(10, 70), UI.SMALL, UI.TEXT_MUTED, 150)
	add_child(_next)


func refresh() -> void:
	_lvl.text = "NV %d" % Game.player_level
	_bar.ratio = Progression.fraction()
	if Game.player_level >= Progression.MAX_LEVEL:
		_xp.text = "NÍVEL MÁXIMO"
	else:
		_xp.text = "XP %d/%d" % [Game.player_xp, Progression.xp_to_next(Game.player_level)]
	_kz.text = Economy.fmt(Game.kwanzas)
	var nr := Progression.next_reward_level()
	_next.text = "PRÊMIO NO NV %d" % nr if nr > 0 else "TODOS OS PRÊMIOS"
