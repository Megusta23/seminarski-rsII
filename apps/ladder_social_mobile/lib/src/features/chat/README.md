# Chat feature

Mobilni chat podržava Text, Image, Voice i Video poruke sa client-side end-to-end enkripcijom.

Glavni UI je `presentation/chat_screen.dart`. Kriptografske primitive, device identitet, conversation-key envelope, TOFU pinning i transport modeli nalaze se u zajedničkom paketu `ladder_social_core`, dok mobilni presentation sloj upravlja pickerima, recorderom, privremenim clear fajlovima i playback kontrolama.

Novi privatni sadržaj uvijek prolazi kroz `/api/conversations/{conversationId}/messages/e2e`. Stari plaintext write endpoint nije dio API-ja. Postojeće `EncryptionVersion = 0` poruke ostaju dostupne samo kao jasno označena legacy historija.

Objedinjena provjera:

```bash
bash scripts/test-review-e2e-multimedia-chat.sh http://localhost:5001
```
