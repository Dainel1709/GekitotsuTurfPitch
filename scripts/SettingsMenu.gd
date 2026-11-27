extends CanvasLayer

signal settings_closed

onready var modal_root = $ModalRoot
onready var scheme_button = $ModalRoot/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SchemeButton
onready var scheme_desc_label = $ModalRoot/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SchemeDescLabel
onready var music_value_label = $ModalRoot/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MusicHBox/MusicValueLabel
onready var music_slider = $ModalRoot/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MusicSlider
onready var sfx_value_label = $ModalRoot/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SfxHBox/SfxValueLabel
onready var sfx_slider = $ModalRoot/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SfxSlider
onready var fullscreen_check = $ModalRoot/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/FullscreenCheck
onready var save_close_button = $ModalRoot/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SaveCloseButton

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	if modal_root:
		modal_root.visible = false

	if scheme_button:
		scheme_button.connect("pressed", self, "_on_scheme_pressed")
	if music_slider:
		music_slider.connect("value_changed", self, "_on_music_changed")
	if sfx_slider:
		sfx_slider.connect("value_changed", self, "_on_sfx_changed")
	if fullscreen_check:
		fullscreen_check.connect("toggled", self, "_on_fullscreen_toggled")
	if save_close_button:
		save_close_button.connect("pressed", self, "close_and_save")

	_setup_focus_neighbours()
	_sync_ui_from_settings()

func _input(event) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		close_and_save()

func is_open() -> bool:
	return modal_root != null and modal_root.visible

func open_menu() -> void:
	_sync_ui_from_settings()
	if modal_root:
		modal_root.visible = true
	if scheme_button:
		scheme_button.grab_focus()

func close_and_save() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		if gs.has_method("apply_audio_and_display_settings"):
			gs.apply_audio_and_display_settings()
		if gs.has_method("save_progress"):
			gs.save_progress({})
	if modal_root:
		modal_root.visible = false
	emit_signal("settings_closed")

func _sync_ui_from_settings() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		return

	_update_scheme_labels()

	var m_pct = int(round(clamp(gs.music_volume, 0.0, 1.0) * 100.0))
	var s_pct = int(round(clamp(gs.sfx_volume, 0.0, 1.0) * 100.0))

	if music_slider:
		music_slider.value = m_pct
	if music_value_label:
		music_value_label.text = "%d%%" % m_pct

	if sfx_slider:
		sfx_slider.value = s_pct
	if sfx_value_label:
		sfx_value_label.text = "%d%%" % s_pct

	if fullscreen_check:
		fullscreen_check.pressed = bool(gs.fullscreen_enabled)

func _update_scheme_labels() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		return
	var is_pes = (gs.get_control_scheme() == gs.ControlScheme.PES_ALTERNATIVE)
	if scheme_button:
		scheme_button.text = "Esquema: Alternativo (PES)" if is_pes else "Esquema: Clásico (FIFA)"
	if scheme_desc_label:
		if is_pes:
			scheme_desc_label.text = "Disparo: □ (Cuadrado) | Centro: O (Círculo) | Pase: X (Cruz)"
		else:
			scheme_desc_label.text = "Disparo: O (Círculo) | Centro: □ (Cuadrado) | Pase: X (Cruz)"

func _on_scheme_pressed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and gs.has_method("toggle_control_scheme"):
		gs.toggle_control_scheme()
	_update_scheme_labels()

func _on_music_changed(val: float) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.music_volume = clamp(val / 100.0, 0.0, 1.0)
		if gs.has_method("apply_audio_and_display_settings"):
			gs.apply_audio_and_display_settings()
	if music_value_label:
		music_value_label.text = "%d%%" % int(round(val))

func _on_sfx_changed(val: float) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.sfx_volume = clamp(val / 100.0, 0.0, 1.0)
		if gs.has_method("apply_audio_and_display_settings"):
			gs.apply_audio_and_display_settings()
	if sfx_value_label:
		sfx_value_label.text = "%d%%" % int(round(val))

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.fullscreen_enabled = button_pressed
		if gs.has_method("apply_audio_and_display_settings"):
			gs.apply_audio_and_display_settings()

func _setup_focus_neighbours() -> void:
	var controls = []
	for c in [scheme_button, music_slider, sfx_slider, fullscreen_check, save_close_button]:
		if c:
			controls.append(c)
	var count = controls.size()
	for i in range(count):
		var cur = controls[i]
		cur.focus_neighbour_top = controls[(i - 1 + count) % count].get_path()
		cur.focus_neighbour_bottom = controls[(i + 1) % count].get_path()
