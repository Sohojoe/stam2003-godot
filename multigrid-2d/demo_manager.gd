extends Node2D

var simple_ui: CanvasLayer
var fire_gpu_texture_shader: FluidTextureShaderGpu 
var debug_view_strategy: MultigridDebugViewStrategy

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
	#pow(2,15), #32,768 # is crashing
	]

@export var mode:int = 0
@export var grid_size_idx:int = 0
@export var debug_view:int = 1

func _ready() -> void:
	simple_ui = get_tree().current_scene.get_node("simple_ui")
	fire_gpu_texture_shader = get_tree().current_scene.get_node("Fire GPU Texture Shader")
	debug_view_strategy = MultigridDebugViewStrategy.new()
	fire_gpu_texture_shader.set_debug_view_strategy(debug_view_strategy)
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
	if Input.is_action_just_pressed("toggle_debug_view"):
		debug_view_strategy.enable_debug(!debug_view_strategy.is_debug_enabled())
	if Input.is_action_just_pressed("next_debug_view"):
		debug_view_strategy.next_view()
	if Input.is_action_just_pressed("previous_debug_view"):
		debug_view_strategy.previous_view()
	if Input.is_action_just_pressed("restart"):
		fire_gpu_texture_shader.restart()
	if Input.is_action_just_pressed("toggle_view"):
		fire_gpu_texture_shader.skip_gi_rendering = !fire_gpu_texture_shader.skip_gi_rendering
	if Input.is_action_just_pressed("toggle_pause_motion"):
		fire_gpu_texture_shader.pause_motion = !fire_gpu_texture_shader.pause_motion

func update_debug():
	if mode == 0:
		var s = " mode: fire_gpu_texture_shader"
		s = s+"\n grid size: " + str(fire_gpu_texture_shader.grid_size_n)
		if debug_view_strategy.is_debug_enabled():
			s = s+"\n " + debug_view_strategy.get_step_debug_name(debug_view_strategy.view_step_idx)
		if fire_gpu_texture_shader.skip_gi_rendering:
			s = s+"\n rendering disabled (v to toggle))"
		simple_ui.set_debug_output_text(s)
	else:
		var s = " only one mode supported"
		simple_ui.set_debug_output_text(s)
		

func cycle_mode():
	mode += 1
	if mode >=1:
		mode = 0
	set_mode()

func set_mode():
	fire_gpu_texture_shader.hide()
	if mode == 0:
		fire_gpu_texture_shader.show()
	elif mode ==1:
		pass

func cycle_grid_size():
	grid_size_idx += 1
	if grid_size_idx >= len(grid_sizes):
		grid_size_idx = 0
	set_grid_size()

func set_grid_size():
	fire_gpu_texture_shader.grid_size_n = grid_sizes[grid_size_idx]
	if fire_gpu_texture_shader.debug_multigrid_idx >= len(fire_gpu_texture_shader.multigrid_sizes):
		fire_gpu_texture_shader.debug_multigrid_idx = 0
