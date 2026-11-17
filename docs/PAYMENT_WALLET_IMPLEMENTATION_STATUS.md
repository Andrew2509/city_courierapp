# City Courier — Payment & Wallet Implementation Status

**Last Updated:** 2026-11-17

| Area | Classification | Verification & Notes |
|---|---|---|
| Project Audit & Documentation | COMPLETED | Full inspection across `C:\laragon\www\City-Courier-web` & `F:\DariNoStudio\city_courierapp`; docs mirrored in both repos |
| Database Schema & Migrations | COMPLETED | 13 SQLite + MySQL compatible migrations (`2026_11_17_000001..000013`) using `BIGINT` IDR; verified via `PaymentWalletMigrationTest` |
| Double-Entry Ledger & Freeze Engine | COMPLETED | `DoubleEntryLedgerService`, `WalletLedgerManager`, `WalletFreezeService`, `LedgerReconciliationService` (`lockForUpdate`, immutable ledger, `dedupe_key`) |
| Provider Adapter Architecture (Mock, Xendit, DOKU) | COMPLETED / SANDBOX ONLY | `MockPaymentProvider` (blocked in `production`), `XenditPaymentProvider` (v3), `XenditPayoutProvider` (v2 + `Idempotency-key`), `DokuPaymentProvider` (Jokul HMAC) |
| Live Real-Money Merchant Credentials | BLOCKED BY BUSINESS APPROVAL & PROVIDER | Waiting legal entity registration, Xendit/DOKU live KYB/merchant keys, and regulatory approval |
| Customer Wallet Top-Up, Checkout & Refund APIs | COMPLETED | `/api/v1/customer/wallet/*` (Sanctum auth, ownership checks, idempotency, frozen wallet guard, webhook verification) |
| Customer Stored-Value Withdrawal | SANDBOX ONLY / BLOCKED BY BUSINESS APPROVAL | Hard-blocked in `production` (`403 CUSTOMER_WITHDRAWAL_DISABLED_IN_PRODUCTION`) until regulatory/provider approval; testable in `demo`/`sandbox` |
| Courier Automatic Earnings, Settlement & Auto-Payout | COMPLETED | `OrderController` -> `CourierEarningJob` -> `pending` -> settlement waiting -> `available` -> hourly `RunAutoPayoutsCommand` -> `PayoutProcessingJob` / `PayoutStatusCheckJob` |
| Admin Finance Web Panel | COMPLETED | 13 Blade views under `/admin/finance/*` with Spatie permissions (`CheckMenuPermission`), freeze/unfreeze, settings, CSV exports, reconciliation |
| Flutter Customer Wallet & Checkout UI | COMPLETED | `CustomerWalletService`, `PaymentMethodScreen` wallet option, `CustomerWalletDashboardScreen`, Top-Up flow, Withdrawals, Refunds, Destinations |
| Flutter Courier Wallet & Auto-Payout UI | COMPLETED | `CourierWalletV1Service`, upgraded `DompetScreen` + Earnings Overview, Pending/Available Earnings, Destinations (Bank/E-Wallet), Auto-Payout Status, Payout History/Detail |
| Automated Verification (Laravel & Flutter) | COMPLETED | Laravel SQLite suite: **109 passed (646 assertions)** (`PaymentWalletMigrationTest`, `WalletLedgerCoreTest`, `PaymentWalletSystemV1Test`, `AdminFinanceTest` + 98 baseline tests). Flutter: **`flutter analyze --no-fatal-infos` exited 0 (0 errors, 0 warnings in new files)** & **`flutter test` exited 0 (191 passed)** |

> **Environment Note:** Local Laragon MySQL (`127.0.0.1:3306`) is stopped in this workstation environment, so Artisan migration/test runs against live MySQL (`migrate`, legacy MySQL-only `CourierCancelAssignmentTest`, `CourierRejectOrderTest`, `ScheduledPickupCancellationTest`) could not be executed against MySQL and were verified instead against SQLite `:memory:`.
