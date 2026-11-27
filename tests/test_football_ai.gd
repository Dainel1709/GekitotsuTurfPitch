extends SceneTree

# Test headless para validar comportamiento de FootballAI:
# 1. Velocidades moderadas de NPCs (move=4.6, dribble=4.4, sprint=6.3)
# 2. separation_radius = 4.5
# 3. Porteros anclados a Z = ±26.8

func _init():
	print("==================================================")
	print("[TEST] FootballAI - Velocidades, Separación y Porteros")
	print("==================================================")

	var pitch_scene = load("res://scenes/FootballPitch.tscn")
	assert(pitch_scene != null, "scenes/FootballPitch.tscn debe cargar correctamente")

	var pitch = pitch_scene.instance()
	root.add_child(pitch)

	# Access AI actors
	var ai_root = pitch.get_node("AIActors")
	var rival_gk = ai_root.get_node("RivalGoalkeeper")
	var ally_gk = ai_root.get_node("AllyGoalkeeper")
	var opponent1 = ai_root.get_node("Opponent1")
	var teammate1 = ai_root.get_node("Teammate1")

	# Verificar roles
	print("[Test] Rival GK role: %s" % rival_gk.role)
	assert(rival_gk.role == "goalkeeper", "RivalGoalkeeper role debe ser 'goalkeeper'")
	print("[Test] Ally GK team: %s" % str(ally_gk.is_player_team))
	assert(ally_gk.is_player_team == true, "AllyGoalkeeper debe ser del equipo del jugador")

	# Verificar velocidades base de teammates (no escaladas por matchday)
	print("\n--- Verificando velocidades base de NPCs ---")
	assert(abs(teammate1.move_speed - 4.6) < 0.01, "move_speed de teammate1 debe ser 4.6 (actual: %.2f)" % teammate1.move_speed)
	assert(abs(teammate1.dribble_speed - 4.4) < 0.01, "dribble_speed de teammate1 debe ser 4.4 (actual: %.2f)" % teammate1.dribble_speed)
	assert(abs(teammate1.sprint_speed - 6.3) < 0.01, "sprint_speed de teammate1 debe ser 6.3 (actual: %.2f)" % teammate1.sprint_speed)
	print("[Test] Velocidades teammate OK: move=4.6, dribble=4.4, sprint=6.3")

	# Opponents tienen escalado por matchday, verificar base mínima
	assert(opponent1.move_speed >= 4.6, "move_speed de opponent1 debe ser >= 4.6 (actual: %.2f)" % opponent1.move_speed)
	assert(opponent1.sprint_speed >= 6.3, "sprint_speed de opponent1 debe ser >= 6.3 (actual: %.2f)" % opponent1.sprint_speed)
	print("[Test] Velocidades opponent OK: move>=4.6, sprint>=6.3")

	# Verificar separation_radius = 4.5
	print("\n--- Verificando separation_radius ---")
	assert(abs(opponent1.separation_radius - 4.5) < 0.01, "separation_radius debe ser 4.5 (actual: %.2f)" % opponent1.separation_radius)
	assert(abs(teammate1.separation_radius - 4.5) < 0.01, "separation_radius debe ser 4.5 (actual: %.2f)" % teammate1.separation_radius)
	print("[Test] separation_radius = 4.5: OK")

	# Verificar posición de porteros
	print("\n--- Verificando posición de porteros ---")
	assert(abs(ally_gk.home_position.z - 26.8) < 0.01, "Portero aliado Z debe ser 26.8")
	assert(abs(ally_gk.home_position.x) < 0.01, "Portero aliado X debe ser 0.0")
	assert(abs(rival_gk.home_position.z - (-26.8)) < 0.01, "Portero rival Z debe ser -26.8")
	assert(abs(rival_gk.home_position.x) < 0.01, "Portero rival X debe ser 0.0")
	print("[Test] Porteros en Z = ±26.8, X = 0.0: OK")

	print("\n==================================================")
	print("TODOS LOS TESTS DE FOOTBALL AI PASARON CON ÉXITO")
	print("==================================================")
	quit(0)
