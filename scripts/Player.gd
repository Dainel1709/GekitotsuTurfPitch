extends KinematicBody

class_name Player

signal fury_changed(new_fury, max_fury)
signal special_shot_executed()

# Referencia a la clase backend de C++ (FootballMechanics en GDExtension / GDNative)
var mechanics = null

# RPG Stats desde GekitotsuStoryManager (C++)
var combat_stat: int = 0
var discipline_stat: int = 0
var kick_power_mult: float = 1.0
var fury_gain_mult: float = 1.0
var sprint_drain_mult: float = 1.0

# Barra de Furia
var fury: float = 0.0 setget set_fury, get_fury
var max_fury: float = 100.0

export(String) var tactical_slot: String = "ST"
export(Vector3) var home_position: Vector3 = Vector3(0.0, 0.8, -3.5)

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
var is_dribbling: bool = false
var is_ball_controlled: bool = false

# Timers de conducción y autopase
var kick_cooldown: float = 0.0
var knock_on_boost_timer: float = 0.0
var r_tap_timer: float = 0.0
var prev_btn_r: bool = false

# Recepción asistida de pases
var expecting_pass: bool = false
var pass_receive_timer: float = 0.0

# Cooldown para recepción de faltas
var foul_cooldown: float = 0.0

# Detección de flancos para botones PPSSPP
var prev_btn_cross: bool = false
var prev_btn_circle: bool = false
var prev_btn_square: bool = false
var prev_btn_triangle: bool = false
var prev_btn_l: bool = false

# Acción defensiva: Robo / Entrada (Tackle)
var tackle_cooldown: float = 0.0

# Herramienta de pruebas: congelar rivales (Tecla F)
var prev_key_f: bool = false
var opponents_frozen: bool = false

# Variables de respaldo local (Fallback si la librería nativa no está cargada)
export(bool) var enable_stamina_fatigue: bool = true
var is_exhausted: bool = false
var stun_timer: float = 0.0
var is_in_brawl: bool = false
var prev_both_triggers: bool = false
var pitch_brawls_count: int = 0

var fallback_base_speed: float = 10.0
var stamina: float = 100.0 setget set_stamina, get_stamina
var max_stamina: float = 100.0 setget set_max_stamina, get_max_stamina
var fallback_stamina: float = 100.0
var fallback_max_stamina: float = 100.0

var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("player")

	# Asignar material visual exclusivo para el jugador principal (azul eléctrico brillante)
	var player_mat = SpatialMaterial.new()
	player_mat.albedo_color = Color(0.10, 0.60, 1.0)
	player_mat.roughness = 0.3
	player_mat.emission_enabled = true
	player_mat.emission = Color(0.05, 0.25, 0.5)
	player_mat.emission_energy = 0.35
	var player_mesh = get_node_or_null("PlayerMesh")
	if player_mesh and player_mesh is MeshInstance:
		player_mesh.material_override = player_mat
	else:
		for child in get_children():
			if child is MeshInstance and child.name != "IndicatorRing":
				child.material_override = player_mat
				break

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

	# Lectura y vinculación de RPG Stats desde C++ (GekitotsuStoryManager)
	var combat: int = 0
	var discipline: int = 0
	if ClassDB.class_exists("GekitotsuStoryManager"):
		var sm = null
		if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("GekitotsuStoryManager"):
			sm = ClassDB.instantiate("GekitotsuStoryManager")
		elif ClassDB.has_method("can_instance") and ClassDB.can_instance("GekitotsuStoryManager"):
			sm = ClassDB.instance("GekitotsuStoryManager")
		if sm:
			if sm.has_method("get_combat_technique"):
				combat = sm.get_combat_technique()
			if sm.has_method("get_discipline_points"):
				discipline = sm.get_discipline_points()
	elif get_tree() and get_tree().root and get_tree().root.has_meta("gtp_stats"):
		var stats = get_tree().root.get_meta("gtp_stats")
		combat = stats.get("combat", 0)
		discipline = stats.get("discipline", 0)

	apply_rpg_stats(combat, discipline)

func set_fury(val: float) -> void:
	fury = clamp(val, 0.0, max_fury)
	emit_signal("fury_changed", fury, max_fury)

func get_fury() -> float:
	return fury

func add_fury(amount: float) -> void:
	if amount <= 0.0:
		return
	var prev = fury
	fury = clamp(fury + amount, 0.0, max_fury)
	if fury != prev:
		emit_signal("fury_changed", fury, max_fury)

func apply_rpg_stats(p_combat: int, p_discipline: int) -> void:
	combat_stat       = p_combat
	discipline_stat   = p_discipline
	kick_power_mult   = 1.0 + float(p_combat) * 0.008
	fury_gain_mult    = 1.0 + float(p_combat) * 0.015
	sprint_drain_mult = clamp(1.0 - float(p_discipline) * 0.006, 0.55, 1.0)
	dribble_control_radius = 1.65 + float(p_discipline) * 0.005
	if mechanics and mechanics.has_method("apply_rpg_stats"):
		mechanics.apply_rpg_stats(p_combat, p_discipline)
	print("[Player] RPG Stats aplicados: Combate=%d (potencia x%.2f, furia x%.2f) | Disciplina=%d (drenaje sprint x%.2f, control %.2fm)" % [
		p_combat, kick_power_mult, fury_gain_mult, p_discipline, sprint_drain_mult, dribble_control_radius
	])

