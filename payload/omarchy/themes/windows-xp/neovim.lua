-- Windows XP: nvim in the cmd.exe console palette (identical in all five XP
-- schemes), through aether.nvim the way Omarchy's generated themes do it.
-- Black, grey #C0C0C0 text, the 16 legacy console colours, inverted selection.
return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg = "#000000",
        dark_bg = "#000000",
        darker_bg = "#000000",
        lighter_bg = "#000080",

        fg = "#C0C0C0",
        dark_fg = "#808080",
        light_fg = "#C0C0C0",
        bright_fg = "#FFFFFF",
        muted = "#808080",

        red = "#800000",
        yellow = "#808000",
        orange = "#808000",
        green = "#008000",
        cyan = "#008080",
        blue = "#000080",
        magenta = "#800080",
        brown = "#808000",

        bright_red = "#FF0000",
        bright_yellow = "#FFFF00",
        bright_green = "#00FF00",
        bright_cyan = "#00FFFF",
        bright_blue = "#0000FF",
        bright_magenta = "#FF00FF",

        accent = "#C0C0C0",
        cursor = "#FFFFFF",
        foreground = "#C0C0C0",
        background = "#000000",
        selection = "#C0C0C0",
        selection_foreground = "#000000",
        selection_background = "#C0C0C0",
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
