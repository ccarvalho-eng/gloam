class_name GloamMessages
extends RefCounted

static func command(id: String, session_id: String, actor_id: String, command_type: String, target_id, params: Dictionary = {}) -> Dictionary:
	return {
		"id": id,
		"session_id": session_id,
		"actor_id": actor_id,
		"type": command_type,
		"target_id": target_id,
		"params": params,
		"source": "player"
	}

static func is_snapshot(message: Dictionary) -> bool:
	return message.get("type", "") == "snapshot"

static func is_event(message: Dictionary) -> bool:
	return message.get("type", "") == "event"

static func is_error(message: Dictionary) -> bool:
	return message.get("type", "") == "error"

static func require_string(payload: Dictionary, key: String) -> bool:
	return payload.has(key) and payload[key] is String and payload[key] != ""
