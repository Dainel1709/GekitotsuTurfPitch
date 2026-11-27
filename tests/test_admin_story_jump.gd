extends SceneTree

# Test: Verifica que el Panel Admin (F12) puede saltar a todos los nodos y finales del árbol.

func _init():
	print("==================================================")
	print("[TEST] Verificando Panel Admin — Saltos del Árbol Narrativo...")
	print("==================================================")

	# Preparar GameSettings (reutilizar autoload si ya existe en /root/GameSettings)
	var gs = root.get_node_or_null("GameSettings")
	if gs == null:
		var gs_script = load("res://scripts/autoload/GameSettings.gd")
		assert(gs_script != null, "GameSettings.gd debe cargar")
		gs = Node.new()
		gs.name = "GameSettings"
		gs.set_script(gs_script)
		root.add_child(gs)

	# Cargar AdminStoryTree
	var admin_script = load("res://scripts/AdminStoryTree.gd")
	assert(admin_script != null, "AdminStoryTree.gd debe cargar")

	# --------------------------------------------------------------------------
	# 1. Verificar que AdminStoryTree.gd se instancia correctamente
	# --------------------------------------------------------------------------
	print("\n[1] Verificando instanciación de AdminStoryTree...")
	var admin = Control.new()
	admin.set_script(admin_script)
	root.add_child(admin)
	assert(admin != null, "AdminStoryTree debe instanciarse")
	assert(admin.visible == false, "AdminStoryTree debe iniciar oculto (visible == false)")
	assert(admin.has_method("refresh_tree"), "Debe tener método refresh_tree")
	assert(admin.has_method("_on_jump_pressed"), "Debe tener método _on_jump_pressed")

	# Verificar toggle con F12
	var f12_ev = InputEventKey.new()
	f12_ev.scancode = KEY_F12
	f12_ev.pressed = true
	f12_ev.echo = false
	admin._input(f12_ev)
	assert(admin.visible == true, "F12 debe mostrar AdminStoryTree")
	admin._input(f12_ev)
	assert(admin.visible == false, "F12 por segunda vez debe ocultar AdminStoryTree")
	print("  -> Instanciación, ocultamiento inicial y toggle F12 OK")

	# --------------------------------------------------------------------------
	# 2. Verificar saltos a todas las fases válidas
	# --------------------------------------------------------------------------
	print("\n[2] Verificando saltos a fases...")
	var phases_to_test = ["CREATE_PLAYER", "PROLOGUE_HIT", "SELECT_ACADEMY", "LEAGUE", "MID_J4_OFFER", "AMBUSH_J6_BRAWL", "POST_J8_CHOICE", "FINAL_BRAWL"]

	for phase in phases_to_test:
		gs.reset_save()
		gs.story_phase = "LEAGUE"
		gs.ending_id = ""
		admin._on_jump_pressed(phase)
		assert(gs.story_phase == phase, "Tras saltar, story_phase debe ser '%s', fue '%s'" % [phase, gs.story_phase])
		assert(gs.ending_id == "", "ending_id debe estar vacío en fases no-ending")
		print("  -> Salto a %s: OK" % phase)

	# --------------------------------------------------------------------------
	# 3. Verificar saltos a todos los finales
	# --------------------------------------------------------------------------
	print("\n[3] Verificando saltos a todos los 8 finales...")
	var endings_to_test = [
		"EXPELLED_EARLY",
		"PRO_FIGHTER_EARLY",
		"HOSPITAL_DREAM_BAD",
		"PRO_FIGHTER_J8",
		"GOLDEN_BOY_CHAMPION",
		"LEAGUE_CHAMPION",
		"PRO_RUNNER_UP",
		"RELEASED_BAD"
	]

	for end_id in endings_to_test:
		gs.reset_save()
		gs.story_phase = "LEAGUE"
		gs.ending_id = ""
		admin._on_jump_pressed(end_id)
		assert(gs.story_phase == "ENDING", "Tras saltar a ending, story_phase debe ser 'ENDING', fue '%s'" % gs.story_phase)
		assert(gs.ending_id == end_id, "ending_id debe ser '%s', fue '%s'" % [end_id, gs.ending_id])
		if end_id == "GOLDEN_BOY_CHAMPION":
			assert(gs.goals_scored + gs.assists > 11, "Salto a GOLDEN_BOY_CHAMPION debe configurar G+A > 11")
		print("  -> Salto a %s: OK" % end_id)

	# --------------------------------------------------------------------------
	# 4. Verificar que MID_J4_OFFER configura stats coherentes
	# --------------------------------------------------------------------------
	print("\n[4] Verificando que salto a MID_J4_OFFER configura stats...")
	gs.reset_save()
	admin._on_jump_pressed("MID_J4_OFFER")
	var data4 = gs.load_progress()
	assert(int(data4.get("matchday", 0)) == 5, "matchday debe ser 5 para MID_J4_OFFER")
	assert(int(data4.get("combat", 0)) >= 22, "combat debe ser >= 22 para MID_J4_OFFER")
	print("  -> Stats de MID_J4_OFFER coherentes: OK")

	# --------------------------------------------------------------------------
	# 5. Verificar que AMBUSH_J6_BRAWL configura stats coherentes
	# --------------------------------------------------------------------------
	print("\n[5] Verificando que salto a AMBUSH_J6_BRAWL configura stats...")
	gs.reset_save()
	admin._on_jump_pressed("AMBUSH_J6_BRAWL")
	var data5 = gs.load_progress()
	assert(int(data5.get("matchday", 0)) == 7, "matchday debe ser 7 para AMBUSH_J6_BRAWL")
	assert(int(data5.get("discipline", 100)) < 10, "discipline debe ser < 10 para AMBUSH_J6_BRAWL")
	print("  -> Stats de AMBUSH_J6_BRAWL coherentes: OK")

	# --------------------------------------------------------------------------
	# 6. Verificar acción de reset
	# --------------------------------------------------------------------------
	print("\n[6] Verificando acción de reset...")
	gs.save_progress({"matchday": 5, "combat": 30})
	gs.story_phase = "ENDING"
	gs.ending_id = "PRO_FIGHTER_EARLY"
	admin._on_action_pressed("reset")
	assert(gs.story_phase == "LEAGUE", "Tras reset, story_phase debe ser LEAGUE")
	assert(gs.ending_id == "", "Tras reset, ending_id debe estar vacío")
	assert(gs.red_cards_total == 0, "Tras reset, red_cards_total debe ser 0")
	print("  -> Reset completo: OK")

	# --------------------------------------------------------------------------
	# 7. Verificar VALID_ENDINGS y VALID_PHASES
	# --------------------------------------------------------------------------
	print("\n[7] Verificando constantes de validación...")
	assert(gs.VALID_ENDINGS.size() == 8, "Deben existir 8 finales válidos")
	assert(gs.VALID_PHASES.size() == 9, "Deben existir 9 fases válidas")
	for end_id in endings_to_test:
		assert(end_id in gs.VALID_ENDINGS, "%s debe estar en VALID_ENDINGS" % end_id)
	print("  -> VALID_ENDINGS (8) y VALID_PHASES (9): OK")

	# Limpieza
	admin.queue_free()
	gs.reset_save()

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DEL PANEL ADMIN Y SALTOS PASARON EXITOSAMENTE.")
	print("==================================================")
	quit(0)
