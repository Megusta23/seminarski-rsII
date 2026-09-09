# E2E multimedia chat arhitektura

## Trenutni status faze

Ovaj dokument se dopunjava kroz više malih implementacijskih paketa. Trenutno su završeni:

1. backend persistence model i EF Core migracija;
2. backend API za javne device ključeve, conversation-key envelope i ciphertext poruke;
3. Flutter kriptografska osnova za X25519 identitet, HKDF, AES-256-GCM, secure storage i lokalni text/media roundtrip;
4. produkcijski E2E Text tok: registracija uređaja, provjera javnih ključeva, bootstrap conversation keya, slanje ciphertexta i lokalna dekripcija;
5. produkcijski E2E Image tok: lokalna validacija i dekodiranje, lokalna AES-GCM enkripcija, `application/octet-stream` upload, autorizovani ciphertext download i prikaz tek nakon lokalne autentifikacije i dekripcije;
6. produkcijski E2E Voice tok: microphone permission, record/stop/cancel, provjera trajanja i AAC/M4A formata, lokalni preview, AES-GCM enkripcija, upload progress, autorizovani ciphertext download, lokalna autentifikacija/dekripcija te play/pause/seek UI;
7. produkcijski E2E Video tok: Camera ili Gallery izbor, lokalna provjera MP4/MOV/WebM formata, veličine i trajanja, preview, AES-GCM enkripcija, upload progress, autorizovani ciphertext download, lokalna autentifikacija/dekripcija i playback sa seek/progress kontrolama.

Nove tekstualne, image, voice i video poruke sa mobilnog chat ekrana više ne koriste legacy plaintext/media endpoint. Slanje se prekida ako E2E priprema nije uspješna; nema automatskog fallbacka na plaintext. Postojeće `EncryptionVersion = 0` poruke i slike ostaju čitljive i jasno označene kao legacy.

Sva četiri privatna tipa poruke sada imaju klijentski E2E tok. Završna hardening faza uklanja legacy plaintext write ugovor iz API-ja i Flutter repository-ja, zadržava samo čitanje postojeće `EncryptionVersion = 0` historije i uvodi objedinjeni test `scripts/test-review-e2e-multimedia-chat.sh`.

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

## Flutter E2E Image orkestracija

Mobilni image tok koristi isti `E2EChatCoordinator` i conversation key kao E2E Text, ali čisti image bajtovi nikada ne ulaze u repository request. Tok slanja je:

1. korisnik bira sliku iz galerije;
2. klijent prije mrežnog poziva provjerava maksimalnu veličinu i JPEG, PNG ili WebP magic bytes;
3. Flutter image codec pokušava dekodirati sliku, čime se odbijaju oštećeni ili samo preimenovani fajlovi;
4. coordinator pravi defensive kopiju čistih bajtova i lokalno ih enkriptuje kao `E2EPrivateMessageType.image`;
5. repository šalje samo `ciphertext || authenticationTag`, nonce, sender device-key ID i key version;
6. ciphertext se šalje pod generičkim nazivom `.bin` i MIME tipom `application/octet-stream`, pa server ne dobija originalni naziv, MIME ni magic bytes slike;
7. klijent provjerava da backend response ne sadrži `Content`, `EncryptedContent` ili text nonce i da attachment metadata tačno odgovara poslanom ciphertextu.

Tok prijema je:

1. chat dobija samo E2E attachment metadata;
2. `EncryptedImagePayload` prikazuje loading stanje, ne sliku;
3. participant-autorizovani media endpoint vraća ciphertext bajtove;
4. klijent provjerava veličinu i metadata ugovor;
5. conversation key se učitava ili lokalno oporavlja iz envelope-a;
6. AES-256-GCM authentication i dekripcija izvršavaju se lokalno, uz `Image` message type u associated data;
7. dekriptovani bajtovi ponovo prolaze magic-byte validaciju;
8. `Image.memory` dobija clear bytes tek nakon uspješne autentifikacije; failure stanje nudi eksplicitni Retry.

Promijenjen ciphertext, nonce, conversation ID, key version ili media type ne proizvodi djelimičan prikaz. Authentication mora potpuno uspjeti prije nego što widget dobije clear bytes. Uspješno poslana vlastita slika privremeno se kešira samo u memoriji procesa radi trenutnog prikaza; nije zapisana u obični lokalni storage.

## Flutter E2E Voice orkestracija

