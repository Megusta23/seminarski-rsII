# E2E multimedia chat arhitektura

## Trenutni status faze

Ovaj dokument se dopunjava kroz više malih implementacijskih paketa. Trenutno su završeni:

1. backend persistence model i EF Core migracija;
2. backend API za javne device ključeve, conversation-key envelope i ciphertext poruke;
3. Flutter kriptografska osnova za X25519 identitet, HKDF, AES-256-GCM, secure storage i lokalni text/media roundtrip.

Flutter chat ekran još nije prebačen na novi E2E repository tok. Zbog postepenog rollout-a, postojeći legacy endpoint za plaintext Text/Image poruke privremeno ostaje dostupan dok naredni paket ne poveže registraciju uređaja, envelope bootstrap i enkriptovani text flow. Zbog toga kompletan chat još ne treba predstavljati kao završen E2E sistem.

## Izbor kriptografskih primitiva

Klijent koristi provjereni Dart paket `cryptography` verzije `2.9.0`; projekt ne implementira vlastitu kriptografsku primitivu.

Implementirani algoritmi su:

- X25519 za dogovor zajedničke tajne između dva device identiteta;
- HKDF-HMAC-SHA-256 za izvođenje 32-bajtnog wrapping ključa iz X25519 zajedničke tajne;
- AES-256-GCM za enkripciju conversation key envelope-a, teksta i media bajtova;
- sistemski kriptografski generator slučajnih brojeva za private seed, conversation key i svaki 12-bajtni nonce.

AES-GCM istovremeno obezbjeđuje povjerljivost i integritet. Promijenjen ciphertext, nonce ili associated data uzrokuje authentication grešku i sadržaj se ne vraća pozivaocu.

## Kriptografski format backend ugovora

Backend ne implementira kriptografske primitive. On samo validira format i čuva vrijednosti koje je proizveo Flutter klijent.

Implementirani klijentski format je:

- X25519 javni ključ: 32 bajta;
- X25519 private seed: 32 bajta, isključivo u secure storage-u klijenta;
- conversation key: 32 bajta;
- AES-GCM nonce: 12 bajtova;
- AES-GCM authentication tag: 16 bajtova;
- svaki AEAD poziv dobija novi kriptografski nasumičan nonce;
- wrapped conversation key: 48 bajtova, odnosno 32 bajta ciphertexta i 16 bajtova taga;
- backend polje `EncryptedContent` i encrypted media fajl sadrže `ciphertext || authenticationTag`, dok se nonce čuva odvojeno;
- `EncryptionVersion = 1` za novi client-side E2E format;
- `EncryptionVersion = 0` za postojeće legacy poruke.

Klijentske i serverske granice veličine su usklađene:

- encrypted text: najviše 20 KiB, uključujući authentication tag;
- encrypted media: najviše 25 MiB, uključujući authentication tag;
- MIME tip ciphertext media fajla: `application/octet-stream`.

## Flutter device identitet i secure storage

`E2ECryptoService.loadOrCreateDeviceIdentity()` prvi put generiše:

- stabilni installation `DeviceId`;
- 32-bajtni X25519 private seed;
- odgovarajući 32-bajtni X25519 public key.

`FlutterE2ESecureStorage` koristi postojeći `flutter_secure_storage`. Installation ID, private seed i public key čuvaju se pod verzionisanim ključevima. Identitet je namespacovan po autentifikovanom `UserId`, pa dva korisnička naloga na istom uređaju ne dijele privatni ključ.

Klijent odbija nepotpun ili međusobno neusklađen stored key pair umjesto da tiho generiše novi identitet. Time se sprječava neprimjetna rotacija koja bi stare conversation envelope-e učinila nečitljivim.

Javni registration model izlaže samo:

- `deviceId`;
- Base64 `publicKey`.

Private seed nema getter u javnom modelu i nije dio JSON requesta. Serverski endpoint zato nikada ne dobija private key.

## Lokalno čuvanje conversation keya

Conversation key se generiše kao 32 kriptografski nasumična bajta. Nakon kreiranja ili uspješnog otvaranja envelope-a čuva se u `flutter_secure_storage` namespace-u koji uključuje:

- korisnički ID;
- conversation ID;
- key version.

Conversation key se ne zapisuje u obični preferences, logove, DTO objekte niti backend request u plaintext obliku.

