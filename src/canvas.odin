package game

import "core:fmt"
import "core:math"
import "utils"
import rl "vendor:raylib"

HandleMode :: enum {
	START,
	END,
	BOTH,
}

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
			end_sqrdist := dist_squared(point, v.end)
			if start_sqrdist < thr_sqr || end_sqrdist < thr_sqr {
				if start_sqrdist < end_sqrdist do return start_sqrdist, .START
				return end_sqrdist, .END
			}
			return dist_squared(point, closest_point_on_segment(point, v.start, v.end)), .BOTH
		case .CIRCLE:
			center_sqrdist := dist_squared(point, v.start)
			radius := math.sqrt(dist_squared(v.start, v.end))
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
	group: ^DrawshapeGroup,
	point: Vec2,
	threshold: f32,
	best: ^f32,
) -> (
	ref: ShapeRef,
	handle: HandleMode,
	found: bool,
) {
	for i in 0 ..< len(group.contents) {
		item := group.contents[i]
		if g, ok := item^.(^DrawshapeGroup); ok {
			sub_ref, sub_handle, sub_found := nearest_shape_in_group(g, point, threshold, best)
			if sub_found {
				ref = sub_ref
				handle = sub_handle
				found = true
			}
		} else {
			dist, h := shape_handle_sqrdist(item^, point, threshold)
			if dist < best^ {
				best^ = dist
				ref = {group, i}
				handle = h
				found = true
			}
		}
	}
	return
}

nearest_shape :: proc(
	group: ^DrawshapeGroup,
	point: Vec2,
	threshold: f32,
) -> (
	ref: ShapeRef,
	handle: HandleMode,
	found: bool,
) {
	best := threshold * threshold
	return nearest_shape_in_group(group, point, threshold, &best)
}

highlighted_ref: ShapeRef
highlighted_found: bool
highlighted_handle: HandleMode
drag_offset: Vec2

drawable_base_shape :: proc(d: Drawable) -> (s: Drawshape, ok: bool) {
	switch v in d {
	case Drawshape:
		return v, true
	case DrawshapePro:
		return v.drawshape, true
	case ^DrawshapeGroup:
		return {}, false
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
				draw_dot(base.end, dot_scale, .DEBUG, 2.0)
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
		if move_whole || handle == .END do s.end += delta
		d^ = s
	case DrawshapePro:
		p := d^.(DrawshapePro)
		if move_whole || handle == .START do p.start += delta
		if move_whole || handle == .END do p.end += delta
		d^ = p
	case ^DrawshapeGroup:
		g := d^.(^DrawshapeGroup)
		for item in g.contents {
			move_drawable(item, delta, true, .BOTH)
		}
	}
}

draw_drag: Drag = {
	button = rl.MouseButton.LEFT,
}
shape_drag: Drag = {
	button = rl.MouseButton.RIGHT,
}
root: DrawshapeGroup = {
	name = "root",
}
selected_shapes: [dynamic]ShapeRef

BONE_NAMES := [10]string {
	"torso",
	"head",
	"upper_arm_r",
	"lower_arm_r",
	"upper_arm_l",
	"lower_arm_l",
	"upper_leg_r",
	"lower_leg_r",
	"upper_leg_l",
	"lower_leg_l",
}

bone_groups:          [10]^DrawshapeGroup
active_bone_group:    ^DrawshapeGroup
canvas_skeleton:      Skeleton
canvas_ref_skeleton:  Skeleton
canvas_initialized:   bool
selected_color:     ThemeColor = .PRIMARY
pose_drag:          Drag = {button = rl.MouseButton.LEFT}
pose_drag_bone_idx: int

NUM_THEME_COLORS :: int(max(ThemeColor)) + 1

skeleton_bones :: proc(sk: Skeleton) -> [10]Bone {
	return {
		sk.torso,
		sk.head,
		sk.upper_arm_r,
		sk.lower_arm_r,
		sk.upper_arm_l,
		sk.lower_arm_l,
		sk.upper_leg_r,
		sk.lower_leg_r,
		sk.upper_leg_l,
		sk.lower_leg_l,
	}
}

nearest_bone_idx :: proc(pos: Vec2) -> int {
	bones     := skeleton_bones(canvas_skeleton)
	best_dist: f32 = math.F32_MAX
	best_idx  := 0
	for b, i in bones {
		closest := closest_point_on_segment(pos, b.root, b.tip)
		d := dist_squared(pos, closest)
		if d < best_dist {
			best_dist = d
			best_idx  = i
		}
	}
	return best_idx
}

