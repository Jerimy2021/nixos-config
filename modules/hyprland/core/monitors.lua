-- ==============================================================================
-- CORE: MONITORES Y PANTALLAS (Sintaxis Lua - v0.55+)
-- ==============================================================================

-- 1. Pantalla principal (Tu Laptop) - Forzando su máxima resolución y Hz naturales
hl.monitor({
  output = "eDP-1",
  mode = "1366x768@60",
  position = "0x0",
  scale = 1
})

-- 2. Regla universal de fallback (Por si conectas un HDMI a un proyector o TV)
-- Dejando el 'output' vacío ("") creamos la regla por defecto para cualquier pantalla extra.
--
-- Hito 004 follow-up 20: reconsiderado si hacía falta una regla explícita
-- para HDMI-A-1 en vez de este fallback genérico, dado el perfil híbrido
-- Intel+NVIDIA PRIME de este laptop (NIXOS_ARCHITECTURE_HITO_001.md
-- §1.1/§4.2). Verificado en vivo (no asumido) cuál GPU maneja el puerto:
-- /sys/class/drm/card1-HDMI-A-{1,2}/status ambos resuelven a
-- pci0000:00:02.0, el Bus ID documentado del iGPU Intel (PCI:0:2:0) — el
-- HDMI lo maneja Intel en solitario, la dGPU NVIDIA (offload puro) no
-- entra en el camino de auto-detección/hotplug en absoluto. Conclusión:
-- NO hace falta una regla explícita por el motivo que se sospechaba (una
-- carrera de switch de GPU) — este fallback genérico se comporta
-- exactamente igual que en un laptop solo-Intel, sin complejidad extra de
-- PRIME en el medio. El bug real de solape (ver hosts/laptop/scripts.nix,
-- hdmi-control) no era esto — era `wlr-randr` peleando con el motor de
-- reglas de Hyprland por fuera, ya corregido ahí usando `hl.monitor()` en
-- vivo vía `hyprctl eval` en vez de wlr-randr.
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1
})
