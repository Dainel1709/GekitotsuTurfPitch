extends KinematicBody2D

class_name Fighter

# ---------------------------------------------------------------------------
# Señales
# ---------------------------------------------------------------------------
signal health_changed(new_health, max_health)
signal died()
signal defeated()
signal punched()
signal combo_updated(fighter, step_count, combo_text)
signal combo_broken()
signal shake_requested(intensity)
signal fury_changed(new_fury, max_fury)
signal special_attack_executed()

# ---------------------------------------------------------------------------
# Constantes de combate arcade
# ---------------------------------------------------------------------------
const COMBO_DATA = [
	{
		"name": "Jab",
		"damage": 8.0,
		"cooldown": 0.24,
		"knockback": 65.0,
		"advance": 18.0,
		"hitstun": 0.24,
		"hitstop": 0.03,
		"range_mult": 1.0
	},
	{
		"name": "Directo",
		"damage": 9.0,
		"cooldown": 0.25,
		"knockback": 70.0,
		"advance": 18.0,
		"hitstun": 0.24,
		"hitstop": 0.03,
		"range_mult": 1.0
	},
	{
		"name": "Gancho",
		"damage": 11.0,
		"cooldown": 0.26,
		"knockback": 75.0,
		"advance": 22.0,
		"hitstun": 0.24,
		"hitstop": 0.03,
		"range_mult": 1.0
	},
	{
		"name": "Patada media",
		"damage": 12.0,
		"cooldown": 0.27,
		"knockback": 80.0,
		"advance": 22.0,
		"hitstun": 0.24,
		"hitstop": 0.03,
		"range_mult": 1.0
	},
	{
		"name": "Codazo",
		"damage": 14.0,
		"cooldown": 0.28,
		"knockback": 85.0,
		"advance": 22.0,
		"hitstun": 0.24,
		"hitstop": 0.03,
		"range_mult": 1.0
	},
	{
		"name": "Remate final",
		"damage": 28.0,
		"cooldown": 0.40,
		"knockback": 430.0,
		"advance": 25.0,
		"hitstun": 0.40,
		"hitstop": 0.07,
		"range_mult": 1.45
	}
]

const HEAVY_ATTACK_DATA = {
	"name": "Golpe pesado",
	"damage": 26.0,
	"cooldown": 0.80,
	"knockback": 400.0,
	"advance": 15.0,
	"hitstun": 0.40,
	"hitstop": 0.07,
	"range_mult": 1.20
}

const AIR_ATTACK_DATA = {
	"name": "Ataque aereo",
	"damage": 20.0,
	"cooldown": 0.35,
	"knockback": 180.0,
	"advance": 0.0,
	"hitstun": 0.30,
	"hitstop": 0.055,
	"range_mult": 1.35
}

# ---------------------------------------------------------------------------
# Propiedades exportadas
# ---------------------------------------------------------------------------
export(bool)   var is_player:              bool   = false setget set_is_player, get_is_player
export(bool)   var is_ai:                  bool   = false
export(String) var fighter_name:           String = "Luchador"
export(float)  var max_health:             float  = 100.0
export(float)  var health:                 float  = 100.0 setget set_health, get_health
export(float)  var speed:                  float  = 220.0 setget set_speed, get_speed
export(float)  var move_speed:             float  = 220.0 setget set_speed, get_speed
export(float)  var attack_damage:          float  = 20.0  setget set_attack_damage, get_attack_damage
export(float)  var punch_damage:           float  = 20.0  setget set_punch_damage,  get_punch_damage
export(float)  var heavy_damage:           float  = 26.0
export(float)  var punch_range:            float  = 65.0
export(float)  var punch_cooldown:         float  = 0.45
export(float)  var heavy_cooldown:         float  = 0.80
export(float)  var dodge_speed:            float  = 320.0
export(float)  var dodge_duration:         float  = 0.18
export(float)  var block_dmg_factor:       float  = 0.25
export(float)  var ai_punch_interval:      float  = 1.2
# Combo
export(float)  var combo_window_duration:  float  = 0.55
# Física de salto
export(float)  var gravity:                float  = 1350.0
export(float)  var jump_force:             float  = -560.0
# IA: cooldown entre saltos de la IA
export(float)  var ai_jump_cooldown:       float  = 2.2

