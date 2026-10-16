class_name StoryRunner
extends RefCounted
## Executa o roteiro (Story): escolhe a fala certa de cada NPC, roda scripts de
## eventos, abre e conclui missões e mostra os avisos das missões. A parte visual
## (caixa de texto, perguntas, viagens, batalhas, telas) é feita pelo Overworld.

var ow: Overworld


func _init(overworld: Overworld) -> void:
	ow = overworld


# ---------------------------------------------------------------- condições

## Confere uma condição de Story (todas as chaves precisam valer). Estática: usada
## também por Quests, Regions e pelo próprio mundo.
static func test(cond: Dictionary) -> bool:
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
			"quest_ready":
				if not Quests.is_ready(v):
					return false
			"quest_step":
				var step := Quests.current_step(v[0])
				if Game.quest_state(v[0]) != "active" or (step >= 0 and step < int(v[1])):
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
			"has_item":
				var item: String = v if typeof(v) == TYPE_STRING else v[0]
				var qty: int = 1 if typeof(v) == TYPE_STRING else int(v[1])
				if Game.item_count(item) < qty:
					return false
			"level_at_least":
				if Game.player_level < int(v):
					return false
			"trainer_beaten":
				if not Trainers.beaten(v):
					return false
			"trainer_not_beaten":
				if Trainers.beaten(v):
					return false
			"region_unlocked":
				if not Regions.unlocked(v):
					return false
			"any_fainted":
				if Game.fainted().is_empty() == bool(v):
					return false
			"revival_active":
				if Hospital.has_request() != bool(v):
					return false
	return true


func check(cond: Dictionary) -> bool:
	return test(cond)


func text(s: String) -> String:
	return s.replace("{seen}", str(Game.seen.size())).replace("{nivel}", str(Game.player_level)) \
		.replace("{kz}", Economy.fmt(Game.kwanzas))


# ---------------------------------------------------------------- execução

## Fala com um NPC: roda a primeira entrada cuja condição vale.
func talk(dialog_id: String) -> void:
	Game.emit_event("talk", {"npc": dialog_id})
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
			Game.emit_event("flag", {"flag": cmd[1]})
		"unflag":
			Game.flags.erase(cmd[1])
		"quest_start":
			Quests.start(cmd[1])
		"quest_done":
			var r: Dictionary = Story.QUESTS[cmd[1]].get("rewards", {})
			if Quests.complete(cmd[1]) and not r.is_empty():
				await ow.msg.say("Recompensa: %s." % Quests.rewards_text(r))
		"deliver":
			var r: Dictionary = Story.QUESTS[cmd[1]].get("rewards", {})
			if Quests.deliver(cmd[1]):
				await ow.msg.say("Você entregou os itens. Recompensa: %s." % Quests.rewards_text(r))
		"say_step":
			var step := Quests.current_step(cmd[1])
			if step >= 0:
				await ow.msg.say("Etapa atual: %s." % Quests.objectives(cmd[1])[step].text)
		"ask":
			var yes := await ow.ask(text(cmd[1]))
			await run(cmd[2] if yes else cmd[3])
		"choose":
			var i := await ow.choose(text(cmd[1]), cmd[2])
			var branches: Array = cmd[3]
			if i >= 0 and i < branches.size():
				await run(branches[i])
		"pay":
			if Economy.pay(int(cmd[1]), cmd[2]):
				await ow.toast("PAGAMENTO", "-" + Economy.fmt(int(cmd[1])))
				await run(cmd[3])
			else:
				await run(cmd[4])
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
		"trainer":
			var result: String = await ow.trainer_battle(cmd[1])
			if result == "win":
				await run(cmd[2] if cmd.size() > 2 else [])
			elif cmd.size() > 3:
				await run(cmd[3])
		"shop":
			await ow.open_shop()
		"revival":
			await ow.hospital_desk()
		"mutation":
			await ow.mutation_lab()
		"if":
			await run(cmd[2] if check(cmd[1]) else (cmd[3] if cmd.size() > 3 else []))


## Mostra os avisos das missões (objetivo cumprido...) quando a cena fica livre.
func update_goals() -> void:
	Quests.refresh()
	while not Quests.pending_say.is_empty():
		var s: String = Quests.pending_say.pop_front()
		await ow.msg.say(s)
		ow.msg.hide()
