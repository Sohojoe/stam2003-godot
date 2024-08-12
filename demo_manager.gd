extends Node2D

var simple_ui: CanvasLayer
var fire_cpu_compute_shader: FluidShaderCpu
var fire_gpu_compute_shader: FluidShaderGpu 

var grid_sizes = [
	pow(2,6), #64
	pow(2,7), #128
	pow(2,8), #256
	pow(2,9), #512
	pow(2,10), #1024
	pow(2,11), #2048
	pow(2,12), #4096
	pow(2,13), #8192
	pow(2,14), #16,384
	]

@export var mode:int = 0
@export var grid_size_idx:int = 0

func _ready() -> void:
	simple_ui = get_tree().current_scene.get_node("simple_ui")
	fire_cpu_compute_shader = get_tree().current_scene.get_node("Fire CPU Compute Shader")
	fire_gpu_compute_shader = get_tree().current_scene.get_node("Fire GPU Compute Shader")
	set_mode()
	set_grid_size()

	
func _process(_delta: float) -> void:
	handle_input()
	update_debug()
	
func handle_input():
	if Input.is_action_just_pressed("cycle_mode"):
		cycle_mode()
	if Input.is_action_just_pressed("cycle_grid_size"):
		cycle_grid_size()


func update_debug():
	if mode == 0:
		var s = " mode: fire_gpu_compute_shader"
		s = s+"\n grid size: " + str(fire_gpu_compute_shader.grid_size_n)
		simple_ui.set_debug_output_text(s)
	elif mode == 1:
		var s = " mode: fire_cpu_compute_shader"
		s = s+"\n grid size: " + str(fire_cpu_compute_shader.grid_size_n)
		simple_ui.set_debug_output_text(s)
		

func cycle_mode():
	mode += 1
	if mode >=2:
		mode = 0
	set_mode()

func set_mode():
	fire_cpu_compute_shader.hide()
	fire_gpu_compute_shader.hide()
	if mode == 0:
		fire_gpu_compute_shader.show()
	elif mode ==1:
		fire_cpu_compute_shader.show()

func cycle_grid_size():
	grid_size_idx += 1
	if grid_size_idx >= len(grid_sizes):
		grid_size_idx = 0
	set_grid_size()

func set_grid_size():
	fire_gpu_compute_shader.grid_size_n = grid_sizes[grid_size_idx]
	fire_cpu_compute_shader.grid_size_n = grid_sizes[grid_size_idx]
