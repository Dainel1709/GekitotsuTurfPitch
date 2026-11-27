extends SceneTree

# Test: Verifica el árbol narrativo auto-balanceado por estadísticas (DeSiGNAR)
# y el visor en vivo en AdminStoryTree y MainGame.

func _init():
	print("==================================================")
	print("[TEST] Verificando Árbol Narrativo Auto-Balanceado...")
	print("==================================================")

	var gs = root.get_node_or_null("GameSettings")
	if gs == null:
		var gs_script = load("res://scripts/autoload/GameSettings.gd")
		assert(gs_script != null, "GameSettings.gd debe cargar")
		gs = Node.new()
		gs.name = "GameSettings"
		gs.set_script(gs_script)
		root.add_child(gs)

	gs.reset_save()

	# --------------------------------------------------------------------------
	# 1. Estado neutral (0 vs 0) -> Rama Doble Vida
	# --------------------------------------------------------------------------
	print("\n[1] Estado neutral -> Rama Doble Vida...")
	var branch_0 = gs.rebalance_story_tree(0, 0, 0, 0, 0, 0, 1)
	assert(branch_0 == "DUAL_LIFE", "Debe ser DUAL_LIFE, fue: " + branch_0)
	assert(gs.get_active_branch_name() == "Rama Doble Vida", "Nombre debe ser Rama Doble Vida")
	assert(gs.get_balance_delta() == 0, "Delta debe ser 0")
	print("  -> Neutral OK (Delta: %d, Rama: %s)" % [gs.get_balance_delta(), gs.get_active_branch_name()])

	# --------------------------------------------------------------------------
	# 2. Subir combate -> Rama Submundo Callejero
	# --------------------------------------------------------------------------
	print("\n[2] Subir combate -> Rama Submundo Callejero...")
	# combate=20, disc=5, rep=5, goals=0, assists=0, red=1 => F=10, C=int(36)+10=46, delta=-36
	var branch_street = gs.rebalance_story_tree(20, 5, 5, 0, 0, 1, 4)
	assert(branch_street == "STREET_BRAWLER", "Debe ser STREET_BRAWLER, fue: " + branch_street)
	assert(gs.get_active_branch_name() == "Rama Submundo Callejero", "Debe inclinar a Rama Submundo Callejero")
	assert(gs.football_score == 10, "football_score debe ser 10")
	assert(gs.street_score == 46, "street_score debe ser 46")
	assert(gs.get_balance_delta() == -36, "Delta debe ser -36")
	print("  -> Submundo Callejero OK (F:%d vs C:%d, Delta:%d)" % [gs.football_score, gs.street_score, gs.get_balance_delta()])

	# --------------------------------------------------------------------------
	# 3. Subir disciplina + G+A -> Rama Élite Deportiva
	# --------------------------------------------------------------------------
	print("\n[3] Subir disciplina + G+A -> Rama Élite Deportiva...")
	# combate=5, disc=40, rep=15, goals=8, assists=5, red=0 => F=40+15+26=81, C=9, delta=+72
	var branch_elite = gs.rebalance_story_tree(5, 40, 15, 8, 5, 0, 6)
	assert(branch_elite == "ELITE_FOOTBALL", "Debe ser ELITE_FOOTBALL, fue: " + branch_elite)
	assert(gs.get_active_branch_name() == "Rama Élite Deportiva", "Debe inclinar a Rama Élite Deportiva")
	assert(gs.football_score == 81, "football_score debe ser 81")
	assert(gs.street_score == 9, "street_score debe ser 9")
	assert(gs.get_balance_delta() == 72, "Delta debe ser 72")
	print("  -> Élite Deportiva OK (F:%d vs C:%d, Delta:%d)" % [gs.football_score, gs.street_score, gs.get_balance_delta()])

	# --------------------------------------------------------------------------
	# 4. Visor en vivo en AdminStoryTree.tscn: botones de ajuste rápido
	# --------------------------------------------------------------------------
	print("\n[4] Probando visor en vivo en AdminStoryTree.tscn...")
	var admin_scene = load("res://scenes/AdminStoryTree.tscn")
	assert(admin_scene != null, "AdminStoryTree.tscn debe cargar")
	var admin = admin_scene.instance()
	root.add_child(admin)

	gs.reset_save()
	root.set_meta("gtp_stats", {
		"discipline": 0, "combat": 0, "money": 0, "reputation": 0,
		"matchday": 3, "league_wins": 1, "league_losses": 1, "day": 3
	})

	# Pulsar +15 Combate -> street_score = int(15*1.8) = 27 -> Delta = -27 -> Rama Submundo Callejero
	admin.adjust_stat_and_rebalance("combat", 15)
	assert(gs.get_active_branch_name() == "Rama Submundo Callejero", "Tras +15 Combate debe ser Rama Submundo Callejero, fue: " + gs.get_active_branch_name())
	print("  -> Ajuste rápido +15 Combate OK: %s (Delta: %d)" % [gs.get_active_branch_name(), gs.get_balance_delta()])

	# Pulsar +15 Disciplina x3 (45) + +1 Gol x4 (+8) -> F = 53, C = 27 -> Delta = +26 -> Rama Élite Deportiva
	admin.adjust_stat_and_rebalance("discipline", 45)
	admin.adjust_stat_and_rebalance("goals", 4)
	assert(gs.get_active_branch_name() == "Rama Élite Deportiva", "Tras subir disciplina+goles debe ser Rama Élite Deportiva, fue: " + gs.get_active_branch_name())
	print("  -> Ajuste rápido +45 Disciplina + 4 Goles OK: %s (Delta: %+d)" % [gs.get_active_branch_name(), gs.get_balance_delta()])

	# --------------------------------------------------------------------------
	# 5. Instanciar MainGame.tscn y TitleScreen.tscn y verificar BalanceLabel
	# --------------------------------------------------------------------------
	print("\n[5] Verificando MainGame.tscn, TitleScreen.tscn y BalanceLabel...")
	var title_scene = load("res://scenes/TitleScreen.tscn")
	assert(title_scene != null, "TitleScreen.tscn debe cargar")
	var title_node = title_scene.instance()
	root.add_child(title_node)
	title_node.queue_free()

	var main_scene = load("res://scenes/MainGame.tscn")
	assert(main_scene != null, "MainGame.tscn debe cargar")
	var main_node = main_scene.instance()
	root.add_child(main_node)
	var bal_lbl = main_node.balance_label
	assert(bal_lbl != null, "MainGame.tscn debe tener balance_label")
	assert("Tendencia del Árbol:" in bal_lbl.text, "BalanceLabel debe mostrar la tendencia del árbol")
	print("  -> MainGame BalanceLabel OK: %s" % bal_lbl.text)

	main_node.queue_free()
	admin.queue_free()
	gs.reset_save()

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DE ÁRBOL AUTO-BALANCEADO PASARON EXITOSAMENTE.")
	print("==================================================")
	quit(0)
