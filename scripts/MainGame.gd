extends Control

onready var stats_label = $VBoxContainer/StatsLabel if has_node("VBoxContainer/StatsLabel") else null
onready var league_label = $VBoxContainer/LeagueLabel if has_node("VBoxContainer/LeagueLabel") else null
onready var balance_label = $VBoxContainer/BalanceLabel if has_node("VBoxContainer/BalanceLabel") else null
onready var description_label = $VBoxContainer/DescriptionLabel if has_node("VBoxContainer/DescriptionLabel") else null
onready var left_button = $VBoxContainer/LeftButton if has_node("VBoxContainer/LeftButton") else null
onready var right_button = $VBoxContainer/RightButton if has_node("VBoxContainer/RightButton") else null
onready var match_button = $VBoxContainer/MatchButton if has_node("VBoxContainer/MatchButton") else null
onready var fight_button = $VBoxContainer/FightButton if has_node("VBoxContainer/FightButton") else null
onready var controls_button = $VBoxContainer/ControlsButton if has_node("VBoxContainer/ControlsButton") else null
onready var reset_button = $VBoxContainer/ResetButton if has_node("VBoxContainer/ResetButton") else null

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

	# Crear Panel Admin (F12)
	_setup_admin_panel()

	update_ui()

func _input(event) -> void:
	if event is InputEventKey and event.pressed and event.scancode == KEY_F12:
		_toggle_admin_panel()

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
	var rival_name = get_current_rival_name(matchday)

	# Comprobar si estamos en un estado narrativo especial
	var current_phase = gs.story_phase if gs else "LEAGUE"
	var current_ending = gs.ending_id if gs else ""

	# --- FASE: ENDING (cualquier final alcanzado) ---
	if current_phase == "ENDING" and current_ending != "":
		_show_ending_screen(gs, meta_stats)
		return

	# --- FASE: MID_J4_OFFER (oferta del promotor de peleas) ---
	if current_phase == "MID_J4_OFFER":
		_show_j4_offer_screen(gs, meta_stats)
		return

	# --- FASE: AMBUSH_J6_BRAWL (emboscada nocturna J6) ---
	if current_phase == "AMBUSH_J6_BRAWL":
		_show_ambush_j6_screen(gs, meta_stats)
		return

	# --- FASE: POST_J8_CHOICE (elección post-temporada) ---
	if current_phase == "POST_J8_CHOICE":
		_show_post_j8_screen(gs, meta_stats)
		return

	# --- FASE: FINAL_BRAWL (pelea final J8) ---
	if current_phase == "FINAL_BRAWL":
		_show_final_brawl_screen(gs, meta_stats)
		return

	# --- MODO NORMAL: Liga y Hub ---
	# Rebalancear árbol narrativo DeSiGNAR según estadísticas actuales
	var d_val = int(meta_stats.get("discipline", 0))
	var c_val = int(meta_stats.get("combat", 0))
	var r_val = int(meta_stats.get("reputation", 0))
	var g_val = gs.goals_scored if gs else 0
	var a_val = gs.assists if gs else 0
	var rc_val = gs.red_cards_total if gs else 0

	var branch_name = "Rama Doble Vida"
	var delta_val = 0
	var f_score = 0
	var s_score = 0
	var dyn_title = ""
	var dyn_prompt = ""

	if story_manager and story_manager.has_method("rebalance_story_tree"):
		story_manager.rebalance_story_tree(c_val, d_val, r_val, g_val, a_val, rc_val, matchday)
		branch_name = story_manager.get_active_branch_name()
		delta_val = int(story_manager.get_balance_delta())
		f_score = int(story_manager.get_football_score()) if story_manager.has_method("get_football_score") else 0
		s_score = int(story_manager.get_street_score()) if story_manager.has_method("get_street_score") else 0
		dyn_title = story_manager.get_dynamic_event_title() if story_manager.has_method("get_dynamic_event_title") else ""
		dyn_prompt = story_manager.get_dynamic_event_prompt() if story_manager.has_method("get_dynamic_event_prompt") else ""
	if gs and gs.has_method("rebalance_story_tree"):
		gs.rebalance_story_tree(c_val, d_val, r_val, g_val, a_val, rc_val, matchday)
		if not (story_manager and story_manager.has_method("rebalance_story_tree")):
			branch_name = gs.get_active_branch_name()
			delta_val = int(gs.get_balance_delta())
			f_score = int(gs.football_score)
			s_score = int(gs.street_score)
			dyn_title = gs.dynamic_event_title
			dyn_prompt = gs.dynamic_event_prompt

	if balance_label:
		balance_label.visible = true
		balance_label.text = "Tendencia del Árbol: %s (Delta: %+d | F:%d vs C:%d)" % [branch_name, delta_val, f_score, s_score]
		if delta_val >= 10:
			balance_label.modulate = Color(0.25, 0.95, 0.45)
		elif delta_val <= -10:
			balance_label.modulate = Color(1.0, 0.4, 0.25)
		else:
			balance_label.modulate = Color(1.0, 0.85, 0.2)

	# Actualizar banner de jornada de liga
	if league_label:
		league_label.text = "Jornada %d — Rival: %s (Liga: %d V / %d D)" % [matchday, rival_name, wins, losses]

	if story_manager:
		var title = story_manager.get_current_title() if story_manager.has_method("get_current_title") else ""
		var prompt = story_manager.get_current_prompt() if story_manager.has_method("get_current_prompt") else ""
		var discipline = story_manager.get_discipline_points() if story_manager.has_method("get_discipline_points") else meta_stats.get("discipline", 0)
		var combat = story_manager.get_combat_technique() if story_manager.has_method("get_combat_technique") else meta_stats.get("combat", 0)
		var money = story_manager.get_money() if story_manager.has_method("get_money") else meta_stats.get("money", 0)
		var reputation = story_manager.get_street_reputation() if story_manager.has_method("get_street_reputation") else meta_stats.get("reputation", 0)
		var is_over = story_manager.is_career_over() if story_manager.has_method("is_career_over") else false

		if description_label:
			description_label.text = "[%s]\n%s\n\n[%s] %s" % [title, prompt, dyn_title, dyn_prompt]
		if stats_label:
			stats_label.text = "Disciplina Deportiva: %d | Combate: %d | Dinero: $%d | Reputación en Asfalto: %d" % [discipline, combat, money, reputation]

		if is_over:
			if left_button:
				left_button.visible = false
			if right_button:
				right_button.visible = false
			var ending = story_manager.get_ending_summary() if story_manager.has_method("get_ending_summary") else ""
			if description_label:
				description_label.text += "\n\n*** ¡FIN DEL CAMINO / DESENLACE A LOS 18 AÑOS ALCANZADO! ***\n" + ending
		else:
			if left_button:
				left_button.visible = true
			if right_button:
				right_button.visible = true
			var left_text = story_manager.get_discipline_option_text() if story_manager.has_method("get_discipline_option_text") else ""
			var right_text = story_manager.get_street_option_text() if story_manager.has_method("get_street_option_text") else ""
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
			description_label.text = "[%s — %s]\n%s\n\n[La Encrucijada de la Cantera] ¿Entrenamiento profesional o pelea en el callejón?" % [dyn_title, branch_name, dyn_prompt]
		if left_button:
			left_button.text = "Quedarse a entrenar (+15 Disciplina, -5 Dinero)"
		if right_button:
			right_button.text = "Aceptar la pelea clandestina (+20 Reputación, +$500 Dinero, +5 Combate)"
		if stats_label:
			stats_label.text = "Disciplina Deportiva: %d | Combate: %d | Dinero: $%d | Reputación en Asfalto: %d" % [d, c, m, r]

	# Mostrar/ocultar botones según la fase
	_update_buttons_for_phase(current_phase, matchday)
	_update_controls_button_text()
	_setup_focus()