nearest_bone_group :: proc(pos: Vec2) -> ^DrawshapeGroup {
	return bone_groups[nearest_bone_idx(pos)]
}

pose_angle_ptrs :: proc(pose: ^Pose) -> [10]^f32 {
	return {
		&pose.torso,
		&pose.head,
		&pose.upper_arm_r, &pose.lower_arm_r,
		&pose.upper_arm_l, &pose.lower_arm_l,
		&pose.upper_leg_r, &pose.lower_leg_r,
		&pose.upper_leg_l, &pose.lower_leg_l,
	}
}

draw_group_on_bone :: proc(group: ^DrawshapeGroup, ref_bone: Bone, curr_bone: Bone, scale_hint: f32) {
	for item in group.contents {
		switch v in item^ {
		case Drawshape:
			ws := v
			ws.start = bone_to_world(curr_bone, world_to_bone(ref_bone, v.start))
			ws.end   = bone_to_world(curr_bone, world_to_bone(ref_bone, v.end))
			draw_shape(ws, scale_hint)
		case DrawshapePro:
			ws := v
			ws.start = bone_to_world(curr_bone, world_to_bone(ref_bone, v.start))
			ws.end   = bone_to_world(curr_bone, world_to_bone(ref_bone, v.end))
			draw_shape_pro(ws, scale_hint)
		case ^DrawshapeGroup:
			draw_group_on_bone(v, ref_bone, curr_bone, scale_hint)
		}
	}
}

init_canvas :: proc() {
	canvas_ref_skeleton = build_skeleton({0, 0}, jelly_proportions, jelly_idle_pose)
	canvas_skeleton     = canvas_ref_skeleton
	for i in 0 ..< 10 {
		g := new(DrawshapeGroup)
		g.name = BONE_NAMES[i]
		g.contents = make([dynamic]^Drawable)
		bone_groups[i] = g
		ptr := new(Drawable)
		ptr^ = Drawable(g)
		append(&root.contents, ptr)
	}

	data, success := utils.read_entire_file("assets/shapes.json", context.allocator)
	if !success do return
	defer delete(data)

	loaded_d, decoded := drawable_decode(data)
	if !decoded do return
	loaded_root, is_group := loaded_d.(^DrawshapeGroup)
	if !is_group do return

	for item in loaded_root.contents {
		sub, sub_ok := item^.(^DrawshapeGroup)
		if !sub_ok do continue
		for name, i in BONE_NAMES {
			if sub.name == name {
				bone_groups[i].contents = sub.contents
				break
			}
		}
	}
}

CanvasTool :: struct {
	name:         cstring,
	drag_handler: proc(d: Drag) -> Drawable,
}
shape_tool_drag_handler :: proc(d: Drag, shape: Drawshape_Type) -> Drawable {
	out := DrawshapePro {
		drawshape  = {shape, d.start, d.end},
		col        = selected_color,
		brightness = 1.0,
	}
	draw_shape(out, state.scale_hint)
	return out
}
POSE_TOOL_IDX :: 3

canvas_tools: []CanvasTool = {
	{"Dot",    proc(d: Drag) -> Drawable { return shape_tool_drag_handler(d, .DOT)    }},
	{"Line",   proc(d: Drag) -> Drawable { return shape_tool_drag_handler(d, .LINE)   }},
	{"Circle", proc(d: Drag) -> Drawable { return shape_tool_drag_handler(d, .CIRCLE) }},
	{"Pose",   nil},
}


draw_canvas_tool :: proc(
	start: Vec2,
	end: Vec2,
	idx: int,
	cursor: Vec2,
	scale_hint: f32 = 1.0,
) -> bool {
	brightness: f32 = .5
	if is_box_hovered(start, end, cursor) {
		brightness = 1.0
	}
	if selected_tool_idx == idx {
		brightness = 2.0
	}

	_, size := box_geo(start, end)

	draw_box(start, end, scale_hint, .PRIMARY, brightness)

	x, y := vec_ints(start + size / 10)
	rl.DrawText(rl.TextFormat("%i", idx + 1), x, y, 10, modulate(.PRIMARY))
	x, y = vec_ints({start.x + size.x * 0.1, start.y + size.y * 0.8})
	rl.DrawText(canvas_tools[idx].name, x, y, 10, modulate(.PRIMARY))

	return get_number_pressed() == idx || !click_claimed && is_box_clicked(start, end, cursor)
}

