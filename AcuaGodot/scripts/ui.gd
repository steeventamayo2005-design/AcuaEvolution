extends CanvasLayer
# Interfaz: pastillas superiores, tutorial, Heimdall, aviso E, ventana de tanque y tienda.

const PARAMS := [
    ["o2", "Oxígeno", "mg/L", 0.0, 12.0, 5.0, 10.0],
    ["temp", "Temperatura", "°C", 14.0, 38.0, 0.0, 0.0],
    ["ph", "pH", "", 5.0, 10.0, 6.5, 8.5],
    ["nh3", "Amoníaco", "mg/L", 0.0, 2.0, 0.0, 0.1],
    ["stress", "Estrés", "%", 0.0, 100.0, 0.0, 30.0],
    ["noise", "Ruido", "dB", 0.0, 70.0, 0.0, 40.0],
    ["parasites", "Parásitos", "%", 0.0, 100.0, 0.0, 15.0],
    ["health", "Salud", "%", 0.0, 100.0, 70.0, 100.0],
    ["hunger", "Hambre", "%", 0.0, 100.0, 0.0, 40.0],
]

const STEPS := [
    ["Abre el PC de gestión", "Ve a la oficina y pulsa E en el monitor", "pc"],
    ["Compra balanceado", "En AquaShop compra al menos 10 kg de balanceado", "bought"],
    ["Siembra alevines", "Pulsa E en un tanque y siembra 300 alevines", "sowed"],
    ["Planifica el sitio", "Pulsa Tab, elige un edificio en la paleta y constrúyelo en el plano", "built"],
    ["Da de comer", "Abre el tanque y pulsa Alimentar", "fed"],
    ["Cambia el agua", "Gira la válvula roja del tanque (E) cuando suba el amoníaco", "wchg"],
    ["Cosecha y vende", "Cuando los peces pesen 350 g, cosecha y vende", "sold"],
]

var prompt := ""
var panel := 0  # 0 ninguno, 1 tanque, 2 tienda
var tank: WaterTank
var _date: Label
var _money: Label
var _level: Label
var _rep: Label
var _prompt_cc: CenterContainer
var _prompt_lbl: Label
var _toast_cc: CenterContainer
var _toast_lbl: Label
var _tank_root: CenterContainer
var _shop_root: CenterContainer
var _shop_box: VBoxContainer
var _tank_title: Label
var _tank_info: Label
var _species: OptionButton
var _bars := {}
var _ae: HSlider
var _ae_lbl: Label
var _tt: HSlider
var _tt_lbl: Label
var _tut: PanelContainer
var _tut_count: Label
var _tut_title: Label
var _tut_desc: Label
var _step := 0
var _tut_on := true
var _adv: Label
var _radio_box: PanelContainer
var _radio_lbl: Label
var _crosshair: ColorRect
var observation_mode := false

func tutorial_off() -> void:
    _tut_on = false

func panel_open() -> bool:
    return panel != 0

func close_panel() -> void:
    panel = 0
    _tank_root.visible = false
    _shop_root.visible = false

func set_observation_mode(active: bool) -> void:
    observation_mode = active
    _crosshair.visible = not active
    _tut.visible = not active and _tut_on
    if active:
        _prompt_cc.visible = false

func _dark(radius: int = 8, alpha: float = 0.92) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.05, 0.10, 0.15, alpha)
    sb.set_corner_radius_all(radius)
    sb.border_color = Color(0.16, 0.27, 0.35)
    sb.set_border_width_all(1)
    return sb

func _lbl(t: String, size: int = 14) -> Label:
    var l := Label.new()
    l.text = t
    l.add_theme_font_size_override("font_size", size)
    return l

