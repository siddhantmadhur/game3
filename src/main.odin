package main

import "base:runtime"
import "core:fmt"


import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:time"

import sapp "../sokol-odin/sokol/app"
import sfetch "../sokol-odin/sokol/fetch"
import sg "../sokol-odin/sokol/gfx"
import sglue "../sokol-odin/sokol/glue"
import slog "../sokol-odin/sokol/log"
import sgl "../sokol-odin/sokol/gl"

import imgui "../imgui-odin"
import opengl "../imgui-odin/imgui_impl_opengl3"

import stbi "vendor:stb/image"
import stbrp "vendor:stb/rect_pack"
import stbtt "vendor:stb/truetype"

Settings :: struct {
	window_w:    i32,
	window_h:    i32,
	title:       cstring,
	paused:      bool,
	input_state: InputState,
	is_imgui_hovered: bool,
}

global: Settings = {
	window_w    = 1280,
	window_h    = 720,
	title       = "game3",
	paused      = false,
	input_state = {},
	is_imgui_hovered = false,
}

GameEvents :: struct {
	e: [255]sapp.Event,
	n: int,
}

events: GameEvents

state: struct {
	pip:         sg.Pipeline,
	bind:        sg.Bindings,
	pass_action: sg.Pass_Action,
}

vec_to_col :: proc(colors: [4]f32) -> sg.Color {
	return sg.Color{colors[0], colors[1], colors[2], colors[3]}
}

hex_to_rgba :: proc(hex_cl: int) -> [4]f32 {
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

	return Vector4{colors[0], colors[1], colors[2], colors[3]}
}

is_within_square :: proc(pos: Vector2, obj_pos: Vector2, obj_size: Vector2) -> bool {
	is_below_y := obj_pos.y <= pos.y
	is_above_y := (obj_pos.y + obj_size.y) >= pos.y
	is_left_x := (obj_pos.x) <= pos.x
	is_right_x := (obj_pos.x + obj_size.x) >= pos.x

	return is_below_y && is_above_y && is_left_x && is_right_x
}

// Calculates the actual world coordinates in terms of relative screen position
world_to_pos :: proc(world: Vector2) -> Vector2 {

	camera_offset := game.camera_pos - (v2{f32(global.window_w), f32(global.window_h)} * 0.5)

	pos := world + camera_offset
	pos.y *= -1

	pos.y /= game.camera_zoom

	return pos
}

Vertex :: struct {
	pos:       Vector2,
	color:     Vector4,
	uv:        Vector2,
	tex_index: u8,
	_pad:      [3]u8,
}

Quad :: [4]Vertex

MAX_QUADS :: 8192
MAX_VERTS :: MAX_QUADS * 4

Draw_Frame :: struct {
	quads:        [MAX_QUADS]Quad,
	quad_count:   int,
	projection:   Matrix4,
	camera_xform: Matrix4,
}

draw_frame: Draw_Frame

v2_length :: proc(vec: Vector2) -> f32 {
	return math.sqrt(math.pow(vec.x, 2) + math.pow(vec.y, 2))
}

v2_normalize :: proc(vec: ^Vector2) {
	length := v2_length(vec^)
	if length != 0 {
		vec.x /= length
		vec.y /= length
	}
}

screen_to_world :: proc(pos: Vector2) -> Vector2 {

	ndc_x := (pos.x / (f32(global.window_w) * 0.5)) - 1.0
	ndc_y := (pos.y / (f32(global.window_h) * 0.5)) - 1.0
	//ndc_y *= -1

	pos_world: v4 = v4{ndc_x, ndc_y, 0, 1}

	pos_world *= linalg.inverse(draw_frame.projection)
	pos_world = linalg.inverse(draw_frame.camera_xform) * pos_world

	return pos_world.xy

}


DEFAULT_UV :: v4{0, 0, 1, 1}
Vector2i :: [2]int
Vector2 :: [2]f32
Vector3 :: [3]f32
Vector4 :: [4]f32
v2 :: Vector2
v3 :: Vector3
v4 :: Vector4
Matrix4 :: linalg.Matrix4f32

COLOR_WHITE :: Vector4{1, 1, 1, 1}
COLOR_RED :: Vector4{1, 0, 0, 1}

