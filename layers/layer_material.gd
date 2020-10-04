extends Resource

"""
A material whose maps are generated by blending several `MaterialLayers`

`layers` contains the `MaterialLayers`, each of which
can have multiple channels enabled.
When generating the results, all `LayerTexture`s of each map
are blended together and stored in the `results` `Dictionary`.
It stores the blended `Texture`s with the map names as keys.

To make it possible to use Viewports inside of sub-resources of MaterialLayers,
this and every `Resource` class that is used inside of it has to be local to scene.
"""

export var layers : Array

var results : Dictionary

const TextureLayer = preload("res://layers/texture_layer.gd")
const MaterialLayer = preload("res://layers/material_layer.gd")
const BlendingLayer = preload("res://addons/layer_blending_viewport/layer_blending_viewport.gd").BlendingLayer
const LayerTexture = preload("res://layers/layer_texture.gd")
const FolderLayer = preload("res://layers/folder_layer.gd")

func _init() -> void:
	resource_local_to_scene = true


func update_results(result_size : Vector2) -> void:
	var flat_layers := get_flat_layers(layers, false)
	for map in Globals.TEXTURE_MAP_TYPES:
		var blending_layers := []
		for layer in flat_layers:
			if not (map in layer.maps and layer.maps[map]):
				continue
			var map_layer_texture : LayerTexture = layer.maps[map]
			map_layer_texture.update_result(result_size)
			
			var blending_layer := BlendingLayer.new()
			if layer.mask:
				layer.mask.update_result(result_size)
				blending_layer.mask = layer.mask.result
			blending_layer.code = "texture({0}, UV).rgb"
			blending_layer.uniform_types = ["sampler2D"]
			blending_layer.uniform_values = [map_layer_texture.result]
			blending_layers.append(blending_layer)
		
		if blending_layers.empty():
			results.erase(map)
			continue
		
		var result : Texture = yield(LayerBlendViewportManager.blend(
				blending_layers, result_size, map.hash()), "completed")
		
		if map == "height":
			map = "normal"
			result = yield(NormalMapGenerationViewport.get_normal_map(result), "completed")
		results[map] = result



func update_all_layer_textures(result_size : Vector2) -> void:
	var flat_layers := get_flat_layers(layers, false)
	for layer in flat_layers:
		var result = layer.update_all_layer_textures(result_size)
		if result is GDScriptFunctionState:
			result = yield(result, "completed")


func export_textures(to_folder : String) -> void:
	for type in results.keys():
		results[type].get_data().save_png(to_folder.plus_file(type) + ".png")


func get_depending_layer_texture(texture_layer : TextureLayer) -> LayerTexture:
	for layer in get_flat_layers():
		layer = layer as MaterialLayer
		var depending_layer = layer.get_depending_layer_texture(texture_layer)
		if depending_layer:
			return depending_layer
	return null


func get_layer_texture_of_texture_layer(texture_layer):
	for layer in get_flat_layers():
		var layer_texture = layer.get_layer_texture_of_texture_layer(texture_layer)
		if layer_texture:
			return layer_texture


func get_flat_layers(layer_array : Array = layers, add_hidden := true) -> Array:
	var flat_layers := []
	for layer in layer_array:
		if (not add_hidden) and not layer.visible:
			continue
		if layer is FolderLayer:
			flat_layers += get_flat_layers(layer.layers, add_hidden)
		else:
			flat_layers.append(layer)
	return flat_layers


func get_folders(layer_array : Array = layers) -> Array:
	var folders := []
	for layer in layer_array:
		if layer is FolderLayer:
			folders.append(layer)
			folders += get_folders(layer.layers)
	return folders


func get_parent(layer):
	if layer in layers:
		return self
	else:
		for folder in get_folders():
			if layer in folder.layers:
				return folder
	for layer in get_flat_layers():
		for layer_texture in layer.get_layer_textures():
			var parent = layer_texture.get_parent(layer)
			if parent:
				return parent
	return []
