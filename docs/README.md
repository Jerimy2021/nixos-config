# Índice de documentación

Historial de arquitectura de este repo, en orden. Cada `NIXOS_ARCHITECTURE_HITO_*.md`
documenta decisiones tomadas, bugs reales encontrados y su causa raíz, y el estado
exacto del sistema en ese momento — no se reescriben retroactivamente, cada hito
nuevo es un archivo nuevo.

- [`NIXOS_ARCHITECTURE_HITO_001.md`](NIXOS_ARCHITECTURE_HITO_001.md) — estado inicial del sistema (hardware, estética, stack base).
- [`NIXOS_ARCHITECTURE_HITO_002.md`](NIXOS_ARCHITECTURE_HITO_002.md) — Hyprland-Lua fork, dispatchers `hl.dsp.*`.
- [`NIXOS_ARCHITECTURE_HITO_003.md`](NIXOS_ARCHITECTURE_HITO_003.md) — deprecación de `modules/ml4w/`, migración de Claude Code a paquete declarativo.
- [`NIXOS_ARCHITECTURE_HITO_004.md`](NIXOS_ARCHITECTURE_HITO_004.md) — QuickShell reemplaza waybar/swaync/dunst, doce follow-ups (theming, HDMI, Dolphin+Kvantum, etc.). Cerrado — ver su propia §30 "Estado de Ratificación".
- [`NIXOS_ARCHITECTURE_HITO_005.md`](NIXOS_ARCHITECTURE_HITO_005.md) — file manager Kirigami+KIO (`nixfm`), en construcción, instalado en paralelo a Dolphin.
- [`NIXOS_FILEMANAGER_HITO05_PLAN.md`](NIXOS_FILEMANAGER_HITO05_PLAN.md) — plan de investigación/scope del Hito 005, aprobado antes de escribir código.
- [`NIXOS_SHELL_VIDEO_ANALYSIS.md`](NIXOS_SHELL_VIDEO_ANALYSIS.md) — análisis de video del shell (QuickShell), insumo de varios follow-ups del Hito 004.

## Mantenimiento del repo (fuera del alcance de un hito específico)

**2026-08-06** — dos limpiezas independientes, en `hito-05-filemanager`, sin relación
con el trabajo del file manager en sí:

1. **Reorganización de docs**: los siete archivos de arriba vivían sueltos en la raíz
   del repo; se movieron acá (`git mv`, historia preservada por archivo) y se
   actualizó la referencia de `README.md`. Este archivo es el índice nuevo que faltaba.
2. **Auditoría de paquetes muertos** en `hosts/laptop/home.nix` (misma metodología
   que la deprecación de ml4w del Hito 003: grep de todo el repo por uso real antes
   de tocar nada). Eliminados por evidencia de cero referencias:
   `webp-pixbuf-loader`, `poppler_gi` (decodificadores GTK/tumbler de la era Thunar,
   ya documentados como reemplazados por el stack KIO de Dolphin pero nunca
   removidos), `wl-clip-persist` (demonio instalado pero nunca lanzado en
   `autostart.lua` ni en ningún script). Candidatos revisados y confirmados como
   ya limpios de antes: `pywal` (sigue en uso real), `waybar`/`wlogout`/paquetes
   Thunar (ya removidos en Hito 004), los diez `mis-scripts.*` (todos referenciados).
   Verificado con `nixos-rebuild build --flake .#laptop`.
