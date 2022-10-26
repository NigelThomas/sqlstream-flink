# edrgen.py
#
# - Generates flows and sessions

import random
import string
import argparse
import logging
import time
from datetime import datetime, timedelta
import sys

logger = logging.getLogger('edrgen')
logger.setLevel(logging.DEBUG)

ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)

formatter = logging.Formatter('%(asctime)s - %(message)s')
ch.setFormatter(formatter)

logger.addHandler(ch)

out_delim_default = ','

# return random as a string
def getRandomNumberInRange(min, max):
    return str(random.randint(min,max))

burst_array = []

# define the distribution profile for bursts of flows
# IRL there is a long tail (out to several 100) but frequencies are very low
cumul_dist = [385,594, 689, 763, 807, 845, 867, 888, 903, 917
    , 928, 937, 944, 950, 955, 960, 964, 967, 970, 973
    , 975, 977, 979, 981, 982, 984, 985, 986, 987, 988
    , 989, 990, 991, 992, 993, 994, 994, 995, 996, 996,
    1000 ]

# map the profile to a flat array to speed access
cdi = 0
cumul_total = 0

for i in range(0,cumul_dist[-1]):
    burst_array.append(cdi+1)
    cumul_total += cdi+1
    if i == cumul_dist[cdi]:
        cdi += 1    
#logger.debug("burst_array = "+str(burst_array))
avg_burst_count = float(cumul_total) / float(len(burst_array))
#logger.debug("cum total: %d, array_size: %d, avg_burst_count %f" % (cumul_total, len(burst_array), avg_burst_count))


# how many flows to burst for current session
def get_burst_count():
    return burst_array[random.randint(0,len(burst_array)-1)]

# def randomstring(length):
#     return (''.join([random.choice(string.ascii_letters) for i in range(length)]))

# version where we pick a random slice of the correct length; halves number of randoms and replace join with a slice
# so letters in a string will be successive

def randomstring(length):
    start = random.randint(0,len(string.ascii_letters))
    return (string.ascii_letters + string.ascii_letters)[start:start+length]

def random_tonnage(maxtonnage):

    # get a basic tonnage
    dtonnage = random.randint(0,maxtonnage)
    utonnage = random.randint(0,maxtonnage)

    # use same drop probability for up/down/octets/packets for simplicity
    drop_prob = (dtonnage) % 10 / 20

    # half of the records will have zero drops
    if drop_prob < 0.25:
        drop_prob = 0

    uplinkoctets = dtonnage
    downlinkoctets = utonnage
    uplinkdropoctets = int(uplinkoctets*drop_prob)
    downlinkdropoctets = int(downlinkoctets*drop_prob)

    # to avoid more randomisation, just base packets on tonnage
       
    uplinkpackets = int(dtonnage / 100)
    downlinkpackets = int(utonnage / 100)
    uplinkdroppackets = int(uplinkpackets*drop_prob)
    downlinkdroppackets = int(downlinkpackets*drop_prob)

    return [ str(uplinkoctets), str(uplinkpackets)
              , str(downlinkoctets), str(downlinkpackets)
              , str(uplinkdropoctets), str(uplinkdroppackets)
              , str(downlinkdropoctets), str(downlinkdroppackets) ]   

def get_filename(file_prefix, epoch_time, file_suffix):
    if file_prefix == '-':
        return file_prefix
    elif args.write_to_pipe:
        return args.tempdir+"/"+file_prefix
    else:
        return args.tempdir+"/"+file_prefix + "_" + time.strftime("%d%m%Y%H%M%S", time.localtime(epoch_time)) + "_" + file_suffix


def close_file(filedict):
    logger.debug("Closing file %s after writing %d records" % (filedict['name'], filedict['records']))
    filedict['handle'].close
    filedict['handle'] = {}
    filedict['records'] = 0

def open_file(filedict, fileprefix, filesuffix, filetime, fileheader):
    # TODO add a header?
    filestem = "%s%s" % (fileprefix, filetime)

    filedict['name'] = filestem + filesuffix
    filedict['records'] = 0

    logger.debug("Opening file %s",filedict['name'])
    filedict['handle'] = open(filedict['name'], "w")
    if fileheader:
        filedict['handle'].write("%s\n" % fileheader)

