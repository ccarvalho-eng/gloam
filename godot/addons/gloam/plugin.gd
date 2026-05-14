@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GloamClient"
const AUTOLOAD_PATH := "res://addons/gloam/scripts/gloam_client.gd"

func _enter_tree():
    add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _exit_tree():
    remove_autoload_singleton(AUTOLOAD_NAME)
