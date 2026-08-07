# Análisis del video de referencia — QuickShell "soramane"

**Fecha:** 2026-08-02
**Fuente:** `soramane.mp4` (showcase oficial de QuickShell), 1920×1080, ~49.4s, sin audio relevante para este análisis.
**Método:** contact sheet (`fps=1/2, scale=480:-1, tile=4x7`) para overview + 9 ráfagas de 4 frames a resolución completa (`fps=3`) alrededor de los momentos con transición/hover/expand visible. Sin `ydotool`/entrada sintética disponible — todas las lecturas de "velocidad" y "easing" están inferidas de cuánto cambia la UI entre frames espaciados ~0.33s, **no medidas con un profiler ni con acceso al proyecto fuente**. Etiquetado explícito de estimados en §2.
**Propósito:** Fase 1 de la corrección de calidad de interacción/movimiento pedida — este documento es solo lectura/análisis, cero QML tocado. Pendiente de tu aprobación antes de Fase 2.

---

## 0. Resumen ejecutivo

El video muestra el shell de referencia de QuickShell ("caelestia-dots" style): un dock vertical delgado en el borde izquierdo (siempre visible, no autohide observado) + un panel flotante superior con pestañas (Dashboard/Media/Performance/Workspaces) que aparece anclado arriba-centro, + un launcher tipo spotlight anclado abajo-centro que también actúa como command palette (prefijo `>`) y de ahí se ramifica a un selector de wallpapers. El wallpaper y el acento de todo el chrome cambian juntos por workspace (paper claro con acento rojo-vino vs dark dramático con acento magenta/púrpura), igual que ya hace `WorkspaceSync.qml` en este proyecto — valida el enfoque, no lo contradice.

**Hallazgo más importante para tus objetivos:** casi nada de la estructura de layout es trasplantable 1:1 — el video no tiene una barra horizontal persistente en absoluto, todo su chrome son paneles flotantes convocados desde el dock o el launcher. Lo que sí es trasplantable es la *sensación* de movimiento: paneles opacos con sombra suave (no glassmorphism pesado, ver §2), crossfades en vez de saltos duros, listas con highlight que desliza en vez de saltar, y un color de acento que re-tiñe TODO el chrome (no solo una línea decorativa) cuando cambia el wallpaper/workspace.

---

## 1. Observaciones por componente

### 1.1 Dock vertical (borde izquierdo)
- **Qué es:** franja delgada (~40-50px estimado) pegada al borde izquierdo, presente en el 100% de los frames del contact sheet — nunca desaparece, no parece tener comportamiento de auto-hide ni proximity-reveal.
- **Layout:** logo/launcher arriba, 2-3 puntitos debajo (probablemente indicador de workspace — ver §1.9), luego un bloque de iconos de sistema (monitor/desktop, notif, ThemeSwitcher según icono de luna), luego iconos de apps corriendo (Discord, Spotify) con **badge de color de fondo circular cuando la app está activa** (verde para Spotify, un tono para Discord), y en la parte inferior iconos de red/bluetooth/batería + reloj (hora arriba, día abajo) + botón de power al fondo.
- **Motion:** no se capturó ninguna transición de aparición/desaparición del dock mismo — está siempre ahí. Los iconos individuales no muestran hover-scale visible en los frames capturados (posible pero no confirmado).
- **Relevancia para ti:** estructuralmente NO aplica (tu bar es horizontal arriba), pero el patrón "badge de color = app corriendo" es directamente reusable para el estado `active` de tus cápsulas de Discord/Spotify en `AppLaunchers.qml`.

### 1.2 Panel de pestañas (Dashboard/Media/Performance/Workspaces)
- **Qué es:** tarjeta flotante anclada arriba, centrada horizontalmente (no pegada a ningún borde ni al dock), con una fila de 4 tabs con iconos arriba y texto debajo, subrayada por un indicador que en tu propio `TabBar.qml` ya replicaste (underline con `Behavior on x`).
- **Layout:** tabs arriba, separador de 1px, contenido abajo. El contenido de cada tab reemplaza tarjetas completas (no hay scroll compartido entre tabs — coincide con tu decisión de Flickables independientes por tab).
- **Motion:** no se capturó la transición de cambio de tab en sí (todos los frames muestran el contenido ya asentado), así que **no puedo confirmar si el contenido hace crossfade, slide, o corte duro al cambiar de tab** — inferencia únicamente por consistencia del indicador deslizante, no evidencia directa de frame-a-frame.
- **Nomenclatura de tabs:** Dashboard / Media / Performance / **Workspaces** — pero el contenido del tab "Workspaces" en este video resultó ser el selector de wallpapers (ver §1.6), no un indicador de workspaces de Hyprland. Esto es una fuente de la ambigüedad original — el video llama "Workspaces" a lo que tú llamarías "Wallpapers".

### 1.3 Tarjetas del Dashboard (clima / perfil / calendario)
- **Qué es:** 3 tarjetas en fila: clima (icono+temp+condición), perfil (avatar+distro+WM+uptime), calendario compacto (fecha grande + mini gráfico de barras). Debajo, una tarjeta de calendario completa (grid mensual).
- **Layout:** tarjetas de igual altura, radius grande, fondo pastel sólido (no vidrio — ver §2), sin borde visible, separadas por gaps generosos.
- **Motion:** la única animación capturada aquí es decorativa — un mascota-doodle (gato/mochi) al lado del reproductor cambia de pose (ojos cerrados → sonrojado) al togglear play/pause. Puramente cosmético, baja prioridad.

### 1.4 Reproductor de música (Now Playing)
- **Qué es:** disco giratorio con "rayos" radiales alrededor de la carátula (animación idle continua, no se puede confirmar velocidad de rotación desde frames estáticos), transport controls, seekbar, y un **selector de fuente tipo pill** (`Feishin` / `Spotify`) para alternar entre backends de medios.
- **Layout:** versión compacta embebida en el tab Dashboard (una tarjeta más, mismo tamaño que clima/perfil); versión completa en el tab Media (mismo contenido, más grande, ancho completo).
- **Motion — cambio de fuente:** al tocar el pill de la fuente inactiva, el álbum art y el texto (título/artista/label) hacen crossfade; en el frame intermedio capturado el texto aparece con **glitch/doble-exposición** breve antes de resolverse — sugiere fade-out+fade-in solapados más que un slide. Se siente **rápido/snappy** (resuelto en ≤1s completo, posiblemente ≤500ms — ESTIMADO, no medido).
- **Comportamiento no confirmado / ambiguo:** en una de las ráfagas capturadas (t≈8-10s) vi el mismo widget aparecer momentáneamente **centrado y superpuesto sobre una ventana de Spotify en pantalla completa**, luego "recogerse" de vuelta a su posición anclada arriba. No pude determinar el disparador (¿hover sobre el icono del dock? ¿un atajo?) — lo marco como observado pero no explicado, no lo copiaría sin más evidencia.

