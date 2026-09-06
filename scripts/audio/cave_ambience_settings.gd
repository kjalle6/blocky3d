extends Resource
## Background level, independent of movement contacts and their reverb.
@export var enabled := true
@export var recording: AudioStream
## Distinguishes old mixes with a fixed drip track from an intentional empty slot.
@export var recording_configured := false
@export_range(-50.0, 0.0, 0.5) var volume_db := -6.0