func _btn(parent: Node, t: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = t
    b.pressed.connect(cb)
    parent.add_child(b)
    return b

func _pill(parent: Node) -> HBoxContainer:
    var pc := PanelContainer.new()
    pc.add_theme_stylebox_override("panel", _dark(16))
    parent.add_child(pc)
    var mg := MarginContainer.new()
    mg.add_theme_constant_override("margin_left", 14)
    mg.add_theme_constant_override("margin_right", 14)
    mg.add_theme_constant_override("margin_top", 7)
    mg.add_theme_constant_override("margin_bottom", 7)
    pc.add_child(mg)
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 10)
    mg.add_child(hb)
    return hb

func _make_panel(width: int) -> Array:
    var cc := CenterContainer.new()
    cc.set_anchors_preset(Control.PRESET_FULL_RECT)
    cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cc.visible = false
    add_child(cc)
    var pc := PanelContainer.new()
    pc.custom_minimum_size = Vector2(width, 0)
    pc.add_theme_stylebox_override("panel", _dark(12, 0.96))
    cc.add_child(pc)
    var mg := MarginContainer.new()
    for s in ["left", "right", "top", "bottom"]:
        mg.add_theme_constant_override("margin_" + s, 12)
    pc.add_child(mg)
    var sc := ScrollContainer.new()
    sc.custom_minimum_size = Vector2(width - 24, 600)
    sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    mg.add_child(sc)
    var vb := VBoxContainer.new()
    vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(vb)
    return [cc, vb]

