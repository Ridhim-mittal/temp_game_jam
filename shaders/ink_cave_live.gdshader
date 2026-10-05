shader_type canvas_item;
// Brings the Ink Cave's painting (assets/backgrounds/ink_cave.webp) to life
// like a live wallpaper: the bright ink-fire (hot pink, yellow, cyan) licks
// upwards and flickers, the glowing ink river ripples sideways, and the whole
// cave breathes with the fire's light. Masks come from the painting's own
// colours, so the dark rock stays still.

uniform float flame_amount = 0.010;   // UV displacement inside the fire
uniform float flame_speed = 0.55;     // how fast the fire's turbulence rises
uniform float river_amount = 0.006;   // sideways ripple in the ink river
uniform float river_top = 0.74;       // UV y where the river / floor starts
uniform float pulse = 0.12;           // brightness flicker of the fire
uniform float shake = 0.0;            // the cave collapsing (cave_arena.gd)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// how "fire-like" a colour is: bright and saturated
float fire_mask(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx - mn;
	return smoothstep(0.28, 0.6, sat) * smoothstep(0.35, 0.75, mx);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	if (shake > 0.0) {
		uv += (vec2(hash(vec2(floor(t * 30.0), 1.0)), hash(vec2(floor(t * 30.0), 2.0))) - 0.5) * 0.02 * shake;
	}
	vec3 base = texture(TEXTURE, uv).rgb;
	// soft mask: blur the mask a little by sampling around (stops it tearing at edges)
	float m = fire_mask(base);
	m = max(m, fire_mask(texture(TEXTURE, uv + vec2(0.0, 0.012)).rgb));
	m = max(m, fire_mask(texture(TEXTURE, uv - vec2(0.0, 0.012)).rgb)) * 0.9;
	float above_floor = 1.0 - smoothstep(river_top - 0.04, river_top + 0.02, uv.y);
	float river = smoothstep(river_top - 0.02, river_top + 0.04, uv.y);

	// fire: rising turbulence, stronger higher up in the flame
	vec2 q = vec2(uv.x * 7.0, uv.y * 5.0 + t * flame_speed * 3.0);
	vec2 flow = vec2(fbm(q) - 0.5, fbm(q + vec2(5.2, 1.3)) - 0.5);
	vec2 disp = flow * flame_amount * 2.0 * m * above_floor;
	disp.y += (fbm(q * 1.7) - 0.3) * flame_amount * m * above_floor;  // flames lick upwards
	// river: sideways ripples
	float wave = sin(uv.y * 160.0 - t * 2.4 + fbm(vec2(uv.x * 6.0, t * 0.3)) * 6.0);
	disp.x += wave * river_amount * river * m;

	vec4 col = texture(TEXTURE, uv + disp);
	float m2 = fire_mask(col.rgb);
	// flicker: patches of fire brighten and dim
	float flick = fbm(vec2(uv.x * 4.0, uv.y * 3.0 + t * 1.6)) - 0.45;
	col.rgb *= 1.0 + flick * pulse * 2.4 * m2;
	// hot cores glow white-ish now and then
	col.rgb += vec3(1.0, 0.85, 0.7) * pow(max(flick, 0.0), 2.0) * 0.5 * m2 * above_floor;
	// the whole cave breathes with the fire's light
	float breathe = 0.5 + 0.5 * sin(t * 1.3) * 0.6 + 0.4 * sin(t * 3.7 + 1.0) * 0.4;
	col.rgb *= 0.9 + 0.12 * breathe;
	COLOR = vec4(col.rgb, 1.0) * COLOR;
}
