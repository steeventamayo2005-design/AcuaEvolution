class_name Critters
extends RefCounted
# Modelos procedurales de animales acuáticos con animación sencilla (cola, pulso, balanceo).

static func _mat(c: Color, rough: float = 0.45, metal: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    m.metallic = metal
    return m

static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.scale = scl
    mi.rotation_degrees = rot
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi

static func _sphere(r: float, seg: int = 14, rings: int = 7) -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    s.radial_segments = seg
    s.rings = rings
    return s

static func _prism(w: float, h: float, d: float) -> PrismMesh:
    var p := PrismMesh.new()
    p.size = Vector3(w, h, d)
    return p

# Pez: cabeza hacia +X, largo aprox. 1,6 con la cola.
static func fish(c: Color) -> Node3D:
    var root := Node3D.new()
    var body_mat := _mat(c, 0.35, 0.15)
    body_mat.set_meta("recolor", true)
    _mesh(root, _sphere(0.5), body_mat, Vector3.ZERO, Vector3(1.5, 0.62, 0.34))
    _mesh(root, _sphere(0.5), _mat(c.lightened(0.55), 0.4), Vector3(0.02, -0.12, 0.0), Vector3(1.25, 0.34, 0.3))
    var dorsal_mat := _mat(c.darkened(0.2), 0.5)
    dorsal_mat.set_meta("recolor_dark", true)
    _mesh(root, _prism(0.5, 0.3, 0.04), dorsal_mat, Vector3(-0.05, 0.3, 0.0))
    _mesh(root, _prism(0.22, 0.18, 0.03), dorsal_mat, Vector3(0.1, -0.27, 0.0), Vector3.ONE, Vector3(0, 0, 180))
    var tail := Node3D.new()
    tail.name = "Tail"
    tail.position = Vector3(-0.72, 0.0, 0.0)
    root.add_child(tail)
    _mesh(tail, _prism(0.5, 0.55, 0.04), dorsal_mat, Vector3(-0.2, 0.0, 0.0), Vector3.ONE, Vector3(0, 0, -90))
    var eye := _mat(Color(0.02, 0.02, 0.02), 0.2)
    _mesh(root, _sphere(0.05, 8, 4), eye, Vector3(0.6, 0.08, 0.14))
    _mesh(root, _sphere(0.05, 8, 4), eye, Vector3(0.6, 0.08, -0.14))
    return root

static func recolor(node: Node3D, c: Color) -> void:
    for ch in node.get_children():
        if ch is MeshInstance3D:
            var m := ch.material_override as StandardMaterial3D
            if m != null and m.has_meta("recolor"):
                m.albedo_color = c
            elif m != null and m.has_meta("recolor_dark"):
                m.albedo_color = c.darkened(0.2)
        elif ch is Node3D:
            recolor(ch, c)

static func shrimp() -> Node3D:
    var root := Node3D.new()
    var c := Color(0.95, 0.68, 0.6)
    var m := _mat(c, 0.4)
    var caps := CapsuleMesh.new()
    caps.radius = 0.07
    caps.height = 0.26
    for i in 4:
        _mesh(root, caps, m, Vector3(0.28 - i * 0.2, 0.03 * i, 0.0), Vector3(1.0, 1.0 - i * 0.12, 1.0), Vector3(0, 0, 90 + i * 12))
    var tail := Node3D.new()
    tail.name = "Tail"
    tail.position = Vector3(-0.58, 0.1, 0.0)
    root.add_child(tail)
    _mesh(tail, _prism(0.2, 0.18, 0.03), m, Vector3(-0.08, 0.0, 0.0), Vector3.ONE, Vector3(0, 0, -90))
    var ant := CylinderMesh.new()
    ant.top_radius = 0.004
    ant.bottom_radius = 0.008
    ant.height = 0.5
    _mesh(root, ant, m, Vector3(0.55, 0.12, 0.05), Vector3.ONE, Vector3(0, 0, 70))
    _mesh(root, ant, m, Vector3(0.55, 0.12, -0.05), Vector3.ONE, Vector3(0, 0, 70))
    _mesh(root, _sphere(0.02, 6, 3), _mat(Color.BLACK), Vector3(0.38, 0.06, 0.05))
    return root

static func jelly(c: Color) -> Node3D:
    var root := Node3D.new()
    var bell_mat := StandardMaterial3D.new()
    bell_mat.albedo_color = Color(c.r, c.g, c.b, 0.55)
    bell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    bell_mat.emission_enabled = true
    bell_mat.emission = c
    bell_mat.emission_energy_multiplier = 0.6
    bell_mat.roughness = 0.1
    var bell := Node3D.new()
    bell.name = "Bell"
    root.add_child(bell)
    var hs := SphereMesh.new()
    hs.radius = 0.25
    hs.height = 0.25
    hs.is_hemisphere = true
    hs.radial_segments = 16
    hs.rings = 6
    _mesh(bell, hs, bell_mat, Vector3.ZERO)
    var tm := CylinderMesh.new()
    tm.top_radius = 0.006
    tm.bottom_radius = 0.01
    tm.height = 0.45
    var tent_mat := _mat(Color(c.r, c.g, c.b), 0.3)
    tent_mat.emission_enabled = true
    tent_mat.emission = c
    for i in 7:
        var a := i * TAU / 7.0
        _mesh(root, tm, tent_mat, Vector3(cos(a) * 0.15, -0.22, sin(a) * 0.15))
    return root

static func crab() -> Node3D:
    var root := Node3D.new()
    var c := Color(0.8, 0.2, 0.12)
    var m := _mat(c, 0.5)
    _mesh(root, _sphere(0.25), m, Vector3.ZERO, Vector3(1.2, 0.45, 1.0))
    _mesh(root, _sphere(0.1), m, Vector3(0.38, 0.0, 0.25))
    _mesh(root, _sphere(0.1), m, Vector3(0.38, 0.0, -0.25))
    var lm := CylinderMesh.new()
    lm.top_radius = 0.012
    lm.bottom_radius = 0.012
    lm.height = 0.3
    for i in 3:
        for s in [-1.0, 1.0]:
            _mesh(root, lm, m, Vector3(0.12 - i * 0.14, -0.05, 0.3 * s), Vector3.ONE, Vector3(70.0 * s, 0, 0))
    _mesh(root, _sphere(0.025, 6, 3), _mat(Color.BLACK), Vector3(0.28, 0.12, 0.1))
    _mesh(root, _sphere(0.025, 6, 3), _mat(Color.BLACK), Vector3(0.28, 0.12, -0.1))
    return root

static func seaweed(c: Color) -> Node3D:
    var root := Node3D.new()
    var m := _mat(c, 0.6)
    var bm := BoxMesh.new()
    bm.size = Vector3(0.12, 0.7, 0.01)
    for i in 6:
        var leaf := Node3D.new()
        leaf.name = "Leaf%d" % i
        leaf.position = Vector3(cos(i * 1.1) * 0.1, 0.0, sin(i * 1.1) * 0.1)
        root.add_child(leaf)
        _mesh(leaf, bm, m, Vector3(0, 0.35, 0), Vector3.ONE, Vector3(0, i * 60.0, 0))
    return root

static func clam() -> Node3D:
    var root := Node3D.new()
    var hs := SphereMesh.new()
    hs.radius = 0.1
    hs.height = 0.1
    hs.is_hemisphere = true
    _mesh(root, hs, _mat(Color(0.15, 0.13, 0.12), 0.8), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
    return root

static func make(kind: String, c: Color) -> Node3D:
    match kind:
        "shrimp": return shrimp()
        "jelly": return jelly(c)
        "crab": return crab()
        "algae": return seaweed(c)
        "clam": return clam()
    return fish(c)

# Animación por tipo. t en segundos, ph = fase individual.
static func anim(node: Node3D, kind: String, t: float, ph: float) -> void:
    match kind:
        "fish":
            var tail := node.get_node_or_null("Tail")
            if tail != null:
                tail.rotation.y = sin(t * 9.0 + ph) * 0.55
        "shrimp":
            var tl := node.get_node_or_null("Tail")
            if tl != null:
                tl.rotation.z = sin(t * 6.0 + ph) * 0.25
        "jelly":
            var bell := node.get_node_or_null("Bell")
            if bell != null:
                var k := 1.0 + sin(t * 2.2 + ph) * 0.16
                bell.scale = Vector3(k, 2.0 - k, k)
        "algae":
            for i in 6:
                var lf := node.get_node_or_null("Leaf%d" % i)
                if lf != null:
                    lf.rotation.z = sin(t * 1.3 + ph + i) * 0.25
                    lf.rotation.x = cos(t * 1.1 + ph + i) * 0.2
