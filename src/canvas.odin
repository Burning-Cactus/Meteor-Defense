package game

import "core:math"
import rl "vendor:raylib"

HandleMode :: enum {START, END, BOTH}

shape_handle_sqrdist ::proc(s:Drawshape, point:Vec2, threshold:f32) -> (f32, HandleMode) {
	thr_sqr := threshold * threshold
	switch s.type {
	case .DOT:
		d := point - s.end
		return d.x*d.x + d.y*d.y, .END
	case .LINE:
		start_dist, _ := shape_handle_sqrdist({.DOT, s.start, s.start}, point, threshold)
		end_dist, _ := shape_handle_sqrdist({.DOT, s.end, s.end}, point, threshold)
		if start_dist < thr_sqr || end_dist < thr_sqr {
			if start_dist < end_dist do return start_dist, .START
			return end_dist, .END
		}
		ab := s.end - s.start
		ap := point - s.start
		denom := ab.x*ab.x + ab.y*ab.y
		t := (ap.x*ab.x + ap.y*ab.y) / denom if denom != 0 else 0
		closest := s.start + clamp(t, 0, 1) * ab
		d := point - closest
		return d.x*d.x + d.y*d.y, .BOTH
	case .CIRCLE:
		d := point - s.start
		dist_to_center := math.sqrt(d.x*d.x + d.y*d.y)
		r := s.end - s.start
		radius := math.sqrt(r.x*r.x + r.y*r.y)
		diff := dist_to_center - radius
		center_sqrdist := dist_to_center * dist_to_center
		perimeter_sqrdist := diff * diff
		if center_sqrdist < perimeter_sqrdist do return center_sqrdist, .START
		return perimeter_sqrdist, .BOTH
	}
	return 0, .START
}

highlighted_shape : ^Drawshape
highlighted_handle: HandleMode
handle_highlighted_shape :: proc(shapes:^[dynamic]Drawshape, idx:int) {
	shape := shapes^[idx]

	switch highlighted_handle {
	case .START:
		draw_dot(shape.start, .DEBUG, state.scale_hint * 0.3)
	case .END:
		draw_dot(shape.end, .DEBUG, state.scale_hint * 0.3)
	case .BOTH:
		draw_shape(shape, .DEBUG, state.scale_hint)
	}


	if rl.IsKeyPressed(.D) {
		unordered_remove(shapes, idx)
	}
}

drag_start:Vec2
drawing:bool
draw_mode : Drawshape_Type
curr_shape : Drawshape
drawshapes : [dynamic]Drawshape
canvas_loop :: proc(delta:f32) {
	select_threshold := 6.0 / state.scale_hint
	closest_distance_squared := select_threshold * select_threshold
	highlighted_shape_idx := -1
	for i in 0..<len(drawshapes) {
		shape := drawshapes[i]
		dist, handle := shape_handle_sqrdist(shape, state.cursor, select_threshold)
		if dist < closest_distance_squared{
			highlighted_shape_idx = i
			highlighted_handle = handle
		}
		draw_shape(shape, .PRIMARY, state.scale_hint)
	}

	if highlighted_shape_idx != -1 do handle_highlighted_shape( &drawshapes, highlighted_shape_idx)



	if rl.IsKeyPressed(.ONE) do draw_mode = .DOT
	if rl.IsKeyPressed(.TWO) do draw_mode = .LINE
	if rl.IsKeyPressed(.THREE) do draw_mode = .CIRCLE


	if rl.IsMouseButtonPressed(.LEFT) {
		drag_start = state.cursor
		curr_shape = {draw_mode, drag_start, drag_start}
		drawing = true
	}
	if drawing {
		curr_shape.end = state.cursor
		draw_shape(curr_shape, .PRIMARY, state.scale_hint)
	}
	if rl.IsMouseButtonReleased(.LEFT) {
		append(&drawshapes, (curr_shape))
		drawing = false
	}

}
