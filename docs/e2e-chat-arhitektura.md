# E2E multimedia chat arhitektura

## Trenutni status faze

Ovaj dokument se dopunjava kroz više malih implementacijskih paketa. Trenutno su završeni:

1. backend persistence model i EF Core migracija;
2. backend API za javne device ključeve, conversation-key envelope i ciphertext poruke.

Flutter generisanje ključeva, lokalna enkripcija/dekripcija i multimedia korisnički interfejs još nisu dio ove faze. Zbog postepenog rollout-a, postojeći legacy endpoint za plaintext Text/Image poruke privremeno ostaje dostupan dok Flutter ne bude prebačen na novi E2E endpoint. Zbog toga kompletan chat još ne treba predstavljati kao završen E2E sistem.

## Kriptografski format backend ugovora

Backend ne implementira kriptografske primitive. On samo validira format i čuva vrijednosti koje je proizveo Flutter klijent.

Planirani klijentski format je:

- X25519 javni ključ: 32 bajta;
- conversation key: 32 bajta;
- AEAD nonce: 12 bajtova;
- authentication tag: 16 bajtova;
- svaki AEAD poziv mora dobiti novi kriptografski nasumičan nonce; nonce se ne smije ponoviti sa istim ključem;
- wrapped conversation key: 48 bajtova, odnosno 32 bajta ciphertexta i 16 bajtova taga;
- `EncryptionVersion = 1` za novi client-side E2E format;
- `EncryptionVersion = 0` za postojeće legacy poruke.

Privatni ključ nije dio nijednog request/response DTO-a niti serverskog entiteta. Flutter će ga generisati i čuvati u `flutter_secure_storage`.

## Javni device ključevi

`PUT /api/conversations/device-keys`

Autentifikovani korisnik registruje samo:

- stabilni `DeviceId`;
- X25519 `PublicKey`.

`UserId` se uzima iz validiranog JWT tokena. Ponovna registracija istog `DeviceId` i istog javnog ključa je idempotentna. Tiha zamjena javnog ključa za postojeći `DeviceId` vraća HTTP 409; klijent za novu instalaciju ili rotaciju mora kreirati novi `DeviceId`.

`GET /api/conversations/{conversationId}/device-keys?page=1&pageSize=100`

Samo participant razgovora može dobiti paginirane aktivne javne ključeve participanata. Endpoint nikada ne vraća privatni ključ.

## Conversation-key envelope

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

## Fokusirana backend provjera

Nakon podizanja Docker okruženja pokrenuti:

```bash
bash scripts/test-review-e2e-chat-backend.sh http://localhost:5001
```

Skripta provjerava registraciju javnih ključeva, idempotency i zabranu tihe zamjene ključa, participant autorizaciju, envelope autorizaciju, obaveznu envelope pokrivenost, odbijanje System poruke i pogrešnog media MIME tipa, ciphertext-only response, Image/Voice/Video upload, byte-for-byte roundtrip sva tri media ciphertexta, generičke notifikacije, non-participant zabranu i unfriend pravilo.

## Ograničenja trenutnog backend paketa

Ovaj paket namjerno ne pokušava riješiti cijeli klijentski protokol:

- javni ključevi još nemaju Flutter TOFU/pinning prikaz; to se uvodi u klijentskoj crypto fazi kako bi se tiha promjena ključa mogla prikazati korisniku;
- nema korisničkog interfejsa za opoziv izgubljenog uređaja; `RevokedAtUtc` ostaje spreman za kasniji device-management tok;
- bootstrap nove `KeyVersion` vrijednosti mora koordinirati jedan Flutter uređaj kako dva klijenta ne bi istovremeno generisala različite conversation ključeve za istu verziju;
- protokol koristi verzionisani conversation key, a ne Double Ratchet, pa ovaj seminarski obim ne obećava per-message forward secrecy;
- dok Flutter ne pređe na E2E endpoint, legacy plaintext endpoint ostaje samo radi kompatibilnosti i cijeli chat se ne smije označiti kao završen E2E.

Prilikom slanja backend zahtijeva envelope za svaki aktivni device ključ svakog participant-a. Time se sprječava da nova poruka bude poslana u stanju u kojem neki registrovani aktivni uređaj nema način preuzeti conversation key. Klijentska faza mora paginirati sve device ključeve i napraviti nedostajuće envelope-e prije slanja.
