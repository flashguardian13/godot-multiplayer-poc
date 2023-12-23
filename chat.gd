extends Window

var participants:Dictionary = {}

func participant_spawner() -> MultiplayerSpawner:
	return $ChatVBoxContainer/UpperHBoxContainer/ParticipantsScrollContainer2/MultiplayerSpawner

func _ready():
	participant_spawner().spawn_function = _spawn_partipant

func _spawn_partipant(data:Dictionary) -> Label:
	print("[%s] _spawn_partipant called with %s" % [multiplayer.get_unique_id(), data])
	var p:Label = Label.new()
	participants[data["peer_id"]] = p
	p.text = data["name"]
	return p

func _delete_participant(peer_id:int) -> void:
	print("[%s] _delete_participant called with %s" % [multiplayer.get_unique_id(), peer_id])
	var p:Label = participants[peer_id]
	participants.erase(p)
	participant_spawner().get_node(participant_spawner().spawn_path).remove_child(p)
	p.queue_free()

func _on_close_requested():
	hide()
	get_tree().paused = false

func _on_go_back_requested():
	hide()
	get_tree().paused = false