# ---------------------------------------------------------------------------
# Estado interno (runtime)
# ---------------------------------------------------------------------------
var current_health:       float   = 100.0 setget set_health, get_health
var velocity:             Vector2 = Vector2.ZERO
var can_punch:            bool    = true
var is_dead:              bool    = false
var is_blocking:          bool    = false
var facing_direction:     int     = 1   # 1 = derecha, -1 = izquierda

# Combo
var combo_step:           int     = 0
var max_combo_steps:      int     = 6
var combo_window_timer:   float   = 0.0

# RPG Stats desde GekitotsuStoryManager
var combat_stat:          int     = 0
var discipline_stat:      int     = 0
var damage_multiplier:    float   = 1.0
var fury_gain_mult:       float   = 1.0

# Furia y Ataque Especial
var fury:                 float   = 0.0 setget set_fury, get_fury
var max_fury:             float   = 100.0

# Hitstun / Blockstun / Hitstop / Knockback
var hitstun_timer:        float   = 0.0
var blockstun_timer:      float   = 0.0
var hitstop_timer:        float   = 0.0
var knockback_velocity:   Vector2 = Vector2.ZERO

# Ataque aéreo
var has_air_attacked:     bool    = false

var punch_cooldown_timer: float   = 0.0
var heavy_cooldown_timer: float   = 0.0
var dodge_timer:          float   = 0.0
var dodge_direction:      int     = 0
var ai_timer:             float   = 0.0
var ai_jump_timer:        float   = 0.0
var punch_visual_timer:   float   = 0.0

# Salto / suelo
var ground_y:             float   = 0.0   # Y del suelo guardada en _ready()
var is_jumping:           bool    = false # true mientras está en el aire

# Sin anotación de tipo Fighter (evita crash de cast en Godot 3.6)
var opponent = null

# Rastreo de excepción de colisión con el rival (cross-up)
var _collision_excepted:  bool    = false

# ---------------------------------------------------------------------------
# Referencias a nodos hijos (pueden no existir en escenas de prueba)
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
	ground_y       = global_position.y   # Guardar altura del suelo
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

func set_speed(val: float) -> void:
	speed      = val
	move_speed = val

func get_speed() -> float:
	return speed

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
	damage_multiplier = 1.0 + float(p_combat) * 0.015
	fury_gain_mult    = 1.0 + float(p_combat) * 0.015
	block_dmg_factor  = clamp(0.25 - float(p_discipline) * 0.003, 0.12, 0.25)
	print("[%s] RPG Stats C++ aplicados: Combate=%d (dmg x%.2f, furia x%.2f) | Disciplina=%d (bloqueo %.0f%% mit)" % [
		fighter_name, p_combat, damage_multiplier, fury_gain_mult, p_discipline, (1.0 - block_dmg_factor) * 100.0
	])

