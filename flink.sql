SET 'sql-client.execution.result-mode'='TABLEAU';
SET 'execution.runtime-mode' = 'streaming';

CREATE OR REPLACE TABLE flows_fs
(
load_ts VARCHAR(32),
event_time VARCHAR(32),
-- eventtime as CASE WHEN CHAR_LENGTH(event_time) = 22 THEN FLOOR(TO_TIMESTAMP(SUBSTRING(event_time, 1, 19) || '.000') TO MINUTE) ELSE FLOOR(TO_TIMESTAMP(event_time) TO MINUTE) END ,
eventtime as CASE WHEN CHAR_LENGTH(event_time) = 22 THEN TO_TIMESTAMP(SUBSTRING(event_time, 1, 19) || '.000') ELSE TO_TIMESTAMP(event_time) END ,
creationtime VARCHAR(32),
lastaccesstime VARCHAR(32),
flowid VARCHAR(8),
bearerid VARCHAR(4),
sessionid VARCHAR(16),
recordtype VARCHAR(32),
reserved00 VARCHAR(4),
reserved01 VARCHAR(4),
reserved02 VARCHAR(4),
reserved03 VARCHAR(4),
protocol VARCHAR(4),
uplinkoctets VARCHAR(16),
uplinkpackets VARCHAR(16),
downlinkoctets VARCHAR(16),
downlinkpackets VARCHAR(16),
uplinkdropoctets VARCHAR(16),
uplinkdroppackets VARCHAR(16),
downlinkdropoctets VARCHAR(16),
downlinkdroppackets VARCHAR(16),
dpiapplication VARCHAR(32),
dpirealprotocol VARCHAR(16),
protoinfoprotocol VARCHAR(4),
subprotocoltype VARCHAR(4),
subprotocolvalue VARCHAR(8),
operatingsystem VARCHAR(16),
operatingsystemversion VARCHAR(8),
im_si VARCHAR(16),
uplinkretranspackets VARCHAR(8),
uplinkretransbytes VARCHAR(8),
downlinkretranspackets VARCHAR(8),
downlinkretransbytes VARCHAR(8),
initialrtt VARCHAR(8),
httpttfbtime VARCHAR(8),
dpiprotocolattributes VARCHAR(16),
dpitransferredcontent VARCHAR(16),
dpilayer7protocol VARCHAR(4),
applicationattributes VARCHAR(4),
ulinitrtttime VARCHAR(8),
dlinitrtttime VARCHAR(8),
ulflowactivityduration VARCHAR(8),
dlflowactivityduration VARCHAR(16),
ulflowpeakthroughput VARCHAR(8),
dlflowpeakthroughput VARCHAR(8),
ulsessionactivityduration VARCHAR(8),
dlsessionactivityduration VARCHAR(8),
ulsessionpeakthroughput VARCHAR(8),
dlsessionpeakthroughput VARCHAR(8),
bucketname VARCHAR(4),
bucketmin VARCHAR(8),
bucketmax VARCHAR(8),
buckettime VARCHAR(8),
bucketdirection VARCHAR(4),
tetheringentitled VARCHAR(8),
tetheredflow VARCHAR(8),
tetheringalgorithm VARCHAR(4),
protoinfosubprotocol VARCHAR(4),
closurereason VARCHAR(16),
cplanesessionid VARCHAR(8),
qualityindex VARCHAR(4),
reserved1 VARCHAR(4),
reserved2 VARCHAR(4),
reserved3 VARCHAR(4),
reserved4 VARCHAR(4),
reserved5 VARCHAR(4),
reserved6 VARCHAR(4),
reserved7 VARCHAR(4),
reserved8 VARCHAR(4),
reserved9 VARCHAR(4),
reserved10 VARCHAR(4),
data_dt VARCHAR(16),
WATERMARK FOR eventtime AS eventtime - INTERVAL '0.001' SECOND
)
WITH (
'connector' = 'filesystem',
-- 'path' = 'file:///tmp/f_20210124_1.resorted.txt',
'path' = 'file:///tmp/flows_all.csv',
'format' = 'csv',
'csv.disable-quote-character' = 'true'
);

