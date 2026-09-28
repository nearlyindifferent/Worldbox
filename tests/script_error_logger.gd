class_name ScriptErrorLogger
extends Logger
## Counts script errors so the test runner can fail a test whose body was aborted
## by a runtime error (GDScript otherwise just returns and the test looks green).

var script_errors: int = 0
var last_message := ""


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_SCRIPT:
		script_errors += 1
		last_message = "%s (%s:%d in %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]


func _log_message(_message: String, _error: bool) -> void:
	pass
