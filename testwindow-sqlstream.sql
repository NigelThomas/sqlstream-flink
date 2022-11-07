CREATE OR REPLACE SCHEMA test;
SET SCHEMA 'test';

CREATE OR REPLACE FOREIGN STREAM testwindow_fs
(   event_time TIMESTAMP
,   c1 varchar(4)
)
    SERVER FILE_SERVER
OPTIONS (
-- using STATIC_FILES results in the stream closing at end of file, so the benchmark run ends (as for Flink)
STATIC_FILES 'true',
PARSER 'CSV',
CHARACTER_ENCODING 'UTF-8',
SKIP_HEADER 'false',
DIRECTORY '/tmp',
FILENAME_PATTERN 'testwindow.dat' 
);

CREATE OR REPLACE VIEW testwindow_v1
AS
SELECT STREAM event_time AS ROWTIME
     , event_time
     , c1
FROM testwindow_fs
;

CREATE OR REPLACE VIEW testwindow_v2
AS
SELECT STREAM event_time, c1
, MIN(event_time) OVER w as min_et
, MAX(event_time) OVER w as max_et
, MIN(c1) OVER w as min_c1
, MAX(c1) OVER w as max_c1
, COUNT(*) OVER w as cnt
FROM testwindow_v1 s
WINDOW w AS (ORDER BY FLOOR(s.ROWTIME TO MINUTE) RANGE INTERVAL '2' MINUTE PRECEDING);
