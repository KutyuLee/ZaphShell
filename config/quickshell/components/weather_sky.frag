#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    float uIntro;
    float uCloudiness;
    float uSunAmount;
    float uRainAmount;
    float uStormAmount;
    float uSnowAmount;
    float uFogAmount;
    float uCornerRadius;
    vec4 uSkyTop;
    vec4 uSkyMid;
    vec4 uSkyBot;
    vec2 uSize;
};

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.45);
    return fract(p.x * p.y);
}

float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

const mat2 ROT = mat2(0.80, -0.60, 0.60, 0.80);

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; ++i) {
        v += a * noise2d(p);
        p = ROT * p * 2.03 + vec2(7.1, 3.4);
        a *= 0.5;
    }
    return v;
}

// Smooth analytical raindrop layer (stretches top-to-bottom across the entire panel)
float rainLayer(vec2 uv, float scale, float speed, float time, float seed) {
    vec2 p = vec2(uv.x + uv.y * 0.20, uv.y * 1.45);
    p *= vec2(scale, scale * 0.16);
    p.y -= time * speed;
    vec2 id = floor(p);
    vec2 gv = fract(p) - 0.5;
    float n = hash21(id + seed);
    if (n < 0.54) return 0.0;
    float xOff = (fract(n * 17.3) - 0.5) * 0.56;
    float dx = abs(gv.x - xOff);
    float streak = smoothstep(0.09, 0.01, dx);
    float vertFade = smoothstep(-0.48, 0.15, gv.y) * smoothstep(0.48, -0.15, gv.y);
    return streak * vertFade * (0.45 + 0.55 * fract(n * 9.1));
}

