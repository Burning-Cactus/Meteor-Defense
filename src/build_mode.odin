package game

import rl "vendor:raylib"
import "core:math"

current_tower_type:TowerType
current_pending_tower:Tower

selectable_towers:[]TowerType = {.LASER, .CANNON}
selected_tower_idx:=-1
draw_tower_toolbar ::proc() {
	result := draw_toolbar({10, 50}, .TOP_LEFT, .BOTTOM, len(selectable_towers), draw_tower_selector)
	if result != -1 {
		if result != selected_tower_idx || !state.buildMode {
			selected_tower_idx = result
			current_tower_type = selectable_towers[result]
			state.buildMode = true
			play_sfx("ui_click")
		} else {
			selected_tower_idx = -1
			state.buildMode = false
			play_sfx("ui_back")
		}
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
	icon := Tower{rot=-math.PI/2, pos={center.x, end.y}}
	init_tower(&icon, type)
	switch type {
	case .CANNON:
		icon.scale = 0.35
	case .LASER:
		icon.scale = 0.4
	}
	icon.barrel_angle = -math.PI / 6
	null_state:=GameState{scale_hint=1.0}
	draw_entity(&icon, &null_state)

	draw_box(start, end, scale_hint, .PRIMARY, brightness)
	inner_corner := start+ size/10
	rl.DrawText(rl.TextFormat("%i", idx+1), i32(inner_corner.x), i32(inner_corner.y), 10, modulate(.PRIMARY))

	return is_box_clicked(start, end, cursor) || get_number_pressed() == idx
}

update_build_mode :: proc(state: ^GameState) {
	//NOTE: input processing should only be done in frame loop
	point, normal := find_intersection_point_on_entity(state.cursor, state.comet)
	current_pending_tower.pos = point
	current_pending_tower.rot = vec_angle(normal)

	init_tower(&current_pending_tower, current_tower_type)
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

	draw_entity(&current_pending_tower.entity, state)
	if rl.IsMouseButtonPressed(.LEFT) && try_claim_click() {
		if can_build {
			state.money -= current_pending_tower.value
			current_pending_tower.col = .PRIMARY
			attach_to_parent(&current_pending_tower, &state.comet)
			spawn(&state.towers, current_pending_tower.pos, current_pending_tower)
			current_pending_tower = {}
			state.buildMode = false
		} else do play_sfx("ui_error")
	}
}
