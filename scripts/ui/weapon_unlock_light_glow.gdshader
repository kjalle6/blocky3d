shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 strip_size = vec2(40.0, 4.0);
uniform float padding = 24.0;
uniform float strength = 1.0;

void fragment() {
	// Bloom only the authored strip, without blurring or sampling the game.
	vec2 p = (UV - vec2(0.5)) * (strip_size + vec2(padding * 2.0));
	vec2 outside = max(abs(p) - strip_size * 0.5, vec2(0.0));
	float distance_squared = dot(outside, outside);
	float tight = exp(-distance_squared / 32.0);
	float soft = exp(-distance_squared / 220.0);
	float edge = 1.0 - smoothstep(padding - 4.0, padding, length(outside));
	float halo = (tight * 0.42 + soft * 0.16) * edge * strength;
	COLOR = vec4(COLOR.rgb, COLOR.a * halo);
}