# --- Pantallas Narrativas Especiales ---

func _show_ending_screen(gs, meta_stats: Dictionary) -> void:
	var end_id = gs.ending_id if gs else ""
	var end_title = gs.get_ending_title(end_id) if gs and gs.has_method("get_ending_title") else "Final"
	var end_desc = gs.get_ending_description(end_id) if gs and gs.has_method("get_ending_description") else ""

	if league_label:
		league_label.text = "*** FIN DE LA HISTORIA ***"
	if description_label:
		description_label.text = "[%s]\n\n%s\n\n*** ¡FIN DEL CAMINO! ***" % [end_title, end_desc]
	if stats_label:
		var d = meta_stats.get("discipline", 0)
		var c = meta_stats.get("combat", 0)
		var m = meta_stats.get("money", 0)
		var r = meta_stats.get("reputation", 0)
		stats_label.text = "FINAL: %s | Disciplina: %d | Combate: %d | Dinero: $%d | Reputación: %d" % [end_id, d, c, m, r]

	# Ocultar todos los botones excepto Reiniciar
	if left_button:
		left_button.visible = false
	if right_button:
		right_button.visible = false
	if match_button:
		match_button.visible = false
	if fight_button:
		fight_button.visible = false
	if controls_button:
		controls_button.visible = false
	if reset_button:
		reset_button.visible = true
		reset_button.text = "Reiniciar Trayectoria (Nueva Temporada)"
	_setup_focus()

