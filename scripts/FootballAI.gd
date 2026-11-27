extends KinematicBody

class_name FootballAI

# Roles disponibles: "goalkeeper", "opponent", "teammate"
export(String, "goalkeeper", "opponent", "teammate") var role: String = "opponent"
export(bool) var is_player_team: bool = false
export(String) var tactical_slot: String = ""
export(Vector3) var home_position: Vector3 = Vector3.ZERO
export(String) var formation_name: String = ""
# Velocidades equilibradas y dinámicas
export(float) var move_speed: float = 7.4
export(float) var sprint_speed: float = 10.4
export(float) var dribble_speed: float = 7.0
export(float) var kick_reach: float = 1.6
# Estamina y IA
export(bool) var enable_stamina_fatigue: bool = true
export(float) var stamina: float = 100.0 setget set_stamina, get_stamina
export(float) var max_stamina: float = 100.0
var is_exhausted: bool = false
var stun_timer: float = 0.0
var ai_decision_timer: float = 0.0
var separation_radius: float = 3.5

# Variables de prueba en cancha (Frenar / Pausar)
export(bool) var is_frozen_for_test: bool = false
var test_freeze_timer: float = 0.0

# Temporizadores de pase a Ryu y desmarque asistido
var pass_to_player_cooldown: float = 0.0
var unmark_timer: float = 0.0

var velocity: Vector3 = Vector3.ZERO
var target_velocity: Vector3 = Vector3.ZERO
var facing_direction: Vector3 = Vector3(0, 0, 1)
var target_facing: Vector3 = Vector3(0, 0, 1)
var initial_position: Vector3 = Vector3.ZERO
var initial_facing: Vector3 = Vector3(0, 0, 1)

var ball_ref = null
var has_ball: bool = false
var is_dribbling: bool = false

var possession_cooldown: float = 0.0
var kick_cooldown: float = 0.0
var tackle_cooldown: float = 0.0

func _ready() -> void:
	initial_position = global_transform.origin
	if home_position == Vector3.ZERO:
		home_position = initial_position

	# Asignación de grupos según rol y equipo
	if role == "goalkeeper":
		add_to_group("goalkeepers")
		if is_player_team:
			add_to_group("teammates")
			facing_direction = Vector3(0, 0, -1)
		else:
			add_to_group("opponents")
			facing_direction = Vector3(0, 0, 1)
	elif role == "teammate":
		is_player_team = true
		add_to_group("teammates")
		facing_direction = Vector3(0, 0, -1)
	elif role == "opponent":
		is_player_team = false
		add_to_group("opponents")
		facing_direction = Vector3(0, 0, 1)

		# Escalar ligeramente velocidad y ritmo de la IA rival según la jornada de liga
		var matchday: int = 1
		var gs = get_node_or_null("/root/GameSettings")
		if gs and gs.has_method("load_progress"):
			var save_d = gs.load_progress()
			matchday = int(save_d.get("matchday", 1))
		elif get_tree() and get_tree().root and get_tree().root.has_meta("gtp_stats"):
			var s = get_tree().root.get_meta("gtp_stats")
			matchday = int(s.get("matchday", 1))

		var scale_factor: float = clamp(float(matchday - 1) * 0.035, 0.0, 0.35)
		move_speed = 7.4 * (1.0 + scale_factor)
		sprint_speed = 10.4 * (1.0 + scale_factor)
		dribble_speed = 7.0 * (1.0 + scale_factor * 0.5)

	initial_facing = facing_direction

	# Aplicar material independiente sobre el nodo hijo MeshInstance
	var mat = SpatialMaterial.new()
	mat.roughness = 0.4
	match role:
		"goalkeeper":
			if is_player_team:
				mat.albedo_color = Color(0.10, 0.30, 0.75)
			else:
				mat.albedo_color = Color(0.75, 0.28, 0.10)
		"teammate":
			mat.albedo_color = Color(0.15, 0.85, 0.55)
		"opponent":
			mat.albedo_color = Color(0.90, 0.16, 0.16)

	for child in get_children():
		if child is MeshInstance:
			child.material_override = mat
			break

