# AcuaEvolution · Godot · v0.5.5 (beta visual; pendiente de validar en Godot)

Extrae TODO el zip en una carpeta nueva e importa project.godot. No copies archivos sueltos sobre otra versión.

Para probar esta copia, importa `project.godot` desde la raíz de la carpeta extraída en Godot 4.3 y ejecuta el proyecto con F5.

## Modo de observación isométrica

La operación sigue siendo en primera persona. Pulsa **F3** para cambiar temporalmente a una cámara ortográfica inclinada que permite leer la distribución de la colonia completa; vuelve a pulsar **F3** (o **Esc**) para regresar a la persona y continuar las tareas. En esa vista, **WASD/flechas** desplazan el encuadre, la **rueda** acerca/aleja y **arrastrar con el botón izquierdo** orbita. La cúpula se oculta solo mientras observas desde arriba y vuelve al regresar a primera persona. Esta cámara sirve para observar, no para interactuar ni reemplazar la tableta de construcción **Tab/M**.

## Novedades v0.5.5 · lectura visual de la colonia

- Campus procedural con rutas de servicio radiales, anillos de circulación y balizas de orientación alrededor de la plaza central; la infraestructura acompaña la colocación libre de módulos sin imponer una cuadrícula de construcción.
- Base de la cúpula reforzada con anillos técnicos metálicos y una línea de guía turquesa, manteniendo el domo transparente y el modo de observación existente.
- HUD con paneles compactos azul petróleo, acentos verde agua y una indicación clara de la velocidad de simulación activa.
- No se añadieron modelos externos: la mejora usa geometría y materiales del propio proyecto. La cámara isométrica sigue siendo solo de observación; se vuelve a primera persona para operar y construir.

## Recorrido corto para probar la beta

1. Pulsa **Nueva partida**. Entra a la oficina de la nave, mira el monitor y pulsa **E** para abrir AquaShop.
2. Compra balanceado, vuelve a uno de los tanques y pulsa **E**. Siembra 300 alevines, alimenta, ajusta aireación/temperatura y vigila oxígeno, amoníaco, salud y hambre.
3. Usa **Tab** para abrir el plano. Elige un módulo en Construcción, haz clic en un sitio libre del domo y confirma la ubicación. Usa **R** para rotarlo; el plano rechaza solapamientos, zonas fuera del domo y construcciones sin fondos. Cierra la tableta para ver el edificio en 3D.
4. Prueba los módulos circulares con residuos: crían productos con insumos y horas de juego; las existencias aparecen en AquaShop. Allí puedes convertir ahora las larvas BSF o microalgas no reservadas en balanceado, o dejar que el sistema aproveche el excedente al cierre del día.
5. Cuida el agua hasta que el lote alcance talla comercial y cosecha desde el panel del tanque. Las ventas, los subproductos y los gastos aparecen en AquaShop; **K** en la tableta abre SCADA.

La conversión de coproductos a balanceado es una abstracción de jugabilidad basada en factores experimentales del juego. No representa una dieta formulada ni sustituye una validación nutricional. Las cifras biológicas y económicas de esta versión continúan siendo de prueba.

## Cómo se juega ahora
Un solo mundo continuo en primera persona: sales frente a la nave de tilapia, bajo un domo de cristal. Caminas a cualquier edificio sin pantallas de carga.
- Tab o M: tableta de planificación (el plano 2D como holograma). También con E en la mesa de la plaza central. Construye, demuele, automatiza y viaja ("Ir allí") sin salir del juego. Al cerrarla, los edificios nuevos aparecen en 3D.
- F3: vista isométrica de observación; no cambia el modo de interacción en primera persona.
- WASD mover · Shift correr · E interactuar · Esc soltar el ratón.
- Ciclo de día y noche con el reloj del juego.

## Novedades v0.5
- Pantalla de inicio con tu imagen (botones transparentes encima de los dibujados).
- Campus 3D: domo geodésico, suelo teñido por las 4 zonas, plaza con mesa holográfica y todos los edificios del plano en 3D (estanques con animales, paneles solares, aerogeneradores, silos, galpones con interior, hatcheries recorribles).
- Animales con modelo y animación: peces con cola, camarón, medusas que laten, cangrejo, macroalgas, almeja.
- Economía: plantas de fileteado (x2,5) y de harina/colágeno (x4) con capacidad diaria; saturación de mercado (el precio baja si vendes demasiado de una especie); contratos con plazo; bono verde por energía renovable y módulos de alimento.
- Guía por radio: avisa cuando un tanque está listo para cosechar o algo se desajusta.
- SCADA (tecla K en la tableta): servidor que se calienta (sobre 75 °C: ERR: NO_SIGNAL y la IA se cae), ventilas manuales o climatización automática, alarmas y tendencias de oxígeno.
- Automatización IA Heimdall por edificio (70 % a 90 % de su valor). En la nave controla aireación, alimentación, cambio de agua y tratamiento; en los demás sube el ingreso x1,2.
- Hatcheries 2 a 5 con diseño borrador recorrible (data/hatchery_*.json).
- Modelos propios: copia .glb a assets/models/ con los nombres barrel, gas_cylinder o pallet.

## Cambios de v0.5.1 (economía y ritmo)
- Velocidades hasta x100 (botones y teclas 1 a 5; 0 = pausa).
- Agente de ventas ($150) en el PC: cosecha y vende solo los lotes de 350 g o más (comisión 4 %). Resiembra automática ($250) repite la siembra.
- Siembra de 300, 600 o 900 peces por tanque. El oxígeno y el amoníaco ahora dependen de la densidad (kg por m³), no del peso total, así que se puede estar más denso.
- La nave consume 3 kW (antes 12) y ya no tiene ingreso pasivo: tu ingreso es lo que cosechas. Con la simulación de prueba, un tanque de 600 peces deja unos 480 $ netos por ciclo de unos 12 días de juego.
- Resumen de ingresos y gastos por categoría en el PC (AquaShop), para ver en qué se va el dinero.