func _physics_process(delta: float) -> void:
	if not can_move or stun_timer > 0.0:
		if stun_timer > 0.0:
			stun_timer = max(0.0, stun_timer - delta)
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
	if tackle_cooldown > 0.0:
		tackle_cooldown = max(0.0, tackle_cooldown - delta)
	if pass_receive_timer > 0.0:
		pass_receive_timer = max(0.0, pass_receive_timer - delta)
		if pass_receive_timer <= 0.0:
			expecting_pass = false
	if foul_cooldown > 0.0:
		foul_cooldown = max(0.0, foul_cooldown - delta)

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
	# Botón L: Pedir el balón (sin posesión) / Freno y control orientado (con posesión) -> Q | L1 (PS)
	var cur_btn_l = Input.is_action_pressed("psp_l") or Input.is_key_pressed(KEY_Q) or Input.is_joy_button_pressed(0, JOY_BUTTON_4)

	# Detección de flanco de ambos gatillos a la vez (Q + W / L1 + R1) para iniciar Duelo en Cancha
	var both_triggers: bool = cur_btn_l and cur_btn_r
	var both_triggers_just_pressed: bool = both_triggers and not prev_both_triggers
	prev_both_triggers = both_triggers

	if both_triggers:
		# Cancelar timers de autopase y petición L cuando se presionan ambos gatillos a la vez
		r_tap_timer = 0.0
		if both_triggers_just_pressed and fury >= 100.0:
			_trigger_pitch_brawl()

	var is_sprinting: bool = cur_btn_r and not both_triggers
	var r_just_pressed: bool = cur_btn_r and not prev_btn_r and not both_triggers
	prev_btn_r = cur_btn_r

	# Detección de doble toque en R (ventana < 0.28 s) para autopase largo (knock-on)
	if r_just_pressed:
		if r_tap_timer > 0.0 and is_moving and _is_ball_controlled():
			_execute_knock_on()
			r_tap_timer = 0.0
		else:
			r_tap_timer = 0.28

	var l_just_pressed = cur_btn_l and not prev_btn_l and not both_triggers
	prev_btn_l = cur_btn_l
	if l_just_pressed:
		_on_button_l_pressed()

	# Herramienta de prueba en cancha: Tecla F para frenar / pausar rivales
	var cur_key_f: bool = Input.is_key_pressed(KEY_F)
	if cur_key_f and not prev_key_f:
		var is_shift: bool = Input.is_key_pressed(KEY_SHIFT)
		var is_ctrl: bool = Input.is_key_pressed(KEY_CONTROL)
		var pulse_freeze: bool = is_shift or (opponents_frozen and is_ctrl)
		_toggle_opponents_freeze(pulse_freeze)
	prev_key_f = cur_key_f

	# 4. Procesamiento de acciones PPSSPP (Cruz, Círculo, Triángulo, Cuadrado)
	_handle_ppsspp_actions(delta)

	# 5. Cálculo de velocidad y estamina unificada
	var current_speed: float = 0.0

	if enable_stamina_fatigue:
		# Compartir mismas reglas de estamina que los NPCs
		if not is_exhausted:
			if is_sprinting and is_moving:
				var drain: float = 20.0 * sprint_drain_mult
				stamina = max(0.0, stamina - drain * delta)
			else:
				var rec: float = 12.0 * (1.0 + float(discipline_stat) * 0.008)
				stamina = min(max_stamina, stamina + rec * delta)
			if stamina <= 0.0:
				stamina = 0.0
				is_exhausted = true
		else:
			var rec: float = 12.0 * (1.0 + float(discipline_stat) * 0.008)
			stamina = min(max_stamina, stamina + rec * delta)
			if stamina >= 35.0:
				is_exhausted = false

		fallback_stamina = stamina
		if mechanics and mechanics.has_method("set_stamina"):
			mechanics.set_stamina(stamina)

		var fatigue_mult: float = 0.8 if is_exhausted else 1.0
		var sprint_mult: float = 1.6 if (is_sprinting and not is_exhausted) else 1.0
		current_speed = fallback_base_speed * sprint_mult * fatigue_mult
	else:
		# Si enable_stamina_fatigue == false, ninguno sufre penalización de velocidad por cansancio
		is_exhausted = false
		stamina = max_stamina
		fallback_stamina = max_stamina
		if mechanics and mechanics.has_method("set_stamina"):
			mechanics.set_stamina(max_stamina)
		var sprint_mult: float = 1.6 if is_sprinting else 1.0
		current_speed = fallback_base_speed * sprint_mult

	# Impulso temporal de velocidad por autopase largo (knock-on boost = 0.45 s con 1.22x)
	if knock_on_boost_timer > 0.0:
		current_speed *= 1.22

	# Conducción en Corto con botón L presionado (velocidad al 80% para recortes precisos)
	if cur_btn_l and (is_dribbling or is_ball_controlled):
		current_speed *= 0.8

	# Reducción de velocidad mientras prepara un tiro cargado con Botón Cuadrado
	if is_charging:
		current_speed *= 0.65

	velocity.x = move_direction.x * current_speed
	velocity.y = 0.0
	velocity.z = move_direction.z * current_speed

	velocity = move_and_slide(velocity, Vector3.UP)

	# Mantener dentro de los límites jugables de la cancha
	translation.x = clamp(translation.x, -19.0, 19.0)
	translation.z = clamp(translation.z, -27.5, 27.5)

	# 6. Conducción controlada del balón (Dribbling en plano X/Z) y detección de colisiones
	is_colliding_with_ball = false
	var slide_count = get_slide_count()
	for i in range(slide_count):
		var col = get_slide_collision(i)
		if col and col.collider:
			if col.collider.is_in_group("ball"):
				is_colliding_with_ball = true
				if col.collider is RigidBody:
					ball_ref = col.collider as RigidBody
			elif col.collider.is_in_group("opponents") or ("role" in col.collider and col.collider.role == "opponent"):
				if foul_cooldown <= 0.0:
					receive_foul(col.collider)

	# Detección de contacto o disputa cercana con rivales para recibir falta
	if foul_cooldown <= 0.0 and not is_in_brawl:
		var opponents = get_tree().get_nodes_in_group("opponents")
		for opp in opponents:
			if opp != self and is_instance_valid(opp):
				var opp_pos = opp.global_transform.origin
				var dist_opp = global_transform.origin.distance_to(opp_pos)
				var ball_near: bool = false
				if ball_ref and is_instance_valid(ball_ref):
					ball_near = global_transform.origin.distance_to(ball_ref.global_transform.origin) <= 2.2
				if dist_opp <= 1.4 and (is_dribbling or is_ball_controlled or ball_near):
					receive_foul(opp)
					break

	_update_match_tension_fury(delta)
	_update_ball_dribble(delta, is_moving, is_sprinting)

	# Orientar rotación hacia facing_direction suavizado
	var target_look: Vector3 = translation + facing_direction
	target_look.y = translation.y
	if translation.distance_squared_to(target_look) > 0.001:
		look_at(target_look, Vector3.UP)

