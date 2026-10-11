from PIL import Image


def find_red_lines(img):
    w, h = img.size

    x_lines = []
    for x in range(w):
        if sum(
            1
            for y in range(h)
            if (lambda p: p[0] > 200 and p[1] < 80 and p[2] < 80)(img.getpixel((x, y)))
        ) > h * 0.5:
            x_lines.append(x)

    y_lines = []
    for y in range(h):
        if sum(
            1
            for x in range(w)
            if (lambda p: p[0] > 200 and p[1] < 80 and p[2] < 80)(img.getpixel((x, y)))
        ) > w * 0.5:
            y_lines.append(y)

    return x_lines, y_lines


def remove_red(img):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src = img.load()
    dst = out.load()

    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = src[x, y]
            if r > 200 and g < 80 and b < 80:
                continue
            dst[x, y] = (r, g, b, a)

    return out


def extract_font(filename, first_char):
    img = Image.open(filename).convert("RGBA")

    x_lines, y_lines = find_red_lines(img)

    if len(y_lines) < 2:
        raise RuntimeError(f"Couldn't detect horizontal guide lines in {filename}")

    if len(x_lines) < 27:
        raise RuntimeError(f"Couldn't detect vertical guide lines in {filename}")

    img = img.crop((0, y_lines[0] + 1, img.width, y_lines[1]))

    font = {}

    for i in range(26):
        glyph = img.crop((x_lines[i] + 1, 0, x_lines[i + 1], img.height))
        font[chr(first_char + i)] = remove_red(glyph)

    return font


def extract_fonts():
    fonts = {}
    fonts.update(extract_font("gfx/cut_capital2.png", ord("A")))
    fonts.update(extract_font("gfx/cut_small2.png", ord("a")))
    return fonts


def render_text(text, fonts, width):
    if not fonts:
        return None

    height = max(g.height for g in fonts.values())
    space_width = round(sum(g.width for g in fonts.values()) / len(fonts))

    glyphs = []

    for c in text:
        if c == " ":
            glyphs.append(Image.new("RGBA", (space_width, height), (0, 0, 0, 0)))
        elif c in fonts:
            glyphs.append(fonts[c])

    if not glyphs:
        return None

    total_width = sum(g.width for g in glyphs)

    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    x = (width - total_width) // 2

    for glyph in glyphs:
        canvas.paste(glyph, (x, height - glyph.height), glyph)
        x += glyph.width

    return canvas


def pixel_is_white(pixel):
    r, g, b, _ = pixel
    return (r + g + b) // 3 > 128


def encode_mode_f(img):
    pixels = img.load()
    data = bytearray()

    for y in range(img.height):
        for x in range(0, img.width, 8):
            v = 0
            for i in range(8):
                if x + i < img.width and pixel_is_white(pixels[x + i, y]):
                    v |= 1 << (7 - i)
            data.append(v)

    return data


def encode_mode_e(img):
    pixels = img.load()
    data = bytearray()

    for y in range(img.height):
        for x in range(0, img.width, 4):
            v = 0
            for i in range(4):
                if x + i < img.width:
                    color = 1 if pixel_is_white(pixels[x + i, y]) else 0
                    v |= color << (6 - i * 2)
            data.append(v)

    return data


def render_and_save(strings_dict, mode="E"):
    print (f"Generating mode {mode}")
    fonts = extract_fonts()

    mode = mode.upper()

    if mode == "F":
        width = 320
        encoder = encode_mode_f
    elif mode == "E":
        width = 160
        encoder = encode_mode_e
    else:
        raise ValueError("mode must be E or F")

    for text, outfile in strings_dict.items():
        bitmap = render_text(text, fonts, width)

        if bitmap is None:
            continue

        with open(outfile, "wb") as f:
            f.write(encoder(bitmap))

        print(f"Wrote {outfile}")


render_dict = {
    "Die Geburt": "../assets/diegeburt.dta",
    "Der Tunnel": "../assets/dertunnel.dta",
    "Das Leben": "../assets/dasleben.dta",
    "Der Tod": "../assets/dertod.dta",
}

render_and_save(render_dict, mode="F")