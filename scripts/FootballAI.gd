extends KinematicBody

class_name FootballAI

# Roles disponibles: "goalkeeper", "opponent", "teammate"
export(String, "goalkeeper", "opponent", "teammate") var role: String = "opponent"
export(bool) var is_player_team: bool = false
# Velocidades equilibradas y dinámicas
export(float) var move_speed: float = 7.4
export(float) var sprint_speed: float = 10.4
export(float) var dribble_speed: float = 7.0
export(float) var kick_reach: float = 1.6
# Estamina y IA
export(float) var stamina: float = 100.0
export(float) var max_stamina: float = 100.0
var is_exhausted: bool = false
var ai_decision_timer: float = 0.0
var separation_radius: float = 3.2

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

func reset_position() -> void:
	global_transform.origin = initial_position
	facing_direction = initial_facing
	target_facing = initial_facing
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

	# Estamina y agotamiento (drena al esprintar y recupera al trotar)
	var is_sprinting_now: bool = velocity.length() > move_speed + 0.5
	if not is_exhausted:
		if is_sprinting_now:
			stamina = max(0.0, stamina - 18.0 * delta)
		else:
			stamina = min(max_stamina, stamina + 12.0 * delta)
		if stamina <= 10.0:
			is_exhausted = true
	else:
		stamina = min(max_stamina, stamina + 12.0 * delta)
		if stamina >= 35.0:
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
		translation.z = clamp(translation.z, -23.8, 23.8)

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

	# Posición Z fija en la línea de gol
	var target_z: float = initial_position.z
	var diff_z: float = target_z - my_pos.z
	target_velocity.z = diff_z * 4.0
	target_velocity.y = 0.0

	# Detección de parada / despeje
	if decision_ready:
		var dist_to_ball: float = my_pos.distance_to(ball_pos)
		var in_save_area: bool = false
		if is_player_team:
			if ball_pos.z >= 19.6 and ball_pos.z <= 23.8 and abs(ball_pos.x) <= 4.2:
				in_save_area = true
		else:
			if ball_pos.z <= -19.6 and ball_pos.z >= -23.8 and abs(ball_pos.x) <= 4.2:
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
	var speed_mult: float = 0.75 if is_exhausted else 1.0

	# Detectar portador actual de forma segura
	var carrier = _find_allied_ball_carrier()
	var carrier_is_player: bool = false
	if carrier != null:
		if carrier.is_in_group("player"):
			carrier_is_player = true
		elif "is_player_team" in carrier:
			carrier_is_player = carrier.is_player_team

	# Si un compañero del mismo equipo ya tiene el balón, desmarcarse
	if carrier != null and carrier != self and carrier_is_player == is_player_team:
		var side_x: float = -7.5 if my_pos.x > 0 else 7.5
		var target_pos = Vector3(side_x, my_pos.y, my_pos.z)
		var to_target = target_pos - my_pos
		to_target.y = 0.0
		if to_target.length() > 0.2:
			target_facing = to_target.normalized()
			target_velocity = target_facing * move_speed * speed_mult
		else:
			target_velocity = Vector3.ZERO
		return

	if has_ball:
		# Conducir hacia la portería Sur
		var target_goal = Vector3(0.0, 0.8, 23.1)
		var to_goal = target_goal - my_pos
		to_goal.y = 0.0
		target_facing = to_goal.normalized()
		target_velocity = target_facing * dribble_speed * speed_mult

		if decision_ready and my_pos.z >= 4.0 and kick_cooldown <= 0.0:
			var shot_target = Vector3(rand_range(-2.5, 2.5), 0.5, 23.1)
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
		# Sin balón: buscar portador o balón libre
		var target_dest = ball_pos
		if carrier and is_instance_valid(carrier):
			target_dest = carrier.global_transform.origin

		var to_dest = target_dest - my_pos
		to_dest.y = 0.0
		var dist = to_dest.length()

		if dist > 0.1:
			target_facing = to_dest.normalized()
			target_velocity = target_facing * sprint_speed * speed_mult
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

