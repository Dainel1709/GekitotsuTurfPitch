extends KinematicBody

class_name Ball

# Enlace dinámico con el backend C++ (BallMechanics en GDExtension)
var mechanics = null

# Configuración física
export var radius: float = 0.25
export var bounciness: float = 0.75
export var ground_friction: float = 1.85
export var gravity: float = 19.6

# Variables físicas locales / Fallback GDScript
var velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO

# Nodos hijos
onready var mesh_instance: MeshInstance = $BallMesh
onready var shadow_instance: Spatial = $Shadow

func _ready() -> void:
	add_to_group("ball")
	
	# Intentar instanciar la clase C++ BallMechanics
	if ClassDB.class_exists("BallMechanics"):
		if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("BallMechanics"):
			mechanics = ClassDB.instantiate("BallMechanics")
		elif ClassDB.has_method("can_instance") and ClassDB.can_instance("BallMechanics"):
			mechanics = ClassDB.instance("BallMechanics")
		
		if mechanics:
			add_child(mechanics)
			mechanics.set_position(translation.x, translation.y, translation.z)
			mechanics.set_friction(ground_friction)
			mechanics.set_restitution(bounciness)
			mechanics.set_radius(radius)
			print("[Ball] Enlazado exitosamente con BallMechanics (C++ Backend)")

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return

	if mechanics:
		# 1. Simulación impulsada por el núcleo de C++
		mechanics.update(delta)
		
		var sim_vx: float = mechanics.get_vel_x()
		var sim_vy: float = mechanics.get_vel_y()
		var sim_vz: float = mechanics.get_vel_z()
		velocity = Vector3(sim_vx, sim_vy, sim_vz)
		
		# Movimiento y detección de colisiones con el entorno
		var motion = velocity * delta
		var collision = move_and_collide(motion)
		
		if collision:
			var normal = collision.normal
			
			# Rebote horizontal contra paredes y obstáculos
			if abs(normal.x) > 0.001 or abs(normal.z) > 0.001:
				mechanics.bounce(normal.x, normal.z, bounciness)
				velocity.x = mechanics.get_vel_x()
				velocity.z = mechanics.get_vel_z()
			
			# Si colisiona verticalmente (ej. poste o suelo)
			if abs(normal.y) > 0.5 and velocity.y < 0.0:
				velocity.y = -velocity.y * 0.55
				mechanics.set_velocity(velocity.x, velocity.y, velocity.z)
		
		# Sincronizar posición de vuelta con C++
		mechanics.set_position(translation.x, translation.y, translation.z)
	else:
		# 2. Fallback de físicas matemáticas puras en GDScript
		_process_fallback_physics(delta)

	# 3. Rodamiento visual del balón
	_update_visual_rotation(delta)

	# 4. Actualizar sombra cenital 2.5D proyectada en el césped
	_update_shadow()

func _process_fallback_physics(delta: float) -> void:
	var airborne = translation.y > (radius + 0.02) or abs(velocity.y) > 0.1
	
	if airborne:
		velocity.y -= gravity * delta
		velocity.x -= velocity.x * 0.12 * delta
		velocity.z -= velocity.z * 0.12 * delta
	else:
		translation.y = radius
		velocity.y = 0.0
		var h_speed = Vector2(velocity.x, velocity.z).length()
		if h_speed > 0.05:
			var drop = ground_friction * 9.8 * delta
			var new_speed = max(0.0, h_speed - drop)
			var ratio = new_speed / h_speed
			velocity.x *= ratio
			velocity.z *= ratio
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	
	var collision = move_and_collide(velocity * delta)
	if collision:
		var normal = collision.normal
		if abs(normal.x) > 0.001 or abs(normal.z) > 0.001:
			var dot = velocity.x * normal.x + velocity.z * normal.z
			if dot < 0.0:
				velocity.x -= (1.0 + bounciness) * dot * normal.x
				velocity.z -= (1.0 + bounciness) * dot * normal.z
		
		if abs(normal.y) > 0.5 and velocity.y < 0.0:
			if velocity.y < -1.5:
				velocity.y = -velocity.y * 0.55
			else:
				velocity.y = 0.0

	# Mantener siempre sobre el césped
	if translation.y < radius:
		translation.y = radius
		if velocity.y < 0.0:
			velocity.y = 0.0

func _update_visual_rotation(delta: float) -> void:
	if not mesh_instance:
		return
	
	var h_velocity = Vector3(velocity.x, 0.0, velocity.z)
	var speed = h_velocity.length()
	if speed > 0.1:
		# El eje de rotación es perpendicular a la dirección del movimiento
		var roll_axis = h_velocity.cross(Vector3.UP).normalized()
		var angular_step = (speed / radius) * delta
		mesh_instance.rotate(roll_axis, angular_step)

func _update_shadow() -> void:
	if not shadow_instance:
		return
	
	# La sombra permanece fija en el césped (Y = 0.02)
	shadow_instance.global_transform.origin = Vector3(global_transform.origin.x, 0.02, global_transform.origin.z)
	
	# Escala y desvanecimiento según altura
	var height = max(0.0, translation.y - radius)
	var factor = clamp(1.0 - (height / 6.0), 0.25, 1.0)
	shadow_instance.scale = Vector3(factor, 1.0, factor)

# --- Métodos Públicos de Jugabilidad ---

func kick(direction: Vector3, force: float, elevation: float = 0.0) -> void:
	var dir_2d = Vector2(direction.x, direction.z).normalized()
	if mechanics:
		mechanics.kick(dir_2d.x, dir_2d.y, force, elevation)
		velocity.x = mechanics.get_vel_x()
		velocity.y = mechanics.get_vel_y()
		velocity.z = mechanics.get_vel_z()
	else:
		velocity.x = dir_2d.x * force
		velocity.z = dir_2d.y * force
		velocity.y = elevation * force * 0.55

func dribble(player_velocity: Vector3) -> void:
	var move_speed = player_velocity.length()
	if move_speed > 0.1:
		var dir_2d = Vector2(player_velocity.x, player_velocity.z).normalized()
		if mechanics:
			mechanics.dribble(dir_2d.x, dir_2d.y, move_speed)
			velocity.x = mechanics.get_vel_x()
			velocity.z = mechanics.get_vel_z()
		else:
			var target_speed = move_speed * 1.15
			velocity.x = dir_2d.x * target_speed
			velocity.z = dir_2d.y * target_speed

func apply_impulse(impulse: Vector3) -> void:
	if mechanics:
		mechanics.apply_impulse(impulse.x, impulse.y, impulse.z)
		velocity.x = mechanics.get_vel_x()
		velocity.y = mechanics.get_vel_y()
		velocity.z = mechanics.get_vel_z()
	else:
		velocity += impulse

func get_speed() -> float:
	if mechanics:
		return mechanics.get_speed()
	return velocity.length()

func reset(pos: Vector3 = Vector3(0, 0.25, 0)) -> void:
	translation = pos
	velocity = Vector3.ZERO
	if mechanics:
		mechanics.reset(pos.x, pos.y, pos.z)
