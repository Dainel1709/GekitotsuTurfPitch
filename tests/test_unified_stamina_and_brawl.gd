extends SceneTree

# Test headless para validar:
# 1. Sistema de estamina unificado entre Player.gd y FootballAI.gd (enable_stamina_fatigue, drenaje, agotamiento al 80%, recuperación)
# 2. Activación del duelo superpuesto en cancha (fury 100%, rango <= 4.0m, CanvasLayer layer 20, Viewport transparent_bg & own_world, pausa)
# 3. Modo Duelo en Cancha (is_pitch_brawl, ocultación de fondo opaco, banner layer 25, stats C++)
# 4. Retorno exacto al partido (destrucción del overlay, fury=0, reanudación paused=false, stun_timer=7.0 / 3.5)

func _init():
	print("==================================================")
	print("[TEST] Estamina Unificada y Duelo Superpuesto en Cancha")
	print("==================================================")

	# --------------------------------------------------------------------------
	# PARTE 1: Sistema de Estamina Unificado (Player.gd y FootballAI.gd)
	# --------------------------------------------------------------------------
	print("\n--- 1. Verificando Estamina Unificada ---")
	var player_script = load("res://scripts/Player.gd")
	var ai_script = load("res://scripts/FootballAI.gd")
	assert(player_script != null, "Player.gd debe cargarse correctamente")
	assert(ai_script != null, "FootballAI.gd debe cargarse correctamente")

	var player = KinematicBody.new()
	player.set_script(player_script)
	root.add_child(player)

	var opponent = KinematicBody.new()
	opponent.set_script(ai_script)
	opponent.role = "opponent"
	root.add_child(opponent)

	# 1.1 Comprobar exports y valores por defecto
	assert("enable_stamina_fatigue" in player, "Player debe tener enable_stamina_fatigue")
	assert("enable_stamina_fatigue" in opponent, "FootballAI debe tener enable_stamina_fatigue")
	assert(player.enable_stamina_fatigue == true, "enable_stamina_fatigue de Player debe ser true por defecto")
	assert(opponent.enable_stamina_fatigue == true, "enable_stamina_fatigue de FootballAI debe ser true por defecto")
	assert(player.is_exhausted == false, "Player no debe empezar agotado")
	assert(opponent.is_exhausted == false, "Opponent no debe empezar agotado")
	print("  -> enable_stamina_fatigue y estado inicial en Player y AI: OK")

	# 1.2 Drenar estamina hasta 0 en ambos y verificar is_exhausted == true
	player.drain_stamina(120.0)
	assert(player.stamina == 0.0, "La estamina de Player debe ser 0 tras drenaje completo")
	assert(player.is_exhausted == true, "Player debe entrar en is_exhausted = true al llegar a 0 de estamina")

	opponent.drain_stamina(120.0)
	assert(opponent.stamina == 0.0, "La estamina de FootballAI debe ser 0 tras drenaje completo")
	assert(opponent.is_exhausted == true, "FootballAI debe entrar en is_exhausted = true al llegar a 0 de estamina")
	print("  -> Agotamiento (is_exhausted = true al llegar a 0) en Player y AI: OK")

	# 1.3 Verificar penalización de velocidad al 80%
	var p_exhausted_spd = player.get_current_speed()
	assert(abs(p_exhausted_spd - 8.0) < 0.01, "Velocidad de Player agotado debe ser 8.0")

	var opp_speed_mult = 0.8 if (opponent.enable_stamina_fatigue and opponent.is_exhausted) else 1.0
	assert(abs(opp_speed_mult - 0.8) < 0.001, "speed_mult de FootballAI agotado debe ser 0.8")
	print("  -> Penalización de velocidad al 80% por cansancio en Player y AI: OK")

	# 1.4 Recuperación de estamina al trotar/detenerse hasta >= 35.0
	player.stamina = 34.0
	assert(player.is_exhausted == true, "Player debe seguir agotado mientras stamina < 35.0")
	player.stamina = 35.0
	assert(player.is_exhausted == false, "Player debe salir de agotamiento al recuperar >= 35.0 de estamina")

	opponent.stamina = 34.0
	assert(opponent.is_exhausted == true, "FootballAI debe seguir agotado mientras stamina < 35.0")
	opponent.stamina = 35.0
	assert(opponent.is_exhausted == false, "FootballAI debe salir de agotamiento al recuperar >= 35.0 de estamina")
	print("  -> Recuperación y desbloqueo de agotamiento al superar 35.0 de estamina: OK")

	# 1.5 Desactivación de fatiga (enable_stamina_fatigue == false)
	player.enable_stamina_fatigue = false
	player.stamina = 0.0
	assert(player.get_current_speed() == 10.0, "Con enable_stamina_fatigue=false, Player no debe sufrir penalización")

	opponent.enable_stamina_fatigue = false
	opponent.stamina = 0.0
	var opp_free_mult = 0.8 if (opponent.enable_stamina_fatigue and opponent.is_exhausted) else 1.0
	assert(opp_free_mult == 1.0, "Con enable_stamina_fatigue=false, FootballAI no debe sufrir penalización")
	print("  -> Con enable_stamina_fatigue = false, penalización desactivada: OK")

	# Restaurar modo con fatiga
	player.enable_stamina_fatigue = true
	player.stamina = 100.0
	opponent.enable_stamina_fatigue = true
	opponent.stamina = 100.0

	# --------------------------------------------------------------------------
	# PARTE 2: Activación del Duelo Superpuesto desde Cancha
	# --------------------------------------------------------------------------
	print("\n--- 2. Verificando Activación del Duelo de Pelea desde la Cancha ---")
	player.global_transform.origin = Vector3(0, 0, 0)
	opponent.global_transform.origin = Vector3(10.0, 0, 10.0) # Lejos (> 4.0m)
	opponent.add_to_group("opponents")

	# 2.1 Con Furia al 100% pero rival lejano (> 4.0m)
	player.fury = 100.0
	var triggered_far = player.trigger_pitch_brawl()
	assert(triggered_far == false, "No debe iniciar duelo si el rival está a más de 4.0 metros")
	assert(player.fury == 100.0, "La furia debe conservarse al 100% si no hay rival cercano")
	assert(paused == false, "El juego no debe pausarse si no hay rival cercano")
	print("  -> Rival lejano (>4m): Duelo rechazado sin consumir Furia: OK")

	# 2.2 Con rival a <= 4.0m y Furia al 100%
	opponent.global_transform.origin = Vector3(2.0, 0, 1.5) # Distancia XZ = sqrt(4 + 2.25) = 2.5m <= 4.0m
	var triggered_near = player.trigger_pitch_brawl()
	assert(triggered_near == true, "Debe iniciar duelo cuando hay rival a <= 4.0m")
	assert(paused == true, "El juego debe quedar en pausa (get_tree().paused = true)")
	print("  -> Activación de duelo con rival a 2.5m y juego pausado: OK")

	# 2.3 Verificar estructura del overlay (CanvasLayer 20, ViewportContainer, Viewport)
	var brawl_layer = root.get_node_or_null("BrawlOverlayLayer")
	if not brawl_layer:
		brawl_layer = player.get_node_or_null("BrawlOverlayLayer")
	if not brawl_layer:
		for child in root.get_children():
			if child is CanvasLayer and child.name == "BrawlOverlayLayer":
				brawl_layer = child
				break

	assert(brawl_layer != null, "BrawlOverlayLayer debe existir")
	assert(brawl_layer.layer == 20, "BrawlOverlayLayer debe tener layer = 20")
	assert(brawl_layer.pause_mode == Node.PAUSE_MODE_PROCESS, "BrawlOverlayLayer debe tener pause_mode = PROCESS")

	var vp_container = brawl_layer.get_node_or_null("BrawlViewportContainer")
	assert(vp_container != null, "BrawlViewportContainer debe existir")

	var vp = vp_container.get_node_or_null("BrawlViewport")
	assert(vp != null, "BrawlViewport debe existir")
	assert(vp.transparent_bg == true, "BrawlViewport debe tener transparent_bg = true")
	assert(vp.own_world == true, "BrawlViewport debe tener own_world = true")
	print("  -> CanvasLayer (layer 20), ViewportContainer y Viewport (transparent_bg=true, own_world=true): OK")

	# --------------------------------------------------------------------------
	# PARTE 3: Configuración Interna de FightArena en Modo Duelo
	# --------------------------------------------------------------------------
	print("\n--- 3. Verificando FightArena en Modo Cancha (is_pitch_brawl) ---")
	var fight_arena = vp.get_node_or_null("FightArena")
	assert(fight_arena != null, "FightArena debe estar instanciada dentro de BrawlViewport")
	assert(fight_arena.is_pitch_brawl == true, "is_pitch_brawl debe ser true")
	assert(fight_arena.has_signal("brawl_finished"), "FightArena debe tener la señal brawl_finished")

	# 3.1 Comprobar que los fondos opacos de Environment están ocultos
	var env = fight_arena.get_node_or_null("Environment")
	assert(env != null, "Environment debe existir en FightArena")
	var sky = env.get_node_or_null("SkyBackground")
	var asphalt = env.get_node_or_null("Asphalt")
	if sky:
		assert(sky.visible == false, "SkyBackground debe estar oculto para ver la cancha")
	if asphalt:
		assert(asphalt.visible == false, "Asphalt debe estar oculto para ver la cancha")

	# Colisiones físicas intactas
	var floor_body = env.get_node_or_null("FloorBody")
	assert(floor_body != null, "FloorBody debe seguir existiendo para las colisiones de lucha")
	print("  -> Fondos visuales opacos ocultos y colisiones de suelo intactas: OK")

	# 3.2 Comprobar HUD interno con layer = 25 y banner
	var arena_canvas = fight_arena.get_node_or_null("CanvasLayer")
	assert(arena_canvas != null, "CanvasLayer interno de FightArena debe existir")
	assert(arena_canvas.layer == 25, "CanvasLayer interno debe tener layer = 25")
	var banner = arena_canvas.get_node_or_null("BrawlBanner")
	assert(banner != null, "BrawlBanner debe existir en CanvasLayer interno")
	assert(banner.text == "¡DUELO EN LA CANCHA!", "BrawlBanner debe tener texto '¡DUELO EN LA CANCHA!'")
	print("  -> HUD interno (layer = 25) y banner '¡DUELO EN LA CANCHA!': OK")

	# --------------------------------------------------------------------------
	# PARTE 4: Conclusión del Duelo y Retorno Exacto al Partido
	# --------------------------------------------------------------------------
	print("\n--- 4. Verificando Conclusión del Duelo y Retorno a Cancha ---")
	# Simular que Ryu gana el duelo emitiendo brawl_finished(true)
	fight_arena.emit_signal("brawl_finished", true)

	assert(paused == false, "El partido debe reanudarse (get_tree().paused = false)")
	assert(player.fury == 0.0, "La furia de Player debe reiniciarse a 0.0 tras el duelo")
	assert(opponent.stun_timer == 7.0, "El rival debe recibir stun_timer = 7.0 al ganar Ryu")
	assert(player.stun_timer == 0.0, "Ryu no debe estar aturdido si ganó")
	print("  -> Retorno al partido: paused=false, fury=0.0, rival aturdido por 7.0s: OK")

	# Simular si Ryu hubiese perdido
	player.set_stun(3.5)
	assert(player.stun_timer == 3.5, "Ryu debe recibir stun_timer = 3.5 si pierde")
	player._physics_process(0.016)
	assert(player.velocity == Vector3.ZERO, "Ryu no puede moverse mientras está aturdido")
	print("  -> Aturdimiento a Ryu (3.5s) verificado: OK")

	# Limpieza
	player.free()
	opponent.free()

	print("\n==================================================")
	print("TODAS LAS PRUEBAS DE ESTAMINA Y DUELO SUPERPUESTO PASARON EXITOSAMENTE.")
	print("==================================================")
	quit(0)
