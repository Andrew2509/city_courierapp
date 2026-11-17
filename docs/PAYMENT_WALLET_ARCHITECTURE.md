# City Courier — Payment & Wallet System Architecture & Audit Report

**Date:** 2026-11-17  
**Target Projects:**
- **Project A (Backend & Admin Web):** `C:\laragon\www\City-Courier-web` (Laravel `^13.0`, PHP `8.3.12`, MySQL 8 / SQLite for testing, Sanctum `^4.3`, Spatie Permission `^7.3`)
- **Project B (Flutter Mobile App):** `F:\DariNoStudio\city_courierapp` (Flutter `3.41.7`, Dart `3.11.5`, Provider `^6.1.1`)

---

## 1. Pre-Implementation Audit Report

### 1.1 Existing Backend Architecture (`City-Courier-web`)
- **Framework & Auth:** Laravel 13 with Sanctum token auth (`auth:sanctum`) for mobile REST endpoints and session auth + `CheckMenuPermission` (`menu.permission`) + Spatie roles (`super-admin`, `admin`, `operator`, `viewer`, `courier`, `customer`) for the Admin panel.
- **Database & Queue:** `.env` uses MySQL (`city-courier-web`) and `QUEUE_CONNECTION=database` (tables `jobs`, `job_batches`, `failed_jobs` already exist). Test suite in `phpunit.xml` uses SQLite `:memory:` (98 existing payment/wallet/auth tests pass; 3 legacy tests hardcode `mysql` directly).
- **Existing Payment & Wallet Modules:**
  1. `wallets` & `wallet_transactions`: Courier-only (`courier_id` NOT NULL, unique FK to `couriers`), single-entry transactions, `decimal(15,2)` amounts. No customer wallet support, no double-entry ledger, no `reserved_balance` column (uses `pending_balance` to hold funds), no freeze controls.
  2. `withdrawals` & `WithdrawalService` / `WithdrawalController`: Handles manual courier withdrawals to DANA via iPaymu (`POST /api/courier/withdrawals`), with row locking (`lockForUpdate`), idempotency key, reserve/confirm/release pattern, rate limiting, and `status_history`.
  3. `payments` & `IpaymuPaymentService` / `PaymentController` / `iPaymuWebhookController` / `PaymentCancellationService`: Handles checkout order payments via iPaymu API v2 (VA, QRIS, Redirect fallback) and legacy Komerce callback.
  4. `dana_connections` & `ovo_connections`: Legacy courier e-wallet binding tables/controllers (`DanaController`, `OvoController`).
  5. **Admin Panel:** Blade + Tailwind CSS (`resources/views/layouts/admin.blade.php`), `config/admin_menus.php`, `CiWorkController::finance` (`admin/ci-work/finance.blade.php`), `SettingController::providers` (`admin/settings/providers.blade.php`).

### 1.2 Existing Flutter Architecture (`city_courierapp`)
- **State & Navigation:** Uses `Provider` (`MultiProvider` in `lib/main.dart`) + `StatefulWidget` (`setState`) + `Navigator` (`MaterialPageRoute`) with `RouteObserver` (GetX is **not** installed).
- **Design System:** Orange primary (`#EC5B13` / `#FA880F` / `#FF5A00`), dark navy/slate (`#0F172A` / `#111827`), blue accent (`#0095FC` / `#2196F3`), surface background (`#F8FAFC`).
- **Existing Payment & Wallet Screens:**
  - Customer Checkout: `PaymentMethodScreen`, `VirtualAccountConfirmationScreen`, `EWalletConfirmationScreen`, `HostedPaymentScreen`, `DirectPaymentConfirmationScreen`, `UnpaidListScreen`.
  - Courier Wallet: `DompetScreen` (`DriverEarningsScreen` redirects here), `TarikDanaScreen`, `RiwayatTransaksiScreen`, `StatusPenarikanScreen`, `TransactionDetailScreen`.
- **Test Status:** `flutter test` passes all 183 existing tests; `flutter analyze` has 0 errors/warnings.

### 1.3 Critical Gaps & Potential Conflicts Identified
1. **Courier Earnings Never Credited Automatically:** `WalletService::credit()` / `WalletController::addEarning()` are never called in `OrderController::updateStatus()` when an order becomes `delivered`. `CourierController::stats()` and `earnings()` compute earnings ad-hoc from `orders.price * 0.9` while `WalletService` reads `wallets.available_balance`.
2. **No Customer Wallet & Wallet Checkout:** Customers have no wallet balance, no top-up flow, no wallet payment option in `PaymentMethodScreen`, no refund management, and no withdrawal destination/request screens.
3. **No Double-Entry Ledger or BIGINT IDR:** Existing `wallets` and `wallet_transactions` use `decimal(15,2)` single-entry records without a balanced double-entry `wallet_ledger_entries` source of truth.
4. **No Automatic Courier Payout Pipeline:** No `courier_earnings` settlement waiting period (`pending` -> `available`), no `payout_destinations` table for bank/e-wallet destinations, and no scheduled/queued automatic payout jobs (`PayoutProcessingJob`, `PayoutStatusCheckJob`, `ReconciliationJob`).
5. **No Xendit / DOKU Provider Adapters or Mode Isolation:** Only iPaymu & legacy DANA/OVO providers exist. There is no unified `PaymentProviderInterface` / `PayoutProviderInterface` supporting `Xendit` (v3 Payment Requests & v2 Payouts), `DOKU` (Jokul HMAC adapter), and `MockPaymentProvider` with strict `DEMO` / `SANDBOX` / `PRODUCTION` isolation.
6. **Backward Compatibility Risk:** Existing PHPUnit tests (`WalletHistoryTest`, `DanaWithdrawalTest`, `IpaymuCheckoutPaymentTest`, `PaymentCancellationTest`, `DanaContractTest`) construct minimal SQLite tables manually without running migrations and expect legacy `/api/courier/*` and `/api/payment/*` routes to keep their exact response shapes.
   - **Resolution:** Preserve all existing routes, services, and table contracts; use additive non-destructive migrations; implement new modules cleanly under `app/Modules/*` with safe schema checks when legacy `WalletService` bridges into the new ledger.