func _ready() -> void:
    # Pastillas superiores
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 8)
    add_child(top)
    top.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 14)
    _date = _lbl("")
    _pill(top).add_child(_date)
    var sp := _pill(top)
    for s in [0, 1, 3, 10, 30, 100]:
        var b := Button.new()
        b.text = "Pausa" if s == 0 else "%d×" % s
        b.flat = true
        b.pressed.connect(func(): Game.time_scale = s)
        sp.add_child(b)
    _money = _lbl("")
    _pill(top).add_child(_money)
    _level = _lbl("")
    _pill(top).add_child(_level)
    var rp := _pill(top)
    var dot := _lbl("●")
    dot.add_theme_color_override("font_color", Color(0.95, 0.6, 0.1))
    rp.add_child(dot)
    _rep = _lbl("")
    rp.add_child(_rep)
    # Texto de ayuda y versión
    var hint := _lbl("F3 = vista isométrica de observación · Tab / M = tableta · 1–5 = velocidad · 0 = pausa", 12)
    hint.modulate = Color(1, 1, 1, 0.45)
    add_child(hint)
    hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
    hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    var ver := _lbl("Beta de prueba · v0.5.4", 12)
    ver.modulate = Color(1, 1, 1, 0.45)
    add_child(ver)
    ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
    ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
    # Tutorial
    _tut = PanelContainer.new()
    _tut.add_theme_stylebox_override("panel", _dark(12))
    _tut.custom_minimum_size = Vector2(390, 0)
    add_child(_tut)
    _tut.position = Vector2(14, 66)
    var tm := MarginContainer.new()
    for s in ["left", "right", "top", "bottom"]:
        tm.add_theme_constant_override("margin_" + s, 14)
    _tut.add_child(tm)
    var tv := VBoxContainer.new()
    tv.add_theme_constant_override("separation", 6)
    tm.add_child(tv)
    var th := HBoxContainer.new()
    tv.add_child(th)
    var tt := _lbl("Tutorial", 15)
    tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    th.add_child(tt)
    _tut_count = _lbl("")
    th.add_child(_tut_count)
    var sk := Button.new()
    sk.text = "Saltar tutorial"
    sk.flat = true
    sk.pressed.connect(func(): _tut_on = false)
    th.add_child(sk)
    _tut_title = _lbl("", 18)
    tv.add_child(_tut_title)
    var dr := HBoxContainer.new()
    tv.add_child(dr)
    var ex := _lbl("!", 15)
    ex.add_theme_color_override("font_color", Color(0.95, 0.72, 0.15))
    dr.add_child(ex)
    _tut_desc = _lbl("", 13)
    _tut_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _tut_desc.custom_minimum_size = Vector2(330, 0)
    _tut_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    dr.add_child(_tut_desc)
    var fl := _lbl("F = saltar este paso", 12)
    fl.modulate = Color(1, 1, 1, 0.5)
    tv.add_child(fl)
    # Heimdall (asistente)
    var hm := PanelContainer.new()
    hm.add_theme_stylebox_override("panel", _dark(12))
    add_child(hm)
    hm.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
    hm.grow_vertical = Control.GROW_DIRECTION_BEGIN
    var hv := VBoxContainer.new()
    hm.add_child(hv)
    _adv = _lbl("", 13)
    _adv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _adv.custom_minimum_size = Vector2(300, 0)
    _adv.visible = false
    hv.add_child(_adv)
    var hb := Button.new()
    hb.text = "Heimdall ▸"
    hb.flat = true
    hb.alignment = HORIZONTAL_ALIGNMENT_LEFT
    hb.pressed.connect(func(): _adv.visible = not _adv.visible)
    hv.add_child(hb)
    # Radio (guía)
    _radio_box = PanelContainer.new()
    _radio_box.add_theme_stylebox_override("panel", _dark(12))
    _radio_box.custom_minimum_size = Vector2(380, 0)
    add_child(_radio_box)
    _radio_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 36)
    _radio_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _radio_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
    var rm := MarginContainer.new()
    for s in ["left", "right", "top", "bottom"]:
        rm.add_theme_constant_override("margin_" + s, 10)
    _radio_box.add_child(rm)
    _radio_lbl = _lbl("", 13)
    _radio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _radio_lbl.custom_minimum_size = Vector2(360, 0)
    rm.add_child(_radio_lbl)
    _radio_box.visible = false
    # Mira
    _crosshair = ColorRect.new()
    _crosshair.color = Color(1, 1, 1, 0.6)
    _crosshair.set_anchors_preset(Control.PRESET_CENTER)
    _crosshair.offset_left = -2
    _crosshair.offset_right = 2
    _crosshair.offset_top = -2
    _crosshair.offset_bottom = 2
    _crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_crosshair)
    # Aviso de interacción (centrado abajo)
    _prompt_cc = CenterContainer.new()
    _prompt_cc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _prompt_cc.offset_top = -150
    _prompt_cc.offset_bottom = -105
    _prompt_cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_prompt_cc)
    var ppc := PanelContainer.new()
    ppc.add_theme_stylebox_override("panel", _dark(14))
    ppc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _prompt_cc.add_child(ppc)
    var pm := MarginContainer.new()
    pm.add_theme_constant_override("margin_left", 18)
    pm.add_theme_constant_override("margin_right", 18)
    pm.add_theme_constant_override("margin_top", 8)
    pm.add_theme_constant_override("margin_bottom", 8)
    ppc.add_child(pm)
    _prompt_lbl = _lbl("", 15)
    pm.add_child(_prompt_lbl)
    # Aviso temporal (arriba centrado)
    _toast_cc = CenterContainer.new()
    _toast_cc.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _toast_cc.offset_top = 70
    _toast_cc.offset_bottom = 115
    _toast_cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_toast_cc)
    var tpc := PanelContainer.new()
    var tsb := _dark(14)
    tsb.border_color = Color(0.88, 0.63, 0.2)
    tpc.add_theme_stylebox_override("panel", tsb)
    tpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _toast_cc.add_child(tpc)
    var tmg := MarginContainer.new()
    tmg.add_theme_constant_override("margin_left", 16)
    tmg.add_theme_constant_override("margin_right", 16)
    tmg.add_theme_constant_override("margin_top", 6)
    tmg.add_theme_constant_override("margin_bottom", 6)
    tpc.add_child(tmg)
    _toast_lbl = _lbl("", 14)
    _toast_lbl.add_theme_color_override("font_color", Color(1, 0.84, 0.54))
    tmg.add_child(_toast_lbl)
    _build_tank_panel()
    var s := _make_panel(540)
    _shop_root = s[0]
    _shop_box = s[1]

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F and _tut_on:
        _step += 1

