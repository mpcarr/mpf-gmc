@tool
extends Sprite2D
class_name MPFShowCreator

## The root node for creating light shows for MPF.

const CONFIG_PATH = "user://mpf_show_creator.cfg"

var _light_color: Color

## An AnimationPlayer node containing the animations to render as shows.
@export var animation_player: AnimationPlayer
## Color to modulate the light icons
@export var lights_color: Color = Color(0.3, 0.3, 0.3, 1.0):
	set(value):
		_light_color = value
		for l in lights:
			l.set_color(value)
	get:
		return _light_color
## A list of group names (comma-separated) whose lights will be included
@export var light_groups: String = ""

var lights = []
var spf: float
var file: FileAccess
var file_path: String
var _groups: Array

var animation_name
var strip_unchanged_lights
var strip_empty_times
var use_alpha
var fps

func _enter_tree():
	# If there are groups, use those instead.
	# This will be called before all the children register themselves.
	if self.light_groups:
		self._groups = []
		for g in self.light_groups.split(","):
			self._groups.append(g.strip_edges())

func _ready():
	if Engine.is_editor_hint():
		return

	assert(self.texture, "MPFShowCreator node requires a playfield image as a texture.")
	ProjectSettings.set_setting("display/window/size/window_width_override", self.texture.get_width())
	ProjectSettings.set_setting("display/window/size/window_height_override", self.texture.get_height())
	set_process(false)

	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		assert(false, "Error loading config file: %s" % err)
		return
	if config.has_section("show_creator") and config.has_section_key("show_creator", "animation"):
			animation_name = config.get_value("show_creator", "animation")

	assert(animation_name, "No animation name found in configuration.")
	assert(animation_player, "No AnimationPlayer node attached to the MPFShowGenerator root.")
	assert(animation_player.has_animation(animation_name), "AnimationPlayer has no animation named '%s'" % animation_name)

	fps = config.get_value("show_creator", "fps", 30)
	strip_unchanged_lights = config.get_value("show_creator", "strip_lights", true)
	strip_empty_times = config.get_value("show_creator", "strip_times", false)
	use_alpha = config.get_value("show_creator", "use_alpha", false)

	if not self.lights:
		if self._groups:
			assert(false, "No lights found matching the selected groups.")
		else:
			assert(false, "No lights found. Please add some MPFShowLight nodes.")
	self.spf = 1.0 / self.fps
	self.clip_children = CanvasItem.CLIP_CHILDREN_ONLY

	self.file_path = "%s/%s.yaml" % [OS.get_user_data_dir(), animation_name]
	self.file = FileAccess.open(self.file_path, FileAccess.WRITE)
	self.file.store_line("#show_version=6")

	await RenderingServer.frame_post_draw
	self.animation_player.assigned_animation = animation_name
	self.animation_player.callback_mode_process = AnimationPlayer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	self.animation_player.play(animation_name)
	self.animation_player.advance(0)
	self.animation_player.animation_finished.connect(self.on_animation_finished)
	self._run_animation()

func _run_animation():
	print("Generating animation show %s.yaml: duration %ss with frames every %0.5fs" % [self.animation_player.current_animation, self.animation_player.current_animation_length, self.spf])
	var duration = self.animation_player.current_animation_length
	while self.animation_player.current_animation_position <= duration:
		await RenderingServer.frame_post_draw
		self.snapshot()
		self.animation_player.advance(self.spf)

func register_light(light: MPFShowLight):
	if light.position.x < 0 or light.position.y < 0 or light.position.x > self.texture.get_width() or light.position.y > self.texture.get_height():
		# In the editor, include all lights
		if not Engine.is_editor_hint():
			push_warning("Light %s is outside of the viewport and will not be included." % light.name)
			return
	if self._groups:
		var has_match = false
		for g in self._groups:
			if light.is_in_group(g):
				has_match = true
				break
		if not has_match:
			return
	self.lights.append(light)

func snapshot():
	var tex := get_viewport().get_texture().get_image()
	var timestamp = self.animation_player.current_animation_position
	var light_lines := []
	for l in lights:
		var c = l.get_color(tex, strip_unchanged_lights)
		if c != null:
			light_lines.append("    %s: \"%s\"" % [l.name, c.to_html(use_alpha)])
	if light_lines or not strip_empty_times:
		file.store_line("- time: %0.5f" % timestamp)
		if light_lines:
			file.store_line("  lights:")
			for line in light_lines:
				file.store_line(line)

func on_animation_finished(_animation_name=null):
	self.finish()

func finish():
	set_process(false)
	file.close()
	OS.shell_show_in_file_manager(self.file_path)
	get_tree().quit()