func _update_ball_dribble(delta: float, is_moving: bool, is_sprinting: bool) -> void:
	if kick_cooldown > 0.0:
		is_dribbling = false
		is_ball_controlled = false
		return

	if not ball_ref or not is_instance_valid(ball_ref):
		is_dribbling = false
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

	# 1. Bandera booleana is_dribbling y recepción asistida:
	var ball_heading_towards_ryu: bool = (ball_speed > 1.0 and dist_to_ball > 0.01 and ball_ref.linear_velocity.dot(-to_ball.normalized()) > 1.2)
	var is_receiving_pass: bool = (expecting_pass or pass_receive_timer > 0.0 or ball_heading_towards_ryu)
	var max_allowed_speed: float = 26.0 if is_receiving_pass else 15.0
	var effective_radius: float = 1.85 if is_receiving_pass else dribble_control_radius

	var just_started_dribble: bool = false
	if not is_dribbling:
		if dist_to_ball <= effective_radius and ball_speed <= max_allowed_speed and kick_cooldown <= 0.0 and not _is_rival_near_ball(ball_pos, 0.8):
			if dot >= -0.25 or dist_to_ball <= 0.45 or is_receiving_pass or (is_moving and dot < 0.0):
				is_dribbling = true
				just_started_dribble = true
				if is_receiving_pass:
					# Amortiguar inmediatamente su velocidad horizontal
					ball_ref.linear_velocity.x *= 0.25
					ball_ref.linear_velocity.z *= 0.25
					# Colocarlo suavemente delante de los pies de Ryu sin que rebote contra su colisión física
					var front_pos: Vector3 = player_pos + facing_direction * 0.75
					front_pos.y = ball_ref.global_transform.origin.y
					ball_ref.global_transform.origin = front_pos
					ball_pos = front_pos
					if expecting_pass or pass_receive_timer > 0.0:
						add_fury(6.0 * fury_gain_mult)
					expecting_pass = false
					pass_receive_timer = 0.0
	else:
		if dist_to_ball > 1.85 or kick_cooldown > 0.0:
			is_dribbling = false

	if is_dribbling:
		is_ball_controlled = true

		# 2. Distancia objetivo:
		# Conducción en Corto con L presionado (0.65 m), sprint (1.45 m) o caminar normal (1.0 m)
		var is_holding_l: bool = Input.is_action_pressed("psp_l") or Input.is_key_pressed(KEY_Q) or Input.is_joy_button_pressed(0, JOY_BUTTON_4)
		var target_dist: float = 1.0
		var is_running_forward: bool = is_moving and (velocity.dot(facing_direction) >= -0.1 or velocity.length_squared() < 0.5)
		if is_holding_l:
			target_dist = 0.65
		elif is_running_forward and dot < 0.35:
			target_dist = 1.25 if is_sprinting else 1.0
		elif dot < 0.2:
			target_dist = 0.70
		elif is_sprinting:
			target_dist = 1.45
		else:
			target_dist = 1.0

		var target_pos: Vector3 = player_pos + facing_direction * target_dist
		var to_target: Vector3 = target_pos - ball_pos
		to_target.y = 0.0

		# Adelantar suavemente hacia el frente con impulso si inicia la conducción o si el balón quedó detrás corriendo al frente
		var should_nudge_forward: bool = (just_started_dribble and (dot < 0.0 or is_moving)) or (is_running_forward and dot < 0.0)
		if should_nudge_forward:
			var forward_dir: Vector3 = to_target.normalized()
			if forward_dir.length_squared() > 0.01:
				var push_force: float = clamp(to_target.length() * 1.5, 0.8, 2.5)
				ball_ref.apply_central_impulse(forward_dir * push_force)

		var vel_carry: Vector3 = velocity * 0.85 if is_moving else Vector3.ZERO
		var target_vel: Vector3 = to_target * 10.0 + vel_carry

		# 3. Limitar (clamp) la velocidad máxima de corrección del balón en X/Z
		# a max_dribble_speed = max(current_speed * 1.35, 12.5) para que al girar 180° el balón orbite,
		# y max_dribble_speed = max(current_speed * 1.85, 16.0) mientras dot < 0.35 para adelantar rápidamente
		var player_speed: float = velocity.length()
		var max_dribble_speed: float = max(player_speed * 1.35, 12.5)
		if dot < 0.35 and (is_running_forward or just_started_dribble):
			max_dribble_speed = max(player_speed * 1.85, 16.0)

		var target_h_speed: float = Vector2(target_vel.x, target_vel.z).length()
		if target_h_speed > max_dribble_speed and target_h_speed > 0.001:
			var scale_factor = max_dribble_speed / target_h_speed
			target_vel.x *= scale_factor
			target_vel.z *= scale_factor

		var lerp_weight: float = clamp((20.0 if dot < 0.35 else 14.0) * delta, 0.0, 1.0)
		ball_ref.linear_velocity.x = lerp(ball_ref.linear_velocity.x, target_vel.x, lerp_weight)
		ball_ref.linear_velocity.z = lerp(ball_ref.linear_velocity.z, target_vel.z, lerp_weight)

		# Clamping de la velocidad horizontal del RigidBody
		var ball_h_speed: float = Vector2(ball_ref.linear_velocity.x, ball_ref.linear_velocity.z).length()
		if ball_h_speed > max_dribble_speed and ball_h_speed > 0.001:
			var scale_b = max_dribble_speed / ball_h_speed
			ball_ref.linear_velocity.x *= scale_b
			ball_ref.linear_velocity.z *= scale_b

		# Actualizar velocidad angular acorde al desplazamiento de rodadura
		var ball_radius: float = 0.25
		ball_ref.angular_velocity = Vector3(
			ball_ref.linear_velocity.z / ball_radius,
			0.0,
			-ball_ref.linear_velocity.x / ball_radius
		)

		# Cargar Furia al conducir en movimiento
		if is_moving:
			add_fury(5.0 * delta * fury_gain_mult)
	else:
		is_ball_controlled = false

func _is_ball_controlled() -> bool:
	if kick_cooldown > 0.0:
		return false
	if is_dribbling:
		return true
	if is_ball_controlled:
		return true
	if not ball_ref or not is_instance_valid(ball_ref):
		return false
	var dist = translation.distance_to(ball_ref.translation)
	var is_receiving_pass: bool = (expecting_pass or pass_receive_timer > 0.0)
	var max_spd: float = 26.0 if is_receiving_pass else 15.0
	var rad: float = 1.85 if is_receiving_pass else dribble_control_radius
	if dist > rad or ball_ref.linear_velocity.length() > max_spd:
		return false
	var to_ball = ball_ref.global_transform.origin - global_transform.origin
	to_ball.y = 0.0
	var dot = facing_direction.dot(to_ball.normalized()) if dist > 0.001 else 1.0
	return (dot >= -0.25 or dist <= 0.45 or is_receiving_pass)

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
	is_dribbling = false
	is_ball_controlled = false
	knock_on_boost_timer = 0.45
	drain_stamina(10.0)
	add_fury(14.0 * fury_gain_mult)
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

	# --- 1. Botón X (Cruz): Pase Corto (con balón) / Robo-Entrada (sin balón) -> Tecla Z | X (PS) / A (Xbox) ---
	var cur_btn_cross = Input.is_action_pressed("psp_cross") or Input.is_key_pressed(KEY_Z) or Input.is_joy_button_pressed(0, btn_cross)
	if cur_btn_cross and not prev_btn_cross:
		if is_dribbling or is_ball_controlled:
			_execute_short_pass()
		else:
			_execute_tackle()
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
	
	# --- Comprobación de Tiro Especial (Gekitotsu Shot: L + Disparo con Furia 100%) ---
	var cur_btn_l: bool = Input.is_action_pressed("psp_l") or Input.is_key_pressed(KEY_Q) or Input.is_joy_button_pressed(0, JOY_BUTTON_4)
	if cur_btn_l and fury >= 100.0 and _can_kick_ball():
		var special_triggered: bool = false
		if scheme == 0:
			# FIFA Clásico: Disparo es Círculo
			if raw_circle_pressed and not prev_btn_circle:
				special_triggered = true
		else:
			# PES Alternativo: Disparo es Cuadrado
			if raw_square_pressed and not prev_btn_square:
				special_triggered = true

		if special_triggered:
			is_charging = false
			shot_charge = 0.0
			prev_btn_circle = raw_circle_pressed
			prev_btn_square = raw_square_pressed
			_execute_special_shot()
			return

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
	return is_colliding_with_ball or is_ball_in_kick_area or dist_to_ball <= kick_reach or is_dribbling or is_ball_controlled

