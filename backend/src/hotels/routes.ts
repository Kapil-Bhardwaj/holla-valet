import { Router } from "express";
import { prisma } from "../db/prisma";
import { requireAdmin } from "../auth/middleware";
import { hashPassword } from "../auth/password";
import { asyncHandler } from "../asyncHandler";

export const hotelRouter = Router();
hotelRouter.use(requireAdmin);

hotelRouter.post(
  "/",
  asyncHandler(async (req, res) => {
    const { vendorId, name, address } = req.body ?? {};
    if (!vendorId || !name) {
      return res.status(400).json({ error: "vendorId and name are required" });
    }

    const vendor = await prisma.vendor.findUnique({ where: { id: vendorId } });
    if (!vendor) return res.status(404).json({ error: "vendor not found" });

    const hotel = await prisma.hotel.create({ data: { vendorId, name, address } });
    res.status(201).json(hotel);
  })
);

hotelRouter.get(
  "/",
  asyncHandler(async (req, res) => {
    const { vendorId } = req.query;
    const hotels = await prisma.hotel.findMany({
      where: vendorId ? { vendorId: String(vendorId) } : undefined,
      include: { _count: { select: { qrCodes: true, managers: true } } },
      orderBy: { createdAt: "desc" },
    });
    res.json(hotels);
  })
);

// Creates the login a hotel's valet manager will use. One hotel can have
// more than one manager login (e.g. shift handoff) if you call this twice.
hotelRouter.post(
  "/:hotelId/manager",
  asyncHandler(async (req, res) => {
    const { hotelId } = req.params;
    const { email, password } = req.body ?? {};
    if (!email || !password) {
      return res.status(400).json({ error: "email and password are required" });
    }

    const hotel = await prisma.hotel.findUnique({ where: { id: hotelId } });
    if (!hotel) return res.status(404).json({ error: "hotel not found" });

    const manager = await prisma.managerUser.create({
      data: { hotelId, email, passwordHash: hashPassword(password) },
    });
    res.status(201).json({ id: manager.id, email: manager.email, hotelId: manager.hotelId });
  })
);

hotelRouter.get(
  "/:hotelId/managers",
  asyncHandler(async (req, res) => {
    const managers = await prisma.managerUser.findMany({
      where: { hotelId: req.params.hotelId },
      select: { id: true, email: true, createdAt: true },
    });
    res.json(managers);
  })
);

// No self-service "forgot password" flow yet (that needs email/SMS sending,
// out of scope for MVP) - admin resets it by hand instead.
hotelRouter.patch(
  "/:hotelId/manager/:managerId/password",
  asyncHandler(async (req, res) => {
    const { password } = req.body ?? {};
    if (!password) return res.status(400).json({ error: "password is required" });

    const manager = await prisma.managerUser.findFirst({
      where: { id: req.params.managerId, hotelId: req.params.hotelId },
    });
    if (!manager) return res.status(404).json({ error: "manager not found for this hotel" });

    await prisma.managerUser.update({
      where: { id: manager.id },
      data: { passwordHash: hashPassword(password) },
    });
    res.json({ ok: true });
  })
);
