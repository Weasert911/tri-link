shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float brightness : hint_range(0.5, 1.5) = 1.08;
uniform float saturation : hint_range(0.5, 1.5) = 1.12;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
uniform vec3 tint : source_color = vec3(1.0, 0.99, 0.97);
uniform int posterize_steps : hint_range(0, 12) = 6;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.18;
uniform float glow_threshold : hint_range(0.0, 1.0) = 0.68;
uniform float glow_softness : hint_range(0.0, 0.5) = 0.12;

void fragment() {
	vec3 color = texture(screen_tex, SCREEN_UV).rgb * brightness;
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(luminance), color, saturation);
	color = (color - 0.5) * contrast + 0.5;
	if (posterize_steps > 1) {
		float steps = float(posterize_steps);
		color = floor(color * steps + 0.5) / steps;
	}
	float glow = smoothstep(glow_threshold, glow_threshold + glow_softness, luminance);
	color += color * glow * glow_strength;
	COLOR = vec4(clamp(color * tint, vec3(0.0), vec3(1.0)), 1.0);
}