xform_translate :: proc(pos: Vector2) -> Matrix4 {
	return linalg.matrix4_translate(v3{pos.x, pos.y, 0})
}
xform_rotate :: proc(angle: f32) -> Matrix4 {
	return linalg.matrix4_rotate(math.to_radians(angle), v3{0, 0, 1})
}
xform_scale :: proc(scale: Vector2) -> Matrix4 {
	return linalg.matrix4_scale(v3{scale.x, scale.y, 1})
}

Pivot :: enum {
	bottom_left,
	bottom_center,
	bottom_right,
	center_left,
	center_center,
	center_right,
	top_left,
	top_center,
	top_right,
}
scale_from_pivot :: proc(pivot: Pivot) -> Vector2 {
	switch pivot {
	case .bottom_left:
		return v2{0.0, 0.0}
	case .bottom_center:
		return v2{0.5, 0.0}
	case .bottom_right:
		return v2{1.0, 0.0}
	case .center_left:
		return v2{0.0, 0.5}
	case .center_center:
		return v2{0.5, 0.5}
	case .center_right:
		return v2{1.0, 0.5}
	case .top_center:
		return v2{0.5, 1.0}
	case .top_left:
		return v2{0.0, 1.0}
	case .top_right:
		return v2{1.0, 1.0}
	}
	return {}
}


//
// :FONT
//
draw_text :: proc(
	pos: Vector2,
	text: string,
	scale_d := 1.0,
	pivot := Pivot.bottom_left,
	color := COLOR_WHITE,
) -> Vector2 {
	using stbtt

	scale := scale_d / 2.0


	// loop thru and find the text size box thingo
	total_size: v2
	for char, i in text {

		advance_x: f32
		advance_y: f32
		q: aligned_quad
		GetBakedQuad(
			&font.char_data[0],
			font_bitmap_w,
			font_bitmap_h,
			cast(i32)char - 32,
			&advance_x,
			&advance_y,
			&q,
			false,
		)
		// this is the the data for the aligned_quad we're given, with y+ going down
		// x0, y0,     s0, t0, // top-left
		// x1, y1,     s1, t1, // bottom-right

		size := v2{abs(q.x0 - q.x1), abs(q.y0 - q.y1)}

		bottom_left := v2{q.x0, -q.y1}
		top_right := v2{q.x1, -q.y0}
		assert(bottom_left + size == top_right)

		if i == len(text) - 1 {
			total_size.x += size.x
		} else {
			total_size.x += advance_x
		}

		total_size.y = max(total_size.y, top_right.y)
	}

	pivot_offset := total_size * -scale_from_pivot(pivot)


	// draw glyphs one by one
	x: f32
	y: f32
	for char in text {

		advance_x: f32
		advance_y: f32
		q: aligned_quad
		GetBakedQuad(
			&font.char_data[0],
			font_bitmap_w,
			font_bitmap_h,
			cast(i32)char - 32,
			&advance_x,
			&advance_y,
			&q,
			false,
		)
		// this is the the data for the aligned_quad we're given, with y+ going down
		// x0, y0,     s0, t0, // top-left
		// x1, y1,     s1, t1, // bottom-right

		size := v2{abs(q.x0 - q.x1), abs(q.y0 - q.y1)}

		bottom_left := v2{q.x0, -q.y1}
		top_right := v2{q.x1, -q.y0}
		assert(bottom_left + size == top_right)

		//bottom_left.y += size.y 
		//top_right.y += size.y 

		offset_to_render_at := v2{x, y} + bottom_left

		offset_to_render_at += pivot_offset

		uv := v4{q.s0, q.t1, q.s1, q.t0}

		xform := Matrix4(1)
		xform *= xform_translate(pos)
		xform *= xform_scale(v2{auto_cast scale, auto_cast scale})
		xform *= xform_translate(offset_to_render_at)


		draw_rect_xform(xform, size, uv = uv, img_id = font.img_id, col = color)

		x += advance_x
		y += -advance_y
	}

	return total_size * f32(scale)
}
font_bitmap_w :: 256 * 2
font_bitmap_h :: 256 * 2
char_count :: 96
Font :: struct {
	char_data: [char_count]stbtt.bakedchar,
	img_id:    Image_Id,
}
font: Font

