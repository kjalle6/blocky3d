shader_type canvas_item;
render_mode unshaded;

uniform float elapsed = 0.0;
uniform vec2 display_size = vec2(504.0, 210.0);

void fragment() {
	// The display and its lighting share the surrounding GUI's two-pixel grid.
	vec2 p = floor(UV * display_size / 2.0) * 2.0;
	vec2 uv = p / display_size;
	vec3 base = vec3(0.018, 0.033, 0.07);
	float pulse = 0.9 + 0.1 * sin(elapsed * 1.8);
	float glow = exp(-length((uv - vec2(0.5, 0.48)) * vec2(4.0, 3.0)));
	base += vec3(0.008, 0.09, 0.13) * glow;
	// Light spills inward from the pink and cyan strips recessed into the frame.
	base += vec3(0.22, 0.014, 0.13) * exp(-uv.x * 15.0) * pulse * 0.42;
	base += vec3(0.01, 0.18, 0.25) * exp(-(1.0 - uv.x) * 15.0) * pulse * 0.42;

	// A subdued perspective floor keeps the weapon suspended within the display.
	float depth = max(uv.y - 0.50, 0.0);
	float lane = abs(fract((uv.x - 0.5) / (depth + 0.28) * 5.0 + 0.5) - 0.5);
	float row = abs(fract(log(depth + 0.2) * 5.0) - 0.5);
	float grid = (1.0 - step(0.014, lane)) + (1.0 - step(0.035, row));
	base += vec3(0.01, 0.18, 0.23) * grid * smoothstep(0.02, 0.16, depth) * 0.5;
	base *= 1.0 - (1.0 - step(1.0, mod(p.y, 6.0))) * 0.12;

	// One luminous blue line, always behind the sprite: no floating particles.
	float beam_y = floor((display_size.y * 0.48 + sin(elapsed * 0.7) * 6.0) / 2.0) * 2.0;
	float distance_y = abs(p.y - beam_y);
	float core = 1.0 - step(1.0, distance_y);
	float halo = exp(-distance_y / 6.0);
	float spread = exp(-distance_y / 19.0);
	float entrance = smoothstep(0.0, 0.28, elapsed);
	base += (vec3(0.10, 0.61, 0.78) * core
		+ vec3(0.012, 0.14, 0.23) * halo
		+ vec3(0.0, 0.025, 0.07) * spread) * entrance * pulse;
	COLOR = vec4(base, 1.0);
}
