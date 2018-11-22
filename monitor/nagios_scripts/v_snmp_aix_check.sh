#!/bin/bash

#snmp_aix_check.sh -H hostname/IP -c community -w warning -c critical -t [mem|user|cpu|process|uptime]
#This nagios plagin is finished by HongRui Wang at 2010-03-15
#2010-04-22  Edit the cpu portion, delete the tmp file. Edit the uptime portion, change the -xxxx to xxxx.
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
hrStorageIndex=".1.3.6.1.2.1.25.2.3.1.1"
hrStorageType=".1.3.6.1.2.1.25.2.3.1.2"
hrStorageDescr=".1.3.6.1.2.1.25.2.3.1.3"
hrStorageAllocationUnits=".1.3.6.1.2.1.25.2.3.1.4"
hrStorageSize=".1.3.6.1.2.1.25.2.3.1.5"
hrStorageUsed=".1.3.6.1.2.1.25.2.3.1.6"
hrFSMountPoint=".1.3.6.1.2.1.25.3.8.1.2"
hrMemorySize=".1.3.6.1.2.1.25.2.2.0"

hrSystemUptime=".1.3.6.1.2.1.25.1.1.0"
hrSystemNumUsers=".1.3.6.1.2.1.25.1.5.0"
hrSystemProcesses=".1.3.6.1.2.1.25.1.6.0"
hrSystemMaxProcesses=".1.3.6.1.2.1.25.1.7.0"
hrProcessorLoad="1.3.6.1.2.1.25.3.3.1.2"

