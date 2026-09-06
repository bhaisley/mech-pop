class_name NetworkInputBuffer
extends RefCounted

const MAX_BATCH: int = 16
const MAX_PENDING: int = 64
const STALE_SECONDS: float = 0.25
const MAX_QUEUED_FRAMES: int = 6
var pending: Dictionary = {}
var consumed: int = 0
var newest: int = 0
var last_arrival: float = -1.0
var held := FighterCommand.new()
var rejected: int = 0
var skipped: int = 0

static func pack(sequence: int, command: FighterCommand) -> Array:
	var bits: int = int(command.jump_pressed) | (int(command.jump_held) << 1) | (int(command.light) << 2) | (int(command.heavy) << 3) | (int(command.special) << 4) | (int(command.dodge) << 5) | (int(command.salvage) << 6)
	return [sequence, command.move.clamp(Vector2(-1, -1), Vector2.ONE), bits]

static func valid(frame: Variant) -> bool:
	if not frame is Array or frame.size() != 3: return false
	if not frame[0] is int or frame[0] < 1 or frame[0] > 2147483647: return false
	if not frame[1] is Vector2 or not frame[1].is_finite() or absf(frame[1].x) > 1.0 or absf(frame[1].y) > 1.0: return false
	return frame[2] is int and frame[2] >= 0 and frame[2] <= 127

static func unpack(frame: Array) -> FighterCommand:
	var result := FighterCommand.new()
	result.move = frame[1]
	var bits: int = frame[2]
	result.jump_pressed = bool(bits & 1)
	result.jump_held = bool(bits & 2)
	result.light = bool(bits & 4)
	result.heavy = bool(bits & 8)
	result.special = bool(bits & 16)
	result.dodge = bool(bits & 32)
	result.salvage = bool(bits & 64)
	return result

func push(frames: Array, now: float) -> bool:
	if frames.is_empty() or frames.size() > MAX_BATCH:
		rejected += 1
		return false
	# Reject the whole batch before applying any of it.
	for frame in frames:
		if not valid(frame) or int(frame[0]) > maxi(consumed, newest) + 240:
			rejected += 1
			return false
	last_arrival = now
	for frame in frames:
		var sequence: int = frame[0]
		newest = maxi(newest, sequence)
		if sequence > consumed and not pending.has(sequence):
			pending[sequence] = frame
	while pending.size() > MAX_PENDING:
		var oldest: int = pending.keys().min()
		pending.erase(oldest)
		skipped += 1
	return true

func take(now: float) -> FighterCommand:
	if last_arrival < 0.0 or now - last_arrival > STALE_SECONDS:
		pending.clear()
		consumed = newest
		held = FighterCommand.new()
		return held.copy()
	if not pending.is_empty():
		# A burst after a network stall must not leave the authority replaying
		# half a second of old movement forever. Collapse the backlog into one
		# current command, retaining recent press edges once, then leave two
		# frames for the ordinary 60 Hz packet / 120 Hz simulation cadence.
		if pending.size() > MAX_QUEUED_FRAMES:
			var sequences: Array = pending.keys()
			sequences.sort()
			var cutoff: int = int(sequences[-3])
			var combined: FighterCommand = unpack(pending[cutoff])
			for sequence in sequences:
				if int(sequence) > cutoff: break
				if int(sequence) >= newest - 30:
					var previous: FighterCommand = unpack(pending[sequence])
					combined.jump_pressed = combined.jump_pressed or previous.jump_pressed
					combined.light = combined.light or previous.light
					combined.heavy = combined.heavy or previous.heavy
					combined.special = combined.special or previous.special
					combined.dodge = combined.dodge or previous.dodge
					combined.salvage = combined.salvage or previous.salvage
				pending.erase(sequence)
				skipped += 1
			consumed = cutoff
			held = FighterCommand.new()
			held.move = combined.move
			held.jump_held = combined.jump_held
			return combined
		var next: int = pending.keys().min()
		consumed = next
		var result: FighterCommand = unpack(pending[next])
		pending.erase(next)
		held = FighterCommand.new()
		held.move = result.move
		held.jump_held = result.jump_held
		return result
	# Extrapolate held movement briefly; press edges can never fire twice.
	return held.copy()

func clear() -> void:
	pending.clear()
	consumed = newest
	held = FighterCommand.new()
	last_arrival = -1.0