### 1.5 Tab Performance
- **Qué es:** 3 gauges circulares (GPU temp, CPU temp, Memoria+Storage) con arco de progreso proporcional al valor, número grande al centro, label debajo.
- **Layout:** 3 en fila, mismo tamaño, dentro de una sola tarjeta contenedora.
- **Motion:** no se capturó actualización en vivo de los valores (solo frames estáticos con los mismos números), no hay evidencia de animación aquí más allá de lo que ya asumirías (arco anima al cambiar valor).

### 1.6 Selector de wallpapers (vía launcher, no un tab dedicado en la práctica)
- **Qué es:** aunque el tab "Workspaces" muestra una grid de miniaturas, la vía real de acceso capturada en el video es **escribir `>wallpaper` en el launcher/spotlight**, que autocompleta a una sola entrada de acción ("Wallpaper — Change the current wallpaper") y luego, tras confirmar, expande hacia arriba en el mismo panel hacia una grid horizontal de miniaturas con nombre debajo de cada una.
- **Motion:** el thumbnail bajo el cursor/foco se ve **más grande que sus vecinos + sombra propia** (hover-scale + elevation). Al seleccionar una miniatura, se ve un frame de **doble-exposición** (dos wallpapers superpuestos con transparencia) — confirma que el cambio de wallpaper de fondo es un **crossfade**, no un corte. Duración no medible con precisión pero cae dentro de la ventana de 0.33-0.66s que until capturé entre frames — se siente **moderado, ni instantáneo ni lento** (ESTIMADO).
- **Hallazgo importante:** cuando el wallpaper nuevo tiene un tema claro, **el panel del launcher/picker mismo cambia de dark theme a light theme** en sincronía — confirma que en el shell de referencia, el color de acento/tema no es solo una decoración sino que re-skinnea todos los paneles flotantes activos. Exactamente el principio que ya aplicaste en Bar.qml con `Theme.activeAccent`, aquí extendido a superficies flotantes completas.

### 1.7 Launcher / command palette (spotlight)
- **Qué es:** panel anclado abajo-centro, growing hacia arriba conforme hay más resultados, search box fijo abajo con placeholder `Type ">" for commands`.
- **Layout:** lista de resultados con icono+título+subtítulo, fila destacada (foco de teclado) con fondo resaltado tipo pill/rounded-rect detrás de toda la fila.
- **Motion — filtrado en vivo:** al escribir letra por letra, la lista de resultados cambia; en un frame intermedio capturado se ven **dos sets de resultados superpuestos/fantasma** (texto de la lista vieja y la nueva ligeramente desalineados) — esto indica que el filtrado anima con **crossfade de posición** (los ítems no saltan instantáneamente a su nueva posición/contenido, hay una transición breve donde ambos estados son parcialmente visibles). La barra de highlight de selección también parece desplazarse suavemente hacia el nuevo top-match en vez de saltar — inferido, no confirmado con un frame que la muestre a mitad de camino.
- **Se siente:** rápido/snappy (todo el ciclo de filtrado ocurre dentro de la ventana de ~0.33s entre mis frames).

### 1.8 Notificaciones (toasts)
- **Qué es:** tarjetas ancladas arriba-derecha, **apiladas verticalmente cuando hay más de una** (confirmado con 2 tarjetas simultáneas en pantalla).
- **Layout por tarjeta:** icono+título+timestamp+chevron (colapsada, cuerpo truncado a una línea) vs expandida (cuerpo completo + 2 botones de acción, ej. "I got it!" / "Another action").
- **Motion:** el dismiss de una tarjeta individual ocurre entre dos de mis frames sin que yo capturara el frame intermedio de la animación de salida — no puedo describir su curva de easing, solo confirmar que desaparece dejando la tarjeta restante en su lugar (no hay evidencia de que las demás "resbalen" para rellenar el hueco vs. simplemente redibujarse ahí).
- **⚠️ CONFLICTO explícito con tu requerimiento:** el video apila múltiples tarjetas — vos pediste una sola tarjeta que se expande, no un stack. Ver §3.

### 1.9 Indicadores de workspace
- Lo único observado en el dock son 2-3 puntitos pequeños y tenues justo debajo del logo superior — consistente con la opción "dots restyled" de tu lista, **no** se observó ningún indicador de workspace basado en icono-por-app en ningún frame. El video no me da evidencia visual para la opción "per-app icons" — no puedo mostrarte una referencia real de esa variante desde este material.

### 1.10 Menús contextuales de bandeja del sistema (nativos, no construidos por el shell)
- Lo que originalmente marqué como "popup de duración de DND" resultó ser, al ver los frames a resolución completa, **tres menús contextuales nativos de apps de bandeja distintas** (SafeEyes con su submenú de snooze "For 30 minutes / 1 hour / 2 hours / 3 hours / Until restart / Back", y Discord con su menú nativo "Open Discord / Check for Updates / Acknowledgements / Quit Discord"). Es decir: **no es una feature del dashboard**, es el estilo que QuickShell le da a los menús de `StatusNotifierItem` de apps de terceros — pill redondeada, lista compacta, fila de foco resaltada, botón "Back" para submenús.
- Relevante solo como referencia de lenguaje visual de listas/menús compactos, no como feature a replicar.

---

## 2. Tokens estimados (⚠️ TODOS ESTIMADOS — leídos a ojo de capturas PNG, no medidos con devtools ni con acceso al proyecto fuente)

