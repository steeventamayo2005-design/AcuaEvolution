extends Control
# Plano 2D del sitio (domo de 240 m): construir, demoler y organizar; entrar a las naves en 3D.
# Rueda = zoom · botón derecho/central = mover · WASD = mover · V/B/X = herramientas · R = rotar · E = entrar.

var cam := Vector2.ZERO
var zoom := 2.6
var tool := "select"
var build_id := ""
var rot := 0
var sel: Dictionary = {}
var mouse_w := Vector2.ZERO
var over_ui := false
var show_zones := true
var show_water := false
var show_power := true
var _panels: Array = []
var _t := 0.0
var _date: Label
var _money: Label
var _bal: Label
var _salt: Label
var _spark: SparkLine
var _gen_root: CenterContainer
var _gen_box: VBoxContainer
var overlay := false
var _ctr: Label
var _scada_root: CenterContainer
var _sc_waste: Label
var _ops_lbl: Label
var _ops_t := 0.0
var _sc_status: Label
var _sc_temp: ParamBar
var _sc_alarms: Label
var _sc_auto_btn: Button
var _sc_sparks: Array = []
var _sc_labels: Array = []
var _toast: Label
var _bars := {}
var _info_box: VBoxContainer
var _tool_btns := {}
var _font: Font

# ---------------------------------------------------------------- utilidades
func _w2s(p: Vector2) -> Vector2:
    return (p - cam) * zoom + size / 2.0

func _s2w(s: Vector2) -> Vector2:
    return (s - size / 2.0) / zoom + cam

func _dark(radius: int = 10, alpha: float = 0.92) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.05, 0.10, 0.15, alpha)
    sb.set_corner_radius_all(radius)
    sb.border_color = Color(0.16, 0.27, 0.35)
    sb.set_border_width_all(1)
    return sb

func _lbl(t: String, fs: int = 14) -> Label:
    var l := Label.new()
    l.text = t
    l.add_theme_font_size_override("font_size", fs)
    return l

func _panel(parent: Node) -> PanelContainer:
    var pc := PanelContainer.new()
    pc.add_theme_stylebox_override("panel", _dark())
    parent.add_child(pc)
    _panels.append(pc)
    return pc

func _margin(parent: Node, m: int) -> MarginContainer:
    var mg := MarginContainer.new()
    for s in ["left", "right", "top", "bottom"]:
        mg.add_theme_constant_override("margin_" + s, m)
    parent.add_child(mg)
    return mg

func _fmt(v: float) -> String:
    if v >= 1000000.0:
        return "%.1f M" % (v / 1000000.0)
    if v >= 1000.0:
        return "%.1f k" % (v / 1000.0)
    return "%d" % int(v)

func _zone_name(z: Dictionary) -> String:
    return ("Agua dulce" if z.water == "dulce" else "Agua salada") + " · " + ("cálida" if z.temp == "calida" else "fría")

# ---------------------------------------------------------------- interfaz
func _ready() -> void:
    _font = ThemeDB.fallback_font
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_top()
    _build_bars()
    _build_palette()
    _build_info()
    _build_toolbar()
    _build_gen()
    _build_scada()
    _toast = _lbl("", 14)
    _toast.add_theme_color_override("font_color", Color(1, 0.84, 0.54))
    add_child(_toast)
    _toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 70)
    _toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
    Game.report = Game.economy_report()
    _refresh_info()
    _update_hud()

func _build_top() -> void:
    var pc := _panel(self)
    pc.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 10)
    var mg := _margin(pc, 8)
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 12)
    mg.add_child(hb)
    _date = _lbl("")
    hb.add_child(_date)
    for s in [0, 1, 3, 10, 30, 100]:
        var b := Button.new()
        b.text = "Pausa" if s == 0 else "%d×" % s
        b.flat = true
        b.pressed.connect(func(): Game.time_scale = s)
        hb.add_child(b)
    _money = _lbl("")
    hb.add_child(_money)
    _bal = _lbl("")
    hb.add_child(_bal)
    _salt = _lbl("")
    hb.add_child(_salt)
    _ctr = _lbl("")
    hb.add_child(_ctr)

func _mkbar(parent: Node, key: String, label: String, unit: String, vmin: float, vmax: float, a: float, b: float) -> void:
    var pb := ParamBar.new()
    pb.label = label
    pb.unit = unit
    pb.vmin = vmin
    pb.vmax = vmax
    pb.opt_a = a
    pb.opt_b = b
    parent.add_child(pb)
    _bars[key] = pb

func _build_bars() -> void:
    var pc := _panel(self)
    pc.position = Vector2(10, 62)
    pc.custom_minimum_size = Vector2(350, 0)
    var mg := _margin(pc, 10)
    var vb := VBoxContainer.new()
    mg.add_child(vb)
    vb.add_child(_lbl("Estado del sitio", 14))
    _mkbar(vb, "energy", "Energía", "%", 0.0, 200.0, 100.0, 200.0)
    _mkbar(vb, "water", "Agua", "%", 0.0, 200.0, 100.0, 200.0)
    _mkbar(vb, "o2", "Oxígeno", "mg/L", 0.0, 12.0, 5.0, 10.0)
    _mkbar(vb, "bio", "Biomasa", "t", 0.0, 50.0, 0.0, 50.0)
    vb.add_child(_lbl("Mercado de sal ($/kg)", 12))
    _spark = SparkLine.new()
    vb.add_child(_spark)

