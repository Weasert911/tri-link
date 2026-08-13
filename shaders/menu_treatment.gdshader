shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float darkness : hint_range(0.0, 1.0) = 0.48;
uniform float desaturation : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 1.2);
	float gray = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 color = mix(source.rgb, vec3(gray), desaturation);
	vec2 centered = UV - vec2(0.5);
	float vignette = smoothstep(0.2, 0.78, length(centered));
	color *= 1.0 - darkness - vignette * 0.28;
	COLOR = vec4(color, 1.0);
}
