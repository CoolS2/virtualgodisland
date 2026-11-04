import * as THREE from 'three';
import type { Biome, IslandMap } from '@vgi/sim';

const COLORS: Record<Biome, THREE.Color> = {
  sea: new THREE.Color('#c9b27a'),   // дно под водой
  beach: new THREE.Color('#f2d27a'),
  field: new THREE.Color('#8fd14f'),
  forest: new THREE.Color('#2f8f3a'),
  mountain: new THREE.Color('#8a8f99'),
};
const SNOW = new THREE.Color('#f4f6fb');

export function buildTerrain(map: IslandMap, tile = 1): THREE.Mesh {
  const n = map.size;
  const geo = new THREE.PlaneGeometry((n - 1) * tile, (n - 1) * tile, n - 1, n - 1);
  geo.rotateX(-Math.PI / 2);

  const pos = geo.getAttribute('position') as THREE.BufferAttribute;
  const colors = new Float32Array(pos.count * 3);
  for (let i = 0; i < pos.count; i++) {
    const x = i % n, y = Math.floor(i / n);
    const h = map.heights[y]![x]!;
    const biome = map.biomes[y]![x]!;
    pos.setY(i, h);
    (biome === 'mountain' && h > 7 ? SNOW : COLORS[biome]).toArray(colors, i * 3);
  }
  geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geo.computeVertexNormals();

  const mesh = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ vertexColors: true, flatShading: true }));
  mesh.receiveShadow = true;
  mesh.castShadow = true;
  return mesh;
}

export function buildWater(map: IslandMap, tile = 1): THREE.Mesh {
  const geo = new THREE.PlaneGeometry(map.size * tile * 4, map.size * tile * 4);
  geo.rotateX(-Math.PI / 2);
  const mat = new THREE.MeshStandardMaterial({ color: '#2a6fdb', transparent: true, opacity: 0.85, roughness: 0.3 });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.y = -0.05;
  mesh.receiveShadow = true;
  return mesh;
}
