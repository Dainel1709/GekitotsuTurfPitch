extends Node2D

# Sin anotación de tipo para evitar errores de cast de Godot 3.6 antes del set_script()
onready var player = $Player
onready var rival = $Rival

onready var player_hp_bar: ProgressBar = $CanvasLayer/TopPanel/HBox/PlayerBox/PlayerHPBar
onready var rival_hp_bar: ProgressBar = $CanvasLayer/TopPanel/HBox/RivalBox/RivalHPBar
onready var player_hp_label: Label = $CanvasLayer/TopPanel/HBox/PlayerBox/PlayerHPLabel
onready var rival_hp_label: Label = $CanvasLayer/TopPanel/HBox/RivalBox/RivalHPLabel
onready var message_label: Label = $CanvasLayer/MessageLabel

var fight_over: bool = false

func _ready() -> void:
	# Paso 1: Asegurar que ambos nodos tienen Fighter.gd antes de acceder a sus propiedades
	_setup_fighters()

	# Vincular referencias cruzadas entre luchadores
	player.opponent = rival
	rival.opponent = player

	# Conectar señales de salud y fin de combate
	player.connect("health_changed", self, "_on_player_health_changed")
	player.connect("died", self, "_on_player_died")
	if player.has_signal("defeated"):
		player.connect("defeated", self, "_on_player_died")

	rival.connect("health_changed", self, "_on_rival_health_changed")
	rival.connect("died", self, "_on_rival_died")
	if rival.has_signal("defeated"):
		rival.connect("defeated", self, "_on_rival_died")

	# Inicializar barras de vida
	player_hp_bar.max_value = player.max_health
	player_hp_bar.value = player.current_health
	rival_hp_bar.max_value = rival.max_health
	rival_hp_bar.value = rival.current_health

	_update_labels()

	# Mensaje inicial de inicio de pelea
	message_label.text = "¡PELEA!"
	message_label.modulate = Color(1.0, 0.9, 0.2)
	message_label.visible = true

	yield(get_tree().create_timer(1.2), "timeout")
	if not fight_over:
		message_label.visible = false

func _setup_fighters() -> void:
	# Carga defensiva: si un nodo llega sin el script de Fighter.gd, lo asigna ahora
	var fighter_script = load("res://scripts/Fighter.gd")
	if fighter_script == null:
		push_error("[FightArena] ERROR CRÍTICO: No se pudo cargar res://scripts/Fighter.gd")
		return

	if not player.get_script() or player.get_script() != fighter_script:
		player.set_script(fighter_script)
		print("[FightArena] Fighter.gd asignado a Player por set_script()")

	if not rival.get_script() or rival.get_script() != fighter_script:
		rival.set_script(fighter_script)
		print("[FightArena] Fighter.gd asignado a Rival por set_script()")

	# Verificación de sanidad: el método take_damage debe existir
	if not player.has_method("take_damage"):
		push_error("[FightArena] Player no tiene take_damage tras set_script(); Fighter.gd tiene errores.")
		return
	if not rival.has_method("take_damage"):
		push_error("[FightArena] Rival no tiene take_damage tras set_script(); Fighter.gd tiene errores.")
		return

	# Configurar roles: jugador vs IA
	player.is_player = true
	player.is_ai    = false
	rival.is_player = false
	rival.is_ai     = true
	print("[FightArena] Fighters configurados correctamente: Player(is_player=%s) Rival(is_ai=%s)" % [player.is_player, rival.is_ai])

func _on_player_health_changed(new_hp: float, _max_hp: float) -> void:
	player_hp_bar.value = new_hp
	_update_labels()

func _on_rival_health_changed(new_hp: float, _max_hp: float) -> void:
	rival_hp_bar.value = new_hp
	_update_labels()

func _update_labels() -> void:
	if player_hp_label:
		player_hp_label.text = "%s: %d / %d HP" % [player.fighter_name, int(player.current_health), int(player.max_health)]
	if rival_hp_label:
		rival_hp_label.text = "%s: %d / %d HP" % [rival.fighter_name, int(rival.current_health), int(rival.max_health)]

func _on_player_died() -> void:
	_finish_fight(false)

func _on_rival_died() -> void:
	_finish_fight(true)

func _finish_fight(player_won: bool) -> void:
	if fight_over:
		return
	fight_over = true

	# Mostrar resultado en pantalla
	if player_won:
		message_label.text = "¡GANASTE!"
		message_label.modulate = Color(0.2, 1.0, 0.3)
		print("[FightArena] ¡El jugador ha ganado la pelea callejera!")
	else:
		message_label.text = "PERDISTE"
		message_label.modulate = Color(1.0, 0.25, 0.25)
		print("[FightArena] ¡El jugador ha sido derrotado en la pelea callejera!")

	message_label.visible = true

	# 1. Actualizar estadísticas en C++ mediante GekitotsuStoryManager
	if ClassDB.class_exists("GekitotsuStoryManager"):
		var sm = null
		if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("GekitotsuStoryManager"):
			sm = ClassDB.instantiate("GekitotsuStoryManager")
		elif ClassDB.has_method("can_instance") and ClassDB.can_instance("GekitotsuStoryManager"):
			sm = ClassDB.instance("GekitotsuStoryManager")
		if sm and sm.has_method("apply_fight_result"):
			sm.apply_fight_result(player_won)

	# 2. Actualizar respaldo persistente en el árbol de Godot (fallback GDScript)
	var cur_stats = get_tree().root.get_meta("gtp_stats") if get_tree().root.has_meta("gtp_stats") else {
		"discipline": 0, "combat": 0, "money": 0, "reputation": 0, "day": 1
	}
	if player_won:
		cur_stats["combat"] += 15
		cur_stats["reputation"] += 20
		cur_stats["money"] += 150
	else:
		cur_stats["discipline"] = max(0, cur_stats.get("discipline", 0) - 10)
		cur_stats["reputation"] += 5
	cur_stats["day"] += 1
	get_tree().root.set_meta("gtp_stats", cur_stats)

	# Regresar automáticamente a MainGame.tscn tras 2 segundos
	yield(get_tree().create_timer(2.0), "timeout")
	get_tree().change_scene("res://scenes/MainGame.tscn")
