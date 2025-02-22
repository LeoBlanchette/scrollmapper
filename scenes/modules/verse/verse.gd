extends MarginContainer

class_name Verse

#region base properties
@export_group("Main Verse Properties")
@export var verse_id: int
@export var book_id: int
@export var chapter: int
@export var verse: int
@export var text: String
@export var book_name: String
@export var translation_id: int
@export var translation_abbr: String
@export var title: String
@export var license: String
@export var translation: Dictionary
@export var book: Dictionary
@export var copy_text: String
#endregion

#region exported properties
@export_group("Object References")
@export var scripture_reference: RichTextLabel
@export var scripture_text: RichTextLabel
@export var actions_buttons: AspectRatioContainer
@export var button_action_context: Button 
@export var button_action_cross_reference: Button 
@export var button_action_copy: Button 
@export var button_action_add_to_export_list: Button 
@export var button_action_to_work_station: Button 
@export var hover_sensor: Area2D
@export var hover_sensor_collision: CollisionShape2D 
@export var action_backdrop: Panel 
@export var add_verse_to_set_texture:Texture2D
@export var remove_verse_from_set_texture:Texture2D
#endregion

#region type adjustment
@export_group("Context Adjustment")
var verse_type: Types.VerseType = Types.VerseType.BASIC
@export var meta_info_top: MarginContainer
@export var meta_info_bottom: MarginContainer 
@export var meta_info_top_text: RichTextLabel
@export var meta_info_bottom_text: RichTextLabel 
#endregion

#region cross reference variables
@export_group("Cross Reference Properties")
@export var cross_reference_id: int
@export var from_book: String
@export var from_chapter: int
@export var from_verse: int
@export var to_book: String
@export var to_chapter_start: int
@export var to_chapter_end: int
@export var to_verse_start: int
@export var to_verse_end: int
@export var votes: int
#endregion

#region signals
signal button_pressed
signal button_action_add_to_export_list_pressed(verse:Verse)
#endregion 

func _ready() -> void:
	hover_sensor.mouse_entered.connect(show_actions_buttons)
	hover_sensor.mouse_exited.connect(hide_actions_buttons)
	visibility_changed.connect(set_hover_sensor_size)
	resized.connect(set_hover_sensor_size)
	
	button_action_copy.pressed.connect(copy_text_to_clipboard)
	button_action_cross_reference.pressed.connect(request_cross_references)
	button_action_context.pressed.connect(request_context)
	button_action_add_to_export_list.pressed.connect(emit_button_action_add_to_export_list_pressed)
	button_action_to_work_station.pressed.connect(send_to_workstation)

	button_action_copy.pressed.connect(emit_button_pressed)
	button_action_cross_reference.pressed.connect(emit_button_pressed)
	button_action_context.pressed.connect(emit_button_pressed)
	button_action_to_work_station.pressed.connect(emit_button_pressed)

	hide_actions_buttons()
	

func initiate_from_json(verse_data: Dictionary, verse_type: Types.VerseType = Types.VerseType.BASIC) -> void:
	verse_id = verse_data.get("verse_id", -1)
	book_id = verse_data.get("book_id", -1)
	chapter = verse_data.get("chapter", -1)
	verse = verse_data.get("verse", -1)
	text = verse_data.get("text", "")
	book_name = verse_data.get("book_name", "")
	translation_id = verse_data.get("translation_id", -1)
	translation_abbr = verse_data.get("translation_abbr", "")
	title = verse_data.get("title", "")
	license = verse_data.get("license", "")
	translation = verse_data.get("translation", {})
	book = verse_data.get("book", {})
	copy_text = "%s %s:%s - %s" % [book_name, str(chapter), str(verse), text]
	self.verse_type = verse_type
	set_object_name()
	match verse_type:
		Types.VerseType.BASIC:
			hide_meta_info()
		Types.VerseType.CROSS_REFERENCE:
			convert_to_cross_reference(verse_data)
		Types.VerseType.MINIMAL:
			hide_meta_info()
		Types.VerseType.VX_LISTING:
			hide_meta_info()
			conver_to_vx_listing()

func set_object_name() -> void:
	name = "%s_%s-%s" % [book_name, str(chapter), str(verse)]

func set_hover_sensor_size() -> void:
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(size.x, size.y)
	hover_sensor_collision.position.x = size.x / 2
	hover_sensor_collision.position.y = size.y / 2
	hover_sensor_collision.shape = rect_shape

