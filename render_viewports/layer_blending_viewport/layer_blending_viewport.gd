extends "res://addons/texture_render_viewport/texture_render_viewport.gd"

const BLEND_SHADERS := """
vec3 blendmultiplyf(vec3 base, vec3 blend) {
	return base * blend;
}

vec3 blendmultiply(vec3 base, vec3 blend, float opacity) {
	return (blendmultiplyf(base, blend) * opacity + base * (1.0 - opacity));
}


float blenddarkenf(float base, float blend) {
	return min(blend, base);
}

vec3 blenddarkenb(vec3 base, vec3 blend) {
	return vec3(blenddarkenf(base.r, blend.r), blenddarkenf(base.g, blend.g), blenddarkenf(base.b, blend.b));
}

vec3 blenddarken(vec3 base, vec3 blend, float opacity) {
	return (blenddarkenb(base, blend) * opacity + base * (1.0 - opacity));
}


float blendcolordodgef(float base, float blend) {
	return (blend==1.0)?blend:min(base/(1.0-blend), 1.0);
}

vec3 blendcolordodgeb(vec3 base, vec3 blend) {
	return vec3(blendcolordodgef(base.r, blend.r), blendcolordodgef(base.g, blend.g), blendcolordodgef(base.b, blend.b));
}

vec3 blendcolordodge(vec3 base, vec3 blend, float opacity) {
	return (blendcolordodgeb(base, blend) * opacity + base * (1.0 - opacity));
}


float blendcolorburnf(float base, float blend) {
	return (blend == 0.0) ? blend : max((1.0 - ((1.0 - base) / blend)), 0.0);
}

vec3 blendcolorburnb(vec3 base, vec3 blend) {
	return vec3(blendcolorburnf(base.r, blend.r), blendcolorburnf(base.g, blend.g), blendcolorburnf(base.b, blend.b));
}

vec3 blendcolorburn(vec3 base, vec3 blend, float opacity) {
	return (blendcolorburnb(base, blend) * opacity + base * (1.0 - opacity));
}


vec3 blenddifferenceb(vec3 base, vec3 blend) {
	return abs(base-blend);
}

vec3 blenddifference(vec3 base, vec3 blend, float opacity) {
	return (blenddifferenceb(base, blend) * opacity + base * (1.0 - opacity));
}


float blendscreenf(float base, float blend) {
	return 1.0 - ((1.0 - base) * (1.0 - blend));
}

vec3 blendscreenb(vec3 base, vec3 blend) {
	return vec3(blendscreenf(base.r, blend.r), blendscreenf(base.g, blend.g), blendscreenf(base.b, blend.b));
}

vec3 blendscreen(vec3 base, vec3 blend, float opacity) {
	return (blendscreenb(base, blend) * opacity + base * (1.0 - opacity));
}


vec3 blendnormalb(vec3 base, vec3 blend) {
	return blend;
}

vec3 blendnormal(vec3 base, vec3 blend, float opacity) {
	return (blendnormalb(base, blend) * opacity + base * (1.0 - opacity));
}


float blendsubtractf(float base, float blend) {
	return max(base + blend - 1.0, 0.0);
}

vec3 blendsubtractb(vec3 base, vec3 blend) {
	return max(base + blend - vec3(1.0), vec3(0.0));
}

vec3 blendsubtract(vec3 base, vec3 blend, float opacity) {
	return (blendsubtractb(base, blend) * opacity + base * (1.0 - opacity));
}


float blendlightenf(float base, float blend) {
	return max(blend, base);
}

vec3 blendlightenb(vec3 base, vec3 blend) {
	return vec3(blendlightenf(base.r, blend.r), blendlightenf(base.g, blend.g), blendlightenf(base.b, blend.b));
}

vec3 blendlighten(vec3 base, vec3 blend, float opacity) {
	return (blendlightenb(base, blend) * opacity + base * (1.0 - opacity));
}


float blendaddf(float base, float blend) {
	return min(base+blend, 1.0);
}

vec3 blendaddb(vec3 base, vec3 blend) {
	return min(base+blend, vec3(1.0));
}

vec3 blendadd(vec3 base, vec3 blend, float opacity) {
	return (blendaddb(base, blend) * opacity + base * (1.0 - opacity));
}


float blendsoftlightf(float base, float blend) {
	return (blend < 0.5) ? (2.0 * base * blend + base * base * (1.0 - 2.0 * blend)) : (sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base *(1.0 - blend));
}

vec3 blendsoftlightb(vec3 base, vec3 blend) {
	return vec3(blendsoftlightf(base.r, blend.r), blendsoftlightf(base.g, blend.g), blendsoftlightf(base.b, blend.b));
}

vec3 blendsoftlight(vec3 base, vec3 blend, float opacity) {
	return (blendsoftlightb(base, blend) * opacity + base * (1.0 - opacity));
}


float blendoverlayf(float base, float blend) {
	return base < 0.5 ? (2.0 * base * blend) : (1.0 - 2.0 * (1.0 - base) * (1.0 - blend));
}

vec3 blendoverlayb(vec3 base, vec3 blend) {
	return vec3(blendoverlayf(base.r, blend.r), blendoverlayf(base.g, blend.g), blendoverlayf(base.b, blend.b));
}

vec3 blendoverlay(vec3 base, vec3 blend, float opacity) {
	return (blendoverlayb(base, blend) * opacity + base * (1.0 - opacity));
}
"""
const SHADER_TEMPLATE := """shader_type canvas_item;

{uniforms}

{blend_shaders}

void fragment() {
{preparing_code}
	
{blending}
	
	COLOR = {result};
}
"""

