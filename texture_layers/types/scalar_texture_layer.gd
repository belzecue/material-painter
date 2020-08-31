extends "res://texture_layers/texture_layer.gd"

func _init(_name := "Untitled Scalar Texture"):
	name = _name
	properties.value = .5


func get_properties() -> Array:
	return .get_properties() + [Properties.FloatProperty.new("value", 0.0, 1.0)]


func generate_texture() -> void:
	var image := Image.new()
	image.create(int(size.x), int(size.y), false, Image.FORMAT_RGB8)
	image.fill(Color.black.lightened(properties.value))
	texture = ImageTexture.new()
	texture.create_from_image(image)
