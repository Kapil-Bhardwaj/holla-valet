import { prisma } from "../db/prisma";
import { sendText } from "../whatsapp/client";

type CheckInResult =
  | { ok: true; ticketId: string; hotelName: string }
  | { ok: false; reason: "code_not_found" | "code_locked" | "race_condition" };

// Creates a Ticket for a valid, currently-free QR code. Locks the QR so it
// can't be used to check in a second car until this ticket completes.
// Atomic: uses a conditional update (status must still be ASSIGNED_FREE at
// write time) so two near-simultaneous scans on the same tag can't both win.
export async function checkInTicket(code: string, customerPhone: string): Promise<CheckInResult> {
  return prisma.$transaction(async (tx) => {
    const qr = await tx.qRCode.findUnique({ where: { code }, include: { hotel: true } });

    if (!qr) {
      await tx.invalidScanLog.create({
        data: { rawCode: code, reason: "code_not_found", source: "whatsapp_webhook" },
      });
      return { ok: false, reason: "code_not_found" };
    }

    if (qr.status !== "ASSIGNED_FREE") {
      await tx.invalidScanLog.create({
        data: { rawCode: code, reason: "code_locked", source: "whatsapp_webhook" },
      });
      return { ok: false, reason: "code_locked" };
    }

    const lockResult = await tx.qRCode.updateMany({
      where: { id: qr.id, status: "ASSIGNED_FREE" },
      data: { status: "ASSIGNED_LOCKED" },
    });
    if (lockResult.count !== 1) {
      return { ok: false, reason: "race_condition" };
    }

    const ticket = await tx.ticket.create({
      data: { qrCodeId: qr.id, customerPhone, status: "CHECKED_IN" },
    });

    return { ok: true, ticketId: ticket.id, hotelName: qr.hotel.name };
  });
}

// Called when the customer taps "Get my car". Matches by phone number to
// their currently open ticket - known MVP limitation: assumes one active
// ticket per phone number platform-wide at a time.
export async function requestCar(customerPhone: string): Promise<{ ok: boolean }> {
  const ticket = await prisma.ticket.findFirst({
    where: { customerPhone, status: "CHECKED_IN" },
    orderBy: { checkedInAt: "desc" },
  });
  if (!ticket) return { ok: false };

  await prisma.ticket.update({
    where: { id: ticket.id },
    data: { status: "REQUESTED", requestedAt: new Date() },
  });
  return { ok: true };
}

// Called when the manager clicks "Car Arrived". Closes the ticket, frees the
// QR tag immediately, and notifies the customer.
export async function markArrived(ticketId: string, hotelId: string): Promise<{ ok: boolean; error?: string }> {
  const ticket = await prisma.ticket.findUnique({
    where: { id: ticketId },
    include: { qrCode: true },
  });

  if (!ticket || ticket.qrCode.hotelId !== hotelId) {
    return { ok: false, error: "ticket not found for this hotel" };
  }
  if (ticket.status === "COMPLETED") {
    return { ok: false, error: "ticket already completed" };
  }

  await prisma.$transaction([
    prisma.ticket.update({
      where: { id: ticket.id },
      data: { status: "COMPLETED", completedAt: new Date() },
    }),
    prisma.qRCode.update({
      where: { id: ticket.qrCodeId },
      data: { status: "ASSIGNED_FREE" },
    }),
  ]);

  await sendText(ticket.customerPhone, "Your car has arrived! Please come to the entrance.");
  return { ok: true };
}
