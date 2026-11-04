import { Router } from "express";
import { prisma } from "../db/prisma";
import { verifyPassword } from "./password";
import { signToken } from "./jwt";
import { asyncHandler } from "../asyncHandler";

export const authRouter = Router();

authRouter.post(
  "/admin/login",
  asyncHandler(async (req, res) => {
    const { email, password } = req.body ?? {};
    if (!email || !password) {
      return res.status(400).json({ error: "email and password are required" });
    }

    const admin = await prisma.adminUser.findUnique({ where: { email } });
    if (!admin || !verifyPassword(password, admin.passwordHash)) {
      return res.status(401).json({ error: "invalid credentials" });
    }

    const token = signToken({ role: "admin", adminId: admin.id });
    res.json({ token });
  })
);

authRouter.post(
  "/manager/login",
  asyncHandler(async (req, res) => {
    const { email, password } = req.body ?? {};
    if (!email || !password) {
      return res.status(400).json({ error: "email and password are required" });
    }

    const manager = await prisma.managerUser.findUnique({ where: { email } });
    if (!manager || !verifyPassword(password, manager.passwordHash)) {
      return res.status(401).json({ error: "invalid credentials" });
    }

    const token = signToken({ role: "manager", managerId: manager.id, hotelId: manager.hotelId });
    res.json({ token });
  })
);