func _build_palette() -> void:
    var pc := _panel(self)
    pc.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
    pc.offset_left = -350
    pc.offset_right = -10
    pc.offset_top = 10
    pc.offset_bottom = -72
    var mg := _margin(pc, 10)
    var vb := VBoxContainer.new()
    mg.add_child(vb)
    vb.add_child(_lbl("Construcción", 16))
    var sc := ScrollContainer.new()
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vb.add_child(sc)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(list)
    for c in Catalog.CATS:
        var h := _lbl(c[1], 14)
        h.add_theme_color_override("font_color", Color(0.3, 0.85, 0.8))
        list.add_child(h)
        for id in Catalog.BUILDINGS:
            var d: Dictionary = Game.def(id)
            if d.cat != c[0]:
                continue
            var b := Button.new()
            b.text = "%s · %s $ · %d×%d m" % [d.name, _fmt(d.cost), int(d.w), int(d.d)]
            b.alignment = HORIZONTAL_ALIGNMENT_LEFT
            b.clip_text = true
            b.tooltip_text = d.desc
            b.disabled = d.get("locked", false)
            b.pressed.connect(_choose.bind(id))
            list.add_child(b)

func _build_toolbar() -> void:
    var cc := CenterContainer.new()
    cc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    cc.offset_top = -60
    cc.offset_bottom = -10
    cc.offset_right = -360
    cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(cc)
    var pc := _panel(cc)
    var mg := _margin(pc, 6)
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 6)
    mg.add_child(hb)
    for t in [["select", "Seleccionar (V)"], ["build", "Construir (B)"], ["demolish", "Demoler (X)"]]:
        var b := Button.new()
        b.text = t[1]
        b.toggle_mode = true
        b.pressed.connect(_set_tool.bind(t[0]))
        hb.add_child(b)
        _tool_btns[t[0]] = b
    var rb := Button.new()
    rb.text = "Rotar (R)"
    rb.pressed.connect(func(): rot = 1 - rot)
    hb.add_child(rb)
    var eb := Button.new()
    eb.text = "Ir allí (E)"
    eb.pressed.connect(_enter)
    hb.add_child(eb)
    for t in [["Zonas", "z"], ["Agua", "w"], ["Energía", "p"]]:
        var b := Button.new()
        b.text = t[0]
        b.toggle_mode = true
        b.button_pressed = (t[1] == "z" or t[1] == "p")
        b.toggled.connect(_toggle_layer.bind(t[1]))
        hb.add_child(b)
    var gb := Button.new()
    gb.text = "Genética (G)"
    gb.pressed.connect(_toggle_gen)
    hb.add_child(gb)
    var sb := Button.new()
    sb.text = "SCADA (K)"
    sb.pressed.connect(_toggle_scada)
    hb.add_child(sb)
    var mb := Button.new()
    mb.text = "Cerrar tableta (Tab)" if overlay else "Guardar y salir"
    mb.pressed.connect(_close_or_exit)
    hb.add_child(mb)
    _set_tool("select")

func _build_info() -> void:
    var pc := _panel(self)
    pc.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    pc.offset_left = 10
    pc.offset_right = 400
    pc.offset_top = -90
    pc.offset_bottom = -72
    pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
    var mg := _margin(pc, 10)
    _info_box = VBoxContainer.new()
    mg.add_child(_info_box)

func _toggle_layer(on: bool, which: String) -> void:
    if which == "z":
        show_zones = on
    elif which == "w":
        show_water = on
    else:
        show_power = on

func _set_tool(t: String) -> void:
    tool = t
    for k in _tool_btns:
        _tool_btns[k].set_pressed_no_signal(k == t)
    if t != "build":
        build_id = ""
    elif build_id == "":
        Game.say("Elige un edificio en la paleta de la derecha")
    _refresh_info()

func _choose(id: String) -> void:
    build_id = id
    rot = 0
    sel = {}
    _set_tool("build")
    build_id = id
    _refresh_info()

