EXPLAIN
ANALYZE
SELECT *
FROM postgres_air.flight
WHERE departure_airport = 'JFK'
  AND scheduled_departure BETWEEN '2024-08-13' AND '2024-08-14';

-- 3.2 range filtering that selects a significant portion of the table
-- => use an full table scan
EXPLAIN
SELECT flight_no,
       departure_airport,
       arrival_airport
FROM flight
WHERE scheduled_departure BETWEEN
          '2023-05-15' AND '2023-08-31';

-- 3.3 range filtering that selects a small portion of the table
-- => use an index-based table access
EXPLAIN
SELECT
    flight_no,
    departure_airport,
    arrival_airport
FROM flight
WHERE scheduled_departure BETWEEN
          '2023-08-12' AND '2023-08-13';