func _build_tank_panel() -> void:
    var r := _make_panel(520)
    _tank_root = r[0]
    var vb: VBoxContainer = r[1]
    _tank_title = _lbl("", 16)
    vb.add_child(_tank_title)
    _tank_info = _lbl("")
    vb.add_child(_tank_info)
    _species = OptionButton.new()
    for s in Catalog.SPECIES:
        _species.add_item("%s · óptimo %d °C" % [s.name, int(s.opt_temp)])
    _species.item_selected.connect(_on_species)
    vb.add_child(_species)
    for p in PARAMS:
        var b := ParamBar.new()
        b.label = p[1]
        b.unit = p[2]
        b.vmin = p[3]
        b.vmax = p[4]
        b.opt_a = p[5]
        b.opt_b = p[6]
        vb.add_child(b)
        _bars[p[0]] = b
    _ae_lbl = _lbl("")
    vb.add_child(_ae_lbl)
    _ae = HSlider.new()
    _ae.min_value = 0
    _ae.max_value = 100
    _ae.value_changed.connect(func(v): tank.aeration = v)
    vb.add_child(_ae)
    _tt_lbl = _lbl("")
    vb.add_child(_tt_lbl)
    _tt = HSlider.new()
    _tt.min_value = 18
    _tt.max_value = 34
    _tt.step = 0.5
    _tt.value_changed.connect(func(v): tank.target_temp = v)
    vb.add_child(_tt)
    var row1 := HBoxContainer.new()
    vb.add_child(row1)
    _btn(row1, "Sembrar 300", func(): Game.say(tank.sow(Catalog.SPECIES[_species.selected], 300)))
    _btn(row1, "600", func(): Game.say(tank.sow(Catalog.SPECIES[_species.selected], 600)))
    _btn(row1, "900", func(): Game.say(tank.sow(Catalog.SPECIES[_species.selected], 900)))
    _btn(row1, "Alimentar", func(): Game.say(tank.feed()))
    _btn(row1, "Cambio de agua ($2)", func(): Game.say(tank.water_change()))
    var row2 := HBoxContainer.new()
    vb.add_child(row2)
    _btn(row2, "Tratar parásitos ($10)", func(): Game.say(tank.treat()))
    _btn(row2, "Purgar lodo y muertos ($1)", func(): Game.say(tank.purge()))
    _btn(row2, "Cosechar y vender", func(): Game.say(tank.harvest()))
    _btn(row2, "Cerrar (E)", _close_btn)

func _close_btn() -> void:
    close_panel()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_species(i: int) -> void:
    if tank != null and tank.fish == 0:
        tank.sp = Catalog.SPECIES[i]

func open_tank(t: WaterTank) -> void:
    tank = t
    panel = 1
    _tank_root.visible = true
    _shop_root.visible = false
    _tank_title.text = t.name_t + " · cultivo de tilapia"
    var idx := 0
    for i in Catalog.SPECIES.size():
        if Catalog.SPECIES[i].id == t.sp.id:
            idx = i
    _species.select(idx)
    _ae.set_value_no_signal(t.aeration)
    _tt.set_value_no_signal(t.target_temp)

func open_shop() -> void:
    panel = 2
    _tank_root.visible = false
    _shop_root.visible = true
    Game.flag("pc")
    if is_instance_valid(Game.marker):
        Game.marker.visible = false
    _shop_refresh()

func _buy_feed(kg: float) -> void:
    Game.say(Game.buy_feed(kg))
    _shop_refresh()

func _buy_agent() -> void:
    Game.say(Game.buy_sales_agent())
    _shop_refresh()

