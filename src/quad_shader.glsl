@header package main
@header import sg "../sokol-odin/sokol/gfx"

@vs vs

in vec2 position;
in vec4 color0;

out vec4 color;

void main() {
	gl_Position = vec4(position.x, position.y, 0.0, 1.0);
	color = color0;
}

@end

@fs fs

in vec4 color;
out vec4 FragColor;

void main() {
	FragColor = color; 
}

@end

@program simple vs fs