extends Node3D
# Escena principal: campus continuo en primera persona + tableta de planificación (Tab / M).

var campus
var ui
var player
var tablet: CanvasLayer

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    campus = load("res://scripts/campus.gd").new()
    add_child(campus)
    ui = load("res://scripts/ui.gd").new()
    add_child(ui)
    player = load("res://scripts/player.gd").new()
    player.ui = ui
    add_child(player)
    # aparición: frente a la entrada del portón de la nave (lado oeste)
    var spawn := Vector3(-45.0 - 15.0 - 5.0, 0.1, 25.0)
    for b in Game.buildings:
        if b.id == "tilapia_nave":
            spawn = Vector3(b.x - 20.0, 0.1, b.y)
    player.position = spawn
    player.rotation.y = -PI / 2.0
    Game.overlay_open = false

func toggle_tablet() -> void:
    if tablet != null:
        tablet.queue_free()
        tablet = null
        Game.overlay_open = false
        campus.sync_buildings()
        if Game.has_tp:
            Game.has_tp = false
            player.teleport(Game.pending_tp, Game.pending_yaw)
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    else:
        tablet = CanvasLayer.new()
        tablet.layer = 20
        var pl = load("res://plano.tscn").instantiate()
        pl.overlay = true
        tablet.add_child(pl)
        add_child(tablet)
        Game.overlay_open = true
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
