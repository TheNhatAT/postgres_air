-- find the flights, including their departure and arrival airports, that are scheduled to arrive on October 14, 2023.
-- 1.1
SELECT flight_id
     , departure_airport
     , arrival_airport
FROM flight
WHERE scheduled_arrival >= '2023-10-14'
  AND scheduled_arrival < '2023-10-15';

-- 1.2
SELECT flight_id
     , departure_airport
     , arrival_airport
FROM flight
WHERE scheduled_arrival::date = '2023-10-14';
----------

-- find how many people with frequent flyer level 4 fly out of Chicago for Independence Day
-- imperative approach (natural for humans)
-- step 1: select all frequent flyers with level 4
SELECT *
FROM frequent_flyer
WHERE level = 4;
-- step 2: select all corresponding accounts
SELECT *
FROM account
WHERE frequent_flyer_id IN (SELECT frequent_flyer_id FROM frequent_flyer WHERE level = 4);
-- step 3: select all bookings made by these accounts
WITH level4 AS (SELECT *
                FROM account
                WHERE frequent_flyer_id IN (SELECT frequent_flyer_id
                                            FROM frequent_flyer
                                            WHERE level = 4))
SELECT *
FROM booking
WHERE account_id IN
      (SELECT account_id FROM level4);
-- step 4: find frequent flyers traveled to Chicago on July 3rd
WITH bk AS (
    WITH level4 AS (SELECT *
                    FROM account
                    WHERE frequent_flyer_id IN (
                        SELECT
                            frequent_flyer_id
                        FROM
                            frequent_flyer
                        WHERE level =4
                    )
    )
    SELECT * FROM booking WHERE account_id IN
                                (SELECT account_id FROM level4)
)
SELECT * FROM bk WHERE bk.booking_id IN
                       (SELECT booking_id FROM booking_leg WHERE
                           leg_num=1 AND is_returning IS false
                                                             AND flight_id IN (
                               SELECT flight_id
                               FROM flight
                               WHERE departure_airport IN
                                     ('ORD', 'MDW')
                                 AND scheduled_departure::
                                         DATE='2023-07-04'));
-- step 5: count the number of passengers
WITH bk_chi AS (
    WITH bk AS (
        WITH level4 AS (SELECT *
                        FROM account
                        WHERE frequent_flyer_id IN (
                            SELECT
                                frequent_flyer_id
                            FROM
                                frequent_flyer
                            WHERE level =4
                        )
        )
        SELECT * FROM booking WHERE account_id
                                        IN
                                    (SELECT account_id FROM level4
                                    )
    )
    SELECT * FROM bk WHERE bk.booking_id IN
                           (SELECT booking_id FROM booking_leg WHERE
                               leg_num=1 AND is_returning IS false
                                                                 AND flight_id IN (
                                   SELECT flight_id
                                   FROM flight
                                   WHERE departure_airport
                                       IN ('ORD', 'MDW')
                                     AND
                                       scheduled_departure:: DATE='2023-07-04')
                           )
)
SELECT count(*) FROM passenger WHERE booking_id IN
                                     (SELECT booking_id FROM bk_chi);

-- declarative approach
SELECT count(*)
FROM booking bk
         JOIN booking_leg bl ON bk.booking_id=bl.booking_id
         JOIN flight f ON f.flight_id=bl.flight_id
         JOIN account a ON a.account_id=bk.account_id
         JOIN frequent_flyer ff ON
    ff.frequent_flyer_id=a.frequent_flyer_id
         JOIN passenger ps ON ps.booking_id=bk.booking_id
WHERE level=4
  AND leg_num=1
  AND is_returning IS false
  AND departure_airport IN ('ORD', 'MDW')
  AND scheduled_departure >= '2023-07-04'
  AND scheduled_departure <'2023-07-05';