func _refresh_info() -> void:
    for ch in _info_box.get_children():
        ch.queue_free()
    if tool == "build" and build_id != "":
        var bd: Dictionary = Game.def(build_id)
        _info_box.add_child(_lbl(bd.name, 16))
        _info_box.add_child(_wrap("Clic para construir · R rota · Shift = rejilla de 5 m · Clic derecho cancela.\n" + bd.desc))
        _info_box.add_child(_lbl(_stats(bd), 13))
        return
    if sel.is_empty():
        _info_box.add_child(_lbl("Plano del sitio", 16))
        _info_box.add_child(_wrap("Selecciona un edificio para ver sus datos. Elige uno en la paleta para construir. La nave de tilapia y el hatchery se pueden recorrer con E."))
        return
    var d: Dictionary = Game.def(sel.id)
    var s: Vector2 = Game.size_of(sel)
    _info_box.add_child(_lbl(d.name, 16))
    _info_box.add_child(_lbl("%d×%d m (%d m²)" % [int(s.x), int(s.y), int(s.x * s.y)], 13))
    var st := Game.zone_status(sel)
    if st.applies:
        var need := {"water": d.water, "temp": d.temp}
        _info_box.add_child(_lbl("Zona: " + _zone_name(st.zone) + " · requiere: " + _zone_name(need), 13))
        if st.match:
            _info_box.add_child(_lbl("En su zona: rendimiento ×1", 13))
        elif sel.cond:
            _info_box.add_child(_lbl("Acondicionado: rendimiento ×%d" % int(Game.mult(sel)), 13))
        else:
            _info_box.add_child(_lbl("Fuera de zona sin acondicionar: ×0,5", 13))
    if st.applies:
        var n := Game.salinity_need(sel)
        if not n.is_empty():
            _info_box.add_child(_wrap(_sal_text(n)))
    _info_box.add_child(_lbl(_stats(d), 13))
    _info_box.add_child(_wrap(d.desc))
    _ops_lbl = null
    if Ops.has(sel):
        _ops_lbl = OpsPanel.build(_info_box, sel, _refresh_info)
    var hb := HBoxContainer.new()
    _info_box.add_child(hb)
    var gb := Button.new()
    gb.text = "Ir allí (E)"
    gb.pressed.connect(_enter)
    hb.add_child(gb)
    if d.cat == "produccion" or d.cat == "alimento" or d.cat == "hatchery":
        if sel.get("auto", false):
            _info_box.add_child(_lbl("Automatizado por Heimdall (ingreso ×1,2)", 13))
        else:
            var ab := Button.new()
            ab.text = "Automatizar con IA ($%d)" % Game.auto_cost(sel)
            ab.disabled = not Game.can_automate()
            ab.tooltip_text = "Requiere Oficina SCADA y Hub de servidores en línea"
            ab.pressed.connect(_automate_sel)
            hb.add_child(ab)
    if st.applies and not st.match and not sel.cond:
        var b := Button.new()
        b.text = "Acondicionar ($%.0f)" % Game.cond_total(sel).total
        b.pressed.connect(_condition)
        hb.add_child(b)
    if d.has("mod"):
        var m: Dictionary = Game.module_def(d.mod)
        var b := Button.new()
        b.text = "Mejorar nivel %d → %d ($%d)" % [Game.module_levels[d.mod], Game.module_levels[d.mod] + 1, Game.module_cost(m)]
        b.disabled = Game.module_levels[d.mod] >= 5
        b.pressed.connect(_upgrade)
        hb.add_child(b)
    if sel.id != "tilapia_nave":
        var b := Button.new()
        b.text = "Demoler"
        b.pressed.connect(_demolish_sel)
        hb.add_child(b)

func _wrap(t: String) -> Label:
    var l := _lbl(t, 13)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(360, 0)
    return l

func _stats(d: Dictionary) -> String:
    var parts: Array = []
    if d.has("kw"):
        parts.append("%+.0f kW" % d.kw)
    if d.has("m3"):
        parts.append("%+.0f m³/d" % d.m3)
    if d.get("income", 0.0) > 0.0:
        parts.append("ingreso %.0f $/d" % d.income)
    if d.get("opex", 0.0) > 0.0:
        parts.append("operación %.0f $/d" % d.opex)
    if d.has("kwh"):
        parts.append("%.3f $/kWh" % d.kwh)
    if d.has("proc"):
        parts.append("procesa %.0f kg/día ×%.1f" % [d.cap, d.pmult])
    var cost: String = "costo %s $" % _fmt(d.cost)
    return cost + (" · " + " · ".join(PackedStringArray(parts)) if parts.size() > 0 else "")

func _automate_sel() -> void:
    Game.say(Game.automate(sel))
    _refresh_info()

func _condition() -> void:
    Game.say(Game.condition(sel))
    _refresh_info()

func _upgrade() -> void:
    var d: Dictionary = Game.def(sel.id)
    Game.say(Game.buy_module(Game.module_def(d.mod)))
    _refresh_info()

func _demolish_sel() -> void:
    var err := Game.demolish(sel)
    if err != "":
        Game.say(err)
    else:
        sel = {}
    _refresh_info()

func _close_or_exit() -> void:
    SaveGame.save()
    if overlay:
        get_tree().current_scene.toggle_tablet()
    else:
        get_tree().change_scene_to_file("res://menu.tscn")

func _enter() -> void:
    if sel.is_empty():
        Game.say("Selecciona un edificio para ir allí")
        return
    var s: Vector2 = Game.size_of(sel)
    var px := float(sel.x)
    var pz := float(sel.y) + s.y / 2.0 + 4.0
    var yaw := 0.0
    if sel.id == "tilapia_nave":
        px = float(sel.x) - s.x / 2.0 - 4.0
        pz = float(sel.y)
        yaw = -PI / 2.0
    elif str(sel.id).begins_with("hatchery_"):
        pz = float(sel.y) - s.y / 2.0 - 4.0
        yaw = PI
    Game.pending_tp = Vector3(px, 0.1, pz)
    Game.pending_yaw = yaw
    Game.has_tp = true
    if overlay:
        get_tree().current_scene.toggle_tablet()
    else:
        Game.say("Abre el juego principal para caminar hasta allí")

func _update_hud() -> void:
    var rep: Dictionary = Game.report
    var hh := int(Game.minutes) % 1440
    _date.text = "Día %d · %02d:%02d" % [Game.day + 1, int(hh / 60.0), hh % 60]
    _money.text = "%.0f $" % Game.money
    _bal.text = "Balance/día %+.0f $" % rep.net
    var dem: float = rep.demand
    _bars["energy"].value = 200.0 if dem <= 0.0 else rep.cap / dem * 100.0
    var wd: float = rep.water_dem
    _bars["water"].value = 200.0 if wd <= 0.0 else rep.water_sup / wd * 100.0
    var o2 := 0.0
    var n := 0
    for t in Game.tanks:
        if t.fish > 0:
            o2 += t.o2
            n += 1
    _bars["o2"].value = o2 / n if n > 0 else 8.0
    _bars["bio"].value = rep.biomass
    _salt.text = "Sal %.2f $/kg · pureza %d %%%s" % [Game.salt_price, int(Game.salt_quality * 100.0), " · ESCASEZ" if Game.salt_shortage_days > 0 else ""]
    _spark.values = Game.salt_hist
    _spark.queue_redraw()
    _ctr.text = "Contratos %d · verde %+.0f $/d" % [Game.contracts.size(), float(rep.get("green", 0.0))]
    _toast.text = Game.toast

