extends SceneTree
## Writes every procedural sound effect to tools/out/sfx/*.wav for listening.
##   godot --headless --path . -s res://tools/export_sfx.gd
func _init() -> void:
	var bank := SoundBank.new()
	root.add_child(bank)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/out/sfx"))
	for id: String in bank._streams:
		(bank._streams[id] as AudioStreamWAV).save_to_wav(ProjectSettings.globalize_path("res://tools/out/sfx/%s.wav" % id))
		print("wrote ", id)
	quit()
