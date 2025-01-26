shader_type canvas_item;

uniform sampler2D dissolve_texture : source_color, filter_nearest;
uniform float dissolve_value : hint_range(0,1);
uniform float burn_size: hint_range(0.0, 1.0, 0.01);
uniform vec4 burn_color: source_color;


varying vec4 modulate;
void vertex() 
{
    modulate = COLOR;
}
void fragment(){
    vec4 main_texture = texture(TEXTURE, UV);
    vec4 noise_texture = texture(dissolve_texture, UV);
	
	// Snapped UV
	float size_x = float(textureSize(TEXTURE, 0).x);
	float size_y = float(textureSize(TEXTURE, 0).y) / 5.0;
	vec2 UVr = vec2(floor(UV.x*size_x)/size_x, floor(UV.y*size_y)/size_y);
	// This is needed to avoid keeping a small burn_color dot with dissolve being 0 or 1
	// is there another way to do it?
	float burn_size_step = burn_size * step(0.001, dissolve_value) * step(dissolve_value, 0.999);
	float threshold = smoothstep(noise_texture.x-burn_size_step, noise_texture.x, dissolve_value);
	float border = smoothstep(noise_texture.x, noise_texture.x + burn_size_step, dissolve_value);
	
	COLOR.a *= threshold;
	COLOR.rgb = mix(burn_color.rgb, main_texture.rgb, border);
	COLOR *= modulate;
}

//float random(vec2 uv) {
	//return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 438.5453);
//}
//
//uniform float sensitivity : hint_range(0.0, 1.0) = .5;

//void fragment() {
	// Get size of texture in pixels
	//vec4 main_texture = texture(TEXTURE, UV);
    //vec4 noise_texture = texture(dissolve_texture, UV);
	//
	//// This is needed to avoid keeping a small burn_color dot with dissolve being 0 or 1
	//// is there another way to do it?
	//float burn_size_step = burn_size * step(0.001, dissolve_value) * step(dissolve_value, 0.999);
	//float threshold = smoothstep(noise_texture.x-burn_size_step, noise_texture.x, dissolve_value);
	//float border = smoothstep(noise_texture.x, noise_texture.x + burn_size_step, dissolve_value);
	////
	//COLOR.a *= threshold;
	//COLOR.rgb = mix(burn_color.rgb, main_texture.rgb, border);
	//vec4 pixelColor = texture(TEXTURE, UV);
	// Create a new "UV" which remaps every UV value to a snapped pixel value
	// Determine whether pixel should be visible or not
	//float visible = step(sensitivity, random(UVr));
	// Draw the pixel, or not depending on if it is visible or not
	//COLOR = vec4(pixelColor.r, pixelColor.g, pixelColor.b, min(visible, pixelColor.a));
	//COLOR *= modulate;
//}
