extends SceneTree

# Test: Verifica que los escudos de los clubes se asignen en SELECT_ACADEMY
# y se limpien en cualquier otra fase narrativa en MainGame.

func _init():
	print("==================================================")
	print("[TEST] Verificando Escudos de Clubes en SELECT_ACADEMY...")
	print("==================================================")

	var gs = root.get_node_or_null("GameSettings")
	if gs == null:
		var gs_script = load("res://scripts/autoload/GameSettings.gd")
		assert(gs_script != null, "GameSettings.gd debe cargar")
		gs = Node.new()
		gs.name = "GameSettings"
		gs.set_script(gs_script)
		root.add_child(gs)

	gs.reset_save()
	gs.player_name = "Ryu"
	gs.story_phase = "SELECT_ACADEMY"

	var main_scene = load("res://scenes/MainGame.tscn")
	assert(main_scene != null, "MainGame.tscn debe cargar")
	var main_node = main_scene.instance()
	root.add_child(main_node)

	gs.story_phase = "SELECT_ACADEMY"
	gs.ending_id = ""
	main_node.update_ui()

	# 1. En SELECT_ACADEMY deben mostrarse los 3 escudos en fila horizontal con expand_icon = true y rect_min_size = (220, 120)
	assert(main_node.choices_hbox is HBoxContainer, "choices_hbox debe ser HBoxContainer")
	assert(main_node.choices_hbox.alignment == BoxContainer.ALIGN_CENTER, "choices_hbox debe estar centrado")
	assert(main_node.choices_hbox.get_constant("separation") == 18, "choices_hbox separation debe ser 18")
	assert(main_node.choices_hbox.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "choices_hbox debe usar Fill + Expand")

	assert(main_node.left_button.visible, "left_button debe ser visible en SELECT_ACADEMY")
	assert(main_node.right_button.visible, "right_button debe ser visible en SELECT_ACADEMY")
	assert(main_node.third_academy_button.visible, "third_academy_button debe ser visible en SELECT_ACADEMY")

	assert(main_node.left_button.icon != null, "left_button debe tener el escudo de Estudiantes de Mérida")
	assert(main_node.right_button.icon != null, "right_button debe tener el escudo de FC Barcelona Juvenil")
	assert(main_node.third_academy_button.icon != null, "third_academy_button debe tener el escudo de Real Madrid Castilla")

	assert(main_node.left_button.expand_icon == true, "left_button.expand_icon debe ser true")
	assert(main_node.right_button.expand_icon == true, "right_button.expand_icon debe ser true")
	assert(main_node.third_academy_button.expand_icon == true, "third_academy_button.expand_icon debe ser true")

	assert(main_node.left_button.rect_min_size == Vector2(220, 120), "left_button.rect_min_size debe ser (220, 120)")
	assert(main_node.right_button.rect_min_size == Vector2(220, 120), "right_button.rect_min_size debe ser (220, 120)")
	assert(main_node.third_academy_button.rect_min_size == Vector2(220, 120), "third_academy_button.rect_min_size debe ser (220, 120)")
	print("  -> SELECT_ACADEMY fila horizontal, escudos, expand_icon y rect_min_size (220, 120) OK")

	# 2. En PROLOGUE_HIT, LEAGUE y ENDING deben limpiarse los iconos, expand_icon = false y rect_min_size = (0, 40)
	for phase in ["PROLOGUE_HIT", "LEAGUE", "MID_J4_OFFER", "AMBUSH_J6_BRAWL", "POST_J8_CHOICE", "FINAL_BRAWL"]:
		gs.story_phase = phase
		gs.ending_id = ""
		main_node.update_ui()
		for btn in [main_node.left_button, main_node.right_button, main_node.third_academy_button]:
			assert(btn.icon == null, "En fase %s el icono debe ser null" % phase)
			assert(btn.expand_icon == false, "En fase %s expand_icon debe ser false" % phase)
			assert(btn.rect_min_size == Vector2(0, 40), "En fase %s rect_min_size debe ser (0, 40)" % phase)

	gs.set_story_ending("ENDING", "GOLDEN_BOY")
	main_node.update_ui()
	for btn in [main_node.left_button, main_node.right_button, main_node.third_academy_button]:
		assert(btn.icon == null, "En ENDING el icono debe ser null")
		assert(btn.expand_icon == false, "En ENDING expand_icon debe ser false")
		assert(btn.rect_min_size == Vector2(0, 40), "En ENDING rect_min_size debe ser (0, 40)")
	print("  -> Limpieza de iconos en todas las demás fases OK")

	main_node.queue_free()
	gs.reset_save()

	print("==================================================")
	print("PRUEBA DE ESCUDOS DE CANTERA EXITOSA.")
	print("==================================================")
	quit(0)
