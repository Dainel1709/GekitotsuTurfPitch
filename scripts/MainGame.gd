extends Control

onready var player_header_label = $MarginContainer/VBoxContainer/HeaderCard/HeaderMargin/HeaderVBox/HeaderTopRow/PlayerHeaderLabel
onready var config_button = $MarginContainer/VBoxContainer/HeaderCard/HeaderMargin/HeaderVBox/HeaderTopRow/ConfigButton
onready var stats_label = $MarginContainer/VBoxContainer/HeaderCard/HeaderMargin/HeaderVBox/StatsLabel
onready var league_label = $MarginContainer/VBoxContainer/HeaderCard/HeaderMargin/HeaderVBox/LeagueLabel
onready var balance_label = $MarginContainer/VBoxContainer/HeaderCard/HeaderMargin/HeaderVBox/BalanceLabel
onready var description_label = $MarginContainer/VBoxContainer/StoryCard/StoryMargin/DescriptionLabel

onready var player_name_input = $MarginContainer/VBoxContainer/ActionVBox/PlayerNameInput
onready var left_button = $MarginContainer/VBoxContainer/ActionVBox/LeftButton
onready var right_button = $MarginContainer/VBoxContainer/ActionVBox/RightButton
onready var third_academy_button = $MarginContainer/VBoxContainer/ActionVBox/ThirdAcademyButton

onready var bottom_bar = $MarginContainer/VBoxContainer/BottomBar
onready var match_button = $MarginContainer/VBoxContainer/BottomBar/MatchButton
onready var fight_button = $MarginContainer/VBoxContainer/BottomBar/FightButton
onready var admin_button = $MarginContainer/VBoxContainer/BottomBar/AdminButton
onready var reset_button = $MarginContainer/VBoxContainer/BottomBar/ResetButton

var story_manager = null
var admin_panel = null

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

const ACADEMIES = [
	"Estudiantes de Mérida",
	"FC Barcelona Juvenil",
	"Real Madrid Castilla"
]

func _ready() -> void:
	if left_button:
		left_button.connect("pressed", self, "_on_left_choice_pressed")
	if right_button:
		right_button.connect("pressed", self, "_on_right_choice_pressed")
	if third_academy_button:
		third_academy_button.connect("pressed", self, "_on_third_academy_pressed")
	if match_button:
		match_button.connect("pressed", self, "_on_match_pressed")
	if fight_button:
		fight_button.connect("pressed", self, "_on_fight_pressed")
	if admin_button:
		admin_button.visible = false
		admin_button.connect("pressed", self, "_on_admin_pressed")
	if reset_button:
		reset_button.connect("pressed", self, "_on_reset_pressed")
	if config_button:
		config_button.connect("pressed", self, "_on_config_pressed")
		config_button.text = "⚙ Config"

	_sync_from_save_file()
	_setup_story_manager()
	_setup_admin_panel()
	update_ui()

func _input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_ESCAPE:
			var so = get_node_or_null("/root/SettingsOverlay")
			if so and not so.is_open():
				_on_config_pressed()

func _setup_admin_panel() -> void:
	var admin_script = load("res://scripts/AdminStoryTree.gd")
	if admin_script:
		admin_panel = Control.new()
		admin_panel.set_script(admin_script)
		admin_panel.name = "AdminStoryPanel"
		admin_panel.visible = false
		add_child(admin_panel)

