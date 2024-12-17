@header package main
@header import sg "../sokol-odin/sokol/gfx"

@vs vs

in vec4 position;
in vec2 aTexCoord;

out vec3 ourColor;
out vec2 TexCoord;

void main() {
	gl_Position = vec4(position.x, position.y, position.z, 1.0);
	ourColor = vec3(1.0, 1.0, 1.0);
	TexCoord = aTexCoord;
}

@end

@fs fs

out vec4 FragColor;

in vec3 ourColor;
in vec2 TexCoord;

layout(binding = 0) uniform texture2D _ourTexture;
layout(binding = 0) uniform sampler ourTexture_smp;
#define ourTexture sampler2D(_ourTexture, ourTexture_smp)

void main() {
	FragColor = texture(ourTexture, TexCoord);
}

@end

@program simple vs fs