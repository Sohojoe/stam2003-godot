class_name FluidTextureShaderGpu
#extends CanvasLayer
extends Node2D

# ---- global illimination values
@export var skip_gi_rendering: bool = false
@export_range(0, 3, .1) var di_debug_view: int = 0
@export_range(0.0, 1.0) var debug_div_color_scale: float = 0.0002
@export_range(0.0, 0.010) var debug_p_color_scale: float = 0.0003
@export_range(0.0, 0.30) var debug_uv_color_scale: float = 0.07
# ---- config
@export var grid_size_n:int = 64
# ---- params
@export_range(0.0, 1.0) var campfire_width: float = .2
@export_range(1, 20, .1) var campfire_height: int = 2
@export_range(0.0, 1.0) var add_perturbance_probability: float = .2
@export var num_iters_projection: int = 20
@export var num_iters_diffuse: int = 20
@export var diffuse_visc_value: float = .00001
@export var diffuse_diff_value: float = .00001
@export var wind: Vector2 = Vector2.ZERO
@export var min_dt: float = 1.0 / 60.0
@export var max_dt: float = 1.0 / 120.0
@export var paused: bool = false
# ---- 

# ----
# ----

@onready var view_gpu_texture_shader: Sprite2D = $"view gpu texture shader"
@onready var editor_label: RichTextLabel = $EditorLabel2

var c_scale = 1.0
var camera: Camera2D = null

var shader_file_names = {
	"apply_force": "res://components/stam_compute_shader/texture_shaders/apply_force.glsl",
	"diffuse": "res://components/stam_compute_shader/texture_shaders/diffuse.glsl",
	"advect": "res://components/stam_compute_shader/texture_shaders/advect.glsl",
	"set_square_bnd_uv_open": "res://components/stam_compute_shader/texture_shaders/set_square_bnd_uv_open.glsl",
	"project_compute_divergence": "res://components/stam_compute_shader/texture_shaders/project_1_compute_divergence.glsl",
	"set_square_bnd_div": "res://components/stam_compute_shader/texture_shaders/set_square_bnd_div.glsl",
	"project_solve_pressure": "res://components/stam_compute_shader/texture_shaders/project_2_solve_pressure.glsl",
	"set_square_bnd_p": "res://components/stam_compute_shader/texture_shaders/set_square_bnd_p.glsl",
	"project_apply_pressure": "res://components/stam_compute_shader/texture_shaders/project_3_apply_pressure.glsl",
	"calculate_divergence_centered_grid": "res://components/stam_compute_shader/texture_shaders/calculate_divergence_centered_grid.glsl",
	"cool_and_lift": "res://components/stam_compute_shader/texture_shaders/cool_and_lift.glsl",
	"apply_ignition": "res://components/stam_compute_shader/texture_shaders/apply_ignition.glsl",
	"view_t": "res://components/stam_compute_shader/texture_shaders/view_t.glsl",
	"view_div": "res://components/stam_compute_shader/texture_shaders/view_div.glsl",
	"view_p": "res://components/stam_compute_shader/texture_shaders/view_p.glsl",
	"view_uv": "res://components/stam_compute_shader/texture_shaders/view_uv.glsl",
}
var texture_shader_file_names = {
	"apply_ignition": "res://components/stam_compute_shader/texture_shaders/apply_ignition.gdshader",
	"view_t": "res://components/stam_compute_shader/texture_shaders/view_t.gdshader",
	"view_p": "res://components/stam_compute_shader/texture_shaders/view_p.gdshader",
	"view_div": "res://components/stam_compute_shader/texture_shaders/view_div.gdshader",
	"view_uv": "res://components/stam_compute_shader/texture_shaders/view_uv.gdshader",
}
func _ready():
	camera = find_camera(get_tree().current_scene)
	if not camera:
		print("Camera2D not found")
	
	RenderingServer.call_on_render_thread(initialize_compute_code.bind(grid_size_n))
	# disbale 	editor_label
	editor_label.visible = false