func set_test_freeze(frozen: bool, duration: float = 0.0) -> void:
	if role == "goalkeeper":
		return
	is_frozen_for_test = frozen
	test_freeze_timer = max(0.0, duration)
	if is_frozen_for_test or test_freeze_timer > 0.0:
		velocity = Vector3.ZERO
		target_velocity = Vector3.ZERO
		has_ball = false
		is_dribbling = false

func drain_stamina(amount: float) -> void:
	if not enable_stamina_fatigue:
		return
	stamina = max(0.0, stamina - amount)
	if stamina <= 0.0:
		stamina = 0.0
		is_exhausted = true

func set_stamina(val: float) -> void:
	stamina = clamp(val, 0.0, max_stamina)
	if enable_stamina_fatigue and stamina <= 0.0:
		is_exhausted = true
	elif is_exhausted and stamina >= 35.0:
		is_exhausted = false

func get_stamina() -> float:
	return stamina

func set_stun(duration: float = 7.0) -> void:
	stun_timer = max(0.0, duration)
	velocity = Vector3.ZERO
	target_velocity = Vector3.ZERO
	has_ball = false
	is_dribbling = false

func reset_position() -> void:
	if home_position != Vector3.ZERO:
		global_transform.origin = home_position
	else:
		global_transform.origin = initial_position
	facing_direction = Vector3(0, 0, -1) if is_player_team else Vector3(0, 0, 1)
	target_facing = facing_direction
	velocity = Vector3.ZERO
	target_velocity = Vector3.ZERO
	has_ball = false
	is_dribbling = false
	possession_cooldown = 0.0
	kick_cooldown = 0.0
	tackle_cooldown = 0.0
	is_frozen_for_test = false
	test_freeze_timer = 0.0
	pass_to_player_cooldown = 0.0
	unmark_timer = 0.0
	stun_timer = 0.0
	is_exhausted = false
	stamina = max_stamina

func lose_ball() -> void:
	has_ball = false
	is_dribbling = false
	possession_cooldown = 0.65

func _resolve_ball() -> void:
	if ball_ref == null or not is_instance_valid(ball_ref):
		var balls = get_tree().get_nodes_in_group("ball")
		for b in balls:
			if b is RigidBody:
				ball_ref = b
				break

