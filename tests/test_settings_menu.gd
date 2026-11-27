extends SceneTree

# Test: Verifica el menú de configuración (SettingsMenu / SettingsOverlay)
# y la persistencia de esquema de controles, música, SFX y pantalla completa.

func _init():
	print("==================================================")
	print("[TEST] Verificando SettingsMenu y Persistencia...")
	print("==================================================")

	var gs = root.get_node_or_null("GameSettings")
	if gs == null:
		var gs_script = load("res://scripts/autoload/GameSettings.gd")
		assert(gs_script != null, "GameSettings.gd debe cargar")
		gs = Node.new()
		gs.name = "GameSettings"
		gs.set_script(gs_script)
		root.add_child(gs)

	var settings_scene = load("res://scenes/SettingsMenu.tscn")
	assert(settings_scene != null, "SettingsMenu.tscn debe cargar")

	var so = root.get_node_or_null("SettingsOverlay")
	if so == null:
		so = settings_scene.instance()
		so.name = "SettingsOverlay"
		root.add_child(so)

	gs.reset_save()
	gs.music_volume = 0.8
	gs.sfx_volume = 0.9
	gs.fullscreen_enabled = false
	gs.set_control_scheme(gs.ControlScheme.FIFA_CLASSIC)
	gs.save_progress({})

	# --------------------------------------------------------------------------
	# 1. Abrir modal y verificar estado inicial
	# --------------------------------------------------------------------------
	print("\n[1] Abriendo SettingsOverlay...")
	so.open_menu()
	assert(so.is_open(), "SettingsOverlay debe estar abierto tras open_menu()")
	assert(int(round(so.music_slider.value)) == 80, "MusicSlider debe iniciar en 80")
	assert(int(round(so.sfx_slider.value)) == 90, "SfxSlider debe iniciar en 90")
	assert(so.fullscreen_check.pressed == false, "FullscreenCheck debe iniciar en false")
	print("  -> Estado inicial OK")

	# --------------------------------------------------------------------------
	# 2. Cambiar controles, música, SFX y pantalla completa
	# --------------------------------------------------------------------------
	print("\n[2] Modificando ajustes desde el modal...")
	so._on_scheme_pressed() # FIFA -> PES
	so.music_slider.value = 35.0
	so._on_music_changed(35.0)
	so.sfx_slider.value = 55.0
	so._on_sfx_changed(55.0)
	so._on_fullscreen_toggled(true)
	so.close_and_save()

	assert(not so.is_open(), "SettingsOverlay debe cerrarse tras close_and_save()")
	assert(gs.get_control_scheme() == gs.ControlScheme.PES_ALTERNATIVE, "Esquema debe ser PES_ALTERNATIVE")
	assert(abs(gs.music_volume - 0.35) < 0.01, "music_volume debe ser 0.35")
	assert(abs(gs.sfx_volume - 0.55) < 0.01, "sfx_volume debe ser 0.55")
	assert(gs.fullscreen_enabled == true, "fullscreen_enabled debe ser true")
	print("  -> Cambios aplicados OK")

	# --------------------------------------------------------------------------
	# 3. Simular recarga desde user://savegame.json
	# --------------------------------------------------------------------------
	print("\n[3] Verificando recarga persistente desde savegame.json...")
	gs.set_control_scheme(gs.ControlScheme.FIFA_CLASSIC)
	gs.music_volume = 1.0
	gs.sfx_volume = 1.0
	gs.fullscreen_enabled = false

	var loaded = gs.load_progress()
	assert(gs.get_control_scheme() == gs.ControlScheme.PES_ALTERNATIVE, "Recarga debe restaurar PES_ALTERNATIVE")
	assert(abs(gs.music_volume - 0.35) < 0.01, "Recarga debe restaurar music_volume=0.35")
	assert(abs(gs.sfx_volume - 0.55) < 0.01, "Recarga debe restaurar sfx_volume=0.55")
	assert(gs.fullscreen_enabled == true, "Recarga debe restaurar fullscreen_enabled=true")
	assert(loaded.has("music_volume") and loaded.has("sfx_volume") and loaded.has("fullscreen_enabled"), "JSON debe contener claves de audio/pantalla")
	print("  -> Persistencia y recarga OK")

	# Restaurar estado limpio (ventana normal para no dejar fullscreen en editor/PC)
	gs.fullscreen_enabled = false
	gs.music_volume = 0.8
	gs.sfx_volume = 0.9
	gs.apply_audio_and_display_settings()
	gs.reset_save()

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DE SETTINGS MENU PASARON EXITOSAMENTE.")
	print("==================================================")
	quit(0)
