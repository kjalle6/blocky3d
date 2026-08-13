class_name DressingPalette
extends Resource
## A deliberately small palette of assets approved for one visual language.

@export var palette_id: StringName
@export var assets: Array[DressingAssetDefinition] = []


func asset(asset_id: StringName) -> DressingAssetDefinition:
	for definition in assets:
		if definition != null and definition.asset_id == asset_id:
			return definition
	return null


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	if palette_id.is_empty():
		errors.append("Dressing palette requires an id.")
	for definition in assets:
		if definition == null:
			errors.append("Dressing palette '%s' contains a null asset." % palette_id)
			continue
		for error in definition.validation_errors():
			errors.append(error)
		if ids.has(definition.asset_id):
			errors.append("Duplicate dressing asset id '%s'." % definition.asset_id)
		ids[definition.asset_id] = true
	return errors