# ---------------------------------------------------------------------------
# _physics_process
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = 0.0
		velocity.y = 0.0
		velocity   = move_and_slide(velocity, Vector2.UP)
		return

	# --- Hitstop (micro-pausa de impacto): congela movimiento y temporizadores ---
	if hitstop_timer > 0.0:
		hitstop_timer -= delta
		return

	# --- Cooldowns de golpe y ventana de combo ---
	if not can_punch:
		punch_cooldown_timer -= delta
		if punch_cooldown_timer <= 0.0:
			can_punch = true

	if heavy_cooldown_timer > 0.0:
		heavy_cooldown_timer -= delta

	if combo_window_timer > 0.0:
		combo_window_timer -= delta
		if combo_window_timer <= 0.0:
			_reset_combo()

	# --- Visual de puño ---
	if punch_visual_timer > 0.0:
		punch_visual_timer -= delta
		if punch_visual_timer <= 0.0 and fist_visual:
			fist_visual.visible = false

	# --- Gravedad / Aterrizaje ---
	if not is_on_floor() and global_position.y < ground_y:
		velocity.y += gravity * delta
	else:
		if global_position.y >= ground_y:
			global_position.y = ground_y
			velocity.y = 0.0
		if is_jumping:
			is_jumping = false
			_on_landed()

	# --- Hitstun (aturdimiento por golpe) ---
	if hitstun_timer > 0.0:
		hitstun_timer -= delta
		knockback_velocity.x = lerp(knockback_velocity.x, 0.0, 10.0 * delta)
		velocity.x = knockback_velocity.x
		velocity = move_and_slide(velocity, Vector2.UP)
		global_position.x = clamp(global_position.x, 35.0, 989.0)
		return

	# --- Blockstun (retroceso por guardia) ---
	if blockstun_timer > 0.0:
		blockstun_timer -= delta
		knockback_velocity.x = lerp(knockback_velocity.x, 0.0, 12.0 * delta)
		velocity.x = knockback_velocity.x
		velocity = move_and_slide(velocity, Vector2.UP)
		global_position.x = clamp(global_position.x, 35.0, 989.0)
		return

	# --- Esquive activo (dodge) ---
	if dodge_timer > 0.0:
		dodge_timer -= delta
		velocity.x   = dodge_direction * dodge_speed
		velocity     = move_and_slide(velocity, Vector2.UP)
		global_position.x = clamp(global_position.x, 35.0, 989.0)
		_manage_crossup_collision(true)
		return
	else:
		_manage_crossup_collision(false)

	# --- Input o IA ---
	if is_ai:
		_process_ai(delta)
	else:
		_process_player_input(delta)

	# --- Aplicar movimiento y limitar dentro del área de la arena ---
	velocity = move_and_slide(velocity, Vector2.UP)
	global_position.x = clamp(global_position.x, 35.0, 989.0)

	# --- Habilitar traspaso si está en el aire (cross-up) ---
	_manage_crossup_collision(is_jumping)

	# --- Auto-giro en suelo: mirar hacia el rival ---
	if not is_jumping and not is_blocking:
		_auto_face_opponent()