def write_flow(filedict, eventtime, session, tonnage, delimiter):
# field defintions for flows:
    # load_ts VARCHAR(32),
    # 1: eventtime VARCHAR(32),
    # creationtime VARCHAR(32),
    # lastaccesstime VARCHAR(32),
    # flowid VARCHAR(8),
    # bearerid VARCHAR(4),
    # 6: sessionid VARCHAR(16),
    # recordtype VARCHAR(32),
    # reserved00 VARCHAR(4),
    # reserved01 VARCHAR(4),
    # reserved02 VARCHAR(4),
    # reserved03 VARCHAR(4),
    # protocol VARCHAR(4),
    # 13: uplinkoctets VARCHAR(16),
    # 14: uplinkpackets VARCHAR(16),
    # 15: downlinkoctets VARCHAR(16),
    # 16: downlinkpackets VARCHAR(16),
    # 17: uplinkdropoctets VARCHAR(16),
    # 18: uplinkdroppackets VARCHAR(16),
    # 19: downlinkdropoctets VARCHAR(16),
    # 20: downlinkdroppackets VARCHAR(16),
    # dpiapplication VARCHAR(32),
    # dpirealprotocol VARCHAR(16),
    # protoinfoprotocol VARCHAR(4),
    # subprotocoltype VARCHAR(4),
    # subprotocolvalue VARCHAR(8),
    # operatingsystem VARCHAR(16),
    # operatingsystemversion VARCHAR(8),
    # im_si VARCHAR(16),
    # uplinkretranspackets VARCHAR(8),
    # 30: uplinkretransbytes VARCHAR(8),
    # downlinkretranspackets VARCHAR(8),
    # downlinkretransbytes VARCHAR(8),
    # initialrtt VARCHAR(8),
    # httpttfbtime VARCHAR(8),
    # dpiprotocolattributes VARCHAR(16),
    # dpitransferredcontent VARCHAR(16),
    # dpilayer7protocol VARCHAR(4),
    # applicationattributes VARCHAR(4),
    # ulinitrtttime VARCHAR(8),
    # 40: dlinitrtttime VARCHAR(8),
    # ulflowactivityduration VARCHAR(8),
    # dlflowactivityduration VARCHAR(16),
    # ulflowpeakthroughput VARCHAR(8),
    # dlflowpeakthroughput VARCHAR(8),
    # ulsessionactivityduration VARCHAR(8),
    # dlsessionactivityduration VARCHAR(8),
    # ulsessionpeakthroughput VARCHAR(8),
    # dlsessionpeakthroughput VARCHAR(8),
    # 50: bucketname VARCHAR(4),
    # bucketmin VARCHAR(8),
    # bucketmax VARCHAR(8),
    # buckettime VARCHAR(8),
    # bucketdirection VARCHAR(4),
    # tetheringentitled VARCHAR(8),
    # tetheredflow VARCHAR(8),
    # tetheringalgorithm VARCHAR(4),
    # protoinfosubprotocol VARCHAR(4),
    # closurereason VARCHAR(16),
    # 60: cplanesessionid VARCHAR(8),
    # qualityindex VARCHAR(4),
    # reserved1 VARCHAR(4),
    # reserved2 VARCHAR(4),
    # reserved3 VARCHAR(4),
    # reserved4 VARCHAR(4),
    # reserved5 VARCHAR(4),
    # reserved6 VARCHAR(4),
    # reserved7 VARCHAR(4),
    # reserved8 VARCHAR(4),
    # 70: reserved9 VARCHAR(4),
    # reserved10 VARCHAR(4),
    # data_dt VARCHAR(16)

    # lengths_min = [19,  22,  19,  19,   1,   1,   5,  15,   0,   0
    #             ,   0,   0,   1,   1,   1,   1,   1,   1,   1,   1
    #             ,   1,   0,   0,   0,   0,   4,   0,   0,   5,   1
    #             ,   1,   1,   1,   2,   2,   0,   0,   0,   0,   1
    #             ,   1,   1,   1,   1,   1,   4,   4,   4,   4,   0
    #             ,   4,   4,   4,   0,   4,   4,   2,   0,   0,   4
    #             ,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0
    #             ,   0,   8]

    lengths_avg = [19,  22,  22,  22,   4,   1,   7,  15,   0,   0
                ,   0,   0,   1,   2,   1,   3,   1,   1,   1,   1
                ,   1,   3,   3,   0,   0,   4,   0,   0,   7,   3
                ,   3,   3,   3,   3,   3,   1,   3,   0,   0,   1
                ,   1,   2,   2,   2,   3,   4,   4,   4,   4,   0
                ,   4,   4,   4,   0,   4,   4,   2,   0,  10,   4
                ,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0
                ,   0,   8]

    # lengths_max = [19,  23,  23,  23,   6,   1,   8,  15,   0,   0
    #             ,   0,   0,   2,   9,   7,  10,   7,   7,   4,   8
    #             ,   5,  36,  18,   0,   0,   4,   7,  92,   8,   4
    #             ,   6,   4,   7,   4,   5,  13,  19,   0,   0,   6
    #             ,   5,  11,  11,   7,   7,   4,   4,   4,   4,   0
    #             ,   4,   4,   4,   0,   4,   5,  18,   0,  15,   4
    #             ,   9,   0,   0,   0,   0,   0,   0,   0,   0,   0
    #             ,   0,   8]


    fields = []
    for l in lengths_avg:
        if l > 0:
            fields.append(randomstring(l))
        else:
            fields.append("")
        
    # now replace random strings for the columns that matter
    fields[1] = eventtime
    fields[6] = session

    # set uplink/downlink/dropped octets / packages
    for i in range(0,8):
        fields[13+i] = str(tonnage[i])

    filedict['handle'].write("%s\n" % delimiter.join(fields))
    filedict['records'] += 1

