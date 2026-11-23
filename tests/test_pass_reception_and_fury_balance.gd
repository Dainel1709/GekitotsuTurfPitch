extends SceneTree

# Test headless para validar:
# 1. Recepción limpia de pases rápidos sin rebote (expecting_pass, amortiguación al 25%, is_dribbling=true).
# 2. Carga real y equilibrada de la Barra de Furia (tensión de marcador, faltas recibidas, robos y remates).

func _init():
	print("==================================================")
	print("[TEST] Recepción Limpia de Pases y Carga de Furia")
	print("==================================================")

	# --------------------------------------------------------------------------
	# PARTE 1: Recepción Limpia de Pases sin Rebote
	# --------------------------------------------------------------------------
	print("\n--- 1. Verificando Recepción Limpia de Pases Asistidos ---")
	var player_script = load("res://scripts/Player.gd")
	var ai_script = load("res://scripts/FootballAI.gd")
	assert(player_script != null, "Player.gd debe cargarse correctamente")
	assert(ai_script != null, "FootballAI.gd debe cargarse correctamente")

	var player = KinematicBody.new()
	player.set_script(player_script)
	root.add_child(player)
	player.global_transform.origin = Vector3(0.0, 0.0, 0.0)
	player.facing_direction = Vector3(0.0, 0.0, -1.0)
	player.fury = 0.0

	var teammate = KinematicBody.new()
	teammate.set_script(ai_script)
	teammate.role = "teammate"
	teammate.add_to_group("teammates")
	root.add_child(teammate)
	teammate.global_transform.origin = Vector3(5.0, 0.0, -10.0)

	var ball = RigidBody.new()
	ball.name = "FootballBall"
	ball.add_to_group("ball")
	root.add_child(ball)
	player.ball_ref = ball

	# 1.1 Comprobar variables de recepción asistida
	assert("expecting_pass" in player, "Player debe tener la variable expecting_pass")
	assert("pass_receive_timer" in player, "Player debe tener pass_receive_timer")
	assert(player.expecting_pass == false, "expecting_pass debe iniciar en false")

	# 1.2 Activación de recepción asistida con on_incoming_pass()
	player.on_incoming_pass()
	assert(player.expecting_pass == true, "on_incoming_pass() debe activar expecting_pass = true")
	assert(player.pass_receive_timer == 2.5, "pass_receive_timer debe inicializarse en 2.5s")
	print("  -> Activación de expecting_pass y pass_receive_timer (2.5s): OK")

	# 1.3 Comprobar que receive_pass_call de FootballAI activa on_incoming_pass en Ryu
	player.expecting_pass = false
	player.pass_receive_timer = 0.0
	ball.global_transform.origin = teammate.global_transform.origin
	teammate.ball_ref = ball
	teammate.has_ball = true
	teammate.receive_pass_call(player)
	assert(player.expecting_pass == true, "FootballAI.receive_pass_call debe invocar target_player.on_incoming_pass()")
	print("  -> Pase de compañero hacia Ryu invoca on_incoming_pass() automáticamente: OK")

	# 1.4 Simulación de pase rápido viajando hacia Ryu a alta velocidad (20.0 m/s)
	ball.global_transform.origin = Vector3(0.0, 0.25, -1.75) # A 1.75m de Ryu (dentro de 1.85m)
	ball.linear_velocity = Vector3(0.0, 0.0, 20.0) # Viniendo veloz hacia Ryu (+Z hacia Z=0)
	var initial_h_speed = ball.linear_velocity.length()
	assert(initial_h_speed == 20.0, "La velocidad inicial del pase debe ser 20.0 m/s")

	# Ejecutar actualización de dribble
	player.kick_cooldown = 0.0
	player.is_dribbling = false
	player._update_ball_dribble(0.016, false, false)

	# Verificar amortiguación, control del balón y recolocación suave
	assert(player.is_dribbling == true, "Ryu debe controlar el balón rápido sin rechazarlo (is_dribbling = true)")
	assert(ball.linear_velocity.z <= 5.1, "La velocidad horizontal del balón debe amortiguarse al 25% (<= 5.1 m/s)")
	assert(ball.global_transform.origin.z < 0.0, "El balón debe situarse delante de los pies de Ryu (Z < 0)")
	assert(player.expecting_pass == false, "expecting_pass debe reiniciarse tras completar la recepción")
	assert(player.fury >= 6.0, "Debe sumarse +6.0 de furia por completar la recepción del pase")
	print("  -> Amortiguación de velocidad al 25%, posesión limpia (is_dribbling=true) y sin rebote: OK")

	# --------------------------------------------------------------------------
	# PARTE 2: Carga de Barra de Furia por Tres Vías
	# --------------------------------------------------------------------------
	print("\n--- 2. Verificando Carga Real y Equilibrada de Furia ---")
	player.fury = 0.0

	# 2.1 Carga por Tensión del Partido (Marcador en contra y minutos finales)
	var hud_script = load("res://scripts/PitchHUD.gd")
	assert(hud_script != null, "PitchHUD.gd debe cargarse")
	var hud = CanvasLayer.new()
	hud.set_script(hud_script)
	var hud_ctrl = Control.new()
	hud_ctrl.name = "HUDControl"
	var score_panel = PanelContainer.new()
	score_panel.name = "ScorePanel"
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	var score_lbl = Label.new()
	score_lbl.name = "ScoreLabel"
	var clock_lbl = Label.new()
	clock_lbl.name = "ClockLabel"
	vbox.add_child(clock_lbl)
	vbox.add_child(score_lbl)
	score_panel.add_child(vbox)
	hud_ctrl.add_child(score_panel)

	var fury_bar = ProgressBar.new()
	fury_bar.name = "PlayerFuryBar"
	hud_ctrl.add_child(fury_bar)
	var fury_lbl = Label.new()
	fury_lbl.name = "PlayerFuryLabel"
	hud_ctrl.add_child(fury_lbl)

	hud.add_child(hud_ctrl)
	root.add_child(hud)
	hud.fury_bar = fury_bar
	hud.fury_label = fury_lbl

	# Simular rival ganando por 1 gol (diff == 1 -> +3.0/s)
	# Creamos metas simuladas con script GoalArea
	var goal_script = load("res://scripts/GoalArea.gd")
	var dummy_goal_p = Area.new()
	dummy_goal_p.name = "RivalGoalArea"
	dummy_goal_p.set_script(goal_script)
	dummy_goal_p.fallback_player_score = 0
	var dummy_goal_opp = Area.new()
	dummy_goal_opp.name = "PlayerGoalArea"
	dummy_goal_opp.set_script(goal_script)
	dummy_goal_opp.fallback_opponent_score = 1
	root.add_child(dummy_goal_p)
	root.add_child(dummy_goal_opp)

	player._update_match_tension_fury(1.0)
	assert(player.fury >= 2.9, "1 gol abajo debe sumar +3.0 Furia por segundo de tensión")
	print("  -> Tensión: 1 gol abajo suma +3.0/s de Furia: OK")

	# Simular rival ganando por 2 goles (diff >= 2 -> +5.0/s)
	player.fury = 0.0
	dummy_goal_opp.set("fallback_opponent_score", 2)
	player._update_match_tension_fury(1.0)
	assert(player.fury >= 4.9, "2 goles abajo debe sumar +5.0 Furia por segundo de tensión")
	print("  -> Tensión: 2+ goles abajo suma +5.0/s de Furia: OK")

	# Minuto >= 75 empatado o perdiendo (150s reales = 75 minutos -> +2.0/s adicional)
	player.fury = 0.0
	hud.real_elapsed_time = 155.0 # Minuto 77
	player._update_match_tension_fury(1.0)
	assert(player.fury >= 6.9, "Minuto >= 75 perdiendo debe sumar +5.0 + 2.0 = +7.0/s: OK")
	print("  -> Tensión: Últimos 15 minutos (>= 75') suma +2.0/s adicional: OK")

	# 2.2 Faltas y Choques Físicos
	player.fury = 0.0
	player.foul_cooldown = 0.0
	player.receive_foul()
	assert(player.fury == 30.0, "receive_foul() debe sumar exactamente +30.0 Furia")
	print("  -> Falta / Choque físico recibido suma +30.0 Furia: OK")

	player.on_goal_conceded()
	assert(player.fury == 55.0, "on_goal_conceded() debe sumar +25.0 Furia (total 55.0)")
	print("  -> Gol en contra recibido suma +25.0 Furia: OK")

	# 2.3 Acciones de Intensidad en Cancha
	# Entrada / Robo exitoso (+8.0)
	var opponent = KinematicBody.new()
	opponent.set_script(ai_script)
	opponent.role = "opponent"
	opponent.add_to_group("opponents")
	root.add_child(opponent)
	opponent.global_transform.origin = player.global_transform.origin + Vector3(0.5, 0.0, 0.5)
	opponent.has_ball = true

	player.tackle_cooldown = 0.0
	player._execute_tackle()
	assert(player.fury >= 63.0, "Robo exitoso con entrada debe sumar +8.0 Furia (total 63.0)")
	print("  -> Robo exitoso con entrada suma +8.0 Furia: OK")

	# Remate a puerta (+12.0)
	player.is_ball_in_kick_area = true
	player.shot_charge = 0.5
	player._execute_kick()
	assert(player.fury >= 75.0, "Remate a puerta debe sumar +12.0 Furia (total 75.0)")
	print("  -> Remate a puerta suma +12.0 Furia: OK")

	# Llevar Furia al 100%
	player.add_fury(40.0)
	assert(player.fury == 100.0, "La furia debe clampearse a max_fury (100.0)")

	# 2.4 Actualización en PitchHUD por frame
	hud._process(0.016)
	assert(hud.fury_bar.value == 100.0, "PitchHUD fury_bar debe reflejar 100.0")
	assert(hud.fury_label.text == "¡FURIA LISTA!", "PitchHUD fury_label debe mostrar ¡FURIA LISTA!")
	print("  -> Actualización visual de barra de furia y textos en PitchHUD: OK")

	# Limpieza
	player.free()
	teammate.free()
	opponent.free()
	ball.free()
	dummy_goal_p.free()
	dummy_goal_opp.free()
	hud.free()

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DE RECEPCIÓN Y FURIA PASARON EXITOSAMENTE.")
	print("==================================================")
	quit(0)
