@tool
extends EditorPlugin

var show_creator_dock

func _enter_tree():
	add_custom_type("MPFShowCreator", "Sprite2D", preload("classes/MPFShowCreator.gd"), null)
	add_custom_type("MPFShowLight", "Node2D", preload("classes/MPFShowLight.gd"), null)
	show_creator_dock = preload("res://addons/mpf-show-creator/mpf_show_creator_dock.tscn").instantiate()
	add_control_to_bottom_panel(show_creator_dock, "MPF Show Creator")

func _exit_tree():
	remove_custom_type("MPFShowCreator")
	remove_custom_type("MPFShowLight")
	remove_control_from_bottom_panel(show_creator_dock)