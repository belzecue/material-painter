extends "res://addons/texture_render_viewport/texture_render_viewport.gd"

"""
A `TextureRenderViewport` to render a stack of `BlendingLayer`s

BlendingLayers can have different blend modes.
Either texture masks or float values control the opacities of a blending_layer.
`blend` is called to generate a result from an array of configured `BlendingLayer`s.
A shader is procedurally generated by using string manipulation,
applied to a `ColorRect` and then rendered using `render_texture`.
"""

var cached_shader : Shader

const Constants = preload("constants.gd")

class Layer:
	var code : String
	var uniform_types : Array
	var uniform_names : Array
	var uniform_values : Array

class BlendingLayer extends Layer:
	func _init(generation_code : String, blend_mode := "normal", opacity := 1.0, mask : Texture = null) -> void:
		if mask:
			code = "return blend{mode}({previous}(uv), {code}, texture({mask}, uv).r);".format({
				mode = blend_mode,
				code = generation_code,
			})
			uniform_types.append("sampler2D")
			uniform_names.append("mask")
			uniform_values.append(mask)
		else:
			code = "return blend{mode}({previous}(uv), {code}, {opacity});".format({
				mode = blend_mode,
				code = generation_code,
				opacity = opacity,
			})


func blend(layers : Array, result_size : Vector2, use_cached_shader := false) -> ViewportTexture:
	if layers.size() == 0:
		var color_rect := ColorRect.new()
		color_rect.rect_size = result_size
		return render_texture(color_rect, result_size)
	
	var shader : Shader
	if use_cached_shader and cached_shader:
		shader = cached_shader
	else:
		shader = Shader.new()
		shader.resource_local_to_scene = true
		shader.code = _generate_blending_shader(layers)
		cached_shader = shader
	
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
	var generator_functions := Constants.GENERATOR_FUNCTION_TEMPLATE.format({
		name = _function_name(-1),
		code = "return vec4(1.0);",
	}) + "\n"
	var uniform_count := 0
	
	for layer_num in layers.size():
		var layer := layers[layer_num] as Layer
		var generator_function := Constants.GENERATOR_FUNCTION_TEMPLATE.format({
			name = _function_name(layer_num),
			code = layer.code,
		})
		
		for uniform in layer.uniform_types.size():
			uniform_declaration += "uniform %s %s;\n" % [
					layer.uniform_types[uniform],
					_uniform_var(uniform_count)]
			generator_function = generator_function.replace(
					"{%s}" % layer.uniform_names[uniform],
					_uniform_var(uniform_count))
			uniform_count += 1
		generator_function = generator_function.replace(
				"{previous}",
				_function_name(layer_num - 1))
		
		generator_functions += generator_function + "\n"
	
	var shader_code := Constants.SHADER_TEMPLATE.format({
		uniform_declaration = uniform_declaration,
		blend_shaders = Constants.BLEND_SHADERS,
		generator_functions = generator_functions,
		result_func = _function_name(layers.size() - 1),
	})
	
	return shader_code


static func _setup_shader_vars(material : Material, layers : Array) -> void:
	var uniform_count := 0
	for layer_num in layers.size():
		var layer := layers[layer_num] as Layer
		for uniform in layer.uniform_types.size():
			material.set_shader_param(
					_uniform_var(uniform_count),
					layer.uniform_values[uniform])
			uniform_count += 1


static func _function_name(num : int) -> String:
	return "gen_func_%s" % (num + 1)


static func _uniform_var(num : int) -> String:
	return "uniform_%s" % num
