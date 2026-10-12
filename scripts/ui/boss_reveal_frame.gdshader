shader_type canvas_item;
// The frozen frame behind a boss reveal: drained of colour and pushed into the
// night blue, so the full-colour boss pops against it.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(0.36, 0.40, 0.56);

void fragment() {
	vec3 colour = texture(TEXTURE, UV).rgb;
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));
	vec3 dimmed = mix(colour, vec3(grey), 0.85) * tint;
	COLOR = vec4(mix(colour, dimmed, amount), 1.0);
}
