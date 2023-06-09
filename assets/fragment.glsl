#version 130
#extension GL_EXT_gpu_shader4 : enable

#ifdef GL_ES
#define PRECISION mediump
precision mediump float;
precision mediump int;
#else
#define PRECISION
#endif

#define MAX_SIZE 32

uniform sampler2D u_texture;
uniform float u_splitStart;
uniform float u_splitEnd;
uniform float u_repeats;
uniform float u_heightOfTile;
uniform float u_guidePointX[MAX_SIZE];
uniform float u_guidePointY[MAX_SIZE];
uniform int u_numberOfGuidePoints;
uniform vec2 u_resolution;
uniform float u_screenToWorld;
uniform vec2 u_camera;

//uniform sampler2D iChannel0;

varying vec2 v_texCoords;

// Let's say that there are coordinate spaces.
// First one is of cource the coordinate over the texture. Let that be called T.
// Second is the coordinate over the extended tile. Let that be called E.
// The third one is the coordinate the shader actually receives. Let that be called P.

// Converts the given coordinate in E to a coordinate in T
vec2 warpESpaceToTSpace(vec2 e, float splitStart, float splitEnd, float repeats) {
    // Given that the bottom left point on the texture is 0,0 and the top right is 1.0
    // the area between x=0 to x=splitStart is preserved as the starting part
    // and the area between x=splitEnd to x=1 is preserved as the ending part.
    // The middle part is repeated 'repeats' times and stretch to fill up the middle part.

    // TODO: if repeats==-1, calculate an appropriate number of repeats.

    // Length of the extended tile in T's scale.
    // Note, that height remains 1 as we didn't repeat along that.
    // As the starting and ending part remain the same,
    //      the e tile starts with 0,splitStart of t tile.
    //          width = splitStart
    //      the e tile ends with splitEnd,1 of t tile.
    //          width = 1 - splitEnd
    // Meanwhile, the moddle part repeats,
    //      width = repeats * thickness
    //            = repeats * (splitEnd - splitStart)
    float startWidth = splitStart;
    float midWidth = repeats * (splitEnd - splitStart);
    float endWidth = (1.0 - splitEnd);
    float totalLength = startWidth + midWidth + endWidth;

    // Further, it will help us by converting the scale of e from E to T
    e.x *= totalLength;

    if (e.x < 0.0) {
        return vec2(0.0, e.y);
    }

    if (e.x <= startWidth) {
        return e;
    }
    e.x -= startWidth;

    if (e.x <= midWidth) {
        // Convert the scale from [0,midWidth] to [0,repeats] and apply modulo
        e.x = e.x / midWidth * repeats;
        e.x = mod(e.x, 1.0);
        // Convert the scale from [0,1] to [splitStart,splitEnd]
        e.x = splitStart + e.x * (splitEnd - splitStart);
        return e;
    }
    e.x -= midWidth;

    if (e.x <= endWidth) {
        // TODO: Add a comment
        e.x += splitEnd;
        return e;
    }
    return vec2(0.0, e.y);
}

float sigmoid(float f) {
    return 1 / (1 + exp(-10.0 * f));
}

vec2 lerp(vec2 a, vec2 b, float f) {
    return a + (b - a) * f;
}

float lerp(float a, float b, float f) {
    return a + (b - a) * f;
}

vec2 bezier(vec2 a, vec2 b, vec2 c, float f) {
    //    return lerp(lerp(a, b, f), lerp(b, c, f), f);
    return a + 2.0 * (b - a) * f + (c - 2.0 * b + a) * f * f;
}

// distance between a point 'p' and a line through 'a' and 'b'
float pointLineDistance(vec2 p, vec2 a, vec2 b) {
    float m = (a.y - b.y) / (a.x - b.x);
    return abs((m * p.x - p.y - m * a.x + a.y) / sqrt(m * m + 1.0));
}

// Reference: https://www.shadertoy.com/view/wdXXW7
float sgn(float x) {
    return x < 0.0 ? -1.0 : 1.0; // Return 1 for x == 0
}

// Reference: https://www.shadertoy.com/view/wdXXW7
int quadratic(float A, float B, float C, out vec2 res) {
    float x1, x2;
    float b = -0.5 * B;
    float q = b * b - A * C;
    if (q < 0.0) return 0;
    float r = b + sgn(b) * sqrt(q);
    if (r == 0.0) {
        x1 = C / A; x2 = -x1;
    } else {
        x1 = C / r; x2 = r / A;
    }
    res = vec2(x1, x2);
    return 2;
}

// Reference: https://www.shadertoy.com/view/wdXXW7
// Evaluate cubic and derivative.
void eval(float X, float A, float B, float C, float D,
out float Q, out float Q1, out float B1, out float C2) {
    float q0 = A * X;
    B1 = q0 + B;
    C2 = B1 * X + C;
    Q1 = (q0 + B1) * X + C2;
    Q = C2 * X + D;
}

