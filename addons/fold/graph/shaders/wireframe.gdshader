shader_type spatial;

uniform vec3 albedo_color: source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D albedo_texture: hint_default_white;

uniform float width_min = 10.0;
uniform float width_max = 20.0;

uniform float B_scale = 4.0;
uniform vec4 B_color: source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 M_color: source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 V_color: source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 F_color: source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 U_color: source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 C_color: source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform vec4 J_color: source_color = vec4(0.0, 0.0, 0.0, 0.25);
uniform float fade: hint_range(0.0, 1.0, 0.01) = 1.0;

varying vec3 bc; /* barycentric coordinates */
varying vec3 v_bmv; /* vertex flags (B, MV, M/V ratio) */
varying flat ivec3 ea; /* edges assignment */
varying flat vec3 efa; /* edges fold angle */
varying float fragment_distance;
const float MARGIN = 0.75;
const float EPS = 0.001;


vec3 iaverage(vec3 i) {
	vec3 o;
	o.r = (i.g + i.b) * 0.5;
	o.g = (i.r + i.g) * 0.5;
	o.b = (i.r + i.g) * 0.5;
	return o;
}


vec4 get_assignment_color(int assignment) {
	if (assignment == 7) { return B_color; }
	if (assignment == 6) { return M_color; }
	if (assignment == 5) { return V_color; }
	if (assignment == 4) { return F_color; }
	if (assignment == 3) { return U_color; }
	if (assignment == 2) { return C_color; }
	if (assignment == 1) { return J_color; }
	return vec4(1.0, 0.0, 1.0, 1.0);
}


void vertex() {
	ivec4 color = ivec4(COLOR * 255.0);

	int rgb = (color.a >> 6);
	if (rgb == 1) { bc = vec3(1.0, 0.0, 0.0); }            /* 11000000 */
	if (rgb == 2) { bc = vec3(0.0, 1.0, 0.0); }            /* 11000000 */
	if (rgb == 3) { bc = vec3(0.0, 0.0, 1.0); }            /* 11000000 */
	v_bmv.x = float((color.a & 32) >> 5);                  /* 00100000 */
	v_bmv.y = float(int((color.a & 31) == 31));            /* 00011111 */
	v_bmv.z = float(color.a & 31) / 30.0;                  /* 00011111 */

	ea.r = (color.r >> 5);                                 /* 11100000 */
	ea.g = (color.g >> 5);                                 /* 11100000 */
	ea.b = (color.b >> 5);                                 /* 11100000 */
	efa.r = float(color.r & 31) / 31.0;                    /* 00011111 */
	efa.g = float(color.g & 31) / 31.0;                    /* 00011111 */
	efa.b = float(color.b & 31) / 31.0;                    /* 00011111 */
	efa = vec3(fade);

	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fragment_distance = distance(CAMERA_POSITION_WORLD, world_position);
}


