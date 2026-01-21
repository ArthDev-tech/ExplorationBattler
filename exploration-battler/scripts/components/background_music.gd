extends AudioStreamPlayer

## Background music player that randomly selects from available tracks and loops them.

var _music_tracks: Array[String] = [
	"res://audio/music/SimpleBG1.mp3",
	"res://audio/music/SimpleBG2.mp3"
]

func _ready() -> void:
	# Keep music playing even when game is paused (menus/battles)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if _music_tracks.is_empty():
		push_warning("BackgroundMusic: No music tracks configured")
		return
	
	# Pick a random track
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var selected_track: String = _music_tracks[rng.randi_range(0, _music_tracks.size() - 1)]
	
	var stream_resource: AudioStream = load(selected_track)
	if not stream_resource:
		push_warning("BackgroundMusic: Failed to load track: " + selected_track)
		return
	
	stream = stream_resource
	autoplay = true
	
	# Explicitly call play() to ensure music starts (setting autoplay in code doesn't always trigger)
	if stream:
		play()
		print("BackgroundMusic: Started playing track: ", selected_track)
	else:
		push_warning("BackgroundMusic: Stream is null after assignment")
	
	# Connect finished signal to loop
	finished.connect(_on_finished)

func _on_finished() -> void:
	# Loop the same track
	if stream:
		play()
