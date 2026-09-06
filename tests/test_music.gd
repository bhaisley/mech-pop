extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var director := SoundDirector.new()
	root.add_child(director)
	var seen: Array[String] = []
	for id in StageCatalog.IDS:
		var stage: StageData = StageCatalog.stage(id)
		if not ResourceLoader.exists(stage.music):
			failures.append("Missing music: " + stage.music)
			continue
		if seen.has(stage.music): failures.append("Reused arena theme: " + stage.music)
		seen.append(stage.music)
		var stream: AudioStream = load(stage.music)
		if stream.get_length() < 60 or stream.get_length() > 120: failures.append("Unexpected loop length: " + stage.music)
		director.music.stream = stream
		director._loop_music()
		if stream is AudioStreamOggVorbis and not stream.loop: failures.append("Vorbis loop not enabled")
		if stream is AudioStreamWAV and stream.loop_mode != AudioStreamWAV.LOOP_FORWARD: failures.append("WAV loop not enabled")
		# Major combat events duck the transport; they must not replace/restart it.
		director._on_event(&"part_pop", {})
		if director.music.stream != stream or director.duck < 4: failures.append("Combat interrupted music transport")
		director.stop_all()
		if director.music.stream != null: failures.append("Music remained retained after stop")
	print("MUSIC TESTS: five distinct arena loops; failures=", failures)
	director.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
