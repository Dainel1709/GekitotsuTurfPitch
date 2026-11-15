extends SceneTree

func _init():
	print("==================================================")
	print("[TEST] Iniciando verificacion de GameSettings y Controles...")
	print("==================================================")

	var gs_script = load("res://scripts/autoload/GameSettings.gd")
	assert(gs_script != null, "No se pudo cargar GameSettings.gd")
	var gs = gs_script.new()
	assert(gs != null, "No se pudo instanciar GameSettings")

	# --------------------------------------------------------------------------
	# 1. Verificación de Esquemas de Control (FIFA Clásico vs PES Alternativo)
	# --------------------------------------------------------------------------
	print("\n[1] Verificando alternancia de esquemas de controles FIFA / PES...")
	assert(gs.get_control_scheme() == gs.ControlScheme.FIFA_CLASSIC, "El esquema inicial debe ser FIFA_CLASSIC (0)")
	assert(gs.get_scheme_short_name() == "Clásico (FIFA)", "Nombre corto inicial esperado: 'Clásico (FIFA)'")
	assert(gs.get_scheme_name() == "Clásico (FIFA)", "Nombre completo inicial esperado: 'Clásico (FIFA)'")
	print("  -> Esquema por defecto FIFA verificado OK")

	var toggled = gs.toggle_control_scheme()
	assert(toggled == gs.ControlScheme.PES_ALTERNATIVE, "Tras alternar, debe ser PES_ALTERNATIVE (1)")
	assert(gs.get_control_scheme() == gs.ControlScheme.PES_ALTERNATIVE)
	assert(gs.get_scheme_short_name() == "Alternativo (PES)", "Nombre corto esperado: 'Alternativo (PES)'")
	assert(gs.get_scheme_name() == "Alternativo (PES / PPSSPP)", "Nombre completo esperado: 'Alternativo (PES / PPSSPP)'")
	print("  -> Alternancia a PES Alternativo OK")

	toggled = gs.toggle_control_scheme()
	assert(toggled == gs.ControlScheme.FIFA_CLASSIC, "Tras alternar de nuevo, debe ser FIFA_CLASSIC (0)")
	assert(gs.get_control_scheme() == gs.ControlScheme.FIFA_CLASSIC)
	print("  -> Regreso a FIFA Clásico OK")

	# --------------------------------------------------------------------------
	# 2. Verificación de Mando Estándar / Xbox (mapeo habitual)
	# --------------------------------------------------------------------------
	print("\n[2] Verificando controlador estándar / Xbox...")
	gs.set_simulated_joy_name("Xbox One Controller")
	assert(not gs.is_playstation_controller(0), "Xbox no debe ser detectado como PlayStation")
	assert(gs.get_button_cross(0) == 0, "Cruz en Xbox debe ser botón 0 (A)")
	assert(gs.get_button_circle(0) == 1, "Círculo en Xbox debe ser botón 1 (B)")
	assert(gs.get_button_square(0) == 2, "Cuadrado en Xbox debe ser botón 2 (X)")
	assert(gs.get_button_triangle(0) == 3, "Triángulo en Xbox debe ser botón 3 (Y)")
	print("  -> Mapeo estándar / Xbox verificado OK")

	# --------------------------------------------------------------------------
	# 3. Verificación de Soporte Automático PlayStation 4 (DualShock 4)
	# --------------------------------------------------------------------------
	print("\n[3] Verificando soporte automático para PS4 (DualShock 4 USB / Bluetooth)...")
	# Caso 3a: DualShock 4 por USB en Windows
	gs.set_simulated_joy_name("Sony Interactive Entertainment Wireless Controller")
	assert(gs.is_playstation_controller(0), "Debe detectar mando Sony/PS4")
	assert(gs.is_ps4_controller(0), "Debe identificar como PS4")
	assert(gs.get_button_cross(0) == 1, "Cruz física en PS4 DirectInput debe ser botón 1")
	assert(gs.get_button_circle(0) == 2, "Círculo físico en PS4 DirectInput debe ser botón 2")
	assert(gs.get_button_square(0) == 0, "Cuadrado físico en PS4 DirectInput debe ser botón 0")
	assert(gs.get_button_triangle(0) == 3, "Triángulo físico en PS4 DirectInput debe ser botón 3")
	print("  -> PS4 USB: Posiciones físicas (Cruz=1, Círculo=2, Cuadrado=0, Triángulo=3) OK")

	# Caso 3b: DualShock 4 por Bluetooth en Windows ("Wireless Controller")
	gs.set_simulated_joy_name("Wireless Controller")
	assert(gs.is_playstation_controller(0), "Windows Bluetooth 'Wireless Controller' debe detectarse como PS")
	assert(gs.get_button_cross(0) == 1)
	assert(gs.get_button_circle(0) == 2)
	assert(gs.get_button_square(0) == 0)
	assert(gs.get_button_triangle(0) == 3)
	print("  -> PS4 Bluetooth ('Wireless Controller'): Posiciones físicas OK")

	# --------------------------------------------------------------------------
	# 4. Verificación de Soporte Automático PlayStation 5 (DualSense)
	# --------------------------------------------------------------------------
	print("\n[4] Verificando soporte automático para PS5 (DualSense USB / Bluetooth)...")
	gs.set_simulated_joy_name("DualSense Wireless Controller")
	assert(gs.is_playstation_controller(0), "Debe detectar DualSense como PlayStation")
	assert(gs.is_ps5_controller(0), "Debe identificar como PS5")
	assert(gs.get_button_cross(0) == 1, "Cruz física en PS5 debe ser botón 1")
	assert(gs.get_button_circle(0) == 2, "Círculo físico en PS5 debe ser botón 2")
	assert(gs.get_button_square(0) == 0, "Cuadrado físico en PS5 debe ser botón 0")
	assert(gs.get_button_triangle(0) == 3, "Triángulo físico en PS5 debe ser botón 3")
	print("  -> PS5 DualSense: Posiciones físicas (Cruz=1, Círculo=2, Cuadrado=0, Triángulo=3) OK")

	# --------------------------------------------------------------------------
	# 5. Verificación de grab_focus() en TitleScreen.tscn y MainGame.tscn
	# --------------------------------------------------------------------------
	print("\n[5] Verificando grab_focus() y selector de controles en escenas...")
	
	# Prueba TitleScreen
	var title_scene = load("res://scenes/TitleScreen.tscn")
	assert(title_scene != null, "TitleScreen.tscn debe existir")
	var title_instance = title_scene.instance()
	root.add_child(title_instance)
	var start_btn = title_instance.find_node("StartButton", true, false)
	assert(start_btn != null, "StartButton debe existir en TitleScreen")
	assert(start_btn.has_focus(), "StartButton debe tener grab_focus() para navegación con mando")
	print("  -> TitleScreen.tscn: StartButton.grab_focus() verificado OK")
	title_instance.queue_free()

	# Prueba MainGame
	var main_scene = load("res://scenes/MainGame.tscn")
	assert(main_scene != null, "MainGame.tscn debe existir")
	var main_instance = main_scene.instance()
	root.add_child(main_instance)
	
	var left_btn = main_instance.find_node("LeftButton", true, false)
	var controls_btn = main_instance.find_node("ControlsButton", true, false)
	assert(controls_btn != null, "ControlsButton debe existir en MainGame.tscn")
	assert(left_btn != null, "LeftButton debe existir en MainGame.tscn")
	assert(left_btn.has_focus(), "LeftButton debe tener grab_focus() inicial para navegación con mando")
	print("  -> MainGame.tscn: Botón de foco inicial grab_focus() verificado OK")

	# Probar pulsación de controls_btn y actualización de texto en pantalla
	var initial_text = controls_btn.text
	assert("Controles Fútbol:" in initial_text, "El texto del botón debe incluir 'Controles Fútbol:'")
	print("  -> Texto inicial en pantalla: '%s'" % initial_text)

	# Simular pulsación de botón
	controls_btn.emit_signal("pressed")
	var new_text = controls_btn.text
	print("  -> Texto tras alternar en pantalla: '%s'" % new_text)
	assert(new_text != initial_text or "Alternativo" in new_text or "PES" in new_text, "El texto en pantalla debe actualizarse al alternar")
	
	main_instance.queue_free()
	gs.free()

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DE GAMESETTINGS Y CONTROLES PASARON EXITOSAMENTE.")
	print("==================================================")
	quit(0)
