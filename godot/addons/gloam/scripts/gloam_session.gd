class_name GloamSession
extends RefCounted

var session_id: String = ""
var token: String = ""
var snapshot: Dictionary = {}
var connected: bool = false

func configure(new_session_id: String, new_token: String) -> void:
    session_id = new_session_id
    token = new_token

func apply_snapshot(new_snapshot: Dictionary) -> void:
    snapshot = new_snapshot

func clear() -> void:
    session_id = ""
    token = ""
    snapshot = {}
    connected = false
