class_name StoryRunner
extends RefCounted
## Executa o roteiro (Story): escolhe a fala certa de cada NPC, roda scripts de
## eventos, abre e conclui missões e confere os objetivos. A parte visual (caixa de
## texto, perguntas, viagens, batalhas) é feita pelo Overworld.

var ow: Overworld


func _init(overworld: Overworld) -> void:
	ow = overworld


# ---------------------------------------------------------------- condições

func check(cond: Dictionary) -> bool:
	for k in cond:
		var v = cond[k]
		match k:
			"flag":
				if not Game.flags.get(v, false):
					return false
			"not_flag":
				if Game.flags.get(v, false):
					return false
			"quest_active":
				if Game.quest_state(v) != "active":
					return false
			"quest_done":
				if Game.quest_state(v) != "done":
					return false
			"quest_new":
				if Game.quest_state(v) != "":
					return false
			"has_species":
				if not Game.has_species_in_party(v):
					return false
			"caught":
				if not Game.caught.has(v):
					return false
			"seen_at_least":
				if Game.seen.size() < int(v):
					return false
			"party_empty":
				if Game.party.is_empty() != bool(v):
					return false
			"campfires":
				for c in v:
					if not Game.campfires.has(c):
						return false
	return true


func text(s: String) -> String:
	return s.replace("{seen}", str(Game.seen.size()))


# ---------------------------------------------------------------- execução

## Fala com um NPC: roda a primeira entrada cuja condição vale.
func talk(dialog_id: String) -> void:
	for entry in Story.DIALOGUES.get(dialog_id, []):
		if check(entry.get("if", {})):
			await run(entry.do)
			return


func run_named(name: String) -> void:
	await run(Story.SCRIPTS[name])


func run(script: Array) -> void:
	var rc := ow.region_changes
	for cmd in script:
		await _do(cmd)
		if ow.region_changes != rc:
			return  # mudou de região: o resto do script não vale mais aqui
	ow.msg.hide()


func _do(cmd: Array) -> void:
	match cmd[0]:
		"say":
			await ow.msg.say(text(cmd[1]))
		"say_random":
			var opts: Array = cmd[1]
			await ow.msg.say(text(opts[randi() % opts.size()]))
		"give":
			Game.add_item(cmd[1], int(cmd[2]))
		"heal":
			Game.heal_party()
		"flag":
			Game.flags[cmd[1]] = true
		"unflag":
			Game.flags.erase(cmd[1])
		"quest_start":
			if Game.start_quest(cmd[1]):
				await ow.toast("NOVA MISSÃO", Story.QUESTS[cmd[1]].title)
		"quest_done":
			if Game.quest_state(cmd[1]) == "":
				Game.start_quest(cmd[1])
			if Game.complete_quest(cmd[1]):
				await ow.toast("MISSÃO CONCLUÍDA", Story.QUESTS[cmd[1]].title)
		"ask":
			var yes := await ow.ask(text(cmd[1]))
			await run(cmd[2] if yes else cmd[3])
		"warp":
			await ow.change_region(cmd[1], cmd[2])
		"step_back":
			await ow.step_back()
		"remove_npc":
			Game.flags["sem_npc:%s:%s" % [ow.region_id, cmd[1]]] = true
			await ow.remove_npc(cmd[1])
		"choose_starter":
			await ow.give_starter()
		"battle":
			var result: String = await ow.story_battle(cmd[1], int(cmd[2]), cmd[3])
			if result == "win" or result == "caught":
				await run(cmd[4])
			elif cmd.size() > 5:
				await run(cmd[5])
		"if":
			await run(cmd[2] if check(cmd[1]) else (cmd[3] if cmd.size() > 3 else []))


## Confere os objetivos das missões ativas (depois de batalhas, capturas, fogueiras).
func update_goals() -> void:
	for id in Story.QUEST_ORDER:
		if Game.quest_state(id) != "active":
			continue
		var q: Dictionary = Story.QUESTS[id]
		if not q.has("goal") or not check(q.goal):
			continue
		if q.get("auto", false):
			Game.complete_quest(id)
			await ow.toast("MISSÃO CONCLUÍDA", q.title)
			await run(q.get("reward", []))
		elif not Game.flags.get(q.ready_flag, false):
			Game.flags[q.ready_flag] = true
			await ow.toast("OBJETIVO CUMPRIDO", q.title)
			if q.has("ready"):
				await ow.msg.say(q.ready)
				ow.msg.hide()
