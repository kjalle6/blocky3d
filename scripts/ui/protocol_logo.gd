extends Control
## Authored pixel lettering: independent prefix, wordmark and override stamp.
## Local artboard is 1400 x 385. Timing is deterministic for live review/capture.
const INK := Color("#080e22")
const PAPER := Color("#e9f5ef")
const CYAN := Color("#72eef3")
const PINK := Color("#fa60a8")
# Spaced phrase arrivals leave room for a possible future sound/vocal treatment.
# Keep the individual impacts brisk; the holds provide the slower overall pace.
const ENTRANCE_DURATION := 4.8
const PREFIX_START := 0.35
const PREFIX_REVEAL := 0.4
const WORDMARK_START := 1.8
const WORDMARK_LOCK := 0.4
const STAMP_START := 3.4
const STAMP_LAND := 0.28
# An 8 x 10 grid keeps two-cell strokes and generous counters throughout.
# N/X/R diagonals use solid polygons to avoid oversized staircase notches.
const GLYPHS := {
	"E": ["11111111","11111111","11000000","11000000","11111100","11111100","11000000","11000000","11111111","11111111"],
	"O": ["01111110","11111111","11000011","11000011","11000011","11000011","11000011","11000011","11111111","01111110"],
	"P": ["11111110","11111111","11000011","11000011","11111111","11111110","11000000","11000000","11000000","11000000"],
	"I": ["11111111","11111111","00011000","00011000","00011000","00011000","00011000","00011000","11111111","11111111"],
	"L": ["11000000","11000000","11000000","11000000","11000000","11000000","11000000","11000000","11111111","11111111"],
	"R": ["11111110","11111111","11000011","11000011","11111111","11111110","11000000","11000000","11000000","11000000"],
	"T": ["11111111","11111111","00011000","00011000","00011000","00011000","00011000","00011000","00011000","00011000"],
	"C": ["00111111","01111111","11000000","11000000","11000000","11000000","11000000","11000000","01111111","00111111"],
	"B": ["11111110","11111111","11000011","11000011","11111110","11111111","11000011","11000011","11111111","11111110"]
}
var entrance_time := 0.0
var prefix_glow_strength := 1.0:
	set(value):
		prefix_glow_strength = clampf(value, 0.0, 2.0)
		queue_redraw()
var effects_enabled := true:
	set(value):
		effects_enabled = value
		queue_redraw()
# Temporary drawing state; no timers, particles or shader clocks survive a skip.
var _clip_enabled := false
var _clip := Rect2()
var _slice_offset := Vector2.ZERO
var _neon_time := 0.0
var _neon_level := 1.0

func _process(delta: float) -> void:
	if not effects_enabled or entrance_time < ENTRANCE_DURATION or not is_visible_in_tree():
		return
	set_neon_time(_neon_time + delta)

func set_neon_time(seconds: float) -> void:
	var was_riot_active := _idle_riot_age(_neon_time) >= 0.0
	_neon_time = maxf(seconds, 0.0)
	var level := _idle_neon_level(_neon_time)
	if not is_equal_approx(level, _neon_level) or was_riot_active or _idle_riot_age(_neon_time) >= 0.0:
		_neon_level = level
		queue_redraw()

func _idle_neon_level(seconds: float) -> float:
	# Three different fault patterns separated by long steady stretches.
	# The cycle is deliberately uneven; no regular pulse or breathing loop.
	var t := fposmod(seconds, 19.7)
	if t >= 2.6 and t < 3.20:
		return _neon_fault(t - 2.6, 0)
	if t >= 9.1 and t < 9.58:
		return _neon_fault(t - 9.1, 1)
	if t >= 15.4 and t < 16.12:
		return _neon_fault(t - 15.4, 2)
	return 1.0

func _neon_fault(age: float, pattern: int) -> float:
	if pattern == 1:
		if age < 0.17: return 0.24
		if age < 0.23: return 1.16
		if age < 0.36: return 0.06
		if age < 0.42: return 0.62
		return 1.08
	if pattern == 2:
		if age < 0.23: return 0.48
		if age < 0.31: return 0.08
		if age < 0.38: return 1.12
		if age < 0.51: return 0.18
		if age < 0.58: return 0.92
		if age < 0.64: return 0.12
		return 1.06
	if age < 0.12: return 0.06
	if age < 0.18: return 1.20
	if age < 0.28: return 0.10
	if age < 0.35: return 0.88
	if age < 0.43: return 0.22
	if age < 0.50: return 1.12
	if age < 0.56: return 0.38
	return 1.0