func _process(delta):
	if not is_visible_in_tree():
		return
	if not paused:
		delta = clamp(delta, max_dt, min_dt)
		handle_ignition_cpu()
		RenderingServer.call_on_render_thread(render_thread_update.bind(delta, grid_size_n))
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
	ignition.fill(0) # Note: this is not efficient, lol
	# var campfire_start = int((numX/2.)-numX/2.*campfire_width)
	# var campfire_end = int((numX/2.)+numX/2.*campfire_width)
	var campfire_start = int((numX/2.)-64/2.*campfire_width)
	var campfire_end = int((numX/2.)+64/2.*campfire_width)	
	for row in range(1, 1+campfire_height):
		for col in range(campfire_start, campfire_end):
			ignition[row * numY + col] = 255
	RenderingServer.call_on_render_thread(mark_ignition_changed)

func restart():
	RenderingServer.call_on_render_thread(initialize_compute_code.bind(grid_size_n))

func toggle_is_updating():
	view_gpu_texture_shader.toggle_is_updating()

###############################################################################
# rendering thread.
var numX: int
var numY: int

var state: PackedByteArray
var ignition: PackedByteArray

var rd: RenderingDevice
var pipelines = {}
var shaders = {}
var texture_shaders = {}
var uniform_sets = {}
var consts_buffer

var u_texture:Texture2DRD
var u_texture_rid:RID
var u_texture_prev:Texture2DRD
var u_texture_prev_rid:RID
var v_texture:Texture2DRD
var v_texture_rid:RID
var v_texture_prev:Texture2DRD
var v_texture_prev_rid:RID
var s_texture:Texture2DRD
var s_texture_rid:RID
var p_texture:Texture2DRD
var p_texture_rid:RID
var p_texture_prev:Texture2DRD
var p_texture_prev_rid:RID
var t_texture:Texture2DRD
var t_texture_rid:RID
var t_texture_prev:Texture2DRD
var t_texture_prev_rid:RID
var div_texture:Texture2DRD
var div_texture_rid:RID
var i_texture:Texture2DRD
var i_texture_rid:RID
var sampler_nearest:RID


var ignition_changed:bool = false
var grid_size_n_prev: int = -1

