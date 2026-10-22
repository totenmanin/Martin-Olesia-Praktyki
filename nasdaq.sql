-- =====================================================================
--  GOTOWA BAZA POD NASDAQ SCRAPER  (XAMPP: MariaDB/MySQL, phpMyAdmin)
--  Nazwa bazy: nasdaq_db
--
--  PRZED IMPORTEM zmien oba hasla ponizej (ZMIEN_HASLO_COLLECTOR / ZMIEN_HASLO_API)
--  na swoje - tylko litery i cyfry.
--  Import: phpMyAdmin -> zakladka "Import" -> wybierz ten plik -> "Wykonaj".
-- =====================================================================

CREATE DATABASE IF NOT EXISTS nasdaq_db CHARACTER SET utf8mb4;
USE nasdaq_db;

-- Schemat jak najlzejszy: male typy liczbowe, jeden indeks (klucz glowny) na tabele.
-- Ceny zapisane jako cena * 10000 (INT UNSIGNED, 4 B, dokladnie, bez bledow zaokraglen).

-- Slownik spolek: ticker i nazwa zapisane raz; w notowaniach tylko 2-bajtowe id
CREATE TABLE IF NOT EXISTS stocks (
    id     SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    ticker VARCHAR(16)  NOT NULL,
    name   VARCHAR(100) NULL,
    UNIQUE KEY uq_stocks_ticker (ticker)
) ENGINE=InnoDB;

-- Notowania dzienne (OHLCV). Klucz glowny (stock_id, trade_date) = jedyny indeks.
CREATE TABLE IF NOT EXISTS daily_prices (
    stock_id    SMALLINT UNSIGNED NOT NULL,
    trade_date  DATE NOT NULL,
    open_price  INT UNSIGNED NOT NULL,
    high_price  INT UNSIGNED NOT NULL,
    low_price   INT UNSIGNED NOT NULL,
    close_price INT UNSIGNED NOT NULL,
    volume      INT UNSIGNED NOT NULL,
    PRIMARY KEY (stock_id, trade_date)
) ENGINE=InnoDB;

-- Wykryte wzorce wzrostu/spadku (tylko momenty zdarzen).
-- pattern: 1=STREAK_UP 2=STREAK_DOWN 3=SMA_CROSS_UP 4=SMA_CROSS_DOWN 5=BREAKOUT_UP
--   6=BREAKOUT_DOWN 7=BIG_RISE 8=BIG_DROP 9=GAP_UP 10=GAP_DOWN 11=VOLUME_SPIKE
--   12=RSI_OVERBOUGHT 13=RSI_OVERSOLD
CREATE TABLE IF NOT EXISTS signals (
    stock_id   SMALLINT UNSIGNED NOT NULL,
    trade_date DATE NOT NULL,
    pattern    TINYINT UNSIGNED NOT NULL,
    value      FLOAT NULL,
    PRIMARY KEY (stock_id, trade_date, pattern)
) ENGINE=InnoDB;


-- ---------------------------------------------------------------------
-- Uzytkownicy o minimalnych uprawnieniach (zmien hasla!)
--   nasdaq_collector - zapis (SELECT, INSERT, UPDATE)
--   nasdaq_api_ro    - tylko odczyt (SELECT)
-- ---------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'nasdaq_collector'@'localhost'  IDENTIFIED BY 'ZMIEN_HASLO_COLLECTOR';
CREATE USER IF NOT EXISTS 'nasdaq_collector'@'127.0.0.1'  IDENTIFIED BY 'ZMIEN_HASLO_COLLECTOR';
GRANT SELECT, INSERT, UPDATE ON nasdaq_db.* TO 'nasdaq_collector'@'localhost';
GRANT SELECT, INSERT, UPDATE ON nasdaq_db.* TO 'nasdaq_collector'@'127.0.0.1';

CREATE USER IF NOT EXISTS 'nasdaq_api_ro'@'localhost'  IDENTIFIED BY 'ZMIEN_HASLO_API';
CREATE USER IF NOT EXISTS 'nasdaq_api_ro'@'127.0.0.1'  IDENTIFIED BY 'ZMIEN_HASLO_API';
GRANT SELECT ON nasdaq_db.* TO 'nasdaq_api_ro'@'localhost';
GRANT SELECT ON nasdaq_db.* TO 'nasdaq_api_ro'@'127.0.0.1';

FLUSH PRIVILEGES;
