import { Router } from "express";
import { prisma } from "../db/prisma";
import { requireAdmin } from "../auth/middleware";
import { asyncHandler } from "../asyncHandler";

export const vendorRouter = Router();
vendorRouter.use(requireAdmin);

vendorRouter.post(
  "/",
  asyncHandler(async (req, res) => {
    const { name } = req.body ?? {};
    if (!name) return res.status(400).json({ error: "name is required" });

    const vendor = await prisma.vendor.create({ data: { name } });
    res.status(201).json(vendor);
  })
);

vendorRouter.get(
  "/",
  asyncHandler(async (_req, res) => {
    const vendors = await prisma.vendor.findMany({
      include: { hotels: { select: { id: true, name: true } } },
      orderBy: { createdAt: "desc" },
    });
    res.json(vendors);
  })
);
