import * as THREE from 'three';

/** Заглушка руки бога: сфера, парящая над точкой под курсором. Модель — этап 1. */
export function createHand(): THREE.Mesh {
  const hand = new THREE.Mesh(
    new THREE.SphereGeometry(0.8, 16, 12),
    new THREE.MeshStandardMaterial({ color: '#ffd7b5' }),
  );
  hand.castShadow = true;
  return hand;
}

export function followPointer(
  hand: THREE.Object3D,
  target: THREE.Object3D,
  camera: THREE.Camera,
  pointer: THREE.Vector2,
  raycaster: THREE.Raycaster,
  hover = 3,
): void {
  raycaster.setFromCamera(pointer, camera);
  const hit = raycaster.intersectObject(target, false)[0];
  if (!hit) return;
  hand.position.lerp(hit.point.clone().add(new THREE.Vector3(0, hover, 0)), 0.2);
}
