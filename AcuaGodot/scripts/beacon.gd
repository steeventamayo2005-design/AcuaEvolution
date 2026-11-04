extends MeshInstance3D
# Baliza de actividad sobre cada módulo: el color indica el estado y gira cuando produce.

var uid := -1
var _mat: StandardMaterial3D
var _t := 0.0
var _spin := false

func _ready() -> void:
    var bm := BoxMesh.new()
    bm.size = Vector3(0.5, 0.5, 0.5)
    mesh = bm
    _mat = StandardMaterial3D.new()
    _mat.emission_enabled = true
    material_override = _mat
    _apply()

func _process(dt: float) -> void:
    if _spin:
        rotate_y(dt * 3.0)
    _t += dt
    if _t < 0.4:
        return
    _t = 0.0
    _apply()

func _apply() -> void:
    var b: Dictionary = Ops.by_uid(uid)
    var st := "off"
    if not b.is_empty():
        st = str(b.get("st", {}).get("state", "idle"))
    var col: Color = Ops.state_color(st)
    _mat.albedo_color = col
    _mat.emission = col
    _mat.emission_energy_multiplier = 2.2 if st == "producing" else 0.7
    _spin = st == "producing" or st == "partial"
