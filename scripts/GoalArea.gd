extends Area

class_name GoalArea

# Si es true, representa la portería rival (anotar aquí otorga punto al jugador)
# Si es false, representa la portería propia (anotar aquí otorga punto al rival)
export(bool) var is_rival_goal: bool = true
export(String) var goal_name: String = "Portería Rival"
export(Vector3) var reset_point: Vector3 = Vector3(0.0, 0.25, 0.0)

# Señal emitida cuando ocurre un gol: goal_scored(is_rival_goal, player_score, opponent_score)
signal goal_scored(is_rival_goal, player_score, opponent_score)

# Variables de respaldo local para marcador en caso de no disponer de la instancia C++
var fallback_player_score: int = 0
var fallback_opponent_score: int = 0

func _ready() -> void:
	# Escuchar la señal body_entered del Area
	connect("body_entered", self, "_on_body_entered")

func _on_body_entered(body: Node) -> void:
	# Verificar si el cuerpo que ingresa es el FootballBall
	if body.is_in_group("ball") or body is FootballBall or body.name == "FootballBall":
		_process_goal(body)

func _process_goal(ball: Node) -> void:
	var mechanics = _find_mechanics()
	var player_score: int = 0
	var opponent_score: int = 0

	if is_rival_goal:
		print("=========================================")
		print("[GOLAZO] ¡GOL DEL JUGADOR en la " + goal_name + "! (Porteria Rival)")
		if mechanics and mechanics.has_method("score_goal_player"):
			mechanics.score_goal_player()
			player_score = mechanics.get_player_score()
			opponent_score = mechanics.get_opponent_score()
		else:
			fallback_player_score += 1
			player_score = fallback_player_score
			opponent_score = fallback_opponent_score
		print("[MARCADOR C++] Jugador: " + str(player_score) + " | Rival: " + str(opponent_score))
		print("=========================================")
	else:
		print("=========================================")
		print("[GOL RIVAL] ¡Gol recibido en la " + goal_name + "! (Porteria Propia)")
		if mechanics and mechanics.has_method("score_goal_opponent"):
			mechanics.score_goal_opponent()
			player_score = mechanics.get_player_score()
			opponent_score = mechanics.get_opponent_score()
		else:
			fallback_opponent_score += 1
			player_score = fallback_player_score
			opponent_score = fallback_opponent_score
		print("[MARCADOR C++] Jugador: " + str(player_score) + " | Rival: " + str(opponent_score))
		print("=========================================")

	# Emitir señal para notificar a la UI u otros controladores
	emit_signal("goal_scored", is_rival_goal, player_score, opponent_score)

	# Reiniciar posición del balón al centro del campo (reseteando velocidad lineal y angular)
	if ball.has_method("reset_ball"):
		ball.reset_ball(reset_point)
	else:
		if ball is RigidBody:
			ball.linear_velocity = Vector3.ZERO
			ball.angular_velocity = Vector3.ZERO
		ball.global_transform.origin = reset_point

	# Reiniciar posición de todos los actores (Jugador, IA)
	_reset_all_actors()

func _find_mechanics() -> Object:
	# 1. Buscar en nodos del grupo "player" (donde Player.gd instancia FootballMechanics)
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "mechanics" in p and p.mechanics != null:
			return p.mechanics

	# 2. Buscar en la escena activa un nodo llamado "FootballMechanics"
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		var mechanics_node = current_scene.find_node("FootballMechanics", true, false)
		if mechanics_node:
			return mechanics_node

	# 3. Fallback de instanciación dinámica vía ClassDB si está registrado
	if ClassDB.class_exists("FootballMechanics"):
		if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("FootballMechanics"):
			return ClassDB.instantiate("FootballMechanics")
		elif ClassDB.has_method("can_instance") and ClassDB.can_instance("FootballMechanics"):
			return ClassDB.instance("FootballMechanics")

	return null

func _reset_all_actors() -> void:
	var tree = get_tree()
	if not tree:
		return

	# Reiniciar jugador principal
	var players = tree.get_nodes_in_group("player")
	for p in players:
		if p is Spatial:
			if "is_dribbling" in p:
				p.is_dribbling = false
			if "is_ball_controlled" in p:
				p.is_ball_controlled = false
			if "kick_cooldown" in p:
				p.kick_cooldown = 0.0
			if "tackle_cooldown" in p:
				p.tackle_cooldown = 0.0
			# Reposicionar al jugador en su posición inicial
			if p.has_method("get") and p.get("initial_position") != null:
				p.global_transform.origin = p.initial_position
			else:
				p.global_transform.origin = Vector3(0.0, 0.8, 3.5)
		print("[GoalArea] Jugador principal reposicionado tras gol.")

	# Reiniciar IA: compañeros, rivales y porteros
	var ai_groups = ["teammates", "opponents", "goalkeepers"]
	for grp in ai_groups:
		var nodes = tree.get_nodes_in_group(grp)
		for ai in nodes:
			if ai.has_method("reset_position"):
				ai.reset_position()
			elif ai is Spatial:
				if "initial_position" in ai:
					ai.global_transform.origin = ai.initial_position
				if "has_ball" in ai:
					ai.has_ball = false
				if "is_dribbling" in ai:
					ai.is_dribbling = false
				if "velocity" in ai:
					ai.velocity = Vector3.ZERO
	print("[GoalArea] Todas las posiciones de IA reiniciadas tras gol.")
