shader_type canvas_item;
// The comic page's panels in the climb out of the Margins (page_climb.gd):
// crops of the city painting drawn as the story coming back to life on the
// way up. The vertex colour's red channel is the panel's life: 0 a dead
// panel of the Margins (dark, faded, all but rubbed out), then a pencil
// rough, then inked line art, then the full-colour page with its ink, and at
// 1 the picture untouched (the last frame of the 3D Margins). Alpha is alpha.

const vec3 PAPER = vec3(0.94, 0.91, 0.84);
const vec3 DEAD = vec3(0.12, 0.11, 0.13);
const vec3 GRAPHITE = vec3(0.34, 0.33, 0.37);
const vec3 INK = vec3(0.05, 0.03, 0.1);

varying float life;
varying float alpha;

void vertex() {
	life = COLOR.r;
	alpha = COLOR.a;
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.55, 0.15));
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	vec2 px = TEXTURE_PIXEL_SIZE * 1.5;
	float l = lum(c);
	float gx = lum(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb) - lum(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb);
	float gy = lum(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb) - lum(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb);
	float edge = smoothstep(0.06, 0.22, length(vec2(gx, gy)));
	// dead: a faded, all but rubbed-out grey ghost of the picture
	vec3 dead = DEAD + vec3(0.1) * l + vec3(0.07) * edge;
	// pencil: graphite lines on paper, hatching in the dark parts
	vec2 h = UV / (TEXTURE_PIXEL_SIZE * 7.0);
	float hatch = step(0.55, fract(h.x + h.y)) * (1.0 - smoothstep(0.18, 0.42, l));
	vec3 pencil = mix(PAPER, GRAPHITE, max(edge * 0.85, hatch * 0.4));
	// ink: black lines, flat greys
	float tone = floor(l * 3.0 + 0.5) / 3.0;
	vec3 inked = mix(mix(vec3(0.58, 0.56, 0.6), PAPER, tone), INK, edge);
	// colour: the page itself, inked
	vec3 colour = mix(c, INK, edge * 0.55);
	vec3 o = dead;
	o = mix(o, pencil, smoothstep(0.15, 0.32, life));
	o = mix(o, inked, smoothstep(0.38, 0.55, life));
	o = mix(o, colour, smoothstep(0.62, 0.8, life));
	o = mix(o, c, smoothstep(0.9, 1.0, life));
	COLOR = vec4(o, alpha);
}
