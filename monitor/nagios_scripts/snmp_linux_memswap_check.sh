#!/bin/bash

#snmp_linux_memswap_check.sh -H hostname/IP -c community 
#This nagios plagin is finished by HongRui Wang at 2010-04-06
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
hrStorageDescr=".1.3.6.1.2.1.25.2.3.1.3"
hrStorageAllocationUnits=".1.3.6.1.2.1.25.2.3.1.4"
hrStorageSize=".1.3.6.1.2.1.25.2.3.1.5"
hrStorageUsed=".1.3.6.1.2.1.25.2.3.1.6"


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
	#Mount point of each disk, find Memory and Swap index
	mount_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $hrStorageDescr | gawk '{print $4 $5}' ))
	n=0
	m=0
	for i in "${mount_g[@]}";do
		if [[ $i = RealMemory ]];then
			break
		fi
		(( n=${n}+1 ))			
	done
	for j in "${mount_g[@]}";do
		if [[ $j = SwapSpace ]];then
			break
		fi
		(( m=${m}+1 ))
	done
	#The size unit of each disk
	unit_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $hrStorageAllocationUnits | gawk '{print $4}' ))
	if [[ "$?" -eq 0 ]];then
	    #The total count of each disk	
		total_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $hrStorageSize | gawk '{print $4}' ))
		if [[ "$?" -eq 0 ]];then
			#The used count of each disk
			used_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $hrStorageUsed | gawk '{print $4}' ))
			if [[ "$?" -eq 0 ]];then
				mem_unit=${unit_g[${n}]}
				mem_total_count=${total_g[${n}]}
				mem_used_count=${used_g[${n}]}
				swap_unit=${unit_g[${m}]}
				swap_total_count=${total_g[${m}]}
				swap_used_count=${used_g[${m}]}
				(( mem_used=${mem_used_count}*${mem_unit}/1024/1024 ))
				(( mem_usage=${mem_used_count}*100/${mem_total_count} ))
				(( mem_total=${mem_total_count}*${mem_unit}/1024/1024 ))
				(( swap_used=${swap_used_count}*${swap_unit}/1024/1024 ))
				(( swap_usage=${swap_used_count}*100/${swap_total_count} ))
				(( swap_total=${swap_total_count}*${swap_unit}/1024/1024 ))
				
				(( total_usage=((${mem_used_count}*${mem_unit})+(${swap_used_count}*${swap_unit}))*100/((${mem_total_count}*${mem_unit})+(${swap_total_count}*${swap_unit})) ))
							
				#Print the memory information
				if [[ -n $WARN && -n $CRIT ]];then
					if [[ ${total_usage} -le $WARN ]];then
						printf "%s%s%%%s%s%s%s%s%s%s%s" "OK - Usage:" $total_usage "  Mem_Total(MB):" $mem_total " Mem_Used(MB):" $mem_used "  Swap_Total(MB):" $swap_total " Swap_Used(MB):" $swap_used   
						printf "%s%s%s%s%s%s%s%s\n" "|mem_used=" $mem_used "MB;0;0;0;" $mem_total " swap_used=" $swap_used "MB;0;0;0;" $swap_total
						exit $STATE_OK
					elif [[ ${total_usage} -gt $WARN && ${total_usage} -le $CRIT ]];then
						printf "%s%s%%%s%s%s%s%s%s%s%s" "WARN - Usage:" $total_usage "  Mem_Total(MB):" $mem_total " Mem_Used(MB):" $mem_used "  Swap_Total(MB):" $swap_total " Swap_Used(MB):" $swap_used   
						printf "%s%s%s%s%s%s%s%s\n" "|mem_used=" $mem_used "MB;0;0;0;" $mem_total " swap_used=" $swap_used "MB;0;0;0;" $swap_total	
						exit $STATE_WARNING
					else
						printf "%s%s%%%s%s%s%s%s%s%s%s" "CRIT - Usage:" $total_usage "  Mem_Total(MB):" $mem_total " Mem_Used(MB):" $mem_used "  Swap_Total(MB):" $swap_total " Swap_Used(MB):" $swap_used   
						printf "%s%s%s%s%s%s%s%s\n" "|mem_used=" $mem_used "MB;0;0;0;" $mem_total " swap_used=" $swap_used "MB;0;0;0;" $swap_total
						exit $STATE_CRITICAL
					fi
				else
					print_usage
					exit $STATE_UNKNOWN
				fi																	
			else
				echo "CRITICAL - Can't get used count of memory"
				exit $STATE_UNKNOWN
			fi
		else
			echo "CRITICAL - Can't get total count of memory"
			exit $STATE_UNKNOWN
		fi
	else	
		echo "CRITICAL - Can't get unit size of memory"
		exit $STATE_UNKNOWN
	fi
else
	print_usage
    exit $STATE_UNKNOWN
fi


