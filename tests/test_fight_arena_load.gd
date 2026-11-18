extends SceneTree

func get_tree():
	return self

func _init():
	print("==================================================")
	print("[TEST] Fighter.gd & FightArena.tscn: Combate Arcade")
	print("==================================================")

	# -- 1. Carga de scripts sin Parser Error --
	var fighter_script = load("res://scripts/Fighter.gd")
	assert(fighter_script != null, "Fighter.gd debe cargarse sin Parser Error")
	var arena_script = load("res://scripts/FightArena.gd")
	assert(arena_script != null, "FightArena.gd debe cargarse sin Parser Error")
	print("  -> Scripts cargados sin Parser Error              OK")

	# -- 2. Instanciar Fighter dummy y verificar propiedades --
	var dummy = KinematicBody2D.new()
	dummy.set_script(fighter_script)
	root.add_child(dummy)

	assert("combo_step" in dummy,             "combo_step debe existir")
	assert("max_combo_steps" in dummy,         "max_combo_steps debe existir")
	assert("combo_window_timer" in dummy,      "combo_window_timer debe existir")
	assert("combo_window_duration" in dummy,   "combo_window_duration debe existir")
	assert("move_speed" in dummy,              "move_speed debe existir")
	assert("dodge_speed" in dummy,             "dodge_speed debe existir")
	assert("hitstun_timer" in dummy,           "hitstun_timer debe existir")
	assert("blockstun_timer" in dummy,         "blockstun_timer debe existir")
	assert("hitstop_timer" in dummy,           "hitstop_timer debe existir")
	assert("knockback_velocity" in dummy,      "knockback_velocity debe existir")
	assert("has_air_attacked" in dummy,        "has_air_attacked debe existir")
	assert("is_jumping" in dummy,              "is_jumping debe existir")

	assert(dummy.combo_step == 0,              "combo_step inicial debe ser 0")
	assert(dummy.max_combo_steps == 6,         "max_combo_steps debe ser 6")
	assert(dummy.combo_window_timer == 0.0,    "combo_window_timer inicial debe ser 0.0")
	assert(dummy.combo_window_duration == 0.55,"combo_window_duration debe ser 0.55")
	assert(dummy.move_speed == 220.0,          "move_speed debe ser 220.0")
	assert(dummy.dodge_speed == 320.0,         "dodge_speed debe ser 320.0")
	assert(dummy.has_air_attacked == false,    "has_air_attacked inicial debe ser false")

	assert(dummy.has_signal("combo_updated"),  "combo_updated señal debe existir")
	assert(dummy.has_signal("combo_broken"),   "combo_broken señal debe existir")
	assert(dummy.has_signal("shake_requested"),"shake_requested señal debe existir")
	print("  -> Propiedades, timers y señales de combo arcade   OK")

	# -- 3. Daño, Hitstun, Guardia y Knockback --
	dummy.max_health     = 100.0
	dummy.current_health = 100.0
	dummy.is_blocking    = false
	dummy.take_damage(20.0, 95.0, 0.24, 1)
	assert(dummy.current_health == 80.0,       "Salud debe ser 80 tras 20 de daño")
	assert(dummy.hitstun_timer == 0.24,        "hitstun_timer debe ser 0.24s")
	assert(dummy.knockback_velocity.x == 95.0, "knockback_velocity.x debe ser 95.0")
	print("  -> Daño sin guardia, hitstun y knockback           OK")

	# Bloqueo: reducción 75%, blockstun 0.10s, retroceso 85 px/s
	dummy.current_health = 100.0
	dummy.is_blocking    = true
	dummy.take_damage(40.0, 100.0, 0.24, 1)
	assert(dummy.current_health == 90.0,       "Con guardia, 40 daño se reduce a 10")
	assert(dummy.blockstun_timer == 0.10,      "blockstun_timer debe ser 0.10s")
	assert(dummy.knockback_velocity.x == 85.0, "Retroceso de guardia debe ser 85 px/s")
	assert(dummy.is_blocking == true,          "Guardia debe permanecer activa tras impacto")
	dummy.is_blocking    = false
	print("  -> Guardia (reducción 75%, blockstun 0.10s, 85px/s) OK")

	dummy.free()

	# -- 4. Verificación de la cadena completa de combo de 6 golpes --
	var attacker = KinematicBody2D.new()
	attacker.set_script(fighter_script)
	attacker.fighter_name   = "Attacker"
	attacker.max_health     = 250.0
	attacker.current_health = 250.0
	attacker.global_position = Vector2(200, 475)
	attacker.facing_direction = 1
	root.add_child(attacker)

	var victim = KinematicBody2D.new()
	victim.set_script(fighter_script)
	victim.fighter_name   = "Victim"
	victim.max_health     = 250.0
	victim.current_health = 250.0
	victim.global_position = Vector2(245, 475)
	victim.facing_direction = -1
	root.add_child(victim)

	attacker.opponent = victim
	victim.opponent   = attacker

	# Golpe 1 (Jab): daño 8, cooldown 0.24, knockback 65, hitstop 0.03
	victim.global_position.x = attacker.global_position.x + 40.0
	attacker._execute_combo_step(0)
	assert(victim.current_health == 242.0, "Victima debe tener 242 HP tras Golpe 1 (daño 8)")
	assert(attacker.combo_step == 1,       "combo_step debe ser 1 tras Golpe 1")
	assert(attacker.combo_window_timer == 0.55, "combo_window_timer debe ser 0.55")
	assert(victim.knockback_velocity.x == 65.0, "Knockback de Golpe 1 debe ser 65 px/s")
	assert(attacker.hitstop_timer == 0.03, "Hitstop de Golpe 1 debe ser 0.03s")
	print("  -> Golpe 1 (Jab, dmg 8, kb 65, hitstop 0.03s)     OK")

	# Golpe 2 (Directo): daño 9, cooldown 0.25, knockback 70, hitstop 0.03
	attacker.hitstop_timer = 0.0
	victim.hitstop_timer   = 0.0
	victim.global_position.x = attacker.global_position.x + 40.0
	attacker._execute_combo_step(1)
	assert(victim.current_health == 233.0, "Victima debe tener 233 HP tras Golpe 2 (daño 9)")
	assert(attacker.combo_step == 2,       "combo_step debe ser 2 tras Golpe 2")
	assert(victim.knockback_velocity.x == 70.0, "Knockback de Golpe 2 debe ser 70 px/s")
	assert(attacker.hitstop_timer == 0.03, "Hitstop de Golpe 2 debe ser 0.03s")
	print("  -> Golpe 2 (Directo, dmg 9, kb 70, hitstop 0.03s) OK")

	# Golpe 3 (Gancho): daño 11, cooldown 0.26, knockback 75, hitstop 0.03
	attacker.hitstop_timer = 0.0
	victim.hitstop_timer   = 0.0
	victim.global_position.x = attacker.global_position.x + 40.0
	attacker._execute_combo_step(2)
	assert(victim.current_health == 222.0, "Victima debe tener 222 HP tras Golpe 3 (daño 11)")
	assert(attacker.combo_step == 3,       "combo_step debe ser 3 tras Golpe 3")
	assert(victim.knockback_velocity.x == 75.0, "Knockback de Golpe 3 debe ser 75 px/s")
	assert(attacker.hitstop_timer == 0.03, "Hitstop de Golpe 3 debe ser 0.03s")
	print("  -> Golpe 3 (Gancho, dmg 11, kb 75, hitstop 0.03s) OK")

	# Golpe 4 (Patada media): daño 12, cooldown 0.27, knockback 80, hitstop 0.03
	attacker.hitstop_timer = 0.0
	victim.hitstop_timer   = 0.0
	victim.global_position.x = attacker.global_position.x + 40.0
	attacker._execute_combo_step(3)
	assert(victim.current_health == 210.0, "Victima debe tener 210 HP tras Golpe 4 (daño 12)")
	assert(attacker.combo_step == 4,       "combo_step debe ser 4 tras Golpe 4")
	assert(victim.knockback_velocity.x == 80.0, "Knockback de Golpe 4 debe ser 80 px/s")
	assert(attacker.hitstop_timer == 0.03, "Hitstop de Golpe 4 debe ser 0.03s")
	print("  -> Golpe 4 (Patada, dmg 12, kb 80, hitstop 0.03s) OK")

	# Golpe 5 (Codazo / Uppercut): daño 14, cooldown 0.28, knockback 85, hitstop 0.03
	attacker.hitstop_timer = 0.0
	victim.hitstop_timer   = 0.0
	victim.global_position.x = attacker.global_position.x + 40.0
	attacker._execute_combo_step(4)
	assert(victim.current_health == 196.0, "Victima debe tener 196 HP tras Golpe 5 (daño 14)")
	assert(attacker.combo_step == 5,       "combo_step debe ser 5 tras Golpe 5")
	assert(victim.knockback_velocity.x == 85.0, "Knockback de Golpe 5 debe ser 85 px/s")
	assert(attacker.hitstop_timer == 0.03, "Hitstop de Golpe 5 debe ser 0.03s")
	print("  -> Golpe 5 (Codazo, dmg 14, kb 85, hitstop 0.03s) OK")

	# Golpe 6 (Remate final tras paso 5): daño 28, knockback 430, hitstun 0.40, hitstop 0.07
	attacker.hitstop_timer = 0.0
	victim.hitstop_timer   = 0.0
	victim.global_position.x = attacker.global_position.x + 40.0
	attacker._execute_combo_step(5)
	assert(victim.current_health == 168.0, "Victima debe tener 168 HP tras Golpe 6 (daño 28)")
	assert(victim.knockback_velocity.x == 430.0, "Knockback de Golpe 6 debe ser 430 px/s")
	assert(victim.hitstun_timer == 0.40,   "Hitstun de Golpe 6 debe ser 0.40s")
	assert(attacker.hitstop_timer == 0.07, "Hitstop de Golpe 6 debe ser 0.07s")
	assert(attacker.combo_step == 0,       "combo_step debe reiniciar a 0 tras remate")
	print("  -> Golpe 6 (Remate, dmg 28, kb 430, hitstop 0.07s) OK")

	# -- 5. Golpe Pesado individual fuera del paso 6 --
	attacker.hitstop_timer = 0.0
	victim.hitstop_timer   = 0.0
	attacker.combo_step    = 0
	victim.global_position.x = attacker.global_position.x + 40.0
	attacker._execute_heavy_attack()
	assert(victim.current_health == 142.0, "Victima debe recibir 26 de daño (168 -> 142)")
	assert(victim.knockback_velocity.x == 400.0, "Knockback de Golpe Pesado debe ser 400 px/s")
	assert(victim.hitstun_timer == 0.40,   "Hitstun de Golpe Pesado debe ser 0.40s")
	assert(attacker.hitstop_timer == 0.07, "Hitstop de Golpe Pesado debe ser 0.07s")
	assert(attacker.combo_step == 0,       "combo_step debe mantenerse en 0")
	print("  -> Golpe Pesado individual (dmg 26, kb 400, hitstop 0.07s) OK")

	# -- 6. Whiff reinicia el combo a 0 --
	attacker.combo_step = 2
	victim.global_position.x = 950.0  # Fuera de rango
	attacker._execute_combo_step(2)
	assert(attacker.combo_step == 0, "Whiff al aire debe reiniciar combo_step a 0")
	print("  -> Whiff al aire reinicia combo_step = 0          OK")

	# -- 7. Ataque Aéreo --
	victim.global_position.x = attacker.global_position.x + 40.0  # Volver a rango
	attacker.is_jumping       = true
	attacker.has_air_attacked = false
	attacker.hitstop_timer    = 0.0
	victim.hitstop_timer      = 0.0
	attacker._execute_air_attack()
	assert(attacker.has_air_attacked == true, "has_air_attacked debe ser true tras ataque aéreo")
	assert(victim.current_health == 122.0,    "Victima debe recibir 20 de daño (142 -> 122)")
	assert(victim.knockback_velocity.x == 180.0, "Knockback aéreo debe ser 180 px/s")
	assert(attacker.hitstop_timer == 0.055,   "Hitstop aéreo debe ser 0.055s")

	# Aterrizaje reinicia has_air_attacked
	attacker._on_landed()
	assert(attacker.has_air_attacked == false, "has_air_attacked debe ser false tras aterrizar")
	print("  -> Ataque aéreo (dmg 20, kb 180, hitstop 0.055s) y aterrizaje OK")

	attacker.free()
	victim.free()

	# -- 8. Cargar FightArena.tscn y verificar nodos --
	var scene = load("res://scenes/FightArena.tscn")
	assert(scene != null, "FightArena.tscn debe cargarse")
	var instance = scene.instance()
	assert(instance != null, "FightArena.tscn debe instanciarse")

	var player_node = instance.get_node_or_null("Player")
	var rival_node  = instance.get_node_or_null("Rival")
	var camera_node = instance.get_node_or_null("Camera2D")
	var combo_node  = instance.get_node_or_null("CanvasLayer/ComboLabel")

	assert(player_node != null, "Nodo Player debe existir en FightArena")
	assert(rival_node  != null, "Nodo Rival debe existir en FightArena")
	assert(camera_node != null, "Nodo Camera2D debe existir en FightArena")
	assert(combo_node  != null, "Nodo ComboLabel debe existir en CanvasLayer")

	assert("combo_step" in player_node, "Player debe tener combo_step")
	assert("move_speed" in player_node, "Player debe tener move_speed")
	assert("dodge_speed" in player_node,"Player debe tener dodge_speed")
	assert(instance.has_method("trigger_camera_shake"), "FightArena debe tener trigger_camera_shake")

	print("  -> FightArena.tscn: Camera2D, ComboLabel y luchadores OK")

	instance.free()

	print("==================================================")
	print("TODAS LAS PRUEBAS DE COMBATE ARCADE PASARON CON ÉXITO.")
	print("==================================================")
	get_tree().quit(0)