# ---------------------------------------------------------------------------
# Entrada del jugador humano
# Controles exclusivos unificados:
#   Movimiento:   Flechas Izquierda/Derecha + cruceta/stick izquierdo
#   Salto:        Flecha Arriba + cruceta/stick arriba (KEY_UP / psp_up / joy_y < -0.5)
#   Golpe básico: A (Cuadrado) / Z (Cruz)
#   Golpe fuerte: X (Círculo) / S (Triángulo)
#   Guardia:      Q / L1 (psp_l / JOY_BUTTON_4)  — mantener
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

	# --- 1. MOVIMIENTO HORIZONTAL: solo flechas + cruceta/stick ---
	var move_x: float = 0.0

	if Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("psp_left") or Input.is_action_pressed("ui_left"):
		move_x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("psp_right") or Input.is_action_pressed("ui_right"):
		move_x += 1.0

	# Cruceta digital
	if Input.is_joy_button_pressed(0, JOY_DPAD_LEFT):
		move_x = -1.0
	if Input.is_joy_button_pressed(0, JOY_DPAD_RIGHT):
		move_x = 1.0

	# Stick analógico izquierdo — eje X
	var joy_x: float = Input.get_joy_axis(0, JOY_AXIS_0)
	if abs(joy_x) > 0.25:
		move_x = sign(joy_x)

	velocity.x = move_x * move_speed
	if move_x != 0.0:
		_set_facing(int(sign(move_x)))

	# --- 2. SALTO: Flecha Arriba / psp_up / Cruceta Arriba / Stick hacia arriba ---
	var jump_just: bool = (
		Input.is_key_pressed(KEY_UP) or
		Input.is_action_just_pressed("psp_up") or
		Input.is_action_just_pressed("ui_up") or
		Input.is_joy_button_pressed(0, JOY_DPAD_UP)
	)
	var joy_y: float = Input.get_joy_axis(0, JOY_AXIS_1)
	if joy_y < -0.5:
		jump_just = true

	if jump_just and not is_jumping and global_position.y >= ground_y - 4.0:
		velocity.y = jump_force
		is_jumping = true
		print("[%s] ¡Salta!" % fighter_name)

	# --- 3. GUARDIA / BLOQUEO: Q o L1 ---
	is_blocking = (
		Input.is_key_pressed(KEY_Q) or
		Input.is_action_pressed("psp_l") or
		Input.is_joy_button_pressed(0, JOY_BUTTON_4)
	)

	# --- 4. ESQUIVE: W o R1 — tap (solo en suelo) ---
	var dodge_just: bool = (
		Input.is_key_pressed(KEY_W) or
		Input.is_action_just_pressed("psp_r") or
		Input.is_joy_button_pressed(0, JOY_BUTTON_5)
	)
	if dodge_just and dodge_timer <= 0.0 and not is_blocking and not is_jumping:
		dodge_direction = facing_direction
		dodge_timer     = dodge_duration
		return

	# --- 5. DETECCIÓN DE BOTONES DE ATAQUE ---
	var basic_pressed: bool = (
		Input.is_key_pressed(KEY_A) or
		Input.is_key_pressed(KEY_Z) or
		Input.is_action_just_pressed("psp_square") or
		Input.is_action_just_pressed("psp_cross") or
		Input.is_joy_button_pressed(0, btn_square) or
		Input.is_joy_button_pressed(0, btn_cross)
	)

	var heavy_pressed: bool = (
		Input.is_key_pressed(KEY_X) or
		Input.is_key_pressed(KEY_S) or
		Input.is_action_just_pressed("psp_circle") or
		Input.is_action_just_pressed("psp_triangle") or
		Input.is_joy_button_pressed(0, btn_circle) or
		Input.is_joy_button_pressed(0, btn_tri)
	)

	# --- 6. GOLPE ESPECIAL ("Gekitotsu Breaker"): A+X / Z+S / Cuadrado+Círculo / Cruz+Triángulo ---
	var special_pressed: bool = (
		(basic_pressed and heavy_pressed) or
		(Input.is_key_pressed(KEY_A) and Input.is_key_pressed(KEY_X)) or
		(Input.is_key_pressed(KEY_Z) and Input.is_key_pressed(KEY_S)) or
		(Input.is_joy_button_pressed(0, btn_square) and Input.is_joy_button_pressed(0, btn_circle)) or
		(Input.is_joy_button_pressed(0, btn_cross) and Input.is_joy_button_pressed(0, btn_tri))
	)
	if special_pressed and fury >= 100.0 and not is_jumping and can_punch:
		_execute_special_attack()
		return

	# Golpe básico individual o encadenado
	if basic_pressed and can_punch:
		_on_basic_punch_input()

	# Golpe fuerte individual
	elif heavy_pressed and heavy_cooldown_timer <= 0.0:
		_on_heavy_punch_input()

# ---------------------------------------------------------------------------
# Lógica de inputs de ataque
# ---------------------------------------------------------------------------
func _on_basic_punch_input() -> void:
	if is_jumping:
		if not has_air_attacked:
			_execute_air_attack()
		return

	# En el suelo: encadenar combo
	if combo_step == 5:
		# Tras el 5.º golpe: activable con Golpe Básico -> Remate final
		_execute_combo_step(5)
	else:
		_execute_combo_step(combo_step)