init_fonts :: proc() {
	using stbtt

	bitmap, _ := mem.alloc(font_bitmap_w * font_bitmap_h)
	font_height := 32 // for some reason this only bakes properly at 15 ? it's a 16px font dou...
	path := "assets/fonts/PressStart2P-Regular.ttf"
	ttf_data, ttf_size, err := read_entire_file(path)
	defer mem.free(ttf_data)
	assert(ttf_data != nil, "failed to read font")
	io := imgui.GetIO() 
	imgui.FontAtlas_AddFontDefault(io.Fonts,nil)
	ret := BakeFontBitmap(
		auto_cast ttf_data,
		0,
		auto_cast font_height,
		auto_cast bitmap,
		font_bitmap_w,
		font_bitmap_h,
		32,
		char_count,
		&font.char_data[0],
	)
	assert(ret > 0, "not enough space in bitmap")

	stbi.write_png(
		"font.png",
		auto_cast font_bitmap_w,
		auto_cast font_bitmap_h,
		1,
		bitmap,
		auto_cast font_bitmap_w,
	)

	// setup font atlas so we can use it in the shader
	desc: sg.Image_Desc
	desc.width = auto_cast font_bitmap_w
	desc.height = auto_cast font_bitmap_h
	desc.pixel_format = .R8
	desc.data.subimage[0][0] = {
		ptr  = bitmap,
		size = auto_cast (font_bitmap_w * font_bitmap_h),
	}

	sg_img := sg.make_image(desc)
	if sg_img.id == sg.INVALID_ID {
		fmt.printfln("failed to make image")
	}

	id := store_image(font_bitmap_w, font_bitmap_h, 1, sg_img)
	font.img_id = id
}
// kind scuffed...
// but I'm abusing the Images to store the font atlas by just inserting it at the end with the next id
store_image :: proc(w: int, h: int, tex_index: u8, sg_img: sg.Image) -> Image_Id {

	img: Image
	img.width = auto_cast w
	img.height = auto_cast h
	img.tex_index = tex_index
	img.sg_img = sg_img
	img.atlas_uvs = DEFAULT_UV

	id := image_count
	images[id] = img
	image_count += 1

	return auto_cast id
}

draw_quad_projected :: proc(
	world_to_clip: Matrix4,
	positions: [4]Vector2,
	colors: [4]Vector4,
	uvs: [4]Vector2,
	tex_indices: [4]u8,
) {
	using linalg

	if draw_frame.quad_count >= MAX_QUADS {
		return
	}

	verts := &draw_frame.quads[draw_frame.quad_count]

	draw_frame.quad_count += 1

	verts[0].pos = (world_to_clip * Vector4{positions[0].x, positions[0].y, 0.0, 1.0}).xy
	verts[1].pos = (world_to_clip * Vector4{positions[1].x, positions[1].y, 0.0, 1.0}).xy
	verts[2].pos = (world_to_clip * Vector4{positions[2].x, positions[2].y, 0.0, 1.0}).xy
	verts[3].pos = (world_to_clip * Vector4{positions[3].x, positions[3].y, 0.0, 1.0}).xy

	verts[0].tex_index = tex_indices[0]
	verts[1].tex_index = tex_indices[1]
	verts[2].tex_index = tex_indices[2]
	verts[3].tex_index = tex_indices[3]

	verts[0].uv = uvs[0]
	verts[1].uv = uvs[1]
	verts[2].uv = uvs[2]
	verts[3].uv = uvs[3]

	verts[0].color = colors[0]
	verts[1].color = colors[1]
	verts[2].color = colors[2]
	verts[3].color = colors[3]

}

draw_rect_projected :: proc(
	world_to_clip: Matrix4,
	size: Vector2,
	col: Vector4 = COLOR_WHITE,
	uv: Vector4 = DEFAULT_UV,
	img_id: Image_Id = .nil,
) {

	bl := v2{0, 0}
	tl := v2{0, size.y}
	tr := v2{size.x, size.y}
	br := v2{size.x, 0}

	uv0 := uv
	if uv == DEFAULT_UV {
		uv0 = images[img_id].atlas_uvs
	}

	tex_index := images[img_id].tex_index
	if img_id == .nil {
		tex_index = 255
	}
	draw_quad_projected(
		world_to_clip,
		{bl, tl, tr, br},
		{col, col, col, col},
		{uv0.xy, uv0.xw, uv0.zw, uv0.zy},
		{tex_index, tex_index, tex_index, tex_index},
	)

}

