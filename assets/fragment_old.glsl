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
uniform float u_bezier_x[MAX_SIZE];
uniform float u_bezier_y[MAX_SIZE];
uniform int u_bezier_length;

varying vec2 v_texCoords;

vec2 getAdjustedCoordinates() {
    float repeats = 6.0;

    float start_width = u_split_start;
    float end_width = 1.0 - u_split_end;
    float mid_width = u_split_end - u_split_start;
    float tlength = u_split_start + repeats * mid_width + end_width;

    if (v_texCoords.x < u_split_start / tlength)
    return vec2(v_texCoords.x * tlength, v_texCoords.y);

    else if (v_texCoords.x > 1.0 - (1.0 - u_split_end) / tlength)
    return vec2(u_split_end + (v_texCoords.x - (1.0 - (1.0 - u_split_end) / tlength)) * tlength, v_texCoords.y);

    else {
        float x = v_texCoords.x - u_split_start / tlength;
        x = x / (1.0 - (1.0 - u_split_end) / tlength - u_split_start / tlength);
        x = mod(x, 1.0 / repeats);
        x = x * repeats;
        x = x * (u_split_end - u_split_start);
        x = x + u_split_start;
        return vec2(x, v_texCoords.y);
    }
}

vec2 lerp(vec2 a, vec2 b, float f) {
    return a + (b - a) * f;
}

vec2 bezier(vec2 a, vec2 b, vec2 c, float f) {
    return lerp(lerp(a, b, f), lerp(b, c, f), f);
}

void main() {
    vec2 coords = getAdjustedCoordinates();

    int bezier_length = min(u_bezier_length, MAX_SIZE);
    float bezier_y[MAX_SIZE];
    for (int i = 0; i < bezier_length; ++i)
    bezier_y[i] = 1.0 - u_bezier_y[i];

    float distx = length(v_texCoords - bezier(vec2(u_bezier_x[0], bezier_y[0]), vec2(u_bezier_x[1], bezier_y[1]), vec2(u_bezier_x[2], bezier_y[2]), v_texCoords.x));

    

    float f = u_split_start + u_split_end + u_repeats;
//    if (distx > 0.3)
    gl_FragColor = texture2D(u_texture, coords) * f / f * distx;
//    else
//    gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
}
