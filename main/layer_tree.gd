extends Tree

"""
An interactive representation of a `LayerMaterial` as a tree

The tree consists of a list of `MaterialLayer`s with the `TextureLayer`s
of the selected `LayerTexture` below.
Shows previews of maps and masks as buttons.
"""

var root : TreeItem
var tree_items : Dictionary = {}
var selected_maps : Dictionary = {}
var selected_layer_textures : Dictionary = {}
var clicked_layer : MaterialLayer

signal material_layer_selected(material_layer)
signal texture_layer_selected(texture_layer)

enum Buttons {
	MASK,
	RESULT,
	MAP_DROPDOWN,
	VISIBILITY,
}

const LayerMaterial = preload("res://layers/layer_material.gd")
const MaterialLayer = preload("res://layers/material_layer.gd")
const LayerTexture = preload("res://layers/layer_texture.gd")
const TextureLayer = preload("res://layers/texture_layer.gd")
const FileTextureLayer = preload("res://layers/texture_layers/file_texture_layer.gd")

onready var main : Control = $"../../../../.."
onready var material_layer_popup_menu : PopupMenu = $MaterialLayerPopupMenu
onready var map_type_popup_menu : PopupMenu = $MapTypePopupMenu

func _ready() -> void:
	columns = 2
	set_column_expand(0, false)
	set_column_min_width(0, 100)


func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed:
		material_layer_popup_menu.rect_global_position = event.global_position
		material_layer_popup_menu.popup()


func can_drop_data(_position : Vector2, data) -> bool:
	return data is Dictionary and "asset" in data


func drop_data(position : Vector2, data) -> void:
	if data.asset is String:
		var layer := FileTextureLayer.new()
		layer.path = data.asset
		main.add_texture_layer(layer, selected_layer_textures[get_item_at_position(position).get_meta("layer")])
	elif data.asset is MaterialLayer:
		main.add_material_layer(data.asset)


func setup_layer_material(layer_material : LayerMaterial) -> void:
	tree_items = {}
	clear()
	root = create_item()
	for material_layer in layer_material.layers:
		setup_material_layer_item(material_layer)
	update_icons()


func setup_material_layer_item(material_layer : MaterialLayer) -> void:
	var material_layer_item := create_item(root)
	material_layer_item.set_meta("layer", material_layer)
	
	if not material_layer in selected_maps:
		if material_layer.maps.size() > 0:
			selected_maps[material_layer] = material_layer.maps.values().front()
	var selected_layer_texture : LayerTexture
	if material_layer in selected_layer_textures:
		selected_layer_texture = selected_layer_textures[material_layer]
	
	if material_layer.mask:
		material_layer_item.add_button(0, ImageTexture.new(), Buttons.MASK)
	if material_layer.maps.size() > 0:
		material_layer_item.add_button(0, ImageTexture.new(), Buttons.RESULT)
	if material_layer.maps.size() > 1:
		material_layer_item.add_button(0, preload("res://icons/down.svg"), Buttons.MAP_DROPDOWN)
	
	material_layer_item.set_text(1, material_layer.name)
	material_layer_item.add_button(1, preload("res://icons/icon_visible.svg"), Buttons.VISIBILITY)
	
	material_layer_item.set_custom_draw(0, self, "_draw_material_layer_item")
	
	tree_items[material_layer] = material_layer_item
	
	if selected_layer_texture:
		for texture_layer in selected_layer_texture.layers:
			setup_texture_layer_item(texture_layer, material_layer_item)


func setup_texture_layer_item(texture_layer : TextureLayer, on_item : TreeItem) -> void:
	var texture_layer_item := create_item(on_item)
	texture_layer_item.set_meta("layer", texture_layer)
	texture_layer_item.add_button(0, ImageTexture.new(), Buttons.RESULT)
	texture_layer_item.set_text(1, "Texture Layer")
	texture_layer_item.add_button(1, preload("res://icons/icon_visible.svg"), Buttons.VISIBILITY)
	tree_items[texture_layer] = texture_layer_item


func update_icons() -> void:
	for layer in tree_items.keys():
		var tree_item : TreeItem = tree_items[layer]
		if layer is TextureLayer:
			tree_item.set_button(0, 0, yield(layer.generate_result(Vector2(32, 32), false), "completed"))
		elif layer is MaterialLayer:
			var button_count := 0
			if layer.mask:
				tree_item.set_button(0, 0, yield(layer.mask.generate_result(Vector2(32, 32), false), "completed"))
				button_count += 1
			if layer.maps.size() > 0:
				if layer in selected_maps:
					var selected_map : LayerTexture = selected_maps[layer]
					tree_item.set_button(0, button_count, yield(selected_map.generate_result(Vector2(32, 32), false), "completed"))


func get_selected_material_layer() -> MaterialLayer:
	return _get_selected_material_layer_item().get_meta("layer")


func get_selected_texture_layer() -> TextureLayer:
	return get_selected().get_meta("layer") as TextureLayer


func get_selected_layer_texture() -> LayerTexture:
	return selected_layer_textures[get_selected_material_layer()] as LayerTexture


func _get_selected_material_layer_item() -> TreeItem:
	if get_selected().get_meta("layer") is MaterialLayer:
		return get_selected()
	else:
		return get_selected().get_parent()


func _on_button_pressed(item : TreeItem, _column : int, id : int) -> void:
	match id:
		Buttons.MAP_DROPDOWN:
			clicked_layer = item.get_meta("layer")
			map_type_popup_menu.rect_global_position = get_global_transform().xform(get_item_area_rect(item).position)
			map_type_popup_menu.popup()
		Buttons.RESULT:
			var material_layer : MaterialLayer = item.get_meta("layer")
			if material_layer in selected_layer_textures and selected_layer_textures[material_layer] == selected_maps[material_layer]:
				selected_layer_textures.erase(material_layer)
			else:
				selected_layer_textures[material_layer] = selected_maps[material_layer]
			setup_layer_material(main.editing_layer_material)
		Buttons.MASK:
			var material_layer : MaterialLayer = item.get_meta("layer")
			if material_layer in selected_layer_textures and selected_layer_textures[material_layer] == material_layer.mask:
				selected_layer_textures.erase(material_layer)
			else:
				selected_layer_textures[material_layer] = material_layer.mask
			setup_layer_material(main.editing_layer_material)
		Buttons.VISIBILITY:
			pass


func _on_MapTypePopupMenu_id_pressed(id : int) -> void:
	var selected_map : LayerTexture = clicked_layer.maps.values()[id]
	selected_maps[clicked_layer] = selected_map
	selected_layer_textures[clicked_layer] = selected_map
	setup_layer_material(main.editing_layer_material)


func _on_cell_selected() -> void:
	var layer = get_selected().get_meta("layer")
	if layer is MaterialLayer:
		emit_signal("material_layer_selected", layer)
	elif layer is TextureLayer:
		emit_signal("texture_layer_selected", layer)


func _on_MapTypePopupMenu_about_to_show() -> void:
	map_type_popup_menu.clear()
	for map in clicked_layer.maps:
		map_type_popup_menu.add_item(map)
		var icon : ImageTexture = yield(
			clicked_layer.maps[map].generate_result(Vector2(32, 32), false), "completed")
		map_type_popup_menu.set_item_icon(map_type_popup_menu.get_item_count() - 1, icon)


func _draw_material_layer_item(_material_layer_item : TreeItem, _item_rect : Rect2) -> void:
	# no way to get button regions, so no selection border
	pass