func _on_heavy_punch_input() -> void:
	if is_jumping:
		if not has_air_attacked:
			_execute_air_attack()
		return

	# En el suelo:
	if combo_step == 5:
		# Tras el 5.º golpe: activable con Golpe Fuerte -> Remate final
		_execute_combo_step(5)
	else:
		# Fuera del paso 6: ejecuta directamente el golpe pesado individual
		_execute_heavy_attack()

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

	if ai_jump_timer > 0.0:
		ai_jump_timer -= delta

	var dist:            float = abs(opponent.global_position.x - global_position.x)
	var dir_to_opponent: float = sign(opponent.global_position.x - global_position.x)
	if dir_to_opponent != 0.0:
		_set_facing(int(dir_to_opponent))

	if dist > punch_range * 0.85:
		# Lejos: avanzar
		velocity.x = dir_to_opponent * move_speed
		ai_timer   = 0.0

		if ai_jump_timer <= 0.0 and not is_jumping and global_position.y >= ground_y - 4.0:
			if randf() < 0.15 * delta * 60.0:
				velocity.y    = jump_force
				is_jumping    = true
				ai_jump_timer = ai_jump_cooldown
				print("[%s IA] ¡Salta!" % fighter_name)
	else:
		# Cerca: detenerse y atacar
		velocity.x  = 0.0
		ai_timer   += delta
		if ai_timer >= ai_punch_interval:
			ai_timer = 0.0
			if can_punch:
				if is_jumping:
					if not has_air_attacked:
						_execute_air_attack()
				elif combo_step == 5:
					_execute_combo_step(5)
				elif randf() < 0.25 and combo_step == 0:
					_execute_heavy_attack()
				else:
					_execute_combo_step(combo_step)

# ---------------------------------------------------------------------------
# Ejecución de combo de 6 pasos en suelo
# ---------------------------------------------------------------------------
func _execute_combo_step(step_index: int) -> void:
	if step_index < 0 or step_index >= COMBO_DATA.size():
		step_index = 0

	var data   = COMBO_DATA[step_index]
	var dmg:    float = data["damage"] * damage_multiplier
	var cd:     float = data["cooldown"]
	var kb:     float = data["knockback"]
	var adv:    float = data["advance"]
	var stun:   float = data["hitstun"]
	var stop:   float = data["hitstop"]
	var r_mult: float = data["range_mult"]
	var hit_num: int   = step_index + 1

	can_punch            = false
	punch_cooldown_timer = cd
	punch_visual_timer   = 0.16
	if fist_visual:
		fist_visual.visible = true

	emit_signal("punched")
	_apply_micro_advance(adv)

	print("[%s] Lanza combo %d: %s (%.0f dmg) | Orientacion: %d" % [fighter_name, hit_num, data["name"], dmg, facing_direction])

	_resolve_opponent()
	if opponent == null or not is_instance_valid(opponent) or opponent.is_dead:
		_reset_combo()
		return

	var dist:       float = abs(opponent.global_position.x - global_position.x)
	var dir_to_opp: float = sign(opponent.global_position.x - global_position.x)
	var eff_range:  float = punch_range * r_mult

	if dist <= eff_range and (dir_to_opp == 0.0 or int(dir_to_opp) == facing_direction):
		# ¡Golpe conectado!
		print("[%s] ¡Golpe %d conectado sobre %s!" % [fighter_name, hit_num, opponent.fighter_name])
		opponent.take_damage(dmg, kb, stun, facing_direction)

		# Cargar Furia: más en combos altos y escalado por Combate
		var base_fury: float = 8.0 + float(step_index) * 2.5
		if hit_num == 6:
			base_fury = 25.0
		add_fury(base_fury * fury_gain_mult)

		# Hitstop aplicado al atacante y receptor
		hitstop_timer = stop
		if opponent and is_instance_valid(opponent):
			opponent.hitstop_timer = stop

		# Sacudida de cámara
		var shake = 7.0 if hit_num == 6 else 2.5
		emit_signal("shake_requested", shake)

		# Actualizar contador progresivo de combo
		if hit_num == max_combo_steps:
			var combo_str = get_combo_text(6)
			emit_signal("combo_updated", self, 6, combo_str)
			# Remate final completa el combo: se reinicia la cadena
			combo_step         = 0
			combo_window_timer = 0.0
		else:
			combo_step         = hit_num
			combo_window_timer = combo_window_duration
			var combo_str = get_combo_text(combo_step)
			emit_signal("combo_updated", self, combo_step, combo_str)
	else:
		# Whiff al aire: reinicio de combo
		print("[%s] ¡Whiff! Golpe %d falló al aire." % [fighter_name, hit_num])
		_reset_combo()

