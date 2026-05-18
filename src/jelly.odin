package game

import "core:log"
import "core:math"

SHAPES_JSON :: #load("../assets/shapes.json")

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

jelly_pose_idle := Pose{
	torso       = -1.57079637,
	head        = -1.57079637,
	upper_arm_r =  1.3137604,
	lower_arm_r =  1.311434,
	upper_arm_l =  1.77348089,
	lower_arm_l =  1.7261244,
	upper_leg_r =  1.37222958,
	lower_leg_r =  1.3718947,
	upper_leg_l =  1.62024009,
	lower_leg_l =  1.60250628,
}

jelly_pose_left := Pose{
	torso       = -1.86465657,
	head        = -2.1318326,
	upper_arm_r =  0.26341823,
	lower_arm_r =  0.55728239,
	upper_arm_l =  2.929299,
	lower_arm_l = -2.8876944,
	upper_leg_r =  0.89294946,
	lower_leg_r =  0.7890843,
	upper_leg_l =  1.34022498,
	lower_leg_l =  0.91807669,
}

jelly_pose_right := Pose{
	torso       = -1.36135197,
	head        = -1.3238679,
	upper_arm_r =  1.21756279,
	lower_arm_r =  0.84316164,
	upper_arm_l = -3.0783021,
	lower_arm_l = -3.0506518,
	upper_leg_r =  1.59599459,
	lower_leg_r =  2.3246145,
	upper_leg_l =  2.411772,
	lower_leg_l =  1.86991906,
}

jelly_pose_up := Pose{
	torso       = -1.5610718,
	head        = -1.42740119,
	upper_arm_r = -0.9958912,
	lower_arm_r = -1.3936832,
	upper_arm_l = -1.81823039,
	lower_arm_l = -1.5819522,
	upper_leg_r =  1.6928267,
	lower_leg_r =  1.6178542,
	upper_leg_l =  1.3938068,
	lower_leg_l =  1.5840915,
}

jelly_pose_down := Pose{
	torso       = -1.23640227,
	head        = -0.84925079,
	upper_arm_r =  0.26112399,
	lower_arm_r = -0.189163938,
	upper_arm_l =  2.8379047,
	lower_arm_l =  3.0971854,
	upper_leg_r = -0.16934022,
	lower_leg_r =  2.2960322,
	upper_leg_l =  0.8307476,
	lower_leg_l =  2.7116654,
}

// jelly_idle_pose is the reference pose used by the canvas editor — keep in sync with jelly_pose_idle.
jelly_idle_pose := jelly_pose_idle

lerp_angle :: proc(a, b, t: f32) -> f32 {
	diff := math.mod(b - a + math.PI, math.TAU) - math.PI
	return a + diff * t
}

lerp_pose :: proc(a, b: Pose, t: f32) -> Pose {
	la :: lerp_angle
	return Pose{
		torso       = la(a.torso,       b.torso,       t),
		head        = la(a.head,        b.head,        t),
		upper_arm_r = la(a.upper_arm_r, b.upper_arm_r, t),
		lower_arm_r = la(a.lower_arm_r, b.lower_arm_r, t),
		upper_arm_l = la(a.upper_arm_l, b.upper_arm_l, t),
		lower_arm_l = la(a.lower_arm_l, b.lower_arm_l, t),
		upper_leg_r = la(a.upper_leg_r, b.upper_leg_r, t),
		lower_leg_r = la(a.lower_leg_r, b.lower_leg_r, t),
		upper_leg_l = la(a.upper_leg_l, b.upper_leg_l, t),
		lower_leg_l = la(a.lower_leg_l, b.lower_leg_l, t),
	}
}

// Blend the five directional poses using velocity.
// Each axis weight is independent; they are blended into idle additively.
player_pose_from_velocity :: proc(vel: Vec2) -> Pose {
	speed :f32= 800.0
	wx := math.clamp(vel.x / speed, -1, 1)
	wy := math.clamp(vel.y / speed, -1, 1)

	pose := jelly_pose_idle
	if wx < 0 do pose = lerp_pose(pose, jelly_pose_left,  -wx)
	if wx > 0 do pose = lerp_pose(pose, jelly_pose_right,  wx)
	if wy < 0 do pose = lerp_pose(pose, jelly_pose_up,    -wy)
	if wy > 0 do pose = lerp_pose(pose, jelly_pose_down,   wy)
	return pose
}

jelly_bone_shapes: [10][]DrawshapePro
jelly_loaded:      bool

load_jelly_shapes :: proc() {
	ref_sk    := build_skeleton({0, 0}, jelly_proportions, jelly_pose_idle)
	ref_bones := skeleton_bones(ref_sk)

	root_d, ok := drawable_decode(SHAPES_JSON)
	if !ok {
		log.error("jelly: failed to decode shapes.json")
		return
	}
	root_group, is_group := root_d.(^DrawshapeGroup)
	if !is_group {
		log.error("jelly: root is not a DrawshapeGroup")
		return
	}

	for item in root_group.contents {
		sub, sub_ok := item^.(^DrawshapeGroup)
		if !sub_ok do continue

		bone_idx := -1
		for name, i in BONE_NAMES {
			if sub.name == name {
				bone_idx = i
				break
			}
		}
		if bone_idx < 0 do continue

		ref_bone := ref_bones[bone_idx]
		shapes   := make([dynamic]DrawshapePro)
		for ptr in sub.contents {
			pro: DrawshapePro
			switch v in ptr^ {
			case Drawshape:       pro = {drawshape = v, col = .PRIMARY, brightness = 1.0}
			case DrawshapePro:    pro = v
			case ^DrawshapeGroup: continue
			}
			append(&shapes, DrawshapePro{
				drawshape  = {pro.type, world_to_bone(ref_bone, pro.start), world_to_bone(ref_bone, pro.end)},
				col        = pro.col,
				brightness = pro.brightness,
			})
		}
		jelly_bone_shapes[bone_idx] = shapes[:]
	}

	jelly_loaded = true
}

draw_player :: proc(e: ^Entity, state: ^GameState) {
	if !jelly_loaded do load_jelly_shapes()

	sh    := state.scale_hint
	pose  := player_pose_from_velocity(e.velocity)
	sk    := build_skeleton(e.pos + Vec2{0, 8}, jelly_proportions, pose)
	bones := skeleton_bones(sk)

	for shapes, i in jelly_bone_shapes {
		if len(shapes) > 0 {
			draw_on_bone_pro(bones[i], shapes, sh)
		}
	}

	if draw_debug do draw_skeleton_debug(sk, sh)
}
