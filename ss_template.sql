
SELECT STREAM s.ROWTIME, *
     , cast(cast ((last_value(s.rowtime) over rw - first_value(s.rowtime) over rw) second(4) as varchar(8)) as integer) as "TestSecs"
FROM STREAM (DATA_RATE_RPS(CURSOR (SELECT STREAM * FROM EDR.viewname))) s
-- don't show rows where progress has stopped
WHERE RPS > 0
WINDOW RW AS (ROWS 2000 PRECEDING)
;
