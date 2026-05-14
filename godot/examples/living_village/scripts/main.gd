extends Node2D

@onready var player_marker: ColorRect = $Player
@onready var status_label: Label = $UI/Panel/Margin/Text/Status
@onready var clock_label: Label = $UI/Panel/Margin/Text/Clock
@onready var log_label: Label = $UI/Panel/Margin/Text/Log

const PLAYER_SPEED := 220.0
const PLAYER_MIN := Vector2(24, 64)
const PLAYER_MAX := Vector2(900, 480)

var locations := {
	"village_square": Vector2(462, 248),
	"blacksmith": Vector2(730, 184),
	"old_shrine": Vector2(198, 330)
}
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

	if direction == Vector2.ZERO:
		return

	player_marker.position = _bounded_position(player_marker.position + direction * PLAYER_SPEED * delta)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	if event.keycode == KEY_1:
		_submit("travel", "blacksmith", {})
		return

	if event.keycode == KEY_2:
		_submit("travel", "old_shrine", {})
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
	_finish_smoke(0)

func _on_snapshot_received(snapshot: Dictionary) -> void:
	var player: Dictionary = snapshot.get("player", {})
	var calendar: Dictionary = snapshot.get("calendar", {})
	var location_id: String = player.get("location_id", "village_square")
	player_marker.position = _bounded_position(locations.get(location_id, locations["village_square"]))
	clock_label.text = _calendar_text(calendar)

func _on_command_accepted(_command_id: String, events: Array) -> void:
	_log("Server accepted command with " + str(events.size()) + " event(s).")

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
	log_label.text = message + "\nArrows/WASD move. 1 blacksmith, 2 shrine, 3 wait"

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