draw_rect_xform :: proc(
	xform: Matrix4,
	size: Vector2,
	col: Vector4 = COLOR_WHITE,
	uv: Vector4 = DEFAULT_UV,
	img_id: Image_Id = .nil,
) {
	draw_rect_projected(
		draw_frame.projection * draw_frame.camera_xform * xform,
		size,
		col,
		uv,
		img_id,
	)
}

draw_rect :: proc(
	pos: Vector2,
	size: Vector2,
	color: Vector4 = COLOR_WHITE,
	uv: Vector4 = DEFAULT_UV,
	img_id: Image_Id = .nil,
) {
	xform := linalg.matrix4_translate(v3{pos.x, pos.y, 0})
	draw_rect_xform(xform, size, color, uv, img_id)
}


// :Image stuff

Image :: struct {
	width, height: i32,
	tex_index:     u8,
	sg_img:        sg.Image,
	data:          [^]byte,
	atlas_uvs:     Vector4,
}

images: [128]Image
image_count: int

import "core:strings"


fetch_callback :: proc "c" (response: ^sfetch.Response) {
	context = runtime.default_context()
	user_data_cpy: ^ReadFileUserData = auto_cast response.user_data
	user_data := user_data_cpy.self_ptr
	if response.fetched {
		user_data.data_size = response.data.size
		user_data.ptr = response.data.ptr
	} else if response.dispatched {
		fmt.printfln("Fetching %s...", response.path)
	} else if response.failed {
		fmt.printfln("Error fetching %s: code %d", response.path, response.error_code)
		user_data.err = true
		user_data.err_code = response.error_code
	} else {
		fmt.printfln("Something else with %s...", response.path)
	}

	if response.finished {
		user_data.is_finished = true
	}
}

ReadFileUserData :: struct {
	ptr: rawptr,
	data_size: uint,
	is_finished: bool,
	err: bool,
	err_code: sfetch.Error,
	self_ptr: ^ReadFileUserData,
}
read_entire_file :: proc(path: string) -> (rawptr, uint, bool) {

	fmt.printfln("Reading %s...", path)

	user_data := ReadFileUserData {
		is_finished = false,
		err = false,
		data_size = 0,
		err_code = .NO_ERROR,
		ptr = nil,
	}

	user_data.self_ptr = &user_data

	bffr_size: uint = size_of(u64) * 8192 * 8192
	bffr, alloc_err := mem.alloc(auto_cast bffr_size)
	assert(bffr != nil, "Did not allocate correctly")
	if alloc_err != .None {
		fmt.printfln("Allocate error")
		return nil, 0, true
	} else {
		fmt.printfln("Allocated bytes: %d", bffr_size)
	}


	sfetch.send(
		sfetch.Request {
			path = strings.clone_to_cstring(path),
			buffer = {ptr = bffr, size = bffr_size},
			callback = fetch_callback,
			user_data = {ptr = &user_data, size = size_of(ReadFileUserData)}
		},
	)

	for ;!user_data.is_finished; {
		sfetch.dowork()
	}

	data, _:= mem.alloc(auto_cast user_data.data_size)
	mem.copy(data, user_data.ptr, auto_cast user_data.data_size)
	mem.free(bffr)

	return data, user_data.data_size, user_data.err
}


init_images :: proc() {
	using fmt

	img_dir := "assets/images/"

	highest_id := 0
	for img_name, id in Image_Id {
		if id == 0 {continue}
		if id > highest_id {
			highest_id = id
		}

		path := tprint(img_dir, img_name, ".png", sep = "")
		png_data, png_size, succ := read_entire_file(path)
		defer mem.free(png_data)
		assert(!succ, fmt.tprintf("Could not read png file: %s\n", img_name))

		stbi.set_flip_vertically_on_load(1)
		width, height, channels: i32
		img_data := stbi.load_from_memory(
			auto_cast png_data,
			auto_cast png_size,
			&width,
			&height,
			&channels,
			4,
		)
		assert(img_data != nil, "stbi load failed, invalid image?")

		img: Image
		img.width = width
		img.height = height
		img.data = img_data
		img.tex_index = 0

		images[id] = img

	}

	image_count = highest_id + 1

	pack_images_into_atlas()
}

