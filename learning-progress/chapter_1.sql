-- 1.1
SELECT
    flight_id
     ,departure_airport
     ,arrival_airport
FROM flight
WHERE scheduled_arrival >='2023-10-14'
  AND scheduled_arrival <'2023-10-15';