| Token | Estimado | Nota |
|---|---|---|
| Radius tarjetas grandes (dashboard/media/performance) | ~20-24px | Consistente entre tabs |
| Radius launcher/picker panel | ~16px | Ligeramente menor que las tarjetas de tab |
| Radius pills/botones (source-switcher, capsule) | full-pill (h/2) | |
| Radius thumbnails (wallpaper grid) | ~10-12px | |
| Opacidad de superficie | **Alta, ~90-95%** | Sorpresa: el chrome se ve mayormente **sólido/opaco tipo "paper card"**, no vidrio traslúcido pesado — la separación visual viene de sombra + contraste de color, no de transparencia. Esto es distinto de lo que "glassmorphism" sugiere de entrada. |
| Blur de fondo | Bajo o ausente detectable | No veo el wallpaper "sangrando" a través de ninguna tarjeta en ningún frame — si hay blur, es sutil, no dominante |
| Spacing interno tarjetas | ~20-24px de padding | |
| Spacing entre elementos hermanos (iconos dock, botones) | ~8-12px | |
| Duración crossfades (fuente de media, wallpaper, filtrado launcher) | ~200-500ms | Rango amplio a propósito — no pude aislar un valor único con frames a 0.33s de separación |
| Easing | No determinable con confianza | Sin frames suficientemente densos para leer la curva; todo "se siente" eased-out más que lineal, pero es una impresión, no una medición |

---

## 3. Conflictos explícitos contra tus restricciones (no resueltos por mí — para que decidas)

1. **Layout de la bar.** El video no tiene ninguna barra horizontal persistente — todo su chrome son paneles flotantes convocados desde un dock vertical o un launcher. No hay estructura 1:1 que trasplantar a `Bar.qml`; solo la *sensación* (superficies opacas con sombra, crossfades, acento que tiñe todo el chrome) es aplicable. Tu bar horizontal arriba se mantiene como está estructuralmente — confirmalo si asumís lo mismo.
2. **Sistema de tabs existente (Dashboard/Wallpapers/Media).** Se mantiene, se restylea. El video usa 4 tabs con nombres parecidos pero **su tab "Workspaces" en realidad contiene el picker de wallpapers** — no es un indicador de workspaces de Hyprland. No hay conflicto real con tu estructura (vos ya tenés Wallpapers como tab propio, correcto), solo aviso de que el nombre "Workspaces" del video no significa lo que sugiere a primera vista.
3. **Iconos de Discord/Spotify en la bar.** Sin conflicto — el video los muestra como iconos de bandeja con badge de color cuando están activos y menú contextual nativo al click derecho; tu implementación (click para focus-or-launch) es un patrón distinto pero compatible, sin nada que corregir por este análisis.
4. **Acento como token runtime de matugen.** Sin conflicto — el video hace básicamente lo mismo (el acento y el tema completo cambian con el wallpaper/workspace), validando tu arquitectura. Solo hay que evitar tomar los hex literales del video (rojo-vino `#~8B2E2E` estimado en el tema claro, magenta/púrpura en el oscuro) como valores fijos — ya lo tenés resuelto vía `Theme.activeAccent`, mantenerlo así.
5. **Power menu con confirmación.** El video no tiene ningún power menu visible en el material capturado (no lo encontré en los 25 frames del overview ni en las 9 ráfagas). No hay una referencia de comportamiento con la cual comparar tu requisito de hold/two-step — es un requisito tuyo que no tiene contraparte a favor ni en contra en este material. Lo que sí observé es que **todo el resto del video usa acciones instantáneas de un click** (borrar fuente de media, dismiss de notificación) — tu exigencia de confirmación en el power menu es una desviación deliberada de esa filosofía general del video, no un alineamiento con ella. Vale la pena tenerlo presente como decisión consciente, no como algo "que ya hace el video distinto".
6. **Power menu trigger como icono dedicado en la bar.** Mismo caso que el punto anterior — no hay power menu visible en el material, entonces no hay nada que confirme o contradiga "icono dedicado vs anidado en dropdown". Sin evidencia, sin conflicto, sin nada que ajustar.
7. **Notificaciones: tarjeta única expandible vs stacking.** ⚠️ **Conflicto real y directo.** El video apila múltiples tarjetas simultáneas arriba-derecha cuando hay más de una notificación. Vos pediste explícitamente una sola tarjeta que se expande, no un stack. Recomendación (no ejecutada, para tu decisión): tomar del video el patrón interno de cada tarjeta (colapsada=título+cuerpo truncado+chevron, expandida=cuerpo completo+botones de acción) pero aplicado a un modelo de "una tarjeta a la vez" — cuando llega una segunda notificación mientras la primera sigue visible, reemplazar/encolar en vez de apilar. Confirmame si esto es lo que querés antes de que lo implemente así en Fase 2.
8. **Indicadores de workspace: dots vs iconos por app.** El video solo me da evidencia de la variante "dots" (puntitos pequeños en el dock, sin iconos de apps por workspace). No tengo ninguna referencia real en este material para la variante "per-app icons" — no puedo mostrarte cómo se vería ese enfoque desde este video. Si querés explorar esa opción vas a necesitar decidir sin referencia visual del video, o yo diseño algo nuevo sin base en el material.

---

## 4. Cosas que no pude verificar / limitaciones honestas

- **No hay entrada sintética de mouse en este entorno** (mismo limitante de rondas anteriores) — todas las lecturas de "qué dispara qué" (hover vs click vs teclado) son inferencia visual sobre el estado resultante, no observación directa de la interacción disparándose.
- **No tengo el proyecto fuente del video** (es un video de un shell de otra persona, no un repo al que tenga acceso) — cero valores de píxel, timing o QML reales, todo lo de §2 es lectura a ojo sobre PNGs.
- **No pude aislar la transición de cambio de tab** (Dashboard↔Media↔Performance↔Workspaces) en sí misma — todos mis frames capturados de esa zona muestran el contenido ya asentado en un estado o el otro, nunca a mitad de camino.
- **El comportamiento "widget flotante centrado que se recoge"** en §1.4 quedó sin explicación de causa — lo reporto como observado, no como entendido.
- **No encontré ningún power menu en los 49.4 segundos de video** — no es que lo haya visto y no lo haya extraído, genuinamente no aparece en el overview ni en ninguna de las 9 ráfagas dirigidas. Si existe en el video en algún punto que no muestreé, no lo vi.
- Duraciones y curvas de easing en §2 son estimaciones de rango amplio, no números que deberías tratar como especificación — son punto de partida para que ajustes por ojo en Fase 2, no un contrato.

---

