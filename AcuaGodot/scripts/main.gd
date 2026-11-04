extends Node3D
# Escena principal: campus continuo en primera persona + tableta de planificación (Tab / M).

var campus
var ui
var player
var tablet: CanvasLayer
var observation_camera: Camera3D
var observing := false
var observation_hint: Label
var _observation_hint_panel: PanelContainer

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    campus = load("res://scripts/campus.gd").new()
    add_child(campus)
    ui = load("res://scripts/ui.gd").new()
    add_child(ui)
    player = load("res://scripts/player.gd").new()
    player.ui = ui
    add_child(player)
    observation_camera = load("res://scripts/observation_camera.gd").new()
    observation_camera.current = false
    add_child(observation_camera)
    _build_observation_hint()
    # aparición: frente a la entrada del portón de la nave (lado oeste)
    var spawn := Vector3(-45.0 - 15.0 - 5.0, 0.1, 25.0)
    for b in Game.buildings:
        if b.id == "tilapia_nave":
            spawn = Vector3(b.x - 20.0, 0.1, b.y)
    player.position = spawn
    player.rotation.y = -PI / 2.0
    Game.overlay_open = false

func _build_observation_hint() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 15
    add_child(layer)
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
    panel.offset_left = 0
    panel.offset_right = 0
    panel.offset_top = 12
    panel.offset_bottom = 48
    panel.visible = false
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.11, 0.15, 0.88)
    style.border_color = Color(0.16, 0.68, 0.66, 0.85)
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    panel.add_theme_stylebox_override("panel", style)
    layer.add_child(panel)
    var center := CenterContainer.new()
    panel.add_child(center)
    observation_hint = Label.new()
    observation_hint.text = "VISTA DE OBSERVACIÓN · F3 volver a primera persona · rueda acercar/alejar · WASD desplazar · arrastrar para orbitar"
    observation_hint.add_theme_color_override("font_color", Color(0.78, 0.96, 0.93))
    observation_hint.add_theme_font_size_override("font_size", 14)
    center.add_child(observation_hint)
    _observation_hint_panel = panel

func toggle_observation() -> void:
    observing = not observing
    if observing:
        observation_camera.make_current()
        player.set_physics_process(false)
        campus.set_observation_mode(true)
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        ui.set_observation_mode(true)
        _observation_hint_panel.visible = true
    else:
        player.cam.make_current()
        player.set_physics_process(true)
        campus.set_observation_mode(false)
        ui.set_observation_mode(false)
        _observation_hint_panel.visible = false
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func handle_observation_input(event: InputEvent) -> void:
    observation_camera.handle_observation_input(event)

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