func _toggle_admin_panel() -> void:
	if admin_panel:
		admin_panel.visible = not admin_panel.visible
		if admin_panel.visible and admin_panel.has_method("refresh_tree"):
			admin_panel.refresh_tree()

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
	var gs = get_node_or_null("/root/GameSettings")
	var meta_stats = _get_persistent_stats()
	var matchday = int(meta_stats.get("matchday", 1))
	var wins = int(meta_stats.get("league_wins", 0))
	var losses = int(meta_stats.get("league_losses", 0))
	var draws = max(0, (matchday - 1) - wins - losses)
	var points = wins * 3 + draws
	var table_pos = 1 if points >= 18 else (2 if points >= 12 else 3)

	var current_phase = gs.story_phase if gs else "LEAGUE"
	var current_ending = gs.ending_id if gs else ""
	var pname = gs.player_name if gs else "Ryu"
	var academy = gs.academy_name if gs else "Estudiantes de Mérida"
	var goals = gs.goals_scored if gs else 0
	var assists = gs.assists if gs else 0
	var ga_total = goals + assists
	var red_cards = gs.red_cards_total if gs else 0

	var d_val = int(meta_stats.get("discipline", 0))
	var c_val = int(meta_stats.get("combat", 0))
	var r_val = int(meta_stats.get("reputation", 0))
	var m_val = int(meta_stats.get("money", 0))

	# Rebalancear árbol narrativo DeSiGNAR
	var branch_name = "Rama Doble Vida"
	var delta_val = 0
	var f_score = 0
	var s_score = 0
	var dyn_title = ""
	var dyn_prompt = ""

	if story_manager and story_manager.has_method("rebalance_story_tree"):
		story_manager.rebalance_story_tree(c_val, d_val, r_val, goals, assists, red_cards, matchday)
		branch_name = story_manager.get_active_branch_name()
		delta_val = int(story_manager.get_balance_delta())
		f_score = int(story_manager.get_football_score()) if story_manager.has_method("get_football_score") else 0
		s_score = int(story_manager.get_street_score()) if story_manager.has_method("get_street_score") else 0
		dyn_title = story_manager.get_dynamic_event_title() if story_manager.has_method("get_dynamic_event_title") else ""
		dyn_prompt = story_manager.get_dynamic_event_prompt() if story_manager.has_method("get_dynamic_event_prompt") else ""

	if gs and gs.has_method("rebalance_story_tree"):
		gs.rebalance_story_tree(c_val, d_val, r_val, goals, assists, red_cards, matchday)
		if not (story_manager and story_manager.has_method("rebalance_story_tree")):
			branch_name = gs.get_active_branch_name()
			delta_val = int(gs.get_balance_delta())
			f_score = int(gs.football_score)
			s_score = int(gs.street_score)
			dyn_title = gs.dynamic_event_title
			dyn_prompt = gs.dynamic_event_prompt

	# Actualizar Cabecera Superior
	if player_header_label:
		var club_text = "Sin club aún" if current_phase in ["CREATE_PLAYER", "PROLOGUE_HIT", "SELECT_ACADEMY"] else academy
		player_header_label.text = "Canterano: %s | Club: %s" % [pname, club_text]

	if stats_label:
		stats_label.text = "Disciplina: %d | Combate: %d | Reputación: %d | Dinero: $%d" % [d_val, c_val, r_val, m_val]

	if league_label:
		league_label.text = "Jornada %d/8 | Tabla: %d.º (%d pts) | Goles: %d | Asist.: %d | G+A: %d (Meta Golden Boy: > 11)" % [
			min(8, matchday), table_pos, points, goals, assists, ga_total
		]

	if balance_label:
		balance_label.visible = true
		balance_label.text = "Tendencia del Árbol: %s (Delta: %+d | F: %d vs C: %d)" % [branch_name, delta_val, f_score, s_score]
		if delta_val >= 10:
			balance_label.modulate = Color(0.25, 0.95, 0.45)
		elif delta_val <= -10:
			balance_label.modulate = Color(1.0, 0.4, 0.25)
		else:
			balance_label.modulate = Color(1.0, 0.85, 0.2)

	# Despacho por fase narrativa
	if current_phase == "ENDING" and current_ending != "":
		_show_ending_screen(gs, meta_stats)
		return
	if current_phase == "CREATE_PLAYER":
		_show_create_player_screen(gs)
		return
	if current_phase == "PROLOGUE_HIT":
		_show_prologue_hit_screen(gs)
		return
	if current_phase == "SELECT_ACADEMY":
		_show_select_academy_screen(gs)
		return
	if current_phase == "MID_J4_OFFER":
		_show_j4_offer_screen(gs, meta_stats)
		return
	if current_phase == "AMBUSH_J6_BRAWL":
		_show_ambush_j6_screen(gs, meta_stats)
		return
	if current_phase == "POST_J8_CHOICE":
		_show_post_j8_screen(gs, meta_stats)
		return
	if current_phase == "FINAL_BRAWL":
		_show_final_brawl_screen(gs, meta_stats)
		return

	# --- MODO NORMAL: LEAGUE ---
	var rival_name = get_current_rival_name(matchday)
	if league_label:
		league_label.text = "Jornada %d/8 vs %s | Tabla: %d.º (%d pts) | Goles: %d | Asist.: %d | G+A: %d (Meta Golden Boy: > 11)" % [
			min(8, matchday), rival_name, table_pos, points, goals, assists, ga_total
		]

	if player_name_input:
		player_name_input.visible = false
	if third_academy_button:
		third_academy_button.visible = false

	if story_manager:
		var title = story_manager.get_current_title() if story_manager.has_method("get_current_title") else ""
		var prompt = story_manager.get_current_prompt() if story_manager.has_method("get_current_prompt") else ""
		var is_over = story_manager.is_career_over() if story_manager.has_method("is_career_over") else false

		if description_label:
			description_label.text = "[%s]\n%s\n\n[%s] %s" % [title, prompt, dyn_title, dyn_prompt]

		if is_over:
			if left_button:
				left_button.visible = false
			if right_button:
				right_button.visible = false
			var ending = story_manager.get_ending_summary() if story_manager.has_method("get_ending_summary") else ""
			if description_label:
				description_label.text += "\n\n*** ¡FIN DEL CAMINO! ***\n" + ending
		else:
			if left_button:
				left_button.visible = true
				var left_text = story_manager.get_discipline_option_text() if story_manager.has_method("get_discipline_option_text") else ""
				left_button.text = left_text if left_text != "" else "Entrenar en el Club (+Disciplina)"
			if right_button:
				right_button.visible = true
				var right_text = story_manager.get_street_option_text() if story_manager.has_method("get_street_option_text") else ""
				right_button.text = right_text if right_text != "" else "Pelea en el Callejón (+Reputación, +Dinero)"
	else:
		if description_label:
			description_label.text = "[%s — %s]\n%s\n\n[La Encrucijada de la Cantera] ¿Dedicas el día a entrenar con disciplina o buscas dinero rápido en el callejón?" % [dyn_title, branch_name, dyn_prompt]
		if left_button:
			left_button.visible = true
			left_button.text = "Quedarse a entrenar (+15 Disciplina, -$5)"
		if right_button:
			right_button.visible = true
			right_button.text = "Aceptar pelea clandestina (+20 Reputación, +$500, +5 Combate)"

	_show_bottom_bar(true, matchday <= 8, true, false, true, true)
	_setup_focus()

