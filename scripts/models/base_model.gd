extends Node

class_name BaseModel

const CMD_STYLE_APP = "res://addons/cmd/interface/styles/cmd_styles/cmd_style_app.tres"
const CMD_STYLE_EDITOR = "res://addons/cmd/interface/styles/cmd_styles/cmd_style_editor.tres"

var cmd_style: CmdStyle = null

var db: SQLite = null

func _init() -> void:
	if not Engine.is_editor_hint():
		cmd_style = load(CMD_STYLE_APP)
	else:
		cmd_style = load(CMD_STYLE_EDITOR)
	if not Engine.is_editor_hint():
		db = GlobalDB.get_db()
	else:
		# We are in editor.
		db = CMDEditor.get_db()

func execute_query(query: String, params: Array = []):
	db.query_with_bindings(query, params)
	

func get_results(query: String, params: Array = []):
	db.query_with_bindings(query, params)
	var results = []
	for result in db.query_result:
		results.append(result)
	if db.error_message != "":
		print("Error executing query: %s" % db.error_message)
	return results

func create_table():
	var create_table_query = get_create_table_query()
	execute_query(create_table_query)

func get_create_table_query() -> String:
	return ""  # To be overridden by subclasses
