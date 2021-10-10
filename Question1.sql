
with aggregation AS( 
	SELECT row_number() OVER (PARTITION BY c."name" ORDER BY count(*) DESC) AS rownum
			,f.title
			,c."name"
			,COUNT(DISTINCT r.rental_id) countofrentals
	FROM rental r
	LEFT JOIN inventory i 
	on i.inventory_id = r.inventory_id 
	LEFT JOIN film f 
	on f.film_id  = i.film_id 
	LEFT JOIN film_category fc 
	on fc.film_id = f.film_id 
	LEFT JOIN category c 
	on c.category_id = fc.category_id 
	WHERE r.rental_date >= '2005-01-01' AND r.rental_date <= '2005-06-30'
	GROUP BY c."name", f.title)

SELECT * FROM aggregation WHERE rownum <11