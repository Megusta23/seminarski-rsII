# Ladder Social

Ladder Social je društvena aplikacija usmjerena na produktivnost, razvijena u okviru predmeta Razvoj softvera II.

Sistem se sastoji od:

* Flutter Android mobilne aplikacije
* Flutter Windows administratorske desktop aplikacije
* ASP.NET Core Web API-ja
* SQL Server baze podataka
* RabbitMQ servisa i odvojenog Worker mikroservisa
* Docker Compose okruženja

## Glavne funkcionalnosti

### Mobilna aplikacija

* Registracija, prijava, reset lozinke i upravljanje profilom
* Upravljanje jednokratnim, dnevnim i ponavljajućim zadacima
* Završavanje zadataka uz opcionalnu dokaznu fotografiju
* Feed aktivnosti prijatelja i izdvojene objave
* Zahtjevi za prijateljstvo, pretraga korisnika i preporuke
* Dnevna i sedmična rang-lista
* Sistemske obavijesti
* Tekstualni chat i slanje slika
* Vlastiti profil i profili prijatelja

### Desktop aplikacija

* Administratorska autentifikacija
* Analitički dashboard
* Pretraga i detaljan pregled korisnika
* Aktivacija i deaktivacija korisnika
* CRUD operacije nad referentnim podacima
* Moderacija objava
* PDF izvještaj o aktivnostima aplikacije
* PDF izvještaj za pojedinačnog korisnika

## Preduslovi

Za pokretanje kompletnog sistema potrebni su:

* Docker Desktop
* Android emulator za mobilni APK
* Windows x64 okruženje za desktop aplikaciju

Flutter i .NET SDK potrebni su samo za izgradnju ili izmjenu izvornog koda.

## Podešavanje konfiguracije

Šifrovana konfiguracija okruženja nalazi se u arhivi:

```text
.env-tajne.zip
```

Arhivu treba raspakovati u korijenski direktorij repozitorija tako da postoji datoteka:

```text
.env
```

Šifra arhive dostavlja se odvojeno putem DLWMS-a.

Raspakovanu `.env` datoteku nije dozvoljeno commitovati niti javno dijeliti.

## Pokretanje backend sistema

Iz korijenskog direktorija repozitorija pokrenuti:

```bash
docker compose --env-file .env up --build -d
```

Provjera statusa kontejnera:

```bash
docker compose --env-file .env ps
```

Provjera dostupnosti API-ja:

```text
http://localhost:5001/api/health
```

Dodatni servisi:

```text
RabbitMQ Management: http://localhost:15672
smtp4dev:            http://localhost:5002
```

API automatski primjenjuje EF Core migracije. Kada je uključena sljedeća postavka, automatski se kreiraju i realistični demonstracijski podaci:

```env
SEED_DEMO_DATA=true
```

## Testni pristupni podaci

### Mobilni korisnik

```text
E-mail: mobile@laddersocial.local
Lozinka: Mobile_Test_220087!
Uloga: User
```

### Desktop administrator

```text
E-mail: admin@laddersocial.local
Lozinka: Admin_Test_220087!
Uloga: Admin
```

## Pokretanje Android aplikacije

Release APK nalazi se unutar GitHub Release arhive na putanji:

```text
apps/ladder_social_mobile/build/app/outputs/flutter-apk/app-release.apk
```

Pokrenuti Android emulator i instalirati APK:

```bash
adb install -r app-release.apk
```

Android aplikacija pristupa API-ju putem adrese:

```text
http://10.0.2.2:5001
```

Pokretanje mobilne aplikacije iz izvornog koda:

```bash
cd apps/ladder_social_mobile

flutter pub get

flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

## Pokretanje Windows administratorske aplikacije

Raspakovati kompletan direktorij:

```text
apps/ladder_social_admin/build/windows/x64/runner/Release/
```

Sve datoteke iz direktorija moraju ostati zajedno. Zatim pokrenuti:

```text
ladder_social_admin.exe
```

Windows aplikacija očekuje API na adresi:

```text
http://localhost:5001
```

Pokretanje desktop aplikacije iz izvornog koda na Windowsu:

```powershell
cd apps\ladder_social_admin

flutter pub get

flutter run -d windows `
  --dart-define=API_BASE_URL=http://localhost:5001
```

## Kreiranje release buildova

### Android

```bash
cd apps/ladder_social_mobile

flutter clean
flutter pub get

flutter build apk \
  --release \
  --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

### Windows

```powershell
cd apps\ladder_social_admin

flutter clean
flutter pub get

flutter build windows --release `
  --dart-define=API_BASE_URL=http://localhost:5001
```

## Testiranje

Backend i opšta provjera projekta:

```bash
dotnet test LadderSocial.sln
./scripts/verify-source.sh
```

Dostupne smoke-test skripte nalaze se u direktoriju:

```text
scripts/
```

Primjeri:

```bash
./scripts/test-auth.sh
./scripts/test-demo-seed.sh
./scripts/test-tasks.sh
./scripts/test-feed-v2.sh
./scripts/test-admin-reports.sh
```

## Sistem preporuke

Preporuka prijatelja zasniva se na grafovskom algoritmu „friend-of-friend“. Kandidati se rangiraju prema broju zajedničkih prijatelja, dok se postojeći prijatelji i korisnici s aktivnim zahtjevima za prijateljstvo isključuju iz rezultata.

Detaljna dokumentacija dostupna je u datoteci:

```text
recommender-dokumentacija.md
```

## Korisne komande

Zaustavljanje sistema uz zadržavanje podataka:

```bash
docker compose --env-file .env down
```

Pregled API logova:

```bash
docker compose --env-file .env logs -f api
```

Pregled Worker logova:

```bash
docker compose --env-file .env logs -f worker
```

Potpuno brisanje lokalnih Docker podataka koristiti samo kada se namjerno želi kreirati nova baza:

```bash
docker compose --env-file .env down -v
```