Atlas :: struct {
	w, h:     int,
	sg_image: sg.Image,
}
atlas: Atlas
// We're hardcoded to use just 1 atlas now since I don't think we'll need more
// It would be easy enough to extend though. Just add in more texture slots in the shader
// :pack
pack_images_into_atlas :: proc() {

	// TODO - add a single pixel of padding for each so we avoid the edge oversampling issue

	// 8192 x 8192 is the WGPU recommended max I think
	atlas.w = 1300
	atlas.h = 1300

	cont: stbrp.Context
	nodes: [512]stbrp.Node // #volatile with atlas.w
	stbrp.init_target(&cont, auto_cast atlas.w, auto_cast atlas.h, &nodes[0], auto_cast atlas.w)

	rects: [dynamic]stbrp.Rect
	for img, id in images {
		if img.width == 0 {
			continue
		}
		append(
			&rects,
			stbrp.Rect{id = auto_cast id, w = auto_cast img.width, h = auto_cast img.height},
		)
	}

	succ := stbrp.pack_rects(&cont, &rects[0], auto_cast len(rects))
	if succ == 0 {
		assert(false, "failed to pack all the rects, ran out of space?")
	}

	// allocate big atlas
	raw_data, err := mem.alloc(atlas.w * atlas.h * 4)
	defer mem.free(raw_data)
	mem.set(raw_data, 255, atlas.w * atlas.h * 4)

	// copy rect row-by-row into destination atlas
	for rect in rects {
		img := &images[rect.id]

		// copy row by row into atlas
		for row in 0 ..< rect.h {
			src_row := mem.ptr_offset(&img.data[0], row * rect.w * 4)
			dest_row := mem.ptr_offset(
				cast(^u8)raw_data,
				((rect.y + row) * auto_cast atlas.w + rect.x) * 4,
			)
			mem.copy(dest_row, src_row, auto_cast rect.w * 4)
		}

		// yeet old data
		stbi.image_free(img.data)
		img.data = nil

		// img.atlas_x = auto_cast rect.x
		// img.atlas_y = auto_cast rect.y

		img.atlas_uvs.x = cast(f32)rect.x / cast(f32)atlas.w
		img.atlas_uvs.y = cast(f32)rect.y / cast(f32)atlas.h
		img.atlas_uvs.z = img.atlas_uvs.x + cast(f32)img.width / cast(f32)atlas.w
		img.atlas_uvs.w = img.atlas_uvs.y + cast(f32)img.height / cast(f32)atlas.h
	}

	stbi.write_png(
		"atlas.png",
		auto_cast atlas.w,
		auto_cast atlas.h,
		4,
		raw_data,
		4 * auto_cast atlas.w,
	)

	// setup image for GPU
	desc: sg.Image_Desc
	desc.width = auto_cast atlas.w
	desc.height = auto_cast atlas.h
	desc.pixel_format = .RGBA8
	desc.data.subimage[0][0] = {
		ptr  = raw_data,
		size = auto_cast (atlas.w * atlas.h * 4),
	}
	atlas.sg_image = sg.make_image(desc)
	if atlas.sg_image.id == sg.INVALID_ID {
		fmt.printfln("failed to make image")
	}
}