func initialize_compute_code(grid_size: int) -> void:
	if rd:
		free_previous_resources() 
	
	grid_size_n_prev = grid_size

	var canvas_width = 1024
	var canvas_height = 1024
	numX= grid_size
	numY = grid_size
	var sim_height = numY / 64.0
	c_scale = canvas_height / sim_height
	var sim_width = canvas_width / c_scale
	var num_cells = grid_size*grid_size
	var h = sqrt(sim_width * sim_height / num_cells)
	#var h = sqrt(1 / (64*64))
	state = PackedByteArray()
	state.resize(numX * numY)
	state.fill(255)
	ignition = PackedByteArray()
	ignition.resize(numX * numY)
	ignition.fill(0)
	
	rd = RenderingServer.get_rendering_device()
	var h2 = 0.5 * h

	var view_texture_size = view_gpu_texture_shader.view_texture_size

	var consts_buffer_bytes := PackedInt32Array([numX, numY, view_texture_size, view_texture_size]).to_byte_array()
	consts_buffer_bytes.append_array(PackedFloat32Array([h, h2]).to_byte_array())
	consts_buffer_bytes.resize(ceil(consts_buffer_bytes.size() / 16.0) * 16)
	consts_buffer = rd.storage_buffer_create(consts_buffer_bytes.size(), consts_buffer_bytes)
	

	var grid_size_v2 = Vector2(numX, numY)
	var view_size = Vector2(view_texture_size, view_texture_size)
	var view_ratio = grid_size_v2 / view_size
	RenderingServer.global_shader_parameter_set("dt", 1.0/60)
	RenderingServer.global_shader_parameter_set("grid_size", grid_size_v2)
	RenderingServer.global_shader_parameter_set("h", h)
	RenderingServer.global_shader_parameter_set("h2", h2)	
	RenderingServer.global_shader_parameter_set("numX", numX)
	RenderingServer.global_shader_parameter_set("numY", numY)
	RenderingServer.global_shader_parameter_set("viewX", view_texture_size)
	RenderingServer.global_shader_parameter_set("viewY", view_texture_size)
	RenderingServer.global_shader_parameter_set("view_ratio", view_ratio)
	RenderingServer.global_shader_parameter_set("view_size", view_size)
	
	var filenames = shader_file_names
	for key in filenames.keys():
		var file_name = filenames[key]
		var shader_file = load(file_name)
		var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
		var shader = rd.shader_create_from_spirv(shader_spirv)
		shaders[key] = shader
		pipelines[key] = rd.compute_pipeline_create(shader)

	var fmt3_R32_SFLOAT := RDTextureFormat.new()
	fmt3_R32_SFLOAT.width = numX
	fmt3_R32_SFLOAT.height = numY
	fmt3_R32_SFLOAT.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	fmt3_R32_SFLOAT.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	var fmt3_R16_SFLOAT := RDTextureFormat.new()
	fmt3_R16_SFLOAT.width = numX
	fmt3_R16_SFLOAT.height = numY
	fmt3_R16_SFLOAT.format = RenderingDevice.DATA_FORMAT_R16_SFLOAT
	fmt3_R16_SFLOAT.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	var fmt3_R8_UNORM := RDTextureFormat.new()
	fmt3_R8_UNORM.width = numX
	fmt3_R8_UNORM.height = numY
	fmt3_R8_UNORM.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	fmt3_R8_UNORM.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	var view3 = RDTextureView.new()
	u_texture_rid = rd.texture_create(fmt3_R16_SFLOAT, view3)
	u_texture = Texture2DRD.new()
	u_texture.texture_rd_rid = u_texture_rid
	u_texture_prev_rid = rd.texture_create(fmt3_R16_SFLOAT, view3)
	u_texture_prev = Texture2DRD.new()
	u_texture_prev.texture_rd_rid = u_texture_prev_rid
	v_texture_rid = rd.texture_create(fmt3_R16_SFLOAT, view3)
	v_texture = Texture2DRD.new()
	v_texture.texture_rd_rid = v_texture_rid
	v_texture_prev_rid = rd.texture_create(fmt3_R16_SFLOAT, view3)
	v_texture_prev = Texture2DRD.new()
	v_texture_prev.texture_rd_rid = v_texture_prev_rid
	s_texture_rid = rd.texture_create(fmt3_R8_UNORM, view3)
	s_texture = Texture2DRD.new()
	s_texture.texture_rd_rid = s_texture_rid
	p_texture_rid = rd.texture_create(fmt3_R16_SFLOAT, view3)
	p_texture = Texture2DRD.new()
	p_texture.texture_rd_rid = p_texture_rid
	p_texture_prev_rid = rd.texture_create(fmt3_R16_SFLOAT, view3)
	p_texture_prev = Texture2DRD.new()
	p_texture_prev.texture_rd_rid = p_texture_prev_rid
	t_texture_rid = rd.texture_create(fmt3_R16_SFLOAT, view3)
	t_texture = Texture2DRD.new()
	t_texture.texture_rd_rid = t_texture_rid
	t_texture_prev_rid = rd.texture_create(fmt3_R16_SFLOAT, view3)
	t_texture_prev = Texture2DRD.new()
	t_texture_prev.texture_rd_rid = t_texture_prev_rid
	div_texture_rid = rd.texture_create(fmt3_R16_SFLOAT, view3)
	div_texture = Texture2DRD.new()
	div_texture.texture_rd_rid = div_texture_rid
	i_texture_rid = rd.texture_create(fmt3_R8_UNORM, view3)
	i_texture = Texture2DRD.new()
	i_texture.texture_rd_rid = i_texture_rid

	var i_bytes = state
	rd.texture_update(s_texture_rid, 0, i_bytes)

	var ss = RDSamplerState.new()
	# ss.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	# ss.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_BORDER
	ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_BORDER
	ss.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_BORDER
	ss.border_color = RenderingDevice.SAMPLER_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK
	sampler_nearest = rd.sampler_create(ss)

	for key in texture_shader_file_names.keys():
		var file_name:String = texture_shader_file_names[key]
		var shader = load(file_name)
		texture_shaders[key] = shader

	campfire_width_prev = -1
	campfire_height_prev = -1


