#!/usr/bin/env python3
"""Generate Big Red Button heartbeat glow GLB material variants.

The native Meta Spatial SDK Mesh path does not currently expose a mutable
material handle for a loaded GLB renderer. This generator keeps the original
geometry, animation, buffers, and opaque material path, then writes 32 GLB
copies with progressively hotter cap material color/emission and subtle warmth
on the neighboring metal bezel. The dark base is intentionally preserved so the
pedestal does not appear to change material during a heartbeat.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import struct
from pathlib import Path

JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942

CAP_MATERIAL = "glossy_red_button_cap"
SIDE_MATERIAL = "deep_red_cap_side"
BEZEL_MATERIAL = "dark_brushed_metal_bezel"
BASE_MATERIAL = "matte_black_base"

CAP_PEAK_BASE = [1.0, 0.085, 0.025, 1.0]
CAP_PEAK_EMISSION = [3.35, 0.095, 0.026]
CAP_PEAK_ROUGHNESS = 0.128

SIDE_PEAK_BASE = [0.86, 0.035, 0.016, 1.0]
SIDE_PEAK_EMISSION = [0.78, 0.026, 0.008]
SIDE_PEAK_ROUGHNESS = 0.205

BEZEL_PEAK_BASE = [0.365, 0.35, 0.33, 1.0]
BEZEL_PEAK_EMISSION = [0.020, 0.004, 0.0015]
BEZEL_PEAK_ROUGHNESS = 0.205

BASE_PEAK_BASE = [0.018, 0.020, 0.022, 1.0]
BASE_PEAK_EMISSION = [0.0, 0.0, 0.0]
BASE_PEAK_ROUGHNESS = 0.38


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        type=Path,
        default=Path("app/src/main/assets/models/BigRedButton.glb"),
        help="Source BigRedButton.glb path.",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("app/src/main/assets/models/glow"),
        help="Output directory for BigRedButtonGlowLevelXX.glb files.",
    )
    parser.add_argument("--levels", type=int, default=32)
    args = parser.parse_args()

    gltf, chunks = read_glb(args.source)
    args.out_dir.mkdir(parents=True, exist_ok=True)

    cap_index = find_material(gltf, CAP_MATERIAL)
    side_index = find_material(gltf, SIDE_MATERIAL)
    bezel_index = find_material(gltf, BEZEL_MATERIAL)
    base_index = find_material(gltf, BASE_MATERIAL)
    cap_base = material_base(gltf, cap_index)
    side_base = material_base(gltf, side_index)
    bezel_base = material_base(gltf, bezel_index)
    base_base = material_base(gltf, base_index)
    cap_roughness = material_roughness(gltf, cap_index)
    side_roughness = material_roughness(gltf, side_index)
    bezel_roughness = material_roughness(gltf, bezel_index)
    base_roughness = material_roughness(gltf, base_index)

    outputs = []
    for level in range(1, args.levels + 1):
        raw_t = level / args.levels
        t = 1.0 - math.pow(1.0 - raw_t, 1.65)
        variant = copy.deepcopy(gltf)
        update_material(
            variant,
            cap_index,
            name=f"{CAP_MATERIAL}_native_emissive_contrast_{level:02d}",
            base=lerp_vec(cap_base, CAP_PEAK_BASE, t),
            emissive=lerp_vec([0.0, 0.0, 0.0], CAP_PEAK_EMISSION, t),
            roughness=lerp(cap_roughness, CAP_PEAK_ROUGHNESS, t),
        )
        update_material(
            variant,
            side_index,
            name=f"{SIDE_MATERIAL}_native_emissive_contrast_{level:02d}",
            base=lerp_vec(side_base, SIDE_PEAK_BASE, t),
            emissive=lerp_vec([0.0, 0.0, 0.0], SIDE_PEAK_EMISSION, t),
            roughness=lerp(side_roughness, SIDE_PEAK_ROUGHNESS, t),
        )
        update_material(
            variant,
            bezel_index,
            name=f"{BEZEL_MATERIAL}_native_reflected_warmth_{level:02d}",
            base=lerp_vec(bezel_base, BEZEL_PEAK_BASE, t),
            emissive=lerp_vec([0.0, 0.0, 0.0], BEZEL_PEAK_EMISSION, t),
            roughness=lerp(bezel_roughness, BEZEL_PEAK_ROUGHNESS, t),
        )
        update_material(
            variant,
            base_index,
            name=f"{BASE_MATERIAL}_native_reflected_warmth_{level:02d}",
            base=lerp_vec(base_base, BASE_PEAK_BASE, t),
            emissive=lerp_vec([0.0, 0.0, 0.0], BASE_PEAK_EMISSION, t),
            roughness=lerp(base_roughness, BASE_PEAK_ROUGHNESS, t),
        )
        out_path = args.out_dir / f"BigRedButtonGlowLevel{level:02d}.glb"
        write_glb(out_path, variant, chunks)
        outputs.append(
            {
                "level": level,
                "path": str(out_path),
                "t": round(t, 6),
                "capBase": material_base(variant, cap_index),
                "capEmission": variant["materials"][cap_index]["emissiveFactor"],
                "bezelEmission": variant["materials"][bezel_index]["emissiveFactor"],
                "baseEmission": variant["materials"][base_index]["emissiveFactor"],
            }
        )

    print(json.dumps({"source": str(args.source), "levels": outputs}, indent=2))


def read_glb(path: Path) -> tuple[dict, list[tuple[int, bytes]]]:
    data = path.read_bytes()
    magic, version, total_length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or total_length != len(data):
        raise ValueError(f"{path} is not a valid GLB v2 file")
    offset = 12
    gltf = None
    chunks: list[tuple[int, bytes]] = []
    while offset < len(data):
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset : offset + chunk_length]
        offset += chunk_length
        if chunk_type == JSON_CHUNK:
            gltf = json.loads(chunk.decode("utf-8").rstrip("\x00 "))
        else:
            chunks.append((chunk_type, chunk))
    if gltf is None:
        raise ValueError(f"{path} has no JSON chunk")
    return gltf, chunks


def write_glb(path: Path, gltf: dict, chunks: list[tuple[int, bytes]]) -> None:
    json_bytes = pad(json.dumps(gltf, separators=(",", ":")).encode("utf-8"), b" ")
    body = bytearray()
    body.extend(struct.pack("<II", len(json_bytes), JSON_CHUNK))
    body.extend(json_bytes)
    for chunk_type, chunk in chunks:
        padded_chunk = pad(chunk, b"\x00")
        body.extend(struct.pack("<II", len(padded_chunk), chunk_type))
        body.extend(padded_chunk)
    header = struct.pack("<4sII", b"glTF", 2, 12 + len(body))
    path.write_bytes(header + body)


def pad(data: bytes, fill: bytes) -> bytes:
    remainder = len(data) % 4
    if remainder == 0:
        return data
    return data + fill * (4 - remainder)


def find_material(gltf: dict, name: str) -> int:
    for index, material in enumerate(gltf.get("materials", [])):
        if material.get("name") == name:
            return index
    raise ValueError(f"Material not found: {name}")


def material_base(gltf: dict, index: int) -> list[float]:
    pbr = gltf["materials"][index].setdefault("pbrMetallicRoughness", {})
    return list(pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0]))


def material_roughness(gltf: dict, index: int) -> float:
    pbr = gltf["materials"][index].setdefault("pbrMetallicRoughness", {})
    return float(pbr.get("roughnessFactor", 0.5))


def update_material(
    gltf: dict,
    index: int,
    name: str,
    base: list[float],
    emissive: list[float],
    roughness: float,
) -> None:
    material = gltf["materials"][index]
    material["name"] = name
    material["emissiveFactor"] = [round(value, 6) for value in emissive[:3]]
    pbr = material.setdefault("pbrMetallicRoughness", {})
    pbr["baseColorFactor"] = [round(value, 6) for value in base]
    pbr["roughnessFactor"] = round(roughness, 6)


def lerp(start: float, end: float, t: float) -> float:
    return start + (end - start) * t


def lerp_vec(start: list[float], end: list[float], t: float) -> list[float]:
    return [lerp(start[index], end[index], t) for index in range(len(end))]


if __name__ == "__main__":
    main()
