#ifdef GL_ES
precision highp float;
#endif

#define PI 3.141592654
#define PI2 6.283185308

const int MAX_SIZE = 32;

uniform sampler2D u_texture;
uniform float u_split_start;
uniform float u_split_end;
uniform float u_repeats;

varying vec2 v_texCoords;

vec2 warp(vec2 e, float splitStart, float splitEnd, float repeats) {
    // TODO: if repeats==-1, calculate an appropriate number of repeats.

    float startWidth = splitStart;
    float midWidth = repeats * (splitEnd - splitStart);
    float endWidth = (1.0 - splitEnd);
    float totalLength = startWidth + midWidth + endWidth;

    // Further, it will help us by converting the scale of e from E to T
    e.x *= totalLength;

    if (e.x < 0.0) {
        return vec2(0.0);
    }

    if (e.x < startWidth) {
        return vec2(e.x, e.y);
    }
    e.x -= startWidth;

    if (e.x < midWidth) {
        // Convert the scale from [0,midWidth] to [0,repeats] and apply modulo
        e.x = e.x / midWidth * repeats;
        e.x = mod(e.x, 1.0);
        // Convert the scale from [0,1] to [splitStart,splitEnd] and apply modulo
        e.x = splitStart + e.x * (splitEnd - splitStart);
        return vec2(e.x, e.y);
    }
    e.x -= midWidth;

    if (e.x < endWidth) {
        // TODO: Add a comment
        e.x += splitEnd;
        return vec2(e.x, e.y);
    }
    return vec2(0.0);
}

void main() {
    vec2 coords = warp(v_texCoords, u_split_start, u_split_end, u_repeats);
    gl_FragColor = texture2D(u_texture, coords);
}