func free_previous_resources():
	view_gpu_texture_shader.material.set_shader_parameter("p_texture", null)	
	view_gpu_texture_shader.material.shader = null

	if consts_buffer:
		rd.free_rid(consts_buffer)

	if u_texture:
		rd.free_rid(u_texture_rid)
		u_texture = null
	if u_texture_prev:
		rd.free_rid(u_texture_prev_rid)
		u_texture_prev = null
	if v_texture:
		rd.free_rid(v_texture_rid)
		v_texture = null
	if v_texture_prev:
		rd.free_rid(v_texture_prev_rid)
		v_texture_prev = null
	if s_texture:
		rd.free_rid(s_texture_rid)
		s_texture = null
	if p_texture:
		rd.free_rid(p_texture_rid)
		p_texture = null
	if p_texture_prev:
		rd.free_rid(p_texture_prev_rid)
		p_texture_prev = null
	if t_texture:
		rd.free_rid(t_texture_rid)
		t_texture = null
	if t_texture_prev:
		rd.free_rid(t_texture_prev_rid)
		t_texture_prev = null
	if div_texture:
		rd.free_rid(div_texture_rid)
		div_texture = null
	if i_texture:
		rd.free_rid(i_texture_rid)
		i_texture = null
	if sampler_nearest:
		rd.free_rid(sampler_nearest)
	
	uniform_sets.clear()
	
	for key in shaders.keys():
		if shaders[key].is_valid():
			rd.free_rid(shaders[key])
	shaders.clear()

	#for key in pipelines.keys():
		#if pipelines[key].is_valid():
			#rd.free_rid(pipelines[key])
	pipelines.clear()

	texture_shaders.clear()

func render_thread_update(delta: float, cur_grid_size_n: int) -> void:
	if cur_grid_size_n != grid_size_n_prev:
		initialize_compute_code(cur_grid_size_n)
	else:
		simulate_stam(delta)

func simulate_stam(dt: float) -> void:
	RenderingServer.global_shader_parameter_set("dt", dt)

	#--- GPU work
	handle_ignition_gpu()
	# integrate_s(dt, wind)
	apply_ignition()
	cool_and_lift(dt)
	diffuse_uv(dt, num_iters_diffuse)
	project_s(num_iters_projection)
	stam_advect_vel(dt)
	project_s(num_iters_projection)
	diffuse_t(dt, num_iters_diffuse)
	stam_advect_temperature(dt)
	if not skip_gi_rendering:
		match di_debug_view:
			1:
				view_div()
			2:
				view_p()
			3:
				view_uv()
			_:
				view_t()

#--- helper functions
func get_uniform(buffer, binding: int, uniform_type):
	var rd_uniform = RDUniform.new()
	rd_uniform.uniform_type = uniform_type
	rd_uniform.binding = binding
	if buffer is Array:
		for item in buffer:
			rd_uniform.add_id(item)
	else:
		rd_uniform.add_id(buffer)
	return rd_uniform

func get_uniform_set(values: Array):
	var hashed = values.hash()
	if uniform_sets.has(hashed):
		return uniform_sets[hashed]
	var uniforms = []
	var shader_name = values[0]
	var shader = shaders[shader_name]
	for i in range(1, values.size(), 3):
		var buffer = values[i]
		var binding = values[i + 1]
		var uniform_type = values[i + 2]
		var rd_uniform = get_uniform(buffer, binding, uniform_type)
		uniforms.append(rd_uniform)
	var uniform_set = rd.uniform_set_create(uniforms, shader, 0)
	uniform_sets[hashed] = uniform_set
	return uniform_set

