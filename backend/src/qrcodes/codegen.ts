import { randomBytes } from "crypto";

// Random, unguessable, URL-safe. This is the value embedded in the printed
// QR/short-link - never the sequential hotelLocalNumber, so nobody can guess
// a neighbouring tag's code from one they have.
export function generateQrCode(): string {
  return randomBytes(6).toString("base64url");
}