func _physics_process(delta: float) -> void:
	_resolve_ball()

	# Estado de aturdimiento (por resultado de duelo o impacto)
	if stun_timer > 0.0:
		stun_timer = max(0.0, stun_timer - delta)
		velocity = Vector3.ZERO
		target_velocity = Vector3.ZERO
		has_ball = false
		is_dribbling = false
		return

	# Manejo de congelamiento para pruebas en cancha (tecla F: rivales y compañero)
	if role == "opponent" or role == "teammate":
		if test_freeze_timer > 0.0:
			test_freeze_timer = max(0.0, test_freeze_timer - delta)
			if test_freeze_timer <= 0.0:
				test_freeze_timer = 0.0
				is_frozen_for_test = false

		if is_frozen_for_test or test_freeze_timer > 0.0:
			velocity = Vector3.ZERO
			target_velocity = Vector3.ZERO
			has_ball = false
			is_dribbling = false
			return

	# Temporizadores de desmarque tras pase al jugador
	if pass_to_player_cooldown > 0.0:
		pass_to_player_cooldown = max(0.0, pass_to_player_cooldown - delta)
	if unmark_timer > 0.0:
		unmark_timer = max(0.0, unmark_timer - delta)

	# Temporizadores generales
	if possession_cooldown > 0.0:
		possession_cooldown = max(0.0, possession_cooldown - delta)
	if kick_cooldown > 0.0:
		kick_cooldown = max(0.0, kick_cooldown - delta)
	if tackle_cooldown > 0.0:
		tackle_cooldown = max(0.0, tackle_cooldown - delta)

	# IA decision timer (conservado alrededor de 0.16–0.22 s para reactividad y ritmo fluido)
	ai_decision_timer -= delta
	var decision_ready = ai_decision_timer <= 0.0
	if decision_ready:
		ai_decision_timer = 0.18

	# Estamina y agotamiento compartidos (drena al esprintar y recupera al caminar/trotar o detenerse)
	if enable_stamina_fatigue:
		var is_sprinting_now: bool = velocity.length() > move_speed + 0.5
		if not is_exhausted:
			if is_sprinting_now:
				stamina = max(0.0, stamina - 20.0 * delta)
			else:
				stamina = min(max_stamina, stamina + 12.0 * delta)
			if stamina <= 0.0:
				stamina = 0.0
				is_exhausted = true
		else:
			stamina = min(max_stamina, stamina + 12.0 * delta)
			if stamina >= 35.0:
				is_exhausted = false
	else:
		is_exhausted = false

	# Selección de comportamiento según rol
	match role:
		"goalkeeper":
			_process_goalkeeper(delta, decision_ready)
		"opponent":
			_process_opponent(delta, decision_ready)
		"teammate":
			_process_teammate(delta, decision_ready)

	# Interpolación suave de velocity y facing_direction
	velocity = velocity.linear_interpolate(target_velocity, clamp(10.0 * delta, 0.0, 1.0))
	if target_facing.length_squared() > 0.001:
		facing_direction = facing_direction.linear_interpolate(target_facing, clamp(8.5 * delta, 0.0, 1.0)).normalized()

	# Movimiento físico continuo y fluido
	velocity = move_and_slide(velocity, Vector3.UP)

	# Conducción fluida del balón cuando el NPC tiene la posesión
	if has_ball and ball_ref and is_instance_valid(ball_ref):
		var ball_pos = ball_ref.global_transform.origin
		var target_ball = global_transform.origin + facing_direction * 0.95
		target_ball.y = ball_pos.y
		var to_b = target_ball - ball_pos
		to_b.y = 0.0
		ball_ref.linear_velocity = to_b * 9.0 + velocity * 0.85

	# Mantener dentro de los límites del campo (excepto porteros)
	if role != "goalkeeper":
		translation.x = clamp(translation.x, -19.0, 19.0)
		translation.z = clamp(translation.z, -27.5, 27.5)

	# Rotación suave hacia facing_direction
	var target_look = translation + facing_direction
	target_look.y = translation.y
	if translation.distance_squared_to(target_look) > 0.001:
		look_at(target_look, Vector3.UP)

	# Separación entre compañeros del mismo equipo
	var team_group = "teammates" if is_player_team else "opponents"
	var allies = get_tree().get_nodes_in_group(team_group)
	for ally in allies:
		if ally == self:
			continue
		if not (ally is Spatial):
			continue
		var diff = global_transform.origin - ally.global_transform.origin
		var dist = diff.length()
		if dist < separation_radius and dist > 0.001:
			var push = diff.normalized() * (separation_radius - dist) * 0.5
			translation += push * delta

# -------------------------------------------------------------------------
# 1. COMPORTAMIENTO DE PORTEROS ("goalkeeper")
# -------------------------------------------------------------------------
func _process_goalkeeper(_delta: float, decision_ready: bool = true) -> void:
	if not ball_ref or not is_instance_valid(ball_ref):
		target_velocity = Vector3.ZERO
		return

	var ball_pos: Vector3 = ball_ref.global_transform.origin
	var my_pos: Vector3 = global_transform.origin

	# Movimiento lateral en X dentro de los postes
	var target_x: float = clamp(ball_pos.x, -3.8, 3.8)
	var diff_x: float = target_x - my_pos.x
	if abs(diff_x) > 0.08:
		target_velocity.x = sign(diff_x) * min(abs(diff_x) * 6.0, move_speed)
	else:
		target_velocity.x = 0.0

	# Posición Z fija en la línea de gol (±26.5)
	var target_z: float = home_position.z if home_position != Vector3.ZERO else initial_position.z
	var diff_z: float = target_z - my_pos.z
	target_velocity.z = diff_z * 4.0
	target_velocity.y = 0.0

	# Detección de parada / despeje
	if decision_ready:
		var dist_to_ball: float = my_pos.distance_to(ball_pos)
		var in_save_area: bool = false
		if is_player_team:
			if ball_pos.z >= 21.0 and ball_pos.z <= 28.5 and abs(ball_pos.x) <= 4.5:
				in_save_area = true
		else:
			if ball_pos.z <= -21.0 and ball_pos.z >= -28.5 and abs(ball_pos.x) <= 4.5:
				in_save_area = true
		if dist_to_ball <= 2.2:
			in_save_area = true

		if in_save_area and kick_cooldown <= 0.0:
			var ball_speed: float = ball_ref.linear_velocity.length()
			if ball_speed < 24.0:
				var forward_z: float = 1.0 if not is_player_team else -1.0
				var side_x: float = rand_range(-0.6, 0.6)
				var clear_dir = Vector3(side_x, 0.1, forward_z).normalized()
				var clear_speed = 19.0
				var clear_impulse = Vector3(clear_dir.x * clear_speed, 1.4, clear_dir.z * clear_speed)
				ball_ref.linear_velocity = clear_impulse
				ball_ref.apply_central_impulse(clear_impulse)
				kick_cooldown = 0.55
				print("[AI Goalkeeper] Parada y despeje en %s! Vel. balón: %.1f" % [("Sur" if is_player_team else "Norte"), ball_speed])
			else:
				print("[AI Goalkeeper] Disparo imparable superó al portero! Vel: %.1f" % ball_speed)

