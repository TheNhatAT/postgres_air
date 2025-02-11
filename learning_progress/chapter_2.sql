-- filter
SELECT *
FROM flight
WHERE departure_airport='LAG'
  AND (arrival_airport='ORD' OR arrival_airport='MDW')
  AND scheduled_departure BETWEEN '2023-05-27'
    AND '2023-05-28';

-- project
SELECT city FROM airport;
SELECT DISTINCT city FROM airport;

-- product (Cartesian product)
SELECT d.airport_code AS departure_airport,
       a.airport_code AS arrival_airport
FROM airport a,
     airport d;
