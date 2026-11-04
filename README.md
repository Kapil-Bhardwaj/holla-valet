# Holla Valet

WhatsApp-based valet ticketing for hotels, pubs, clubs etc.

- The **customer** only ever uses WhatsApp — no app install.
- The **valet runner** carries no app/login at all — purely physical, directed
  verbally by the person running the dashboard.
- The **valet manager** runs a live dashboard per hotel (web today, can become
  a native app later without a rewrite).
- **You (platform admin)** manage vendors, hotels, and QR code allocation from
  a separate admin panel.

## How a visit works

1. Customer hands car to the runner.
2. Runner shows a keychain QR tag (doesn't hand it over), customer scans it.
3. Scan redirects to WhatsApp with a pre-filled message containing the tag's
   code → customer sends it → a **Ticket** is created, status `CHECKED_IN`.
4. Runner parks the car, returns the physical tag to the podium — it's
   immediately reusable, since from here the customer is tracked by their
   WhatsApp number, not the physical tag.
5. Later, customer taps "Get my car" in WhatsApp → ticket moves to
   `REQUESTED` → manager's dashboard alerts (sound + visual).
6. Manager tells the runner which car, by its tag number.
7. Runner brings the car up. Manager clicks **"Car Arrived"** → ticket closes
   (`COMPLETED`), the tag frees up for reuse, and WhatsApp auto-sends "your
   car has arrived" to the customer.

## Tech stack

| Layer | Choice | Why |
|---|---|---|
| Backend | Node.js + Express + TypeScript | Simple to read and extend, no heavy framework ceremony |
| Database | SQLite via Prisma | One file, no DB server to run; Prisma gives a readable schema + a GUI (`npx prisma studio`) to browse data without knowing SQL; swapping to Postgres later is a config change, not a rewrite |
| Frontend (both apps) | Flutter (web now, Android/iOS later from the same code) | Needed because the manager dashboard may become a real mobile app later for push alerts; one codebase covers both |
| Messaging | WhatsApp Cloud API (Meta), single shared number for the whole platform | Free at this scale, official, no per-hotel number needed since the tag code already identifies the hotel |
| Hosting | One EC2 instance, Docker, nginx + Let's Encrypt | Matches your "EC2 only" call; cheapest and simplest to reason about at this scale |

## Folders

- `backend/` — the API: vendors, hotels, QR allocation + redirect, ticket
  state machine, WhatsApp webhook, login.
- `frontend-admin/` — Flutter app for you: add vendors/hotels, assign QR
  batches, export printable tags, view invalid-scan logs.
- `frontend-hola-hotel/` — Flutter app for a hotel's valet manager: live
  ticket board, "Car Arrived" button, this hotel's QR inventory.

## Data model

```
Vendor -> Hotel -> QRCode (permanent, reusable) -> Ticket (one per car visit)
                 -> ManagerUser (login scoped to this hotel)
AdminUser (your login, not tied to a hotel)
InvalidScanLog (unknown/locked QR codes - never becomes a Ticket)
```

QR status: `ASSIGNED_FREE → ASSIGNED_LOCKED → ASSIGNED_FREE` (frees the
instant a ticket completes, never deleted, "permanent" per hotel).

Ticket status: `CHECKED_IN → REQUESTED → COMPLETED`.

## Build stages

### Stage 1 — Application ✅ done

- [x] Backend: all routes (auth, vendors, hotels, QR allocation + redirect,
      ticket state machine, WhatsApp webhook)
- [x] Robustness: startup config validation, async errors can't crash the
      process, WhatsApp webhook signature verification, retry-safe webhook
      dedup (by WhatsApp's message id)
- [x] Admin app (Flutter): login, vendors, hotels, manager logins + password
      reset, QR batch assignment, printable QR export, disable/re-enable a
      lost tag, invalid-scan audit log
- [x] Valet manager app (Flutter): login, live board (Checked In / Requested
      with alert / recently completed), "Car Arrived" action, QR inventory
- [x] Sessions persist across a page refresh (7-day token, stored locally)
- [x] Verified end to end locally: admin → vendor → hotel → manager → QR
      batch → scan redirect → simulated WhatsApp check-in → "Get my car" →
      "Car Arrived" → tag frees up again
- [ ] Self-service password reset (currently admin resets it by hand - no
      email/SMS sending wired up, intentionally out of scope for MVP)

### Stage 2 — Account creation ⏳ in progress

- [ ] AWS account (MFA, IAM user, budget alert)
- [ ] Domain name purchase
- [ ] Meta Developer account + Business + App + WhatsApp product (WABA)
- [ ] Permanent system-user access token
- [ ] Test phone number added as a verified recipient
- [ ] `backend/.env` filled in with real WhatsApp credentials
- [ ] Business Verification started (lifts the 5-test-number cap) - real
      lead time, start as early as possible in this stage
- [ ] Display name review

### Stage 3 — Deployment + testing ⏳ pending

- [ ] EC2 instance + security group (only 443/80 public, SSH locked to one IP)
- [ ] Docker + nginx + Let's Encrypt TLS
- [ ] Domain pointed at the instance
- [ ] WhatsApp webhook switched from the dev ngrok URL to the production URL
- [ ] Real QR tags printed and laminated
- [ ] Full real-world check-in/request/arrival cycle run before handing off
      to hotel staff

## Quick start (local dev)

```bash
# Backend
cd backend
cp .env.example .env        # fill in JWT_SECRET, ADMIN_EMAIL/PASSWORD at minimum
npm install
npx prisma migrate deploy
npm run seed                # creates your one admin login
npm run dev                 # http://localhost:3000

# Admin app
cd frontend-admin
flutter pub get
flutter run -d chrome

# Valet manager app
cd frontend-hola-hotel
flutter pub get
flutter run -d chrome
```

To test real WhatsApp messages locally (Stage 2 credentials required):
`ngrok http 3000`, then register `<ngrok-url>/webhook/whatsapp` as the
webhook callback in Meta's app settings.

## Costs (rough, checked against current pricing)

- EC2 t3.small, 24/7: ~$15-17/month
- EBS disk: ~$2-3/month
- Domain: ~$10-12/year
- WhatsApp: first 1,000 service replies/month free per number — expect $0-5/month at single-hotel pilot scale
