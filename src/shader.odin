package game

import rl "vendor:raylib"
import "core:strings"

ShaderParams :: struct {
	ca_strength:    f32,
	glow_radius:    f32,
	glow_strength:  f32,
	noise_strength: f32,
}

shader_target: rl.RenderTexture2D
shader:        rl.Shader
shader_params := ShaderParams{
	ca_strength    = 0.0012,
	glow_radius    = 3.8,
	glow_strength  = 0.4,
	noise_strength = 0.65,
}
shader_debug_open: bool

shader_loc_resolution:    i32
shader_loc_time:          i32
shader_loc_ca_strength:   i32
shader_loc_glow_radius:   i32
shader_loc_glow_strength: i32
shader_loc_noise_strength: i32

when ODIN_OS == .JS {
	_SHADER_SRC :: #load("../assets/shader_es.glsl", string)
} else {
	_SHADER_SRC :: #load("../assets/shader.glsl", string)
}

init_shader :: proc() {
	shader_target = rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())
	src := strings.clone_to_cstring(_SHADER_SRC, context.allocator)
	defer delete(src)
	shader = rl.LoadShaderFromMemory(nil, src)
	shader_loc_resolution     = rl.GetShaderLocation(shader, "resolution")
	shader_loc_time           = rl.GetShaderLocation(shader, "time")
	shader_loc_ca_strength    = rl.GetShaderLocation(shader, "ca_strength")
	shader_loc_glow_radius    = rl.GetShaderLocation(shader, "glow_radius")
	shader_loc_glow_strength  = rl.GetShaderLocation(shader, "glow_strength")
	shader_loc_noise_strength = rl.GetShaderLocation(shader, "noise_strength")
}

resize_shader :: proc() {
	rl.UnloadRenderTexture(shader_target)
	shader_target = rl.LoadRenderTexture(rl.GetScreenWidth(), rl.GetScreenHeight())
}

draw_shader :: proc() {
	src := rl.Rectangle{0, 0, f32(shader_target.texture.width), -f32(shader_target.texture.height)}
	dst := rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
	if rl.IsShaderValid(shader) {
		resolution := [2]f32{f32(shader_target.texture.width), f32(shader_target.texture.height)}
		t := f32(rl.GetTime())
		rl.SetShaderValue(shader, shader_loc_resolution,     &resolution,                   .VEC2)
		rl.SetShaderValue(shader, shader_loc_time,           &t,                            .FLOAT)
		rl.SetShaderValue(shader, shader_loc_ca_strength,    &shader_params.ca_strength,    .FLOAT)
		rl.SetShaderValue(shader, shader_loc_glow_radius,    &shader_params.glow_radius,    .FLOAT)
		rl.SetShaderValue(shader, shader_loc_glow_strength,  &shader_params.glow_strength,  .FLOAT)
		rl.SetShaderValue(shader, shader_loc_noise_strength, &shader_params.noise_strength, .FLOAT)
		rl.BeginShaderMode(shader)
		rl.DrawTexturePro(shader_target.texture, src, dst, {0, 0}, 0, rl.WHITE)
		rl.EndShaderMode()
	} else {
		rl.DrawTexturePro(shader_target.texture, src, dst, {0, 0}, 0, rl.WHITE)
	}
}

draw_shader_debug :: proc() {
	if rl.IsKeyPressed(.F3) do shader_debug_open = !shader_debug_open
	if !shader_debug_open do return

	PAD :: f32(8)
	ROW :: f32(26)
	W   :: f32(320)
	N   :: 4

	panel_h := f32(N) * (ROW + PAD) + PAD
	rl.DrawRectangle(10, 10, i32(W), i32(panel_h), {0, 0, 0, 200})

	x  := f32(10) + PAD
	sw := W - PAD * 2
	y  := f32(10) + PAD

	rl.GuiSliderBar({x, y, sw, ROW}, "CA",         rl.TextFormat("%.4f", shader_params.ca_strength),    &shader_params.ca_strength,    0,   0.02)
	y += ROW + PAD
	rl.GuiSliderBar({x, y, sw, ROW}, "Glow R",     rl.TextFormat("%.1f",  shader_params.glow_radius),   &shader_params.glow_radius,    0.0, 8)
	y += ROW + PAD
	rl.GuiSliderBar({x, y, sw, ROW}, "Glow",       rl.TextFormat("%.2f",  shader_params.glow_strength), &shader_params.glow_strength,  0,   2)
	y += ROW + PAD
	rl.GuiSliderBar({x, y, sw, ROW}, "Noise",      rl.TextFormat("%.3f",  shader_params.noise_strength),&shader_params.noise_strength, 0,  1.0)
}

shutdown_shader :: proc() {
	rl.UnloadRenderTexture(shader_target)
	rl.UnloadShader(shader)
}
