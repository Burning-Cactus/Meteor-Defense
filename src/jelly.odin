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

jelly_bone_shapes: [10][]DrawshapePro
jelly_loaded:      bool

load_jelly_shapes :: proc() {
	ref_sk    := build_skeleton({0, 0}, jelly_proportions, jelly_idle_pose)
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
			case Drawshape:    pro = {drawshape = v,          col = .PRIMARY, brightness = 1.0}
			case DrawshapePro: pro = v
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
	sk    := build_skeleton(e.pos + Vec2{0, 8}, jelly_proportions, jelly_idle_pose)
	bones := skeleton_bones(sk)

	for shapes, i in jelly_bone_shapes {
		if len(shapes) > 0 {
			draw_on_bone_pro(bones[i], shapes, sh)
		}
	}

	if draw_debug do draw_skeleton_debug(sk, sh)
}