func _stamp_neon_level() -> float:
	# Preserve the accepted entrance. Faults only run on the settled title/menu.
	return _neon_level if entrance_time >= ENTRANCE_DURATION else 1.0

func _idle_riot_age(seconds: float) -> float:
	var t := fposmod(seconds, 23.9)
	if t >= 4.4 and t < 4.82:
		return t - 4.4
	if t >= 16.2 and t < 16.54:
		return t - 16.2
	return -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_entrance_time(seconds: float) -> void:
	var next := clampf(seconds, 0.0, ENTRANCE_DURATION)
	if is_equal_approx(next, entrance_time):
		return
	entrance_time = next
	if next < ENTRANCE_DURATION:
		set_neon_time(0.0)
	queue_redraw()

func _width(word: String, cell: float) -> float:
	var units := -1
	for letter in word:
		units += 6 if letter == " " else 9
	return units * cell

func _pixels(word: String, origin: Vector2, cell: float, color: Color, grow := 0.0) -> void:
	var cursor := origin
	for letter in word:
		if letter == " ":
			cursor.x += cell * 6
			continue
		if letter == "N":
			_ink_rect(Rect2(cursor, Vector2(2, 10) * cell).grow(grow), color)
			_ink_rect(Rect2(cursor + Vector2(6, 0) * cell, Vector2(2, 10) * cell).grow(grow), color)
			_stroke(PackedVector2Array([Vector2(1, 0), Vector2(3, 0), Vector2(7, 10), Vector2(5, 10)]), cursor, cell, color, grow)
			cursor.x += cell * 9
			continue
		if letter == "X":
			_stroke(PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(8, 10), Vector2(6, 10)]), cursor, cell, color, grow)
			_stroke(PackedVector2Array([Vector2(6, 0), Vector2(8, 0), Vector2(2, 10), Vector2(0, 10)]), cursor, cell, color, grow)
			cursor.x += cell * 9
			continue
		var glyph: Array = GLYPHS[letter]
		for row in glyph.size():
			var col := 0
			while col < 8:
				if glyph[row][col] != "1":
					col += 1
					continue
				var start := col
				while col < 8 and glyph[row][col] == "1":
					col += 1
				_ink_rect(Rect2(cursor + Vector2(start, row) * cell, Vector2(col - start, 1) * cell).grow(grow), color)
		if letter == "R":
			_stroke(PackedVector2Array([Vector2(3, 5), Vector2(5, 5), Vector2(8, 10), Vector2(6, 10)]), cursor, cell, color, grow)
		cursor.x += cell * 9

func _stroke(points: PackedVector2Array, origin: Vector2, cell: float, color: Color, grow: float) -> void:
	for i in points.size():
		points[i] = origin + points[i] * cell
	if grow > 0.0:
		for polygon in Geometry2D.offset_polygon(points, grow, Geometry2D.JOIN_MITER):
			_ink_polygon(polygon, color)
	else:
		_ink_polygon(points, color)

func _lettering(word: String, origin: Vector2, cell: float, color: Color, outline: float) -> void:
	_pixels(word, origin + Vector2(5, 9), cell, INK, outline)
	_pixels(word, origin, cell, INK, outline)
	_pixels(word, origin, cell, color)

# Clip authored geometry, not a rasterised copy: diagonals stay straight at every
# window size. Rectangles take the cheap intersection path; only N/X/R polygons
# require edge clipping. The static logo never uses either clipping path.
func _ink_rect(rect: Rect2, color: Color) -> void:
	if _clip_enabled:
		rect = rect.intersection(_clip)
		if not rect.has_area():
			return
	draw_rect(Rect2(rect.position + _slice_offset, rect.size), color)

func _ink_polygon(points: PackedVector2Array, color: Color) -> void:
	if _clip_enabled:
		for axis in 2:
			points = _clip_edge(points, axis, _clip.position[axis], true)
			points = _clip_edge(points, axis, _clip.end[axis], false)
		# A moving clip can touch a corner exactly, producing duplicate points
		# or a zero-area sliver. Neither is a drawable polygon.
		var distinct := PackedVector2Array()
		for point in points:
			if distinct.is_empty() or point.distance_squared_to(distinct[distinct.size() - 1]) > 0.000001:
				distinct.append(point)
		if distinct.size() > 1 and distinct[0].distance_squared_to(distinct[distinct.size() - 1]) <= 0.000001:
			distinct.remove_at(distinct.size() - 1)
		points = distinct
		if points.size() < 3:
			return
		var twice_area := 0.0
		for i in range(1, points.size() - 1):
			twice_area += (points[i] - points[0]).cross(points[i + 1] - points[0])
		if absf(twice_area) < 0.001:
			return
	if not _slice_offset.is_zero_approx():
		for i in points.size():
			points[i] += _slice_offset
	draw_colored_polygon(points, color)

