
CREATE OR REPLACE SCHEMA EDR;
ALTER PUMP EDR.* STOP;
DROP SCHEMA EDR CASCADE;
CREATE OR REPLACE SCHEMA EDR;
SET SCHEMA 'EDR';
SET PATH 'EDR';

CREATE OR REPLACE FOREIGN STREAM Flows_parsed_fs(
load_ts VARCHAR(32),
eventtime VARCHAR(32),
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
data_dt VARCHAR(16)
)
SERVER FILE_SERVER
OPTIONS (
PARSER 'CSV',
CHARACTER_ENCODING 'UTF-8',
SKIP_HEADER 'false',
DIRECTORY '/tmp',
-- FILENAME_PATTERN 'repro.txt' 
FILENAME_PATTERN 'repro.*' 
);

CREATE OR REPLACE VIEW Step_1 AS
    SELECT STREAM sessionid,
        CASE WHEN CHAR_LENGTH(eventtime) = 22 THEN SUBSTRING(eventtime, 1, 19) || '.000' ELSE eventtime END AS eventtime,
        CAST(uplinkoctets AS BIGINT) as uplinkoctets, CAST(downlinkoctets AS BIGINT) as downlinkoctets, 
        CAST(uplinkpackets AS BIGINT) as uplinkpackets, CAST(downlinkpackets AS BIGINT) as downlinkpackets, 
        CAST(uplinkdropoctets AS BIGINT) as uplinkdropoctets, CAST(downlinkdropoctets AS BIGINT) as downlinkdropoctets, 
        CAST(uplinkdroppackets AS BIGINT) as uplinkdroppackets, CAST(downlinkdroppackets AS BIGINT) as downlinkdroppackets
    FROM Flows_parsed_fs AS input;

CREATE OR REPLACE VIEW Step_3 AS
    SELECT STREAM sessionid as sessionid, CAST(eventtime AS TIMESTAMP) AS ROWTIME, uplinkoctets + downlinkoctets + uplinkdropoctets + downlinkdropoctets AS Octets, uplinkpackets + downlinkpackets + uplinkdroppackets + downlinkdroppackets AS Packets
    FROM Step_1 AS input;

CREATE OR REPLACE VIEW Agg1View AS
SELECT STREAM sessionid, Octets, 
Avg(Octets) OVER w + 2 * stddev_pop(Octets) OVER w as upper_bb,
Avg(Octets) OVER w - 2 * stddev_pop(Octets) OVER w as lower_bb
FROM Step_3 as s 
WINDOW w AS (PARTITION BY sessionid
RANGE BETWEEN INTERVAL '60' MINUTE PRECEDING
AND CURRENT ROW);

SELECT STREAM ROWTIME, * FROM STREAM(DATA_RATE_RPS(CURSOR (SELECT STREAM * FROM Agg1View)));