# --- Acción Defensiva: Robo / Entrada (Tackle) — Botón Cruz sin posesión ---
func _execute_tackle() -> void:
	if tackle_cooldown > 0.0:
		return
	_resolve_ball_reference()
	if not ball_ref or not is_instance_valid(ball_ref):
		return

	var my_pos: Vector3 = global_transform.origin
	var ball_pos: Vector3 = ball_ref.global_transform.origin
	var dist_to_ball: float = my_pos.distance_to(ball_pos)

	# Buscar si hay un rival cercano al balón (radio 1.8 m)
	var tree = get_tree()
	if not tree:
		return
	var rivals_found = tree.get_nodes_in_group("opponents")
	var carrier = null
	for r in rivals_found:
		if r is Spatial and is_instance_valid(r):
			var r_pos = r.global_transform.origin
			r_pos.y = ball_pos.y
			if ball_pos.distance_to(r_pos) <= 1.8:
				carrier = r
				break

	# Si no hay rival portador, buscar también en footballai opponents
	if not carrier:
		var opp_groups = tree.get_nodes_in_group("opponents")
		for o in opp_groups:
			if "has_ball" in o and o.has_ball:
				var o_pos = o.global_transform.origin
				o_pos.y = my_pos.y
				if my_pos.distance_to(o_pos) <= 1.8:
					carrier = o
					break

	if carrier and my_pos.distance_to(carrier.global_transform.origin) <= 1.8:
		# Robo exitoso: quitar el balón al rival
		if "has_ball" in carrier:
			carrier.has_ball = false
		if "is_dribbling" in carrier:
			carrier.is_dribbling = false
		if "possession_cooldown" in carrier:
			carrier.possession_cooldown = 0.65
		# Tomar posesión
		is_dribbling = true
		is_ball_controlled = true
		kick_cooldown = 0.0
		tackle_cooldown = 0.45
		add_fury(8.0 * fury_gain_mult)
		print("[Player] ¡ENTRADA / ROBO exitoso! Balón recuperado (Tackle). +8 Furia.")
	elif dist_to_ball <= 1.8 and ball_ref.linear_velocity.length() < 18.0:
		# Balón suelto cerca: tomar control directo
		is_dribbling = true
		is_ball_controlled = true
		kick_cooldown = 0.0
		tackle_cooldown = 0.45
		add_fury(8.0 * fury_gain_mult)
		print("[Player] Balón suelto controlado con entrada. +8 Furia.")
	else:
		# Entrada fallida
		tackle_cooldown = 0.45
		print("[Player] Entrada fallida: sin rival ni balón en rango de 1.8 m.")

# --- Herramienta de Pruebas en Cancha: Congelar / Frenar Rivales y Compañero ---
func _toggle_opponents_freeze(pulse: bool = false) -> void:
	var tree = get_tree()
	if not tree:
		return
	var opponents = tree.get_nodes_in_group("opponents")
	var teammates = tree.get_nodes_in_group("teammates")
	var target_nodes = []
	for opp in opponents:
		target_nodes.append(opp)
	for team in teammates:
		if team != self:
			target_nodes.append(team)

	if pulse:
		opponents_frozen = true
		for actor in target_nodes:
			if "role" in actor and actor.role == "goalkeeper":
				continue
			if actor.has_method("set_test_freeze"):
				actor.set_test_freeze(true, 1.5)
			elif "is_frozen_for_test" in actor:
				actor.is_frozen_for_test = true
				if "test_freeze_timer" in actor:
					actor.test_freeze_timer = 1.5
		print("[Test F] Rivales y Compañero FRENADOS por pulso (1.5s)")
	else:
		opponents_frozen = not opponents_frozen
		for actor in target_nodes:
			if "role" in actor and actor.role == "goalkeeper":
				continue
			if actor.has_method("set_test_freeze"):
				actor.set_test_freeze(opponents_frozen, 0.0)
			elif "is_frozen_for_test" in actor:
				actor.is_frozen_for_test = opponents_frozen
				if "test_freeze_timer" in actor:
					actor.test_freeze_timer = 0.0
		if opponents_frozen:
			print("[Test F] Rivales y Compañero FRENADOS para pruebas")
		else:
			print("[Test F] Rivales y Compañero ACTIVOS")

# --- Asistencia de Pase Hacia Compañeros Aliados ---
func _find_assisted_teammate(base_dir: Vector3) -> Dictionary:
	if manual_aim_mode:
		return {}

	var tree = get_tree()
	if not tree:
		return {}

	var teammates = tree.get_nodes_in_group("teammates")
	var best_teammate = null
	var best_score: float = -999.0
	var best_dist: float = 0.0
	var best_dir: Vector3 = Vector3.ZERO
	var my_pos: Vector3 = global_transform.origin

	for t in teammates:
		if t == self or not (t is Spatial) or not is_instance_valid(t):
			continue
		var t_pos: Vector3 = t.global_transform.origin
		var to_t: Vector3 = t_pos - my_pos
		to_t.y = 0.0
		var dist: float = to_t.length()
		if dist < 0.5 or dist > 28.0:
			continue
		var dir_to_t: Vector3 = to_t.normalized()
		var dot: float = base_dir.dot(dir_to_t)
		if dot < 0.35:
			continue

		var score: float = dot * 2.0 - (dist / 28.0) * 0.4
		if score > best_score:
			best_score = score
			best_teammate = t
			best_dist = dist
			best_dir = dir_to_t

	if best_teammate != null:
		return {
			"node": best_teammate,
			"dist": best_dist,
			"dir": best_dir
		}
	return {}

func _get_assisted_pass_vector(base_dir: Vector3, pass_type: String) -> Dictionary:
	var assist_info = _find_assisted_teammate(base_dir)
	var final_dir: Vector3 = base_dir
	var dist: float = 0.0
	var has_assist: bool = false

	if not assist_info.empty():
		has_assist = true
		dist = assist_info["dist"]
		var t_node = assist_info["node"]
		var target_dir: Vector3 = assist_info["dir"]

		if pass_type == "through":
			var lead_offset: Vector3 = Vector3(0, 0, -2.4)
			if "facing_direction" in t_node and t_node.facing_direction.length_squared() > 0.01:
				lead_offset = t_node.facing_direction.normalized() * 2.4
			var lead_pos: Vector3 = t_node.global_transform.origin + lead_offset
			var to_lead: Vector3 = lead_pos - global_transform.origin
			to_lead.y = 0.0
			if to_lead.length() > 0.5:
				target_dir = to_lead.normalized()
				dist = to_lead.length()

		# Mezcla moderada: ~60% hacia compañero / ~40% dirección apuntada (asistencia 55%-65%)
		final_dir = (base_dir * 0.40 + target_dir * 0.60).normalized()

	return {
		"dir": final_dir,
		"dist": dist,
		"assisted": has_assist
	}

# --- Botón X: Pase Corto Raso ---
func _execute_short_pass() -> void:
	if not _can_kick_ball():
		return

	var base_dir = _get_action_direction()
	var assist_data = _get_assisted_pass_vector(base_dir, "short")
	var pass_dir: Vector3 = assist_data["dir"]
	var pass_impulse: Vector3 = Vector3.ZERO

	var pass_speed: float = fallback_pass_force
	if assist_data["assisted"]:
		pass_speed = clamp(assist_data["dist"] * 0.95 + 4.5, fallback_pass_force, 24.0)

	if mechanics and mechanics.has_method("calculate_pass_force"):
		var res = mechanics.calculate_pass_force(pass_dir.x, pass_dir.z)
		if typeof(res) == TYPE_VECTOR3:
			if assist_data["assisted"]:
				var h_speed: float = max(1.0, Vector2(res.x, res.z).length())
				var mult: float = pass_speed / h_speed
				pass_impulse = Vector3(res.x * mult, 0.08, res.z * mult)
			else:
				pass_impulse = res
		else:
			pass_impulse = Vector3(pass_dir.x * pass_speed, 0.08, pass_dir.z * pass_speed)
	else:
		pass_impulse = Vector3(pass_dir.x * pass_speed, 0.08, pass_dir.z * pass_speed)

	ball_ref.apply_central_impulse(pass_impulse)
	drain_stamina(4.0)
	add_fury(8.0 * fury_gain_mult)
	kick_cooldown = 0.25
	is_dribbling = false
	is_ball_controlled = false
	print("[PPSSPP] Botón X (Cruz): Pase corto ejecutado -> ", pass_impulse, " (Asistido: %s)" % str(assist_data["assisted"]))

