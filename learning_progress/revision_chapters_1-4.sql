CREATE EXTENSION pg_buffercache;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create a test table with 1 million rows
CREATE TABLE large_table AS
SELECT generate_series(1, 1000000) as id,
       md5(random()::text) as random_text;

-- Clear statistics
SELECT pg_stat_reset();

-- Clear buffer cache
SELECT pg_prewarm('large_table', 'buffer');

-- Run a query that will cache data
SELECT COUNT(*) FROM large_table WHERE id < 100000;

-- Check what's in the buffer cache
SELECT c.relname, count(*) AS buffers
FROM pg_class c
         JOIN pg_buffercache b ON b.relfilenode = c.relfilenode
WHERE c.relname = 'large_table'
GROUP BY c.relname;

-- Run some queries, then check their statistics
SELECT query, calls,
       total_exec_time / calls as avg_time,
       rows / calls as avg_rows
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
SELECT
    relname AS table_name,
    heap_blks_read AS disk_reads,
    heap_blks_hit AS cache_hits,
    CASE WHEN heap_blks_hit + heap_blks_read = 0 THEN 0
         ELSE heap_blks_hit::float / (heap_blks_hit + heap_blks_read)
        END AS hit_ratio
FROM pg_statio_user_tables
ORDER BY heap_blks_hit + heap_blks_read DESC
LIMIT 10;

-- show config path of postgres
SHOW config_file;