Produkcijski E2E Voice tok koristi iste device ključeve, conversation key i `/messages/e2e` endpoint kao Text i Image, ali dodaje Android snimanje i lokalnu reprodukciju. Mobilna aplikacija koristi:

- `record` za microphone permission i AAC-LC snimanje;
- `path_provider` za privatni privremeni direktorij aplikacije;
- `just_audio` za lokalni preview i reprodukciju dekriptovanih poruka.

Android manifest traži `android.permission.RECORD_AUDIO`, a minimalni Android SDK je 23, što odgovara zahtjevu recorder plugina. Voice poruka je ograničena na 0,3 sekunde do 5 minuta i na postojeću maksimalnu clear-media veličinu od 25 MiB.

Tok snimanja je:

1. korisnik pritisne microphone dugme;
2. aplikacija traži microphone permission i odbija početak ako permission nije odobren;
3. `VoiceRecordingService` snima mono AAC-LC u privremeni `.m4a` fajl;
4. UI prikazuje proteklo vrijeme, `Stop` i `Cancel`, a na pet minuta automatski finalizira snimak;
5. `Stop` učitava fajl, dekoderom određuje stvarno trajanje i lokalno provjerava AAC/M4A signature, veličinu i dozvoljeno trajanje;
6. `VoiceDraftPreview` omogućava play/pause, seek/progress i uklanjanje snimka prije slanja;
7. `Cancel` ili uklanjanje previewa briše privremeni clear fajl.

Tok slanja je:

1. coordinator pravi defensive kopiju clear audio bajtova i ponavlja lokalnu validaciju;
2. audio se enkriptuje AES-256-GCM algoritmom kao `E2EPrivateMessageType.voice`;
3. trajanje u milisekundama ulazi u AEAD associated data, pa server ili napadač ne može promijeniti duration bez authentication greške;
4. repository šalje isključivo `ciphertext || authenticationTag`, nonce, sender device-key ID, key version i duration;
5. ciphertext se šalje kao generički `.bin` fajl sa `application/octet-stream` MIME tipom;
6. Dio `onSendProgress` iz Dio klijenta prikazuje stvarni upload progress;
7. klijent prihvata send response samo ako ciphertext metadata, nonce, tip, key version i duration odgovaraju originalnom requestu;
8. nakon uspješnog slanja clear draft fajl se briše.

Tok prijema i reprodukcije je:

1. `EncryptedVoicePayload` prvo prikazuje loading stanje, bez playera i bez clear audio sadržaja;
2. participant-autorizovani media endpoint vraća ciphertext;
3. coordinator provjerava URL, MIME, veličinu, nonce, encryption version, key version i obavezni duration;
4. AES-GCM authentication/dekripcija se izvršava lokalno uz Voice tip i duration u associated data;
5. dekriptovani bajtovi ponovo prolaze AAC/M4A i duration validaciju;
6. tek nakon uspjeha clear bytes se zapisuju u privatni temporary direktorij i predaju audio playeru;
7. widget pruža play/pause, seek slider, elapsed/total progress i Retry nakon download, authentication ili playback greške;
8. privremeni dekriptovani fajl briše se pri retry-u ili dispose-u widgeta.

Server zato može vidjeti tip poruke, ciphertext veličinu i trajanje, ali ne vidi audio codec header, originalne audio bajtove, conversation key niti privatni device ključ. Potpuna zaštita clear temporary fajla od iznenadnog prekida procesa zavisi od zaštite aplikacijskog sandboxa; normalni UI lifecycle fajl eksplicitno briše.

## Flutter E2E Video orkestracija

Produkcijski E2E Video tok koristi isti device-key, conversation-key i ciphertext API ugovor kao ostali privatni tipovi. Mobilna aplikacija koristi `image_picker` za izbor videa iz galerije ili pokretanje sistemske kamere, `video_player` za lokalnu provjeru i playback, te `path_provider` za privatne privremene fajlove.

Video poruka je ograničena na 0,3 sekunde do 2 minute i na postojeću maksimalnu clear-media veličinu. Podržani lokalni kontejneri su MP4, QuickTime MOV i WebM, prepoznati po magic bytes potpisu prije bilo kakvog mrežnog poziva.

Tok izbora i previewa je:

1. attachment meni nudi image iz galerije, video iz galerije ili snimanje videa sistemskom kamerom;
2. `VideoSelectionService` traži video sa maksimalnim dozvoljenim trajanjem;
3. klijent prije kopiranja provjerava veličinu, zatim učitava bajtove i provjerava `ftyp` ili EBML potpis;
4. odabrani video se kopira u privatni temporary direktorij kojim upravlja aplikacija;
5. `video_player` dekodira fajl i daje stvarno trajanje, nakon čega se ponavljaju duration/size/format provjere;
6. `VideoDraftPreview` omogućava play/pause, seek/progress i uklanjanje videa prije slanja;
7. cancel, zamjena ili uspješno slanje brišu privremeni clear draft fajl.

Tok slanja je:

1. coordinator pravi defensive kopiju clear video bajtova i ponavlja lokalnu validaciju;
2. video se enkriptuje AES-256-GCM algoritmom kao `E2EPrivateMessageType.video`;
3. trajanje u milisekundama je dio authenticated associated data, pa promjena duration metadata uzrokuje authentication failure;
4. repository šalje samo `ciphertext || authenticationTag`, nonce, sender device-key ID, key version i duration;
5. server dobija generički `.bin` attachment sa `application/octet-stream` MIME tipom;
6. upload callback prikazuje progres ciphertext uploada;
7. klijent prihvata response samo kada type, ciphertext veličina, nonce, key version i duration odgovaraju requestu;
8. lokalni clear draft se briše poslije uspješnog slanja.

Tok prijema i playbacka je:

1. `EncryptedVideoPayload` prikazuje download/authentication loading stanje, bez video framea;
2. participant-autorizovani endpoint vraća ciphertext;
3. coordinator provjerava URL, MIME, veličinu, nonce, encryption version, key version i obavezni duration;
4. AES-GCM authentication/dekripcija izvršava se lokalno uz Video tip i duration u associated data;
5. dekriptovani bajtovi ponovo prolaze MP4/MOV/WebM, size i duration provjeru;
6. tek nakon uspješne autentifikacije clear bytes se zapisuju u privatni temporary fajl i predaju playeru;
7. dekodirano trajanje mora odgovarati autentifikovanom trajanju uz malu toleranciju kontejnera;
8. widget nudi play/pause, seek/progress i Retry nakon download, authentication, decoding ili playback greške;
9. dekriptovani playback fajl briše se pri retry-u i dispose-u widgeta.

Server zato ne vidi originalni kontejner, codec header, video frameove, naziv fajla, conversation key niti privatni device ključ. Kao i kod voice poruke, zaštita od naglog prekida procesa oslanja se i na Android aplikacijski sandbox, dok normalni lifecycle eksplicitno čisti temporary fajlove.

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

## Legacy historija i uklonjena plaintext write putanja

Postojeće `EncryptionVersion = 0` poruke i legacy image attachmenti ostaju dostupni participantima kroz isti paginirani read endpoint. To je read-only kompatibilnost; postojeći plaintext se ne prepisuje serverskom enkripcijom i ne označava kao E2E.

Produkcijski write ugovor više ne sadrži:

- `POST /api/conversations/{conversationId}/messages`;
- `SendMessageForm`;
- `SendMessageCommand` i `IChatService.SendMessageAsync()`;
- Flutter `ChatRepository.sendMessage()`.

Pošto GET ruta za historiju ostaje, pokušaj POST zahtjeva na staru putanju završava sa HTTP 405 i ne kreira poruku, attachment ni notifikaciju. Jedina javna write putanja za privatni korisnički sadržaj je `/messages/e2e`, koja ne prima plaintext polje.

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
- dozvoljeni tip poruke, veličine nonce-a i obavezna media polja;
- Voice trajanje od 0,3 sekunde do 5 minuta i Video trajanje od 0,3 sekunde do 2 minute, usklađeno sa mobilnim validatorima.

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

Objedinjena završna provjera builda, testova, EF snapshot-a, Docker runtimea, legacy-write zabrane, autorizacije, notifikacija i SQL ciphertext invarianti:

```bash
bash scripts/test-review-e2e-multimedia-chat.sh http://localhost:5001
```

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

Produkcijski E2E Image tok:

```bash
bash scripts/test-review-e2e-chat-image.sh
```

Produkcijski E2E Voice tok:

```bash
bash scripts/test-review-e2e-chat-voice.sh
```

Produkcijski E2E Video tok:

```bash
bash scripts/test-review-e2e-chat-video.sh
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

Image testovi dodatno provjeravaju:

- lokalno prepoznavanje JPEG, PNG i WebP magic bytes i odbijanje preimenovanog ne-image fajla;
- Alice uploaduje samo ciphertext, a Bob dobija identične clear image bajtove tek nakon lokalne dekripcije;
- poznati image plaintext marker nije prisutan u serverskom attachment storage-u;
- promijenjen attachment ciphertext ili nonce pada na AES-GCM authentication provjeri;
- pogrešan server MIME/metadata response se odbija;
- razlika između deklarisane i preuzete ciphertext veličine se odbija prije dekripcije;
- E2E Image zapis sa plaintext sadržajem se odbija prije download poziva;
- UI ne kreira `Image.memory` prije završetka autentifikovanog loadera i nudi Retry nakon greške;
- produkcijski chat ekran ne poziva legacy `sendMessage` za novu sliku.

Voice testovi dodatno provjeravaju:

- lokalnu AAC/M4A signature, minimal-duration, maksimal-duration i maksimal-size validaciju;
- Alice šalje isključivo encrypted voice bytes, a Bob dobija iste clear audio bajtove tek nakon lokalne dekripcije;
- upload progress callback dobija prenesene i ukupne ciphertext bajtove;
- poznati voice plaintext marker nije prisutan u serverskom attachment storage-u;
- promijenjen ciphertext ili nonce pada na AES-GCM authentication provjeri;
- promijenjeni duration pada jer je duration dio authenticated associated data;
- nedostajući ili promijenjeni duration u backend responseu se odbija prije playbacka;
- nevalidan lokalni voice fajl se odbija prije kriptografskog i mrežnog rada;
- UI ne prikazuje Play prije uspješnog download/decrypt toka, pruža Retry i podržava play/pause/seek/progress;
- Android konfiguracija sadrži microphone permission i minimalni SDK koji podržava recorder plugin;
- produkcijski chat ekran nema legacy voice fallback.

Video testovi dodatno provjeravaju:

- lokalno prepoznavanje MP4, QuickTime MOV i WebM potpisa i odbijanje preimenovanog ne-video fajla;
- izbor iz Camera ili Gallery toka i prosljeđivanje maksimalnog trajanja pickeru;
- Alice šalje isključivo encrypted video bytes, a Bob dobija identične clear bajtove tek nakon lokalne dekripcije;
- poznati video plaintext marker nije prisutan u serverskom attachment storage-u;
- upload progress callback dobija prenesene i ukupne ciphertext bajtove;
- promijenjen ciphertext ili duration pada na AES-GCM authentication provjeri;
- nedostajući ili promijenjeni duration u backend responseu se odbija;
- nevalidan lokalni video se odbija prije device registration, crypto i network rada;
- UI ne prikazuje video frame niti Play prije uspješnog download/decrypt i decode toka;
- Retry ponavlja ciphertext download, a play/pause/seek/progress rade tek nad lokalnim clear temporary fajlom;
- produkcijski chat ekran nema legacy video fallback.

## Ograničenja i svjesne granice protokola

E2E Text, E2E Image, E2E Voice i E2E Video tokovi su aktivni. Preostala ograničenja protokola i uređaja su:

- nema korisničkog interfejsa za opoziv izgubljenog uređaja; `RevokedAtUtc` ostaje spreman za kasniji device-management tok;
- novi uređaj ne može sam otvoriti historijski conversation key ako još nema svoj envelope; najmanje jedan postojeći uređaj koji već posjeduje ključ mora otvoriti razgovor i kreirati envelope za novi uređaj;
- nema ručne key-rotation akcije niti migracije postojećih legacy poruka;
- protokol koristi verzionisani conversation key, a ne Double Ratchet, pa ne obećava per-message forward secrecy;
- TOFU otkriva promjenu nakon prvog kontakta, ali nema out-of-band safety-number verifikaciju.

Legacy plaintext write endpoint je uklonjen. Kompatibilnost se odnosi samo na čitanje već postojećih `EncryptionVersion = 0` zapisa; novi Text, Image, Voice i Video sadržaj može nastati samo kroz ciphertext endpoint. Objedinjeni završni smoke test dodatno pokušava poslati poznati plaintext marker starom rutom, očekuje HTTP 405 i SQL provjerom potvrđuje da marker nije upisan u poruke ni notifikacije.
