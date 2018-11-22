#!/bin/bash

#snmp_sco_check.sh -H hostname/IP -c community -w warning -c critical -t [mem|user|cpu|process|uptime]
#This nagios plagin is finished by HongRui Wang at 2010-04-28
#This plugin is same as "snmp_aix_check.sh", only the uptime portion have difference. 
#Test on SUSE10SP2-x86_64 ------->  SCO UnixWare 7.1.3        				(OK)
#Test on SUSE10SP2-x86_64 ------->  SCO TCP/IP Runtime Release 2.0.0        (ERROR)
#2010-05-17 调整了对snmp命令返回结果的判断。如果snmp命令后增加了管道符处理部分。那么命令执行结果总会返回0。
#2012-01-31 调整内存部分，原本通过hrStorageSize来获取内存总大小，后发现可能获取负值，且不准确，现改为通过hrMemorySize来获取。
#2012-2-6 获取的内存使用大小有负值，进行取正

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

#hrSystemUptime=".1.3.6.1.2.1.25.1.1.0"
sysUpTimeInstance=".1.3.6.1.2.1.1.3.0"
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
			uptime=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $sysUpTimeInstance 2>/dev/null )
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
		mem)
			if [[ -n $WARN && -n $CRIT ]];then
				#加这么一条snmp命令，是为了确认当前snmpd是否能够得到值。因为snmp的返回字符串通过管道符处理后，即使snmp命令出错，返回结果也为0。
				mem_test=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrStorageType )
				r1=$?
				
				mem_index=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrStorageType |grep hrStorageRam |awk -F. '{print $2}'|awk -F= '{print $1}' )
				mem_unit=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrStorageAllocationUnits|grep hrStorageAllocationUnits.${mem_index} |awk '{print $4}' )
				#2012-01-31  直接获取的内存大小单位为Kbytes，所以后面除以1024即为MB
				mem_total_size=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrMemorySize|gawk -F: '{print $4}'|gawk '{print $1}' )
				mem_used_count=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrStorageUsed|grep hrStorageUsed.${mem_index} |awk -F: '{print $4}' )
				if [[ "$r1" -eq 0 ]];then
					(( mem_total=${mem_total_size}/1024 ))
					#2012-2-6 获取的内存使用大小有负值，进行取正
					if [[ $mem_used_count -lt 0 ]];then
						mem_used_count=$( echo $mem_used_count|sed -e 's/^-//' )
					fi
					(( mem_used=${mem_unit}*${mem_used_count}/1024/1024 ))
					(( mem_usage=${mem_used}*100/${mem_total} ))
					(( mem_free=${mem_total}-${mem_used} ))
					(( mem_freeage=100-${mem_usage} ))
					if [[ $mem_usage -le $WARN ]];then
						printf "%s%s%s%s%s%s%%%s%s%s%s%%%s\n" "Memory OK: total:" $mem_total " Mb - used:" $mem_used " Mb(" $mem_usage ") - free:" $mem_free " Mb(" $mem_freeage ")"
						STATUS=$STATE_OK
					elif [[ $mem_usage -gt $WARN && $mem_usage -le $CRIT ]];then
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
					if [[ $usernum -le $WARN ]];then
						printf "%s%s%s\n" "USERS OK - " $usernum "users currently logged in"
						STATUS=$STATE_OK
					elif [[ $usernum -gt $WARN && $usernum -le $CRIT ]];then
						printf "%s%s%s\n" "USERS WARN - " $usernum "users currently logged in"
						STATUS=$STATE_WARNING
					else
						printf "%s%s%s\n" "USERS CRIT - " $usernum "users currently logged in"
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
					if [[ $processnum -le $WARN ]];then
						printf "%s%s%s\n" "PROCS OK : " $processnum " processes"
						STATUS=$STATE_OK
					elif [[ $processnum -gt $WARN && $processnum -le $CRIT ]];then
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
				cpu_test=$( $SNMPWALK -v 1 -c $COMMUNITY $HOSTNAME $hrProcessorLoad )
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
							if [[ $cpu_load -le $WARN ]];then
								STATUS=$STATE_OK
							elif [[ $cpu_load -gt $WARN && $cpu_load -le $CRIT ]];then
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

