extends SceneTree

# Test headless para validar:
# 1. Eliminación de toda mención o mecánica de carreras clandestinas/callejeras.
# 2. Transición cinematográfica (zoom en PitchCamera y flash en PitchHUD).
# 3. Consecuencias arbitrales: Tarjeta Amarilla en 1er duelo y Tarjeta Roja en 2do duelo (expulsión).
# 4. Ciclo de Jornadas de Liga y persistencia en user://savegame.json.

func _init():
	print("==================================================")
	print("[TEST] Fútbol + Peleas, Transición Cinematográfica, Tarjetas y Guardado de Liga")
	print("==================================================")

	# --------------------------------------------------------------------------
	# PARTE 1: Verificación de eliminación de referencias a carreras
	# --------------------------------------------------------------------------
	print("\n--- 1. Verificando eliminación de referencias a carreras ---")
	var main_game_scene = load("res://scenes/MainGame.tscn")
	assert(main_game_scene != null, "MainGame.tscn debe cargar correctamente")

	var main_game = main_game_scene.instance()
	root.add_child(main_game)

	# Verificar que el texto inicial de la decisión en MainGame.gd no mencione 'carrera'
	var meta_stats = main_game._get_persistent_stats()
	var desc_text = main_game.description_label.text.to_lower()
	assert(not "carrera clandestina" in desc_text, "MainGame no debe mencionar carreras clandestinas")
	assert(not "carrera callejera" in desc_text, "MainGame no debe mencionar carreras callejeras")
	assert("pelea clandestina" in desc_text or "cantera" in desc_text, "Debe enfocarse en fútbol y peleas")
	print("  -> Textos en Hub y decisiones sin referencias a carreras: OK")

	# --------------------------------------------------------------------------
	# PARTE 2: Transición cinematográfica (PitchCamera y PitchHUD)
	# --------------------------------------------------------------------------
	print("\n--- 2. Verificando Transición Cinematográfica (PitchCamera y PitchHUD) ---")
	var cam_script = load("res://scripts/PitchCamera.gd")
	var hud_script = load("res://scripts/PitchHUD.gd")
	assert(cam_script != null, "PitchCamera.gd debe cargar correctamente")
	assert(hud_script != null, "PitchHUD.gd debe cargar correctamente")

	var camera = Camera.new()
	camera.set_script(cam_script)
	root.add_child(camera)
	assert(camera.is_in_group("pitch_camera"), "PitchCamera debe registrarse en grupo pitch_camera")

	var hud = CanvasLayer.new()
	hud.set_script(hud_script)
	var hud_ctrl = Control.new()
	hud_ctrl.name = "HUDControl"
	var goal_label = Label.new()
	goal_label.name = "GoalNoticeLabel"
	hud_ctrl.add_child(goal_label)
	hud.add_child(hud_ctrl)
	root.add_child(hud)
	assert(hud.is_in_group("pitch_hud"), "PitchHUD debe registrarse en grupo pitch_hud")

	# 2.1 Zoom de cámara hacia punto medio
	var test_midpoint = Vector3(4.0, 0.0, -10.0)
	camera.start_cinematic_zoom(test_midpoint)
	assert(camera.is_cinematic_zoom == true, "PitchCamera debe entrar en is_cinematic_zoom = true")
	assert(camera.cinematic_target_pos == test_midpoint, "PitchCamera debe guardar el punto medio objetivo")
	camera._process(0.016)
	assert(camera.translation.y < 35.0, "La cámara debe descender en altura para el plano dramático")

	# 2.2 Restauración suave de cámara
	camera.reset_cinematic_zoom()
	assert(camera.is_cinematic_zoom == false, "PitchCamera debe desactivar is_cinematic_zoom al resetear")
	print("  -> Zoom dramático de PitchCamera y restauración: OK")

	# 2.3 Flash y banner de entrada en PitchHUD
	hud.play_brawl_transition("¡CHISPA EN EL CÉSPED! ¡DUELO 1 VS 1!")
	assert(hud.flash_rect != null, "PitchHUD debe generar FlashRect")
	assert(hud.goal_notice_label != null, "GoalNoticeLabel debe existir")
	assert(hud.goal_notice_label.text == "¡CHISPA EN EL CÉSPED! ¡DUELO 1 VS 1!", "Banner debe mostrar ¡CHISPA EN EL CÉSPED!")
	print("  -> Flash de pantalla y banner de entrada en PitchHUD: OK")

	# --------------------------------------------------------------------------
	# PARTE 3: Consecuencias Arbitrales (Tarjeta Amarilla y Roja)
	# --------------------------------------------------------------------------
	print("\n--- 3. Verificando Consecuencias Arbitrales en Duelos de Cancha ---")
	var player_script = load("res://scripts/Player.gd")
	var player = KinematicBody.new()
	player.set_script(player_script)
	root.add_child(player)

	var opponent = KinematicBody.new()
	var ai_script = load("res://scripts/FootballAI.gd")
	opponent.set_script(ai_script)
	opponent.role = "opponent"
	root.add_child(opponent)

	# 3.1 Primer duelo: Tarjeta Amarilla y descuento de Disciplina
	root.set_meta("gtp_stats", {
		"discipline": 50,
		"combat": 20,
		"money": 100,
		"reputation": 10,
		"matchday": 1,
		"league_wins": 0,
		"league_losses": 0,
		"day": 1
	})
	player.pitch_brawls_count = 0
	player.discipline_stat = 50

	# Simular fin del 1er duelo con victoria de Ryu
	player._on_brawl_finished(true, null, opponent)
	assert(player.pitch_brawls_count == 1, "pitch_brawls_count debe ser 1 tras el 1er duelo")
	assert(opponent.stun_timer == 7.0, "Rival debe recibir 7.0s de aturdimiento tras victoria de Ryu")
	var stats_after_1 = root.get_meta("gtp_stats")
	assert(stats_after_1["discipline"] < 50, "Debe descontarse Disciplina tras el 1er duelo")
	print("  -> 1er Duelo: Tarjeta Amarilla, disciplina descontada y rival aturdido 7.0s: OK")

	# 3.2 Segundo duelo: Tarjeta Roja y finalización por descalificación
	player._on_brawl_finished(true, null, opponent)
	assert(player.pitch_brawls_count == 2, "pitch_brawls_count debe ser 2 tras el 2do duelo")
	var stats_after_2 = root.get_meta("gtp_stats")
	assert(stats_after_2["league_losses"] >= 1, "El 2do duelo debe registrar derrota por descalificación")
	assert(hud.match_finished == true, "El partido debe terminar tras la Tarjeta Roja")
	print("  -> 2do Duelo: Tarjeta Roja, expulsión y derrota registrada en liga: OK")

	# --------------------------------------------------------------------------
	# PARTE 4: Ciclo de Jornadas de Liga y Guardado en user://savegame.json
	# --------------------------------------------------------------------------
	print("\n--- 4. Verificando Jornadas de Liga y Guardado en user://savegame.json ---")
	var gs = root.get_node_or_null("GameSettings")
	if not gs:
		var gs_script = load("res://scripts/autoload/GameSettings.gd")
		gs = Node.new()
		gs.name = "GameSettings"
		gs.set_script(gs_script)
		root.add_child(gs)

	# 4.1 Resetear savegame previo
	gs.reset_save()
	var default_prog = gs.load_progress()
	assert(default_prog["matchday"] == 1, "Jornada inicial debe ser 1")
	assert(default_prog["league_wins"] == 0, "Victorias iniciales deben ser 0")
	assert(default_prog["league_losses"] == 0, "Derrotas iniciales deben ser 0")

	# 4.2 Guardar progreso nuevo y verificar persistencia
	var test_data = {
		"matchday": 3,
		"league_wins": 2,
		"league_losses": 1,
		"discipline": 35,
		"combat": 40,
		"money": 600,
		"reputation": 25,
		"control_scheme": 1
	}
	var save_ok = gs.save_progress(test_data)
	assert(save_ok == true, "save_progress debe retornar true")
	assert(gs.has_save() == true, "has_save() debe ser true tras guardar")

	var loaded = gs.load_progress()
	assert(loaded["matchday"] == 3, "Jornada cargada debe ser 3")
	assert(loaded["league_wins"] == 2, "Victorias cargadas deben ser 2")
	assert(loaded["league_losses"] == 1, "Derrotas cargadas deben ser 1")
	assert(loaded["discipline"] == 35, "Disciplina cargada debe ser 35")
	assert(loaded["combat"] == 40, "Combate cargado debe ser 40")
	assert(loaded["control_scheme"] == 1, "Esquema de controles cargado debe ser 1")
	print("  -> Guardado y carga en user://savegame.json: OK")

	# 4.3 Verificación de rival según jornada en MainGame
	var r1 = main_game.get_current_rival_name(1)
	var r2 = main_game.get_current_rival_name(2)
	var r3 = main_game.get_current_rival_name(3)
	assert(r1 == "Barrio Norte FC", "Rival de jornada 1 debe ser Barrio Norte FC")
	assert(r2 == "Deportivo Callejón", "Rival de jornada 2 debe ser Deportivo Callejón")
	assert(r3 == "Atlético San Cristóbal", "Rival de jornada 3 debe ser Atlético San Cristóbal")
	print("  -> Asignación secuencial de rivales de liga: OK")

	# 4.4 Verificación de escalado de velocidad de IA rival según jornada
	var opp_jornada_1 = KinematicBody.new()
	opp_jornada_1.set_script(ai_script)
	opp_jornada_1.role = "opponent"
	gs.save_progress({"matchday": 1})
	root.add_child(opp_jornada_1)

	var opp_jornada_5 = KinematicBody.new()
	opp_jornada_5.set_script(ai_script)
	opp_jornada_5.role = "opponent"
	gs.save_progress({"matchday": 5})
	root.add_child(opp_jornada_5)

	assert(opp_jornada_5.move_speed > opp_jornada_1.move_speed, "IA rival en jornada 5 debe ser más rápida que en jornada 1")
	assert(opp_jornada_5.sprint_speed > opp_jornada_1.sprint_speed, "Sprint de IA rival en jornada 5 debe ser mayor que en jornada 1")
	print("  -> Escalado dinámico de velocidad de IA rival según la jornada de liga: OK")

	# Limpieza
	camera.free()
	hud.free()
	player.free()
	opponent.free()
	opp_jornada_1.free()
	opp_jornada_5.free()
	main_game.free()
	gs.reset_save()

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DE FÚTBOL + PELEAS, TARJETAS Y LIGA PASARON EXITOSAMENTE.")
	print("==================================================")
	quit(0)
