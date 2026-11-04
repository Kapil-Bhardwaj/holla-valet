import { Router } from "express";
import { prisma } from "../db/prisma";
import { asyncHandler } from "../asyncHandler";

export const qrRedirectRouter = Router();

// Public, anonymous by design - this is what the printed QR tag points to.
// Customers scanning it have no login and shouldn't need one.
qrRedirectRouter.get("/:code", asyncHandler(async (req, res) => {
  const { code } = req.params;

  const qr = await prisma.qRCode.findUnique({ where: { code }, include: { hotel: true } });
  if (!qr) {
    await prisma.invalidScanLog.create({
      data: { rawCode: code, reason: "code_not_found", source: "qr_redirect" },
    });
    return res
      .status(404)
      .send("<h1>Invalid tag</h1><p>Please ask the valet staff for help.</p>");
  }

  const whatsappNumber = process.env.WHATSAPP_DISPLAY_NUMBER;
  if (!whatsappNumber) {
    return res.status(500).send("WhatsApp number is not configured yet.");
  }

  const message =
    `Hi, I'm checking in a car at ${qr.hotel.name} ` +
    `(Tag #${qr.hotelLocalNumber}). REF:${qr.code}`;

  const waUrl = `https://wa.me/${whatsappNumber}?text=${encodeURIComponent(message)}`;
  res.redirect(302, waUrl);
}));
