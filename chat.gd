extends Window

const NAME_ADJECTIVES:Array = ["Red", "Orange", "Yellow", "Green", "Blue", "Indigo", "Violet"]
const NAME_NOUNS:Array = ["Dog", "Cat", "Mouse", "Bird", "Pig", "Fish", "Bear", "Fox", "Bunny"]
# TODO: Let the player choose their name
# TODO: Let the player choose a color
var _chat_nickname:String = "%s %s" % [NAME_ADJECTIVES.pick_random(), NAME_NOUNS.pick_random()]
var _chat_color:Color = Color.from_hsv(randf(), randf() * 0.5 + 0.5, randf() * 0.5 + 0.5)

var participants:Dictionary = {}
var participant_labels:Dictionary = {}

func participant_spawner() -> MultiplayerSpawner:
	return $ChatVBox/UpperHBox/InfoVBox/ParticipantsScroll/ParticipantSpawner

func message_spawner() -> MultiplayerSpawner:
	return $ChatVBox/UpperHBox/MessageScroll/MessageSpawner

func _ready():
	participant_spawner().spawn_function = _spawn_partipant_label
	message_spawner().spawn_function = _spawn_message

func get_chat_config() -> Dictionary:
	return {
		"name": _chat_nickname,
		"color": _chat_color
	}

func register_participant(player_info:Dictionary) -> void:
	print("[%s] register_participant called with %s" % [multiplayer.get_unique_id(), player_info])
	participants[player_info["peer_id"]] = player_info
	if multiplayer.is_server():
		participant_spawner().spawn(player_info)

func _spawn_partipant_label(data:Dictionary) -> Label:
	print("[%s] _spawn_partipant_label called with %s" % [multiplayer.get_unique_id(), data])
	var label:Label = Label.new()
	label.text = data["name"]
	participant_labels[data["peer_id"]] = label
	return label

func deregister_participant(peer_id:int) -> void:
	print("[%s] deregister_participant called with %s" % [multiplayer.get_unique_id(), peer_id])
	_delete_participant_label(peer_id)
	participants.erase(peer_id)

func _delete_participant_label(peer_id:int) -> void:
	print("[%s] _delete_participant_label called with %s" % [multiplayer.get_unique_id(), peer_id])
	var label:Label = participant_labels[peer_id]
	participant_spawner().get_node(participant_spawner().spawn_path).remove_child(label)
	label.queue_free()

func _on_line_edit_text_submitted(_new_text):
	_send_message()
	
func _on_send_button_pressed():
	_send_message()
	$ChatVBox/LowerHBox/MessageLineEdit.grab_focus()

func _send_message() -> void:
	print("[%s] _send_message called" % multiplayer.get_unique_id())
	if !(multiplayer.multiplayer_peer is ENetMultiplayerPeer):
		return
	var le:LineEdit = $ChatVBox/LowerHBox/MessageLineEdit
	if le.text.strip_edges() == "":
		return
	if multiplayer.is_server():
		create_message(le.text)
	else:
		_rpc_create_message.rpc_id(1, le.text)
	le.text = ""

@rpc("any_peer", "reliable")
func _rpc_create_message(message:String) -> void:
	print("[%s] _rpc_create_message called with %s" % [multiplayer.get_unique_id(), message])
	create_message(message)

func create_message(message:String) -> void:
	print("[%s] create_message called with %s" % [multiplayer.get_unique_id(), message])
	if !multiplayer.is_server():
		return
	var sender_id:int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	var info:Dictionary = participants[sender_id]
	message_spawner().spawn({
		"name":    info["name"],
		"color":   info["color"],
		"id":      info["peer_id"] % 10000,
		"message": message
	})

func _spawn_message(data:Dictionary) -> RichTextLabel:
	print("[%s] _spawn_message called with %s" % [multiplayer.get_unique_id(), data])
	var p:RichTextLabel = RichTextLabel.new()
	p.fit_content = true
	p.push_color(data["color"])
	p.add_text("[%s#%s]: " % [data["name"], data["id"]])
	p.append_text(data["message"])
	p.pop_all()
	return p

func _on_close_requested():
	hide()
	get_tree().paused = false

func _on_go_back_requested():
	hide()
	get_tree().paused = false

# When a new message appears, if we are watching the end of the chat, scrolls
# until the new message is fully in view.
func _on_message_v_box_container_child_entered_tree(node):
	var msc:ScrollContainer = $ChatVBoxContainer/UpperHBoxContainer/MessageScrollContainer
	var scrollbar:VScrollBar = msc.get_v_scroll_bar()
	if scrollbar.value >= scrollbar.max_value - scrollbar.page:
		await get_tree().process_frame
		msc.ensure_control_visible(node)
