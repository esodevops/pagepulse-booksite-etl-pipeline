"""PagePulse book catalogue ETL pipeline."""

import argparse
import os
from pathlib import Path
from urllib.parse import urljoin

import pandas as pd
from bs4 import BeautifulSoup
from dotenv import load_dotenv
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from sqlalchemy import URL, create_engine, text


class PagePulsePipeline:
    """Extract, clean, save, and load the Books to Scrape catalogue."""

    RATING_MAP = {
        "One": 1,
        "Two": 2,
        "Three": 3,
        "Four": 4,
        "Five": 5,
    }

    def __init__(self, headless=True):
        self.headless = headless
        self.base_url = "https://books.toscrape.com/"

        self.project_root = Path(__file__).resolve().parents[1]
        self.raw_file = self.project_root / "data/raw_data/books_data.csv"
        self.cleaned_file = self.project_root / "data/cleaned_data/books_data.csv"
        self.schema_file = self.project_root / "sql/schema.sql"

        load_dotenv(self.project_root / ".env")

    def create_driver(self):
        """Create a Chrome browser for the extraction step."""
        options = Options()

        if self.headless:
            options.add_argument("--headless=new")

        options.add_argument("--disable-gpu")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--window-size=1440,1000")

        return webdriver.Chrome(options=options)

    def extract(self):
        """Scrape catalogue and detail pages into a DataFrame."""
        records = []
        driver = self.create_driver()
        page_number = 1
        page_url = urljoin(self.base_url, "catalogue/page-1.html")

        try:
            while page_url:
                driver.get(page_url)
                WebDriverWait(driver, 10).until(
                    EC.presence_of_element_located(
                        (By.CSS_SELECTOR, "article.product_pod")
                    )
                )

                catalogue = BeautifulSoup(driver.page_source, "html.parser")
                books = catalogue.select("article.product_pod")
                next_link = catalogue.select_one("li.next a")
                next_page_url = (
                    urljoin(page_url, next_link.get("href"))
                    if next_link and next_link.get("href")
                    else None
                )

                for book in books:
                    record = self._extract_book_card(book, page_url)
                    record["categories"] = self._extract_category(
                        driver,
                        record["book_urls"],
                    )
                    records.append(record)

                print(
                    f"Extracted page {page_number} ({len(records)} books)"
                )

                page_url = next_page_url
                page_number += 1
        finally:
            driver.quit()

        return pd.DataFrame(records)

    def _extract_book_card(self, book, page_url):
        """Extract fields visible on one catalogue card."""
        title = book.select_one("h3 a")
        price = book.select_one("p.price_color")
        availability = book.select_one("p.instock.availability")
        rating = book.select_one("p.star-rating")
        image = book.select_one("img")

        rating_classes = rating.get("class", []) if rating else []
        rating_word = next(
            (value for value in rating_classes if value != "star-rating"),
            None,
        )

        return {
            "book_names": title.get("title") if title else None,
            "availability": (
                availability.get_text(" ", strip=True)
                if availability
                else None
            ),
            "ratings": rating_word,
            "prices": price.get_text(strip=True) if price else None,
            "categories": None,
            "book_urls": (
                urljoin(page_url, title.get("href"))
                if title and title.get("href")
                else None
            ),
            "book_images": (
                urljoin(page_url, image.get("src"))
                if image and image.get("src")
                else None
            ),
        }

    def _extract_category(self, driver, book_url):
        """Read the category from a book detail page."""
        if not book_url:
            return None

        driver.get(book_url)
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "ul.breadcrumb"))
        )

        detail_page = BeautifulSoup(driver.page_source, "html.parser")
        category = detail_page.select_one("ul.breadcrumb li:nth-of-type(3) a")
        return category.get_text(strip=True) if category else None

    def transform(self, dataframe):
        """Clean values and enforce the expected data types."""
        books = dataframe.copy()

        text_columns = [
            "book_names",
            "availability",
            "categories",
            "book_urls",
            "book_images",
        ]
        for column in text_columns:
            books[column] = books[column].astype("string").str.strip()

        books["prices"] = (
            books["prices"]
            .astype("string")
            .str.replace("£", "", regex=False)
            .str.replace(",", "", regex=False)
        )
        books["prices"] = pd.to_numeric(books["prices"], errors="coerce")

        books["ratings"] = books["ratings"].replace(self.RATING_MAP)
        books["ratings"] = pd.to_numeric(
            books["ratings"],
            errors="coerce",
        )

        required_columns = [
            "book_names",
            "availability",
            "ratings",
            "prices",
            "categories",
            "book_urls",
        ]
        books = books.dropna(subset=required_columns)
        books = books.drop_duplicates(subset="book_urls", keep="first")
        books = books[books["ratings"].between(1, 5)]
        books = books[books["prices"] >= 0]

        books["ratings"] = books["ratings"].astype("int64")
        books["prices"] = books["prices"].round(2)

        return books.reset_index(drop=True)

    def save_csv_files(self, raw_data, cleaned_data):
        """Save raw and cleaned pipeline outputs."""
        self.raw_file.parent.mkdir(parents=True, exist_ok=True)
        self.cleaned_file.parent.mkdir(parents=True, exist_ok=True)

        raw_data.to_csv(self.raw_file, index=False)
        cleaned_data.to_csv(self.cleaned_file, index=False)

        print(f"Raw data saved to {self.raw_file}")
        print(f"Cleaned data saved to {self.cleaned_file}")

    def _database_settings(self):
        """Read and validate PostgreSQL settings from .env."""
        settings = {
            "username": os.getenv("DB_USER"),
            "password": os.getenv("DB_PASSWORD"),
            "host": os.getenv("DB_HOST"),
            "port": os.getenv("DB_PORT", "5432"),
            "database": os.getenv("DB_NAME"),
        }

        missing = [name for name, value in settings.items() if not value]
        if missing:
            raise ValueError(
                "Missing database settings: " + ", ".join(missing)
            )

        return settings

    def create_database_engine(self):
        """Create the database when needed and return its SQLAlchemy engine."""
        settings = self._database_settings()

        admin_url = URL.create(
            "postgresql+psycopg2",
            username=settings["username"],
            password=settings["password"],
            host=settings["host"],
            port=int(settings["port"]),
            database="postgres",
        )
        admin_engine = create_engine(admin_url, isolation_level="AUTOCOMMIT")

        try:
            with admin_engine.connect() as connection:
                exists = connection.execute(
                    text("SELECT 1 FROM pg_database WHERE datname = :name"),
                    {"name": settings["database"]},
                ).scalar()

                if not exists:
                    database_name = (
                        admin_engine.dialect.identifier_preparer.quote_identifier(
                            settings["database"]
                        )
                    )
                    connection.exec_driver_sql(
                        f"CREATE DATABASE {database_name}"
                    )
                    print(f"Created database {settings['database']}")
        finally:
            admin_engine.dispose()

        database_url = URL.create(
            "postgresql+psycopg2",
            username=settings["username"],
            password=settings["password"],
            host=settings["host"],
            port=int(settings["port"]),
            database=settings["database"],
        )
        return create_engine(database_url)

    def load_to_database(self, dataframe):
        """Create the governed table and load the cleaned records."""
        engine = self.create_database_engine()
        schema_sql = self.schema_file.read_text(encoding="utf-8")

        try:
            with engine.begin() as connection:
                connection.exec_driver_sql(schema_sql)
                connection.execute(
                    text(
                        "TRUNCATE TABLE pagepulse.books_data "
                        "RESTART IDENTITY"
                    )
                )
                dataframe.to_sql(
                    "books_data",
                    connection,
                    schema="pagepulse",
                    if_exists="append",
                    index=False,
                )
        finally:
            engine.dispose()

        print(
            f"Loaded {len(dataframe)} books into pagepulse.books_data"
        )

    def run(self, load_database=True):
        """Run the complete PagePulse ETL pipeline."""
        print("Starting PagePulse pipeline")
        raw_data = self.extract()
        cleaned_data = self.transform(raw_data)
        self.save_csv_files(raw_data, cleaned_data)

        if load_database:
            self.load_to_database(cleaned_data)

        # print(f"Pipeline complete: {len(cleaned_data)} clean books")
        return cleaned_data


def main():
    """Run PagePulse from the command line."""
    parser = argparse.ArgumentParser(description="Run the PagePulse ETL pipeline")
    parser.add_argument(
        "--visible",
        action="store_true",
        help="Show Chrome while the scraper runs",
    )
    parser.add_argument(
        "--skip-database",
        action="store_true",
        help="Create CSV files without loading PostgreSQL",
    )
    args = parser.parse_args()

    pipeline = PagePulsePipeline(headless=not args.visible)
    pipeline.run(load_database=not args.skip_database)


if __name__ == "__main__":
    main()
