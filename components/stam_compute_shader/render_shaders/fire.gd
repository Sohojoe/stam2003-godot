extends Sprite2D


@onready var sprite_2d = $"."

func _ready():
	material = material.duplicate()

func update_shader_params(t, skip_rendering:bool = false):
	if skip_rendering:
		return
		var zero_t = PackedByteArray()
		zero_t.resize(t.size() * 4)
		zero_t.fill(0)
		material.set_shader_parameter("t_buffer", zero_t)
		queue_redraw()
		return
	material.set_shader_parameter("t_buffer", t)
	queue_redraw()

#func _draw() -> void:
	#var crap = []
	#for t in range(128*128):
		#crap.append(0.3)
	#material.set_shader_parameter("t_buffer", crap)	
