# Ladder Social mobile

Flutter Android klijent za Ladder Social. Aplikacija uključuje autentifikaciju, profile, prijateljstva, preporuke, zadatke, feed, rang-listu, obavijesti i E2E multimedia chat.

## Pokretanje iz izvornog koda

Iz korijena repozitorija prvo podignite backend:

```bash
docker compose --env-file .env up --build -d
```

Zatim:

```bash
cd apps/ladder_social_mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

Adresa `10.0.2.2` je namijenjena Android emulatoru. Za drugi uređaj koristite adresu backend hosta koja je dostupna tom uređaju.

## E2E chat

Text, Image, Voice i Video sadržaj enkriptuje se na klijentu prije slanja. Privatni device ključ i conversation key čuvaju se u `flutter_secure_storage`; backend prima javne ključeve, encrypted key envelope-e i ciphertext. Detalji su u `../../docs/e2e-chat-arhitektura.md`.

## Testiranje

```bash
flutter analyze
flutter test
```

Kompletna projektna E2E provjera pokreće se iz root direktorija:

```bash
bash scripts/test-review-e2e-multimedia-chat.sh http://localhost:5001
```
