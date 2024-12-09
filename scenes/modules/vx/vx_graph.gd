extends Node
class_name VXGraph

const VX_NODE = preload("res://scenes/modules/vx/vx_node.tscn")
const VX_CONNECTION = preload("res://scenes/modules/vx/vx_connection.tscn")

static var instance:VXGraph = null
static var current_focused_socket:VXSocket = null
static var is_graph_locked:bool = false

## The main "Active Node" selected.
var selected_node:VXNode = null
## Additional nodes added via shift-click.
var selected_nodes:Array[VXNode] = []

#region connected nodes

@export var vx_canvas:VXCanvas
@export var vx_editor:VXEditor
@export var vx_search_results: MarginContainer 
@export var camera_2d:Camera2D

@export var nodes_info: RichTextLabel
@export var connections_info: RichTextLabel 
@export var feed_back_notes: RichTextLabel

#endregion 

## An important dictionary for tracking vx_nodes.
## {node_id: VXNode}
@export var vx_nodes:Dictionary = {}

## An important dictionary for tracking vx_connections.
## {connection_id: VXConnection}
@export var vx_connections:Dictionary = {}

signal graph_changed

func _ready():
	if VXGraph.instance == null:
		VXGraph.instance = self
	else:
		queue_free()
	ScriptureService.verses_searched.connect(_on_verses_searched)
	graph_changed.connect(_on_graph_changed)
	vx_search_results.search_results_toggled.connect(lock_graph)
	

func _exit_tree() -> void:
	VXGraph.instance = null


## Locks the graph if the search results are shown.
func lock_graph(lock:bool) -> void:
	is_graph_locked = lock

## Pushes a message to the feed_back_notes.
func print_feedback_note(note:String) -> void:
	if note.is_empty():
		return
	print(note)
	feed_back_notes.text = note
	await get_tree().create_timer(5.0).timeout
	feed_back_notes.text = ""

## Adds a node to the vx_nodes dictionary.
func add_vx_node(node: VXNode) -> void:
	if node == null:
		push_error("Cannot add a null node.")
		return
	if node.get_node_id() in vx_nodes:
		node.delete_node()
		return
	vx_nodes[node.get_node_id()] = node
	graph_changed.emit()

## Removes a node from the vx_nodes dictionary.
func remove_vx_node(node: VXNode) -> void:
	if node == null:
		push_error("Cannot remove a null node.")
		return
	if node.get_node_id() not in vx_nodes:
		push_error("Node is not found.")
		return
	vx_nodes.erase(node.get_node_id())
	graph_changed.emit()

## Adds a connection to the vx_connections dictionary.
func add_vx_connection(connection: VXConnection) -> void:
	if connection == null:
		push_error("Cannot add a null connection.")
		return
	if connection.get_connection_id() in vx_connections:
		push_error("Connection is already added.")
		return
	vx_connections[connection.get_connection_id()] = connection
	graph_changed.emit()

## Removes a connection from the vx_connections dictionary.
func remove_vx_connection(connection: VXConnection) -> void:
	if connection == null:
		return
	if connection.get_connection_id() not in vx_connections:
		return
	if connection.id == -1:
		print("Connection ID is -1")
		return
	vx_connections.erase(connection.get_connection_id())
	graph_changed.emit()

## Checks if a node with the given ID exists in the vx_nodes dictionary.
func has_node_id(node_id: int) -> bool:
	return node_id in vx_nodes

## Checks if a connection with the given ID exists in the vx_connections dictionary.
func has_connection_id(connection_id: int) -> bool:
	return connection_id in vx_connections

## Gets the main 2d camera of the VX scene.
static func get_camera_2d()->Camera2D:
	return VXGraph.instance.camera_2d

## Gets the main VXGraph of the VX scene.
static func get_instance() -> VXGraph:
	return VXGraph.instance

## Creates a connection between two sockets.
func create_connection(start_socket:VXSocket, end_socket:VXSocket = null) -> VXConnection:
	var vx_connection:VXConnection = VX_CONNECTION.instantiate()
	vx_canvas.add_child(vx_connection)
	vx_connection.initiate(start_socket, end_socket)	
	return vx_connection

## Creates a node and adds it to the vx_canvas.
func create_node() -> VXNode:
	var vx_node:VXNode = VX_NODE.instantiate()
	vx_canvas.add_child(vx_node)
	vx_node.node_selected.connect(move_node_to_front)
	vx_node.node_selected.connect(set_selected_node)
	vx_node.node_dragged.connect(move_node_set)
	vx_node.node_selected_plus.connect(add_node_to_selection_set)
	return vx_node

## Main function to select in this class and on the node. 
func set_selected_node(node:VXNode) -> void:
	if selected_node != null:
		selected_node.is_selected = false
	selected_node = node
	selected_node.is_selected = true
	print_feedback_note("Selected node: " + str(node.get_verse_string()))

