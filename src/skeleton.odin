package game

// A directed line segment used as a bone.
// Shapes attached to a bone use bone-local coordinates:
//   y: 0 = root, 1 = tip
//   x: 0 = centerline, positive = "right" when facing root→tip
Bone :: struct {
	root: Vec2,
	tip:  Vec2,
}

Skeleton :: struct {
	torso:       Bone,
	head:        Bone,
	upper_arm_r: Bone,
	lower_arm_r: Bone,
	upper_arm_l: Bone,
	lower_arm_l: Bone,
	upper_leg_r: Bone,
	lower_leg_r: Bone,
	upper_leg_l: Bone,
	lower_leg_l: Bone,
}

// All angles in radians, world-space. 0=right, π/2=down (screen y), -π/2=up.
Pose :: struct {
	torso:       f32,
	head:        f32,
	upper_arm_r: f32,
	lower_arm_r: f32,
	upper_arm_l: f32,
	lower_arm_l: f32,
	upper_leg_r: f32,
	lower_leg_r: f32,
	upper_leg_l: f32,
	lower_leg_l: f32,
}

// torso_len is in world pixels; all other lengths are fractions of torso_len.
// shoulder_width and hip_width are total widths (each side offset = half).
SkeletonProportions :: struct {
	torso_len:      f32,
	head:           f32,
	shoulder_width: f32,
	hip_width:      f32,
	upper_arm:      f32,
	lower_arm:      f32,
	upper_leg:      f32,
	lower_leg:      f32,
}

// Build a skeleton. hip_pos is the torso root in world space.
// orientation offsets every bone angle equally — pass e.rot to rotate the whole character.
build_skeleton :: proc(hip_pos: Vec2, props: SkeletonProportions, pose: Pose, orientation: f32 = 0) -> Skeleton {
	sk: Skeleton
	tl := props.torso_len
	o  := orientation

	torso_dir  := unit_vector(pose.torso + o)
	torso_perp := Vec2{-torso_dir.y, torso_dir.x}

	sk.torso.root = hip_pos
	sk.torso.tip  = hip_pos + torso_dir * tl

	shoulder := sk.torso.tip
	hip      := sk.torso.root

	sk.head.root = shoulder
	sk.head.tip  = shoulder + unit_vector(pose.head + o) * (props.head * tl)

	shoulder_r := shoulder + torso_perp * (props.shoulder_width * 0.5 * tl)
	shoulder_l := shoulder - torso_perp * (props.shoulder_width * 0.5 * tl)
	hip_r      := hip + torso_perp * (props.hip_width * 0.5 * tl)
	hip_l      := hip - torso_perp * (props.hip_width * 0.5 * tl)

	sk.upper_arm_r.root = shoulder_r
	sk.upper_arm_r.tip  = shoulder_r + unit_vector(pose.upper_arm_r + o) * (props.upper_arm * tl)
	sk.lower_arm_r.root = sk.upper_arm_r.tip
	sk.lower_arm_r.tip  = sk.upper_arm_r.tip + unit_vector(pose.lower_arm_r + o) * (props.lower_arm * tl)

	sk.upper_arm_l.root = shoulder_l
	sk.upper_arm_l.tip  = shoulder_l + unit_vector(pose.upper_arm_l + o) * (props.upper_arm * tl)
	sk.lower_arm_l.root = sk.upper_arm_l.tip
	sk.lower_arm_l.tip  = sk.upper_arm_l.tip + unit_vector(pose.lower_arm_l + o) * (props.lower_arm * tl)

	sk.upper_leg_r.root = hip_r
	sk.upper_leg_r.tip  = hip_r + unit_vector(pose.upper_leg_r + o) * (props.upper_leg * tl)
	sk.lower_leg_r.root = sk.upper_leg_r.tip
	sk.lower_leg_r.tip  = sk.upper_leg_r.tip + unit_vector(pose.lower_leg_r + o) * (props.lower_leg * tl)

	sk.upper_leg_l.root = hip_l
	sk.upper_leg_l.tip  = hip_l + unit_vector(pose.upper_leg_l + o) * (props.upper_leg * tl)
	sk.lower_leg_l.root = sk.upper_leg_l.tip
	sk.lower_leg_l.tip  = sk.upper_leg_l.tip + unit_vector(pose.lower_leg_l + o) * (props.lower_leg * tl)

	return sk
}

// Transform a bone-local point to world space.
bone_to_world :: proc(b: Bone, local: Vec2) -> Vec2 {
	along := b.tip - b.root
	perp  := Vec2{-along.y, along.x}
	return b.root + along * local.y + perp * local.x
}

// Transform a world-space point to bone-local coordinates.
world_to_bone :: proc(b: Bone, world: Vec2) -> Vec2 {
	along := b.tip - b.root
	perp  := Vec2{-along.y, along.x}
	d     := world - b.root
	len_sq := along.x*along.x + along.y*along.y
	return {(d.x*perp.x + d.y*perp.y) / len_sq, (d.x*along.x + d.y*along.y) / len_sq}
}

// Draw shapes on a bone. Coordinates are bone-local.
draw_on_bone :: proc(b: Bone, shapes: []Drawshape, col: ThemeColor, scale_hint: f32) {
	for s in shapes {
		ws: Drawshape
		ws.type  = s.type
		ws.start = bone_to_world(b, s.start)
		ws.end   = bone_to_world(b, s.end)
		draw_shape(ws, scale_hint, col)
	}
}

flip_h :: proc(shapes: []Drawshape) -> []Drawshape {
	for &s in shapes {
		s.start.x *= -1
		s.end.x *= -1
	}
	return shapes
}

flip_v :: proc(shapes: []Drawshape) -> []Drawshape {
	for &s in shapes {
		s.start.y = 1.0 - s.start.y
		s.end.y = 1.0 - s.end.y
	}
	return shapes
}
// Draw shapes on two bones with the x-axis mirrored on the second.
// Pass (right_bone, left_bone) and define shapes for the right side only.
draw_bilateral :: proc(b_r, b_l: Bone, shapes: []Drawshape, col: ThemeColor, scale_hint: f32) {
	draw_on_bone(b_r, shapes, col, scale_hint)
	draw_on_bone(b_l, flip_h(shapes), col, scale_hint)
}

open_polygon :: proc(pts: []Vec2, allocator := context.temp_allocator) -> []Drawshape {
	shapes := make([]Drawshape, len(pts), allocator)
	for i in 0..<len(pts)-1 {
		shapes[i] = Drawshape{.LINE, pts[i], pts[(i + 1)]}
	}
	return shapes
}
// Convert vertex list to a closed polygon of LINE Drawshapes.
// Uses temp allocator — safe to call every frame.
closed_polygon :: proc(pts: []Vec2, allocator := context.temp_allocator) -> []Drawshape {
	n := len(pts)
	shapes := make([]Drawshape, n, allocator)
	for i in 0..<n {
		shapes[i] = Drawshape{.LINE, pts[i], pts[(i + 1) % n]}
	}
	return shapes
}

// Visualise all bones in DEBUG color. Call from the F3 overlay when tuning a character.
draw_skeleton_debug :: proc(sk: Skeleton, scale_hint: f32) {
	bones := [10]Bone{
		sk.torso,
		sk.head,
		sk.upper_arm_r, sk.lower_arm_r,
		sk.upper_arm_l, sk.lower_arm_l,
		sk.upper_leg_r, sk.lower_leg_r,
		sk.upper_leg_l, sk.lower_leg_l,
	}
	for b in bones {
		draw_line(b.root, b.tip, scale_hint, .DEBUG)
	}
}