# --- Botón O: Centro / Pase Bombeado ---
func _execute_lob_pass() -> void:
	if not _can_kick_ball():
		return

	var base_dir = _get_action_direction()
	var assist_data = _get_assisted_pass_vector(base_dir, "lob")
	var pass_dir: Vector3 = assist_data["dir"]
	var lob_impulse: Vector3 = Vector3.ZERO

	var pass_speed: float = fallback_lob_force
	var lob_vy: float = 4.2
	if assist_data["assisted"]:
		pass_speed = clamp(assist_data["dist"] * 0.90 + 6.0, fallback_lob_force, 26.0)
		lob_vy = clamp(3.2 + assist_data["dist"] * 0.12, 3.8, 6.2)

	if mechanics and mechanics.has_method("calculate_lob_pass"):
		var res = mechanics.calculate_lob_pass(pass_dir.x, pass_dir.z)
		if typeof(res) == TYPE_VECTOR3:
			if assist_data["assisted"]:
				var h_speed: float = max(1.0, Vector2(res.x, res.z).length())
				var mult: float = pass_speed / h_speed
				lob_impulse = Vector3(res.x * mult, lob_vy, res.z * mult)
			else:
				lob_impulse = res
		else:
			lob_impulse = Vector3(pass_dir.x * pass_speed, lob_vy, pass_dir.z * pass_speed)
	else:
		lob_impulse = Vector3(pass_dir.x * pass_speed, lob_vy, pass_dir.z * pass_speed)

	ball_ref.apply_central_impulse(lob_impulse)
	drain_stamina(6.0)
	add_fury(10.0 * fury_gain_mult)
	kick_cooldown = 0.25
	is_dribbling = false
	is_ball_controlled = false
	print("[PPSSPP] Botón O (Círculo): Pase bombeado / Centro ejecutado -> ", lob_impulse, " (Asistido: %s)" % str(assist_data["assisted"]))

# --- Botón Δ: Pase en Profundidad / al Hueco ---
func _execute_through_pass() -> void:
	if not _can_kick_ball():
		return

	var base_dir = _get_action_direction()
	var assist_data = _get_assisted_pass_vector(base_dir, "through")
	var pass_dir: Vector3 = assist_data["dir"]
	var through_impulse: Vector3 = Vector3.ZERO

	var pass_speed: float = fallback_through_force
	if assist_data["assisted"]:
		pass_speed = clamp(assist_data["dist"] * 1.05 + 5.5, fallback_through_force, 28.0)

	if mechanics and mechanics.has_method("calculate_through_pass"):
		var res = mechanics.calculate_through_pass(pass_dir.x, pass_dir.z)
		if typeof(res) == TYPE_VECTOR3:
			if assist_data["assisted"]:
				var h_speed: float = max(1.0, Vector2(res.x, res.z).length())
				var mult: float = pass_speed / h_speed
				through_impulse = Vector3(res.x * mult, 0.05, res.z * mult)
			else:
				through_impulse = res
		else:
			through_impulse = Vector3(pass_dir.x * pass_speed, 0.05, pass_dir.z * pass_speed)
	else:
		through_impulse = Vector3(pass_dir.x * pass_speed, 0.05, pass_dir.z * pass_speed)

	ball_ref.apply_central_impulse(through_impulse)
	drain_stamina(7.0)
	add_fury(12.0 * fury_gain_mult)
	kick_cooldown = 0.25
	is_dribbling = false
	is_ball_controlled = false
	print("[PPSSPP] Botón Δ (Triángulo): Pase en profundidad ejecutado -> ", through_impulse, " (Asistido: %s)" % str(assist_data["assisted"]))

# --- Botón □: Disparo / Remate a Portería ---
func _execute_kick() -> void:
	if not _can_kick_ball():
		return

	var kick_dir = _get_action_direction()
	var kick_impulse: Vector3 = _calculate_kick_vector(kick_dir, shot_charge)

	ball_ref.apply_central_impulse(kick_impulse)
	var stamina_cost = 8.0 + shot_charge * 14.0
	drain_stamina(stamina_cost)
	add_fury(12.0 * fury_gain_mult)
	kick_cooldown = 0.25
	is_dribbling = false
	is_ball_controlled = false
	print("[PPSSPP] Botón □ (Cuadrado): Disparo ejecutado -> Potencia: ", stepify(shot_charge * 100, 1), "% | Vector: ", kick_impulse)

# --- Tiro Especial ("Gekitotsu Shot" — Activado con L + Disparo) ---
func _execute_special_shot() -> void:
	if not _can_kick_ball():
		return

	fury = 0.0
	emit_signal("fury_changed", fury, max_fury)
	emit_signal("special_shot_executed")

	# Orientar hacia la portería rival (RivalGoalArea en Z negativo)
	var rival_goal = get_node_or_null("../RivalGoalArea")
	var target_goal_pos = Vector3(0.0, 0.6, -44.2)
	if rival_goal:
		target_goal_pos = rival_goal.global_transform.origin
		target_goal_pos.y = 0.6

	var to_goal = target_goal_pos - ball_ref.global_transform.origin
	var shot_dir = to_goal.normalized()
	if to_goal.length_squared() < 0.01:
		shot_dir = facing_direction.normalized()

	var shot_speed: float = 38.0 * kick_power_mult
	var special_impulse = Vector3(shot_dir.x * shot_speed, 1.5, shot_dir.z * shot_speed)

	ball_ref.linear_velocity = special_impulse
	ball_ref.apply_central_impulse(special_impulse)

	_flash_ball()
	drain_stamina(12.0)
	kick_cooldown = 0.35
	is_dribbling = false
	is_ball_controlled = false

	print("[Player] ¡¡¡GEKITOTSU SHOT (TIRO ESPECIAL) ACTIVADO CON L + DISPARO!!! Potencia: %.1f" % shot_speed)

func _flash_ball() -> void:
	if not ball_ref or not is_instance_valid(ball_ref):
		return
	var mesh_inst = ball_ref.get_node_or_null("MeshInstance")
	if mesh_inst and mesh_inst is MeshInstance:
		var mat = mesh_inst.get_surface_material(0)
		if mat and mat is SpatialMaterial:
			var orig_emission = mat.emission_enabled
			var orig_color = mat.emission
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.85, 0.2)
			if get_tree():
				yield(get_tree().create_timer(0.2), "timeout")
				if mat and is_instance_valid(mat):
					mat.emission_enabled = orig_emission
					mat.emission = orig_color