void fragment() {
	vec3 ibc = vec3(1.0) - bc.rgb;
	vec3 scale = fragment_distance / fwidth(bc);
	vec3 iscale = scale;

	ALBEDO = albedo_color;
	vec4 r = get_assignment_color(ea.r);
	vec4 g = get_assignment_color(ea.g);
	vec4 b = get_assignment_color(ea.b);

	/* width blending */
	vec3 rgb_a = vec3(r.a, g.a, b.a);
	vec3 w1 = 2.0 * max(rgb_a - vec3(0.5), vec3(0.0));
	vec3 w2 = 2.0 * min(rgb_a, vec3(0.5));

	/* alpha blending */
	vec3 albedo = vec3(ALBEDO);
	r.rgb = mix(albedo, r.rgb, r.a);
	g.rgb = mix(albedo, g.rgb, g.a);
	b.rgb = mix(albedo, b.rgb, b.a);

	/* edges width */
	float Bs = B_scale;
	vec3 efa_s = vec3(1.0) + efa;
	vec3 min_width = vec3(width_min) * w1;
	vec3 max_width = vec3(width_max) * w2 - EPS;
	if (ea.r == 7) { min_width.r *= Bs; max_width.r *= Bs; }
	else { min_width.r *= efa_s.r; max_width.r *= efa_s.r; }
	if (ea.g == 7) { min_width.g *= Bs; max_width.g *= Bs; }
	else { min_width.g *= efa_s.g; max_width.g *= efa_s.g; }
	if (ea.b == 7) { min_width.b *= Bs; max_width.b *= Bs; }
	else { min_width.b *= efa_s.b; max_width.b *= efa_s.b; }

	/* edges mask */
	vec3 mask;
	mask.r = min(max_width.r, bc.r * scale.r);
	mask.g = min(max_width.g, bc.g * scale.g);
	mask.b = min(max_width.b, bc.b * scale.b);
	mask.r = smoothstep(min_width.r, max_width.r, mask.r);
	mask.g = smoothstep(min_width.g, max_width.g, mask.g);
	mask.b = smoothstep(min_width.b, max_width.b, mask.b);

	/* edges fold angle fading effect */
	vec3 efa_f = min(vec3(0.5) + efa, vec3(1.0));
	if (ea.r != 7) { r.rgb = mix(albedo_color.rgb, r.rgb, efa_f.r); }
	if (ea.g != 7) { g.rgb = mix(albedo_color.rgb, g.rgb, efa_f.g); }
	if (ea.b != 7) { b.rgb = mix(albedo_color.rgb, b.rgb, efa_f.b); }

	/* drawing edges in the best possible order */
	ALBEDO = albedo_color.rgb;
	if (ea.r >= ea.g && ea.g >= ea.b) {
		ALBEDO = mix(b.rgb, ALBEDO, mask.b);
		ALBEDO = mix(g.rgb, ALBEDO, mask.g);
		ALBEDO = mix(r.rgb, ALBEDO, mask.r);
	} else if (ea.r >= ea.b && ea.b >= ea.g) {
		ALBEDO = mix(g.rgb, ALBEDO, mask.g);
		ALBEDO = mix(b.rgb, ALBEDO, mask.b);
		ALBEDO = mix(r.rgb, ALBEDO, mask.r);
	} else if (ea.b >= ea.r && ea.r >= ea.g) {
		ALBEDO = mix(g.rgb, ALBEDO, mask.g);
		ALBEDO = mix(r.rgb, ALBEDO, mask.r);
		ALBEDO = mix(b.rgb, ALBEDO, mask.b);
	} else if (ea.b >= ea.g && ea.g >= ea.r) {
		ALBEDO = mix(r.rgb, ALBEDO, mask.r);
		ALBEDO = mix(g.rgb, ALBEDO, mask.g);
		ALBEDO = mix(b.rgb, ALBEDO, mask.b);
	} else if (ea.g >= ea.r && ea.r >= ea.b) {
		ALBEDO = mix(b.rgb, ALBEDO, mask.b);
		ALBEDO = mix(r.rgb, ALBEDO, mask.r);
		ALBEDO = mix(g.rgb, ALBEDO, mask.g);
	} else if (ea.g >= ea.b && ea.b >= ea.r) {
		ALBEDO = mix(r.rgb, ALBEDO, mask.r);
		ALBEDO = mix(b.rgb, ALBEDO, mask.b);
		ALBEDO = mix(g.rgb, ALBEDO, mask.g);
	}

	/* vertices width */
	float iBs = Bs;
	vec3 iefa_s = vec3(1.0) + iaverage(efa);
	vec3 imin_width = vec3(width_min) * iaverage(w1);
	vec3 imax_width = vec3(width_max) * iaverage(w2) - EPS;
	if (v_bmv.x > MARGIN) { // TODO: ...
		imin_width = vec3(width_min) * iBs;
		imax_width = vec3(width_max) * iBs;
	} else { imin_width *= iefa_s; imax_width *= iefa_s; }

	/* vertices mask */
	vec3 imask;
	imask.r = min(imax_width.r, ibc.r * iscale.r);
	imask.g = min(imax_width.g, ibc.g * iscale.g);
	imask.b = min(imax_width.b, ibc.b * iscale.b);
	imask.r = smoothstep(imin_width.r, imax_width.r, imask.r);
	imask.g = smoothstep(imin_width.g, imax_width.g, imask.g);
	imask.b = smoothstep(imin_width.b, imax_width.b, imask.b);

	/* hiding vertices from B edges */
	if (ea.g == 7 || ea.b == 7) { imask.r = 1.0; }
	if (ea.r == 7 || ea.b == 7) { imask.g = 1.0; }
	if (ea.r == 7 || ea.g == 7) { imask.b = 1.0; }

	/* coloring vertices */
	vec3 B_ca = mix(albedo, B_color.rgb, B_color.a);
	vec3 M_ca = mix(albedo, M_color.rgb, M_color.a);
	vec3 V_ca = mix(albedo, V_color.rgb, V_color.a);
	vec3 J_ca = mix(albedo, J_color.rgb, J_color.a);

	vec3 i_color = mix(M_ca.rgb, V_ca.rgb, v_bmv.z);
	if (v_bmv.y > MARGIN) { i_color = mix(ALBEDO, J_ca.rgb, J_color.a); }
	else if (v_bmv.x > MARGIN) {i_color = mix(ALBEDO, B_ca.rgb, B_color.a); }
	else { i_color = mix(albedo, i_color, efa_f); }

	/* drawing vertices */
	ALBEDO = mix(i_color, ALBEDO, imask.r);
	ALBEDO = mix(i_color, ALBEDO, imask.g);
	ALBEDO = mix(i_color, ALBEDO, imask.b);
}