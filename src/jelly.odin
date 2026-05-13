package game

import "core:math"

jelly_proportions := SkeletonProportions{
	torso_len      = 32,
	head           = 0.7,
	shoulder_width = 0.5,
	hip_width      = 0.4,
	upper_arm      = 0.65,
	lower_arm      = 0.55,
	upper_leg      = 0.5,
	lower_leg      = 0.9,
}

// All angles in world-space radians. Tune these to pose Jelly.
jelly_idle_pose := Pose{
	torso       = -math.PI / 2,
	head        = -math.PI / 2,
	upper_arm_r =  1.1,
	lower_arm_r =  1.3,
	upper_arm_l =  math.PI - 1.1,
	lower_arm_l =  math.PI - 1.3,
	upper_leg_r =  math.PI/2 - 0.04,
	lower_leg_r =  math.PI/2 - 0.04,
	upper_leg_l =  math.PI/2 + 0.02,
	lower_leg_l =  math.PI/2 + 0.02,
}

draw_player :: proc(e: ^Entity, state: ^GameState) {
	col := ThemeColor.PRIMARY
	sh  := state.scale_hint
	// hip sits slightly below entity centre
	sk  := build_skeleton(e.pos + Vec2{0, 8}, jelly_proportions, jelly_idle_pose)

	// Torso
	torso_diamond := closed_polygon([]Vec2{
		{ 0,    0.3},
		{ 0.25, 0.72 },
		{ 0,    1},
		{ -0.25, 0.72 },
	})
	draw_on_bone(sk.torso, torso_diamond, col, sh)
	draw_on_bone(sk.torso, {{.LINE, {0.15, 0}, {-0.15, 0}}}, col, sh)

	// Head
	chin:Vec2 = {0.2,0.1}
	eyes:Vec2 = {0.5,0.5}
	brow:Vec2 = {0.4,0.6}
	for line in ([]Vec2{chin, eyes, brow}) {
		draw_on_bone(sk.head, {{.LINE, {line.x/2, line.y}, {-line.x/2, line.y}}}, col, sh)
	}
	hair_l := []Drawshape{
		{.LINE, {0.2, 0.9}, {0.52, 0.48}},
		{.LINE, {0.27, 1.0}, {0.7, 0.55}},
	}
	draw_on_bone(sk.head, hair_l, .CYAN, sh)
	draw_on_bone(sk.head, flip_h(hair_l), .CYAN, sh)
	draw_on_bone(sk.head, []Drawshape{
	}, .CYAN, sh)


	// Upper arms
	draw_bilateral(sk.upper_arm_r, sk.upper_arm_l, []Drawshape{
		{.DOT,  {0, 0}, {0, 0}},
		{.LINE, {0, 0.2}, {0, 1}},
	}, col, sh)

	/*
	draw_bilateral(sk.lower_arm_r, sk.lower_arm_l, []Drawshape{
		{.CIRCLE, {0, 1}, {0, 1.1}},
	}, col, sh)
	*/

	// Upper legs
	draw_bilateral(sk.upper_leg_r, sk.upper_leg_l, []Drawshape{
		{.LINE, {0, 0.14}, {0, 0.8}},
	}, col, sh)
	draw_on_bone(sk.upper_leg_r, []Drawshape{
		{.LINE, {-.1, .22}, {.1, .22}},
		{.LINE, {-.1, .23}, {-.1, 1}},
	}, col, sh)

	// Lower legs
	// shoes
	draw_bilateral(sk.lower_leg_r, sk.lower_leg_l, closed_polygon([]Vec2{
		{0, 0.5},
		{0.05, 0.85},
		{-0.2, 0.85}},
	), col, sh)
	// wings
	draw_bilateral(sk.lower_leg_r, sk.lower_leg_l, []Drawshape{
		{.LINE, {-.22, .6}, {-0.3, .3}},
		{.LINE, {-.25, .7}, {-0.7, .6}},
		{.LINE, {-.3, .75}, {-0.5, .9}},
	}, .BLUE, sh)
	// foot
	draw_bilateral(sk.lower_leg_r, sk.lower_leg_l, []Drawshape{
		{.LINE, {.1, 1.0}, {-.1, 1}},
	}, col, sh)

	if draw_debug do draw_skeleton_debug(sk, sh)
}