## Adds a node to the selection set. 
## If the node is already in the selection set, it will be removed.
func add_node_to_selection_set(node:VXNode) -> void:
	if node in selected_nodes:
		selected_nodes.erase(node)
	else:
		selected_nodes.append(node)
	print(selected_nodes)

## Clears the selection set.
func clear_selection_set() ->void:
	selected_nodes = []

## Moves the set of nodes relative to the selected node.
func move_node_set(pos:Vector2) -> void:
	var drag_start_position_global:Vector2 = vx_editor.starting_drag_position_global
	var current_mouse_position:Vector2 = camera_2d.get_global_mouse_position()
	for node:VXNode in selected_nodes:
		if node.id == selected_node.id:
			continue
		var mouse_offset:Vector2 = current_mouse_position - drag_start_position_global
		var final_position:Vector2 = node.last_set_global_position + mouse_offset
		node.move_node(final_position)

func move_node_to_front(node:VXNode) -> void:
	node.move_to_front()

## When the scripture service pushes a result, it will be caught here
## and a new node will be created. 
func _on_verses_searched(results:Array):
	for result in results:
		if vx_nodes.has(result["verse_id"]):
			continue # Avoid duplicates
		# Ensure the result has "work_space" and it is "vx".
		if not result.has("meta"):
			continue
		if not result["meta"].has("work_space"):
			continue
		if result["meta"]["work_space"] != "vx":
			continue
		var node:VXNode = create_node()
		node.initiate(
			result["verse_id"],
			result["book_name"],
			result["chapter"],
			result["verse"],
			result["text"],
			result["translation_abbr"]
		)
		await get_tree().process_frame
		node.move_node(vx_editor.get_cursor_position())
		if not result["meta"].has("socket_direction"):
			set_selected_node(node)
			return
		match result["meta"]["socket_direction"]:
			"SEPARATE":
				# Handle SEPARATE socket direction
				pass
			"LINEAR":
				connect_node_linear(node)
			"PARALLEL":
				connect_node_parallel(node)
				arrange_node_positions()
				pass

## Connects two nodes in a parallel fashion.
func connect_node_parallel(node:VXNode) -> void:
	if selected_node == null:
		set_selected_node(node)
		return	
	if node.get_node_id() > selected_node.get_node_id():
		node.move_node(selected_node.position + Vector2(selected_node.size.x + 100, 0))
		var output_socket_selected_node = selected_node.get_empty_socket(Types.SocketType.OUTPUT, Types.SocketDirectionType.PARALLEL)
		var input_socket_target_node = node.get_empty_socket(Types.SocketType.INPUT, Types.SocketDirectionType.PARALLEL)
		connect_node_sockets(output_socket_selected_node, input_socket_target_node)
		set_selected_node(output_socket_selected_node.connected_node)
	else:
		node.move_node(selected_node.position - Vector2(node.size.x + 100, 0))
		var output_socket_target_node = node.get_empty_socket(Types.SocketType.OUTPUT, Types.SocketDirectionType.PARALLEL)
		var input_socket_selected_node = selected_node.get_empty_socket(Types.SocketType.INPUT, Types.SocketDirectionType.PARALLEL)
		connect_node_sockets(output_socket_target_node, input_socket_selected_node)
		set_selected_node(input_socket_selected_node.connected_node)

## Connects two nodes in a linear fashion.
func connect_node_linear(node:VXNode) -> void:
	if selected_node == null:
		set_selected_node(node)
		return
	node.move_node(selected_node.position+Vector2(0, node.size.y + 100))
	var output_socket_selected_node = selected_node.get_empty_socket(Types.SocketType.OUTPUT, Types.SocketDirectionType.LINEAR)
	var input_socket_target_node = node.get_empty_socket(Types.SocketType.INPUT, Types.SocketDirectionType.LINEAR)
	connect_node_sockets(output_socket_selected_node, input_socket_target_node)
	set_selected_node(input_socket_target_node.connected_node)

## IMPORTANT FUNCTION -- Connects nodes by their sockets independent of mouse drag / drop operations
## Basically it is the programatic way of connecting two nodes. 
func connect_node_sockets(start_socket:VXSocket, end_socket:VXSocket) -> void:
	var connection:VXConnection = create_connection(start_socket, end_socket)
	current_focused_socket = end_socket 
	connection.do_socket_connections()
	

## When the graph changes, this function will be called.
func _on_graph_changed()->void:
	await get_tree().process_frame # avoiding race conditions
	update_node_info_text()
	update_connection_info_text()

## Updates the node info text.
func update_node_info_text() ->void:
	nodes_info.text = "Nodes: " + str(vx_nodes.size())

## Updates the connection info text.
func update_connection_info_text() ->void:
	connections_info.text = "Connections: " + str(vx_connections.size())