# -------------------------------------------------------------------------
# 2. COMPORTAMIENTO DE RIVALES DE CAMPO ("opponent")
# -------------------------------------------------------------------------
func _process_opponent(_delta: float, decision_ready: bool = true) -> void:
	if not ball_ref or not is_instance_valid(ball_ref):
		target_velocity = Vector3.ZERO
		return

	var my_pos: Vector3 = global_transform.origin
	var ball_pos: Vector3 = ball_ref.global_transform.origin
	var speed_mult: float = 0.8 if (enable_stamina_fatigue and is_exhausted) else 1.0

	var carrier = _find_allied_ball_carrier()
	var carrier_is_player: bool = false
	if carrier != null:
		if carrier.is_in_group("player"):
			carrier_is_player = true
		elif "is_player_team" in carrier:
			carrier_is_player = carrier.is_player_team

	# Si otro rival ya tiene el balón, mantener formación táctica y apoyar ataque hacia Sur
	if carrier != null and carrier != self and carrier_is_player == is_player_team:
		var target_pos = _get_tactical_home_pos(ball_pos) + _get_separation_vector(3.5)
		var to_target = target_pos - my_pos
		to_target.y = 0.0
		var dist_tac = to_target.length()
		if dist_tac > 0.3:
			target_facing = to_target.normalized()
			target_velocity = target_facing * move_speed * speed_mult
		else:
			target_velocity = Vector3.ZERO
			target_facing = Vector3(0, 0, 1)
		return

	if has_ball:
		# Conducir hacia la portería Sur (Z = 28.0)
		var target_goal = Vector3(0.0, 0.8, 28.0)
		var to_goal = target_goal - my_pos
		to_goal.y = 0.0
		target_facing = to_goal.normalized()
		target_velocity = target_facing * dribble_speed * speed_mult

		if decision_ready and my_pos.z >= 14.0 and kick_cooldown <= 0.0:
			var shot_target = Vector3(rand_range(-2.5, 2.5), 0.5, 28.2)
			var shot_dir = (shot_target - ball_pos).normalized()
			var shot_impulse = Vector3(shot_dir.x * 20.0, 1.2, shot_dir.z * 20.0)
			ball_ref.linear_velocity = shot_impulse
			ball_ref.apply_central_impulse(shot_impulse)
			has_ball = false
			is_dribbling = false
			kick_cooldown = 0.6
			possession_cooldown = 1.0
			print("[AI Opponent] ¡Rival remata con fuerza hacia la portería Sur!")
	else:
		# Sin balón: solo los 2 rivales más cercanos al balón presionan activamente
		var dist_to_ball = my_pos.distance_to(ball_pos)
		var is_presser = _is_among_closest_to_ball(2)

		if is_presser or dist_to_ball <= 3.5:
			var target_dest = ball_pos
			if carrier and is_instance_valid(carrier):
				target_dest = carrier.global_transform.origin

			var to_dest = target_dest - my_pos
			to_dest.y = 0.0
			var dist = to_dest.length()

			if dist > 0.1:
				target_facing = to_dest.normalized()
				var chase_speed: float = move_speed if (enable_stamina_fatigue and is_exhausted) else sprint_speed
				target_velocity = target_facing * chase_speed * speed_mult
			else:
				target_velocity = Vector3.ZERO

			# Robo por contacto blindado contra distintos scripts
			if carrier and dist <= 1.35 and possession_cooldown <= 0.0:
				if "is_dribbling" in carrier:
					carrier.is_dribbling = false
				if "is_ball_controlled" in carrier:
					carrier.is_ball_controlled = false
				if "has_ball" in carrier:
					carrier.has_ball = false
				if carrier.has_method("lose_ball"):
					carrier.lose_ball()
				has_ball = true
				is_dribbling = true
				possession_cooldown = 0.55
				print("[AI Opponent] ¡Rival contacta y arrebata el balón!")
			elif not carrier and dist <= 1.4 and ball_ref.linear_velocity.length() < 18.0 and possession_cooldown <= 0.0:
				has_ball = true
				is_dribbling = true
				print("[AI Opponent] ¡Rival captura el balón suelto!")
		else:
			# Mantener línea táctica y separación mínima de 3.5 m
			var target_pos = _get_tactical_home_pos(ball_pos) + _get_separation_vector(3.5)
			var to_target = target_pos - my_pos
			to_target.y = 0.0
			var dist_tac = to_target.length()

			if dist_tac > 0.4:
				target_facing = to_target.normalized()
				target_velocity = target_facing * move_speed * speed_mult
			else:
				target_velocity = Vector3.ZERO
				var to_b = ball_pos - my_pos
				to_b.y = 0.0
				if to_b.length() > 0.1:
					target_facing = to_b.normalized()

