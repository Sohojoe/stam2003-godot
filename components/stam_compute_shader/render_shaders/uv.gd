extends Sprite2D

@export_range(0.0, 1.0) var color_scale: float = 1.
@export var auto_reset_color_scale: bool = false

@onready var sprite_2d = $"."
@onready var toggle_timer: Timer = $ToggleTimer

var toggle_reset_color_scale: bool = false
var _toggle_reset_color_scale: bool = false

func _ready():
	material = material.duplicate()
	if toggle_timer:
		toggle_timer.connect("timeout", Callable(self, "_on_toggle_timer_timeout"))
		start_toggle_timer()
	else:
		print("Error: ToggleTimer node not found.")

func update_shader_params(u:PackedFloat32Array, v:PackedFloat32Array):
	if toggle_reset_color_scale != _toggle_reset_color_scale:
		var max_u = u[0]
		var max_v = v[0]
		for i in range(1, u.size()):
			max_u = max(abs(u[i]), max_u)
		for i in range(1, v.size()):
			max_v = max(abs(v[i]), max_v)
		var max_val = max(max_u, max_v)
		color_scale = max_val
		_toggle_reset_color_scale = toggle_reset_color_scale
	material.set_shader_parameter("color_scale", color_scale)
	material.set_shader_parameter("u_buffer", u)
	material.set_shader_parameter("v_buffer", v)
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
