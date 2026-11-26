extends SceneTree

func _init():
	print("==================================================")
	print("[TEST] Iniciando verificacion de Dribbling, Giros y Boton L...")
	print("==================================================")

	var player_script = load("res://scripts/Player.gd")
	assert(player_script != null, "No se pudo cargar Player.gd")
	var player = player_script.new()
	assert(player != null, "No se pudo instanciar Player")
	root.add_child(player)

	# Instanciar balón RigidBody
	var ball = RigidBody.new()
	ball.add_to_group("ball")
	root.add_child(ball)
	player.ball_ref = ball

	# --------------------------------------------------------------------------
	# 1. Verificación de Parámetros Exportados e Iniciales
	# --------------------------------------------------------------------------
	print("\n[1] Verificando parámetros de dribbling y cooldowns...")
	assert(abs(player.dribble_control_radius - 1.65) < 0.001, "dribble_control_radius debe ser 1.65")
	assert(abs(player.turn_speed - 16.0) < 0.001, "turn_speed debe ser 16.0")
	assert(player.kick_cooldown == 0.0, "kick_cooldown inicial debe ser 0.0")
	assert(player.knock_on_boost_timer == 0.0, "knock_on_boost_timer inicial debe ser 0.0")
	assert(player.r_tap_timer == 0.0, "r_tap_timer inicial debe ser 0.0")
	assert(not player.is_dribbling, "is_dribbling inicial debe ser false")
	print("  -> Parámetros de configuración OK")

	# --------------------------------------------------------------------------
	# 2. Verificación de Control de Conducción (_is_ball_controlled)
	# --------------------------------------------------------------------------
	print("\n[2] Verificando condiciones de control del balón (dribble_control_radius, dot, velocidad)...")
	player.translation = Vector3(0.0, 0.0, 0.0)
	player.facing_direction = Vector3(0.0, 0.0, -1.0) # Mirando al Norte (-Z)

	# Caso 2a: Balón de frente a 1.0 m (dentro de radio 1.65 m y dot = 1.0)
	ball.translation = Vector3(0.0, 0.25, -1.0)
	ball.linear_velocity = Vector3.ZERO
	assert(player._is_ball_controlled(), "El balón a 1.0m de frente debe estar controlado")
	print("  -> Caso frontal dentro de radio: Balón controlado OK")

	# Caso 2b: Balón lejos a 2.5 m (fuera de dribble_control_radius 1.65 m)
	ball.translation = Vector3(0.0, 0.25, -2.5)
	assert(not player._is_ball_controlled(), "El balón a 2.5m NO debe estar controlado")
	print("  -> Caso fuera de radio (> 1.65m): Balón libre OK")

	# Caso 2c: Balón a velocidad de disparo (>= 15.0 m/s)
	ball.translation = Vector3(0.0, 0.25, -1.0)
	ball.linear_velocity = Vector3(0.0, 0.0, 16.0)
	assert(not player._is_ball_controlled(), "Balón a velocidad de disparo (>= 15.0) NO debe pegarse")
	ball.linear_velocity = Vector3.ZERO
	print("  -> Caso velocidad de disparo (>= 15.0): Balón no se pega OK")

	# Caso 2d: Balón a la espalda (dot < -0.25 y dist > 0.45 m)
	ball.translation = Vector3(0.0, 0.25, 1.0) # Detrás (+Z)
	assert(not player._is_ball_controlled(), "Balón a la espalda a 1.0m NO debe controlarse")
	print("  -> Caso a la espalda (dot < -0.25): Balón no controlado OK")

	# Caso 2e: Balón entre los pies muy cerca (dist <= 0.45 m, aunque esté ligeramente atrás)
	ball.translation = Vector3(0.0, 0.25, 0.3)
	assert(player._is_ball_controlled(), "Balón a distancia <= 0.45m debe controlarse aunque esté entre los pies")
	print("  -> Caso muy cercano (dist <= 0.45m): Balón controlado OK")

	# --------------------------------------------------------------------------
	# 3. Verificación de Giro de 180° sin Efecto Catapulta
	# --------------------------------------------------------------------------
	print("\n[3] Verificando giros de 180° sin catapulta y mantenimiento de is_dribbling...")
	player.translation = Vector3(0.0, 0.0, 0.0)
	player.facing_direction = Vector3(0.0, 0.0, -1.0)
	player.velocity = Vector3(0.0, 0.0, -8.0)
	ball.translation = Vector3(0.0, 0.25, -1.0)
	ball.linear_velocity = Vector3(0.0, 0.0, -8.0)

	# Iniciar conducción
	player._update_ball_dribble(1.0 / 60.0, true, false)
	assert(player.is_dribbling, "is_dribbling debe activarse al entrar en rango y velocidad controlada")
	assert(player.is_ball_controlled, "is_ball_controlled debe ser true")

	# Simular giro brusco de 180°: jugador cambia repentinamente su orientación al Sur (+Z)
	player.facing_direction = Vector3(0.0, 0.0, 1.0) # dot = -1.0 respecto al balón en -Z
	player._update_ball_dribble(1.0 / 60.0, true, false)

	# is_dribbling debe mantenerse activa mientras dist <= 1.75 m (sin soltar por dot negativo)
	assert(player.is_dribbling, "is_dribbling debe mantenerse activa en giro de 180° (dist <= 1.75m)")
	assert(player.is_ball_controlled, "is_ball_controlled debe mantenerse true")

	# La velocidad del balón debe estar limitada a max_dribble_speed = max(current_speed * 1.35, 12.5)
	var max_allowed = max(player.velocity.length() * 1.35, 12.5)
	var h_ball_spd = Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
	assert(h_ball_spd <= max_allowed + 0.01, "Velocidad de corrección del balón no debe exceder max_dribble_speed")
	print("  -> Giro de 180°: balón en control continuo (is_dribbling=true) y velocidad limitada a %.2f (<= %.2f) OK" % [h_ball_spd, max_allowed])

	# --------------------------------------------------------------------------
	# 4. Verificación de kick_cooldown tras pase o disparo
	# --------------------------------------------------------------------------
	print("\n[4] Verificando kick_cooldown tras ejecución de pase y disparo...")
	player.kick_cooldown = 0.25
	assert(not player._is_ball_controlled(), "Con kick_cooldown > 0 no debe haber anclaje del balón")
	player._update_ball_dribble(1.0 / 60.0, true, false)
	assert(not player.is_dribbling, "is_dribbling debe ser false si kick_cooldown > 0")
	assert(not player.is_ball_controlled, "is_ball_controlled debe ser false si kick_cooldown > 0")
	player.kick_cooldown = 0.0

	# Simular disparo cargado y verificar que activa kick_cooldown = 0.25
	ball.translation = Vector3(0.0, 0.25, -0.8)
	player._execute_kick()
	assert(abs(player.kick_cooldown - 0.25) < 0.001, "Disparo debe asignar kick_cooldown = 0.25")
	assert(not player.is_dribbling, "Disparo debe liberar is_dribbling")
	player.kick_cooldown = 0.0
	print("  -> kick_cooldown = 0.25 y liberación del balón OK")

	# --------------------------------------------------------------------------
	# 5. Verificación de Autopase Largo (_execute_knock_on)
	# --------------------------------------------------------------------------
	print("\n[5] Verificando autopase largo con doble toque en W / R1...")
	var initial_stamina = player.get_stamina()
	ball.translation = Vector3(0.0, 0.25, -1.0)
	player.facing_direction = Vector3(0.0, 0.0, -1.0)
	player.velocity = Vector3(0.0, 0.0, -10.0)

	player._execute_knock_on()

	# Verificar velocidad del balón: ~17.5 frontal, y = 0.06
	assert(abs(ball.linear_velocity.z - (-17.5)) < 0.1, "Velocidad frontal del balón debe ser ~17.5")
	assert(abs(ball.linear_velocity.y - 0.06) < 0.01, "Velocidad vertical del balón debe ser 0.06")
	assert(abs(player.kick_cooldown - 0.38) < 0.001, "kick_cooldown del autopase debe ser 0.38")
	assert(abs(player.knock_on_boost_timer - 0.45) < 0.001, "knock_on_boost_timer debe ser 0.45")
	assert(not player.is_dribbling, "Autopase debe liberar is_dribbling")
	
	var boosted_speed = player.get_current_speed()
	assert(boosted_speed > player.fallback_base_speed * 1.20, "get_current_speed() debe incluir el impulso de 1.22x")
	
	var final_stamina = player.get_stamina()
	assert(abs((initial_stamina - final_stamina) - 10.0) < 0.01, "Autopase debe drenar 10.0 de estamina")
	print("  -> Balón lanzado: vz=%.2f, vy=%.2f | cooldown=%.2f | boost=%.2f | estamina drenada=10.0 OK" % [
		ball.linear_velocity.z, ball.linear_velocity.y, player.kick_cooldown, player.knock_on_boost_timer
	])
	player.kick_cooldown = 0.0

	# --------------------------------------------------------------------------
	# 6. Verificación del Botón L: Sin Atracción Magnética de Balones Lejanos Sueltos
	# --------------------------------------------------------------------------
	print("\n[6] Verificando que el botón L NO atrae magnéticamente balones lejanos sueltos...")
	player.translation = Vector3(0.0, 0.0, 0.0)
	ball.translation = Vector3(12.0, 0.25, -12.0)
	ball.linear_velocity = Vector3.ZERO
	player._on_button_l_pressed()
	assert(ball.linear_velocity.length_squared() == 0.0, "Balón lejano sin aliados NO debe recibir impulso hacia el jugador")
	print("  -> Balón suelto a 17m permanece inmóvil al pulsar L (sin imán) OK")

	# --------------------------------------------------------------------------
	# 7. Verificación del Botón L: Posesión Rival (< 2.2 m de "opponents", "rivals", "enemy")
	# --------------------------------------------------------------------------
	print("\n[7] Verificando bloqueo de botón L si un rival tiene el balón (< 2.2m)...")
	var rival = Spatial.new()
	rival.add_to_group("rivals")
	root.add_child(rival)
	rival.translation = Vector3(12.0, 0.0, -11.5) # A 0.5m del balón
	ball.linear_velocity = Vector3.ZERO

	player._on_button_l_pressed()
	assert(ball.linear_velocity.length_squared() == 0.0, "Si un rival está a < 2.2m del balón, L NO debe quitarlo ni pasarlo")
	print("  -> Con rival a 0.5m del balón: petición de pase L bloqueada OK")
	rival.free()

	# --------------------------------------------------------------------------
	# 8. Verificación del Botón L: Pase Aliado ("teammates", "allies") a < 2.2 m del balón
	# --------------------------------------------------------------------------
	print("\n[8] Verificando que botón L pide pase si un compañero aliado tiene el balón...")
	var ally = Spatial.new()
	ally.add_to_group("teammates")
	root.add_child(ally)
	ally.translation = Vector3(12.0, 0.0, -11.5) # A 0.5m del balón
	ball.linear_velocity = Vector3.ZERO

	player._on_button_l_pressed()
	assert(ball.linear_velocity.length() > 5.0, "Con compañero aliado cerca del balón, L debe iniciar pase hacia Ryu")
	print("  -> Con compañero aliado a 0.5m: pase ejecutado con velocidad %.2f OK" % ball.linear_velocity.length())
	ally.free()

	# --------------------------------------------------------------------------
	# 9. Verificación del Botón L: Recepción / Control Orientado (dist <= 2.2m del jugador)
	# --------------------------------------------------------------------------
	print("\n[9] Verificando recepción / control orientado a 0.65m con botón L...")
	player.translation = Vector3(0.0, 0.0, 0.0)
	player.facing_direction = Vector3(0.0, 0.0, 1.0) # Mirando al Sur
	ball.translation = Vector3(0.0, 0.25, 1.8) # Balón a 1.8m del jugador
	ball.linear_velocity = Vector3(0.0, 0.0, 4.0)

	player._on_button_l_pressed()

	# Debe reorientar hacia la portería rival (0, 0, -1) y frenar a 0.65m delante
	assert(player.facing_direction == Vector3(0.0, 0.0, -1.0), "Debe orientar hacia portería rival (-Z)")
	assert(abs(ball.translation.z - (-0.65)) < 0.01, "El balón debe colocarse frenado a 0.65m delante")
	assert(ball.linear_velocity == Vector3.ZERO, "La velocidad del balón debe quedar a cero")
	assert(player.is_dribbling, "is_dribbling debe estar activo tras recepción")
	assert(player.is_ball_controlled, "is_ball_controlled debe estar activo")
	print("  -> Recepción y freno a 0.65m delante del jugador OK")

	# --------------------------------------------------------------------------
	# 10. Verificación de Recoger Balón desde Atrás al Correr al Frente (dot < 0.0)
	# --------------------------------------------------------------------------
	print("\n[10] Verificando recogida del balón desde atrás corriendo hacia el frente...")
	player.translation = Vector3(0.0, 0.0, 0.0)
	player.facing_direction = Vector3(0.0, 0.0, -1.0) # Mirando al Norte (-Z)
	player.velocity = Vector3(0.0, 0.0, -10.0) # Corriendo al frente a 10 m/s
	player.is_dribbling = false
	player.is_ball_controlled = false
	ball.translation = Vector3(0.0, 0.25, 0.8) # Balón a la espalda (+Z) a 0.8m
	ball.linear_velocity = Vector3.ZERO

	# Ejecutar actualización de conducción
	player._update_ball_dribble(1.0 / 60.0, true, false)
	assert(player.is_dribbling == true, "Ryu debe iniciar conducción aunque el balón esté detrás si corre al frente")
	assert(player.is_ball_controlled == true, "is_ball_controlled debe ser true")
	assert(ball.linear_velocity.z < 0.0, "El balón debe recibir impulso hacia el frente (-Z)")

	# Velocidad horizontal del balón debe acelerar con max_dribble_speed = max(current_speed * 1.85, 16.0)
	var max_forward_spd = max(player.velocity.length() * 1.85, 16.0)
	var ball_spd_now = Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
	assert(ball_spd_now <= max_forward_spd + 0.1, "La velocidad no debe exceder max_forward_spd")
	assert(ball_spd_now > 2.0, "El balón debe acelerar de inmediato para adelantarse a los pies")
	print("  -> Recogida desde atrás: is_dribbling=true, aceleración hacia el frente (%.2f m/s <= %.2f m/s) OK" % [ball_spd_now, max_forward_spd])

	ball.queue_free()
	player.queue_free()

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DE DRIBBLING, GIROS Y BOTON L PASARON EXITOSAMENTE.")
	print("==================================================")
	quit(0)
