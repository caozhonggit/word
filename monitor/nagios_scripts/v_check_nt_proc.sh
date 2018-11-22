#!/bin/bash

#check_nt_proc.sh -H hostname/IP -w warning -c critcal -P processname 
#This nagios plagin is finished by xiaoxu at 2011-09-16
#This version is different with before version, don't witre tmp file.
#Test on SUSE10SP2-x86_64

PATH="/usr/bin:/usr/sbin:/bin:/sbin"
LIBEXEC="/usr/local/nagios/libexec"
CHECK_NT="/usr/local/nagios/libexec/check_nt"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

PROGNAME=`basename $0`


print_usage() {
        echo "Usage: "
        echo "  $PROGNAME -H HOST -w warning -c critical -P processname"
		echo " "
        echo "Check count of processname in windows":
		echo "  $PROGNAME -H HOST -w 1 -c 2 -P java"
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
		-w)
			WARN="$2"
			shift
			;;
		-c)
			CRIT="$2"
			shift
			;;
		-P)
			PROCNAME="$2"
			shift
			;;
		*)
			print_help
			exit $STATE_UNKNOWN
			;;
	esac
	shift
done

check_time=$( date +"%Y-%m-%d %H:%M" )

if [[ -z $HOSTNAME ]]; then
    print_usage
    exit $STATE_UNKNOWN
fi

#get process list
Process_list=$( ${CHECK_NT} -H ${HOSTNAME} -p 12489 -v INSTANCES -l process )
if [[ $? -eq $STATE_UNKNOWN ]];then
    printf "UNKNOWN - Can't get Process List\n"
    exit $STATE_UNKNOWN
elif [[ $? -eq $STATE_CRITICAL ]]; then
    printf "CRITICAL - Get process list error\n"
    exit $STATE_CRITICAL
fi

Process_count=0
if [[ -n $PROCNAME && -n $WARN && -n $CRIT ]];then 
    for var in `echo "${Process_list}"`
    do 
        if [[ ${var} = "${PROCNAME}" ]]; then
            (( Process_count = ${Process_count} + 1 ))
        elif [[ ${var} = "${PROCNAME}," ]]; then
            (( Process_count = ${Process_count} + 1 ))
        fi   
    done 
   # echo ${Process_count} 
   # echo $CRIT
   # echo $WARN
    if [[ ${Process_count} -ge $CRIT ]]; then
        printf "OK - $PROCNAME count is ${Process_count}\n"
        #echo "aaa"
        exit $STATE_OK
    else
        if [[ ${Process_count} -ge $WARN ]]; then
            printf "WARNING - $PROCNAME count is ${Process_count}\n"
            exit $STATE_WARNING
        else
            printf "CRITICAL - $PROCNAME count is ${Process_count}\n"
            exit $STATE_CRITICAL
        fi
    fi 
else
    print_usage
    exit $STATE_UNKNOWN	
fi


