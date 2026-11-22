# Spesifikasi Integrasi Backend Laravel — Fitur Dropoff (Antar Paket) City Courier

Dokumen ini mencatat kontrak API antara aplikasi Flutter (`city_courierapp`) dan backend Laravel (`https://www.neonflux.my.id/api`) untuk fitur **Dropoff (Antar Paket)**, termasuk endpoint yang sudah dipanggil oleh klien Flutter dan penyesuaian yang diperlukan di sisi backend Laravel.

> **Catatan Ruang Lingkup:** Repository backend Laravel tidak tersedia pada workspace `F:\DariNoStudio`, sehingga perilaku endpoint di sisi server didokumentasikan berdasarkan implementasi klien Flutter.

---

## 1. Endpoint yang Sudah Digunakan Klien Flutter

| Alur | Method & Endpoint | File Klien | Status Klien |
| :--- | :--- | :--- | :--- |
| Daftar Drop Point | `GET /api/drop-points` | `DropPointScreen` / `ApiService.getDropPoints` | Aktif |
| Pencocokan Wilayah Asal Drop Point | `POST /api/shipping/match-region` | `RajaOngkirMatcherService.match` | Aktif (fallback jika `city_id`/`subdistrict_id` kosong) |
| Data Wilayah Tujuan | `GET /api/shipping/provinces`, `cities/{id}`, `districts/{id}`, `subdistricts/{id}` | `RajaOngkirService`, `SelectRegionScreen` | Aktif |
| Buku Alamat Pengirim & Penerima | `GET /api/addresses`, `POST /api/addresses` | `AddressService`, `SelectSenderScreen`, `AddSenderScreen` | Aktif |
| Hitung Tarif & Layanan Kurir | `POST /api/shipping/cost` (`courier: 'jne:pos:tiki:sicepat:jnt'`) | `DropoffServiceSelectionScreen`, `RajaOngkirService.calculateCost` | Aktif |
| Buat Pesanan Pengiriman | `POST /api/shipments` | `ConfirmationScreen` | Aktif |
| Metode & Pembayaran City Wallet | `GET /api/wallet`, `POST /api/wallet/pay-order` | `CustomerWalletService`, `PaymentMethodScreen` | Aktif |
| Metode & Pembayaran Gateway (iPaymu) | `GET /api/payment/methods`, `POST /api/payment/create`, `GET /api/payment/{id}/status` | `PaymentService`, `PaymentMethodScreen` | Aktif |
| Konfirmasi Tunai di Drop Point | `POST /api/shipments/{id}/confirm-payment` | `PaymentMethodScreen` | Aktif (`payment_method: 'TUNAI'`) |
| Riwayat & Lacak Pengiriman | `GET /api/shipments`, `GET /api/shipments/{number}/tracking` | `ShipmentService`, `TrackingService` | Aktif |
| Pembatalan Pesanan | `POST /api/shipments/{id}/cancel` | `ShipmentService.cancelShipment` | Aktif |

---

## 2. Penyesuaian & Kebutuhan Backend Laravel untuk Dropoff

### A. `GET /api/drop-points`
Saat ini `DropPoint.fromJson` mendukung field opsional wilayah RajaOngkir/Komerce. Backend disarankan mengembalikan field berikut pada setiap item Drop Point agar tarif ongkir Dropoff selalu memakai wilayah asal Drop Point yang presisi:

```json
{
  "id": 1,
  "name": "City Courier - Grogol",
  "address": "Jl. Latumenten No. 12, Jakarta Barat",
  "phone": "081234567890",
  "schedule": "08:00 - 21:00",
  "rating": 4.9,
  "latitude": -6.1665,
  "longitude": 106.7905,
  "is_active": true,
  "city_id": "151",
  "subdistrict_id": "2095",
  "city_name": "Jakarta Barat",
  "subdistrict_name": "Grogol Petamburan",
  "postal_code": "11460"
}
```