# ---------------------------------------------------------------- entrada
func _process(dt: float) -> void:
    _t += dt
    if _t > 0.4:
        _t = 0.0
        Game.report = Game.economy_report()
    _update_hud()
    _ops_t += dt
    if _ops_t > 0.5:
        _ops_t = 0.0
        if _ops_lbl != null and is_instance_valid(_ops_lbl) and not sel.is_empty() and Ops.has(sel):
            _ops_lbl.text = Ops.status_text(sel)
    if _scada_root.visible:
        _scada_update()
    var mp := get_viewport().get_mouse_position()
    over_ui = false
    for p in _panels:
        if p.visible and p.get_global_rect().has_point(mp):
            over_ui = true
    mouse_w = _s2w(mp)
    var pan := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
        pan.x -= 1.0
    if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
        pan.x += 1.0
    if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
        pan.y -= 1.0
    if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
        pan.y += 1.0
    cam += pan * 420.0 * dt / zoom
    queue_redraw()

func _zoom_at(f: float, pos: Vector2) -> void:
    var before := _s2w(pos)
    zoom = clampf(zoom * f, 1.2, 12.0)
    cam += before - _s2w(pos)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        match event.button_index:
            MOUSE_BUTTON_WHEEL_UP:
                _zoom_at(1.12, event.position)
            MOUSE_BUTTON_WHEEL_DOWN:
                _zoom_at(1.0 / 1.12, event.position)
            MOUSE_BUTTON_LEFT:
                _click(event.position)
            MOUSE_BUTTON_RIGHT:
                if tool != "select":
                    _set_tool("select")
    elif event is InputEventMouseMotion:
        if event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
            cam -= event.relative / zoom

func _input(event: InputEvent) -> void:
    if overlay and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_M or event.keycode == KEY_TAB):
        get_viewport().set_input_as_handled()
        SaveGame.save()
        get_tree().current_scene.toggle_tablet()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_V:
                _set_tool("select")
            KEY_B:
                _set_tool("build")
            KEY_X:
                _set_tool("demolish")
            KEY_R:
                rot = 1 - rot
            KEY_E:
                _enter()
            KEY_G:
                _toggle_gen()
            KEY_K:
                _toggle_scada()

            KEY_ESCAPE:
                _set_tool("select")
            KEY_SPACE:
                Game.time_scale = 0 if Game.time_scale != 0 else 1
            KEY_DELETE:
                if not sel.is_empty():
                    _demolish_sel()

func _snap(w: Vector2) -> Vector2:
    var st := 5.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
    return (w / st).round() * st

func _pick(w: Vector2) -> Dictionary:
    for i in range(Game.buildings.size() - 1, -1, -1):
        var b: Dictionary = Game.buildings[i]
        var s: Vector2 = Game.size_of(b)
        if Rect2(b.x - s.x / 2.0, b.y - s.y / 2.0, s.x, s.y).has_point(w):
            return b
    return {}

func _click(pos: Vector2) -> void:
    var w := _s2w(pos)
    if tool == "build" and build_id != "":
        var p := _snap(w)
        var err := Game.place(build_id, p.x, p.y, rot)
        if err != "":
            Game.say(err)
        else:
            Game.say("Construido: " + str(Game.def(build_id).name))
            Game.report = Game.economy_report()
    elif tool == "demolish":
        var b := _pick(w)
        if not b.is_empty():
            var err := Game.demolish(b)
            if err != "":
                Game.say(err)
            else:
                sel = {}
                Game.say("Demolido")
                _refresh_info()
    else:
        sel = _pick(w)
        _refresh_info()

# ---------------------------------------------------------------- dibujo
func _zcol(water: String, temp: String) -> Color:
    if water == "dulce" and temp == "calida":
        return Color(0.78, 0.92, 0.66, 0.5)
    if water == "dulce":
        return Color(0.70, 0.86, 0.95, 0.5)
    if temp == "calida":
        return Color(0.96, 0.86, 0.62, 0.5)
    return Color(0.62, 0.74, 0.96, 0.5)

