#!/bin/bash
#
# Yandex ClickHouse Zabbix template
#
# Copyright (C) Ivinco Ltd
# Copyright (C) Altinity Ltd



# Default host where ClickHouse is expected to be available
# You may want to change this for your installation
CH_HOST="${2:-localhost}"

##
## Write usage info
##
function usage()
{
  echo "Usage: $(basename "$0") Command [ClickHouse Host to Connect]"
}

# Command to execute
ITEM="$1"
if [ -z "$ITEM" ]; then
  echo "Provide command to run"
  usage
  exit 1
fi

# Ensure xmllint is available
xmllint="$(which xmllint)"
if [ "$?" -ne 0 ]; then
  echo "Looks like xmllint is not available. Please install it."
  exit 1
fi

# Extract ClickHouse data directory
# Usually it is /var/lib/clickhouse
CH_PATH="$(xmllint --xpath 'string(/yandex/path)' /etc/clickhouse-server/config.xml)"
if [ "$?" -ne 0 ]; then
  echo "Something went wrong with parsing ClickHouse config. Is xmllist installed? Is ClickHouse config available?"
  exit 1
fi 

##
## Run ClickHouse monitoring query
##
function run_ch_query()
{
  # Table where to look into
  TABLE=$1
  # Column where to look into
  COLUMN=$2
  # Metric name to fetch
  METRIC=$3
  # System DB to look into
  DATABASE="system"

  SQL="SELECT value FROM ${DATABASE}.${TABLE} WHERE $COLUMN = '$METRIC'"
  /usr/bin/clickhouse-client -h "$CH_HOST" -d "$DATABASE" -q "$SQL"
}

##
## Fetch metric by name from ClickHouse
##
function run_ch_metric_command()
{
  # $1 - metric name to fetch
  run_ch_query 'metrics' 'metric' $1
}

##
## Fetch asynchronous metric by name from ClickHouse
##
function run_ch_async_metric_command()
{
  # $1 - metric name to fetch
  run_ch_query 'asynchronous_metrics' 'metric' $1
}

##
## Fetch event by name from ClickHouse
##
function run_ch_event_command()
{
  # $1 - metric name to fetch
  run_ch_query 'events' 'event' $1
}

##
## Fetch processes info from ClickHouse
##
function run_ch_process_command()
{
  DATABASE="system"
  SQL="SELECT elapsed FROM processes"
  /usr/bin/clickhouse-client -h "$CH_HOST" -d "$DATABASE" -q "$SQL"
}

##
## Fetch event by name from ClickHouse
##
function run_ch_event_command_zeropad()
{
  # $1 - metric name to fetch
  res=`run_ch_query 'events' 'event' $1`
  [ -n "$res" ] || res=0
  echo "$res"
}

##
## Fetch numbers of zabbix advance time records
##
function run_ch_zabbix_advance_time()
{
    TABLE=$1
  DATABASE="zabbix"
    TIMESTAMP=$((`date +%s`+300))
  SQL="SELECT count(*) FROM ${TABLE} WHERE clock>${TIMESTAMP}"
  /usr/bin/clickhouse-client -h "$CH_HOST" -d "$DATABASE" -q "$SQL"
}

##
## Fetch numbers of zabbix no data records
##
function run_ch_zabbix_no_data()
{
    TABLE=$1
  DATABASE="zabbix"
    TIMESTAMP=$((`date +%s`-600))
  SQL="SELECT count(*) FROM ${TABLE} WHERE clock>${TIMESTAMP}"
  /usr/bin/clickhouse-client -h "$CH_HOST" -d "$DATABASE" -q "$SQL"
}

case "$ITEM" in
  DiskUsage)
    du -sb "$CH_PATH" | awk '{print $1}'
    ;;

  Revision)
    cat  "$CH_PATH/status" | grep Revision | awk '{print $2}'
    ;;

  LongestRunningQuery)
    run_ch_process_command | sort | tail -1
    ;;

  DelayedInserts    | \
  DistributedSend   | \
  HTTPConnection    | \
  MemoryTracking    | \
  Merge           | \
  OpenFileForRead   | \
  OpenFileForWrite  | \
  Query         | \
  QueryPreempted    | \
  QueryThread       | \
  Read          | \
  ReplicatedFetch   | \
  ReplicatedSend    | \
  ReplicatedChecks  | \
  BackgroundPoolTask  | \
  RWLockWaitingReaders| \
  RWLockWaitingWriters| \
  RWLockActiveReaders | \
  RWLockActiveWriters | \
  TCPConnection   | \
  Write         | \
  ZooKeeperSession  | \
  ZooKeeperRequest  | \
  ZooKeeperWatch    )
    run_ch_metric_command "$ITEM"
    ;;

  MaxPartCountForPartition| \
  MarkCacheBytes        | \
  ReplicasMaxAbsoluteDelay| \
  ReplicasSumQueueSize  | \
  Uptime      )
    run_ch_async_metric_command "$ITEM"
    ;;

  InsertedBytes       | \
  InsertedRows        | \
  InsertQuery           | \
  MergedRows            | \
  MergedUncompressedBytes | \
  ReadCompressedBytes   | \
  SelectQuery   )
    run_ch_event_command "$ITEM"
    ;;

  HistoryAdvanceTime  )
        run_ch_zabbix_advance_time "history"
    ;;
  HistoryStrAdvanceTime  )
        run_ch_zabbix_advance_time "history_str"
    ;;
  HistoryTextAdvanceTime  )
        run_ch_zabbix_advance_time "history_text"
    ;;
  HistoryUintAdvanceTime  )
    run_ch_zabbix_advance_time "history_uint"
    ;;

  HistoryNoData  )
      run_ch_zabbix_no_data "history"
    ;;
  HistoryStrNoData  )
        run_ch_zabbix_no_data "history_str"
    ;;
  HistoryTextNoData  )
        run_ch_zabbix_no_data "history_text"
    ;;
  HistoryUintNoData  )
    run_ch_zabbix_no_data "history_uint"
    ;;

  SelectedParts)
    run_ch_event_command_zeropad "$ITEM"
    ;;

  *)
    echo "Unknown argument '$ITEM'. Please check command to run"
    exit 1
    ;;
esac
