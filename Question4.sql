DROP TABLE IF EXISTS customer_lifecycle;

CREATE TABLE customer_lifecycle 

AS

WITH first30 AS (SELECT DISTINCT c.customer_id
				,SUM(p.amount) AS First30DayRev
				FROM customer c 
				LEFT JOIN payment p 
				on p.customer_id = c.customer_id
				LEFT JOIN ( SELECT DISTINCT rr.customer_id , date(min(rr.rental_date)) minrentaldate
							FROM rental rr
							GROUP BY rr.customer_id) m
				on m.customer_id = c.customer_id 
				where  p.payment_date >= date(m.minrentaldate) + interval '1 day' AND p.payment_date <(date(m.minrentaldate) + interval '1 day' * 30) 
				group by c.customer_id 
				order by c.customer_id 
                ),

avgrental AS (SELECT w.customer_id
					,avg(w.delta) avgrentaltime
				FROM (SELECT c.customer_id
                            ,r.rental_date 
                            ,r.rental_date - lag(r.rental_date, 1) OVER (PARTITION BY c.customer_id ORDER BY r.rental_date )delta
                    FROM customer c
                    LEFT JOIN rental r 
                    on r.customer_id  = c.customer_id 
                    WINDOW w AS ()) w
				GROUP BY w.customer_id
                ),
				
totalrev AS 	(select distinct c.customer_id, sum(p.amount) totalrev
                FROM customer c
                LEFT JOIN payment p 
                on p.customer_id = c.customer_id 
                GROUP BY c.customer_id
				),
				
minmaxrent AS (SELECT DISTINCT c.customer_id, mm.lastrentdate, f.title FirstFilm, max(f2.title) LastFilm
                FROM customer c
                LEFT JOIN (SELECT DISTINCT c.customer_id, min(r.rental_date) firstrentdate, max(r.rental_date) lastrentdate
                            FROM customer c
                            LEFT JOIN rental r 
                            on r.customer_id = c.customer_id
                            GROUP BY c.customer_id) mm
				on mm.customer_id = c.customer_id
				LEFT JOIN rental r2 
				on r2.customer_id = mm.customer_id AND r2.rental_date = mm.firstrentdate
				LEFT JOIN inventory i 
				on r2.inventory_id = i.inventory_id 
				LEFT JOIN film f 
				on f.film_id =i.film_id 
				LEFT JOIN rental r3 
				on r3.customer_id = mm.customer_id AND r3.rental_date = mm.lastrentdate
				LEFT JOIN inventory i2 
				on r3.inventory_id = i2.inventory_id 
				LEFT JOIN film f2 
				on f2.film_id =i2.film_id
                GROUP BY c.customer_id, mm.lastrentdate, f.title
				),
				
top3actors AS (SELECT concatbase.customer_id
                , string_agg(concatbase.actorname, ', ') AS Top3Actors 
                FROM (SELECT * FROM (SELECT c.customer_id
                                        , aa.actorname,
                                        rank() OVER (PARTITION BY c.customer_id ORDER BY aa.countofrentals DESC, aa.actor_id DESC) ranking
                                    FROM customer c 
                                    LEFT JOIN (SELECT DISTINCT c.customer_id 
                                                , a.first_name || ' ' || a.last_name  ActorName
                                                , count(*) countofrentals
                                                ,a.actor_id 
                                                FROM customer c		
                                                LEFT JOIN rental r 
                                                on r.customer_id = c.customer_id 
                                                LEFT JOIN inventory i 
                                                on i.inventory_id = r.inventory_id 
                                                LEFT JOIN film f 
                                                on f.film_id = i.film_id 
                                                LEFT JOIN film_actor fa 
                                                on fa.film_id = f.film_id 
                                                LEFT JOIN actor a 
                                                on a.actor_id = fa.actor_id 
                                                GROUP BY c.customer_id , a.first_name || ' ' || a.last_name,a.actor_id ) aa
                                    ON c.customer_id = aa.customer_id) rr
                                    WHERE rr.ranking < 4) concatbase
                                    GROUP BY concatbase.customer_id
                ),

favcat as ( SELECT A.customer_id, a.name FavCategory
			FROM (SELECT *, ROW_NUMBER() OVER(PARTITION BY cat.customer_id ORDER BY countofcat DESC) AS catrank
                FROM (SELECT distinct c.customer_id, c2."name", count(*) countofcat
						FROM customer c
						LEFT JOIN rental r
						on r.customer_id = c.customer_id
						LEFT JOIN inventory i 
						on i.inventory_id = r.inventory_id 
						LEFT JOIN film f 
						on f.film_id = i.film_id
						LEFT JOIN film_category fc 
						on fc.film_id = f.film_id 
						LEFT JOIN category c2 
						on c2.category_id = fc.category_id 
						GROUP by c.customer_id,c2."name"
                    ) cat
                ) AS A
			WHERE A.catrank = 1
            ),
			
ttlfilm as (SELECT distinct c.customer_id, count(distinct i.film_id) ttlfilms
            FROM customer c		
            LEFT JOIN rental r 
            on r.customer_id = c.customer_id 
            LEFT JOIN inventory i 
            on i.inventory_id = r.inventory_id
            GROUP by c.customer_id
            )
			
			
SELECT  c.customer_id
	,f.First30DayRev
	,CASE WHEN f.First30DayRev > a.AvgFirst30DayRev THEN 'Top Tier' ELSE 'Bottom Tier' END Tier
	,m.firstfilm
	,m.lastfilm
	,m.lastrentdate
    ,ar.avgrentaltime
	,t.totalrev
	,t3.top3actors
    ,fc.favcategory
	,tf.ttlfilms
	FROM customer c 
	LEFT JOIN first30 f
	on f.customer_id = c.customer_id 
	LEFT JOIN (SELECT avg(First30DayRev) AvgFirst30DayRev
				FROM first30) a
	on 1=1
	LEFT JOIN minmaxrent m
	on m.customer_id = c.customer_id 
    LEFT JOIN avgrental ar 
	on ar.customer_id = c.customer_id
	LEFT JOIN totalrev t
	on t.customer_id = c.customer_id 
	LEFT JOIN top3actors t3 
	on t.customer_id = t3.customer_id 
	LEFT JOIN favcat fc 
	on fc.customer_id = c.customer_id
	LEFT JOIN ttlfilm tf 
	on tf.customer_id = c.customer_id 
	ORDER BY customer_id;


ALTER TABLE customer_lifecycle  ADD CONSTRAINT customer_lifecyclepk PRIMARY KEY (customer_id);
	
	