func swap_u_buffer():
	var tmp_rid = u_texture_rid
	u_texture_rid = u_texture_prev_rid
	u_texture_prev_rid = tmp_rid
	var tmp_t = u_texture
	u_texture = u_texture_prev
	u_texture_prev = tmp_t

func swap_v_buffer():
	var tmp_rid = v_texture_rid
	v_texture_rid = v_texture_prev_rid
	v_texture_prev_rid = tmp_rid
	var tmp_t = v_texture
	v_texture = v_texture_prev
	v_texture_prev = tmp_t

func swap_uv_buffers():
	swap_u_buffer()
	swap_v_buffer()

func swap_t_buffer():
	var tmp_rid = t_texture_rid
	t_texture_rid = t_texture_prev_rid
	t_texture_prev_rid = tmp_rid
	var tmp_t = t_texture
	t_texture = t_texture_prev
	t_texture_prev = tmp_t

func swap_p_buffer():
	var tmp_rid = p_texture_rid
	p_texture_rid = p_texture_prev_rid
	p_texture_prev_rid = tmp_rid
	var tmp_t = p_texture
	p_texture = p_texture_prev
	p_texture_prev = tmp_t

func dispatch(compute_list, shader_name, uniform_set, pc_bytes=null):
	rd.compute_list_bind_compute_pipeline(compute_list, pipelines[shader_name])
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	if pc_bytes:
		rd.compute_list_set_push_constant(compute_list, pc_bytes, pc_bytes.size())
	rd.compute_list_dispatch(compute_list, int(ceil(numX / 16.0)), int(ceil(numY / 16.0)), 1)
	
func dispatch_square_bounds(compute_list, shader_name, uniform_set, pc_bytes=null):
	rd.compute_list_bind_compute_pipeline(compute_list, pipelines[shader_name])
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	if pc_bytes:
		rd.compute_list_set_push_constant(compute_list, pc_bytes, pc_bytes.size())
	rd.compute_list_dispatch(compute_list, int(ceil(numX / 16.0)), 1, 1)

func dispatch_view(compute_list, shader_name, uniform_set, pc_bytes=null):
	rd.compute_list_bind_compute_pipeline(compute_list, pipelines[shader_name])
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	if pc_bytes:
		rd.compute_list_set_push_constant(compute_list, pc_bytes, pc_bytes.size())
	var xsteps = int(ceil(view_gpu_texture_shader.view_texture_size / 16.0))
	var ysteps = int(ceil(view_gpu_texture_shader.view_texture_size / 16.0))
	rd.compute_list_dispatch(compute_list, xsteps, ysteps, 1)

#---- core functions
func integrate_s(dt: float, wind_force: Vector2):
	var shader_name = "apply_force"
	var uniform_set = get_uniform_set([
		shader_name,
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		u_texture_rid, 1, RenderingDevice.UNIFORM_TYPE_IMAGE,
		v_texture_rid, 2, RenderingDevice.UNIFORM_TYPE_IMAGE,
		[sampler_nearest, s_texture_rid], 3, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE])

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
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		u_texture_rid, 1, RenderingDevice.UNIFORM_TYPE_IMAGE,
		v_texture_rid, 2, RenderingDevice.UNIFORM_TYPE_IMAGE,
		t_texture_rid, 8, RenderingDevice.UNIFORM_TYPE_IMAGE])

	# Prepare push constants
	var fseed:float = randf()
	var pc_data := PackedFloat32Array([dt, add_perturbance_probability, fseed])
	var pc_bytes = pc_data.to_byte_array()
	pc_bytes.resize(ceil(pc_bytes.size() / 16.0) * 16)
		
	var compute_list = rd.compute_list_begin()
	dispatch(compute_list, shader_name, uniform_set, pc_bytes)

	# Apply boundary conditions to u and v
	var shader_name_bnd_uv = "set_square_bnd_uv_open"
	var uniform_set_bnd_uv = get_uniform_set([
		shader_name_bnd_uv,
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		u_texture_rid, 1, RenderingDevice.UNIFORM_TYPE_IMAGE,
		v_texture_rid, 2, RenderingDevice.UNIFORM_TYPE_IMAGE])
	dispatch_square_bounds(compute_list, shader_name_bnd_uv, uniform_set_bnd_uv)
	rd.compute_list_end()

