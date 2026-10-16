extends Logger
## Store game output beside the application; rotate one previous session.
const MAX_BYTES := 2 * 1024 * 1024
var file: FileAccess
var mutex := Mutex.new()
var capped := false

func open_log(path: String) -> Error:
	if FileAccess.file_exists(path):
		var error := DirAccess.copy_absolute(path,path.get_base_dir().path_join("game.previous.log"))
		if error != OK: return error
	file = FileAccess.open(path,FileAccess.WRITE)
	return FileAccess.get_open_error() if file == null else OK

func _log_message(message: String, error: bool) -> void:
	write_line(("ERROR " if error else "")+message)

func _log_error(function: String, source_file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	write_line("ERROR %d: %s %s [%s:%d %s]" % [error_type,code,rationale,source_file,line,function])

func write_line(message: String) -> void:
	mutex.lock()
	if file != null and not capped:
		if file.get_position() >= MAX_BYTES:
			file.store_line("Log limit reached for this session.")
			capped = true
		else:
			file.store_line(Time.get_datetime_string_from_system()+" "+message.left(16384).strip_edges())
		file.flush()
	mutex.unlock()

func close_log() -> void:
	mutex.lock()
	if file != null: file.close();file = null
	mutex.unlock()
