class_name FluidShaderGpu
#extends CanvasLayer
extends Node2D

# ---- global illimination values
@export var gi_rendering: bool = false
@export var di_debug_view: int = 0
@export_range(0.0, 1.0) var debug_div_color_scale: float = 0.004
@export_range(0.0, 0.010) var debug_p_color_scale: float = 0.0003
# ---- config
@export var grid_size_n:int = 64
# ---- params
@export_range(0.0, 1.0) var campfire_width: float = .2
@export_range(1, 20, .1) var campfire_height: int = 2
@export_range(0.0, 1.0) var add_perturbance_probability: float = .2
@export var num_iters_projection: int = 20
@export var num_iters_diffuse: int = 20
@export var diffuse_diff_value: float = .00001
@export var wind: Vector2 = Vector2.ZERO
@export var min_dt: float = 1.0 / 60.0
@export var max_dt: float = 1.0 / 120.0
@export var paused: bool = false
# ---- 

# ----
# ----

@onready var view_gpu_compute_shader: Sprite2D = $"view gpu compute shader"
@onready var editor_label: RichTextLabel = $EditorLabel2

var c_scale = 1.0
var camera: Camera2D = null

var shader_file_names = {
	"apply_force": "res://components/stam_compute_shader/shaders/apply_force.glsl",
	"diffuse": "res://components/stam_compute_shader/shaders/diffuse.glsl",
	"advect": "res://components/stam_compute_shader/shaders/advect.glsl",
	"set_bnd_uv_open": "res://components/stam_compute_shader/shaders/set_bnd_uv_open.glsl",
	"project_compute_divergence": "res://components/stam_compute_shader/shaders/project_1_compute_divergence.glsl",
	"set_bnd_div": "res://components/stam_compute_shader/shaders/set_bnd_div.glsl",
	"project_solve_pressure": "res://components/stam_compute_shader/shaders/project_2_solve_pressure.glsl",
	"set_bnd_p": "res://components/stam_compute_shader/shaders/set_bnd_p.glsl",
	"project_apply_pressure": "res://components/stam_compute_shader/shaders/project_3_apply_pressure.glsl",
	"calculate_divergence_centered_grid": "res://components/stam_compute_shader/shaders/calculate_divergence_centered_grid.glsl",
	"cool_and_lift": "res://components/stam_compute_shader/shaders/cool_and_lift.glsl",
	"apply_ignition": "res://components/stam_compute_shader/shaders/apply_ignition.glsl",
	"view_t": "res://components/stam_compute_shader/shaders/view_t.glsl",
	"view_div": "res://components/stam_compute_shader/shaders/view_div.glsl",
	"view_p": "res://components/stam_compute_shader/shaders/view_p.glsl",
}

func _ready():
	camera = find_camera(get_tree().current_scene)
	if not camera:
		print("Camera2D not found")
	
	var canvas_width = grid_size_n
	var canvas_height = grid_size_n
	var sim_height = 1.0
	c_scale = canvas_height / sim_height
	var sim_width = canvas_width / c_scale
	var num_cells = grid_size_n*grid_size_n
	h = sqrt(sim_width * sim_height / num_cells)
	var num_x = floor(sim_width / h)
	var num_y = floor(sim_height / h)
	RenderingServer.call_on_render_thread(initialize_compute_code.bind(num_x, num_y, h))
	# disbale 	editor_label
	editor_label.visible = false


func _process(delta):
	if not is_visible_in_tree():
		return
	if not paused:
		delta = clamp(delta, min_dt, max_dt)
		handle_ignition_cpu()
		RenderingServer.call_on_render_thread(simulate_stam.bind(delta))
		handle_displaying_output()

func find_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var result = find_camera(child)
		if result:
			return result
	return null

