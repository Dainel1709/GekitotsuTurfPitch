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
	# Simulate a tackle attempt by player (should succeed if within range)
	var player = pitch.get_node("Player")
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
