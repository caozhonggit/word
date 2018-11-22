#!/bin/bash

#snmp_solaris8_check.sh -H hostname/IP -c community -w warning -c critical -t [user|process|uptime]
#This nagios plagin is finished by HongRui Wang at 2010-04-22
#2010-05-17 调整了snmp命令返回值判断的部分。如果snmp命令后跟上管道符处理部分，则返回结果总为0。
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

hrSystemUptime=".1.3.6.1.2.1.25.1.1.0"
hrSystemNumUsers=".1.3.6.1.2.1.25.1.5.0"
hrSystemProcesses=".1.3.6.1.2.1.25.1.6.0"
hrSystemMaxProcesses=".1.3.6.1.2.1.25.1.7.0"
hrProcessorLoad="1.3.6.1.2.1.25.3.3.1.2"

print_usage() {
        echo "Usage: "
		echo "  $PROGNAME -H HOST -C community -w warning -c critical -t [user|process|uptime]"
		echo "Example:"
		echo "  $PROGNAME -H 10.1.18.68 -C cebpublic -w 5 -c 10 -t user"
		echo "  $PROGNAME -H 10.1.18.68 -C cebpublic -w 300 -c 400 -t process" 
		echo "  $PROGNAME -H 10.1.18.68 -C cebpublic -t uptime"
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
		-t)
			type="$2"
			shift
			;;
		*)
			print_help
			exit $STATE_UNKNOWN
			;;
	esac
	shift
done

if [[ -n $type ]];then
	case "$type" in
		uptime)
			uptime=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrSystemUptime )
			r1=$?
			uptime=$( echo ${uptime} | awk '{print $5$6$7}' )
			if [[ "$r1" -eq 0 ]];then
				printf "%s%s%s%s%s%s%s\n" "System Uptime - " $uptime
				exit $STATE_OK
			else
				echo "System Uptime - Can't get uptime"
				exit $STATE_UNKNOWN
			fi
			;;
		user)
			if [[ -n $WARN && -n $CRIT ]];then
				usernum=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrSystemNumUsers )
				r1=$?
				usernum=$( echo ${usernum} | awk -F: '{print $NF}' )
				if [[ "$r1" -eq 0 ]];then
					if [[ $usernum -lt $WARN ]];then
						printf "%s%s%s" "USERS OK - " $usernum " users currently logged in"
						STATUS=$STATE_OK
					elif [[ $usernum -gt $WARN && $usernum -lt $CRIT ]];then
						printf "%s%s%s" "USERS WARN - " $usernum " users currently logged in"
						STATUS=$STATE_WARNING
					else
						printf "%s%s%s" "USERS CRIT - " $usernum " users currently logged in"
						STATUS=$STATE_CRITICAL
					fi
					printf "%s%s%s%s%s%s%s\n" "|users=" $usernum ";" $WARN ";" $CRIT ";0;50"
					exit $STATUS
				else
					echo "USERS - Can't get logged users"
					exit $STATE_UNKNOWN
				fi
			else
				print_help
				exit $STATE_UNKNOWN
			fi
			;;
		process)
			if [[ -n $WARN && -n $CRIT ]];then
				processnum=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrSystemProcesses )
				r1=$?
				processnum=$( echo ${processnum} | awk -F: '{print $NF}' )
				if [[ "$r1" -eq 0 ]];then
					if [[ $processnum -lt $WARN ]];then
						printf "%s%s%s" "PROCS OK : " $processnum " processes are running"
						STATUS=$STATE_OK
					elif [[ $processnum -gt $WARN && $processnum -lt $CRIT ]];then
						printf "%s%s%s" "PROCS WARN : " $processnum " processes are running"
						STATUS=$STATE_WARNING
					else
						printf "%s%s%s" "PROCS CRIT : " $processnum " processes are running"
						STATUS=$STATE_CRITICAL
					fi
					printf "%s%s%s%s%s%s%s\n" "|processes=" $processnum ";" $WARN ";" $CRIT ";0;800"
					exit $STATUS
				else
					echo "PROCESS - Can't get Process Num"
					exit $STATE_UNKNOWN
				fi	
			else
				print_help
				exit $STATE_UNKNOWN
			fi
			;;
		*)
			print_help
			exit $STATE_UNKNOWN
			;;
	esac
else
	print_help
	exit $STATE_UNKNOWN
fi

