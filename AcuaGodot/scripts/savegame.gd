class_name SaveGame
extends RefCounted
# Guardado en user:// (una partida + autoguardado diario).

const PATH := "user://acuaevolution_save.json"

static func exists() -> bool:
    return FileAccess.file_exists(PATH)

static func save() -> void:
    var f := FileAccess.open(PATH, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(Game.to_dict()))

static func load_game() -> bool:
    if not exists():
        return false
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if parsed is Dictionary:
        Game.from_dict(parsed)
        return true
    return false
