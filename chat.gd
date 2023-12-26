extends Window

const NAME_ADJECTIVES:Array = ["Red", "Orange", "Yellow", "Green", "Blue", "Indigo", "Violet"]
const NAME_NOUNS:Array = ["Dog", "Cat", "Mouse", "Bird", "Pig", "Fish", "Bear", "Fox", "Bunny"]

var participants:Dictionary = {}
var participant_labels:Dictionary = {}

# UI shortcuts

func participant_spawner() -> MultiplayerSpawner:
	return $ChatVBox/UpperHBox/InfoVBox/ParticipantsScroll/ParticipantSpawner

func message_spawner() -> MultiplayerSpawner:
	return $ChatVBox/UpperHBox/MessageScroll/MessageSpawner

func player_name_line_edit() -> LineEdit:
	return $ChatVBox/UpperHBox/InfoVBox/PlayerHBox/NameLineEdit

func player_color_picker() -> ColorPickerButton:
	return $ChatVBox/UpperHBox/InfoVBox/PlayerHBox/PlayerColorPicker

# Event-driven functions

func _ready():
	participant_spawner().spawn_function = _spawn_partipant_label
	message_spawner().spawn_function = _spawn_message
	player_name_line_edit().text = "%s %s" % [NAME_ADJECTIVES.pick_random(), NAME_NOUNS.pick_random()]
	player_color_picker().color = Color.from_hsv(randf(), randf() * 0.5 + 0.5, randf() * 0.5 + 0.5)

# Participant information functions

func get_chat_config() -> Dictionary:
	return {
		"name": player_name_line_edit().text,
		"color": player_color_picker().color
	}

func register_participant(player_info:Dictionary) -> void:
	print("[%s] register_participant called with %s" % [multiplayer.get_unique_id(), player_info])
	participants[player_info["peer_id"]] = player_info
	if multiplayer.is_server():
		participant_spawner().spawn(player_info)
		create_system_message("%s has connected." % player_info["name"])

func _spawn_partipant_label(data:Dictionary) -> RichTextLabel:
	print("[%s] _spawn_partipant_label called with %s" % [multiplayer.get_unique_id(), data])
	var label:RichTextLabel = RichTextLabel.new()
	label.fit_content = true
	label.push_color(data["color"])
	label.add_text(data["name"])
	label.pop_all()
	participant_labels[data["peer_id"]] = label
	return label

func deregister_participant(peer_id:int) -> void:
	print("[%s] deregister_participant called with %s" % [multiplayer.get_unique_id(), peer_id])
	_delete_participant_label(peer_id)
	if multiplayer.is_server():
		var info:Dictionary = participants[peer_id]
		create_system_message("%s has disconnected." % info["name"])
	participants.erase(peer_id)

func _delete_participant_label(peer_id:int) -> void:
	print("[%s] _delete_participant_label called with %s" % [multiplayer.get_unique_id(), peer_id])
	var label:RichTextLabel = participant_labels[peer_id]
	participant_spawner().get_node(participant_spawner().spawn_path).remove_child(label)
	label.queue_free()

# UI event-driven functions

func _on_message_line_edit_text_submitted(new_text):
	print("[%s] _on_message_line_edit_text_submitted called with %s" % [multiplayer.get_unique_id(), new_text])
	_send_message()
	
func _on_send_button_pressed():
	print("[%s] _on_send_button_pressed called" % multiplayer.get_unique_id())
	_send_message()
	$ChatVBox/LowerHBox/MessageLineEdit.grab_focus()

func _on_close_requested():
	hide()
	get_tree().paused = false

func _on_go_back_requested():
	hide()
	get_tree().paused = false

# When a new message appears, if we are watching the end of the chat, scrolls
# until the new message is fully in view.
func _on_message_v_box_child_entered_tree(node):
	print("[%s] _on_message_v_box_child_entered_tree called with %s" % [multiplayer.get_unique_id(), node])
	var msc:ScrollContainer = $ChatVBox/UpperHBox/MessageScroll
	var scrollbar:VScrollBar = msc.get_v_scroll_bar()
	if scrollbar.value >= scrollbar.max_value - scrollbar.page:
		await get_tree().process_frame
		msc.ensure_control_visible(node)

func _on_player_color_picker_color_changed(color):
	if participants[multiplayer.get_unique_id()]["color"] == color:
		return
	print("[%s] _on_player_color_picker_color_changed called wth %s" % [multiplayer.get_unique_id(), color])
	_change_peer_color(multiplayer.get_unique_id(), color)
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		_rpc_change_peer_color.rpc(color)

