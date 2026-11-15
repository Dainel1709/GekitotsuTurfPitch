extends SceneTree

func _init():
	print("==================================================")
	print("[TEST] Verificando carga de FightArena.tscn...")
	print("==================================================")

	# 1. Cargar escena
	var scene = load("res://scenes/FightArena.tscn")
	assert(scene != null, "FightArena.tscn debe existir y cargar correctamente")

	# 2. Instanciar sin añadir al árbol para prueba básica de script
	var instance = scene.instance()
	assert(instance != null, "FightArena.tscn debe poder instanciarse")

	# 3. Verificar nodos Player y Rival presentes
	var player_node = instance.get_node_or_null("Player")
	var rival_node  = instance.get_node_or_null("Rival")
	assert(player_node != null, "El nodo Player debe existir en FightArena.tscn")
	assert(rival_node  != null, "El nodo Rival debe existir en FightArena.tscn")

	# 4. Verificar que Fighter.gd está asignado (método take_damage disponible)
	assert(player_node.has_method("take_damage"), "Player debe tener take_damage (Fighter.gd asignado)")
	assert(rival_node.has_method("take_damage"),  "Rival debe tener take_damage (Fighter.gd asignado)")

	# 5. Verificar propiedad is_player (la que causaba el crash original)
	assert("is_player" in player_node, "Player debe exponer la propiedad is_player")
	assert("is_player" in rival_node,  "Rival debe exponer la propiedad is_player")

	# 6. Verificar health y attack_damage
	assert("health" in player_node, "Player debe tener propiedad health")
	assert("attack_damage" in player_node, "Player debe tener propiedad attack_damage")

	# 7. Verificar señales clave
	assert(player_node.has_signal("died"),    "Player debe tener señal 'died'")
	assert(player_node.has_signal("defeated"),"Player debe tener señal 'defeated'")
	assert(player_node.has_signal("health_changed"), "Player debe tener señal 'health_changed'")

	print("  -> FightArena.tscn carga sin errores               OK")
	print("  -> Nodos Player y Rival presentes                  OK")
	print("  -> Player y Rival tienen Fighter.gd (take_damage)  OK")
	print("  -> Propiedad is_player disponible en ambos         OK")
	print("  -> Propiedades health y attack_damage presentes     OK")
	print("  -> Señales died/defeated/health_changed presentes  OK")
	print("==================================================")
	print("TODAS LAS PRUEBAS DE FIGHT ARENA PASARON.")
	print("==================================================")

	instance.free()
	quit(0)
