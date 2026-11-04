extends CharacterBody3D
# Jugador en primera persona. WASD mover, Shift correr, ratón mirar, E interactuar, Tab ratón libre, Esc cerrar.

const SPEED := 3.4
const SENS := 0.0022
var ui
var cam: Camera3D
var ray: RayCast3D
var pitch := 0.0

func _ready() -> void:
    var col := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.3
    cap.height = 1.8
    col.shape = cap
    col.position.y = 0.9
    add_child(col)
    cam = Camera3D.new()
    cam.position.y = 1.65
    cam.near = 0.05
    cam.fov = 75.0
    cam.current = true
    add_child(cam)
    ray = RayCast3D.new()
    ray.target_position = Vector3(0, 0, -3.5)
    ray.add_exception(self)
    cam.add_child(ray)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    var open: bool = ui.panel_open() or Game.overlay_open
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not open:
        rotate_y(-event.relative.x * SENS)
        pitch = clampf(pitch - event.relative.y * SENS, -1.4, 1.4)
        cam.rotation.x = pitch
    elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not open:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_E:
            if open:
                ui.close_panel()
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            else:
                _interact()
        elif event.keycode == KEY_ESCAPE:
            if open:
                ui.close_panel()
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            else:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        elif event.keycode >= KEY_1 and event.keycode <= KEY_5 and not open:
            Game.time_scale = [1, 3, 10, 30, 100][event.keycode - KEY_1]
            Game.say("Velocidad ×%d" % Game.time_scale)
        elif event.keycode == KEY_0 and not open:
            Game.time_scale = 0
            Game.say("Pausa")
        elif (event.keycode == KEY_M or event.keycode == KEY_TAB) and not open:
            Game.flag("tablet")
            get_tree().current_scene.toggle_tablet()

func _interact() -> void:
    if not ray.is_colliding():
        return
    var o = ray.get_collider()
    if o == null or not o.has_meta("kind"):
        return
    match o.get_meta("kind"):
        "tank":
            ui.open_tank(Game.tanks[o.get_meta("idx")])
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        "shop":
            ui.open_shop()
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        "valve":
            Game.say(Game.tanks[o.get_meta("idx")].water_change())
        "table":
            Game.flag("tablet")
            get_tree().current_scene.toggle_tablet()
        "aerator":
            var t: WaterTank = Game.tanks[o.get_meta("idx")]
            if t.aeration > 0.0:
                t.aeration = 0.0
                Game.say("Aireador apagado")
            else:
                t.aeration = 60.0
                Game.say("Aireador encendido (60 %)")

func _physics_process(delta: float) -> void:
    var open: bool = ui.panel_open() or Game.overlay_open
    var dir := Vector3.ZERO
    if not open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        if Input.is_physical_key_pressed(KEY_W):
            dir -= transform.basis.z
        if Input.is_physical_key_pressed(KEY_S):
            dir += transform.basis.z
        if Input.is_physical_key_pressed(KEY_D):
            dir += transform.basis.x
        if Input.is_physical_key_pressed(KEY_A):
            dir -= transform.basis.x
    dir = dir.normalized()
    var sp := SPEED * (1.7 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
    velocity.x = dir.x * sp
    velocity.z = dir.z * sp
    if is_on_floor():
        velocity.y = -0.5
    else:
        velocity.y -= 9.8 * delta
    move_and_slide()
    var hp := Vector2(position.x, position.z)
    if hp.length() > Game.DOME_R - 3.0:
        hp = hp.normalized() * (Game.DOME_R - 3.0)
        position.x = hp.x
        position.z = hp.y
    var p := ""
    if not open and ray.is_colliding():
        var o = ray.get_collider()
        if o != null and o.has_meta("prompt"):
            p = o.get_meta("prompt")
    ui.prompt = p

func teleport(pos: Vector3, yaw: float) -> void:
    position = pos
    velocity = Vector3.ZERO
    rotation.y = yaw
    pitch = 0.0
    cam.rotation.x = 0.0