def write_session(filedict, eventtime, session, tonnage, celltower, delimiter):
    # SESSIONS columns

    # 0: load_ts TIMESTAMP,
    # 1: sessionid VARCHAR(8),
    # 2: eventtime VARCHAR(32),
    # recordtype VARCHAR(32),
    # gwtype VARCHAR(32),
    # im_si VARCHAR(16),
    # msisdn VARCHAR(16),
    # imeisv VARCHAR(32),
    # meid VARCHAR(4),
    # mnnai VARCHAR(4),
    # 10: reserved00 VARCHAR(4),
    # pdptype VARCHAR(32),
    # timezone VARCHAR(4),
    # dst VARCHAR(4),
    # pdnconnectionid VARCHAR(8),
    # accessoutintftype VARCHAR(32),
    # reserved01 VARCHAR(4),
    # accessoutteid VARCHAR(16),
    # accessinintftype VARCHAR(32),
    # reserved02 VARCHAR(4),
    # 20: accessinteid VARCHAR(8),
    # networkoutintftype VARCHAR(4),
    # networkoutipaddress VARCHAR(4),
    # networkoutteid VARCHAR(8),
    # networkinintftype VARCHAR(4),
    # networkinipaddress VARCHAR(4),
    # networkinteid VARCHAR(8),
    # starttime VARCHAR(32),
    # stoptime VARCHAR(8),
    # nodeaddress VARCHAR(16),
    # 30: nodeipaddrtype VARCHAR(32),
    # nodetype VARCHAR(32),
    # nodeplmnidmcc VARCHAR(8),
    # nodeplmnidmnc VARCHAR(8),
    # apnid VARCHAR(8),
    # rattype VARCHAR(32),
    # gwaddress VARCHAR(16),
    # gwipaddrtype VARCHAR(32),
    # gwnodeid VARCHAR(16),
    # gwplmnidmcc VARCHAR(8),
    # 40: gwplmnidmnc VARCHAR(8),
    # recordtriggercause VARCHAR(4),
    # 42: uplinkoctets VARCHAR(16),
    # 43: uplinkpackets VARCHAR(16),
    # 44: downlinkoctets VARCHAR(16),
    # 45: downlinkpackets VARCHAR(16),
    # 46: uplinkdropoctets VARCHAR(8),
    # 47: uplinkdroppackets VARCHAR(8),
    # 48: downlinkdropoctets VARCHAR(8),
    # 49: downlinkdroppackets VARCHAR(8),
    # triggercause VARCHAR(32),
    # closeinfoinit VARCHAR(4),
    # closeinfocausecode VARCHAR(8),
    # gtpcausecodeforattempts VARCHAR(4),
    # mbruplink VARCHAR(8),
    # mbrdownlink VARCHAR(16),
    # csgid VARCHAR(8),
    # csgaccessmode VARCHAR(8),
    # csgmembership VARCHAR(8),
    # cgimnc VARCHAR(8),
    # 60: cgici VARCHAR(8),
    # cgimcc VARCHAR(8),
    # cgilac VARCHAR(8),
    # laimnc VARCHAR(8),
    # laimcc VARCHAR(8),
    # lailac VARCHAR(8),
    # saimnc VARCHAR(8),
    # saisac VARCHAR(8),
    # saimcc VARCHAR(8),
    # sailac VARCHAR(8),
    # 70: raimnc VARCHAR(8),
    # rairac VARCHAR(8),
    # raimcc VARCHAR(8),
    # railac VARCHAR(8),
    # taimnc VARCHAR(8),
    # taitac VARCHAR(8),
    # taimcc VARCHAR(8),
    # ecgimnc VARCHAR(8),
    # 78: ecgieci VARCHAR(16),
    # ecgimcc VARCHAR(8),
    # 80: locextclosereason VARCHAR(8),
    # ulsessionactivityduration VARCHAR(16),
    # dlsessionactivityduration VARCHAR(16),
    # ulsessionpeakthroughput VARCHAR(16),
    # dlsessionpeakthroughput VARCHAR(16),
    # aggrtime VARCHAR(32),
    # bucketname VARCHAR(16),
    # bucketmin VARCHAR(4),
    # bucketmax VARCHAR(8),
    # buckettime VARCHAR(8),
    # 90: bucketdirection VARCHAR(8),
    # uplanesessionid VARCHAR(8),
    # realapn VARCHAR(8),
    # reserved1 VARCHAR(4),
    # reserved2 VARCHAR(4),
    # reserved3 VARCHAR(4),
    # reserved4 VARCHAR(4),
    # reserved5 VARCHAR(4),
    # reserved6 VARCHAR(4),
    # reserved7 VARCHAR(4),
    # 100: reserved8 VARCHAR(4),
    # data_dt VARCHAR(16)    

    # field min/avg/max field lengths taken from first hour of session data
    # min: [  19,   5,  22,  15,  15,   3,   3,  15,   0,   0
    #      ,   0,  13,   2,   1,   5,  23,   1,   5,  23,   1
    #      ,   5,   0,   0,   4,   0,   0,   4,  19,   4,  12
    #      ,  13,  22,   3,   1,   3,  14,  12,  15,  14,   3
    #      ,   3,   0,   1,   1,   1,   1,   4,   4,   4,   4
    #      ,   0,   0,   4,   0,   3,   3,   4,   4,   4,   1
    #      ,   4,   3,   4,   4,   4,   4,   1,   3,   3,   4
    #      ,   3,   1,   3,   4,   1,   4,   3,   1,   4,   3
    #      ,   1,   1,   1,   1,   1,  19,   0,   1,   4,   1
    #      ,   0,   4,   3,   1,   1,   1,   1,   1,   1,   1
    #      ,   1,   8

    lengths_avg = \
     [  19,   7,  22,  17,  15,   7,   7,  15,   0,   0
     ,   0,  14,   2,   1,   7,  23,   1,   7,  23,   1
     ,   7,   0,   0,   4,   0,   0,   4,  19,   4,  12
     ,  14,  23,   3,   2,   3,  14,  12,  15,  14,   3
     ,   3,   0,   7,   5,   8,   5,   4,   4,   4,   4
     ,  20,   0,   4,   0,   4,   4,   4,   4,   4,   3
     ,   4,   3,   4,   4,   4,   4,   3,   4,   3,   4
     ,   3,   3,   3,   4,   3,   4,   3,   3,   8,   3
     ,   3,   8,   8,   5,   6,  22,   8,   1,   4,   3
     ,   5,   4,   3,   1,   1,   1,   1,   1,   1,   1
     ,   1,   8 ]

    #max:  [  19,   8,  23,  18,  15,   8,   8,  15,   0,   0
    #      ,   0,  15,   3,   1,   8,  23,   1,  10,  23,   1
    #      ,   8,   0,   0,   4,   0,   0,   4,  19,  19,  15
    #      ,  15,  24,   3,   3,   3,  15,  12,  15,  14,   3
    #      ,   3,   0,  11,   9,  12,   9,   4,   4,   4,   4
    #      ,  30,  20,   4,   0,   6,   7,   4,   4,   4,   4
    #      ,   5,   4,   5,   4,   4,   4,   4,   5,   4,   5
    #      ,   4,   4,   4,   5,   4,   5,   4,   4,   9,   4
    #      ,   4,  12,  12,   7,   8,  23,   9,   4,   4,   7
    #      ,   6,   4,   3,   1,   1,   1,   1,   1,   1,   1
    # ,   1,   8 
    
    fields = []

    for l in lengths_avg:
        if l > 0:
            fields.append(randomstring(l))
        else:
            fields.append("")
        
    # now replace random strings for the columns that matter

    fields[0] = eventtime[:19]  # load_ts must be a timestamp
    fields[1] = session
    fields[2] = eventtime # this timestamp includes ms

    # set uplink/downlink/dropped octets / packages
    for i in range(0,8):
        fields[42+i] = str(tonnage[i])

    # populate ecgieci = celltower
    fields[78] = celltower

    filedict['handle'].write("%s\n" % delimiter.join(fields))
    filedict['records']     += 1