init :: proc "c" () {
	context = runtime.default_context()


	sg.setup(sg.Desc{
		environment = sglue.environment(), 
		logger = {func = slog.func}, 
	})

	imgui_ctx := imgui.CreateContext()

	io := imgui.GetIO()

	io.ConfigFlags += { .NavEnableKeyboard, .DockingEnable }

	backend := sg.query_backend()
	#partial switch backend {
		case .GLCORE:
			opengl.Init("#version 430")
		case :
			fmt.panicf("[IMGUI]: BACKEND NOT SUPPORTED\n")
	}

	io.DisplaySize = v2{f32(global.window_w), f32(global.window_h)}

	sfetch.setup(
		sfetch.Desc {
			max_requests = 64,
			num_channels = 1,
			num_lanes = 4,
			logger = {func = slog.func},
		},
	)


	init_images()
	init_fonts()
	game_init()


	state.bind.vertex_buffers[0] = sg.make_buffer(
		{usage = .DYNAMIC, size = size_of(Quad) * len(draw_frame.quads)},
	)


	index_buffer_count :: MAX_QUADS * 6
	indices: [index_buffer_count]u16
	i := 0
	for i < index_buffer_count {
		// vertex offset pattern to draw a quad
		// { 0, 1, 2,  0, 2, 3 }
		indices[i + 0] = auto_cast ((i / 6) * 4 + 0)
		indices[i + 1] = auto_cast ((i / 6) * 4 + 1)
		indices[i + 2] = auto_cast ((i / 6) * 4 + 2)
		indices[i + 3] = auto_cast ((i / 6) * 4 + 0)
		indices[i + 4] = auto_cast ((i / 6) * 4 + 2)
		indices[i + 5] = auto_cast ((i / 6) * 4 + 3)
		i += 6
	}

	state.bind.index_buffer = sg.make_buffer(
		{type = .INDEXBUFFER, data = {ptr = &indices, size = size_of(indices)}},
	)


	state.bind.samplers[SMP_default_sampler] = sg.make_sampler({})

	pipeline_desc := sg.Pipeline_Desc{
		shader = sg.make_shader(quad_shader_desc(sg.query_backend())),
		index_type = .UINT16,
		layout = {
			attrs = {
				ATTR_quad_position = {format = .FLOAT2},
				ATTR_quad_color0 = {format = .FLOAT4},
				ATTR_quad_uv0 = {format = .FLOAT2},
				ATTR_quad_bytes0 = {format = .UBYTE4N},
			},
		},
		depth = {
			compare = .LESS_EQUAL,
			write_enabled = true,
			pixel_format = .DEPTH_STENCIL,
		},

	}
	//pipeline_desc.depth.pixel_format = .RGBA16F
	blend_state := sg.Blend_State {
		enabled          = true,
		src_factor_rgb   = .SRC_ALPHA,
		dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
		op_rgb           = .ADD,
		src_factor_alpha = .ONE,
		dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
		op_alpha         = .ADD,
	}
	pipeline_desc.colors[0] = sg.Color_Target_State{
		pixel_format = .RGBA8,
		blend = blend_state,
	}

	state.pip = sg.make_pipeline(pipeline_desc)


	state.pass_action = sg.Pass_Action{
		colors = {0 = {load_action = .CLEAR, clear_value = vec_to_col(hex_to_rgba(bg_color))}},
	}

	state.bind.images[IMG_tex0] = atlas.sg_image
	state.bind.images[IMG_tex1] = images[font.img_id].sg_img 


}

elapsed_t: f64 = 0
last_time: time.Time = time.now()

radius: f32 = 150


reset_render :: proc() {
	draw_frame.quad_count = 0
}

delta_t :: sapp.frame_duration

frame :: proc "c" () {
	context = runtime.default_context()


	// Delta time stuff
	elapsed_t += delta_t()
	last_time = time.now()

	opengl.NewFrame()
	imgui.NewFrame()

	game_render()

	//imgui.ShowDemoWindow(&show)


	sg.update_buffer(
		state.bind.vertex_buffers[0],
		{ptr = &draw_frame.quads[0], size = size_of(Quad) * len(draw_frame.quads)},
	)
	
	sg.begin_pass({action = state.pass_action, swapchain = sglue.swapchain()})


	sg.apply_pipeline(state.pip)
	sg.apply_bindings(state.bind)
	sg.draw(0, 6 * draw_frame.quad_count, 1)

	imgui.Render()
	opengl.RenderDrawData(imgui.GetDrawData())

	sg.end_pass()
	sg.commit()


	reset_render()
	reset_events()

}

cleanup :: proc "c" () {
	context = runtime.default_context()
	sfetch.shutdown()
	sg.shutdown()
	opengl.Shutdown()
	imgui.DestroyContext(imgui.GetCurrentContext())
}

