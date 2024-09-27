/*
OBJECTIVE QUESTIONS
2.	Find the top-selling tracks and top artist in the USA and identify their most famous genres.

SELECT track.name AS track_name, artist.name AS artist_name, genre.name AS genre_name, SUM(invoice_line.quantity) AS total_quantity
FROM track
JOIN album ON track.album_id = album.album_id
JOIN artist ON album.artist_id = artist.artist_id
JOIN genre ON track.genre_id = genre.genre_id
JOIN invoice_line ON track.track_id = invoice_line.track_id
JOIN invoice ON invoice_line.invoice_id = invoice.invoice_id
WHERE invoice.billing_country = 'USA'
GROUP BY track.name, artist.name, genre.name
ORDER BY total_quantity DESC;


3.	What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?

SELECT billing_country, COUNT(*)
FROM invoice
GROUP BY billing_country;


4.	Calculate the total revenue and number of invoices for each country, state, and city.

SELECT billing_country, SUM(quantity*unit_price) AS total_revenue, COUNT(invoice.invoice_id) AS invoice_count
FROM invoice_line
JOIN invoice ON invoice_line.invoice_id=invoice.invoice_id
GROUP BY billing_country;

SELECT billing_st, SUM(quantity*unit_price) AS total_revenue, COUNT(invoice.invoice_id) AS invoice_count
FROM invoice_line
JOIN invoice ON invoice_line.invoice_id=invoice.invoice_id
GROUP BY billing_state;

SELECT billing_city, SUM(quantity*unit_price) AS total_revenue, COUNT(invoice.invoice_id) AS invoice_count
FROM invoice_line
JOIN invoice ON invoice_line.invoice_id=invoice.invoice_id
GROUP BY billing_city;

 5.	Find the top 5 customers by total revenue in each country.
 
 WITH CustomerRevenue AS
 (
	SELECT customer.customer_id, first_name, last_name, country, SUM(quantity*unit_price) AS total_revenue
    FROM customer
    JOIN invoice ON customer.customer_id=invoice.customer_id
	JOIN invoice_line ON invoice.invoice_id=invoice_line.invoice_id
    GROUP BY customer_id, first_name, last_name, country
),
RankedCustomers AS
(
	SELECT customer_id, first_name, last_name, country, total_reveune, ROW_NUMBER OVER (PARTITION BY country ORDER BY total_revenue DESC) AS `rank`
    FROM CustomerRevenue
)
	SELECT customer_id, first_name, last_name, country, total_reveune
    FROM RankedCUstomers
    WHERE `rank`<=5
    ORDER BY country, `rank`;

6.	Identify the top-selling track for each customer.

WITH CustomerTrackRevenue AS
 (
	SELECT c.customer_id, c.first_name, c.last_name, t.track_id, t.name AS track_name, SUM(il.quantity*il.unit_price) AS total_revenue
    FROM customer c
    JOIN invoice i ON c.customer_id=i.customer_id
	JOIN invoice_line il ON i.invoice_id=il.invoice_id
    JOIN track t ON il.track_id=t.track_id
    GROUP BY c.customer_id, c.first_name, c.last_name, t.track_id, t.name
),
RankedTracks AS
(
	SELECT customer_id, first_name, last_name, track_id, track_name, total_revenue, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total_revenue DESC) AS `rank`
	FROM CustomerTrackRevenue
)
SELECT customer_id, first_name, last_name, track_id, track_name, total_revenue
FROM RankedTracks
WHERE `rank`=1
ORDER BY customer_id;


7.	Are there any patterns or trends in customer purchasing behavior (e.g., frequency of purchases, preferred payment methods, average order value)?

SELECT c.country, COUNT(i.invoice_id) AS purchase_count, AVG(i.total) AS average_order_value, SUM(i.total) AS total_revenue
FROM customer c
JOIN invoice i ON c.customer_id=i.customer_id
GROUP BY c.country
ORDER BY total_revenue DESC;


8. What is the customer churn rate?

WITH CustomerFirstPurchase AS 
(
    SELECT c.customer_id, i.billing_country, MIN(i.invoice_date) AS first_purchase_date 
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, i.billing_country
),
CustomerType AS 
(
    SELECT customer_id, billing_country, 
        CASE WHEN first_purchase_date <= DATE_SUB(CURDATE(), INTERVAL 1 YEAR) THEN 'Long-term' ELSE 'New' END AS customer_type
    FROM CustomerFirstPurchase
),
RecentPurchases AS 
(
    SELECT DISTINCT c.customer_id, i.billing_country 
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    WHERE i.invoice_date > DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
),
ChurnRates AS
(
    SELECT ct.billing_country, COUNT(*) AS total_customers, COUNT(rp.customer_id) AS active_customers,
    ((total_customers - active_customers)*100.0)/total_customers AS churn_rate
    FROM CustomerType ct
    LEFT JOIN RecentPurchases rp ON ct.customer_id = rp.customer_id
    GROUP BY ct.billing_country
)
SELECT billing_country, total_customers, total_customers - active_customers AS churned_customers, churn_rate
FROM ChurnRates
ORDER BY billing_country;

9.	Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.

WITH genrevs AS
(
    SELECT genre.name, SUM(invoice_line.unit_price*invoice_line.quantity) AS revenue
    FROM genre
    JOIN track ON genre.genre_id=track.genre_id
    JOIN invoice_line ON track.track_id=invoice_line.track_id
    JOIN invoice ON invoice_line.invoice_id=invoice.invoice_id
    WHERE billing_country='USA'
    GROUP BY genre.name
)
SELECT name, (revenue/SUM(revenue) OVER ())*100 AS percentage
FROM genrevs
GROUP BY genrevs.name;

WITH artistrevs AS
(
    SELECT artist.name, SUM(invoice_line.unit_price*invoice_line.quantity) AS revenue
    FROM artist
    JOIN album ON artist.artist_id=album.artist_id
    JOIN track ON album.album_id=track.album_id
    JOIN invoice_line ON track.track_id=invoice_line.track_id
    JOIN invoice ON invoice_line.invoice_id=invoice.invoice_id
    WHERE billing_country='USA'
    GROUP BY artist.name
)
SELECT name, (revenue/SUM(revenue) OVER ())*100 AS percentage
FROM artistrevs
GROUP BY name;

10.	Find customers who have purchased tracks from at least 3 different+ genres.

SELECT customer.customer_id, CONCAT(first_name, " ", last_name) AS name, COUNT(DISTINCT genre.genre_id) AS genre_count
FROM customer
JOIN invoice ON customer.customer_id = invoice.customer_id
JOIN invoice_line ON invoice.invoice_id = invoice_line.invoice_id
JOIN track ON invoice_line.track_id = track.track_id
JOIN genre ON track.genre_id = genre.genre_id
GROUP BY customer_id, name
HAVING COUNT(DISTINCT genre.genre_id) >= 3
ORDER BY genre_count ASC;


11.	Rank genres based on their sales performance in the USA.

SELECT genre.name, SUM(quantity*invoice_line.unit_price) AS revenue, DENSE_RANK() OVER(ORDER BY SUM(quantity*invoice_line.unit_price) DESC) AS `rank`
FROM genre
JOIN track ON genre.genre_id = track.genre_id
JOIN invoice_line ON track.track_id = invoice_line.track_id
JOIN invoice ON invoice_line.invoice_id = invoice.invoice_id
WHERE billing_country='USA'
GROUP BY name;


12.	Identify customers who have not made a purchase in the last 3 months.

SELECT customer_id, CONCAT(first_name, " ", last_name) AS name
FROM customer
WHERE customer_id NOT IN 
(
    SELECT customer_id FROM 
    (
        SELECT DISTINCT customer.customer_id
        FROM customer
        JOIN invoice ON customer.customer_id = invoice.customer_id
        WHERE invoice_date > DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
    ) AS xyz
);

SUBJECTIVE QUESTIONS

1.	Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis.

SELECT title, genre.name AS genre, SUM(invoice_line.quantity*invoice_line.unit_price) AS sales
FROM album
JOIN track ON album.album_id = album.album_id
JOIN genre ON track.genre_id = genre.genre_id
JOIN invoice_line ON track.track_id = invoice_line.track_id
JOIN invoice ON invoice_line.invoice_id= invoice.invoice_id
WHERE billing_country='USA'
GROUP BY title, genre
ORDER BY sales DESC;


2.	Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.

WITH GenreRevenue AS
(
    SELECT genre.name AS genre, billing_country, SUM(quantity * invoice_line.unit_price) AS total_revenue
    FROM genre
    JOIN track ON genre.genre_id = track.genre_id
    JOIN invoice_line ON track.track_id = invoice_line.track_id
    JOIN invoice ON invoice_line.invoice_id = invoice.invoice_id
    WHERE billing_country <> 'USA'
    GROUP BY genre, billing_country
),
RankedGenres AS
(
    SELECT genre, billing_country, total_revenue,
           RANK() OVER (PARTITION BY billing_country ORDER BY total_revenue DESC) AS `rank`
    FROM GenreRevenue
)
SELECT billing_country, genre, total_revenue
FROM RankedGenres
WHERE `rank` = 1
ORDER BY billing_country;


3. Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? What insights can these patterns provide about customer loyalty and retention strategies?

WITH CustomerPurchaseData AS 
(
    SELECT customer_id, CASE WHEN DATEDIFF(CURRENT_DATE, MIN(invoice_date)) <= 180 THEN 'New' ELSE 'Long-Term' END AS customer_type,
        COUNT(DISTINCT invoice_id) AS purchase_frequency, AVG(total) AS average_order_value, SUM(total) AS total_spending
    FROM invoice
    GROUP BY customer_id
),
CustomerTypeSummary AS 
(
    SELECT customer_type, AVG(purchase_frequency) AS avg_purchase_frequency, AVG(average_order_value) AS avg_order_value, AVG(total_spending) AS avg_total_spending
    FROM CustomerPurchaseData GROUP BY customer_type
)
SELECT customer_type, avg_purchase_frequency, avg_order_value,avg_total_spending
FROM CustomerTypeSummary;


4. Which music genres, artists, or albums are frequently purchased together by customers?

WITH GenrePurchases AS (
    SELECT il.invoice_id, g.genre_id, g.name AS genre_name
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
),
GenrePairs AS (
    SELECT gp1.genre_name AS genre1, gp2.genre_name AS genre2, COUNT(*) AS purchase_count
    FROM GenrePurchases gp1
    JOIN GenrePurchases gp2 ON gp1.invoice_id = gp2.invoice_id AND gp1.genre_id <> gp2.genre_id
    GROUP BY gp1.genre_name, gp2.genre_name
    ORDER BY purchase_count DESC
)
SELECT genre1, genre2, purchase_count
FROM GenrePairs
ORDER BY purchase_count DESC
LIMIT 10;


5. Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations?

WITH CustomerMetrics AS (
    SELECT i.billing_country, COUNT(DISTINCT i.invoice_id) AS purchase_count,
           SUM(il.quantity) AS total_items, SUM(il.unit_price * il.quantity) AS total_spent
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY i.billing_country
)
SELECT billing_country, AVG(purchase_count) AS avg_purchase_count,
       AVG(total_items) AS avg_basket_size, AVG(total_spent) AS avg_total_spent
FROM CustomerMetrics
GROUP BY billing_country
ORDER BY billing_country;


6. Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), which customer segments are more likely to churn or pose a higher risk of reduced spending? What factors contribute to this risk?

WITH CustomerActivity AS 
(
    SELECT customer.customer_id, customer.first_name, customer.last_name, customer.country, COUNT(DISTINCT invoice.invoice_id) AS purchase_count, 
        SUM(invoice.total) AS total_spending, MAX(invoice.invoice_date) AS last_purchase_date, 
        DATEDIFF(CURRENT_DATE, MAX(invoice.invoice_date)) AS days_since_last_purchase
    FROM customer
    JOIN invoice ON customer.customer_id = invoice.customer_id
    GROUP BY customer.customer_id, customer.first_name, customer.last_name, customer.country
),
HighRiskSegments AS 
(
    SELECT customer_id, first_name, last_name, country, purchase_count, total_spending, days_since_last_purchase,
        CASE WHEN purchase_count <= 2 THEN 'Low Engagement' WHEN total_spending <= 50 THEN 'Low Spending' WHEN days_since_last_purchase > 90 THEN 'Inactive' 
		ELSE 'Other' END AS risk_factor
    FROM CustomerActivity
)
SELECT customer_id, first_name, last_name, country, risk_factor
FROM HighRiskSegments
WHERE risk_factor IN ('Low Engagement', 'Low Spending', 'Inactive')
ORDER BY risk_factor DESC, country, total_spending;


7.	How can you leverage customer data (tenure, purchase history, engagement) to predict the lifetime value of different customer segments? 

WITH CustomerMetrics AS
(
	SELECT c.customer_id, c.first_name, c.last_name, i.billing_country, MIN(i.invoice_date) As first_purchase_date, MAX(i.invoice_date) as last_purchase_date, COUNT(DISTINCT i.invoice_id) as purchase_count,
	SUM(il.quantity) as total_items, SUM(il.unit_price*il.quantity) as total_spent, AVG(il.unit_price*il.quantity) AS avg_purchase_value
	FROM customer c
	JOIN invoice i on c.customer_id=i.customer_id
	JOIN invoice_line il on i.invoice_id=il.invoice_id
	GROUP BY c.customer_id, c.first_name, c.last_name, i.billing_country
),
CustomerSegments AS
(
	SELECT customer_id, first_name, last_name, billing_country, first_purchase_date, purchase_count, total_items, total_spent, avg_purchase_value,
		CASE WHEN total_spent<=100 THEN 'Low Value' WHEN total_spent BETWEEN 101 AND 500 THEN "Medium Value" ELSE "High Value" END AS value_segment
	FROM CustomerMetrics
),
PredictedCLV AS 
(
	SELECT customer_id, first_name, last_name, billing_country, value_segment, total_spent, purchase_count, avg_purchase_value,
		(avg_purchase_value*purchase_count/(DATEDIFF(CURDATE(), first_purchase_date)/365))*3 AS predicted_clv
	FROM CustomerSegments
)
SELECT * FROM PredictedCLV
ORDER BY predicted_clv DESC;


11. Chinook want to know the average total amount spent by customers from each country, along with the number of customers and the average number of tracks purchased per customer.

WITH CustomerMetrics AS 
(
    SELECT 
        c.country,
        c.customer_id,
        COUNT(DISTINCT i.invoice_id) AS num_purchases,
        SUM(il.quantity) AS total_tracks_purchased,
        SUM(il.unit_price * il.quantity) AS total_spent
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY c.country, c.customer_id
)
SELECT 
    country,
    COUNT(customer_id) AS num_customers,
    AVG(total_spent) AS avg_total_spent,
    AVG(total_tracks_purchased) AS avg_tracks_purchased_per_customer
FROM CustomerMetrics
GROUP BY country
ORDER BY country;
*/