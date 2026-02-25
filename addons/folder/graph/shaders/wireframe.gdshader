shader_type spatial;

uniform vec3 albedo_color: source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D albedo_texture: source_color, hint_default_white;
uniform float alpha_scissor_threshold: hint_range(0.0, 1.0, 0.001) = 0.5;

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
varying flat ivec3 v4eac; /* vertices 4 nearby edges MVFU counts */
varying float fragment_distance; /* distance from camera to pixel */
varying vec3 vBC; /* vertices B or C assignment flags */
varying vec3 bc; /* barycentric coordinates */

const vec3 BC_TABLE[4] = {
	vec3(1.0, 1.0, 1.0),
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0)
};

const float EPSILON = 0.001;
const float VBC_TABLE[4] = { 0.0, 1.0, -1.0, -1.0 };

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


mat3 get_V4EAC_colors_sum() {
	mat3 sum = mat3(vec3(0.0), vec3(0.0), vec3(0.0));
	sum[0] += V4EAC_TABLE[v4eac.r].x * M_color.rgb * M_color.a;
	sum[0] += V4EAC_TABLE[v4eac.r].y * V_color.rgb * V_color.a;
	sum[0] += V4EAC_TABLE[v4eac.r].z * F_color.rgb * F_color.a;
	sum[0] += V4EAC_TABLE[v4eac.r].w * U_color.rgb * U_color.a;
	sum[1] += V4EAC_TABLE[v4eac.g].x * M_color.rgb * M_color.a;
	sum[1] += V4EAC_TABLE[v4eac.g].y * V_color.rgb * V_color.a;
	sum[1] += V4EAC_TABLE[v4eac.g].z * F_color.rgb * F_color.a;
	sum[1] += V4EAC_TABLE[v4eac.g].w * U_color.rgb * U_color.a;
	sum[2] += V4EAC_TABLE[v4eac.b].x * M_color.rgb * M_color.a;
	sum[2] += V4EAC_TABLE[v4eac.b].y * V_color.rgb * V_color.a;
	sum[2] += V4EAC_TABLE[v4eac.b].z * F_color.rgb * F_color.a;
	sum[2] += V4EAC_TABLE[v4eac.b].w * U_color.rgb * U_color.a;
	return sum;
}


vec3 get_V4EAC_scales_sum() {
	vec3 sum = vec3(0.0);
	sum.r += V4EAC_TABLE[v4eac.r].x * M_scale * M_color.a;
	sum.r += V4EAC_TABLE[v4eac.r].y * V_scale * V_color.a;
	sum.r += V4EAC_TABLE[v4eac.r].z * F_scale * F_color.a;
	sum.r += V4EAC_TABLE[v4eac.r].w * U_scale * U_color.a;
	sum.g += V4EAC_TABLE[v4eac.g].x * M_scale * M_color.a;
	sum.g += V4EAC_TABLE[v4eac.g].y * V_scale * V_color.a;
	sum.g += V4EAC_TABLE[v4eac.g].z * F_scale * F_color.a;
	sum.g += V4EAC_TABLE[v4eac.g].w * U_scale * U_color.a;
	sum.b += V4EAC_TABLE[v4eac.b].x * M_scale * M_color.a;
	sum.b += V4EAC_TABLE[v4eac.b].y * V_scale * V_color.a;
	sum.b += V4EAC_TABLE[v4eac.b].z * F_scale * F_color.a;
	sum.b += V4EAC_TABLE[v4eac.b].w * U_scale * U_color.a;
	return sum;
}


vec3 get_V4EAC_components_sum() {
	vec3 sum = vec3(0.0);
	sum.r += V4EAC_TABLE[v4eac.r].x * M_color.a;
	sum.r += V4EAC_TABLE[v4eac.r].y * V_color.a;
	sum.r += V4EAC_TABLE[v4eac.r].z * F_color.a;
	sum.r += V4EAC_TABLE[v4eac.r].w * U_color.a;
	sum.g += V4EAC_TABLE[v4eac.g].x * M_color.a;
	sum.g += V4EAC_TABLE[v4eac.g].y * V_color.a;
	sum.g += V4EAC_TABLE[v4eac.g].z * F_color.a;
	sum.g += V4EAC_TABLE[v4eac.g].w * U_color.a;
	sum.b += V4EAC_TABLE[v4eac.b].x * M_color.a;
	sum.b += V4EAC_TABLE[v4eac.b].y * V_color.a;
	sum.b += V4EAC_TABLE[v4eac.b].z * F_color.a;
	sum.b += V4EAC_TABLE[v4eac.b].w * U_color.a;
	return sum;
}