# -------------------------------------------------------------------------
# 3. COMPORTAMIENTO DE COMPAÑERO ALIADO ("teammate")
# -------------------------------------------------------------------------
func _process_teammate(_delta: float, decision_ready: bool = true) -> void:
	if not ball_ref or not is_instance_valid(ball_ref):
		target_velocity = Vector3.ZERO
		return

	var my_pos: Vector3 = global_transform.origin
	var ball_pos: Vector3 = ball_ref.global_transform.origin
	var speed_mult: float = 0.8 if (enable_stamina_fatigue and is_exhausted) else 1.0

	# 1. Estado prioritario de desmarque y no-intercepción tras dar el pase a Ryu
	if unmark_timer > 0.0:
		has_ball = false
		is_dribbling = false
		var ryu = _find_ryu()
		if ryu:
			var ryu_pos = ryu.global_transform.origin
			var flank_x: float = 7.0 if ryu_pos.x <= 0.0 else -7.0
			var unmark_z: float = clamp(ryu_pos.z - 4.5, -25.0, 24.0)
			var target_pos = Vector3(flank_x, 0.8, unmark_z)

			# Mantener al menos 4.5 m de separación respecto a Ryu
			var diff_ryu = target_pos - ryu_pos
			diff_ryu.y = 0.0
			if diff_ryu.length() < 4.5:
				var away_dir = diff_ryu.normalized() if diff_ryu.length() > 0.01 else Vector3(1, 0, 0)
				target_pos = ryu_pos + away_dir * 4.8

			var to_target = target_pos - my_pos
			to_target.y = 0.0
			var dist = to_target.length()

			if dist > 0.4:
				target_facing = to_target.normalized()
				target_velocity = target_facing * move_speed * speed_mult
			else:
				target_velocity = Vector3.ZERO
				target_facing = Vector3(0, 0, -1)
		return

	# Detectar si un compañero o Ryu tiene el balón
	var carrier = _find_allied_ball_carrier()
	var carrier_is_player: bool = false
	if carrier != null:
		if carrier.is_in_group("player"):
			carrier_is_player = true
		elif "is_player_team" in carrier:
			carrier_is_player = carrier.is_player_team

	# Si Ryu u otro compañero tiene el balón, abrir líneas de pase con posicionamiento táctico
	if carrier != null and carrier != self and carrier_is_player == is_player_team:
		var target_pos = _get_tactical_home_pos(ball_pos) + _get_separation_vector(3.5)
		var to_target = target_pos - my_pos
		to_target.y = 0.0
		var dist_tac = to_target.length()
		if dist_tac > 0.3:
			target_facing = to_target.normalized()
			target_velocity = target_facing * move_speed * speed_mult
		else:
			target_velocity = Vector3.ZERO
			target_facing = Vector3(0, 0, -1)
		return

	if has_ball:
		# Conducir hacia la portería rival (Norte Z = -28.0)
		var target_goal = Vector3(0.0, 0.8, -28.0)
		var to_goal = target_goal - my_pos
		to_goal.y = 0.0
		target_facing = to_goal.normalized()
		target_velocity = target_facing * dribble_speed * speed_mult

		if decision_ready and my_pos.z <= -14.0 and kick_cooldown <= 0.0:
			var shot_target = Vector3(rand_range(-2.2, 2.2), 0.5, -28.2)
			var shot_dir = (shot_target - ball_pos).normalized()
			var shot_impulse = Vector3(shot_dir.x * 20.0, 1.2, shot_dir.z * 20.0)
			ball_ref.linear_velocity = shot_impulse
			ball_ref.apply_central_impulse(shot_impulse)
			has_ball = false
			is_dribbling = false
			kick_cooldown = 0.6
			possession_cooldown = 1.0
			print("[AI Teammate] ¡Compañero remata con potencia a portería rival!")
	else:
		# Sin balón: solo los 2 compañeros más cercanos van a presionar o buscar balón suelto
		var dist_ball = my_pos.distance_to(ball_pos)
		var is_presser = _is_among_closest_to_ball(2)

		if is_presser or dist_ball <= 3.5:
			var to_ball = ball_pos - my_pos
			to_ball.y = 0.0
			var dist = to_ball.length()

			if dist > 0.1:
				target_facing = to_ball.normalized()
				var chase_spd: float = move_speed if (enable_stamina_fatigue and is_exhausted) else sprint_speed
				target_velocity = target_facing * chase_spd * speed_mult
			else:
				target_velocity = Vector3.ZERO

			if dist <= 1.4 and ball_ref.linear_velocity.length() < 18.0 and possession_cooldown <= 0.0 and pass_to_player_cooldown <= 0.0:
				has_ball = true
				is_dribbling = true
				print("[AI Teammate] ¡Compañero aliado controla el balón!")
		else:
			# Mantener línea táctica y separación mínima de 3.5 m
			var target_pos = _get_tactical_home_pos(ball_pos) + _get_separation_vector(3.5)
			var to_tac = target_pos - my_pos
			to_tac.y = 0.0
			if to_tac.length() > 0.4:
				target_velocity = to_tac.normalized() * move_speed * speed_mult
				target_facing = target_velocity.normalized()
			else:
				target_velocity = Vector3.ZERO
				var to_b = ball_pos - my_pos
				to_b.y = 0.0
				if to_b.length() > 0.1:
					target_facing = to_b.normalized()

