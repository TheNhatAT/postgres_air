-- set up the indexes
SET search_path TO postgres_air;
CREATE INDEX flight_arrival_airport ON
    flight (arrival_airport);
CREATE INDEX booking_leg_flight_id ON
    booking_leg (flight_id);
CREATE INDEX flight_actual_departure ON
    flight (actual_departure);
CREATE INDEX boarding_pass_booking_leg_id ON
    boarding_pass (booking_leg_id);
CREATE INDEX booking_update_ts ON
    booking (update_ts);

-- down the indexes
DROP INDEX flight_arrival_airport;
DROP INDEX booking_leg_flight_id;
DROP INDEX flight_actual_departure;
DROP INDEX boarding_pass_booking_leg_id;
DROP INDEX booking_update_ts;

-- analyze after building indexes
ANALYZE flight;
ANALYZE booking_leg;
ANALYZE booking;
ANALYZE boarding_pass;

-- long query examples
SELECT d.airport_code AS departure_airport, a.airport_code AS arrival_airport
FROM airport a,
     airport d;

SELECT avg(flight_length), avg(passengers)
FROM (SELECT flight_no,
             scheduled_arrival -
             scheduled_departure AS flight_length,
             count(passenger_id)    passengers
      FROM flight f
               JOIN booking_leg bl ON bl.flight_id =
                                      f.flight_id
               JOIN passenger p ON
          p.booking_id = bl.booking_id
      GROUP BY 1, 2) a;

-- short query examples
SELECT f.flight_no,
       f.scheduled_departure,
       boarding_time,
       p.last_name,
       p.first_name,
       bp.update_ts as pass_issued,
       ff.level
FROM flight f
         JOIN booking_leg bl ON bl.flight_id =
                                f.flight_id
         JOIN passenger p ON p.booking_id = bl.booking_id
         JOIN account a on a.account_id = p.account_id
         JOIN boarding_pass bp on
    bp.passenger_id = p.passenger_id
         LEFT OUTER JOIN frequent_flyer ff on
    ff.frequent_flyer_id = a.frequent_flyer_id
WHERE f.departure_airport = 'JFK'
  AND f.arrival_airport = 'ORD'
  AND f.scheduled_departure
    BETWEEN '2023-08-05' AND '2023-08-07';

-- index selectivity
SELECT *
FROM flight
WHERE departure_airport = 'LAX'
  AND update_ts BETWEEN '2023-08-13' AND '2023-08-15'
  AND status = 'Delayed'
  AND scheduled_departure BETWEEN '2023-08-13' AND '2023-08-15';

-- Check departure_airport of LAX distribution
SELECT departure_airport, count, percentage
from (SELECT departure_airport,
             COUNT(*)                                 as count,
             COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
      FROM flight
      GROUP BY departure_airport) a
WHERE departure_airport = 'LAX';
-- 1.7278073942662088 %

-- Check status distribution
SELECT status,
       COUNT(*),
       COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
FROM flight
GROUP BY status;
-- 12.3235818483616276 %

-- Check distribution of updates
SELECT day, count
FROM (SELECT date_trunc('day', update_ts) as day, COUNT(*) as count
      FROM flight
      GROUP BY 1
      ORDER BY 1 DESC) as a
WHERE day BETWEEN '2023-08-13' AND '2023-08-15';

-- How many flights in a typical 2-day window?
SELECT COUNT(*)
FROM flight
WHERE scheduled_departure BETWEEN '2023-08-13' AND '2023-08-15'; -- 6988
SELECT COUNT(*)
FROM flight;
-- 683178

-- indexes and the LIKE operator
EXPLAIN
SELECT *
FROM account
WHERE lower(last_name) like 'johns%';

CREATE INDEX account_last_name_lower ON account (lower(last_name)); -- create functional index but still sequence scan
CREATE INDEX account_last_name_lower_pattern ON account (lower(last_name) text_pattern_ops); -- create functional index with pattern ops, using index instead of seq scan
SHOW LC_COLLATE;

-- check index with non-functional index
CREATE INDEX account_last_name ON account (last_name); -- still not work
EXPLAIN
SELECT *
FROM account
WHERE account.last_name like 'johns%';

CREATE INDEX account_last_name_pattern ON account (last_name text_pattern_ops);
-- create functional index with pattern ops, using index instead of seq scan

-- bitmap for multiple indexes
EXPLAIN
SELECT scheduled_departure, scheduled_arrival
FROM flight
WHERE departure_airport = 'ORD'
  AND arrival_airport = 'JFK'
  AND scheduled_departure BETWEEN '2023-07-03'
    AND '2023-07-04';

-- compound indexes
CREATE INDEX flight_depart_arr_sched_dep
    ON flight (departure_airport,
               arrival_airport, scheduled_departure); -- (X,Y,Z)
EXPLAIN
SELECT scheduled_departure, scheduled_arrival
FROM flight
WHERE departure_airport = 'ORD'
  AND arrival_airport = 'JFK'
  AND scheduled_departure BETWEEN '2023-07-03'
    AND '2023-07-04'; -- (X,Y,Z) -> using compound index

EXPLAIN
SELECT departure_airport, scheduled_arrival, scheduled_departure
FROM flight
WHERE departure_airport = 'ORD'
  AND scheduled_departure BETWEEN '2023-07-03' AND '2023-07-04'; -- (X,Z) -> still using compound index

