#version 330 compatibility

#include "./palette.glsl"

#define OUTLINE
#define OUTLINE_WIDTH 10 // [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]
#define OUTLINE_SHADE 1 // [0 1]

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float far;
uniform float near;
uniform float viewHeight;
uniform float viewWidth;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

float linearizeDepth(float depth)
{
    float zNear = 2.0 * depth - 1.0;
    return 2.0 * near * far / (far + near - zNear * (far - near));
}

const int range = OUTLINE_WIDTH;

void main() {
	color = texture(colortex0, texcoord);

	#ifdef OUTLINE
		vec2 resolution = vec2(viewWidth, viewHeight);
		ivec2 fragCoord = ivec2(texcoord * vec2(textureSize(colortex0, 0)));

		vec2 uv = vec2(fragCoord) / resolution;

		float center = linearizeDepth(texture(depthtex0, texcoord).r);
		int hits = 0;
		float detection = far * 0.05;

		for (int x = -range; x <= range; x++) {
			vec2 position = vec2(fragCoord + ivec2(x, 0)) / resolution;
			float depth = texture(depthtex0, position).r;
			hits += int(abs(center - linearizeDepth(depth)) > detection);
		}

		for (int y = -range; y <= range; y++) {
			vec2 position = vec2(fragCoord + ivec2(0, y)) / resolution;
			float depth = texture(depthtex0, position).r;
			hits += int(abs(center - linearizeDepth(depth)) > detection);
		}
		
		if (hits > (range / 2)) {
			#if OUTLINE_SHADE == 1
				color = vec4(lightColor, color.a);
			#endif

			#if OUTLINE_SHADE == 0
				color = vec4(darkColor, color.a);
			#endif
		}
	#endif
}