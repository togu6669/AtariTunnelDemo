from PIL import Image
import os


# ------------------------------------------------------------
# ANTIC Mode F (Graphics 8)
# ------------------------------------------------------------

def decode_mode_f(filename, output_png, height):
    """
    Decode a raw ANTIC Mode F bitmap.

    width  = 320 pixels
    bytes/line = 40
    """

    width = 320

    with open(filename, "rb") as f:
        data = f.read()

    expected = 40 * height

    if len(data) != expected:
        raise ValueError(
            f"Expected {expected} bytes, got {len(data)} bytes."
        )

    img = Image.new("RGB", (width, height), "black")
    pixels = img.load()

    ptr = 0

    for y in range(height):
        for bx in range(40):

            b = data[ptr]
            ptr += 1

            for bit in range(8):

                x = bx * 8 + bit

                if b & (1 << (7 - bit)):
                    pixels[x, y] = (255, 255, 255)

    img.save(output_png)
    print("Saved", output_png)


# ------------------------------------------------------------
# ANTIC Mode E
# ------------------------------------------------------------

def decode_mode_e(filename, output_png, height):
    """
    Decode ANTIC Mode E.

    width = 160
    2 bits/pixel
    40 bytes/line
    """

    width = 160

    with open(filename, "rb") as f:
        data = f.read()

    expected = 40 * height

    if len(data) != expected:
        raise ValueError(
            f"Expected {expected} bytes, got {len(data)} bytes."
        )

    img = Image.new("RGB", (width, height), "black")
    pixels = img.load()

    ptr = 0

    palette = [
        (0, 0, 0),
        (255, 255, 255),
        (170, 170, 170),
        (85, 85, 85),
    ]

    for y in range(height):

        for bx in range(40):

            b = data[ptr]
            ptr += 1

            for i in range(4):

                color = (b >> (6 - i * 2)) & 3

                x = bx * 4 + i

                pixels[x, y] = palette[color]

    img.save(output_png)
    print("Saved", output_png)


# ------------------------------------------------------------
# Wrapper
# ------------------------------------------------------------

def decode(filename, mode, height, output_png=None):

    if output_png is None:
        output_png = os.path.splitext(filename)[0] + ".png"

    mode = mode.upper()

    if mode == "F":
        decode_mode_f(filename, output_png, height)

    elif mode == "E":
        decode_mode_e(filename, output_png, height)

    else:
        raise ValueError("Mode must be E or F")


# ------------------------------------------------------------
# Example
# ------------------------------------------------------------

decode(
    "../assets/diegeburt.dta",
    mode="F",
    height=40
)


decode(
    "../assets/dertunnel.dta",
    mode="F",
    height=40
)


#