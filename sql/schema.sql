-- PagePulse PostgreSQL schema
-- Run this file before loading data/cleaned_data/books_data.csv.

CREATE SCHEMA IF NOT EXISTS pagepulse;

CREATE TABLE IF NOT EXISTS pagepulse.books_data (
    book_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_names TEXT NOT NULL,
    availability TEXT NOT NULL,
    ratings SMALLINT NOT NULL,
    prices NUMERIC(10, 2) NOT NULL,
    categories TEXT NOT NULL,
    book_urls TEXT NOT NULL UNIQUE,
    book_images TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT books_data_rating_valid
        CHECK (ratings BETWEEN 1 AND 5),
    CONSTRAINT books_data_price_valid
        CHECK (prices >= 0),
    CONSTRAINT books_data_name_not_blank
        CHECK (BTRIM(book_names) <> ''),
    CONSTRAINT books_data_category_not_blank
        CHECK (BTRIM(categories) <> ''),
    CONSTRAINT books_data_url_not_blank
        CHECK (BTRIM(book_urls) <> '')
);

-- These indexes support the most common category, rating, price, and stock analyses.
CREATE INDEX IF NOT EXISTS idx_books_data_category
    ON pagepulse.books_data (categories);

CREATE INDEX IF NOT EXISTS idx_books_data_rating
    ON pagepulse.books_data (ratings);

CREATE INDEX IF NOT EXISTS idx_books_data_price
    ON pagepulse.books_data (prices);

CREATE INDEX IF NOT EXISTS idx_books_data_availability
    ON pagepulse.books_data (availability);
