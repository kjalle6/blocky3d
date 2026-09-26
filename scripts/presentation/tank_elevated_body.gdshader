shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D sprite_sheet : source_color, filter_nearest;
void fragment() {
	vec4 ink = texture(sprite_sheet, UV);
	vec2 pixel = UV * vec2(textureSize(sprite_sheet, 0));
	float frame_x = mod(pixel.x, 48.0);
	// The native barrel becomes a separate pivoted piece only for upward aim.
	if (frame_x >= 23.0 && pixel.y >= 24.0 && pixel.y < 34.0) ink.a = 0.0;
	ALBEDO = ink.rgb * COLOR.rgb;
	ALPHA = ink.a * COLOR.a;
}