InputStateFlags :: enum {
	down,
	just_pressed,
	just_released,
	repeat,
}

InputState :: struct {
	keys:         [sapp.MAX_KEYCODES]bit_set[InputStateFlags],
	mouse:        Vector2,
	scroll:       Vector2,
	mouse_button: sapp.Mousebutton,
}

map_sokol_mouse_button :: proc "c" (sokol_mouse_button: sapp.Mousebutton) -> sapp.Keycode {
	#partial switch sokol_mouse_button {
	case .LEFT:
		return sapp.Keycode.LEFT
	case .RIGHT:
		return sapp.Keycode.RIGHT
	case .MIDDLE:
		return sapp.Keycode.UP
	}
	return nil
}

sokol_update_modifier :: proc (io: ^imgui.IO, mod: u32) {
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Ctrl, (mod & sapp.MODIFIER_CTRL) != 0)
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Shift, (mod & sapp.MODIFIER_SHIFT) != 0)
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Alt, (mod & sapp.MODIFIER_ALT) != 0)
	imgui.IO_AddKeyEvent(io, .ImGuiMod_Super, (mod & sapp.MODIFIER_SUPER) != 0)
}

sokol_add_mouse_pos_event :: proc (io: ^imgui.IO, x: f32, y: f32)  {
	imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)
	imgui.IO_AddMousePosEvent(io, x, y)
}


sokol_to_imgui :: proc "c" (ev: ^sapp.Event) -> bool {
	context = runtime.default_context()
	io := imgui.GetIO()
	dpi_scale := imgui.GetWindowDpiScale()

	#partial switch ev.type {
		case .FOCUSED:
			imgui.IO_AddFocusEvent(io, true)
		case .UNFOCUSED:
			imgui.IO_AddFocusEvent(io, false)	
        case .MOUSE_DOWN:
			x := ev.mouse_x / dpi_scale	
			y := ev.mouse_y / dpi_scale	
			imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)
			imgui.IO_AddMouseButtonEvent(io, cast(i32) ev.mouse_button, true)
			imgui.IO_AddMousePosEvent(io, x, y)

			sokol_update_modifier(io, ev.modifiers)

        case .MOUSE_UP:
			x := ev.mouse_x / dpi_scale	
			y := ev.mouse_y / dpi_scale	
			imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)

			imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)
			imgui.IO_AddMouseButtonEvent(io, cast(i32) ev.mouse_button, false)
			sokol_update_modifier(io, ev.modifiers)

        case .MOUSE_MOVE:
			x := ev.mouse_x / dpi_scale
			y := ev.mouse_y / dpi_scale
			imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)
			imgui.IO_AddMousePosEvent(io, x, y)
			global.is_imgui_hovered = io.WantCaptureMouse
        case .MOUSE_SCROLL:
			x := ev.scroll_x
			y := ev.scroll_y
			imgui.IO_AddMouseSourceEvent(io, imgui.MouseSource.Mouse)	
			imgui.IO_AddMouseWheelEvent(io, x, y)
            break;
		case .RESIZED:
			global.window_h = ev.window_height
			global.window_w = ev.window_width
			io.DisplaySize = v2{f32(ev.window_width), f32(ev.window_height)}
			/**
        case SAPP_EVENTTYPE_KEY_DOWN:
            _simgui_update_modifiers(io, ev->modifiers);
            // intercept Ctrl-V, this is handled via EVENTTYPE_CLIPBOARD_PASTED
            if (!_simgui.desc.disable_paste_override) {
                if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_V)) {
                    break;
                }
            }
            // on web platform, don't forward Ctrl-X, Ctrl-V to the browser
            if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_X)) {
                sapp_consume_event();
            }
            if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_C)) {
                sapp_consume_event();
            }
            // it's ok to add ImGuiKey_None key events
            _simgui_add_sapp_key_event(io, ev->key_code, true);
            break;
        case SAPP_EVENTTYPE_KEY_UP:
            _simgui_update_modifiers(io, ev->modifiers);
            // intercept Ctrl-V, this is handled via EVENTTYPE_CLIPBOARD_PASTED
            if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_V)) {
                break;
            }
            // on web platform, don't forward Ctrl-X, Ctrl-V to the browser
            if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_X)) {
                sapp_consume_event();
            }
            if (_simgui_is_ctrl(ev->modifiers) && (ev->key_code == SAPP_KEYCODE_C)) {
                sapp_consume_event();
            }
            // it's ok to add ImGuiKey_None key events
            _simgui_add_sapp_key_event(io, ev->key_code, false);
            break;
        case SAPP_EVENTTYPE_CHAR:
            /* on some platforms, special keys may be reported as
               characters, which may confuse some ImGui widgets,
               drop those, also don't forward characters if some
               modifiers have been pressed
            */
            _simgui_update_modifiers(io, ev->modifiers);
            if ((ev->char_code >= 32) &&
                (ev->char_code != 127) &&
                (0 == (ev->modifiers & (SAPP_MODIFIER_ALT|SAPP_MODIFIER_CTRL|SAPP_MODIFIER_SUPER))))
            {
                simgui_add_input_character(ev->char_code);
            }
            break;
        case SAPP_EVENTTYPE_CLIPBOARD_PASTED:
            // simulate a Ctrl-V key down/up
            if (!_simgui.desc.disable_paste_override) {
                _simgui_add_imgui_key_event(io, _simgui_copypaste_modifier(), true);
                _simgui_add_imgui_key_event(io, ImGuiKey_V, true);
                _simgui_add_imgui_key_event(io, ImGuiKey_V, false);
                _simgui_add_imgui_key_event(io, _simgui_copypaste_modifier(), false);
            }
            break;

		**/

	}

	return io.WantCaptureMouse 

}

