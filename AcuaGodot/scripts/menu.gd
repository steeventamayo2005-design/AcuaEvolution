extends Control
# Menú principal: imagen de fondo con botones transparentes encima; si falta la imagen usa un diseño sencillo.

const IMG_SIZE := Vector2(1024, 618)
const BTN_X := 432.0
const BTN_W := 160.0
const BTN_H := 32.0
const BTN_Y := [420.0, 457.0, 495.0, 533.0, 570.0]

var _msg: Label
var _bg: TextureRect
var _buttons: Array = []

func _flat(c: Color, border: Color) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = c
    sb.set_corner_radius_all(8)
    sb.border_color = border
    sb.set_border_width_all(1)
    return sb

func _ready() -> void:
    Game.time_scale = 0
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var back := ColorRect.new()
    back.color = Color(0.05, 0.09, 0.12)
    back.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(back)
    var tex: Texture2D = null
    if ResourceLoader.exists("res://assets/ui/menu_bg.png"):
        tex = load("res://assets/ui/menu_bg.png") as Texture2D
    var actions := [_continue, _new_game, _load, _soon, _quit]
    var names := ["Continuar", "Nueva partida", "Cargar partida", "Ajustes", "Salir"]
    if tex != null:
        _bg = TextureRect.new()
        _bg.texture = tex
        _bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        _bg.stretch_mode = TextureRect.STRETCH_SCALE
        add_child(_bg)
        for i in 5:
            var b := Button.new()
            b.flat = true
            b.text = ""
            b.tooltip_text = names[i]
            b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
            b.add_theme_stylebox_override("hover", _flat(Color(0.3, 0.9, 0.9, 0.12), Color(0.4, 0.95, 0.95, 0.9)))
            b.add_theme_stylebox_override("pressed", _flat(Color(0.3, 0.9, 0.9, 0.25), Color(0.4, 0.95, 0.95, 1.0)))
            b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
            b.pressed.connect(actions[i])
            add_child(b)
            _buttons.append(b)
        resized.connect(_layout)
        _layout()
    else:
        var cc := CenterContainer.new()
        cc.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(cc)
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 10)
        cc.add_child(vb)
        var title := Label.new()
        title.text = "ACUAEVOLUTION"
        title.add_theme_font_size_override("font_size", 72)
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vb.add_child(title)
        for i in 5:
            var b := Button.new()
            b.text = names[i]
            b.custom_minimum_size = Vector2(300, 0)
            b.pressed.connect(actions[i])
            vb.add_child(b)
    _msg = Label.new()
    _msg.add_theme_color_override("font_color", Color(1, 0.84, 0.54))
    add_child(_msg)
    _msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 20)
    _msg.grow_horizontal = Control.GROW_DIRECTION_BOTH
    var ver := Label.new()
    ver.text = "Beta de prueba · v0.5.4"
    ver.modulate = Color(1, 1, 1, 0.45)
    add_child(ver)
    ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
    ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    ver.grow_vertical = Control.GROW_DIRECTION_BEGIN

# Ajusta la imagen (sin deformarla) y coloca los botones sobre los dibujados en ella.
func _layout() -> void:
    var s := minf(size.x / IMG_SIZE.x, size.y / IMG_SIZE.y)
    var img := IMG_SIZE * s
    var off := (size - img) / 2.0
    _bg.position = off
    _bg.size = img
    for i in _buttons.size():
        var b: Button = _buttons[i]
        b.position = off + Vector2(BTN_X, float(BTN_Y[i]) - BTN_H / 2.0) * s
        b.size = Vector2(BTN_W, BTN_H) * s

func _go_game() -> void:
    Game.time_scale = 1
    get_tree().change_scene_to_file("res://main.tscn")

func _continue() -> void:
    if SaveGame.exists():
        SaveGame.load_game()
    _go_game()

func _new_game() -> void:
    Game.reset_all()
    _go_game()

func _load() -> void:
    if SaveGame.exists() and SaveGame.load_game():
        _go_game()
    else:
        _msg.text = "No hay partida guardada"

func _soon() -> void:
    _msg.text = "Disponible en una próxima versión"

func _quit() -> void:
    get_tree().quit()
