create sequence account_account_id_seq
    as integer
    start with 300001;

alter sequence account_account_id_seq owner to postgres;

create sequence boarding_pass_pass_id_seq
    start with 25293500;

alter sequence boarding_pass_pass_id_seq owner to postgres;

create sequence booking_leg_booking_leg_id_seq
    as integer
    start with 17893600;

alter sequence booking_leg_booking_leg_id_seq owner to postgres;

create sequence booking_number
    start with 5743216;

alter sequence booking_number owner to postgres;

create sequence flight_flight_id_seq
    as integer
    start with 683180;

alter sequence flight_flight_id_seq owner to postgres;

create sequence frequent_flyer_frequent_flyer_id_seq
    as integer
    start with 128356;

alter sequence frequent_flyer_frequent_flyer_id_seq owner to postgres;

create sequence passenger_passenger_id_seq
    as integer
    start with 16313699;

alter sequence passenger_passenger_id_seq owner to postgres;

create sequence phone_phone_id_seq
    as integer
    start with 407449;

alter sequence phone_phone_id_seq owner to postgres;

create table if not exists aircraft
(
    model    text,
    range    numeric not null,
    class    integer not null,
    velocity numeric not null,
    code     text    not null
    primary key
);

alter table aircraft
    owner to postgres;

create table if not exists airport
(
    airport_code char(3) not null
    primary key,
    airport_name text    not null,
    city         text    not null,
    airport_tz   text    not null,
    continent    text,
    iso_country  text,
    iso_region   text,
    intnl        boolean not null,
    update_ts    timestamp with time zone
                               );

alter table airport
    owner to postgres;

create index if not exists airport_city
    on airport (city);

create table if not exists flight
(
    flight_id           integer default nextval('postgres_air.flight_flight_id_seq'::regclass) not null
    primary key,
    flight_no           text                                                                   not null,
    scheduled_departure timestamp with time zone                                               not null,
    scheduled_arrival   timestamp with time zone                                               not null,
                                      departure_airport   char(3)                                                                not null
    constraint departure_airport_fk
    references airport,
    arrival_airport     char(3)                                                                not null
    constraint arrival_airport_fk
    references airport,
    status              text                                                                   not null,
    aircraft_code       char(3)                                                                not null
    constraint aircraft_code_fk
    references aircraft,
    actual_departure    timestamp with time zone,
    actual_arrival      timestamp with time zone,
    update_ts           timestamp with time zone
                                      );

alter table flight
    owner to postgres;

alter sequence flight_flight_id_seq owned by flight.flight_id;

create index if not exists flight_departure_airport
    on flight (departure_airport);

create index if not exists flight_arrival_airport
    on flight (arrival_airport);

create index if not exists flight_scheduled_departure
    on flight (scheduled_departure);

create index if not exists flight_actual_departure
    on flight (actual_departure);

create index if not exists flight_update_ts
    on flight (update_ts);

create index if not exists flight_canceled
    on flight (flight_id)
    where (status = 'Canceled'::text);

create index if not exists flight_actual_departure_not_null
    on flight (actual_departure)
    where (actual_departure IS NOT NULL);

create index if not exists flight_depart_arr_sched_dep
    on flight (departure_airport, arrival_airport, scheduled_departure);

create index if not exists flight_depart_arr_sched_dep_sched_arr
    on flight (departure_airport, arrival_airport, scheduled_departure, scheduled_arrival);

create index if not exists flight_depart_arr_sched_dep_inc_sched_arr
    on flight (departure_airport, arrival_airport, scheduled_departure) include (scheduled_arrival);

create table if not exists frequent_flyer
(
    frequent_flyer_id integer default nextval('postgres_air.frequent_flyer_frequent_flyer_id_seq'::regclass) not null
    primary key,
    first_name        text                                                                                   not null,
    last_name         text                                                                                   not null,
    title             text                                                                                   not null,
    card_num          text                                                                                   not null,
    level             integer                                                                                not null,
    award_points      integer                                                                                not null,
    email             text                                                                                   not null,
    phone             text                                                                                   not null,
    update_ts         timestamp with time zone
                                    );

alter table frequent_flyer
    owner to postgres;

alter sequence frequent_flyer_frequent_flyer_id_seq owned by frequent_flyer.frequent_flyer_id;

create table if not exists account
(
    account_id        integer default nextval('postgres_air.account_account_id_seq'::regclass) not null
    primary key,
    login             text                                                                     not null,
    first_name        text                                                                     not null,
    last_name         text                                                                     not null,
    frequent_flyer_id integer
    constraint frequent_flyer_id_fk
    references frequent_flyer,
    update_ts         timestamp with time zone
                                    );

alter table account
    owner to postgres;

alter sequence account_account_id_seq owned by account.account_id;

create index if not exists account_last_name
    on account (last_name);

create index if not exists account_last_name_lower
    on account (lower(last_name));

create index if not exists account_last_name_lower_pattern
    on account (lower(last_name) text_pattern_ops);

create index if not exists account_login
    on account (login);

create index if not exists account_domain_lower_pattern
    on account (lower(reverse(login)) text_pattern_ops);

create index if not exists account_to_text_id_pattern
    on account ((account_id::text) text_pattern_ops);

create index if not exists account_login_lower_pattern
    on account (lower(login) text_pattern_ops);

