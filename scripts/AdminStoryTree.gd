extends Control

# Panel de Administración del Árbol Narrativo (F12)
# Muestra el diagrama del árbol de decisiones y permite saltar a cualquier nodo/final.

var scroll_container = null
var tree_vbox = null
var title_label = null
var info_label = null
var balance_viewer_label = null

# Colores por tipo de nodo
const COLOR_LEAGUE = Color(0.2, 0.8, 1.0)
const COLOR_BRANCH = Color(1.0, 0.85, 0.15)
const COLOR_ENDING_BAD = Color(1.0, 0.3, 0.2)
const COLOR_ENDING_GOOD = Color(0.2, 1.0, 0.4)
const COLOR_ENDING_ALT = Color(0.9, 0.5, 1.0)
const COLOR_ENDING_SUPREME = Color(1.0, 0.95, 0.3)

func _ready() -> void:
	visible = false
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Fondo semitransparente
	var bg = ColorRect.new()
	bg.name = "AdminBG"
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.05, 0.05, 0.1, 0.92)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Título
	title_label = Label.new()
	title_label.name = "AdminTitle"
	title_label.text = "PANEL ADMIN — ÁRBOL NARRATIVO (F12)"
	title_label.align = Label.ALIGN_CENTER
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.margin_top = 8.0
	title_label.margin_bottom = 36.0
	title_label.modulate = Color(1.0, 0.9, 0.2)
	add_child(title_label)

	# Info actual
	info_label = Label.new()
	info_label.name = "AdminInfo"
	info_label.anchor_left = 0.0
	info_label.anchor_right = 1.0
	info_label.margin_top = 36.0
	info_label.margin_bottom = 64.0
	info_label.align = Label.ALIGN_CENTER
	info_label.autowrap = true
	info_label.modulate = Color(0.8, 0.9, 1.0)
	add_child(info_label)

	# Visor de Balanceo DeSiGNAR en vivo
	balance_viewer_label = Label.new()
	balance_viewer_label.name = "BalanceViewerLabel"
	balance_viewer_label.anchor_left = 0.02
	balance_viewer_label.anchor_right = 0.98
	balance_viewer_label.margin_top = 64.0
	balance_viewer_label.margin_bottom = 104.0
	balance_viewer_label.align = Label.ALIGN_CENTER
	balance_viewer_label.autowrap = true
	balance_viewer_label.modulate = Color(1.0, 0.9, 0.35)
	add_child(balance_viewer_label)

	# ScrollContainer para el árbol
	scroll_container = ScrollContainer.new()
	scroll_container.name = "AdminScroll"
	scroll_container.anchor_left = 0.02
	scroll_container.anchor_right = 0.98
	scroll_container.anchor_top = 0.0
	scroll_container.anchor_bottom = 1.0
	scroll_container.margin_top = 108.0
	scroll_container.margin_bottom = -10.0
	scroll_container.scroll_horizontal_enabled = false
	scroll_container.scroll_vertical_enabled = true
	add_child(scroll_container)

	tree_vbox = VBoxContainer.new()
	tree_vbox.name = "TreeVBox"
	tree_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(tree_vbox)

	refresh_tree()

func _input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.scancode == KEY_F12:
		visible = not visible
		if visible:
			refresh_tree()
		get_tree().set_input_as_handled()

