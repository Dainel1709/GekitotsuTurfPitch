extends Node

# Simple headless test for FootballAI behaviors
# This test runs automatically and quits the engine after checks.

func _ready():
	# Load the scene
	var pitch_scene = load("res://scenes/FootballPitch.tscn")
	var pitch = pitch_scene.instance()
	add_child(pitch)
	# Wait for next frame to ensure nodes are ready
	yield(get_tree(), "idle_frame")
	# Access AI actors
	var ai_root = pitch.get_node("AIActors")
	var rival_gk = ai_root.get_node("RivalGoalkeeper")
	var ally_gk = ai_root.get_node("AllyGoalkeeper")
	var opponent1 = ai_root.get_node("Opponent1")
	var teammate1 = ai_root.get_node("Teammate1")
	# Simple assertions (prints for verification)
	print("[Test] Rival GK role: %s" % rival_gk.role)
	print("[Test] Ally GK team: %s" % str(ally_gk.is_player_team))

	# Verificar velocidades base actualizadas de los NPCs
	assert(abs(opponent1.move_speed - 7.4) < 0.001, "move_speed de opponent1 debe ser 7.4")
	assert(abs(opponent1.dribble_speed - 7.0) < 0.001, "dribble_speed de opponent1 debe ser 7.0")
	assert(abs(opponent1.sprint_speed - 10.4) < 0.001, "sprint_speed de opponent1 debe ser 10.4")
	assert(abs(teammate1.move_speed - 7.4) < 0.001, "move_speed de teammate1 debe ser 7.4")
	assert(abs(teammate1.dribble_speed - 7.0) < 0.001, "dribble_speed de teammate1 debe ser 7.0")
	assert(abs(teammate1.sprint_speed - 10.4) < 0.001, "sprint_speed de teammate1 debe ser 10.4")
	print("[Test] Velocidades de NPCs verificadas OK (move=7.4, dribble=7.0, sprint=10.4)")

	# Verificar diferenciación de color y materiales entre Player y Opponents
	var player = pitch.get_node("Player")
	assert(player.has_node("IndicatorRing"), "Player debe poseer IndicatorRing visible")
	var player_mesh = player.get_node("PlayerMesh")
	var opp_mesh1 = opponent1.get_node("OppMesh1")
	assert(player_mesh.material_override != null, "player_mesh debe tener material_override")
	assert(opp_mesh1.material_override != null, "opp_mesh1 debe tener material_override")
	assert(player_mesh.material_override != opp_mesh1.material_override, "Player y Opponent no deben compartir material")
	var p_color = player_mesh.material_override.albedo_color
	var opp_color = opp_mesh1.material_override.albedo_color
	assert(p_color != opp_color, "Color de Player debe ser diferente al de los rivales")
	assert(opp_color.r > 0.8 and opp_color.g < 0.3, "Opponent debe ser rojo intenso")
	assert(p_color.b > 0.8 and p_color.r < 0.3, "Player debe ser azul eléctrico brillante")
	print("[Test] Diferenciación visual Player (azul) vs Opponents (rojo) OK")
	# Position player near opponent
	player.global_transform.origin = Vector3(-4.0, 0.8, -3.5)
	opponent1.global_transform.origin = Vector3(-4.0, 0.8, -4.0)
	# Force a tackle via player action (press cross)
	player._execute_tackle()
	# Check if opponent lost ball
	print("[Test] Opponent has_ball after tackle: %s" % str(opponent1.has_ball))
	# Request pass from teammate to player via L button call
	player._on_button_l_pressed()
	# Verify teammate received pass call (should have printed in console)
	print("[Test] Pass request executed.")
	# End test
	get_tree().quit()
