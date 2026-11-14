extends Control

func _ready():
	$VBoxContainer/StartButton.connect("pressed", self, "_on_StartButton_pressed")

func _on_StartButton_pressed():
	get_tree().change_scene("res://scenes/MainGame.tscn")
