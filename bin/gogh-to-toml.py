#!/usr/bin/env python3
"""Convert a single Gogh theme JSON object (from Gogh-Co/Gogh data/themes.json)
into an Omarchy colors.toml. Reads the theme JSON on stdin, writes TOML on stdout.
"""
import json
import sys


def clamp(v):
    return max(0, min(255, int(round(v))))


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return "#{:02x}{:02x}{:02x}".format(*(clamp(c) for c in rgb))


def blend(a, b, t):
    """t=0 -> a, t=1 -> b"""
    ar, ag, ab = hex_to_rgb(a)
    br, bg, bb = hex_to_rgb(b)
    return rgb_to_hex((ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t))


def lighten(h, amount):
    return blend(h, "#ffffff", amount)


def darken(h, amount):
    return blend(h, "#000000", amount)


def main():
    theme = json.load(sys.stdin)

    variant = str(theme.get("variant", "dark")).strip().lower()
    mode = "light" if variant == "light" else "dark"

    background = theme["background"]
    foreground = theme["foreground"]
    red = theme["color_02"]
    green = theme["color_03"]
    yellow = theme["color_04"]
    blue = theme["color_05"]
    magenta = theme["color_06"]
    cyan = theme["color_07"]
    bright_red = theme["color_10"]
    bright_green = theme["color_11"]
    bright_yellow = theme["color_12"]
    bright_blue = theme["color_13"]
    bright_magenta = theme["color_14"]
    bright_cyan = theme["color_15"]

    orange = blend(red, yellow, 0.45)
    brown = darken(blend(red, yellow, 0.3), 0.5)
    accent = blue

    if mode == "dark":
        dark_background = darken(background, 0.06)
        darker_background = darken(background, 0.13)
        lighter_background = lighten(background, 0.08)
        selection = blend(background, foreground, 0.18)
        muted = blend(background, foreground, 0.28)
        dark_foreground = blend(foreground, background, 0.55)
        light_foreground = blend(foreground, background, 0.2)
    else:
        dark_background = darken(background, 0.06)
        darker_background = darken(background, 0.13)
        lighter_background = darken(background, 0.09)
        selection = darken(background, 0.12)
        muted = darken(background, 0.2)
        dark_foreground = blend(foreground, background, 0.55)
        light_foreground = blend(foreground, background, 0.2)

    bright_foreground = foreground

    toml = f'''mode = "{mode}"

accent = "{accent}"
selection = "{selection}"
muted = "{muted}"

background = "{background}"
dark_background = "{dark_background}"
darker_background = "{darker_background}"
lighter_background = "{lighter_background}"

foreground = "{foreground}"
dark_foreground = "{dark_foreground}"
light_foreground = "{light_foreground}"
bright_foreground = "{bright_foreground}"

red = "{red}"
yellow = "{yellow}"
orange = "{orange}"
green = "{green}"
cyan = "{cyan}"
blue = "{blue}"
magenta = "{magenta}"
brown = "{brown}"

bright_red = "{bright_red}"
bright_yellow = "{bright_yellow}"
bright_green = "{bright_green}"
bright_cyan = "{bright_cyan}"
bright_blue = "{bright_blue}"
bright_magenta = "{bright_magenta}"
'''
    sys.stdout.write(toml)


if __name__ == "__main__":
    main()