func refresh_tree() -> void:
	if not tree_vbox:
		return

	# Limpiar nodos previos
	for child in tree_vbox.get_children():
		child.queue_free()

	var gs = get_node_or_null("/root/GameSettings")
	var current_phase = gs.story_phase if gs else "LEAGUE"
	var current_ending = gs.ending_id if gs else ""
	var matchday = 1
	var discipline = 0
	var combat = 0
	var reputation = 0
	var goals = 0
	var assists_val = 0
	var red_cards = 0

	if gs:
		var data = gs.load_progress() if gs.has_method("load_progress") else {}
		matchday = int(data.get("matchday", 1))
		discipline = int(data.get("discipline", 0))
		combat = int(data.get("combat", 0))
		reputation = int(data.get("reputation", 0))
		goals = gs.goals_scored
		assists_val = gs.assists
		red_cards = gs.red_cards_total

	# Ejecutar rebalanceo en vivo (C++ si existe story_manager en padre, y GameSettings)
	var branch_name = "Rama Doble Vida"
	var f_score = 0
	var s_score = 0
	var delta_val = 0
	var projected_ending = ""

	var parent = get_parent()
	var sm = parent.story_manager if (parent and "story_manager" in parent) else null
	if sm and sm.has_method("rebalance_story_tree"):
		sm.rebalance_story_tree(combat, discipline, reputation, goals, assists_val, red_cards, matchday)

	if gs and gs.has_method("rebalance_story_tree"):
		gs.rebalance_story_tree(combat, discipline, reputation, goals, assists_val, red_cards, matchday)
		branch_name = gs.get_active_branch_name()
		f_score = gs.football_score
		s_score = gs.street_score
		delta_val = gs.get_balance_delta()
		projected_ending = gs.get_projected_ending() if gs.has_method("get_projected_ending") else ""

	# Info actual
	if info_label:
		info_label.text = "Fase: %s | Final: %s | J%d | Disc: %d | Comb: %d | Rep: %d | G+A: %d | Rojas: %d" % [
			current_phase, current_ending if current_ending != "" else "(ninguno)",
			matchday, discipline, combat, reputation, goals + assists_val, red_cards
		]

	if balance_viewer_label:
		balance_viewer_label.text = "VISOR DeSiGNAR EN VIVO — Fútbol (F): %d | Callejero (C): %d | Delta (F-C): %+d\nRama Activa: %s | Proyección de Final: %s" % [
			f_score, s_score, delta_val, branch_name, projected_ending
		]
		if delta_val >= 10:
			balance_viewer_label.modulate = Color(0.25, 0.95, 0.45)
		elif delta_val <= -10:
			balance_viewer_label.modulate = Color(1.0, 0.4, 0.25)
		else:
			balance_viewer_label.modulate = Color(1.0, 0.9, 0.35)

	# --- AJUSTES RÁPIDOS DE REBALANCEO EN VIVO ---
	_add_section("═══ VISOR DE REBALANCEO EN VIVO (AJUSTE RÁPIDO) ═══", Color(0.4, 1.0, 0.7))
	_add_quick_adjust_row()

	# --- DIAGRAMA DEL ÁRBOL ---
	_add_section("═══ INICIO DE TEMPORADA ═══", COLOR_LEAGUE)
	_add_tree_node("CREATE_PLAYER", "Crear Jugador", "Nombre y cantera", COLOR_LEAGUE, "CREATE_PLAYER")
	_add_tree_node("PROLOGUE_HIT", "Prólogo: El Golpe", "Escena cinematográfica", COLOR_LEAGUE, "PROLOGUE_HIT")
	_add_tree_node("SELECT_ACADEMY", "Seleccionar Cantera", "Estudiantes/Barça/Real Madrid", COLOR_LEAGUE, "SELECT_ACADEMY")

	_add_section("═══ LIGA (8 JORNADAS) ═══", COLOR_LEAGUE)
	_add_tree_node("LEAGUE", "Liga — Jornadas 1-8", "Partidos + decisiones diarias", COLOR_LEAGUE, "LEAGUE")

	_add_section("═══ BIFURCACIONES TEMPRANAS (J2-J7) ═══", COLOR_BRANCH)
	_add_tree_node("EXPELLED_EARLY", "❌ EXPELLED_EARLY (J2-J7)", "disc ≤ 0 ó rojas ≥ 2 → Expulsado", COLOR_ENDING_BAD, "EXPELLED_EARLY")
	_add_tree_node("MID_J4_OFFER", "⚔ MID_J4_OFFER (J4)", "Tras 4.º partido, comb ≥ 22 → Oferta promotor", COLOR_BRANCH, "MID_J4_OFFER")
	_add_tree_node("PRO_FIGHTER_EARLY", "🥊 PRO_FIGHTER_EARLY (J4)", "Acepta oferta → Peleador profesional temprano", COLOR_ENDING_ALT, "PRO_FIGHTER_EARLY")
	_add_tree_node("AMBUSH_J6_BRAWL", "🌙 AMBUSH_J6_BRAWL (J6)", "Tras 6.º partido, disc < 10 → Emboscada", COLOR_BRANCH, "AMBUSH_J6_BRAWL")
	_add_tree_node("HOSPITAL_DREAM_BAD_J6", "💀 HOSPITAL_DREAM_BAD (J6)", "Pierde emboscada → Hospital/Sueño", COLOR_ENDING_BAD, "HOSPITAL_DREAM_BAD")

	_add_section("═══ FINALES DE JORNADA 8 ═══", COLOR_BRANCH)
	_add_tree_node("POST_J8_CHOICE", "🏟 POST_J8_CHOICE", "Fin de temporada → ¿Pelea o liga?", COLOR_BRANCH, "POST_J8_CHOICE")
	_add_tree_node("FINAL_BRAWL", "⚔ FINAL_BRAWL", "Acepta pelea final J8", COLOR_BRANCH, "FINAL_BRAWL")
	_add_tree_node("PRO_FIGHTER_J8", "🥊 PRO_FIGHTER_J8", "Gana pelea + comb ≥ 25 → Peleador J8", COLOR_ENDING_ALT, "PRO_FIGHTER_J8")
	_add_tree_node("HOSPITAL_DREAM_BAD_J8", "💀 HOSPITAL_DREAM_BAD (J8)", "Pierde pelea final → Hospital/Sueño", COLOR_ENDING_BAD, "HOSPITAL_DREAM_BAD")
	_add_tree_node("GOLDEN_BOY_CHAMPION", "🏆 GOLDEN_BOY_CHAMPION", "1.º + goles+asist > 11 → Golden Boy", COLOR_ENDING_SUPREME, "GOLDEN_BOY_CHAMPION")
	_add_tree_node("LEAGUE_CHAMPION", "🏆 LEAGUE_CHAMPION", "1.º en liga → Campeón", COLOR_ENDING_GOOD, "LEAGUE_CHAMPION")
	_add_tree_node("PRO_RUNNER_UP", "🥈 PRO_RUNNER_UP", "2.º en liga → Subcampeón", COLOR_ENDING_GOOD, "PRO_RUNNER_UP")
	_add_tree_node("RELEASED_BAD", "❌ RELEASED_BAD", "3.º+ en liga → Liberado", COLOR_ENDING_BAD, "RELEASED_BAD")

	_add_section("═══ ACCIONES ═══", Color(0.6, 0.6, 0.7))
	_add_action_button("Cerrar Panel (F12)", "close")
	_add_action_button("Reiniciar Temporada", "reset")

