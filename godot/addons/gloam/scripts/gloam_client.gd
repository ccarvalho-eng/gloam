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
	var payload := {"player_id": player_id}
	var request := _new_http_request(_on_create_session_completed)
	var error := _post_json(request, "/api/sessions", payload, PackedStringArray())

	if error != OK:
		request.queue_free()
		command_rejected.emit("", {"code": "session_create_failed", "message": "Could not start HTTP request: " + str(error)})

func refresh_snapshot() -> void:
	if session.session_id == "" or session.token == "":
		resync_required.emit()
		return

	var headers := PackedStringArray(["Authorization: Bearer " + session.token])
	var request := _new_http_request(_on_snapshot_completed)
	var error := request.request(_http_url("/api/sessions/" + session.session_id + "/snapshot"), headers, HTTPClient.METHOD_GET)

	if error != OK:
		request.queue_free()
		resync_required.emit()

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

	if session.token == "":
		return {"ok": false, "command_id": command_id, "error": "missing_token"}

	var headers := PackedStringArray(["Authorization: Bearer " + session.token])
	var request := _new_http_request(_on_command_completed.bind(command_id))
	var error := _post_json(request, "/api/sessions/" + session.session_id + "/commands", command, headers)

	if error != OK:
		request.queue_free()
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

func _new_http_request(callback: Callable) -> HTTPRequest:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(callback.bind(request))
	return request

func _post_json(request: HTTPRequest, path: String, payload: Dictionary, extra_headers: PackedStringArray) -> int:
	var headers := PackedStringArray(["Content-Type: application/json"])

	for header in extra_headers:
		headers.append(header)

	return request.request(_http_url(path), headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

func _on_create_session_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	var payload: Variant = _decode_body(body)

	if result != HTTPRequest.RESULT_SUCCESS:
		command_rejected.emit("", _http_error("session_create_failed", result, response_code))
		return

	if not _successful(response_code) or not payload is Dictionary:
		command_rejected.emit("", _http_error("session_create_failed", result, response_code))
		return

	session.configure(payload.get("session_id", ""), payload.get("token", ""))
	session.apply_snapshot(payload.get("snapshot", {}))
	authenticated.emit()
	snapshot_received.emit(session.snapshot)

func _on_snapshot_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	var payload: Variant = _decode_body(body)

	if result != HTTPRequest.RESULT_SUCCESS or not _successful(response_code) or not payload is Dictionary:
		resync_required.emit()
		return

	session.apply_snapshot(payload.get("snapshot", {}))
	snapshot_received.emit(session.snapshot)

func _on_command_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, command_id: String, request: HTTPRequest) -> void:
	request.queue_free()
	var payload: Variant = _decode_body(body)

	if result != HTTPRequest.RESULT_SUCCESS:
		command_rejected.emit(command_id, _http_error("command_request_failed", result, response_code))
		return

	if not payload is Dictionary:
		command_rejected.emit(command_id, {"code": "invalid_response", "message": "Server response was invalid"})
		return

	if _successful(response_code):
		command_accepted.emit(command_id, payload.get("events", []))
		refresh_snapshot()
		return

	command_rejected.emit(command_id, payload.get("error", {}))

func _decode_body(body: PackedByteArray) -> Variant:
	var text := body.get_string_from_utf8()
	return JSON.parse_string(text)

func _successful(response_code: int) -> bool:
	return response_code >= 200 and response_code < 300

func _http_url(path: String) -> String:
	return server_url + path

func _http_error(code: String, result: int, response_code: int) -> Dictionary:
	return {
		"code": code,
		"message": "Could not reach " + server_url + " (result " + str(result) + ", HTTP " + str(response_code) + ")"
	}

func _websocket_url(path: String) -> String:
	if server_url.begins_with("https://"):
		return "wss://" + server_url.substr(8) + path

	if server_url.begins_with("http://"):
		return "ws://" + server_url.substr(7) + path

	return server_url + path

func _new_command_id() -> String:
	return "cmd-" + str(Time.get_unix_time_from_system()) + "-" + str(randi())
