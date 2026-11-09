extends Logger
## Counts GDScript runtime errors (e.g. null access) so the runner can fail a test that
## crashed half-way instead of reporting it as passed.

var script_errors := 0
var last_message := ""


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_SCRIPT:
		script_errors += 1
		last_message = "%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line]


func _log_message(message: String, error: bool) -> void:
	pass