# ---------------------------------------------------------------------------
# Golpe pesado individual (fuera del paso 6)
# ---------------------------------------------------------------------------
func _execute_heavy_attack() -> void:
	var data   = HEAVY_ATTACK_DATA
	var dmg:    float = data["damage"] * damage_multiplier
	var cd:     float = data["cooldown"]
	var kb:     float = data["knockback"]
	var adv:    float = data["advance"]
	var stun:   float = data["hitstun"]
	var stop:   float = data["hitstop"]
	var r_mult: float = data["range_mult"]

	can_punch            = false
	punch_cooldown_timer = cd
	heavy_cooldown_timer = cd
	punch_visual_timer   = 0.20
	if fist_visual:
		fist_visual.visible = true

	emit_signal("punched")
	_apply_micro_advance(adv)
	_reset_combo()

	print("[%s] ¡Lanza Golpe Pesado individual (%.0f dmg)!" % [fighter_name, dmg])

	_resolve_opponent()
	if opponent == null or not is_instance_valid(opponent) or opponent.is_dead:
		return

	var dist:       float = abs(opponent.global_position.x - global_position.x)
	var dir_to_opp: float = sign(opponent.global_position.x - global_position.x)
	var eff_range:  float = punch_range * r_mult

	if dist <= eff_range and (dir_to_opp == 0.0 or int(dir_to_opp) == facing_direction):
		print("[%s] ¡Golpe Pesado conectado sobre %s!" % [fighter_name, opponent.fighter_name])
		opponent.take_damage(dmg, kb, stun, facing_direction)
		add_fury(20.0 * fury_gain_mult)
		hitstop_timer = stop
		if opponent and is_instance_valid(opponent):
			opponent.hitstop_timer = stop
		emit_signal("shake_requested", 6.5)
	else:
		print("[%s] ¡Golpe Pesado falló al aire!" % fighter_name)

# ---------------------------------------------------------------------------
# Ataque aéreo diagonal hacia abajo-adelante
# ---------------------------------------------------------------------------
func _execute_air_attack() -> void:
	var data   = AIR_ATTACK_DATA
	var dmg:    float = data["damage"] * damage_multiplier
	var cd:     float = data["cooldown"]
	var kb:     float = data["knockback"]
	var stun:   float = data["hitstun"]
	var stop:   float = data["hitstop"]
	var r_mult: float = data["range_mult"]

	has_air_attacked     = true
	can_punch            = false
	punch_cooldown_timer = cd
	punch_visual_timer   = 0.22
	if fist_visual:
		fist_visual.visible = true

	emit_signal("punched")

	# Impulso diagonal hacia abajo-adelante
	velocity.x = facing_direction * 150.0
	velocity.y = max(velocity.y, 80.0) + 120.0

	print("[%s] ¡Lanza ataque aéreo diagonal (%.0f dmg)!" % [fighter_name, dmg])

	_resolve_opponent()
	if opponent == null or not is_instance_valid(opponent) or opponent.is_dead:
		return

	var dist:       float = abs(opponent.global_position.x - global_position.x)
	var dir_to_opp: float = sign(opponent.global_position.x - global_position.x)
	var eff_range:  float = punch_range * r_mult

	if dist <= eff_range and (dir_to_opp == 0.0 or int(dir_to_opp) == facing_direction):
		print("[%s] ¡Ataque aéreo impactó sobre %s!" % [fighter_name, opponent.fighter_name])
		opponent.take_damage(dmg, kb, stun, facing_direction)
		add_fury(15.0 * fury_gain_mult)
		hitstop_timer = stop
		if opponent and is_instance_valid(opponent):
			opponent.hitstop_timer = stop
		emit_signal("shake_requested", 4.5)
	else:
		print("[%s] Ataque aéreo falló al aire." % fighter_name)