func _sector(a0: float, a1: float, col: Color) -> void:
    var c0 := _w2s(Vector2.ZERO)
    var rd := Game.DOME_R * zoom
    var pts := PackedVector2Array([c0])
    for i in 25:
        var a := a0 + (a1 - a0) * i / 24.0
        pts.append(c0 + Vector2(cos(a), sin(a)) * rd)
    draw_colored_polygon(pts, col)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.12, 0.16, 0.93 if overlay else 1.0))
    var c0 := _w2s(Vector2.ZERO)
    var rd := Game.DOME_R * zoom
    draw_circle(c0, rd, Color(0.80, 0.82, 0.80))
    if show_zones:
        _sector(0.0, PI / 2.0, _zcol("salada", "fria"))
        _sector(PI / 2.0, PI, _zcol("dulce", "calida"))
        _sector(PI, PI * 1.5, _zcol("dulce", "fria"))
        _sector(PI * 1.5, TAU, _zcol("salada", "calida"))
    if zoom > 1.6:
        var g := -110.0
        while g <= 110.0:
            var half := sqrt(maxf(0.0, Game.DOME_R * Game.DOME_R - g * g))
            var major := int(absf(g)) % 50 == 0
            var col := Color(0, 0, 0, 0.16 if major else 0.07)
            draw_line(_w2s(Vector2(g, -half)), _w2s(Vector2(g, half)), col, 1.0)
            draw_line(_w2s(Vector2(-half, g)), _w2s(Vector2(half, g)), col, 1.0)
            g += 10.0
    draw_arc(c0, rd + 5.0 * zoom * 0.5, 0.0, TAU, 160, Color(0.45, 0.5, 0.52), maxf(4.0, zoom * 3.0))
    draw_arc(c0, rd, 0.0, TAU, 160, Color(0.7, 0.74, 0.76), maxf(2.0, zoom))
    for i in 72:
        var a := i * TAU / 72.0
        draw_line(c0 + Vector2(cos(a), sin(a)) * rd, c0 + Vector2(cos(a + 0.04), sin(a + 0.04)) * (rd + zoom * 3.0), Color(0.85, 0.88, 0.9, 0.8), 1.0)
    if show_zones:
        var fs := int(clampf(zoom * 5.0, 10.0, 16.0))
        draw_string(_font, _w2s(Vector2(8, -108)), "AGUA SALADA · CÁLIDA", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.4, 0.3, 0.1))
        draw_string(_font, _w2s(Vector2(8, 112)), "AGUA SALADA · FRÍA", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.15, 0.25, 0.45))
        draw_string(_font, _w2s(Vector2(-108, 112)), "AGUA DULCE · CÁLIDA", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.35, 0.1))
        draw_string(_font, _w2s(Vector2(-108, -108)), "AGUA DULCE · FRÍA", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.15, 0.3, 0.4))
    _draw_networks()
    _draw_plaza(c0)
    for b in Game.buildings:
        _draw_building(b, 1.0)
    if not sel.is_empty():
        var s: Vector2 = Game.size_of(sel)
        var r := Rect2(_w2s(Vector2(sel.x, sel.y) - s / 2.0), s * zoom).grow(3.0)
        draw_rect(r, Color(0.2, 0.9, 0.95), false, 2.0)
    if tool == "demolish" and not over_ui:
        var hb := _pick(mouse_w)
        if not hb.is_empty():
            var s: Vector2 = Game.size_of(hb)
            draw_rect(Rect2(_w2s(Vector2(hb.x, hb.y) - s / 2.0), s * zoom), Color(0.9, 0.15, 0.1, 0.45))
    if tool == "build" and build_id != "" and not over_ui:
        _draw_preview()
    _draw_scale()

func _draw_plaza(c0: Vector2) -> void:
    var pr := Game.PLAZA_R * zoom
    draw_circle(c0, pr, Color(0.93, 0.93, 0.9))
    draw_arc(c0, pr * 0.85, 0.2, 4.4, 32, Color(0.5, 0.75, 0.25), maxf(2.0, zoom * 1.2))
    draw_arc(c0, pr * 0.68, 1.4, 5.5, 32, Color(0.2, 0.55, 0.75), maxf(2.0, zoom * 1.2))
    draw_arc(c0, pr * 0.51, 3.0, 6.9, 32, Color(0.9, 0.6, 0.2), maxf(2.0, zoom * 1.2))
    if zoom > 2.0:
        draw_string(_font, c0 + Vector2(-pr, 4.0), "Plaza · matriz circular", HORIZONTAL_ALIGNMENT_CENTER, pr * 2.0, 11, Color(0.2, 0.3, 0.3))

func _route(a: Vector2, b: Vector2, col: Color, w: float) -> void:
    var p1 := _w2s(a)
    var p2 := _w2s(Vector2(b.x, a.y))
    var p3 := _w2s(b)
    draw_line(p1, p2, col, w)
    draw_line(p2, p3, col, w)

func _draw_networks() -> void:
    var w := maxf(1.5, zoom * 0.35)
    var sources: Array = []
    for b in Game.buildings:
        if Game.kw_of(b) > 0.0:
            sources.append(b)
    for b in Game.buildings:
        var d: Dictionary = Game.def(b.id)
        var p := Vector2(b.x, b.y)
        if show_water and d.get("m3", 0.0) != 0.0:
            _route(p, Vector2.ZERO, Color(0.15, 0.5, 0.85, 0.8), w)
        if show_power and Game.kw_of(b) < 0.0 and sources.size() > 0:
            var best: Dictionary = sources[0]
            for s in sources:
                if p.distance_to(Vector2(s.x, s.y)) < p.distance_to(Vector2(best.x, best.y)):
                    best = s
            _route(p, Vector2(best.x, best.y), Color(0.95, 0.6, 0.15, 0.75), w)

func _draw_preview() -> void:
    var p := _snap(mouse_w)
    var err := Game.can_place(build_id, p.x, p.y, rot)
    var d: Dictionary = Game.def(build_id)
    var sz := Vector2(d.w, d.d)
    if rot == 1:
        sz = Vector2(d.d, d.w)
    var tmp := {"id": build_id, "x": p.x, "y": p.y, "rot": rot, "cond": false, "lvl": 0}
    _draw_building(tmp, 0.7)
    var r := Rect2(_w2s(p - sz / 2.0), sz * zoom)
    var col := Color(0.2, 0.9, 0.3, 0.3) if err == "" else Color(0.95, 0.2, 0.15, 0.4)
    draw_rect(r, col)
    draw_rect(r, Color(col.r, col.g, col.b, 1.0), false, 2.0)
    var z: Dictionary = Game.zone_of(p.x, p.y)
    var txt := "%s · %s" % [d.name, _zone_name(z)]
    draw_string(_font, r.position + Vector2(0, -8), txt + ("" if err == "" else " — " + err), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))