func _buy_resow() -> void:
    Game.say(Game.buy_resow())
    _shop_refresh()

func _wrap_lbl(t: String) -> Label:
    var l := _lbl(t, 12)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(500, 0)
    return l

func _buy_mod(m: Dictionary) -> void:
    Game.say(Game.buy_module(m))
    _shop_refresh()

func _craft_feed(item: String) -> void:
    Game.say(Game.craft_feed(item))
    _shop_refresh()

func _shop_refresh() -> void:
    for c in _shop_box.get_children():
        c.queue_free()
    _shop_box.add_child(_lbl("AquaShop · $%.2f · balanceado %.1f kg" % [Game.money, Game.feed_kg], 16))
    _shop_box.add_child(_lbl("Mercado $%.2f/kg · tu costo $%.2f/kg (descuento %d %% por módulos)" % [Game.market_price, Game.feed_cost(), int(Game.discount() * 100.0)]))
    var hb := HBoxContainer.new()
    _shop_box.add_child(hb)
    _btn(hb, "Balanceado 10 kg ($%.2f)" % (Game.feed_cost() * 10.0), _buy_feed.bind(10.0))
    _btn(hb, "Balanceado 50 kg ($%.2f)" % (Game.feed_cost() * 50.0), _buy_feed.bind(50.0))
    _shop_box.add_child(_lbl("Automatización comercial:", 14))
    var agr := HBoxContainer.new()
    _shop_box.add_child(agr)
    if Game.flags.has("auto_sell"):
        agr.add_child(_lbl("Agente de ventas activo (comisión 4 %)"))
    else:
        _btn(agr, "Agente de ventas ($150)", _buy_agent)
    if Game.flags.has("auto_sow"):
        agr.add_child(_lbl("· Resiembra automática activa"))
    else:
        _btn(agr, "Resiembra automática ($250)", _buy_resow)
    _shop_box.add_child(_lbl("Preparación manual de balanceado", 14))
    _shop_box.add_child(_wrap_lbl("Convierte ahora los coproductos no reservados por otros módulos. Los rendimientos son equivalencias experimentales del juego, no una fórmula nutricional real."))
    var craft_row := HBoxContainer.new()
    _shop_box.add_child(craft_row)
    for item in ["larvas_bsf", "microalgas"]:
        var d: Dictionary = Flows.items.get(item, {})
        var yield_per_kg := float(d.get("to_feed", 0.0))
        var available := maxf(0.0, Flows.amount(item) - Ops.keep(item))
        if yield_per_kg <= 0.0:
            continue
        var btn := _btn(craft_row, "%s %.1f kg → %.1f kg" % [d.get("name", item), available, available * yield_per_kg], _craft_feed.bind(item))
        btn.disabled = available < 0.01
    _shop_box.add_child(_wrap_lbl(Game.ledger_text()))
    _shop_box.add_child(_wrap_lbl(Flows.text()))
    _shop_box.add_child(_lbl("Contratos activos (se cumplen al cosechar un tanque que cumpla peso y cantidad):", 14))
    if Game.contracts.size() == 0:
        _shop_box.add_child(_lbl("Sin contratos por ahora."))
    for c in Game.contracts:
        _shop_box.add_child(_lbl("%s: %d kg de %s ≥ %d g · $%.2f/kg · vence día %d" % [c.client, int(c.kg), c.sp_name, int(c.min_w), float(c.price), int(c.due) + 1]))
    _shop_box.add_child(_lbl("Módulos auxiliares (cada nivel baja el costo del balanceado; mejorar cuesta más):"))
    for m in Catalog.MODULES:
        var l: int = Game.module_levels[m.id]
        var row := HBoxContainer.new()
        var nl := _lbl("%s · nivel %d/5" % [m.name, l])
        nl.custom_minimum_size = Vector2(320, 0)
        row.add_child(nl)
        var txt := "Máx."
        if l < 5:
            txt = ("Comprar $" if l == 0 else "Mejorar $") + str(Game.module_cost(m))
        _btn(row, txt, _buy_mod.bind(m))
        _shop_box.add_child(row)
    _shop_box.add_child(_lbl("Procesamiento, hatcheries, SCADA y automatización IA: construye y compra desde la tableta (Tab)."))
    _btn(_shop_box, "Cerrar (E)", _close_btn)