func _show_j4_offer_screen(gs, meta_stats: Dictionary) -> void:
	if league_label:
		league_label.text = "*** OFERTA ESPECIAL — JORNADA 4 ***"
	if description_label:
		var pname = gs.player_name if gs else "Ryu"
		description_label.text = "[El Promotor de las Sombras]\n\nTras el 4.º partido, un hombre misterioso se acerca a %s en el vestuario.\n\n\"He visto tus peleas, chico. Tienes talento real. Te ofrezco un contrato como peleador profesional. Olvida el fútbol, esto paga más y eres mejor con los puños.\"\n\n¿Qué decides?" % pname

	if left_button:
		left_button.visible = true
		left_button.text = "Rechazar y seguir en la cantera"
	if right_button:
		right_button.visible = true
		right_button.text = "Aceptar contrato de peleador (Dejar fútbol)"
	if match_button:
		match_button.visible = false
	if fight_button:
		fight_button.visible = false
	if controls_button:
		controls_button.visible = false

	_update_stats_label(meta_stats)
	_setup_focus()

func _show_ambush_j6_screen(gs, meta_stats: Dictionary) -> void:
	if league_label:
		league_label.text = "*** EMBOSCADA NOCTURNA — JORNADA 6 ***"
	if description_label:
		var pname = gs.player_name if gs else "Ryu"
		description_label.text = "[Emboscada en el Callejón]\n\nDe camino a casa tras el 6.º partido, %s es interceptado por pandilleros que buscan venganza. Con tu disciplina por los suelos, no puedes evitar el enfrentamiento.\n\n¡Prepárate para la pelea!" % pname

	if left_button:
		left_button.visible = false
	if right_button:
		right_button.visible = false
	if match_button:
		match_button.visible = false
	if fight_button:
		fight_button.visible = true
		fight_button.text = "¡Enfrentar la Emboscada Nocturna!"
	if controls_button:
		controls_button.visible = false

	_update_stats_label(meta_stats)
	_setup_focus()

func _show_post_j8_screen(gs, meta_stats: Dictionary) -> void:
	var combat = int(meta_stats.get("combat", 0))

	if league_label:
		league_label.text = "*** FIN DE TEMPORADA — JORNADA 8 COMPLETADA ***"
	if description_label:
		var pname = gs.player_name if gs else "Ryu"
		if combat >= 25:
			description_label.text = "[El Cruce de Caminos Final]\n\n%s ha completado las 8 jornadas de liga. En la puerta del vestuario, un grupo de pandilleros del barrio le reta a una última pelea.\n\nCon tu técnica de combate excepcional (%d), podrías dedicarte al ring profesional si ganas. ¿O prefieres ignorarlos y esperar el veredicto de la liga?" % [pname, combat]
		else:
			description_label.text = "[El Cruce de Caminos Final]\n\n%s ha completado las 8 jornadas de liga. Un grupo de pandilleros le reta en la salida. ¿Acepta la pelea o ignora la provocación y espera los resultados de la liga?" % pname

	if left_button:
		left_button.visible = true
		left_button.text = "Ignorar la pelea (Esperar resultados de liga)"
	if right_button:
		right_button.visible = true
		right_button.text = "Aceptar la pelea final"
	if match_button:
		match_button.visible = false
	if fight_button:
		fight_button.visible = false
	if controls_button:
		controls_button.visible = false

	_update_stats_label(meta_stats)
	_setup_focus()