## 5. Qué sigue

Este documento fue el final de la Fase 1 basada en frames de video. **Actualización:** conseguiste acceso de solo-lectura al proyecto fuente real (`~/reference/caelestia-shell`, GPLv3, autor "soramane" vía ko-fi, repo `caelestia-dots/shell`), lo que reemplaza la inferencia visual por lectura de QML real. Ver §6 (correcciones explícitas a lo que estimé arriba) y §7 (plan de implementación final, por componente). Las secciones 0-4 de arriba se dejan **intactas sin editar** a propósito — son el registro de qué pude inferir solo del video, para que quede documentado qué tan lejos/cerca estuvo la inferencia visual de la realidad del código. No se tocó ningún archivo bajo `modules/quickshell/` — este documento sigue siendo el checkpoint de "solo análisis" hasta tu aprobación.

---

## 6. Correcciones tras leer el código fuente real (reemplaza inferencia visual de §0-4)

Metodología: `~/reference/caelestia-shell` clonado de antemano (no lo cloné yo), lectura directa de los `.qml` relevantes a las 4 piezas en alcance de esta ronda (power menu, notificaciones, dashboard con tabs, indicadores de workspace). Cito rutas relativas al repo de referencia en cada punto.

1. **§1.2 (tab switch motion) — CORREGIDO, no confirmado a medias como dije.** No es crossfade. Es un **carrusel horizontal**: `modules/dashboard/Content.qml` instancia las 4 tabs como `Loader`s dentro de una `RowLayout` puestos en fila dentro de un `Flickable`, y el cambio de tab anima `contentX` (`Behavior on contentX`) hacia la posición x del tab activo — un slide, no un fundido. Además soporta **swipe/drag manual** (arrastrar el contenido cambia de tab pasado cierto umbral) y **scroll de rueda sobre la tab bar misma** (`onWheel` en `modules/dashboard/Tabs.qml`) para cambiar de tab sin tocar el contenido. El indicador subrayado (`Tabs.qml` líneas 58-99) anima `x` e `implicitWidth` con `Behavior`, y su ancho sigue el ancho real del label activo (no un ancho uniforme dividido entre tabs, como asumí que podríamos estar haciendo).
2. **§1.4 (widget de media flotando centrado, sin explicar) — sigue sin resolver, y sigue sin importar para esta ronda.** No es una de las 4 piezas en alcance ahora; no gasté tiempo en buscar su causa en el código fuente. Lo dejo como estaba, sin second-guess.
3. **§1.9 / §3.8 (indicadores de workspace: "solo vi dots, no tengo referencia de iconos por app") — CORRECCIÓN IMPORTANTE, esto cambia la respuesta que te di.** El proyecto real **sí implementa la variante de iconos por app**, simplemente no estaba activa (o no until la mostré) en el momento del video. Ver `modules/bar/components/workspaces/Workspace.qml` líneas 58-112: cada workspace ocupado tiene un `Loader` (`active: root.hasWindows`, gateado por `Config.bar.workspaces.showWindows`) que renderiza una `Column` de `MaterialIcon` — un icono de categoría por ventana abierta en ese workspace (`Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")`), con animación de entrada/salida (`add`/`move` transitions, scale 0→1). Ya no es cierto que "no tengo con qué mostrarte esa opción" — sí tengo una implementación real, ver §7.4 para cómo la adaptaría a tu bar horizontal (la de ellos es vertical, ColumnLayout, porque su bar es un dock vertical).
4. **§3.5 / §3.6 (power menu: "no aparece en el video, sin evidencia ni a favor ni en contra") — el código SÍ existe, aunque el video no lo mostrara.** `modules/bar/components/Power.qml`: un icono material `power_settings_new` en rojo (`Colours.palette.m3error`), **dentro de la bar**, que hace toggle de `screenState.session`. Esto confirma exactamente tu requisito original de "trigger = icono dedicado en la bar, no anidado en un dropdown" — con la diferencia de que en su caso es literalmente parte del layout de la bar, mientras que tu `PowerMenu.qml` actual es una ventana flotante independiente anclada a la esquina inferior derecha (no forma parte de `Bar.qml`). El panel de sesión mismo (`modules/session/Wrapper.qml`) se desliza desde el borde derecho de la pantalla (`anchors.rightMargin` animado desde negativo a 0) — no es un dock de esquina con proximidad, es un panel que aparece/desaparece por click. Es una lista vertical de 4 botones (logout/shutdown/hibernate/reboot) con navegación por teclado estilo vim (Ctrl+j/k, Tab) y **ejecuta al instante en click o Enter — sin ningún paso de confirmación**. Esto confirma lo que ya había anotado: tu requisito de confirmación (hold/two-step) es una decisión tuya sin precedente en el proyecto de referencia, ni en el video ni en el código — hay que diseñarlo desde cero.
5. **§2 tokens ("opacidad alta ~90-95%, blur bajo o ausente") — parcialmente corregido.** Las tarjetas grandes (dashboard, notificaciones, launcher) sí usan colores sólidos de contenedor Material 3 (`Colours.tPalette.m3surfaceContainer` etc.), consistente con lo que estimé. Pero **sí hay blur real y deliberado en al menos un lugar que no aparece en ningún frame que capturé**: `modules/bar/components/workspaces/Workspaces.qml` línea 42-47 aplica `MultiEffect { blurEnabled: true, blur: root.blur, blurMax: 32 }` sobre el indicador de workspaces cuando estás en un workspace especial (`onSpecial`). No es blur generalizado tipo "glass" en todas las superficies — es puntual, ligado a un estado específico — pero corrijo mi frase de que estaba "ausente por completo": estaba ausente en lo que pude ver, no en el código.
6. **Notificaciones (§1.8/§3.7) — confirmado, y ahora con más detalle, no corregido en la conclusión.** `modules/notifications/Content.qml` confirma el stacking (ListView vertical, sin límite de tarjetas simultáneas) — el conflicto que marqué sigue siendo válido y sigue siendo tu decisión, ver §7.2. Lo nuevo que aporta el código (invisible en el video): cada tarjeta individual soporta **swipe horizontal para descartar** (arrastrar más allá de un umbral cierra la notificación, si no vuelve a su lugar), **drag vertical para expandir/colapsar** (además del click en el chevron), y un **timer de auto-dismiss que se pausa mientras el mouse está encima** (`onEntered: timer.stop()`, `onExited: timer.start()`) — `modules/notifications/Notification.qml` líneas 43-90.

