# City Courier — Payment & Wallet Database Design

All monetary amounts in new financial tables use **`BIGINT` (`UNSIGNED BIGINT` / `BIGINT`) in IDR**. `FLOAT` and `DOUBLE` are strictly prohibited for money.

---

## 1. Double-Entry Ledger Rules

1. **Source of Truth:** `wallet_ledger_entries` is append-only and immutable. Completed financial records are never deleted or mutated.
2. **Zero-Sum Journals:** Every financial operation writes a journal (`journal_id`, `journal_reference`) whose `SUM(amount where entry_type='debit') === SUM(amount where entry_type='credit')`.
3. **Bucket Accounts per Wallet:**
   - `WALLET_AVAILABLE` — spendable / withdrawable balance
   - `WALLET_PENDING` — unsettled courier earnings in dispute/waiting window (or pending hold)
   - `WALLET_RESERVED` — funds locked for in-flight payouts / withdrawals
4. **System Clearing Accounts:**
   - `SYSTEM_GATEWAY_CLEARING` — money entering from external payment gateways (VA/QRIS/E-Wallet top-ups or gateway refunds)
   - `SYSTEM_ORDER_ESCROW` — funds held from order payments awaiting courier fulfillment / refund
   - `SYSTEM_PLATFORM_REVENUE` — platform delivery commission & admin/payout fees
   - `SYSTEM_PAYOUT_CLEARING` — funds disbursed out to couriers / customers via payout providers
   - `SYSTEM_REFUND_CLEARING` — manual / provider refund settlement clearing
   - `SYSTEM_SUSPENSE_ADJUSTMENT` — authorized admin reconciliation adjustments
5. **Concurrency & Idempotency:**
   - Balance mutations run inside `DB::transaction()` with `lockForUpdate()` on `wallets` / `wallet_balances` rows.
   - `wallet_ledger_entries.dedupe_key` (`UNIQUE`) prevents duplicate journal lines for the same operation.
   - `wallet_balances` acts as a fast, lockable projection verified against `SUM(credit - debit)` during reconciliation.

---

## 2. Schema Overview

### Adapted Existing Tables (Non-Destructive)
- **`wallets`**:
  - Existing columns retained: `id`, `courier_id`, `status` (`not_active|active|suspended|frozen`), `available_balance`, `pending_balance`, `currency`, `timestamps`.
  - Added columns: `user_id` (nullable FK -> `users`), `wallet_type` (`customer|courier`, default `courier`), `reserved_balance` (`BIGINT` default `0`), `frozen_at`, `frozen_by`, `freeze_reason`.
  - `courier_id` made nullable so customer wallets do not require a courier profile. Unique index on `(user_id, wallet_type)`.
- **`wallet_transactions`**:
  - Existing columns retained for backward compatibility.
  - Added columns: `user_id` (nullable), `wallet_type`, `direction` (`credit|debit`), `amount_idr` (`BIGINT`), `balance_after` (`BIGINT`), `idempotency_key` (nullable unique), `mode` (`demo|sandbox|production`), `metadata` (JSON). `courier_id` made nullable.

