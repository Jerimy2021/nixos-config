-- ==============================================================================
-- CORE: VARIABLES DE ENTORNO (Híbrido Optimus: Intel Main + NVIDIA Offload - LUA)
-- ==============================================================================

-- 1. CURSORES CONSISTENTES
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")

-- 2. SISTEMA WAYLAND
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- 3. COMPATIBILIDAD DE TOOLKITS (Fuerza Wayland nativo en apps)
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("OZONE_PLATFORM", "wayland")

-- (NUEVO) Solución para evitar el parpadeo (flickering) en apps Electron en Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- 4. ACELERACIÓN DE HARDWARE (Manejo inteligente de la GPU Híbrida)
-- Usamos el driver de Intel (iHD) para el escritorio y reproducción de video.
-- Esto asegura animaciones a 60Hz estables y salva tu batería.
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- Opcional para offload de video en NVIDIA si usas nvidia-vaapi-driver:
-- hl.env("NVD_BACKEND", "direct")
