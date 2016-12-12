#!/bin/bash

set -o nounset
set -o errexit
set -o errtrace
set -o pipefail

# Benchmarks:
BENCHDIR=$(dirname "$(readlink -f "$0")")
BENCHES=$(cd $BENCHDIR/benches; echo *)

# Default options:
FILESYSTEMS="bcache ext4 ext4-no-journal xfs btrfs"
DEVS=""
MNT=/mnt/run-benchmark
OUT=$(dirname "$(readlink -f "$0")")

usage()
{
    echo "run-benchmark.sh - run benchmarks"
    echo "  -d devices to test"
    echo "  -f filesystems to test"
    echo "  -b benchmarks to run"
    echo "  -m mountpoint to use (default /mnt/run-benchmark)"
    echo "  -o benchmark output directory (default /root/results/<date>_\$i/"
    echo "  -h display this help and exit"
    exit 0
}

while getopts "hd:f:b:m:o:" arg; do
    case $arg in
	d)
	    DEVS=$OPTARG
	    ;;
	f)
	    FILESYSTEMS=$OPTARG
	    ;;
	b)
	    BENCHES=$OPTARG
	    ;;
	m)
	    MNT=$OPTARG
	    ;;
	o)
	    OUT=$OPTARG
	    ;;
	h)
	    usage
	    exit 0
	    ;;
    esac
done
shift $(( OPTIND - 1 ))

if [[ -z $DEVS ]]; then
    echo "Required parameter -d missing: device(s) to test"
    exit 1
fi


DB="$OUT/benchmark-results"
LOGDIR="$OUT/benchmark-logs"
mkdir -p "$OUT" "$LOGDIR" "$MNT"

# Database schema:
# date		- date benchmark was run
# version	- kernel version or git sha1
# fs		- filesystem being tested
# device	- SSD/HDD model

sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS results(date, version, fs, device, benchmark_name, benchmark_cmd, output, logfile);"

function cleanup {
    umount $MNT > /dev/null 2>&1 || true
}
trap cleanup SIGINT SIGHUP SIGTERM EXIT

benchmark_date=$(date)
kernel_version=$(uname -r)

for dev in $DEVS; do
    model=$(hdparm -i $dev |tr ',' '\n'|sed -n 's/.*Model=\(.*\)/\1/p')

    for bench in $BENCHES; do
	benchmark_cmd=$(cat "$BENCHDIR/benches/$bench")

	for fs in $FILESYSTEMS; do
	    echo "Running $bench on $fs, $dev ($model)"

	    $BENCHDIR/prep-benchmark-fs.sh -d $dev -m $MNT -f $fs #>/dev/null 2>&1
	    sleep 30 # quiesce - SSDs are annoying

	    # run benchmark
	    results=$(cd $MNT; $benchmark_cmd)
	    umount $dev

	    sqlite3 "$DB" "INSERT INTO results values($benchmark_date, $kernel_version, $fs, $model, $bench, $benchmark_cmd, $results, \"\");"
	done
    done
done
