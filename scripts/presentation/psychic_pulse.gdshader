shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float phase = 0.0;
uniform float opacity = 1.0;
uniform bool cage = false;

void fragment() {
	// Quantized rings preserve the sprite world's pixel scale, with a soft halo.
	vec2 p = (floor(UV * 80.0) + 0.5) / 80.0 - 0.5;
	float r = length(p);
	float radius = cage ? 0.31 + sin(phase * 20.0) * 0.018 : mix(0.035, 0.45, phase);
	float ring = 1.0 - smoothstep(0.009, 0.027, abs(r - radius));
	float echo = (1.0 - smoothstep(0.006, 0.017, abs(r - radius * 0.73))) * 0.5;
	float halo = exp(-abs(r - radius) * 22.0) * 0.22;
	float flash = cage ? 0.0 : exp(-r * 11.0) * max(0.0, 1.0 - phase * 4.0);
	float angle = atan(p.y, p.x);
	float spokes = step(0.88, cos(angle * 8.0 + phase * 5.0)) * (1.0 - smoothstep(0.035, 0.07, abs(r - radius)));
	float light = ring + echo + halo + flash + spokes * 0.7;
	ALBEDO = mix(vec3(0.55, 0.08, 1.0), vec3(1.0, 0.62, 1.0), clamp(ring + flash, 0.0, 1.0));
	ALPHA = clamp(light * opacity, 0.0, 1.0);
}