func _clip_edge(points: PackedVector2Array, axis: int, edge: float, keep_above: bool) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.is_empty():
		return result
	var previous := points[points.size() - 1]
	var previous_inside := previous[axis] >= edge if keep_above else previous[axis] <= edge
	for point in points:
		var inside := point[axis] >= edge if keep_above else point[axis] <= edge
		if inside != previous_inside:
			var fraction := (edge - previous[axis]) / (point[axis] - previous[axis])
			result.append(previous.lerp(point, fraction))
		if inside:
			result.append(point)
		previous = point
		previous_inside = inside
	return result

func _draw() -> void:
	_clip_enabled = false
	_slice_offset = Vector2.ZERO
	var t := entrance_time
	if t < PREFIX_START:
		return
	var prefix := Vector2((1400 - _width("NEON PIXEL", 6)) * 0.5, -8)
	_draw_prefix(prefix, t - PREFIX_START)
	if t < WORDMARK_START:
		return
	var age := t - WORDMARK_START
	var lock_in := clampf(age / WORDMARK_LOCK, 0.0, 1.0)
	var shift := roundf(pow(1.0 - lock_in, 3.0) * 90.0)
	var origin := Vector2((1400 - _width("RIOT PROTOCOL", 10.625)) * 0.5 + shift, 92)
	if effects_enabled and age < 0.52:
		_draw_wordmark_signal(origin, age)
	elif effects_enabled and t >= ENTRANCE_DURATION and _idle_riot_age(_neon_time) >= 0.0:
		_draw_wordmark_idle(origin, _idle_riot_age(_neon_time))
	else:
		if not effects_enabled and age < WORDMARK_LOCK - 0.02:
			_pixels("RIOT PROTOCOL", origin + Vector2(-12, 4), 10.625, Color(CYAN, 0.6), 2)
		_lettering("RIOT PROTOCOL", origin, 10.625, PAPER, 7)
	var edge := (1400 - _width("RIOT PROTOCOL", 10.625)) * 0.5
	draw_rect(Rect2(edge - 38, 133, 24, 7), CYAN)
	draw_rect(Rect2(1400 - edge + 14, 155, 24, 7), CYAN)
	if t < STAMP_START:
		return
	_draw_stamp(t - STAMP_START)

func _draw_prefix(origin: Vector2, age: float) -> void:
	var alpha := clampf(age / PREFIX_REVEAL, 0.0, 1.0)
	if effects_enabled:
		_draw_prefix_glow(origin, alpha)
	if age > 0.14 and age < 0.20:
		alpha = 0.28
	_lettering("NEON PIXEL", origin, 6, Color(CYAN, alpha), 4)
	if not effects_enabled or age >= 0.72:
		return
	# A single travelling charge crosses the glyph faces, with small circuit
	# runners above and below. One interruption, then stable power.
	var progress := clampf(age / 0.62, 0.0, 1.0)
	var width := _width("NEON PIXEL", 6)
	var scan_x := origin.x - 56.0 + (width + 112.0) * progress
	var fade := (1.0 - smoothstep(0.52, 0.72, age)) * smoothstep(0.0, 0.07, age)
	_clip_enabled = true
	_clip = Rect2(scan_x - 45, origin.y, 45, 60)
	_pixels("NEON PIXEL", origin, 6, Color(PAPER, fade * 0.85))
	_clip = Rect2(scan_x - 5, origin.y, 5, 60)
	_pixels("NEON PIXEL", origin, 6, Color("#ffffff") * Color(1, 1, 1, fade))
	_clip_enabled = false
	var rail_x := clampf(scan_x, origin.x, origin.x + width)
	var rail_width := minf(54.0, rail_x - origin.x)
	if rail_width > 0:
		draw_rect(Rect2(rail_x - rail_width, origin.y - 13, rail_width, 2), Color(CYAN, fade * 0.65))
		draw_rect(Rect2(rail_x - rail_width * 0.5, origin.y + 72, rail_width * 0.5, 2), Color(CYAN, fade * 0.45))
		draw_rect(Rect2(rail_x, origin.y - 15, 4, 6), Color(PAPER, fade))

func _draw_prefix_glow(origin: Vector2, power: float) -> void:
	# Low-opacity cyan falloff behind the unchanged solid glyphs and outline.
	# Once powered up it stays constant: no pulse, flicker or idle clock.
	var strength := power * prefix_glow_strength
	if strength <= 0.0:
		return
	for layer in [Vector2(18, 0.006), Vector2(14, 0.012), Vector2(11, 0.022), Vector2(8, 0.034), Vector2(6, 0.065)]:
		_pixels("NEON PIXEL", origin, 6, Color(CYAN, layer.y * strength), layer.x)

