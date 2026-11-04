import { Router } from "express";
import { prisma } from "../db/prisma";
import { requireManager } from "../auth/middleware";
import { markArrived } from "./service";
import { asyncHandler } from "../asyncHandler";

export const managerTicketRouter = Router();
managerTicketRouter.use(requireManager);

// Active tickets (what the dashboard's live board is built from) plus a
// short recent-history tail, scoped to the logged-in manager's hotel only.
managerTicketRouter.get(
  "/tickets",
  asyncHandler(async (req, res) => {
    const hotelId = req.hotelId!;

    const active = await prisma.ticket.findMany({
      where: { status: { in: ["CHECKED_IN", "REQUESTED"] }, qrCode: { hotelId } },
      include: { qrCode: { select: { hotelLocalNumber: true } } },
      orderBy: { checkedInAt: "asc" },
    });

    const recentlyCompleted = await prisma.ticket.findMany({
      where: { status: "COMPLETED", qrCode: { hotelId } },
      include: { qrCode: { select: { hotelLocalNumber: true } } },
      orderBy: { completedAt: "desc" },
      take: 10,
    });

    res.json({ active, recentlyCompleted });
  })
);

managerTicketRouter.post(
  "/tickets/:id/arrived",
  asyncHandler(async (req, res) => {
    const hotelId = req.hotelId!;
    const result = await markArrived(req.params.id, hotelId);
    if (!result.ok) return res.status(400).json({ error: result.error });
    res.json({ ok: true });
  })
);

// Read-only QR inventory for this hotel, so the manager can see tag status
// without needing admin access.
managerTicketRouter.get(
  "/qrcodes",
  asyncHandler(async (req, res) => {
    const hotelId = req.hotelId!;
    const qrCodes = await prisma.qRCode.findMany({
      where: { hotelId },
      select: { id: true, hotelLocalNumber: true, status: true },
      orderBy: { hotelLocalNumber: "asc" },
    });
    res.json(qrCodes);
  })
);
