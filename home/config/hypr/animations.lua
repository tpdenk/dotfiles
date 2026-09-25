local hl = hl or error("no hl")

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 1.6, bezier = "linear" })

hl.animation({ leaf = "windows", enabled = true, speed = 1.2, bezier = "linear", style = "popin 90%" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.2, bezier = "linear" })

hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.2, bezier = "linear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.2, bezier = "linear" })

hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 1.4, bezier = "linear" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 1.4, bezier = "linear" })
hl.animation({ leaf = "fadeGlow", enabled = true, speed = 1.4, bezier = "linear" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 1.6, bezier = "linear" })

hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.2, bezier = "linear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1, bezier = "linear" })

hl.animation({ leaf = "fadePopupsIn", enabled = true, speed = 1, bezier = "linear" })
hl.animation({ leaf = "fadePopupsOut", enabled = true, speed = 1, bezier = "linear" })

hl.animation({ leaf = "fadeDpms", enabled = true, speed = 1.6, bezier = "linear" })

hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "linear" })
-- "once" = one gradient sweep each time a window gains focus
hl.animation({ leaf = "borderangle", enabled = true, speed = 6, bezier = "easeOutQuint", style = "once" })
hl.animation({ leaf = "glowangle", enabled = true, speed = 6, bezier = "easeOutQuint", style = "once" })

hl.animation({ leaf = "workspaces", enabled = true, speed = 1.6, bezier = "linear", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.4, bezier = "linear", style = "slidevert" })
