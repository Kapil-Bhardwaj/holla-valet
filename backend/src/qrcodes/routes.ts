import { Router } from "express";
import QRCode from "qrcode";
import { prisma } from "../db/prisma";
import { requireAdmin } from "../auth/middleware";
import { generateQrCode } from "./codegen";
import { asyncHandler } from "../asyncHandler";

export const qrCodeRouter = Router();
qrCodeRouter.use(requireAdmin);

// Assign a new batch of QR tags to a hotel, permanently. Numbering continues
// from whatever the hotel already has (e.g. upgrading 50 -> 100 tags
// allocates #51-100, doesn't touch the existing ones).
qrCodeRouter.post(
  "/hotels/:hotelId/qrcodes",
  asyncHandler(async (req, res) => {
    const { hotelId } = req.params;
    const { count } = req.body ?? {};
    const quantity = Number(count);
    if (!Number.isInteger(quantity) || quantity <= 0 || quantity > 500) {
      return res.status(400).json({ error: "count must be an integer between 1 and 500" });
    }

    const hotel = await prisma.hotel.findUnique({ where: { id: hotelId } });
    if (!hotel) return res.status(404).json({ error: "hotel not found" });

    const created = await prisma.$transaction(async (tx) => {
      const current = await tx.qRCode.aggregate({
        where: { hotelId },
        _max: { hotelLocalNumber: true },
      });
      const startNumber = (current._max.hotelLocalNumber ?? 0) + 1;

      const rows = Array.from({ length: quantity }, (_, i) => ({
        code: generateQrCode(),
        hotelId,
        hotelLocalNumber: startNumber + i,
        status: "ASSIGNED_FREE",
      }));

      await tx.qRCode.createMany({ data: rows });
      return tx.qRCode.findMany({
        where: { hotelId, hotelLocalNumber: { gte: startNumber } },
        orderBy: { hotelLocalNumber: "asc" },
      });
    });

    res.status(201).json(created);
  })
);

qrCodeRouter.get(
  "/hotels/:hotelId/qrcodes",
  asyncHandler(async (req, res) => {
    const { hotelId } = req.params;
    const qrCodes = await prisma.qRCode.findMany({
      where: { hotelId },
      orderBy: { hotelLocalNumber: "asc" },
    });
    res.json(qrCodes);
  })
);

// Lost/damaged tag handling: take a free tag out of circulation, or bring a
// disabled one back. Can't touch a tag that's currently locked to an open
// ticket - that has to complete (or you fix it by hand) first.
qrCodeRouter.patch(
  "/qrcodes/:id/status",
  asyncHandler(async (req, res) => {
    const { status } = req.body ?? {};
    if (status !== "ASSIGNED_FREE" && status !== "DISABLED") {
      return res.status(400).json({ error: "status must be ASSIGNED_FREE or DISABLED" });
    }

    const qr = await prisma.qRCode.findUnique({ where: { id: req.params.id } });
    if (!qr) return res.status(404).json({ error: "qr code not found" });
    if (qr.status === "ASSIGNED_LOCKED") {
      return res.status(409).json({ error: "tag is currently locked to an open ticket" });
    }

    const updated = await prisma.qRCode.update({ where: { id: qr.id }, data: { status } });
    res.json(updated);
  })
);

// Audit trail of scans/messages that didn't match a valid, free QR code.
qrCodeRouter.get(
  "/logs/invalid",
  asyncHandler(async (_req, res) => {
    const logs = await prisma.invalidScanLog.findMany({
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    res.json(logs);
  })
);

// Printable QR image for one tag - encodes the short redirect link, not the
// wa.me link directly, so the message/logic can change later without
// reprinting tags.
qrCodeRouter.get(
  "/qrcodes/:id/image",
  asyncHandler(async (req, res) => {
    const qr = await prisma.qRCode.findUnique({ where: { id: req.params.id } });
    if (!qr) return res.status(404).json({ error: "qr code not found" });

    const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
    const redirectUrl = `${baseUrl}/q/${qr.code}`;

    const png = await QRCode.toBuffer(redirectUrl, { type: "png", width: 400 });
    res.setHeader("Content-Type", "image/png");
    res.send(png);
  })
);
