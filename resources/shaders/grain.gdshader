shader_type canvas_item;
// High-ISO sensor noise over the whole frame. `amount` comes from the noise
// pillar (1 - noise score), so what you see matches how the shot is graded.
// Noise shows most in the shadows, like a real sensor's.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
// 0-1 past the point where the noise pillar bottoms out: adds color blotches.
uniform float chroma : hint_range(0.0, 1.0) = 0.0;
uniform float grain_px = 2.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec3 color = texture(screen_tex, SCREEN_UV).rgb;
	vec2 cell = floor(FRAGCOORD.xy / grain_px);
	// Re-roll the grain 24 times a second, like film frames.
	vec2 seed = cell + floor(TIME * 24.0) * vec2(17.0, 59.0);
	float luma_noise = hash(seed) - 0.5;
	vec3 color_noise = vec3(hash(seed + 0.31), hash(seed + 0.57), hash(seed + 0.83)) - 0.5;
	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	float shadows = mix(1.5, 0.5, clamp(lum, 0.0, 1.0));
	vec3 noise = (vec3(luma_noise) * 0.55 + color_noise * (0.2 + 0.5 * chroma)) * amount * shadows;
	// Noisy sensors also lose contrast and lift the blacks a little.
	color = mix(color, vec3(lum), 0.25 * chroma) + 0.04 * amount;
	COLOR = vec4(color + noise, 1.0);
}
