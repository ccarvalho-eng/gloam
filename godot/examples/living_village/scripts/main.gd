extends Node2D

@onready var player_marker: ColorRect = $Player
@onready var status_label: Label = $UI/Panel/Margin/Text/Status
@onready var clock_label: Label = $UI/Panel/Margin/Text/Clock
@onready var interaction_label: Label = $UI/Panel/Margin/Text/Interaction
@onready var log_label: Label = $UI/Panel/Margin/Text/Log

const PLAYER_SPEED := 220.0
const PLAYER_MIN := Vector2(24, 64)
const PLAYER_MAX := Vector2(900, 480)
const INTERACTION_RADIUS := 92.0
const MAX_LOG_ENTRIES := 5

var locations := {
	"village_square": Vector2(462, 248),
	"blacksmith": Vector2(730, 184),
	"old_well": Vector2(198, 330)
}
var event_log: Array[String] = []
var nearest_bindable: Node
var sync_player_marker_from_snapshot := true
var smoke_mode := false

func _ready() -> void:
	smoke_mode = OS.get_cmdline_user_args().has("--gloam-smoke")
	GloamClient.configure(_server_url())
	GloamClient.authenticated.connect(_on_authenticated)
	GloamClient.snapshot_received.connect(_on_snapshot_received)
	GloamClient.command_accepted.connect(_on_command_accepted)
	GloamClient.command_rejected.connect(_on_command_rejected)
	GloamClient.resync_required.connect(_on_resync_required)
	_start_smoke_timeout()
	_log("Creating a Gloam session...")
	GloamClient.create_local_session("player")

func _physics_process(delta: float) -> void:
	var direction := _movement_direction()

	if direction != Vector2.ZERO:
		player_marker.position = _bounded_position(player_marker.position + direction * PLAYER_SPEED * delta)

	_update_nearest_interaction()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	if event.keycode == KEY_E:
		_interact_with_nearest()
		return

	if event.keycode == KEY_1:
		_submit("travel", "blacksmith", {})
		return

	if event.keycode == KEY_2:
		_submit("travel", "old_well", {})
		return

	if event.keycode == KEY_3:
		_submit("wait", null, {"minutes": 30})

func _submit(command_type: String, target_id, params: Dictionary) -> void:
	var result := GloamClient.submit_command(command_type, target_id, params)

	if result.get("ok", false):
		_log("Sent " + command_type + " command.")
		return

	_log("Command failed locally: " + str(result.get("error", "unknown")))

func _on_authenticated() -> void:
	status_label.text = "Session " + GloamClient.session.session_id
	_log("Connected to Gloam.")

	if smoke_mode:
		_submit("inspect", "old_well", {})

func _on_snapshot_received(snapshot: Dictionary) -> void:
	var player: Dictionary = snapshot.get("player", {})
	var calendar: Dictionary = snapshot.get("calendar", {})
	var location_id: String = player.get("location_id", "village_square")

	if sync_player_marker_from_snapshot:
		player_marker.position = _bounded_position(locations.get(location_id, locations["village_square"]))
		sync_player_marker_from_snapshot = false

	clock_label.text = _calendar_text(calendar)
	_update_nearest_interaction()

func _on_command_accepted(_command_id: String, events: Array) -> void:
	sync_player_marker_from_snapshot = _events_include_player_move(events)
	_append_events(events)
	_finish_smoke(0)

func _on_command_rejected(_command_id: String, error: Dictionary) -> void:
	var code: String = str(error.get("code", "unknown"))
	var message: String = str(error.get("message", ""))
	_log("Rejected: " + code + "\n" + message)
	_finish_smoke(1)

func _on_resync_required() -> void:
	_log("Server sync required.")
	_finish_smoke(1)

func _calendar_text(calendar: Dictionary) -> String:
	return "%s, %s %s %02d:%02d" % [
		calendar.get("weekday", "ashwake"),
		calendar.get("season", "emberwake"),
		str(calendar.get("day_of_season", 1)),
		calendar.get("hour", 6),
		calendar.get("minute", 0)
	]

func _log(message: String) -> void:
	event_log.push_front(message)

	if event_log.size() > MAX_LOG_ENTRIES:
		event_log.resize(MAX_LOG_ENTRIES)

	log_label.text = "\n".join(event_log) + "\nArrows/WASD move. E interact. 1 blacksmith, 2 well, 3 wait"

func _interact_with_nearest() -> void:
	if nearest_bindable == null:
		_log("No nearby Gloam object.")
		return

	_submit(nearest_bindable.get("interaction_type"), nearest_bindable.get("gloam_id"), {})

func _update_nearest_interaction() -> void:
	nearest_bindable = _nearest_bindable()

	if nearest_bindable == null:
		interaction_label.text = "Move near a place and press E"
		return

	interaction_label.text = "E " + str(nearest_bindable.get("interaction_type")) + " " + nearest_bindable.call("interaction_label")

func _nearest_bindable() -> Node:
	var nearest: Node = null
	var nearest_distance := INTERACTION_RADIUS
	var player_center := player_marker.global_position + player_marker.size * 0.5

	for node in get_tree().get_nodes_in_group("gloam_bindable"):
		if not node is Node or not node.has_method("interaction_position"):
			continue

		var bindable := node as Node
		var position: Vector2 = bindable.call("interaction_position")
		var distance := player_center.distance_to(position)

		if distance < nearest_distance:
			nearest = bindable
			nearest_distance = distance

	return nearest

func _append_events(events: Array) -> void:
	if events.is_empty():
		_log("Server accepted duplicate command.")
		return

	for event_message in events:
		if event_message is Dictionary:
			_log(_event_summary(event_message))

func _event_summary(event_message: Dictionary) -> String:
	var event: Dictionary = event_message.get("event", {})
	var event_type := str(event.get("type", "event"))
	var subject_id := str(event.get("subject_id", "world"))

	if event_type == "player_moved":
		return "Gloam moved player to " + subject_id + "."

	if event_type == "calendar_advanced":
		return "Gloam advanced the village clock."

	if event_type == "talk":
		return "Gloam recorded talk with " + subject_id + "."

	if event_type == "inspect":
		return "Gloam inspected " + subject_id + "."

	return "Gloam event: " + event_type + "."

func _events_include_player_move(events: Array) -> bool:
	for event_message in events:
		if not event_message is Dictionary:
			continue

		var event: Dictionary = event_message.get("event", {})

		if event.get("type", "") == "player_moved":
			return true

	return false

func _movement_direction() -> Vector2:
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0

	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		direction.x += 1.0

	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0

	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	return direction.normalized()

func _bounded_position(position: Vector2) -> Vector2:
	return Vector2(
		clampf(position.x, PLAYER_MIN.x, PLAYER_MAX.x),
		clampf(position.y, PLAYER_MIN.y, PLAYER_MAX.y)
	)

func _server_url() -> String:
	var configured_url := OS.get_environment("GLOAM_SERVER_URL")

	if configured_url != "":
		return configured_url

	return "http://127.0.0.1:4000"

func _start_smoke_timeout() -> void:
	if not smoke_mode:
		return

	get_tree().create_timer(5.0).timeout.connect(_on_smoke_timeout)

func _on_smoke_timeout() -> void:
	_finish_smoke(1)

func _finish_smoke(exit_code: int) -> void:
	if smoke_mode:
		get_tree().quit(exit_code)
