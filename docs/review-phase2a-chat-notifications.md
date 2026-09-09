# Review Phase 2A: chat friendship rules and live notifications

Ova historijska faza je prvobitno riješila review stavke 8, 9 i 10. Završna E2E multimedia faza je kasnije dodatno pooštrila write ugovor, pa ovaj dokument opisuje konačno stanje.

## Direct-message autorizacija

Historija direct razgovora ostaje dostupna postojećim participantima nakon uklanjanja prijateljstva. Svaki novi E2E send ponovo provjerava trenutno prijateljstvo unutar baze i transakcije. Kada korisnici više nisu prijatelji, API vraća HTTP 403 i ne kreira poruku, attachment ni notifikaciju.

Conversation response izlaže `canSendMessages`. Mobilni chat pollingom osvježava tu vrijednost, ostavlja historiju vidljivom i onemogućava composer kada direct razgovor postane read-only.

## Uklonjena legacy plaintext write putanja

Stari `POST /api/conversations/{conversationId}/messages` više nije dio API ugovora. Uklonjeni su odgovarajući form model, application command, servisna metoda i Flutter repository metoda. Pokušaj slanja teksta ili slike na staru putanju vraća HTTP 405 i ne stvara zapis.

Postojeće `EncryptionVersion = 0` poruke ostaju čitljive kao legacy historija. Novi Text, Image, Voice i Video sadržaj može se poslati samo kroz `/messages/e2e` kao ciphertext.

## Privacy-safe chat notifikacije

Server ne kopira chat sadržaj u notification body. Koristi isključivo generičke poruke:

- `<display name> sent you a message.`
- `<display name> sent you an image.`
- `<display name> sent you a voice message.`
- `<display name> sent you a video.`

To uklanja raniji mismatch dužine i sprečava da plaintext privatne komunikacije završi u notifikaciji.

## Automatsko osvježavanje liste

Otvorena mobilna notification lista pollingom osvježava svoju prvu stranicu svakih 10 sekundi. Polling se pauzira kada aplikacija nije u foregroundu i odmah nastavlja kada ponovo postane aktivna. Pull-to-refresh ostaje ručni fallback.

## Provjera

```bash
./scripts/test-review-chat-notifications.sh
./scripts/test-review-e2e-chat-backend.sh http://localhost:5001
./scripts/test-review-e2e-multimedia-chat.sh http://localhost:5001
```

Provjere potvrđuju:

- legacy plaintext text/image write vraća HTTP 405;
- odbijeni write ne kreira poruku niti notifikaciju;
- generičke E2E notifikacije ne sadrže poznati plaintext marker;
- historija ostaje dostupna nakon unfriend-a;
- conversation metadata postaje read-only nakon unfriend-a;
- novi E2E Text/Image/Voice/Video send vraća HTTP 403 nakon unfriend-a;
- refriending ponovo omogućava E2E slanje u istom razgovoru, ali ne vraća uklonjenu plaintext rutu.
