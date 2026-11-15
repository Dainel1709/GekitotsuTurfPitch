extends KinematicBody

class_name Player

# Referencia a la clase backend de C++ (FootballMechanics en GDExtension / GDNative)
var mechanics = null

# Configuración de Disparo y Balón
export var fallback_base_kick_force: float = 16.0
export var fallback_max_kick_force: float = 28.0
export var fallback_pass_force: float = 10.0
export var fallback_lob_force: float = 17.0
export var fallback_through_force: float = 20.0
export var kick_reach: float = 1.75
export var dribble_distance: float = 1.2
export var dribble_control_radius: float = 1.65
export var turn_speed: float = 16.0
export var charge_speed: float = 2.4 # Carga completa en ~0.42 segundos

# Estado de Controles PPSSPP y Balón
var shot_charge: float = 0.0
var is_charging: bool = false
var manual_aim_mode: bool = false
var can_move: bool = true

var facing_direction: Vector3 = Vector3(0.0, 0.0, -1.0) # Orientado hacia portería rival (Z negativo)
var ball_ref: RigidBody = null
var is_colliding_with_ball: bool = false
var is_ball_in_kick_area: bool = false
var is_ball_controlled: bool = false

# Timers de conducción y autopase
var kick_cooldown: float = 0.0
var knock_on_boost_timer: float = 0.0
var r_tap_timer: float = 0.0
var prev_btn_r: bool = false

# Detección de flancos para botones PPSSPP
var prev_btn_cross: bool = false
var prev_btn_circle: bool = false
var prev_btn_square: bool = false
var prev_btn_triangle: bool = false
var prev_btn_l: bool = false

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
	if not can_move:
		velocity = Vector3.ZERO
		return

	# 1. Resolver referencia al balón si es necesario
	_resolve_ball_reference()

	# Actualización de temporizadores de juego
	if kick_cooldown > 0.0:
		kick_cooldown = max(0.0, kick_cooldown - delta)
	if knock_on_boost_timer > 0.0:
		knock_on_boost_timer = max(0.0, knock_on_boost_timer - delta)
	if r_tap_timer > 0.0:
		r_tap_timer = max(0.0, r_tap_timer - delta)

	# 2. Captura de Movimiento (Exclusivo Flechas + Cruceta/Stick del Mando)
	var input_2d := Vector2.ZERO

	if Input.is_action_pressed("psp_up") or Input.is_key_pressed(KEY_UP):
		input_2d.y -= 1.0
	if Input.is_action_pressed("psp_down") or Input.is_key_pressed(KEY_DOWN):
		input_2d.y += 1.0
	if Input.is_action_pressed("psp_left") or Input.is_key_pressed(KEY_LEFT):
		input_2d.x -= 1.0
	if Input.is_action_pressed("psp_right") or Input.is_key_pressed(KEY_RIGHT):
		input_2d.x += 1.0

	# Lectura del joystick analógico del gamepad
	var joy_x = Input.get_joy_axis(0, JOY_AXIS_0)
	var joy_y = Input.get_joy_axis(0, JOY_AXIS_1)
	if abs(joy_x) > 0.2:
		input_2d.x = joy_x
	if abs(joy_y) > 0.2:
		input_2d.y = joy_y

	# Normalizar input diagonal
	if input_2d.length_squared() > 1.0:
		input_2d = input_2d.normalized()

	# 3. Transformar input 2D en movimiento 3D restringido a X y Z (Y = 0)
	var move_direction := Vector3(input_2d.x, 0.0, input_2d.y)
	var is_moving: bool = move_direction.length_squared() > 0.001

	# Suavizado de facing_direction hacia las flechas de dirección o stick izquierdo (turn_speed = 16.0)
	if is_moving:
		var target_dir = move_direction.normalized()
		var cur_angle = atan2(facing_direction.x, facing_direction.z)
		var target_angle = atan2(target_dir.x, target_dir.z)
		var smoothed_angle = lerp_angle(cur_angle, target_angle, clamp(turn_speed * delta, 0.0, 1.0))
		facing_direction = Vector3(sin(smoothed_angle), 0.0, cos(smoothed_angle)).normalized()

	# Botón R: Correr (Sprint) / Esprintar -> W | R1 (PS) / RB (Xbox)
	var cur_btn_r: bool = Input.is_action_pressed("psp_r") or Input.is_key_pressed(KEY_W) or Input.is_joy_button_pressed(0, JOY_BUTTON_5)
	var is_sprinting: bool = cur_btn_r
	var r_just_pressed: bool = cur_btn_r and not prev_btn_r
	prev_btn_r = cur_btn_r

	# Detección de doble toque en R (ventana < 0.28 s) para autopase largo (knock-on)
	if r_just_pressed:
		if r_tap_timer > 0.0 and is_moving and _is_ball_controlled():
			_execute_knock_on()
			r_tap_timer = 0.0
		else:
			r_tap_timer = 0.28

	# Botón L: Pedir el balón (sin posesión) / Freno y control orientado (con posesión) -> Q | L1 (PS)
	var cur_btn_l = Input.is_action_pressed("psp_l") or Input.is_key_pressed(KEY_Q) or Input.is_joy_button_pressed(0, JOY_BUTTON_4)
	if cur_btn_l and not prev_btn_l:
		_on_button_l_pressed()
	prev_btn_l = cur_btn_l

	# 4. Procesamiento de acciones PPSSPP (Cruz, Círculo, Triángulo, Cuadrado)
	_handle_ppsspp_actions(delta)

	# 5. Cálculo de velocidad y estamina con backend C++
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

	# Impulso temporal de velocidad por autopase largo (knock-on boost = 0.45 s con 1.22x)
	if knock_on_boost_timer > 0.0:
		current_speed *= 1.22

	# Reducción de velocidad mientras prepara un tiro cargado con Botón Cuadrado
	if is_charging:
		current_speed *= 0.65

	velocity.x = move_direction.x * current_speed
	velocity.y = 0.0
	velocity.z = move_direction.z * current_speed

	velocity = move_and_slide(velocity, Vector3.UP)

	# 6. Conducción controlada del balón (Dribbling en plano X/Z)
	is_colliding_with_ball = false
	var slide_count = get_slide_count()
	for i in range(slide_count):
		var col = get_slide_collision(i)
		if col and col.collider and col.collider.is_in_group("ball"):
			is_colliding_with_ball = true
			if col.collider is RigidBody:
				ball_ref = col.collider as RigidBody

	_update_ball_dribble(delta, is_moving, is_sprinting)

	# Orientar rotación hacia facing_direction suavizado
	var target_look: Vector3 = translation + facing_direction
	target_look.y = translation.y
	if translation.distance_squared_to(target_look) > 0.001:
		look_at(target_look, Vector3.UP)

