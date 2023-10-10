extends GridContainer


# Config
const CONFIG_PATH = "user://config.cfg"
var config = ConfigFile.new()
onready var config_save_bounce_timer = $ConfigSaveBounceTimer
# GUI
onready var threshold_slider: HSlider = $Params/Container/ThresholdSlider
onready var threshold_value: Label = $Params/Container/ThresholdValue
onready var delay_slider: HSlider = $Params/Container/DelaySlider
onready var delay_value: Label = $Params/Container/DelayValue
onready var microphone_icon: TextureRect = $MicrophoneIcon
onready var speaker_icon: TextureRect = $SpeakerIcon
# Function
onready var out_player: AudioStreamPlayer = $AudioOut
var check_effect: AudioEffectCapture = AudioServer.get_bus_effect(AudioServer.get_bus_index("In"), 0)
var record_effect: AudioEffectRecord = AudioServer.get_bus_effect(AudioServer.get_bus_index("In"), 1)
var record_all_effect: AudioEffectRecord = AudioServer.get_bus_effect(AudioServer.get_bus_index("In"), 2)
onready var stop_recording_timer: Timer = $StopRecordingTimer


func _ready() -> void:
	# Load config
	print("Load config...")
	config.load(CONFIG_PATH)
	threshold_slider.value = config.get_value("Last", "threshold", 0.05)
	delay_slider.value = config.get_value("Last", "delay", 0.5)
	# Init record
	print("Init record...")
	record_all_effect.set_recording_active(true)
	# Init orientation change
	_on_size_changed()
	# warning-ignore:return_value_discarded
	get_viewport().connect("size_changed", self, "_on_size_changed")


func _exit_tree() -> void:
	# Save record
	var os_name = OS.get_name()
	if not (os_name == "Windows" or os_name == "OSX" or os_name == "X11" or os_name == "Android"):
		print("Session save not supported on this OS.")
		return
	print("Save session...")
	var dir_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var dir = Directory.new()
	dir.open(dir_path)
	if not dir.dir_exists("AudioRepeaterRecords"):
		dir.make_dir("AudioRepeaterRecords")
	dir.open("%s/AudioRepeaterRecords" % dir_path)
	var i: int = 1
	while dir.file_exists("record%d.wav" % i):
		i += 1
	# warning-ignore:return_value_discarded
	record_all_effect.get_recording().save_to_wav("%s/AudioRepeaterRecords/record%d.wav" % [dir_path, i])


func _physics_process(_delta: float) -> void:
	var stop = -1
	var current_frames = check_effect.get_buffer(check_effect.get_frames_available())
	for sample in current_frames:
		if (sample.x + sample.y) > threshold_slider.value and not out_player.playing:
			stop = 0
			if not record_effect.is_recording_active():
				record_effect.set_recording_active(true)
			break
		elif record_effect.is_recording_active():
			stop = 1
	if stop == 1:
		if stop_recording_timer.is_stopped():
			stop_recording_timer.start(delay_slider.value)
	elif stop == 0:
		stop_recording_timer.stop()
	microphone_icon.modulate = Color.green if record_effect.is_recording_active() else Color.white
	speaker_icon.modulate = Color.green if out_player.playing else Color.white


func _on_stop_recording_timer_timeout() -> void:
	out_player.stream = record_effect.get_recording()
	record_effect.set_recording_active(false)
	out_player.play()


func _on_threshold_slider_value_changed(value: float) -> void:
	threshold_value.text = str(value)
	config_save_bounce_timer.start()


func _on_delay_slider_value_changed(value: float) -> void:
	delay_value.text = str(value)
	config_save_bounce_timer.start()


func _on_size_changed():
	if rect_size.x < rect_size.y:
		columns = 1
	else:
		columns = 4
	queue_sort()


func _save_config() -> void:
	# Save config
	print("Save config...")
	config.set_value("Last", "threshold", threshold_slider.value)
	config.set_value("Last", "delay", delay_slider.value)
	config.save(CONFIG_PATH)


func _on_rich_text_meta_clicked(meta) -> void:
	print("Opening meta ", meta, "...")
	OS.shell_open(meta)