---

## 7. Plan de implementación final (Fase 2) — decisión por componente

Regla general para todo lo que sigue: **nada se copia y pega tal cual**. Todo lo marcado "port" es una adaptación — mismo *mecanismo* de animación/interacción, reescrito contra `Theme.qml` (no `Colours`/`Tokens` de Caelestia), sin las dependencias de `Caelestia.Config`/`Caelestia.Services`/`Quickshell.Widgets` específicas de su plugin C++, y sin arrastrar código que no necesitamos (multi-monitor `perMonitorWorkspaces`, `SessionManager` de systemd, etc.). Todo bloque adaptado lleva un comentario de atribución arriba (URL del repo + GPLv3 + qué archivo se adaptó) antes de tocar `modules/quickshell/`.

### 7.1 Power menu → **REVISADO: PORT del trigger a la bar (Capsule.qml), se elimina la estructura de esquina-por-proximidad**

**Decisión actualizada (reemplaza la versión anterior de esta sección):** confirmaste que el hallazgo de §6.4 cambia la decisión. El trigger deja de ser una ventana flotante en la esquina inferior derecha y pasa a vivir **dentro de `Bar.qml`**, como una cápsula más reusando `Capsule.qml` (el mismo componente que ya usan los launchers de Discord/Spotify) — esto es lo que pediste desde el mensaje original, y ahora sabemos que es exactamente el patrón real de `modules/bar/components/Power.qml` (icono dedicado dentro de la bar, no un dropdown anidado).

**Qué se elimina por completo:** toda la lógica de `proximityZone`/`HoverHandler`/distancia-normalizada/`_amount` de `PowerMenu.qml` (líneas 46-70 y 148-204 del archivo actual) — ya no tiene ningún propósito una vez que el trigger vive en la bar en vez de flotar solo en una esquina. El archivo `PowerMenu.qml` deja de ser una `PanelWindow` de esquina; el panel de acciones se convierte en algo que se despliega desde/cerca de la cápsula en la bar (a definir en Fase 2 si es un flyout hacia abajo desde la bar, estilo dropdown de `Dashboard.qml`/`NotificationCenter.qml`, que es el patrón que ya usamos para todo lo que cuelga de la bar — más consistente con el resto del shell que inventar un tercer patrón de despliegue).

**Qué SÍ se mantiene de la versión anterior:** el estilo de las 5 `ActionButton` (lock/suspend/logout/reboot/shutdown) — círculos con icono, accent-coloreados por Theme, hover-highlight — se reusa dentro del nuevo flyout, solo cambia de dónde cuelga, no cómo se ven los botones en sí.

**Qué se agrega (nuevo, sin precedente en el video ni en el código real — diseño propio):**
- El **paso de confirmación** (hold-to-confirm o two-step) sigue siendo no-negociable y sigue sin tener ninguna referencia real de la que copiar — ni el video ni `modules/session/Content.qml` (ejecuta al instante en click/Enter) tienen este concepto. Propuesta concreta para Fase 2: hold de ~600ms sobre el botón de acción con un arco de progreso radial (`Shape`+`PathAngleArc`, el mismo primitivo que usa `Notification.qml` líneas 189-223 para su indicador de progreso — reutilizo la técnica del arco, no el código de notificaciones) que se llena mientras se mantiene presionado; soltar antes de completarse cancela.
- El botón de la bar en sí (icono `power_settings_new`-equivalente, "󰐥" en nuestra fuente Nerd Font) se agrega como una `Capsule` más en el `Row` derecho de `Bar.qml`, junto a `AppLaunchers`/`SystemCapsules` — reusa el componente existente, no crea uno nuevo.

**Dependencia de plugin nativo (§ítem E):** `modules/bar/components/Power.qml` no importa nada de `Caelestia`/`Caelestia.Services` más allá de `Caelestia.Config` (para `Config.session.*`, que no portamos — usamos nuestros propios `Process` a `hyprlock`/`systemctl` como ya hace `PowerMenu.qml` hoy). `StateLayer`/`MaterialIcon` (usados para el ripple del icono) son QML puro (`components/StateLayer.qml`, `components/MaterialIcon.qml`), sin C++ detrás. **Decisión: reimplementar en QML puro, cero dependencia nativa nueva.**

### 7.2 Notificaciones → **RESTYLE ours in place** (mantener modelo de una sola tarjeta), **PORT adaptado de gestos individuales** (crédito obligatorio)

**Decisión de fondo, ya tomada por vos, confirmada de nuevo acá:** no adoptamos el stacking de `modules/notifications/Content.qml` (ListView sin límite). Nuestro modelo sigue siendo: una sola tarjeta visible a la vez.

**Modelo de cola — resuelto:** si llega una notificación nueva mientras hay una visible, **reemplaza inmediatamente** con crossfade (la vieja se desvanece mientras la nueva aparece) — no hay cola, no hay conteo de pendientes, no se ignoran las entrantes. Nada de esto tiene precedente directo en `Content.qml` de Caelestia (que apila en vez de reemplazar), así que el crossfade de reemplazo es diseño propio sobre `NotificationPopups.qml`: en vez de un `Repeater` sobre `NotifServer.popups` completo, la ventana muestra solo la notificación más reciente (`NotifServer.popups[NotifServer.popups.length - 1]` o un getter equivalente), y el cambio de una `NotificationCard` a otra anima vía opacity (fade-out de la saliente simultáneo/solapado con fade-in de la entrante, no secuencial) usando `Theme.durMed`/`Theme.easeOutCubic` como el resto del shell.

**Qué SÍ porto (adaptado, con crédito):**
- **Expand/collapse con gesto de arrastre vertical**, además del click en el chevron que ya ibas a tener — de `Notification.qml` líneas 76-82 (`onPositionChanged`, umbral `Config.notifs.expandThreshold`). Adaptado: sin `Config.notifs.*`, un umbral fijo o en `Theme.qml`.
- **Swipe horizontal para descartar** — de `Notification.qml` líneas 58-75 (`drag.target: parent`, `drag.axis: Drag.XAxis`, umbral `clearThreshold` sobre `implicitWidth`). Reemplaza el click-en-X como método adicional, no en vez de.
- **Auto-dismiss que se pausa en hover** — de `Notification.qml` líneas 52-56 (`onEntered`/`onExited` sobre el timer). Nuestro `NotificationCard.qml` no tiene esto hoy; es una mejora de UX directa y barata.
- **Icono de app con anillo de progreso** (para notificaciones con `hints.value`, ej. volumen/descarga) — de `Notification.qml` líneas 189-223 (`Shape`+`ShapePath`+`PathAngleArc`). Opcional, solo si `NotifServer` ya expone ese hint; si no lo expone, no vale la pena agregar la extracción de datos solo para esto.

