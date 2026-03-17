#[compute]
#version 450
#define EPS 0.0001

layout(set = 1, binding = 0, std140) buffer Parameters {
    float num_faces;
    highp float dt;
    highp vec4 center;
} p;

layout(set = 1, binding = 1) buffer FV { highp mat3x4 data[]; } fv;
layout(set = 1, binding = 7) buffer FVA { highp mat3x4 data[]; } fva;
layout(set = 1, binding = 8) buffer FVV { highp mat3x4 data[]; } fvv;

void main() {
    uint id = gl_GlobalInvocationID.x;
    if (id >= p.num_faces) { return; }

    fvv.data[id][0].xyz += fva.data[id][0].xyz * p.dt;
    fvv.data[id][1].xyz += fva.data[id][1].xyz * p.dt;
    fvv.data[id][2].xyz += fva.data[id][2].xyz * p.dt;

    fv.data[id][0].xyz += fvv.data[id][0].xyz * p.dt;
    fv.data[id][1].xyz += fvv.data[id][1].xyz * p.dt;
    fv.data[id][2].xyz += fvv.data[id][2].xyz * p.dt;
}
