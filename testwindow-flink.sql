SET 'sql-client.execution.result-mode'='TABLEAU';
SET 'execution.runtime-mode' = 'streaming';

CREATE TABLE testwindow_fs
(   event_time TIMESTAMP(3)
,   c1 varchar(4)
,   event_time_mins AS FLOOR(event_time TO MINUTE)
, WATERMARK FOR event_time_mins as event_time_mins - INTERVAL '0.001' SECOND
)
WITH(
'connector' = 'filesystem',
'path' = 'file:///tmp/testwindow.dat',
'format' = 'csv',
'csv.disable-quote-character' = 'true'
);

CREATE OR REPLACE VIEW testwindow_v1
AS
SELECT event_time
     , event_time_mins
     , c1
FROM testwindow_fs
;

CREATE VIEW IF NOT EXISTS testwindow_v2 
AS
SELECT CAST(event_time AS TIME(3)) as event_time, c1
, CAST(MIN(event_time) OVER w AS TIME(3)) as min_et 
, CAST(MAX(event_time) OVER w AS TIME(3))  as max_et
, MIN(c1) OVER w as min_c1
, MAX(c1) OVER w as max_c1
, COUNT(*) OVER w as cnt
FROM testwindow_v1 s
WINDOW w AS (ORDER BY event_time_mins RANGE INTERVAL '2' MINUTE PRECEDING);
