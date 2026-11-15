extends SceneTree

func _init():
	print("==================================================")
	print("[TEST] Verificando Fighter.gd y FightArena.tscn...")
	print("==================================================")

	# -- 1. Parser / carga de Fighter.gd --
	var fighter_script = load("res://scripts/Fighter.gd")
	assert(fighter_script != null, "Fighter.gd debe cargarse sin errores de parser")
	print("  -> Fighter.gd carga sin Parser Error             OK")

	# -- 2. Instanciar un Fighter directamente --
	var dummy: KinematicBody2D = KinematicBody2D.new()
	dummy.set_script(fighter_script)
	root.add_child(dummy)   # necesario para que _ready() se ejecute

	# Esperar un frame para que _ready() se lance
	yield(get_tree(), "idle_frame")

	assert("is_player"     in dummy, "is_player debe existir")
	assert("health"        in dummy, "health debe existir")
	assert("attack_damage" in dummy, "attack_damage debe existir")
	assert("heavy_damage"  in dummy, "heavy_damage debe existir")
	assert("is_blocking"   in dummy, "is_blocking debe existir")
	assert(dummy.has_method("take_damage"),    "take_damage debe existir")
	assert(dummy.has_method("_execute_punch"), "_execute_punch debe existir")
	assert(dummy.has_signal("died"),           "señal died debe existir")
	assert(dummy.has_signal("defeated"),       "señal defeated debe existir")
	assert(dummy.has_signal("health_changed"), "señal health_changed debe existir")
	print("  -> Propiedades y señales del Fighter OK           OK")

	# is_player setget: al poner is_player=true, is_ai debe ser false
	dummy.is_player = true
	assert(dummy.is_ai  == false, "is_ai debe ser false al asignar is_player=true")
	dummy.is_player = false
	assert(dummy.is_ai  == true,  "is_ai debe ser true al asignar is_player=false")
	print("  -> Setget is_player <-> is_ai funciona            OK")

	# take_damage reduce salud
	dummy.is_player   = true
	dummy.is_ai       = false
	dummy.max_health  = 100.0
	dummy.current_health = 100.0
	dummy.take_damage(30.0)
	assert(dummy.current_health == 70.0, "Salud debe ser 70 tras recibir 30 de daño")
	print("  -> take_damage resta salud correctamente          OK")

	# Bloqueo reduce daño
	dummy.current_health = 100.0
	dummy.is_blocking    = true
	dummy.take_damage(40.0)
	# block_dmg_factor = 0.25 → 40*0.25 = 10 → salud = 90
	assert(dummy.current_health == 90.0,
		"Con bloqueo, 40 de daño debe reducirse a 10 (factor 0.25)")
	dummy.is_blocking = false
	print("  -> Bloqueo reduce daño al 25%%                     OK")

	dummy.queue_free()

	# -- 3. Cargar FightArena.tscn y verificar Player / Rival --
	var scene = load("res://scenes/FightArena.tscn")
	assert(scene != null, "FightArena.tscn debe cargarse")
	var instance = scene.instance()
	assert(instance != null, "FightArena.tscn debe instanciarse")

	var player_node = instance.get_node_or_null("Player")
	var rival_node  = instance.get_node_or_null("Rival")
	assert(player_node != null, "Nodo Player debe existir")
	assert(rival_node  != null, "Nodo Rival debe existir")
	assert(player_node.has_method("take_damage"), "Player.take_damage debe existir")
	assert(rival_node.has_method("take_damage"),  "Rival.take_damage debe existir")
	assert("is_player"    in player_node, "Player.is_player debe existir")
	assert("heavy_damage" in player_node, "Player.heavy_damage debe existir")
	assert("is_blocking"  in player_node, "Player.is_blocking debe existir")
	print("  -> FightArena.tscn: Player y Rival tienen Fighter.gd OK")

	instance.free()

	print("==================================================")
	print("TODAS LAS PRUEBAS DE FIGHTER Y FIGHT ARENA OK.")
	print("==================================================")
	quit(0)
