extends Camera

# Dynamic orthographic camera that follows the ball while keeping the player (Ryu) in view.
# Attach to the OverheadCamera node in FootballPitch.tscn.

var min_size: float = 18.0
var max_size: float = 38.0
var margin: float = 10.0
var look_ahead_dist: float = 6.0
var smooth_speed: float = 5.0

onready var player: Node = null
onready var ball: Node = null

func _ready() -> void:
    # Ensure orthogonal projection
    projection = PROJECTION_ORTHOGONAL
    rotation_degrees = Vector3(-90, 0, 0)
    # Find player and ball nodes
    var players = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        player = players[0]
    var balls = get_tree().get_nodes_in_group("ball")
    if balls.size() > 0:
        ball = balls[0]

func _process(delta: float) -> void:
    if not player or not ball:
        return
    var player_pos: Vector3 = player.global_transform.origin
    var ball_pos: Vector3 = ball.global_transform.origin

    # Interpolated focus point weighted towards ball but anchored to player
    var focus: Vector3 = player_pos.linear_interpolate(ball_pos, 0.65)

    # Look‑ahead when ball is in the last third of the field (north or south)
    var field_z_half: float = 12.0
    if ball_pos.z > field_z_half * 0.66:
        focus.z += look_ahead_dist
    elif ball_pos.z < -field_z_half * 0.66:
        focus.z -= look_ahead_dist

    # Smooth translation towards focus (keep Y unchanged)
    var target_translation: Vector3 = translation
    target_translation.x = lerp(target_translation.x, focus.x, clamp(smooth_speed * delta, 0.0, 1.0))
    target_translation.z = lerp(target_translation.z, focus.z, clamp(smooth_speed * delta, 0.0, 1.0))
    # Clamp to field bounds (+/-19, +/-12) with a small margin
    target_translation.x = clamp(target_translation.x, -19.0 + 1.0, 19.0 - 1.0)
    target_translation.z = clamp(target_translation.z, -12.0 + 1.0, 12.0 - 1.0)
    translation = target_translation

    # Dynamic zoom based on distance between player and ball
    var dx: float = abs(ball_pos.x - player_pos.x)
    var dz: float = abs(ball_pos.z - player_pos.z)
    var desired: float = min_size + (dx + dz + margin) * 0.5
    desired = clamp(desired, min_size, max_size)
    size = lerp(size, desired, clamp(smooth_speed * delta, 0.0, 1.0))
