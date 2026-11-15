-- Windows XP: nvim in Microsoft's "Campbell" console palette (the cmd.exe
-- colour refresh Windows Terminal ships), identical in all five XP schemes,
-- through aether.nvim the way Omarchy's generated themes do it.
-- Black background, #CCCCCC text, XP's #316AC5 highlight blue for selections.
--
-- aether paints most of these as text on black, so where a Campbell colour is
-- too dark to read there (blue #0037DA, purple #B4009E) the role takes its
-- bright Campbell partner, or a lifted magenta for keywords. Campbell has no
-- orange; numbers use one between its red and yellow.
return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg = "#000000",
        dark_bg = "#0C0C0C",
        darker_bg = "#000000",
        -- Word-under-cursor and cursor column: a quiet grey, not a block.
        lighter_bg = "#262626",

        fg = "#CCCCCC",
        dark_fg = "#9A9A9A",
        light_fg = "#F2F2F2",
        bright_fg = "#F2F2F2",
        muted = "#767676",

        red = "#E74856",
        yellow = "#C19C00",
        orange = "#F0A030",
        green = "#13A10E",
        cyan = "#3A96DD",
        blue = "#3B78FF",
        magenta = "#D670D6",
        brown = "#C19C00",

        bright_red = "#E74856",
        bright_yellow = "#F9F1A5",
        bright_green = "#16C60C",
        bright_cyan = "#61D6D6",
        bright_blue = "#3B78FF",
        bright_magenta = "#E07AD8",

        accent = "#3B78FF",
        cursor = "#FFFFFF",
        foreground = "#CCCCCC",
        background = "#000000",
        selection = "#316AC5",
        selection_foreground = "#FFFFFF",
        selection_background = "#316AC5",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
