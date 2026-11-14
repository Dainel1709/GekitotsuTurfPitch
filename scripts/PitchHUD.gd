extends CanvasLayer

onready var score_label = $HUDControl/ScorePanel/ScoreLabel
onready var goal_notice_label = $HUDControl/GoalNoticeLabel
onready var controls_hint = $HUDControl/ControlsHint

var mechanics = null
var match_finished: bool = false
const TARGET_GOALS: int = 3

func _ready() -> void:
	# Buscar referencia a FootballMechanics del jugador
	_resolve_mechanics()
	
	# Conectar con las porterías de la escena para capturar goles
	var rival_goal = get_node_or_null("../RivalGoalArea")
	var player_goal = get_node_or_null("../PlayerGoalArea")
	
	if rival_goal:
		rival_goal.connect("goal_scored", self, "_on_goal_scored")
	if player_goal:
		player_goal.connect("goal_scored", self, "_on_goal_scored")
		
	goal_notice_label.visible = false
	_update_score_display()

func _process(_delta: float) -> void:
	if not match_finished:
		if mechanics == null:
			_resolve_mechanics()
		_update_score_display()

func _resolve_mechanics() -> void:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "mechanics" in p and p.mechanics != null:
			mechanics = p.mechanics
			return
			
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		var node = current_scene.find_node("FootballMechanics", true, false)
		if node:
			mechanics = node
			return

func _update_score_display() -> void:
	var p_score: int = 0
	var opp_score: int = 0
	if mechanics:
		p_score = mechanics.get_player_score()
		opp_score = mechanics.get_opponent_score()
	else:
		var rival_goal = get_node_or_null("../RivalGoalArea")
		var player_goal = get_node_or_null("../PlayerGoalArea")
		if rival_goal and "fallback_player_score" in rival_goal:
			p_score = rival_goal.fallback_player_score
		if player_goal and "fallback_opponent_score" in player_goal:
			opp_score = player_goal.fallback_opponent_score

	score_label.text = "MARCADOR: JUGADOR  [ %d ]  -  [ %d ]  RIVAL\n(Primero a 3 Goles)" % [p_score, opp_score]

func _on_goal_scored(is_rival_goal: bool, player_score: int, opponent_score: int) -> void:
	if match_finished:
		return

	if is_rival_goal:
		goal_notice_label.text = "¡¡¡GOOOOLAZO DEL JUGADOR!!!"
		goal_notice_label.modulate = Color(0.2, 1.0, 0.3)
	else:
		goal_notice_label.text = "¡¡¡GOL DEL RIVAL EN CONTRA!!!"
		goal_notice_label.modulate = Color(1.0, 0.3, 0.2)

	goal_notice_label.visible = true
	_update_score_display()

	if player_score >= TARGET_GOALS or opponent_score >= TARGET_GOALS:
		_finish_match(player_score, opponent_score)
	else:
		yield(get_tree().create_timer(1.6), "timeout")
		if not match_finished:
			goal_notice_label.visible = false

func _finish_match(player_score: int, opponent_score: int) -> void:
	match_finished = true
	
	var is_victory: bool = player_score > opponent_score
	var victory_title: String = "¡VICTORIA DEL CANTERANO!" if is_victory else "¡FINAL DEL ENCUENTRO!"
	goal_notice_label.modulate = Color(1.0, 0.9, 0.1)
	goal_notice_label.text = "%s\nMarcador Final: %d - %d\nActualizando estadísticas en C++ y regresando..." % [
		victory_title, player_score, opponent_score
	]
	goal_notice_label.visible = true

	# 1. Actualizar estadísticas a través de FootballMechanics en C++
	if mechanics and mechanics.has_method("apply_match_result"):
		mechanics.apply_match_result(player_score, opponent_score)

	# 2. Actualizar a través de GekitotsuStoryManager en C++
	if ClassDB.class_exists("GekitotsuStoryManager"):
		var sm = null
		if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("GekitotsuStoryManager"):
			sm = ClassDB.instantiate("GekitotsuStoryManager")
		elif ClassDB.has_method("can_instance") and ClassDB.can_instance("GekitotsuStoryManager"):
			sm = ClassDB.instance("GekitotsuStoryManager")
		if sm and sm.has_method("apply_match_result"):
			sm.apply_match_result(player_score, opponent_score)

	# 3. Sincronizar respaldo persistente en el árbol de Godot
	var cur_stats = get_tree().root.get_meta("gtp_stats") if get_tree().root.has_meta("gtp_stats") else {
		"discipline": 0, "combat": 0, "money": 0, "reputation": 0, "day": 1
	}
	if is_victory:
		cur_stats["discipline"] += 15
		cur_stats["combat"] += 5
		cur_stats["money"] += 250
	else:
		cur_stats["reputation"] += 10
		cur_stats["combat"] += 5
		cur_stats["money"] += 50
	cur_stats["day"] += 1
	get_tree().root.set_meta("gtp_stats", cur_stats)

	print("[PitchHUD] Partido finalizado (3 goles). Estadísticas C++ actualizadas. Transicionando a MainGame...")
	yield(get_tree().create_timer(2.2), "timeout")
	get_tree().change_scene("res://scenes/MainGame.tscn")
