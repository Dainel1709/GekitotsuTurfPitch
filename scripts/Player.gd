extends KinematicBody

class_name Player

# Referencia a la clase backend de C++ (FootballMechanics en GDExtension)
var mechanics = null

# Configuración de Disparo y Balón
export var min_shot_power: float = 12.0
export var max_shot_power: float = 28.0
export var kick_reach: float = 1.6
export var dribble_distance: float = 1.15
export var charge_speed: float = 2.2 # Tiempo de carga completa ~0.45s

# Estado de Disparo y Balón
var shot_charge: float = 0.0
var is_charging: bool = false
var facing_direction: Vector3 = Vector3(1.0, 0.0, 0.0)
var ball_ref: Spatial = null

# Variables de respaldo local (Fallback si la librería nativa no está cargada)
var fallback_base_speed: float = 10.0
var fallback_stamina: float = 100.0
var fallback_max_stamina: float = 100.0

var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("player")

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
	# 1. Obtener referencia al balón si aún no se tiene
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

	# Rotar hacia la dirección de avance
	if is_moving:
		var target_pos: Vector3 = translation + move_direction
		target_pos.y = translation.y
		look_at(target_pos, Vector3.UP)

	# 6. Conducción / Dribling suave al caminar sobre el balón
	if is_moving and not is_charging and ball_ref and is_instance_valid(ball_ref):
		var dist_to_ball = translation.distance_to(ball_ref.translation)
		if dist_to_ball <= dribble_distance:
			if ball_ref.has_method("dribble"):
				ball_ref.dribble(velocity)

func _resolve_ball_reference() -> void:
	if ball_ref == null or not is_instance_valid(ball_ref):
		var balls = get_tree().get_nodes_in_group("ball")
		if balls.size() > 0:
			ball_ref = balls[0]

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

	var dist = translation.distance_to(ball_ref.translation)
	if dist <= kick_reach:
		# Dirección de disparo: orientada hacia donde mira el jugador
		var kick_dir = facing_direction
		if velocity.length_squared() > 1.0:
			kick_dir = (facing_direction * 0.7 + velocity.normalized() * 0.3).normalized()

		# Factor de fatiga según estamina actual
		var current_sta = get_stamina()
		var fatigue_factor = 0.7 if current_sta < 20.0 else 1.0

		# Potencia y elevación parabólica proporcional a la carga
		var power = lerp(min_shot_power, max_shot_power, shot_charge) * fatigue_factor
		var elevation = lerp(0.05, 0.45, shot_charge)

		if ball_ref.has_method("kick"):
			ball_ref.kick(kick_dir, power, elevation)

		# Drenar estamina por el esfuerzo del disparo en el backend C++
		var stamina_cost = 6.0 + shot_charge * 14.0
		drain_stamina(stamina_cost)
		print("[Player] ¡Disparo ejecutado! Potencia: ", stepify(power, 0.1), " | Carga: ", stepify(shot_charge * 100, 1), "%")

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
