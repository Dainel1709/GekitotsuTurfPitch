extends RigidBody

class_name FootballBall

# Parámetros físicos arcade en 2.5D
export var max_vertical_velocity: float = 1.8   # Limita los rebotes excesivos en Y
export var max_height: float = 2.2              # Altura máxima permitida
export var grass_rolling_damp: float = 1.2      # Desaceleración en césped

onready var shadow_node: Spatial = $Shadow
onready var mesh_node: MeshInstance = $BallMesh

func _ready() -> void:
	add_to_group("ball")
	continuous_cd = true
	can_sleep = false
	contact_monitor = true
	contacts_reported = 4

func _integrate_forces(state: PhysicsDirectBodyState) -> void:
	# 1. Limitar la velocidad vertical en Y para mantener el juego arcade y responsivo en X/Z
	if state.linear_velocity.y > max_vertical_velocity:
		state.linear_velocity.y = max_vertical_velocity

	# 2. Amortiguar ascensos pronunciados para que la pelota no vuele fuera de la vista cenital
	if state.transform.origin.y > 0.4 and state.linear_velocity.y > 0.0:
		state.linear_velocity.y *= 0.92

	# 3. Mantener el balón en contacto y rodadura sobre el césped (Y = 0.25 m)
	if state.transform.origin.y < 0.24:
		var t = state.transform
		t.origin.y = 0.25
		state.transform = t
		if state.linear_velocity.y < 0.0:
			state.linear_velocity.y = -state.linear_velocity.y * 0.35

func _physics_process(_delta: float) -> void:
	_update_shadow()

func _update_shadow() -> void:
	if not shadow_node or not is_instance_valid(shadow_node):
		return

	# La sombra permanece proyectada en el plano del césped (Y = 0.02)
	shadow_node.global_transform.origin = Vector3(global_transform.origin.x, 0.02, global_transform.origin.z)

	# Escalar y atenuar la sombra según la altura del balón
	var height = max(0.0, translation.y - 0.25)
	var scale_factor = clamp(1.0 - (height / 3.0), 0.35, 1.0)
	shadow_node.scale = Vector3(scale_factor, 1.0, scale_factor)

# --- Métodos Públicos para Interacción ---

func apply_kick(impulse: Vector3) -> void:
	# Aplicar impulso central al RigidBody
	apply_central_impulse(impulse)

func get_speed() -> float:
	return linear_velocity.length()

func reset_ball(pos: Vector3 = Vector3(0.0, 0.25, 0.0)) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	translation = pos