# --- Pantallas del Flujo Narrativo ---

func _show_create_player_screen(gs) -> void:
	if description_label:
		description_label.text = "[NUEVA CARRERA — CREACIÓN DEL CANTERANO]\n\nAntes de que el balón cambie tu vida, escribe el nombre de tu personaje. Tu historia se dividirá durante 8 jornadas entre la disciplina del fútbol y la ley del callejón."
	if player_name_input:
		player_name_input.visible = true
		if gs and gs.player_name != "":
			player_name_input.text = gs.player_name
	if left_button:
		left_button.visible = true
		left_button.text = "Confirmar Nombre y Comenzar Prólogo"
	if right_button:
		right_button.visible = false
	if third_academy_button:
		third_academy_button.visible = false
	_show_bottom_bar(true, false, false, false, true, false)
	_setup_focus()

func _show_prologue_hit_screen(gs) -> void:
	var pname = gs.player_name if gs else "Ryu"
	if description_label:
		description_label.text = "[PRÓLOGO — EL BALONAZO FORTUITO]\n\nMientras %s camina por el callejón, un balón perdido sale disparado de una cancha cercana. Sin pensarlo, lo controlas con el pecho y lo devuelves de volea directo al ángulo.\n\nUn ojeador juvenil queda impresionado y te invita a probarte en una cantera profesional." % pname
	if player_name_input:
		player_name_input.visible = false
	if left_button:
		left_button.visible = true
		left_button.text = "Aceptar la invitación e ir a las pruebas"
	if right_button:
		right_button.visible = false
	if third_academy_button:
		third_academy_button.visible = false
	_show_bottom_bar(true, false, false, false, true, false)
	_setup_focus()

func _show_select_academy_screen(gs) -> void:
	var pname = gs.player_name if gs else "Ryu"
	if description_label:
		description_label.text = "[ELECCIÓN DE CANTERA]\n\nTres clubes han visto potencial en %s. Elige la academia donde disputarás las 8 jornadas de liga:" % pname
	if player_name_input:
		player_name_input.visible = false
	if left_button:
		left_button.visible = true
		left_button.text = "1. %s" % ACADEMIES[0]
	if right_button:
		right_button.visible = true
		right_button.text = "2. %s" % ACADEMIES[1]
	if third_academy_button:
		third_academy_button.visible = true
		third_academy_button.text = "3. %s" % ACADEMIES[2]
	_show_bottom_bar(true, false, false, false, true, false)
	_setup_focus()