func apply_ignition():
	var shader_name = "apply_ignition"
	var uniform_set = get_uniform_set([
		shader_name,
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		u_texture_rid, 1, RenderingDevice.UNIFORM_TYPE_IMAGE,
		v_texture_rid, 2, RenderingDevice.UNIFORM_TYPE_IMAGE,
		t_texture_rid, 8, RenderingDevice.UNIFORM_TYPE_IMAGE,
		[sampler_nearest, i_texture_rid], 11, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE])
		
	var compute_list = rd.compute_list_begin()
	dispatch(compute_list, shader_name, uniform_set)
	rd.compute_list_end()

func diffuse_uv(dt:float, num_iters:int):
	var shader_name = "diffuse"
	var shader_name_bnd_uv = "set_square_bnd_uv_open"
	var pc_bytes := PackedFloat32Array([dt, diffuse_visc_value]).to_byte_array()
	pc_bytes.resize(ceil(pc_bytes.size() / 16.0) * 16)

	var compute_list = rd.compute_list_begin()

	for k in range(num_iters):
		swap_uv_buffers()
		var uniform_set = get_uniform_set([
			shader_name,
			consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
			[sampler_nearest, u_texture_prev_rid], 1, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
			u_texture_rid, 2, RenderingDevice.UNIFORM_TYPE_IMAGE,
			[sampler_nearest, s_texture_rid], 3, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE])
		dispatch(compute_list, shader_name, uniform_set, pc_bytes)
		uniform_set = get_uniform_set([
			shader_name,
			consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
			[sampler_nearest, v_texture_prev_rid], 1, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
			v_texture_rid, 2, RenderingDevice.UNIFORM_TYPE_IMAGE,
			[sampler_nearest, s_texture_rid], 3, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE])
		dispatch(compute_list, shader_name, uniform_set, pc_bytes)
	#var uniform_set_bnd_uv = get_uniform_set([
		#shader_name_bnd_uv,
		#consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		#u_texture_rid, 1, RenderingDevice.UNIFORM_TYPE_IMAGE,
		#v_texture_rid, 2, RenderingDevice.UNIFORM_TYPE_IMAGE])
	#dispatch_square_bounds(compute_list, shader_name_bnd_uv, uniform_set_bnd_uv)

	rd.compute_list_end()



func diffuse_t(dt:float, num_iters:int):
	var shader_name = "diffuse"
	var pc_bytes := PackedFloat32Array([dt, diffuse_diff_value]).to_byte_array()
	pc_bytes.resize(ceil(pc_bytes.size() / 16.0) * 16)

	var compute_list = rd.compute_list_begin()

	for k in range(num_iters):
		swap_t_buffer()
		var uniform_set = get_uniform_set([
			shader_name,
			consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
			[sampler_nearest, t_texture_prev_rid], 1, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
			t_texture_rid, 2, RenderingDevice.UNIFORM_TYPE_IMAGE,
			[sampler_nearest, s_texture_rid], 3, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE])
		dispatch(compute_list, shader_name, uniform_set, pc_bytes)

	rd.compute_list_end()



