extends Node2D

signal brawl_finished(player_won)

var is_pitch_brawl: bool = false

# Sin anotación de tipo para evitar errores de cast de Godot 3.6 antes del set_script()
onready var player = $Player
onready var rival = $Rival

onready var player_hp_bar: ProgressBar = $CanvasLayer/TopPanel/HBox/PlayerBox/PlayerHPBar
onready var rival_hp_bar: ProgressBar = $CanvasLayer/TopPanel/HBox/RivalBox/RivalHPBar
onready var player_hp_label: Label = $CanvasLayer/TopPanel/HBox/PlayerBox/PlayerHPLabel
onready var rival_hp_label: Label = $CanvasLayer/TopPanel/HBox/RivalBox/RivalHPLabel
onready var player_fury_bar: ProgressBar = $CanvasLayer/TopPanel/HBox/PlayerBox/PlayerFuryBar if has_node("CanvasLayer/TopPanel/HBox/PlayerBox/PlayerFuryBar") else null
onready var player_fury_label: Label = $CanvasLayer/TopPanel/HBox/PlayerBox/PlayerFuryLabel if has_node("CanvasLayer/TopPanel/HBox/PlayerBox/PlayerFuryLabel") else null
onready var message_label: Label = $CanvasLayer/MessageLabel
onready var combo_label: Label = $CanvasLayer/ComboLabel if has_node("CanvasLayer/ComboLabel") else null
onready var camera = $Camera2D if has_node("Camera2D") else null

var fight_over: bool = false
var shake_intensity: float = 0.0
var shake_decay: float = 18.0
var _combo_hide_timer: float = 0.0

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

	# Conectar señales de combo arcade y sacudida de impacto
	if player.has_signal("combo_updated"):
		player.connect("combo_updated", self, "_on_fighter_combo_updated")
	if player.has_signal("combo_broken"):
		player.connect("combo_broken", self, "_on_fighter_combo_broken")
	if player.has_signal("shake_requested"):
		player.connect("shake_requested", self, "trigger_camera_shake")

	if rival.has_signal("combo_updated"):
		rival.connect("combo_updated", self, "_on_fighter_combo_updated")
	if rival.has_signal("combo_broken"):
		rival.connect("combo_broken", self, "_on_fighter_combo_broken")
	if rival.has_signal("shake_requested"):
		rival.connect("shake_requested", self, "trigger_camera_shake")

	# Inicializar barras de vida
	player_hp_bar.max_value = player.max_health
	player_hp_bar.value     = player.current_health
	rival_hp_bar.max_value  = rival.max_health
	rival_hp_bar.value       = rival.current_health

	# Leer RPG Stats (Combate y Disciplina) desde backend C++ o metadatos
	var combat: int = 0
	var discipline: int = 0
	if ClassDB.class_exists("GekitotsuStoryManager"):
		var sm = null
		if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("GekitotsuStoryManager"):
			sm = ClassDB.instantiate("GekitotsuStoryManager")
		elif ClassDB.has_method("can_instance") and ClassDB.can_instance("GekitotsuStoryManager"):
			sm = ClassDB.instance("GekitotsuStoryManager")
		if sm:
			if sm.has_method("get_combat_technique"):
				combat = sm.get_combat_technique()
			if sm.has_method("get_discipline_points"):
				discipline = sm.get_discipline_points()
	elif get_tree() and get_tree().root and get_tree().root.has_meta("gtp_stats"):
		var stats = get_tree().root.get_meta("gtp_stats")
		combat = stats.get("combat", 0)
		discipline = stats.get("discipline", 0)

	if player and player.has_method("apply_rpg_stats"):
		player.apply_rpg_stats(combat, discipline)

	if player.has_signal("fury_changed"):
		player.connect("fury_changed", self, "_on_player_fury_changed")

	if player_fury_bar:
		player_fury_bar.max_value = player.max_fury
		player_fury_bar.value     = player.fury
	_update_fury_ui(player.fury if "fury" in player else 0.0)

	_update_labels()

	# Configurar modo duelo en cancha si está activado
	if is_pitch_brawl:
		_setup_pitch_brawl_mode()

	# Ocultar combo inicialmente
	if combo_label:
		combo_label.visible = false

	# Mensaje inicial de inicio de pelea
	if is_pitch_brawl:
		message_label.text = "¡DUELO EN LA CANCHA!"
	else:
		message_label.text = "¡PELEA!"
	message_label.modulate = Color(1.0, 0.9, 0.2)
	message_label.visible = true

	yield(get_tree().create_timer(1.2, true), "timeout")
	if not fight_over:
		message_label.visible = false

func _process(delta: float) -> void:
	# Sacudida sutil de cámara en impacto (100% compatible con GLES2)
	if camera:
		if shake_intensity > 0.1:
			camera.offset = Vector2(
				rand_range(-shake_intensity, shake_intensity),
				rand_range(-shake_intensity, shake_intensity)
			)
			shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
		elif camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO
			shake_intensity = 0.0

	# Temporizador para ocultar combo_label
	if _combo_hide_timer > 0.0:
		_combo_hide_timer -= delta
		if _combo_hide_timer <= 0.0 and combo_label and not fight_over:
			combo_label.visible = false

func trigger_camera_shake(intensity: float = 5.0) -> void:
	shake_intensity = max(shake_intensity, intensity)

