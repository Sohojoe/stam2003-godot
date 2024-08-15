@tool
extends Sprite2D

@export var view_texture_size: int = 1024:
	get:
		return view_texture_size
	set(value):
		view_texture_size = value
		_update_texture()

var viewport: Viewport
var view_texture: Texture
var shader_material: ShaderMaterial

func _ready() -> void:
	_update_texture()

func _set_view_texture_size(value):
	view_texture_size = value
	_update_texture()

func _update_texture() -> void:
	# Create a new Viewport
	if viewport:
		viewport.queue_free()  # Clean up existing viewport
	viewport = SubViewport.new()
	#add_something_to_viewport(viewport)
	viewport.size = Vector2(view_texture_size, view_texture_size)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	#viewport.set_clear_mode(Viewport.CLEAR_MODE_ONCE)
	# viewport.usage = SubViewport.usage
	#viewport.render_target_vflip = true  # Ensure the texture is not flipped

	# Get the texture from the viewport
	view_texture = viewport.get_texture()
	texture = view_texture

	# Add the viewport as a child (optional, if you want to display it in the scene)
	add_child(viewport)
	shader_material = ShaderMaterial.new()
	# var shader = preload("res://components/stam_compute_shader/texture_shaders/view_t.gdshader")
	# shader_material.shader = shader
	#var fred = shader.get_shader_uniform_list()
	material = shader_material
	# viewport.set_shader(shader_material)
	
	# Initialize rendering to the viewport using your pipeline
	# _init_render_pipeline()

# func _init_render_pipeline():
	# This is where you set up your shaders and render passes.
	# Bind the viewport's texture to the rendering pipeline
	# This can be done by attaching the viewport's texture to your shader pipeline
	# and performing the render passes.
	
	# Example:
	# var shader_material = ShaderMaterial.new()
	# shader_material.set_shader(your_fragment_shader)
	# viewport.set_shader(shader_material)

	# Then you would execute your render passes to apply your fluid simulation
	# shaders to the viewport's texture, similar to how you used to render
	# to the `Texture2DRD`.

#func add_something_to_viewport(viewport: SubViewport):
	#var label = Label.new()
	#label.text = "Hello world"
	#viewport.add_child(label)