func _advice() -> String:
    for t in Game.tanks:
        if t.fish == 0:
            continue
        if t.o2 < 5.0:
            return "%s: oxígeno bajo (%.1f mg/L). Enciende el aireador o cambia agua." % [t.name_t, t.o2]
        if t.nh3 > 0.3:
            return "%s: amoníaco alto (%.2f mg/L). Gira la válvula de cambio de agua." % [t.name_t, t.nh3]
        if t.stress > 45.0:
            return "%s: peces estresados (%d %%). Revisa ruido, oxígeno y hambre." % [t.name_t, int(t.stress)]
        if t.hunger > 60.0:
            return "%s: los peces tienen hambre. Abre el tanque y alimenta." % t.name_t
        if t.parasites > 30.0:
            return "%s: parásitos en aumento (%d %%). Trata y mejora el agua." % [t.name_t, int(t.parasites)]
    return "Todo en orden. Vigila el balanceado y los precios del mercado."

func _process(_dt: float) -> void:
    var hh := int(Game.minutes) % 1440
    _date.text = "Día %d · %02d:%02d" % [Game.day + 1, int(hh / 60.0), hh % 60]
    _money.text = "%.2f $" % Game.money
    _level.text = "Nivel %d · %d/%d XP" % [Game.level, int(Game.xp), 100 * Game.level]
    _rep.text = "Reputación %d %%" % int(Game.reputation)
    _prompt_cc.visible = prompt != "" and panel == 0 and not observation_mode
    _prompt_lbl.text = prompt
    _toast_cc.visible = Game.toast != ""
    _toast_lbl.text = Game.toast
    if _tut_on:
        while _step < STEPS.size() and Game.flags.has(STEPS[_step][2]):
            _step += 1
        if _step >= STEPS.size():
            _tut_on = false
    _tut.visible = _tut_on and not observation_mode
    if _tut_on:
        _tut_count.text = "%d/%d   " % [_step + 1, STEPS.size()]
        _tut_title.text = STEPS[_step][0]
        _tut_desc.text = STEPS[_step][1]
    var rtxt := ""
    for r in Game.radio:
        if float(r.age) < 14.0:
            rtxt += "📻 " + str(r.t) + "\n"
    _radio_box.visible = rtxt != "" and not observation_mode
    _radio_lbl.text = rtxt.strip_edges()
    if _adv.visible:
        _adv.text = _advice()
    if panel == 1 and tank != null:
        for p in PARAMS:
            var b: ParamBar = _bars[p[0]]
            b.value = tank.get(p[0])
            if p[0] == "temp":
                b.opt_a = tank.sp.opt_temp - 3.0 - Genetics.effect("temp")
                b.opt_b = tank.sp.opt_temp + 2.0 + Genetics.effect("temp")
            b.queue_redraw()
        _species.disabled = tank.fish > 0
        _ae_lbl.text = "Aireación (más aire = más ruido): %d %%" % int(tank.aeration)
        _tt_lbl.text = "Temperatura objetivo (gasta energía): %.1f °C" % tank.target_temp
        if tank.fish > 0:
            _tank_info.text = "%s · %d peces · %d g c/u · biomasa %.1f kg · venta desde 350 g\nLodo %.0f kg · muertos %d (%.1f kg)" % [tank.sp.name, tank.fish, int(tank.avg_w), tank.biomass(), tank.sludge_kg, tank.dead_fish, tank.dead_kg]
        else:
            _tank_info.text = "Tanque vacío: elige especie y siembra."
