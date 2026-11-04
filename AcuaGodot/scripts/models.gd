class_name Models
extends RefCounted
# Modelos 3D opcionales: copia archivos .glb o .gltf a res://assets/models/ con estos nombres y se usan
# en lugar de las piezas procedurales: barrel, gas_cylinder, pallet.

static func path(n: String) -> String:
    for ext in ["glb", "gltf"]:
        var p := "res://assets/models/%s.%s" % [n, ext]
        if ResourceLoader.exists(p):
            return p
    return ""

static func has(n: String) -> bool:
    return path(n) != ""

static func spawn(parent: Node, n: String, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: float = 1.0) -> Node3D:
    var p := path(n)
    if p == "":
        return null
    var ps = load(p)
    if ps == null:
        return null
    var inst: Node3D = ps.instantiate()
    inst.position = pos
    inst.rotation_degrees = rot_deg
    inst.scale = Vector3.ONE * scl
    parent.add_child(inst)
    return inst
