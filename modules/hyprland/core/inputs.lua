-- ==============================================================================
-- CORE: INPUTS (Teclado y Touchpad - LUA v0.55+)
-- ==============================================================================

hl.config({
  input = {
    kb_layout = "latam",
    kb_options = "caps:escape",
    repeat_rate = 50,
    repeat_delay = 300,
    numlock_by_default = true,
    follow_mouse = 1,

    touchpad = {
      natural_scroll = true,
      scroll_factor = 0.5,
      disable_while_typing = true,
      tap_to_click = true,
      clickfinger_behavior = true,
      drag_lock = true
    }
  }
})
