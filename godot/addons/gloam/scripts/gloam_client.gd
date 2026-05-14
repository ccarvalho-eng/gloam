extends Node

signal connected
signal authenticated
signal snapshot_received(snapshot: Dictionary)
signal event_received(event: Dictionary)
signal command_accepted(command_id: String, events: Array)
signal command_rejected(command_id: String, error: Dictionary)
signal connection_lost
signal resync_required

const GloamSessionScript := preload("res://addons/gloam/scripts/gloam_session.gd")
const GloamMessagesScript := preload("res://addons/gloam/scripts/gloam_messages.gd")

var server_url: String = "http://localhost:4000"
var session := GloamSessionScript.new()
var websocket := WebSocketPeer.new()
var websocket_active := false
var websocket_connected := false

func configure(new_server_url: String) -> void:
    server_url = new_server_url.rstrip("/")

func create_local_session(player_id: String) -> void:
    # HTTP session creation lands with the server transport slice.
    session.configure("local-" + player_id, "")
    authenticated.emit()

func connect_events() -> int:
    if session.session_id == "":
        return ERR_UNCONFIGURED

    var ws_url := _websocket_url("/ws/sessions/" + session.session_id)
    var headers := PackedStringArray()

    if session.token != "":
        headers.append("Authorization: Bearer " + session.token)

    websocket.handshake_headers = headers
    var error := websocket.connect_to_url(ws_url)

    if error == OK:
        websocket_active = true

    return error

func submit_command(command_type: String, target_id, params: Dictionary = {}) -> Dictionary:
    var command_id := _new_command_id()
    var command := GloamMessagesScript.command(
        command_id,
        session.session_id,
        "player",
        command_type,
        target_id,
        params
    )

    if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
        return {"ok": false, "command_id": command_id, "error": "websocket_not_open"}

    var error := websocket.send_text(JSON.stringify(command))

    if error != OK:
        return {"ok": false, "command_id": command_id, "error": "send_failed"}

    return {"ok": true, "command_id": command_id}

func _process(_delta: float) -> void:
    if not websocket_active:
        return

    websocket.poll()
    _drain_websocket_packets()
    _handle_socket_state()

func _drain_websocket_packets() -> void:
    while websocket.get_available_packet_count() > 0:
        var text := websocket.get_packet().get_string_from_utf8()
        var parsed = JSON.parse_string(text)

        if parsed is Dictionary:
            _handle_message(parsed)

func _handle_message(message: Dictionary) -> void:
    if GloamMessagesScript.is_snapshot(message):
        session.apply_snapshot(message)
        snapshot_received.emit(message)
        return

    if GloamMessagesScript.is_event(message):
        event_received.emit(message.get("event", {}))
        return

    if message.get("type", "") == "command.accepted":
        command_accepted.emit(message.get("command_id", ""), message.get("events", []))
        return

    if message.get("type", "") == "command.rejected":
        command_rejected.emit(message.get("command_id", ""), message.get("error", {}))
        return

    if message.get("type", "") == "resync.required":
        resync_required.emit()

func _handle_socket_state() -> void:
    var state := websocket.get_ready_state()

    if state == WebSocketPeer.STATE_OPEN and not websocket_connected:
        websocket_connected = true
        connected.emit()
        return

    if state == WebSocketPeer.STATE_CLOSED and websocket_active:
        websocket_active = false
        websocket_connected = false
        connection_lost.emit()

func _websocket_url(path: String) -> String:
    if server_url.begins_with("https://"):
        return "wss://" + server_url.substr(8) + path

    if server_url.begins_with("http://"):
        return "ws://" + server_url.substr(7) + path

    return server_url + path

func _new_command_id() -> String:
    return "cmd-" + str(Time.get_unix_time_from_system()) + "-" + str(randi())
