#!/bin/bash

#snmp_hpux_cpu_check.sh -H hostname/IP -c community -w warning -c critical
#This nagios plagin is finished by HongRui Wang at 2010-11-30
#这个脚本用于检查系统上运行的进程数，如果大于等于-n指定的值，则为正确。 
#Test on SUSE10SP2-x86_64

PATH="/usr/bin:/usr/sbin:/bin:/sbin"
LIBEXEC="/usr/local/nagios/libexec"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

PROGNAME=`basename $0`
SNMPWALK="/usr/bin/snmpwalk"
SystemProcessesIndex=".1.3.6.1.4.1.11.2.3.1.4.2.1.22"

print_usage() {
        echo "Usage: "
		echo "  $PROGNAME -H HOST -C community -p process -n number "
		echo "  $PROGNAME -H 10.1.8.90 -C cebpublic -p java -n 2"
}

print_help() {
        echo ""
        print_usage
        echo ""
}

while [ -n "$1" ]
do
	case "$1" in 
		--help)
			print_help
			exit $STATE_UNKNOWN
			;;
		-h)
			print_help
			exit $STATE_UNKNOWN
			;;
		-H)
			HOSTNAME="$2"
			shift
			;;
		-C)
			COMMUNITY="$2"
			shift
			;;
		-p)
			PROCESS="$2"
			shift
			;;
		-n)
			NUMBER="$2"
			shift
			;;
		*)
			print_help
			exit $STATE_UNKNOWN
			;;
	esac
	shift
done


if [[ -n $PROCESS && -n $NUMBER ]];then
	processes=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $SystemProcessesIndex |gawk -F "\"" '{print $2}'|gawk '{print $1}' ))
	aaa=${processes[*]}
	if [[ ${processes[0]} == Timeout* || ${processes[0]} == ""  ]];then
		echo "Can't get necessary data"
		exit $STATE_UNKNOWN

	else
		j=${#processes[@]}
		echo "--- total process ----"	
		echo $j
		i=0
		num=0
		while [ $i -lt $j ]
		do
			if [[ ${processes[$i]##*/} == ${PROCESS}  ]];then
				(( num=$num+1 ))
			fi
			(( i=$i+1 ))	
		done

		if [[ $num -ge $NUMBER ]];then
			STATES=$STATE_OK
			printf "%s%s%s%s\n" "OK: " $PROCESS " Process is Active - Total is " $num  
		else
			STATES=$STATE_CRITICAL
		        printf "%s%s%s%s%s%s\n" "CRITICAL: " $PROCESS " is ERROR - Total is " $num " Less Then " $NUMBER
		fi
		exit $STATES
	fi
else
	print_help
	exit $STATE_UNKNOWN
fi


