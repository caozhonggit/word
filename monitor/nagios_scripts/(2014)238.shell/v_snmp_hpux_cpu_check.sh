#!/bin/bash

#snmp_hpux_cpu_check.sh -H hostname/IP -c community -w warning -c critical
#This nagios plagin is finished by HongRui Wang at 2010-11-15
#Edit 2010-12-10 for running speed. 
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
computerSystemUserCPU=".1.3.6.1.4.1.11.2.3.1.1.13.0"   # User CPU ticks
computerSystemSysCPU=".1.3.6.1.4.1.11.2.3.1.1.14.0"   # System CPU ticks
computerSystemIdleCPU=".1.3.6.1.4.1.11.2.3.1.1.15.0"   # Idle CPU ticks
computerSystemNiceCPU=".1.3.6.1.4.1.11.2.3.1.1.16.0"   # Nice CPU ticks

print_usage() {
        echo "Usage: "
		echo "  $PROGNAME -H HOST -C community -w warning -c critical "
		echo "  $PROGNAME -H 10.1.8.90 -C cebpublic -w 80 -c 90"
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
	#第一次获取cpu相关的tickets值
	cpu_user1=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $computerSystemUserCPU |gawk '{print $4}' )
	if [[ $cpu_user1 != "Such" && -n $cpu_user1 ]];then 
		cpu_sys1=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $computerSystemSysCPU |gawk '{print $4}' )
		if [[ $cpu_sys1 != "Such" && -n $cpu_user1 ]];then
			cpu_idle1=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $computerSystemIdleCPU |gawk '{print $4}' )
			if [[ $cpu_idle1 != "Such" && -n $cpu_user1 ]];then
				cpu_nice1=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $computerSystemNiceCPU |gawk '{print $4}' )
				sleep 1
				if [[ $cpu_nice1 != "Such" && -n $cpu_nice1 ]];then
					#第二次获取cpu相关的tickets值
					cpu_user2=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $computerSystemUserCPU |gawk '{print $4}' )
					if [[ $cpu_user2 != "Such" && -n $cpu_user2 ]];then
						cpu_sys2=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $computerSystemSysCPU |gawk '{print $4}' )
						if [[ $cpu_sys2 != "Such" && -n $cpu_sys2 ]];then
							cpu_idle2=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $computerSystemIdleCPU |gawk '{print $4}' )	
							if [[ $cpu_idle2 != "Such" && -n $cpu_idle2 ]];then
								cpu_nice2=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $computerSystemNiceCPU |gawk '{print $4}' )
								if [[ $cpu_nice2 != "Such" && -n $cpu_nice2 ]];then	

									#求出两次获取时间间隔tickets总值
									(( total=${cpu_user2}+${cpu_sys2}+${cpu_idle2}+${cpu_nice2}-${cpu_user1}-${cpu_sys1}-${cpu_idle1}-${cpu_nice1} ))
									#求出两次获取时间间隔内的空闲tickets值
									(( idle=${cpu_idle2}-${cpu_idle1} ))
									#求出两次获取时间间隔内的使用tickets值
									(( used=${total}-${idle} ))
									#求出两次获取时间间隔内的cpu使用tickets值占总的tickets值的比率
									(( cpu_load=(${used}*100)/${total} ))
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
								fi
							fi
						fi
					fi
				fi
			fi
		fi
	fi


	echo "CPU usage: Can't get necessary data"
	exit $STATE_UNKNOWN

else
	print_help
	exit $STATE_UNKNOWN
fi


