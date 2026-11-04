extends Camera3D
# Cámara ortográfica para observar el campus; las tareas e interacciones siguen en primera persona.

var target := Vector3.ZERO
var yaw := deg_to_rad(45.0)
var pitch := deg_to_rad(55.0)
var orbit_distance := 360.0
var _dragging := false

func _ready() -> void:
    projection = Camera3D.PROJECTION_ORTHOGONAL
    size = 270.0
    current = false
    _update_pose()

func _process(delta: float) -> void:
    if not current:
        return
    var move := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
        move.x -= 1.0
    if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
        move.x += 1.0
    if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
        move.y += 1.0
    if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
        move.y -= 1.0
    if move.length_squared() > 0.0:
        move = move.normalized()
        var right := global_transform.basis.x
        var forward := -global_transform.basis.z
        right.y = 0.0
        forward.y = 0.0
        target += (right.normalized() * move.x + forward.normalized() * move.y) * size * 0.8 * delta
        var planar := Vector2(target.x, target.z)
        if planar.length() > Game.DOME_R - 8.0:
            planar = planar.normalized() * (Game.DOME_R - 8.0)
            target.x = planar.x
            target.z = planar.y
        _update_pose()

func handle_observation_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _dragging = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            size = maxf(90.0, size * 0.88)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            size = minf(420.0, size / 0.88)
    elif event is InputEventMouseMotion and _dragging:
        yaw -= event.relative.x * 0.006
        pitch = clampf(pitch + event.relative.y * 0.004, deg_to_rad(35.0), deg_to_rad(75.0))
        _update_pose()

func _update_pose() -> void:
    var horizontal := orbit_distance * cos(pitch)
    position = target + Vector3(sin(yaw) * horizontal, orbit_distance * sin(pitch), cos(yaw) * horizontal)
    look_at(target, Vector3.UP)
