extends Sprite2D


@onready var sprite_2d = $"."

func _ready():
	material = material.duplicate()

func update_shader_params(t, grid_size_n: int):
	if t.size() > 16384:
		t = t.slice(0, 16384)
	material.set_shader_parameter("t_buffer", t)
	material.set_shader_parameter("grid_size_n", grid_size_n)
	queue_redraw()
