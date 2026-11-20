extends Node

# Headless test for key F opponent freezing and assisted teammate passing

func _ready():
	print("==================================================")
	print("[TEST] Verificación de Frenado de Rivales (Tecla F) y Pase Asistido")
	print("==================================================")

	var pitch_scene = load("res://scenes/FootballPitch.tscn")
	assert(pitch_scene != null, "No se pudo cargar FootballPitch.tscn")
	var pitch = pitch_scene.instance()
	assert(pitch != null, "No se pudo instanciar FootballPitch")
	add_child(pitch)

	yield(get_tree(), "idle_frame")

	var player = pitch.get_node("Player")
	var ball = pitch.get_node("FootballBall")
	var ai_root = pitch.get_node("AIActors")
	var opponent1 = ai_root.get_node("Opponent1")
	var teammate1 = ai_root.get_node("Teammate1")

	assert(player != null, "Player no encontrado")
	assert(ball != null, "FootballBall no encontrado")
	assert(opponent1 != null, "Opponent1 no encontrado")
	assert(teammate1 != null, "Teammate1 no encontrado")

	# =========================================================================
	# PARTE 1: Verificación de Frenado / Pausado de Rivales (Tecla F)
	# =========================================================================
	print("\n[1] Verificando estado inicial de los rivales...")
	assert(not opponent1.is_frozen_for_test, "is_frozen_for_test inicial debe ser false")
	assert(opponent1.test_freeze_timer == 0.0, "test_freeze_timer inicial debe ser 0.0")

	print("\n[2] Verificando congelamiento indefinido con tecla F (_toggle_opponents_freeze)...")
	player._toggle_opponents_freeze(false)
	assert(player.opponents_frozen, "Player.opponents_frozen debe ser true tras toggle")
	assert(opponent1.is_frozen_for_test, "opponent1.is_frozen_for_test debe ser true")
	assert(opponent1.velocity == Vector3.ZERO, "opponent1.velocity debe ser Vector3.ZERO al congelar")

	# Simular un frame de física con rival congelado cerca del balón
	ball.global_transform.origin = opponent1.global_transform.origin + Vector3(0.3, 0.0, 0.0)
	var pos_before = opponent1.global_transform.origin
	opponent1._physics_process(0.016)
	assert(opponent1.global_transform.origin == pos_before, "Rival congelado no debe cambiar de posición")
	assert(opponent1.velocity == Vector3.ZERO, "Rival congelado debe mantener velocity en ZERO")
	assert(not opponent1.has_ball, "Rival congelado NO debe robar el balón")
	assert(not opponent1.is_dribbling, "Rival congelado NO debe estar en conducción")
	print("  -> Rival congelado no se mueve ni roba el balón OK")

	print("\n[3] Verificando descongelamiento con toggle...")
	player._toggle_opponents_freeze(false)
	assert(not player.opponents_frozen, "Player.opponents_frozen debe ser false tras segundo toggle")
	assert(not opponent1.is_frozen_for_test, "opponent1.is_frozen_for_test debe ser false")
	print("  -> Rival descongelado OK")

	print("\n[4] Verificando congelamiento por pulso temporizado (1.5s)...")
	player._toggle_opponents_freeze(true)
	assert(opponent1.is_frozen_for_test, "opponent1.is_frozen_for_test debe ser true en pulso")
	assert(abs(opponent1.test_freeze_timer - 1.5) < 0.001, "test_freeze_timer debe ser 1.5s")
	
	# Simular paso del tiempo hasta expirar el pulso
	opponent1._physics_process(1.6)
	assert(not opponent1.is_frozen_for_test, "is_frozen_for_test debe limpiarse tras expirar el timer")
	assert(opponent1.test_freeze_timer == 0.0, "test_freeze_timer debe llegar a 0.0")
	print("  -> Pulso temporizado de 1.5s y auto-descongelamiento OK")

	# =========================================================================
	# PARTE 2: Verificación de Pase Asistido Hacia Compañero Aliado
	# =========================================================================
	print("\n[5] Verificando pase asistido corto (Z) hacia compañero aliado...")
	# Congelar rivales para que no interfieran en la prueba de pases
	player._toggle_opponents_freeze(false)

	# Colocar Player en el origen mirando hacia el Norte (-Z)
	player.global_transform.origin = Vector3(0.0, 0.8, 0.0)
	player.facing_direction = Vector3(0.0, 0.0, -1.0)
	player.velocity = Vector3.ZERO
	player.manual_aim_mode = false

	# Posicionar compañero aliado en ángulo diagonal hacia adelante (+X, -Z)
	teammate1.global_transform.origin = Vector3(5.0, 0.8, -10.0)

	# Balón controlado por Player
	ball.global_transform.origin = Vector3(0.0, 0.25, -0.6)
	ball.linear_velocity = Vector3.ZERO
	player.ball_ref = ball
	player.is_dribbling = true
	player.is_ball_controlled = true
	player.kick_cooldown = 0.0

	# Ejecutar pase corto raso
	player._execute_short_pass()

	# El impulso debe tener componente X positivo corrigiendo hacia el compañero en X=5
	print("  -> Impulso balón tras pase corto asistido: ", ball.linear_velocity)
	assert(ball.linear_velocity.x > 0.5, "El pase corto debe asistir corrigiendo la trayectoria hacia el compañero (X > 0.5)")
	assert(ball.linear_velocity.z < -5.0, "El pase corto debe avanzar hacia adelante en -Z")
	print("  -> Asistencia de pase corto hacia compañero aliado OK")

	print("\n[6] Verificando pase en profundidad asistido (S / Triángulo)...")
	# Re-vincular balón
	ball.global_transform.origin = Vector3(0.0, 0.25, -0.6)
	ball.linear_velocity = Vector3.ZERO
	player.is_dribbling = true
	player.is_ball_controlled = true
	player.kick_cooldown = 0.0

	player._execute_through_pass()
	print("  -> Impulso balón tras pase en profundidad asistido: ", ball.linear_velocity)
	assert(ball.linear_velocity.x > 0.5, "El pase en profundidad debe asistir hacia el espacio del compañero (X > 0.5)")
	assert(ball.linear_velocity.z < -8.0, "El pase en profundidad debe tener buena fuerza hacia adelante (Z < -8.0)")
	print("  -> Asistencia de pase en profundidad OK")

	print("\n[7] Verificando respeto a manual_aim_mode (sin asistencia teledirigida)...")
	player.manual_aim_mode = true
	ball.global_transform.origin = Vector3(0.0, 0.25, -0.6)
	ball.linear_velocity = Vector3.ZERO
	player.is_dribbling = true
	player.is_ball_controlled = true
	player.kick_cooldown = 0.0

	player._execute_short_pass()
	print("  -> Impulso balón con manual_aim_mode: ", ball.linear_velocity)
	# Con manual_aim_mode = true y facing (0, 0, -1), el componente X no debe desviarse hacia el compañero
	assert(abs(ball.linear_velocity.x) < 0.001, "Con manual_aim_mode activo, la dirección no debe autocorregirse hacia el compañero")
	print("  -> Respeto estricto de manual_aim_mode OK")

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DE FRENADO Y PASE ASISTIDO PASARON EXITOSAMENTE.")
	print("==================================================")
	get_tree().quit()