var campfire_width_prev: float = -1
var campfire_height_prev: int = -1
func handle_ignition_cpu():
	# check if we need to update ignition
	if campfire_width == campfire_width_prev and campfire_height == campfire_height_prev:
		# early exit
		return
	campfire_width_prev = campfire_width
	campfire_height_prev = campfire_height

	# update ignition
	i.fill(0.0) # Note: this is not efficient, lol
	var campfire_start = int((numX/2.)-numX/2.*campfire_width)
	var campfire_end = int((numX/2.)+numX/2.*campfire_width)
	var center = (campfire_start + campfire_end) / 2.
	var max_distance = (campfire_end - campfire_start) / 2.
	for row in range(campfire_height):
		for col in range(campfire_start, campfire_end):
			i[row * numY + col] = 1.0
	RenderingServer.call_on_render_thread(mark_ignition_changed)

###############################################################################
# rendering thread.
var numX: int
var numY: int
var h: float

var s: PackedFloat32Array
var i: PackedFloat32Array

var rd: RenderingDevice
var pipelines = {}
var shaders = {}
var uniform_sets = {}
var consts_buffer
var u_buffer
var u_buffer_prev
var v_buffer
var v_buffer_prev
var s_buffer
var p_buffer
var p_buffer_prev
var t_buffer
var t_buffer_prev
var div_buffer
var i_buffer

var view_texture

var ignition_changed:bool = false


func initialize_compute_code(num_x: int, num_y: int, h_val: float) -> void:
	numX = num_x
	numY = num_y
	h = h_val
	s = PackedFloat32Array()
	s.resize(numX * numY)
	s.fill(1.0)
	i = PackedFloat32Array()
	i.resize(numX * numY)
	i.fill(0.0)
	
	rd = RenderingServer.get_rendering_device()
	var h2 = 0.5 * h

	var consts_buffer_bytes := PackedInt32Array([numX, numY]).to_byte_array()
	consts_buffer_bytes.append_array(PackedFloat32Array([h, h2]).to_byte_array())
	consts_buffer_bytes.resize(ceil(consts_buffer_bytes.size() / 16.0) * 16)
	consts_buffer = rd.storage_buffer_create(consts_buffer_bytes.size(), consts_buffer_bytes)

	var grid_of_bytes_0 = i.to_byte_array()
	var grid_of_bytes_1 = s.to_byte_array()
	u_buffer = rd.storage_buffer_create			(grid_of_bytes_0.size(), grid_of_bytes_0)
	u_buffer_prev = rd.storage_buffer_create		(grid_of_bytes_0.size(), grid_of_bytes_0)
	v_buffer = rd.storage_buffer_create			(grid_of_bytes_0.size(), grid_of_bytes_0)
	v_buffer_prev = rd.storage_buffer_create		(grid_of_bytes_0.size(), grid_of_bytes_0)
	p_buffer = rd.storage_buffer_create			(grid_of_bytes_0.size(), grid_of_bytes_0)
	p_buffer_prev = rd.storage_buffer_create		(grid_of_bytes_0.size(), grid_of_bytes_0)
	div_buffer = rd.storage_buffer_create		(grid_of_bytes_0.size(), grid_of_bytes_0)
	t_buffer = rd.storage_buffer_create			(grid_of_bytes_0.size(), grid_of_bytes_0)
	t_buffer_prev = rd.storage_buffer_create		(grid_of_bytes_0.size(), grid_of_bytes_0)
	i_buffer = rd.storage_buffer_create			(grid_of_bytes_0.size(), grid_of_bytes_0)
	s_buffer = rd.storage_buffer_create			(grid_of_bytes_1.size(), grid_of_bytes_1)


	var fmt3 = RDTextureFormat.new()
	fmt3.width = numX
	fmt3.height = numY
	fmt3.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt3.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT	
	var view3 = RDTextureView.new()
	view_texture = rd.texture_create(fmt3, view3)
	var texture_rd = Texture2DRD.new()
	texture_rd.texture_rd_rid = view_texture
	view_gpu_compute_shader.texture = texture_rd
	var view_scale = Vector2.ONE * (128.0 / numY)
	view_gpu_compute_shader.scale = view_scale
	
	for key in shader_file_names.keys():
		var file_name = shader_file_names[key]
		var shader_file = load(file_name)
		var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
		var shader = rd.shader_create_from_spirv(shader_spirv)
		shaders[key] = shader
		pipelines[key] = rd.compute_pipeline_create(shader)