# -------------------------------------------------------------------------
# 3. COMPORTAMIENTO DE COMPAÑERO ALIADO ("teammate")
# -------------------------------------------------------------------------
func _process_teammate(_delta: float, decision_ready: bool = true) -> void:
	if not ball_ref or not is_instance_valid(ball_ref):
		target_velocity = Vector3.ZERO
		return

	var my_pos: Vector3 = global_transform.origin
	var ball_pos: Vector3 = ball_ref.global_transform.origin
	var speed_mult: float = 0.75 if is_exhausted else 1.0

	# 1. Estado prioritario de desmarque y no-intercepción tras dar el pase a Ryu
	if unmark_timer > 0.0:
		has_ball = false
		is_dribbling = false
		var ryu = _find_ryu()
		if ryu:
			var ryu_pos = ryu.global_transform.origin
			var flank_x: float = 7.0 if ryu_pos.x <= 0.0 else -7.0
			var unmark_z: float = clamp(ryu_pos.z - 4.5, -19.6, 14.0)
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

	# Detectar portador actual de forma segura
	var carrier = _find_allied_ball_carrier()
	var carrier_is_player: bool = false
	if carrier != null:
		if carrier.is_in_group("player"):
			carrier_is_player = true
		elif "is_player_team" in carrier:
			carrier_is_player = carrier.is_player_team

	if carrier != null and carrier != self and carrier_is_player == is_player_team:
		var side_x: float = -7.5 if my_pos.x > 0 else 7.5
		var target_pos = Vector3(side_x, my_pos.y, my_pos.z)
		var to_target = target_pos - my_pos
		to_target.y = 0.0
		if to_target.length() > 0.2:
			target_facing = to_target.normalized()
			target_velocity = target_facing * move_speed * speed_mult
		else:
			target_velocity = Vector3.ZERO
		return

	if has_ball:
		# Conducir hacia la portería rival (Norte)
		var target_goal = Vector3(0.0, 0.8, -23.1)
		var to_goal = target_goal - my_pos
		to_goal.y = 0.0
		target_facing = to_goal.normalized()
		target_velocity = target_facing * dribble_speed * speed_mult

		if decision_ready and my_pos.z <= -4.0 and kick_cooldown <= 0.0:
			var shot_target = Vector3(rand_range(-2.2, 2.2), 0.5, -23.1)
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
		# Sin balón: desmarcarse o buscar balón suelto
		var ryu = _find_ryu()
		var ryu_has_ball = false
		if ryu and "is_dribbling" in ryu and ryu.is_dribbling:
			ryu_has_ball = true

		if ryu_has_ball:
			var ryu_pos = ryu.global_transform.origin
			var flank_x: float = 6.0 if ryu_pos.x <= 0.0 else -6.0
			var unmark_z: float = clamp(ryu_pos.z - 5.5, -19.6, 14.0)
			var target_pos = Vector3(flank_x, 0.8, unmark_z)

			var to_target = target_pos - my_pos
			to_target.y = 0.0
			var dist = to_target.length()

			if dist > 0.4:
				target_facing = to_target.normalized()
				target_velocity = target_facing * move_speed * speed_mult
			else:
				target_velocity = Vector3.ZERO
				target_facing = Vector3(0, 0, -1)
		else:
			var to_ball = ball_pos - my_pos
			to_ball.y = 0.0
			var dist_ball = to_ball.length()

			if dist_ball <= 12.0:
				target_facing = to_ball.normalized()
				target_velocity = target_facing * sprint_speed * speed_mult

				if dist_ball <= 1.4 and ball_ref.linear_velocity.length() < 18.0 and possession_cooldown <= 0.0 and pass_to_player_cooldown <= 0.0:
					has_ball = true
					is_dribbling = true
					print("[AI Teammate] ¡Compañero aliado controla el balón!")
			else:
				var tactic_pos = Vector3(clamp(ball_pos.x * 0.5, -7.0, 7.0), 0.8, clamp(ball_pos.z + 4.0, -6.0, 17.0))
				var to_tac = tactic_pos - my_pos
				to_tac.y = 0.0
				if to_tac.length() > 0.5:
					target_velocity = to_tac.normalized() * move_speed * speed_mult
					target_facing = target_velocity.normalized()
				else:
					target_velocity = Vector3.ZERO
					target_facing = Vector3(0, 0, -1)

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
