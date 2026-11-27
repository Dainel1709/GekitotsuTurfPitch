extends Spatial

# FootballPitch.gd - Controlador de Cancha y Gestión de Plantillas 11 vs 11

var shared_mesh: CapsuleMesh = null
var shared_shape: CapsuleShape = null

var mat_teammate: SpatialMaterial = null
var mat_opponent: SpatialMaterial = null
var mat_ally_gk: SpatialMaterial = null
var mat_rival_gk: SpatialMaterial = null

var current_rival_formation: String = "4-4-2"
var rival_formations: Array = ["4-4-2", "5-2-3", "4-3-3", "5-3-2"]
var current_rival_formation_idx: int = 0

func _ready() -> void:
	add_to_group("football_pitch")
	_init_shared_resources()
	ensure_11v11_roster()
	apply_formations()

func _init_shared_resources() -> void:
	if not shared_mesh:
		shared_mesh = CapsuleMesh.new()
		shared_mesh.radius = 0.4
		shared_mesh.mid_height = 0.8

	if not shared_shape:
		shared_shape = CapsuleShape.new()
		shared_shape.radius = 0.4
		shared_shape.height = 0.8

	if not mat_teammate:
		mat_teammate = SpatialMaterial.new()
		mat_teammate.albedo_color = Color(0.0, 0.8, 0.85, 1.0) # Cyan / Azul
		mat_teammate.roughness = 0.4

	if not mat_opponent:
		mat_opponent = SpatialMaterial.new()
		mat_opponent.albedo_color = Color(0.85, 0.22, 0.22, 1.0) # Rojo
		mat_opponent.roughness = 0.4

	if not mat_ally_gk:
		mat_ally_gk = SpatialMaterial.new()
		mat_ally_gk.albedo_color = Color(0.2, 0.2, 0.75, 1.0) # Azul oscuro
		mat_ally_gk.roughness = 0.4

	if not mat_rival_gk:
		mat_rival_gk = SpatialMaterial.new()
		mat_rival_gk.albedo_color = Color(0.3, 0.3, 0.3, 1.0) # Gris oscuro
		mat_rival_gk.roughness = 0.5

func ensure_11v11_roster() -> void:
	var ai_actors = get_node_or_null("AIActors")
	if not ai_actors:
		ai_actors = Spatial.new()
		ai_actors.name = "AIActors"
		add_child(ai_actors)

	# 1. Asegurar Equipo Aliado (1 GK aliado + 9 compañeros IA + Ryu = 11 jugadores)
	var ally_gks = []
	for gk in get_tree().get_nodes_in_group("goalkeepers"):
		if "is_player_team" in gk and gk.is_player_team:
			ally_gks.append(gk)

	if ally_gks.empty():
		var ally_gk = _create_player_node("AllyGoalkeeper", "goalkeeper", true, mat_ally_gk)
		ai_actors.add_child(ally_gk)

	var allies = get_tree().get_nodes_in_group("teammates")
	var needed_teammates = 9 - allies.size()
	for i in range(needed_teammates):
		var t_idx = allies.size() + i + 1
		var t_node = _create_player_node("Teammate" + str(t_idx), "teammate", true, mat_teammate)
		ai_actors.add_child(t_node)

	# 2. Asegurar Equipo Rival (1 GK rival + 10 rivales IA = 11 jugadores)
	var rival_gks = []
	for gk in get_tree().get_nodes_in_group("goalkeepers"):
		if "is_player_team" in gk and not gk.is_player_team:
			rival_gks.append(gk)

	if rival_gks.empty():
		var rival_gk = _create_player_node("RivalGoalkeeper", "goalkeeper", false, mat_rival_gk)
		ai_actors.add_child(rival_gk)

	var opponents = get_tree().get_nodes_in_group("opponents")
	var needed_opponents = 10 - opponents.size()
	for i in range(needed_opponents):
		var o_idx = opponents.size() + i + 1
		var o_node = _create_player_node("Opponent" + str(o_idx), "opponent", false, mat_opponent)
		ai_actors.add_child(o_node)