func simulate_stam(dt: float) -> void:
	#--- GPU work
	handle_ignition_gpu()
	# integrate_s(dt, wind)
	apply_ignition()
	cool_and_lift(dt)
	diffuse_t(dt, num_iters_diffuse)
	diffuse_uv(dt, num_iters_diffuse)
	project_s(num_iters_projection)
	stam_advect_temperature(dt)
	stam_advect_vel(dt)
	project_s(num_iters_projection)
	if not gi_rendering:
		match di_debug_view:
			1:
				view_div()
			2:
				view_p()
			_:
				view_t()


#--- helper functions
func get_uniform(buffer, binding: int):
	var rd_uniform = RDUniform.new()
	# handle differnt types of buffers
	if buffer == view_texture:
		rd_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	else:
		rd_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	rd_uniform.binding = binding
	rd_uniform.add_id(buffer)
	return rd_uniform

func get_uniform_set(values: Array):
	var hashed = values.hash()
	if uniform_sets.has(hashed):
		return uniform_sets[hashed]
	var uniforms = []
	var shader_name = values[0]
	var shader = shaders[shader_name]
	for i in range(1, values.size(), 2):
		var buffer = values[i]
		var binding = values[i + 1]
		var rd_uniform = get_uniform(buffer, binding)
		uniforms.append(rd_uniform)
	var uniform_set = rd.uniform_set_create(uniforms, shader, 0)
	uniform_sets[hashed] = uniform_set
	return uniform_set

func swap_u_buffer():
	var tmp = u_buffer
	u_buffer = u_buffer_prev
	u_buffer_prev = tmp

func swap_v_buffer():
	var tmp = v_buffer
	v_buffer = v_buffer_prev
	v_buffer_prev = tmp

func swap_uv_buffers():
	swap_u_buffer()
	swap_v_buffer()

func swap_t_buffer():
	var tmp = t_buffer
	t_buffer = t_buffer_prev
	t_buffer_prev = tmp

func swap_p_buffer():
	var tmp = p_buffer
	p_buffer = p_buffer_prev
	p_buffer_prev = tmp

func dispatch(compute_list, shader_name, uniform_set, pc_bytes=null):
	rd.compute_list_bind_compute_pipeline(compute_list, pipelines[shader_name])
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	if pc_bytes:
		rd.compute_list_set_push_constant(compute_list, pc_bytes, pc_bytes.size())
	rd.compute_list_dispatch(compute_list, int(ceil(numX / 16.0)), int(ceil(numY / 16.0)), 1)

#---- core functions
func integrate_s(dt: float, wind_force: Vector2):
	var shader_name = "apply_force"
	var uniform_set = get_uniform_set([
		shader_name,
		consts_buffer, 0,
		u_buffer, 1,
		v_buffer, 2,
		s_buffer, 3])

	# Prepare push constants
	var pc_data := PackedFloat32Array([wind_force.x * dt, wind_force.y * dt])
	var pc_bytes = pc_data.to_byte_array()
	pc_bytes.resize(ceil(pc_bytes.size() / 16.0) * 16)
		
	var compute_list = rd.compute_list_begin()
	dispatch(compute_list, shader_name, uniform_set, pc_bytes)
	rd.compute_list_end()

