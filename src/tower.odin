package game

import rl "vendor:raylib"

TowerStats :: struct {
	shape: Shape,
	// Number of seconds between each attack
	attack_cooldown: f32,
	draw: proc(t: Tower, color: rl.Color),
}

Tower :: struct {
	pos: Vec2,
	rot: f32,
	attack_timer: f32,
	stats: ^TowerStats,
}

laserTowerStats: TowerStats

initTowerStats :: proc() {
	laserTowerStats = {
		shape = Rect{{48, 48}},
		draw = drawTower,
		attack_cooldown = 2
	}
}

drawTower :: proc(tower: Tower, color: rl.Color) {
	switch shape in tower.stats.shape {
	case Rect:
		r := shape
		offset := r.size / 2
		rot_mat := get_rotation_matrix(tower.rot)
		a_pos := Vec2{-offset.x, -offset.y} * rot_mat + tower.pos
		b_pos := Vec2{-offset.x, offset.y} * rot_mat + tower.pos
		c_pos := Vec2{offset.x, offset.y} * rot_mat + tower.pos
		d_pos := Vec2{offset.x, -offset.y} * rot_mat + tower.pos
		line_strip := [5]Vec2{a_pos, b_pos, c_pos, d_pos, a_pos}
		rl.DrawLineStrip(&line_strip[0], 5, color)
	case Circle:
		c := shape
		thickness: f32 = line_thickness/2.0
		rl.DrawRing(tower.pos, c.radius-thickness, c.radius+thickness, 0.0, 360.0, 16, color)
	}
}