selected_tool_idx: int
draw_canvas_toolbar :: proc() {
	if i := draw_toolbar({10, 50}, .TOP_LEFT, .BOTTOM, len(canvas_tools), draw_canvas_tool);
	   i != -1 {
		selected_tool_idx = i
	}
	draw_dot({f32(rl.GetScreenWidth()) - 20, 20}, 0.3, selected_color, 5.0)
}

canvas_loop :: proc(delta: f32) {
	if !canvas_initialized {
		init_canvas()
		canvas_initialized = true
	}
	canvas_skeleton = build_skeleton({0, 0}, jelly_proportions, jelly_idle_pose)
	draw_skeleton_debug(canvas_skeleton, state.scale_hint, .PRIMARY, 0.3)
	ref_bones  := skeleton_bones(canvas_ref_skeleton)
	curr_bones := skeleton_bones(canvas_skeleton)

	select_threshold := 20.0 / state.scale_hint

	if !click_claimed && drag_started(&shape_drag) {
		click_claimed = true
		if len(selected_shapes) == 0 && highlighted_found {
			append(&selected_shapes, highlighted_ref)
		}
		shape_drag.start = state.cursor
		shape_drag.end = state.cursor
	}

	if shape_drag.active {
		cursor_delta := state.cursor - shape_drag.end
		shape_drag.end = state.cursor
		for ref in selected_shapes {
			move_whole := len(selected_shapes) > 1 || highlighted_handle == .BOTH
			move_drawable(
				ref.group.contents[ref.idx],
				cursor_delta,
				move_whole,
				highlighted_handle,
			)
		}
	}

	if drag_ended(&shape_drag) {
		clear(&selected_shapes)
	}

	if !shape_drag.active {
		highlighted_ref, highlighted_handle, highlighted_found = nearest_shape(
			&root,
			state.cursor,
			select_threshold,
		)
	}

	if selected_tool_idx == POSE_TOOL_IDX {
		for i in 0 ..< 10 {
			draw_group_on_bone(bone_groups[i], ref_bones[i], curr_bones[i], state.scale_hint)
		}
	} else {
		draw_shape_group(root, state.scale_hint)
		if highlighted_found do handle_highlighted_shape(highlighted_ref, highlighted_handle)
	}

	// use tool
	if selected_tool_idx == POSE_TOOL_IDX {
		if !click_claimed && drag_started(&pose_drag) {
			click_claimed      = true
			pose_drag_bone_idx = nearest_bone_idx(state.cursor)
		}
		if pose_drag.active {
			bone    := skeleton_bones(canvas_skeleton)[pose_drag_bone_idx]
			angles  := pose_angle_ptrs(&jelly_idle_pose)
			angles[pose_drag_bone_idx]^ = angle_facing(bone.root, state.cursor)
		}
		if drag_ended(&pose_drag) {}
	} else {
		drag_handler := canvas_tools[selected_tool_idx].drag_handler
		if !click_claimed && drag_started(&draw_drag) {
			click_claimed     = true
			draw_drag.start   = state.cursor
			active_bone_group = nearest_bone_group(state.cursor)
		}
		if draw_drag.active {
			draw_drag.end = state.cursor
			drag_handler(draw_drag)
		}
		if drag_ended(&draw_drag) {
			ptr  := new(Drawable)
			ptr^  = drag_handler(draw_drag)
			append(&active_bone_group.contents, ptr)
		}
	}
	if rl.IsKeyPressed(.RIGHT_BRACKET) {
		selected_color = ThemeColor((int(selected_color) + 1) % NUM_THEME_COLORS)
	}
	if rl.IsKeyPressed(.LEFT_BRACKET) {
		selected_color = ThemeColor(
			(int(selected_color) - 1 + NUM_THEME_COLORS) % NUM_THEME_COLORS,
		)
	}

	if rl.IsKeyPressed(.B) {
		p := jelly_idle_pose
		fmt.printf(
			"\ttorso       = %v,\n\thead        = %v,\n\tupper_arm_r = %v,\n\tlower_arm_r = %v,\n\tupper_arm_l = %v,\n\tlower_arm_l = %v,\n\tupper_leg_r = %v,\n\tlower_leg_r = %v,\n\tupper_leg_l = %v,\n\tlower_leg_l = %v,\n",
			p.torso, p.head,
			p.upper_arm_r, p.lower_arm_r,
			p.upper_arm_l, p.lower_arm_l,
			p.upper_leg_r, p.lower_leg_r,
			p.upper_leg_l, p.lower_leg_l,
		)
	}

	if rl.IsKeyPressed(.P) {
		data, err := drawable_encode(&root)
		if err == nil {
			_ = utils.write_entire_file("../../assets/shapes.json", data)
			delete(data)
		}
	}
}

