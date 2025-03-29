CREATE EXTENSION pg_buffercache;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create a test table with 1 million rows
CREATE TABLE large_table AS
SELECT generate_series(1, 1000000) as id,
       md5(random()::text)         as random_text;

-- Clear statistics
SELECT pg_stat_reset();

-- Clear buffer cache
SELECT pg_prewarm('large_table', 'buffer');

-- Run a query that will cache data
SELECT COUNT(*)
FROM large_table
WHERE id < 100000;

-- Check what's in the buffer cache
SELECT c.relname, count(*) AS buffers
FROM pg_class c
         JOIN pg_buffercache b ON b.relfilenode = c.relfilenode
WHERE c.relname = 'large_table'
GROUP BY c.relname;

-- Run some queries, then check their statistics
SELECT query,
       calls,
       total_exec_time / calls as avg_time,
       rows / calls            as avg_rows
FROM pg_stat_statements
WHERE query LIKE '%large_table%'
ORDER BY total_exec_time DESC
LIMIT 5;

-- View cache hit ratios for tables
SELECT relname,
       heap_blks_read,
       heap_blks_hit,
       heap_blks_hit::float / (heap_blks_hit + heap_blks_read) as hit_ratio
FROM pg_statio_user_tables
WHERE heap_blks_hit + heap_blks_read > 0
ORDER BY hit_ratio DESC;

-- Check cache hit ratios without extensions
SELECT relname        AS table_name,
       heap_blks_read AS disk_reads,
       heap_blks_hit  AS cache_hits,
       CASE
           WHEN heap_blks_hit + heap_blks_read = 0 THEN 0
           ELSE heap_blks_hit::float / (heap_blks_hit + heap_blks_read)
           END        AS hit_ratio
FROM pg_statio_user_tables
ORDER BY heap_blks_hit + heap_blks_read DESC
LIMIT 10;

-- show config path of postgres
SHOW config_file;

--
-- Create a table with different column sizes
CREATE TABLE employee
(
    id        INT,
    name      VARCHAR(100),
    bio       TEXT,
    salary    NUMERIC(10, 2),
    hire_date DATE
);

-- Insert some data
INSERT INTO employee
VALUES (1, 'Alice Smith', 'Software Engineer with 5 years experience', 75000.00, '2018-03-15'),
       (2, 'Bob Jones', 'Database Administrator specializing in PostgreSQL performance tuning', 85000.00, '2017-06-20'),
       (3, 'Carol Williams', 'Project Manager with agile certification', 90000.00, '2019-01-10');

-- Install pageinspect extension if needed
CREATE EXTENSION IF NOT EXISTS pageinspect;

-- Look at raw page contents
SELECT lp, t_xmin, t_xmax, t_field3, t_ctid, t_infomask2, t_infomask, t_hoff, t_bits, t_oid,
       LENGTH(t_data) as datalen,
       SUBSTRING(t_data::text FROM 1 FOR 30) as data_start
FROM heap_page_items(get_raw_page('employee', 0));

-- Create tables with different row sizes
CREATE TABLE small_rows (id INT, small_text CHAR(10));
CREATE TABLE medium_rows (id INT, med_text CHAR(100));
CREATE TABLE large_rows (id INT, large_text CHAR(1000));

-- Insert many rows
INSERT INTO small_rows SELECT generate_series(1,1000), 'small';
INSERT INTO medium_rows SELECT generate_series(1,100), repeat('m', 100);
INSERT INTO large_rows SELECT generate_series(1,10), repeat('l', 1000);

-- Check how many pages each table uses (each page = 8192 bytes)
SELECT pg_relation_size('small_rows') / 8192 AS small_rows_pages,
       pg_relation_size('medium_rows') / 8192 AS medium_rows_pages,
       pg_relation_size('large_rows') / 8192 AS large_rows_pages;

-- TOAST (The Oversized-Attribute Storage Technique): mechanism for storing large data types
-- Create a table with potentially large text
CREATE TABLE articles (
                          id INT,
                          title VARCHAR(200),
                          content TEXT  -- This can be TOASTed
);

-- Insert large content
INSERT INTO articles VALUES
    (1, 'PostgreSQL Storage', repeat('This is an article about PostgreSQL storage. ', 1000));

-- Check TOAST usage
SELECT relname, reltoastrelid::regclass AS toast_table,
       pg_total_relation_size(oid) AS total_bytes,
       pg_total_relation_size(reltoastrelid) AS toast_bytes
FROM pg_class
WHERE relname = 'articles';
SELECT pg_relation_size('articles') / 8192 AS articles_pages;

-- Check for table bloat
SELECT
    current_database(), schemaname, tablename,
    pg_size_pretty(bs*tblpages::bigint) AS table_size,
    pg_size_pretty(bs*tblpages-pg_relation_size(schemaname||'.'||tablename)) AS bloat_size
FROM (
         SELECT
             ceil(tblpages/hpps) as heap_pages_per_segment,
             schemaname, tablename, bs,
             tblpages, heappages
         FROM (
                  SELECT
                      schemaname, tablename, bs,
                      tblpages, heappages,
                      ceil(heappages/(ceil(heappages/32)::bigint)) as hpps
                  FROM (
                           SELECT
                               n.nspname as schemaname,
                               c.relname as tablename,
                               (SELECT current_setting('block_size')::numeric) as bs,
                               CASE WHEN c.relpages > 0 THEN c.relpages
                                    ELSE pg_relation_size(c.oid) / (SELECT current_setting('block_size')::numeric)
                                   END as tblpages,
                               pg_relation_size(c.oid) / (SELECT current_setting('block_size')::numeric) as heappages
                           FROM pg_class c
                                    LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                           WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog','information_schema')
                       ) a
              ) b
     ) c
WHERE schemaname = 'public'
ORDER BY bloat_size DESC;