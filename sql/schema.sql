-- PagePulse PostgreSQL schema
-- Run this file before loading data/cleaned_data/books_data.csv.

CREATE SCHEMA IF NOT EXISTS pagepulse;

CREATE TABLE IF NOT EXISTS pagepulse.books_data (
    book_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_names TEXT NOT NULL,
    availability INTEGER NOT NULL,
    ratings SMALLINT NOT NULL,
    prices NUMERIC(10, 2) NOT NULL,
    categories TEXT NOT NULL,
    book_urls TEXT NOT NULL UNIQUE,
    book_images TEXT,
    source_website TEXT NOT NULL,
    scraped_at TIMESTAMPTZ NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT books_data_rating_valid
        CHECK (ratings BETWEEN 1 AND 5),
    CONSTRAINT books_data_price_valid
        CHECK (prices >= 0),
    CONSTRAINT books_data_availability_valid
        CHECK (availability >= 0),
    CONSTRAINT books_data_name_not_blank
        CHECK (BTRIM(book_names) <> ''),
    CONSTRAINT books_data_category_not_blank
        CHECK (BTRIM(categories) <> ''),
    CONSTRAINT books_data_url_not_blank
        CHECK (BTRIM(book_urls) <> ''),
    CONSTRAINT books_data_source_not_blank
        CHECK (BTRIM(source_website) <> '')
);

-- Convert availability from older text values such as
-- "In stock (22 available)" when upgrading an existing table.
ALTER TABLE pagepulse.books_data
    ALTER COLUMN availability TYPE INTEGER
    USING CASE
        WHEN availability::TEXT ~ '[0-9]+'
            THEN SUBSTRING(availability::TEXT FROM '[0-9]+')::INTEGER
        ELSE 0
    END;

-- Upgrade tables created before source metadata was introduced.
ALTER TABLE pagepulse.books_data
    ADD COLUMN IF NOT EXISTS source_website TEXT NOT NULL
        DEFAULT 'https://books.toscrape.com/';

ALTER TABLE pagepulse.books_data
    ADD COLUMN IF NOT EXISTS scraped_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP;

-- These indexes support category, rating, price, and inventory analysis.
CREATE INDEX IF NOT EXISTS idx_books_data_category
    ON pagepulse.books_data (categories);

CREATE INDEX IF NOT EXISTS idx_books_data_rating
    ON pagepulse.books_data (ratings);

CREATE INDEX IF NOT EXISTS idx_books_data_price
    ON pagepulse.books_data (prices);

CREATE INDEX IF NOT EXISTS idx_books_data_availability
    ON pagepulse.books_data (availability);
