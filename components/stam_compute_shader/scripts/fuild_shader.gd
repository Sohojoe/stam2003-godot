class_name FluidShader
#extends CanvasLayer
extends Node2D

# ---- global illimination values
@export var gi_skip_sprite_rendering: bool = false
# ---- smoke
@export var burning_obstacle: bool = true
@export var burning_floor: bool = false
@export var burning_campfire: bool = false
@export var swirls: bool = true
@export var paused: bool = false
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
# ---- 

# ----
# ----

@onready var view_fire: Sprite2D = $view_fire
@onready var view_uv: Sprite2D = $view_uv
@onready var view_p: Sprite2D = $view_p
@onready var view_div: Sprite2D = $view_div
@onready var editor_label: RichTextLabel = $EditorLabel


const U_FIELD = 0
const V_FIELD = 1
const T_FIELD = 2

var numX: int
var numY: int
var h: float

var u: PackedFloat32Array
var v: PackedFloat32Array
var div: PackedFloat32Array
var p: PackedFloat32Array
var s: PackedFloat32Array
var t: PackedFloat32Array
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
}

func _ready():
	camera = find_camera(get_tree().current_scene)
	if not camera:
		print("Camera2D not found")

	var canvas_width = 128
	var canvas_height = 128
	var sim_height = 1.0
	c_scale = canvas_height / sim_height
	var sim_width = canvas_width / c_scale
	var num_cells = 128*128
	h = sqrt(sim_width * sim_height / num_cells)
	var num_x = floor(sim_width / h)
	var num_y = floor(sim_height / h)
	setup(num_x, num_y, h)
	# disbale 	editor_label
	editor_label.visible = false


func _process(delta):
	if not is_visible_in_tree():
		return
	if not paused:
		delta = clamp(delta, min_dt, max_dt)
		simulate_stam(delta)
		if view_fire.visible and not gi_skip_sprite_rendering:
			t = rd.buffer_get_data(t_buffer).to_float32_array()
			view_fire.update_shader_params(t, gi_skip_sprite_rendering)
		if view_uv.visible:
			u = rd.buffer_get_data(u_buffer).to_float32_array()
			v = rd.buffer_get_data(v_buffer).to_float32_array()	
			view_uv.update_shader_params(u, v)
			#view_uv.update_shader_params(t, t)
		if view_p.visible:
			p = rd.buffer_get_data(p_buffer).to_float32_array()	
			view_p.update_shader_params(p)
		if view_div.visible:
			div = rd.buffer_get_data(div_buffer).to_float32_array()
			view_div.update_shader_params(div)	


func setup(num_x: int, num_y: int, h_val: float):
	numX = num_x
	numY = num_y
	h = h_val
	u = PackedFloat32Array()
	u.resize(numX * numY)
	v = PackedFloat32Array()
	v.resize(numX * numY)
	div = PackedFloat32Array()
	div.resize(numX * numY)	
	p = PackedFloat32Array()
	p.resize(numX * numY)
	s = PackedFloat32Array()
	s.resize(numX * numY)
	t = PackedFloat32Array()
	t.resize(numX * numY)
	t.fill(0.0)
	s.fill(1.0)
	i = PackedFloat32Array()
	i.resize(numX * numY)
	i.fill(0.0)
	
	rd = RenderingServer.create_local_rendering_device()

	var consts_buffer_bytes := PackedInt32Array([numX, numY]).to_byte_array()
	var h2 = 0.5 * h
	consts_buffer_bytes.append_array(PackedFloat32Array([h, h2]).to_byte_array())
	consts_buffer_bytes.resize(ceil(consts_buffer_bytes.size() / 16.0) * 16)
	consts_buffer = rd.storage_buffer_create(consts_buffer_bytes.size(), consts_buffer_bytes)
	u_buffer = rd.storage_buffer_create(u.size() * 4, u.to_byte_array())
	u_buffer_prev = rd.storage_buffer_create(u.size() * 4, u.to_byte_array())
	v_buffer = rd.storage_buffer_create(v.size() * 4, v.to_byte_array())
	v_buffer_prev = rd.storage_buffer_create(v.size() * 4, v.to_byte_array())
	s_buffer = rd.storage_buffer_create(s.size() * 4, s.to_byte_array())
	p_buffer = rd.storage_buffer_create(p.size() * 4, p.to_byte_array())
	p_buffer_prev = rd.storage_buffer_create(p.size() * 4, p.to_byte_array())
	div_buffer = rd.storage_buffer_create(div.size() * 4, div.to_byte_array())
	t_buffer = rd.storage_buffer_create(t.size() * 4, t.to_byte_array())
	t_buffer_prev = rd.storage_buffer_create(t.size() * 4, t.to_byte_array())
	i_buffer = rd.storage_buffer_create(t.size() * 4, t.to_byte_array())

	for key in shader_file_names.keys():
		var file_name = shader_file_names[key]
		var shader_file = load(file_name)
		var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
		var shader = rd.shader_create_from_spirv(shader_spirv)
		shaders[key] = shader
		pipelines[key] = rd.compute_pipeline_create(shader)

