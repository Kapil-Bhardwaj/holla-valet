// Fails fast and clearly at startup if required config is missing, instead
// of the server booting fine and then crashing on the first request that
// happens to need the missing value (which is what happened with JWT_SECRET
// before this existed - the process died on the first login attempt).
const REQUIRED = ["JWT_SECRET", "DATABASE_URL"] as const;

export function assertRequiredEnvVars(): void {
  const missing = REQUIRED.filter((key) => !process.env[key]);
  if (missing.length > 0) {
    console.error(
      `Missing required environment variable(s): ${missing.join(", ")}\n` +
        `Check backend/.env against backend/.env.example.`
    );
    process.exit(1);
  }
}
