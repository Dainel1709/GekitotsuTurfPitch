extends KinematicBody2D

class_name Fighter

# ---------------------------------------------------------------------------
# Señales
# ---------------------------------------------------------------------------
signal health_changed(new_health, max_health)
signal died()
signal defeated()
signal punched()

# ---------------------------------------------------------------------------
# Propiedades exportadas (editables desde el Inspector)
# ---------------------------------------------------------------------------
export(bool)   var is_player:        bool   = false setget set_is_player, get_is_player
export(bool)   var is_ai:            bool   = false
export(String) var fighter_name:     String = "Luchador"
export(float)  var max_health:       float  = 100.0
export(float)  var health:           float  = 100.0 setget set_health, get_health
export(float)  var speed:            float  = 190.0
export(float)  var attack_damage:    float  = 20.0  setget set_attack_damage, get_attack_damage
export(float)  var punch_damage:     float  = 20.0  setget set_punch_damage,  get_punch_damage
export(float)  var heavy_damage:     float  = 35.0  # Golpe fuerte (X / Círculo / S / Triángulo)
export(float)  var punch_range:      float  = 65.0
export(float)  var punch_cooldown:   float  = 0.45
export(float)  var heavy_cooldown:   float  = 0.80
export(float)  var dodge_speed:      float  = 380.0
export(float)  var dodge_duration:   float  = 0.18
export(float)  var block_dmg_factor: float  = 0.25  # Fracción de daño al bloquear
export(float)  var ai_punch_interval:float  = 1.2

# ---------------------------------------------------------------------------
# Estado interno (runtime)
# ---------------------------------------------------------------------------
var current_health:     float   = 100.0 setget set_health, get_health
var velocity:           Vector2 = Vector2.ZERO
var can_punch:          bool    = true
var is_dead:            bool    = false
var is_blocking:        bool    = false
var facing_direction:   int     = 1   # 1 = derecha, -1 = izquierda

var punch_cooldown_timer: float = 0.0
var heavy_cooldown_timer: float = 0.0
var dodge_timer:          float = 0.0
var dodge_direction:      int   = 0
var ai_timer:             float = 0.0
var punch_visual_timer:   float = 0.0

# Sin anotación de tipo Fighter para evitar error de cast en Godot 3.6
# cuando el nodo no ha cargado Fighter.gd antes de que se instancie
var opponent = null

# ---------------------------------------------------------------------------
# Referencias a nodos hijos (pueden no existir en algunas escenas de prueba)
# ---------------------------------------------------------------------------
onready var visual_root = $Visual      if has_node("Visual")      else null
onready var fist_visual = $Visual/Fist if has_node("Visual/Fist") else null
onready var body_rect   = $Visual/Body if has_node("Visual/Body") else null

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	current_health = max_health
	health         = max_health
	if fist_visual:
		fist_visual.visible = false
	emit_signal("health_changed", current_health, max_health)

# ---------------------------------------------------------------------------
# Setters / Getters
# ---------------------------------------------------------------------------
func set_is_player(val: bool) -> void:
	is_player = val
	is_ai     = not val

func get_is_player() -> bool:
	return is_player

func set_health(val: float) -> void:
	current_health = clamp(val, 0.0, max_health)
	health         = current_health
	emit_signal("health_changed", current_health, max_health)
	if current_health <= 0.0 and not is_dead:
		_die()

func get_health() -> float:
	return current_health

func set_attack_damage(val: float) -> void:
	attack_damage = val
	punch_damage  = val

func get_attack_damage() -> float:
	return attack_damage

func set_punch_damage(val: float) -> void:
	punch_damage  = val
	attack_damage = val

func get_punch_damage() -> float:
	return punch_damage

# ---------------------------------------------------------------------------
# _physics_process
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x  = 0.0
		velocity    = move_and_slide(velocity, Vector2.UP)
		return

	# Cooldowns
	if not can_punch:
		punch_cooldown_timer -= delta
		if punch_cooldown_timer <= 0.0:
			can_punch = true

	if heavy_cooldown_timer > 0.0:
		heavy_cooldown_timer -= delta

	# Visual de puño
	if punch_visual_timer > 0.0:
		punch_visual_timer -= delta
		if punch_visual_timer <= 0.0 and fist_visual:
			fist_visual.visible = false

	# Esquive activo
	if dodge_timer > 0.0:
		dodge_timer  -= delta
		velocity.x    = dodge_direction * dodge_speed
		velocity      = move_and_slide(velocity, Vector2.UP)
		return

	if is_ai:
		_process_ai(delta)
	else:
		_process_player_input(delta)

	velocity = move_and_slide(velocity, Vector2.UP)

