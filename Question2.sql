WITH customeridlist AS (SELECT percentrankcalc.*
						from (SELECT c.customer_id , sum(p.amount) totalpayment, percent_rank() OVER ( ORDER BY sum(p.amount) ) AS percentrank 
								from customer c 
								LEFT JOIN rental r 
								on r.customer_id = c.customer_id 
								LEFT JOIN payment p 
								on p.customer_id  = c.customer_id 
								WHERE date_part('year', r.rental_date) = 2005
								group BY c.customer_id
								ORDER BY sum(p.amount)
								) as percentrankcalc
						WHERE percentrank < 0.9 AND percentrank > 0.1 
						)
SELECT DISTINCT cc.store_id, date_part('month', rr.rental_date) rentalmonth, avg(pp.amount) avgvalue
from customer cc
LEFT JOIN rental rr
on rr.customer_id  = cc.customer_id 
LEFT JOIN payment pp 
on pp.customer_id =cc.customer_id 
INNER JOIN customeridlist 
on customeridlist.customer_id = cc.customer_id 
WHERE date_part('year', rr.rental_date) = 2005
GROUP BY cc.store_id, date_part('month', rr.rental_date)