create index if not exists account_frequent_flyer_id
    on account (frequent_flyer_id);

create table if not exists booking
(
    booking_id   bigint not null
    primary key,
    booking_ref  text   not null
    unique,
    booking_name text,
    account_id   integer
    constraint booking_account_id_fk
    references account,
    email        text   not null,
    phone        text   not null,
    update_ts    timestamp with time zone,
    price        numeric(7, 2)
    );

alter table booking
    owner to postgres;

create index if not exists booking_account_id
    on booking (account_id);

create index if not exists booking_update_ts
    on booking (update_ts);

create index if not exists booking_email_lower_pattern
    on booking (lower(email) text_pattern_ops);

create table if not exists booking_leg
(
    booking_leg_id integer default nextval('postgres_air.booking_leg_booking_leg_id_seq'::regclass) not null
    primary key,
    booking_id     integer                                                                          not null
    constraint booking_id_fk
    references booking,
    flight_id      integer                                                                          not null
    constraint flight_id_fk
    references flight,
    leg_num        integer,
    is_returning   boolean,
    update_ts      timestamp with time zone
                                 );

alter table booking_leg
    owner to postgres;

alter sequence booking_leg_booking_leg_id_seq owned by booking_leg.booking_leg_id;

create index if not exists booking_leg_booking_id
    on booking_leg (booking_id);

create index if not exists booking_leg_update_ts
    on booking_leg (update_ts);

create index if not exists booking_leg_flight_id
    on booking_leg (flight_id);

create index if not exists frequent_fl_last_name_lower_pattern
    on frequent_flyer (lower(last_name) text_pattern_ops);

create index if not exists frequent_fl_last_name_lower
    on frequent_flyer (lower(last_name));

create table if not exists passenger
(
    passenger_id integer default nextval('postgres_air.passenger_passenger_id_seq'::regclass) not null
    primary key,
    booking_id   integer                                                                      not null
    constraint pass_booking_id_fk
    references booking,
    booking_ref  text,
    passenger_no integer,
    first_name   text                                                                         not null,
    last_name    text                                                                         not null,
    account_id   integer
    constraint pass_account_id_fk
    references account
    constraint pass_frequent_flyer_id_fk
    references account,
    update_ts    timestamp with time zone,
                               age          integer
                               );

alter table passenger
    owner to postgres;

alter sequence passenger_passenger_id_seq owned by passenger.passenger_id;

create table if not exists boarding_pass
(
    pass_id        integer default nextval('postgres_air.boarding_pass_pass_id_seq'::regclass) not null
    primary key,
    passenger_id   bigint
    constraint passenger_id_fk
    references passenger,
    booking_leg_id bigint
    constraint booking_leg_id_fk
    references booking_leg,
    seat           text,
    boarding_time  timestamp with time zone,
    precheck       boolean,
    update_ts      timestamp with time zone
                                 );

alter table boarding_pass
    owner to postgres;

create index if not exists boarding_pass_booking_leg_id
    on boarding_pass (booking_leg_id);

create index if not exists boarding_pass_update_ts
    on boarding_pass (update_ts);

create index if not exists boarding_pass_passenger_id
    on boarding_pass (passenger_id);

create index if not exists passenger_account_id
    on passenger (account_id);

create index if not exists passenger_last_name
    on passenger (last_name);

create index if not exists passenger_last_name_lower_pattern
    on passenger (lower(last_name) text_pattern_ops);

create index if not exists passenger_booking_id
    on passenger (booking_id);

create table if not exists phone
(
    phone_id      integer default nextval('postgres_air.phone_phone_id_seq'::regclass) not null
    primary key,
    account_id    integer
    constraint phone_account_id_fk
    references account,
    phone         text,
    phone_type    text,
    primary_phone boolean,
    update_ts     timestamp with time zone
                                );

alter table phone
    owner to postgres;

alter sequence phone_phone_id_seq owned by phone.phone_id;

create index if not exists phone_account_id
    on phone (account_id);

create index if not exists phone_update_ts
    on phone (update_ts);

create or replace procedure advance_air_time(IN p_weeks integer DEFAULT 52, IN p_schema_name text DEFAULT 'postgres_air'::text, IN p_run boolean DEFAULT false)
    language plpgsql
as
$fun$
declare   stmt text;
begin
raise notice $$Interval: % $$,  make_interval (weeks=>p_weeks);
if p_run
then raise notice $$Executing updates$$;
else raise notice $$Displaying only$$;
end if;
----
for stmt in
select
    ---  nspname, relname, attname, typname
    'update  '||nspname ||'.'|| relname ||' set '
        || string_agg(attname || '='|| attname
                          ||'+make_interval(weeks=>' || p_weeks ||')', ',')
        ||';'
from pg_class r
         join pg_attribute a on a.attrelid=r.oid
         join pg_type t on t.oid=a.atttypid
         join  pg_namespace n on relnamespace = n.oid
where relkind='r'
  and attnum>0
  and n.nspname  = p_schema_name
  and typname  in ('timestamptz','timestamp')
group  by  nspname, relname
order by  nspname, relname
    loop
   raise notice $$ - % $$, stmt;
if p_run
   then execute stmt;
end if;
end loop;
end;
$fun$;

alter procedure advance_air_time(integer, text, boolean) owner to postgres;

