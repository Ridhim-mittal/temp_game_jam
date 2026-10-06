shader_type spatial;
// Ink outline as a second pass ("inverted hull"): the mesh is pushed out a
// little and only its back faces are drawn, leaving a dark rim around the
// silhouette. from_center = 1 pushes along the direction from the mesh
// centre, which keeps box corners closed; 0 uses the normals (smooth meshes).
// Drawn in the transparent pass (fully opaque ink, no depth write) so it stays
// out of the sun's shadow map: as an opaque pass every outline was drawn into
// the shadows too, ~440 wasted draw calls a frame in the hub; it looks the same.
render_mode unshaded, cull_front, specular_disabled, blend_mix, depth_draw_never;

uniform vec4 ink : source_color = vec4(0.06, 0.04, 0.09, 1.0);
uniform float width = 0.04;
uniform float from_center : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	vec3 dir = normalize(mix(NORMAL, normalize(VERTEX + vec3(0.0, 1e-4, 0.0)), from_center));
	// Constant world width even on scaled nodes.
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX += dir * width / max(s, vec3(1e-3));
}

void fragment() {
	ALBEDO = ink.rgb;
	ALPHA = 1.0;
}