# --- Detección de Rivales y Compañeros para Posesión de Balón ---
func _is_rival_near_ball(ball_pos: Vector3, max_dist: float = 2.2) -> bool:
	var tree = get_tree()
	if not tree:
		return false
	var rival_groups = ["opponents", "rivals", "enemy"]
	for grp in rival_groups:
		var nodes = tree.get_nodes_in_group(grp)
		for node in nodes:
			if node is Spatial and is_instance_valid(node) and not node.is_queued_for_deletion():
				var n_pos = node.global_transform.origin
				n_pos.y = ball_pos.y
				if ball_pos.distance_to(n_pos) <= max_dist:
					return true
	return false

func _get_allied_teammate_near_ball(ball_pos: Vector3, max_dist: float = 4.5) -> Spatial:
	var tree = get_tree()
	if not tree:
		return null
	var ally_groups = ["teammates", "allies"]
	for grp in ally_groups:
		var nodes = tree.get_nodes_in_group(grp)
		for node in nodes:
			if node != self and node is Spatial and is_instance_valid(node) and not node.is_queued_for_deletion():
				if "role" in node and node.role == "goalkeeper":
					continue
				if "has_ball" in node and node.has_ball:
					return node as Spatial
				if "is_dribbling" in node and node.is_dribbling:
					return node as Spatial
				var n_pos = node.global_transform.origin
				n_pos.y = ball_pos.y
				if ball_pos.distance_to(n_pos) <= max_dist:
					return node as Spatial
	return null

# --- Botón L (Q / L1): Pedir el balón o Control Orientado ---
func _on_button_l_pressed() -> void:
	_resolve_ball_reference()
	if not ball_ref or not is_instance_valid(ball_ref):
		return

	var ball_pos: Vector3 = ball_ref.global_transform.origin
	var player_pos: Vector3 = global_transform.origin
	var to_player: Vector3 = ball_pos - player_pos
	to_player.y = 0.0
	var dist_to_player: float = to_player.length()

	# 1. Si existe algún rival a menos de 2.2 m del balón (el rival tiene posesión),
	# presionar L NO debe pasar ni atraer el balón hacia el jugador; ignora la petición.
	if _is_rival_near_ball(ball_pos, 2.2):
		print("[Futbol] Botón L (Q / L1): Posesión rival (< 2.2m); petición ignorada.")
		return

	# 2. Si el balón está a <= 2.2 m del propio jugador (y no lo tiene un rival):
	# Recepción / Control Orientado (frena el balón a 0.65 m delante del jugador)
	if dist_to_player <= 2.2:
		facing_direction = Vector3(0.0, 0.0, -1.0)
		var target_pos = player_pos + facing_direction * 0.65
		target_pos.y = ball_pos.y
		ball_ref.global_transform.origin = target_pos
		ball_ref.linear_velocity = Vector3.ZERO
		ball_ref.angular_velocity = Vector3.ZERO
		is_dribbling = true
		is_ball_controlled = true
		kick_cooldown = 0.0
		print("[Futbol] Botón L (Q / L1): Recepción / Control orientado a 0.65 m hacia portería.")
		return

	# 3. Si el balón está lejos (> 2.2 m):
	on_incoming_pass()
	# Buscar si un compañero aliado tiene el balón o está a <= 4.5 m del balón suelto
	var ally = _get_allied_teammate_near_ball(ball_pos, 4.5)
	if ally != null:
		if ally.has_method("receive_pass_call"):
			ally.receive_pass_call(self)
			print("[Futbol] Botón L (Q / L1): Compañero aliado pasa a Ryu y se desmarca.")
			return
		else:
			var pass_target = player_pos + (facing_direction * 1.0)
			var pass_vec = pass_target - ball_pos
			pass_vec.y = 0.0
			var pass_dist = pass_vec.length()
			if pass_dist > 0.1:
				var pass_dir = pass_vec.normalized()
				var pass_speed = clamp(pass_dist * 0.85, 8.0, 18.0)
				var impulse = Vector3(pass_dir.x * pass_speed, 0.08, pass_dir.z * pass_speed)
				ball_ref.linear_velocity = impulse
				ball_ref.apply_central_impulse(impulse)
				print("[Futbol] Botón L (Q / L1): Compañero aliado realiza pase hacia Ryu.")
				return

	# Si hay otros compañeros en el grupo teammates con receive_pass_call a <= 4.5m o con balón
	var teammates = get_tree().get_nodes_in_group("teammates")
	for t in teammates:
		if t != self and t.has_method("receive_pass_call"):
			var t_pos = t.global_transform.origin
			t_pos.y = ball_pos.y
			var t_dist = t_pos.distance_to(ball_pos)
			var has_it = ("has_ball" in t and t.has_ball) or ("is_dribbling" in t and t.is_dribbling)
			if has_it or t_dist <= 4.5:
				t.receive_pass_call(self)
				print("[Futbol] Botón L (Q / L1): Teammate llamado a pasar y desmarcarse.")
				return

	# 4. Balón suelto en la cancha y no hay nadie cerca:
	# Se elimina por completo la atracción magnética desde lejos. No hacer nada.
	print("[Futbol] Botón L (Q / L1): Balón suelto sin compañeros cerca (< 4.5m); petición ignorada.")
		
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
	if not enable_stamina_fatigue:
		return
	stamina = max(0.0, stamina - amount)
	fallback_stamina = stamina
	if mechanics:
		if mechanics.has_method("drain_stamina"):
			mechanics.drain_stamina(amount)
		elif mechanics.has_method("set_stamina"):
			mechanics.set_stamina(stamina)
	if stamina <= 0.0:
		stamina = 0.0
		is_exhausted = true

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

func on_incoming_pass() -> void:
	expecting_pass = true
	pass_receive_timer = 2.5

func receive_foul(opponent = null) -> void:
	if foul_cooldown > 0.0:
		return
	foul_cooldown = 1.2
	add_fury(30.0 * fury_gain_mult)
	print("[Player] ¡FALTA RECIBIDA! Choque físico con rival (+30 Furia).")
	var hud = _find_pitch_hud()
	if hud and hud.has_method("show_foul_notice"):
		hud.show_foul_notice("¡FALTA RECIBIDA! +30 FURIA")

func on_goal_conceded() -> void:
	add_fury(25.0 * fury_gain_mult)
	print("[Player] Gol recibido en contra (+25 Furia).")

func _update_match_tension_fury(delta: float) -> void:
	if is_in_brawl or get_tree().paused:
		return

	var p_goals: int = 0
	var r_goals: int = 0
	var match_min: int = 0

	var hud = _find_pitch_hud()
	if hud:
		if hud.has_method("get_player_score"):
			p_goals = hud.get_player_score()
		if hud.has_method("get_opponent_score"):
			r_goals = hud.get_opponent_score()
		if hud.has_method("get_match_minute"):
			match_min = hud.get_match_minute()
		elif "real_elapsed_time" in hud:
			match_min = int((hud.real_elapsed_time * 30.0) / 60.0)
	elif mechanics:
		if mechanics.has_method("get_player_score"):
			p_goals = mechanics.get_player_score()
		if mechanics.has_method("get_opponent_score"):
			r_goals = mechanics.get_opponent_score()

	var tension_rate: float = 0.0
	var diff: int = r_goals - p_goals

	if diff >= 2:
		tension_rate += 5.0
	elif diff == 1:
		tension_rate += 3.0

	# En los últimos 15 minutos (>= 75') empatado o perdiendo suma +2.0 * delta
	if match_min >= 75 and diff >= 0:
		tension_rate += 2.0

	if tension_rate > 0.0:
		add_fury(tension_rate * delta * fury_gain_mult)

