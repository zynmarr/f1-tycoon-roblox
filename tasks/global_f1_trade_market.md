# Concept One-Pager: Global F1 Trade Market (Bursa Mobil Bekas & Auction)

## Problem Statement
Bagaimana kita bisa menciptakan sistem perdagangan pasar terbuka (*Global Auction & Trade Hub*) yang membuat ekonomi mobil F1 antar pemain menjadi dinamis, aman dari eksploitasi (duplikasi/fraud), dan memberikan pengalaman lelang yang seru tanpa merusak keseimbangan passive income?

---

## Recommended Direction: "Grand Prix Trade Exchange"
- **Centralized Marketplace**: Pemain dapat mendaftarkan mobil (*Tool*) ke bursa global dengan harga lelang (*Auction*) atau beli instan (*Buyout*).
- **Tax & Economy Sink**: Menggunakan skema pajak transaksi 5% s/d 10% untuk mencegah inflasi uang di dalam game.
- **Anti-Fraud & Stack Verification**: Memeriksa kelayakan data atribut (`Amount`, `Rarity`, `Variant`, `Income`) secara valid di server-side sebelum listing dipublikasikan.

---

## Key Assumptions to Validate
- [ ] Pemain bersedia menjual mobil langka (*Epic/Legendary/Mythic*) mereka ke pasar terbuka daripada menyimpannya di koleksi.
- [ ] Sistem lelang dengan timer (misal: 1 jam atau 24 jam) dapat ditangani secara asinkronis di DataStore/MemoryStore tanpa lag server.
- [ ] Pajak transaksi cukup untuk menahan laju hiperinflasi uang (*Cash*).

---

## MVP Scope

### In Scope (MVP)
- **Listing Menu**: Tombol "Jual ke Pasar" di Inventory/Backpack UI.
- **Bursa UI**: Tab daftar mobil yang dijual oleh seluruh pemain di server/global dengan filter Rarity & Variant.
- **System Bidding & Buyout**: Pemain bisa memasang penawaran (*Bid*) atau membeli langsung (*Buyout*).
- **Pengiriman Hadiah/Barang**: Mobil & uang otomatis ditransfer via server-side DataManager saat lelang berakhir.

---

## Not Doing (and Why)
- **Direct P2P Trading Without Lock**: Menghindari transaksi barter langsung tanpa validasi pasar untuk mencegah eksploitasi akun alt.
- **Cross-Server Real-Time Voice Chat Auction**: Terlalu kompleks dan tidak relevan untuk gameplay Tycoon utama.

---

## Open Questions
- Apakah batas waktu lelang terbaik adalah 1 jam, 6 jam, atau 24 jam?
- Apakah lelang hanya boleh menggunakan Cash, atau juga mendukung RPM Tokens?
