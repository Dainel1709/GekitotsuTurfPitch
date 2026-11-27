extends Control

# Panel de Administración del Árbol Binario Narrativo (F12)
# Visualiza la historia como un árbol binario (Hijos Izquierdos = Eje Principal + Golden Boy;
# Hijos Derechos = Desvíos Tempranos y Finales Balanceados por DeSiGNAR) con teletransporte SALTAR.

var scroll_container = null
var tree_canvas = null
var title_label = null
var info_label = null
var balance_viewer_label = null
var toolbar_hbox = null

# Colores por tipo de nodo
const COLOR_LEAGUE = Color(0.22, 0.78, 1.0)
const COLOR_BRANCH = Color(1.0, 0.82, 0.2)
const COLOR_ENDING_BAD = Color(1.0, 0.32, 0.25)
const COLOR_ENDING_GOOD = Color(0.22, 0.95, 0.45)
const COLOR_ENDING_ALT = Color(0.88, 0.48, 1.0)
const COLOR_ENDING_SUPREME = Color(1.0, 0.92, 0.25)

# Colores de conexión en vivo
const COLOR_EDGE_ACTIVE = Color(1.0, 0.88, 0.22, 1.0)
const COLOR_EDGE_ELITE = Color(0.25, 1.0, 0.48, 1.0)
const COLOR_EDGE_DIM = Color(0.28, 0.30, 0.36, 0.55)

class TreeCanvas extends Control:
	var edges = [] # Array of Dictionaries: {from_rect, to_rect, side, active, highlight_color, label}

	func _draw() -> void:
		for edge in edges:
			var r_from = edge["from_rect"]
			var r_to = edge["to_rect"]
			var side = edge["side"] # "left" o "right"
			var is_active = edge["active"]
			var col = edge["highlight_color"] if is_active else Color(0.28, 0.30, 0.36, 0.55)
			var width = 4.0 if is_active else 1.5

			var start_pt = Vector2.ZERO
			var end_pt = Vector2.ZERO
			if side == "left":
				# Hijo izquierdo: sale por abajo del padre hacia arriba del hijo
				start_pt = Vector2(r_from.position.x + r_from.size.x * 0.5, r_from.position.y + r_from.size.y)
				end_pt = Vector2(r_to.position.x + r_to.size.x * 0.5, r_to.position.y)
				draw_line(start_pt, end_pt, col, width, true)
			else:
				# Hijo derecho: sale por el lado derecho del padre hacia el lado izquierdo del hijo
				start_pt = Vector2(r_from.position.x + r_from.size.x, r_from.position.y + r_from.size.y * 0.5)
				end_pt = Vector2(r_to.position.x, r_to.position.y + r_to.size.y * 0.5)
				var mid_x = (start_pt.x + end_pt.x) * 0.5
				var p1 = Vector2(mid_x, start_pt.y)
				var p2 = Vector2(mid_x, end_pt.y)
				draw_line(start_pt, p1, col, width, true)
				draw_line(p1, p2, col, width, true)
				draw_line(p2, end_pt, col, width, true)

			# Punta de flecha en destino
			var dir = (end_pt - start_pt).normalized()
			if side == "right":
				dir = Vector2(1.0, 0.0)
			var perp = Vector2(-dir.y, dir.x)
			var arrow_size = 7.0 if is_active else 5.0
			var a1 = end_pt - dir * arrow_size + perp * (arrow_size * 0.6)
			var a2 = end_pt - dir * arrow_size - perp * (arrow_size * 0.6)
			draw_colored_polygon(PoolVector2Array([end_pt, a1, a2]), col)

			if is_active:
				draw_circle(start_pt, 4.0, col)

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
	bg.color = Color(0.05, 0.05, 0.09, 0.94)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Título
	title_label = Label.new()
	title_label.name = "AdminTitle"
	title_label.text = "PANEL ADMIN — ÁRBOL BINARIO NARRATIVO DeSiGNAR (F12)"
	title_label.align = Label.ALIGN_CENTER
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.margin_top = 6.0
	title_label.margin_bottom = 28.0
	title_label.modulate = Color(1.0, 0.9, 0.2)
	add_child(title_label)

	# Info actual
	info_label = Label.new()
	info_label.name = "AdminInfo"
	info_label.anchor_left = 0.0
	info_label.anchor_right = 1.0
	info_label.margin_top = 28.0
	info_label.margin_bottom = 50.0
	info_label.align = Label.ALIGN_CENTER
	info_label.autowrap = true
	info_label.modulate = Color(0.8, 0.9, 1.0)
	add_child(info_label)

	# Visor de Balanceo DeSiGNAR en vivo
	balance_viewer_label = Label.new()
	balance_viewer_label.name = "BalanceViewerLabel"
	balance_viewer_label.anchor_left = 0.02
	balance_viewer_label.anchor_right = 0.98
	balance_viewer_label.margin_top = 52.0
	balance_viewer_label.margin_bottom = 88.0
	balance_viewer_label.align = Label.ALIGN_CENTER
	balance_viewer_label.autowrap = true
	balance_viewer_label.modulate = Color(1.0, 0.9, 0.35)
	add_child(balance_viewer_label)

	# Barra superior fija de ajuste rápido y acciones
	toolbar_hbox = HBoxContainer.new()
	toolbar_hbox.name = "QuickAdjustToolbar"
	toolbar_hbox.anchor_left = 0.02
	toolbar_hbox.anchor_right = 0.98
	toolbar_hbox.margin_top = 92.0
	toolbar_hbox.margin_bottom = 126.0
	toolbar_hbox.add_constant_override("separation", 6)
	add_child(toolbar_hbox)
	_build_quick_adjust_toolbar()

	# ScrollContainer para el lienzo del árbol binario
	scroll_container = ScrollContainer.new()
	scroll_container.name = "AdminScroll"
	scroll_container.anchor_left = 0.02
	scroll_container.anchor_right = 0.98
	scroll_container.anchor_top = 0.0
	scroll_container.anchor_bottom = 1.0
	scroll_container.margin_top = 132.0
	scroll_container.margin_bottom = -10.0
	scroll_container.scroll_horizontal_enabled = true
	scroll_container.scroll_vertical_enabled = true
	add_child(scroll_container)

	tree_canvas = TreeCanvas.new()
	tree_canvas.name = "TreeCanvas"
	tree_canvas.rect_min_size = Vector2(1200, 1440)
	scroll_container.add_child(tree_canvas)

	refresh_tree()

