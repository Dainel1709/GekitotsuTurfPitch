extends CanvasLayer

onready var clock_label: Label = $HUDControl/ScorePanel/VBox/ClockLabel
onready var score_label: Label = $HUDControl/ScorePanel/VBox/ScoreLabel
onready var tactic_label: Label = $HUDControl/ScorePanel/VBox/TacticLabel
onready var pause_panel: PanelContainer = $HUDControl/PausePanel
onready var goal_notice_label: Label = $HUDControl/GoalNoticeLabel
onready var controls_hint: Label = $HUDControl/ControlsHint
onready var fury_bar: ProgressBar = $HUDControl/ScorePanel/VBox/FuryContainer/FuryBar if has_node("HUDControl/ScorePanel/VBox/FuryContainer/FuryBar") else null
onready var fury_label: Label = $HUDControl/ScorePanel/VBox/FuryContainer/FuryLabel if has_node("HUDControl/ScorePanel/VBox/FuryContainer/FuryLabel") else null
onready var fury_notice_label: Label = $HUDControl/FuryNoticeLabel if has_node("HUDControl/FuryNoticeLabel") else null

var mechanics = null
var match_finished: bool = false

# Reloj de partido: 3 minutos reales (180 segundos) = 90 minutos de partido (1s real = 30s de partido)
const MATCH_DURATION_REAL: float = 180.0
var real_elapsed_time: float = 0.0

# Sistema de Tácticas PPSSPP (SELECT)
var tactic_index: int = 0
const TACTIC_NAMES = ["Equilibrado", "Ofensivo", "Defensivo"]

# Detección de flancos para botones de interfaz
var prev_btn_start: bool = false
var prev_btn_select: bool = false

var flash_rect: ColorRect = null
var card_panel: PanelContainer = null
var card_label: Label = null

func _ready() -> void:
	add_to_group("pitch_hud")
	pause_mode = Node.PAUSE_MODE_PROCESS
	_ensure_cinematic_nodes()
	_resolve_mechanics()

func _ensure_cinematic_nodes() -> void:
	var hud_ctrl = get_node_or_null("HUDControl")
	if not hud_ctrl:
		return
	if not flash_rect:
		flash_rect = ColorRect.new()
		flash_rect.name = "FlashRect"
		flash_rect.anchor_right = 1.0
		flash_rect.anchor_bottom = 1.0
		flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_ctrl.add_child(flash_rect)

	if not card_panel:
		card_panel = PanelContainer.new()
		card_panel.name = "RefereeCardPanel"
		card_panel.anchor_left = 0.5
		card_panel.anchor_right = 0.5
		card_panel.margin_left = -260.0
		card_panel.margin_top = 80.0
		card_panel.margin_right = 260.0
		card_panel.margin_bottom = 135.0
		card_panel.visible = false

		card_label = Label.new()
		card_label.name = "RefereeCardLabel"
		card_label.align = Label.ALIGN_CENTER
		card_label.valign = Label.VALIGN_CENTER
		card_label.autowrap = true
		card_panel.add_child(card_label)
		hud_ctrl.add_child(card_panel)

func play_brawl_transition(banner_text: String = "¡CHISPA EN EL CÉSPED! ¡DUELO 1 VS 1!") -> void:
	_ensure_cinematic_nodes()
	if flash_rect:
		flash_rect.color = Color(1.0, 1.0, 0.9, 0.75)
		flash_rect.visible = true
	if goal_notice_label:
		goal_notice_label.text = banner_text
		goal_notice_label.modulate = Color(1.0, 0.85, 0.1)
		goal_notice_label.visible = true
	yield(get_tree().create_timer(0.18, true), "timeout")
	if flash_rect:
		flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)

