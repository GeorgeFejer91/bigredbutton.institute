#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) {
  args.set(process.argv[i], process.argv[i + 1]);
}

const modelPath = args.get("--model");
const outPath = args.get("--out");
const ffmpegPath = args.get("--ffmpeg") || "ffmpeg";
const size = Number.parseInt(args.get("--size") || "512", 10);
const yaw = degToRad(Number.parseFloat(args.get("--yaw") || "-32"));
const pitch = degToRad(Number.parseFloat(args.get("--pitch") || "-24"));

if (!modelPath || !outPath) {
  throw new Error("Usage: node render-button-model-thumbnail.mjs --model <BigRedButton.glb> --out <png>");
}

const glb = readFileSync(modelPath);
const parsed = parseGlb(glb);
const texturePng = extractImage(parsed);
const textureInfo = texturePng ? parsePngHeader(texturePng) : { width: 1, height: 1 };
const texture = texturePng ? decodePngToRgba(texturePng, textureInfo.width, textureInfo.height, ffmpegPath) : null;
const vertices = collectVertices(parsed);
const bounds = computeBounds(vertices.map((v) => v.position));
const center = [
  (bounds.min[0] + bounds.max[0]) / 2,
  (bounds.min[1] + bounds.max[1]) / 2,
  (bounds.min[2] + bounds.max[2]) / 2,
];

for (const vertex of vertices) {
  const local = [
    vertex.position[0] - center[0],
    vertex.position[1] - center[1],
    vertex.position[2] - center[2],
  ];
  vertex.view = rotate(rotate(local, "y", yaw), "x", pitch);
  vertex.viewNormal = normalize(rotate(rotate(vertex.normal, "y", yaw), "x", pitch));
}

const viewBounds = computeBounds(vertices.map((v) => [v.view[0], -v.view[1], v.view[2]]));
const pad = size * 0.12;
const scale = Math.min(
  (size - pad * 2) / Math.max(0.000001, viewBounds.max[0] - viewBounds.min[0]),
  (size - pad * 2) / Math.max(0.000001, viewBounds.max[1] - viewBounds.min[1]),
);
const offsetX = (size - (viewBounds.min[0] + viewBounds.max[0]) * scale) / 2;
const offsetY = (size - (viewBounds.min[1] + viewBounds.max[1]) * scale) / 2;

for (const vertex of vertices) {
  vertex.screen = [
    vertex.view[0] * scale + offsetX,
    -vertex.view[1] * scale + offsetY,
    vertex.view[2],
  ];
}

const rgba = new Uint8ClampedArray(size * size * 4);
const zBuffer = new Float32Array(size * size);
zBuffer.fill(-Infinity);
drawSoftShadow(rgba, size);

const light = normalize([-0.35, 0.78, 0.52]);
for (const tri of parsed.triangles) {
  rasterizeTriangle(
    rgba,
    zBuffer,
    size,
    vertices[tri.indices[0]],
    vertices[tri.indices[1]],
    vertices[tri.indices[2]],
    tri.material,
    texture,
    textureInfo.width,
    textureInfo.height,
    light,
  );
}

encodePng(Buffer.from(rgba.buffer), size, size, outPath, ffmpegPath);
console.log(
  JSON.stringify(
    {
      model: modelPath,
      output: outPath,
      size,
      yawDegrees: Number((yaw / Math.PI * 180).toFixed(2)),
      pitchDegrees: Number((pitch / Math.PI * 180).toFixed(2)),
      vertices: vertices.length,
      triangles: parsed.triangles.length,
      note: texture
        ? "Rendered directly from BigRedButton.glb geometry and embedded texture."
        : "Rendered directly from BigRedButton.glb geometry and material colors.",
    },
    null,
    2,
  ),
);

function parseGlb(buffer) {
  if (buffer.toString("ascii", 0, 4) !== "glTF") {
    throw new Error("Input is not a binary glTF file.");
  }
  const jsonLength = buffer.readUInt32LE(12);
  const jsonType = buffer.toString("ascii", 16, 20);
  if (jsonType !== "JSON") {
    throw new Error(`Unexpected first GLB chunk: ${jsonType}`);
  }
  const json = JSON.parse(buffer.toString("utf8", 20, 20 + jsonLength));
  const binHeader = 20 + jsonLength;
  const binLength = buffer.readUInt32LE(binHeader);
  const binType = buffer.toString("ascii", binHeader + 4, binHeader + 8);
  if (binType !== "BIN\u0000") {
    throw new Error(`Unexpected second GLB chunk: ${binType}`);
  }
  const bin = buffer.subarray(binHeader + 8, binHeader + 8 + binLength);
  const parsed = { json, bin, triangles: [] };
  return parsed;
}