# ---------------------------------------------------------------------------
# Entrada del jugador humano
# Controles exclusivos unificados con el sistema de fútbol:
#   Movimiento:   Flechas Izquierda/Derecha + cruceta/stick izquierdo
#   Golpe básico: A (Cuadrado) / Z (Cruz)
#   Golpe fuerte: X (Círculo) / S (Triángulo)
#   Guardia:      Q / L1 (psp_l / JOY_BUTTON_4)  — mantener presionado
#   Esquive:      W / R1 (psp_r / JOY_BUTTON_5)  — tap
# ---------------------------------------------------------------------------
func _process_player_input(_delta: float) -> void:
	# --- Leer GameSettings para PS4/PS5 ---
	var gs         = get_node_or_null("/root/GameSettings")
	var btn_square = JOY_BUTTON_2
	var btn_cross  = JOY_BUTTON_0
	var btn_circle = JOY_BUTTON_1
	var btn_tri    = JOY_BUTTON_3
	if gs:
		if gs.has_method("get_button_square"):   btn_square = gs.get_button_square(0)
		if gs.has_method("get_button_cross"):    btn_cross  = gs.get_button_cross(0)
		if gs.has_method("get_button_circle"):   btn_circle = gs.get_button_circle(0)
		if gs.has_method("get_button_triangle"): btn_tri    = gs.get_button_triangle(0)

	# --- 1. MOVIMIENTO: solo flechas + cruceta/stick (sin A/D) ---
	var move_x: float = 0.0

	if Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("psp_left") or Input.is_action_pressed("ui_left"):
		move_x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("psp_right") or Input.is_action_pressed("ui_right"):
		move_x += 1.0

	# Cruceta digital del mando
	if Input.is_joy_button_pressed(0, JOY_DPAD_LEFT):
		move_x = -1.0
	if Input.is_joy_button_pressed(0, JOY_DPAD_RIGHT):
		move_x = 1.0

	# Stick analógico izquierdo
	var joy_x: float = Input.get_joy_axis(0, JOY_AXIS_0)
	if abs(joy_x) > 0.25:
		move_x = sign(joy_x)

	velocity.x = move_x * speed
	if move_x != 0.0:
		_set_facing(int(sign(move_x)))

	# --- 2. GUARDIA / BLOQUEO: Q o L1 (psp_l / JOY_BUTTON_4) ---
	is_blocking = (
		Input.is_key_pressed(KEY_Q) or
		Input.is_action_pressed("psp_l") or
		Input.is_joy_button_pressed(0, JOY_BUTTON_4)
	)

	# --- 3. ESQUIVE / IMPULSO: W o R1 (psp_r / JOY_BUTTON_5) — tap ---
	var dodge_just: bool = (
		Input.is_key_pressed(KEY_W) or
		Input.is_action_just_pressed("psp_r") or
		Input.is_joy_button_pressed(0, JOY_BUTTON_5)
	)
	if dodge_just and dodge_timer <= 0.0 and not is_blocking:
		dodge_direction = facing_direction
		dodge_timer     = dodge_duration
		return  # El dodge consume este frame

	# --- 4. GOLPE BÁSICO: A (Cuadrado) o Z (Cruz) ---
	var basic_pressed: bool = (
		Input.is_key_pressed(KEY_A) or
		Input.is_key_pressed(KEY_Z) or
		Input.is_action_just_pressed("psp_square") or
		Input.is_action_just_pressed("psp_cross") or
		Input.is_joy_button_pressed(0, btn_square) or
		Input.is_joy_button_pressed(0, btn_cross)
	)
	if basic_pressed and can_punch:
		_execute_punch(attack_damage, punch_cooldown)

	# --- 5. GOLPE FUERTE: X (Círculo) o S (Triángulo) ---
	var heavy_pressed: bool = (
		Input.is_key_pressed(KEY_X) or
		Input.is_key_pressed(KEY_S) or
		Input.is_action_just_pressed("psp_circle") or
		Input.is_action_just_pressed("psp_triangle") or
		Input.is_joy_button_pressed(0, btn_circle) or
		Input.is_joy_button_pressed(0, btn_tri)
	)
	if heavy_pressed and heavy_cooldown_timer <= 0.0:
		_execute_punch(heavy_damage, heavy_cooldown)
		heavy_cooldown_timer = heavy_cooldown

