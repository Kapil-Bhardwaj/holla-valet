import jwt from "jsonwebtoken";

export type AdminTokenPayload = { role: "admin"; adminId: string };
export type ManagerTokenPayload = { role: "manager"; managerId: string; hotelId: string };
export type TokenPayload = AdminTokenPayload | ManagerTokenPayload;

function getSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error("JWT_SECRET is not set - refusing to sign/verify tokens");
  }
  return secret;
}

// 7 days: logging in once should hold through a browser refresh and across
// several shifts, not force a re-login every session. Both apps persist
// this token locally so a refresh doesn't lose it either.
export function signToken(payload: TokenPayload): string {
  return jwt.sign(payload, getSecret(), { expiresIn: "7d" });
}

export function verifyToken(token: string): TokenPayload {
  return jwt.verify(token, getSecret()) as TokenPayload;
}