const BLEND_TEMPLATE := "vec4 {result} = blend{mode}({a}, {b}, {opacity})"

"""
{result} = {0};
"""

"""
{result} = texture({0}, UV);
"""

class Layer:
	var code : String
	var uniform_types : PoolStringArray
	var uniform_values : Array
	var blend_type : String
	var opacity : float


func blend(layers : Array, result_size : Vector2) -> Texture:
	var shader = Shader.new()
	shader.code = generate_blend_shader(layers)
	var material := ShaderMaterial.new()
	material.shader = shader
	setup_shader_vars(material, layers)
	
	var color_rect := ColorRect.new()
	color_rect.rect_size = result_size
	color_rect.material = material
	
	return render_texture(color_rect, result_size)


static func setup_shader_vars(material : Material, layers : Array) -> void:
	var uniform_count := 0
	for layer_num in layers.size():
		var layer := layers[layer_num] as Layer
		for uniform in layer.uniform_types.size():
			material.set_shader_param(
					uniform_var(uniform_count),
					layer.uniform_values[uniform_count])
			uniform_count += 1


static func generate_blend_shader(layers : Array) -> String:
	var uniforms := ""
	var preparing_code := ""
	var blending_code := ""
	var blend_result_count := 0
	var uniform_count := 0
	
	for layer_num in layers.size():
		var layer := layers[layer_num] as Layer
		var prepared_shader := layer.code.format({
			result = result_var(layer_num)
		})
		for uniform in layer.uniform_types.size():
			uniforms += "uniform %s %s;\n" % [
					layer.uniform_types[uniform],
					uniform_var(uniform_count)]
			prepared_shader.replace(
					"{%s}" % uniform,
					uniform_var(uniform_count))
			uniform_count += 1
		
		preparing_code += prepared_shader + "\n"
		
		blending_code += BLEND_TEMPLATE.format({
			result = blend_result_var(blend_result_count + 1),
			a = blend_result_var(blend_result_count),
			b = result_var(layer_num),
			opacity = layer.opacity,
		}) + "\n"
		
		blend_result_count += 1
	
	var shader_code := BLEND_TEMPLATE.format({
		uniforms = uniforms,
		blend_shaders = BLEND_SHADERS,
		preparing_code = preparing_code,
		blending = blending_code,
		result = blend_result_var(blend_result_count),
	})
	
	return shader_code


static func uniform_var(num : int) -> String:
	return "uniform_%s" % num


static func result_var(num : int) -> String:
	return "result_%s" % num


static func blend_result_var(num : int) -> String:
	return "blend_result_%s" % num