CREATE TABLE sessions_fs
(
load_ts VARCHAR(32),
sessionid VARCHAR(8),
event_time VARCHAR(32),
--eventtime as CASE WHEN CHAR_LENGTH(event_time) = 22 THEN FLOOR(TO_TIMESTAMP(SUBSTRING(event_time, 1, 19) || '.000') TO MINUTE) ELSE FLOOR(TO_TIMESTAMP(event_time) TO MINUTE) END ,
eventtime as CASE WHEN CHAR_LENGTH(event_time) = 22 THEN TO_TIMESTAMP(SUBSTRING(event_time, 1, 19) || '.000') ELSE TO_TIMESTAMP(event_time) END ,
recordtype VARCHAR(32),
gwtype VARCHAR(32),
im_si VARCHAR(16),
msisdn VARCHAR(16),
imeisv VARCHAR(32),
meid VARCHAR(4),
mnnai VARCHAR(4),
reserved00 VARCHAR(4),
pdptype VARCHAR(32),
timezone VARCHAR(4),
dst VARCHAR(4),
pdnconnectionid VARCHAR(8),
accessoutintftype VARCHAR(32),
reserved01 VARCHAR(4),
accessoutteid VARCHAR(16),
accessinintftype VARCHAR(32),
reserved02 VARCHAR(4),
accessinteid VARCHAR(8),
networkoutintftype VARCHAR(4),
networkoutipaddress VARCHAR(4),
networkoutteid VARCHAR(8),
networkinintftype VARCHAR(4),
networkinipaddress VARCHAR(4),
networkinteid VARCHAR(8),
starttime VARCHAR(32),
stoptime VARCHAR(8),
nodeaddress VARCHAR(16),
nodeipaddrtype VARCHAR(32),
nodetype VARCHAR(32),
nodeplmnidmcc VARCHAR(8),
nodeplmnidmnc VARCHAR(8),
apnid VARCHAR(8),
rattype VARCHAR(32),
gwaddress VARCHAR(16),
gwipaddrtype VARCHAR(32),
gwnodeid VARCHAR(16),
gwplmnidmcc VARCHAR(8),
gwplmnidmnc VARCHAR(8),
recordtriggercause VARCHAR(4),
uplinkoctets VARCHAR(16),
uplinkpackets VARCHAR(16),
downlinkoctets VARCHAR(16),
downlinkpackets VARCHAR(16),
uplinkdropoctets VARCHAR(16),
uplinkdroppackets VARCHAR(16),
downlinkdropoctets VARCHAR(16),
downlinkdroppackets VARCHAR(16),
triggercause VARCHAR(32),
closeinfoinit VARCHAR(4),
closeinfocausecode VARCHAR(8),
gtpcausecodeforattempts VARCHAR(4),
mbruplink VARCHAR(8),
mbrdownlink VARCHAR(16),
csgid VARCHAR(8),
csgaccessmode VARCHAR(8),
csgmembership VARCHAR(8),
cgimnc VARCHAR(8),
cgici VARCHAR(8),
cgimcc VARCHAR(8),
cgilac VARCHAR(8),
laimnc VARCHAR(8),
laimcc VARCHAR(8),
lailac VARCHAR(8),
saimnc VARCHAR(8),
saisac VARCHAR(8),
saimcc VARCHAR(8),
sailac VARCHAR(8),
raimnc VARCHAR(8),
rairac VARCHAR(8),
raimcc VARCHAR(8),
railac VARCHAR(8),
taimnc VARCHAR(8),
taitac VARCHAR(8),
taimcc VARCHAR(8),
ecgimnc VARCHAR(8),
ecgieci VARCHAR(16),
ecgimcc VARCHAR(8),
locextclosereason VARCHAR(8),
ulsessionactivityduration VARCHAR(16),
dlsessionactivityduration VARCHAR(16),
ulsessionpeakthroughput VARCHAR(16),
dlsessionpeakthroughput VARCHAR(16),
aggrtime VARCHAR(32),
bucketname VARCHAR(16),
bucketmin VARCHAR(4),
bucketmax VARCHAR(8),
buckettime VARCHAR(8),
bucketdirection VARCHAR(8),
uplanesessionid VARCHAR(8),
realapn VARCHAR(8),
reserved1 VARCHAR(4),
reserved2 VARCHAR(4),
reserved3 VARCHAR(4),
reserved4 VARCHAR(4),
reserved5 VARCHAR(4),
reserved6 VARCHAR(4),
reserved7 VARCHAR(4),
reserved8 VARCHAR(4),
data_dt VARCHAR(16),
WATERMARK FOR eventtime as eventtime - INTERVAL '0.001' SECOND
)
WITH(
'connector' = 'filesystem',
'path' = 'file:///tmp/sessions_all.csv',
'format' = 'csv',
'csv.disable-quote-character' = 'true'
);

CREATE OR REPLACE VIEW parse_view AS
SELECT * FROM flows_fs;

