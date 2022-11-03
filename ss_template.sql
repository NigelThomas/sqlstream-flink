
SELECT STREAM s.ROWTIME, *
       , cast((unix_timestamp(s.rowtime) - unix_timestamp(current_timestamp))/1000 as int) as "TestSecs"
FROM STREAM (DATA_RATE_RPS(CURSOR (SELECT STREAM * FROM EDR.viewname))) s
-- don't show rows where progress has stopped
WHERE RPS > 0
;
