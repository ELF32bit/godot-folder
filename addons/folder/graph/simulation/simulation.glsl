#[compute]
#version 450
#define EPS 0.0001
#define PI 3.141592653589793
#define PI2 6.283185307179586

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std140) buffer Parameters {
    float num_faces;
    highp float dt;
    highp vec4 center;
} p;

layout(set = 0, binding = 1) buffer FV { highp mat3x4 data[]; } fv;
layout(set = 0, binding = 2) restrict readonly buffer FP { highp mat3x4 data[]; } fp;
layout(set = 0, binding = 3) restrict readonly buffer K { highp mat3x4 data[]; } k;
layout(set = 0, binding = 4) buffer FVN { float data[]; } fvn;
layout(set = 0, binding = 5) readonly buffer FVNI { float data[]; } fvni;
layout(set = 0, binding = 6) readonly buffer FVNII { float data[]; } fvnii;
layout(set = 0, binding = 7) buffer FVA { highp mat3x4 data[]; } fva;
layout(set = 0, binding = 8) buffer FVV { highp mat3x4 data[]; } fvv;

vec3 normalize_s(vec3 v) {
    float vv = dot(v, v);
    return (vv > 0.0) ? v * inversesqrt(vv) : vec3(0.0);
}

float length_s(vec3 v) {
    return max(length(v), EPS);
}

float difference_s(float a, float b) {
    float d = a - b;
    float s = sign(d);
    return s * max(abs(d) - EPS, 0.0);
}

float angle_s(vec3 v1, vec3 v2) {
    return acos(clamp(dot(v1, v2), -1.0, 1.0));
}

float cot_s(float angle) {
    float a = clamp(angle, EPS, PI - EPS); 
    return cos(a) / sin(a);
}

float dihedral_s(vec3 n1, vec3 n2, vec3 axis) {
    float x = clamp(dot(n1, n2), -1.0, 1.0);
    float y = dot(cross(n1, axis), n2);
    return atan(y, x);
}