func show_referee_card(card_type: String, msg: String) -> void:
	_ensure_cinematic_nodes()
	if card_panel and card_label:
		card_panel.visible = true
		card_label.text = msg
		if card_type == "yellow":
			card_panel.self_modulate = Color(1.0, 0.9, 0.1, 0.95)
			card_label.modulate = Color(0.1, 0.1, 0.1)
		else:
			card_panel.self_modulate = Color(1.0, 0.15, 0.15, 0.95)
			card_label.modulate = Color(1.0, 1.0, 1.0)
	elif goal_notice_label:
		goal_notice_label.text = msg
		if card_type == "yellow":
			goal_notice_label.modulate = Color(1.0, 0.9, 0.1)
		else:
			goal_notice_label.modulate = Color(1.0, 0.2, 0.2)
		goal_notice_label.visible = true

func hide_referee_card() -> void:
	if card_panel:
		card_panel.visible = false
	if goal_notice_label:
		goal_notice_label.visible = false

func show_duel_result(msg: String, is_player_win: bool = true) -> void:
	if goal_notice_label:
		goal_notice_label.text = msg
		if is_player_win:
			goal_notice_label.modulate = Color(0.2, 1.0, 0.3)
		else:
			goal_notice_label.modulate = Color(1.0, 0.3, 0.2)
		goal_notice_label.visible = true

	# Conectar con las porterías para capturar goles durante los 90 minutos
	var rival_goal = get_node_or_null("../RivalGoalArea")
	var player_goal = get_node_or_null("../PlayerGoalArea")
	
	if rival_goal:
		rival_goal.connect("goal_scored", self, "_on_goal_scored")
	if player_goal:
		player_goal.connect("goal_scored", self, "_on_goal_scored")
		
	goal_notice_label.visible = false
	if pause_panel:
		pause_panel.visible = false

	_update_tactic_display()
	_update_clock_and_hud()
	_update_controls_hint()

	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.has_signal("fury_changed") and not p.is_connected("fury_changed", self, "_on_player_fury_changed"):
			p.connect("fury_changed", self, "_on_player_fury_changed")
		if "fury" in p:
			_on_player_fury_changed(p.fury, p.max_fury if "max_fury" in p else 100.0)

func _on_player_fury_changed(fury_val: float, max_val: float) -> void:
	if fury_bar:
		fury_bar.max_value = max_val
		fury_bar.value     = fury_val
	if fury_label:
		if fury_val >= 100.0:
			fury_label.text = "¡FURIA LISTA!"
			fury_label.modulate = Color(1.0, 0.35, 0.1)
		else:
			fury_label.text = "FURIA: %d%%" % int(fury_val)
			fury_label.modulate = Color(1.0, 1.0, 1.0)
	if fury_notice_label:
		fury_notice_label.visible = (fury_val >= 100.0 and not match_finished)
		if fury_val >= 100.0:
			fury_notice_label.text = "¡FURIA 100%! Q+W (L1+R1): Duelo | Q+Tiro: Especial"
			fury_notice_label.modulate = Color(1.0, 0.85, 0.1)

func show_brawl_warning(msg: String = "¡ACÉRCATE A UN RIVAL PARA INICIAR DUELO!") -> void:
	if goal_notice_label:
		goal_notice_label.text = msg
		goal_notice_label.modulate = Color(1.0, 0.35, 0.15)
		goal_notice_label.visible = true
		yield(get_tree().create_timer(1.8, true), "timeout")
		if not match_finished and goal_notice_label.text == msg:
			goal_notice_label.visible = false
	elif fury_notice_label:
		var orig = fury_notice_label.text
		fury_notice_label.text = msg
		fury_notice_label.visible = true
		yield(get_tree().create_timer(1.8, true), "timeout")
		if fury_notice_label.text == msg:
			fury_notice_label.text = orig

func _update_controls_hint() -> void:
	if controls_hint:
		var gs = get_node_or_null("/root/GameSettings")
		var scheme = gs.get_control_scheme() if (gs and gs.has_method("get_control_scheme")) else 0
		if scheme == 0:
			controls_hint.text = "FIFA: Cruz: Pase corto | O: Disparo | L+O: Tiro Especial | Δ: Pase al hueco | □: Centro | R: Sprint | L: Manual"
		else:
			controls_hint.text = "PES: Cruz: Pase corto | □: Disparo | L+□: Tiro Especial | Δ: Pase al hueco | O: Centro | R: Sprint | L: Manual"

