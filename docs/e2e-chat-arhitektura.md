# E2E multimedia chat arhitektura

## Trenutni status faze

Ovaj dokument se dopunjava kroz više malih implementacijskih paketa. Trenutno su završeni:

1. backend persistence model i EF Core migracija;
2. backend API za javne device ključeve, conversation-key envelope i ciphertext poruke;
3. Flutter kriptografska osnova za X25519 identitet, HKDF, AES-256-GCM, secure storage i lokalni text/media roundtrip;
4. produkcijski E2E Text tok: registracija uređaja, provjera javnih ključeva, bootstrap conversation keya, slanje ciphertexta i lokalna dekripcija.

Nove tekstualne poruke sa mobilnog chat ekrana više ne koriste legacy plaintext endpoint. Slanje teksta se prekida ako E2E priprema nije uspješna; nema automatskog fallbacka na plaintext. Postojeće `EncryptionVersion = 0` poruke ostaju čitljive i jasno označene kao legacy.

Image picker u ovom inkrementalnom paketu još koristi postojeći legacy image tok, dok Voice i Video UI dolaze u narednim paketima. Zbog toga se kompletan multimedia chat još ne predstavlja kao završeno E2E rješenje.

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

## Flutter E2E Text orkestracija

`E2EChatCoordinator` povezuje kriptografski servis i postojeći `ChatRepository` bez premještanja kriptografije na server. Tok nakon autentifikacije je:

1. `AuthenticatedHomeScreen` pokreće idempotentnu registraciju lokalnog javnog device ključa;
2. otvaranje chata ponavlja registraciju ako je raniji pokušaj bio privremeno neuspješan;
3. klijent paginira sve aktivne device ključeve razgovora;
4. provjerava da svaki participant ima najmanje jedan uređaj i odbija ključeve korisnika koji nisu participanti;
5. učitava ili lokalno generiše conversation key za `KeyVersion = 1`;
6. kreira nedostajući envelope za svaki aktivni uređaj;
7. tekst lokalno enkriptuje i tek tada poziva `/messages/e2e`;
8. primljeni ciphertext se lokalno dekriptuje prije prikaza u bubble-u.

Paralelni pozivi za registraciju uređaja, pripremu razgovora i učitavanje conversation keya dedupliciraju se u memoriji. Time polling, početno učitavanje i pritisak na Send ne pokreću više konkurentnih bootstrap operacija za isti razgovor.

Klijent validira da backend response nakon slanja sadrži isti conversation ID, sender user ID, key version, ciphertext i nonce koji su poslani, da je `Content = null` i da nema attachmenta. Ako server vrati izmijenjen payload ili pokušaj plaintext sadržaja, lokalni UI odbija response.

## TOFU i pinning javnih ključeva

`SecureE2EPeerKeyTrustStore` pri prvom uspješnom susretu pamti Base64 javni ključ po kombinaciji:

```text
trenutni korisnik
peer korisnik
stabilni peer DeviceId
```

Svaki naredni različit javni ključ za isti peer uređaj zaustavlja E2E pripremu. Promjena se ne prihvata automatski i poruka se ne šalje. Ovo je TOFU model: štiti od tihe naknadne zamjene ključa, ali prvi kontakt još zavisi od autentifikovanog backend kanala jer seminarski obim nema QR/safety-number potvrdu izvan aplikacije.

## Bootstrap conversation keya

Za prvu `KeyVersion` vrijednost svi klijenti sortiraju aktivne device-key ID vrijednosti i isti najniži ID koriste kao deterministički claim recipient. Samo prvi neidentični envelope za tu kombinaciju razgovora, recipient uređaja i key versiona može biti upisan; backend za drugi sadržaj vraća HTTP 409.

Klijent koji izgubi race ne generiše novi aktivni ključ i ne šalje plaintext. On čeka vlastiti envelope, otvara ga lokalno i nastavlja sa ključem pobjedničkog bootstrap toka. Vlastiti envelope se priprema prije ostalih uređaja, a postojeći vlastiti envelope se lokalno otvara i poredi sa očekivanim conversation keyem prije nastavka.

Ovo rješava uobičajeni istovremeni bootstrap u seminarskom obimu. Nije distribuirani consensus protokol; djelimični mrežni prekid tačno između claim upisa i kreiranja vlastitog envelope-a može zahtijevati da claim-device korisnik ponovo otvori chat.

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

Produkcijski E2E Text tok:

```bash
bash scripts/test-review-e2e-chat-text.sh
```

Text testovi provjeravaju:

- automatsku registraciju javnog device ključa bez private key polja;
- envelope kreiranje za oba uređaja;
- odsustvo poznatog plaintext markera iz serverskog message modela;
- lokalni Alice → Bob i Bob → Alice decrypt tok;
- odbijanje tampered ciphertexta;
- odbijanje izmijenjenog backend send responsea;
- odbijanje plaintexta ili attachment metapodataka u E2E Text responseu;
- odbijanje non-participant device ključa prije envelope kreiranja;
- TOFU odbijanje promijenjenog ili oštećenog peer-key pina;
- blokiranje slanja prije kriptografskog i mrežnog rada kada razgovor više nije writable;
- blokiranje slanja kada participant nema registrovan uređaj;
- očuvanje i jasno označavanje legacy poruka;
- parsiranje Base64 ciphertext/nonce polja bez plaintext fallbacka.

## Ograničenja trenutne inkrementalne faze

E2E Text tok je aktivan, ali kompletna profesorova multimedia stavka još nije završena:

- image picker trenutno ostaje na legacy image endpointu; naredni paket mora lokalno enkriptovati image bytes, uploadovati `application/octet-stream`, preuzeti ciphertext i prikazati sliku tek nakon lokalne dekripcije;
- Voice recorder, permission, preview, upload/decrypt i playback još nisu spojeni na UI;
- Video picker/camera, preview, validacija, upload/decrypt i playback još nisu spojeni na UI;
- nema korisničkog interfejsa za opoziv izgubljenog uređaja; `RevokedAtUtc` ostaje spreman za kasniji device-management tok;
- novi uređaj ne može sam otvoriti historijski conversation key ako još nema svoj envelope; najmanje jedan postojeći uređaj koji već posjeduje ključ mora otvoriti razgovor i kreirati envelope za novi uređaj;
- nema ručne key-rotation akcije niti migracije postojećih legacy poruka;
- protokol koristi verzionisani conversation key, a ne Double Ratchet, pa ne obećava per-message forward secrecy;
- TOFU otkriva promjenu nakon prvog kontakta, ali nema out-of-band safety-number verifikaciju.

Legacy endpoint ostaje privremeno potreban samo za postojeći Image tok i čitanje stare historije. Produkcijski Text submit ga više ne poziva. Cijeli chat se može označiti kao kompletno E2E tek nakon završetka Image, Voice i Video paketa i završnog smoke testa.
