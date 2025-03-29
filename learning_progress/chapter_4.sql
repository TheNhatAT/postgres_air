-- 4.1
EXPLAIN
SELECT f.flight_no,
       f.actual_departure,
       count(passenger_id) passengers
FROM flight f
         JOIN booking_leg bl ON bl.flight_id = f.flight_id
         JOIN passenger p ON p.booking_id = bl.booking_id
WHERE f.departure_airport = 'JFK'
  AND f.arrival_airport = 'ORD'
  AND f.actual_departure BETWEEN
    '2023-08-10' and '2023-08-13'
GROUP BY f.flight_id, f.actual_departure;

-- 4.3
EXPLAIN
SELECT flight_id,
       scheduled_departure
FROM flight f
         JOIN airport a ON departure_airport = airport_code
    AND iso_country = 'US';
-- 4.4
EXPLAIN
SELECT flight_id,
       scheduled_departure
FROM flight f
         JOIN airport a ON departure_airport = airport_code
    AND iso_country = 'CZ';

-- show the different between selectivity of US and CZ
select count(1) as total, airport.iso_country
from airport
where iso_country in ('US', 'CZ')
group by iso_country
order by total;