func _process(delta: float) -> void:
	# Actualización continua de barra y texto de Furia en cada frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if "fury" in p:
			_on_player_fury_changed(p.fury, p.max_fury if "max_fury" in p else 100.0)

	# 1. Botón START: Pausar / Reanudar el partido
	var start_pressed = Input.is_action_just_pressed("psp_start") or Input.is_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_P) or (Input.is_joy_button_pressed(0, JOY_BUTTON_11) and not prev_btn_start)
	if start_pressed and not prev_btn_start:
		_toggle_pause()
	prev_btn_start = Input.is_action_pressed("psp_start") or Input.is_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_P) or Input.is_joy_button_pressed(0, JOY_BUTTON_11)

	# Si el juego está pausado o el partido terminó, no avanzar el cronómetro
	if get_tree().paused or match_finished:
		return

	# 2. Botón SELECT: Alternar Táctica rápida
	var select_pressed = Input.is_action_just_pressed("psp_select") or Input.is_key_pressed(KEY_TAB) or Input.is_key_pressed(KEY_T) or (Input.is_joy_button_pressed(0, JOY_BUTTON_10) and not prev_btn_select)
	if select_pressed and not prev_btn_select:
		_cycle_tactic()
	prev_btn_select = Input.is_action_pressed("psp_select") or Input.is_key_pressed(KEY_TAB) or Input.is_key_pressed(KEY_T) or Input.is_joy_button_pressed(0, JOY_BUTTON_10)

	# 3. Avance del cronómetro de partido
	real_elapsed_time += delta
	_update_clock_and_hud()

	# 4. Comprobar si se han cumplido los 90:00 minutos de partido (180 segundos reales)
	if real_elapsed_time >= MATCH_DURATION_REAL:
		_finish_match_90_minutes()

func _toggle_pause() -> void:
	if match_finished:
		return
	var new_pause = !get_tree().paused
	get_tree().paused = new_pause
	if pause_panel:
		pause_panel.visible = new_pause
	print("[PitchHUD] START presionado -> Partida ", "PAUSADA" if new_pause else "REANUDADA")

func _cycle_tactic() -> void:
	tactic_index = (tactic_index + 1) % 3
	if mechanics and mechanics.has_method("set_team_tactic"):
		mechanics.set_team_tactic(tactic_index)
	_update_tactic_display()
	print("[PitchHUD] SELECT: Táctica alternada a -> ", TACTIC_NAMES[tactic_index])

func _update_tactic_display() -> void:
	if not tactic_label:
		return
	var mode_text = "Asistido"
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and "manual_aim_mode" in players[0]:
		mode_text = "Manual" if players[0].manual_aim_mode else "Asistido"

	tactic_label.text = "Táctica: [ %s ] (SELECT) | Modo: [ %s ] (L)" % [TACTIC_NAMES[tactic_index], mode_text]

func _update_clock_and_hud() -> void:
	# Cálculo de reloj: 1s real = 30s de partido
	var clamped_real = min(MATCH_DURATION_REAL, real_elapsed_time)
	var match_sec_total = int(clamped_real * 30.0)
	var match_min = int(match_sec_total / 60)
	var match_sec = int(match_sec_total % 60)

	if clock_label:
		clock_label.text = "%02d:%02d" % [match_min, match_sec]

	var p_score: int = 0
	var opp_score: int = 0
	if mechanics:
		p_score = mechanics.get_player_score()
		opp_score = mechanics.get_opponent_score()
	else:
		var rival_goal = get_node_or_null("../RivalGoalArea")
		var player_goal = get_node_or_null("../PlayerGoalArea")
		if rival_goal and "fallback_player_score" in rival_goal:
			p_score = rival_goal.fallback_player_score
		if player_goal and "fallback_opponent_score" in player_goal:
			opp_score = player_goal.fallback_opponent_score

	if score_label:
		score_label.text = "MARCADOR: JUGADOR  [ %d ]  -  [ %d ]  RIVAL" % [p_score, opp_score]

