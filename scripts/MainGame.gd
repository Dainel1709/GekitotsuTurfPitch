extends Control

onready var stats_label = $VBoxContainer/StatsLabel if has_node("VBoxContainer/StatsLabel") else null
onready var league_label = $VBoxContainer/LeagueLabel if has_node("VBoxContainer/LeagueLabel") else null
onready var description_label = $VBoxContainer/DescriptionLabel if has_node("VBoxContainer/DescriptionLabel") else null
onready var left_button = $VBoxContainer/LeftButton if has_node("VBoxContainer/LeftButton") else null
onready var right_button = $VBoxContainer/RightButton if has_node("VBoxContainer/RightButton") else null
onready var match_button = $VBoxContainer/MatchButton if has_node("VBoxContainer/MatchButton") else null
onready var fight_button = $VBoxContainer/FightButton if has_node("VBoxContainer/FightButton") else null
onready var controls_button = $VBoxContainer/ControlsButton if has_node("VBoxContainer/ControlsButton") else null
onready var reset_button = $VBoxContainer/ResetButton if has_node("VBoxContainer/ResetButton") else null

var story_manager = null

const LEAGUE_RIVALS = [
	"Barrio Norte FC",
	"Deportivo Callejón",
	"Atlético San Cristóbal",
	"Real Chama",
	"Furia del Asfalto FC",
	"Titanes de Mérida",
	"Guerreros del Césped",
	"Club Deportivo Los Andes"
]

func _ready() -> void:
	if left_button:
		left_button.connect("pressed", self, "_on_left_choice_pressed")
	if right_button:
		right_button.connect("pressed", self, "_on_right_choice_pressed")
	if match_button:
		match_button.connect("pressed", self, "_on_match_pressed")
	if fight_button:
		fight_button.connect("pressed", self, "_on_fight_pressed")
	if controls_button:
		controls_button.connect("pressed", self, "_on_controls_pressed")
	if reset_button:
		reset_button.connect("pressed", self, "_on_reset_pressed")

	# Sincronizar automáticamente con guardado persistente local
	_sync_from_save_file()

	# Enlace dinámico con la clase C++ GekitotsuStoryManager
	_setup_story_manager()

	update_ui()

func _setup_story_manager() -> void:
	if ClassDB.class_exists("GekitotsuStoryManager"):
		if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("GekitotsuStoryManager"):
			story_manager = ClassDB.instantiate("GekitotsuStoryManager")
		elif ClassDB.has_method("can_instance") and ClassDB.can_instance("GekitotsuStoryManager"):
			story_manager = ClassDB.instance("GekitotsuStoryManager")
		if story_manager:
			add_child(story_manager)

func _sync_from_save_file() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	var save_data = gs.load_progress() if (gs and gs.has_method("load_progress")) else {}
	var cur_stats = _get_persistent_stats()
	for k in ["discipline", "combat", "money", "reputation", "matchday", "league_wins", "league_losses"]:
		if save_data.has(k):
			cur_stats[k] = save_data[k]
	get_tree().root.set_meta("gtp_stats", cur_stats)

func get_current_rival_name(matchday: int) -> String:
	var idx = int(max(0, matchday - 1)) % LEAGUE_RIVALS.size()
	return LEAGUE_RIVALS[idx]

func update_ui() -> void:
	var meta_stats = _get_persistent_stats()
	var matchday: int = meta_stats.get("matchday", 1)
	var wins: int = meta_stats.get("league_wins", 0)
	var losses: int = meta_stats.get("league_losses", 0)
	var rival_name: String = get_current_rival_name(matchday)

	# Actualizar banner de jornada de liga
	if league_label:
		league_label.text = "Jornada %d — Rival: %s (Liga: %d V / %d D)" % [matchday, rival_name, wins, losses]

	if story_manager:
		var title: String = story_manager.get_current_title() if story_manager.has_method("get_current_title") else ""
		var prompt: String = story_manager.get_current_prompt() if story_manager.has_method("get_current_prompt") else ""
		var discipline: int = story_manager.get_discipline_points() if story_manager.has_method("get_discipline_points") else meta_stats.get("discipline", 0)
		var combat: int = story_manager.get_combat_technique() if story_manager.has_method("get_combat_technique") else meta_stats.get("combat", 0)
		var money: int = story_manager.get_money() if story_manager.has_method("get_money") else meta_stats.get("money", 0)
		var reputation: int = story_manager.get_street_reputation() if story_manager.has_method("get_street_reputation") else meta_stats.get("reputation", 0)
		var is_over: bool = story_manager.is_career_over() if story_manager.has_method("is_career_over") else false

		if description_label:
			description_label.text = "[%s]\n\n%s" % [title, prompt]
		if stats_label:
			stats_label.text = "Disciplina Deportiva: %d | Combate: %d | Dinero: $%d | Reputación en Asfalto: %d" % [discipline, combat, money, reputation]

		if is_over:
			if left_button:
				left_button.visible = false
			if right_button:
				right_button.visible = false
			var ending: String = story_manager.get_ending_summary() if story_manager.has_method("get_ending_summary") else ""
			if description_label:
				description_label.text += "\n\n*** ¡FIN DEL CAMINO / DESENLACE A LOS 18 AÑOS ALCANZADO! ***\n" + ending
		else:
			if left_button:
				left_button.visible = true
			if right_button:
				right_button.visible = true
			var left_text: String = story_manager.get_discipline_option_text() if story_manager.has_method("get_discipline_option_text") else ""
			var right_text: String = story_manager.get_street_option_text() if story_manager.has_method("get_street_option_text") else ""
			if left_button:
				left_button.text = left_text if left_text != "" else "Elegir Club / Disciplina (+Disciplina Deportiva)"
			if right_button:
				right_button.text = right_text if right_text != "" else "Elegir Calle / Asfalto (+Reputación Callejera)"
	else:
		var d = meta_stats.get("discipline", 0)
		var c = meta_stats.get("combat", 0)
		var m = meta_stats.get("money", 0)
		var r = meta_stats.get("reputation", 0)

		if description_label:
			description_label.text = "[La Encrucijada de la Cantera]\n\nHas sido admitido en las pruebas del club juvenil, pero esta noche hay una pelea clandestina en el callejón que paga el alquiler familiar. ¿Qué camino eliges?"
		if left_button:
			left_button.text = "Quedarse a entrenar (+15 Disciplina, -5 Dinero)"
		if right_button:
			right_button.text = "Aceptar la pelea clandestina (+20 Reputación, +$500 Dinero, +5 Combate)"
		if stats_label:
			stats_label.text = "Disciplina Deportiva: %d | Combate: %d | Dinero: $%d | Reputación en Asfalto: %d" % [d, c, m, r]

	_update_controls_button_text()
	_setup_focus()