func cool_and_lift(dt: float):
	var shader_name = "cool_and_lift"
	var uniform_set = get_uniform_set([
		shader_name,
		consts_buffer, 0,
		u_buffer, 1,
		v_buffer, 2,
		t_buffer, 8])

	# Prepare push constants
	var seed:float = randf()
	var pc_data := PackedFloat32Array([dt, add_perturbance_probability, seed])
	var pc_bytes = pc_data.to_byte_array()
	pc_bytes.resize(ceil(pc_bytes.size() / 16.0) * 16)
		
	var compute_list = rd.compute_list_begin()
	dispatch(compute_list, shader_name, uniform_set, pc_bytes)

	# Apply boundary conditions to u and v
	var shader_name_bnd_uv = "set_bnd_uv_open"
	var uniform_set_bnd_uv = get_uniform_set([
		shader_name_bnd_uv,
		consts_buffer, 0,
		u_buffer, 1,
		v_buffer, 2])
	dispatch(compute_list, shader_name_bnd_uv, uniform_set_bnd_uv)
	rd.compute_list_end()

func apply_ignition():
	var shader_name = "apply_ignition"
	var uniform_set = get_uniform_set([
		shader_name,
		consts_buffer, 0,
		u_buffer, 1,
		v_buffer, 2,
		t_buffer, 8,
		i_buffer, 11])
		
	var compute_list = rd.compute_list_begin()
	dispatch(compute_list, shader_name, uniform_set)
	rd.compute_list_end()

func diffuse(read_buffer, write_buffer, dt:float, num_iters:int):
	var shader_name = "diffuse"
	var uniform_set = get_uniform_set([
		shader_name,
		consts_buffer, 0,
		read_buffer, 1,
		write_buffer, 2,
		s_buffer, 3
		])
	var pc_bytes := PackedFloat32Array([dt, diffuse_diff_value]).to_byte_array()
	pc_bytes.resize(ceil(pc_bytes.size() / 16.0) * 16)

	var compute_list = rd.compute_list_begin()

	for k in range(num_iters):
		dispatch(compute_list, shader_name, uniform_set, pc_bytes)

	rd.compute_list_end()


func diffuse_uv(dt:float, num_iters:int):

	swap_uv_buffers()
	diffuse(u_buffer_prev, u_buffer, dt, num_iters)
	diffuse(v_buffer_prev, v_buffer, dt, num_iters)


func diffuse_t(dt:float, num_iters:int):

	swap_t_buffer()
	diffuse(t_buffer_prev, t_buffer, dt, num_iters)


func project_s(num_iters: int):
	
	var compute_list = rd.compute_list_begin()

	# Compute divergence
	var shader_name_div = "project_compute_divergence"
	var uniform_set_div = get_uniform_set([
		shader_name_div,
		consts_buffer, 0,
		u_buffer, 1,
		v_buffer, 2,
		s_buffer, 3,
		p_buffer, 4,
		div_buffer, 5])
	dispatch(compute_list, shader_name_div, uniform_set_div)
	## Apply boundary conditions to div
	var shader_name_bnd_div = "set_bnd_div"
	var uniform_set_bnd_div = get_uniform_set([
		shader_name_bnd_div,
		consts_buffer, 0,
		div_buffer, 5])
	dispatch(compute_list, shader_name_bnd_div, uniform_set_bnd_div)

	# Solve pressure iterations
	for k in range(num_iters):
		swap_p_buffer()
		var shader_name_p = "project_solve_pressure"
		var uniform_set_p = get_uniform_set([
			shader_name_p,
				consts_buffer, 0,
				s_buffer, 3,
				p_buffer, 4,
				div_buffer, 5,
				p_buffer_prev, 10])
		dispatch(compute_list, shader_name_p, uniform_set_p)
		## Apply boundary conditions to pressure
		var shader_name_bnd_p = "set_bnd_p"
		var uniform_set_bnd_p = get_uniform_set([
			shader_name_bnd_p,
			consts_buffer, 0,
			p_buffer, 4])
		dispatch(compute_list, shader_name_bnd_p, uniform_set_bnd_p)

	# Apply pressure gradient
	var shader_name_apply_p = "project_apply_pressure"
	var uniform_set_apply_p = get_uniform_set([
		shader_name_apply_p,
		consts_buffer, 0,
		u_buffer, 1,
		v_buffer, 2,
		s_buffer, 3,
		p_buffer, 4])
	dispatch(compute_list, shader_name_apply_p, uniform_set_apply_p)

	# Apply boundary conditions to u and v
	var shader_name_bnd_uv = "set_bnd_uv_open"
	var uniform_set_bnd_uv = get_uniform_set([
		shader_name_bnd_uv,
		consts_buffer, 0,
		u_buffer, 1,
		v_buffer, 2])
	dispatch(compute_list, shader_name_bnd_uv, uniform_set_bnd_uv)

	# calculate_divergence_centered_grid
	var shader_name_calc_div = "calculate_divergence_centered_grid"
	var uniform_set_calc_div = get_uniform_set([
		shader_name_calc_div,
		consts_buffer, 0,
		u_buffer, 1,
		v_buffer, 2,
		s_buffer, 3,
		div_buffer, 5])
	dispatch(compute_list, shader_name_calc_div, uniform_set_calc_div)
	## Apply boundary conditions to div
	dispatch(compute_list, shader_name_bnd_div, uniform_set_bnd_div)

	rd.compute_list_end()