**Qué NO porto:** el `ListView` con `move`/`displaced`/`ListView.onRemove` transitions (es infraestructura de stacking que no vamos a usar), el `ExtraIndicator` de conteo scroll (solo tiene sentido con una lista larga).

**Dependencia de plugin nativo (§ítem E):** el único símbolo nativo real que toca `Notification.qml` es `ButtonRow` (`modules/notifications/Notification.qml` línea 450, importado de `Caelestia.Components`, respaldado por `plugin/src/Caelestia/Components/buttonrow.cpp`) — un layout en C++ que reparte los botones de acción a ancho completo cuando hay uno solo, o distribuidos cuando hay varios. Es una funcionalidad chica (una fila que hace fill-width entre 1-3 botones). **Decisión: reimplementar en QML puro** (un `Row` con anchos calculados a mano, o un simple `Grid`/`RowLayout` con `Layout.fillWidth: true` por hijo) — no vale la pena una dependencia de build nativo por esto. El resto de gestos portados (drag, swipe, timer hover-pause) son `MouseArea`/`Timer`/`Behavior` puro QtQuick, sin tocar el plugin.

### 7.3 Dashboard con tabs → **PORT del mecanismo de carrusel** (adaptado), mantener nuestro contenido/tokens

**Qué porto:** el mecanismo de `modules/dashboard/Content.qml` líneas 80-187 — un `Flickable` con los 3 tabs (Dashboard/Wallpapers/Media, los nuestros, no los 4 de ellos) puestos en fila dentro de una `Row`, `contentX` bindeado a la posición del tab activo con `Behavior on contentX`, reemplazando el `visible: UiState.dashboardTab === N` instantáneo que tenemos hoy en `Dashboard.qml`. Esto reemplaza el "salto duro" actual por el slide que confirmamos es el comportamiento real (§6.1), y de paso habilita gratis el swipe manual entre tabs si querés esa interacción (arrastrar el contenido, no solo tocar la tab).

**Qué NO porto:** el sistema de `Loader` con activación diferida por `visibleArea` de la Caelestia (optimización para tabs con contenido pesado tipo weather-tab con red) — nuestros 3 tabs son livianos, activarlos todos de una no es un problema de performance real que tengamos hoy; si algún día lo es, se revisita.

**Qué ajusto de paso (restyle, no port):** el indicador de `TabBar.qml` ya existe y ya desliza — lo ajusto para que su ancho siga el ancho real del label activo (como hace `Tabs.qml` de ellos) en vez del ancho uniforme dividido que tiene hoy, si el resultado visual se ve mejor al probarlo en vivo — decisión estética a confirmar mirándolo correr, no algo que pueda decidir solo leyendo código.

**Dependencia de plugin nativo (§ítem E):** `Content.qml`/`Tabs.qml` no llaman ningún símbolo de `Caelestia`/`Caelestia.Services` más allá de `Config`/`Tokens` (que no portamos) y `CUtils.clamp` (línea 60 de `Content.qml` — un clamp de un valor contra 0/máximo, trivial: `Math.max(0, Math.min(max, val))` en una línea de JS). El mecanismo de carrusel (`Flickable`+`RowLayout`+`contentX` animado) es QtQuick puro. **Decisión: reimplementar en QML puro, cero dependencia nativa nueva.**

### 7.4 Indicadores de workspace → **DIFERIDO explícitamente, no en esta ronda**

**Resuelto:** no se toca en esta ronda. Confirmaste que el alcance ya es suficiente (bar glass + dashboard + relocación del power menu) y que esto queda para después. Los dot-pills de `Workspaces.qml` se mantienen tal cual están hoy — sin cambios, ni de estilo ni de estructura.

**Para que no se pierda (diferido, no olvidado):** ya tengo la referencia concreta si en algún momento se retoma — queda documentada abajo tal como estaba, sin empezar a implementarla.

Esto seguía siendo tu decisión de fondo (dots vs iconos, la dejaste abierta a propósito) — lo que cambió con el acceso al código real es que ahora sí hay una implementación de referencia concreta para la opción de iconos, no una promesa vacía, para cuando decidas retomarlo.

**Recomendación:** no reemplazar el pill-dot que ya tenés en `Workspaces.qml` (ya cumple bien "restyled dots", con grow+glow animado, Theme-driven). En cambio, **agregar los iconos-por-app como una capa adicional condicional** (visible solo si el workspace está ocupado), adaptando `modules/bar/components/workspaces/Workspace.qml` líneas 58-112 — con dos cambios estructurales obligatorios porque su bar es vertical y la tuya es horizontal:
- Su `Column` de iconos (apilados verticalmente debajo del label, porque el dock crece hacia abajo) se vuelve una `Row` de iconos apilados **debajo del pill** en un layout horizontal (el equivalente rotado 90°) — no es un copy-paste directo, es la misma idea de "iconos de las ventanas de ese workspace, animados al entrar/salir" adaptada a la orientación de tu bar.
- El mapeo de icono usa `Icons.getAppCategoryIcon(class, fallback)`, una utilidad propia de Caelestia que no tenemos — lo reemplazo con `Quickshell.iconPath(class)` (que ya usamos en `AppLaunchers.qml`) más un fallback simple, no arrastro su sistema de categorías completo.
- Necesita datos de "qué ventanas hay en cada workspace" que hoy no tenemos expuestos — `Hypr.qml` ya tiene `runningClasses` (global, no por workspace) de la ronda anterior; habría que extenderlo a algo como `classesByWorkspace(wsId)` vía el mismo `hyprctl clients -j` que ya usamos, agrupando por `workspace.id` en vez de aplanar a una lista global.