func _build_quick_adjust_toolbar() -> void:
	if not toolbar_hbox:
		return
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
		toolbar_hbox.add_child(btn)

	var reset_btn = Button.new()
	reset_btn.text = "Reiniciar Temp."
	reset_btn.rect_min_size = Vector2(120, 32)
	reset_btn.connect("pressed", self, "_on_action_pressed", ["reset"])
	toolbar_hbox.add_child(reset_btn)

	var close_btn = Button.new()
	close_btn.text = "Cerrar (F12)"
	close_btn.rect_min_size = Vector2(105, 32)
	close_btn.connect("pressed", self, "_on_action_pressed", ["close"])
	toolbar_hbox.add_child(close_btn)

func _input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.scancode == KEY_F12:
		visible = not visible
		if visible:
			refresh_tree()
		get_tree().set_input_as_handled()

func refresh_tree() -> void:
	if not tree_canvas:
		return

	for child in tree_canvas.get_children():
		child.queue_free()
	tree_canvas.edges.clear()

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
	var league_wins = 0
	var league_losses = 0

	if gs:
		var data = gs.load_progress() if gs.has_method("load_progress") else {}
		matchday = int(data.get("matchday", 1))
		discipline = int(data.get("discipline", 0))
		combat = int(data.get("combat", 0))
		reputation = int(data.get("reputation", 0))
		league_wins = int(data.get("league_wins", 0))
		league_losses = int(data.get("league_losses", 0))
		goals = gs.goals_scored
		assists_val = gs.assists
		red_cards = gs.red_cards_total

	var branch_name = "Rama Doble Vida"
	var f_score = 0
	var s_score = 0
	var delta_val = 0
	var projected_ending = "RELEASED_BAD"

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
		projected_ending = gs.get_projected_ending({
			"discipline": discipline,
			"combat": combat,
			"matchday": matchday,
			"league_wins": league_wins,
			"league_losses": league_losses
		}) if gs.has_method("get_projected_ending") else "RELEASED_BAD"

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

	# Determinar qué camino del árbol está ganando el balanceo en vivo
	var early_expelled = (projected_ending == "EXPELLED_EARLY")
	var early_j4 = (projected_ending == "PRO_FIGHTER_EARLY")
	var early_j6 = (projected_ending == "HOSPITAL_DREAM_BAD" and delta_val <= -10 and combat < 22 and discipline < 10)
	var goes_past_j2 = not early_expelled
	var goes_past_j4 = goes_past_j2 and not early_j4
	var goes_past_j6 = goes_past_j4 and not early_j6
	var is_golden_boy = (projected_ending == "GOLDEN_BOY_CHAMPION")
	var goes_to_j8_right = goes_past_j6 and not is_golden_boy
	var is_brawl_j8 = (projected_ending == "PRO_FIGHTER_J8") or (projected_ending == "HOSPITAL_DREAM_BAD" and not early_j6)

	var win_color = COLOR_EDGE_ELITE if delta_val >= 10 else COLOR_EDGE_ACTIVE

	# Cabeceras de columnas del árbol binario
	_add_column_header(Vector2(30, 6), 330, "HIJOS IZQUIERDOS: EJE PRINCIPAL + GOLDEN BOY", COLOR_LEAGUE)
	_add_column_header(Vector2(430, 6), 330, "HIJOS DERECHOS: DESVÍOS TEMPRANOS (J2-J7)", COLOR_BRANCH)
	_add_column_header(Vector2(820, 6), 340, "HIJOS DERECHOS: FINALES BALANCEADOS", COLOR_ENDING_GOOD)

	var rects = {}

	# --- COLUMNA IZQUIERDA (EJE PRINCIPAL) ---
	rects["CREATE_PLAYER"] = _create_node_card(
		"CREATE_PLAYER", Vector2(30, 36), Vector2(330, 66),
		"Crear Jugador", "Nombre y perfil inicial", COLOR_LEAGUE, "CREATE_PLAYER", true
	)
	rects["PROLOGUE_HIT"] = _create_node_card(
		"PROLOGUE_HIT", Vector2(30, 124), Vector2(330, 66),
		"Prólogo: El Balonazo", "Escena inicial del golpe", COLOR_LEAGUE, "PROLOGUE_HIT", true
	)
	rects["SELECT_ACADEMY"] = _create_node_card(
		"SELECT_ACADEMY", Vector2(30, 212), Vector2(330, 66),
		"Cantera", "Estudiantes / Barça / Real Madrid", COLOR_LEAGUE, "SELECT_ACADEMY", true
	)

	var md_y_start = 306
	var md_step = 88
	for i in range(1, 9):
		var key = "J%d" % i
		var pos = Vector2(30, md_y_start + (i - 1) * md_step)
		var is_active_md = true
		if i > 2 and early_expelled:
			is_active_md = false
		elif i > 4 and early_j4:
			is_active_md = false
		elif i > 6 and early_j6:
			is_active_md = false
		var subtitle = "Partido J%d + decisiones" % i
		if i == 4:
			subtitle = "J4 — Check Combate ≥ 22"
		elif i == 6:
			subtitle = "J6 — Check Disciplina < 10"
		elif i == 8:
			subtitle = "J8 — Cierre de Temporada"
		rects[key] = _create_node_card(
			"LEAGUE_J%d" % i, pos, Vector2(330, 66),
			"Jornada %d" % i, subtitle, COLOR_LEAGUE, "LEAGUE_J%d" % i, is_active_md,
			(current_phase == "LEAGUE" and matchday == i)
		)

	# Hijo Izquierdo de Jornada 8: GOLDEN BOY
	rects["GOLDEN_BOY_CHAMPION"] = _create_node_card(
		"GOLDEN_BOY_CHAMPION", Vector2(30, 1028), Vector2(330, 78),
		"🏆 Premio Golden Boy", "1.º + Goles+Asist > 11", COLOR_ENDING_SUPREME, "GOLDEN_BOY_CHAMPION", is_golden_boy
	)

	# --- COLUMNA CENTRAL / HIJOS DERECHOS DE J2-J7 Y POST-J8 ---
	rects["EXPELLED_EARLY"] = _create_node_card(
		"EXPELLED_EARLY", Vector2(430, 394), Vector2(330, 68),
		"❌ Expulsado (J2-J7)", "disc ≤ 0 ó rojas ≥ 2", COLOR_ENDING_BAD, "EXPELLED_EARLY", early_expelled
	)
	rects["MID_J4_OFFER"] = _create_node_card(
		"MID_J4_OFFER", Vector2(430, 570), Vector2(330, 68),
		"⚔ Oferta Promotor J4", "comb ≥ 22 tras 4.º partido", COLOR_BRANCH, "MID_J4_OFFER", early_j4
	)
	rects["AMBUSH_J6_BRAWL"] = _create_node_card(
		"AMBUSH_J6_BRAWL", Vector2(430, 746), Vector2(330, 68),
		"🌙 Emboscada J6", "disc < 10 tras 6.º partido", COLOR_BRANCH, "AMBUSH_J6_BRAWL", early_j6
	)
	rects["POST_J8_CHOICE"] = _create_node_card(
		"POST_J8_CHOICE", Vector2(430, 922), Vector2(330, 68),
		"🏟 Bifurcación Final J8", "Finales balanceados DeSiGNAR", COLOR_BRANCH, "POST_J8_CHOICE", goes_to_j8_right
	)
	rects["FINAL_BRAWL"] = _create_node_card(
		"FINAL_BRAWL", Vector2(430, 1110), Vector2(330, 68),
		"⚔ Pelea Final J8", "Acepta el reto callejero", COLOR_BRANCH, "FINAL_BRAWL", is_brawl_j8
	)

	# --- COLUMNA DERECHA (FINALES BALANCEADOS) ---
	rects["PRO_FIGHTER_EARLY"] = _create_node_card(
		"PRO_FIGHTER_EARLY", Vector2(820, 570), Vector2(340, 68),
		"🥊 Peleador Pro Temprano", "Acepta oferta del promotor J4", COLOR_ENDING_ALT, "PRO_FIGHTER_EARLY", early_j4
	)
	rects["HOSPITAL_DREAM_J6"] = _create_node_card(
		"HOSPITAL_DREAM_J6", Vector2(820, 746), Vector2(340, 68),
		"💀 Hospital / Sueño (J6)", "Pierde emboscada nocturna", COLOR_ENDING_BAD, "HOSPITAL_DREAM_BAD", early_j6
	)
	rects["LEAGUE_CHAMPION"] = _create_node_card(
		"LEAGUE_CHAMPION", Vector2(820, 860), Vector2(340, 68),
		"🏆 Ganó la Liga", "1.º puesto con Copa", COLOR_ENDING_GOOD, "LEAGUE_CHAMPION", projected_ending == "LEAGUE_CHAMPION"
	)
	rects["PRO_RUNNER_UP"] = _create_node_card(
		"PRO_RUNNER_UP", Vector2(820, 944), Vector2(340, 68),
		"🥈 Quedó Segundo", "Ascenso Profesional", COLOR_ENDING_GOOD, "PRO_RUNNER_UP", projected_ending == "PRO_RUNNER_UP"
	)
	rects["RELEASED_BAD"] = _create_node_card(
		"RELEASED_BAD", Vector2(820, 1028), Vector2(340, 68),
		"❌ No pasó nada / Descartado", "3.º o peor en la liga", COLOR_ENDING_BAD, "RELEASED_BAD", projected_ending == "RELEASED_BAD"
	)
	rects["PRO_FIGHTER_J8"] = _create_node_card(
		"PRO_FIGHTER_J8", Vector2(820, 1112), Vector2(340, 68),
		"🥊 Camino del Pelea", "Combate dominante (≥ 25)", COLOR_ENDING_ALT, "PRO_FIGHTER_J8", projected_ending == "PRO_FIGHTER_J8"
	)
	rects["HOSPITAL_DREAM_J8"] = _create_node_card(
		"HOSPITAL_DREAM_J8", Vector2(820, 1196), Vector2(340, 68),
		"💀 Derrota Final — Hospital", "Sin piernas / Todo fue un sueño", COLOR_ENDING_BAD, "HOSPITAL_DREAM_BAD", (projected_ending == "HOSPITAL_DREAM_BAD" and not early_j6)
	)

	# --- CONEXIONES IZQUIERDAS (EJE PRINCIPAL) ---
	_add_edge(rects["CREATE_PLAYER"], rects["PROLOGUE_HIT"], "left", true, win_color)
	_add_edge(rects["PROLOGUE_HIT"], rects["SELECT_ACADEMY"], "left", true, win_color)
	_add_edge(rects["SELECT_ACADEMY"], rects["J1"], "left", true, win_color)
	_add_edge(rects["J1"], rects["J2"], "left", true, win_color)
	_add_edge(rects["J2"], rects["J3"], "left", goes_past_j2, win_color)
	_add_edge(rects["J3"], rects["J4"], "left", goes_past_j2, win_color)
	_add_edge(rects["J4"], rects["J5"], "left", goes_past_j4, win_color)
	_add_edge(rects["J5"], rects["J6"], "left", goes_past_j4, win_color)
	_add_edge(rects["J6"], rects["J7"], "left", goes_past_j6, win_color)
	_add_edge(rects["J7"], rects["J8"], "left", goes_past_j6, win_color)
	_add_edge(rects["J8"], rects["GOLDEN_BOY_CHAMPION"], "left", is_golden_boy, COLOR_ENDING_SUPREME)

	# --- CONEXIONES DERECHAS (DESVÍOS TEMPRANOS Y FINALES) ---
	_add_edge(rects["J2"], rects["EXPELLED_EARLY"], "right", early_expelled, COLOR_EDGE_ACTIVE)
	_add_edge(rects["J4"], rects["MID_J4_OFFER"], "right", early_j4, COLOR_EDGE_ACTIVE)
	_add_edge(rects["MID_J4_OFFER"], rects["PRO_FIGHTER_EARLY"], "right", early_j4, COLOR_EDGE_ACTIVE)
	_add_edge(rects["J6"], rects["AMBUSH_J6_BRAWL"], "right", early_j6, COLOR_EDGE_ACTIVE)
	_add_edge(rects["AMBUSH_J6_BRAWL"], rects["HOSPITAL_DREAM_J6"], "right", early_j6, COLOR_EDGE_ACTIVE)

	_add_edge(rects["J8"], rects["POST_J8_CHOICE"], "right", goes_to_j8_right, win_color)
	_add_edge(rects["POST_J8_CHOICE"], rects["LEAGUE_CHAMPION"], "right", projected_ending == "LEAGUE_CHAMPION", COLOR_EDGE_ELITE)
	_add_edge(rects["POST_J8_CHOICE"], rects["PRO_RUNNER_UP"], "right", projected_ending == "PRO_RUNNER_UP", COLOR_EDGE_ELITE)
	_add_edge(rects["POST_J8_CHOICE"], rects["RELEASED_BAD"], "right", projected_ending == "RELEASED_BAD", COLOR_EDGE_ACTIVE)
	_add_edge(rects["POST_J8_CHOICE"], rects["FINAL_BRAWL"], "left", is_brawl_j8, COLOR_EDGE_ACTIVE)
	_add_edge(rects["FINAL_BRAWL"], rects["PRO_FIGHTER_J8"], "right", projected_ending == "PRO_FIGHTER_J8", COLOR_EDGE_ACTIVE)
	_add_edge(rects["FINAL_BRAWL"], rects["HOSPITAL_DREAM_J8"], "right", (projected_ending == "HOSPITAL_DREAM_BAD" and not early_j6), COLOR_EDGE_ACTIVE)

	tree_canvas.update()

