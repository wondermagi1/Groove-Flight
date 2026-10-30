extends Node
## A separate offline process keeps decoding/model inference off Godot's UI.
signal completed(result: Dictionary)
var running: bool=false
var progress: float=0.
var message: String=""
var process_id: int=-1
var job_path: String=""
var started_at: int=0
var elapsed: float=0.
var _poll: float=0.

func begin(path: String,options: Dictionary={},test_mode: bool=false) -> bool:
	cancel()
	var helper=ProjectSettings.globalize_path("res://tools/audio_recognizer/BeatDriftTranscribe/BeatDriftTranscribe.exe")
	if OS.has_feature("standalone") and not FileAccess.file_exists(helper):
		helper=OS.get_executable_path().get_base_dir().path_join("tools/audio_recognizer/BeatDriftTranscribe/BeatDriftTranscribe.exe")
	if not FileAccess.file_exists(helper):
		completed.emit({"ok":false,"error":"本地识谱组件缺失，请重新运行 tools/build_audio_recognizer.py 构建组件。"}); return false
	var base="res://work/transcription-jobs" if test_mode else "user://transcription"
	job_path=ProjectSettings.globalize_path(base.path_join("%d-%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]))
	if DirAccess.make_dir_recursive_absolute(job_path)!=OK:
		completed.emit({"ok":false,"error":"无法建立音频识别的临时目录。"}); return false
	var request=options.duplicate(true); request.path=path
	var file=FileAccess.open(job_path.path_join("request.json"),FileAccess.WRITE)
	if file==null:
		completed.emit({"ok":false,"error":"无法保存识别参数。"}); return false
	file.store_string(JSON.stringify(request)); file.close()
	process_id=OS.create_process(helper,PackedStringArray(["--request",job_path.path_join("request.json"),"--output",job_path.path_join("result.json"),"--status",job_path.path_join("status.json")]),false)
	if process_id<=0:
		completed.emit({"ok":false,"error":"无法启动本地音频识别组件。"}); return false
	running=true; progress=0.; message="正在启动本地识谱……"; started_at=Time.get_ticks_msec(); elapsed=0.; _poll=0.
	return true

func cancel() -> void:
	if running and process_id>0 and OS.is_process_running(process_id):
		# Directory packaging runs in one process and needs no temp DLL extraction.
		OS.kill(process_id)
	running=false; process_id=-1; progress=0.; message="已取消识别；原曲谱保留。"

func _process(delta: float) -> void:
	if not running: return
	elapsed=(Time.get_ticks_msec()-started_at)*.001
	_poll+=delta
	if _poll<.15: return
	_poll=0.
	if elapsed>600:
		cancel(); completed.emit({"ok":false,"error":"本次识别超过10分钟，已停止。请缩短片段再试。"}); return
	var status_path=job_path.path_join("status.json")
	if FileAccess.file_exists(status_path):
		var status=JSON.parse_string(FileAccess.get_file_as_string(status_path))
		if status is Dictionary:
			progress=clampf(float(status.get("progress",0.)),0.,1.); message=str(status.get("message","识别中"))
	if OS.is_process_running(process_id): return
	running=false; process_id=-1
	var file=FileAccess.open(job_path.path_join("result.json"),FileAccess.READ)
	if file==null or file.get_length()>4*1024*1024:
		completed.emit({"ok":false,"error":"识谱组件未返回有效结果；原曲谱保留。"}); return
	var result=JSON.parse_string(file.get_as_text())
	if not result is Dictionary:
		completed.emit({"ok":false,"error":"识谱结果无法读取；原曲谱保留。"}); return
	completed.emit(result)

func _exit_tree() -> void: cancel()