EXPLAIN
SELECT departure_airport, scheduled_arrival, scheduled_departure
FROM flight
WHERE arrival_airport = 'JFK'
  AND scheduled_departure BETWEEN '2023-07-03' AND '2023-07-04'; -- (Y,Z) -> not using compound index

CREATE INDEX flight_depart_arr_sched_dep_sched_arr
    ON flight (departure_airport, arrival_airport,
               scheduled_departure, scheduled_arrival); -- index for index-only scan

EXPLAIN
SELECT scheduled_departure, scheduled_arrival
FROM flight
WHERE departure_airport = 'ORD'
  AND arrival_airport = 'JFK'
  AND scheduled_departure BETWEEN '2023-07-03'
    AND '2023-07-04'; -- index-only scan


CREATE INDEX
    flight_depart_arr_sched_dep_inc_sched_arr ON
    flight (departure_airport, arrival_airport, scheduled_departure)
    INCLUDE (scheduled_arrival); -- covering index that include scheduled_arrival data into the index

EXPLAIN
SELECT scheduled_departure, scheduled_arrival
FROM flight
WHERE departure_airport = 'ORD'
  AND arrival_airport = 'JFK'
  AND scheduled_departure BETWEEN '2023-07-03'
    AND '2023-07-04';
-- covering index is used for retrieving data of scheduled_arrival

-- Check if your index is providing index-only scans
EXPLAIN (ANALYZE, BUFFERS)
SELECT departure_airport, scheduled_departure, scheduled_arrival
FROM flight
WHERE arrival_airport = 'JFK'
  AND departure_airport = 'ORD'
  AND scheduled_departure BETWEEN '2023-07-03' AND '2023-07-04';
-- Heap Fetches: 0 => index-only scan


-- excessive selection criteria
EXPLAIN
SELECT last_name, first_name, seat
FROM boarding_pass bp
         JOIN booking_leg bl USING (booking_leg_id)
         JOIN flight f USING (flight_id)
         JOIN booking b USING (booking_id)
         JOIN passenger p USING (passenger_id)
WHERE (departure_airport = 'JFK'
    AND scheduled_departure BETWEEN '2023-07-10' AND '2023-07-11'
    AND last_name = 'JOHNSON')
   OR (departure_airport = 'EDW'
    AND scheduled_departure BETWEEN '2023-07-13' AND '2023-07-14'
    AND last_name = 'JOHNSTON');
-- query with conditions on two different tables

-- example of rebuild the sql for excessive selection criteria
SELECT bp.update_ts AS boarding_pass_issued,
       scheduled_departure,
       actual_departure,
       status
FROM flight f
         JOIN booking_leg bl USING (flight_id)
         JOIN boarding_pass bp USING (booking_leg_id)
WHERE bp.update_ts > scheduled_departure + interval '30 minutes' -- update_ts is in boarding_pass table, scheduled_departure is in flight table
  AND f.update_ts >= scheduled_departure - interval '1 hour';
-- => cannot build index on criteria from one table depend on vales from another table

-- update the sql to just include only the most recent exceptions suits the business owner's needs
CREATE INDEX boarding_pass_update_ts ON
    postgres_air.boarding_pass (update_ts);

EXPLAIN
SELECT bp.update_ts AS boarding_pass_issued, scheduled_departure, actual_departure, status
FROM flight f
         JOIN booking_leg bl USING (flight_id)
         JOIN boarding_pass bp USING (booking_leg_id)
WHERE bp.update_ts > scheduled_departure + interval '30 minutes'
  AND f.update_ts >= scheduled_departure - interval '1 hour'
  AND bp.update_ts >= '2023-08-13'
  AND bp.update_ts < '2023-08-14';


-- partial indexes
EXPLAIN ANALYSE
SELECT *
FROM flight
WHERE scheduled_departure between '2023-08-13' AND
    '2023-08-14'
  AND status = 'Canceled'; -- before using partial index, Execution Time: 91.787 ms

CREATE INDEX flight_canceled ON flight (flight_id)
    WHERE status = 'Canceled';

EXPLAIN ANALYSE
SELECT *
FROM flight
WHERE scheduled_departure between '2023-08-13' AND
    '2023-08-14'
  AND status = 'Canceled'; -- after using partial index, Execution Time: 0.164 ms

DROP INDEX flight_canceled;
-- reset the index

-- index and the join order
-- setup indexes for examine join order
CREATE INDEX account_login ON account (login);
CREATE INDEX account_login_lower_pattern ON
    account (lower(login) text_pattern_ops);
CREATE INDEX passenger_last_name ON
    passenger (last_name);
CREATE INDEX boarding_pass_passenger_id ON
    boarding_pass (passenger_id);
CREATE INDEX passenger_last_name_lower_pattern ON
    passenger (lower(last_name) text_pattern_ops);
CREATE INDEX passenger_booking_id ON
    passenger (booking_id);
CREATE INDEX booking_account_id ON
    booking (account_id);
CREATE INDEX booking_email_lower_pattern ON
    booking (lower(email) text_pattern_ops);

EXPLAIN SELECT b.account_id, a.login, p.last_name, p.first_name
FROM passenger p
         JOIN booking b USING (booking_id)
         JOIN account a ON a.account_id = b.account_id
WHERE lower(p.last_name) LIKE 'smith%'
  AND lower(login) LIKE 'smith%';
