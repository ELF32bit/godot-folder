shader_type spatial;

uniform vec3 albedo_color: source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D albedo_texture: hint_default_white;

uniform float wireframe_width_min: hint_range(0.0, 4000.0, 0.01) = 200.0;
uniform float wireframe_width_max: hint_range(0.0, 4000.0, 0.01) = 400.0;
uniform float wireframe_scale: hint_range(0.0, 256000.0, 0.01) = 32000.0;
uniform float wireframe_pow: hint_range(0.0, 32.0, 0.01) = 2.71;

uniform vec4 B_color: source_color = vec4(0.0, 0.0, 0.0, 1.00);
uniform vec4 M_color: source_color = vec4(1.0, 0.0, 0.0, 1.00);
uniform vec4 V_color: source_color = vec4(0.0, 0.0, 1.0, 1.00);
uniform vec4 F_color: source_color = vec4(0.5, 0.5, 0.5, 1.00);
uniform vec4 U_color: source_color = vec4(1.0, 1.0, 0.0, 1.00);
uniform vec4 C_color: source_color = vec4(0.0, 1.0, 0.0, 1.00);
uniform vec4 J_color: source_color = vec4(0.0, 0.0, 0.0, 0.25);

uniform float B_scale: hint_range(0.001, 8.0) = 4.0;
uniform float M_scale: hint_range(0.001, 8.0) = 1.0;
uniform float V_scale: hint_range(0.001, 8.0) = 1.0;
uniform float F_scale: hint_range(0.001, 8.0) = 1.0;
uniform float U_scale: hint_range(0.001, 8.0) = 1.0;
uniform float C_scale: hint_range(0.001, 8.0) = 0.5;
uniform float J_scale: hint_range(0.001, 8.0) = 1.0;

varying flat ivec3 ea; /* edges assignments */
varying flat ivec3 v4eac; /* vertices 4 nearby edges assignments counts */
varying float fragment_distance; /* distance from camera to pixel */
varying vec3 vBC; /* vertices B or C assignment flags */
varying vec3 bc; /* barycentric coordinates */

const vec3 BC_TABLE[4] = {
	vec3(1.0, 1.0, 1.0),
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0)
};

const float VBC_TABLE[4] = { 0.0, 1.0, -1.0, -1.0 };
const float EPSILON = 0.001;

const vec4 V4EAC_TABLE[70] = {
	vec4(0, 0, 0, 0), vec4(0, 0, 0, 1), vec4(0, 0, 0, 2), vec4(0, 0, 0, 3),
	vec4(0, 0, 0, 4), vec4(0, 0, 1, 0), vec4(0, 0, 1, 1), vec4(0, 0, 1, 2),
	vec4(0, 0, 1, 3), vec4(0, 0, 2, 0), vec4(0, 0, 2, 1), vec4(0, 0, 2, 2),
	vec4(0, 0, 3, 0), vec4(0, 0, 3, 1), vec4(0, 0, 4, 0), vec4(0, 1, 0, 0),
	vec4(0, 1, 0, 1), vec4(0, 1, 0, 2), vec4(0, 1, 0, 3), vec4(0, 1, 1, 0),
	vec4(0, 1, 1, 1), vec4(0, 1, 1, 2), vec4(0, 1, 2, 0), vec4(0, 1, 2, 1),
	vec4(0, 1, 3, 0), vec4(0, 2, 0, 0), vec4(0, 2, 0, 1), vec4(0, 2, 0, 2),
	vec4(0, 2, 1, 0), vec4(0, 2, 1, 1), vec4(0, 2, 2, 0), vec4(0, 3, 0, 0),
	vec4(0, 3, 0, 1), vec4(0, 3, 1, 0), vec4(0, 4, 0, 0), vec4(1, 0, 0, 0),
	vec4(1, 0, 0, 1), vec4(1, 0, 0, 2), vec4(1, 0, 0, 3), vec4(1, 0, 1, 0),
	vec4(1, 0, 1, 1), vec4(1, 0, 1, 2), vec4(1, 0, 2, 0), vec4(1, 0, 2, 1),
	vec4(1, 0, 3, 0), vec4(1, 1, 0, 0), vec4(1, 1, 0, 1), vec4(1, 1, 0, 2),
	vec4(1, 1, 1, 0), vec4(1, 1, 1, 1), vec4(1, 1, 2, 0), vec4(1, 2, 0, 0),
	vec4(1, 2, 0, 1), vec4(1, 2, 1, 0), vec4(1, 3, 0, 0), vec4(2, 0, 0, 0),
	vec4(2, 0, 0, 1), vec4(2, 0, 0, 2), vec4(2, 0, 1, 0), vec4(2, 0, 1, 1),
	vec4(2, 0, 2, 0), vec4(2, 1, 0, 0), vec4(2, 1, 0, 1), vec4(2, 1, 1, 0),
	vec4(2, 2, 0, 0), vec4(3, 0, 0, 0), vec4(3, 0, 0, 1), vec4(3, 0, 1, 0),
	vec4(3, 1, 0, 0), vec4(4, 0, 0, 0)
};