// Analytical falling snow layer (stretches top-to-bottom with gentle sway)
float snowLayer(vec2 uv, float scale, float speed, float time, float seed) {
    vec2 p = vec2(uv.x, uv.y * 1.35) * scale;
    p.y -= time * speed;
    p.x += sin(time * 0.9 + p.y * 0.6 + seed) * 0.28;
    vec2 id = floor(p);
    vec2 gv = fract(p) - 0.5;
    float n = hash21(id + seed);
    if (n < 0.62) return 0.0;
    vec2 offset = vec2(fract(n * 13.7) - 0.5, fract(n * 29.3) - 0.5) * 0.48;
    float d = length(gv - offset);
    float radius = 0.08 + 0.08 * fract(n * 41.2);
    return smoothstep(radius, radius * 0.15, d) * (0.4 + 0.6 * fract(n * 7.7));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * uSize;
    float aspect = uSize.x / max(1.0, uSize.y);
    float intro = clamp(uIntro, 0.0, 1.0);
    float introEase = 1.0 - pow(1.0 - intro, 3.0);

    // 1. Full-height top-to-bottom Honor atmospheric sky gradient (including top bar all the way to bottom)
    vec3 sky = mix(uSkyTop.rgb, uSkyMid.rgb, smoothstep(0.0, 0.44, uv.y));
    sky = mix(sky, uSkyBot.rgb, smoothstep(0.38, 1.0, uv.y));

    // 2. Radiant Sun with Opening Shine Animation (star-burst rays + soft warm core, never blowing out white text)
    vec2 sunPos = vec2(0.76, 0.15 - (1.0 - introEase) * 0.05);
    vec2 sunDelta = (uv - sunPos) * vec2(aspect, 1.0);
    float sunDist = length(sunDelta);
    float sunOpen = smoothstep(0.0, 1.0, introEase);
    float disc = smoothstep(0.068 * (0.5 + 0.5 * sunOpen), 0.012, sunDist) * (0.38 * sunOpen);
    float innerCorona = exp(-sunDist * mix(11.0, 7.2, sunOpen)) * (0.30 * sunOpen);
    vec3 sunWarm = vec3(1.00, 0.76, 0.32);
    vec3 sunCore = vec3(1.00, 0.92, 0.68);
    if (uSunAmount > 0.005) {
        float rayRot = (1.0 - introEase) * 0.75;
        float angle = atan(sunDelta.y, sunDelta.x) + rayRot;
        float rays = 0.5 + 0.5 * sin(angle * 7.0 + uTime * 0.38) * cos(angle * 4.0 - uTime * 0.24);
        float spread = mix(5.8, 3.0, sunOpen);
        float rayMask = exp(-sunDist * spread) * rays * (0.14 * sunOpen);
        float outerGlow = exp(-sunDist * mix(4.8, 2.6, sunOpen)) * (0.24 * sunOpen);

        vec3 sunLight = (sunWarm * (outerGlow + rayMask) + sunCore * (innerCorona + disc)) * uSunAmount;
        sky = sky + sunLight * (vec3(0.90) - sky * 0.65);
    }

    // 3. Multi-layered Volumetric FBM Clouds that float in on open & drift continuously top-to-bottom
    if (uCloudiness > 0.01) {
        float cloudSlideIn = (1.0 - introEase);
        // Back cloud layer slides in from right & top on open
        vec2 cUv = vec2((uv.x + cloudSlideIn * 0.34) * aspect * 1.95, (uv.y + cloudSlideIn * 0.12) * 3.10);

        vec2 q = vec2(
            fbm(cUv + vec2(uTime * 0.055, uTime * 0.012)),
            fbm(cUv + vec2(1.4, 2.7) + vec2(uTime * 0.042, -uTime * 0.015))
        );
        vec2 warpedUv = cUv + 0.55 * q + vec2(uTime * 0.075, 0.0);
        float rawCloud = fbm(warpedUv);

        // Foreground cloud bank slides in from the left on open (prominent in upper/hero region like Honor reference)
        vec2 fgUv = vec2((uv.x - 0.10 - cloudSlideIn * 0.42) * aspect * 1.65, (uv.y - 0.06 + cloudSlideIn * 0.08) * 2.65);
        float fgCloud = fbm(fgUv + 0.42 * q + vec2(uTime * 0.108, -uTime * 0.018));

        // Vertical envelope: rich billowing clouds across the bar & hero (0.0..0.52), plus softer ambient clouds behind the cards (0.52..1.0)
        float heroEnv = smoothstep(0.0, 0.10, uv.y) * smoothstep(0.62, 0.28, uv.y);
        float lowerEnv = smoothstep(0.32, 0.65, uv.y) * smoothstep(1.02, 0.72, uv.y) * 0.48;
        float vertEnv = max(heroEnv, lowerEnv);
        float leftWeight = mix(0.90, 1.16, smoothstep(0.85, 0.12, uv.x));

        float threshold = mix(0.56, 0.25, uCloudiness);
        float introDensity = mix(0.30, 1.0, introEase);
        // Gently thin clouds near the sun edge so the sun partially peeks through
        float sunClearing = mix(1.0, smoothstep(0.02, 0.24, sunDist), uSunAmount * 0.36);
        float density = smoothstep(threshold, threshold + 0.42, (rawCloud * 0.55 + fgCloud * 0.52) * leftWeight) * vertEnv * uCloudiness * introDensity * sunClearing;

        // Directional light sample for volumetric silver-lining & self-shadowing
        vec2 lightOffset = normalize(vec2(0.45, -0.75)) * 0.095;
        float litSample = fbm(warpedUv + lightOffset);
        float lightTerm = clamp((rawCloud - litSample) * 2.4 + 0.60 * (1.0 - uv.y * 0.75), 0.0, 1.0);

        vec3 darkBelly = mix(vec3(0.25, 0.29, 0.37), vec3(0.16, 0.19, 0.27), uRainAmount * 0.65 + uStormAmount * 0.35);
        vec3 brightCrest = mix(vec3(0.89, 0.92, 0.97), vec3(1.00, 0.93, 0.78), uSunAmount * 0.48);
        vec3 cloudCol = mix(darkBelly, brightCrest, smoothstep(0.12, 0.85, lightTerm));

        if (uStormAmount > 0.01) {
            float flashWave = pow(max(0.0, sin(uTime * 1.85) * sin(uTime * 4.3 + 0.7)), 14.0);
            float cellMask = smoothstep(0.42, 0.78, fgCloud) * smoothstep(0.75, 0.12, length(uv - vec2(0.58, 0.24)));
            cloudCol += vec3(0.86, 0.89, 1.0) * flashWave * cellMask * uStormAmount * 1.40;
        }

        // Partly cloudy puffs are more translucent (~46% max) while overcast/rainy clouds remain dense (~90%)
        float maxCloudAlpha = mix(0.46, 0.90, smoothstep(0.35, 0.88, uCloudiness));
        float cloudAlpha = clamp(density * maxCloudAlpha, 0.0, maxCloudAlpha);
        sky = mix(sky, cloudCol, cloudAlpha);

        // Allow the sun orb to partially shine through translucent clouds in partly-cloudy mode
        if (uSunAmount > 0.05) {
            float bleed = (1.0 - cloudAlpha * 0.72) * uSunAmount;
            sky += sunCore * (disc * 0.34 + innerCorona * 0.16) * bleed * (vec3(0.92) - sky * 0.65);
        }
    }

    // 4. Undulating Volumetric Fog / Mist Ribbons
    if (uFogAmount > 0.01) {
        float mist1 = sin(uv.x * 5.5 + uTime * 0.45 + fbm(uv * 3.0) * 2.2) * 0.5 + 0.5;
        float mist2 = cos(uv.x * 4.2 - uTime * 0.35 + uv.y * 7.5) * 0.5 + 0.5;
        float fogBand = (mist1 * 0.6 + mist2 * 0.4) * smoothstep(0.02, 0.28, uv.y) * smoothstep(0.98, 0.45, uv.y);
        sky = mix(sky, vec3(0.76, 0.83, 0.88), fogBand * uFogAmount * 0.40 * introEase);
    }

    // 5. Multi-depth Parallax Falling Rain Streaks (smooth top-to-bottom rain)
    if (uRainAmount > 0.01) {
        float r1 = rainLayer(uv, 22.0, 2.35, uTime, 1.7);
        float r2 = rainLayer(uv, 34.0, 1.85, uTime, 5.3) * 0.65;
        float r3 = rainLayer(uv, 48.0, 1.40, uTime, 9.1) * 0.40;
        float rainMask = (r1 + r2 + r3) * smoothstep(0.0, 0.06, uv.y) * smoothstep(1.0, 0.78, uv.y);
        vec3 rainCol = vec3(0.68, 0.88, 1.00);
        sky += rainCol * rainMask * uRainAmount * 0.52 * introEase;
    }

    // 6. Multi-depth Parallax Falling & Swaying Snowflakes (top to bottom)
    if (uSnowAmount > 0.01) {
        float s1 = snowLayer(uv, 12.0, 0.55, uTime, 2.1);
        float s2 = snowLayer(uv, 20.0, 0.38, uTime, 6.4) * 0.75;
        float s3 = snowLayer(uv, 30.0, 0.26, uTime, 11.8) * 0.50;
        float snowMask = (s1 + s2 + s3) * smoothstep(0.0, 0.05, uv.y) * smoothstep(1.0, 0.80, uv.y);
        sky += vec3(0.92, 0.97, 1.00) * snowMask * uSnowAmount * 0.70 * introEase;
    }

    // 7. Exact 4-corner Rounded Rectangle SDF matching ScreenFrame's Right Island capsule
    vec2 halfSize = uSize * 0.5 - vec2(1.0);
    float r = clamp(uCornerRadius - 1.0, 2.0, min(halfSize.x, halfSize.y));
    vec2 qBox = abs(px - uSize * 0.5) - (halfSize - vec2(r));
    float boxSdf = length(max(qBox, 0.0)) + min(max(qBox.x, qBox.y), 0.0) - r;
    float mask = 1.0 - smoothstep(-1.2, 0.4, boxSdf);

    float alpha = clamp(mask * introEase, 0.0, 1.0) * qt_Opacity;
    fragColor = vec4(sky * alpha, alpha);
}