**Qué NO porto:** el sistema de "pills" (`OccupiedBg.qml`) que agrupa visualmente workspaces ocupados consecutivos con una cápsula de fondo — es una decoración pensada para un dock vertical denso de muchos workspaces visibles a la vez; no tiene un equivalente obvio ni necesario en una bar horizontal con 9 slots fijos como la tuya.

**Dependencia de plugin nativo (§ítem E, para cuando se retome):** `Workspace.qml` usa `MaterialIcon` (QML puro, sin C++) para los iconos por ventana, con el mapeo de icono resuelto por `Icons.getAppCategoryIcon()` — una utilidad JS de `qs.utils`, no nativa. **Sin dependencia de plugin nativo si se implementa a futuro** — reemplazando `Icons.getAppCategoryIcon` por `Quickshell.iconPath(class)` (que ya usamos en `AppLaunchers.qml`), como ya anticipaba el borrador anterior de esta sección.

### 7.5 Cambio de wallpaper → **RESTYLE menor, pipeline se mantiene sin cambios estructurales**

**Qué estudié:** `modules/background/Wallpaper.qml` (el renderizador de fondo de Caelestia) y `services/Wallpapers.qml` (el servicio que decide qué imagen mostrar).

**Hallazgo principal — no hay nada que portar en la transición en sí:** el crossfade de Caelestia es dos `Image` apiladas, la nueva con `opacity: 0→1` animada (`Anim.SlowEffects`) y la vieja destruida al terminar. Nuestro `workspace-wallpaper` (`hosts/laptop/scripts.nix` líneas 77-113) ya usa `awww img --transition-type wipe --transition-angle 30 --transition-duration 0.65 --transition-fps 60` — una transición angular animada a nivel de compositor/daemon, más elaborada que el fundido plano de Caelestia, no menos. **No hay mejora que portar acá**, nuestra pieza ya es igual o mejor en este punto específico.

**Hallazgo secundario — el "preview en vivo" del video (§1.6/doble-exposición) sí tiene una explicación ahora:** `Wallpapers.qml` tiene `preview(path)`/`stopPreview()` — un booleano `showPreview` que redirige qué imagen alimenta el crossfade, sin tocar el wallpaper real del sistema hasta confirmar. **Decisión: NO portar el preview-en-vivo-sobre-el-escritorio-real.** Nuestro pipeline invoca `awww` + `matugen` + `flock` de forma más pesada que un simple cambio de `source` de `Image` — hacer eso en cada hover de una miniatura sería costoso y probablemente tembloroso (glitchy) si el usuario pasa el mouse rápido por varias miniaturas. Alternativa más barata y más segura, propuesta para Fase 2: agrandar la miniatura bajo hover/foco dentro del propio panel de `WallpaperPicker.qml` (una vista previa grande dentro del picker, no en el escritorio real) — logra el mismo objetivo de "ver antes de elegir" sin tocar el wallpaper real hasta el click.

**Ajuste menor de estilo (restyle, no port):** el video mostraba el nombre del archivo debajo de cada miniatura en el picker — `WallpaperPicker.qml` hoy no muestra ningún label. Agregar un `Text` con el nombre base del archivo (sin extensión) debajo de cada card es un cambio chico y barato, tomado como idea del video, no del código (el código de Caelestia tampoco muestra el nombre en su grid, lo saca de metadata de carpetas/categorías más compleja que no necesitamos).

**Dependencia de plugin nativo (§ítem E):** el pipeline de color de Caelestia depende de `Caelestia::ImageAnalyser` (`plugin/src/Caelestia/imageanalyser.cpp`, nativo) tanto para `wallLuminance` (ver §7.6) como para su propio extractor de paleta. **Ya excluido por vos explícitamente** — nuestro `matugen` vía `workspace-wallpaper` sigue siendo la única fuente de color, sin excepción. Ninguna otra pieza de esta sección requiere el plugin — el crossfade de imagen y el preview-toggle son QtQuick puro.

### 7.6 Vidrio/blur de la bar → hallazgo que cambia el enfoque: **no es blur real, es tinte opaco + sombra de elevación**

**Esto es el hallazgo más importante de toda esta ronda de research.** Fui a buscar la técnica de blur de `components/effects/` y `modules/bar/` esperando encontrar un `MultiEffect`/backdrop-blur aplicado a la bar. No existe tal cosa como blur general de fondo en la bar real:

- `modules/bar/Bar.qml` no dibuja ningún rectángulo de fondo propio — es un `ColumnLayout` desnudo. Cada sección (`Workspaces.qml`, `Tray.qml`, etc.) dibuja su propio fondo redondeado individual con `Colours.tPalette.m3surfaceContainer` — un color **sólido**, no translúcido.
- El único blur real que encontré en toda la bar es puntual y condicional: `Workspaces.qml` línea 42-47 aplica `MultiEffect{blurEnabled:true, blur, blurMax:32}` únicamente cuando estás en un workspace especial (`onSpecial`) — no es la técnica que da la sensación general de "vidrio" del resto de la bar.
- La sensación de "vidrio"/cohesión viene de otro lado: `services/Colours.qml` función `layer()` (líneas 49-53) — las superficies "elevadas" (cards, pills, tabs) son colores **opacos** cuya luminosidad se ajusta según qué tan clara/oscura es la wallpaper actual (`wallLuminance`, calculado por el plugin nativo `ImageAnalyser` — la pieza que ya descartamos en §7.5/§C). Solo la superficie de fondo base (`layer === 0`, el propio `Background.qml`) puede llevar alpha real, y solo si `transparency.enabled` está prendido en su config — que a juzgar por los frames del video (tarjetas opacas, sin wallpaper sangrando a través) probablemente estaba apagado o en un valor bajo durante la grabación.
- La separación visual "flotante" viene de **sombra de elevación** (`components/effects/Elevation.qml`) — `RectangularShadow` (tipo stock de `QtQuick.Effects`, Qt 6.8+, no es un componente nativo de Caelestia) con blur/spread/offset escalados por un "nivel" de elevación tipo Material Design (dp 0,1,3,6,8,12). Esto confirma casi exactamente mi estimado de §2 ("opacidad alta, separación por sombra y contraste, no por transparencia") — ahora con evidencia de código, no solo lectura visual.

