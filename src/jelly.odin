package game

import "core:math"

jelly_proportions := SkeletonProportions{
	torso_len      = 32,
	head           = 0.5,
	shoulder_width = 0.9,
	hip_width      = 0.55,
	upper_arm      = 0.65,
	lower_arm      = 0.55,
	upper_leg      = 0.65,
	lower_leg      = 0.6,
}

// All angles in world-space radians. Tune these to pose Jelly.
jelly_idle_pose := Pose{
	torso       = -math.PI / 2,
	head        = -math.PI / 2,
	upper_arm_r =  1.1,
	lower_arm_r =  1.3,
	upper_arm_l =  math.PI - 1.1,
	lower_arm_l =  math.PI - 1.3,
	upper_leg_r =  math.PI/2 - 0.12,
	lower_leg_r =  math.PI/2 + 0.10,
	upper_leg_l =  math.PI/2 + 0.12,
	lower_leg_l =  math.PI/2 - 0.10,
}

draw_player :: proc(e: ^Entity, state: ^GameState) {
	col := ThemeColor.CYAN
	sh  := state.scale_hint
	// hip sits slightly below entity centre
	sk  := build_skeleton(e.pos + Vec2{0, 8}, jelly_proportions, jelly_idle_pose)

	// Torso: diamond body
	draw_on_bone(sk.torso, closed_polygon([]Vec2{
		{ 0,    0.05},
		{ 0.35, 0.5 },
		{ 0,    0.95},
		{-0.35, 0.5 },
	}), col, sh)

	// Head: small diamond
	draw_on_bone(sk.head, closed_polygon([]Vec2{
		{ 0,    0   },
		{ 0.4,  0.45},
		{ 0,    1   },
		{-0.4,  0.45},
	}), col, sh)

	// Arms: shoulder dot at root, then bone line. Right side drives both via bilateral.
	draw_bilateral(sk.upper_arm_r, sk.upper_arm_l, []Drawshape{
		{.DOT,  {0, 0}, {0, 0}},
		{.LINE, {0, 0}, {0, 1}},
	}, col, sh)
	draw_bilateral(sk.lower_arm_r, sk.lower_arm_l, []Drawshape{
		{.LINE, {0, 0}, {0, 1}},
	}, col, sh)

	// Legs
	draw_bilateral(sk.upper_leg_r, sk.upper_leg_l, []Drawshape{
		{.LINE, {0, 0}, {0, 1}},
	}, col, sh)
	draw_bilateral(sk.lower_leg_r, sk.lower_leg_l, []Drawshape{
		{.LINE, {0, 0}, {0, 1}},
	}, col, sh)

	if draw_debug do draw_skeleton_debug(sk, sh)
}