func _add_section(text: String, color: Color) -> void:
	var sep = Label.new()
	sep.text = text
	sep.align = Label.ALIGN_CENTER
	sep.modulate = color
	tree_vbox.add_child(sep)

func _add_tree_node(node_id: String, label_text: String, desc: String, color: Color, jump_target: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl = Label.new()
	lbl.text = "  %s — %s" % [label_text, desc]
	lbl.modulate = color
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap = true
	hbox.add_child(lbl)

	var btn = Button.new()
	btn.text = "SALTAR"
	btn.rect_min_size = Vector2(90, 30)
	btn.connect("pressed", self, "_on_jump_pressed", [jump_target])
	hbox.add_child(btn)

	# Resaltar el nodo actual
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		var is_current = false
		if gs.story_phase == "ENDING" and gs.ending_id == jump_target:
			is_current = true
		elif gs.story_phase == jump_target and jump_target != "ENDING":
			is_current = true
		if is_current:
			lbl.text = "▶ " + lbl.text
			lbl.modulate = Color(1.0, 1.0, 1.0)

	tree_vbox.add_child(hbox)

func _add_quick_adjust_row() -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var adjustments = [
		["+15 Combate", "combat", 15],
		["+15 Disciplina", "discipline", 15],
		["+1 Gol", "goals", 1],
		["+1 Asist.", "assists", 1],
		["+1 Roja", "red_cards", 1],
		["Reset Stats", "reset_stats", 0]
	]
	for item in adjustments:
		var btn = Button.new()
		btn.text = item[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.rect_min_size = Vector2(0, 32)
		btn.connect("pressed", self, "adjust_stat_and_rebalance", [item[1], item[2]])
		hbox.add_child(btn)
	tree_vbox.add_child(hbox)

func adjust_stat_and_rebalance(stat_key: String, delta_amount: int) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		return
	var root_node = get_tree().root
	var cur_stats = root_node.get_meta("gtp_stats") if root_node.has_meta("gtp_stats") else {
		"discipline": 0, "combat": 0, "money": 0, "reputation": 0,
		"matchday": 1, "league_wins": 0, "league_losses": 0, "day": 1
	}
	var saved = gs.load_progress() if gs.has_method("load_progress") else {}
	for k in ["discipline", "combat", "money", "reputation", "matchday", "league_wins", "league_losses"]:
		if not cur_stats.has(k) or int(cur_stats[k]) == 0:
			if saved.has(k):
				cur_stats[k] = saved[k]

	match stat_key:
		"combat":
			cur_stats["combat"] = int(cur_stats.get("combat", 0)) + delta_amount
		"discipline":
			cur_stats["discipline"] = int(cur_stats.get("discipline", 0)) + delta_amount
		"goals":
			gs.goals_scored += delta_amount
		"assists":
			gs.assists += delta_amount
		"red_cards":
			gs.red_cards_total += delta_amount
		"reset_stats":
			cur_stats["discipline"] = 0
			cur_stats["combat"] = 0
			cur_stats["reputation"] = 0
			gs.goals_scored = 0
			gs.assists = 0
			gs.red_cards_total = 0

	root_node.set_meta("gtp_stats", cur_stats)
	gs.save_progress(cur_stats)

	var parent = get_parent()
	var sm = parent.story_manager if (parent and "story_manager" in parent) else null
	if sm and sm.has_method("rebalance_story_tree"):
		sm.rebalance_story_tree(
			int(cur_stats.get("combat", 0)),
			int(cur_stats.get("discipline", 0)),
			int(cur_stats.get("reputation", 0)),
			gs.goals_scored,
			gs.assists,
			gs.red_cards_total,
			int(cur_stats.get("matchday", 1))
		)

	gs.rebalance_story_tree(
		int(cur_stats.get("combat", 0)),
		int(cur_stats.get("discipline", 0)),
		int(cur_stats.get("reputation", 0)),
		gs.goals_scored,
		gs.assists,
		gs.red_cards_total,
		int(cur_stats.get("matchday", 1))
	)

	refresh_tree()
	if parent and parent.has_method("update_ui"):
		parent.update_ui()

func _add_action_button(text: String, action: String) -> void:
	var btn = Button.new()
	btn.text = text
	btn.rect_min_size = Vector2(0, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.connect("pressed", self, "_on_action_pressed", [action])
	tree_vbox.add_child(btn)

func _on_jump_pressed(target: String) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		return

	print("[AdminStoryTree] Saltando a: %s" % target)

	# Verificar si es un ending_id directo
	var is_ending = target in gs.VALID_ENDINGS

	if is_ending:
		gs.set_story_ending("ENDING", target)
	elif target in gs.VALID_PHASES:
		gs.story_phase = target
		gs.ending_id = ""
		# Configurar stats mínimas para que la fase tenga sentido
		match target:
			"MID_J4_OFFER":
				_set_stats_for_jump({"matchday": 5, "combat": 22, "discipline": 20})
			"AMBUSH_J6_BRAWL":
				_set_stats_for_jump({"matchday": 7, "discipline": 5, "combat": 15})
			"POST_J8_CHOICE":
				_set_stats_for_jump({"matchday": 9, "discipline": 30, "combat": 20, "league_wins": 5})
			"FINAL_BRAWL":
				_set_stats_for_jump({"matchday": 9, "discipline": 30, "combat": 25, "league_wins": 5})
			_:
				pass
		gs.save_progress({})

	# Recargar la escena MainGame para aplicar cambios
	refresh_tree()

	# Actualizar la UI del MainGame padre
	var parent = get_parent()
	if parent and parent.has_method("update_ui"):
		parent.update_ui()

func _set_stats_for_jump(overrides: Dictionary) -> void:
	var root_node = get_tree().root
	var cur_stats = root_node.get_meta("gtp_stats") if root_node.has_meta("gtp_stats") else {
		"discipline": 0, "combat": 0, "money": 0, "reputation": 0,
		"matchday": 1, "league_wins": 0, "league_losses": 0, "day": 1
	}
	for k in overrides.keys():
		cur_stats[k] = overrides[k]
	root_node.set_meta("gtp_stats", cur_stats)

	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("save_progress"):
		gs.save_progress(cur_stats)

func _on_action_pressed(action: String) -> void:
	match action:
		"close":
			visible = false
		"reset":
			var gs = get_node_or_null("/root/GameSettings")
			if gs and gs.has_method("reset_save"):
				gs.reset_save()
			get_tree().root.set_meta("gtp_stats", {
				"discipline": 0, "combat": 0, "money": 0, "reputation": 0,
				"matchday": 1, "league_wins": 0, "league_losses": 0, "day": 1
			})
			refresh_tree()
			var parent = get_parent()
			if parent and parent.has_method("update_ui"):
				parent.update_ui()
