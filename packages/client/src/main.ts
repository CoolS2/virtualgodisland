import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { catchUp, generateIsland } from '@vgi/sim';
import { createHand, followPointer } from './hand';
import { loadWorld, saveWorld } from './save';
import { buildTerrain, buildWater } from './terrain';

const world = loadWorld(Date.now());
const offlineTicks = catchUp(world, Date.now());
const map = generateIsland(world.seed);

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color('#87c6ff');
scene.fog = new THREE.Fog('#87c6ff', 120, 260);

const camera = new THREE.PerspectiveCamera(50, innerWidth / innerHeight, 0.1, 1000);
camera.position.set(60, 55, 60);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.maxPolarAngle = Math.PI * 0.45;
controls.minDistance = 20;
controls.maxDistance = 160;

scene.add(new THREE.HemisphereLight('#ffffff', '#3a5a40', 0.9));
const sun = new THREE.DirectionalLight('#fff4e0', 2);
sun.position.set(40, 80, 20);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -60, right: 60, top: 60, bottom: -60 });
scene.add(sun);

const terrain = buildTerrain(map);
scene.add(terrain, buildWater(map));

const hand = createHand();
scene.add(hand);

const pointer = new THREE.Vector2(9, 9); // за экраном, пока мышь не двигалась
const raycaster = new THREE.Raycaster();
addEventListener('pointermove', (e) => {
  pointer.set((e.clientX / innerWidth) * 2 - 1, -(e.clientY / innerHeight) * 2 + 1);
});
addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
});

const hud = document.getElementById('hud')!;
const renderHud = (): void => {
  const h = world.human;
  hud.textContent =
    `seed ${world.seed} · tick ${world.tick} · офлайн +${offlineTicks} · ` +
    `голод ${h.hunger.toFixed(0)} · жажда ${h.thirst.toFixed(0)} · силы ${h.energy.toFixed(0)}` +
    (h.alive ? '' : ' · ПОГИБ');
};

// живая симуляция: тот же catchUp раз в секунду, тики идут по реальному времени
setInterval(() => {
  if (catchUp(world, Date.now()) > 0) saveWorld(world);
  renderHud();
}, 1000);
addEventListener('beforeunload', () => saveWorld(world));
saveWorld(world);
renderHud();

renderer.setAnimationLoop(() => {
  controls.update();
  followPointer(hand, terrain, camera, pointer, raycaster);
  renderer.render(scene, camera);
});

