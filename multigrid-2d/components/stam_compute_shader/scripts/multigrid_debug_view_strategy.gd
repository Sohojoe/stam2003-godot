class_name MultigridDebugViewStrategy
extends DebugViewStrategy

var debug_color_scale:float = 0.0002
var sampler_nearest_0:RID
var sampler_nearest_clamp:RID
var sampler_linear_clamp:RID

var compute_list:int
var rd: RenderingDevice
var num_steps:int = 0
var cur_step_idx:int = 0

var uniform_sets = {}
var shaders = {}
var pipelines = {}
var shader_file_names = {
	"view_div": "res://components/stam_compute_shader/texture_shaders/view_div.glsl",
	"view_p": "res://components/stam_compute_shader/texture_shaders/view_p.glsl",
	"view_uv": "res://components/stam_compute_shader/texture_shaders/view_uv.glsl",
	"view_residual": "res://components/stam_compute_shader/texture_shaders/view_residual.glsl",
}
var debug_view_sprite2d: Sprite2D
var debug_string:String = ""
var cur_group:String = ""
var is_enabled:bool = false
var view_step_idx:int = 0

## Called at the beginning of each render frame to initialize debug strategy.
func begin(
	_compute_list:int,
	_rd:RenderingDevice,
	_debug_view_sprite2d: Sprite2D
):
	var rd_prev = rd
	compute_list = _compute_list
	rd = _rd
	debug_view_sprite2d = _debug_view_sprite2d

	if rd != rd_prev:
		lazy_init()

	if cur_step_idx != num_steps:
		num_steps = cur_step_idx
		if view_step_idx >= num_steps:
			view_step_idx = num_steps - 1

	cur_step_idx = 0
	cur_group = ""

## Called to add a view step to the debug strategy.
func add_step(
	_key:String,
	_texture_rid:RID,
	_multigrid_idx:int
):
	if is_enabled and view_step_idx == cur_step_idx:
		add_step_to_compute_list(_key, _texture_rid, _multigrid_idx)
	cur_step_idx += 1


## Returns the debug name of the step at the given index.
func get_step_debug_name(_step_idx:int) -> String:
	return debug_string

func next_view():
	view_step_idx += 1
	if view_step_idx >= num_steps:
		view_step_idx = 0

func previous_view():
	view_step_idx -= 1
	if view_step_idx < 0:
		view_step_idx = num_steps - 1

func enable_debug(new_state:bool):
	is_enabled = new_state

func is_debug_enabled() -> bool:
	return is_enabled


func _init():
	is_enabled = false
	
func lazy_init():
	view_step_idx = 0
	var ss = RDSamplerState.new()
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_BORDER
	ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_BORDER
	ss.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_BORDER
	ss.border_color = RenderingDevice.SAMPLER_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK
	sampler_nearest_0 = rd.sampler_create(ss)
	var ss2 = RDSamplerState.new()
	#ss2.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	#ss2.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss2.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss2.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss2.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_nearest_clamp = rd.sampler_create(ss2)
	var ss3 = RDSamplerState.new()
	ss3.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss3.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss3.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss3.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss3.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_linear_clamp = rd.sampler_create(ss3)
	var filenames = shader_file_names
	for key in filenames.keys():
		var file_name = filenames[key]
		var shader_file = load(file_name)
		var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
		var shader = rd.shader_create_from_spirv(shader_spirv)
		shaders[key] = shader
		pipelines[key] = rd.compute_pipeline_create(shader)


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

func add_step_to_compute_list(
	key:String,
	texture_rid:RID,
	multigrid_idx:int
):
	debug_string = "step: " + str(cur_step_idx)
	if cur_group != "":
		debug_string += "\n group: " + str(cur_group)
	debug_string += "\n " + key
	debug_string += "\n multigrid idx: " + str(multigrid_idx)
	match key:
		"calculate_residual":
			render_debug_view("view_residual", texture_rid, debug_color_scale)
		"project_solve_pressure":
			render_debug_view("view_p", texture_rid, debug_color_scale)
		"project_compute_divergence", "restriction":
			render_debug_view("view_div", texture_rid, debug_color_scale)
		"prolongate_correction":
			render_debug_view("view_residual", texture_rid, debug_color_scale)
		"add_correction_to_pressure":
			render_debug_view("view_p", texture_rid, debug_color_scale)
		"smooth_pressure_up":
			render_debug_view("view_p", texture_rid, debug_color_scale)
		"view_uv":
			render_debug_view("view_uv", texture_rid, debug_color_scale)
		"uv":
			render_debug_view("view_uv", texture_rid, debug_color_scale)
		_:
			debug_string += "\n error: unknown key: " + key

func render_debug_view(
	shader_name:String,
	texture_rid:RID,
	color_scale:float
):
	var pc_data := PackedFloat32Array([color_scale])
	var pc_bytes = pc_data.to_byte_array()
	pc_bytes.resize(ceil(pc_bytes.size() / 16.0) * 16)
	var uniform_set = get_uniform_set([
		shader_name,
		[sampler_nearest_0, texture_rid], 1, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
		debug_view_sprite2d.view_texture, 2, RenderingDevice.UNIFORM_TYPE_IMAGE],
		)
	# dispatch_view(compute_list, shader_name, uniform_set, pc_bytes)
	rd.compute_list_bind_compute_pipeline(compute_list, pipelines[shader_name])
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	if pc_bytes:
		rd.compute_list_set_push_constant(compute_list, pc_bytes, pc_bytes.size())
	var xsteps = int(ceil(debug_view_sprite2d.view_texture_size / 16.0))
	var ysteps = int(ceil(debug_view_sprite2d.view_texture_size / 16.0))
	rd.compute_list_dispatch(compute_list, xsteps, ysteps, 1)
