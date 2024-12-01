extends Node

## This global class detects user input and stores the input status in variables.
## Other scripts can use these variables to check if specific actions are occurring.
## This simplifies input detection for common actions in the software.

#region mouse signals 

## signals that a click was just performed.
signal clicked

## signals that a right click was just performed.
signal right_clicked

## signals that a double click was just performed.
signal double_clicked

## Signals that the dragging of the mouse has started.
signal mouse_drag_started(position: Vector2)

## Signals that the mouse drag has ended at a given position.
signal mouse_drag_ended(position: Vector2)

## Signals that the mouse is being dragged.
signal mouse_dragged(position: Vector2)

## Signals that the mouse wheel has been increased.
signal mouse_wheel_increased

## Signals that the mouse wheel has been decreased.
signal mouse_wheel_decreased

#endregion	mouse signals

#region keyboard variables
signal space_bar_pressed
signal escape_key_pressed
#endregion keyboard variables

var is_dragging = false
var drag_start_position = Vector2()

func _ready() -> void:
	set_process_input(true)

func _input(event):
	detect_mouse_events(event)
	detect_keyboard_events(event)

func detect_mouse_events(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				right_clicked.emit()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				if event.double_click:
					double_clicked.emit()
				else:
					clicked.emit()
					is_dragging = true
					drag_start_position = event.position
					mouse_drag_started.emit(event.position)
			else:
				if is_dragging:
					is_dragging = false
					mouse_drag_ended.emit(event.position)

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			mouse_wheel_increased.emit()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			mouse_wheel_decreased.emit()

	elif event is InputEventMouseMotion:
		if is_dragging:
			# Handle mouse dragging logic here if needed
			mouse_dragged.emit(event.position)

func detect_keyboard_events(event):
	if event is InputEventKey:
		if event.is_pressed():
			# Handle key press logic here if needed
			if event.keycode == KEY_SPACE:
				space_bar_pressed.emit()
			if event.keycode == KEY_ESCAPE:
				escape_key_pressed.emit()
		else:
			# Handle key release logic here if needed
			pass