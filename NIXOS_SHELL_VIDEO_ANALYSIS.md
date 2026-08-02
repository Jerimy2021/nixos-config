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

Este documento es el final de la Fase 1. No se tocó ningún archivo QML. Quedo a la espera de tus correcciones sobre lo que haya leído mal (especialmente §1.4 el widget flotante, y tu decisión sobre §3.7 notificaciones) antes de arrancar Fase 2.
