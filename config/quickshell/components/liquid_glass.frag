#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 uBounds;       // (x / screenW, y / screenH, w / screenW, h / screenH)
    vec4 uTint;         // glass tint color (rgb) + blend alpha (a)
    vec4 uRimColor;     // specular rim color (rgb) + intensity (a)
    vec2 uBoxSize;      // capsule width, height in px
    vec2 uTexSize;      // texture width, height in px
    float uRadius;      // corner radius in px
    float uRefraction;  // base bevel refraction strength
    float uBevelDepth;  // curved edge depth multiplier
    float uBevelWidth;  // fraction of min dimension
    float uAberration;  // chromatic dispersion strength
    float uFrost;       // Vogel-disk frost blur radius
};

layout(binding = 1) uniform sampler2D uSource;

float udRoundBox(vec2 p, vec2 b, float r) {
    return length(max(abs(p) - b + r, 0.0)) - r;
}

vec2 cornerNormal(vec2 p, vec2 b, float r, vec2 fallback) {
    vec2 q = abs(p) - b + r;
    vec2 m = max(q, 0.0);
    float l = length(m);
    if (l <= 0.0) return fallback;
    float w = smoothstep(0.0, max(r * 0.5, 1.0), min(m.x, m.y));
    if (w <= 0.0) return fallback;
    vec2 s = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
    return normalize(mix(fallback, s * (m / l), w));
}

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float edgeFactor(vec2 p_px, vec2 b_px, float radius_px) {
    float d = -udRoundBox(p_px, b_px, radius_px);
    // Slightly thicker optical bevel (5.5px on bar pills/buttons, up to 12.5px on full panels)
    float bevel_px = clamp(uBevelWidth * min(uBoxSize.x, uBoxSize.y), 5.5, 12.5);
    return 1.0 - smoothstep(0.0, bevel_px, d);
}

void main() {
    vec2 lensUV = qt_TexCoord0;
    vec2 p_px = (lensUV - 0.5) * uBoxSize;
    vec2 b_px = 0.5 * uBoxSize;
    float r = clamp(uRadius, 2.0, min(b_px.x, b_px.y));

    float dmask = udRoundBox(p_px, b_px, r);
    float inShape = 1.0 - smoothstep(-1.0, 0.4, dmask);
    if (inShape <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float edge = edgeFactor(p_px, b_px, r);
    // Smooth quadratic lens profile (avoids sharp oily refraction cliffs on the outer 1-2px)
    float offsetPxMag = edge * uRefraction + (edge * edge) * uBevelDepth;

    vec2 pNorm = p_px / max(1.0, min(uBoxSize.x, uBoxSize.y));
    vec2 gradApprox = vec2(
        udRoundBox(p_px + vec2(0.5, 0.0), b_px, r) - udRoundBox(p_px - vec2(0.5, 0.0), b_px, r),
        udRoundBox(p_px + vec2(0.0, 0.5), b_px, r) - udRoundBox(p_px - vec2(0.0, 0.5), b_px, r)
    );
    vec2 fallbackDir = length(gradApprox) > 0.0001 ? normalize(gradApprox) : normalize(pNorm + vec2(0.00001));
    vec2 refractDir = cornerNormal(p_px, b_px, r, fallbackDir);

    float centreBlend = smoothstep(0.08, 0.88, edge);
    // Pixel-space inward convex refraction (uniform across ultrawide/portrait, never grabs distant colors)
    vec2 texel = 1.0 / max(vec2(1.0), uTexSize);
    vec2 offset = -refractDir * offsetPxMag * centreBlend * texel;

    vec2 mapped = uBounds.xy + lensUV * uBounds.zw;
    vec2 refracted = mapped + offset;
    float oob = max(max(-refracted.x, refracted.x - 1.0), max(-refracted.y, refracted.y - 1.0));
    float clampBlend = 1.0 - smoothstep(0.0, 0.015, oob);
    vec2 sampleUV = mix(mapped, clamp(refracted, vec2(0.001), vec2(0.999)), clampBlend);

    vec2 chroma = offset * uAberration;
    vec4 refrCol = vec4(0.0);

    if (uFrost > 0.01) {
        float radius = uFrost * 5.2;
        vec4 sum = vec4(0.0);
        const int SAMPLES = 28;
        for (int i = 0; i < SAMPLES; ++i) {
            float fi = float(i) + 0.5;
            float angle = fi * 2.3999632;
            float dist = sqrt(fi / float(SAMPLES)) * radius;
            vec2 foff = vec2(cos(angle), sin(angle)) * texel * dist;
            if (uAberration > 0.001) {
                sum.r += texture(uSource, clamp(sampleUV + foff - chroma, 0.001, 0.999)).r;
                sum.g += texture(uSource, clamp(sampleUV + foff, 0.001, 0.999)).g;
                sum.b += texture(uSource, clamp(sampleUV + foff + chroma, 0.001, 0.999)).b;
                sum.a += texture(uSource, clamp(sampleUV + foff, 0.001, 0.999)).a;
            } else {
                sum += texture(uSource, clamp(sampleUV + foff, 0.001, 0.999));
            }
        }
        refrCol = sum / float(SAMPLES);
    } else {
        refrCol = texture(uSource, sampleUV);
        if (uAberration > 0.001) {
            refrCol.r = texture(uSource, clamp(sampleUV - chroma, 0.001, 0.999)).r;
            refrCol.b = texture(uSource, clamp(sampleUV + chroma, 0.001, 0.999)).b;
        }
    }

    // Preserve crystal-clear vivid color on dark backgrounds; progressively smoke bright areas for crisp text legibility
    float bgLum = dot(refrCol.rgb, vec3(0.2126, 0.7152, 0.0722));
    float darkThemeMask = 1.0 - smoothstep(0.35, 0.65, dot(uTint.rgb, vec3(0.299, 0.587, 0.114)));
    float brightBg = smoothstep(0.42, 0.92, bgLum) * darkThemeMask;
    vec3 smokedColor = refrCol.rgb * mix(1.02, 0.56, brightBg);
    vec3 smokedBase = mix(smokedColor, vec3(0.08, 0.10, 0.13), brightBg * 0.36);
    vec3 glassRgb = mix(smokedBase, uTint.rgb, uTint.a);

    // Subtle static top-left glass sheen (zero moving spotlights or idle repaints)
    vec2 normPos = (p_px + b_px) / max(vec2(1.0), uBoxSize);
    float specGlow = smoothstep(0.75, 0.0, distance(normPos, vec2(0.18, 0.14))) * 0.028;

    // Subtle slightly-thicker glass Fresnel catchlight + crisp dark edge hairline on pure white
    float bevelBand = smoothstep(0.58, 0.99, edge);
    float lightAngle = pow(abs(dot(refractDir, normalize(vec2(-0.70, -0.71)))), 2.1);
    float rimStroke = smoothstep(-1.45, -0.35, dmask);
    float rimIntensity = bevelBand * lightAngle * 0.095 + rimStroke * (0.065 + 0.17 * lightAngle);
    vec3 rimCol = uRimColor.rgb * rimIntensity * uRimColor.a;
    float outerEdgeDark = rimStroke * brightBg * 0.10;

    vec3 finalRgb = clamp(glassRgb * (1.0 - outerEdgeDark) + vec3(specGlow * (1.0 - brightBg * 0.5)) + rimCol * (1.0 - brightBg * 0.45), 0.0, 1.0);
    float alpha = inShape * qt_Opacity;
    fragColor = vec4(finalRgb * alpha, alpha);
}
