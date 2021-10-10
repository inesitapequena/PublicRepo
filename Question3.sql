CREATE TABLE film_recommendations
AS 

WITH t AS (

SELECT DISTINCT c.customer_id, f.title,row_number() OVER (PARTITION BY c.customer_id  ) AS rownum
FROM customer c 
LEFT JOIN rental r 
on r.customer_id  = c.customer_id 
LEFT JOIN inventory i 
on i.inventory_id  = r.inventory_id 
FULL OUTER JOIN film f
on f.film_id =i.film_id 
)

SELECT t.customer_id, t.title "recommendation"
FROM t
WHERE rownum <11
ORDER BY customer_id
