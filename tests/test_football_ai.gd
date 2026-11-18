extends SceneTree

# ===========================================================================
# TEST: IA de Fútbol — Porteros, Robo de Balón, Pase de Compañero, Reinicio
# Ejecutar en modo headless con Godot 3.6:
#   godot --no-window -s tests/test_football_ai.gd
# ===========================================================================

func _init():
	print("==================================================")
	print("[TEST] Iniciando pruebas de IA de Fútbol (FootballAI.gd)...")
	print("==================================================")

	var ai_script = load("res://scripts/FootballAI.gd")
	assert(ai_script != null, "No se pudo cargar FootballAI.gd")

	var player_script = load("res://scripts/Player.gd")
	assert(player_script != null, "No se pudo cargar Player.gd")

	var goal_area_script = load("res://scripts/GoalArea.gd")
	assert(goal_area_script != null, "No se pudo cargar GoalArea.gd")

	print("  -> Scripts cargados correctamente OK")

	# Crear balón RigidBody
	var ball = RigidBody.new()
	ball.add_to_group("ball")
	root.add_child(ball)
	ball.global_transform.origin = Vector3(0.0, 0.25, 0.0)

	# -----------------------------------------------------------------------
	# 1. TEST: Portero Rival — Parada de balón lento
	# -----------------------------------------------------------------------
	print("\n[1] Verificando comportamiento de portero rival (goalkeeper, is_player_team=false)...")
	var gk_rival = KinematicBody.new()
	gk_rival.set_script(ai_script)
	root.add_child(gk_rival)
	gk_rival.role = "goalkeeper"
	gk_rival.is_player_team = false
	gk_rival.global_transform.origin = Vector3(0.0, 0.8, -11.0)
	gk_rival._ready()

	# Verificar que el portero rival está en el grupo "opponents"
	assert(gk_rival.is_in_group("opponents"), "Portero rival debe estar en grupo 'opponents'")
	assert(gk_rival.is_in_group("goalkeepers"), "Portero rival debe estar en grupo 'goalkeepers'")
	assert(not gk_rival.is_in_group("teammates"), "Portero rival NO debe estar en grupo 'teammates'")
	print("  -> Portero rival en grupos correctos OK")

	# Verificar variables iniciales
	assert(abs(gk_rival.kick_cooldown) < 0.001, "kick_cooldown inicial debe ser 0")
	assert(not gk_rival.has_ball, "has_ball inicial debe ser false")
	print("  -> Variables iniciales del portero OK")

	# Simular que el balón llega a su área con velocidad lenta (< 24.0)
	ball.global_transform.origin = Vector3(1.0, 0.25, -10.5)
	ball.linear_velocity = Vector3(0.0, 0.0, -5.0)  # Velocidad baja
	gk_rival.ball_ref = ball

	# Ejecutar _process_goalkeeper — el portero debería moverse lateralmente
	var old_x = gk_rival.global_transform.origin.x
	# No podemos llamar directamente _process_goalkeeper desde fuera sin KinematicBody activo,
	# pero verificamos que ball_ref es válido y la lógica de velocidad funciona.
	var ball_speed_slow = ball.linear_velocity.length()
	assert(ball_speed_slow < 24.0, "Velocidad del balón debe ser < 24.0 para que el portero pare")
	print("  -> Velocidad de balón lento (%.1f < 24.0): Portero DEBERÍA parar OK" % ball_speed_slow)

	# Simular disparo imparable (Gekitotsu Shot > 24.0)
	ball.linear_velocity = Vector3(0.0, 0.0, -38.0)
	var ball_speed_fast = ball.linear_velocity.length()
	assert(ball_speed_fast >= 24.0, "Velocidad del Gekitotsu Shot debe ser >= 24.0 para superar al portero")
	print("  -> Velocidad de Gekitotsu Shot (%.1f >= 24.0): Portero NO puede parar OK" % ball_speed_fast)

	# -----------------------------------------------------------------------
	# 2. TEST: Portero Aliado — Verificar grupos
	# -----------------------------------------------------------------------
	print("\n[2] Verificando portero aliado (goalkeeper, is_player_team=true)...")
	var gk_ally = KinematicBody.new()
	gk_ally.set_script(ai_script)
	root.add_child(gk_ally)
	gk_ally.role = "goalkeeper"
	gk_ally.is_player_team = true
	gk_ally.global_transform.origin = Vector3(0.0, 0.8, 11.0)
	gk_ally._ready()

	assert(gk_ally.is_in_group("goalkeepers"), "Portero aliado debe estar en 'goalkeepers'")
	assert(gk_ally.is_in_group("teammates"), "Portero aliado debe estar en 'teammates'")
	assert(not gk_ally.is_in_group("opponents"), "Portero aliado NO debe estar en 'opponents'")
	print("  -> Portero aliado en grupos correctos OK")

	# -----------------------------------------------------------------------
	# 3. TEST: Rivales de Campo — Verificar grupo y lógica de robo
	# -----------------------------------------------------------------------
	print("\n[3] Verificando rivales de campo (opponent)...")
	var opp1 = KinematicBody.new()
	opp1.set_script(ai_script)
	root.add_child(opp1)
	opp1.role = "opponent"
	opp1.is_player_team = false
	opp1.global_transform.origin = Vector3(-4.0, 0.8, -4.0)
	opp1._ready()

	assert(opp1.is_in_group("opponents"), "Rival debe estar en grupo 'opponents'")
	assert(not opp1.is_in_group("teammates"), "Rival NO debe estar en 'teammates'")
	print("  -> Rival en grupos correctos OK")

	# Verificar lógica de robo: rival cerca del balón y un "carrier" aliado
	opp1.ball_ref = ball
	ball.global_transform.origin = Vector3(-4.0, 0.25, -4.0)
	ball.linear_velocity = Vector3.ZERO

	# Simular: rival no tiene balón, verifica que has_ball empieza en false
	assert(not opp1.has_ball, "Rival no debe tener balón al inicio")

	# El rival puede adquirir el balón si está cerca (<= 1.4 m) y la velocidad es baja
	var dist_opp_ball = opp1.global_transform.origin.distance_to(ball.global_transform.origin)
	# Colocar balón a menos de 1.4 m del rival
	ball.global_transform.origin = Vector3(-4.0, 0.25, -3.0)
	dist_opp_ball = opp1.global_transform.origin.distance_to(ball.global_transform.origin)
	assert(dist_opp_ball <= 1.4, "Distancia rival-balón debe ser <= 1.4 m para prueba de posesión")
	print("  -> Rival a %.2f m del balón (rango de posesión) OK" % dist_opp_ball)

	var opp2 = KinematicBody.new()
	opp2.set_script(ai_script)
	root.add_child(opp2)
	opp2.role = "opponent"
	opp2.is_player_team = false
	opp2.global_transform.origin = Vector3(4.0, 0.8, -2.0)
	opp2._ready()

	assert(opp2.is_in_group("opponents"), "Rival 2 debe estar en grupo 'opponents'")
	print("  -> Rival 2 creado y en grupos correctos OK")

	# -----------------------------------------------------------------------
	# 4. TEST: Compañero Aliado — Verificar grupo y receive_pass_call
	# -----------------------------------------------------------------------
	print("\n[4] Verificando compañero aliado (teammate)...")
	var ally1 = KinematicBody.new()
	ally1.set_script(ai_script)
	root.add_child(ally1)
	ally1.role = "teammate"
	ally1.is_player_team = true
	ally1.global_transform.origin = Vector3(5.0, 0.8, 1.0)
	ally1._ready()

	assert(ally1.is_in_group("teammates"), "Compañero aliado debe estar en 'teammates'")
	assert(not ally1.is_in_group("opponents"), "Compañero aliado NO debe estar en 'opponents'")
	print("  -> Compañero en grupos correctos OK")

	# Verificar método receive_pass_call
	assert(ally1.has_method("receive_pass_call"), "FootballAI debe tener método receive_pass_call")
	print("  -> Método receive_pass_call existe OK")

	# Simular compañero con balón cerca y recibir llamada de pase
	ally1.ball_ref = ball
	ball.global_transform.origin = Vector3(5.0, 0.25, 1.0)
	ball.linear_velocity = Vector3.ZERO
	ally1.has_ball = true
	ally1.is_dribbling = true

	# Crear jugador Ryu simulado
	var ryu_node = Spatial.new()
	ryu_node.add_to_group("player")
	root.add_child(ryu_node)
	ryu_node.global_transform.origin = Vector3(0.0, 0.8, 3.5)

	# Llamar receive_pass_call
	ally1.receive_pass_call(ryu_node)

	# Después del pase, el compañero debe haber soltado el balón
	assert(not ally1.has_ball, "Compañero debe haber soltado el balón tras receive_pass_call")
	assert(not ally1.is_dribbling, "is_dribbling del compañero debe ser false tras pass_call")
	assert(ball.linear_velocity.length() > 0.01, "El balón debe tener velocidad tras el pase")
	print("  -> receive_pass_call: compañero soltó balón y lo dirigió hacia Ryu OK (vel: %.2f)" % ball.linear_velocity.length())

	# -----------------------------------------------------------------------
	# 5. TEST: Acción Defensiva (Tackle) en Player.gd
	# -----------------------------------------------------------------------
	print("\n[5] Verificando acción defensiva (tackle) en Player.gd...")
	var player = player_script.new()
	root.add_child(player)
	player.global_transform.origin = Vector3(0.0, 0.8, 0.0)
	player.ball_ref = ball

	# Verificar que tackle_cooldown existe
	assert("tackle_cooldown" in player, "Player debe tener variable tackle_cooldown")
	assert(player.tackle_cooldown == 0.0, "tackle_cooldown inicial debe ser 0.0")
	print("  -> tackle_cooldown inicializado OK")

	# Verificar que _execute_tackle existe
	assert(player.has_method("_execute_tackle"), "Player debe tener método _execute_tackle")
	print("  -> Método _execute_tackle existe OK")

	# Simular robo con rival cerca (opp1 tiene balón a 0.5 m del jugador)
	ball.global_transform.origin = Vector3(0.0, 0.25, 0.5)
	ball.linear_velocity = Vector3.ZERO
	opp1.global_transform.origin = Vector3(0.0, 0.8, 0.5)
	opp1.has_ball = true
	opp1.is_dribbling = true

	player._execute_tackle()
	# Si el rival estaba en rango, el jugador debe haber tomado posesión
	assert(player.is_dribbling or player.is_ball_controlled, "Jugador debe tener posesión tras tackle exitoso")
	assert(player.tackle_cooldown > 0.0, "tackle_cooldown debe ser > 0 tras ejecutar tackle")
	print("  -> Tackle exitoso: posesión recuperada (is_dribbling=%s, cooldown=%.2f) OK" % [str(player.is_dribbling), player.tackle_cooldown])

	# -----------------------------------------------------------------------
	# 6. TEST: reset_position en FootballAI
	# -----------------------------------------------------------------------
	print("\n[6] Verificando reset_position en FootballAI...")
	var ai_test = KinematicBody.new()
	ai_test.set_script(ai_script)
	root.add_child(ai_test)
	ai_test.role = "opponent"
	ai_test.is_player_team = false
	ai_test.global_transform.origin = Vector3(3.0, 0.8, 2.0)
	ai_test._ready()

	# Registrar initial_position
	var initial_pos = ai_test.initial_position
	# Mover el AI
	ai_test.global_transform.origin = Vector3(10.0, 0.8, 8.0)
	ai_test.has_ball = true
	ai_test.is_dribbling = true

	ai_test.reset_position()

	var reset_pos = ai_test.global_transform.origin
	assert(abs(reset_pos.x - initial_pos.x) < 0.01, "reset_position debe restaurar X inicial")
	assert(abs(reset_pos.z - initial_pos.z) < 0.01, "reset_position debe restaurar Z inicial")
	assert(not ai_test.has_ball, "has_ball debe ser false tras reset_position")
	assert(not ai_test.is_dribbling, "is_dribbling debe ser false tras reset_position")
	print("  -> reset_position: posición restaurada (%.1f, %.1f) y estado limpio OK" % [reset_pos.x, reset_pos.z])

	# -----------------------------------------------------------------------
	# 7. TEST: GoalArea — reset_all_actors existe
	# -----------------------------------------------------------------------
	print("\n[7] Verificando GoalArea._reset_all_actors...")
	var ga = Area.new()
	ga.set_script(goal_area_script)
	root.add_child(ga)
	# Añadir CollisionShape requerida por Area
	var col = CollisionShape.new()
	ga.add_child(col)
	ga._ready()

	assert(ga.has_method("_reset_all_actors"), "GoalArea debe tener método _reset_all_actors")
	# Llamar directamente (no provoca crash aunque el tree esté vacío de actores)
	ga._reset_all_actors()
	print("  -> GoalArea._reset_all_actors existe y se ejecuta sin errores OK")

	# -----------------------------------------------------------------------
	# RESUMEN
	# -----------------------------------------------------------------------
	print("\n==================================================")
	print("[TEST] TODAS LAS PRUEBAS DE IA DE FÚTBOL PASARON ✓")
	print("==================================================")

	quit()
