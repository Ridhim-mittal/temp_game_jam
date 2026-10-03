shader_type canvas_item;
// Comic print shading for the background drawers.
// Vertex alpha is NOT transparency here: it encodes halftone strength
// (alpha 1.0 = flat colour, 0.5 = full dots; see ComicView.halftone()).
// Output is always opaque. Dots live in the node's local space so they stick
// to the surface while it parallaxes (no "shower door" effect).

uniform float dot_spacing = 6.0;
uniform float dot_darkness : hint_range(0.0, 1.0) = 0.42;
uniform float dot_angle = 0.785398; // 45 degrees, classic print screen angle

varying vec4 v_color;
varying vec2 v_local;

void vertex() {
	v_color = COLOR;
	v_local = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = v_color.rgb * tex.rgb;
	float strength = clamp((1.0 - v_color.a) * 2.0, 0.0, 1.0);
	if (strength > 0.001) {
		float c = cos(dot_angle);
		float s = sin(dot_angle);
		vec2 g = mat2(vec2(c, s), vec2(-s, c)) * v_local / dot_spacing;
		float d = length(fract(g) - 0.5);
		// sqrt keeps inked area proportional to strength
		float radius = sqrt(strength) * 0.62;
		float aa = fwidth(d);
		float dots = 1.0 - smoothstep(radius - aa, radius + aa, d);
		rgb = mix(rgb, rgb * (1.0 - dot_darkness), dots);
	}
	COLOR = vec4(rgb, tex.a);
}