func _create_player_node(node_name: String, role: String, is_player_team: bool, mat: SpatialMaterial) -> KinematicBody:
	var body = KinematicBody.new()
	body.name = node_name
	var ai_script = load("res://scripts/FootballAI.gd")
	body.set_script(ai_script)
	body.role = role
	body.is_player_team = is_player_team

	var mesh_inst = MeshInstance.new()
	mesh_inst.name = "BodyMesh"
	mesh_inst.mesh = shared_mesh
	mesh_inst.transform = Transform(Basis().rotated(Vector3.RIGHT, deg2rad(90)), Vector3.ZERO)
	mesh_inst.set_surface_material(0, mat)
	body.add_child(mesh_inst)

	var col = CollisionShape.new()
	col.name = "CollisionShape"
	col.shape = shared_shape
	col.transform = Transform(Basis().rotated(Vector3.RIGHT, deg2rad(90)), Vector3.ZERO)
	body.add_child(col)

	body.collision_layer = 1
	body.collision_mask = 7
	return body

func apply_formations() -> void:
	apply_ally_formation_4213()

	var matchday = 1
	if get_tree() and get_tree().root and get_tree().root.has_meta("gtp_stats"):
		matchday = int(get_tree().root.get_meta("gtp_stats").get("matchday", 1))
	else:
		var gs = get_node_or_null("/root/GameSettings")
		if gs and gs.has_method("load_progress"):
			matchday = int(gs.load_progress().get("matchday", 1))

	current_rival_formation_idx = int(max(0, matchday - 1)) % rival_formations.size()
	set_rival_formation(rival_formations[current_rival_formation_idx])

func apply_ally_formation_4213() -> void:
	# 1. Ryu como ST en tridente ofensivo
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Spatial:
			p.set("tactical_slot", "ST")
			p.set("home_position", Vector3(0.0, 0.8, -3.5))
			p.set("initial_position", Vector3(0.0, 0.8, -3.5))
			p.global_transform.origin = Vector3(0.0, 0.8, -3.5)

	# 2. Portero Aliado en Sur (Z = 26.5)
	for gk in get_tree().get_nodes_in_group("goalkeepers"):
		if "is_player_team" in gk and gk.is_player_team:
			gk.tactical_slot = "GK"
			gk.home_position = Vector3(0.0, 0.8, 26.5)
			gk.initial_position = Vector3(0.0, 0.8, 26.5)
			gk.formation_name = "4-2-1-3"
			gk.global_transform.origin = Vector3(0.0, 0.8, 26.5)

	# 3. 9 Compañeros IA en 4-2-1-3
	var slots = [
		{"slot": "LB", "pos": Vector3(-13.0, 0.8, 19.0)},
		{"slot": "LCB", "pos": Vector3(-4.5, 0.8, 20.0)},
		{"slot": "RCB", "pos": Vector3(4.5, 0.8, 20.0)},
		{"slot": "RB", "pos": Vector3(13.0, 0.8, 19.0)},
		{"slot": "LDM", "pos": Vector3(-5.0, 0.8, 12.0)},
		{"slot": "RDM", "pos": Vector3(5.0, 0.8, 12.0)},
		{"slot": "CAM", "pos": Vector3(0.0, 0.8, 6.0)},
		{"slot": "LW", "pos": Vector3(-12.0, 0.8, -3.0)},
		{"slot": "RW", "pos": Vector3(12.0, 0.8, -3.0)}
	]
	var teammates = get_tree().get_nodes_in_group("teammates")
	for i in range(min(teammates.size(), slots.size())):
		var tm = teammates[i]
		tm.tactical_slot = slots[i]["slot"]
		tm.home_position = slots[i]["pos"]
		tm.initial_position = slots[i]["pos"]
		tm.formation_name = "4-2-1-3"
		tm.global_transform.origin = slots[i]["pos"]