// Reference: https://www.shadertoy.com/view/wdXXW7
// Solve: Ax^3 + Bx^2 + Cx + D == 0
// Find one real root, then reduce to quadratic.
int cubic(float A, float B, float C, float D, out vec3 res) {
    float X, b1, c2;
    if (A == 0.0) {
        X = 1e8; A = B; b1 = C; c2 = D;
    } else if (D == 0.0) {
        X = 0.0; b1 = B; c2 = C;
    } else {
        X = -(B / A) / 3.0;
        float t, r, s, q, dq, x0;
        eval(X, A, B, C, D, q, dq, b1, c2);
        t = q / A; r = pow(abs(t), 1.0 / 3.0); s = sgn(t);
        t = -dq / A; if (t > 0.0) r = 1.324718 * max(r, sqrt(t));
        x0 = X - s * r;
        if (x0 != X) {
            X = x0;
            for (int i = 0; i < 4; i++) {
                eval(X, A, B, C, D, q, dq, b1, c2);
                if (dq == 0.0) break;
                X -= (q / dq);
            }
            if (abs(A) * X * X > abs(D / X)) {
                c2 = -D / X; b1 = (c2 - C) / X;
            }
        }
    }
    res.x = X;
    return 1 + quadratic(A, b1, c2, res.yz);
}

// Unbezierize, ie, get a value of 'f' which represents the nearest point to x
float unbezier(vec2 a, vec2 b, vec2 c, vec2 x) {
    vec2 A = a, B = 2.0 * (b - a), C = c - 2.0 * b + a;

    // (2fc+b)(f2c+fb+a-x)
    // 2fc(f2c+fb+a-x) + b(f2c+fb+a-x)
    // 2f3c2+2f2bc+2fac-2fcx  +  f2bc+fb2+ab-bx
    // 2f3c2+3f2bc+f(2ac+b2-2cx)+ab-bx
    // 2f3C2+3f2BC+f(2AC+B2-2Cx)+AB-Bx
    // 2CC  3BC  2AC+BB-2Cx  AB-Bx
    // 2.0*C*C  3.0*B*C  2.0*A*C+B*B-2.0*C*x  A*B-B*x

    vec3 roots;
    int nroots = cubic(
    2.0 * C.x * C.x + 2.0 * C.y * C.y,
    3.0 * B.x * C.x + 3.0 * B.y * C.y,
    2.0 * A.x * C.x + B.x * B.x - 2.0 * C.x * x.x + 2.0 * A.y * C.y + B.y * B.y - 2.0 * C.y * x.y,
    A.x * B.x - B.x * x.x + A.y * B.y - B.y * x.y,
    roots
    );
    if (nroots > 1 && (roots.x < 0.0 || roots.x > 1.0)) {
        if (roots.y < 0.0 || roots.y > 1.0) return roots.z;
        return roots.y;
    }
    return roots.x;
}

void main()
{
    float scale = min(u_resolution.x, u_resolution.y);

    vec2 p = gl_FragCoord.xy * u_screenToWorld + u_camera - u_resolution / 2.0;
    p /= scale;

    vec2
    a = vec2(u_guidePointX[0], u_guidePointY[0]) / scale,
    b = vec2(u_guidePointX[1], u_guidePointY[1]) / scale,
    c = vec2(u_guidePointX[2], u_guidePointY[2]) / scale;

    // Get the suitable value of f
    float f = unbezier(a, b, c, p);
    vec2 z = bezier(a, b, c, f);
    // Get the distance bw x and bezier at f
    float d = length(p - z);

    // Convert the point p in space P to space E
    vec2 e = vec2(f, d / u_heightOfTile * scale);
    // Convert the point e in space E to space T
    //        vec2 t = warpESpaceToTSpace(e, u_splitStart, u_splitEnd, u_repeats);
    vec2 t = warpESpaceToTSpace(e, u_splitStart, u_splitEnd, ceil((length(a - b) + length(b - c)) / (u_heightOfTile / scale)));

    t.y = 1.0 - t.y;
    gl_FragColor = texture2D(u_texture, t);
    //    gl_FragColor = warpESpaceToTSpace2(e, u_splitStart, u_splitEnd, ceil((length(a - b) + length(b - c)) / (u_heightOfTile / scale)));
    if (f < 0.0 || f > 1.0 || d < 0.0 || d > u_heightOfTile / scale || p.y < z.y) gl_FragColor = vec4(0.0);

    //    if (length(p - vec2(0.0, 0.0)) < 0.1) gl_FragColor = vec4(1.0);
    //    if (length(p - vec2(1.0, 1.0)) < 0.1) gl_FragColor = vec4(1.0);

    //    if (
    //    length(p - a) < 0.1
    //    || length(p - b) < 0.1
    //    || length(p - c) < 0.1
    //    ) gl_FragColor = vec4(1.0);
}