# ---------------------------------------------------------------------------
# IA del rival
# ---------------------------------------------------------------------------
func _process_ai(delta: float) -> void:
	_resolve_opponent()
	if opponent == null or not is_instance_valid(opponent):
		velocity.x = 0.0
		return
	if opponent.is_dead:
		velocity.x = 0.0
		return

	var dist:            float = abs(opponent.global_position.x - global_position.x)
	var dir_to_opponent: float = sign(opponent.global_position.x - global_position.x)
	if dir_to_opponent != 0.0:
		_set_facing(int(dir_to_opponent))

	if dist > punch_range * 0.85:
		# Lejos: avanzar hacia el jugador
		velocity.x  = dir_to_opponent * speed
		ai_timer    = 0.0
	else:
		# Cerca: detenerse y golpear periódicamente
		velocity.x  = 0.0
		ai_timer   += delta
		if ai_timer >= ai_punch_interval:
			ai_timer = 0.0
			if can_punch:
				_execute_punch(attack_damage, punch_cooldown)

# ---------------------------------------------------------------------------
# Ejecutar golpe (básico o fuerte)
# ---------------------------------------------------------------------------
func _execute_punch(dmg: float, cooldown_time: float) -> void:
	can_punch            = false
	punch_cooldown_timer = cooldown_time
	punch_visual_timer   = 0.16
	if fist_visual:
		fist_visual.visible = true

	emit_signal("punched")
	print("[%s] ¡Lanza golpe (%.0f dmg)! Orientacion: %d" % [fighter_name, dmg, facing_direction])

	_resolve_opponent()
	if opponent == null or not is_instance_valid(opponent):
		return
	if opponent.is_dead:
		return

	var dist:        float = abs(opponent.global_position.x - global_position.x)
	var dir_to_opp:  float = sign(opponent.global_position.x - global_position.x)

	if dist <= punch_range and (dir_to_opp == 0.0 or int(dir_to_opp) == facing_direction):
		print("[%s] ¡Golpe conectado sobre %s!" % [fighter_name, opponent.fighter_name])
		opponent.take_damage(dmg)
		# Retroceso por impacto
		opponent.velocity.x += facing_direction * 140.0

# ---------------------------------------------------------------------------
# Recibir daño
# ---------------------------------------------------------------------------
func take_damage(amount: float) -> void:
	if is_dead:
		return

	var effective: float = amount
	if is_blocking:
		effective = amount * block_dmg_factor
		print("[%s] ¡Bloqueó! Daño reducido a %.1f" % [fighter_name, effective])

	current_health = max(0.0, current_health - effective)
	health         = current_health
	emit_signal("health_changed", current_health, max_health)

	# Flash visual de daño
	if body_rect and is_instance_valid(body_rect):
		var orig_color = body_rect.color
		body_rect.color = Color(1.0, 1.0, 1.0, 1.0)
		yield(get_tree().create_timer(0.08), "timeout")
		if body_rect and is_instance_valid(body_rect):
			body_rect.color = orig_color

	if current_health <= 0.0:
		_die()

# ---------------------------------------------------------------------------
# Muerte / derrota
# ---------------------------------------------------------------------------
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	emit_signal("defeated")
	emit_signal("died")
	print("[%s] ¡Ha sido noqueado / derrotado!" % fighter_name)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _set_facing(dir: int) -> void:
	if dir == 0:
		return
	facing_direction = dir
	if visual_root and is_instance_valid(visual_root):
		visual_root.scale.x = float(dir)

func _resolve_opponent() -> void:
	if opponent != null and is_instance_valid(opponent):
		return
	var fighters = get_tree().get_nodes_in_group("fighters")
	for f in fighters:
		if f != self and f.has_method("take_damage"):
			opponent = f
			break