func set_rival_formation(form_name: String) -> void:
	current_rival_formation = form_name
	current_rival_formation_idx = rival_formations.find(form_name)
	if current_rival_formation_idx == -1:
		current_rival_formation_idx = 0

	# Portero Rival en Norte (Z = -26.5)
	for gk in get_tree().get_nodes_in_group("goalkeepers"):
		if "is_player_team" in gk and not gk.is_player_team:
			gk.tactical_slot = "GK"
			gk.home_position = Vector3(0.0, 0.8, -26.5)
			gk.initial_position = Vector3(0.0, 0.8, -26.5)
			gk.formation_name = form_name
			gk.global_transform.origin = Vector3(0.0, 0.8, -26.5)

	var formation_slots = {
		"4-4-2": [
			{"slot": "LB", "pos": Vector3(-13.0, 0.8, -19.0)},
			{"slot": "LCB", "pos": Vector3(-4.5, 0.8, -20.0)},
			{"slot": "RCB", "pos": Vector3(4.5, 0.8, -20.0)},
			{"slot": "RB", "pos": Vector3(13.0, 0.8, -19.0)},
			{"slot": "LM", "pos": Vector3(-12.5, 0.8, -10.0)},
			{"slot": "LCM", "pos": Vector3(-4.0, 0.8, -10.5)},
			{"slot": "RCM", "pos": Vector3(4.0, 0.8, -10.5)},
			{"slot": "RM", "pos": Vector3(12.5, 0.8, -10.0)},
			{"slot": "LST", "pos": Vector3(-4.0, 0.8, -2.5)},
			{"slot": "RST", "pos": Vector3(4.0, 0.8, -2.5)}
		],
		"5-2-3": [
			{"slot": "LWB", "pos": Vector3(-14.0, 0.8, -17.0)},
			{"slot": "LCB", "pos": Vector3(-7.0, 0.8, -20.0)},
			{"slot": "CB", "pos": Vector3(0.0, 0.8, -21.0)},
			{"slot": "RCB", "pos": Vector3(7.0, 0.8, -20.0)},
			{"slot": "RWB", "pos": Vector3(14.0, 0.8, -17.0)},
			{"slot": "LCM", "pos": Vector3(-4.5, 0.8, -10.0)},
			{"slot": "RCM", "pos": Vector3(4.5, 0.8, -10.0)},
			{"slot": "LW", "pos": Vector3(-12.0, 0.8, -3.0)},
			{"slot": "ST", "pos": Vector3(0.0, 0.8, -3.5)},
			{"slot": "RW", "pos": Vector3(12.0, 0.8, -3.0)}
		],
		"4-3-3": [
			{"slot": "LB", "pos": Vector3(-13.0, 0.8, -19.0)},
			{"slot": "LCB", "pos": Vector3(-4.5, 0.8, -20.0)},
			{"slot": "RCB", "pos": Vector3(4.5, 0.8, -20.0)},
			{"slot": "RB", "pos": Vector3(13.0, 0.8, -19.0)},
			{"slot": "LCM", "pos": Vector3(-6.0, 0.8, -10.0)},
			{"slot": "CM", "pos": Vector3(0.0, 0.8, -11.5)},
			{"slot": "RCM", "pos": Vector3(6.0, 0.8, -10.0)},
			{"slot": "LW", "pos": Vector3(-12.0, 0.8, -3.0)},
			{"slot": "ST", "pos": Vector3(0.0, 0.8, -3.5)},
			{"slot": "RW", "pos": Vector3(12.0, 0.8, -3.0)}
		],
		"5-3-2": [
			{"slot": "LWB", "pos": Vector3(-14.0, 0.8, -17.0)},
			{"slot": "LCB", "pos": Vector3(-7.0, 0.8, -20.0)},
			{"slot": "CB", "pos": Vector3(0.0, 0.8, -21.0)},
			{"slot": "RCB", "pos": Vector3(7.0, 0.8, -20.0)},
			{"slot": "RWB", "pos": Vector3(14.0, 0.8, -17.0)},
			{"slot": "LCM", "pos": Vector3(-6.0, 0.8, -10.0)},
			{"slot": "CM", "pos": Vector3(0.0, 0.8, -11.0)},
			{"slot": "RCM", "pos": Vector3(6.0, 0.8, -10.0)},
			{"slot": "LST", "pos": Vector3(-4.0, 0.8, -2.5)},
			{"slot": "RST", "pos": Vector3(4.0, 0.8, -2.5)}
		]
	}

	var slots = formation_slots.get(form_name, formation_slots["4-4-2"])
	var opponents = get_tree().get_nodes_in_group("opponents")
	for i in range(min(opponents.size(), slots.size())):
		var opp = opponents[i]
		opp.tactical_slot = slots[i]["slot"]
		opp.home_position = slots[i]["pos"]
		opp.initial_position = slots[i]["pos"]
		opp.formation_name = form_name
		# Reposicionar suavemente si está iniciando o en reposición
		if opp.velocity.length_squared() < 0.1:
			opp.global_transform.origin = slots[i]["pos"]

	print("[FootballPitch] Formación táctica rival actualizada a: ", form_name)