handle_events :: proc "c" (event: ^sapp.Event) {
	inp_state := &global.input_state

	//simgui.handle_event(event^)
	sokol_to_imgui(event)

	#partial switch event.type {
	case .MOUSE_MOVE:
		mouse := v2{event.mouse_x, event.mouse_y}

		x := mouse.x / f32(global.window_w)
		y := mouse.y / f32(global.window_h) - 1.0
		y *= -1

		global.input_state.mouse = v2{x * f32(global.window_w), y * f32(global.window_h)}
	case .MOUSE_SCROLL:
		inp_state.scroll = v2{event.scroll_x, event.scroll_y}
	case .KEY_DOWN:
		if !event.key_repeat && !(.down in inp_state.keys[event.key_code]) {
			inp_state.keys[event.key_code] += {.down, .just_pressed}
		}
		if event.key_repeat {
			inp_state.keys[event.key_code] += {.repeat}
		}

	case .KEY_UP:
		if .down in inp_state.keys[event.key_code] {
			inp_state.keys[event.key_code] -= {.down}
			inp_state.keys[event.key_code] += {.just_released}
		}
	case .MOUSE_UP:
		if .down in inp_state.keys[map_sokol_mouse_button(event.mouse_button)] {
			inp_state.keys[map_sokol_mouse_button(event.mouse_button)] -= {.down}
			inp_state.keys[map_sokol_mouse_button(event.mouse_button)] += {.just_released}
		}
	case .MOUSE_DOWN:
		if !(.down in inp_state.keys[map_sokol_mouse_button(event.mouse_button)]) {
			inp_state.keys[map_sokol_mouse_button(event.mouse_button)] += {.down, .just_pressed}
		}
	}
}


key_just_pressed :: proc(code: sapp.Keycode) -> bool {
	return .just_pressed in global.input_state.keys[code]
}

key_down :: proc(code: sapp.Keycode) -> bool {
	return .down in global.input_state.keys[code]
}

reset_events :: proc() {
	global.input_state.scroll = v2{0, 0}
	for &set in &global.input_state.keys {
		set -= {.just_pressed, .just_released, .repeat}
	}
}

main :: proc() {

	events = GameEvents {
		e = {},
		n = 0,
	}

	sapp.run(
		{
			init_cb = init,
			frame_cb = frame,
			event_cb = handle_events,
			cleanup_cb = cleanup,
			width = global.window_w,
			height = global.window_h,
			window_title = global.title,
			icon = {sokol_default = true},
			logger = {func = slog.func},
		},
	)
}