func set_scripture_reference() -> void:
	scripture_reference.bbcode_text = "[b]%s %s:%s[/b]" % [book_name, str(chapter), str(verse)]

func set_scripture_text() -> void:
	scripture_text.bbcode_text = text

func show_actions_buttons() -> void:
	action_backdrop.show()
	actions_buttons.show()

func hide_actions_buttons() -> void:
	action_backdrop.hide()
	actions_buttons.hide()

func hide_meta_info() -> void:
	meta_info_top.hide()
	meta_info_bottom.hide()

#region button commands
func copy_text_to_clipboard() -> void:
	DisplayServer.clipboard_set(copy_text)

func request_cross_references() -> void:
	ScriptureService.request_cross_references(translation_abbr, book_name, chapter, verse)

func request_context() -> void:
	pass

## This will send a verse request on behalf of the workstation it is associated with.
func send_to_workstation() -> void:
	var meta:Dictionary = {}
	match verse_type:
		Types.VerseType.BASIC:
			pass
		Types.VerseType.CROSS_REFERENCE:
			meta = ScriptureService.apply_verse_meta(self, {"work_space": "vx"})
			ScriptureService.initiate_verse_search(translation_abbr, book_name, chapter, verse, meta)
		Types.VerseType.MINIMAL:
			pass
		Types.VerseType.VX_LISTING:
			meta = ScriptureService.apply_verse_meta(self, {"work_space": "vx"})
			ScriptureService.initiate_verse_search(translation_abbr, book_name, chapter, verse, meta)
#endregion

#region verse type conversions
func convert_to_cross_reference(verse_data: Dictionary) -> void:
	verse_type = Types.VerseType.CROSS_REFERENCE
	button_action_context.hide()
	button_action_cross_reference.hide()
	meta_info_top.show()
	cross_reference_id = verse_data.get("cross_reference_id", -1)
	from_book = verse_data.get("from_book", "")
	from_chapter = verse_data.get("from_chapter", -1)
	from_verse = verse_data.get("from_verse", -1)
	to_book = verse_data.get("to_book", "")
	to_chapter_start = verse_data.get("to_chapter_start", -1)
	to_chapter_end = verse_data.get("to_chapter_end", -1)
	to_verse_start = verse_data.get("to_verse_start", -1)
	to_verse_end = verse_data.get("to_verse_end", -1)
	votes = verse_data.get("votes", 0)
	var meta_values: Array = [
		from_book, 
		str(from_chapter), 
		str(from_verse), 
		to_book, 
		str(to_chapter_start), 
		str(to_verse_start), 
		to_book,
		str(to_chapter_end), 
		str(to_verse_end), 
		str(votes)
	]
	if is_extended_cross_reference():
		var meta_info: String = "%s %s:%s -> %s %s:%s-%s %s:%s   [Votes: %s]" % meta_values
		meta_info_top_text.bbcode_text = meta_info
	else:
		meta_values = meta_values.slice(0, 6) + meta_values.slice(9, 10)
		var meta_info: String = "%s %s:%s -> %s %s:%s   [Votes: %s]" % meta_values
		meta_info_top_text.bbcode_text = meta_info
	meta_info_bottom.hide() # hide the bottom meta info
	button_action_add_to_export_list.queue_free()

func conver_to_vx_listing():
	button_action_cross_reference.queue_free()
	button_action_context.queue_free()

func is_extended_cross_reference() -> bool:
	return to_chapter_start != to_chapter_end or to_verse_start != to_verse_end
#endregion

#region signal propagation
## This is emitted ONLY for the buttons that will cause search results to close. 
func emit_button_pressed():
	button_pressed.emit()

## Emitted for when the Add Verse button is pressed, which is created for adding 
## multiple verses to a set before exporting to a workstation.
func emit_button_action_add_to_export_list_pressed():
	button_action_add_to_export_list_pressed.emit(self)


#endregion

#region icons
## This changes the icon on the "add" button of the verse.
## True means to activate the "+" version of hte icon. False means 
## to activate the "x" version of the icon.
func set_add_remove_verse_icon(add:bool = true)->void:
	if add:
		button_action_add_to_export_list.icon = add_verse_to_set_texture
	else:
		button_action_add_to_export_list.icon = remove_verse_from_set_texture

## Automatically triggers the button_action_add_to_export_list button.
## Programatically activates the button_action_add_to_export_list button.
func activate_button_action_add_to_export_list(activate: bool) -> void:
	button_action_add_to_export_list.pressed.emit()

#endregion 

#region misc

#endregion 