function extractImage(parsed) {
  const image = parsed.json.images?.[0];
  if (!image?.bufferView) {
    return null;
  }
  const view = parsed.json.bufferViews[image.bufferView];
  return parsed.bin.subarray(view.byteOffset || 0, (view.byteOffset || 0) + view.byteLength);
}

function collectVertices(parsed) {
  const out = [];
  for (const mesh of parsed.json.meshes || []) {
    for (const primitive of mesh.primitives || []) {
      const baseIndex = out.length;
      const positions = readAccessor(parsed, primitive.attributes.POSITION);
      const normals = readAccessor(parsed, primitive.attributes.NORMAL);
      const texcoords = readAccessor(parsed, primitive.attributes.TEXCOORD_0);
      for (let i = 0; i < positions.length; i++) {
        out.push({
          position: positions[i],
          normal: normals[i] || [0, 1, 0],
          uv: texcoords[i] || [0.5, 0.5],
        });
      }
      const indices = readAccessor(parsed, primitive.indices).flat();
      const material = readMaterial(parsed, primitive.material);
      for (let i = 0; i < indices.length; i += 3) {
        parsed.triangles.push({
          indices: [baseIndex + indices[i], baseIndex + indices[i + 1], baseIndex + indices[i + 2]],
          material,
        });
      }
    }
  }
  return out;
}

function readMaterial(parsed, materialIndex) {
  const material = parsed.json.materials?.[materialIndex] || {};
  const pbr = material.pbrMetallicRoughness || {};
  const factor = pbr.baseColorFactor || [1, 1, 1, 1];
  return {
    baseColor: [
      clamp(Math.round(factor[0] * 255), 0, 255),
      clamp(Math.round(factor[1] * 255), 0, 255),
      clamp(Math.round(factor[2] * 255), 0, 255),
      clamp(Math.round((factor[3] ?? 1) * 255), 0, 255),
    ],
    hasTexture: Boolean(pbr.baseColorTexture),
    roughness: pbr.roughnessFactor ?? 0.45,
    metallic: pbr.metallicFactor ?? 0,
  };
}

function readAccessor(parsed, accessorIndex) {
  const accessor = parsed.json.accessors[accessorIndex];
  const view = parsed.json.bufferViews[accessor.bufferView];
  const componentCount = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 }[accessor.type];
  const componentSize = { 5123: 2, 5126: 4 }[accessor.componentType];
  const byteStride = view.byteStride || componentCount * componentSize;
  const start = (view.byteOffset || 0) + (accessor.byteOffset || 0);
  const values = [];
  for (let i = 0; i < accessor.count; i++) {
    const item = [];
    const itemStart = start + i * byteStride;
    for (let c = 0; c < componentCount; c++) {
      const offset = itemStart + c * componentSize;
      if (accessor.componentType === 5126) {
        item.push(parsed.bin.readFloatLE(offset));
      } else if (accessor.componentType === 5123) {
        item.push(parsed.bin.readUInt16LE(offset));
      } else {
        throw new Error(`Unsupported component type ${accessor.componentType}`);
      }
    }
    values.push(item);
  }
  return values;
}

function rasterizeTriangle(rgba, zBuffer, size, a, b, c, material, texture, texWidth, texHeight, light) {
  const ax = a.screen[0], ay = a.screen[1];
  const bx = b.screen[0], by = b.screen[1];
  const cx = c.screen[0], cy = c.screen[1];
  const area = edge(ax, ay, bx, by, cx, cy);
  if (Math.abs(area) < 0.00001) return;

  const minX = clamp(Math.floor(Math.min(ax, bx, cx)), 0, size - 1);
  const maxX = clamp(Math.ceil(Math.max(ax, bx, cx)), 0, size - 1);
  const minY = clamp(Math.floor(Math.min(ay, by, cy)), 0, size - 1);
  const maxY = clamp(Math.ceil(Math.max(ay, by, cy)), 0, size - 1);

  for (let y = minY; y <= maxY; y++) {
    for (let x = minX; x <= maxX; x++) {
      const px = x + 0.5;
      const py = y + 0.5;
      const w0 = edge(bx, by, cx, cy, px, py) / area;
      const w1 = edge(cx, cy, ax, ay, px, py) / area;
      const w2 = 1 - w0 - w1;
      if (w0 < -0.0001 || w1 < -0.0001 || w2 < -0.0001) continue;

      const z = a.screen[2] * w0 + b.screen[2] * w1 + c.screen[2] * w2;
      const pixel = y * size + x;
      if (z <= zBuffer[pixel]) continue;
      zBuffer[pixel] = z;

      const u = a.uv[0] * w0 + b.uv[0] * w1 + c.uv[0] * w2;
      const v = a.uv[1] * w0 + b.uv[1] * w1 + c.uv[1] * w2;
      const texel = material.hasTexture && texture
        ? sampleTexture(texture, texWidth, texHeight, u, v)
        : material.baseColor;
      const normal = normalize([
        a.viewNormal[0] * w0 + b.viewNormal[0] * w1 + c.viewNormal[0] * w2,
        a.viewNormal[1] * w0 + b.viewNormal[1] * w1 + c.viewNormal[1] * w2,
        a.viewNormal[2] * w0 + b.viewNormal[2] * w1 + c.viewNormal[2] * w2,
      ]);
      const diffuse = Math.max(0, dot(normal, light));
      const rim = Math.max(0, 1 - Math.abs(normal[2])) * 0.09;
      const specularBoost = material.metallic * 0.12 + (1 - material.roughness) * 0.08;
      const shade = 0.66 + diffuse * 0.42 + rim + specularBoost;
      const o = pixel * 4;
      rgba[o] = clamp(Math.round(texel[0] * shade), 0, 255);
      rgba[o + 1] = clamp(Math.round(texel[1] * shade), 0, 255);
      rgba[o + 2] = clamp(Math.round(texel[2] * shade), 0, 255);
      rgba[o + 3] = 255;
    }
  }
}

