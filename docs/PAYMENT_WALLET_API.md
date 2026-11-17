# City Courier — Payment & Wallet API v1 Contract

**Base URL:** `/api/v1`  
**Authentication:** Laravel Sanctum Bearer Token (`Authorization: Bearer <token>`) for all customer and courier routes.  
**Currency:** `IDR` (all monetary values are integer Rupiah / `BIGINT`).  
**Idempotency:** Mutating endpoints accept `Idempotency-Key` header or `idempotency_key` body field. Replaying the same key returns the existing transaction without duplicating ledger mutations.

---

## Standard Response Envelope

### Success
```json
{
  "success": true,
  "message": "Wallet retrieved successfully",
  "data": { }
}
```

### Validation / Business Error
```json
{
  "success": false,
  "error_code": "INSUFFICIENT_BALANCE",
  "message": "Saldo wallet tidak mencukupi.",
  "errors": { }
}
```

---

## 1. Customer Wallet Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/customer/wallet` | Get customer wallet balance, status, freeze status, active environment mode, withdrawal policy |
| `GET` | `/api/v1/customer/wallet/transactions` | Paginated customer wallet transactions (`page`, `per_page`, `type`, `status`) |
| `GET` | `/api/v1/customer/wallet/transactions/{id}` | Single customer transaction detail |
| `GET` | `/api/v1/customer/wallet/topups/methods` | Available top-up methods (`va`, `qris`, `ewallet`) for active provider & mode |
| `POST` | `/api/v1/customer/wallet/topups` | Create wallet top-up request (`amount`, `payment_type`, `channel_code`, `idempotency_key`) |
| `GET` | `/api/v1/customer/wallet/topups/{id}` | Get top-up status & instructions (syncs with provider if pending) |
| `POST` | `/api/v1/customer/wallet/topups/{id}/simulate-paid` | **DEMO/SANDBOX ONLY** — simulate paid callback for `is_simulated=true` mock top-ups (403 in production) |
| `POST` | `/api/v1/customer/wallet/payments` | Pay delivery order/shipment using customer wallet balance (`shipment_id` or `order_id`, `idempotency_key`) |
| `GET` | `/api/v1/customer/wallet/withdrawals` | List customer withdrawal requests |
| `POST` | `/api/v1/customer/wallet/withdrawals` | Request customer withdrawal (403 `CUSTOMER_WITHDRAWAL_DISABLED_IN_PRODUCTION` in production unless approved) |
| `GET` | `/api/v1/customer/wallet/refunds` | List customer refund requests and `eligible_shipments` |
| `POST` | `/api/v1/customer/wallet/refunds` | Request refund for eligible paid order/shipment (`shipment_id` / `payment_transaction_id`, `reason`, `idempotency_key`) |
| `GET` | `/api/v1/customer/wallet/destinations` | List registered bank / e-wallet destinations |
| `POST` | `/api/v1/customer/wallet/destinations` | Register bank or e-wallet destination |
| `PATCH` | `/api/v1/customer/wallet/destinations/{id}` | Update destination / set default / toggle active |

---

## 2. Courier Wallet, Earnings & Payout Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/courier/wallet` | Get courier wallet (`available_balance`, `pending_balance`, `reserved_balance`, auto-payout policy, mode) |
| `GET` | `/api/v1/courier/wallet/transactions` | Paginated courier wallet transaction history (`filter`, `status`, `page`, `per_page`) |
| `GET` | `/api/v1/courier/wallet/transactions/{id}` | Single courier transaction detail |
| `GET` | `/api/v1/courier/wallet/earnings` | Courier earnings summary (`pending_earnings`, `available_earnings`, `paid_earnings`, commission breakdown, paginated items) |
| `GET` | `/api/v1/courier/wallet/payouts` | Paginated courier payout history + auto-payout eligibility & next schedule status |
| `GET` | `/api/v1/courier/wallet/payouts/{id}` | Single payout detail + status timeline + provider reference |
| `GET` | `/api/v1/courier/wallet/notifications` | Payout & wallet notifications |
| `GET` | `/api/v1/courier/wallet/destinations` | List courier payout bank/e-wallet destinations |
| `POST` | `/api/v1/courier/wallet/destinations` | Add bank account or e-wallet payout destination |
| `PATCH` | `/api/v1/courier/wallet/destinations/{id}/default` | Set default verified payout destination |

---

## 3. Webhook Endpoints (Public, Signature Verified)

| Method | Endpoint | Header Verification |
|---|---|---|
| `POST` | `/api/v1/webhooks/xendit/payment` | `x-callback-token` |
| `POST` | `/api/v1/webhooks/xendit/payout` | `x-callback-token` |
| `POST` | `/api/v1/webhooks/doku` | `Client-Id`, `Request-Id`, `Request-Timestamp`, `Signature` (`HMACSHA256`) |