func _show_ending_screen(gs, meta_stats: Dictionary) -> void:
	var end_id = gs.ending_id if gs else ""
	var end_title = gs.get_ending_title(end_id) if gs and gs.has_method("get_ending_title") else "Final"
	var end_desc = gs.get_ending_description(end_id) if gs and gs.has_method("get_ending_description") else ""

	if league_label:
		league_label.text = "*** FIN DE LA HISTORIA (%s) ***" % end_id
	if description_label:
		description_label.text = "[%s]\n\n%s\n\n*** ¡FIN DEL CAMINO! ***" % [end_title, end_desc]

	if player_name_input:
		player_name_input.visible = false
	if left_button:
		left_button.visible = false
	if right_button:
		right_button.visible = false
	if third_academy_button:
		third_academy_button.visible = false

	_show_bottom_bar(true, false, false, false, true, true)
	_setup_focus()

func _show_j4_offer_screen(gs, _meta_stats: Dictionary) -> void:
	var pname = gs.player_name if gs else "Ryu"
	if description_label:
		description_label.text = "[EL PROMOTOR DE LAS SOMBRAS — JORNADA 4]\n\nTras el 4.º partido, un promotor clandestino intercepta a %s:\n\"Tienes dinamita en los puños. Deja el fútbol y firma como peleador profesional.\"" % pname
	if player_name_input:
		player_name_input.visible = false
	if left_button:
		left_button.visible = true
		left_button.text = "Rechazar y seguir en la cantera"
	if right_button:
		right_button.visible = true
		right_button.text = "Aceptar contrato de peleador (Dejar fútbol)"
	if third_academy_button:
		third_academy_button.visible = false
	_show_bottom_bar(true, false, false, false, true, false)
	_setup_focus()

func _show_ambush_j6_screen(gs, _meta_stats: Dictionary) -> void:
	var pname = gs.player_name if gs else "Ryu"
	if description_label:
		description_label.text = "[EMBOSCADA NOCTURNA — JORNADA 6]\n\nDe camino a casa tras el 6.º partido, %s es rodeado por pandilleros rivales. Tu baja disciplina te deja sin respaldo del club." % pname
	if player_name_input:
		player_name_input.visible = false
	if left_button:
		left_button.visible = true
		left_button.text = "¡Enfrentar la Emboscada Nocturna!"
	if right_button:
		right_button.visible = false
	if third_academy_button:
		third_academy_button.visible = false
	_show_bottom_bar(true, false, false, false, true, false)
	_setup_focus()

func _show_post_j8_screen(gs, meta_stats: Dictionary) -> void:
	var combat = int(meta_stats.get("combat", 0))
	var pname = gs.player_name if gs else "Ryu"
	if description_label:
		if combat >= 25:
			description_label.text = "[EL CRUCE DE CAMINOS FINAL — JORNADA 8]\n\n%s completa las 8 jornadas. A la salida del estadio te retan a una última pelea (Combate: %d). Si ganas podrás vivir del ring profesional, o puedes ignorarlos y esperar el veredicto de la liga." % [pname, combat]
		else:
			description_label.text = "[EL CRUCE DE CAMINOS FINAL — JORNADA 8]\n\n%s completa las 8 jornadas. Un grupo te reta a la salida del vestuario. ¿Aceptas la pelea o esperas el cierre de la liga?" % pname
	if player_name_input:
		player_name_input.visible = false
	if left_button:
		left_button.visible = true
		left_button.text = "Ignorar la pelea (Esperar resultados de liga)"
	if right_button:
		right_button.visible = true
		right_button.text = "Aceptar la pelea final"
	if third_academy_button:
		third_academy_button.visible = false
	_show_bottom_bar(true, false, false, false, true, false)
	_setup_focus()

func _show_final_brawl_screen(_gs, _meta_stats: Dictionary) -> void:
	if description_label:
		description_label.text = "[LA PELEA DEFINITIVA — JORNADA 8]\n\n¡Tu destino está en juego! Si caes derrotado aquí, las consecuencias serán irreversibles."
	if player_name_input:
		player_name_input.visible = false
	if left_button:
		left_button.visible = true
		left_button.text = "¡PELEAR! (Pelea Final)"
	if right_button:
		right_button.visible = false
	if third_academy_button:
		third_academy_button.visible = false
	_show_bottom_bar(true, false, false, false, true, false)
	_setup_focus()

