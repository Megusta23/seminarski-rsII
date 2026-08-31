# Dorade nakon reviewa — faza 1: konzistentnost task domene

Ovaj dokument opisuje implementaciju stavki 3–7 iz reviewa seminarskog rada.
Cilj je da recurrence, status taska, datum completiona i statistika imaju jednu
poslovnu definiciju u cijelom sistemu.

## 1. Podržani recurrence kodovi

Semantički recurrence kod je ograničen na četiri vrijednosti:

```text
none
daily
weekly
monthly
```

Administrator i dalje ima CRUD nad referentnom tabelom, ali ne može kreirati
proizvoljan kod koji ostatak sistema ne razumije. Kod postojećeg podržanog reda
je nepromjenjiv; administrator može mijenjati naziv, redoslijed i aktivno stanje.

Serverski izvor istine je `RecurrenceCodes`. `RecurrenceRuleService` je jedino
mjesto koje određuje:

- recurrence anchor;
- da li je task zakazan određenog dana;
- da li je completion datum dozvoljen;
- koje completion datume mobilna aplikacija smije ponuditi.

## 2. Recurrence anchor i validni datumi

Pravila su:

- `none`: completion je moguć od datuma kreiranja do trenutnog business datuma;
- `daily`: svaki datum od kreiranja do business datuma;
- `weekly`: anchor je deadline kada postoji, inače datum kreiranja; validni su
  anchor i svaki naredni datum udaljen `7n` dana;
- `monthly`: anchor je deadline kada postoji, inače datum kreiranja; validan je
  isti dan u mjesecu na ili poslije anchora. Mjesec koji nema taj dan nema
  occurrence.

Svaki recurring completion prije anchora se odbija. Budući completion se uvijek
odbija na backendu.

Endpoint:

```http
GET /api/tasks/{taskId}/completion-date-options
```

vraća:

```text
businessDate
recurrenceAnchorDate
recurrenceCode
allowedDates
```

Mobilni date picker koristi samo `allowedDates`, pa korisniku ne prikazuje datum
koji će backend kasnije odbiti.

## 3. UTC business datum

Za ovu fazu je izabrana jedna globalna definicija:

```text
business datum = kalendarski datum vrijednosti UtcNow
```

Backend je izvor istine i vraća `businessDate` kroz task DTO i completion-date
endpoint. Mobilni To-do koristi taj datum za quick-complete i oznake roka.
Feed i leaderboard koriste isti UTC kalendarski datum kao podrazumijevani
"danas". DateOnly vrijednosti se serijalizuju bez lokalne time-zone konverzije.

Ova odluka izbjegava situaciju oko ponoći u kojoj Flutter smatra datum današnjim,
a backend budućim. Ako se kasnije uvede korisnička vremenska zona, ona mora
zamijeniti ovu definiciju na jednom centralnom mjestu.

## 4. Kontrolisani statusi taska

`TaskStateMachine` centralizuje status pravila.

Dozvoljeni obični edit tokovi:

```text
Active    -> Active / Cancelled / Archived
Cancelled -> Active / Cancelled / Archived
```

Terminalna stanja:

```text
Completed
Archived
```

`Completed` se može postići samo kroz completion endpoint, ne kroz obični PUT.
Completed task se ne može vratiti na Active kroz edit formu. Flutter koristi
serverska polja `canEdit`, `canComplete` i `allowedEditStatuses`, zbog čega ne
prikazuje nevažeću edit formu za terminalni task.

Numerički status koji nije definisan u `TaskItemStatus` vraća HTTP 400.

## 5. OccurrenceDate i CompletedAtUtc

Polja više nemaju isto značenje:

```text
OccurrenceDate  = poslovni dan za koji se task računa
CompletedAtUtc  = stvarni UTC trenutak kada je korisnik evidentirao completion
```

Primjer: ako korisnik danas evidentira jučerašnji task, `OccurrenceDate` je
jučer, a `CompletedAtUtc` je trenutni `UtcNow`.

Upotreba:

- streak, leaderboard i periodični productivity izvještaji koriste
  `OccurrenceDate`;
- recent activity, audit i redoslijed evidencije koriste `CompletedAtUtc`.

## 6. Historijska statistika i soft delete

`CompletionStatisticsService` je centralni servis za:

- ukupan broj completiona;
- trenutni streak;
- broj completiona u periodu;
- leaderboard score;
- top korisnike.

Servis direktno čita `TaskCompletions`, bez join-a na trenutno aktivne taskove.
Soft delete uklanja task iz budućeg rada, feeda i drugih socijalnih prikaza, ali
ne briše historijsku činjenicu da je occurrence ranije završen.

Isti servis koriste:

```text
Own profile
Friend profile
Friends lista
Feed streak
Leaderboard
Admin dashboard
Admin user pregled
Activity report
User report
```

Streak nema proizvoljni plafon od 366 dana. Ako je niz completion datuma duži,
prikazuje se stvarna vrijednost.

## 7. Testiranje

Unit testovi pokrivaju:

- weekly i monthly datume prije/poslije anchora;
- nepodržan recurrence kod;
- isključivanje budućih i već završenih occurrence datuma;
- terminalni Completed status;
- nepoznat numerički status;
- streak duži od 366 dana;
- UTC DateOnly serijalizaciju.

Integracijska smoke skripta:

```bash
./scripts/test-review-task-domain.sh
```

provjerava recurrence CRUD ograničenja, completion-date opcije, buduće i
pre-anchor datume, state machine, stvarni `CompletedAtUtc` za backdated zapis i
očuvanje historijske statistike nakon soft delete-a.
