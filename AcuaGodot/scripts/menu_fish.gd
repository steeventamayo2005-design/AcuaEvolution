extends Node2D
# Peces nadando en el fondo del menú principal.

var fishes: Array = []

func _ready() -> void:
    var sz := get_viewport_rect().size
    for i in 12:
        fishes.append({"x": randf() * sz.x, "y": randf() * sz.y, "v": 12.0 + randf() * 28.0, "s": 0.6 + randf() * 1.1,
            "k": randi() % 3, "ph": randf() * 6.28, "dir": 1.0 if randf() < 0.5 else -1.0})

func _process(dt: float) -> void:
    var sz := get_viewport_rect().size
    for f in fishes:
        f.x += f.v * f.dir * dt
        if f.dir > 0.0 and f.x > sz.x + 60.0:
            f.x = -60.0
        elif f.dir < 0.0 and f.x < -60.0:
            f.x = sz.x + 60.0
    queue_redraw()

func _draw() -> void:
    var t := Time.get_ticks_msec() / 1000.0
    for f in fishes:
        var y: float = f.y + sin(t * 0.8 + f.ph) * 10.0
        _fish(Vector2(f.x, y), f.s, f.dir, f.k, t + f.ph)

func _fish(p: Vector2, s: float, dir: float, kind: int, t: float) -> void:
    var body := Color(0.92, 0.5, 0.2)
    if kind == 1:
        body = Color(0.95, 0.95, 0.92)
    elif kind == 2:
        body = Color(0.55, 0.62, 0.6)
    var pts := PackedVector2Array()
    for i in 20:
        var a := i * TAU / 20.0
        pts.append(p + Vector2(cos(a) * 26.0 * s * dir, sin(a) * 10.0 * s))
    draw_colored_polygon(pts, body)
    var wag := sin(t * 5.0) * 4.0 * s
    draw_colored_polygon(PackedVector2Array([
        p + Vector2(-22.0 * s * dir, 0.0),
        p + Vector2(-40.0 * s * dir, -10.0 * s + wag),
        p + Vector2(-40.0 * s * dir, 10.0 * s + wag)]), body.darkened(0.15))
    if kind == 1:
        draw_circle(p + Vector2(4.0 * s * dir, -3.0 * s), 5.0 * s, Color(0.85, 0.12, 0.1))
        draw_circle(p + Vector2(-10.0 * s * dir, 2.0 * s), 4.0 * s, Color(0.85, 0.12, 0.1))
    elif kind == 2:
        draw_line(p + Vector2(-16.0 * s * dir, 0.0), p + Vector2(18.0 * s * dir, 0.0), Color(0.85, 0.5, 0.5), 2.0 * s)
    draw_circle(p + Vector2(17.0 * s * dir, -2.0 * s), 1.8 * s, Color.BLACK)
