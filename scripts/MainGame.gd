extends Control

onready var description_label = $VBoxContainer/DescriptionLabel
onready var left_button = $VBoxContainer/LeftButton
onready var right_button = $VBoxContainer/RightButton
onready var stats_label = $StatsLabel

var story_manager = null

func _ready() -> void:
	left_button.connect("pressed", self, "_on_left_choice_pressed")
	right_button.connect("pressed", self, "_on_right_choice_pressed")
	
	# Enlace dinámico con la clase C++ GekitotsuStoryManager expuesta por GDExtension
	if ClassDB.class_exists("GekitotsuStoryManager"):
		if ClassDB.has_method("can_instantiate") and ClassDB.can_instantiate("GekitotsuStoryManager"):
			story_manager = ClassDB.instantiate("GekitotsuStoryManager")
		elif ClassDB.has_method("can_instance") and ClassDB.can_instance("GekitotsuStoryManager"):
			story_manager = ClassDB.instance("GekitotsuStoryManager")
		
		if story_manager:
			add_child(story_manager)

	update_ui()

func update_ui() -> void:
	if story_manager:
		# Métodos clave expuestos desde DeSiGNARStoryTree en C++:
		var title: String = story_manager.get_current_title()
		var prompt: String = story_manager.get_current_prompt()
		var discipline: int = story_manager.get_discipline_points()
		var reputation: int = story_manager.get_street_reputation()
		var is_over: bool = story_manager.is_career_over()

		description_label.text = "[%s]\n%s" % [title, prompt]
		stats_label.text = "Disciplina Deportiva: %d | Reputación en Asfalto: %d" % [discipline, reputation]

		if is_over:
			left_button.visible = false
			right_button.visible = false
			description_label.text += "\n\n*** ¡FIN DE LA CARRERA / DESENLACE A LOS 18 AÑOS ALCANZADO! ***"
		else:
			left_button.text = "Elegir Club / Disciplina (+Disciplina Deportiva)"
			right_button.text = "Elegir Calle / Asfalto (+Reputación Callejera)"
	else:
		description_label.text = "La Encrucijada de la Cantera:\n¿Entrenamiento profesional o carreras clandestinas?"
		left_button.text = "Quedarse a entrenar (+Disciplina)"
		right_button.text = "Asistir a la carrera (+Reputación)"
		stats_label.text = "Modo Demo UI (Esperando enlace nativo GDExtension)"

func _on_left_choice_pressed() -> void:
	if story_manager:
		story_manager.choose_discipline()
	update_ui()

func _on_right_choice_pressed() -> void:
	if story_manager:
		story_manager.choose_street()
	update_ui()
