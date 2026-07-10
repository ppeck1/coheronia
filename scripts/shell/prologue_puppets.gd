extends RefCounted
## FQ-09C hybrid acting pass: articulated puppet figures for the opening
## cinematic, in the filled-polygon tradition of early-90s cinematic
## platformers. Pure static helpers: given a spec, a base point, and a pose,
## they append draw commands to the caller's command list — no state, no
## clocks, no randomness, so canvas fingerprint determinism is preserved.
##
## A puppet is a small skeleton (legs, torso, head, two arms, optional held
## tool) rendered as hard filled quads. Poses are dictionaries of joint
## angles in degrees; keyframe tracks interpolate between poses with angle
## quantization (5 degree steps) and pixel snapping so motion stays visibly
## stepped rather than smoothly tweened.
##
## Pose keys (all optional, default 0):
##   lean        torso angle from vertical (+ = leaning right/forward)
##   head_ang    extra head tilt relative to the torso
##   arm_l_ang / arm_r_ang    shoulder angles (0 = hanging down, + = forward)
##   elbow_r     extra forearm bend on the right arm (two-segment arm)
##   leg_l_ang / leg_r_ang    hip angles (0 = standing, + = forward)
##   hip_dx      root x shift in px    bob    root y shift in px (- = up)
##   tool        "" | "hammer" | "pick" | "crate" | "beam"
##   tool_ang    tool angle (0 = up along the arm line)

const ANGLE_STEP := 5.0   # degrees; the quantized-motion contract


## Ancestry body specs: silhouette identity through proportion, not detail.
static func spec(kind: String, col: Color) -> Dictionary:
	match kind:
		"dwarf":
			return {"h": 17.0, "torso_w": 7.0, "head": 4.5, "limb_w": 3.0, "col": col}
		"elf":
			return {"h": 29.0, "torso_w": 3.0, "head": 3.5, "limb_w": 2.0, "col": col}
		"orc":
			return {"h": 27.0, "torso_w": 8.0, "head": 5.0, "limb_w": 3.0, "col": col}
		"goblin":
			return {"h": 13.0, "torso_w": 4.0, "head": 4.0, "limb_w": 2.0, "col": col}
		_:   # human: balanced, upright, civic
			return {"h": 25.0, "torso_w": 5.0, "head": 4.0, "limb_w": 2.0, "col": col}


## Renders one puppet: base is the point between the feet on the ground.
static func render(c: Array, body: Dictionary, base: Vector2, pose: Dictionary) -> void:
	var col: Color = body["col"]
	var h: float = body["h"]
	var leg_len := h * 0.40
	var torso_len := h * 0.40
	var arm_len := h * 0.36
	var limb_w: float = body["limb_w"]
	var root := base + Vector2(float(pose.get("hip_dx", 0.0)), -leg_len + float(pose.get("bob", 0.0)))
	# Legs: hip to foot, angle 0 = straight down.
	for leg in [["leg_l_ang", -1.0], ["leg_r_ang", 1.0]]:
		var ang := deg_to_rad(float(pose.get(leg[0], 0.0)))
		var foot := root + Vector2(sin(ang) * leg_len + leg[1] * limb_w * 0.6, cos(ang) * leg_len)
		_limb(c, root, foot, limb_w, col)
	# Torso and head.
	var lean := deg_to_rad(float(pose.get("lean", 0.0)))
	var shoulder := root + Vector2(sin(lean), -cos(lean)) * torso_len
	_limb(c, root, shoulder, body["torso_w"], col)
	var head_ang := lean + deg_to_rad(float(pose.get("head_ang", 0.0)))
	var head_r: float = body["head"]
	var head_c := shoulder + Vector2(sin(head_ang), -cos(head_ang)) * (head_r + 1.0)
	c.append(["rect", Rect2(floorf(head_c.x - head_r * 0.8), floorf(head_c.y - head_r),
		floorf(head_r * 1.6), floorf(head_r * 1.9)), col])
	# Left arm: one segment behind the torso.
	var al := deg_to_rad(float(pose.get("arm_l_ang", 0.0)))
	var hand_l := shoulder + Vector2(sin(al) * arm_len, cos(al) * arm_len)
	_limb(c, shoulder, hand_l, limb_w, col)
	# Right arm: optional two-segment (elbow) for tool acting.
	var ar := deg_to_rad(float(pose.get("arm_r_ang", 0.0)))
	var hand_r: Vector2
	if pose.has("elbow_r"):
		var elbow := shoulder + Vector2(sin(ar), cos(ar)) * (arm_len * 0.55)
		var fore := ar + deg_to_rad(float(pose.get("elbow_r", 0.0)))
		hand_r = elbow + Vector2(sin(fore), cos(fore)) * (arm_len * 0.55)
		_limb(c, shoulder, elbow, limb_w, col)
		_limb(c, elbow, hand_r, limb_w, col)
	else:
		hand_r = shoulder + Vector2(sin(ar) * arm_len, cos(ar) * arm_len)
		_limb(c, shoulder, hand_r, limb_w, col)
	_tool(c, str(pose.get("tool", "")), hand_r,
		deg_to_rad(float(pose.get("tool_ang", 0.0))), col)