func is_charging_shot() -> bool:
	return is_charging

func set_stamina(val: float) -> void:
	stamina = clamp(val, 0.0, max_stamina)
	fallback_stamina = stamina
	if enable_stamina_fatigue and stamina <= 0.0:
		is_exhausted = true
	elif is_exhausted and stamina >= 35.0:
		is_exhausted = false
	if mechanics and mechanics.has_method("set_stamina"):
		mechanics.set_stamina(stamina)

func get_stamina() -> float:
	if mechanics and mechanics.has_method("get_stamina"):
		return mechanics.get_stamina()
	return stamina

func set_max_stamina(val: float) -> void:
	max_stamina = max(1.0, val)
	fallback_max_stamina = max_stamina

func get_max_stamina() -> float:
	if mechanics and mechanics.has_method("get_max_stamina"):
		return mechanics.get_max_stamina()
	return max_stamina

func get_current_speed() -> float:
	var spd = fallback_base_speed
	if enable_stamina_fatigue and is_exhausted:
		spd *= 0.8
	if knock_on_boost_timer > 0.0:
		spd *= 1.22
	var cur_btn_l: bool = Input.is_action_pressed("psp_l") or Input.is_key_pressed(KEY_Q) or Input.is_joy_button_pressed(0, JOY_BUTTON_4)
	if cur_btn_l and (is_dribbling or is_ball_controlled):
		spd *= 0.8
	return spd

func get_facing_direction() -> Vector3:
	return facing_direction

# ---------------------------------------------------------------------------
# Sistema de Duelo Superpuesto en Cancha (Pitch Brawl) y Aturdimiento
# ---------------------------------------------------------------------------
func set_stun(duration: float = 3.5) -> void:
	stun_timer = max(0.0, duration)
	velocity = Vector3.ZERO

func _find_nearest_brawl_rival() -> Spatial:
	var tree = get_tree()
	if not tree:
		return null
	var candidate_groups = ["opponents", "rivals"]
	var my_pos = global_transform.origin
	var nearest_rival: Spatial = null
	var min_dist: float = 999999.0

	for grp in candidate_groups:
		var nodes = tree.get_nodes_in_group(grp)
		for node in nodes:
			if node != self and node is Spatial and is_instance_valid(node) and not node.is_queued_for_deletion():
				var node_pos = node.global_transform.origin
				var dist_xz = Vector2(node_pos.x - my_pos.x, node_pos.z - my_pos.z).length()
				if dist_xz <= 4.0 and dist_xz < min_dist:
					min_dist = dist_xz
					nearest_rival = node as Spatial
	return nearest_rival

func _find_pitch_camera():
	var tree = get_tree()
	if not tree:
		return null
	var cams = tree.get_nodes_in_group("pitch_camera")
	if cams.size() > 0:
		return cams[0]
	if has_node("../PitchCamera"):
		return get_node("../PitchCamera")
	if has_node("../OverheadCamera"):
		return get_node("../OverheadCamera")
	return null

func _find_pitch_hud():
	var tree = get_tree()
	if not tree:
		return null
	var huds = tree.get_nodes_in_group("pitch_hud")
	if huds.size() > 0:
		return huds[0]
	if has_node("../PitchHUD"):
		return get_node("../PitchHUD")
	return null

func _show_brawl_warning_in_hud(msg: String) -> void:
	var hud = _find_pitch_hud()
	if hud and hud.has_method("show_brawl_warning"):
		hud.show_brawl_warning(msg)

func trigger_pitch_brawl(instant: bool = false) -> bool:
	return _trigger_pitch_brawl(instant)

func _trigger_pitch_brawl(instant: bool = false) -> bool:
	if is_in_brawl or get_tree().paused:
		return false

	var rival = _find_nearest_brawl_rival()
	if not rival:
		print("[Player] No hay rivales a <= 4.0m para iniciar duelo.")
		_show_brawl_warning_in_hud("¡ACÉRCATE A UN RIVAL PARA INICIAR DUELO!")
		return false

	is_in_brawl = true

	# 1. Transición cinematográfica: Zoom rápido de PitchCamera al punto medio entre Ryu y el rival
	var my_pos = global_transform.origin
	var rival_pos = rival.global_transform.origin if "global_transform" in rival else my_pos
	var midpoint: Vector3 = (my_pos + rival_pos) * 0.5

	var cam = _find_pitch_camera()
	if cam and cam.has_method("start_cinematic_zoom"):
		cam.start_cinematic_zoom(midpoint)

	# 2. Flash de pantalla breve y banner '¡CHISPA EN EL CÉSPED! ¡DUELO 1 VS 1!' en PitchHUD
	var hud = _find_pitch_hud()
	if hud and hud.has_method("play_brawl_transition"):
		hud.play_brawl_transition("¡CHISPA EN EL CÉSPED! ¡DUELO 1 VS 1!")

	# Pausar la cancha para que los jugadores y el balón se detengan
	get_tree().paused = true

	# 3. Micro-secuencia de 0.35s compatible con pausa antes de desplegar FightArena
	if not instant and get_tree() and get_tree().current_scene != null:
		_delayed_start_pitch_brawl_overlay(rival)
		return true

	var layer = _start_pitch_brawl_overlay(rival)
	return layer != null

func _delayed_start_pitch_brawl_overlay(rival) -> void:
	yield(get_tree().create_timer(0.35, true), "timeout")
	if is_in_brawl:
		_start_pitch_brawl_overlay(rival)

func start_pitch_brawl(rival = null):
	if rival == null:
		rival = _find_nearest_brawl_rival()
	if not rival:
		_show_brawl_warning_in_hud("¡ACÉRCATE A UN RIVAL PARA INICIAR DUELO!")
		return null

	is_in_brawl = true
	var my_pos = global_transform.origin
	var rival_pos = rival.global_transform.origin if "global_transform" in rival else my_pos
	var midpoint: Vector3 = (my_pos + rival_pos) * 0.5

	var cam = _find_pitch_camera()
	if cam and cam.has_method("start_cinematic_zoom"):
		cam.start_cinematic_zoom(midpoint)

	var hud = _find_pitch_hud()
	if hud and hud.has_method("play_brawl_transition"):
		hud.play_brawl_transition("¡CHISPA EN EL CÉSPED! ¡DUELO 1 VS 1!")

	return _start_pitch_brawl_overlay(rival)