## Conversation-key envelope

`E2ECryptoService.wrapConversationKey()` izvodi sljedeći tok:

1. učita lokalni X25519 private seed;
2. kombinuje ga sa recipient X25519 public keyem;
3. iz X25519 zajedničke tajne izvodi 32-bajtni wrapping key koristeći HKDF-HMAC-SHA-256;
4. enkriptuje conversation key pomoću AES-256-GCM;
5. vraća samo 48-bajtni `ciphertext || tag`, 12-bajtni nonce i javni kontekst potreban backendu.

HKDF i AES-GCM associated data vežu envelope za:

```text
protocol version
conversation ID
sender device-key ID
recipient device-key ID
key version
```

Zbog toga isti envelope ne može biti premješten na drugi razgovor, uređaj ili key version bez authentication greške.

`E2ECryptoService.openConversationKeyEnvelope()` radi obrnuti tok koristeći recipient private seed i sender public key. Server nema nijednu tajnu potrebnu za ovu operaciju.

## Lokalna enkripcija teksta i medija

Tekst se prvo pretvara u strogi UTF-8, zatim se lokalno enkriptuje AES-256-GCM algoritmom. Media API prima čiste image, voice ili video bajtove i vraća ciphertext bajtove; originalni format ostaje vidljiv samo klijentu prije enkripcije i nakon uspješne dekripcije.

Associated data za poruku veže payload za:

```text
protocol version
conversation ID
message type
content ili attachment dio
key version
```

Time se, na primjer, image ciphertext ne može autentifikovati kao video niti se poruka može premjestiti u drugi razgovor ili drugu key version vrijednost.

`E2EEncryptedPayload` pravi defensive kopije bajtova i podržava standardni Base64 transport potreban postojećem ASP.NET Core `byte[]` JSON ugovoru.

## Javni device ključevi

`PUT /api/conversations/device-keys`

Autentifikovani korisnik registruje samo:

- stabilni `DeviceId`;
- X25519 `PublicKey`.

`UserId` se uzima iz validiranog JWT tokena. Ponovna registracija istog `DeviceId` i istog javnog ključa je idempotentna. Tiha zamjena javnog ključa za postojeći `DeviceId` vraća HTTP 409; klijent za novu instalaciju ili rotaciju mora kreirati novi `DeviceId`.

`GET /api/conversations/{conversationId}/device-keys?page=1&pageSize=100`

Samo participant razgovora može dobiti paginirane aktivne javne ključeve participanata. Endpoint nikada ne vraća privatni ključ.

## Conversation-key envelope API

`PUT /api/conversations/{conversationId}/key-envelopes`

Klijent lokalno enkriptuje conversation key za konkretni recipient device. Server prima:

- `RecipientDeviceKeyId`;
- `SenderDeviceKeyId`;
- `EncryptedConversationKey`;
- `Nonce`;
- `KeyVersion`.

Server provjerava da sender device pripada trenutno autentifikovanom korisniku i da recipient device pripada participant-u istog razgovora. Envelope je nepromjenjiv za kombinaciju razgovora, recipient uređaja i verzije ključa. Identičan ponovljeni PUT je dozvoljen, a različit sadržaj za istu verziju vraća HTTP 409.

`GET /api/conversations/{conversationId}/key-envelopes/{recipientDeviceKeyId}?keyVersion=1`

Envelope može preuzeti samo vlasnik navedenog recipient device ključa koji je ujedno participant razgovora. Server vraća ciphertext i javne identifikatore; nema mogućnost otvaranja envelope-a.

## Ciphertext poruke

`POST /api/conversations/{conversationId}/messages/e2e`

Endpoint koristi `multipart/form-data` radi jedinstvenog toka za Text, Image, Voice i Video. Polja su:

- `type`: 1 Text, 2 Image, 4 Voice ili 5 Video;
- `senderDeviceKeyId`;
- `keyVersion`;
- `encryptedContentBase64` i `contentNonceBase64` za tekst ili opcionalne enkriptovane metapodatke;
- `attachment` kao `application/octet-stream` za enkriptovani media sadržaj;
- `attachmentNonceBase64`;
- `durationMilliseconds` za Voice i Video.

`System` se odbija na ovom endpointu jer ostaje serverski generisana poruka.

Prije prihvatanja poruke backend provjerava:

