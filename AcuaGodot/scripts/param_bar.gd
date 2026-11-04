class_name ParamBar
extends Control
# Barra de parámetro con zona óptima marcada.

var label := ""
var unit := ""
var vmin := 0.0
var vmax := 1.0
var opt_a := 0.0
var opt_b := 1.0
var value := 0.0

func _init() -> void:
    custom_minimum_size = Vector2(0, 22)

func _q(v: float) -> float:
    return clampf((v - vmin) / (vmax - vmin), 0.0, 1.0)

func _draw() -> void:
    var f := ThemeDB.fallback_font
    draw_string(f, Vector2(0, 16), label, HORIZONTAL_ALIGNMENT_LEFT, 110, 14)
    draw_string(f, Vector2(112, 16), "%.2f %s" % [value, unit], HORIZONTAL_ALIGNMENT_LEFT, 100, 14)
    var x0 := 215.0
    var w := maxf(10.0, size.x - x0)
    draw_rect(Rect2(x0, 6, w, 10), Color(0.1, 0.18, 0.23))
    draw_rect(Rect2(x0 + w * _q(opt_a), 6, w * (_q(opt_b) - _q(opt_a)), 10), Color(0.2, 0.5, 0.3, 0.6))
    var m := (vmax - vmin) * 0.15
    var c := Color(0.84, 0.33, 0.33)
    if value >= opt_a and value <= opt_b:
        c = Color(0.25, 0.75, 0.48)
    elif value >= opt_a - m and value <= opt_b + m:
        c = Color(0.88, 0.63, 0.2)
    draw_rect(Rect2(x0, 8, w * _q(value), 6), c)
