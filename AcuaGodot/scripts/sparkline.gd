class_name SparkLine
extends Control
# Mini gráfico de línea (historial de precios).

var values: Array = []

func _init() -> void:
    custom_minimum_size = Vector2(0, 48)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.14, 0.2))
    if values.size() < 2:
        return
    var lo: float = 1.0e9
    var hi: float = -1.0e9
    for v in values:
        lo = minf(lo, float(v))
        hi = maxf(hi, float(v))
    if hi - lo < 0.01:
        hi = lo + 0.01
    var pts := PackedVector2Array()
    for i in values.size():
        var x := size.x * i / float(values.size() - 1)
        var y: float = size.y - 4.0 - (size.y - 8.0) * (float(values[i]) - lo) / (hi - lo)
        pts.append(Vector2(x, y))
    draw_polyline(pts, Color(0.95, 0.7, 0.25), 2.0)
    var f := ThemeDB.fallback_font
    draw_string(f, Vector2(4, 12), "%.2f" % hi, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.6))
    draw_string(f, Vector2(4, size.y - 3), "%.2f" % lo, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.6))