func get_player_score() -> int:
	if mechanics and mechanics.has_method("get_player_score"):
		return mechanics.get_player_score()
	var rival_goal = get_node_or_null("../RivalGoalArea")
	if not rival_goal and get_tree() and get_tree().root:
		rival_goal = get_tree().root.find_node("RivalGoalArea", true, false)
	if rival_goal and "fallback_player_score" in rival_goal:
		return rival_goal.fallback_player_score
	return 0

func get_opponent_score() -> int:
	if mechanics and mechanics.has_method("get_opponent_score"):
		return mechanics.get_opponent_score()
	var player_goal = get_node_or_null("../PlayerGoalArea")
	if not player_goal and get_tree() and get_tree().root:
		player_goal = get_tree().root.find_node("PlayerGoalArea", true, false)
	if player_goal and "fallback_opponent_score" in player_goal:
		return player_goal.fallback_opponent_score
	return 0

func get_match_minute() -> int:
	var clamped_real = min(MATCH_DURATION_REAL, real_elapsed_time)
	return int((clamped_real * 30.0) / 60.0)

func show_foul_notice(msg: String = "¡FALTA RECIBIDA! +30 FURIA") -> void:
	if goal_notice_label:
		goal_notice_label.text = msg
		goal_notice_label.modulate = Color(1.0, 0.8, 0.1)
		goal_notice_label.visible = true
		yield(get_tree().create_timer(1.2, true), "timeout")
		if not match_finished and goal_notice_label.text == msg:
			goal_notice_label.visible = false

func _on_goal_scored(is_rival_goal: bool, _player_score: int, _opponent_score: int) -> void:
	if match_finished:
		return

	if is_rival_goal:
		goal_notice_label.text = "¡¡¡GOOOOLAZO DEL JUGADOR!!!"
		goal_notice_label.modulate = Color(0.2, 1.0, 0.3)
	else:
		goal_notice_label.text = "¡¡¡GOL DEL RIVAL EN CONTRA!!!"
		goal_notice_label.modulate = Color(1.0, 0.3, 0.2)

	goal_notice_label.visible = true
	_update_clock_and_hud()

	# El partido cronometrado continúa hasta los 90 minutos reglamentarios
	yield(get_tree().create_timer(1.8), "timeout")
	if not match_finished:
		goal_notice_label.visible = false

