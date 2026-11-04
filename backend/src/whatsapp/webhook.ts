import { createHmac, timingSafeEqual } from "crypto";
import { Router } from "express";
import { Prisma } from "@prisma/client";
import { prisma } from "../db/prisma";
import { checkInTicket, requestCar } from "../tickets/service";
import { sendCheckInMenu } from "./client";
import { asyncHandler } from "../asyncHandler";

export const whatsappWebhookRouter = Router();

// Meta's one-time handshake when you register the webhook URL.
whatsappWebhookRouter.get("/", (req, res) => {
  const mode = req.query["hub.mode"];
  const token = req.query["hub.verify_token"];
  const challenge = req.query["hub.challenge"];

  if (mode === "subscribe" && token === process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN) {
    return res.status(200).send(challenge);
  }
  return res.status(403).send("verification failed");
});

// Verifies the request actually came from Meta, not a spoofed caller.
// Fails closed: with no app secret configured, every request is rejected
// unless WHATSAPP_SKIP_SIGNATURE_VERIFICATION=true is explicitly set, which
// is for local/dev testing only and must never be set in production.
function isSignatureValid(rawBody: Buffer | undefined, signatureHeader: string | undefined): boolean {
  if (process.env.WHATSAPP_SKIP_SIGNATURE_VERIFICATION === "true") {
    console.warn("[whatsapp:dev] signature verification bypassed - do not use in production");
    return true;
  }

  const appSecret = process.env.WHATSAPP_APP_SECRET;
  if (!appSecret || !rawBody || !signatureHeader?.startsWith("sha256=")) {
    return false;
  }

  const expected = createHmac("sha256", appSecret).update(rawBody).digest("hex");
  const provided = signatureHeader.slice("sha256=".length);

  const expectedBuf = Buffer.from(expected, "hex");
  const providedBuf = Buffer.from(provided, "hex");
  if (expectedBuf.length !== providedBuf.length) return false;
  return timingSafeEqual(expectedBuf, providedBuf);
}

const CODE_PATTERN = /REF:([A-Za-z0-9_-]+)/;

whatsappWebhookRouter.post(
  "/",
  asyncHandler(async (req, res) => {
    const rawBody = (req as unknown as { rawBody?: Buffer }).rawBody;
    if (!isSignatureValid(rawBody, req.header("x-hub-signature-256"))) {
      return res.status(401).send("invalid signature");
    }

    // Always acknowledge quickly - Meta retries if it doesn't get a fast 200.
    res.sendStatus(200);

    const entries = req.body?.entry ?? [];
    for (const entry of entries) {
      for (const change of entry.changes ?? []) {
        const messages = change.value?.messages ?? [];
        for (const message of messages) {
          // Caught per-message so one malformed message can't stop the rest
          // of the batch from being processed, and can't crash the process.
          try {
            if (await alreadyProcessed(message.id)) continue;
            await handleInboundMessage(message);
          } catch (err) {
            console.error("[whatsapp] failed to process inbound message:", err);
          }
        }
      }
    }
  })
);

// WhatsApp retries a webhook delivery it didn't get a fast-enough 200 for,
// so the same message can arrive twice. Claims the message id (wamid)
// atomically via the unique constraint - if another delivery already
// claimed it, this throws P2002 and we skip reprocessing it.
async function alreadyProcessed(messageId: string | undefined): Promise<boolean> {
  if (!messageId) return false; // no id to dedupe on - process it, can't do better
  try {
    await prisma.processedWebhookMessage.create({ data: { id: messageId } });
    return false;
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
      return true;
    }
    throw err;
  }
}

async function handleInboundMessage(message: any): Promise<void> {
  const fromPhone: string | undefined = message.from;
  if (!fromPhone) return;

  const buttonId = message.interactive?.button_reply?.id;
  if (message.type === "interactive" && buttonId === "GET_CAR") {
    await requestCar(fromPhone);
    return;
  }

  if (message.type === "text") {
    const text: string = message.text?.body ?? "";
    const match = text.match(CODE_PATTERN);
    if (!match) return; // not a check-in message and not a recognised button - drop it

    const result = await checkInTicket(match[1], fromPhone);
    if (result.ok) {
      await sendCheckInMenu(fromPhone, result.hotelName);
    }
    // Invalid codes are logged inside checkInTicket and dropped here,
    // per the "wrong transaction" requirement - no reply sent.
  }
}
