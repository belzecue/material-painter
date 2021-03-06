extends MenuButton

signal bake_mesh_maps_pressed
signal size_selected(size)

func _ready() -> void:
	var popup := get_popup()
	var texture_size_popup := PopupMenu.new()
	texture_size_popup.name = "TextureSizePopupMenu"
	for i in 7:
		texture_size_popup.add_item(str(_get_size(i)))
	texture_size_popup.connect("index_pressed", self, "_on_TextureSizePopupMenu_index_pressed")
	
	popup.connect("id_pressed", self, "_on_PopupMenu_id_pressed")
	popup.add_child(texture_size_popup)
	popup.add_submenu_item("Texture Size", "TextureSizePopupMenu")


func _on_PopupMenu_id_pressed(id : int) -> void:
	if id == 0:
		emit_signal("bake_mesh_maps_pressed")


func _on_TextureSizePopupMenu_index_pressed(index : int) -> void:
	emit_signal("size_selected", Vector2.ONE * _get_size(index))


func _get_size(index : int) -> int:
	return int(pow(2, index + 6))
