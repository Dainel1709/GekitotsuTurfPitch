extends Camera

# Dynamic camera that follows the ball while keeping the player (Ryu) in view
# and preserving the angled aerial perspective set on OverheadCamera.

export var tilt_x_deg: float = -74.0
export var base_height: float = 40.0
export var max_height: float = 62.0
export var z_offset_from_tilt: float = 19.0
export var margin: float = 10.0
export var look_ahead_dist: float = 8.0
export var smooth_speed: float = 5.0

# Fallback values if used in orthogonal mode
export var min_size: float = 42.0
export var max_size: float = 76.0

var player = null
var ball = null

func _ready():
	current = true
	rotation_degrees = Vector3(tilt_x_deg, 0.0, 0.0)
	_refresh_targets()

func _refresh_targets():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	elif has_node("../Player"):
		player = get_node("../Player")

	var balls = get_tree().get_nodes_in_group("ball")
	if balls.size() > 0:
		ball = balls[0]
	elif has_node("../FootballBall"):
		ball = get_node("../FootballBall")

func _process(delta):
	if not is_instance_valid(player) or not is_instance_valid(ball):
		_refresh_targets()
		if not is_instance_valid(player) or not is_instance_valid(ball):
			return

	var player_pos = player.global_transform.origin
	var ball_pos = ball.global_transform.origin

	# Focus weighted towards the ball while anchoring Ryu in frame
	var focus = player_pos.linear_interpolate(ball_pos, 0.65)

	# Slight look-ahead towards north or south goal in the final third
	var field_z_half = 45.0
	if ball_pos.z > field_z_half * 0.66:
		focus.z += look_ahead_dist
	elif ball_pos.z < -field_z_half * 0.66:
		focus.z -= look_ahead_dist

	# Keep the slight aerial tilt angle intact
	rotation_degrees = Vector3(tilt_x_deg, 0.0, 0.0)

	# Dynamic distance/height based on separation between player and ball
	var dx = abs(ball_pos.x - player_pos.x)
	var dz = abs(ball_pos.z - player_pos.z)
	var spread = (dx + dz + margin) * 0.45

	var desired_y = clamp(base_height + spread * 0.35, base_height, max_height)
	var desired_x = clamp(focus.x, -18.0, 18.0)
	var desired_z = clamp(focus.z + z_offset_from_tilt, -52.0, 52.0)

	var blend = clamp(smooth_speed * delta, 0.0, 1.0)
	var next_pos = translation
	next_pos.x = lerp(next_pos.x, desired_x, blend)
	next_pos.y = lerp(next_pos.y, desired_y, blend)
	next_pos.z = lerp(next_pos.z, desired_z, blend)
	translation = next_pos

	if projection == PROJECTION_ORTHOGONAL:
		var desired_size = clamp(min_size + (dx + dz + margin) * 0.5, min_size, max_size)
		size = lerp(size, desired_size, blend)
