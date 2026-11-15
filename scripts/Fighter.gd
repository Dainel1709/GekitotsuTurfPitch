extends KinematicBody2D

class_name Fighter

signal health_changed(new_health, max_health)
signal died()
signal defeated()
signal punched()

export(bool) var is_player: bool = false setget set_is_player, get_is_player
export(bool) var is_ai: bool = false
export(String) var fighter_name: String = "Luchador"
export(float) var max_health: float = 100.0
export(float) var health: float = 100.0 setget set_health, get_health
export(float) var speed: float = 190.0
export(float) var attack_damage: float = 20.0 setget set_attack_damage, get_attack_damage
export(float) var punch_damage: float = 20.0 setget set_punch_damage, get_punch_damage
export(float) var punch_range: float = 65.0
export(float) var punch_cooldown: float = 0.45
export(float) var ai_punch_interval: float = 1.2

var current_health: float = 100.0 setget set_health, get_health
var velocity: Vector2 = Vector2.ZERO
var can_punch: bool = true
var is_dead: bool = false
var facing_direction: int = 1 # 1: derecha, -1: izquierda

var punch_cooldown_timer: float = 0.0
var ai_timer: float = 0.0
var punch_visual_timer: float = 0.0

var opponent: Fighter = null

onready var visual_root = $Visual
onready var fist_visual = $Visual/Fist
onready var body_rect = $Visual/Body

func _ready() -> void:
	current_health = max_health
	health = max_health
	if fist_visual:
		fist_visual.visible = false
	emit_signal("health_changed", current_health, max_health)

func set_is_player(val: bool) -> void:
	is_player = val
	is_ai = not val

func get_is_player() -> bool:
	return is_player

func set_health(val: float) -> void:
	current_health = clamp(val, 0.0, max_health)
	health = current_health
	emit_signal("health_changed", current_health, max_health)
	if current_health <= 0.0 and not is_dead:
		_die()

func get_health() -> float:
	return current_health

func set_attack_damage(val: float) -> void:
	attack_damage = val
	punch_damage = val

func get_attack_damage() -> float:
	return attack_damage

func set_punch_damage(val: float) -> void:
	punch_damage = val
	attack_damage = val

func get_punch_damage() -> float:
	return punch_damage

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = 0.0
		velocity = move_and_slide(velocity, Vector2.UP)
		return

	# Actualizar temporizador de cooldown de golpe
	if not can_punch:
		punch_cooldown_timer -= delta
		if punch_cooldown_timer <= 0.0:
			can_punch = true

	# Actualizar visual de golpe (puño extendido)
	if punch_visual_timer > 0.0:
		punch_visual_timer -= delta
		if punch_visual_timer <= 0.0 and fist_visual:
			fist_visual.visible = false

	if is_ai:
		_process_ai(delta)
	else:
		_process_player_input(delta)

	velocity = move_and_slide(velocity, Vector2.UP)

func _process_player_input(_delta: float) -> void:
	var move_x: float = 0.0

	# 1. Movimiento por Teclado (A/D y Flechas Izquierda/Derecha)
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("psp_left") or Input.is_action_pressed("ui_left"):
		move_x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("psp_right") or Input.is_action_pressed("ui_right"):
		move_x += 1.0

	# 2. Movimiento por Gamepad (Stick Analógico Izquierdo y Cruceta / D-Pad)
	var joy_x = Input.get_joy_axis(0, JOY_AXIS_0)
	if abs(joy_x) > 0.25:
		move_x = sign(joy_x)
	if Input.is_joy_button_pressed(0, JOY_DPAD_LEFT):
		move_x = -1.0
	if Input.is_joy_button_pressed(0, JOY_DPAD_RIGHT):
		move_x = 1.0

	velocity.x = move_x * speed

	if move_x != 0.0:
		_set_facing(int(sign(move_x)))

	# 3. Golpe Básico con Teclado (Espacio, J, Z, A, Enter) o Mando PS4/PS5/Xbox
	var gs = get_node_or_null("/root/GameSettings")
	var btn_square = gs.get_button_square(0) if (gs and gs.has_method("get_button_square")) else JOY_BUTTON_2
	var btn_cross = gs.get_button_cross(0) if (gs and gs.has_method("get_button_cross")) else JOY_BUTTON_0
	var btn_circle = gs.get_button_circle(0) if (gs and gs.has_method("get_button_circle")) else JOY_BUTTON_1

	var punch_pressed: bool = (
		Input.is_key_pressed(KEY_SPACE) or 
		Input.is_key_pressed(KEY_J) or 
		Input.is_key_pressed(KEY_Z) or 
		Input.is_key_pressed(KEY_A) or 
		Input.is_key_pressed(KEY_ENTER) or
		Input.is_action_just_pressed("ui_accept") or
		Input.is_action_just_pressed("psp_cross") or
		Input.is_action_just_pressed("psp_square") or
		Input.is_joy_button_pressed(0, btn_square) or
		Input.is_joy_button_pressed(0, btn_cross) or
		Input.is_joy_button_pressed(0, btn_circle) or
		Input.is_joy_button_pressed(0, JOY_BUTTON_0) or
		Input.is_joy_button_pressed(0, JOY_BUTTON_2)
	)

	if punch_pressed and can_punch:
		_execute_punch()