func _get_persistent_stats() -> Dictionary:
	if not get_tree().root.has_meta("gtp_stats"):
		get_tree().root.set_meta("gtp_stats", {
			"discipline": 0,
			"combat": 0,
			"money": 0,
			"reputation": 0,
			"matchday": 1,
			"league_wins": 0,
			"league_losses": 0,
			"day": 1
		})
	return get_tree().root.get_meta("gtp_stats")

func _save_current_state() -> void:
	var s = _get_persistent_stats()
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("save_progress"):
		gs.save_progress(s)

func _on_left_choice_pressed() -> void:
	if story_manager and story_manager.has_method("choose_discipline"):
		story_manager.choose_discipline()
	else:
		var s = _get_persistent_stats()
		s["discipline"] += 15
		s["money"] -= 5
		s["day"] += 1
		get_tree().root.set_meta("gtp_stats", s)
	_save_current_state()
	update_ui()

func _on_right_choice_pressed() -> void:
	if story_manager and story_manager.has_method("choose_street"):
		story_manager.choose_street()
	else:
		var s = _get_persistent_stats()
		s["reputation"] += 20
		s["money"] += 500
		s["combat"] += 5
		s["day"] += 1
		get_tree().root.set_meta("gtp_stats", s)
	_save_current_state()
	update_ui()

func _on_match_pressed() -> void:
	get_tree().change_scene("res://scenes/FootballPitch.tscn")

func _on_fight_pressed() -> void:
	get_tree().change_scene("res://scenes/FightArena.tscn")

func _on_controls_pressed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("toggle_control_scheme"):
		gs.toggle_control_scheme()
		_save_current_state()
	_update_controls_button_text()

func _on_reset_pressed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("reset_save"):
		gs.reset_save()
	get_tree().root.set_meta("gtp_stats", {
		"discipline": 0,
		"combat": 0,
		"money": 0,
		"reputation": 0,
		"matchday": 1,
		"league_wins": 0,
		"league_losses": 0,
		"day": 1
	})
	if story_manager:
		story_manager.queue_free()
		story_manager = null
		_setup_story_manager()
	update_ui()
	print("[MainGame] Temporada reiniciada a Jornada 1.")

func _update_controls_button_text() -> void:
	if controls_button:
		var scheme_str: String = "Clásico (FIFA)"
		var gs = get_node_or_null("/root/GameSettings")
		if gs and gs.has_method("get_scheme_short_name"):
			scheme_str = gs.get_scheme_short_name()
		controls_button.text = "Controles Fútbol: " + scheme_str

func _setup_focus() -> void:
	var active_buttons: Array = []
	if left_button and left_button.visible:
		active_buttons.append(left_button)
	if right_button and right_button.visible:
		active_buttons.append(right_button)
	if match_button and match_button.visible:
		active_buttons.append(match_button)
	if fight_button and fight_button.visible:
		active_buttons.append(fight_button)
	if controls_button and controls_button.visible:
		active_buttons.append(controls_button)
	if reset_button and reset_button.visible:
		active_buttons.append(reset_button)

	var count = active_buttons.size()
	for i in range(count):
		var btn: Button = active_buttons[i]
		var prev_btn: Button = active_buttons[(i - 1 + count) % count]
		var next_btn: Button = active_buttons[(i + 1) % count]
		btn.focus_neighbour_top = prev_btn.get_path()
		btn.focus_neighbour_bottom = next_btn.get_path()

	# Asegurar foco inicial en el primer botón activo para control por gamepad
	if active_buttons.size() > 0:
		var has_any_focus = false
		for btn in active_buttons:
			if btn.has_focus():
				has_any_focus = true
				break
		if not has_any_focus:
			active_buttons[0].grab_focus()