func _finish_match_90_minutes() -> void:
	match_finished = true

	# 1. Detener el jugador y el balón
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "can_move" in p:
			p.can_move = false
		if "velocity" in p:
			p.velocity = Vector3.ZERO

	var balls = get_tree().get_nodes_in_group("ball")
	for b in balls:
		if b is RigidBody:
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity = Vector3.ZERO

	# 2. Evaluar quién tiene más goles (Victoria, Empate o Derrota)
	var p_score: int = 0
	var opp_score: int = 0
	if mechanics:
		p_score = mechanics.get_player_score()
		opp_score = mechanics.get_opponent_score()
	else:
		var rival_goal = get_node_or_null("../RivalGoalArea")
		var player_goal = get_node_or_null("../PlayerGoalArea")
		if rival_goal and "fallback_player_score" in rival_goal:
			p_score = rival_goal.fallback_player_score
		if player_goal and "fallback_opponent_score" in player_goal:
			opp_score = player_goal.fallback_opponent_score

	var result_title = ""
	if p_score > opp_score:
		result_title = "¡VICTORIA DEL CANTERANO!"
		goal_notice_label.modulate = Color(0.2, 1.0, 0.3)
	elif p_score == opp_score:
		result_title = "¡EMPATE AL FINAL DE LOS 90 MINUTOS!"
		goal_notice_label.modulate = Color(1.0, 0.9, 0.2)
	else:
		result_title = "¡DERROTA TRAS EL PITIDO FINAL!"
		goal_notice_label.modulate = Color(1.0, 0.3, 0.2)

	goal_notice_label.text = "%s\nMarcador Final: %d - %d (90:00)\nActualizando estadísticas en C++ y regresando..." % [
		result_title, p_score, opp_score
	]
	goal_notice_label.visible = true

	# 3. Actualizar estadísticas en C++ (apply_match_result)
	if mechanics and mechanics.has_method("apply_match_result"):
		mechanics.apply_match_result(p_score, opp_score)

	if ClassDB.class_exists("GekitotsuStoryManager"):
		var sm = null
		if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("GekitotsuStoryManager"):
			sm = ClassDB.instantiate("GekitotsuStoryManager")
		elif ClassDB.has_method("can_instance") and ClassDB.can_instance("GekitotsuStoryManager"):
			sm = ClassDB.instance("GekitotsuStoryManager")
		if sm and sm.has_method("apply_match_result"):
			sm.apply_match_result(p_score, opp_score)

	# Respaldo persistente en el árbol de Godot y en savegame.json
	var cur_stats = get_tree().root.get_meta("gtp_stats") if get_tree().root.has_meta("gtp_stats") else {
		"discipline": 0, "combat": 0, "money": 0, "reputation": 0, "day": 1, "matchday": 1, "league_wins": 0, "league_losses": 0
	}
	if p_score > opp_score:
		cur_stats["discipline"] = cur_stats.get("discipline", 0) + 15
		cur_stats["combat"] = cur_stats.get("combat", 0) + 5
		cur_stats["money"] = cur_stats.get("money", 0) + 250
		cur_stats["league_wins"] = cur_stats.get("league_wins", 0) + 1
	elif p_score == opp_score:
		cur_stats["discipline"] = cur_stats.get("discipline", 0) + 5
		cur_stats["money"] = cur_stats.get("money", 0) + 50
	else:
		cur_stats["reputation"] = cur_stats.get("reputation", 0) + 10
		cur_stats["combat"] = cur_stats.get("combat", 0) + 5
		cur_stats["money"] = cur_stats.get("money", 0) + 50
		cur_stats["league_losses"] = cur_stats.get("league_losses", 0) + 1

	cur_stats["matchday"] = cur_stats.get("matchday", 1) + 1
	cur_stats["day"] = cur_stats.get("day", 1) + 1
	get_tree().root.set_meta("gtp_stats", cur_stats)

	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("save_progress"):
		gs.save_progress(cur_stats)

	print("[PitchHUD] Partido de 90 minutos concluido (%d - %d). Regresando a MainGame tras 2.5s..." % [p_score, opp_score])

	# 4. Regreso a MainGame.tscn tras 2.5 segundos
	yield(get_tree().create_timer(2.5, true), "timeout")
	get_tree().paused = false
	get_tree().change_scene("res://scenes/MainGame.tscn")

func finish_match_disqualification() -> void:
	match_finished = true

	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "can_move" in p:
			p.can_move = false
		if "velocity" in p:
			p.velocity = Vector3.ZERO

	var balls = get_tree().get_nodes_in_group("ball")
	for b in balls:
		if b is RigidBody:
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity = Vector3.ZERO

	var cur_stats = get_tree().root.get_meta("gtp_stats") if get_tree().root.has_meta("gtp_stats") else {
		"discipline": 0, "combat": 0, "money": 0, "reputation": 0, "day": 1, "matchday": 1, "league_wins": 0, "league_losses": 0
	}
	cur_stats["discipline"] = max(0, cur_stats.get("discipline", 0) - 25)
	cur_stats["reputation"] = cur_stats.get("reputation", 0) + 15
	cur_stats["league_losses"] = cur_stats.get("league_losses", 0) + 1
	cur_stats["matchday"] = cur_stats.get("matchday", 1) + 1
	cur_stats["day"] = cur_stats.get("day", 1) + 1
	get_tree().root.set_meta("gtp_stats", cur_stats)

	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("save_progress"):
		gs.save_progress(cur_stats)

	print("[PitchHUD] Partido finalizado por descalificación / Tarjeta Roja.")

func _resolve_mechanics() -> void:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "mechanics" in p and p.mechanics != null:
			mechanics = p.mechanics
			return
			
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		var node = current_scene.find_node("FootballMechanics", true, false)
		if node:
			mechanics = node
			return