func _update_ball_dribble(delta: float, is_moving: bool, is_sprinting: bool) -> void:
	if kick_cooldown > 0.0:
		is_ball_controlled = false
		return

	if not ball_ref or not is_instance_valid(ball_ref):
		is_ball_controlled = false
		return

	var player_pos: Vector3 = global_transform.origin
	var ball_pos: Vector3 = ball_ref.global_transform.origin
	var to_ball: Vector3 = ball_pos - player_pos
	to_ball.y = 0.0
	var dist_to_ball: float = to_ball.length()

	var ball_speed: float = ball_ref.linear_velocity.length()

	var dot: float = 1.0
	if dist_to_ball > 0.001:
		dot = facing_direction.dot(to_ball / dist_to_ball)

	# Control del balón: dentro de dribble_control_radius (1.65 m), velocidad < 16.0 y de frente (dot >= -0.25 o distancia <= 0.45 m)
	if dist_to_ball <= dribble_control_radius and ball_speed < 16.0 and (dot >= -0.25 or dist_to_ball <= 0.45):
		is_ball_controlled = true
		var target_dist: float = 1.45 if is_sprinting else 1.0
		var target_pos: Vector3 = player_pos + facing_direction * target_dist

		var to_target: Vector3 = target_pos - ball_pos
		to_target.y = 0.0

		var vel_carry: Vector3 = velocity * 0.85 if is_moving else Vector3.ZERO
		var target_vel: Vector3 = to_target * 10.0 + vel_carry
		var lerp_weight: float = clamp(14.0 * delta, 0.0, 1.0)
		ball_ref.linear_velocity.x = lerp(ball_ref.linear_velocity.x, target_vel.x, lerp_weight)
		ball_ref.linear_velocity.z = lerp(ball_ref.linear_velocity.z, target_vel.z, lerp_weight)

		# Actualizar velocidad angular acorde al desplazamiento de rodadura
		var ball_radius: float = 0.25
		ball_ref.angular_velocity = Vector3(
			ball_ref.linear_velocity.z / ball_radius,
			0.0,
			-ball_ref.linear_velocity.x / ball_radius
		)
	else:
		is_ball_controlled = false