func project_s(num_iters: int):
	
	var compute_list = rd.compute_list_begin()

	# Compute divergence
	var shader_name_div = "project_compute_divergence"
	var uniform_set_div = get_uniform_set([
		shader_name_div,
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		[sampler_nearest, u_texture_rid], 1, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
		[sampler_nearest, v_texture_rid], 2, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
		[sampler_nearest, s_texture_rid], 3, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
		p_texture_rid, 4, RenderingDevice.UNIFORM_TYPE_IMAGE,
		div_texture_rid, 5, RenderingDevice.UNIFORM_TYPE_IMAGE])
	dispatch(compute_list, shader_name_div, uniform_set_div)
	## Apply boundary conditions to div
	var shader_name_bnd_div = "set_square_bnd_div"
	var uniform_set_bnd_div = get_uniform_set([
		shader_name_bnd_div,
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		div_texture_rid, 5, RenderingDevice.UNIFORM_TYPE_IMAGE])
	dispatch_square_bounds(compute_list, shader_name_bnd_div, uniform_set_bnd_div)

	# Solve pressure iterations
	for k in range(num_iters):
		swap_p_buffer()
		var shader_name_p = "project_solve_pressure"
		var uniform_set_p = get_uniform_set([
			shader_name_p,
				consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
				[sampler_nearest, s_texture_rid], 3, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
				p_texture_rid, 4, RenderingDevice.UNIFORM_TYPE_IMAGE,
				[sampler_nearest, div_texture_rid], 5, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
				[sampler_nearest, p_texture_prev_rid], 10, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE])
		dispatch(compute_list, shader_name_p, uniform_set_p)
		## Apply boundary conditions to pressure
		var shader_name_bnd_p = "set_square_bnd_p"
		var uniform_set_bnd_p = get_uniform_set([
			shader_name_bnd_p,
			consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
			p_texture_rid, 4, RenderingDevice.UNIFORM_TYPE_IMAGE])
		dispatch_square_bounds(compute_list, shader_name_bnd_p, uniform_set_bnd_p)

	# Apply pressure gradient
	var shader_name_apply_p = "project_apply_pressure"
	var uniform_set_apply_p = get_uniform_set([
		shader_name_apply_p,
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		u_texture_rid, 1, RenderingDevice.UNIFORM_TYPE_IMAGE,
		v_texture_rid, 2, RenderingDevice.UNIFORM_TYPE_IMAGE,
		[sampler_nearest, s_texture_rid], 3, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
		[sampler_nearest, p_texture_rid], 4, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE])
	dispatch(compute_list, shader_name_apply_p, uniform_set_apply_p)

	# Apply boundary conditions to u and v
	var shader_name_bnd_uv = "set_square_bnd_uv_open"
	var uniform_set_bnd_uv = get_uniform_set([
		shader_name_bnd_uv,
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		u_texture_rid, 1, RenderingDevice.UNIFORM_TYPE_IMAGE,
		v_texture_rid, 2, RenderingDevice.UNIFORM_TYPE_IMAGE])
	dispatch_square_bounds(compute_list, shader_name_bnd_uv, uniform_set_bnd_uv)

	rd.compute_list_end()


func advect(read_texture:RID, write_texture:RID, dt: float):
	var shader_name = "advect"
	var uniform_set = get_uniform_set([
		shader_name,
			consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
			[sampler_nearest, u_texture_rid], 1, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
			[sampler_nearest, v_texture_rid], 2, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
			[sampler_nearest, s_texture_rid], 3, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
			write_texture, 4, RenderingDevice.UNIFORM_TYPE_IMAGE,
			[sampler_nearest, read_texture], 5, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE])

	var pc_bytes := PackedFloat32Array([dt]).to_byte_array()
	pc_bytes.resize(ceil(pc_bytes.size() / 16.0) * 16)

	var compute_list = rd.compute_list_begin()
	dispatch(compute_list, shader_name, uniform_set, pc_bytes)
	rd.compute_list_end()


