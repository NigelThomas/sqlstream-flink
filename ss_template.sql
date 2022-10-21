alter session set "llvm.enabled" = 'true';

SELECT STREAM s.ROWTIME, *
FROM STREAM(DATA_RATE_RPS(CURSOR (SELECT STREAM * FROM EDR.viewname))) s;
