@header package main
@header import sg "../sokol-odin/sokol/gfx"


//
// VERTEX SHADER
//
@vs vs
in vec2 position;
in vec4 color0;
in vec2 uv0;
in vec4 bytes0;

out vec4 color;
out vec2 uv;
out vec4 bytes;


void main() {
	gl_Position = vec4(position, 0, 1);
	color = color0;
	uv = uv0;
	bytes = bytes0;
}
@end


//
// FRAGMENT SHADER
//
@fs fs
layout(binding=0) uniform texture2D tex0;
layout(binding=0) uniform sampler default_sampler;

in vec4 color;
in vec2 uv;
in vec4 bytes;

out vec4 col_out;

void main() {

	int tex_index = int(bytes.x * 255.0);
	
	vec4 tex_col = vec4(1.0);
	if (tex_index == 0) {
		tex_col = texture(sampler2D(tex0, default_sampler), uv);
	} 	
	col_out = tex_col;
	col_out *= color;
	
}
@end

@program quad vs fs