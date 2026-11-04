import { randomBytes, scryptSync, timingSafeEqual } from "crypto";

// Uses Node's built-in crypto (scrypt) instead of an extra native dependency
// like bcrypt - one less thing to install/compile on the server later.

const KEY_LENGTH = 64;

export function hashPassword(plainPassword: string): string {
  const salt = randomBytes(16).toString("hex");
  const derivedKey = scryptSync(plainPassword, salt, KEY_LENGTH).toString("hex");
  return `${salt}:${derivedKey}`;
}

export function verifyPassword(plainPassword: string, storedHash: string): boolean {
  const [salt, derivedKeyHex] = storedHash.split(":");
  if (!salt || !derivedKeyHex) return false;
  const candidate = scryptSync(plainPassword, salt, KEY_LENGTH);
  const stored = Buffer.from(derivedKeyHex, "hex");
  if (candidate.length !== stored.length) return false;
  return timingSafeEqual(candidate, stored);
}