func advect(read_buffer, write_buffer, dt: float):
	var shader_name = "advect"
	var uniform_set = get_uniform_set([
		shader_name,
			consts_buffer, 0,
			u_buffer, 1,
			v_buffer, 2,
			s_buffer, 3,
			write_buffer, 4,
			read_buffer, 5])

	var pc_bytes := PackedFloat32Array([dt]).to_byte_array()
	pc_bytes.resize(ceil(pc_bytes.size() / 16.0) * 16)

	var compute_list = rd.compute_list_begin()
	dispatch(compute_list, shader_name, uniform_set, pc_bytes)
	rd.compute_list_end()


func stam_advect_temperature(dt: float):

	swap_t_buffer()
	advect(t_buffer_prev, t_buffer, dt)

func stam_advect_vel(dt: float):

	swap_uv_buffers()
	advect(u_buffer_prev, u_buffer, dt)
	advect(v_buffer_prev, v_buffer, dt)

func handle_ignition_gpu():
	if (ignition_changed):
		ignition_changed = false
		rd.buffer_update(i_buffer, 0, i.size() * 4, i.to_byte_array())

func mark_ignition_changed() -> void:
	ignition_changed = true

func view_t():
	var shader_name = "view_t"
	var uniform_set = get_uniform_set([
		shader_name,
		consts_buffer, 0,
		t_buffer, 8,
		view_texture, 20])
		
	var compute_list = rd.compute_list_begin()
	dispatch(compute_list, shader_name, uniform_set)
	rd.compute_list_end()

func view_div():
	var shader_name = "view_div"
	var uniform_set = get_uniform_set([
		shader_name,
		consts_buffer, 0,
		div_buffer, 5,
		view_texture, 20])

	var pc_bytes := PackedFloat32Array([debug_div_color_scale]).to_byte_array()
	pc_bytes.resize(ceil(pc_bytes.size() / 16.0) * 16)

	var compute_list = rd.compute_list_begin()
	dispatch(compute_list, shader_name, uniform_set, pc_bytes)
	rd.compute_list_end()

func view_p():
	var shader_name = "view_p"
	var uniform_set = get_uniform_set([
		shader_name,
		consts_buffer, 0,
		p_buffer, 4,
		view_texture, 20])

	var pc_bytes := PackedFloat32Array([debug_p_color_scale]).to_byte_array()
	pc_bytes.resize(ceil(pc_bytes.size() / 16.0) * 16)

	var compute_list = rd.compute_list_begin()
	dispatch(compute_list, shader_name, uniform_set, pc_bytes)
	rd.compute_list_end()

# -----------------------------------------------------------------------------------
# UI and debug vars and code
# 

func handle_displaying_output():
	pass