func find_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var result = find_camera(child)
		if result:
			return result
	return null

func simulate_stam(dt: float):
	#--- CPU work
	handle_ignition()

	#--- GPU work
	# integrate_s(dt, wind)
	apply_ignition()
	cool_and_lift(dt)
	diffuse_t(dt, num_iters_diffuse)
	diffuse_uv(dt, num_iters_diffuse)
	project_s(num_iters_projection)
	stam_advect_temperature(dt)
	stam_advect_vel(dt)
	project_s(num_iters_projection)

	#--- wait for gpu
	rd.submit()
	wait_for_gpu()

func wait_for_gpu():
	rd.sync()

#--- helper functions
func get_uniform(buffer, binding: int):
	var rd_uniform = RDUniform.new()
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

	# HACK - doing this to address update_fire() not doing boundaries propery
	# Apply boundary conditions to u and v
	var shader_name_bnd_uv = "set_bnd_uv_open"
	var uniform_set_bnd_uv = get_uniform_set([
		shader_name_bnd_uv,
		consts_buffer, 0,
		u_buffer, 1,
		v_buffer, 2])
	dispatch(compute_list, shader_name_bnd_uv, uniform_set_bnd_uv)

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


var campfire_width_prev: float = -1
var campfire_height_prev: int = -1
func handle_ignition():
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

	# send to gpu
	rd.buffer_update(i_buffer, 0, i.size() * 4, i.to_byte_array())



#func update_fire(dt: float):
	#var fire_cooling = 1.2 * dt
	#var smoke_cooling = 0.3 * dt
	#var lift = 3.0
	#var acceleration = 6.0 * dt
	#var kernel_radius = swirl_max_radius
#
	#var n = numY
	#var max_x = (numX - 1) * h
	#var max_y = (numY - 1) * h
#
#
	## cool temperature, add lift to v
	#var min_r = 0.85 * obstacle_radius
	#var max_r = obstacle_radius + h
	#var cell: int = 0
	#var queued_new_swirls = []
	#
	#var step = 3
	#var normed_1 = 1 * (60.0 * dt);
#
	#var campfire_start = int((numX/2.)-numX/2.*campfire_width)
	#var campfire_end = int((numX/2.)+numX/2.*campfire_width)
	#var center = (campfire_start + campfire_end) / 2.
	#var max_distance = (campfire_end - campfire_start) / 2.
	#if burning_campfire:
		#for row in range(campfire_height):
			#for col in range(campfire_start, campfire_end):
				#t[row * n + col] = 1.0
				#u[row * n + col] = 0.0
				#v[row * n + col] = 0.0 #0.30
#
#
#
	#if cpu_fire:
		#for row in range(numY):
			#for col in range(numX):
				#cell = row * numX + col
				#var t_val = t[cell]
				#var cooling = smoke_cooling if (t_val < 0.3) else fire_cooling
				#t_val = max(t_val - cooling, 0.0)
				#t[cell] = t_val
				##var u_val = u[cell]
				#var v_val = v[cell]
				#var target_v = t_val * lift
				#v[cell] += (target_v - v_val) * acceleration
				#
				#if t_val > 0.8:				
					#var chance = (1.0 - (t_val -0.8) * 10.0) * randf()
					#if chance > 1-(add_perturbance_probability * normed_1):
						#var u_perb = (-1.0 + 2.0 * randf()) * 1
						#var v_perb = (-1.0 + 2.0 * randf()) * 1
						#u_perb = -step if u_perb < -0.333 else step if u_perb > 0.333 else 0.
						#v_perb = -step if v_perb < -0.333 else step if v_perb > 0.333 else 0.
						#u[cell] += u_perb
						#v[cell] += v_perb
#
#
#
#
#
#func sample_field(x: float, y: float, field: int) -> float:
	#var h1 = 1.0 / h
	#var h2 = 0.5 * h
#
	#x = clamp(x, h, numX * h)
	#y = clamp(y, h, numY * h)
#
	#var dx = 0.0
	#var dy = 0.0
#
	#var f: PackedFloat32Array
	#if field == U_FIELD:
		#f = u
		#dy = h2
	#elif field == V_FIELD:
		#f = v
		#dx = h2
	#elif field == T_FIELD:
		#f = t
		#dx = h2
		#dy = h2
#
	#var x0 = min(floor((x - dx) * h1), numX - 1)
	#var tx = ((x - dx) - x0 * h) * h1
	#var x1 = min(x0 + 1, numX - 1)
#
	#var y0 = min(floor((y - dy) * h1), numY - 1)
	#var ty = ((y - dy) - y0 * h) * h1
	#var y1 = min(y0 + 1, numY - 1)
#
	#var sx = 1.0 - tx
	#var sy = 1.0 - ty
#
	#y0 *= numX 
	#y1 *= numX 
	#return sx * sy * f[x0 + y0] + \
		   #tx * sy * f[x1 + y0] + \
		   #tx * ty * f[x1 + y1] + \
		   #sx * ty * f[x0 + y1]