##########################################################################


parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
# default start = 1 Jan 2022 at 00:00 1640995200
default_start_epoch_secs = 1640995200

parser.add_argument("-s","--start_time",type=int, default=default_start_epoch_secs, help="start time epoch in seconds - default 01/01/2022 00:00:00")
# default end = 1 Aug 2020 at 01:00 1640998800
# end after five minutes
parser.add_argument("-p","--period_mins",type=int, default=60, help="length of run in minutes ")
parser.add_argument("-i","--interval_secs",type=int, default=1, help="time interval in secs between batches" )
parser.add_argument("-l","--log_interval_secs",type=int, default=900, help="time interval in secs between logging" )
parser.add_argument("-t","--trickle_secs",type=int, default=0, help="Seconds to sleep between batches - by default do not sleep")
parser.add_argument("-n","--number_sessions",type=int, default=30000, help="How many concurrent sessions")
parser.add_argument("-r","--session_rate",type=int, default=250,help="average session records per interval")
parser.add_argument("-m","--match_flow_pct", type=int, default=70, help="Percent of sessions that have flows" )
parser.add_argument("-f","--flow_ratio",type=float, default=4.5,help="ratio of flow record bursts to session records")
parser.add_argument("-S","--sessions_fileprefix", default="sessions_",help="prefix for output sessions file - may include existing path")
parser.add_argument("-F","--flows_fileprefix", default="flows_",help="prefix for output flows file - may include existing path")
parser.add_argument("--filesuffix", default=".csv",help="suffix for output files")
parser.add_argument("-R","--recs_per_file",type=int, default=1000000, help="Max records per file")
parser.add_argument("-d","--output_delimiter", default=out_delim_default,help="delimiter for output file")
parser.add_argument("--flows_lateness_secs", type=int, default=0, help="max lateness for flows data")
parser.add_argument("--sessions_lateness_secs", type=int, default=0, help="max lateness for sessions data")
# TODO read the cell tower ids from a file rather than making them up
parser.add_argument("-c","--cell_towers", type=int, default=400,help="number of distinct cell towers")