func _is_ball_controlled() -> bool:
	if kick_cooldown > 0.0:
		return false
	if is_ball_controlled:
		return true
	if not ball_ref or not is_instance_valid(ball_ref):
		return false
	var dist = translation.distance_to(ball_ref.translation)
	if dist > dribble_control_radius or ball_ref.linear_velocity.length() >= 16.0:
		return false
	var to_ball = ball_ref.global_transform.origin - global_transform.origin
	to_ball.y = 0.0
	var dot = facing_direction.dot(to_ball.normalized()) if dist > 0.001 else 1.0
	return (dot >= -0.25 or dist <= 0.45)

func _execute_knock_on() -> void:
	if not ball_ref or not is_instance_valid(ball_ref):
		return

	var knock_dir = facing_direction.normalized()
	var knock_speed: float = 17.5
	ball_ref.linear_velocity = Vector3(knock_dir.x * knock_speed, 0.06, knock_dir.z * knock_speed)
	var ball_radius: float = 0.25
	ball_ref.angular_velocity = Vector3(
		knock_dir.z * knock_speed / ball_radius,
		0.0,
		-knock_dir.x * knock_speed / ball_radius
	)

	kick_cooldown = 0.38
	is_ball_controlled = false
	knock_on_boost_timer = 0.45
	drain_stamina(10.0)
	print("[Player] ¡Autopase largo (Knock-on) con doble toque en W / R1! Velocidad: ", knock_speed, " | Boost activo")

func _get_control_scheme() -> int:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("get_control_scheme"):
		return gs.get_control_scheme()
	return 0 # 0 = FIFA_CLASSIC, 1 = PES_ALTERNATIVE

func _handle_ppsspp_actions(delta: float) -> void:
	var scheme = _get_control_scheme()
	var gs = get_node_or_null("/root/GameSettings")
	var btn_cross = gs.get_button_cross(0) if (gs and gs.has_method("get_button_cross")) else JOY_BUTTON_0
	var btn_circle = gs.get_button_circle(0) if (gs and gs.has_method("get_button_circle")) else JOY_BUTTON_1
	var btn_square = gs.get_button_square(0) if (gs and gs.has_method("get_button_square")) else JOY_BUTTON_2
	var btn_triangle = gs.get_button_triangle(0) if (gs and gs.has_method("get_button_triangle")) else JOY_BUTTON_3

	# --- 1. Botón X (Cruz): Pase Corto -> Tecla Z | X (PS) / A (Xbox) ---
	var cur_btn_cross = Input.is_action_pressed("psp_cross") or Input.is_key_pressed(KEY_Z) or Input.is_joy_button_pressed(0, btn_cross)
	if cur_btn_cross and not prev_btn_cross:
		_execute_short_pass()
	prev_btn_cross = cur_btn_cross

	# --- 2. Botón Δ (Triángulo): Pase en profundidad -> Tecla S | Δ (PS) / Y (Xbox) ---
	var cur_btn_triangle = Input.is_action_pressed("psp_triangle") or Input.is_key_pressed(KEY_S) or Input.is_joy_button_pressed(0, btn_triangle)
	if cur_btn_triangle and not prev_btn_triangle:
		_execute_through_pass()
	prev_btn_triangle = cur_btn_triangle

	# --- 3. Botón O (Círculo): Tecla X | O (PS) / B (Xbox) ---
	var raw_circle_pressed = Input.is_action_pressed("psp_circle") or Input.is_key_pressed(KEY_X) or Input.is_joy_button_pressed(0, btn_circle)

	# --- 4. Botón □ (Cuadrado): Tecla A | □ (PS) / X (Xbox) ---
	var raw_square_pressed = Input.is_action_pressed("psp_square") or Input.is_key_pressed(KEY_A) or Input.is_joy_button_pressed(0, btn_square)
	
	var shoot_pressed: bool = false
	var lob_pressed: bool = false

	if scheme == 0:
		# Clásico (FIFA): Círculo = Disparo | Cuadrado = Centro / Pase bombeado
		shoot_pressed = raw_circle_pressed
		if raw_square_pressed and not prev_btn_square:
			lob_pressed = true
	else:
		# Alternativo (PES / PPSSPP): Cuadrado = Disparo | Círculo = Centro / Pase bombeado
		shoot_pressed = raw_square_pressed
		if raw_circle_pressed and not prev_btn_circle:
			lob_pressed = true

	prev_btn_circle = raw_circle_pressed
	prev_btn_square = raw_square_pressed

	# Ejecutar centro / pase bombeado
	if lob_pressed:
		_execute_lob_pass()

	# Ejecutar disparo / remate con carga
	if shoot_pressed:
		is_charging = true
		shot_charge = min(1.0, shot_charge + charge_speed * delta)
	else:
		if is_charging:
			_execute_kick()
			is_charging = false
			shot_charge = 0.0

