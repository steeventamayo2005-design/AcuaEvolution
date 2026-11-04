extends Node3D
# Cardumen / grupo de animales que nadan dentro de un estanque (rectangular o circular).

var kind := "fish"
var color := Color(0.8, 0.5, 0.3)
var count := 10
var half := Vector2(4, 2)      # semiextensión en x,z
var water_y := 0.9
var depth := 0.6
var circular := false
var scale_f := 0.35
var _items: Array = []

func setup() -> void:
    for i in count:
        var c := color
        if kind == "fish":
            c = color.lightened(randf() * 0.2)
        var n := Critters.make(kind, c)
        n.scale = Vector3.ONE * scale_f * (0.8 + randf() * 0.4)
        add_child(n)
        _items.append({"n": n, "a": randf() * TAU, "s": 0.2 + randf() * 0.35, "r": 0.4 + randf() * 0.55, "y": randf(), "ph": randf() * 6.28})

func _process(_dt: float) -> void:
    var t := Time.get_ticks_msec() / 1000.0
    for it in _items:
        var n: Node3D = it.n
        var a: float = it.a + t * it.s
        var r: float = it.r
        var y := water_y - 0.15 - depth * float(it.y)
        var px := cos(a) * half.x * r
        var pz := sin(a) * half.y * r
        if circular:
            px = cos(a) * half.x * r
            pz = sin(a) * half.x * r
        match kind:
            "algae":
                px = (float(it.r) - 0.7) * half.x * 1.6
                pz = (float(it.y) - 0.5) * half.y * 1.6
                y = water_y - depth
            "shrimp", "crab":
                y = water_y - depth - 0.05
            "jelly":
                y = water_y - 0.3 - depth * (0.5 + 0.5 * sin(t * 0.5 + float(it.ph)))
        n.position = Vector3(px, y, pz)
        if kind != "algae":
            n.rotation.y = -a - PI / 2.0
        Critters.anim(n, kind, t, float(it.ph))