- conversation membership;
- trenutno prijateljstvo za direct chat;
- vlasništvo nad sender device ključem;
- postojanje aktivnog device ključa za svakog participant-a;
- postojanje conversation-key envelope-a za svaki aktivni uređaj i traženi `KeyVersion`;
- dozvoljeni tip poruke, veličine nonce-a i obavezna media polja.

Za E2E poruku `Message.Content` se uvijek postavlja na `null`. Ciphertext teksta se čuva u `Message.EncryptedContent`, a enkriptovani media bajtovi u storage-u sa `.bin` nastavkom i MIME tipom `application/octet-stream`.

## Download i autorizacija medija

Postojeći endpoint:

`GET /api/media/message-attachments/{attachmentId}`

zadržava participant provjeru. Za E2E attachment vraća tačne ciphertext bajtove kao `application/octet-stream`. Server ne pokušava prepoznati originalni image/audio/video format zato što su magic bytes nakon enkripcije namjerno neprepoznatljivi.

## Notifikacije i conversation preview

Server ne koristi sadržaj poruke za notifikaciju. Generičke poruke su:

- `X sent you a message.`
- `X sent you an image.`
- `X sent you a voice message.`
- `X sent you a video.`

E2E tekst u listi razgovora ima serverski preview `Encrypted message`. Pravi preview može nastati samo lokalno nakon dekripcije na Flutter klijentu.

## Unfriend ponašanje

Uklanjanje prijateljstva ne briše postojeću historiju niti ciphertext. Participanti i dalje mogu preuzeti staru historiju i svoje key envelope-e, ali backend odbija sve nove Text, Image, Voice i Video poruke dok prijateljstvo ponovo ne postane aktivno.

## Šta server vidi

Server vidi:

- identitete participanata;
- device identifikatore i javne ključeve;
- tip poruke;
- vrijeme slanja;
- veličinu ciphertext attachmenta;
- trajanje Voice/Video poruke;
- nonce, verziju enkripcije i verziju ključa;
- ciphertext i authentication tag.

Server ne treba vidjeti:

- privatni device ključ;
- plaintext Text poruke;
- plaintext image, voice ili video sadržaj;
- conversation key u plaintext obliku.

## Fokusirane provjere

Backend ugovor nakon podizanja Docker okruženja:

```bash
bash scripts/test-review-e2e-chat-backend.sh http://localhost:5001
```

Flutter kriptografska osnova:

```bash
bash scripts/test-review-e2e-chat-crypto.sh
```

Flutter testovi provjeravaju stabilne wire vrijednosti, local-only private key, odbijanje nepotpunog key paira, envelope roundtrip, vezivanje envelope konteksta, tampered ciphertext i nonce, text UTF-8 roundtrip, odsustvo poznatog plaintext markera iz ciphertexta, image/voice/video roundtrip, vezivanje media tipa, Base64 transport i secure-storage persistence conversation keya.

## Ograničenja trenutne inkrementalne faze

Ovaj paket namjerno još ne prebacuje produkcijski chat na E2E tok:

- device identitet se generiše lokalno, ali registracija javnog ključa nakon login-a dolazi u narednom paketu;
- javni ključevi još nemaju Flutter TOFU/pinning provjeru; naredni paket mora zapamtiti prvi viđeni peer key i odbiti tihu promjenu;
- nema korisničkog interfejsa za opoziv izgubljenog uređaja; `RevokedAtUtc` ostaje spreman za kasniji device-management tok;
- bootstrap nove `KeyVersion` vrijednosti mora koordinirati jedan Flutter uređaj kako dva klijenta ne bi istovremeno generisala različite conversation ključeve za istu verziju;
- protokol koristi verzionisani conversation key, a ne Double Ratchet, pa ovaj seminarski obim ne obećava per-message forward secrecy;
- dok Flutter repository i chat screen ne pređu na E2E endpoint, legacy plaintext endpoint ostaje samo radi kompatibilnosti i cijeli chat se ne smije označiti kao završen E2E.

Prilikom slanja backend zahtijeva envelope za svaki aktivni device ključ svakog participant-a. Time se sprječava da nova poruka bude poslana u stanju u kojem neki registrovani aktivni uređaj nema način preuzeti conversation key. Naredna klijentska faza mora paginirati sve device ključeve i napraviti nedostajuće envelope-e prije slanja.