### New Financial Tables
1. **`wallet_balances`**: `id`, `wallet_id` (unique FK), `currency`, `available_balance` (`BIGINT`), `pending_balance` (`BIGINT`), `reserved_balance` (`BIGINT`), `total_credited` (`BIGINT`), `total_debited` (`BIGINT`), `last_ledger_entry_id`, `version` (`BIGINT`), `timestamps`.
2. **`wallet_ledger_entries`**: `id`, `journal_id`, `journal_reference`, `dedupe_key` (unique), `wallet_id` (nullable FK), `user_id` (nullable FK), `account_code`, `entry_type` (`debit|credit`), `amount` (`UNSIGNED BIGINT`), `currency`, `transaction_type`, `reference_type`, `reference_id`, `idempotency_key`, `mode`, `description`, `metadata` (JSON), `created_at`.
3. **`topup_transactions`**: `id`, `reference` (unique), `idempotency_key` (unique), `user_id` (FK), `wallet_id` (FK), `provider`, `mode`, `is_simulated`, `payment_type`, `channel_code`, `amount` (`UNSIGNED BIGINT`), `fee` (`UNSIGNED BIGINT`), `net_amount` (`UNSIGNED BIGINT`), `status`, `provider_reference`, `va_number`, `qr_string`, `payment_url`, `instructions` (JSON), `provider_payload` (JSON), `expired_at`, `paid_at`, `settled_at`, `failure_reason`, `timestamps`.
4. **`payment_transactions`**: `id`, `reference` (unique), `idempotency_key` (unique), `user_id` (FK), `wallet_id` (nullable FK), `shipment_id` (nullable FK), `order_id` (nullable FK), `legacy_payment_id` (nullable FK), `payment_method`, `provider`, `mode`, `is_simulated`, `channel_code`, `amount` (`UNSIGNED BIGINT`), `fee` (`UNSIGNED BIGINT`), `total_amount` (`UNSIGNED BIGINT`), `status`, `provider_reference`, `paid_at`, `metadata` (JSON), `timestamps`.
5. **`courier_earnings`**: `id`, `reference` (unique), `courier_id` (FK), `wallet_id` (FK), `order_id` (unique FK), `shipment_id` (nullable FK), `gross_amount` (`UNSIGNED BIGINT`), `commission_rate` (`DECIMAL(5,2)`), `commission_amount` (`UNSIGNED BIGINT`), `net_amount` (`UNSIGNED BIGINT`), `status` (`pending|available|reserved|paid|disputed|reversed`), `payout_transaction_id` (nullable), `mode`, `earned_at`, `available_at`, `released_at`, `paid_at`, `metadata` (JSON), `timestamps`.
6. **`payout_destinations`**: `id`, `owner_type` (`customer|courier`), `user_id` (FK), `courier_id` (nullable FK), `destination_type` (`bank|ewallet`), `channel_code`, `channel_name`, `account_number`, `account_number_masked`, `account_holder_name`, `is_verified`, `verification_status`, `verified_at`, `is_default`, `is_active`, `metadata` (JSON), `timestamps`.
7. **`payout_transactions`**: `id`, `reference` (unique), `idempotency_key` (unique), `owner_type`, `user_id` (FK), `courier_id` (nullable FK), `wallet_id` (FK), `payout_destination_id` (nullable FK), `legacy_withdrawal_id` (nullable FK), `payout_type`, `provider`, `mode`, `is_simulated`, `channel_code`, `account_number_masked`, `account_holder_name`, `amount` (`UNSIGNED BIGINT`), `fee` (`UNSIGNED BIGINT`), `net_amount` (`UNSIGNED BIGINT`), `status`, `provider_reference`, `failure_code`, `failure_reason`, `retry_count`, `status_history` (JSON), `scheduled_at`, `submitted_at`, `completed_at`, `failed_at`, `metadata` (JSON), `timestamps`.
8. **`refund_transactions`**: `id`, `reference` (unique), `idempotency_key` (unique), `user_id` (FK), `wallet_id` (nullable FK), `payment_transaction_id` (nullable FK), `legacy_payment_id` (nullable FK), `shipment_id` (nullable FK), `order_id` (nullable FK), `refund_method`, `provider`, `mode`, `is_simulated`, `amount` (`UNSIGNED BIGINT`), `reason`, `status`, `reviewed_by` (nullable FK), `reviewed_at`, `review_notes`, `processed_at`, `provider_reference`, `metadata` (JSON), `timestamps`.
9. **`payment_webhooks`**: `id`, `provider`, `event_type`, `external_id`, `provider_reference`, `webhook_hash` (unique), `signature_valid`, `processing_status`, `headers` (JSON), `payload` (JSON), `error_message`, `processed_at`, `timestamps`.
10. **`payment_provider_configs`**: `id`, `provider_code` (unique), `display_name`, `mode`, `is_active`, `supports_money_in`, `supports_money_out`, `supports_customer_withdrawal`, `capabilities` (JSON), `settings` (JSON, non-secret only), `health_status`, `last_tested_at`, `timestamps`.
11. **`wallet_audit_logs`**: `id`, `actor_user_id` (nullable FK), `actor_type`, `wallet_id` (nullable FK), `action`, `target_type`, `target_id`, `old_values` (JSON), `new_values` (JSON), `ip_address`, `user_agent`, `notes`, `created_at`.
12. **Admin Menu Permissions Seeder Migration (`2026_11_17_000013`)**: Seeds `finance_dashboard.*`, `finance_wallets.*`, `finance_payouts.*`, `finance_reports`, `finance_settings.*` in Spatie `permissions` and grants them to `super-admin` and `admin`.