### 1.4 Existing Reusable Components
- **Backend:** `Setting::get/set`, `CheckMenuPermission`, `layouts/admin.blade.php` Tailwind component classes (`.card`, `.data-table`, `.badge`, `.btn`, `.modal-backdrop`, `.filter-tabs`), `iPaymuService` / `IpaymuPaymentService`, `WithdrawalService::normalizePhoneNumber` & `maskPhone`, `Order::price`, `Shipment`, `Courier`, `User`.
- **Flutter:** `ApiService.baseUrl`, `TokenStore`, `AuthGuard`, `AppColors`, `AppTypography`, `currency_format.dart` (`formatRupiah`), `PaymentBrandLogo`, `WalletHistoryTile`, `WalletNotificationsSheet`, `DriverBottomNavigation`, `BottomNavBar`.

---

## 2. Target Modular Architecture

```
app/Modules/
├── Wallet/
│   ├── Models/ (WalletBalance, WalletAuditLog, PayoutDestination)
│   └── Services/ (WalletLedgerManager, WalletFreezeService)
├── Ledger/
│   ├── Models/ (WalletLedgerEntry)
│   └── Services/ (DoubleEntryLedgerService, LedgerReconciliationService)
├── Payment/
│   ├── Contracts/ (PaymentProviderInterface, PayoutProviderInterface)
│   ├── Models/ (PaymentTransaction, PaymentWebhook, PaymentProviderConfig)
│   ├── Providers/ (MockPaymentProvider, XenditPaymentProvider, XenditPayoutProvider, DokuPaymentProvider, ProviderResolver)
│   ├── Services/ (OrderWalletPaymentService, WebhookProcessorService)
│   └── Jobs/ (PaymentWebhookJob, ReconciliationJob)
├── TopUp/
│   ├── Models/ (TopupTransaction)
│   └── Services/ (TopupService)
├── Earnings/
│   ├── Models/ (CourierEarning)
│   ├── Services/ (CourierEarningService)
│   └── Jobs/ (CourierEarningJob)
├── Payout/
│   ├── Models/ (PayoutTransaction)
│   ├── Services/ (PayoutService, DestinationService)
│   └── Jobs/ (PayoutProcessingJob, PayoutStatusCheckJob)
├── Refund/
│   ├── Models/ (RefundTransaction)
│   └── Services/ (RefundService)
└── FinancialReports/
    └── Services/ (AdminFinanceDashboardService, FinancialReportExportService)
```

---

## 3. Environment Modes & Regulatory Compliance

City Courier is currently in the business planning stage without a registered legal entity or approved stored-value/e-money license. Therefore:

1. **Three Explicit Modes (`demo`, `sandbox`, `production`):**
   - `demo`: Uses `MockPaymentProvider`; simulated confirmations allowed strictly for UI/UX testing; clearly badged `DEMO / SIMULASI`.
   - `sandbox`: Uses provider sandbox endpoints (Xendit test keys / iPaymu sandbox) or `MockPaymentProvider` when provider keys are absent; records tagged `mode = sandbox`.
   - `production`: Uses live provider endpoints ONLY; `MockPaymentProvider` throws an exception if invoked; simulated top-up confirmation endpoints return `403 Forbidden`.
2. **Customer Wallet Withdrawal Regulatory Guard:**
   - Stored-value cash-out (customer wallet withdrawal) is **hard-blocked in `production`** (`CUSTOMER_WITHDRAWAL_DISABLED_IN_PRODUCTION`, HTTP `403`) unless explicit regulatory/provider approval flag (`CUSTOMER_WITHDRAWAL_REGULATORY_APPROVED=true`) is enabled.
   - All customer withdrawal service interfaces, validation, destination management, and ledger mechanics remain testable in `demo` and `sandbox` modes.
3. **Courier Payout Flow (Queued & Scheduled):**
   - Order `delivered` -> `CourierEarningJob` -> `courier_earnings` (`pending`, credits `WALLET_PENDING`) -> configurable settlement/dispute delay -> released to `available` (`WALLET_AVAILABLE`) -> scheduler checks verified default `payout_destination` & `minimum_payout` -> reserves funds (`WALLET_AVAILABLE` -> `WALLET_RESERVED`) -> dispatches `PayoutProcessingJob` -> calls provider with `Idempotency-key` -> confirms via webhook or `PayoutStatusCheckJob` -> finalizes ledger or releases reserved funds on confirmed failure -> notifies courier.
