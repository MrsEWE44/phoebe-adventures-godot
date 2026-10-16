extends Node
## Portable game-owned data. Never write saves/settings back to the legacy user directory.
const MIGRATION_MARKER := "migration_v1.json"
var data_root := ""
var last_error := ""
var logger: Logger

static func resolve_data_root(editor_build: bool, project_directory: String, executable: String) -> String:
	return (project_directory if editor_build else executable.get_base_dir()).path_join("Data").simplify_path()

static func script_run() -> bool:
	return OS.get_cmdline_args().has("--script") or OS.get_cmdline_args().has("-s")

func _ready() -> void:
	data_root = resolve_data_root(OS.has_feature("editor"), ProjectSettings.globalize_path("res://"), OS.get_executable_path())
	# Tests opt in with a temporary root and must never migrate the real player's data.
	if script_run(): return
	if initialize(data_root, ProjectSettings.globalize_path("user://")) != OK:
		show_storage_error.call_deferred()

func save_file() -> String:
	return data_root.path_join("Saves/campaign_v1.json")

func settings_file() -> String:
	return data_root.path_join("Settings/audio_settings.cfg")

func initialize(destination: String, legacy_directory: String, enable_logging := true) -> Error:
	data_root = destination.simplify_path()
	last_error = ""
	for folder in ["", "Saves", "Settings", "Backups", "Logs"]:
		var error := DirAccess.make_dir_recursive_absolute(data_root.path_join(folder))
		if error != OK: return fail("无法创建数据目录："+data_root.path_join(folder),error)
	var ignore := FileAccess.open(data_root.path_join(".gdignore"), FileAccess.WRITE)
	if ignore == null: return fail("无法写入数据目录："+data_root,FileAccess.get_open_error())
	ignore.close()
	var migration_error := migrate_legacy(legacy_directory)
	if migration_error != OK: return migration_error
	if enable_logging:
		logger = preload("res://Scence/portable_logger.gd").new()
		var error: Error = logger.open_log(data_root.path_join("Logs/game.log"))
		if error != OK: return fail("无法创建运行日志",error)
		OS.add_logger(logger)
		print("Game data directory: ",data_root)
	return OK

func migrate_legacy(legacy_directory: String) -> Error:
	var marker := data_root.path_join(MIGRATION_MARKER)
	if FileAccess.file_exists(marker): return OK
	var copied: Array[String] = []
	var source := legacy_directory.simplify_path()
	# A local primary OR backup means this installation already owns its progress.
	if not FileAccess.file_exists(save_file()) and not FileAccess.file_exists(save_file()+".bak"):
		for suffix in ["", ".bak"]:
			var error := copy_if_missing(source.path_join("campaign_v1.json"+suffix),save_file()+suffix,copied)
			if error != OK: return error
	var settings_error := copy_if_missing(source.path_join("audio_settings.cfg"),settings_file(),copied)
	if settings_error != OK: return settings_error
	var directory := DirAccess.open(source)
	if directory != null:
		for filename in directory.get_files():
			if filename.begins_with("campaign_v1.json.before-") and filename.ends_with(".bak"):
				var error := copy_if_missing(source.path_join(filename),data_root.path_join("Backups").path_join(filename),copied)
				if error != OK: return error
	var file := FileAccess.open(marker+".tmp",FileAccess.WRITE)
	if file == null: return fail("无法保存迁移记录",FileAccess.get_open_error())
	file.store_string(JSON.stringify({"version":1,"created_at":Time.get_datetime_string_from_system(),"legacy_source":source,"copied":copied},"\t"))
	file.flush()
	file.close()
	var error := DirAccess.rename_absolute(marker+".tmp",marker)
	if error != OK: return fail("无法完成迁移记录",error)
	return OK

func copy_if_missing(source: String, destination: String, copied: Array[String]) -> Error:
	if not FileAccess.file_exists(source) or FileAccess.file_exists(destination): return OK
	# Copy to a staging name so an interrupted migration cannot leave a partial save.
	var error := DirAccess.copy_absolute(source,destination+".migrating")
	if error != OK: return fail("无法迁移旧数据："+source,error)
	error = DirAccess.rename_absolute(destination+".migrating",destination)
	if error != OK: return fail("无法完成旧数据迁移："+destination,error)
	copied.append(destination.trim_prefix(data_root+"/"))
	return OK

func fail(text: String, error: Error) -> Error:
	last_error = text+"（"+error_string(error)+"）"
	push_error(last_error)
	return error

func show_storage_error() -> void:
	OS.alert(last_error+"\n请将游戏放在可写入的文件夹后重试。数据不会改存到系统目录。", "游戏数据目录不可写入")

func _exit_tree() -> void:
	if logger != null:
		OS.remove_logger(logger)
		logger.close_log()
		logger = null