func _draw_scale() -> void:
    var y := size.y - 80.0
    var x := 420.0
    var line_len := 10.0 * zoom
    draw_line(Vector2(x, y), Vector2(x + line_len, y), Color(1, 1, 1, 0.8), 2.0)
    draw_line(Vector2(x, y - 4), Vector2(x, y + 4), Color(1, 1, 1, 0.8), 2.0)
    draw_line(Vector2(x + line_len, y - 4), Vector2(x + line_len, y + 4), Color(1, 1, 1, 0.8), 2.0)
    draw_string(_font, Vector2(x + line_len + 6.0, y + 4.0), "10 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))

func _draw_building(b: Dictionary, alpha: float) -> void:
    var d: Dictionary = Game.def(b.id)
    var s: Vector2 = Game.size_of(b)
    var r := Rect2(_w2s(Vector2(b.x, b.y) - s / 2.0), s * zoom)
    _shape(d, r, alpha)
    if minf(r.size.x, r.size.y) > 30.0:
        var nm: String = d.name
        draw_string(_font, Vector2(r.position.x, r.get_center().y + 4.0), nm, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color(0, 0, 0, 0.55 * alpha))
        draw_string(_font, Vector2(r.position.x, r.get_center().y + 3.0), nm, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color(1, 1, 1, alpha))
    var st := Game.zone_status(b)
    if st.applies and not st.match:
        var pt := r.position + Vector2(r.size.x - 8.0, 8.0)
        if b.cond:
            draw_circle(pt, 7.0, Color(0.2, 0.75, 0.3, alpha))
            draw_string(_font, pt + Vector2(-6, 4), "×%d" % int(Game.mult(b)), HORIZONTAL_ALIGNMENT_CENTER, 14, 9, Color(0, 0, 0, alpha))
        else:
            draw_circle(pt, 7.0, Color(0.95, 0.75, 0.1, alpha))
            draw_string(_font, pt + Vector2(-3, 5), "!", HORIZONTAL_ALIGNMENT_CENTER, 8, 12, Color(0.2, 0.1, 0, alpha))

func _shape(d: Dictionary, r: Rect2, a: float) -> void:
    var shape: String = d.get("shape", "box")
    var c: Color = d.get("color", Color(0.5, 0.5, 0.5))
    c.a = a
    var conc := Color(0.62, 0.64, 0.63, a)
    var ctr := r.get_center()
    var t := Time.get_ticks_msec() / 1000.0
    match shape:
        "nave", "hatchery":
            draw_rect(r, c.darkened(0.3))
            var inner := Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4))
            draw_rect(inner, c)
            if shape == "nave":
                if r.size.x >= r.size.y:
                    draw_line(Vector2(r.position.x, ctr.y), Vector2(r.end.x, ctr.y), c.lightened(0.4), 2.0)
                else:
                    draw_line(Vector2(ctr.x, r.position.y), Vector2(ctr.x, r.end.y), c.lightened(0.4), 2.0)
            else:
                draw_rect(Rect2(ctr.x - 1.5 * zoom, r.position.y, 3.0 * zoom, r.size.y), c.lightened(0.35))
                var yy := r.position.y + 8.0 * zoom
                while yy < r.end.y:
                    draw_line(Vector2(r.position.x, yy), Vector2(ctr.x - 1.5 * zoom, yy), c.darkened(0.35), 1.0)
                    draw_line(Vector2(ctr.x + 1.5 * zoom, yy), Vector2(r.end.x, yy), c.darkened(0.35), 1.0)
                    yy += 8.0 * zoom
        "circle":
            var rad := minf(r.size.x, r.size.y) / 2.0
            draw_circle(ctr, rad, conc)
            draw_circle(ctr, rad * 0.86, c)
            draw_arc(ctr, rad * 0.5, 0.0, TAU, 24, c.lightened(0.3), 1.0)
            for i in 4:
                var an := t * 0.7 + i * TAU / 4.0
                draw_circle(ctr + Vector2(cos(an), sin(an)) * rad * 0.6, maxf(1.5, rad * 0.06), Color(0.95, 0.55, 0.3, a))
        "pond", "algae", "raceway":
            draw_rect(r, conc)
            var iw := Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6))
            draw_rect(iw, c)
            if shape == "raceway":
                var k := 1
                while k < 4:
                    var xx := iw.position.x + iw.size.x * k / 4.0
                    draw_line(Vector2(xx, iw.position.y), Vector2(xx, iw.end.y), conc, 2.0)
                    k += 1
            for i in 5:
                var fx := iw.position.x + fmod(absf(sin(i * 12.9 + t * 0.15)) * iw.size.x, iw.size.x)
                var fy := iw.position.y + (0.2 + 0.6 * absf(sin(i * 78.2))) * iw.size.y
                var col2 := Color(0.5, 0.8, 0.3, a) if shape == "algae" else Color(0.9, 0.6, 0.4, a)
                draw_circle(Vector2(fx, fy), maxf(1.5, zoom * 0.5), col2)
        "solar":
            draw_rect(r, c.darkened(0.3))
            draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), c)
            var cols := 8
            for i in range(1, cols):
                var xx := r.position.x + r.size.x * i / cols
                draw_line(Vector2(xx, r.position.y), Vector2(xx, r.end.y), Color(0.7, 0.8, 1.0, 0.5 * a), 1.0)
            for j in range(1, 3):
                var yy := r.position.y + r.size.y * j / 3.0
                draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(0.7, 0.8, 1.0, 0.5 * a), 1.0)
        "wind":
            var rad2 := minf(r.size.x, r.size.y) / 2.0
            draw_circle(ctr, rad2 * 0.4, Color(0.4, 0.42, 0.45, a))
            for i in 3:
                var an := t * 0.8 + i * TAU / 3.0
                draw_line(ctr, ctr + Vector2(cos(an), sin(an)) * rad2 * 1.8, Color(0.95, 0.95, 0.97, a), maxf(2.0, zoom * 0.5))
        "silo":
            var rad3 := minf(r.size.x, r.size.y) / 2.0
            draw_circle(ctr, rad3, c.darkened(0.3))
            draw_circle(ctr, rad3 * 0.85, c)
            draw_arc(ctr, rad3 * 0.55, 0.0, TAU, 24, c.lightened(0.3), 1.5)
        "beds":
            draw_rect(r, c.darkened(0.35))
            var n := 4
            for i in range(n):
                var yy2 := r.position.y + r.size.y * (i + 0.5) / n
                draw_line(Vector2(r.position.x + 3, yy2), Vector2(r.end.x - 3, yy2), c, maxf(2.0, r.size.y / n * 0.55))
        "plant":
            draw_rect(r, c.darkened(0.2))
            for i in 4:
                draw_circle(Vector2(r.position.x + r.size.x * (i + 0.5) / 4.0, ctr.y), minf(r.size.y, r.size.x / 4.0) * 0.32, Color(0.3, 0.55, 0.85, a))
        "hub":
            draw_rect(r, c.darkened(0.2))
            for i in 2:
                var fc := Vector2(r.position.x + r.size.x * (i + 0.5) / 2.0, ctr.y)
                draw_circle(fc, minf(r.size.y, r.size.x / 2.0) * 0.32, Color(0.2, 0.22, 0.25, a))
                draw_arc(fc, minf(r.size.y, r.size.x / 2.0) * 0.22, t * 6.0, t * 6.0 + 4.0, 12, Color(0.8, 0.85, 0.9, a), 1.5)
        _:
            draw_rect(r, c.darkened(0.3))
            draw_rect(Rect2(r.position + Vector2(1.5, 1.5), r.size - Vector2(3, 3)), c)

