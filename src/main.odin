package main

import "base:runtime"
import "core:fmt"

import "core:math/linalg"

import slog "../sokol-odin/sokol/log"
import sg "../sokol-odin/sokol/gfx"
import sapp "../sokol-odin/sokol/app"
import sglue "../sokol-odin/sokol/glue"

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

pass_action: sg.Pass_Action;

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

init :: proc "c" () {
	context = runtime.default_context()
	sg.setup({
		environment = sglue.environment(),
		logger = { func = slog.func },
	})
	pass_action.colors[0] = { load_action = .CLEAR, clear_value = hex_to_rgba(0x443355FF) }

	switch sg.query_backend() {
		case .D3D11: fmt.println(">> using D3D11 backend")
        case .GLCORE, .GLES3: fmt.println(">> using GL backend")
        case .METAL_MACOS, .METAL_IOS, .METAL_SIMULATOR: fmt.println(">> using Metal backend")
        case .WGPU: fmt.println(">> using WebGPU backend")
        case .DUMMY: fmt.println(">> using dummy backend")
	}


}

frame :: proc "c" () {
	context = runtime.default_context()
	sg.begin_pass({ action = pass_action, swapchain = sglue.swapchain() })
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