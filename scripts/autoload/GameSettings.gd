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

const SAVE_PATH: String = "user://savegame.json"

# --- Estado Narrativo del Árbol de Decisiones ---
# Fases posibles: "CREATE_PLAYER", "PROLOGUE_HIT", "SELECT_ACADEMY", "LEAGUE",
#   "MID_J4_OFFER", "AMBUSH_J6_BRAWL", "POST_J8_CHOICE", "FINAL_BRAWL", "ENDING"
var story_phase: String = "LEAGUE"
var ending_id: String = ""
var red_cards_total: int = 0
var player_name: String = "Ryu"
var academy_name: String = "Estudiantes de Mérida"
var goals_scored: int = 0
var assists: int = 0

# Ending IDs válidos
const VALID_ENDINGS = [
	"EXPELLED_EARLY",
	"PRO_FIGHTER_EARLY",
	"HOSPITAL_DREAM_BAD",
	"PRO_FIGHTER_J8",
	"GOLDEN_BOY_CHAMPION",
	"LEAGUE_CHAMPION",
	"PRO_RUNNER_UP",
	"RELEASED_BAD"
]

const VALID_PHASES = [
	"CREATE_PLAYER",
	"PROLOGUE_HIT",
	"SELECT_ACADEMY",
	"LEAGUE",
	"MID_J4_OFFER",
	"AMBUSH_J6_BRAWL",
	"POST_J8_CHOICE",
	"FINAL_BRAWL",
	"ENDING"
]

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_register_sdl_mappings()
	Input.connect("joy_connection_changed", self, "_on_joy_connection_changed")
	update_controller_support(0)
	load_progress()

# --- Persistencia y Guardado de Ciclo de Liga (user://savegame.json) ---

func has_save() -> bool:
	var f = File.new()
	return f.file_exists(SAVE_PATH)

func get_default_save_data() -> Dictionary:
	return {
		"matchday": 1,
		"league_wins": 0,
		"league_losses": 0,
		"discipline": 0,
		"combat": 0,
		"money": 0,
		"reputation": 0,
		"control_scheme": current_control_scheme,
		"story_phase": "LEAGUE",
		"ending_id": "",
		"red_cards_total": 0,
		"player_name": "Ryu",
		"academy_name": "Estudiantes de Mérida",
		"goals_scored": 0,
		"assists": 0
	}

func _read_save_dict() -> Dictionary:
	var data: Dictionary = get_default_save_data()
	var f = File.new()
	if not f.file_exists(SAVE_PATH):
		return data
	var err = f.open(SAVE_PATH, File.READ)
	if err != OK:
		return data
	var json_str = f.get_as_text()
	f.close()
	var parse_res = JSON.parse(json_str)
	if parse_res.error == OK and typeof(parse_res.result) == TYPE_DICTIONARY:
		for k in parse_res.result.keys():
			data[k] = parse_res.result[k]
	return data

func load_progress() -> Dictionary:
	var data: Dictionary = _read_save_dict()
	if data.has("control_scheme"):
		current_control_scheme = int(data["control_scheme"])
	# Sincronizar variables narrativas desde el guardado
	if data.has("story_phase"):
		story_phase = str(data["story_phase"])
	if data.has("ending_id"):
		ending_id = str(data["ending_id"])
	if data.has("red_cards_total"):
		red_cards_total = int(data["red_cards_total"])
	if data.has("player_name"):
		player_name = str(data["player_name"])
	if data.has("academy_name"):
		academy_name = str(data["academy_name"])
	if data.has("goals_scored"):
		goals_scored = int(data["goals_scored"])
	if data.has("assists"):
		assists = int(data["assists"])
	return data

func save_progress(new_fields: Dictionary = {}) -> bool:
	var data: Dictionary = _read_save_dict()
	for k in new_fields.keys():
		data[k] = new_fields[k]
	if not data.has("control_scheme"):
		data["control_scheme"] = current_control_scheme
	# Siempre persistir el estado narrativo actual
	data["story_phase"] = story_phase
	data["ending_id"] = ending_id
	data["red_cards_total"] = red_cards_total
	data["player_name"] = player_name
	data["academy_name"] = academy_name
	data["goals_scored"] = goals_scored
	data["assists"] = assists
	
	var f = File.new()
	var err = f.open(SAVE_PATH, File.WRITE)
	if err != OK:
		push_error("[GameSettings] Error al abrir %s para escritura: %d" % [SAVE_PATH, err])
		return false
	f.store_string(JSON.print(data, "\t"))
	f.close()
	print("[GameSettings] Progreso de liga guardado exitosamente: Jornada %d | %d V / %d D" % [
		data.get("matchday", 1), data.get("league_wins", 0), data.get("league_losses", 0)
	])
	return true

func reset_save() -> void:
	var dir = Directory.new()
	if dir.file_exists(SAVE_PATH):
		dir.remove(SAVE_PATH)
	story_phase = "LEAGUE"
	ending_id = ""
	red_cards_total = 0
	player_name = "Ryu"
	academy_name = "Estudiantes de Mérida"
	goals_scored = 0
	assists = 0
	print("[GameSettings] Archivo de guardado reiniciado.")

