
-- 1. Total number of books
SELECT COUNT(*) AS total_books
FROM pagepulse.books;

-- 2. Average book price rounded to two decimal places
SELECT ROUND(AVG(prices), 2) AS average_price
FROM pagepulse.books;

-- 3. Ten most expensive books
SELECT book_names, prices FROM pagepulse.books
ORDER BY prices DESC
LIMIT 10;

-- 4. Largest category by number of books
SELECT categories, COUNT(*) AS book_count
FROM pagepulse.books
WHERE categories != 'Default'
GROUP BY categories
ORDER BY book_count DESC
LIMIT 1;

-- 5. Category with the highest average price
SELECT categories, AVG(prices) AS average_price  
FROM pagepulse.books
GROUP BY categories
ORDER BY average_price DESC
LIMIT 1;

-- 6. Number of books by rating
SELECT ratings, COUNT(*) AS book_count
FROM pagepulse.books
GROUP BY ratings
ORDER BY book_count DESC;

-- 7. All books currently in stock
SELECT COUNT(*) AS in_stock_books
FROM pagepulse.books;

-- 8. Books priced above £ 40
SELECT book_names, prices
FROM pagepulse.books
WHERE prices > 40
ORDER BY prices DESC; 

-- 9. Average rating by category
SELECT categories, ROUND(AVG(ratings), 2) AS average_rating
FROM pagepulse.books
GROUP BY categories
ORDER BY average_rating DESC;

-- 10. Categories with more than 20 books
SELECT categories, COUNT(*) AS book_count
FROM pagepulse.books
GROUP BY categories
HAVING COUNT(*) > 20
ORDER BY book_count DESC;
