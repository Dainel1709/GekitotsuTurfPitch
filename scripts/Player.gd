extends KinematicBody

class_name Player

# Referencia a la clase backend de C++ (FootballMechanics en GDExtension)
var mechanics = null

# Configuración de Disparo y Balón
export var fallback_base_kick_force: float = 16.0
export var fallback_max_kick_force: float = 28.0
export var kick_reach: float = 1.65
export var dribble_distance: float = 1.2
export var charge_speed: float = 2.4 # Carga completa en ~0.42 segundos

# Estado de Disparo y Balón
var shot_charge: float = 0.0
var is_charging: bool = false
var facing_direction: Vector3 = Vector3(0.0, 0.0, -1.0) # Orientado hacia la portería rival (Z negativo)
var ball_ref: RigidBody = null
var is_colliding_with_ball: bool = false
var is_ball_in_kick_area: bool = false

# Variables de respaldo local (Fallback si la librería nativa no está cargada)
var fallback_base_speed: float = 10.0
var fallback_stamina: float = 100.0
var fallback_max_stamina: float = 100.0

var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("player")

	# Conectar KickArea si existe en la escena
	if has_node("KickArea"):
		var kick_area = get_node("KickArea")
		kick_area.connect("body_entered", self, "_on_kick_area_body_entered")
		kick_area.connect("body_exited", self, "_on_kick_area_body_exited")

	# Enlace dinámico con la clase C++ FootballMechanics
	if ClassDB.class_exists("FootballMechanics"):
		if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("FootballMechanics"):
			mechanics = ClassDB.instantiate("FootballMechanics")
		elif ClassDB.has_method("can_instance") and ClassDB.can_instance("FootballMechanics"):
			mechanics = ClassDB.instance("FootballMechanics")
		
		if mechanics:
			add_child(mechanics)
			print("[Player] Vinculado exitosamente con FootballMechanics (C++ Backend)")

func _physics_process(delta: float) -> void:
	# 1. Resolver referencia al balón si es necesario
	_resolve_ball_reference()

	# 2. Capturar el input 2D (Flechas direccionales o WASD)
	var input_2d := Vector2.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up"):
		input_2d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down"):
		input_2d.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
		input_2d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right"):
		input_2d.x += 1.0

	var is_sprinting: bool = Input.is_key_pressed(KEY_SHIFT)

	# Normalizar input diagonal
	if input_2d.length_squared() > 1.0:
		input_2d = input_2d.normalized()

	# 3. Transformar input 2D en movimiento 3D restringido a los ejes X y Z (Y = 0)
	var move_direction := Vector3(input_2d.x, 0.0, input_2d.y)
	var is_moving: bool = move_direction.length_squared() > 0.001

	if is_moving:
		facing_direction = move_direction.normalized()

	# 4. Gestión de Disparo / Pateo (Barra Espaciadora / ui_select)
	_handle_shot_mechanic(delta)

	# 5. Conexión con el backend de C++ para velocidad y drenaje de estamina
	var current_speed: float = 0.0

	if mechanics:
		mechanics.set_moving(is_moving)
		mechanics.set_sprinting(is_sprinting)
		mechanics.update_stamina(delta)
		current_speed = mechanics.get_current_speed()
	else:
		if is_moving:
			var drain: float = 35.0 if is_sprinting else 20.0
			fallback_stamina = max(0.0, fallback_stamina - drain * delta)
		else:
			fallback_stamina = min(fallback_max_stamina, fallback_stamina + 15.0 * delta)
		
		var fatigue: float = 0.4 if fallback_stamina <= 0.0 else 1.0
		var sprint_mult: float = 1.6 if (is_sprinting and fallback_stamina > 0.0) else 1.0
		current_speed = fallback_base_speed * sprint_mult * fatigue

	# Reducción de velocidad mientras prepara un tiro cargado
	if is_charging:
		current_speed *= 0.65

	# Aplicar velocidad solo a X y Z (Y = 0)
	velocity.x = move_direction.x * current_speed
	velocity.y = 0.0
	velocity.z = move_direction.z * current_speed

	velocity = move_and_slide(velocity, Vector3.UP)

	# 6. Detección de colisión directa con el balón mediante move_and_slide
	is_colliding_with_ball = false
	var slide_count = get_slide_count()
	for i in range(slide_count):
		var col = get_slide_collision(i)
		if col and col.collider and col.collider.is_in_group("ball"):
			is_colliding_with_ball = true
			if col.collider is RigidBody:
				ball_ref = col.collider as RigidBody
				
				# Conducción / empuje suave arcade al avanzar sobre el balón
				if not is_charging and velocity.length_squared() > 0.1:
					var push_dir = -col.normal
					push_dir.y = 0.0
					var push_impulse = push_dir.normalized() * (velocity.length() * 0.35)
					ball_ref.apply_central_impulse(push_impulse)

	# Rotar hacia la dirección de avance
	if is_moving:
		var target_pos: Vector3 = translation + move_direction
		target_pos.y = translation.y
		look_at(target_pos, Vector3.UP)

