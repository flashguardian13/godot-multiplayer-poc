extends Node2D

const IP_ADDRESS:String = "127.0.0.1"
const PORT:int = 45367
const MAX_CLIENTS:int = 8

# Map of peer IDs to players
var players:Dictionary = {}

# Player information
var player_info:Dictionary = { "name": "Player %s" % randi() }

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# Button press event listeners

func _on_host_button_pressed():
	if is_multiplayer():
		print("[%s] Connection already exists." % multiplayer.get_unique_id())
		return
	var peer:ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error:
		print("[%s] %s" % [peer.get_unique_id(), error])
		return error
	multiplayer.multiplayer_peer = peer
	print("[%s] Peer (server) created." % peer.get_unique_id())

func _on_join_button_pressed():
	if is_multiplayer():
		print("[%s] Connection already exists." % multiplayer.get_unique_id())
		return
	var peer:ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error = peer.create_client(IP_ADDRESS, PORT)
	if error:
		print("[%s] %s" % [peer.get_unique_id(), error])
		return error
	multiplayer.multiplayer_peer = peer
	print("[%s] Peer (client) created." % peer.get_unique_id())

func _on_leave_button_pressed():
	var peer_id:int = multiplayer.get_unique_id()
	if !is_multiplayer():
		print("[%s] No connection exists." % peer_id)
		return
	disconnect_from_server()

# Local multiplayer event listeners.

func _on_peer_connected(id:int):
	print("[%s] Peer %s has connected." % [multiplayer.get_unique_id(), id])
	_register_player.rpc_id(id, player_info) # Hello, [id], here is my player info.

func _on_peer_disconnected(id:int):
	print("[%s] Peer %s disconnected." % [multiplayer.get_unique_id(), id])
	players.erase(id)

func _on_connected_to_server():
	print("[%s] Connection to server succeeded." % multiplayer.get_unique_id())
	players[multiplayer.get_unique_id()] = player_info

func _on_connection_failed():
	print("[%s] Connection to server failed!" % multiplayer.get_unique_id())
	disconnect_from_server()

func _on_server_disconnected():
	print("[%s] Disconnected from server." % multiplayer.get_unique_id())
	disconnect_from_server()

# Multiplayer functions

func is_multiplayer() -> bool:
	return players.size() > 0

@rpc("any_peer", "reliable")
func _register_player(player_info:Dictionary):
	var sender_id:int = multiplayer.get_remote_sender_id()
	print("[%s] Received information for player %s." % [multiplayer.get_unique_id(), sender_id])
	players[sender_id] = player_info

func disconnect_from_server() -> void:
	players.clear()
	print("[%s] Peer destroyed." % multiplayer.get_unique_id())
	multiplayer.multiplayer_peer = null