func stam_advect_temperature(dt: float):
	swap_t_buffer()
	advect(t_texture_prev_rid, t_texture_rid, dt)
	var shader_name_bnd_p = "set_square_bnd_p"
	var uniform_set_bnd_p = get_uniform_set([
		shader_name_bnd_p,
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		p_texture_rid, 4, RenderingDevice.UNIFORM_TYPE_IMAGE])
	var compute_list = rd.compute_list_begin()
	dispatch_square_bounds(compute_list, shader_name_bnd_p, uniform_set_bnd_p)
	rd.compute_list_end()

func stam_advect_vel(dt: float):
	swap_uv_buffers()
	advect(u_texture_prev_rid, u_texture_rid, dt)
	advect(v_texture_prev_rid, v_texture_rid, dt)
	var shader_name_bnd_uv = "set_square_bnd_uv_open"
	var uniform_set_bnd_uv = get_uniform_set([
		shader_name_bnd_uv,
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		u_texture_rid, 1, RenderingDevice.UNIFORM_TYPE_IMAGE,
		v_texture_rid, 2, RenderingDevice.UNIFORM_TYPE_IMAGE])
	var compute_list = rd.compute_list_begin()
	dispatch_square_bounds(compute_list, shader_name_bnd_uv, uniform_set_bnd_uv)
	rd.compute_list_end()

func handle_ignition_gpu():
	if (ignition_changed):
		ignition_changed = false
		rd.texture_update(i_texture_rid, 0, ignition)

func mark_ignition_changed() -> void:
	ignition_changed = true

func view_t():
	var shader_name = "view_t"
	view_gpu_texture_shader.material.set_shader_parameter("t_texture", t_texture)	
	view_gpu_texture_shader.material.shader = texture_shaders[shader_name]

func view_div():
	var compute_list = rd.compute_list_begin()
	var shader_name_div = "project_compute_divergence"
	var uniform_set_div = get_uniform_set([
		shader_name_div,
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		[sampler_nearest, u_texture_rid], 1, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
		[sampler_nearest, v_texture_rid], 2, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
		[sampler_nearest, s_texture_rid], 3, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
		p_texture_rid, 4, RenderingDevice.UNIFORM_TYPE_IMAGE,
		div_texture_rid, 5, RenderingDevice.UNIFORM_TYPE_IMAGE])
	dispatch(compute_list, shader_name_div, uniform_set_div)
	## Apply boundary conditions to div
	var shader_name_bnd_div = "set_square_bnd_div"
	var uniform_set_bnd_div = get_uniform_set([
		shader_name_bnd_div,
		consts_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,
		div_texture_rid, 5, RenderingDevice.UNIFORM_TYPE_IMAGE])
	dispatch_square_bounds(compute_list, shader_name_bnd_div, uniform_set_bnd_div)
	rd.compute_list_end()

	var shader_name = "view_div"
	view_gpu_texture_shader.material.set_shader_parameter("div_texture", div_texture)	
	view_gpu_texture_shader.material.set_shader_parameter("color_scale", debug_div_color_scale)	
	view_gpu_texture_shader.material.shader = texture_shaders[shader_name]

func view_p():
	var shader_name = "view_p"
	view_gpu_texture_shader.material.set_shader_parameter("p_texture", p_texture)	
	view_gpu_texture_shader.material.set_shader_parameter("color_scale", debug_p_color_scale)	
	view_gpu_texture_shader.material.shader = texture_shaders[shader_name]

func view_uv():
	var shader_name = "view_uv"
	view_gpu_texture_shader.material.set_shader_parameter("u_texture", u_texture)	
	view_gpu_texture_shader.material.set_shader_parameter("v_texture", v_texture)	
	view_gpu_texture_shader.material.set_shader_parameter("color_scale", debug_uv_color_scale)	
	view_gpu_texture_shader.material.shader = texture_shaders[shader_name]

# -----------------------------------------------------------------------------------
# UI and debug vars and code
# 

func handle_displaying_output():
	pass