args = parser.parse_args()

# now process the data
run_end_time = args.start_time + 60*args.period_mins

logger.info("Generating data from %s to %s" % (datetime.utcfromtimestamp(args.start_time).strftime('%Y-%m-%d %H:%M:%S'),datetime.utcfromtimestamp(run_end_time).strftime('%Y-%m-%d %H:%M:%S') ) )
logger.info("Microbatches every %d seconds, with %d session records in each microbatch" % (args.interval_secs, args.session_rate))
if args.trickle_secs == 0:
    logger.info("Producing microbatches without breaks")
else:
    logger.info("Waiting %d seconds between microbatches" % args.trickle_secs)
logger.info("There will be %d concurrent sessions; %d percent of them will have flows" %(args.number_sessions, args.match_flow_pct))
logger.info("For every session record there will be %f flow bursts" % args.flow_ratio)
if args.sessions_lateness_secs > 0:
    logger.info("Session data may be %d seconds late or more, falling exponentially" % args.sessions_lateness_secs)
else:
    logger.info("Session data is perfectly ordered")
if args.flows_lateness_secs > 0:
    logger.info("Flow data may be %d seconds late or more, falling exponentially" % args.flows_lateness_secs)
else:
    logger.info("Flow data is perfectly ordered")
logger.info("Output will be written to session files starting %s and flow files starting %s with a suffix of %s" % (args.sessions_fileprefix, args.flows_fileprefix, args.filesuffix))
logger.info("Files are CSV with '%s' as the delimiter and will be rotated after every %d records" % (args.output_delimiter, args.recs_per_file))
logger.info("%d different cell towers are defined" % args.cell_towers)
logger.info("Currently no headers are generated")

rcount = 0

flows_file = {"name":None, "records":0, "handle":{} }
sessions_file = {"name":None, "records":0, "handle":{} }

proc_start_time = time.time()

sessions=[]
flowsessions=[]

last_filestem = "x"
fseq = 1

# inital stock of sessions

for i in range(0,args.number_sessions):  
    session='{:08d}'.format(i)
    sessions.append(session)
    in_flows = random.randint(0,100) < args.match_flow_pct
    if in_flows:
        flowsessions.append(session)


