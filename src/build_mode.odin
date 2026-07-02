package game

import rl "vendor:raylib"
import "core:math"

current_tower_type:TowerType
current_pending_tower:Tower

selectable_towers:[]TowerType = {.LASER, .CANNON}
selected_tower_idx:=-1
draw_tower_toolbar ::proc() {
	w,h := f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
	result := draw_toolbar({w/2, h-min(30, h/10)}, .BOTTOM, .RIGHT, len(selectable_towers), draw_tower_selector)
	if result != -1 {
		selected_tower_idx = result
		current_tower_type = selectable_towers[result]
	}
}

draw_tower_selector :: proc(start:Vec2, end:Vec2, idx:int, cursor:Vec2, scale_hint:f32=1.0) -> bool {
	brightness:f32= .5
	if is_box_hovered(start, end, cursor) {
		brightness = 1.0
	}
	type := selectable_towers[idx]
	if current_tower_type == type && state.buildMode {
		brightness = 2.0
	}

	center, size := box_geo(start, end)
	toolslot_scale := (end.y - start.y)/ tool_slot_size
	icon := Tower{rot=-math.PI/2, pos={center.x, end.y}}
	init_tower(&icon, type)
	switch type {
	case .CANNON:
		icon.scale = 0.35 * toolslot_scale
	case .LASER:
		icon.scale = 0.4 * toolslot_scale
	}
	icon.barrel_angle = -math.PI / 6
	null_state:=GameState{scale_hint=1.0}
	do_culling=false //HACK
	draw_entity(&icon, &null_state)
	do_culling=true

	draw_box(start, end, scale_hint, .PRIMARY, brightness)
	inner_corner := start+ size/10
	rl.DrawText(rl.TextFormat("%i", idx+1), i32(inner_corner.x), i32(inner_corner.y), 10, modulate(.PRIMARY))

	// HACK: this is a fix for a bug added in cf44467 to make them clickable again.
	// A mouse click feeds the same input path the number keys use, so build-mode
	// toggling stays centralized in game_loop (via input.build_mode).
	if is_box_clicked(start, end, cursor) {
		if !state.buildMode {
			input.build_mode = true
			play_sfx("ui_click")
		} else if idx == input.select_slot {
			input.build_mode = true
			play_sfx("ui_back")
		} else do play_sfx("ui_click")
		input.select_slot = idx
	}
	return get_number_selection(len(selectable_towers)-1) == idx
}

update_build_mode :: proc(state: ^GameState) {
	//NOTE: input processing should only be done in frame loop
	point, normal := find_intersection_point_on_entity(state.cursor, state.comet)
	current_pending_tower.pos = point
	current_pending_tower.rot = vec_angle(normal)

	init_tower(&current_pending_tower, current_tower_type)
}

draw_aim_arc :: proc(tower: ^Tower, col: ThemeColor, scale_hint: f32) {
	tower_pos   := entity_world_pos(tower^)
	base_angle  := entity_world_rot(tower^)
	a0 := base_angle - tower.aim_arc
	a1 := base_angle + tower.aim_arc

	draw_line(tower_pos, tower_pos + unit_vector(a0) * tower.range, scale_hint, col, 0.3)
	draw_line(tower_pos, tower_pos + unit_vector(a1) * tower.range, scale_hint, col, 0.3)

	n :: 24
	prev := tower_pos + unit_vector(a0) * tower.range
	for i in 1..=n {
		a    := a0 + f32(i) * (a1 - a0) / f32(n)
		curr := tower_pos + unit_vector(a) * tower.range
		draw_line(prev, curr, scale_hint, col, 0.3)
		prev = curr
	}
}

draw_build_mode :: proc(state: ^GameState) {
	can_build := true
	if check_collision_any(current_pending_tower, state.towers) {
		current_pending_tower.col = .RED
		can_build = false
	} else if current_pending_tower.value > state.money {
		current_pending_tower.col = .YELLOW
		can_build = false
	} else {
		current_pending_tower.col = .CYAN
	}

	draw_aim_arc(&current_pending_tower, current_pending_tower.col, state.scale_hint)
	draw_entity(&current_pending_tower.entity, state)
	if input.fire && try_claim_click() {
		if can_build {
			state.money -= current_pending_tower.value
			current_pending_tower.col = .PRIMARY
			attach_to_parent(&current_pending_tower, &state.comet)
			spawn(&state.towers, current_pending_tower.pos, current_pending_tower)
			current_pending_tower = {}
			state.buildMode = false
			play_sfx("place_tower")
		} else do play_sfx("ui_error")
	}
}
