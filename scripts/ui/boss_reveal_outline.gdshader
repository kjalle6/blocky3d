shader_type canvas_item;
// One source pixel of solid outline around a padded sprite frame. Drawn with
// nearest filtering at a whole-number scale, it stays a hard pixel edge.

uniform vec4 outline_colour : source_color = vec4(1.0);

void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	if (colour.a < 0.5) {
		vec2 step_size = TEXTURE_PIXEL_SIZE;
		float near = 0.0;
		near = max(near, texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a);
		near = max(near, texture(TEXTURE, UV - vec2(step_size.x, 0.0)).a);
		near = max(near, texture(TEXTURE, UV + vec2(0.0, step_size.y)).a);
		near = max(near, texture(TEXTURE, UV - vec2(0.0, step_size.y)).a);
		colour = near > 0.5 ? outline_colour : vec4(0.0);
	}
	COLOR = colour;
}