void vertex() {
	ivec4 color = ivec4(COLOR * 255.0); /* 0 -> 255 */

	/* unpacking 32 bit color as bits */
	int c32 = color.a;
	c32 |= (color.r << 24);
	c32 |= (color.g << 16);
	c32 |= (color.b << 8);

	/* unpacking barycentric coordinates */
	bc = BC_TABLE[clamp((c32 >> 2) & 3, 0, 3)];

	/* unpacking edges assignments */
	ea.r = clamp(((c32 >> 29) & 7), 0, 7);
	ea.g = clamp(((c32 >> 26) & 7), 0, 7);
	ea.b = clamp(((c32 >> 23) & 7), 0, 7);

	/* unpacking vertices 4 nearby edges assignments counts */
	int v4eac3 = ((c32 >> 4) & 524287);
	v4eac.r = clamp((v4eac3 / 70) / 70, 0, 69);
	v4eac.g = clamp((v4eac3 / 70) % 70, 0, 69);
	v4eac.b = clamp(v4eac3 % 70, 0, 69);

	/* unpacking vertices B and C flags */
	vBC = bc * VBC_TABLE[clamp(c32 & 3, 0, 3)];

	/* calculating interpolated fragment distance */
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fragment_distance = distance(CAMERA_POSITION_WORLD, world_position);
}


