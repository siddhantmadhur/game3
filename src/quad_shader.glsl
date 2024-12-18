@header package main
@header import sg "../sokol-odin/sokol/gfx"

@vs vs

in vec2 position;
in vec4 color0;
in vec2 aTexCoord;

out vec4 color;
out vec2 TexCoord;

void main() {
	gl_Position = vec4(position.x, position.y, 0.0, 1.0);
	color = vec4(color0.x, color0.y, color0.z, 1.0); 
	TexCoord = aTexCoord;
}

@end

@fs fs

in vec4 color;
in vec2 TexCoord;

out vec4 FragColor;

layout(binding = 0) uniform texture2D _ourTexture;
layout(binding = 0) uniform sampler ourTexture_smp;
#define ourTexture sampler2D(_ourTexture, ourTexture_smp)



void main() {
	FragColor = texture(ourTexture, TexCoord) * color; 
}

@end

@program simple vs fs