## Arranges node positions based on their connections.
func arrange_node_positions():
	await get_tree().process_frame # This stops issues with nodes getting skipped
	var active_node:VXNode = selected_node
	var connected_nodes:Dictionary = active_node.get_connected_nodes()

	var top_nodes: Array = connected_nodes.get("top", [])
	var bottom_nodes: Array = connected_nodes.get("bottom", [])
	var left_nodes: Array = connected_nodes.get("left", [])
	var right_nodes: Array = connected_nodes.get("right", [])

	# Get the boundaries of the rectangles that will contain the nodes.
	var top_rectangle = calculate_rectangle_boundaries(active_node, top_nodes, "top")
	var bottom_rectangle = calculate_rectangle_boundaries(active_node, bottom_nodes, "bottom")
	var left_rectangle = calculate_rectangle_boundaries(active_node, left_nodes, "left")
	var right_rectangle = calculate_rectangle_boundaries(active_node, right_nodes, "right")
	
	# Will determine offsets for arrange_nodes_within_rectangle
	var width_max:float = max(top_rectangle["size"].x, bottom_rectangle["size"].x)
	var height_max:float = max(left_rectangle["size"].y, right_rectangle["size"].y)
	
	# Arrange nodes within the rectangles.
	arrange_nodes_within_rectangle(top_nodes, top_rectangle, Vector2(0, -height_max/2))
	arrange_nodes_within_rectangle(bottom_nodes, bottom_rectangle, Vector2(0, height_max/2))
	arrange_nodes_within_rectangle(left_nodes, left_rectangle, Vector2(-width_max/2, 0))
	arrange_nodes_within_rectangle(right_nodes, right_rectangle, Vector2(width_max/2, 0))

	# Recalculate connection lines
	recalculate_connection_lines()

## Calculates the boundaries of the rectangle that will contain the nodes.
## Rectagle is positioned on the given side of the active node.
## Active node is the node that is selected by the user.
## Connected nodes are the nodes that are connected to the active node.
## Side is the side of the active node that the rectangle will be positioned.
func calculate_rectangle_boundaries(active_node:VXNode, connected_nodes:Array, side:String):
	var active_node_center:Vector2 = active_node.position + active_node.size/2
	var rectangle_size_parallel:Vector2 = Vector2(0, 0)
	var rectangle_size_linear:Vector2 = Vector2(0, 0)
	var padding:float = 50
	for node:VXNode in connected_nodes:
		var node_size:Vector2 = node.size
		# Calculate the rectangle size for parallel connections if that is what it will become.
		if node_size.x > rectangle_size_parallel.x:
			rectangle_size_parallel.x = node_size.x
		rectangle_size_parallel.y += node_size.y + padding
		# Calculate the rectangle size for linear connections if that is what it will become.
		if node_size.y > rectangle_size_linear.y:
			rectangle_size_linear.y = node_size.y
		rectangle_size_linear.x += node_size.x + padding
	
	var rectangle_size:Vector2 = Vector2(0, 0)
	var rectangle_position:Vector2 = Vector2(0, 0)

	match side:
		"top", "bottom":
			rectangle_size = rectangle_size_linear
		"left", "right":
			rectangle_size = rectangle_size_parallel

	match side:
		"top":
			rectangle_position = active_node_center - Vector2(rectangle_size.x/2, rectangle_size.y + active_node.size.y/2 + 150)
		"bottom":
			rectangle_position = active_node_center + Vector2(-rectangle_size.x/2, active_node.size.y/2 + 150)
		"left":
			rectangle_position = active_node_center - Vector2(rectangle_size.x + active_node.size.x/2 + 150, rectangle_size.y/2)
		"right":
			rectangle_position = active_node_center + Vector2(active_node.size.x/2 + 150, -rectangle_size.y/2)

	return {
		"position": rectangle_position,
		"size": rectangle_size
	}

## Arranges nodes within the given rectangle.
## Nodes are arranged from left to right if the rectangle is wider than it is tall.
## Nodes are arranged from top to bottom if the rectangle is taller than it is wide.
## Padding is used to separate the nodes.
func arrange_nodes_within_rectangle(nodes:Array, rectangle:Dictionary, offset:Vector2 = Vector2.ZERO) -> void:
	var position:Vector2 = rectangle["position"] + offset
	var size:Vector2 = rectangle["size"]
	var padding:float = 50

	if size.x > size.y:
		# Arrange nodes from left to right
		for node in nodes:
			node.position = position
			position.x += node.size.x + padding
	else:
		# Arrange nodes from top to bottom
		for node in nodes:
			node.position = position
			position.y += node.size.y + padding

## Recalculates the connection lines.
func recalculate_connection_lines():
	for node:VXNode in vx_nodes.values():
		# We used node_moved.emit(<same_position>) because moving a node
		# will trigger the connection lines to recalculate.
		node.node_moved.emit(node.position)