func _on_fighter_combo_updated(_fighter, step: int, text: String) -> void:
	if combo_label and not fight_over:
		combo_label.text = text
		combo_label.visible = true
		_combo_hide_timer = 1.0

		if step == 6:
			combo_label.modulate = Color(1.0, 0.25, 0.1) # Fuego/Naranja brillante para 6-HIT COMBO!
		elif step >= 4:
			combo_label.modulate = Color(1.0, 0.85, 0.15) # Oro arcade
		elif step >= 2:
			combo_label.modulate = Color(0.2, 0.9, 1.0) # Celeste eléctrico
		else:
			combo_label.modulate = Color(0.3, 1.0, 0.4) # Verde

func _on_fighter_combo_broken() -> void:
	_combo_hide_timer = 0.2

func _on_player_fury_changed(new_fury: float, _max_fury: float) -> void:
	if player_fury_bar:
		player_fury_bar.value = new_fury
	_update_fury_ui(new_fury)

func _update_fury_ui(fury_val: float) -> void:
	if player_fury_label:
		if fury_val >= 100.0:
			player_fury_label.text = "¡FURIA LISTA! (A+X / Z+S)"
			player_fury_label.modulate = Color(1.0, 0.35, 0.1)
		else:
			player_fury_label.text = "Furia: %d%%" % int(fury_val)
			player_fury_label.modulate = Color(0.9, 0.8, 0.3)

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
		print("[FightArena] ¡El jugador ha ganado el duelo!")
	else:
		message_label.text = "PERDISTE"
		message_label.modulate = Color(1.0, 0.25, 0.25)
		print("[FightArena] ¡El jugador ha sido derrotado en el duelo!")

	message_label.visible = true

	if is_pitch_brawl:
		# Esperar 1.5s compatible con pausa
		yield(get_tree().create_timer(1.5, true), "timeout")

		# Actualizar estadísticas en C++ (+combate y -disciplina si Ryu gana; -disciplina si pierde)
		if ClassDB.class_exists("GekitotsuStoryManager"):
			var sm = null
			if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("GekitotsuStoryManager"):
				sm = ClassDB.instantiate("GekitotsuStoryManager")
			elif ClassDB.has_method("can_instance") and ClassDB.can_instance("GekitotsuStoryManager"):
				sm = ClassDB.instance("GekitotsuStoryManager")
			if sm:
				if sm.has_method("apply_fight_result"):
					sm.apply_fight_result(player_won)
				if player_won:
					if sm.has_method("add_combat_technique"):
						sm.add_combat_technique(10)
					if sm.has_method("add_sports_discipline"):
						sm.add_sports_discipline(-8)
				else:
					if sm.has_method("add_sports_discipline"):
						sm.add_sports_discipline(-12)

		# Respaldo persistente en meta
		if get_tree() and get_tree().root:
			var cur_stats = get_tree().root.get_meta("gtp_stats") if get_tree().root.has_meta("gtp_stats") else {
				"discipline": 0, "combat": 0, "money": 0, "reputation": 0, "day": 1
			}
			if player_won:
				cur_stats["combat"] = cur_stats.get("combat", 0) + 12
				cur_stats["discipline"] = max(0, cur_stats.get("discipline", 0) - 8)
			else:
				cur_stats["discipline"] = max(0, cur_stats.get("discipline", 0) - 12)
			get_tree().root.set_meta("gtp_stats", cur_stats)

		emit_signal("brawl_finished", player_won)
		# Retorno exacto al partido: ¡NO cambiar de escena a MainGame.tscn!
		return

	# Si NO es duelo en cancha (pelea callejera independiente):
	if ClassDB.class_exists("GekitotsuStoryManager"):
		var sm = null
		if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("GekitotsuStoryManager"):
			sm = ClassDB.instantiate("GekitotsuStoryManager")
		elif ClassDB.has_method("can_instance") and ClassDB.can_instance("GekitotsuStoryManager"):
			sm = ClassDB.instance("GekitotsuStoryManager")
		if sm and sm.has_method("apply_fight_result"):
			sm.apply_fight_result(player_won)

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

func _setup_pitch_brawl_mode() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS

	# Ocultar elementos visuales opacos de fondo y suelo del callejón (manteniendo intactas las colisiones del suelo y límites)
	var env = get_node_or_null("Environment")
	if env:
		for child in env.get_children():
			if child is ColorRect:
				child.visible = false

	# Capa 25 para el HUD interno
	var canvas = get_node_or_null("CanvasLayer")
	if canvas:
		canvas.layer = 25
		var banner = canvas.get_node_or_null("BrawlBanner")
		if not banner:
			banner = Label.new()
			banner.name = "BrawlBanner"
			banner.anchor_left = 0.5
			banner.anchor_right = 0.5
			banner.margin_left = -250.0
			banner.margin_top = 8.0
			banner.margin_right = 250.0
			banner.margin_bottom = 36.0
			banner.text = "¡DUELO EN LA CANCHA!"
			banner.align = Label.ALIGN_CENTER
			banner.valign = Label.VALIGN_CENTER
			banner.modulate = Color(1.0, 0.85, 0.1)
			canvas.add_child(banner)
		else:
			banner.text = "¡DUELO EN LA CANCHA!"
			banner.visible = true

	# Asegurar que todos los descendientes procesen con el árbol en pausa
	_ensure_pause_process(self)

func _ensure_pause_process(node: Node) -> void:
	node.pause_mode = Node.PAUSE_MODE_PROCESS
	for child in node.get_children():
		_ensure_pause_process(child)