### B. `POST /api/shipments`
Klien Flutter mengirim metadata Dropoff saat membuat pesanan dari `DropoffScreen` -> `ConfirmationScreen`:

- `shipping_method`: `"dropoff"`
- `service_type`: `"dropoff"`
- `delivery_method`: `"dropoff"`
- `drop_point_id`: `int` (ID Drop Point terpilih)
- `drop_point_name`: `string`
- `drop_point_address`: `string`
- `courier_name`: kode kurir dari respons `/shipping/cost` (mis. `"jne"`, `"sicepat"`, `"jnt"`, `"pos"`, `"tiki"`)
- `courier_service`: nama layanan (mis. `"REG"`, `"YES"`, `"BEST"`, `"JTR"`)
- `notes`: catatan tambahan paket dari `ItemInfoScreen`

**Kewajiban Backend:**
1. Simpan `shipping_method`, `drop_point_id`, `drop_point_name`, dan `drop_point_address` ke tabel `shipments`.
2. Hitung/verifikasi nomor resi (`tracking_number`) resmi dari backend — klien tidak membuat resi acak.
3. Jangan memicu auto-assign kurir jemput (`pickup`) untuk pesanan dengan `shipping_method = 'dropoff'`.
4. Status awal setelah pesanan dibuat adalah `pending` (menunggu pembayaran), lalu berubah ke `waiting_dropoff` setelah pembayaran terkonfirmasi atau metode `TUNAI` (bayar di Drop Point) dipilih.

### C. `POST /api/shipments/{id}/confirm-payment` (Khusus `TUNAI` Dropoff)
Klien sekarang **memvalidasi** respons endpoint ini (`success == true` atau `confirmed == true`) sebelum menganggap pesanan terkonfirmasi. Pastikan backend Laravel:
1. Memvalidasi kepemilikan pesanan (`auth()->id()`).
2. Mengizinkan `payment_method = "TUNAI"` untuk `shipping_method = "dropoff"`.
3. Mengubah status shipment menjadi `waiting_dropoff` (dan menandai pembayaran tunai akan diselesaikan di petugas Drop Point), **bukan** langsung menandai `delivered` atau `dropped_off`.
4. Mengembalikan HTTP `200` dengan `{ "success": true, "confirmed": true, "data": ... }`.

### D. Siklus Status Pengiriman Dropoff & Otorisasi Petugas
Model `TrackingStatus` dan `ShipmentModel` di Flutter sudah mendukung siklus status berikut:

1. `pending` — Menunggu Pembayaran
2. `waiting_dropoff` (atau `awaiting_dropoff`) — Menunggu Diantar ke Drop Point
3. `dropped_off` (atau `received_at_drop_point`) — Paket Diterima Petugas Drop Point
4. `processing` — Paket Diproses
5. `in_transit` — Dalam Perjalanan
6. `arrived_at_destination` — Sampai di Kota Tujuan
7. `delivering` — Dalam Pengantaran
8. `delivered` — Paket Diterima

**Aturan Keamanan:**
- Pelanggan hanya dapat melihat status `waiting_dropoff` setelah membuat/membayar pesanan; status `dropped_off` **hanya** boleh diubah oleh petugas/agen Drop Point terotorisasi setelah memindai QR/No. Resi paket secara fisik di gerai.
- Disarankan endpoint khusus petugas di Laravel, misalnya:
  `POST /api/drop-points/{dropPointId}/shipments/{trackingNumber}/receive`
  dengan middleware otorisasi role petugas/agen Drop Point.

### E. `GET /api/shipments/{number}/tracking` & `GET /api/shipments`
Pastikan endpoint tracking & riwayat menyertakan:
- `shipping_method`: `"dropoff"` (atau objek `drop_point: { id, name, address }`)
- `drop_point_id`, `drop_point_name`, `drop_point_address`
- `status` menggunakan string di bagian **2.D** dan array `timeline` berisi riwayat transisi status.
