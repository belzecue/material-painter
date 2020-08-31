extends "res://texture_layers/texture_layer.gd"

func _init(_name := "Untitled Color Texture"):
	name = _name
	properties.color = Color()


func get_properties() -> Array:
	return .get_properties() + [Properties.ColorProperty.new("color")]


func generate_texture() -> void:
	var image := Image.new()
	image.create(int(size.x), int(size.y), false, Image.FORMAT_RGB8)
	image.fill(properties.color)
	texture = ImageTexture.new()
	texture.create_from_image(image)
