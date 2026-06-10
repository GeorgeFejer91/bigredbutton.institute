#!/usr/bin/env node
import { writeFileSync } from "node:fs";

const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) {
  args.set(process.argv[i], process.argv[i + 1]);
}

const outPath = args.get("--out");
if (!outPath) {
  throw new Error("Usage: node create-realistic-button-model.mjs --out <BigRedButton.glb>");
}

const meshes = [];
const materials = [
  { name: "glossy_red_button_cap", color: [0.92, 0.015, 0.012, 1], metallic: 0.02, roughness: 0.18 },
  { name: "matte_black_base", color: [0.018, 0.02, 0.022, 1], metallic: 0.15, roughness: 0.38 },
  { name: "dark_brushed_metal_bezel", color: [0.35, 0.35, 0.34, 1], metallic: 0.82, roughness: 0.23 },
  { name: "deep_red_cap_side", color: [0.48, 0.006, 0.006, 1], metallic: 0.02, roughness: 0.24 },
];

meshes.push(makeLatheMesh("button_cap", 0, [
  [0.0100, 0.00685],
  [0.0126, 0.00685],
  [0.0141, 0.00670],
  [0.0156, 0.00618],
  [0.0169, 0.00525],
  [0.0178, 0.00395],
  [0.01835, 0.00225],
  [0.01855, 0.00000],
], 96));
meshes.push(makeLatheMesh("cap_side_shadow", 3, [
  [0.00945, 0.00695],
  [0.0101, 0.00695],
], 96));
meshes.push(makeLatheMesh("metal_bezel", 2, [
  [0.00615, 0.00795],
  [0.00675, 0.00855],
  [0.00855, 0.00855],
  [0.00925, 0.00755],
  [0.00962, 0.00685],
], 96));
meshes.push(makeLatheMesh("button_base", 1, [
  [0.0000, 0.00765],
  [0.0007, 0.00885],
  [0.0028, 0.00925],
  [0.00455, 0.00885],
  [0.00585, 0.00775],
  [0.0063, 0.00695],
], 96));

const glb = buildGlb(meshes, materials);
writeFileSync(outPath, glb);
console.log(JSON.stringify({
  output: outPath,
  meshes: meshes.length,
  vertices: meshes.reduce((sum, mesh) => sum + mesh.positions.length / 3, 0),
  triangles: meshes.reduce((sum, mesh) => sum + mesh.indices.length / 3, 0),
  animation: "pressed",
  note: "Generated smooth packaged GLB for the native Quest study; preserves BigRedButton.glb URI and pressed animation contract.",
}, null, 2));

function makeLatheMesh(name, material, profile, segments) {
  const positions = [];
  const normals = [];
  const texcoords = [];
  const indices = [];

  for (let r = 0; r < profile.length; r++) {
    const [y, radius] = profile[r];
    for (let s = 0; s < segments; s++) {
      const t = (s / segments) * Math.PI * 2;
      positions.push(Math.cos(t) * radius, y, Math.sin(t) * radius);
      texcoords.push(s / segments, r / Math.max(1, profile.length - 1));
      normals.push(0, 0, 0);
    }
  }

  for (let r = 0; r < profile.length - 1; r++) {
    for (let s = 0; s < segments; s++) {
      const next = (s + 1) % segments;
      const a = r * segments + s;
      const b = r * segments + next;
      const c = (r + 1) * segments + s;
      const d = (r + 1) * segments + next;
      const r0 = profile[r][1];
      const r1 = profile[r + 1][1];
      if (r0 > 0 && r1 > 0) {
        indices.push(a, c, b, b, c, d);
      } else if (r0 > 0) {
        indices.push(a, c, b);
      } else if (r1 > 0) {
        indices.push(a, c, d);
      }
    }
  }

  accumulateNormals(positions, normals, indices);
  return { name, material, positions, normals, texcoords, indices };
}

function accumulateNormals(positions, normals, indices) {
  for (let i = 0; i < indices.length; i += 3) {
    const ia = indices[i] * 3;
    const ib = indices[i + 1] * 3;
    const ic = indices[i + 2] * 3;
    const a = [positions[ia], positions[ia + 1], positions[ia + 2]];
    const b = [positions[ib], positions[ib + 1], positions[ib + 2]];
    const c = [positions[ic], positions[ic + 1], positions[ic + 2]];
    const n = normalize(cross(sub(b, a), sub(c, a)));
    for (const idx of [ia, ib, ic]) {
      normals[idx] += n[0];
      normals[idx + 1] += n[1];
      normals[idx + 2] += n[2];
    }
  }
  for (let i = 0; i < normals.length; i += 3) {
    const n = normalize([normals[i], normals[i + 1], normals[i + 2]]);
    normals[i] = n[0];
    normals[i + 1] = n[1];
    normals[i + 2] = n[2];
  }
}