# --- Utilidades Narrativas ---

func set_story_ending(phase: String, end_id: String) -> void:
	story_phase = phase
	ending_id = end_id
	save_progress({})
	print("[GameSettings] Fase narrativa: %s | Final: %s" % [phase, end_id])

func get_ending_title(end_id: String) -> String:
	match end_id:
		"EXPELLED_EARLY":
			return "Final Malo Temprano: Expulsado por Indisciplina"
		"PRO_FIGHTER_EARLY":
			return "Final Alternativo Temprano: Peleador Profesional (J4)"
		"HOSPITAL_DREAM_BAD":
			return "Final Trágico: Hospital — Todo Fue un Sueño"
		"PRO_FIGHTER_J8":
			return "Final Alternativo: Peleador Profesional (J8)"
		"GOLDEN_BOY_CHAMPION":
			return "Final Supremo: Golden Boy Campeón"
		"LEAGUE_CHAMPION":
			return "Final Bueno: Campeón de Liga"
		"PRO_RUNNER_UP":
			return "Final Bueno: Subcampeón y Ascenso"
		"RELEASED_BAD":
			return "Final Malo: Liberado del Club"
		_:
			return "Final Desconocido"

func get_ending_description(end_id: String) -> String:
	match end_id:
		"EXPELLED_EARLY":
			return "%s ha sido expulsado de la cantera de %s por indisciplina reiterada. Las tarjetas rojas y la falta de disciplina deportiva han truncado su carrera antes de completar la temporada. El sueño del fútbol profesional se desvanece en el asfalto." % [player_name, academy_name]
		"PRO_FIGHTER_EARLY":
			return "Tras el 4.º partido, un promotor de peleas clandestinas ofreció a %s un contrato como peleador profesional. Con una técnica de combate excepcional, %s decide abandonar el fútbol y dedicarse al mundo de las peleas. La cantera pierde un talento, pero el ring gana una estrella." % [player_name, player_name]
		"HOSPITAL_DREAM_BAD":
			return "%s recibe un golpe brutal en la cabeza durante una emboscada nocturna. Despierta en una cama de hospital, desorientado y sin poder sentir sus piernas. Los médicos le explican que todo lo que vivió — la cantera, los partidos, las peleas — podría haber sido un sueño febril. El final más oscuro." % [player_name]
		"PRO_FIGHTER_J8":
			return "Tras completar las 8 jornadas, %s elige enfrentar la emboscada final. Con una técnica de combate de élite (≥25), gana la pelea y decide dedicar su vida al combate profesional en vez del fútbol. Un camino distinto, pero igualmente glorioso." % [player_name]
		"GOLDEN_BOY_CHAMPION":
			return "¡%s lo ha logrado todo! Campeón de liga, máximo goleador, líder en asistencias y ascenso directo al primer equipo de %s. La prensa lo llama el Golden Boy. Una leyenda nace en la cantera." % [player_name, academy_name]
		"LEAGUE_CHAMPION":
			return "¡%s levanta la Copa de la Liga con %s! Primer puesto en la temporada y ascenso profesional al primer equipo. Un canterano que cumplió su sueño." % [player_name, academy_name]
		"PRO_RUNNER_UP":
			return "%s termina la temporada como subcampeón con %s. Un excelente rendimiento que le vale el ascenso profesional al primer equipo. El camino continúa." % [player_name, academy_name]
		"RELEASED_BAD":
			return "%s completa las 8 jornadas pero queda en 3.º lugar o inferior. %s decide no renovar su contrato. El sueño de la cantera se apaga, pero la calle siempre espera." % [player_name, academy_name]
		_:
			return "Desenlace no reconocido."

func evaluate_j8_ending() -> String:
	var gs_data = load_progress()
	var wins = int(gs_data.get("league_wins", 0))
	var losses = int(gs_data.get("league_losses", 0))
	var draws = 8 - wins - losses
	var points = wins * 3 + draws
	var combat = int(gs_data.get("combat", 0))
	var total_ga = goals_scored + assists

	# Determinar posición en liga (simplificado: >18 pts = 1.º, >12 pts = 2.º, resto = 3.º+)
	var league_position = 3
	if points >= 18:
		league_position = 1
	elif points >= 12:
		league_position = 2

	# GOLDEN_BOY_CHAMPION: 1.º + goles+asistencias > 11
	if league_position == 1 and total_ga > 11:
		return "GOLDEN_BOY_CHAMPION"
	# LEAGUE_CHAMPION: 1.º
	elif league_position == 1:
		return "LEAGUE_CHAMPION"
	# PRO_RUNNER_UP: 2.º
	elif league_position == 2:
		return "PRO_RUNNER_UP"
	# RELEASED_BAD: 3.º+
	else:
		return "RELEASED_BAD"

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