func _draw_wordmark_signal(origin: Vector2, age: float) -> void:
	# Two brief signal faults, then a smaller correction. The broad silhouette
	# stays coherent; only narrow horizontal bands move.
	var offsets := [0.0, 0.0, 0.0, 0.0]
	if age < 0.075:
		offsets = [3.0, -14.0, 10.0, -3.0]
	elif age >= 0.14 and age < 0.215:
		offsets = [-2.0, 11.0, -8.0, 2.0]
	elif age >= 0.29 and age < 0.335:
		offsets = [0.0, -4.0, 4.0, 0.0]
	var separation := roundf(13.0 * (1.0 - smoothstep(0.04, 0.39, age)))
	var channel_alpha := (1.0 - smoothstep(0.18, 0.43, age)) * 0.8
	var bands := [-20.0, 28.0, 43.0, 72.0, 132.0]
	_clip_enabled = true
	for i in 4:
		_clip = Rect2(-2000, origin.y + bands[i], 6000, bands[i + 1] - bands[i])
		_slice_offset = Vector2(offsets[i], 0)
		# Expanded dark silhouettes keep the coloured edge channels legible
		# against the existing neon city without washing out the white face.
		_pixels("RIOT PROTOCOL", origin + Vector2(-separation, 0), 10.625, INK, 7)
		_pixels("RIOT PROTOCOL", origin + Vector2(separation, 0), 10.625, INK, 7)
		_pixels("RIOT PROTOCOL", origin + Vector2(-separation, 0), 10.625, Color(CYAN, channel_alpha), 2)
		_pixels("RIOT PROTOCOL", origin + Vector2(separation, 0), 10.625, Color(PINK, channel_alpha), 2)
		_lettering("RIOT PROTOCOL", origin, 10.625, PAPER, 7)
	_clip_enabled = false
	_slice_offset = Vector2.ZERO
	# A narrow white/cyan read head completes the lock, then disappears.
	if age >= 0.22:
		var scan_y := origin.y + 106.25 * clampf((age - 0.22) / 0.28, 0, 1)
		var strength := sin(clampf((age - 0.22) / 0.30, 0, 1) * PI) * 0.55
		_clip_enabled = true
		_clip = Rect2(-2000, scan_y, 6000, 3)
		_pixels("RIOT PROTOCOL", origin, 10.625, Color(CYAN, strength))
		_clip_enabled = false

func _draw_wordmark_idle(origin: Vector2, age: float) -> void:
	# Brief interference on an otherwise static sign. Keep the lettering whole
	# and readable: the same solid glyphs move together, never warp.
	var shifted := origin + _wordmark_recoil(age)
	_draw_wordmark_blitz(shifted, age)
	var face := PAPER
	if age < 0.07 or (age >= 0.14 and age < 0.20):
		face = Color("#ffffff")
	_lettering("RIOT PROTOCOL", shifted, 10.625, face, 7)
	if age < 0.08 or (age >= 0.14 and age < 0.20):
		var y := shifted.y + (32 if age < 0.08 else 69)
		_clip_enabled = true
		_clip = Rect2(-2000, y, 6000, 4)
		_pixels("RIOT PROTOCOL", shifted, 10.625, Color(CYAN, 0.8))
		_clip_enabled = false

func _wordmark_recoil(age: float) -> Vector2:
	if age < 0.065: return Vector2(14, -5)
	if age < 0.115: return Vector2(-11, 4)
	if age < 0.17: return Vector2(8, -3)
	if age < 0.225: return Vector2(-6, 2)
	if age < 0.275: return Vector2(4, -1)
	if age < 0.32: return Vector2(-2, 0)
	return Vector2.ZERO

