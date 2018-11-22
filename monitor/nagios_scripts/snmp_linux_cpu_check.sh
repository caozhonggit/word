#!/bin/bash

#snmp_linux_cpu_check.sh -H hostname/IP -c community -w warning -c critical
#This nagios plagin is finished by HongRui Wang at 2010-04-23 
#This  plagin is same with snmp_solaris8_cpu_check.sh
#Edit jugement of snmp command result. If snmp command result is 1, add "|" portion, the result will be change to 0. 
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
ssCpuUser=".1.3.6.1.4.1.2021.11.9"
ssCpuSystem=".1.3.6.1.4.1.2021.11.10"
ssCpuIdle=".1.3.6.1.4.1.2021.11.11"

print_usage() {
        echo "Usage: "
		echo "  $PROGNAME -H HOST -C community -w warning -c critical "
		echo "  $PROGNAME -H 10.1.101.226 -C cebpublic -w 80 -c 90"
		echo "  Note: This plugin is check Cpu Usage.Threshold value above,like 80 and 90,unit '%' is omit."
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
		-w)
			WARN="$2"
			shift
			;;
		-c)
			CRIT="$2"
			shift
			;;
		*)
			print_help
			exit $STATE_UNKNOWN
			;;
	esac
	shift
done


if [[ -n $WARN && -n $CRIT ]];then
	#增加这条测试命令为了确认snmp可以拿到值
	cpu_test=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $ssCpuIdle )
	r1=$?
	cpu_idle=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $ssCpuIdle |gawk '{print $4}' )	
	if [[ "$r1" -eq 0 ]];then
		(( cpu_load=100-${cpu_idle} ))
		if [[ $cpu_load -le $WARN ]];then
			STATES=$STATE_OK
		elif [[ $cpu_load -gt $WARN && $cpu_load -le $CRIT ]];then
			STATES=$STATE_WARNNING
		else
			STATES=$STATE_CRITICAL
		fi
		printf "%s%s%%" "CPU average utilization percentage : " $cpu_load
		printf "%s%s%%%s%s%s%s%s\n" "|cpu=" $cpu_load ";" $WARN ";" $CRIT ";0;100"
		exit $STATES
	else
		echo "CPU usage: Can't get necessary data"
		exit $STATE_UNKNOWN
	fi
else
	print_help
	exit $STATE_UNKNOWN
fi


