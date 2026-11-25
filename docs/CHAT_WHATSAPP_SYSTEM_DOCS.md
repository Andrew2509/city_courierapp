# City Courier — Dokumentasi Sistem Chat Internal Realtime + WhatsApp Business Cloud API

Dokumen ini merangkum arsitektur final, skema database, kontrak API, protokol WebSocket, kepatuhan WhatsApp Business Cloud API (Meta), alur notifikasi, dan checklist keamanan sistem komunikasi Customer ↔ Courier.

---

## 1. Prinsip Arsitektur

1. **Internal Chat sebagai Primary Source of Truth:** Seluruh komunikasi antara Customer dan Courier tersimpan dalam tabel `conversations` dan `messages` di MySQL City Courier dan tetap berjalan 100% walaupun WhatsApp Cloud API dinonaktifkan (`WHATSAPP_CLOUD_ENABLED=false`).
2. **Ruang Percakapan Terikat Order (`1 Order = 1 Conversation`):** Setiap pengiriman (`order_id`) memiliki maksimal satu ruang percakapan. Hanya `customer_user_id` pemilik pesanan dan `courier_user_id` kurir aktif yang berhak mengakses pesan dan media percakapan tersebut (`ConversationPolicy`).
3. **Kepatuhan Resmi Meta Cloud API:** Tidak ada akses atau sinkronisasi ke WhatsApp pribadi pengguna. Seluruh jembatan WhatsApp menggunakan **Meta WhatsApp Business Cloud API resmi** melalui nomor bisnis terverifikasi City Courier.

---

## 2. Endpoint API & Webhook (`/api/v1`)

### Authenticated (`Authorization: Bearer <sanctum_token>`)
| Method | Endpoint | Fungsi |
|---|---|---|
| `GET` | `/api/v1/chat/conversations` | Inbox daftar percakapan terurut pesan terbaru + `total_unread` |
| `POST` | `/api/v1/chat/conversations/by-order/{orderIdentifier}` | Buka/buat percakapan berdasarkan `order_id`, `order_number`, atau `tracking_number` |
| `GET` | `/api/v1/chat/conversations/{conversation}` | Detail percakapan + info lawan bicara |
| `GET` | `/api/v1/chat/unread-count` | Ringkasan jumlah total pesan belum dibaca |
| `GET` | `/api/v1/chat/conversations/{conversation}/messages` | Riwayat pesan cursor-paginated (`?before_id=...&limit=30`) |
| `POST` | `/api/v1/chat/conversations/{conversation}/messages` | Kirim teks atau gambar multipart (idempoten via `client_message_id`) |
| `POST` | `/api/v1/chat/conversations/{conversation}/read` | Tandai pesan dibaca (`read_at`) dan reset unread count |
| `POST` | `/api/v1/chat/conversations/{conversation}/typing` | Broadcast indikator mengetik (server-throttled) |
| `GET` | `/api/v1/chat/media/{message}` | Akses file gambar privat dengan verifikasi `ConversationPolicy` |
| `GET` | `/api/v1/chat/realtime-config` | Konfigurasi non-rahasia WebSocket (Reverb/Pusher) untuk aplikasi mobile |
| `POST` | `/api/v1/chat/broadcasting/auth` | Autentikasi private channel `private-conversation.{id}` & `private-user.{id}` |
| `GET` | `/api/v1/chat/whatsapp/status` | Status opt-in WhatsApp user & status window 24 jam |
| `POST` | `/api/v1/chat/whatsapp/opt-in` | Aktifkan/nonaktifkan notifikasi WA (syarat `phone_verified = true`) |
| `POST` / `DELETE` | `/api/v1/devices/fcm-token` | Daftarkan / cabut token FCM perangkat saat login/logout |

### Public Meta Webhook (Signature Verified)
| Method | Endpoint | Keamanan |
|---|---|---|
| `GET` | `/api/v1/whatsapp/webhook` | Verifikasi `hub.mode=subscribe` + `hub.verify_token` (`hash_equals`) |
| `POST` | `/api/v1/whatsapp/webhook` | Wajib lolos HMAC-SHA256 `X-Hub-Signature-256`, deduplikasi `event_hash` di `whatsapp_message_logs`, lalu diproses asinkron oleh `ProcessWhatsAppWebhookJob` |

---

## 3. WebSocket Realtime & Fallback

- **Server:** Laravel Reverb (protokol Pusher v7) melalui channel privat terotentikasi:
  - `private-conversation.{conversationId}` -> event `message.sent`, `message.status`, `user.typing`
  - `private-user.{userId}` -> event `conversation.updated`
- **Client Flutter (`ChatRealtimeService` + `ChatProvider`):**
  - Memakai `web_socket_channel` murni (stabil pada Android tanpa konflik native SDK).
  - *Reconnect* otomatis dengan *exponential backoff*.
  - *Adaptive fallback polling* (10 detik di dalam room, 30 detik di luar room) **hanya aktif ketika WebSocket terputus** dan berhenti otomatis saat WebSocket tersambung.

---

## 4. Aturan WhatsApp Business Cloud API & Kepatuhan Meta

1. **Normalisasi E.164 (`PhoneNumberNormalizer`):** `08...` -> `628...`, menghilangkan spasi/tanda baca non-digit.
2. **Opt-In Eksplisit & Opt-Out (`STOP`):** Pengiriman pesan keluar ke WA hanya dilakukan jika `whatsapp_contacts.opt_in_status === 'opted_in'`. Balasan kata kunci `STOP` / `UNSUBSCRIBE` / `BERHENTI` via WA otomatis memutus status menjadi `opted_out`.
3. **Aturan 24-Hour Customer Service Window:**
   - Jika `now < window_expires_at` -> pesan chat internal diteruskan sebagai pesan teks/gambar biasa (media diupload langsung ke Meta `/media` API agar storage internal tetap privat).
   - Jika `now >= window_expires_at` -> wajib memakai **Approved Utility Template** (`config('whatsapp.utility_template_name')`), dilarang mengirim teks bebas.
4. **Anti-Loop & Monotonic Status Sync:** Pesan masuk dari webhook ditandai `channel = 'whatsapp'` dan diabaikan oleh `QueueWhatsAppBridgeListener` sehingga tidak pernah terpantul keluar lagi. Update status webhook (`sent` -> `delivered` -> `read`) bersifat monotonik sehingga webhook terlambat tidak menurunkan status `read`.
5. **Disambiguasi Multi-Order Aktif:** Balasan WA dicocokkan berurutan lewat `context.id` (reply kutipan pesan order asal), `active_conversation_id` terbaru pada `whatsapp_contacts`, lalu percakapan aktif paling baru milik pengguna.

---

## 5. Checklist Keamanan & Anti-Duplikasi Notifikasi

- **Rahasia Server-Side Only:** Token akses Meta (`WHATSAPP_ACCESS_TOKEN`), App Secret (`WHATSAPP_APP_SECRET`), Reverb Secret, dan Service Account FCM tidak pernah dikirim atau ditanam di kode Flutter.
- **Anti-Duplikasi Notifikasi (`ChatNotificationCoordinator`):**
  - Merekam ID pesan yang sudah diberitahukan (`_seenMessageIds`, `_seenClientMessageIds`) agar kedatangan lewat WebSocket + FCM tidak memunculkan dua notifikasi.
  - Menekan notifikasi heads-up/suara jika user sedang aktif membuka percakapan tersebut (`activeConversationId == incomingConversationId`).
  - Menonaktifkan `fcm_token` pada backend secara otomatis saat user logout (`ApiService.logout()`) maupun saat FCM merespons `404`/`UNREGISTERED`.