func _show_final_brawl_screen(gs, meta_stats: Dictionary) -> void:
	if league_label:
		league_label.text = "*** PELEA FINAL — DESTINO EN JUEGO ***"
	if description_label:
		description_label.text = "[La Pelea Definitiva]\n\n¡Es hora de demostrar de qué estás hecho! Si pierdes, las consecuencias serán devastadoras..."

	if left_button:
		left_button.visible = false
	if right_button:
		right_button.visible = false
	if match_button:
		match_button.visible = false
	if fight_button:
		fight_button.visible = true
		fight_button.text = "¡PELEAR! (Pelea Final)"
	if controls_button:
		controls_button.visible = false

	_update_stats_label(meta_stats)
	_setup_focus()

func _update_stats_label(meta_stats: Dictionary) -> void:
	if stats_label:
		var d = meta_stats.get("discipline", 0)
		var c = meta_stats.get("combat", 0)
		var m = meta_stats.get("money", 0)
		var r = meta_stats.get("reputation", 0)
		stats_label.text = "Disciplina Deportiva: %d | Combate: %d | Dinero: $%d | Reputación en Asfalto: %d" % [d, c, m, r]

func _update_buttons_for_phase(phase: String, matchday: int) -> void:
	# En modo LEAGUE normal, mostrar todos los botones habituales
	if phase != "LEAGUE":
		return
	if match_button:
		match_button.visible = (matchday <= 8)
	if fight_button:
		fight_button.visible = true
	if controls_button:
		controls_button.visible = true
	if reset_button:
		reset_button.visible = true

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
	var gs = get_node_or_null("/root/GameSettings")
	var current_phase = gs.story_phase if gs else "LEAGUE"

	# Manejo especial para MID_J4_OFFER: Rechazar => volver a LEAGUE
	if current_phase == "MID_J4_OFFER":
		gs.story_phase = "LEAGUE"
		gs.save_progress({})
		print("[MainGame] Oferta del promotor RECHAZADA. Continúa la liga.")
		update_ui()
		return

	# Manejo especial para POST_J8_CHOICE: Ignorar pelea => evaluar final de liga
	if current_phase == "POST_J8_CHOICE":
		var league_ending = gs.evaluate_j8_ending()
		gs.set_story_ending("ENDING", league_ending)
		print("[MainGame] Pelea ignorada. Final de liga: %s" % league_ending)
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

	# Manejo especial para MID_J4_OFFER: Aceptar => PRO_FIGHTER_EARLY
	if current_phase == "MID_J4_OFFER":
		gs.set_story_ending("ENDING", "PRO_FIGHTER_EARLY")
		print("[MainGame] Oferta del promotor ACEPTADA. Final: PRO_FIGHTER_EARLY")
		update_ui()
		return

	# Manejo especial para POST_J8_CHOICE: Aceptar pelea => FINAL_BRAWL
	if current_phase == "POST_J8_CHOICE":
		gs.story_phase = "FINAL_BRAWL"
		gs.save_progress({})
		print("[MainGame] Pelea final aceptada. Fase: FINAL_BRAWL")
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

func _on_match_pressed() -> void:
	get_tree().change_scene("res://scenes/FootballPitch.tscn")

func _on_fight_pressed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	# Si es emboscada J6 o pelea final, marcar la fase correspondiente para FightArena
	if gs and gs.story_phase == "AMBUSH_J6_BRAWL":
		print("[MainGame] Iniciando emboscada nocturna J6...")
	elif gs and gs.story_phase == "FINAL_BRAWL":
		print("[MainGame] Iniciando pelea final J8...")
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
		var scheme_str = "Clásico (FIFA)"
		var gs = get_node_or_null("/root/GameSettings")
		if gs and gs.has_method("get_scheme_short_name"):
			scheme_str = gs.get_scheme_short_name()
		controls_button.text = "Controles Fútbol: " + scheme_str

func _setup_focus() -> void:
	var active_buttons = []
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
		var btn = active_buttons[i]
		var prev_btn = active_buttons[(i - 1 + count) % count]
		var next_btn = active_buttons[(i + 1) % count]
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