# ---------------------------------------------------------------------------
# Golpe Especial ("Gekitotsu Breaker" — Furia 100%)
# ---------------------------------------------------------------------------
func _execute_special_attack() -> void:
	fury = 0.0
	emit_signal("fury_changed", fury, max_fury)
	emit_signal("special_attack_executed")
	emit_signal("punched")

	can_punch            = false
	punch_cooldown_timer = 0.55
	punch_visual_timer   = 0.30
	_reset_combo()

	if fist_visual:
		fist_visual.visible = true

	_apply_micro_advance(30.0)
	_flash_color(Color(1.0, 0.75, 0.1, 1.0), 0.15)

	var base_special_dmg: float = 55.0
	var dmg:              float = base_special_dmg * damage_multiplier
	var kb:               float = 520.0
	var stun:             float = 0.45
	var stop:             float = 0.09
	var eff_range:        float = punch_range * 1.6

	print("[%s] ¡¡¡GEKITOTSU BREAKER (GOLPE ESPECIAL)!!! Daño: %.1f | Furia consumida" % [fighter_name, dmg])

	_resolve_opponent()
	if opponent == null or not is_instance_valid(opponent) or opponent.is_dead:
		return

	var dist:       float = abs(opponent.global_position.x - global_position.x)
	var dir_to_opp: float = sign(opponent.global_position.x - global_position.x)

	if dist <= eff_range and (dir_to_opp == 0.0 or int(dir_to_opp) == facing_direction):
		print("[%s] ¡¡¡GEKITOTSU BREAKER IMPACTÓ SOBRE %s!!!" % [fighter_name, opponent.fighter_name])
		opponent.take_damage(dmg, kb, stun, facing_direction)
		hitstop_timer = stop
		if opponent and is_instance_valid(opponent):
			opponent.hitstop_timer = stop
		emit_signal("shake_requested", 12.0)
	else:
		print("[%s] Gekitotsu Breaker falló al aire." % fighter_name)

# ---------------------------------------------------------------------------
# Método retrocompatible de golpe
# ---------------------------------------------------------------------------
func _execute_punch(dmg: float = 20.0, cooldown_time: float = 0.45) -> void:
	if is_jumping and not has_air_attacked:
		_execute_air_attack()
	elif combo_step == 5:
		_execute_combo_step(5)
	elif dmg >= 25.0:
		_execute_heavy_attack()
	else:
		_execute_combo_step(combo_step)

# ---------------------------------------------------------------------------
# Micro-avance del atacante
# ---------------------------------------------------------------------------
func _apply_micro_advance(amount: float) -> void:
	if amount <= 0.0:
		return
	if opponent and is_instance_valid(opponent) and not is_jumping and dodge_timer <= 0.0:
		var dir_to_opp = sign(opponent.global_position.x - global_position.x)
		if dir_to_opp != 0.0 and int(dir_to_opp) == facing_direction:
			var cur_dist = abs(opponent.global_position.x - global_position.x)
			# Evitar sobrepasar al oponente en suelo si ya están en contacto (~36 px)
			var max_advance = max(0.0, cur_dist - 36.0)
			amount = min(amount, max_advance)
	global_position.x += facing_direction * amount
	global_position.x = clamp(global_position.x, 35.0, 989.0)

# ---------------------------------------------------------------------------
# Formateador de texto de combo
# ---------------------------------------------------------------------------
func get_combo_text(step: int) -> String:
	match step:
		1: return "1-HIT"
		2: return "2-HIT"
		3: return "3-HIT"
		4: return "4-HIT"
		5: return "5-HIT"
		6: return "6-HIT COMBO!"
		_: return "%d-HIT" % step

# ---------------------------------------------------------------------------
# Reinicio de combo por whiff, expiración o interrupción
# ---------------------------------------------------------------------------
func _reset_combo() -> void:
	if combo_step > 0:
		emit_signal("combo_broken")
	combo_step         = 0
	combo_window_timer = 0.0

