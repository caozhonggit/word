#!/bin/bash

#snmp_linux_mem_check_v1.sh -H hostname/IP -c community 
#This nagios plagin is finished by HongRui Wang at 2010-04-15
#This plagin just test memory on machine (don't include swap space)
# mem_used =  used - buffers - cached
# mem_free =  free + buffers + cached 
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

memIndex="1.3.6.1.4.1.2021.4.1.0"                           #"Bogus Index. This should always return the integer 0."
memErrorName="1.3.6.1.4.1.2021.4.2.0"						#"Bogus Name. This should always return the string 'swap'."
memTotalSwap="1.3.6.1.4.1.2021.4.3.0"						#"Total Swap Size configured for the host."
memAvailSwap="1.3.6.1.4.1.2021.4.4.0"						#"Available Swap Space on the host."
memTotalReal="1.3.6.1.4.1.2021.4.5.0"						#"Total Real/Physical Memory Size on the host."
memAvailReal="1.3.6.1.4.1.2021.4.6.0"						#"Available Real/Physical Memory Space on the host."	
memTotalFree="1.3.6.1.4.1.2021.4.11.0"						#"Total Available Memory on the host"
memMinimumSwap="1.3.6.1.4.1.2021.4.12.0"					#"Minimum amount of free swap required to be free
															#or else memErrorSwap is set to 1 and an error string is
															#returned memSwapErrorMsg."
memShared="1.3.6.1.4.1.2021.4.13.0"							#"Total Shared Memory"
memBuffer="1.3.6.1.4.1.2021.4.14.0"							#"Total Buffered Memory"
memCached="1.3.6.1.4.1.2021.4.15.0"							#"Total Cached Memory"
memSwapError="1.3.6.1.4.1.2021.4.100.0"						#"Error flag. 1 indicates very little swap space left"
memSwapErrorMsg="1.3.6.1.4.1.2021.4.101.0"					#"Error message describing the Error Flag condition"

print_usage() {
        echo "Usage: "
        echo "  $PROGNAME -H HOST -C community -w warning -c critical"
		echo " "
		echo "Example: "
		echo "  $PROGNAME -H 10.1.90.38 -c cebpublic -w 80 -c 90 "
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

if [[ -n $HOSTNAME && -n $COMMUNITY ]];then 	
		#增加这条snmp测试命令，是为了确认可以拿到OID值。因为snmp命令一旦添加管道符，结果就总为0。
		total_test=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $memTotalReal )
		r1=$?
	    #Get the snmp data of memory
		total=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $memTotalReal | gawk '{print $4}' ))
		avail=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $memAvailReal | gawk '{print $4}' ))
		buffer=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $memBuffer | gawk '{print $4}' ))
		cached=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $memCached | gawk '{print $4}' ))

		if [[ $r1 -eq 0 ]];then
				(( mem_free=${avail}+${buffer}+${cached} ))
				(( mem_free_M=${mem_free}/1024 ))
				(( mem_used=(${total}-${mem_free})/1024 ))
				(( mem_usage=(${total}-${mem_free})*100/${total} ))
				(( mem_total=${total}/1024 ))
							
				#Print the memory information
				if [[ -n $WARN && -n $CRIT ]];then
					(( warn_used=${total}*${WARN}/1024/100 ))
					(( crit_used=${total}*${CRIT}/1024/100 ))
					if [[ ${mem_usage} -le $WARN ]];then
						printf "%s%s%%%s%s%s%s" "OK - Usage:" $mem_usage "  Total(MB):" $mem_total "  Used(MB):" $mem_used   
						printf "%s%s%s%s%s%s%s%s" "| mem_used=" $mem_used "MB;" $warn_used ";" $crit_used ";0;" $mem_total
						printf "%s%s%s%s\n" " mem_free=" ${mem_free_M} "MB;0;0;0;" $mem_total
						exit $STATE_OK
					elif [[ ${mem_usage} -gt $WARN && ${mem_usage} -le $CRIT ]];then
						printf "%s%s%%%s%s%s%s" "WARN - Usage:" $mem_usage "  Total(MB):" $mem_total "  Used(MB):" $mem_used 
						printf "%s%s%s%s%s%s%s%s" "| used=" $mem_used "MB;" $warn_used ";" $crit_used ";0;" $mem_total	
						printf "%s%s%s%s\n" " mem_free=" ${mem_free_M} "MB;0;0;0;" $mem_total
						exit $STATE_WARNING
					else
						printf "%s%s%%%s%s%s%s" "CRIT - Usage:" $mem_usage "  Total(MB):" $mem_total "  Used(MB):" $mem_used
						printf "%s%s%s%s%s%s%s%s" "| used=" $mem_used "MB;" $warn_used ";" $crit_used ";0;" $mem_total
						printf "%s%s%s%s\n" " mem_free=" ${mem_free_M} "MB;0;0;0;" $mem_total
						exit $STATE_CRITICAL
					fi
				else
					print_usage
					exit $STATE_UNKNOWN
				fi																	
		else
			echo "CRITICAL - Can't get snmp data of memory"
			exit $STATE_UNKNOWN
		fi

else
	print_usage
    exit $STATE_UNKNOWN
fi


