extends SceneTree

# Test headless para validar:
# 1. Conteo exacto de 11 jugadores en el equipo aliado (4-2-1-3) y 11 en el rival (Total 22).
# 2. Porteros centrados en Z = ±26.8, X = 0.0.
# 3. Separación por mitad de campo en saque inicial.
# 4. Rotación del equipo rival entre 4-4-2, 5-2-3, 4-3-3 y 5-3-2 con actualización real de posiciones tácticas.
# 5. Velocidades moderadas de NPCs.
# 6. Reinicio de los 22 jugadores tras gol en GoalArea.

func _init():
	print("==================================================")
	print("[TEST] Partidos 11v11, Formación 4-2-1-3 y Rotación Rival")
	print("==================================================")

	var pitch_scene = load("res://scenes/FootballPitch.tscn")
	assert(pitch_scene != null, "scenes/FootballPitch.tscn debe cargar correctamente")

	var pitch = pitch_scene.instance()
	root.add_child(pitch)

	# --------------------------------------------------------------------------
	# PARTE 1: Conteo Exacto de Plantillas 11 vs 11
	# --------------------------------------------------------------------------
	print("\n--- 1. Verificando Conteo 11 vs 11 (22 Jugadores en Total) ---")
	
	var players = root.get_nodes_in_group("player")
	assert(players.size() == 1, "Debe existir exactamente 1 jugador principal (Ryu)")
	var ryu = players[0]
	assert("tactical_slot" in ryu and ryu.tactical_slot == "ST", "Ryu debe ocupar el slot táctico ST en 4-2-1-3")

	var teammates = root.get_nodes_in_group("teammates")
	assert(teammates.size() == 9, "Deben existir exactamente 9 compañeros de campo (actual: %d)" % teammates.size())

	var goalkeepers = root.get_nodes_in_group("goalkeepers")
	var ally_gk = null
	var rival_gk = null
	for gk in goalkeepers:
		if "is_player_team" in gk and gk.is_player_team:
			ally_gk = gk
		elif "is_player_team" in gk and not gk.is_player_team:
			rival_gk = gk

	assert(ally_gk != null, "Debe existir un portero aliado (is_player_team = true)")
	assert(rival_gk != null, "Debe existir un portero rival (is_player_team = false)")

	var total_allies = 1 + teammates.size() + 1 # Ryu + 9 Teammates + 1 Ally GK = 11
	assert(total_allies == 11, "El equipo aliado debe sumar exactamente 11 jugadores (actual: %d)" % total_allies)
	print("  -> Plantilla Aliada: 1 Ryu (ST) + 9 Compañeros + 1 Portero = 11 jugadores: OK")

	var opponents = root.get_nodes_in_group("opponents")
	assert(opponents.size() == 10, "Deben existir exactamente 10 rivales de campo (actual: %d)" % opponents.size())
	var total_rivals = opponents.size() + 1 # 10 Opponents + 1 Rival GK = 11
	assert(total_rivals == 11, "El equipo rival debe sumar exactamente 11 jugadores (actual: %d)" % total_rivals)
	print("  -> Plantilla Rival: 10 Rivales + 1 Portero = 11 jugadores: OK")

	var total_pitch_players = total_allies + total_rivals
	assert(total_pitch_players == 22, "El partido debe tener exactamente 22 jugadores en cancha (actual: %d)" % total_pitch_players)
	print("  -> Total en Cancha: 22 jugadores simultaneos: OK")

	# --------------------------------------------------------------------------
	# PARTE 2: Posiciones exactas de Porteros (Z = ±26.8, X = 0.0)
	# --------------------------------------------------------------------------
	print("\n--- 2. Verificando Porteros centrados en arco (Z = ±26.8, X = 0.0) ---")
	
	assert(abs(ally_gk.home_position.x - 0.0) < 0.01, "Portero aliado X debe ser 0.0 (actual: %.2f)" % ally_gk.home_position.x)
	assert(abs(ally_gk.home_position.z - 26.8) < 0.01, "Portero aliado Z debe ser 26.8 (actual: %.2f)" % ally_gk.home_position.z)
	assert(abs(ally_gk.global_transform.origin.x - 0.0) < 0.1, "Portero aliado origin.x debe ser ~0.0")
	assert(abs(ally_gk.global_transform.origin.z - 26.8) < 0.1, "Portero aliado origin.z debe ser ~26.8")
	print("  -> Portero Aliado: home_position = %s, origin = %s: OK" % [str(ally_gk.home_position), str(ally_gk.global_transform.origin)])

	assert(abs(rival_gk.home_position.x - 0.0) < 0.01, "Portero rival X debe ser 0.0 (actual: %.2f)" % rival_gk.home_position.x)
	assert(abs(rival_gk.home_position.z - (-26.8)) < 0.01, "Portero rival Z debe ser -26.8 (actual: %.2f)" % rival_gk.home_position.z)
	assert(abs(rival_gk.global_transform.origin.x - 0.0) < 0.1, "Portero rival origin.x debe ser ~0.0")
	assert(abs(rival_gk.global_transform.origin.z - (-26.8)) < 0.1, "Portero rival origin.z debe ser ~-26.8")
	print("  -> Portero Rival: home_position = %s, origin = %s: OK" % [str(rival_gk.home_position), str(rival_gk.global_transform.origin)])

	# --------------------------------------------------------------------------
	# PARTE 3: Separación por mitad de campo en saque inicial
	# --------------------------------------------------------------------------
	print("\n--- 3. Verificando separación por mitad de campo en saque ---")
	
	# Ryu (ST) debe estar en Z = 0.6 (campo Sur, justo en el punto de saque)
	assert(ryu.home_position.z >= 0.0, "Ryu (ST) debe iniciar en campo Sur (Z >= 0.0), actual: %.2f" % ryu.home_position.z)
	print("  -> Ryu (ST): home_position.z = %.2f (campo Sur): OK" % ryu.home_position.z)

	# Todos los compañeros aliados deben estar en campo Sur (Z >= 0.0)
	for tm in teammates:
		assert(tm.home_position.z >= 0.0, "Compañero %s debe estar en campo Sur (Z >= 0.0), actual Z=%.2f" % [tm.tactical_slot, tm.home_position.z])
	print("  -> 9 Compañeros aliados en campo Sur (Z >= 0.0): OK")

	# Portero aliado en campo Sur (Z > 0)
	assert(ally_gk.home_position.z > 0.0, "Portero aliado debe estar en campo Sur")
	print("  -> Portero aliado en campo Sur: OK")

	# Todos los rivales de campo deben estar en campo Norte (Z <= -1.5)
	for opp in opponents:
		assert(opp.home_position.z <= -1.5, "Rival %s debe estar en campo Norte (Z <= -1.5), actual Z=%.2f" % [opp.tactical_slot, opp.home_position.z])
	print("  -> 10 Rivales de campo en campo Norte (Z <= -1.5): OK")

	# Portero rival en campo Norte (Z < 0)
	assert(rival_gk.home_position.z < 0.0, "Portero rival debe estar en campo Norte")
	print("  -> Portero rival en campo Norte: OK")

	# --------------------------------------------------------------------------
	# PARTE 4: Formación Aliada 4-2-1-3
	# --------------------------------------------------------------------------
	print("\n--- 4. Verificando Formación Aliada Fija 4-2-1-3 ---")
	var expected_ally_slots = ["LB", "LCB", "RCB", "RB", "LDM", "RDM", "CAM", "LW", "RW"]
	var found_ally_slots = []
	for tm in teammates:
		assert("tactical_slot" in tm, "Cada compañero debe tener tactical_slot")
		found_ally_slots.append(tm.tactical_slot)
		assert("home_position" in tm and tm.home_position != Vector3.ZERO, "Cada compañero debe tener home_position definida")
		assert("formation_name" in tm and tm.formation_name == "4-2-1-3", "Formacion aliada debe ser 4-2-1-3")

	for expected_slot in expected_ally_slots:
		assert(expected_slot in found_ally_slots, "El slot aliado %s debe estar asignado en 4-2-1-3" % expected_slot)
	print("  -> Slots tácticos aliados (4 DEF, 2 CDM, 1 CAM, 2 WING + Ryu ST): OK")

	# --------------------------------------------------------------------------
	# PARTE 5: Velocidades moderadas de NPCs
	# --------------------------------------------------------------------------
	print("\n--- 5. Verificando Velocidades moderadas de NPCs ---")
	
	# Verificar velocidades base de los NPCs (sin escalado por matchday)
	# Los opponents pueden tener escalado aplicado, así que verificamos los teammates
	# cuyas velocidades base deben ser las nuevas
	for tm in teammates:
		assert(abs(tm.move_speed - 4.6) < 0.01, "Teammate move_speed debe ser 4.6 (actual: %.2f)" % tm.move_speed)
		assert(abs(tm.dribble_speed - 4.4) < 0.01, "Teammate dribble_speed debe ser 4.4 (actual: %.2f)" % tm.dribble_speed)
		assert(abs(tm.sprint_speed - 6.3) < 0.01, "Teammate sprint_speed debe ser 6.3 (actual: %.2f)" % tm.sprint_speed)
		break # Solo necesitamos verificar uno
	print("  -> Velocidades NPC teammate: move=4.6, dribble=4.4, sprint=6.3: OK")

	# Verificar que separation_radius es 4.5
	for tm in teammates:
		assert(abs(tm.separation_radius - 4.5) < 0.01, "separation_radius debe ser 4.5 (actual: %.2f)" % tm.separation_radius)
		break
	print("  -> separation_radius = 4.5: OK")

	# --------------------------------------------------------------------------
	# PARTE 6: Rotación Táctica del Equipo Rival (4-4-2, 5-2-3, 4-3-3, 5-3-2)
	# --------------------------------------------------------------------------
	print("\n--- 6. Verificando Rotación Táctica Rival (4-4-2, 5-2-3, 4-3-3, 5-3-2) ---")
	var formations_to_test = ["4-4-2", "5-2-3", "4-3-3", "5-3-2"]
	for form in formations_to_test:
		pitch.set_rival_formation(form)
		assert(pitch.current_rival_formation == form, "current_rival_formation debe ser %s" % form)
		for opp in opponents:
			assert(opp.formation_name == form, "Cada rival debe tener formation_name = %s" % form)
			assert(opp.home_position != Vector3.ZERO, "home_position no debe ser Vector3.ZERO")
			assert(opp.home_position.z < 0.0, "La posición táctica rival debe estar en campo Norte (Z < 0): Z=%.1f" % opp.home_position.z)

		var first_opp_slot = opponents[0].tactical_slot
		var first_opp_pos = opponents[0].home_position
		print("  -> Formación Rival [%s] aplicada: Slot[0]=%s en pos %s: OK" % [form, first_opp_slot, str(first_opp_pos)])

	# --------------------------------------------------------------------------
	# PARTE 7: Reinicio de los 22 Jugadores tras Gol
	# --------------------------------------------------------------------------
	print("\n--- 7. Verificando Reinicio de los 22 Jugadores tras Gol ---")
	var rival_goal = pitch.get_node_or_null("RivalGoalArea")
	assert(rival_goal != null, "RivalGoalArea debe existir en FootballPitch")

	# Desplazar a todos los 22 jugadores fuera de sus home_positions
	ryu.global_transform.origin = Vector3(15.0, 0.8, 15.0)
	ally_gk.global_transform.origin = Vector3(5.0, 0.8, 5.0)
	rival_gk.global_transform.origin = Vector3(-5.0, 0.8, -5.0)
	for tm in teammates:
		tm.global_transform.origin = Vector3(10.0, 0.8, 10.0)
	for opp in opponents:
		opp.global_transform.origin = Vector3(-10.0, 0.8, -10.0)

	# Invocar el reseteo de actores que se dispara con el gol
	rival_goal._reset_all_actors()

	# Validar que Ryu regresa a su home_position
	assert(ryu.global_transform.origin.distance_to(ryu.home_position) < 0.1, "Ryu debe ser reiniciado a su home_position")

	# Validar que portero aliado y rival regresan a su home_position
	assert(ally_gk.global_transform.origin.distance_to(ally_gk.home_position) < 0.1, "Portero aliado debe reiniciarse en home_position")
	assert(rival_gk.global_transform.origin.distance_to(rival_gk.home_position) < 0.1, "Portero rival debe reiniciarse en home_position")

	# Validar que los 9 compañeros regresan a sus home_positions
	for i in range(teammates.size()):
		var tm = teammates[i]
		assert(tm.global_transform.origin.distance_to(tm.home_position) < 0.1, "Compañero %d debe reiniciarse en su home_position" % i)

	# Validar que los 10 rivales regresan a sus home_positions
	for i in range(opponents.size()):
		var opp = opponents[i]
		assert(opp.global_transform.origin.distance_to(opp.home_position) < 0.1, "Rival %d debe reiniciarse en su home_position" % i)

	# Verificar que porteros vuelven a Z = ±26.8 tras gol
	assert(abs(ally_gk.global_transform.origin.z - 26.8) < 0.1, "Portero aliado tras gol debe estar en Z=26.8")
	assert(abs(rival_gk.global_transform.origin.z - (-26.8)) < 0.1, "Portero rival tras gol debe estar en Z=-26.8")
	assert(abs(ally_gk.global_transform.origin.x) < 0.1, "Portero aliado tras gol debe estar en X=0.0")
	assert(abs(rival_gk.global_transform.origin.x) < 0.1, "Portero rival tras gol debe estar en X=0.0")

	print("  -> Reinicio tras gol de los 22 actores a sus respectivas home_positions: OK")
	print("  -> Porteros vuelven a Z = ±26.8, X = 0.0 tras gol: OK")

	print("\n==================================================")
	print("TODOS LOS TESTS 11v11 PASARON CON ÉXITO")
	print("==================================================")
	quit(0)
