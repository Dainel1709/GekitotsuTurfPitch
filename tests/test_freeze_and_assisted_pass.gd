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
	# PARTE 1: Verificación de Frenado / Pausado de Rivales y Compañero (Tecla F)
	# =========================================================================
	print("\n[1] Verificando estado inicial de rivales y compañero...")
	assert(not opponent1.is_frozen_for_test, "is_frozen_for_test inicial de rival debe ser false")
	assert(not teammate1.is_frozen_for_test, "is_frozen_for_test inicial de compañero debe ser false")
	assert(opponent1.test_freeze_timer == 0.0, "test_freeze_timer inicial debe ser 0.0")
	assert(teammate1.test_freeze_timer == 0.0, "test_freeze_timer de compañero debe ser 0.0")

	print("\n[2] Verificando congelamiento indefinido con tecla F (_toggle_opponents_freeze)...")
	player._toggle_opponents_freeze(false)
	assert(player.opponents_frozen, "Player.opponents_frozen debe ser true tras toggle")
	assert(opponent1.is_frozen_for_test, "opponent1.is_frozen_for_test debe ser true")
	assert(teammate1.is_frozen_for_test, "teammate1.is_frozen_for_test debe ser true con F")
	assert(opponent1.velocity == Vector3.ZERO, "opponent1.velocity debe ser Vector3.ZERO al congelar")
	assert(teammate1.velocity == Vector3.ZERO, "teammate1.velocity debe ser Vector3.ZERO al congelar")

	# Simular un frame de física con rival y compañero congelados cerca del balón
	ball.global_transform.origin = opponent1.global_transform.origin + Vector3(0.3, 0.0, 0.0)
	var pos_opp_before = opponent1.global_transform.origin
	var pos_team_before = teammate1.global_transform.origin
	opponent1._physics_process(0.016)
	teammate1._physics_process(0.016)
	assert(opponent1.global_transform.origin == pos_opp_before, "Rival congelado no debe cambiar de posición")
	assert(teammate1.global_transform.origin == pos_team_before, "Compañero congelado no debe cambiar de posición")
	assert(opponent1.velocity == Vector3.ZERO, "Rival congelado debe mantener velocity en ZERO")
	assert(teammate1.velocity == Vector3.ZERO, "Compañero congelado debe mantener velocity en ZERO")
	assert(not opponent1.has_ball, "Rival congelado NO debe robar el balón")
	assert(not teammate1.has_ball, "Compañero congelado NO debe tomar el balón")
	print("  -> Rivales y compañero congelados no se mueven ni interactúan con el balón OK")

	print("\n[3] Verificando descongelamiento con toggle...")
	player._toggle_opponents_freeze(false)
	assert(not player.opponents_frozen, "Player.opponents_frozen debe ser false tras segundo toggle")
	assert(not opponent1.is_frozen_for_test, "opponent1.is_frozen_for_test debe ser false")
	assert(not teammate1.is_frozen_for_test, "teammate1.is_frozen_for_test debe ser false")
	print("  -> Rivales y compañero descongelados OK")

	print("\n[4] Verificando congelamiento por pulso temporizado (1.5s)...")
	player._toggle_opponents_freeze(true)
	assert(opponent1.is_frozen_for_test, "opponent1.is_frozen_for_test debe ser true en pulso")
	assert(teammate1.is_frozen_for_test, "teammate1.is_frozen_for_test debe ser true en pulso")
	assert(abs(opponent1.test_freeze_timer - 1.5) < 0.001, "opponent1.test_freeze_timer debe ser 1.5s")
	assert(abs(teammate1.test_freeze_timer - 1.5) < 0.001, "teammate1.test_freeze_timer debe ser 1.5s")
	
	# Simular paso del tiempo hasta expirar el pulso
	opponent1._physics_process(1.6)
	teammate1._physics_process(1.6)
	assert(not opponent1.is_frozen_for_test, "opponent1.is_frozen_for_test debe limpiarse tras expirar el timer")
	assert(not teammate1.is_frozen_for_test, "teammate1.is_frozen_for_test debe limpiarse tras expirar el timer")
	assert(opponent1.test_freeze_timer == 0.0, "opponent1.test_freeze_timer debe llegar a 0.0")
	assert(teammate1.test_freeze_timer == 0.0, "teammate1.test_freeze_timer debe llegar a 0.0")
	print("  -> Pulso temporizado de 1.5s y auto-descongelamiento de ambos OK")

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

	# =========================================================================
	# PARTE 3: Petición de Balón con L (Q / L1) -> Pase + Desmarque sin Quitar Balón
	# =========================================================================
	print("\n[8] Verificando pase del compañero al pedir el balón con L (posesión previa)...")
	# Configurar posiciones: Ryu en cancha propia (Z=3.0), compañero más adelantado (Z=-2.0, X=4.0)
	player.global_transform.origin = Vector3(0.0, 0.8, 3.0)
	player.facing_direction = Vector3(0.0, 0.0, -1.0)
	player.velocity = Vector3.ZERO
	player.is_dribbling = false
	player.is_ball_controlled = false
	player.kick_cooldown = 0.0

	teammate1.global_transform.origin = Vector3(4.0, 0.8, -2.0)
	teammate1.is_frozen_for_test = false
	teammate1.test_freeze_timer = 0.0
	teammate1.has_ball = true
	teammate1.is_dribbling = true
	teammate1.unmark_timer = 0.0
	teammate1.pass_to_player_cooldown = 0.0
	teammate1.possession_cooldown = 0.0

	ball.global_transform.origin = teammate1.global_transform.origin + Vector3(0.0, -0.5, -0.3)
	ball.linear_velocity = Vector3.ZERO

	# Ryu pide el balón con botón L
	player._on_button_l_pressed()

	# 1. El compañero debe soltar el balón y pasarlo hacia Ryu (Z > 0)
	assert(not teammate1.has_ball, "Compañero debe soltar posesión (has_ball = false)")
	assert(not teammate1.is_dribbling, "Compañero no debe estar en dribbling")
	assert(teammate1.unmark_timer > 0.0, "unmark_timer debe estar activo tras el pase")
	assert(teammate1.pass_to_player_cooldown > 0.0, "pass_to_player_cooldown debe estar activo")
	assert(ball.linear_velocity.z > 2.0, "El pase debe salir impulsado hacia la posición de Ryu (Z positivo)")
	print("  -> Pase hacia Ryu ejecutado con éxito. Balón vel Z: %.2f" % ball.linear_velocity.z)

	# 2. Durante el desmarque (unmark_timer activo), el compañero no debe quitar el balón a Ryu
	print("\n[9] Verificando estado de desmarque y no-intercepción del compañero...")
	# Simular que el balón llega a los pies de Ryu y el compañero está cerca
	ball.global_transform.origin = player.global_transform.origin + Vector3(0.0, -0.5, -0.6)
	player.is_dribbling = true
	player.is_ball_controlled = true

	# Colocar al compañero en trayectoria o cerca de Ryu
	teammate1.global_transform.origin = player.global_transform.origin + Vector3(1.5, 0.0, 0.0)
	teammate1._physics_process(0.032)

	assert(not teammate1.has_ball, "Compañero en desmarque NO debe quitarle el balón a Ryu")
	assert(not teammate1.is_dribbling, "Compañero en desmarque no debe driblear")
	# Debe moverse alejándose de Ryu hacia una zona abierta
	assert(teammate1.velocity.length() > 0.1, "Compañero debe estar en movimiento desmarcándose")
	print("  -> Compañero se desmarca activamente sin quitarle la posesión a Ryu OK")

	print("\n[10] Verificando petición con L cuando el balón está suelto a <= 4.5m del compañero...")
	teammate1.unmark_timer = 0.0
	teammate1.pass_to_player_cooldown = 0.0
	teammate1.has_ball = false
	teammate1.is_dribbling = false
	teammate1.global_transform.origin = Vector3(5.0, 0.8, -3.0)

	player.is_dribbling = false
	player.is_ball_controlled = false
	player.global_transform.origin = Vector3(0.0, 0.8, 4.0)

	# Balón suelto a 2.5m de teammate1 y lejos de Ryu (> 5m)
	ball.global_transform.origin = Vector3(4.0, 0.25, -2.0)
	ball.linear_velocity = Vector3.ZERO

	player._on_button_l_pressed()
	assert(ball.linear_velocity.z > 2.0, "El compañero debe patear el balón suelto hacia Ryu")
	assert(teammate1.unmark_timer > 0.0, "unmark_timer debe activarse al pasar balón suelto")
	print("  -> Compañero asiste el balón suelto a <= 4.5m y se desmarca OK")

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DE FRENADO, PASE ASISTIDO Y DESMARQUE PASARON EXITOSAMENTE.")
	print("==================================================")
	get_tree().quit()
