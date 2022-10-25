SET SCHEMA 'EDR';
SET PATH 'EDR';

ALTER PUMP EDR.* STOP;
ALTER STREAM EDR.* RESET;

-- Set the number of shards to start
ALTER PUMP EDR.p0, EDR.p1 SET num_shards = '2';

ALTER PUMP
     EDR.sessions_pump
     , EDR.Flows_pump_0 , EDR.p0
     -- comment out the line below when num_shards = 1
     , EDR.Flows_pump_1 , EDR.p1
   START;


SELECT STREAM AVG(RPS) OVER (RANGE UNBOUNDED PRECEDING) FROM (select stream count(*) as rps from EDR.datarate_view as s group by floor(s.rowtime to second));