func _on_name_line_edit_text_submitted(new_text):
	if participants[multiplayer.get_unique_id()]["name"] == new_text:
		return
	print("[%s] _on_name_line_edit_text_submitted called wth %s" % [multiplayer.get_unique_id(), new_text])
	_change_peer_name(multiplayer.get_unique_id(), new_text)
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		_rpc_change_peer_name.rpc(new_text)

func _on_name_line_edit_focus_exited():
	var new_text:String = player_name_line_edit().text
	if participants[multiplayer.get_unique_id()]["name"] == new_text:
		return
	print("[%s] _on_name_line_edit_focus_exited called" % multiplayer.get_unique_id())
	_change_peer_name(multiplayer.get_unique_id(), new_text)
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		_rpc_change_peer_name.rpc(new_text)

# Other functions

func _send_message() -> void:
	print("[%s] _send_message called" % multiplayer.get_unique_id())
	if !(multiplayer.multiplayer_peer is ENetMultiplayerPeer):
		return
	var le:LineEdit = $ChatVBox/LowerHBox/MessageLineEdit
	if le.text.strip_edges() == "":
		return
	if multiplayer.is_server():
		create_message(multiplayer.get_unique_id(), le.text)
	else:
		_rpc_create_message.rpc_id(1, le.text)
	le.text = ""

@rpc("any_peer", "reliable")
func _rpc_create_message(message:String) -> void:
	print("[%s] (RPC) _rpc_create_message called with %s" % [multiplayer.get_unique_id(), message])
	create_message(multiplayer.get_remote_sender_id(), message)

func create_message(peer_id:int, message:String) -> void:
	print("[%s] create_message called with %s, %s" % [multiplayer.get_unique_id(), peer_id, message])
	if !multiplayer.is_server():
		return
	var info:Dictionary = participants[peer_id]
	message_spawner().spawn({
		"name":    info["name"],
		"color":   info["color"],
		"id":      info["peer_id"] % 10000,
		"message": message
	})

func create_system_message(message:String) -> void:
	print("[%s] create_system_message called with %s" % [multiplayer.get_unique_id(), message])
	if !multiplayer.is_server():
		return
	message_spawner().spawn({
		"name":    "",
		"color":   Color.WHITE,
		"id":      0,
		"message": message
	})

func _spawn_message(data:Dictionary) -> RichTextLabel:
	print("[%s] _spawn_message called with %s" % [multiplayer.get_unique_id(), data])
	var p:RichTextLabel = RichTextLabel.new()
	p.fit_content = true
	p.push_color(data["color"])
	if data["name"] != "" || data["id"] != 0:
		p.add_text("[%s#%s]: " % [data["name"], data["id"]])
	p.append_text(data["message"])
	p.pop_all()
	return p

@rpc("any_peer", "reliable")
func _rpc_change_peer_color(color:Color):
	print("[%s] (RPC) _rpc_change_peer_color called wth %s" % [multiplayer.get_unique_id(), color])
	_change_peer_color(multiplayer.get_remote_sender_id(), color)

func _change_peer_color(peer_id:int, color:Color):
	print("[%s] _change_peer_color called with %s, %s" % [multiplayer.get_unique_id(), peer_id, color])
	participants[peer_id]["color"] = color
	update_participant_label(peer_id)

@rpc("any_peer", "reliable")
func _rpc_change_peer_name(nickname:String):
	print("[%s] (RPC) _rpc_change_peer_name called with %s" % [multiplayer.get_unique_id(), nickname])
	_change_peer_name(multiplayer.get_remote_sender_id(), nickname)

func _change_peer_name(peer_id:int, nickname:String):
	print("[%s] _change_peer_name called with %s, %s" % [multiplayer.get_unique_id(), peer_id, nickname])
	var info:Dictionary = participants[peer_id]
	if multiplayer.is_server():
		create_system_message("%s has changed their name to %s." % [info["name"], nickname])
	info["name"] = nickname
	update_participant_label(peer_id)

func update_participant_label(peer_id:int):
	var peer_info:Dictionary = participants[peer_id]
	var label:RichTextLabel = participant_labels[peer_id]
	label.clear()
	label.push_color(peer_info["color"])
	label.add_text(peer_info["name"])
	label.pop_all()
