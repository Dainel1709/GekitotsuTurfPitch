extends KinematicBody

class_name Player

# Referencia a la clase backend de C++ (GDExtension)
var mechanics = null

# Variables de respaldo local (Fallback si la librería nativa no está cargada)
var fallback_base_speed: float = 10.0
var fallback_stamina: float = 100.0
var fallback_max_stamina: float = 100.0

var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
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
	# 1. Capturar el input 2D (Flechas direccionales o WASD)
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

	# Normalizar input diagonal para evitar mayor velocidad al desplazarse en diagonal
	if input_2d.length_squared() > 1.0:
		input_2d = input_2d.normalized()

	# 2. Transformar el input 2D en movimiento 3D restringido a los ejes X y Z (Y fija en 0)
	var move_direction := Vector3(input_2d.x, 0.0, input_2d.y)
	var is_moving: bool = move_direction.length_squared() > 0.001

	# 3. Conexión con el backend de C++ para drenar estamina real
	var current_speed: float = 0.0

	if mechanics:
		mechanics.set_moving(is_moving)
		mechanics.set_sprinting(is_sprinting)
		# Drenaje / regeneración de estamina en tiempo real gestionado por C++
		mechanics.update_stamina(delta)
		current_speed = mechanics.get_current_speed()
	else:
		# Lógica de respaldo local
		if is_moving:
			var drain: float = 35.0 if is_sprinting else 20.0
			fallback_stamina = max(0.0, fallback_stamina - drain * delta)
		else:
			fallback_stamina = min(fallback_max_stamina, fallback_stamina + 15.0 * delta)
		
		var fatigue: float = 0.4 if fallback_stamina <= 0.0 else 1.0
		var sprint_mult: float = 1.6 if (is_sprinting and fallback_stamina > 0.0) else 1.0
		current_speed = fallback_base_speed * sprint_mult * fatigue

	# Aplicar velocidad solo a X y Z (Y = 0)
	velocity.x = move_direction.x * current_speed
	velocity.y = 0.0
	velocity.z = move_direction.z * current_speed

	velocity = move_and_slide(velocity, Vector3.UP)

	# Rotar suavemente hacia la dirección de avance
	if is_moving:
		var target_pos: Vector3 = translation + move_direction
		target_pos.y = translation.y
		look_at(target_pos, Vector3.UP)

# Métodos públicos para consulta de estado (ej. desde UI o HUD de Liga)
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