void vertex() {
	ivec4 color = ivec4(COLOR * 255.0); /* 0 -> 255 */

	/* unpacking 32 bit color as bits */
	int c32 = 0;
	c32 |= (color.r << 24);
	c32 |= (color.g << 16);
	c32 |= (color.b << 8);
	c32 |= color.a;

	/* unpacking barycentric coordinates */
	bc = BC_TABLE[(c32 >> 2) & 3];

	/* unpacking edges assignments */
	ea.r = ((c32 >> 29) & 7);
	ea.g = ((c32 >> 26) & 7);
	ea.b = ((c32 >> 23) & 7);

	/* unpacking vertices 4 nearby edges assignments counts */
	int v4eac3 = ((c32 >> 4) & 524287);
	v4eac.r = clamp((v4eac3 / 70) / 70, 0, 69);
	v4eac.g = clamp((v4eac3 / 70) % 70, 0, 69);
	v4eac.b = clamp(v4eac3 % 70, 0, 69);

	/* unpacking vertices B and C flags */
	vBC = bc * VBC_TABLE[c32 & 3];

	/* calculating interpolated fragment distance */
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fragment_distance = distance(CAMERA_POSITION_WORLD, world_position);
}


void fragment() {
	vec3 ibc = vec3(1.0) - bc.rgb;
	vec3 scale = fragment_distance / fwidth(bc);

	/* blending between absolute and relative wireframe width */
	float c = max(max(bc.r, bc.g), bc.b);
	float blend = pow(2.0 * clamp(c - 0.5, 0.0, 0.5), wireframe_pow);
	scale = mix(scale, vec3(wireframe_scale), blend);

	/* preparing wireframe edges lookup tables */
	vec4 EA_TABLE[8] = {vec4(1.0, 0.0, 1.0, 1.0),
		J_color, U_color, F_color, V_color, M_color, B_color, C_color};
	float EA_SCALE_TABLE[8] = {1.0,
		J_scale, U_scale, F_scale, V_scale, M_scale, B_scale, C_scale};

	/* obtaining wireframe edges colors */
	vec4 r = EA_TABLE[ea.r];
	vec4 g = EA_TABLE[ea.g];
	vec4 b = EA_TABLE[ea.b];

	/* obtaining wireframe vertices average colors */
	vec4 ir = vec4(0.0); float ir_c = 0.0;
	ir += V4EAC_TABLE[v4eac.r].x * M_color; ir_c += V4EAC_TABLE[v4eac.r].x;
	ir += V4EAC_TABLE[v4eac.r].y * V_color; ir_c += V4EAC_TABLE[v4eac.r].y;
	ir += V4EAC_TABLE[v4eac.r].z * F_color; ir_c += V4EAC_TABLE[v4eac.r].z;
	ir += V4EAC_TABLE[v4eac.r].w * U_color; ir_c += V4EAC_TABLE[v4eac.r].w;
	ir = (ir_c < EPSILON) ? (J_color) : (ir / ir_c);

	vec4 ig = vec4(0.0); float ig_c = 0.0;
	ig += V4EAC_TABLE[v4eac.g].x * M_color; ig_c += V4EAC_TABLE[v4eac.g].x;
	ig += V4EAC_TABLE[v4eac.g].y * V_color; ig_c += V4EAC_TABLE[v4eac.g].y;
	ig += V4EAC_TABLE[v4eac.g].z * F_color; ig_c += V4EAC_TABLE[v4eac.g].z;
	ig += V4EAC_TABLE[v4eac.g].w * U_color; ig_c += V4EAC_TABLE[v4eac.g].w;
	ig = (ig_c < EPSILON) ? (J_color) : (ig / ig_c);

	vec4 ib = vec4(0.0); float ib_c = 0.0;
	ib += V4EAC_TABLE[v4eac.b].x * M_color; ib_c += V4EAC_TABLE[v4eac.b].x;
	ib += V4EAC_TABLE[v4eac.b].y * V_color; ib_c += V4EAC_TABLE[v4eac.b].y;
	ib += V4EAC_TABLE[v4eac.b].z * F_color; ib_c += V4EAC_TABLE[v4eac.b].z;
	ib += V4EAC_TABLE[v4eac.b].w * U_color; ib_c += V4EAC_TABLE[v4eac.b].w;
	ib = (ib_c < EPSILON) ? (J_color) : (ib / ib_c);

	/* obtaining wireframe vertices average scale */
	float irs = 1.0; float irs_c = 0.0;
	irs += V4EAC_TABLE[v4eac.r].x * M_scale; irs_c += V4EAC_TABLE[v4eac.r].x;
	irs += V4EAC_TABLE[v4eac.r].y * V_scale; irs_c += V4EAC_TABLE[v4eac.r].y;
	irs += V4EAC_TABLE[v4eac.r].z * F_scale; irs_c += V4EAC_TABLE[v4eac.r].z;
	irs += V4EAC_TABLE[v4eac.r].w * U_scale; irs_c += V4EAC_TABLE[v4eac.r].w;
	irs = (irs_c < EPSILON) ? (J_scale) : (irs / irs_c);

	float igs = 1.0; float igs_c = 0.0;
	igs += V4EAC_TABLE[v4eac.g].x * M_scale; igs_c += V4EAC_TABLE[v4eac.g].x;
	igs += V4EAC_TABLE[v4eac.g].y * V_scale; igs_c += V4EAC_TABLE[v4eac.g].y;
	igs += V4EAC_TABLE[v4eac.g].z * F_scale; igs_c += V4EAC_TABLE[v4eac.g].z;
	igs += V4EAC_TABLE[v4eac.g].w * U_scale; igs_c += V4EAC_TABLE[v4eac.g].w;
	igs = (igs_c < EPSILON) ? (J_scale) : (igs / igs_c);

	float ibs = 1.0; float ibs_c = 0.0;
	ibs += V4EAC_TABLE[v4eac.b].x * M_scale; ibs_c += V4EAC_TABLE[v4eac.b].x;
	ibs += V4EAC_TABLE[v4eac.b].y * V_scale; ibs_c += V4EAC_TABLE[v4eac.b].y;
	ibs += V4EAC_TABLE[v4eac.b].z * F_scale; ibs_c += V4EAC_TABLE[v4eac.b].z;
	ibs += V4EAC_TABLE[v4eac.b].w * U_scale; ibs_c += V4EAC_TABLE[v4eac.b].w;
	ibs = (ibs_c < EPSILON) ? (J_scale) : (ibs / ibs_c);

	/* coloring intersections with B or C edges without averaging */
	if (vBC.r > EPSILON) { ir = EA_TABLE[6]; }
	else if (vBC.r < -EPSILON) { ir = EA_TABLE[7]; }

	if (vBC.g > EPSILON) { ig = EA_TABLE[6]; }
	else if (vBC.g < -EPSILON) { ig = EA_TABLE[7]; }

	if (vBC.b > EPSILON) { ib = EA_TABLE[6]; }
	else if (vBC.b < -EPSILON) { ib = EA_TABLE[7]; }

	/* alpha blending edges and vertices colors */
	r.rgb = mix(albedo_color, r.rgb, r.a);
	g.rgb = mix(albedo_color, g.rgb, g.a);
	b.rgb = mix(albedo_color, b.rgb, b.a);
	ir.rgb = mix(albedo_color, ir.rgb, ir.a);
	ig.rgb = mix(albedo_color, ig.rgb, ig.a);
	ib.rgb = mix(albedo_color, ib.rgb, ib.a);

	/* wireframe width based on edge assignment */
	vec3 width_min = vec3(wireframe_width_min);
	vec3 width_max = vec3(wireframe_width_max);
	width_min.r *= EA_SCALE_TABLE[ea.r]; width_max.r *= EA_SCALE_TABLE[ea.r];
	width_min.g *= EA_SCALE_TABLE[ea.g]; width_max.g *= EA_SCALE_TABLE[ea.g];
	width_min.b *= EA_SCALE_TABLE[ea.b]; width_max.b *= EA_SCALE_TABLE[ea.b];

	vec3 iwidth_min = vec3(wireframe_width_min);
	vec3 iwidth_max = vec3(wireframe_width_max);
	if (vBC.r > EPSILON) { iwidth_min.r *= B_scale; iwidth_max.r *= B_scale; }
	else if (vBC.r < -EPSILON) { iwidth_min.r *= C_scale; iwidth_max.r *= C_scale; }
	else { iwidth_min.r *= irs; iwidth_max.r *= irs; }

	if (vBC.g > EPSILON) { iwidth_min.g *= B_scale; iwidth_max.g *= B_scale; }
	else if (vBC.g < -EPSILON) { iwidth_min.g *= C_scale; iwidth_max.g *= C_scale; }
	else { iwidth_min.g *= igs; iwidth_max.g *= igs; }

	if (vBC.b > EPSILON) { iwidth_min.b *= B_scale; iwidth_max.b *= B_scale; }
	else if (vBC.b < -EPSILON) { iwidth_min.b *= C_scale; iwidth_max.b *= C_scale; }
	else { iwidth_min.b *= ibs; iwidth_max.b *= ibs; }

	/* wireframe edges mask */
	vec3 mask = width_max;
	mask.r = min(width_max.r, bc.r * scale.r);
	mask.g = min(width_max.g, bc.g * scale.g);
	mask.b = min(width_max.b, bc.b * scale.b);
	mask.r = smoothstep(width_min.r, width_max.r, mask.r);
	mask.g = smoothstep(width_min.g, width_max.g, mask.g);
	mask.b = smoothstep(width_min.b, width_max.b, mask.b);

	/* wireframe vertices mask */
	vec3 imask = iwidth_max;
	imask.r = min(iwidth_max.r, ibc.r * scale.r);
	imask.g = min(iwidth_max.g, ibc.g * scale.g);
	imask.b = min(iwidth_max.b, ibc.b * scale.b);
	imask.r = smoothstep(iwidth_min.r, iwidth_max.r, imask.r);
	imask.g = smoothstep(iwidth_min.g, iwidth_max.g, imask.g);
	imask.b = smoothstep(iwidth_min.b, iwidth_max.b, imask.b);

	/* drawing wireframe edges in the best possible order */
	vec3 albedo = vec3(ALBEDO);
	if (ea.r >= ea.g && ea.g >= ea.b) {
		albedo = mix(b.rgb, albedo, mask.b);
		albedo = mix(g.rgb, albedo, mask.g);
		albedo = mix(r.rgb, albedo, mask.r);
	} else if (ea.r >= ea.b && ea.b >= ea.g) {
		albedo = mix(g.rgb, albedo, mask.g);
		albedo = mix(b.rgb, albedo, mask.b);
		albedo = mix(r.rgb, albedo, mask.r);
	} else if (ea.b >= ea.r && ea.r >= ea.g) {
		albedo = mix(g.rgb, albedo, mask.g);
		albedo = mix(r.rgb, albedo, mask.r);
		albedo = mix(b.rgb, albedo, mask.b);
	} else if (ea.b >= ea.g && ea.g >= ea.r) {
		albedo = mix(r.rgb, albedo, mask.r);
		albedo = mix(g.rgb, albedo, mask.g);
		albedo = mix(b.rgb, albedo, mask.b);
	} else if (ea.g >= ea.r && ea.r >= ea.b) {
		albedo = mix(b.rgb, albedo, mask.b);
		albedo = mix(r.rgb, albedo, mask.r);
		albedo = mix(g.rgb, albedo, mask.g);
	} else if (ea.g >= ea.b && ea.b >= ea.r) {
		albedo = mix(r.rgb, albedo, mask.r);
		albedo = mix(b.rgb, albedo, mask.b);
		albedo = mix(g.rgb, albedo, mask.g);
	}

	/* drawing vertices */
	vec3 ialbedo = vec3(albedo);
	ialbedo = mix(ir.rgb, ialbedo, imask.r);
	ialbedo = mix(ig.rgb, ialbedo, imask.g);
	ialbedo = mix(ib.rgb, ialbedo, imask.b);

	ALBEDO = ialbedo;
}