func _sal_text(n: Dictionary) -> String:
    var t := "Salinidad: fuente %.1f PSU · objetivo %.0f–%.0f PSU · volumen %.0f m³" % [n.src, n.lo, n.hi, n.volume]
    if n.type == "salt":
        t += "\nSal: llenado %.0f kg + %.0f kg/día (≈ %.0f $/día a %.2f $/kg)" % [n.fill_kg, n.daily_kg, n.daily_kg * Game.salt_price, Game.salt_price]
    elif n.type == "fresh":
        t += "\nAgua dulce: llenado %.0f m³ + %.1f m³/día (desalinizadora o camión cisterna)" % [n.fill_m3, n.daily_m3]
    else:
        t += "\nDentro del rango: no necesita tratamiento"
    return t

# ---------------------------------------------------------------- genética
func _build_gen() -> void:
    _gen_root = CenterContainer.new()
    _gen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _gen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _gen_root.visible = false
    add_child(_gen_root)
    var pc := PanelContainer.new()
    pc.add_theme_stylebox_override("panel", _dark(12, 0.97))
    pc.custom_minimum_size = Vector2(700, 0)
    _gen_root.add_child(pc)
    _panels.append(pc)
    var mg := _margin(pc, 12)
    _gen_box = VBoxContainer.new()
    mg.add_child(_gen_box)

func _toggle_gen() -> void:
    _gen_root.visible = not _gen_root.visible
    if _gen_root.visible:
        _gen_refresh()

func _gen_refresh() -> void:
    for ch in _gen_box.get_children():
        ch.queue_free()
    _gen_box.add_child(_lbl("Genética · selección (barata, lenta) vs ingeniería (cara, inmediata)", 16))
    _gen_box.add_child(_wrap("Selección: %d días por nivel, sin laboratorio. Ingeniería: instantánea, requiere el Laboratorio de genética. Los efectos se aplican a todos los cultivos." % Genetics.SEL_DAYS))
    for t in Genetics.TRAITS:
        var row := HBoxContainer.new()
        var nm := _lbl(t.name, 13)
        nm.custom_minimum_size = Vector2(190, 0)
        nm.tooltip_text = t.desc
        row.add_child(nm)
        var lv := _lbl("Sel %d/%d · Ing %d/%d" % [Genetics.lvl("sel", t.id), Genetics.SEL_MAX, Genetics.lvl("eng", t.id), Genetics.ENG_MAX], 13)
        lv.custom_minimum_size = Vector2(140, 0)
        row.add_child(lv)
        var e := Genetics.effect(t.id)
        var ef := _lbl("+%.1f °C" % e if t.id == "temp" else "+%d %%" % int(round(e * 100.0)), 13)
        ef.custom_minimum_size = Vector2(70, 0)
        row.add_child(ef)
        var b1 := Button.new()
        if Game.gen.prog.has(t.id):
            b1.text = "En curso (%d d)" % int(Game.gen.prog[t.id])
            b1.disabled = true
        else:
            b1.text = "Seleccionar $%d" % Genetics.sel_cost(t.id)
        b1.pressed.connect(_gen_sel.bind(t.id))
        row.add_child(b1)
        var b2 := Button.new()
        b2.text = "Editar ADN $%d" % Genetics.eng_cost(t.id)
        b2.disabled = not Genetics.has_lab()
        b2.pressed.connect(_gen_eng.bind(t.id))
        row.add_child(b2)
        _gen_box.add_child(row)
    var cb := Button.new()
    cb.text = "Cerrar (G)"
    cb.pressed.connect(_toggle_gen)
    _gen_box.add_child(cb)