# -------------------------------------------------------------------------
# 4. PETICIÓN DE PASE DESDE RYU (Botón L1 / Q)
# -------------------------------------------------------------------------
func receive_pass_call(target_player: Node) -> void:
	_resolve_ball()
	if not ball_ref or not is_instance_valid(ball_ref):
		return

	var ball_pos = ball_ref.global_transform.origin
	var my_pos = global_transform.origin
	var dist_to_ball = my_pos.distance_to(ball_pos)

	if has_ball or is_dribbling or dist_to_ball <= 4.5:
		var player_lead = Vector3.ZERO
		if target_player:
			if "velocity" in target_player and target_player.velocity.length_squared() > 1.0:
				player_lead = target_player.velocity.normalized() * clamp(target_player.velocity.length() * 0.25, 0.8, 2.2)
			elif "facing_direction" in target_player and target_player.facing_direction.length_squared() > 0.01:
				player_lead = target_player.facing_direction.normalized() * 1.0

		var target_pos = (target_player.global_transform.origin + player_lead) if target_player else Vector3(0, 0, 3.5)
		var to_target = target_pos - ball_pos
		to_target.y = 0.0
		var dist = to_target.length()
		var pass_dir = to_target.normalized() if dist > 0.01 else -facing_direction
		var pass_speed = clamp(dist * 0.95 + 6.0, 10.0, 22.0)
		var pass_impulse = Vector3(pass_dir.x * pass_speed, 0.08, pass_dir.z * pass_speed)

		ball_ref.linear_velocity = pass_impulse
		ball_ref.apply_central_impulse(pass_impulse)
		if target_player and target_player.has_method("on_incoming_pass"):
			target_player.on_incoming_pass()
		has_ball = false
		is_dribbling = false
		pass_to_player_cooldown = 1.6
		unmark_timer = 2.2
		possession_cooldown = 2.2
		kick_cooldown = 0.5
		print("[AI Teammate] ¡Pase de compañero hacia Ryu ejecutado tras llamada con L (Q / L1)! Vel: %.1f | Desmarque activado" % pass_speed)