function buildGlb(meshes, materials) {
  const chunks = [];
  const bufferViews = [];
  const accessors = [];
  const gltfMeshes = [];

  for (const mesh of meshes) {
    const positionAccessor = addFloatAccessor(chunks, bufferViews, accessors, mesh.positions, "VEC3", 34962, bounds(mesh.positions, 3));
    const normalAccessor = addFloatAccessor(chunks, bufferViews, accessors, mesh.normals, "VEC3", 34962);
    const texcoordAccessor = addFloatAccessor(chunks, bufferViews, accessors, mesh.texcoords, "VEC2", 34962);
    const indexAccessor = addUint16Accessor(chunks, bufferViews, accessors, mesh.indices, "SCALAR", 34963);
    gltfMeshes.push({
      name: mesh.name,
      primitives: [{
        attributes: { POSITION: positionAccessor, NORMAL: normalAccessor, TEXCOORD_0: texcoordAccessor },
        indices: indexAccessor,
        material: mesh.material,
        mode: 4,
      }],
    });
  }

  const timeAccessor = addFloatAccessor(chunks, bufferViews, accessors, [0, 0.07, 0.16], "SCALAR");
  const pressAccessor = addFloatAccessor(chunks, bufferViews, accessors, [
    0, 0, 0,
    0, -0.0038, 0,
    0, 0, 0,
  ], "VEC3");

  const bin = Buffer.concat(chunks);
  const json = {
    asset: { version: "2.0", generator: "Big Red Button native study generator" },
    scene: 0,
    scenes: [{ nodes: [0] }],
    nodes: [
      { name: "RootNode", children: [1, 2, 3, 4] },
      { name: "button", mesh: 0 },
      { name: "cap_side_shadow", mesh: 1 },
      { name: "metal_bezel", mesh: 2 },
      { name: "button_base", mesh: 3 },
    ],
    meshes: gltfMeshes,
    materials: materials.map((mat) => ({
      name: mat.name,
      pbrMetallicRoughness: {
        baseColorFactor: mat.color,
        metallicFactor: mat.metallic,
        roughnessFactor: mat.roughness,
      },
      alphaMode: "OPAQUE",
    })),
    animations: [{
      name: "pressed",
      samplers: [{ input: timeAccessor, output: pressAccessor, interpolation: "LINEAR" }],
      channels: [{ sampler: 0, target: { node: 1, path: "translation" } }],
    }],
    buffers: [{ byteLength: bin.length }],
    bufferViews,
    accessors,
  };

  const jsonBuffer = padded(Buffer.from(JSON.stringify(json), "utf8"), 0x20);
  const binBuffer = padded(bin, 0x00);
  const totalLength = 12 + 8 + jsonBuffer.length + 8 + binBuffer.length;
  const header = Buffer.alloc(12);
  header.write("glTF", 0, 4, "ascii");
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(totalLength, 8);
  const jsonHeader = Buffer.alloc(8);
  jsonHeader.writeUInt32LE(jsonBuffer.length, 0);
  jsonHeader.write("JSON", 4, 4, "ascii");
  const binHeader = Buffer.alloc(8);
  binHeader.writeUInt32LE(binBuffer.length, 0);
  binHeader.write("BIN\0", 4, 4, "ascii");
  return Buffer.concat([header, jsonHeader, jsonBuffer, binHeader, binBuffer]);
}

function addFloatAccessor(chunks, bufferViews, accessors, values, type, target, minMax = null) {
  const buffer = Buffer.alloc(values.length * 4);
  values.forEach((value, index) => buffer.writeFloatLE(value, index * 4));
  return addAccessor(chunks, bufferViews, accessors, buffer, 5126, type, target, values, minMax);
}

function addUint16Accessor(chunks, bufferViews, accessors, values, type, target) {
  const buffer = Buffer.alloc(values.length * 2);
  values.forEach((value, index) => buffer.writeUInt16LE(value, index * 2));
  return addAccessor(chunks, bufferViews, accessors, buffer, 5123, type, target, values, null);
}

function addAccessor(chunks, bufferViews, accessors, rawBuffer, componentType, type, target, values, minMax) {
  const byteOffset = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  const paddedBuffer = padded(rawBuffer, 0x00);
  chunks.push(paddedBuffer);
  const bufferView = { buffer: 0, byteOffset, byteLength: rawBuffer.length };
  if (target) bufferView.target = target;
  const bufferViewIndex = bufferViews.push(bufferView) - 1;
  const componentCount = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 }[type];
  const accessor = {
    bufferView: bufferViewIndex,
    byteOffset: 0,
    componentType,
    count: values.length / componentCount,
    type,
  };
  if (minMax) {
    accessor.min = minMax.min;
    accessor.max = minMax.max;
  }
  return accessors.push(accessor) - 1;
}

function bounds(values, width) {
  const min = Array(width).fill(Infinity);
  const max = Array(width).fill(-Infinity);
  for (let i = 0; i < values.length; i += width) {
    for (let c = 0; c < width; c++) {
      min[c] = Math.min(min[c], values[i + c]);
      max[c] = Math.max(max[c], values[i + c]);
    }
  }
  return { min, max };
}

function padded(buffer, byte) {
  const pad = (4 - (buffer.length % 4)) % 4;
  return pad ? Buffer.concat([buffer, Buffer.alloc(pad, byte)]) : buffer;
}

function sub(a, b) {
  return [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
}

function cross(a, b) {
  return [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ];
}

function normalize(v) {
  const len = Math.hypot(v[0], v[1], v[2]) || 1;
  return [v[0] / len, v[1] / len, v[2] / len];
}
