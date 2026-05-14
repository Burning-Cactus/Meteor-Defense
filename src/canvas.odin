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
		if center_sqrdist < perimeter_sqrdist do return center_sqrdist, .BOTH
		return perimeter_sqrdist, .END
	}
	return 0, .START
}

nearest_shape :: proc(shapes:[dynamic]Drawshape, point:Vec2, threshold:f32) -> (idx:int, handle:HandleMode) {
	idx = -1
	best := threshold * threshold
	for i in 0..<len(shapes) {
		dist, h := shape_handle_sqrdist(shapes[i], point, threshold)
		if dist < best {
			best = dist
			idx = i
			handle = h
		}
	}
	return
}

highlighted_shape_idx := -1
highlighted_handle: HandleMode
drag_offset: Vec2

handle_highlighted_shape :: proc(shapes:^[dynamic]Drawshape, idx:int) {
	shape := shapes^[idx]

	if shape.type == .CIRCLE {
		switch highlighted_handle {
		case .START:
			draw_dot(shape.start, .DEBUG, state.scale_hint * 0.3)
		case .END:
			draw_shape(shape, .DEBUG, state.scale_hint)
		case .BOTH:
			draw_dot(shape.start, .DEBUG, state.scale_hint * 0.3)
			draw_dot(shape.end, .DEBUG, state.scale_hint * 0.3)
		}
	} else {
		switch highlighted_handle {
		case .START:
			draw_dot(shape.start, .DEBUG, state.scale_hint * 0.3)
		case .END:
			draw_dot(shape.end, .DEBUG, state.scale_hint * 0.3)
		case .BOTH:
			draw_shape(shape, .DEBUG, state.scale_hint)
		}
	}

	if rl.IsKeyPressed(.D) {
		unordered_remove(shapes, idx)
	}
}

draw_drag:  Drag = {button = rl.MouseButton.LEFT}
shape_drag: Drag = {button = rl.MouseButton.RIGHT}
draw_mode:  Drawshape_Type
curr_shape: Drawshape
drawshapes: [dynamic]Drawshape

canvas_loop :: proc(delta:f32) {
	select_threshold := 20.0 / state.scale_hint

	if drag_started(&shape_drag) && highlighted_shape_idx != -1 {
		s := drawshapes[highlighted_shape_idx]
		switch highlighted_handle {
		case .START, .BOTH:
			drag_offset = s.start - state.cursor
		case .END:
			drag_offset = s.end - state.cursor
		}
	}

	if shape_drag.active && highlighted_shape_idx != -1 {
		s := &drawshapes[highlighted_shape_idx]
		switch highlighted_handle {
		case .START:
			s.start = state.cursor + drag_offset
		case .END:
			s.end = state.cursor + drag_offset
		case .BOTH:
			new_start := state.cursor + drag_offset
			s.end    += new_start - s.start
			s.start   = new_start
		}
	}

	drag_ended(&shape_drag)

	if !shape_drag.active {
		highlighted_shape_idx, highlighted_handle = nearest_shape(drawshapes, state.cursor, select_threshold)
	}

	for shape in drawshapes {
		draw_shape(shape, .PRIMARY, state.scale_hint)
	}
	if highlighted_shape_idx != -1 do handle_highlighted_shape(&drawshapes, highlighted_shape_idx)

	if rl.IsKeyPressed(.ONE) do draw_mode = .DOT
	if rl.IsKeyPressed(.TWO) do draw_mode = .LINE
	if rl.IsKeyPressed(.THREE) do draw_mode = .CIRCLE

	if drag_started(&draw_drag) {
		draw_drag.start = state.cursor
		curr_shape = {draw_mode, draw_drag.start, draw_drag.start}
	}
	if draw_drag.active {
		curr_shape.end = state.cursor
		draw_shape(curr_shape, .PRIMARY, state.scale_hint)
	}
	if drag_ended(&draw_drag) {
		append(&drawshapes, curr_shape)
	}
}