func _add_column_header(pos: Vector2, width: float, text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.rect_position = pos
	lbl.rect_size = Vector2(width, 22)
	lbl.align = Label.ALIGN_CENTER
	lbl.modulate = color
	tree_canvas.add_child(lbl)

func _create_node_card(node_id: String, pos: Vector2, size: Vector2, title_txt: String, desc_txt: String, color: Color, jump_target: String, is_favored: bool, force_current: bool = false) -> Rect2:
	var gs = get_node_or_null("/root/GameSettings")
	var is_current = force_current
	if gs and not force_current:
		if gs.story_phase == "ENDING" and gs.ending_id == jump_target:
			is_current = true
		elif gs.story_phase == jump_target and jump_target != "ENDING":
			is_current = true

	var panel = Panel.new()
	panel.name = "Node_" + node_id
	panel.rect_position = pos
	panel.rect_size = size

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	if is_current:
		style.bg_color = Color(0.16, 0.22, 0.30, 0.98)
		style.border_color = Color(1.0, 1.0, 1.0)
	elif is_favored:
		style.bg_color = Color(0.10, 0.14, 0.20, 0.96)
		style.border_color = color
	else:
		style.bg_color = Color(0.07, 0.08, 0.11, 0.78)
		style.border_color = Color(0.26, 0.28, 0.34, 0.8)
	panel.add_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.margin_left = 8
	hbox.margin_top = 6
	hbox.margin_right = -8
	hbox.margin_bottom = -6
	hbox.add_constant_override("separation", 6)
	panel.add_child(hbox)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var lbl_title = Label.new()
	lbl_title.text = ("▶ " + title_txt) if is_current else title_txt
	lbl_title.modulate = Color(1.0, 1.0, 1.0) if is_current else (color if is_favored else Color(0.55, 0.58, 0.65))
	lbl_title.clip_text = true
	vbox.add_child(lbl_title)

	var lbl_desc = Label.new()
	lbl_desc.text = desc_txt
	lbl_desc.modulate = Color(0.85, 0.9, 0.95) if is_favored else Color(0.45, 0.48, 0.54)
	lbl_desc.clip_text = true
	vbox.add_child(lbl_desc)

	var btn = Button.new()
	btn.text = "SALTAR"
	btn.rect_min_size = Vector2(72, 34)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.connect("pressed", self, "_on_jump_pressed", [jump_target])
	hbox.add_child(btn)

	tree_canvas.add_child(panel)
	return Rect2(pos, size)

func _add_edge(from_rect: Rect2, to_rect: Rect2, side: String, is_active: bool, highlight_color: Color) -> void:
	tree_canvas.edges.append({
		"from_rect": from_rect,
		"to_rect": to_rect,
		"side": side,
		"active": is_active,
		"highlight_color": highlight_color
	})

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

func _on_jump_pressed(target: String) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		return

	print("[AdminStoryTree] Saltando a: %s" % target)

	if target.begins_with("LEAGUE_J"):
		var md = int(target.replace("LEAGUE_J", ""))
		gs.story_phase = "LEAGUE"
		gs.ending_id = ""
		_set_stats_for_jump({"matchday": md})
		gs.save_progress({})
	else:
		var is_ending = target in gs.VALID_ENDINGS

		if is_ending:
			gs.set_story_ending("ENDING", target)
		elif target in gs.VALID_PHASES:
			gs.story_phase = target
			gs.ending_id = ""
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

	refresh_tree()

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