func _on_kick_area_body_entered(body: Node) -> void:
	if body.is_in_group("ball"):
		is_ball_in_kick_area = true
		if body is RigidBody:
			ball_ref = body as RigidBody

func _on_kick_area_body_exited(body: Node) -> void:
	if body == ball_ref or body.is_in_group("ball"):
		is_ball_in_kick_area = false

func _resolve_ball_reference() -> void:
	if ball_ref == null or not is_instance_valid(ball_ref):
		var balls = get_tree().get_nodes_in_group("ball")
		for b in balls:
			if b is RigidBody:
				ball_ref = b
				break

func _handle_shot_mechanic(delta: float) -> void:
	var shoot_pressed: bool = Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_select") or Input.is_action_pressed("ui_accept")

	if shoot_pressed:
		is_charging = true
		shot_charge = min(1.0, shot_charge + charge_speed * delta)
	else:
		if is_charging:
			# Disparar al soltar la tecla
			_execute_kick()
			is_charging = false
			shot_charge = 0.0

func _execute_kick() -> void:
	if not ball_ref or not is_instance_valid(ball_ref):
		return

	var dist_to_ball = translation.distance_to(ball_ref.translation)
	# Puede patear si está en contacto por colisión, dentro del área frontal o en rango de distancia
	if is_colliding_with_ball or is_ball_in_kick_area or dist_to_ball <= kick_reach:
		# Dirección del disparo
		var kick_dir = facing_direction
		if velocity.length_squared() > 1.0:
			kick_dir = (facing_direction * 0.7 + velocity.normalized() * 0.3).normalized()
		elif dist_to_ball > 0.01:
			var to_ball = (ball_ref.global_transform.origin - global_transform.origin)
			to_ball.y = 0.0
			if to_ball.length_squared() > 0.01:
				kick_dir = (facing_direction * 0.5 + to_ball.normalized() * 0.5).normalized()

		# Obtener vector de fuerza calculado por el backend de C++
		var kick_impulse: Vector3 = _calculate_kick_vector(kick_dir, shot_charge)

		# Aplicar impulso central al RigidBody del balón
		ball_ref.apply_central_impulse(kick_impulse)

		# Drenar estamina por el esfuerzo físico de la patada
		var stamina_cost = 7.0 + shot_charge * 13.0
		drain_stamina(stamina_cost)

		print("[Player] ¡Patada ejecutada! Vector impulso: ", kick_impulse, " | Carga: ", stepify(shot_charge * 100, 1), "%")

func _calculate_kick_vector(kick_dir: Vector3, charge: float) -> Vector3:
	if mechanics:
		# Llamar al método C++ calculate_kick_force
		if mechanics.has_method("calculate_kick_force"):
			var res = mechanics.calculate_kick_force(kick_dir.x, kick_dir.z, charge)
			if typeof(res) == TYPE_VECTOR3:
				return res
			elif typeof(res) == TYPE_REAL or typeof(res) == TYPE_INT:
				var mag = float(res)
				var vy = min(1.6, mag * (0.04 + 0.05 * charge))
				return Vector3(kick_dir.x * mag, vy, kick_dir.z * mag)
		elif mechanics.has_method("calculate_kick_force_magnitude"):
			var mag = mechanics.calculate_kick_force_magnitude(charge)
			var vy = min(1.6, mag * (0.04 + 0.05 * charge))
			return Vector3(kick_dir.x * mag, vy, kick_dir.z * mag)

	# Fallback si no está cargada la DLL nativa
	var charge_clamped = clamp(charge, 0.0, 1.0)
	var raw_force = fallback_base_kick_force + (fallback_max_kick_force - fallback_base_kick_force) * charge_clamped
	var stamina_ratio = fallback_stamina / fallback_max_stamina
	var stamina_factor = 1.0 if stamina_ratio >= 0.3 else (0.5 + 0.5 * (stamina_ratio / 0.3))
	var final_force = raw_force * stamina_factor
	var vy = min(1.6, final_force * (0.04 + 0.05 * charge_clamped))
	return Vector3(kick_dir.x * final_force, vy, kick_dir.z * final_force)

func drain_stamina(amount: float) -> void:
	if mechanics:
		if mechanics.has_method("drain_stamina"):
			mechanics.drain_stamina(amount)
		else:
			var cur = mechanics.get_stamina()
			mechanics.set_stamina(max(0.0, cur - amount))
	else:
		fallback_stamina = max(0.0, fallback_stamina - amount)

# --- Métodos Públicos para Consulta y UI/HUD ---

func get_shot_charge() -> float:
	return shot_charge

func is_charging_shot() -> bool:
	return is_charging

func is_ball_in_range() -> bool:
	if is_colliding_with_ball or is_ball_in_kick_area:
		return true
	if ball_ref and is_instance_valid(ball_ref):
		return translation.distance_to(ball_ref.translation) <= kick_reach
	return false

func get_stamina() -> float:
	if mechanics:
		return mechanics.get_stamina()
	return fallback_stamina

func get_max_stamina() -> float:
	if mechanics:
		return mechanics.get_max_stamina()
	return fallback_max_stamina

func get_current_speed() -> float:
	if mechanics:
		return mechanics.get_current_speed()
	return fallback_base_speed