void fragment() {
	/* drawing textures */
	vec4 albedo_texture_color = texture(albedo_texture, UV);
	if (albedo_texture_color.a < alpha_scissor_threshold) { discard; }
	ALBEDO = albedo_texture_color.rgb * albedo_color;

	/* blending between absolute and relative wireframe width */
	vec3 ibc = vec3(1.0) - bc.rgb;
	float c = max(max(bc.r, bc.g), bc.b);
	vec3 scale = fragment_distance / fwidth(bc);
	float blend = pow(2.0 * clamp(c - 0.5, 0.0, 0.5), wireframe_pow);
	scale = mix(scale, vec3(wireframe_scale), blend);

	/* preparing wireframe edges assignments color and scale tables */
	vec4 EA_COLOR_TABLE[8] = {vec4(1.0, 0.0, 1.0, 1.0),
		J_color, U_color, F_color, V_color, M_color, B_color, C_color};
	float EA_SCALE_TABLE[8] = {1.0,
		J_scale, U_scale, F_scale, V_scale, M_scale, B_scale, C_scale};

	/* obtaining wireframe edges colors */
	vec4 r = EA_COLOR_TABLE[ea.r];
	vec4 g = EA_COLOR_TABLE[ea.g];
	vec4 b = EA_COLOR_TABLE[ea.b];

	/* obtaining wireframe vertices average colors and scales */
	mat3 irgb = get_V4EAC_colors_sum();
	vec3 irgbs = get_V4EAC_scales_sum();
	vec3 irgbc = get_V4EAC_components_sum();
	vec3 irgba = clamp(irgbc, vec3(0.0), vec3(1.0));

	vec4 ir = (irgbc.r < EPSILON) ? J_color : vec4((irgb[0] / irgbc.r), irgba.r);
	vec4 ig = (irgbc.g < EPSILON) ? J_color : vec4((irgb[1] / irgbc.g), irgba.g);
	vec4 ib = (irgbc.b < EPSILON) ? J_color : vec4((irgb[2] / irgbc.b), irgba.b);

	float irs = (irgbc.r < EPSILON) ? (J_scale) : (irgbs.r / irgbc.r);
	float igs = (irgbc.g < EPSILON) ? (J_scale) : (irgbs.g / irgbc.g);
	float ibs = (irgbc.b < EPSILON) ? (J_scale) : (irgbs.b / irgbc.b);

	/* coloring intersections with B or C edges without averaging */
	if (vBC.r > EPSILON) { ir = EA_COLOR_TABLE[6]; }
	else if (vBC.r < -EPSILON) { ir = EA_COLOR_TABLE[7]; }

	if (vBC.g > EPSILON) { ig = EA_COLOR_TABLE[6]; }
	else if (vBC.g < -EPSILON) { ig = EA_COLOR_TABLE[7]; }

	if (vBC.b > EPSILON) { ib = EA_COLOR_TABLE[6]; }
	else if (vBC.b < -EPSILON) { ib = EA_COLOR_TABLE[7]; }

	/* wireframe width based on edge assignment */
	vec3 width_min = vec3(wireframe_width_min);
	width_min.r *= EA_SCALE_TABLE[ea.r];
	width_min.g *= EA_SCALE_TABLE[ea.g];
	width_min.b *= EA_SCALE_TABLE[ea.b];

	vec3 width_max = vec3(wireframe_width_max);
	width_max.r *= EA_SCALE_TABLE[ea.r];
	width_max.g *= EA_SCALE_TABLE[ea.g];
	width_max.b *= EA_SCALE_TABLE[ea.b];

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
		b.rgb = mix(albedo, b.rgb, b.a); albedo = mix(b.rgb, albedo, mask.b);
		g.rgb = mix(albedo, g.rgb, g.a); albedo = mix(g.rgb, albedo, mask.g);
		r.rgb = mix(albedo, r.rgb, r.a); albedo = mix(r.rgb, albedo, mask.r);
	} else if (ea.r >= ea.b && ea.b >= ea.g) {
		g.rgb = mix(albedo, g.rgb, g.a); albedo = mix(g.rgb, albedo, mask.g);
		b.rgb = mix(albedo, b.rgb, b.a); albedo = mix(b.rgb, albedo, mask.b);
		r.rgb = mix(albedo, r.rgb, r.a); albedo = mix(r.rgb, albedo, mask.r);
	} else if (ea.b >= ea.r && ea.r >= ea.g) {
		g.rgb = mix(albedo, g.rgb, g.a); albedo = mix(g.rgb, albedo, mask.g);
		r.rgb = mix(albedo, r.rgb, r.a); albedo = mix(r.rgb, albedo, mask.r);
		b.rgb = mix(albedo, b.rgb, b.a); albedo = mix(b.rgb, albedo, mask.b);
	} else if (ea.b >= ea.g && ea.g >= ea.r) {
		r.rgb = mix(albedo, r.rgb, r.a); albedo = mix(r.rgb, albedo, mask.r);
		g.rgb = mix(albedo, g.rgb, g.a); albedo = mix(g.rgb, albedo, mask.g);
		b.rgb = mix(albedo, b.rgb, b.a); albedo = mix(b.rgb, albedo, mask.b);
	} else if (ea.g >= ea.r && ea.r >= ea.b) {
		b.rgb = mix(albedo, b.rgb, b.a); albedo = mix(b.rgb, albedo, mask.b);
		r.rgb = mix(albedo, r.rgb, r.a); albedo = mix(r.rgb, albedo, mask.r);
		g.rgb = mix(albedo, g.rgb, g.a); albedo = mix(g.rgb, albedo, mask.g);
	} else if (ea.g >= ea.b && ea.b >= ea.r) {
		r.rgb = mix(albedo, r.rgb, r.a); albedo = mix(r.rgb, albedo, mask.r);
		b.rgb = mix(albedo, b.rgb, b.a); albedo = mix(b.rgb, albedo, mask.b);
		g.rgb = mix(albedo, g.rgb, g.a); albedo = mix(g.rgb, albedo, mask.g);
	}

	/* drawing vertices on top of edges */
	vec3 ialbedo = vec3(albedo);
	ir.rgb = mix(albedo, ir.rgb, ir.a); ialbedo = mix(ir.rgb, ialbedo, imask.r);
	ig.rgb = mix(albedo, ig.rgb, ig.a); ialbedo = mix(ig.rgb, ialbedo, imask.g);
	ib.rgb = mix(albedo, ib.rgb, ib.a); ialbedo = mix(ib.rgb, ialbedo, imask.b);

	ALBEDO = ialbedo;
}