-- CreateTable
CREATE TABLE "ProcessedWebhookMessage" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "processedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
