extends Node

enum ControlScheme {
	FIFA_CLASSIC = 0,
	PES_ALTERNATIVE = 1
}

enum ControllerType {
	STANDARD_XBOX = 0,
	PLAYSTATION_4 = 1,
	PLAYSTATION_5 = 2
}

var current_control_scheme: int = ControlScheme.FIFA_CLASSIC
var _simulated_joy_name: String = ""

# Base de datos de mapeos SDL para mandos Sony DualShock 4 y DualSense en Windows
const SDL_PLAYSTATION_MAPPINGS = [
	# DualShock 4 USB v1 (054c:05c4)
	"030000004c050000c405000000000000,PS4 Controller,a:b1,b:b2,x:b0,y:b3,back:b8,start:b9,leftstick:b10,rightstick:b11,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a5,lefttrigger:a3,righttrigger:a4,platform:Windows,",
	# DualShock 4 USB v2 (054c:09cc)
	"030000004c050000cc09000000000000,PS4 Controller,a:b1,b:b2,x:b0,y:b3,back:b8,start:b9,leftstick:b10,rightstick:b11,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a5,lefttrigger:a3,righttrigger:a4,platform:Windows,",
	# DualShock 4 Bluetooth Windows ("Wireless Controller")
	"030000004c050000c405000011010000,PS4 Wireless Controller,a:b1,b:b2,x:b0,y:b3,back:b8,start:b9,leftstick:b10,rightstick:b11,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a5,lefttrigger:a3,righttrigger:a4,platform:Windows,",
	# DualSense PS5 USB (054c:0ce6)
	"030000004c050000e60c000000000000,PS5 Controller,a:b1,b:b2,x:b0,y:b3,back:b8,start:b9,leftstick:b10,rightstick:b11,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a5,lefttrigger:a3,righttrigger:a4,platform:Windows,",
	# DualSense Edge PS5 (054c:0df2)
	"030000004c050000f20d000000000000,PS5 DualSense Edge,a:b1,b:b2,x:b0,y:b3,back:b8,start:b9,leftstick:b10,rightstick:b11,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a5,lefttrigger:a3,righttrigger:a4,platform:Windows,"
]

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_register_sdl_mappings()
	Input.connect("joy_connection_changed", self, "_on_joy_connection_changed")
	update_controller_support(0)

func _register_sdl_mappings() -> void:
	for mapping in SDL_PLAYSTATION_MAPPINGS:
		Input.add_joy_mapping(mapping, true)

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		print("[GameSettings] Mando conectado en puerto %d: '%s'" % [device_id, Input.get_joy_name(device_id)])
	else:
		print("[GameSettings] Mando desconectado del puerto %d" % device_id)
	update_controller_support(device_id)

func set_control_scheme(scheme: int) -> void:
	current_control_scheme = scheme
	print("[GameSettings] Esquema de controles cambiado a: ", get_scheme_name())

func get_control_scheme() -> int:
	return current_control_scheme

func toggle_control_scheme() -> int:
	if current_control_scheme == ControlScheme.FIFA_CLASSIC:
		current_control_scheme = ControlScheme.PES_ALTERNATIVE
	else:
		current_control_scheme = ControlScheme.FIFA_CLASSIC
	print("[GameSettings] Esquema de controles alternado a: ", get_scheme_name())
	return current_control_scheme

func get_scheme_name() -> String:
	if current_control_scheme == ControlScheme.PES_ALTERNATIVE:
		return "Alternativo (PES / PPSSPP)"
	return "Clásico (FIFA)"

func get_scheme_short_name() -> String:
	if current_control_scheme == ControlScheme.PES_ALTERNATIVE:
		return "Alternativo (PES)"
	return "Clásico (FIFA)"

# --- Soporte y Detección de Mandos PlayStation (PS4 / PS5) en Windows ---

func set_simulated_joy_name(name_str: String) -> void:
	_simulated_joy_name = name_str
	update_controller_support(0)

func get_detected_joy_name(device_id: int = 0) -> String:
	if _simulated_joy_name != "":
		return _simulated_joy_name
	return Input.get_joy_name(device_id)

func is_playstation_controller(device_id: int = 0) -> bool:
	var joy_name = get_detected_joy_name(device_id).to_lower()
	if joy_name == "":
		return false
	# Descartar controladores explícitamente Xbox o XInput
	if "xbox" in joy_name or "xinput" in joy_name:
		return false
	# Patrones de identificación para DualShock 4 y DualSense (USB y Bluetooth en Windows)
	if "ps4" in joy_name or "ps5" in joy_name:
		return true
	if "dualshock" in joy_name or "dualsense" in joy_name:
		return true
	if "playstation" in joy_name or "sony" in joy_name:
		return true
	if "wireless controller" in joy_name:
		return true
	return false

