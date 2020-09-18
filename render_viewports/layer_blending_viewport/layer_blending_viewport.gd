extends "res://addons/texture_render_viewport/texture_render_viewport.gd"

"""
A `TextureRenderViewport` to render a stack of blending_layers

BlendingLayers can have different blend modes.
Either texture masks or float values control the opacities of a blending_layer.
To generate the result, call `blend` with an array of configured `BlendingLayer`s.
A shader is procedurally generated, applied to a `ColorRect`
and then rendered using `render_texture`.
"""

const Constants = preload("res://render_viewports/layer_blending_viewport/constants.gd")

class BlendingLayer:
	var code : String
	var uniform_types : PoolStringArray
	var uniform_values : Array
# warning-ignore:unused_class_variable
	var blend_mode := "normal"
	var opacity := 1.0
	var mask : Texture

func blend(layers : Array, result_size : Vector2) -> ViewportTexture:
	if layers.size() == 0:
		var color_rect := ColorRect.new()
		color_rect.rect_size = result_size
		return render_texture(color_rect, result_size)
	
	var shader := Shader.new()
	shader.resource_local_to_scene = true
	shader.code = _generate_blending_shader(layers)
	
	var material := ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = shader
	_setup_shader_vars(material, layers)
	
	var color_rect := ColorRect.new()
	color_rect.rect_size = result_size
	color_rect.material = material
	
	return render_texture(color_rect, result_size)


static func _generate_blending_shader(layers : Array) -> String:
	var uniform_declaration := ""
	var preparing_code := ""
	var blending_code := ""
	var blend_result_count := 0
	var uniform_count := 0
	
	for layer_num in layers.size():
		var layer := layers[layer_num] as BlendingLayer
		var prepared_shader := Constants.RESULT_TEMPLATE.format({
			result = _result_var(layer_num),
			code = layer.code,
		})
		
		if layer.mask:
			uniform_declaration += "uniform sampler2D %s;\n" % _mask_var(layer_num)
		
		for uniform in layer.uniform_types.size():
			uniform_declaration += "uniform %s %s;\n" % [
					layer.uniform_types[uniform],
					_uniform_var(uniform_count)]
			prepared_shader = prepared_shader.replace(
					"{%s}" % uniform,
					_uniform_var(uniform_count))
			uniform_count += 1
		
		preparing_code += prepared_shader + "\n"
		
		if layer_num > 0:
			var template : String
			if layer.mask:
				template = Constants.MASKED_BLEND_TEMPLATE
			else:
				template = Constants.BLEND_TEMPLATE
			
			blending_code += template.format({
					result = _blend_result_var(blend_result_count + 1),
					a = _result_var(0) if layer_num == 1 else _blend_result_var(blend_result_count),
					b = _result_var(layer_num),
					mode = layer.blend_mode,
# warning-ignore:incompatible_ternary
# warning-ignore:incompatible_ternary
					opacity = _mask_var(layer_num) if layer.mask else layer.opacity,
				})
			blending_code += "\n"
			blend_result_count += 1
	
	var shader_code := Constants.SHADER_TEMPLATE.format({
		uniform_declaration = uniform_declaration,
		blend_shaders = Constants.BLEND_SHADERS,
		preparing_code = preparing_code,
		blending_code = blending_code,
		result = _blend_result_var(blend_result_count) if layers.size() > 1 else _result_var(0),
	})
	
	return shader_code


static func _setup_shader_vars(material : Material, layers : Array) -> void:
	var uniform_count := 0
	for layer_num in layers.size():
		var layer := layers[layer_num] as BlendingLayer
		
		if layer.mask:
			material.set_shader_param(_mask_var(layer_num), layer.mask)
		
		for uniform in layer.uniform_types.size():
			material.set_shader_param(
					_uniform_var(uniform_count),
					layer.uniform_values[uniform])
			uniform_count += 1


static func _uniform_var(num : int) -> String:
	return "uniform_%s" % num


static func _result_var(num : int) -> String:
	return "result_%s" % num


static func _blend_result_var(num : int) -> String:
	return "blend_result_%s" % num


static func _mask_var(num : int) -> String:
	return "mask_%s" % num
