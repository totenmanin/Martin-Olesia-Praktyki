# Martin-Olesia-Praktyki chyba bez olesi ale za to szymonito szefito jest


# Nasdaq Scraper

Collector pobiera dzienne notowania spółek Nasdaq (Yahoo Finance, biblioteka `yfinance`), wykrywa wzorce
wzrostu i spadku i zapisuje dane do MySQL/MariaDB w jak najlżejszej formie. Osobne API tylko do odczytu
(FastAPI) udostępnia dane innym aplikacjom.

```
Yahoo Finance --> collector --(INSERT/UPDATE)--> MySQL <--(SELECT)-- API (FastAPI) <-- aplikacje
                  (osobny proces)              (port nie na zewnątrz)  (klucze API, limity)
```

## Uruchomienie na XAMPP (bez Dockera)

1. W XAMPP uruchom **MySQL**. Wymagany Python 3.11+.
2. Otwórz `db/nasdaq.sql`, zmień oba hasła (`ZMIEN_HASLO_...`), potem w phpMyAdmin
   (`http://localhost/phpmyadmin`) wybierz **Import** i wgraj plik. Powstanie baza `nasdaq_db`, 3 tabele i 2 użytkownicy.
3. W folderze projektu (PowerShell):
   ```
   python -m venv .venv
   .venv\Scripts\activate
   pip install -r requirements.txt
   copy .env.example .env
   python scripts/make_api_key.py moja_aplikacja
   ```
   Linię `nazwa:hash` wpisz do `API_KEYS` w `.env`. Jeśli MySQL w XAMPP ma port inny niż 3306, dodaj `DB_PORT=...`.
4. **Collector** (pobiera dane, jednorazowo; z `--daemon` robi to codziennie o `RUN_AT_UTC`):
   ```
   $env:DB_USER="nasdaq_collector"; $env:DB_PASSWORD="TWOJE_HASLO_COLLECTOR"
   python -m app.collector
   ```
   Szybki test na kilku spółkach: `python -m app.collector AAPL MSFT NVDA`
5. **API** (drugi terminal):
   ```
   $env:DB_USER="nasdaq_api_ro"; $env:DB_PASSWORD="TWOJE_HASLO_API"
   uvicorn app.api:app --port 8001
   ```
6. Test: `curl -H "X-API-Key: TWOJ_KLUCZ" http://127.0.0.1:8001/api/v1/prices/latest`

## Uruchomienie w Dockerze

`copy .env.example .env`, uzupełnij hasła i `API_KEYS`, potem `docker compose up -d --build`.
API działa na `127.0.0.1:8001` (8001, żeby nie kolidować z projektem crypto na 8000).

## Endpointy (nagłówek `X-API-Key` wymagany poza `/health`)

| Endpoint | Opis |
|---|---|
| `GET /health` | status API i bazy |
| `GET /api/v1/stocks` | lista spółek |
| `GET /api/v1/prices/latest[?ticker=AAPL]` | ostatnia sesja |
| `GET /api/v1/stocks/{ticker}/prices?start_date=&end_date=&limit=` | historia notowań |
| `GET /api/v1/stocks/{ticker}/patterns?start_date=&end_date=&limit=` | wykryte wzorce |
| `GET /api/v1/stocks/{ticker}/analysis` | trend, RSI, SMA, zmiany %, wzorce z ostatniej sesji |

Swagger (`/docs`) jest domyślnie wyłączony (`ENABLE_DOCS=true`, żeby włączyć).

## Wykrywane wzorce

`BIG_RISE/BIG_DROP` (dzienny ruch ≥ 3%), `GAP_UP/GAP_DOWN` (luka przy otwarciu ≥ 2%),
`STREAK_UP/DOWN` (5 sesji z rzędu), `SMA_CROSS_UP/DOWN` (SMA 20 vs 50), `BREAKOUT_UP/DOWN`
(wybicie z zakresu 20 sesji), `VOLUME_SPIKE` (wolumen ≥ 2× średnia), `RSI_OVERBOUGHT/OVERSOLD`.
Progi zmienisz w `.env` / `app/config.py`. To proste wskaźniki edukacyjne, nie porada inwestycyjna.

## Jak dane są przechowywane lekko

- Ticker i nazwa raz w `stocks`; w notowaniach 2-bajtowe `stock_id` (było `BIGINT`, 8 B).
- Ceny jako liczby całkowite (cena × 10000, `INT UNSIGNED`, 4 B) zamiast `DECIMAL(12,4)` (6 B) - dokładnie i bez błędów zaokrągleń.
- Jeden indeks na tabelę: klucz główny `(stock_id, trade_date)`. Bez kolumny `id`, bez dodatkowego indeksu na dacie i bez klucza obcego.
- Wzorce w tabeli `signals` jako kod 1 B, zapisujemy tylko zdarzenia; trend i % zmiany liczy API.
- Szacunek: ~25 B danych na sesję (było ~50 B + 2 dodatkowe indeksy), czyli kilka razy mniej miejsca. Dla 30 spółek to ułamek MB
  rocznie. Zmierz u siebie:
  `SELECT table_name, ROUND((data_length+index_length)/1024,1) AS kb FROM information_schema.tables WHERE table_schema='nasdaq_db';`

## Ważne w danych giełdowych

- Zapisujemy tylko **zakończone sesje** (po 16:15 czasu nowojorskiego); niepełna dzisiejsza świeca jest pomijana.
- Przy każdym pobraniu nadpisujemy cały okres `HISTORY_PERIOD` (upsert). Dzięki temu po splicie akcji ceny w tym okresie
  zostają spójne (inaczej split wyglądałby jak spadek o 90% i dał fałszywy sygnał). Wpisy starsze niż ten okres nie są korygowane.
- Yahoo Finance to nieoficjalne źródło (bez gwarancji); collector robi pauzy między spółkami i nie przerywa się przy błędzie jednej.

## Bezpieczeństwo

Klucze API trzymane jako hash SHA-256 (każdy klient własny), limit zapytań na klucz i blokada po 10 błędnych próbach z IP
(w pamięci procesu - 1 worker), dwóch użytkowników bazy (`nasdaq_collector`: SELECT/INSERT/UPDATE, `nasdaq_api_ro`: tylko SELECT),
port MySQL nie jest wystawiony, walidacja tickerów (regex + baza), błędy bazy nie ujawniają szczegółów, kontener bez roota.

## Testy

```
pip install -r requirements-dev.txt
pytest
```

## Ograniczenia

- Brak migracji (Alembic) - schemat w `db/01-schema.sql`; zapytania w czystym SQL w `app/queries.py`.
- Limity zapytań działają dla jednego procesu API.
- Dane dzienne (nie intraday) - nie ma sensu pobierać częściej niż raz na dobę.
