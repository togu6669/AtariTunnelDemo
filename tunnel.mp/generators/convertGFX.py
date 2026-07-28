from PIL import Image, ImageOps


def generate_gender_assets():
    def process_image(input_path, output_path, value):
        img = Image.open(input_path).convert("RGBA")

        target_height = 128
        aspect_ratio = img.width / img.height
        new_width = int(target_height * aspect_ratio)
        img = img.resize((new_width, target_height), Image.NEAREST)

        pad_width = 320
        padding_left = (pad_width - new_width) // 2
        padding_right = pad_width - new_width - padding_left
        img = ImageOps.expand(
            img, border=(padding_left, 0, padding_right, 0), fill=0
        )

        pad_height = 192
        padding_top = (pad_height - target_height) // 2
        padding_bottom = pad_height - target_height - padding_top
        img = ImageOps.expand(
            img, border=(0, padding_top, 0, padding_bottom), fill=0
        )

        final_size = (160, 192)
        img = img.resize(final_size, Image.NEAREST)

        pixels = img.load()

        byte_stream = bytearray()

        for y in range(192):
            line_bytes = bytearray()
            for x in range(0, 160, 4):
                packed = 0
                for i in range(4):
                    r, g, b, a = pixels[x + i, y]
                    if (
                        a == 0
                        or (r, g, b) == (255, 255, 255)
                        or (r, g, b) == (0, 0, 0)
                    ):
                        color = 0
                    else:
                        color = value
                    packed |= (color & 0x03) << (6 - i * 2)
                line_bytes.append(packed)

            if (len(byte_stream) // 4096) != (
                (len(byte_stream) + len(line_bytes) - 1) // 4096
            ):
                pad_amount = 4096 - (len(byte_stream) % 4096)
                byte_stream.extend([0] * pad_amount)
                print(
                    f"Padded {pad_amount} bytes before line {y} to respect 4K boundary"
                )

            byte_stream.extend(line_bytes)

        with open(output_path, "wb") as f:
            f.write(byte_stream)

        print(f"Wrote {output_path} ({len(byte_stream)} bytes)")

    process_image("./gfx/man.png", "../assets/man.dta", 1)
    process_image("./gfx/woman.png", "../assets/woman.dta", 2)


generate_gender_assets()
