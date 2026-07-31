#!/usr/bin/env python3
"""Combine Meshy one-animation GLBs that share an identical rig.

Meshy's multi-animation ZIP currently contains one skinned GLB per clip. This
tool keeps the mesh, skin, materials, and texture from a chosen base GLB and
copies the animation accessors from every sibling GLB into one compact file.
"""

from __future__ import annotations

import argparse
import copy
import json
import struct
from pathlib import Path


GLB_MAGIC = b"glTF"
JSON_CHUNK = b"JSON"
BIN_CHUNK = b"BIN\x00"


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    if len(data) < 20 or data[:4] != GLB_MAGIC:
        raise ValueError(f"Not a GLB file: {path}")
    version, total_length = struct.unpack_from("<II", data, 4)
    if version != 2 or total_length != len(data):
        raise ValueError(f"Unsupported or truncated GLB: {path}")

    offset = 12
    json_data: dict | None = None
    binary = b""
    while offset < len(data):
        chunk_length = struct.unpack_from("<I", data, offset)[0]
        chunk_type = data[offset + 4 : offset + 8]
        chunk = data[offset + 8 : offset + 8 + chunk_length]
        offset += 8 + chunk_length
        if chunk_type == JSON_CHUNK:
            json_data = json.loads(chunk.rstrip(b"\x00 ").decode("utf-8"))
        elif chunk_type == BIN_CHUNK:
            binary = chunk

    if json_data is None:
        raise ValueError(f"GLB has no JSON chunk: {path}")
    return json_data, binary


def write_glb(path: Path, gltf: dict, binary: bytes) -> None:
    json_bytes = json.dumps(
        gltf, ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    json_bytes += b" " * ((-len(json_bytes)) % 4)
    binary += b"\x00" * ((-len(binary)) % 4)
    gltf["buffers"][0]["byteLength"] = len(binary)

    # byteLength changed after the first encoding, so encode the final JSON.
    json_bytes = json.dumps(
        gltf, ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    json_bytes += b" " * ((-len(json_bytes)) % 4)
    total_length = 12 + 8 + len(json_bytes) + 8 + len(binary)
    output = bytearray()
    output += GLB_MAGIC
    output += struct.pack("<II", 2, total_length)
    output += struct.pack("<I", len(json_bytes)) + JSON_CHUNK + json_bytes
    output += struct.pack("<I", len(binary)) + BIN_CHUNK + binary
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(output)


def node_signature(gltf: dict) -> list[tuple]:
    return [
        (
            str(node.get("name", "")),
            tuple(node.get("children", [])),
            tuple(node.get("translation", [])),
            tuple(node.get("rotation", [])),
            tuple(node.get("scale", [])),
            tuple(node.get("matrix", [])),
        )
        for node in gltf.get("nodes", [])
    ]


def skin_signature(gltf: dict) -> list[tuple[int | None, tuple[int, ...]]]:
    return [
        (skin.get("skeleton"), tuple(skin.get("joints", [])))
        for skin in gltf.get("skins", [])
    ]


def append_animation(
    target: dict,
    target_binary: bytearray,
    source: dict,
    source_binary: bytes,
    animation: dict,
) -> None:
    buffer_view_map: dict[int, int] = {}
    accessor_map: dict[int, int] = {}

    def copy_buffer_view(source_index: int) -> int:
        if source_index in buffer_view_map:
            return buffer_view_map[source_index]
        source_view = source["bufferViews"][source_index]
        source_offset = int(source_view.get("byteOffset", 0))
        source_length = int(source_view["byteLength"])
        target_binary.extend(b"\x00" * ((-len(target_binary)) % 4))
        target_offset = len(target_binary)
        target_binary.extend(
            source_binary[source_offset : source_offset + source_length]
        )
        target_view = copy.deepcopy(source_view)
        target_view["buffer"] = 0
        target_view["byteOffset"] = target_offset
        target_index = len(target["bufferViews"])
        target["bufferViews"].append(target_view)
        buffer_view_map[source_index] = target_index
        return target_index

    def copy_accessor(source_index: int) -> int:
        if source_index in accessor_map:
            return accessor_map[source_index]
        target_accessor = copy.deepcopy(source["accessors"][source_index])
        if "bufferView" in target_accessor:
            target_accessor["bufferView"] = copy_buffer_view(
                int(target_accessor["bufferView"])
            )
        sparse = target_accessor.get("sparse")
        if sparse:
            sparse["indices"]["bufferView"] = copy_buffer_view(
                int(sparse["indices"]["bufferView"])
            )
            sparse["values"]["bufferView"] = copy_buffer_view(
                int(sparse["values"]["bufferView"])
            )
        target_index = len(target["accessors"])
        target["accessors"].append(target_accessor)
        accessor_map[source_index] = target_index
        return target_index

    target_animation = copy.deepcopy(animation)
    for sampler in target_animation.get("samplers", []):
        sampler["input"] = copy_accessor(int(sampler["input"]))
        sampler["output"] = copy_accessor(int(sampler["output"]))
    target["animations"].append(target_animation)


def combine(input_dir: Path, output: Path, base_match: str) -> None:
    output = output.resolve()
    paths = sorted(path for path in input_dir.rglob("*.glb") if path.resolve() != output)
    if not paths:
        raise ValueError(f"No GLB files found below {input_dir}")
    base_candidates = [path for path in paths if base_match.lower() in path.name.lower()]
    if len(base_candidates) != 1:
        raise ValueError(
            f"Expected one base matching {base_match!r}, found {len(base_candidates)}"
        )
    base_path = base_candidates[0]
    base, base_binary = read_glb(base_path)
    expected_nodes = node_signature(base)
    expected_skins = skin_signature(base)
    target = copy.deepcopy(base)
    target["animations"] = []
    target_binary = bytearray(base_binary)
    names: set[str] = set()

    for source_path in paths:
        source, source_binary = read_glb(source_path)
        if node_signature(source) != expected_nodes:
            raise ValueError(f"Node layout differs: {source_path}")
        if skin_signature(source) != expected_skins:
            raise ValueError(f"Skin layout differs: {source_path}")
        animations = source.get("animations", [])
        if len(animations) != 1:
            raise ValueError(
                f"Expected exactly one animation in {source_path}, found {len(animations)}"
            )
        name = str(animations[0].get("name", source_path.stem))
        if name in names:
            raise ValueError(f"Duplicate animation name: {name}")
        names.add(name)
        append_animation(target, target_binary, source, source_binary, animations[0])

    write_glb(output, target, bytes(target_binary))
    print(f"Combined {len(names)} animations into {output}")
    for name in sorted(names):
        print(name)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--base-match", default="Idle_11")
    args = parser.parse_args()
    combine(args.input_dir.resolve(), args.output.resolve(), args.base_match)


if __name__ == "__main__":
    main()
