extends MarginContainer

@export
var player_scene:PackedScene

# Network configuration
const IP_ADDRESS:String = "127.0.0.1"
const PORT:int = 45367
const MAX_CLIENTS:int = 8

# Per-peer information
var player_details:Dictionary = {}
var player_sprites:Dictionary = {}

# Local Player information
var my_info:Dictionary = { "name": "Player %s" % randi() }

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	$MultiplayerSpawner.spawn_function = spawn_player

# Button press event listeners

func _on_host_button_pressed():
	print("[%s] (Click) Host" % my_peer_id())
	if is_multiplayer():
		print("[%s] (Click) Connection already exists." % my_peer_id())
		return
	var peer:ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error:
		print("[%s] (Click) %s" % [my_peer_id(), error])
		return error
	multiplayer.multiplayer_peer = peer
	print("[%s] peer is now %s" % [my_peer_id(), multiplayer.multiplayer_peer])
	setup_player(multiplayer.get_unique_id(), my_info)

func _on_join_button_pressed():
	print("[%s] (Click) Join" % my_peer_id())
	if is_multiplayer():
		print("[%s] (Click) Connection already exists." % my_peer_id())
		return
	var peer:ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error = peer.create_client(IP_ADDRESS, PORT)
	if error:
		print("[%s] (Click) %s" % [my_peer_id(), error])
		return error
	multiplayer.multiplayer_peer = peer
	print("[%s] peer is now %s" % [my_peer_id(), multiplayer.multiplayer_peer])

func _on_leave_button_pressed():
	print("[%s] (Click) Leave" % my_peer_id())
	if !is_multiplayer():
		print("[%s] (Click) No connection exists." % my_peer_id())
		return
	disconnect_from_server()

func _on_chat_toggle_button_pressed():
	print("[%s] (Click) Chat" % my_peer_id())
	get_tree().paused = true
	$ChatVBoxContainer.popup_centered()

# Local multiplayer event listeners.

func _on_peer_connected(id:int):
	print("[%s] (Event) Peer %s has connected." % [my_peer_id(), id])
	_register_player.rpc_id(id, my_info) # Hello, [id], here is my player info.

func _on_peer_disconnected(id:int):
	print("[%s] (Event) Peer %s disconnected." % [my_peer_id(), id])
	teardown_player(id)

func _on_connected_to_server():
	print("[%s] (Event) Connection to server succeeded." % my_peer_id())
	player_details[my_peer_id()] = my_info

func _on_connection_failed():
	print("[%s] (Event) Connection to server failed!" % my_peer_id())
	disconnect_from_server()

func _on_server_disconnected():
	print("[%s] (Event) Disconnected from server." % my_peer_id())
	disconnect_from_server()

# Multiplayer functions

func is_multiplayer() -> bool:
	return player_details.size() > 0

func my_peer_id() -> int:
	if multiplayer && multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return -1

@rpc("any_peer", "reliable")
func _register_player(player_info:Dictionary):
	var sender_id:int = multiplayer.get_remote_sender_id()
	print("[%s] (RPC) Received information for player %s." % [my_peer_id(), sender_id])
	setup_player(sender_id, player_info)

func setup_player(peer_id:int, peer_info:Dictionary):
	print("[%s] setup_player() called for peer %s." % [my_peer_id(), peer_id])
	player_details[peer_id] = peer_info
	if multiplayer.is_server():
		$MultiplayerSpawner.spawn({ "auth_id": peer_id })
		$ChatVBoxContainer.participant_spawner().spawn(
			{
				"name": peer_info["name"],
				"peer_id": peer_id
			}
		)

func spawn_player(data:Dictionary) -> Node2D:
	var auth_id:int = data.get("auth_id")
	print("[%s] spawn_player() called for peer %s." % [my_peer_id(), auth_id])
	var player_sprite:Node2D = player_scene.instantiate()
	player_sprites[auth_id] = player_sprite
	player_sprite.name = "Player%s" % auth_id
	player_sprite.call_deferred("set_multiplayer_authority", auth_id)
	player_sprite.position = Vector2(
		randi() % DisplayServer.window_get_size().x,
		randi() % DisplayServer.window_get_size().y
	)
	return player_sprite

func disconnect_from_server() -> void:
	if !is_multiplayer():
		return
	print("[%s] disconnect_from_server() called." % my_peer_id())
	var old_peer:MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	print("[%s] peer is now %s" % [my_peer_id(), multiplayer.multiplayer_peer])
	old_peer.close()
	print("[%s] Multiplayer peer closed." % my_peer_id())
	for player_id in player_details.keys():
		teardown_player(player_id)

func teardown_player(peer_id:int):
	print("[%s] teardown_player() called for peer %s." % [my_peer_id(), peer_id])
	player_details.erase(peer_id)
	if multiplayer.is_server():
		despawn_player(peer_id)
		$ChatVBoxContainer._delete_participant(peer_id)

func despawn_player(id:int) -> void:
	print("[%s] despawn_player() called for peer %s." % [my_peer_id(), id])
	var player_sprite:Node2D = player_sprites[id]
	player_sprites.erase(id)
	$World.remove_child(player_sprite)
	player_sprite.queue_free()
