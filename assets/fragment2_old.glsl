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

varying vec2 v_texCoords;

// Let's say that there are three coordinate spaces.
// First one is of course the coordinate over the texture. Let that be called T.
// Second is the coordinate over the extended tile. Let that be called E.
// The third one is the coordinate the shader actually receives. Let that be called P.

// Converts the given coordinate in E to a coordinate in T
vec2 warpESpaceToTSpace(vec2 e, float splitStart, float splitEnd, float repeats) {
    // Given that the bottom left point on the texture is 0,0 and the top right is 1.0
    // the area between x=0 to x=splitStart is preserved as the starting part
    // and the area between x=splitEnd to x=1 is preserved as the ending part.
    // The middle part is repeated 'repeats' times and tiled to fill up the middle part.

    // TODO: if repeats==-1, calculate an appropriate number of repeats.

    // Length of the extended tile in T's scale.
    // Note, that height remains 1 as we didn't repeat along that in this implementation.
    // As the starting and ending part remain the same,
    //      the e tile starts with 0,splitStart of t tile.
    //          width = splitStart
    //      the e tile ends with splitEnd,1 of t tile.
    //          width = 1 - splitEnd
    // Meanwhile, the middle part repeats,
    //      width = repeats * thickness
    //            = repeats * (splitEnd - splitStart)
    float startWidth = splitStart;
    float midWidth = repeats * (splitEnd - splitStart);
    float endWidth = (1.0 - splitEnd);
    float totalLength = startWidth + midWidth + endWidth;

    // Further, it will help us by converting the scale of e from E to T
    e.x *= totalLength;
    e.y = 1.0 - e.y;

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

// distance between a point 'p' and a line through 'a' and 'b'
float pointLineDistance(vec2 p, vec2 a, vec2 b) {
    float m = (a.y - b.y) / (a.x - b.x);
    return abs((m * p.x - p.y - m * a.x + a.y) / sqrt(m * m + 1.0));
}

// Find's the (f x 100)th percentile on the bezier formed by a, b, c and d.
vec2 bezier(vec2 a, vec2 b, vec2 c, vec2 d, float f) {
    return f * f * f * (-1.0 * a + 3.0 * b - 3.0 * c + 1.0 * d) + 1.0 * a
    + f * f * (+ 3.0 * a - 6.0 * b + 3.0 * c) + f * (-3.0 * a + 3.0 * b);
}

// Distance between x and the bezier point
float bezier_distance(vec2 a, vec2 b, vec2 c, vec2 d, vec2 x, float f) {
    return length(x - bezier(a, b, c, d, f));
}

// Perform a... binary search... to get the f of the bezier point nearest to x.
// TODO: Find if the search is actually spread among the branches and not
//  just dragging itself to the lowest/highest branch.
float debezierize_search(vec2 a, vec2 b, vec2 c, vec2 d, vec2 x, float lf, float hf) {
    do {
        float f50 = (hf + lf) * 0.5;
        if (hf - lf < 0.001) return f50;

        float f25 = (3.0 * lf + hf) * 0.25;
        float h25 = bezier_distance(a, b, c, d, x, f25);

        float f75 = (lf + 3.0 * hf) * 0.25;
        float h75 = bezier_distance(a, b, c, d, x, f75);

        if (h25 < h75) hf = f50;
        else lf = f50;
    } while (true);
}

// Converts the given coordinate in P to a coordinate in E
vec2 warpPSpaceToESpace(vec2 a, vec2 b, vec2 c, vec2 d, vec2 x, float h) {
    float lf = debezierize_search(a, b, c, d, x, 0.0, 0.5);
    float lh = bezier_distance(a, b, c, d, x, lf);
    float hf = debezierize_search(a, b, c, d, x, 0.5, 1.0);
    float hh = bezier_distance(a, b, c, d, x, hf);
    if (lh < hh) return vec2(lf, lh * h);
    return vec2(hf, hh * h);
}

void main()
{
    int numberOfGuidePoints = min(u_numberOfGuidePoints, MAX_SIZE);
    int beziersInSpline = (numberOfGuidePoints - 1) / 3;
    numberOfGuidePoints = beziersInSpline * 3 + 1;

    float scale = min(u_resolution.x, u_resolution.y);

    vec2 p = gl_FragCoord.xy * u_screenToWorld + u_camera - u_resolution / 2.0;
    p /= scale;

    vec2 splinePoints[MAX_SIZE];
    for(int i = 0; i < numberOfGuidePoints; ++i)
            splinePoints[i] = vec2(u_guidePointX[i], u_guidePointY[i]) / scale;

    vec2
    a = vec2(u_guidePointX[0], u_guidePointY[0]) / scale,
    b = vec2(u_guidePointX[1], u_guidePointY[1]) / scale,
    c = vec2(u_guidePointX[2], u_guidePointY[2]) / scale,
    d = vec2(u_guidePointX[3], u_guidePointY[3]) / scale;

    float repeats = u_repeats >= 0.0 ? u_repeats : ceil((length(a - b) + length(b - c) + length(c - d)) / (u_heightOfTile / scale));

    vec2 e = warpPSpaceToESpace(a, b, c, d, p, scale / u_heightOfTile);
    vec2 t = warpESpaceToTSpace(e, u_splitStart, u_splitEnd, repeats);

    if (bezier(a, b, c, d, e.x).y < p.y)
    gl_FragColor = texture2D(u_texture, t);

    if (e.x <= 0.001 || e.x > 0.999 || e.y < 0.0 || e.y > 1.0) gl_FragColor = vec4(0.0);
    //    if (f < 0.0 || f > 1.0 || d < 0.0 || d > u_heightOfTile / scale || p.y < z.y) gl_FragColor = vec4(0.0);

    //    if (
    //    length(p - a) < 0.1
    //    || length(p - b) < 0.1
    //    || length(p - c) < 0.1
    //    ) gl_FragColor = vec4(1.0);
}
