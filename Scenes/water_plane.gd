extends MeshInstance3D

var material :ShaderMaterial
var noise :Image
var noise_scale :float = 0
var height_scale :float = 0
var time: float = 0

func _ready():
	material = $".".get_surface_override_material (0)

	noise = material.get_shader_parameter("wave").noise.get_seamless_image(512,512)
	noise_scale = material.get_shader_parameter("noise_scale")
	height_scale = material.get_shader_parameter("height_scale")

func _process(delta):
	time += delta
	material.set_shader_parameter("wave_time", time)

func get_height(world_position: Vector3) -> float:
	var uv_x = wrapf(world_position.x / noise_scale + time, 0, 1)
	var uv_y = wrapf(world_position.z / noise_scale + time, 0, 1)
	var pixel_pos = Vector2(uv_x* noise.get_width(), uv_y * noise.get_width())

	return global_position.y + noise.get_pixelv(pixel_pos).r * height_scale