# ---------------------------------------------------------------------------
# Recibir daño
# ---------------------------------------------------------------------------
func take_damage(amount: float, knockback: float = 0.0, hitstun: float = 0.24, attacker_facing: int = 0) -> void:
	if is_dead:
		return

	var push_dir: int = attacker_facing
	if push_dir == 0:
		if opponent and is_instance_valid(opponent):
			push_dir = int(sign(global_position.x - opponent.global_position.x))
		if push_dir == 0:
			push_dir = -facing_direction

	if is_blocking:
		var effective: float = amount * block_dmg_factor
		current_health = max(0.0, current_health - effective)
		health         = current_health
		emit_signal("health_changed", current_health, max_health)

		# Cargar un poco de furia al bloquear
		add_fury(5.0 * fury_gain_mult)

		# Guardia: blockstun breve (0.10s) y retroceso corto (85 px/s) sin abrir la guardia
		blockstun_timer      = 0.10
		knockback_velocity.x = float(push_dir) * 85.0
		_flash_color(Color(0.6, 0.85, 1.0, 1.0), 0.06)
		print("[%s] ¡Bloqueó! Daño reducido a %.1f, blockstun 0.10s, retroceso 85 px/s" % [fighter_name, effective])

		if current_health <= 0.0:
			_die()
		return

	# Sin guardia:
	var effective: float = amount
	current_health = max(0.0, current_health - effective)
	health         = current_health
	emit_signal("health_changed", current_health, max_health)

	# Interrumpir cualquier ataque o combo activo
	_reset_combo()
	can_punch = true

	# Hitstun mitigado por Disciplina y knockback amortiguado
	var eff_hitstun: float = hitstun * clamp(1.0 - float(discipline_stat) * 0.005, 0.65, 1.0)
	hitstun_timer        = eff_hitstun
	knockback_velocity.x = float(push_dir) * knockback

	# Destello de impacto
	_flash_color(Color(1.0, 1.0, 1.0, 1.0), 0.08)

	print("[%s] Recibió %.1f daño. Hitstun: %.2fs (base: %.2fs), Knockback: %.1f px/s" % [fighter_name, effective, eff_hitstun, hitstun, knockback])

	if current_health <= 0.0:
		_die()

# ---------------------------------------------------------------------------
# Flash visual de impacto / bloqueo
# ---------------------------------------------------------------------------
func _flash_color(col: Color, duration: float) -> void:
	if body_rect and is_instance_valid(body_rect):
		var orig_color = body_rect.color
		body_rect.color = col
		if get_tree():
			yield(get_tree().create_timer(duration), "timeout")
			if body_rect and is_instance_valid(body_rect):
				body_rect.color = orig_color

# ---------------------------------------------------------------------------
# Muerte / derrota
# ---------------------------------------------------------------------------
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_manage_crossup_collision(false)
	emit_signal("defeated")
	emit_signal("died")
	print("[%s] ¡Ha sido noqueado / derrotado!" % fighter_name)

# ---------------------------------------------------------------------------
# Callback al aterrizar
# ---------------------------------------------------------------------------
func _on_landed() -> void:
	has_air_attacked = false
	_manage_crossup_collision(false)
	print("[%s] Aterrizó." % fighter_name)

# ---------------------------------------------------------------------------
# Cross-up: habilitar/deshabilitar colisión con el rival
# ---------------------------------------------------------------------------
func _manage_crossup_collision(allow_pass: bool) -> void:
	if opponent == null or not is_instance_valid(opponent):
		_collision_excepted = false
		return

	if allow_pass and not _collision_excepted:
		add_collision_exception_with(opponent)
		_collision_excepted = true
	elif not allow_pass and _collision_excepted:
		var overlap: float = abs(global_position.x - opponent.global_position.x)
		if overlap > 42.0:
			remove_collision_exception_with(opponent)
			_collision_excepted = false

# ---------------------------------------------------------------------------
# Auto-giro en suelo: siempre mirar hacia el rival
# ---------------------------------------------------------------------------
func _auto_face_opponent() -> void:
	if opponent == null or not is_instance_valid(opponent):
		return
	var dir: float = sign(opponent.global_position.x - global_position.x)
	if dir != 0.0:
		_set_facing(int(dir))

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
