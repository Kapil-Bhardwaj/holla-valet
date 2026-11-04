import type { NextFunction, Request, Response } from "express";
import { verifyToken } from "./jwt";

// Augment Express's Request type with what our auth middleware attaches.
declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      adminId?: string;
      managerId?: string;
      hotelId?: string;
    }
  }
}

function extractBearerToken(req: Request): string | null {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) return null;
  return header.slice("Bearer ".length).trim();
}

export function requireAdmin(req: Request, res: Response, next: NextFunction) {
  const token = extractBearerToken(req);
  if (!token) return res.status(401).json({ error: "missing bearer token" });
  try {
    const payload = verifyToken(token);
    if (payload.role !== "admin") {
      return res.status(403).json({ error: "admin role required" });
    }
    req.adminId = payload.adminId;
    next();
  } catch {
    return res.status(401).json({ error: "invalid or expired token" });
  }
}

export function requireManager(req: Request, res: Response, next: NextFunction) {
  const token = extractBearerToken(req);
  if (!token) return res.status(401).json({ error: "missing bearer token" });
  try {
    const payload = verifyToken(token);
    if (payload.role !== "manager") {
      return res.status(403).json({ error: "manager role required" });
    }
    req.managerId = payload.managerId;
    req.hotelId = payload.hotelId;
    next();
  } catch {
    return res.status(401).json({ error: "invalid or expired token" });
  }
}