CREATE OR REPLACE VIEW flows_step_1 AS
    SELECT sessionid, 
        eventtime,
        CAST(uplinkoctets AS BIGINT) as uplinkoctets, CAST(downlinkoctets AS BIGINT) as downlinkoctets,
        CAST(uplinkpackets AS BIGINT) as uplinkpackets, CAST(downlinkpackets AS BIGINT) as downlinkpackets,
        CAST(uplinkdropoctets AS BIGINT) as uplinkdropoctets, CAST(downlinkdropoctets AS BIGINT) as downlinkdropoctets,
        CAST(uplinkdroppackets AS BIGINT) as uplinkdroppackets, CAST(downlinkdroppackets AS BIGINT) as downlinkdroppackets
FROM flows_fs;

CREATE OR REPLACE VIEW sessions_step_1 AS
SELECT sessionid, 
       eventtime,
        ecgieci
from sessions_fs;

CREATE OR REPLACE VIEW flows_step_2 AS
    SELECT sessionid as sessionid
         , eventtime
         , uplinkoctets + downlinkoctets + uplinkdropoctets + downlinkdropoctets AS Octets
         , uplinkpackets + downlinkpackets + uplinkdroppackets + downlinkdroppackets AS Packets
    FROM flows_step_1 AS input;

CREATE OR REPLACE VIEW projection_view AS
SELECT * FROM flows_step_2;

CREATE OR REPLACE VIEW sessions_step_2 AS
SELECT sessionid, eventtime, ecgieci as cellid
FROM sessions_step_1;


CREATE OR REPLACE VIEW agg_view AS
SELECT sessionid, Octets, eventtime,
Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
FROM projection_view as s
WINDOW w AS (PARTITION BY sessionid
            ORDER BY eventtime
            RANGE BETWEEN INTERVAL '60' MINUTE PRECEDING AND CURRENT ROW);

-- include variants of agg_view with varying window sizes 60m, 20m, 10m, 5m, 2m, 1m

CREATE OR REPLACE VIEW agg_view_60m AS
SELECT sessionid, Octets, eventtime,
Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
FROM projection_view as s
WINDOW w AS (PARTITION BY sessionid
            ORDER BY eventtime
            RANGE BETWEEN INTERVAL '60' MINUTE PRECEDING AND CURRENT ROW);

CREATE OR REPLACE VIEW agg_view_20m AS
SELECT sessionid, Octets, eventtime,
Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
FROM projection_view as s
WINDOW w AS (PARTITION BY sessionid
            ORDER BY eventtime
            RANGE BETWEEN INTERVAL '20' MINUTE PRECEDING AND CURRENT ROW);

CREATE OR REPLACE VIEW agg_view_10m AS
SELECT sessionid, Octets, eventtime,
Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
FROM projection_view as s
WINDOW w AS (PARTITION BY sessionid
            ORDER BY eventtime
            RANGE BETWEEN INTERVAL '10' MINUTE PRECEDING AND CURRENT ROW);

CREATE OR REPLACE VIEW agg_view_5m AS
SELECT sessionid, Octets, eventtime,
Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
FROM projection_view as s
WINDOW w AS (PARTITION BY sessionid
            ORDER BY eventtime
            RANGE BETWEEN INTERVAL '5' MINUTE PRECEDING AND CURRENT ROW);

CREATE OR REPLACE VIEW agg_view_2m AS
SELECT sessionid, Octets, eventtime,
Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
FROM projection_view as s
WINDOW w AS (PARTITION BY sessionid
            ORDER BY eventtime
            RANGE BETWEEN INTERVAL '2' MINUTE PRECEDING AND CURRENT ROW);

CREATE OR REPLACE VIEW agg_view_1m AS
SELECT sessionid, Octets, eventtime,
Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
FROM projection_view as s
WINDOW w AS (PARTITION BY sessionid
            ORDER BY eventtime
            RANGE BETWEEN INTERVAL '1' MINUTE PRECEDING AND CURRENT ROW);


--Join Query
CREATE OR REPLACE VIEW join_view AS
SELECT lhs.sessionid as sessionid, lhs.eventtime as eventtime, cellid, Octets, Packets
from projection_view as lhs
INNER JOIN sessions_step_2 as rhs
ON (lhs.sessionid = rhs.sessionid AND lhs.eventtime BETWEEN rhs.eventtime - INTERVAL '5' MINUTE AND rhs.eventtime);

CREATE OR REPLACE VIEW join_n_agg_view AS
SELECT cellid, Octets, eventtime,
Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
FROM join_view as s
WINDOW w AS (PARTITION BY cellid
            ORDER BY eventtime
            RANGE BETWEEN INTERVAL '60' MINUTE PRECEDING AND CURRENT ROW)
            ;


