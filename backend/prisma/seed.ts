import "dotenv/config";
import { prisma } from "../src/db/prisma";
import { hashPassword } from "../src/auth/password";

// Idempotent: safe to run more than once. Creates (or leaves alone) your one
// admin login, from ADMIN_EMAIL/ADMIN_PASSWORD in .env. There's no public
// admin signup on purpose - this is the only way an AdminUser gets created.
async function main() {
  const email = process.env.ADMIN_EMAIL;
  const password = process.env.ADMIN_PASSWORD;
  if (!email || !password) {
    throw new Error("Set ADMIN_EMAIL and ADMIN_PASSWORD in .env before seeding");
  }

  const existing = await prisma.adminUser.findUnique({ where: { email } });
  if (existing) {
    console.log(`Admin user ${email} already exists, leaving it as-is.`);
    return;
  }

  await prisma.adminUser.create({
    data: { email, passwordHash: hashPassword(password) },
  });
  console.log(`Created admin user ${email}`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