# Prepare a list of cell towers
# TODO read the list from a file (and/or generate the file)
celltowers = []
for i in range(0,args.cell_towers):
    celltowers.append(str(10000+i))

for rec_time_secs in range(args.start_time, run_end_time, args.interval_secs):

    if args.trickle_secs > 0 and rec_time_secs > args.start_time:
        logger.debug("sleeping for "+str(args.trickle_secs))
        time.sleep(args.trickle_secs)

    num_session_rows=args.session_rate

    scount = 0
    session_sample = random.sample(sessions, num_session_rows)
    for session in session_sample:

        # step milliseconds as we walk through the interval
        milliseconds = (float) (scount * args.interval_secs)/ num_session_rows       
        rec_plus_millis = rec_time_secs + milliseconds

        # filetime determines which file the record is added to
        filetime = datetime.utcfromtimestamp(rec_plus_millis).strftime('%Y-%m-%d-%H-%M-%S')

        # if we want disordered data, randomly choose how late this row is (compared to rec_plus_millis)
        # we use 6 as the cut off so minimising the number of late rows
        if args.sessions_lateness_secs > 0:
            adjustment_secs = random.expovariate(1) * args.sessions_lateness_secs / 6
            #adjustment_secs = random.randint(0,args.sessions_lateness_secs)
            #logger.debug("adjustment_secs=%f" % adjustment_secs)
        else:
            adjustment_millis = 0

        # trim off any microsecs to leave millisecs (truncate not round)
        eventtime = datetime.utcfromtimestamp(rec_plus_millis-adjustment_secs).strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
        celltower = random.choice(celltowers)

        if sessions_file['records'] >= args.recs_per_file:
            close_file(sessions_file)

        if sessions_file['handle'] == {}:
            # TODO optional headers on each file
            open_file(sessions_file, args.sessions_fileprefix, args.filesuffix, filetime, None)

        # octets are uplink, downlink, updropped, downdropped
        tonnage = random_tonnage(100000)

        write_session(sessions_file, eventtime, session, tonnage, celltower, args.output_delimiter)

        scount += 1
        rcount += 1
    
    num_flow_rows=int(float(num_session_rows) * args.flow_ratio)
    num_flow_bursts = int(num_flow_rows / avg_burst_count)

    flow_sample = random.sample(flowsessions, num_flow_bursts)

    fcount = 0
    for flow in flow_sample:

        # step milliseconds as we walk through the interval
        # NB milliseconds are in fractions of a second
        milliseconds = (float) (fcount * args.interval_secs)/ num_flow_bursts       
        rec_plus_millis = rec_time_secs + milliseconds

        # filetime determines which file the record is added to
        filetime = datetime.utcfromtimestamp(rec_plus_millis).strftime('%Y-%m-%d-%H-%M-%S')

        # if we want disordered data, randomly choose how late this row is (compared to rec_plus_millis)
        # we use 6 as the cut off so minimising the number of late rows
        if args.flows_lateness_secs > 0:
            adjustment_secs = random.expovariate(1) * args.flows_lateness_secs / 6
            #adjustment_secs = random.randint(0,args.flows_lateness_secs)
        else:
            adjustment_secs = 0

        

        # trim off any microsecs to leave millisecs (truncate not round)
        eventtime = datetime.utcfromtimestamp(rec_plus_millis-adjustment_secs).strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]

        if flows_file['records'] >= args.recs_per_file:
            close_file(flows_file)

        if flows_file['handle'] == {}:
            # TODO optional headers on each file
            open_file(flows_file, args.flows_fileprefix, args.filesuffix, filetime, None)

        burst_count = get_burst_count()

        for i in range(0,burst_count):
            tonnage = random_tonnage(25000)
            write_flow(flows_file, eventtime, flow, tonnage, args.output_delimiter)
            rcount += 1
        
        fcount += 1

    # report progress every x seconds
    if rec_time_secs % args.log_interval_secs == 0:
        logger.debug("Time: %s, sessions: %d, flows: %d" % (datetime.utcfromtimestamp(rec_time_secs).strftime('%Y-%m-%d %H:%M:%S'), sessions_file['records'], flows_file['records']))


if sessions_file['handle']:
    close_file(sessions_file)

if flows_file['handle']:
    close_file(flows_file)

logger.debug("Total row count (flows + sessions): %d" % (rcount))

proc_end_time = time.time()
execution_time = proc_end_time - proc_start_time

logger.info("Generation took %d seconds = %s" % (int(execution_time), timedelta(seconds=execution_time)))
