extends Control

onready var start_button = $CenterContainer/CardPanel/MarginContainer/VBoxContainer/StartButton
onready var continue_button = $CenterContainer/CardPanel/MarginContainer/VBoxContainer/ContinueButton
onready var admin_button = $CenterContainer/CardPanel/MarginContainer/VBoxContainer/AdminButton
onready var config_button = $ConfigButton if has_node("ConfigButton") else null

var admin_overlay = null

func _ready() -> void:
	if start_button:
		start_button.connect("pressed", self, "_on_StartButton_pressed")
	if continue_button:
		continue_button.connect("pressed", self, "_on_ContinueButton_pressed")
	if admin_button:
		admin_button.visible = false
		admin_button.connect("pressed", self, "_on_AdminButton_pressed")
	if config_button:
		config_button.connect("pressed", self, "_on_ConfigButton_pressed")

	_refresh_continue_state()
	_setup_admin_overlay()
	_setup_focus()

func _input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == KEY_ESCAPE:
			var so = get_node_or_null("/root/SettingsOverlay")
			if so and not so.is_open():
				_on_ConfigButton_pressed()

func _refresh_continue_state() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	var save_exists = gs.has_save() if (gs and gs.has_method("has_save")) else false
	if continue_button:
		continue_button.visible = save_exists
		continue_button.disabled = not save_exists

func _setup_admin_overlay() -> void:
	var admin_script = load("res://scripts/AdminStoryTree.gd")
	if admin_script:
		admin_overlay = Control.new()
		admin_overlay.set_script(admin_script)
		admin_overlay.name = "AdminOverlay"
		admin_overlay.visible = false
		add_child(admin_overlay)

func _toggle_admin_overlay() -> void:
	if admin_overlay:
		admin_overlay.visible = not admin_overlay.visible
		if admin_overlay.visible and admin_overlay.has_method("refresh_tree"):
			admin_overlay.refresh_tree()

func _on_StartButton_pressed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		if gs.has_method("reset_save"):
			gs.reset_save()
		gs.story_phase = "CREATE_PLAYER"
		gs.ending_id = ""
		if gs.has_method("save_progress"):
			gs.save_progress({})
	get_tree().root.set_meta("gtp_stats", {
		"discipline": 0,
		"combat": 0,
		"money": 0,
		"reputation": 0,
		"matchday": 1,
		"league_wins": 0,
		"league_losses": 0,
		"day": 1
	})
	get_tree().change_scene("res://scenes/MainGame.tscn")

func _on_ContinueButton_pressed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("load_progress"):
		gs.load_progress()
	get_tree().change_scene("res://scenes/MainGame.tscn")

func _on_AdminButton_pressed() -> void:
	_toggle_admin_overlay()

func _on_ConfigButton_pressed() -> void:
	var so = get_node_or_null("/root/SettingsOverlay")
	if so and so.has_method("open_menu"):
		so.open_menu()

func update_ui() -> void:
	_refresh_continue_state()

func _setup_focus() -> void:
	var btns = []
	if start_button and start_button.visible:
		btns.append(start_button)
	if continue_button and continue_button.visible and not continue_button.disabled:
		btns.append(continue_button)
	if admin_button and admin_button.visible:
		btns.append(admin_button)

	var count = btns.size()
	for i in range(count):
		var b = btns[i]
		b.focus_neighbour_top = btns[(i - 1 + count) % count].get_path()
		b.focus_neighbour_bottom = btns[(i + 1) % count].get_path()

	if count > 0:
		btns[0].grab_focus()
