#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uBackPhase;
    float uFrontPhase;
    float uLightMix;
    vec4 uColor;
    vec4 uGeom;   // x: baseW, y: baseH, z: panelW, w: cornerRadius
    vec2 uScale;  // x: xScale, y: yScale
};

const float TWO_PI = 6.28318530718;

vec3 evalWaveHdr(float perp, float shimmer, vec3 auraColor, vec3 hotCoreColor)
{
    float d = abs(perp);

    // Wide atmospheric optical bloom (asymmetric so haze spreads smoothly into the dark glass above and liquid below)
    float dAura = perp < 0.0 ? -perp * 1.14 : perp * 0.76;
    float aura = exp(-dAura * 0.088);

    // Mid-range saturated corona around the crest
    float corona = exp(-(d * d) / (2.0 * 4.8 * 4.8));

    // Tight HDR incandescent crest filament
    float core = exp(-(d * d) / (2.0 * 1.35 * 1.35));

    // Translucent liquid glass body below the wave crest
    float body = smoothstep(-2.0, 3.5, perp) * exp(-max(0.0, perp) * 0.048);

    vec3 glow = auraColor * (body * 0.15 + aura * 0.135);
    glow += mix(auraColor, hotCoreColor, 0.36) * (corona * 0.21);
    glow += hotCoreColor * (core * shimmer * 0.42);
    return glow;
}

void main()
{
    vec2 p = qt_TexCoord0 * uGeom.xy;

    // 1. Seamless spatial fades (zero top border, soft lateral glass vignette, exact rounded-bottom SDF)
    float topFade = smoothstep(0.0, 26.0, p.y);
    float edgeT = abs(qt_TexCoord0.x - 0.5) * 2.0;
    float sideVignette = mix(1.0, 0.22, smoothstep(0.42, 1.0, edgeT));

    float halfW = max(12.0, uGeom.z * 0.5);
    float r = clamp(uGeom.w - 1.0, 4.0, halfW - 1.0);
    float px = (qt_TexCoord0.x - 0.5) * uGeom.z;
    float yFromBottom = max(0.0, (1.0 - qt_TexCoord0.y) * uGeom.y * uScale.y);
    vec2 cornerQ = vec2(max(0.0, abs(px) - (halfW - r)), max(0.0, r - yFromBottom));
    float cornerSdf = length(cornerQ) - r;
    float cornerMask = 1.0 - smoothstep(-1.8, 0.6, cornerSdf);

    // 2. Spectral chroma boost for rich outer bloom + luminous HDR core shift
    vec3 srcRgb = clamp(uColor.rgb, 0.0, 1.0);
    float srcLum = dot(srcRgb, vec3(0.2126, 0.7152, 0.0722));
    float maxC = max(srcRgb.r, max(srcRgb.g, srcRgb.b));
    float minC = min(srcRgb.r, min(srcRgb.g, srcRgb.b));
    float chromaSpan = maxC - minC;

    vec3 chroma = clamp(mix(vec3(srcLum), srcRgb, 1.44), 0.0, 1.0);
    float chromaMax = max(chroma.r, max(chroma.g, chroma.b));
    vec3 vividColor = chromaMax > 0.02 ? (chroma / max(0.82, chromaMax)) : vec3(0.88);
    vec3 baseGlowColor = mix(srcRgb, vividColor, smoothstep(0.05, 0.22, chromaSpan));

    vec3 hotCoreDark = mix(baseGlowColor, vec3(1.0), 0.58);
    vec3 hotCoreLight = mix(baseGlowColor * 0.85, vec3(1.0), 0.22);
    vec3 hotCoreColor = mix(hotCoreDark, hotCoreLight, uLightMix);
    vec3 auraColor = mix(baseGlowColor, baseGlowColor * 0.88, uLightMix);

    // 3. Two C-infinity smooth counter-drifting harmonic swells (integer phase multipliers = seamless loop wrap)
    float k1 = TWO_PI / 460.0;
    float t1 = p.x * k1 + uBackPhase;
    float y1 = 50.0 + 9.0 * sin(t1) + 2.2 * sin(t1 * 2.0 + 0.85);
    float dy1 = k1 * (9.0 * cos(t1) + 4.4 * cos(t1 * 2.0 + 0.85));
    float perp1 = (p.y - y1) * inversesqrt(1.0 + dy1 * dy1);
    float shimmer1 = 0.80 + 0.20 * sin(p.x * (TWO_PI / 520.0) - uBackPhase);

    float k2 = TWO_PI / 380.0;
    float t2 = p.x * k2 - uFrontPhase;
    float y2 = 62.5 + 8.0 * sin(t2 + 1.35) + 1.8 * cos(t2 * 2.0 - 0.55);
    float dy2 = k2 * (8.0 * cos(t2 + 1.35) - 3.6 * sin(t2 * 2.0 - 0.55));
    float perp2 = (p.y - y2) * inversesqrt(1.0 + dy2 * dy2);
    float shimmer2 = 0.78 + 0.22 * sin(p.x * (TWO_PI / 440.0) + uFrontPhase + 1.1);

    // 4. Linear additive HDR radiance accumulation + soft filmic tone curve
    float floorMist = pow(clamp((p.y - 28.0) / 68.0, 0.0, 1.0), 1.9);
    vec3 hdr = auraColor * (floorMist * 0.075);
    hdr += 0.85 * evalWaveHdr(perp1, shimmer1, auraColor, hotCoreColor);
    hdr += 1.22 * evalWaveHdr(perp2, shimmer2, auraColor, hotCoreColor);

    vec3 toneMapped = hdr / (vec3(1.0) + 0.30 * hdr);
    float modeScale = mix(1.0, 0.78, uLightMix);
    vec3 lit = toneMapped * modeScale * cornerMask * topFade * sideVignette;

    // 5. Valid premultiplied alpha output for Wayland translucent glass compositing
    float outAlpha = clamp(max(lit.r, max(lit.g, lit.b)), 0.0, 1.0);
    vec3 premulRgb = min(lit, vec3(outAlpha));
    fragColor = vec4(premulRgb, outAlpha) * qt_Opacity;
}
