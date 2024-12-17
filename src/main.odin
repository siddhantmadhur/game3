package main

import "base:runtime"
import "core:fmt"


import "core:math/linalg"
import "core:os"

import slog "../sokol-odin/sokol/log"
import sg "../sokol-odin/sokol/gfx"
import sapp "../sokol-odin/sokol/app"
import sglue "../sokol-odin/sokol/glue"

import stbi "vendor:stb/image"

Settings :: struct {
	window_w: i32,
	window_h: i32,
	title: cstring,
}

global_settings: Settings = {
	window_w = 1280,
	window_h = 720,
	title = "Houses&Houses"
}

state: struct {
	pip: sg.Pipeline,
	bind: sg.Bindings,
	pass_action: sg.Pass_Action,
}

hex_to_rgba :: proc (hex_cl: int) -> sg.Color {
	hex := hex_cl
	colors: [4]f32 

	for i := 0; i < 4; i += 1 {
		color := 0
		for d: uint = 0; d < 2; d = d + 1 {
			c := hex % 16
			if d == 1 {
				c = c * 16
			}
			color += c
			hex = hex / 16
		}		
		colors[3 - i] = (auto_cast color) / 255.0
	}

	return sg.Color{colors[0], colors[1], colors[2], colors[3]}
}

Vertex :: struct {
	pos: Vector2,
	color: Vector4,
	uv: Vector2,
	tex_index: u8,
}

Quad :: [4]Vertex

MAX_QUADS :: 8192
MAX_VERTS :: MAX_QUADS * 4

Draw_Frame :: struct {
	quads: [MAX_QUADS]Quad,
	quad_count: int,

	projection: Matrix4,
	camera_xform: Matrix4,

}

draw_frame : Draw_Frame;

DEFAULT_UV :: v4{0, 0, 1, 1}
Vector2i :: [2]int
Vector2 :: [2]f32
Vector3 :: [3]f32
Vector4 :: [4]f32
v2 :: Vector2
v3 :: Vector3
v4 :: Vector4
Matrix4 :: linalg.Matrix4f32;

COLOR_WHITE :: Vector4 {1,1,1,1}
COLOR_RED :: Vector4 {1,0,0,1}

// :Image stuff

Image_Id :: enum {
	nil,
	brick,	
}

Image :: struct {
	width, height: i32,
	tex_index: u8,
	sg_img: sg.Image,
	data: [^]byte,
	atlas_uvs: Vector4,
}

images: [128]Image
image_count: int

init_images :: proc () {
	using fmt

	img_dir := "assets/images/"

	highest_id := 0
	for img_name, id in Image_Id {
		if id == 0 { continue }
		if id > highest_id {
			highest_id = id
		}

		path := tprint(img_dir, img_name, ".png", sep="")
		png_data, succ := os.read_entire_file(path)
		assert(succ)

		stbi.set_flip_vertically_on_load(1)
		width, height, channels: i32
		img_data := stbi.load_from_memory(raw_data(png_data), auto_cast len(png_data), &width, &height, &channels, 4)
		assert(img_data != nil, "stbi load failed, invalid image?")

		img : Image;
		img.width = width
		img.height = height
		img.data = img_data
		
		images[id] = img
	}

	image_count = highest_id + 1
}

init :: proc "c" () {
	context = runtime.default_context()

	init_images()
	

	sg.setup({
		environment = sglue.environment(),
		logger = { func = slog.func },
	})
	
	switch sg.query_backend() {
		case .D3D11: fmt.println(">> using D3D11 backend")
        case .GLCORE, .GLES3: fmt.println(">> using GL backend")
        case .METAL_MACOS, .METAL_IOS, .METAL_SIMULATOR: fmt.println(">> using Metal backend")
        case .WGPU: fmt.println(">> using WebGPU backend")
        case .DUMMY: fmt.println(">> using dummy backend")
	}



	shd: sg.Shader = sg.make_shader(simple_shader_desc(sg.query_backend()));

 /* a vertex buffer with 4 vertices */
	vertices := [?]f32  {
		// positions 		// Texture Coords
		 0.5,  0.5, 0.0,	1.0, 1.0,    
		 0.5, -0.5, 0.0,   	1.0, 0.0, 
		-0.5, -0.5, 0.0,   	0.0, 0.0,
		-0.5,  0.5, 0.0,    0.0, 1.0, 
	};

	state.bind.vertex_buffers[0] = sg.make_buffer({
		data = { ptr = &vertices, size = size_of(vertices) }	
	})

	indices:= [?]u16 {
		0, 1, 3,
		1, 2, 3
	}

	state.bind.index_buffer = sg.make_buffer({
		data = { ptr = &indices, size = size_of(indices) }
	})

	 pixels := [4*4]u32 {
        0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF, 0xFF000000,
        0xFF000000, 0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF,
        0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF, 0xFF000000,
        0xFF000000, 0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF,
    }
	brick := images[Image_Id.brick]
	state.bind.images[IMG__ourTexture] = sg.make_image({
		width = brick.width,
		height = brick.height,
		pixel_format = sg.Pixel_Format.RGBA8,
		data = {
			subimage = {
				0 = {
					0 = { ptr = brick.data, size = auto_cast (brick.width * brick.height * 4) },
				},
			},
		},
	})

	stbi.image_free(brick.data)

	state.bind.samplers[SMP_ourTexture_smp] = sg.make_sampler({})

	state.pip = sg.make_pipeline({
		shader = shd,
		index_type = .UINT16,
		layout = {
			attrs = {
				ATTR_simple_position = { format = .FLOAT3 },
				ATTR_simple_aTexCoord = { format = .FLOAT2 },
			},
		},
		cull_mode = .BACK,
		depth = {
			compare = .LESS_EQUAL,
			write_enabled = true,
		}
	})


	state.pass_action = {
		colors = {
			0 = { load_action = .CLEAR, clear_value = hex_to_rgba(0x443355FF) }
		}
	}


}

frame :: proc "c" () {
	context = runtime.default_context()
	sg.begin_pass({ action = state.pass_action, swapchain = sglue.swapchain() })
	sg.apply_pipeline(state.pip)
	sg.apply_bindings(state.bind)
	sg.draw(0, 6, 1);
	sg.end_pass()
	sg.commit()
}

cleanup :: proc "c" () {
	context = runtime.default_context()
	sg.shutdown()
}

main :: proc() {
	sapp.run({
		init_cb = init,
		frame_cb = frame,
		cleanup_cb = cleanup,
		width = global_settings.window_w,
		height = global_settings.window_h,
		window_title = global_settings.title,
		icon = { sokol_default = true },
		logger = { func = slog.func },
	})
}