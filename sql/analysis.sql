-- PagePulse business analytics
-- Each query answers one practical business question and can run independently.

-- 1. What does the current catalogue look like at a glance?
SELECT
    COUNT(*) AS total_books,
    COUNT(DISTINCT categories) AS total_categories,
    ROUND(AVG(prices)::NUMERIC, 2) AS average_price,
    ROUND(AVG(ratings)::NUMERIC, 2) AS average_rating,
    COUNT(*) FILTER (WHERE LOWER(availability) = 'in stock') AS books_in_stock,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE LOWER(availability) = 'in stock')
        / NULLIF(COUNT(*), 0),
        1
    ) AS in_stock_percentage
FROM pagepulse.books_data;


-- 2. Which categories have the largest assortment and how do they perform?
SELECT
    categories AS category,
    COUNT(*) AS number_of_books,
    ROUND(AVG(prices)::NUMERIC, 2) AS average_price,
    ROUND(AVG(ratings)::NUMERIC, 2) AS average_rating,
    COUNT(*) FILTER (WHERE ratings >= 4) AS highly_rated_books
FROM pagepulse.books_data
GROUP BY categories
ORDER BY number_of_books DESC, category;


-- 3. Which books combine strong customer ratings with a premium price?
-- These are candidates for prominent placement or premium promotions.
SELECT
    book_names AS book,
    categories AS category,
    ratings AS rating,
    prices AS price,
    availability
FROM pagepulse.books_data
WHERE ratings >= 4
  AND prices > (SELECT AVG(prices) FROM pagepulse.books_data)
  AND LOWER(availability) = 'in stock'
ORDER BY rating DESC, price DESC, book;


-- 4. Which highly rated books offer customers the best value?
-- A simple value pick has a 4- or 5-star rating and costs no more than £25.
SELECT
    book_names AS book,
    categories AS category,
    ratings AS rating,
    prices AS price
FROM pagepulse.books_data
WHERE ratings >= 4
  AND prices <= 25
  AND LOWER(availability) = 'in stock'
ORDER BY price, rating DESC, book;


-- 5. How is the catalogue distributed across customer rating levels?
SELECT
    ratings AS rating,
    COUNT(*) AS number_of_books,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS catalogue_percentage
FROM pagepulse.books_data
GROUP BY ratings
ORDER BY rating DESC;


-- 6. How much of the catalogue sits in each price band?
SELECT
    CASE
        WHEN prices < 20 THEN 'Budget: under £20'
        WHEN prices < 40 THEN 'Mid-range: £20–£39.99'
        ELSE 'Premium: £40 and above'
    END AS price_band,
    COUNT(*) AS number_of_books,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS catalogue_percentage,
    ROUND(AVG(ratings)::NUMERIC, 2) AS average_rating
FROM pagepulse.books_data
GROUP BY price_band
ORDER BY MIN(prices);


-- 7. Which sizeable categories may need quality or assortment improvement?
-- Limit this review to categories with at least five books to avoid tiny samples.
SELECT
    categories AS category,
    COUNT(*) AS number_of_books,
    ROUND(AVG(ratings)::NUMERIC, 2) AS average_rating,
    COUNT(*) FILTER (WHERE ratings <= 2) AS low_rated_books
FROM pagepulse.books_data
GROUP BY categories
HAVING COUNT(*) >= 5
   AND AVG(ratings) < 3
ORDER BY average_rating, number_of_books DESC;


-- 8. Which categories contain the most unavailable books?
-- This highlights categories where catalogue availability may require attention.
SELECT
    categories AS category,
    COUNT(*) FILTER (WHERE LOWER(availability) <> 'in stock') AS unavailable_books,
    COUNT(*) AS total_books,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE LOWER(availability) <> 'in stock')
        / NULLIF(COUNT(*), 0),
        1
    ) AS unavailable_percentage
FROM pagepulse.books_data
GROUP BY categories
HAVING COUNT(*) FILTER (WHERE LOWER(availability) <> 'in stock') > 0
ORDER BY unavailable_percentage DESC, unavailable_books DESC, category;
