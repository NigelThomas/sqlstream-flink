alter session set "llvm.enabled" = 'true';

CREATE OR REPLACE SCHEMA EDR;
ALTER PUMP EDR.* STOP;
DROP SCHEMA EDR CASCADE;
CREATE OR REPLACE SCHEMA EDR;
SET SCHEMA 'EDR';
SET PATH 'EDR';

CREATE OR REPLACE FOREIGN STREAM Flows_fs(
load_ts VARCHAR(32),
eventtime VARCHAR(32),
creationtime VARCHAR(32),
lastaccesstime VARCHAR(32),
flowid VARCHAR(8),
bearerid VARCHAR(4),
sessionid int,
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
data_dt VARCHAR(16)
)
SERVER FILE_SERVER
OPTIONS (
PARSER 'CSV',
CHARACTER_ENCODING 'UTF-8',
SKIP_HEADER 'false',
DIRECTORY $(INGESTION_DIR) DEFAULT '/tmp',
FILENAME_PATTERN 'flows_.*csv' 
);

CREATE OR REPLACE FOREIGN STREAM Sessions_fs
(
load_ts TIMESTAMP,
sessionid int,
eventtime VARCHAR(32),
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
uplinkdropoctets VARCHAR(8),
uplinkdroppackets VARCHAR(8),
downlinkdropoctets VARCHAR(8),
downlinkdroppackets VARCHAR(8),
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
data_dt VARCHAR(16)
)
SERVER FILE_SERVER
OPTIONS (
PARSER 'CSV',
CHARACTER_ENCODING 'UTF-8',
SEPARATOR ',',
--SKIP_HEADER 'true',
--FILE_TYPE 'none',
DIRECTORY '/tmp',
FILENAME_PATTERN 'sessions_.*'
);

-- Flows ingestion pipeline
CREATE OR REPLACE VIEW Flows_ingestion_step_1 AS
SELECT STREAM 
        CASE WHEN CHAR_LENGTH(eventtime) = 22 THEN SUBSTRING(eventtime, 1, 19) || '.000' ELSE eventtime END AS eventtime,
	sessionid,
        CAST(uplinkoctets AS BIGINT) + CAST(downlinkoctets AS BIGINT)  +
        CAST(uplinkdropoctets AS BIGINT) + CAST(downlinkdropoctets AS BIGINT) as Octets,
        CAST(uplinkpackets AS BIGINT) + CAST(downlinkpackets AS BIGINT) +
        CAST(uplinkdroppackets AS BIGINT) + CAST(downlinkdroppackets AS BIGINT) as Packets
FROM Flows_fs;

CREATE OR REPLACE VIEW Flows_ingestion_step_2 AS
    SELECT STREAM CAST(eventtime AS TIMESTAMP) AS ROWTIME, *
    FROM Flows_ingestion_step_1 AS input;

CREATE OR REPLACE STREAM Flows_ingestion_out_ns (
eventtime VARCHAR(32),
sessionid int,
octets BIGINT,
packets BIGINT
);

-- Sessions ingestion pipeline
CREATE OR REPLACE VIEW Sessions_ingestion_step_1 AS
SELECT STREAM sessionid,
CASE WHEN CHAR_LENGTH(eventtime) = 22 THEN SUBSTRING(eventtime, 1, 19) || '.000' ELSE eventtime END AS eventtime,
ecgieci
from Sessions_fs;

CREATE OR REPLACE VIEW Sessions_ingestion_step_2 AS
SELECT STREAM CAST(eventtime as TIMESTAMP) as ROWTIME, sessionid, eventtime, ecgieci as cellid
FROM Sessions_ingestion_step_1;

CREATE OR REPLACE STREAM Sessions_ingestion_out_ns
(
sessionid int,
eventtime VARCHAR(32),
cellid VARCHAR(16)
);

CREATE OR REPLACE PUMP sessions_pump STOPPED OPTIONS ("llvm.enabled" 'true') AS
INSERT INTO Sessions_ingestion_out_ns SELECT STREAM * FROM Sessions_ingestion_step_2;

-- Agg pipeline
CREATE OR REPLACE VIEW Flows_agg_step_0 AS
    SELECT STREAM *
    FROM Flows_ingestion_out_ns AS input
    WHERE MOD(sessionid, $(num_shards as INT)) = $(shard as int)
    ;

CREATE OR REPLACE VIEW "Flows_agg_Sessions_shard_view" AS
SELECT STREAM * FROM Sessions_ingestion_out_ns 
WHERE MOD(sessionid, $(num_shards as INT)) = $(shard as INT)
;

CREATE OR REPLACE VIEW Flows_agg_step_1 AS
SELECT STREAM sessionid,
Min(Octets) OVER w as minOctets, max(Octets) OVER w as maxOctets,
Sum(Octets) OVER w as sumOctets, Count(Octets) OVER w as countOctets
FROM Flows_agg_step_0 as s 
WINDOW w AS (PARTITION BY sessionid
ORDER BY FLOOR(s.ROWTIME TO MINUTE)
RANGE BETWEEN INTERVAL '60' MINUTE PRECEDING
AND INTERVAL '1' MINUTE PRECEDING);

CREATE OR REPLACE VIEW Flows_agg_step_2 AS
SELECT STREAM lhs.sessionid as sessionid, cellid, minOctets, maxOctets, sumOctets, countOctets
from Flows_agg_step_1 as lhs
INNER JOIN "Flows_agg_Sessions_shard_view" OVER (RANGE INTERVAL '5' MINUTE PRECEDING) as rhs
-- INNER JOIN Step_4 OVER (PARTITION BY SESSION ON sessionid TIMEOUT AFTER INTERVAL '1' HOUR ROWS CURRENT ROW) as rhs
ON (lhs.sessionid = rhs.sessionid );

CREATE OR REPLACE STREAM Flows_agg_out_ns (
sessionid int,
cellid varchar(16),
minOctets bigint,
maxOctets bigint,
sumOctets bigint,
countOctets bigint
);

CREATE OR REPLACE VIEW datarate_view AS
SELECT STREAM CURRENT_ROW_TIMESTAMP AS ROWTIME, 1 FROM EDR.Flows_ingestion_out_ns;

CREATE OR REPLACE PUMP Flows_pump_0 STOPPED OPTIONS (ingestion_dir '/tmp') AS
INSERT INTO Flows_ingestion_out_ns SELECT STREAM * FROM Flows_ingestion_step_2;

CREATE OR REPLACE PUMP Flows_pump_1 STOPPED OPTIONS (ingestion_dir '/tmp') AS
INSERT INTO Flows_ingestion_out_ns SELECT STREAM * FROM Flows_ingestion_step_2;

CREATE OR REPLACE PUMP p0 STOPPED OPTIONS (num_shards '2', shard '0') AS
INSERT INTO Flows_agg_out_ns SELECT STREAM * FROM Flows_agg_step_2;

CREATE OR REPLACE PUMP p1 STOPPED OPTIONS (num_shards '2', shard '1') AS
INSERT INTO Flows_agg_out_ns SELECT STREAM * FROM Flows_agg_step_2;

ALTER PUMP EDR.* SET "llvm.enabled" = 'true';

-- This filter finds rows to be processed by each shard
-- WHERE MOD(sessionid, $(num_shards as INT)) = $(shard as INT)
-- Set the shard number for each pump
ALTER PUMP EDR.p0 SET shard = '0';
ALTER PUMP EDR.p1 SET shard = '1';
