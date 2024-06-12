@tool
extends Control

const CONFIG_PATH = "user://mpf_show_creator.cfg"
const DEFAULT_SHOW =  "res://show_creator.tscn"

var config: ConfigFile
var lights: = {}

@onready var button_mpf_config = $VBoxContainer/container_mpf_config/button_mpf_config
@onready var edit_mpf_config = $VBoxContainer/container_mpf_config/edit_mpf_config
@onready var button_show_scene = $VBoxContainer/container_show_scene/button_show_scene
@onready var edit_show_scene = $VBoxContainer/container_show_scene/edit_show_scene

@onready var button_generate_lights = $VBoxContainer/button_generate_lights
@onready var button_generate_scene = $VBoxContainer/button_generate_scene

func _ready():
	button_mpf_config.pressed.connect(self._select_mpf_config)
	button_show_scene.pressed.connect(self._select_show_scene)
	button_generate_lights.pressed.connect(self._generate_lights)
	button_generate_scene.pressed.connect(self._generate_scene)
	edit_mpf_config.text_submitted.connect(self._save_mpf_config)
	edit_show_scene.text_submitted.connect(self._save_show_scene)

	self.config = ConfigFile.new()
	var err = self.config.load(CONFIG_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		printerr("Error loading config file: %s" % err)

	if self.config.has_section("show_creator"):
		if self.config.has_section_key("show_creator", "mpf_config"):
			edit_mpf_config.text = self.config.get_value("show_creator", "mpf_config")
			self.parse_mpf_config()
		if self.config.has_section_key("show_creator", "show_scene"):
			edit_show_scene.text = self.config.get_value("show_creator", "show_scene")

	self._render_generate_button()

func _generate_lights(lights_node: Node2D = null):
	if self.lights.is_empty():
		printerr("No light configuration found.")
		return
	var scene = load(edit_show_scene.text).instantiate()
	# Look for a lights child node
	if not lights_node:
		lights_node = scene.get_node_or_null("lights")
	if not lights_node:
		lights_node = Node2D.new()
		lights_node.name = "lights"
		scene.add_child(lights_node)
		lights_node.owner = scene
	for l in self.lights.keys():
		var light_child = scene.find_child(l)
		if not light_child:
			light_child = MPFShowLight.new()
			light_child.name = l
			lights_node.add_child(light_child)
			light_child.owner = scene
		else:
			print("Found light '%s' in scene!")
		if not self.lights[l]["tags"]:
			for t in self.lights[l].tags:
				light_child.add_to_group(t, true)

	var pckscene = PackedScene.new()
	var result = pckscene.pack(scene)
	if result != OK:
		push_error("Error packing scene: %s" % result)
		return
	var err = ResourceSaver.save(pckscene, edit_show_scene.text)
	if err != OK:
		push_error("Error saving scene: %s" % err)
		return

func _generate_scene():
	var root = MPFShowCreator.new()
	root.name = "MPFShowCreator"
	var animp = AnimationPlayer.new()
	animp.name = "AnimationPlayer"
	root.add_child(animp)
	root.animation_player = animp
	animp.owner = root
	var lights_node = Node2D.new()
	lights_node.name = "lights"
	root.add_child(lights_node)
	lights_node.owner = root

	var scene = PackedScene.new()
	var result = scene.pack(root)
	if result != OK:
		push_error("Error packing scene: %s" % result)
		return
	var err = ResourceSaver.save(scene, DEFAULT_SHOW)
	if err != OK:
		push_error("Error saving scene: %s" % err)
		return

	self.config.set_value("show_creator", "show_scene", DEFAULT_SHOW)
	self.config.save(CONFIG_PATH)
	edit_show_scene.text = DEFAULT_SHOW

	if not self.lights.is_empty():
		self._generate_lights()

func _select_mpf_config():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	self.add_child(dialog)
	dialog.popup_centered(Vector2i(400, 400))
	var path = await dialog.file_selected

	self.remove_child(dialog)
	dialog.queue_free()

	if not path:
		return
	self._save_mpf_config(path)

func _save_mpf_config(path):
	self.config.set_value("show_creator", "mpf_config", path)
	edit_mpf_config.text = path
	self.config.save(CONFIG_PATH)
	self.parse_mpf_config()

func _select_show_scene():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	self.add_child(dialog)
	dialog.popup_centered(Vector2i(400, 400))
	var path = await dialog.file_selected
	self.remove_child(dialog)
	dialog.queue_free()
	if not path:
		return
	self._save_show_scene(path)

func _save_show_scene(path):
	self.config.set_value("show_creator", "show_scene", path)
	edit_show_scene.text = path
	button_generate_scene.disabled = true
	button_generate_scene.visible = false
	self.config.save(CONFIG_PATH)
	self._render_generate_button()

func _render_generate_button():
	if edit_show_scene.text:
		button_generate_scene.disabled = true
		button_generate_scene.visible = false
	else:
		button_generate_scene.disabled = false
		button_generate_scene.visible = true

func parse_mpf_config():
	var mpf_config = FileAccess.open(edit_mpf_config.text, FileAccess.READ)
	var line = mpf_config.get_line()
	var is_in_lights = false
	var current_light: String
	var delimiter: String
	var delimiter_size: int
	while mpf_config.get_position() < mpf_config.get_length():
		var line_stripped = line.strip_edges()
		if not line_stripped or line_stripped.begins_with("#"):
			line = mpf_config.get_line()
			continue
		if line_stripped == "lights:":
			is_in_lights = true
			# The next line will give us our delimiter
			line = mpf_config.get_line()
			var dedent = line.dedent()
			delimiter_size = line.length() - dedent.length()
			delimiter = line.substr(0, delimiter_size)
			print("DELIMITER: '%s'" % delimiter)

		if is_in_lights:
			var line_data = line_stripped.split(":")
			var indent_check = line.substr(delimiter_size).length() - line.strip_edges(true, false).length()
			# If the check is zero, there is one delimiter and this is a new light
			if indent_check == 0:
				current_light = line_data[0]
				lights[current_light] = { "tags": []}
				print("Found light %s" % current_light)
			# If the check is larger, there is more than a delimiter and this is part of the light
			elif indent_check > 0:
				if line_data[0] == "tags":
					for t in line_data[1].split(","):
						lights[current_light]["tags"].append(t.strip_edges())
					print(" - tags: %s" % " and ".join(lights[current_light]["tags"]))
			# If the check is smaller, there is less than a delimiter and we are done with lights
			else:
				is_in_lights = false
		line = mpf_config.get_line()