func _get_action_direction() -> Vector3:
	var dir = facing_direction
	if manual_aim_mode:
		return dir

	if not ball_ref or not is_instance_valid(ball_ref):
		return dir

	var dist_to_ball = translation.distance_to(ball_ref.translation)
	if velocity.length_squared() > 1.0:
		dir = (facing_direction * 0.7 + velocity.normalized() * 0.3).normalized()
	elif dist_to_ball > 0.01:
		var to_ball = (ball_ref.global_transform.origin - global_transform.origin)
		to_ball.y = 0.0
		if to_ball.length_squared() > 0.01:
			dir = (facing_direction * 0.4 + to_ball.normalized() * 0.6).normalized()

	return dir

func _can_kick_ball() -> bool:
	if not ball_ref or not is_instance_valid(ball_ref):
		return false
	var dist_to_ball = translation.distance_to(ball_ref.translation)
	return is_colliding_with_ball or is_ball_in_kick_area or dist_to_ball <= kick_reach or is_ball_controlled

# --- Botón X: Pase Corto Raso ---
func _execute_short_pass() -> void:
	if not _can_kick_ball():
		return

	var pass_dir = _get_action_direction()
	var pass_impulse: Vector3 = Vector3.ZERO

	if mechanics and mechanics.has_method("calculate_pass_force"):
		var res = mechanics.calculate_pass_force(pass_dir.x, pass_dir.z)
		if typeof(res) == TYPE_VECTOR3:
			pass_impulse = res
		else:
			pass_impulse = Vector3(pass_dir.x * fallback_pass_force, 0.08, pass_dir.z * fallback_pass_force)
	else:
		pass_impulse = Vector3(pass_dir.x * fallback_pass_force, 0.08, pass_dir.z * fallback_pass_force)

	ball_ref.apply_central_impulse(pass_impulse)
	drain_stamina(4.0)
	kick_cooldown = 0.25
	is_ball_controlled = false
	print("[PPSSPP] Botón X (Cruz): Pase corto ejecutado -> ", pass_impulse)

# --- Botón O: Centro / Pase Bombeado ---
func _execute_lob_pass() -> void:
	if not _can_kick_ball():
		return

	var pass_dir = _get_action_direction()
	var lob_impulse: Vector3 = Vector3.ZERO

	if mechanics and mechanics.has_method("calculate_lob_pass"):
		var res = mechanics.calculate_lob_pass(pass_dir.x, pass_dir.z)
		if typeof(res) == TYPE_VECTOR3:
			lob_impulse = res
		else:
			lob_impulse = Vector3(pass_dir.x * fallback_lob_force, 4.2, pass_dir.z * fallback_lob_force)
	else:
		lob_impulse = Vector3(pass_dir.x * fallback_lob_force, 4.2, pass_dir.z * fallback_lob_force)

	ball_ref.apply_central_impulse(lob_impulse)
	drain_stamina(6.0)
	kick_cooldown = 0.25
	is_ball_controlled = false
	print("[PPSSPP] Botón O (Círculo): Pase bombeado / Centro ejecutado -> ", lob_impulse)