func _start_pitch_brawl_overlay(rival):
	is_in_brawl = true

	# 1. CanvasLayer (BrawlOverlayLayer, layer = 20)
	var brawl_layer = CanvasLayer.new()
	brawl_layer.name = "BrawlOverlayLayer"
	brawl_layer.layer = 20
	brawl_layer.pause_mode = Node.PAUSE_MODE_PROCESS

	# 2. ViewportContainer + Viewport con transparent_bg = true y own_world = true
	var vp_container = ViewportContainer.new()
	vp_container.name = "BrawlViewportContainer"
	vp_container.pause_mode = Node.PAUSE_MODE_PROCESS
	vp_container.anchor_right = 1.0
	vp_container.anchor_bottom = 1.0
	vp_container.stretch = true

	var vp = Viewport.new()
	vp.name = "BrawlViewport"
	vp.pause_mode = Node.PAUSE_MODE_PROCESS
	vp.transparent_bg = true
	vp.own_world = true
	var tree = get_tree()
	if tree and tree.root:
		vp.size = tree.root.size
	else:
		vp.size = Vector2(1024, 600)
	vp.render_target_update_mode = Viewport.UPDATE_ALWAYS

	# 3. Instanciar res://scenes/FightArena.tscn
	var arena_scene = load("res://scenes/FightArena.tscn")
	if not arena_scene:
		push_error("[Player] Error al cargar res://scenes/FightArena.tscn")
		is_in_brawl = false
		return null

	var arena = arena_scene.instance()
	arena.name = "FightArena"
	arena.pause_mode = Node.PAUSE_MODE_PROCESS
	arena.is_pitch_brawl = true

	arena.connect("brawl_finished", self, "_on_brawl_finished", [brawl_layer, rival])

	vp.add_child(arena)
	vp_container.add_child(vp)
	brawl_layer.add_child(vp_container)

	if get_parent():
		get_parent().add_child(brawl_layer)
	elif tree and tree.root:
		tree.root.add_child(brawl_layer)
	else:
		add_child(brawl_layer)

	get_tree().paused = true
	print("[Player] ¡DUELO INICIADO EN LA CANCHA! Cancha pausada, overlay 2.5D activo.")
	return brawl_layer

func _on_brawl_finished(player_won: bool, brawl_layer, rival) -> void:
	pitch_brawls_count += 1

	# 1. Destruir overlay
	if brawl_layer and is_instance_valid(brawl_layer):
		brawl_layer.queue_free()

	# 2. Restaurar zoom de PitchCamera suavemente
	var cam = _find_pitch_camera()
	if cam and cam.has_method("reset_cinematic_zoom"):
		cam.reset_cinematic_zoom()

	# 3. Reiniciar furia
	fury = 0.0
	emit_signal("fury_changed", fury, max_fury)

	# 4. Mostrar resultado del duelo en PitchHUD
	var hud = _find_pitch_hud()
	if hud and hud.has_method("show_duel_result"):
		var result_msg = "¡RIVAL NOQUEADO EN EL CÉSPED!" if player_won else "¡RYU ATURDIDO!"
		hud.show_duel_result(result_msg, player_won)

	# 5. Aplicar aturdimiento temporal
	if player_won:
		if rival and is_instance_valid(rival):
			if "stun_timer" in rival:
				rival.stun_timer = 7.0
			elif rival.has_method("set_stun"):
				rival.set_stun(7.0)
			if "velocity" in rival:
				rival.velocity = Vector3.ZERO
			if "target_velocity" in rival:
				rival.target_velocity = Vector3.ZERO
		print("[Player] ¡Ryu venció en el duelo! Rival aturdido por 7.0s.")
	else:
		stun_timer = 3.5
		velocity = Vector3.ZERO
		print("[Player] ¡Ryu fue derrotado en el duelo! Aturdido por 3.5s.")

	# 6. Consecuencia arbitral por pelear en la cancha
	var cur_stats = get_tree().root.get_meta("gtp_stats") if (get_tree() and get_tree().root and get_tree().root.has_meta("gtp_stats")) else {
		"discipline": discipline_stat, "combat": combat_stat, "money": 0, "reputation": 0
	}
	var cur_disc: int = int(cur_stats.get("discipline", discipline_stat))

	if pitch_brawls_count == 1:
		# 1er duelo: Tarjeta Amarilla y descuento de Disciplina
		cur_stats["discipline"] = max(0, cur_disc - 15)
		if get_tree() and get_tree().root:
			get_tree().root.set_meta("gtp_stats", cur_stats)

		if ClassDB.class_exists("GekitotsuStoryManager"):
			var sm = null
			if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("GekitotsuStoryManager"):
				sm = ClassDB.instantiate("GekitotsuStoryManager")
			elif ClassDB.has_method("can_instance") and ClassDB.can_instance("GekitotsuStoryManager"):
				sm = ClassDB.instance("GekitotsuStoryManager")
			if sm and sm.has_method("add_sports_discipline"):
				sm.add_sports_discipline(-15)

		if hud and hud.has_method("show_referee_card"):
			hud.show_referee_card("yellow", "¡TARJETA AMARILLA! Última advertencia del árbitro")

		# Reanudar partido
		get_tree().paused = false
		is_in_brawl = false
		apply_rpg_stats(int(cur_stats.get("combat", combat_stat)), int(cur_stats.get("discipline", discipline_stat)))
		print("[Player] Árbitro muestra Tarjeta Amarilla (1er duelo). Disciplina descontada. Partido reanudado.")

		# Ocultar aviso de tarjeta tras 2.2s
		yield(get_tree().create_timer(2.2, true), "timeout")
		if hud and hud.has_method("hide_referee_card"):
			hud.hide_referee_card()

	else:
		# 2do duelo o disciplina agotada: Tarjeta Roja (Expulsión por conducta antideportiva)
		cur_stats["discipline"] = max(0, cur_disc - 30)
		cur_stats["reputation"] = cur_stats.get("reputation", 0) + 20
		if get_tree() and get_tree().root:
			get_tree().root.set_meta("gtp_stats", cur_stats)

		if ClassDB.class_exists("GekitotsuStoryManager"):
			var sm = null
			if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("GekitotsuStoryManager"):
				sm = ClassDB.instantiate("GekitotsuStoryManager")
			elif ClassDB.has_method("can_instance") and ClassDB.can_instance("GekitotsuStoryManager"):
				sm = ClassDB.instance("GekitotsuStoryManager")
			if sm and sm.has_method("add_sports_discipline"):
				sm.add_sports_discipline(-30)

		# Asegurar que el overlay de FightArena esté destruido (queue_free) ANTES de finish_match_disqualification
		if brawl_layer and is_instance_valid(brawl_layer):
			brawl_layer.queue_free()

		var found_layer = get_tree().root.find_node("BrawlOverlayLayer", true, false) if (get_tree() and get_tree().root) else null
		if found_layer and is_instance_valid(found_layer):
			found_layer.queue_free()

		if hud and hud.has_method("show_referee_card"):
			hud.show_referee_card("red", "¡TARJETA ROJA! Expulsión por conducta antideportiva")
		if hud and hud.has_method("finish_match_disqualification"):
			hud.finish_match_disqualification()

		print("[Player] Árbitro muestra Tarjeta Roja (2do duelo o disciplina en 0). Expulsión.")

		# Esperar 2.5s y regresar a MainGame.tscn
		yield(get_tree().create_timer(2.5, true), "timeout")
		get_tree().paused = false
		is_in_brawl = false
		get_tree().change_scene("res://scenes/MainGame.tscn")