func _draw_wordmark_blitz(origin: Vector2, age: float) -> void:
	# Two electric discharges: tight glyph silhouettes plus clipped shards.
	# The city and the other title lines never flash.
	var flash := 0.0
	if age < 0.105:
		flash = 1.0 - age / 0.105
	elif age >= 0.14 and age < 0.245:
		flash = (1.0 - (age - 0.14) / 0.105) * 0.8
	if flash <= 0.0:
		return
	_pixels("RIOT PROTOCOL", origin + Vector2(-22, 1), 10.625, Color(CYAN, flash * 0.26), 5)
	_pixels("RIOT PROTOCOL", origin + Vector2(20, -2), 10.625, Color(PINK, flash * 0.22), 5)
	var width := _width("RIOT PROTOCOL", 10.625)
	for i in 8:
		var left := i % 2 == 0
		var y := origin.y + 8 + (i % 4) * 28
		var travel := (1.0 - flash) * 32.0
		var x := origin.x - 18 - travel if left else origin.x + width + 8 + travel
		var length := (14 + i % 3 * 13) * flash
		var p := Vector2(x - length if left else x, y)
		draw_rect(Rect2(p.round(), Vector2(length, 3 if i % 3 else 5)), Color(CYAN if left else PINK, flash * 0.9))
	# A thin discharge along the upper edge gives the shake a crisp onset.
	draw_rect(Rect2(origin.x + width * 0.19, origin.y - 15, width * 0.27 * flash, 2), Color(PAPER, flash * 0.8))
	draw_rect(Rect2(origin.x + width * 0.65, origin.y + 120, width * 0.15 * flash, 2), Color(CYAN, flash * 0.8))

func _draw_stamp(age: float) -> void:
	var progress := clampf(age / STAMP_LAND, 0.0, 1.0)
	var stamp_scale := 1.0 + pow(1.0 - progress, 3.0) * 0.45
	draw_set_transform(Vector2(700, 300), deg_to_rad(-4.0), Vector2.ONE * stamp_scale)
	var stamp_rect := Rect2(-365, -54, 730, 108)
	var impact_age := age - 0.16
	if effects_enabled and impact_age >= 0.0 and impact_age < 0.55:
		var pulse := impact_age / 0.55
		var expansion := 4.0 + (1.0 - pow(1.0 - pulse, 3.0)) * 42.0
		var opacity := pow(1.0 - pulse, 2.0)
		# Rectangular pressure wave follows the slanted stamp, not the screen.
		draw_rect(stamp_rect.grow(expansion), Color(PINK, opacity * 0.10), false, 14)
		draw_rect(stamp_rect.grow(expansion), Color(PINK, opacity * 0.65), false, 2)
		if pulse < 0.6:
			draw_rect(stamp_rect.grow(expansion * 0.48), Color(PINK, opacity * 0.32), false, 3)
	var lamp := _stamp_neon_level() if effects_enabled else 1.0
	var neon := Color("#392637").lerp(PINK, minf(lamp, 1.0))
	if lamp > 1.0:
		neon = PINK.lerp(PAPER, (lamp - 1.0) * 2.0)
		draw_rect(stamp_rect.grow(9), Color(PINK, (lamp - 1.0) * 0.36), false, 9)
	draw_rect(stamp_rect.grow(7), INK)
	draw_rect(stamp_rect, neon, false, 4)
	draw_rect(Rect2(-357, -46, 714, 92), Color("#1a122a"))
	var face := neon
	if effects_enabled and age < 0.34:
		face = PINK.lerp(PAPER, maxf(0, 1.0 - absf(age - 0.19) / 0.12) * 0.35)
	_pixels("RETRO REBEL", Vector2(-_width("RETRO REBEL", 7.3) * 0.5, -36.5), 7.3, face)
	draw_set_transform(Vector2.ZERO)
	if effects_enabled:
		_draw_override_fragments(impact_age)
	else:
		var fragment_alpha := 1.0 - clampf((age - 0.13) / 0.38, 0.0, 1.0)
		if fragment_alpha > 0:
			for i in 10:
				var direction := Vector2(-1 if i % 2 == 0 else 1, (i % 5 - 2) * 0.38)
				var p := Vector2(700, 300) + direction * (370.0 + age * 200.0) + Vector2(0, (i % 3 - 1) * 18)
				draw_rect(Rect2(p.round(), Vector2(5 + i % 3 * 3, 5)), Color(PINK, fragment_alpha))

func _draw_override_fragments(age: float) -> void:
	if age < 0 or age >= 0.62:
		return
	var progress := age / 0.62
	var travel := 1.0 - pow(1.0 - progress, 3.0)
	var alpha := pow(1.0 - progress, 1.5)
	for i in 12:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := i / 2
		var start := Vector2(700 + side * (378 + (row % 2) * 8), 300 + (row - 2.5) * 16)
		var direction := Vector2(side, (row - 2.5) * 0.24)
		var p := (start + direction * travel * (65 + row % 3 * 24)).round()
		var length := maxf(3.0, (16.0 + row % 3 * 7.0) * (1.0 - progress))
		draw_rect(Rect2(p - Vector2(length * 0.5, 0), Vector2(length, 3 + row % 2 * 2)), Color(PINK, alpha))
		if i % 3 == 0:
			draw_rect(Rect2(p + Vector2(side * 8, -6), Vector2(3, 3)), Color(PAPER, alpha * 0.8))
