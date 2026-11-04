// Thin wrapper around Meta's WhatsApp Cloud API for outbound messages.
// If credentials aren't configured yet (local dev before Stage 2), this
// logs instead of throwing, so the rest of the app keeps working.

const GRAPH_BASE = "https://graph.facebook.com/v20.0";

function isConfigured(): boolean {
  return Boolean(process.env.WHATSAPP_ACCESS_TOKEN && process.env.WHATSAPP_PHONE_NUMBER_ID);
}

async function callGraphApi(body: unknown): Promise<void> {
  if (!isConfigured()) {
    console.log("[whatsapp:dev] WHATSAPP_ACCESS_TOKEN/PHONE_NUMBER_ID not set, skipping send:", body);
    return;
  }

  const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
  const url = `${GRAPH_BASE}/${phoneNumberId}/messages`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${process.env.WHATSAPP_ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    console.error("[whatsapp] send failed:", response.status, text);
  }
}

export async function sendText(toPhone: string, body: string): Promise<void> {
  await callGraphApi({
    messaging_product: "whatsapp",
    to: toPhone,
    type: "text",
    text: { body },
  });
}

// Sends the post-check-in menu as tappable buttons, rather than relying on
// the customer typing free text - much more reliable to parse on the way back in.
export async function sendCheckInMenu(toPhone: string, hotelName: string): Promise<void> {
  await callGraphApi({
    messaging_product: "whatsapp",
    to: toPhone,
    type: "interactive",
    interactive: {
      type: "button",
      body: { text: `Welcome to ${hotelName}! Your car is checked in.` },
      action: {
        buttons: [
          { type: "reply", reply: { id: "GET_CAR", title: "Get my car" } },
        ],
      },
    },
  });
}