## Cambios de v0.5.2 (desechos de los peces: paso 1 de la economía circular)
Todo lo que sale de los peces ahora se registra en un inventario (`scripts/flows.gd`, autoload `Flows`; datos en `data/flows_items.json`).
- Lodo del RAS: cada vez que alimentas se genera lodo (heces + alimento sin comer si el pez no tenía hambre). Se acumula en el tanque, sube el amoníaco y se retira con "Purgar lodo y muertos ($1)".
- Peces muertos: la mortalidad ya no desaparece; quedan en el tanque (amoníaco y parásitos) hasta que los retiras con Purgar.
- Agua residual: cada cambio de agua suma efluente (m³) al inventario, para la futura acuaponía.
- Fileteado: el 60 % de lo procesado son residuos (cabezas y espinazo, vísceras, piel y escamas). Si pasó también por la planta de harina, se consume allí; si no, queda en el acopio.
- Acopio de desechos: 400 kg. Si se llena, el excedente se lleva afuera a $0,06/kg ("disposicion de residuos"). Es el costo que luego evitarán compost, lombrices, BSF y biodigestor.
- La IA Heimdall de la nave también purga. Resumen de desechos en el PC (AquaShop) y en la SCADA. La guía avisa de lodo alto y peces muertos.
- `Flows.tags()` ya devuelve los valores con nombre tipo `acua/flujos/lodo_ras/stock`, listos para MQTT.
- Valores de prueba: ver `_nota` en el JSON. Falta calibrarlos con fuentes y probar en Godot.

## Cambios de v0.5.3 (módulos activos y automáticos)
Los módulos auxiliares dejan de ser escenarios vacíos: trabajan solos cada hora de juego (`scripts/ops.gd`, autoload `Ops`; datos en `data/ops_modules.json`).
- Cadena de materiales: el acopio de desechos alimenta compostera, lombricultura, BSF, biodigestor, acuaponía, hidroponía, aeroponía, hongos, microalgas, daphnia y zooplancton. Cada uno tiene su receta (entradas por día y salidas).
- Dinero: lo que sobra se vende solo cada día (x0,85 del precio). Las larvas BSF y las microalgas se convierten en balanceado propio. Los módulos compran carbono o nutrientes si faltan.
- Compostera: calcula la relación C:N de la mezcla y la completa con carbono (aserrín/bagazo). Fuera de 20-35 baja el rendimiento.
- Colector automático de lodo (nuevo, $2500): retira el lodo de los tanques cada hora; con la "Red de retiro" saca también los muertos.
- Acuaponía y microalgas limpian el amoníaco de los tanques. El biodigestor ahora produce energía según tenga o no residuos.
- Rareza (nivel 1-5): Común, Raro, Épico, Legendario, Mítico. Sube el rendimiento y las ranuras de mejoras.
- Hop-ups (mejoras especiales, se instalan y se quitan con 50 % de reembolso): sensores IoT, bombas de alto caudal, recuperador de calor, contrato directo, mantenimiento predictivo, bio-enzimas, red de retiro, doble filtro.
- Modo (p. ej. lombriz: Humus/Cría; BSF: Pienso/Frass) y prioridad de insumos (1-5) para decidir quién se queda con los residuos.
- Desgaste y mantenimiento: sube trabajando, baja el rendimiento y a 100 se avería. Heimdall (módulo automatizado) y el hop-up predictivo lo mantienen solos con el SCADA en línea.
- Sobrecarga: la carga sube con lo que procesa; al llegar a 100 se activa x2 durante 24 h (más desgaste).
- Baliza 3D sobre cada módulo: verde y girando si produce, ámbar parcial, azul sin insumo, rojo averiado. El SCADA lista estado y desgaste de todos.
- `Ops.tags()` deja listos los tags `acua/mod/<id>/estado|desgaste|rareza` para MQTT.
- Todos los valores son de prueba. Falta calibrar y probar en Godot.

## Pendiente
Herramientas en mano (oxímetro, red), enciclopedia, sonido, personalización, mejores texturas y datos reales del Paquete 1. Los valores económicos siguen siendo de prueba.

## Bibliotecas de modelos para una siguiente pasada visual

No se descargaron ni incorporaron modelos externos en esta versión; los edificios actuales siguen usando geometría procedural y las texturas que ya trae el proyecto. Para futuros props modulares (bombas, tuberías, herramientas, vegetación o equipamiento de granja), estas bibliotecas indican licencias permisivas en sus páginas oficiales:

- [Poly Haven Models](https://polyhaven.com/models) publica sus modelos bajo [CC0](https://polyhaven.com/license). La atribución no es obligatoria, pero es recomendable registrar autor y enlace del modelo concreto al incorporarlo.
- [Kenney Assets](https://kenney.nl/assets) declara que sus paquetes de assets de juego son de dominio público [CC0](https://kenney.nl/support). No se debe usar el logotipo de Kenney como si fuera parte de un proyecto oficial.
- El [resumen de Creative Commons CC0](https://creativecommons.org/publicdomain/zero/1.0/) explica el uso y redistribución, incluso comercial. Aun con CC0, hay que comprobar por separado marcas, logos y derechos de imagen/modelo de terceros para cada asset específico.

La guía de licencias es una referencia para selección futura, no un registro de assets ya incluidos. El estilo visual de esta pasada se guía por la organización modular de hatchery/tanques de las referencias del usuario y no reutiliza arte de otros juegos.