## A limb/torso as a hard filled quad between two joints.
static func _limb(c: Array, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := b - a
	if d.length() < 0.5:
		return
	var n := Vector2(-d.y, d.x).normalized() * (w * 0.5)
	c.append(["poly", PackedVector2Array([
		Vector2(floorf(a.x + n.x), floorf(a.y + n.y)),
		Vector2(floorf(b.x + n.x), floorf(b.y + n.y)),
		Vector2(floorf(b.x - n.x), floorf(b.y - n.y)),
		Vector2(floorf(a.x - n.x), floorf(a.y - n.y)),
	]), col])


static func _tool(c: Array, kind: String, hand: Vector2, ang: float, col: Color) -> void:
	if kind == "":
		return
	var dir := Vector2(sin(ang), -cos(ang))
	match kind:
		"hammer":
			var tip := hand + dir * 9.0
			_limb(c, hand - dir * 2.0, tip, 1.5, col)
			c.append(["rect", Rect2(floorf(tip.x - 2.0), floorf(tip.y - 1.5), 5.0, 3.0), col.lightened(0.25)])
		"pick":
			var tip2 := hand + dir * 10.0
			_limb(c, hand - dir * 2.0, tip2, 1.5, col)
			var side := Vector2(-dir.y, dir.x)
			_limb(c, tip2 - side * 4.0 + dir * 1.5, tip2 + side * 4.0 - dir * 1.5, 1.5, col.lightened(0.25))
		"crate":
			c.append(["rect", Rect2(floorf(hand.x - 4.0), floorf(hand.y - 6.0), 8.0, 7.0), col.lightened(0.3)])
		"beam":
			var side2 := Vector2(-dir.y, dir.x)
			_limb(c, hand - side2 * 9.0, hand + side2 * 9.0, 2.0, col.lightened(0.25))


## Mirrors a pose horizontally (a figure working leftward): angle-like keys
## negate, everything else holds.
static func mirror(pose: Dictionary) -> Dictionary:
	var out := {}
	for k in pose:
		var v = pose[k]
		if (v is float or v is int) and (str(k).ends_with("_ang")
				or str(k) == "lean" or str(k) == "elbow_r" or str(k) == "hip_dx"):
			out[k] = -float(v)
		else:
			out[k] = v
	return out


# ---------- keyframe tracks ----------

## Track: ordered [[tick, pose], ...]. Returns the pose at tick t, holding
## before the first and after the last key, interpolating between keys with
## quantized angles/pixels so tween motion still reads as stepped animation.
static func pose_at(track: Array, t: int) -> Dictionary:
	if track.is_empty():
		return {}
	var first: Array = track[0]
	if t <= int(first[0]):
		return first[1]
	for i in range(track.size() - 1):
		var a: Array = track[i]
		var b: Array = track[i + 1]
		if t < int(b[0]):
			var f := float(t - int(a[0])) / float(maxi(1, int(b[0]) - int(a[0])))
			return _mix(a[1], b[1], f)
	var last: Array = track[track.size() - 1]
	return last[1]


## Looping track: the pose cycle repeats every `period` ticks (offset for
## staggering multiple puppets off one shared cycle).
static func cycle_at(track: Array, t: int, period: int, offset: int = 0) -> Dictionary:
	return pose_at(track, posmod(t + offset, maxi(1, period)))


static func _mix(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
	var out := {}
	for key in a:
		out[key] = a[key]
	for key in b:
		var vb = b[key]
		if not (vb is float or vb is int):
			out[key] = vb if f > 0.5 else out.get(key, vb)
			continue
		var prev = out.get(key, 0.0)
		var va := 0.0
		if prev is float or prev is int:
			va = float(prev)
		var mixed := lerpf(va, float(vb), f)
		if str(key).ends_with("_ang") or str(key) == "lean" or str(key) == "elbow_r":
			out[key] = roundf(mixed / ANGLE_STEP) * ANGLE_STEP
		else:
			out[key] = roundf(mixed)
	# Keys only in a keep their value (already copied); tool strings hold.
	return out


## A shared two-beat work/walk cycle: legs and arms alternate on a hard beat.
static func walk_track() -> Array:
	return [
		[0, {"leg_l_ang": 20.0, "leg_r_ang": -14.0, "arm_l_ang": -12.0, "arm_r_ang": 12.0, "bob": 0.0}],
		[3, {"leg_l_ang": -14.0, "leg_r_ang": 20.0, "arm_l_ang": 12.0, "arm_r_ang": -12.0, "bob": -1.0}],
		[6, {"leg_l_ang": 20.0, "leg_r_ang": -14.0, "arm_l_ang": -12.0, "arm_r_ang": 12.0, "bob": 0.0}],
	]


## Hammer swing: raise, hold, strike. Strike lands on the last key's tick.
static func hammer_track(strike_period: int) -> Array:
	var up := {"lean": -5.0, "arm_r_ang": 150.0, "elbow_r": 40.0, "tool": "hammer", "tool_ang": 160.0}
	var down := {"lean": 15.0, "arm_r_ang": 55.0, "elbow_r": 10.0, "tool": "hammer", "tool_ang": 55.0}
	return [
		[0, up],
		[strike_period - 2, down],
		[strike_period, up],
	]
