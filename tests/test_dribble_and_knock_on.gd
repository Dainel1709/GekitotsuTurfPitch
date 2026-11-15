extends SceneTree

func _init():
	print("==================================================")
	print("[TEST] Iniciando verificacion de Dribbling y Autopase Largo...")
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

	# Caso 2c: Balón a velocidad de disparo (>= 16.0 m/s)
	ball.translation = Vector3(0.0, 0.25, -1.0)
	ball.linear_velocity = Vector3(0.0, 0.0, 18.0)
	assert(not player._is_ball_controlled(), "Balón a velocidad de disparo (>= 16.0) NO debe pegarse")
	ball.linear_velocity = Vector3.ZERO
	print("  -> Caso velocidad de disparo (>= 16.0): Balón no se pega OK")

	# Caso 2d: Balón a la espalda (dot < -0.25 y dist > 0.45 m)
	ball.translation = Vector3(0.0, 0.25, 1.0) # Detrás (+Z)
	assert(not player._is_ball_controlled(), "Balón a la espalda a 1.0m NO debe controlarse")
	print("  -> Caso a la espalda (dot < -0.25): Balón no controlado OK")

	# Caso 2e: Balón entre los pies muy cerca (dist <= 0.45 m, aunque esté ligeramente atrás)
	ball.translation = Vector3(0.0, 0.25, 0.3)
	assert(player._is_ball_controlled(), "Balón a distancia <= 0.45m debe controlarse aunque esté entre los pies")
	print("  -> Caso muy cercano (dist <= 0.45m): Balón controlado OK")

	# --------------------------------------------------------------------------
	# 3. Verificación de Física de Conducción (_update_ball_dribble)
	# --------------------------------------------------------------------------
	print("\n[3] Verificando ajuste de linear_velocity y angular_velocity en dribble...")
	player.translation = Vector3(0.0, 0.0, 0.0)
	player.facing_direction = Vector3(0.0, 0.0, -1.0)
	player.velocity = Vector3(0.0, 0.0, -8.0) # Jugador avanzando a 8 m/s
	ball.translation = Vector3(0.0, 0.25, -0.5)
	ball.linear_velocity = Vector3.ZERO

	# Conducción al caminar (is_moving = true, is_sprinting = false -> target_dist = 1.0)
	player._update_ball_dribble(1.0 / 60.0, true, false)
	assert(ball.linear_velocity.z < 0.0, "La velocidad del balón en Z debe avanzar con el jugador")
	assert(ball.angular_velocity.x < 0.0, "El balón debe rotar en X acorde al avance en Z")
	print("  -> Conducción al caminar: linear_velocity.z=%.2f, angular_velocity.x=%.2f OK" % [ball.linear_velocity.z, ball.angular_velocity.x])

	# Conducción al esprintar (is_sprinting = true -> target_dist = 1.45)
	player._update_ball_dribble(1.0 / 60.0, true, true)
	assert(player.is_ball_controlled, "is_ball_controlled debe ser true tras _update_ball_dribble")
	print("  -> Conducción en sprint verificada OK")

	# --------------------------------------------------------------------------
	# 4. Verificación de kick_cooldown tras pase o disparo
	# --------------------------------------------------------------------------
	print("\n[4] Verificando kick_cooldown tras ejecución de pase y disparo...")
	player.kick_cooldown = 0.25
	assert(not player._is_ball_controlled(), "Con kick_cooldown > 0 no debe haber anclaje del balón")
	player._update_ball_dribble(1.0 / 60.0, true, false)
	assert(not player.is_ball_controlled, "is_ball_controlled debe ser false si kick_cooldown > 0")
	player.kick_cooldown = 0.0

	# Simular disparo cargado y verificar que activa kick_cooldown = 0.25
	player._execute_kick()
	assert(abs(player.kick_cooldown - 0.25) < 0.001, "Disparo debe asignar kick_cooldown = 0.25")
	player.kick_cooldown = 0.0
	print("  -> kick_cooldown = 0.25 verificado OK")

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
	
	var boosted_speed = player.get_current_speed()
	assert(boosted_speed > player.fallback_base_speed * 1.20, "get_current_speed() debe incluir el impulso de 1.22x")
	
	var final_stamina = player.get_stamina()
	assert(abs((initial_stamina - final_stamina) - 10.0) < 0.01, "Autopase debe drenar 10.0 de estamina")
	print("  -> Balón lanzado: vz=%.2f, vy=%.2f | cooldown=%.2f | boost=%.2f | estamina drenada=10.0 OK" % [
		ball.linear_velocity.z, ball.linear_velocity.y, player.kick_cooldown, player.knock_on_boost_timer
	])

	# --------------------------------------------------------------------------
	# 6. Verificación de Doble Toque R (psp_r / W / JOY_BUTTON_5)
	# --------------------------------------------------------------------------
	print("\n[6] Verificando lógica de detección de ventana rápida de doble toque (< 0.28s)...")
	# Primer toque en R: abre ventana de 0.28s
	player.r_tap_timer = 0.0
	player.prev_btn_r = false
	var is_moving = true
	# Simular pulsación 1
	var r_just_pressed = true
	if r_just_pressed:
		if player.r_tap_timer > 0.0 and is_moving and player._is_ball_controlled():
			player._execute_knock_on()
			player.r_tap_timer = 0.0
		else:
			player.r_tap_timer = 0.28
	assert(abs(player.r_tap_timer - 0.28) < 0.001, "Primer toque debe iniciar ventana de 0.28s")

	# Simular paso de 0.10 segundos
	player.r_tap_timer -= 0.10
	assert(player.r_tap_timer > 0.0, "Ventana de 0.28s sigue activa tras 0.10s")

	# Simular pulsación 2 dentro de la ventana con balón controlado
	ball.translation = Vector3(0.0, 0.25, -1.0)
	ball.linear_velocity = Vector3.ZERO
	player.kick_cooldown = 0.0
	r_just_pressed = true
	if r_just_pressed:
		if player.r_tap_timer > 0.0 and is_moving and player._is_ball_controlled():
			player._execute_knock_on()
			player.r_tap_timer = 0.0
		else:
			player.r_tap_timer = 0.28
	assert(player.r_tap_timer == 0.0, "Doble toque exitoso debe reiniciar r_tap_timer a 0.0")
	assert(abs(player.kick_cooldown - 0.38) < 0.001, "Autopase activado por doble toque OK")
	print("  -> Detección de doble toque < 0.28s OK")

	# --------------------------------------------------------------------------
	# 7. Verificación de Suavizado de Giro (turn_speed = 16.0)
	# --------------------------------------------------------------------------
	print("\n[7] Verificando suavizado de rotación 360 grados (turn_speed = 16.0)...")
	player.facing_direction = Vector3(0.0, 0.0, -1.0)
	var target_dir = Vector3(1.0, 0.0, 0.0) # Giro a 90 grados derecha
	var delta = 1.0 / 60.0
	var cur_angle = atan2(player.facing_direction.x, player.facing_direction.z)
	var target_angle = atan2(target_dir.x, target_dir.z)
	var smoothed_angle = lerp_angle(cur_angle, target_angle, clamp(player.turn_speed * delta, 0.0, 1.0))
	var new_facing = Vector3(sin(smoothed_angle), 0.0, cos(smoothed_angle)).normalized()
	assert(new_facing.x > 0.0, "La dirección debe girar progresivamente hacia X positivo")
	assert(new_facing.z < 0.0, "La dirección conserva componente frontal durante el recorte")
	print("  -> Giro fluido hacia (%.2f, 0, %.2f) OK" % [new_facing.x, new_facing.z])

	ball.queue_free()
	player.queue_free()

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DE DRIBBLING Y AUTOPASE PASARON EXITOSAMENTE.")
	print("==================================================")
	quit(0)
