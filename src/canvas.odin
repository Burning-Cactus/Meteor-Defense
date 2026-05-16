package game

import "core:math"
import rl "vendor:raylib"

HandleMode :: enum {START, END, BOTH}

ShapeRef :: struct {
	group: ^DrawshapeGroup,
	idx:   int,
}

shape_handle_sqrdist :: proc(d: Drawable, point: Vec2, threshold: f32) -> (f32, HandleMode) {
	thr_sqr := threshold * threshold
	switch v in d {
	case Drawshape:
		switch v.type {
		case .DOT:
			return dist_squared(point, v.end), .END
		case .LINE:
			start_sqrdist := dist_squared(point, v.start)
			end_sqrdist   := dist_squared(point, v.end)
			if start_sqrdist < thr_sqr || end_sqrdist < thr_sqr {
				if start_sqrdist < end_sqrdist do return start_sqrdist, .START
				return end_sqrdist, .END
			}
			return dist_squared(point, closest_point_on_segment(point, v.start, v.end)), .BOTH
		case .CIRCLE:
			center_sqrdist    := dist_squared(point, v.start)
			radius            := math.sqrt(dist_squared(v.start, v.end))
			perimeter_sqrdist := sqr(math.sqrt(center_sqrdist) - radius)
			if center_sqrdist < perimeter_sqrdist do return center_sqrdist, .BOTH
			return perimeter_sqrdist, .END
		}
	case DrawshapePro:
		return shape_handle_sqrdist(v.drawshape, point, threshold)
	case ^DrawshapeGroup:
		best := thr_sqr + 1
		best_handle := HandleMode.BOTH
		for item in v.contents {
			dist, h := shape_handle_sqrdist(item^, point, threshold)
			if dist < best {
				best = dist
				best_handle = h
			}
		}
		return best, best_handle
	}
	return 0, .START
}

nearest_shape_in_group :: proc(
	group:     ^DrawshapeGroup,
	point:     Vec2,
	threshold: f32,
	best:      ^f32,
) -> (ref: ShapeRef, handle: HandleMode, found: bool) {
	for i in 0..<len(group.contents) {
		item := group.contents[i]
		if g, ok := item^.(^DrawshapeGroup); ok {
			sub_ref, sub_handle, sub_found := nearest_shape_in_group(g, point, threshold, best)
			if sub_found {
				ref    = sub_ref
				handle = sub_handle
				found  = true
			}
		} else {
			dist, h := shape_handle_sqrdist(item^, point, threshold)
			if dist < best^ {
				best^  = dist
				ref    = {group, i}
				handle = h
				found  = true
			}
		}
	}
	return
}

nearest_shape :: proc(group: ^DrawshapeGroup, point: Vec2, threshold: f32) -> (ref: ShapeRef, handle: HandleMode, found: bool) {
	best := threshold * threshold
	return nearest_shape_in_group(group, point, threshold, &best)
}

highlighted_ref:    ShapeRef
highlighted_found:  bool
highlighted_handle: HandleMode
drag_offset: Vec2

drawable_base_shape :: proc(d: Drawable) -> (s: Drawshape, ok: bool) {
	switch v in d {
	case Drawshape:       return v, true
	case DrawshapePro:    return v.drawshape, true
	case ^DrawshapeGroup: return {}, false
	}
	return {}, false
}

handle_highlighted_shape :: proc(ref: ShapeRef, handle: HandleMode) {
	d := ref.group.contents[ref.idx]^
	dot_scale := state.scale_hint * .5

	if base, ok := drawable_base_shape(d); ok {
		if base.type == .CIRCLE {
			switch handle {
			case .START:
				draw_dot(base.start, dot_scale, .DEBUG, 2.0)
			case .END:
				draw_shape(d, state.scale_hint, .DEBUG, 5.0)
			case .BOTH:
				draw_dot(base.start, dot_scale, .DEBUG, 2.0)
				draw_dot(base.end,   dot_scale, .DEBUG, 2.0)
			}
		} else {
			switch handle {
			case .START:
				draw_dot(base.start, dot_scale, .DEBUG, 2.0)
			case .END:
				draw_dot(base.end, dot_scale, .DEBUG, 2.0)
			case .BOTH:
				draw_shape(d, state.scale_hint, .DEBUG, 2.0)
			}
		}
	} else {
		draw_shape(d, state.scale_hint, .DEBUG, 2.0)
	}

	if rl.IsKeyPressed(.D) {
		free(ref.group.contents[ref.idx])
		unordered_remove(&ref.group.contents, ref.idx)
		clear(&selected_shapes)
		highlighted_found = false
	}
}

move_drawable :: proc(d: ^Drawable, delta: Vec2, move_whole: bool, handle: HandleMode) {
	switch _ in d^ {
	case Drawshape:
		s := d^.(Drawshape)
		if move_whole || handle == .START do s.start += delta
		if move_whole || handle == .END   do s.end   += delta
		d^ = s
	case DrawshapePro:
		p := d^.(DrawshapePro)
		if move_whole || handle == .START do p.start += delta
		if move_whole || handle == .END   do p.end   += delta
		d^ = p
	case ^DrawshapeGroup:
		g := d^.(^DrawshapeGroup)
		for item in g.contents {
			move_drawable(item, delta, true, .BOTH)
		}
	}
}

draw_drag:  Drag = {button = rl.MouseButton.LEFT}
shape_drag: Drag = {button = rl.MouseButton.RIGHT}
draw_mode:  Drawshape_Type
curr_shape: Drawshape
root:            DrawshapeGroup = {name = "root"}
selected_shapes: [dynamic]ShapeRef


canvas_loop :: proc(delta: f32) {
	select_threshold := 20.0 / state.scale_hint

	if drag_started(&shape_drag) {
		if len(selected_shapes) == 0 && highlighted_found {
			append(&selected_shapes, highlighted_ref)
		}
		shape_drag.start = state.cursor
		shape_drag.end   = state.cursor
	}

	if shape_drag.active {
		cursor_delta := state.cursor - shape_drag.end
		shape_drag.end = state.cursor
		for ref in selected_shapes {
			move_whole := len(selected_shapes) > 1 || highlighted_handle == .BOTH
			move_drawable(ref.group.contents[ref.idx], cursor_delta, move_whole, highlighted_handle)
		}
	}

	if drag_ended(&shape_drag) {
		clear(&selected_shapes)
	}

	if !shape_drag.active {
		highlighted_ref, highlighted_handle, highlighted_found = nearest_shape(&root, state.cursor, select_threshold)
	}

	draw_shape_group(root, state.scale_hint)
	if highlighted_found do handle_highlighted_shape(highlighted_ref, highlighted_handle)

	/*
	if drag_started(&draw_drag) && selected_tool.use != nil {
		selected_tool.use()
		draw_drag.start = state.cursor
		curr_shape = {draw_mode, draw_drag.start, draw_drag.start}
	}
	if draw_drag.active {
		curr_shape.end = state.cursor
		draw_shape(curr_shape, state.scale_hint)
	}
	if drag_ended(&draw_drag) {
		ptr := new(Drawable)
		ptr^ = curr_shape
		append(&root.contents, ptr)
	}
	*/
}
