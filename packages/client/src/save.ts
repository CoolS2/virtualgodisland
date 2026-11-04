import { createWorld, type World } from '@vgi/sim';

const KEY = 'vgi:save:v1';

export function loadWorld(now: number): World {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return JSON.parse(raw) as World;
  } catch {
    // битый сейв — начинаем заново
  }
  return createWorld(Math.floor(Math.random() * 2 ** 31), now); // Math.random() допустим только вне sim/
}

export function saveWorld(w: World): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(w));
  } catch {
    // квота/приватный режим — игнорируем
  }
}
