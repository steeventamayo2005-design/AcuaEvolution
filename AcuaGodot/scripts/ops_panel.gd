class_name OpsPanel
extends RefCounted
# Panel de un módulo activo dentro del plano: estado, rareza, modo, prioridad, hop-ups y sobrecarga.
# Devuelve el Label de estado para que el plano lo refresque sin reconstruir los botones.

static func _lbl(t: String, size: int = 13) -> Label:
    var l := Label.new()
    l.text = t
    l.add_theme_font_size_override("font_size", size)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(360, 0)
    return l

static func _btn(row: Node, t: String, cb: Callable, disabled: bool = false) -> Button:
    var b := Button.new()
    b.text = t
    b.disabled = disabled
    b.pressed.connect(cb)
    row.add_child(b)
    return b

static func build(box: VBoxContainer, b: Dictionary, on_change: Callable) -> Label:
    Ops.ensure(b)
    var rc: Dictionary = Ops.recipes[b.id]
    var lvl := Ops.level(b)
    var head := _lbl("Rareza: %s (nivel %d/5) · mejoras %d/%d" % [Ops.tier(b).n, lvl, (b.hop as Array).size(), Ops.slots(b)], 14)
    head.add_theme_color_override("font_color", Ops.tier_color(b))
    box.add_child(head)
    box.add_child(_lbl(Ops.io_text(b)))
    var status := _lbl(Ops.status_text(b))
    status.add_theme_color_override("font_color", Ops.state_color(b.st.state))
    box.add_child(status)
    var r1 := HBoxContainer.new()
    box.add_child(r1)
    _btn(r1, "Apagar" if b.on else "Encender", func():
        Ops.toggle(b)
        on_change.call())
    var do_maint := func():
        Game.say(Ops.maintain(b))
        on_change.call()
    _btn(r1, "Mantener ($%.0f)" % Ops.maintain_cost(b), do_maint, float(b.st.wear) < 1.0)
    var modes: Array = rc.get("modes", [])
    if modes.size() > 0:
        _btn(r1, "Modo: %s" % modes[clampi(int(b.mode), 0, modes.size() - 1)].n, func():
            Ops.cycle_mode(b)
            on_change.call())
    if not rc.get("collector", false):
        var r2 := HBoxContainer.new()
        box.add_child(r2)
        r2.add_child(_lbl("Prioridad de insumos: %d (1 = primero)" % int(b.prio)))
        _btn(r2, "▲", func():
            Ops.shift_prio(b, -1)
            on_change.call())
        _btn(r2, "▼", func():
            Ops.shift_prio(b, 1)
            on_change.call())
    var r3 := HBoxContainer.new()
    box.add_child(r3)
    var do_ult := func():
        Game.say(Ops.fire_ult(b))
        on_change.call()
    _btn(r3, "Sobrecarga x2 (24 h)", do_ult, not Ops.ult_ready(b))
    if not Game.def(b.id).has("mod"):
        var do_up := func():
            Game.say(Ops.upgrade(b))
            on_change.call()
        _btn(r3, "Mejorar a %s ($%d)" % [Ops.tiers[mini(lvl + 1, 5)].n, Ops.upgrade_cost(b)], do_up, lvl >= 5)
    # hop-ups instalados
    var inst: Array = b.hop
    if inst.size() > 0:
        var r4 := HBoxContainer.new()
        box.add_child(r4)
        for h in inst:
            _btn(r4, "Quitar %s" % Ops.hopups[h].name, func():
                Game.say(Ops.remove_hop(b, h))
                on_change.call())
    # instalar un hop-up
    var avail: Array = Ops.hop_available(b)
    if avail.size() > 0 and inst.size() < Ops.slots(b):
        var r5 := HBoxContainer.new()
        box.add_child(r5)
        var ob := OptionButton.new()
        for h in avail:
            ob.add_item("%s ($%d)" % [Ops.hopups[h].name, int(Ops.hopups[h].cost)])
        ob.tooltip_text = "Mejoras especiales: cada una ocupa una ranura"
        r5.add_child(ob)
        _btn(r5, "Instalar", func():
            Game.say(Ops.install_hop(b, str(avail[ob.selected])))
            on_change.call())
        box.add_child(_lbl(str(Ops.hopups[avail[0]].desc), 12))
    # últimos eventos
    if Ops.events.size() > 0:
        var t := "Actividad reciente:"
        var n := 0
        for e in Ops.events:
            if str(e.t).begins_with(str(Game.def(b.id).name)):
                t += "\n· día %d %s" % [int(e.d), str(e.t).substr(str(Game.def(b.id).name).length() + 2)]
                n += 1
                if n >= 3:
                    break
        if n > 0:
            box.add_child(_lbl(t, 12))
    return status
