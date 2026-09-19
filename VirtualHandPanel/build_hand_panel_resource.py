"""Build HandPanelAssets.res from HandPanelsBackground.png.

The output is a standard Microsoft .res file containing one RCDATA resource
named HAND_PANEL_BACKGROUND. It avoids requiring Delphi to invoke a resource
compiler for a secondary .rc file.
"""

from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "HandPanelsBackground.png"
OUTPUT = ROOT / "HandPanelAssets.res"
RESOURCE_NAME = "HAND_PANEL_BACKGROUND"
RT_RCDATA = 10


def pad4(data: bytes) -> bytes:
    return data + (b"\0" * (-len(data) % 4))


def ordinal(value: int) -> bytes:
    return struct.pack("<HH", 0xFFFF, value)


def resource_entry(name: str, resource_type: int, data: bytes) -> bytes:
    variable_header = ordinal(resource_type)
    variable_header += (name + "\0").encode("utf-16le")
    variable_header = pad4(variable_header)

    fixed_header = struct.pack(
        "<IHHII",
        0,      # DataVersion
        0x0030, # MOVEABLE | PURE
        0,      # neutral language
        0,      # Version
        0,      # Characteristics
    )
    header_size = 8 + len(variable_header) + len(fixed_header)
    header = struct.pack("<II", len(data), header_size)
    header += variable_header + fixed_header
    return header + pad4(data)


def main() -> None:
    # Microsoft .res files begin with an empty resource header.
    null_header = struct.pack("<II", 0, 32)
    null_header += ordinal(0) + ordinal(0)
    null_header += struct.pack("<IHHII", 0, 0, 0, 0, 0)

    output = null_header + resource_entry(
        RESOURCE_NAME,
        RT_RCDATA,
        SOURCE.read_bytes(),
    )
    OUTPUT.write_bytes(output)
    print(f"Wrote {OUTPUT.name} ({len(output)} bytes)")


if __name__ == "__main__":
    main()