# --- Botón Δ: Pase en Profundidad / al Hueco ---
func _execute_through_pass() -> void:
	if not _can_kick_ball():
		return

	var pass_dir = _get_action_direction()
	var through_impulse: Vector3 = Vector3.ZERO

	if mechanics and mechanics.has_method("calculate_through_pass"):
		var res = mechanics.calculate_through_pass(pass_dir.x, pass_dir.z)
		if typeof(res) == TYPE_VECTOR3:
			through_impulse = res
		else:
			through_impulse = Vector3(pass_dir.x * fallback_through_force, 0.05, pass_dir.z * fallback_through_force)
	else:
		through_impulse = Vector3(pass_dir.x * fallback_through_force, 0.05, pass_dir.z * fallback_through_force)

	ball_ref.apply_central_impulse(through_impulse)
	drain_stamina(7.0)
	kick_cooldown = 0.25
	is_ball_controlled = false
	print("[PPSSPP] Botón Δ (Triángulo): Pase en profundidad ejecutado -> ", through_impulse)

# --- Botón □: Disparo / Remate a Portería ---
func _execute_kick() -> void:
	if not _can_kick_ball():
		return

	var kick_dir = _get_action_direction()
	var kick_impulse: Vector3 = _calculate_kick_vector(kick_dir, shot_charge)

	ball_ref.apply_central_impulse(kick_impulse)
	var stamina_cost = 8.0 + shot_charge * 14.0
	drain_stamina(stamina_cost)
	kick_cooldown = 0.25
	is_ball_controlled = false
	print("[PPSSPP] Botón □ (Cuadrado): Disparo ejecutado -> Potencia: ", stepify(shot_charge * 100, 1), "% | Vector: ", kick_impulse)

# --- Botón L (Q / L1): Pedir el balón o Control Orientado ---
func _on_button_l_pressed() -> void:
	_resolve_ball_reference()
	if not ball_ref or not is_instance_valid(ball_ref):
		return

	# 1. Si ya tienes el balón cerca: Control orientado hacia la portería rival
	if _can_kick_ball():
		ball_ref.linear_velocity *= 0.15
		ball_ref.angular_velocity = Vector3.ZERO
		facing_direction = Vector3(0.0, 0.0, -1.0)
		print("[Carrera] Botón L (Q / L1): Control orientado hacia portería.")
		return

	# 2. Si NO tienes el balón: Pedir el pase hacia tu posición adelantada
	var target_pos = global_transform.origin + (facing_direction * 1.2)
	var to_player = target_pos - ball_ref.global_transform.origin
	to_player.y = 0.0

	var dist = to_player.length()
	if dist > 0.5 and dist <= 24.0:
		var pass_dir = to_player.normalized()
		var pass_speed = clamp(dist * 0.85, 8.0, 18.0)
		ball_ref.linear_velocity = Vector3.ZERO
		ball_ref.apply_central_impulse(Vector3(pass_dir.x * pass_speed, 0.08, pass_dir.z * pass_speed))
		print("[Carrera] Botón L (Q / L1): ¡Balón pedido al pie!")
		
func _calculate_kick_vector(kick_dir: Vector3, charge: float) -> Vector3:
	if mechanics:
		if mechanics.has_method("calculate_kick_force"):
			var res = mechanics.calculate_kick_force(kick_dir.x, kick_dir.z, charge)
			if typeof(res) == TYPE_VECTOR3:
				return res
			elif typeof(res) == TYPE_REAL or typeof(res) == TYPE_INT:
				var mag = float(res)
				var vy = min(1.6, mag * (0.04 + 0.05 * charge))
				return Vector3(kick_dir.x * mag, vy, kick_dir.z * mag)

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

func get_shot_charge() -> float:
	return shot_charge

func is_charging_shot() -> bool:
	return is_charging

func get_stamina() -> float:
	if mechanics:
		return mechanics.get_stamina()
	return fallback_stamina

func get_max_stamina() -> float:
	if mechanics:
		return mechanics.get_max_stamina()
	return fallback_max_stamina

func get_current_speed() -> float:
	var spd = fallback_base_speed
	if mechanics:
		spd = mechanics.get_current_speed()
	if knock_on_boost_timer > 0.0:
		spd *= 1.22
	return spd

func get_facing_direction() -> Vector3:
	return facing_direction