func _process_ai(delta: float) -> void:
	_resolve_opponent()
	if not opponent or opponent.is_dead:
		velocity.x = 0.0
		return

	var dist = abs(opponent.global_position.x - global_position.x)
	var dir_to_opponent = sign(opponent.global_position.x - global_position.x)
	if dir_to_opponent != 0:
		_set_facing(int(dir_to_opponent))

	# Si está fuera de rango de golpe, avanzar hacia el jugador
	if dist > punch_range * 0.85:
		velocity.x = dir_to_opponent * speed
		ai_timer = 0.0
	else:
		# Está cerca: detenerse y acumular tiempo hacia el golpe cada 1.2 segundos
		velocity.x = 0.0
		ai_timer += delta
		if ai_timer >= ai_punch_interval:
			ai_timer = 0.0
			if can_punch:
				_execute_punch()

func _execute_punch() -> void:
	can_punch = false
	punch_cooldown_timer = punch_cooldown
	punch_visual_timer = 0.16
	if fist_visual:
		fist_visual.visible = true

	emit_signal("punched")
	print("[%s] ¡Lanza golpe! Orientacion: %d" % [fighter_name, facing_direction])

	_resolve_opponent()
	if opponent and not opponent.is_dead:
		var dist = abs(opponent.global_position.x - global_position.x)
		var dir_to_opp = sign(opponent.global_position.x - global_position.x)
		
		# Conecta el golpe si está a distancia de puño y orientado hacia el rival
		if dist <= punch_range and (dir_to_opp == 0 or dir_to_opp == facing_direction):
			print("[%s] ¡Golpe conecto sobre %s!" % [fighter_name, opponent.fighter_name])
			opponent.take_damage(attack_damage)
			# Ligero retroceso por impacto
			opponent.velocity.x += facing_direction * 140.0

func take_damage(amount: float) -> void:
	if is_dead:
		return

	current_health = max(0.0, current_health - amount)
	health = current_health
	emit_signal("health_changed", current_health, max_health)

	# Efecto visual de parpadeo de daño
	if body_rect:
		var orig_color = body_rect.color
		body_rect.color = Color(1.0, 1.0, 1.0, 1.0) # Flash blanco/impacto
		yield(get_tree().create_timer(0.08), "timeout")
		if body_rect and is_instance_valid(body_rect):
			body_rect.color = orig_color

	if current_health <= 0.0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	emit_signal("defeated")
	emit_signal("died")
	print("[%s] ¡Ha sido noqueado / derrotado!" % fighter_name)

func _set_facing(dir: int) -> void:
	if dir == 0:
		return
	facing_direction = dir
	if visual_root:
		visual_root.scale.x = float(dir)

func _resolve_opponent() -> void:
	if opponent != null and is_instance_valid(opponent):
		return
	var fighters = get_tree().get_nodes_in_group("fighters")
	for f in fighters:
		if f != self and f is Fighter:
			opponent = f
			break
