extends Control

func _ready():
	var start_button = $VBoxContainer/StartButton
	start_button.connect("pressed", self, "_on_StartButton_pressed")
	start_button.grab_focus()

func _on_StartButton_pressed():
	get_tree().change_scene("res://scenes/MainGame.tscn")
