#ifdef GL_ES
#define PRECISION mediump
precision  PRECISION float;
precision  PRECISION int;
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

varying vec2 v_texCoords;

//const float u_split_start = 0.35;
//const float u_split_end = 0.65;
//const float u_heightOfTile = 0.3;

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

// solve a cubic equation
// Reference: https://www.shadertoy.com/view/3d23Dc
float solveCubicAndGetReducedSolution(float a, float b, float c, float d) {
    float Q, A, D, v, l, k = -1.0;

    if (abs(a) < 0.001) {
        // degenerated P3
        k = -2.0;
        v = c * c - 4.0 * b * d;
        l = (-c - sign(b) * sqrt(v)) / (2.0 * b);
    } else {
        // true P3
        b /= a;
        c /= a;
        d /= a;
        float p = (3.0 * c - b * b) / 3.0,
        q = (9.0 * b * c - 27.0 * d - 2.0 * b * b * b) / 27.0, // -
        r = q / 2.0;
        Q = p / 3.0;
        D = Q * Q * Q + r * r;

        if (D < 0.0) {
            // --- if 3 sol
            A = acos(r / sqrt(-Q * Q * Q));
            k = round(1.5 - A / 6.283); // k = 0,1,2 ; we want min l
            #define sol(k)(2.0 * sqrt(-Q) * cos((A + (k) * 6.283) / 3.0) - b / 3.0)
            l = sol(k);
        } else if (p > 0.0) {
            // --- if 1 sol
            v = -2.0 * sqrt(p / 3.0);
            #define asinh(z)(sign(z) * asinh(abs(z))) // fix asinh() symetry error
            l = -v * sinh(asinh(3.0 * -q / p / v) / 3.0) - b / 3.0;
        } else {
            v = -2.0 * sqrt(-p / 3.0);
            l = sign(-q) * v * cosh(acosh(3.0 * abs(q) / p / v) / 3.0) - b / 3.0;
        }
    }

    // TODO: Decide when to return which value...
    if (k >= 0.0 && sol(k + 2.0) < 1.0)
    return sol(k + 2.0);
    //    return sol(k+1.);
    return l;
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

    return solveCubicAndGetReducedSolution(
    2.0 * C.x * C.x + 2.0 * C.y * C.y,
    3.0 * B.x * C.x + 3.0 * B.y * C.y,
    2.0 * A.x * C.x + B.x * B.x - 2.0 * C.x * x.x + 2.0 * A.y * C.y + B.y * B.y - 2.0 * C.y * x.y,
    A.x * B.x - B.x * x.x + A.y * B.y - B.y * x.y
    );
}

void main() {
    //vec2 p = vec2(v_texCoords.x, 1.0-v_texCoords.y);
    vec2 p = gl_FragCoord / 480;
    //p.y = 1.0-p.y;

    vec2 a = vec2(u_guidePointX[0], u_guidePointY[0]), b = vec2(u_guidePointX[1], u_guidePointY[1]), c = vec2(u_guidePointX[2], u_guidePointY[2]);
//        vec2 a = vec2(0.1, 0.1), b = vec2(0.5, 0.2), c = vec2(0.9, 0.9);
//    vec2 a = vec2(0.1, 0.1), b = vec2(0.5, 0.2), c = vec2(0.9, 0.7);
//    vec2 a = vec2(0.1, 0.1), b = vec2(0.5, 0.5), c = vec2(0.9, 0.9);

    // Get the suitable value of f
    float f = unbezier(a, b, c, p);
    // Get the distance bw x and bexzier at f
    float d = length(p - bezier(a, b, c, f));

    // Convert the point p in space P to space E
    vec2 e = vec2(f, d * 6.0);
    // Convert the point e in space E to space T
    vec2 t = warpESpaceToTSpace(e, u_splitStart, u_splitEnd, u_repeats);

    t.y = 1.0 - t.y;
    gl_FragColor = texture2D(u_texture, t);

//    if (pointLineDistance(p, a, b) < 0.1)gl_FragColor *= vec4(0.0, 1.0, 1.0, 1.0);
//        if (p.x < 0.9999)gl_FragColor = vec4(f*0.01, 1.0, 1.0, 1.0);
//        if(length(p-a)<0.02)gl_FragColor*=0.0;
//        if(length(p-b)<0.02)gl_FragColor*=0.0;
//        if(length(p-c)<0.02)gl_FragColor*=0.0;
//        if(pointLineDistance(p,a,b)<0.005)gl_FragColor*=0.0;
//        if(pointLineDistance(p,b,c)<0.005)gl_FragColor*=0.0;
//        if(length(p-bezier(a,b,c,p.x))<0.1)gl_FragColor*=0.0;

    //    if (p.y < 0.5) gl_FragColor=vec4(1.0);

    //vec2 vs = p - bezier(a, b, c, f);
    // Uncomment the commentlet below to strictly clamp the image
    //if (vs.y < 0.0 /* || d/heightOfTile > 1.0 || f>1.0 || f < 0.0 */)
    //gl_FragColor *= vec4(0.0);
}
