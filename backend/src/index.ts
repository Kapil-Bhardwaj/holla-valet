import "dotenv/config";
import cors from "cors";
import express from "express";
import type { NextFunction, Request, Response } from "express";
import { assertRequiredEnvVars } from "./env";
import { authRouter } from "./auth/routes";
import { vendorRouter } from "./vendors/routes";
import { hotelRouter } from "./hotels/routes";
import { qrCodeRouter } from "./qrcodes/routes";
import { qrRedirectRouter } from "./qrcodes/redirect";
import { managerTicketRouter } from "./tickets/routes";
import { whatsappWebhookRouter } from "./whatsapp/webhook";

assertRequiredEnvVars();

const app = express();

// FRONTEND_ORIGINS: comma-separated list of allowed origins for the Flutter
// web apps (e.g. "http://localhost:5000,https://admin.holla-valet.com").
// Every protected route still requires a bearer token the browser doesn't
// auto-attach, so a permissive dev default here isn't a login bypass - but
// set this explicitly once deployed (Stage 3) rather than leaving it open.
const allowedOrigins = process.env.FRONTEND_ORIGINS?.split(",").map((o) => o.trim());
app.use(
  cors({
    origin: allowedOrigins ?? true,
  })
);

// Captures the raw request body so the WhatsApp webhook can verify Meta's
// HMAC signature against the exact bytes received, before JSON-parsing it.
app.use(
  express.json({
    verify: (req, _res, buf) => {
      (req as unknown as { rawBody?: Buffer }).rawBody = buf;
    },
  })
);

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/auth", authRouter);
app.use("/admin/vendors", vendorRouter);
app.use("/admin/hotels", hotelRouter);
app.use("/admin", qrCodeRouter); // mounts /admin/hotels/:hotelId/qrcodes, /admin/qrcodes/:id/image, /admin/logs/invalid
app.use("/q", qrRedirectRouter); // public - what the printed QR tags point to
app.use("/manager", managerTicketRouter);
app.use("/webhook/whatsapp", whatsappWebhookRouter); // public - signature-verified instead of logged in

// Catches anything that reaches here (via asyncHandler's .catch(next), or a
// synchronous throw) and returns a 500 instead of letting the process crash.
// Must be registered after all routes.
app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  console.error("[unhandled request error]", err);
  if (res.headersSent) return;
  res.status(500).json({ error: "internal server error" });
});

const port = process.env.PORT ?? 3000;
app.listen(port, () => {
  console.log(`Holla backend listening on port ${port}`);
});

// Last-resort safety net - logs instead of letting Node kill the whole
// process over something outside Express's request/response cycle
// (e.g. a stray rejected promise in a background task).
process.on("unhandledRejection", (reason) => {
  console.error("[unhandled rejection]", reason);
});
