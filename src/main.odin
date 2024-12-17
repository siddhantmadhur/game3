package main

import "base:runtime"
import "core:fmt"
import slog "../sokol-odin/sokol/log"
import sg "../sokol-odin/sokol/gfx"
import sapp "../sokol-odin/sokol/app"
import sglue "../sokol-odin/sokol/glue"

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
		width = 400,
		height = 300,
		window_title = "Houses&Houses",
		icon = { sokol_default = true },
		logger = { func = slog.func },
	})
}