function sampleTexture(texture, width, height, u, v) {
  const x = clamp(Math.round(fract(u) * (width - 1)), 0, width - 1);
  const y = clamp(Math.round((1 - fract(v)) * (height - 1)), 0, height - 1);
  const offset = (y * width + x) * 4;
  return [texture[offset], texture[offset + 1], texture[offset + 2], texture[offset + 3]];
}

function drawSoftShadow(rgba, size) {
  const cx = size * 0.5;
  const cy = size * 0.68;
  const rx = size * 0.29;
  const ry = size * 0.09;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const d = ((x - cx) * (x - cx)) / (rx * rx) + ((y - cy) * (y - cy)) / (ry * ry);
      if (d <= 1) {
        const alpha = Math.round((1 - d) * 42);
        const o = (y * size + x) * 4;
        rgba[o] = 0;
        rgba[o + 1] = 0;
        rgba[o + 2] = 0;
        rgba[o + 3] = alpha;
      }
    }
  }
}

function decodePngToRgba(pngBytes, width, height, ffmpegPath) {
  const result = spawnSync(
    ffmpegPath,
    ["-hide_banner", "-loglevel", "error", "-i", "pipe:0", "-f", "rawvideo", "-pix_fmt", "rgba", "pipe:1"],
    { input: pngBytes, maxBuffer: width * height * 4 + 1024 * 1024 },
  );
  if (result.status !== 0) {
    throw new Error(`ffmpeg PNG decode failed: ${result.stderr.toString("utf8")}`);
  }
  return result.stdout;
}

function encodePng(rawRgba, width, height, outPath, ffmpegPath) {
  const result = spawnSync(
    ffmpegPath,
    ["-hide_banner", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", `${width}x${height}`, "-i", "pipe:0", "-frames:v", "1", "-y", outPath],
    { input: rawRgba, maxBuffer: 1024 * 1024 },
  );
  if (result.status !== 0) {
    throw new Error(`ffmpeg PNG encode failed: ${result.stderr.toString("utf8")}`);
  }
}

function parsePngHeader(buffer) {
  if (buffer.toString("ascii", 1, 4) !== "PNG") {
    throw new Error("Embedded image is not PNG.");
  }
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

function computeBounds(points) {
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (const point of points) {
    for (let i = 0; i < 3; i++) {
      min[i] = Math.min(min[i], point[i]);
      max[i] = Math.max(max[i], point[i]);
    }
  }
  return { min, max };
}

function rotate(v, axis, angle) {
  const c = Math.cos(angle);
  const s = Math.sin(angle);
  if (axis === "x") return [v[0], c * v[1] - s * v[2], s * v[1] + c * v[2]];
  if (axis === "y") return [c * v[0] + s * v[2], v[1], -s * v[0] + c * v[2]];
  throw new Error(`Unsupported axis ${axis}`);
}

function normalize(v) {
  const len = Math.hypot(v[0], v[1], v[2]) || 1;
  return [v[0] / len, v[1] / len, v[2] / len];
}

function dot(a, b) {
  return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

function edge(ax, ay, bx, by, cx, cy) {
  return (cx - ax) * (by - ay) - (cy - ay) * (bx - ax);
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function degToRad(degrees) {
  return (degrees * Math.PI) / 180;
}

function fract(value) {
  return value - Math.floor(value);
}