# -------------------------------------------------------------------------
# 5. MÉTODOS AUXILIARES
# -------------------------------------------------------------------------
func _get_tactical_home_pos(ball_pos: Vector3) -> Vector3:
	var base_pos = home_position if home_position != Vector3.ZERO else initial_position
	var shift_x: float = clamp(ball_pos.x * 0.45, -7.0, 7.0)
	var shift_z: float = clamp(ball_pos.z * 0.4, -14.0, 14.0)

	var tac = _get_team_tactic_index()
	if is_player_team:
		if tac == 1:
			shift_z -= 4.5
		elif tac == 2:
			shift_z += 4.5
	else:
		if formation_name in ["4-3-3", "5-2-3"]:
			shift_z += 3.5
		elif formation_name in ["5-3-2"]:
			shift_z -= 3.0

	var target = base_pos + Vector3(shift_x, 0.0, shift_z)
	target.x = clamp(target.x, -18.0, 18.0)
	target.z = clamp(target.z, -26.5, 26.5)
	target.y = 0.8
	return target

func _is_among_closest_to_ball(count: int = 2) -> bool:
	if not ball_ref or not is_instance_valid(ball_ref):
		return false
	var team_group = "teammates" if is_player_team else "opponents"
	var members = get_tree().get_nodes_in_group(team_group)
	var ball_pos = ball_ref.global_transform.origin
	var my_dist = global_transform.origin.distance_to(ball_pos)
	var closer_count = 0
	for m in members:
		if m == self or not (m is Spatial):
			continue
		if "role" in m and m.role == "goalkeeper":
			continue
		if "has_ball" in m and m.has_ball:
			continue
		var d = m.global_transform.origin.distance_to(ball_pos)
		if d < my_dist:
			closer_count += 1
			if closer_count >= count:
				return false
	return true

func _get_separation_vector(min_separation: float = 3.5) -> Vector3:
	var sep = Vector3.ZERO
	var team_group = "teammates" if is_player_team else "opponents"
	var allies = get_tree().get_nodes_in_group(team_group)
	var my_pos = global_transform.origin
	for ally in allies:
		if ally == self or not (ally is Spatial):
			continue
		var diff = my_pos - ally.global_transform.origin
		diff.y = 0.0
		var dist = diff.length()
		if dist < min_separation and dist > 0.001:
			sep += diff.normalized() * (min_separation - dist)
	return sep

func _get_team_tactic_index() -> int:
	var hud = _find_pitch_hud()
	if hud and "tactic_index" in hud:
		return hud.tactic_index
	return 0

func _find_pitch_hud() -> Node:
	var huds = get_tree().get_nodes_in_group("pitch_hud")
	if huds.size() > 0:
		return huds[0]
	return null

func _find_ryu() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _find_allied_ball_carrier() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "is_dribbling" in p and p.is_dribbling:
			return p
	var teammates = get_tree().get_nodes_in_group("teammates")
	for t in teammates:
		if t != self and "has_ball" in t and t.has_ball:
			return t
	return null
