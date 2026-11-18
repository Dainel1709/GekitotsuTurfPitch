extends SceneTree

func get_tree():
	return self

func _init():
	print("==================================================")
	print("[TEST] Combate Arcade, RPG Stats C++ y Sistema de Furia")
	print("==================================================")

	# -- 1. Carga de scripts sin Parser Error --
	var fighter_script = load("res://scripts/Fighter.gd")
	assert(fighter_script != null, "Fighter.gd debe cargarse sin Parser Error")
	var arena_script = load("res://scripts/FightArena.gd")
	assert(arena_script != null, "FightArena.gd debe cargarse sin Parser Error")
	var player_script = load("res://scripts/Player.gd")
	assert(player_script != null, "Player.gd debe cargarse sin Parser Error")
	print("  -> Scripts cargados sin Parser Error              OK")

	# -- 2. Instanciar Fighter dummy y verificar propiedades arcade y Furia --
	var dummy = KinematicBody2D.new()
	dummy.set_script(fighter_script)
	root.add_child(dummy)

	assert("combo_step" in dummy,             "combo_step debe existir")
	assert("max_combo_steps" in dummy,         "max_combo_steps debe existir")
	assert("combo_window_timer" in dummy,      "combo_window_timer debe existir")
	assert("move_speed" in dummy,              "move_speed debe existir")
	assert("dodge_speed" in dummy,             "dodge_speed debe existir")
	assert("hitstun_timer" in dummy,           "hitstun_timer debe existir")
	assert("blockstun_timer" in dummy,         "blockstun_timer debe existir")
	assert("hitstop_timer" in dummy,           "hitstop_timer debe existir")
	assert("knockback_velocity" in dummy,      "knockback_velocity debe existir")
	assert("has_air_attacked" in dummy,        "has_air_attacked debe existir")
	assert("fury" in dummy,                    "fury debe existir")
	assert("max_fury" in dummy,                "max_fury debe existir")
	assert("combat_stat" in dummy,             "combat_stat debe existir")
	assert("discipline_stat" in dummy,         "discipline_stat debe existir")

	assert(dummy.fury == 0.0,                  "fury inicial debe ser 0.0")
	assert(dummy.max_fury == 100.0,            "max_fury debe ser 100.0")
	assert(dummy.has_signal("fury_changed"),   "fury_changed señal debe existir")
	assert(dummy.has_signal("special_attack_executed"), "special_attack_executed debe existir")
	print("  -> Propiedades, timers y señales de Furia/Combate OK")

	# -- 3. Escalado RPG C++ (Combate y Disciplina) en Fighter --
	dummy.apply_rpg_stats(20, 30) # Combate 20, Disciplina 30
	assert(abs(dummy.damage_multiplier - 1.30) < 0.001, "damage_multiplier debe ser 1.30 con Combate=20")
	assert(abs(dummy.fury_gain_mult - 1.30) < 0.001,    "fury_gain_mult debe ser 1.30 con Combate=20")
	assert(abs(dummy.block_dmg_factor - 0.16) < 0.001,  "block_dmg_factor debe ser 0.16 con Disciplina=30 (84% mit)")
	print("  -> Escalado RPG C++ (Combate=20, Disciplina=30)   OK")

	# Daño sin guardia con hitstun reducido por Disciplina
	dummy.max_health     = 100.0
	dummy.current_health = 100.0
	dummy.is_blocking    = false
	dummy.take_damage(20.0, 95.0, 0.24, 1)
	assert(dummy.current_health == 80.0, "Salud debe ser 80 tras 20 de daño")
	# Base 0.24 * (1.0 - 30 * 0.005) = 0.24 * 0.85 = 0.204
	assert(abs(dummy.hitstun_timer - 0.204) < 0.01, "Hitstun debe mitigarse a ~0.204s con Disciplina 30")
	print("  -> Daño sin guardia y mitigación de hitstun       OK")

	# Bloqueo: mitigación mejorada por Disciplina y carga de furia al bloquear
	dummy.current_health = 100.0
	dummy.fury           = 0.0
	dummy.is_blocking    = true
	dummy.take_damage(40.0, 100.0, 0.24, 1)
	# 40 * 0.16 = 6.4 de daño recibido -> salud = 93.6
	assert(abs(dummy.current_health - 93.6) < 0.01, "Salud debe ser 93.6 con 84%% de mitigación")
	assert(dummy.fury > 0.0, "Bloquear debe cargar Furia")
	dummy.is_blocking    = false
	print("  -> Bloqueo con mitigación mejorada y ganancia Furia OK")

	dummy.free()

	# -- 4. Verificación de Combo de 6 Golpes y Golpe Especial (Gekitotsu Breaker) --
	var attacker = KinematicBody2D.new()
	attacker.set_script(fighter_script)
	attacker.fighter_name    = "Attacker"
	attacker.max_health      = 350.0
	attacker.current_health  = 350.0
	attacker.global_position = Vector2(200, 475)
	attacker.facing_direction = 1
	root.add_child(attacker)

	var victim = KinematicBody2D.new()
	victim.set_script(fighter_script)
	victim.fighter_name    = "Victim"
	victim.max_health      = 350.0
	victim.current_health  = 350.0
	victim.global_position = Vector2(245, 475)
	victim.facing_direction = -1
	root.add_child(victim)

	attacker.opponent = victim
	victim.opponent   = attacker

	# Aplicar estadísticas base para pruebas de combo exactas
	attacker.apply_rpg_stats(0, 0)
	victim.apply_rpg_stats(0, 0)

	attacker.fury = 0.0
	# Golpe 1 (Jab)
	victim.global_position.x = attacker.global_position.x + 40.0
	attacker._execute_combo_step(0)
	assert(victim.current_health == 342.0, "Victima debe tener 342 HP tras Golpe 1")
	assert(attacker.combo_step == 1,       "combo_step debe ser 1 tras Golpe 1")
	assert(attacker.fury > 0.0,            "Conectar golpe debe cargar Furia")
	print("  -> Golpe 1 conectado y Furia acumulada            OK")

	# Completar pasos 2 a 6
	for s in range(1, 6):
		attacker.hitstop_timer = 0.0
		victim.hitstop_timer   = 0.0
		victim.global_position.x = attacker.global_position.x + 40.0
		attacker._execute_combo_step(s)

	assert(attacker.combo_step == 0, "Combo de 6 golpes debe completarse")
	print("  -> Cadena completa de 6 golpes completada         OK")

	# Golpe Especial ("Gekitotsu Breaker" — Furia al 100%)
	attacker.apply_rpg_stats(20, 0) # Combate 20 -> damage_multiplier = 1.30
	attacker.fury = 100.0
	attacker.hitstop_timer = 0.0
	victim.hitstop_timer   = 0.0
	victim.global_position.x = attacker.global_position.x + 45.0
	var hp_before_special = victim.current_health

	var special_executed = [false]
	attacker.connect("special_attack_executed", self, "_on_special_attack", [special_executed])
	attacker._execute_special_attack()

	assert(special_executed[0] == true,  "Señal special_attack_executed debe emitirse")
	assert(attacker.fury == 0.0,         "Furia debe consumirse por completo (0.0)")
	# Daño masivo: 55 * 1.30 = 71.5
	var expected_hp = hp_before_special - (55.0 * 1.30)
	assert(abs(victim.current_health - expected_hp) < 0.1, "Daño masivo de Golpe Especial (71.5) aplicado")
	assert(victim.knockback_velocity.x == 520.0, "Knockback de Golpe Especial debe ser 520 px/s")
	assert(victim.hitstun_timer == 0.45,         "Hitstun de Golpe Especial debe ser 0.45s")
	assert(attacker.hitstop_timer == 0.09,       "Hitstop de Golpe Especial debe ser 0.09s")
	print("  -> Golpe Especial (Gekitotsu Breaker, 520 kb, 0.09s stop) OK")

	attacker.free()
	victim.free()

	# -- 5. Verificación de Fútbol: RPG Stats, Furia y Tiro Especial (L + Disparo) --
	var player = player_script.new()
	root.add_child(player)

	assert("fury" in player,              "Player debe tener propiedad fury")
	assert("max_fury" in player,          "Player debe tener max_fury")
	assert("kick_power_mult" in player,   "Player debe tener kick_power_mult")
	assert("sprint_drain_mult" in player, "Player debe tener sprint_drain_mult")

	# Escalado de Combate y Disciplina en fútbol
	player.apply_rpg_stats(25, 40) # Combate 25 (+20% tiro), Disciplina 40 (-24% drenaje sprint)
	assert(abs(player.kick_power_mult - 1.20) < 0.001,   "kick_power_mult debe ser 1.20 con Combate 25")
	assert(abs(player.sprint_drain_mult - 0.76) < 0.001, "sprint_drain_mult debe ser 0.76 con Disciplina 40")
	print("  -> Fútbol: Escalado RPG (Combate=25, Disciplina=40) OK")

	# Carga de Furia
	player.fury = 0.0
	player.add_fury(60.0)
	assert(player.fury == 60.0, "Furia debe acumular 60.0")
	player.add_fury(60.0)
	assert(player.fury == 100.0, "Furia debe topar en 100.0")
	print("  -> Fútbol: Acumulación de Furia al 100%           OK")

	# Balón para tiro
	var ball = RigidBody.new()
	ball.add_to_group("ball")
	root.add_child(ball)
	player.ball_ref = ball
	ball.translation = Vector3(0.0, 0.25, -1.0) # Dentro de rango de pateo
	player.translation = Vector3.ZERO
	player.facing_direction = Vector3(0.0, 0.0, -1.0)

	var special_shot_fired = [false]
	player.connect("special_shot_executed", self, "_on_special_shot", [special_shot_fired])

	# Ejecutar Tiro Especial ("Gekitotsu Shot" con L + Disparo)
	player._execute_special_shot()
	assert(special_shot_fired[0] == true, "special_shot_executed debe emitirse")
	assert(player.fury == 0.0,            "Furia debe consumirse al 100% tras tiro especial")
	assert(player.kick_cooldown == 0.35,  "kick_cooldown debe ser 0.35 tras tiro especial")
	assert(ball.linear_velocity.length() > 30.0, "Balón debe dispararse a altísima velocidad (>30 m/s)")
	print("  -> Fútbol: Tiro Especial L + Disparo (Gekitotsu Shot, vel > 30) OK")

	player.free()
	ball.free()

	# -- 6. Cargar FightArena.tscn y verificar HUD de Furia --
	var arena_scene = load("res://scenes/FightArena.tscn")
	assert(arena_scene != null, "FightArena.tscn debe cargarse")
	var arena_instance = arena_scene.instance()
	assert(arena_instance != null, "FightArena.tscn debe instanciarse")

	var p_fury_bar = arena_instance.get_node_or_null("CanvasLayer/TopPanel/HBox/PlayerBox/PlayerFuryBar")
	var p_fury_lbl = arena_instance.get_node_or_null("CanvasLayer/TopPanel/HBox/PlayerBox/PlayerFuryLabel")
	assert(p_fury_bar != null, "PlayerFuryBar debe existir en FightArena.tscn")
	assert(p_fury_lbl != null, "PlayerFuryLabel debe existir en FightArena.tscn")
	print("  -> FightArena.tscn: PlayerFuryBar y PlayerFuryLabel OK")
	arena_instance.free()

	# -- 7. Cargar FootballPitch.tscn y verificar HUD de Furia --
	var pitch_scene = load("res://scenes/FootballPitch.tscn")
	assert(pitch_scene != null, "FootballPitch.tscn debe cargarse")
	var pitch_instance = pitch_scene.instance()
	assert(pitch_instance != null, "FootballPitch.tscn debe instanciarse")

	var pitch_fury_bar = pitch_instance.get_node_or_null("PitchHUD/HUDControl/ScorePanel/VBox/FuryContainer/FuryBar")
	var pitch_fury_lbl = pitch_instance.get_node_or_null("PitchHUD/HUDControl/ScorePanel/VBox/FuryContainer/FuryLabel")
	var pitch_fury_not = pitch_instance.get_node_or_null("PitchHUD/HUDControl/FuryNoticeLabel")
	assert(pitch_fury_bar != null, "FuryBar debe existir en FootballPitch.tscn")
	assert(pitch_fury_lbl != null, "FuryLabel debe existir en FootballPitch.tscn")
	assert(pitch_fury_not != null, "FuryNoticeLabel debe existir en FootballPitch.tscn")
	print("  -> FootballPitch.tscn: FuryBar, FuryLabel y FuryNoticeLabel OK")
	pitch_instance.free()

	print("==================================================")
	print("TODAS LAS PRUEBAS DE COMBATE, FURIA Y DISPARO L+TIRO OK.")
	print("==================================================")
	get_tree().quit(0)

func _on_special_attack(flag_ref: Array) -> void:
	flag_ref[0] = true

func _on_special_shot(flag_ref: Array) -> void:
	flag_ref[0] = true