func is_ps5_controller(device_id: int = 0) -> bool:
	var joy_name = get_detected_joy_name(device_id).to_lower()
	if not is_playstation_controller(device_id):
		return false
	return "ps5" in joy_name or "dualsense" in joy_name

func is_ps4_controller(device_id: int = 0) -> bool:
	if not is_playstation_controller(device_id):
		return false
	if is_ps5_controller(device_id):
		return false
	return true

func get_controller_type(device_id: int = 0) -> int:
	if is_ps5_controller(device_id):
		return ControllerType.PLAYSTATION_5
	elif is_ps4_controller(device_id):
		return ControllerType.PLAYSTATION_4
	elif is_playstation_controller(device_id):
		return ControllerType.PLAYSTATION_4
	return ControllerType.STANDARD_XBOX

# En Windows con DirectInput nativo para mandos PlayStation:
# Cuadrado (□) = Botón 0 (Izquierda física)
# Cruz (X)     = Botón 1 (Inferior físico)
# Círculo (O)  = Botón 2 (Derecha física)
# Triángulo (Δ)= Botón 3 (Superior físico)
#
# En controladores estándar / XInput:
# A (Inferior) = Botón 0
# B (Derecha)  = Botón 1
# X (Izquierda)= Botón 2
# Y (Superior) = Botón 3

func get_button_cross(device_id: int = 0) -> int:
	if is_playstation_controller(device_id):
		return JOY_BUTTON_1 # Posición física inferior (Cruz / X)
	return JOY_BUTTON_0 # Posición física inferior (A / Cruz en estándar)

func get_button_circle(device_id: int = 0) -> int:
	if is_playstation_controller(device_id):
		return JOY_BUTTON_2 # Posición física derecha (Círculo / O)
	return JOY_BUTTON_1 # Posición física derecha (B / Círculo en estándar)

func get_button_square(device_id: int = 0) -> int:
	if is_playstation_controller(device_id):
		return JOY_BUTTON_0 # Posición física izquierda (Cuadrado / □)
	return JOY_BUTTON_2 # Posición física izquierda (X / Cuadrado en estándar)

func get_button_triangle(device_id: int = 0) -> int:
	return JOY_BUTTON_3 # Posición física superior (Triángulo / Δ)

func update_controller_support(device_id: int = 0) -> void:
	var joy_name = get_detected_joy_name(device_id)
	var is_ps = is_playstation_controller(device_id)
	
	if is_ps:
		var ps_type_str = "DualSense (PS5)" if is_ps5_controller(device_id) else "DualShock 4 (PS4)"
		print("[GameSettings] Mando PlayStation detectado (%s: '%s'). Asignando posiciones físicas:" % [ps_type_str, joy_name])
		print("  -> Cruz=1 (Inf), Círculo=2 (Der), Cuadrado=0 (Izq), Triángulo=3 (Sup)")
	else:
		if joy_name != "":
			print("[GameSettings] Mando estándar detectado: '%s'." % joy_name)
	
	_remap_action_button("psp_cross", get_button_cross(device_id), device_id)
	_remap_action_button("psp_circle", get_button_circle(device_id), device_id)
	_remap_action_button("psp_square", get_button_square(device_id), device_id)
	_remap_action_button("psp_triangle", get_button_triangle(device_id), device_id)
	
	# Remapeo de UI para navegar menús con el mando: Cruz para Aceptar, Círculo para Cancelar
	_remap_action_button("ui_accept", get_button_cross(device_id), device_id)
	_remap_action_button("ui_cancel", get_button_circle(device_id), device_id)

func _remap_action_button(action_name: String, button_index: int, device_id: int = 0) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	
	# Remover únicamente los eventos de botón de joystick para este dispositivo
	var events = InputMap.get_action_list(action_name)
	for ev in events:
		if ev is InputEventJoypadButton and ev.device == device_id:
			InputMap.action_erase_event(action_name, ev)
	
	# Agregar el nuevo botón correspondiente a la posición física
	var new_event = InputEventJoypadButton.new()
	new_event.device = device_id
	new_event.button_index = button_index
	InputMap.action_add_event(action_name, new_event)