**Conclusión práctica — comparación contra el fix de dos rondas atrás:** nuestro fix actual en `Bar.qml` (`Rectangle{color:Theme.activeAccent; opacity:0.09}` superpuesto sobre `Theme.surface`) ya va en la dirección correcta conceptualmente (tinte de acento sobre superficie oscura, no un blur pesado) — el problema no es la técnica, es que es **demasiado débil** comparado con lo que realmente hace que la bar de referencia se sienta cohesiva. Dos cambios concretos a probar en vivo en Fase 2, no mutuamente excluyentes:
1. **Reemplazar el overlay de opacidad plana por un blend HSL real**: mezclar el hue/saturación de `Theme.activeAccent` hacia `Theme.surface` ajustando lightness (similar en espíritu a `alterColour()` de Caelestia pero sin el término `wallLuminance` que depende del plugin nativo que no vamos a adoptar) — probablemente se vea más "tinte de superficie" y menos "capa de color encima".
2. **Agregar sombra de elevación real** a la bar y a las tarjetas del dashboard (drop shadow con blur+offset, vía `MultiEffect` o un `DropShadow`/rect-shadow equivalente disponible en el Qt que usa quickshell) — algo que hoy no tenemos en absoluto y que el código real confirma que es *la* técnica real de separación "flotante" del proyecto de referencia, no el blur.

Ambos son baratos, sin dependencia nativa (ver abajo), y se prueban en vivo comparando contra el fix actual antes de decidir cuál se queda — tal como pediste.

**Dependencia de plugin nativo (§ítem E):** `RectangularShadow` confirmé por grep que **no aparece en ningún archivo del plugin C++** (`plugin/src/Caelestia/`) — es un tipo stock de `QtQuick.Effects`, disponible desde Qt 6.8. `MultiEffect` (usado para el blur puntual de workspaces especiales) es igual de estándar. El blend HSL propuesto es JS puro sobre `Qt.hsla`/`Qt.rgba`. **Decisión: cero dependencia de plugin nativo — todo disponible en QtQuick estándar**, sujeto a confirmar en Fase 2 que la versión de Qt que trae nuestro `quickshell` de nixpkgs sea ≥ 6.8 (si no lo es, `RectangularShadow` no existiría y habría que caer a un `DropShadow` de `Qt5Compat.GraphicalEffects` o simular la sombra con un `Rectangle` extra semitransparente detrás con blur — ambos triviales, sin plugin nativo tampoco).

### 7.7 Resumen de dependencias de plugin nativo (§ítem E, consolidado)

| Componente | Símbolo nativo encontrado | Decisión |
|---|---|---|
| Power menu | `SessionManager.exec` (`Caelestia.Services`) | No se porta — ya tenemos `Process`+`hyprlock`/`systemctl` propio |
| Notificaciones | `ButtonRow` (`Caelestia.Components`, C++) | Reimplementar en QML puro (Row/RowLayout con fill-width manual) |
| Dashboard tabs | `CUtils.clamp` (trivial) | Reimplementar en una línea de JS |
| Workspace icons (diferido) | Ninguno — `Icons.getAppCategoryIcon` es JS puro | Sin impacto, no aplica esta ronda |
| Wallpaper | `ImageAnalyser` (color/luminancia) | Ya excluido explícitamente — matugen sigue siendo la fuente de color |
| Bar glass/elevation | Ninguno — `RectangularShadow`/`MultiEffect` son QtQuick estándar | Sin dependencia, sujeto a versión de Qt (ver §7.6) |

**Conclusión general: ningún componente de esta ronda requiere empaquetar el plugin nativo de Caelestia como derivación Nix.** Cada punto de contacto con `Caelestia`/`Caelestia.Services`/`Caelestia.Components` tiene un sustituto trivial en QML/JS puro o ya tiene un equivalente propio funcionando. Si en el futuro se quisiera portar algo que sí dependa de verdad del plugin (el motor de color M3 completo con `wallLuminance`, el sistema de configuración `Caelestia.Config` completo, el analizador de audio para visualizadores), ahí sí correspondería evaluar `plugin/CMakeLists.txt` como derivación Nix — pero nada de lo decidido en esta ronda lo necesita.

---

## 8. Qué sigue (actualizado — todas las decisiones resueltas)

Con tus respuestas a la ronda anterior de preguntas, el plan queda así, sin puntos abiertos pendientes de tu parte:

| # | Componente | Decisión final |
|---|---|---|
| 1 | Power menu | PORT del trigger a `Bar.qml` vía `Capsule.qml`; se elimina la estructura de esquina-por-proximidad; confirmación hold/two-step se agrega igual (sin precedente, diseño propio) — §7.1 |
| 2 | Notificaciones | Modelo de una tarjeta, reemplazo inmediato por crossfade al llegar una nueva; se portan gestos individuales (drag-dismiss, drag-expand, hover-pausa-timer) con crédito — §7.2 |
| 3 | Dashboard tabs | PORT del mecanismo de carrusel (`Flickable`+`contentX` animado), contenido/tokens propios sin cambios — §7.3 |
| 4 | Workspace indicators | DIFERIDO explícitamente esta ronda — dots se quedan como están, sin tocar — §7.4 |
| 5 | Wallpaper | Sin cambios estructurales al pipeline (`awww`+`matugen` ya es igual o mejor que el crossfade de Caelestia); posible preview-grande-en-el-picker y label de nombre de archivo como mejoras menores — §7.5 |
| 6 | Bar glass/tint | Reemplazar el overlay de 9% de opacidad por un blend HSL más fuerte + agregar sombra de elevación real (`RectangularShadow`/`MultiEffect`, sin dependencia nativa) — ambas técnicas se prueban en vivo y se elige la que se vea mejor, documentando cuál y por qué — §7.6 |
| 7 | Dependencias nativas | Ninguna — todos los puntos de contacto con el plugin C++ de Caelestia tienen sustituto trivial en QML/JS puro o ya tenemos equivalente propio — §7.7 |

Cada bloque de código adaptado (no los que reimplemento desde cero como la confirmación del power menu) lleva su comentario de atribución (`caelestia-dots/shell`, GPLv3, archivo de origen) directamente arriba, como pediste desde el inicio de esta ronda.

**Esto es ahora sí el plan final.** Sigo sin tocar `modules/quickshell/` — quedo a la espera de tu luz verde final antes de arrancar a escribir QML, commit por componente, verificado en vivo, mismo nivel de disciplina que las rondas anteriores.