print_usage() {
        echo "Usage: "
		echo "  $PROGNAME -H HOST -C community -w warning -c critical -t [mem|user|cpu|process|uptime]"
		echo "  $PROGNAME -H 10.1.101.11 -c cebpublic -w 80 -c 90 -t cpu"
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
			uptime=$( echo ${uptime} | awk -F: '{print $NF}' | sed -e 's/-//' )
			if [[ "$r1" -eq 0 ]];then
				(( uptime=$uptime/100 ))
				if [[ $uptime -gt 86400 ]];then
					(( days=uptime/86400 ))
					(( lefthour=uptime%86400 ))
					if [[ lefthour -gt 3600 ]];then
						(( hours=lefthour/3600 ))
						(( leftmin=lefthour%3600 ))
						if [[ leftmin -gt 60 ]];then
							(( min=leftmin/60 ))
						else
							min=0
						fi
					else
						hours=0
					fi
				elif [[ $uptime -lt 86400 && $uptime -gt 3600 ]];then
					days=0
					(( hours=$uptime/3600 ))
					(( leftmin=$uptime%3600 ))
					if [[ leftmin -gt 60 ]];then
						(( min=leftmin/60 ))
					else
						min=0
					fi
				else
					days=0
					hours=0
					if [[ $uptime -gt 60 ]];then
						(( min=$uptime/60 ))
					else
						min=0
					fi
				fi
				printf "%s%s%s%s%s%s%s\n" "System Uptime - " $days "day(s)" $hours "hour(s)" $min "minute(s)"
				exit $STATE_OK
			else
				echo "System Uptime - Can't get uptime"
				exit $STATE_UNKNOWN
			fi
			;;
		mem)
			if [[ -n $WARN && -n $CRIT ]];then
				#加这么一条snmp命令，是为了确认当前snmpd是否能够得到值。因为snmp的返回字符串通过管道符处理后，即使snmp命令出错，返回结果也为0。
				mem_test=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrStorageType )
				r1=$?
				
				mem_index=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrStorageType |grep hrStorageRam |awk -F. '{print $2}'|awk -F= '{print $1}' )
				mem_unit=$($SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrStorageAllocationUnits |grep hrStorageAllocationUnits.${mem_index} |awk '{print $4}' )				
				mem_total_count=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrStorageSize |grep hrStorageSize.${mem_index} |awk -F: '{print $4}' )
				mem_used_count=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrStorageUsed |grep hrStorageUsed.${mem_index} |awk -F: '{print $4}' )
				if [[ "$r1" -eq 0 ]];then
					(( mem_usage=${mem_used_count}*100/${mem_total_count} ))
					(( mem_total=${mem_unit}*${mem_total_count}/1024/1024 ))
					(( mem_used=${mem_unit}*${mem_used_count}/1024/1024 ))
					(( mem_free=(${mem_total_count}-${mem_used_count})*${mem_unit}/1024/1024 ))
					(( mem_freeage=${mem_free}*100/${mem_total} ))
					if [[ $mem_usage -lt $WARN ]];then
						printf "%s%s%s%s%s%s%%%s%s%s%s%%%s\n" "Memory OK: total:" $mem_total " Mb - used:" $mem_used " Mb(" $mem_usage ") - free:" $mem_free " Mb(" $mem_freeage ")"
						STATUS=$STATE_OK
					elif [[ $mem_usage -gt $WARN && $mem_usage -lt $CRIT ]];then
						printf "%s%s%s%s%s%s%%%s%s%s%s%%%s\n" "Memory WARN: total:" $mem_total " Mb - used:" $mem_used " Mb(" $mem_usage ") - free:" $mem_free " Mb(" $mem_freeage ")"
						STATUS=$STATE_WARNING
					else
						printf "%s%s%s%s%s%s%%%s%s%s%s%%%s\n" "Memory CRIT: total:" $mem_total " Mb - used:" $mem_used " Mb(" $mem_usage ") - free:" $mem_free " Mb(" $mem_freeage ")"
						STATUS=$STATE_CRITICAL
					fi
					printf "%s%s%s%s%s\n" "|Used=" $mem_used "Mb Total=" $mem_total "Mb"
					exit $STATUS
				else
					echo "Memory usage: Can't get necessary number"
					exit $STATE_UNKNOWN
				fi
			else
				print_help
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
						printf "%s%s%s\n" "USERS OK - " $usernum " users currently logged in"
						STATUS=$STATE_OK
					elif [[ $usernum -gt $WARN && $usernum -lt $CRIT ]];then
						printf "%s%s%s\n" "USERS WARN - " $usernum " users currently logged in"
						STATUS=$STATE_WARNING
					else
						printf "%s%s%s\n" "USERS CRIT - " $usernum " users currently logged in"
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
				processnum=$( echo ${processnum}| awk -F: '{print $NF}' )
				if [[ "$r1" -eq 0 ]];then
					if [[ $processnum -lt $WARN ]];then
						printf "%s%s%s\n" "PROCS OK : " $processnum " processes"
						STATUS=$STATE_OK
					elif [[ $processnum -gt $WARN && $processnum -lt $CRIT ]];then
						printf "%s%s%s\n" "PROCS WARN : " $processnum " processes"
						STATUS=$STATE_WARNING
					else
						printf "%s%s%s\n" "PROCS CRIT : " $processnum " processes"
						STATUS=$STATE_CRITICAL
					fi
					printf "%s%s%s%s%s%s%s\n" "|processes=" $processnum ";" $WARN ";" $CRIT ";0;800"
					exit $STATUS
				else
					echo "Process - Can't get process num"
					exit $STATE_UNKNOWN
				fi
			else
				print_help
				exit $STATE_UNKNOWN
			fi
			;;
		cpu)
			if [[ -n $WARN && -n $CRIT ]];then
				#加这么一条snmp命令，是为了确认当前snmpd是否能够得到值。因为snmp的返回字符串通过管道符处理后，即使snmp命令出错，返回结果也为0。
				cpu_num=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrProcessorLoad )
				r1=$?
				cpu_num=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrProcessorLoad |wc -l )
				cpu_load_g=($( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrProcessorLoad |awk -F: '{print $NF}' ))
				if [[ "$r1" -eq 0 ]];then
					if [[ -n ${cpu_num} ]];then
						cpu_load=0
						i=0
						for cpu_l in "${cpu_load_g[@]}";do
							(( cpu_load=${cpu_load}+${cpu_l} ))
						done
						if [[ ${cpu_load} -gt 0 ]];then
							(( cpu_load=${cpu_load}/${cpu_num} ))
							if [[ $cpu_load -lt $WARN ]];then
								STATUS=$STATE_OK
							elif [[ $cpu_load -gt $WARN && $cpu_load -lt $CRIT ]];then
								STATUS=$STATE_WARNNING
							else
								STATUS=$STATE_CRITICAL
							fi
							printf "%s%s%%\n" "CPU average utilization percentage : " $cpu_load
							printf "%s%s%%%s%s%s%s%s\n" "|cpu=" $cpu_load ";" $WARN ";" $CRIT ";0;100"
							exit $STATUS
						else
							echo   "CPU average utilization percentage : 0%"
							printf "%s%s%s%s%s\n" "|cpu=0%;" $WARN ";" $CRIT ";0;100"
							exit $STATE_OK
						fi
					fi
				else
					echo "CPU usage: Can't get necessary data"
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

