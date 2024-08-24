@tool
extends Sprite2D

@export var view_texture_size: int = 1024:
	get:
		return view_texture_size
	set(value):
		view_texture_size = value
		_update_texture()



var view_texture

func _ready() -> void:
	_update_texture()

func _set_view_texture_size(value):
	view_texture_size = value
	_update_texture()

func _update_texture() -> void:
	var rd = RenderingServer.get_rendering_device()
	var fmt3 = RDTextureFormat.new()
	fmt3.width = view_texture_size
	fmt3.height = view_texture_size
	fmt3.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt3.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | \
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | \
			RenderingDevice.SAMPLER_FILTER_NEAREST
	var view3 = RDTextureView.new()
	var default_color = Color(1.0, 1.0, 0.0, .2)
	var data = PackedFloat32Array()
	data.resize(view_texture_size * view_texture_size * 4) # 4
	for i in range(0, view_texture_size * view_texture_size * 4, 4):
		data[i] = default_color.r
		data[i + 1] = default_color.g
		data[i + 2] = default_color.b
		data[i + 3] = default_color.a
	view_texture = rd.texture_create(fmt3, view3, [data.to_byte_array()])
	var texture_rd = Texture2DRD.new()
	texture_rd.texture_rd_rid = view_texture
	texture = texture_rd
