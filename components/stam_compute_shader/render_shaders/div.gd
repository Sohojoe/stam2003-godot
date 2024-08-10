extends Sprite2D

@export_range(0.0, 1.0) var color_scale: float = 0.005
@export var auto_reset_color_scale: bool = true

@onready var sprite_2d = $"."
@onready var toggle_timer: Timer = $ToggleTimer

var toggle_reset_color_scale: bool = false
var _toggle_reset_color_scale: bool = false

func _ready():
	material = material.duplicate()
	print("Ready function called.")
	print("Node tree: ", get_tree().root)  # Print the entire node tree to verify node paths
	print("Toggle Timer: ", toggle_timer)
	
	if toggle_timer:
		toggle_timer.connect("timeout", Callable(self, "_on_toggle_timer_timeout"))
		start_toggle_timer()
	else:
		print("Error: ToggleTimer node not found.")
		# Optionally, iterate through children to see if there's a naming issue
		for child in get_children():
			print("Child node: ", child.name)

func update_shader_params(div:PackedFloat32Array):
	if toggle_reset_color_scale != _toggle_reset_color_scale:
		var max_val = div[0]
		for i in range(1, div.size()):
			max_val = max(abs(div[i]), max_val)
		color_scale = max_val
		_toggle_reset_color_scale = toggle_reset_color_scale
	material.set_shader_parameter("color_scale", color_scale)
	material.set_shader_parameter("div_buffer", div)
	queue_redraw()

func _on_toggle_timer_timeout():
	if auto_reset_color_scale:
		toggle_reset_color_scale = !toggle_reset_color_scale
	start_toggle_timer()

func start_toggle_timer():
	var base_time = 3.0
	var variance = 1.0
	var wait_time = base_time + randf_range(-variance, variance)
	toggle_timer.wait_time = wait_time
	toggle_timer.start()
