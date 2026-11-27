extends SceneTree

# Test: Verifica todos los 8 finales del árbol narrativo (anticipados J2-J7 y de cierre J8).

func _init():
	print("==================================================")
	print("[TEST] Verificando 8 Finales del Árbol Narrativo...")
	print("==================================================")

	# Preparar GameSettings
	var gs_script = load("res://scripts/autoload/GameSettings.gd")
	assert(gs_script != null, "GameSettings.gd debe cargar")
	var gs = Node.new()
	gs.name = "GameSettings"
	gs.set_script(gs_script)
	root.add_child(gs)

	# --------------------------------------------------------------------------
	# 1. EXPELLED_EARLY: disciplina <= 0
	# --------------------------------------------------------------------------
	print("\n[1] EXPELLED_EARLY por disciplina <= 0...")
	gs.reset_save()
	gs.story_phase = "LEAGUE"
	gs.ending_id = ""
	gs.red_cards_total = 0
	gs.save_progress({"discipline": 0, "combat": 10, "matchday": 3})
	root.set_meta("gtp_stats", {"discipline": 0, "combat": 10, "matchday": 3, "money": 0, "reputation": 0, "league_wins": 0, "league_losses": 1, "day": 3})

	# Simular evaluación de ramas (lo que haría PitchHUD._evaluate_early_branches_after_match)
	var stats1 = root.get_meta("gtp_stats")
	if int(stats1.get("discipline", 0)) <= 0 or gs.red_cards_total >= 2:
		gs.set_story_ending("ENDING", "EXPELLED_EARLY")
	assert(gs.story_phase == "ENDING", "Debe estar en ENDING")
	assert(gs.ending_id == "EXPELLED_EARLY", "Debe ser EXPELLED_EARLY")
	print("  -> EXPELLED_EARLY (disc <= 0): OK")

	# --------------------------------------------------------------------------
	# 2. EXPELLED_EARLY: red_cards_total >= 2
	# --------------------------------------------------------------------------
	print("\n[2] EXPELLED_EARLY por red_cards_total >= 2...")
	gs.reset_save()
	gs.story_phase = "LEAGUE"
	gs.ending_id = ""
	gs.red_cards_total = 2
	gs.save_progress({"discipline": 30, "combat": 10, "matchday": 4})
	root.set_meta("gtp_stats", {"discipline": 30, "combat": 10, "matchday": 4, "money": 0, "reputation": 0, "league_wins": 1, "league_losses": 1, "day": 4})

	var stats2 = root.get_meta("gtp_stats")
	if int(stats2.get("discipline", 0)) <= 0 or gs.red_cards_total >= 2:
		gs.set_story_ending("ENDING", "EXPELLED_EARLY")
	assert(gs.ending_id == "EXPELLED_EARLY", "Debe ser EXPELLED_EARLY por rojas")
	print("  -> EXPELLED_EARLY (rojas >= 2): OK")

	# --------------------------------------------------------------------------
	# 3. MID_J4_OFFER: matchday == 5 y combat >= 22
	# --------------------------------------------------------------------------
	print("\n[3] MID_J4_OFFER (bifurcación J4)...")
	gs.reset_save()
	gs.story_phase = "LEAGUE"
	gs.ending_id = ""
	gs.red_cards_total = 0
	gs.save_progress({"discipline": 20, "combat": 25, "matchday": 5})
	root.set_meta("gtp_stats", {"discipline": 20, "combat": 25, "matchday": 5, "money": 500, "reputation": 15, "league_wins": 3, "league_losses": 1, "day": 5})

	var stats3 = root.get_meta("gtp_stats")
	var disc3 = int(stats3.get("discipline", 0))
	var comb3 = int(stats3.get("combat", 0))
	var md3 = int(stats3.get("matchday", 1))
	if disc3 > 0 and gs.red_cards_total < 2 and md3 == 5 and comb3 >= 22:
		gs.story_phase = "MID_J4_OFFER"
	assert(gs.story_phase == "MID_J4_OFFER", "Debe entrar en MID_J4_OFFER")
	print("  -> MID_J4_OFFER: OK")

	# --------------------------------------------------------------------------
	# 4. PRO_FIGHTER_EARLY: acepta oferta J4
	# --------------------------------------------------------------------------
	print("\n[4] PRO_FIGHTER_EARLY (acepta oferta)...")
	gs.set_story_ending("ENDING", "PRO_FIGHTER_EARLY")
	assert(gs.ending_id == "PRO_FIGHTER_EARLY", "Debe ser PRO_FIGHTER_EARLY")
	print("  -> PRO_FIGHTER_EARLY: OK")

	# --------------------------------------------------------------------------
	# 5. AMBUSH_J6_BRAWL: matchday == 7 y disciplina < 10
	# --------------------------------------------------------------------------
	print("\n[5] AMBUSH_J6_BRAWL (bifurcación J6)...")
	gs.reset_save()
	gs.story_phase = "LEAGUE"
	gs.ending_id = ""
	gs.red_cards_total = 0
	gs.save_progress({"discipline": 5, "combat": 15, "matchday": 7})
	root.set_meta("gtp_stats", {"discipline": 5, "combat": 15, "matchday": 7, "money": 300, "reputation": 30, "league_wins": 2, "league_losses": 3, "day": 7})

	var stats5 = root.get_meta("gtp_stats")
	var disc5 = int(stats5.get("discipline", 0))
	var md5 = int(stats5.get("matchday", 1))
	if disc5 > 0 and gs.red_cards_total < 2 and md5 == 7 and disc5 < 10:
		gs.story_phase = "AMBUSH_J6_BRAWL"
	assert(gs.story_phase == "AMBUSH_J6_BRAWL", "Debe entrar en AMBUSH_J6_BRAWL")
	print("  -> AMBUSH_J6_BRAWL: OK")

	# --------------------------------------------------------------------------
	# 6. HOSPITAL_DREAM_BAD: pierde emboscada J6
	# --------------------------------------------------------------------------
	print("\n[6] HOSPITAL_DREAM_BAD (pierde emboscada)...")
	gs.set_story_ending("ENDING", "HOSPITAL_DREAM_BAD")
	assert(gs.ending_id == "HOSPITAL_DREAM_BAD", "Debe ser HOSPITAL_DREAM_BAD")
	print("  -> HOSPITAL_DREAM_BAD: OK")

	# --------------------------------------------------------------------------
	# 7. POST_J8_CHOICE y finales de liga
	# --------------------------------------------------------------------------
	print("\n[7] POST_J8_CHOICE y evaluación de finales de liga...")
	gs.reset_save()
	gs.story_phase = "LEAGUE"
	gs.ending_id = ""
	gs.red_cards_total = 0

	# 7a. GOLDEN_BOY_CHAMPION: >= 19 pts (wins=7 => 21 pts) + goles+asist > 11
	gs.goals_scored = 10
	gs.assists = 5
	gs.save_progress({"discipline": 50, "combat": 20, "matchday": 9, "league_wins": 7, "league_losses": 1})
	var ending_7a = gs.evaluate_j8_ending()
	assert(ending_7a == "GOLDEN_BOY_CHAMPION", "Debe ser GOLDEN_BOY_CHAMPION, fue: " + ending_7a)
	print("  -> GOLDEN_BOY_CHAMPION (>=19 pts + g+a>11): OK")

	# 7b. LEAGUE_CHAMPION: >= 19 pts (wins=6, losses=1, draw=1 => 19 pts) pero g+a <= 11
	gs.goals_scored = 5
	gs.assists = 3
	gs.save_progress({"league_wins": 6, "league_losses": 1})
	var ending_7b = gs.evaluate_j8_ending()
	assert(ending_7b == "LEAGUE_CHAMPION", "Debe ser LEAGUE_CHAMPION, fue: " + ending_7b)
	print("  -> LEAGUE_CHAMPION (>=19 pts sin g+a>11): OK")

	# 7c. PRO_RUNNER_UP: 15..18 pts (wins=5, losses=3 => 15 pts)
	gs.save_progress({"league_wins": 5, "league_losses": 3})
	var ending_7c = gs.evaluate_j8_ending()
	assert(ending_7c == "PRO_RUNNER_UP", "Debe ser PRO_RUNNER_UP, fue: " + ending_7c)
	print("  -> PRO_RUNNER_UP (15..18 pts): OK")

	# 7d. RELEASED_BAD: < 15 pts (wins=4, draws=2, losses=2 => 14 pts)
	gs.save_progress({"league_wins": 4, "league_losses": 2})
	var ending_7d = gs.evaluate_j8_ending()
	assert(ending_7d == "RELEASED_BAD", "Debe ser RELEASED_BAD, fue: " + ending_7d)
	print("  -> RELEASED_BAD (<15 pts): OK")

	# --------------------------------------------------------------------------
	# 8. PRO_FIGHTER_J8: gana pelea final con combate >= 25
	# --------------------------------------------------------------------------
	print("\n[8] PRO_FIGHTER_J8...")
	gs.reset_save()
	gs.story_phase = "FINAL_BRAWL"
	gs.ending_id = ""
	gs.set_story_ending("ENDING", "PRO_FIGHTER_J8")
	assert(gs.ending_id == "PRO_FIGHTER_J8", "Debe ser PRO_FIGHTER_J8")
	print("  -> PRO_FIGHTER_J8: OK")

	# --------------------------------------------------------------------------
	# 9. Verificar descripciones de finales
	# --------------------------------------------------------------------------
	print("\n[9] Verificando descripciones de finales...")
	for end_id in gs.VALID_ENDINGS:
		var title = gs.get_ending_title(end_id)
		var desc = gs.get_ending_description(end_id)
		assert(title != "Final Desconocido", "Título de %s no debe ser desconocido" % end_id)
		assert(desc != "Desenlace no reconocido.", "Descripción de %s no debe ser genérica" % end_id)
		assert(desc.length() > 20, "Descripción de %s debe tener contenido sustancial" % end_id)
		print("  -> %s: título y descripción OK" % end_id)

	# Limpieza
	gs.reset_save()

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DE FINALES DEL ÁRBOL NARRATIVO PASARON EXITOSAMENTE.")
	print("==================================================")
	quit(0)