func _gen_sel(id: String) -> void:
    Game.say(Genetics.start_selection(id))
    _gen_refresh()

func _gen_eng(id: String) -> void:
    Game.say(Genetics.edit_dna(id))
    _gen_refresh()

# ---------------------------------------------------------------- SCADA
func _build_scada() -> void:
    _scada_root = CenterContainer.new()
    _scada_root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _scada_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _scada_root.visible = false
    add_child(_scada_root)
    var pc := PanelContainer.new()
    pc.add_theme_stylebox_override("panel", _dark(12, 0.97))
    pc.custom_minimum_size = Vector2(640, 0)
    _scada_root.add_child(pc)
    _panels.append(pc)
    var mg := _margin(pc, 12)
    var vb := VBoxContainer.new()
    mg.add_child(vb)
    vb.add_child(_lbl("SCADA · sala de control", 16))
    _sc_status = _lbl("", 13)
    vb.add_child(_sc_status)
    _sc_temp = ParamBar.new()
    _sc_temp.label = "Servidor"
    _sc_temp.unit = "°C"
    _sc_temp.vmin = 20.0
    _sc_temp.vmax = 110.0
    _sc_temp.opt_a = 20.0
    _sc_temp.opt_b = 60.0
    vb.add_child(_sc_temp)
    var hb := HBoxContainer.new()
    vb.add_child(hb)
    var cb := Button.new()
    cb.text = "Enfriar (abrir ventilas)"
    cb.pressed.connect(func(): Game.cool_manual())
    hb.add_child(cb)
    _sc_auto_btn = Button.new()
    _sc_auto_btn.text = "Climatización automática ($12 k)"
    _sc_auto_btn.pressed.connect(func(): Game.say(Game.buy_auto_cool()))
    hb.add_child(_sc_auto_btn)
    vb.add_child(_lbl("Oxígeno por tanque (mg/L, última hora)", 13))
    for k in 3:
        var row := HBoxContainer.new()
        var nm := _lbl("Tanque %d" % (k + 1), 13)
        nm.custom_minimum_size = Vector2(90, 0)
        row.add_child(nm)
        var sp := SparkLine.new()
        sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        sp.custom_minimum_size = Vector2(300, 40)
        row.add_child(sp)
        var vl := _lbl("", 13)
        vl.custom_minimum_size = Vector2(120, 0)
        row.add_child(vl)
        vb.add_child(row)
        _sc_sparks.append(sp)
        _sc_labels.append(vl)
    _sc_waste = _lbl("", 13)
    vb.add_child(_sc_waste)
    _sc_alarms = _wrap("")
    vb.add_child(_sc_alarms)
    var close := Button.new()
    close.text = "Cerrar (K)"
    close.pressed.connect(_toggle_scada)
    vb.add_child(close)

func _toggle_scada() -> void:
    if Game.count_of("scada") == 0:
        Game.say("Construye la Oficina SCADA (categoría Control) y el Hub de servidores")
        return
    _scada_root.visible = not _scada_root.visible

func _scada_update() -> void:
    var has_hub := Game.count_of("hub") > 0
    var ok := Game.scada_online()
    if not has_hub:
        _sc_status.text = "Sin Hub de servidores: construye el Hub de enfriamiento y automatización."
    elif ok:
        _sc_status.text = "Datos en línea · servidor a %.0f °C" % Game.server_temp
    else:
        _sc_status.text = "ERR: NO_SIGNAL · servidor sobrecalentado, la automatización está caída. Enfría ya."
    _sc_temp.value = Game.server_temp
    _sc_temp.queue_redraw()
    _sc_waste.text = "Acopio de desechos: %.0f / %.0f kg · N %.2f kg" % [Flows.organic_stock(), Flows.p("acopio_cap_kg"), Flows.nitrogen_kg()] + ("\n" + Ops.scada_text() if Ops.scada_text() != "" else "") if ok else ""
    _sc_auto_btn.disabled = Game.auto_cool or not has_hub
    var alarms := ""
    for k in _sc_sparks.size():
        if k >= Game.tanks.size():
            continue
        var t: WaterTank = Game.tanks[k]
        if ok:
            _sc_sparks[k].values = Game.tank_hist[k]
            _sc_labels[k].text = "%.1f mg/L · %s" % [t.o2, "vacío" if t.fish == 0 else "%d g" % int(t.avg_w)]
            if t.fish > 0 and t.o2 < 5.0:
                alarms += "ALARMA %s: oxígeno bajo\n" % t.name_t
            if t.fish > 0 and t.nh3 > 0.3:
                alarms += "ALARMA %s: amoníaco alto\n" % t.name_t
            if t.fish > 0 and t.avg_w >= 350.0:
                alarms += "AVISO %s: lista para cosecha\n" % t.name_t
        else:
            _sc_sparks[k].values = []
            _sc_labels[k].text = "ERR: NO_SIGNAL"
        _sc_sparks[k].queue_redraw()
    if ok:
        alarms += Ops.alarms()
    _sc_alarms.text = alarms if alarms != "" else ("Sin alarmas activas" if ok else "Alarmas no disponibles")
