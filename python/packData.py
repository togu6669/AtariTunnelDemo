import os
import subprocess
from glob import glob


DATA_BASE_ADDRESS = 0xA000
INC_FILE_PATH = "../src/const_data.inc"
RC_FILE_PATH = "../src/resources_data.rc"


def pack_data():
    for p in glob("../assets/*.dta"):
        papu = p.replace(".dta", ".apu")
        subprocess.run(
            ["../../bin/apultra_osx", p, papu],
            check=True,
        )


def generate_data_consts():
    os.makedirs(os.path.dirname(INC_FILE_PATH), exist_ok=True)

    inc_lines = [f"DATA_BASE = ${DATA_BASE_ADDRESS:04X};"]
    rc_lines = []
    current_offset = 0

    for p in sorted(glob("../assets/*.apu")):
        label = os.path.splitext(os.path.basename(p))[0].upper()

        if current_offset == 0:
            inc_lines.append(f"ADR_{label} = DATA_BASE;")
        else:
            inc_lines.append(f"ADR_{label} = DATA_BASE + ${current_offset:04X};")

        rc_lines.append(f"ADR_{label} rcdata '{p}'")

        current_offset += os.path.getsize(p) + 1

    with open(INC_FILE_PATH, "w") as f:
        f.write("\n".join(inc_lines) + "\n")

    with open(RC_FILE_PATH, "w") as f:
        f.write("\n".join(rc_lines) + "\n")


if __name__ == "__main__":
    pack_data()
    generate_data_consts()