void main() {
    uint id = gl_GlobalInvocationID.x;
    if (id >= p.num_faces) { return; }

    /* reading faces vertices */
    vec3 a = fv.data[id][0].xyz;
    vec3 b = fv.data[id][1].xyz;
    vec3 c = fv.data[id][2].xyz;
    int ai = int(fv.data[id][0].w);
    int bi = int(fv.data[id][1].w);
    int ci = int(fv.data[id][2].w);

    /* reading face parameters */
    float ab_l0 = fp.data[id][0].x;
    float bc_l0 = fp.data[id][1].x;
    float ca_l0 = fp.data[id][2].x;
    float cab_a0 = fp.data[id][0].y;
    float abc_a0 = fp.data[id][1].y;
    float bca_a0 = fp.data[id][2].y;
    float ab_d0 = fp.data[id][0].z;
    float bc_d0 = fp.data[id][1].z;
    float ca_d0 = fp.data[id][2].z;

    /* reading outer faces vertices */
    int xi = int(fp.data[id][0].w);
    int yi = int(fp.data[id][1].w);
    int zi = int(fp.data[id][2].w);
    vec3 x = fv.data[xi / 3][xi % 3].xyz;
    vec3 y = fv.data[yi / 3][yi % 3].xyz;
    vec3 z = fv.data[zi / 3][zi % 3].xyz;
    float x_face = (xi < 0) ? 0.0 : 1.0;
    float y_face = (yi < 0) ? 0.0 : 1.0;
    float z_face = (zi < 0) ? 0.0 : 1.0;

    /* reading face coefficients */
    float ab_ka = k.data[id][0].x;
    float bc_ka = k.data[id][1].x;
    float ca_ka = k.data[id][2].x;
    float ab_kc = k.data[id][0].y;
    float bc_kc = k.data[id][1].y;
    float ca_kc = k.data[id][2].y;
    float a_kf = k.data[id][0].w;
    float b_kf = k.data[id][1].w;
    float c_kf = k.data[id][2].w;

    /* reading last dihedral angles */
    float abx_d1 = fva.data[id][0].w;
    float bcy_d1 = fva.data[id][1].w;
    float caz_d1 = fva.data[id][2].w;

    /* reading vertices velocities */
    vec3 a_v = fvv.data[id][0].xyz;
    vec3 b_v = fvv.data[id][1].xyz;
    vec3 c_v = fvv.data[id][2].xyz;

    /* reading vertices masses */
    float a_m = fvv.data[id][0].w;
    float b_m = fvv.data[id][1].w;
    float c_m = fvv.data[id][2].w;

    /* preparing triangle */
    mat3x4 _f = mat3x4(0.0);
    vec3 ab = b - a;
    vec3 bc = c - b;
    vec3 ca = a - c;
    vec3 ab_n = normalize_s(ab);
    vec3 bc_n = normalize_s(bc);
    vec3 ca_n = normalize_s(ca);
    float ab_l = length_s(ab);
    float bc_l = length_s(bc);
    float ca_l = length_s(ca);

    /* calculating axial forces */
    vec3 ab_fa = -ab_ka * difference_s(ab_l, ab_l0) * ab_n;
    vec3 bc_fa = -bc_ka * difference_s(bc_l, bc_l0) * bc_n;
    vec3 ca_fa = -ca_ka * difference_s(ca_l, ca_l0) * ca_n;

    /* applying axial forces */
    _f[2].xyz += (c - (a + b) * 0.5) * 0.1;
    
    _f[0].xyz -= ab_fa;
    _f[0].xyz += ca_fa;
    _f[1].xyz += ab_fa;
    _f[1].xyz -= bc_fa;
    _f[2].xyz += bc_fa;
    _f[2].xyz -= ca_fa;

    /* preparing outer triangles */
    vec3 ax = x - a;
    vec3 by = y - b;
    vec3 cz = z - c;
    vec3 ax_n = normalize_s(ax);
    vec3 by_n = normalize_s(by);
    vec3 cz_n = normalize_s(cz);
    vec3 bx_n = normalize_s(x - b);
    vec3 cy_n = normalize_s(y - c);
    vec3 az_n = normalize_s(z - a);

    /* calculating triangles normals */
    vec3 abc_cross = -cross(ab, bc);
    vec3 bax_cross = -cross(-ab, ax);
    vec3 cby_cross = -cross(-bc, by);
    vec3 acz_cross = -cross(-ca, cz);

    vec3 abc_n = normalize_s(abc_cross);
    vec3 abx_n = normalize_s(bax_cross);
    vec3 bcy_n = normalize_s(cby_cross);
    vec3 caz_n = normalize_s(acz_cross);

    /* calculating triangles areas */
    float abc_area = length_s(abc_cross) * 0.5;
    float abx_area = length_s(bax_cross) * 0.5;
    float bcy_area = length_s(cby_cross) * 0.5;
    float caz_area = length_s(acz_cross) * 0.5;

    /* calculating triangles angles from [0, PI] */
    float abc_a = angle_s(-ab_n, bc_n);
    float bca_a = angle_s(-bc_n, ca_n);
    float cab_a = angle_s(-ca_n, ab_n);
    float bax_a = angle_s(ab_n, ax_n);
    float cby_a = angle_s(bc_n, by_n);
    float acz_a = angle_s(ca_n, cz_n);
    float xba_a = angle_s(-ab_n, bx_n);
    float ycb_a = angle_s(-bc_n, cy_n);
    float zac_a = angle_s(-ca_n, az_n);

    float abc_cota = cot_s(abc_a);
    float bca_cota = cot_s(bca_a);
    float cab_cota = cot_s(cab_a);
    float bax_cota = cot_s(bax_a);
    float cby_cota = cot_s(cby_a);
    float acz_cota = cot_s(acz_a);
    float xba_cota = cot_s(xba_a);
    float ycb_cota = cot_s(ycb_a);
    float zac_cota = cot_s(zac_a);

    /* calculating triangles heights */
    float abx_h = 2.0 * abx_area / ab_l;
    float abc_h = 2.0 * abc_area / ab_l;
    float bcy_h = 2.0 * bcy_area / bc_l;
    float bca_h = 2.0 * abc_area / bc_l;
    float caz_h = 2.0 * caz_area / ca_l;
    float cab_h = 2.0 * abc_area / ca_l;

    vec3 abx_nh = abx_n / abx_h;
    vec3 abc_nh = abc_n / abc_h;
    vec3 bcy_nh = bcy_n / bcy_h;
    vec3 bca_nh = abc_n / bca_h;
    vec3 caz_nh = caz_n / caz_h;
    vec3 cab_nh = abc_n / cab_h;

    /* calculating dihedral angles with outer triangles */
    float abx_d = dihedral_s(abc_n, abx_n, -ab_n);
    float bcy_d = dihedral_s(abc_n, bcy_n, -bc_n);
    float caz_d = dihedral_s(abc_n, caz_n, -ca_n);

    float abx_diff = abx_d - abx_d1;
    float bcy_diff = bcy_d - bcy_d1;
    float caz_diff = caz_d - caz_d1;
    if (abx_diff < -5.0) { abx_d += PI2; }
    else if (abx_diff > 5.0) { abx_d -= PI2; }
    if (bcy_diff < -5.0) { bcy_d += PI2; }
    else if (bcy_diff > 5.0) { bcy_d -= PI2; }
    if (caz_diff < -5.0) { caz_d += PI2; }
    else if (caz_diff > 5.0) { caz_d -= PI2; }
    fva.data[id][0].w = abx_d * x_face;
    fva.data[id][1].w = bcy_d * y_face;
    fva.data[id][2].w = caz_d * z_face;

    /* calculating crease constraints */
    float ab_k1 = max(cab_cota + abc_cota, EPS);
    float ab_k2 = max(bax_cota + xba_cota, EPS);
    float bc_k1 = max(abc_cota + bca_cota, EPS);
    float bc_k2 = max(cby_cota + ycb_cota, EPS);
    float ca_k1 = max(bca_cota + cab_cota, EPS);
    float ca_k2 = max(acz_cota + zac_cota, EPS);

    float ab_fc = -ab_kc * difference_s(abx_d, ab_d0);
    float bc_fc = -bc_kc * difference_s(bcy_d, bc_d0);
    float ca_fc = -ca_kc * difference_s(caz_d, ca_d0);

    /* applying crease constraints */
    _f[0].xyz += bc_fc * bca_nh * y_face;
    _f[1].xyz += ca_fc * cab_nh * z_face;
    _f[2].xyz += ab_fc * abc_nh * x_face;
    _f[0].xyz += ab_fc * (-bca_nh * (abc_cota / ab_k1) - abx_nh * (xba_cota / ab_k2)) * x_face;
    _f[1].xyz += ab_fc * (-cab_nh * (cab_cota / ab_k1) - abx_nh * (bax_cota / ab_k2)) * x_face;
    _f[1].xyz += bc_fc * (-cab_nh * (abc_cota / bc_k1) - bcy_nh * (ycb_cota / bc_k2)) * y_face;
    _f[2].xyz += bc_fc * (-abc_nh * (abc_cota / bc_k1) - bcy_nh * (cby_cota / bc_k2)) * y_face;
    _f[2].xyz += ca_fc * (-abc_nh * (cab_cota / ca_k1) - caz_nh * (zac_cota / ca_k2)) * z_face;
    _f[0].xyz += ca_fc * (-bca_nh * (bca_cota / ca_k1) - caz_nh * (acz_cota / ca_k2)) * z_face;

    /* calculating face constraints */
    vec3 ab_ff = abc_n * ab / (ab_l * ab_l);
    vec3 bc_ff = abc_n * bc / (bc_l * bc_l);
    vec3 ca_ff = abc_n * ca / (ca_l * ca_l);

    float abc_kf = -b_kf * difference_s(abc_a, abc_a0);
    float bca_kf = -c_kf * difference_s(bca_a, bca_a0);
    float cab_kf = -a_kf * difference_s(cab_a, cab_a0);

     /* applying face constraints */
    _f[0].xyz += cab_kf * (ca_ff + ab_ff);
    _f[1].xyz += cab_kf * (-ab_ff);
    _f[2].xyz += cab_kf * (-ca_ff);
    _f[0].xyz += abc_kf * (-ab_ff);
    _f[1].xyz += abc_kf * (ab_ff + bc_ff);
    _f[2].xyz += abc_kf * (-bc_ff);
    _f[0].xyz += bca_kf * (-ca_ff);
    _f[1].xyz += bca_kf * (-bc_ff);
    _f[2].xyz += bca_kf * (bc_ff + ca_ff);

    /* calculating vertices damping forces */
    vec3 a_fd = vec3(0.0);
    int a_n1 = int(fvn.data[ai * 2]);
    int a_n2 = int(fvn.data[ai * 2 + 1]);
    for (int index = a_n1; index < a_n2; index++) {
    	int i = int(fvni.data[index]);
    	int ii = int(fvnii.data[index]);
    	float a_kd = fp.data[ii / 3][ii % 3].z;
    	vec3 a_vn = fvv.data[i / 3][i % 3].xyz;
    	a_fd.x += a_kd * difference_s(a_vn.x, a_v.x);
    	a_fd.y += a_kd * difference_s(a_vn.y, a_v.y);
    	a_fd.z += a_kd * difference_s(a_vn.z, a_v.z);
    }

    vec3 b_fd = vec3(0.0);
    int b_n1 = int(fvn.data[bi * 2]);
    int b_n2 = int(fvn.data[bi * 2 + 1]);
    for (int index = b_n1; index < b_n2; index++) {
    	int i = int(fvni.data[index]);
    	int ii = int(fvnii.data[index]);
    	float b_kd = fp.data[ii / 3][ii % 3].z;
    	vec3 b_vn = fvv.data[i / 3][i % 3].xyz;
    	b_fd.x += b_kd * difference_s(b_vn.x, b_v.x);
    	b_fd.y += b_kd * difference_s(b_vn.y, b_v.y);
    	b_fd.z += b_kd * difference_s(b_vn.z, b_v.z);
    }

    vec3 c_fd = vec3(0.0);
    int c_n1 = int(fvn.data[ci * 2]);
    int c_n2 = int(fvn.data[ci * 2 + 1]);
    for (int index = c_n1; index < c_n2; index++) {
    	int i = int(fvni.data[index]);
    	int ii = int(fvnii.data[index]);
    	float c_kd = fp.data[ii / 3][ii % 3].z;
    	vec3 c_vn = fvv.data[i / 3][i % 3].xyz;
    	c_fd.x += c_kd * difference_s(c_vn.x, c_v.x);
    	c_fd.y += c_kd * difference_s(c_vn.y, c_v.y);
    	c_fd.z += c_kd * difference_s(c_vn.z, c_v.z);
    }

    /* applying vertices damping forces */
    _f[0].xyz += a_fd;
    _f[1].xyz += b_fd;
    _f[2].xyz += c_fd;

    /* applying vertices acceleration */
    fva.data[id][0].xyz = _f[0].xyz / a_m;
    fva.data[id][1].xyz = _f[1].xyz / b_m;
    fva.data[id][2].xyz = _f[2].xyz / c_m;
}
