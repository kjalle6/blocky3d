shader_type canvas_item;
render_mode unshaded;

uniform float elapsed = 0.0;

void fragment() {
	vec4 gun = texture(TEXTURE, UV);
	float progress = clamp(elapsed / 0.28, 0.0, 1.0);
	float edge = 1.12 - progress * 1.24;
	float visible = smoothstep(edge - 0.04, edge + 0.04, UV.y);
	float reveal_line = max(0.0, 1.0 - abs(UV.y - edge) / 0.13) * (1.0 - step(0.28, elapsed));
	float sweep_y = fract(max(elapsed - 0.6, 0.0) * 0.16) * 1.6 - 0.3;
	float sweep = max(0.0, 1.0 - abs(UV.y - sweep_y) / 0.075) * 0.16;
	gun.rgb = mix(gun.rgb, vec3(0.56, 0.97, 1.0), reveal_line * 0.85 + sweep);
	COLOR = vec4(gun.rgb, gun.a * visible);
}