func _show_bottom_bar(show_bar: bool, show_match: bool, show_fight: bool, _show_ctrl: bool, show_admin: bool, show_reset: bool) -> void:
	if bottom_bar:
		bottom_bar.visible = show_bar
	if match_button:
		match_button.visible = show_match
		match_button.text = "Partido de Liga"
	if fight_button:
		fight_button.visible = show_fight
		fight_button.text = "Pelea Callejera"
	if admin_button:
		admin_button.visible = false
	if reset_button:
		reset_button.visible = show_reset
		reset_button.text = "Nueva Carrera"
	if config_button:
		config_button.text = "⚙ Config"

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

# --- Handlers de Botones ---

func _on_left_choice_pressed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	var current_phase = gs.story_phase if gs else "LEAGUE"

	if current_phase == "CREATE_PLAYER":
		if gs:
			var entered = player_name_input.text.strip_edges() if player_name_input else ""
			gs.player_name = entered if entered != "" else "Ryu"
			gs.story_phase = "PROLOGUE_HIT"
			gs.save_progress({})
		update_ui()
		return

	if current_phase == "PROLOGUE_HIT":
		if gs:
			gs.story_phase = "SELECT_ACADEMY"
			gs.save_progress({})
		update_ui()
		return

	if current_phase == "SELECT_ACADEMY":
		_select_academy(ACADEMIES[0])
		return

	if current_phase == "MID_J4_OFFER":
		gs.story_phase = "LEAGUE"
		gs.save_progress({})
		update_ui()
		return

	if current_phase == "AMBUSH_J6_BRAWL" or current_phase == "FINAL_BRAWL":
		_on_fight_pressed()
		return

	if current_phase == "POST_J8_CHOICE":
		var league_ending = gs.evaluate_j8_ending()
		gs.set_story_ending("ENDING", league_ending)
		update_ui()
		return

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
	var gs = get_node_or_null("/root/GameSettings")
	var current_phase = gs.story_phase if gs else "LEAGUE"

	if current_phase == "SELECT_ACADEMY":
		_select_academy(ACADEMIES[1])
		return

	if current_phase == "MID_J4_OFFER":
		gs.set_story_ending("ENDING", "PRO_FIGHTER_EARLY")
		update_ui()
		return

	if current_phase == "POST_J8_CHOICE":
		gs.story_phase = "FINAL_BRAWL"
		gs.save_progress({})
		update_ui()
		return

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

func _on_third_academy_pressed() -> void:
	_select_academy(ACADEMIES[2])

func _select_academy(club_name: String) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.academy_name = club_name
		gs.story_phase = "LEAGUE"
		gs.save_progress({})
	update_ui()

func _on_match_pressed() -> void:
	get_tree().change_scene("res://scenes/FootballPitch.tscn")

func _on_fight_pressed() -> void:
	get_tree().change_scene("res://scenes/FightArena.tscn")

func _on_admin_pressed() -> void:
	_toggle_admin_panel()

func _on_config_pressed() -> void:
	var so = get_node_or_null("/root/SettingsOverlay")
	if so and so.has_method("open_menu"):
		so.open_menu()

func _on_reset_pressed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		if gs.has_method("reset_save"):
			gs.reset_save()
		gs.story_phase = "CREATE_PLAYER"
		gs.ending_id = ""
		gs.save_progress({})
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

func _setup_focus() -> void:
	var active_buttons = []
	for btn in [left_button, right_button, third_academy_button, match_button, fight_button, admin_button, reset_button, config_button]:
		if btn and btn.visible:
			active_buttons.append(btn)

	var count = active_buttons.size()
	for i in range(count):
		var btn = active_buttons[i]
		btn.focus_neighbour_top = active_buttons[(i - 1 + count) % count].get_path()
		btn.focus_neighbour_bottom = active_buttons[(i + 1) % count].get_path()

	if count > 0:
		var has_any_focus = false
		for btn in active_buttons:
			if btn.has_focus():
				has_any_focus = true
				break
		if not has_any_focus:
			active_buttons[0].grab_focus()
