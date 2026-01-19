#version 330 compatibility

#include "./palette.glsl"

#define PIXELS 350.0 // [30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 150.0 200.0 250.0 300.0 350.0 400.0 450.0 500.0 550.0 600.0 650.0 750.0 1000.0]
#define DITHERING
#define DITHER_THRESHOLD 0.055 // [0.5 0.4 0.3 0.2 0.1 0.09 0.07 0.06 0.05 0.055 0.04 0.03 0.02 0.01 0.00]
// #define VIGNETTE
#define VIGNETTE_SIZE 0.3 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]

in vec2 texcoord;

uniform float viewHeight;
uniform float viewWidth;
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float far;
uniform float near;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

// Human eyes see differently from sRGB lol (shocking)
float perceptualDistance(vec3 x, vec3 y) {
    vec3 difference = x - y;
    return sqrt(
        difference.r * difference.r * 0.2125 +
        difference.g * difference.g * 0.7154 +
        difference.b * difference.b * 0.0721
    );
}

// Why isn't depth linear :(
float linearizeDepth(float depth)
{
    float zNear = 2.0 * depth - 1.0;
    return 2.0 * near * far / (far + near - zNear * (far - near));
}

const mat4 bayer4x4 = mat4(
    0.0, 0.5, 0.125, 0.625,
    0.75, 0.25, 0.875, 0.375,
    0.1875, 0.6875, 0.0625, 0.5625,
    0.9375, 0.4375, 0.8125, 0.3125
);

void main() {
	vec2 resolution = vec2(viewWidth, viewHeight);
	ivec2 fragCoord = ivec2(texcoord * vec2(textureSize(colortex0, 0)));

	vec2 uv = vec2(fragCoord) / resolution;

    float factor = resolution.x / resolution.y;

    float shiftedX = round(uv.x * PIXELS);
    float shiftedY = round(uv.y * (PIXELS / factor));

	vec2 normalizedShift = vec2(shiftedX / PIXELS, shiftedY / PIXELS * factor);

    vec4 originalColor = texture(colortex0, normalizedShift);

    #ifdef VIGNETTE
        vec2 shift = abs(normalizedShift - 0.5);
        float dist = distance(shift, vec2(0.0, 0.0));
        float vignetteFactor = smoothstep(0.2, 0.9, dist) * VIGNETTE_SIZE;
            
        originalColor.rgb -= vignetteFactor;
    #endif

    // Will fallback to first color
    int closestColor = 0;
    int secondClosestColor = 0;

    // Use large value but in practice we could use 1.1
    float minimumDistance = 1e9;
    float minimumSecondDistance = 1e9;

    for (int i = 0; i < colorNum; i++) {
        float colorDistance = perceptualDistance(originalColor.rgb, colors[i]);
        if (colorDistance < minimumDistance) {
            secondClosestColor = closestColor;
            closestColor = i;
            minimumDistance = colorDistance;
        } else if (colorDistance < minimumSecondDistance) {
            secondClosestColor = i;
            minimumSecondDistance = colorDistance;
        }
    }

    int index = closestColor;

    #ifdef DITHERING
        if (minimumDistance > DITHER_THRESHOLD) {
            float distanceOne = perceptualDistance(originalColor.rgb, colors[closestColor]);
            float distanceTwo = perceptualDistance(originalColor.rgb, colors[secondClosestColor]);

            float difference = distanceOne / (distanceTwo + 1e-6);

            int positionX = int(shiftedX) % 4;
            int positionY = int(shiftedY) % 4;

            float bayerValue = bayer4x4[positionX][positionY];

            index = (bayerValue <= difference) ? closestColor : secondClosestColor;
        }
    #endif

    color = vec4(colors[index], originalColor.a);
}


