#!/bin/bash

#snmp_solaris8_mem_check.sh -H hostname/IP -c community 
#This nagios plagin is finished by HongRui Wang at 2010-04-21
#This plagin get Physical Memory and Swap information, and show them. 
#But only used Physical memory usage as threshold level.
#2010-05-17 调整了snmp命令返回结果的判断部分。如果snmp命令后跟上管道符处理部分，那么总会返回0。
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
#memShared="1.3.6.1.4.1.2021.4.13.0"							#"Total Shared Memory"
#memBuffer="1.3.6.1.4.1.2021.4.14.0"							#"Total Buffered Memory"
#memCached="1.3.6.1.4.1.2021.4.15.0"							#"Total Cached Memory"
memSwapError="1.3.6.1.4.1.2021.4.100.0"						#"Error flag. 1 indicates very little swap space left"
memSwapErrorMsg="1.3.6.1.4.1.2021.4.101.0"					#"Error message describing the Error Flag condition"

print_usage() {
        echo "Usage: "
        echo "  $PROGNAME -H HOST -C community -w warning -c critical"
		echo " "
		echo "Example: "
		echo "  $PROGNAME -H 10.1.18.68 -C cebpublic -w 80 -c 90 "
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
		#增加这条测试命令，是为了确认snmp是否可以拿到OID值。一旦snmp命令后增加了管道符部分，那么命令返回的状态总为0。
		phy_test=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $memTotalReal )
		r1=$?
	    #Get the snmp data of memory
		phy_total=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $memTotalReal | gawk '{print $4}' ))
		phy_avail=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $memAvailReal | gawk '{print $4}' ))
		swap_total=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $memTotalSwap | gawk '{print $4}' ))
		swap_avail=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $memAvailSwap | gawk '{print $4}' ))
		if [[ $r1 -eq 0 ]];then
				(( phy_total_M=${phy_total}/1024 ))
				(( phy_used_M=(${phy_total}-${phy_avail})/1024 ))
				(( phy_usage=(${phy_total}-${phy_avail})*100/${phy_total} ))
				(( swap_total_M=${swap_total}/1024 ))
				(( swap_used_M=(${swap_total}-${swap_avail})/1024 ))
				(( swap_usage=(${swap_total}-${swap_avail})*100/${swap_total} ))
							
				#Print the memory information
				if [[ -n $WARN && -n $CRIT ]];then
					(( phy_warn_used_M=${phy_total}*${WARN}/1024/100 ))
					(( phy_crit_used_M=${phy_total}*${CRIT}/1024/100 ))
					(( swap_warn_used_M=${swap_total}*${WARN}/1024/100 ))
					(( swap_crit_used_M=${swap_total}*${CRIT}/1024/100 ))
					
					if [[ ${phy_usage} -le $WARN ]];then
						printf "%s%s%%%s%s%s%s" "OK - Mem_Usage:" $phy_usage "  Mem_Total(MB):" $phy_total_M "  Mem_Used(MB):" $phy_used_M    
						printf "%s%s%%%s%s%s%s" " Swap_Usage:" $swap_usage " Swap_Total(MB):" $swap_total_M " Swap_Used(MB):" $swap_used_M
						printf "%s%s%s%s%s%s%s%s" "| mem_used=" $phy_used_M "MB;" $phy_warn_used_M ";" $phy_crit_used_M ";0;" $phy_total_M 
						printf "%s%s%s%s%s%s%s%s\n" " swap_used=" $swap_used_M "MB;" $swap_warn_used_M ";" $swap_crit_used_M ";0;" $swap_total_M
						exit $STATE_OK
					elif [[ ${phy_usage} -gt $WARN && ${phy_usage} -le $CRIT ]];then
						printf "%s%s%%%s%s%s%s" "WARN - Mem_Usage:" $phy_usage "  Mem_Total(MB):" $phy_total_M "  Mem_Used(MB):" $phy_used_M
						printf "%s%s%%%s%s%s%s" " Swap_Usage:" $swap_usage " Swap_Total(MB):" $swap_total_M " Swap_Used(MB):" $swap_used_M
						printf "%s%s%s%s%s%s%s%s" "| mem_used=" $phy_used_M "MB;" $phy_warn_used_M ";" $phy_crit_used_M ";0;" $phy_total_M
						printf "%s%s%s%s%s%s%s%s\n" " swap_used=" $swap_used_M "MB;" $swap_warn_used_M ";" $swap_crit_used_M ";0;" $swap_total_M
						exit $STATE_WARNING
					else
						printf "%s%s%%%s%s%s%s" "CRIT - Mem_Usage:" $phy_usage "  Mem_Total(MB):" $phy_total_M "  Mem_Used(MB):" $phy_used_M
						printf "%s%s%%%s%s%s%s" " Swap_Usage:" $swap_usage " Swap_Total(MB):" $swap_total_M " Swap_Used(MB):" $swap_used_M
						printf "%s%s%s%s%s%s%s%s" "| mem_used=" $phy_used_M "MB;" $phy_warn_used_M ";" $phy_crit_used_M ";0;" $phy_total_M
						printf "%s%s%s%s%s%s%s%s\n" " swap_used=" $swap_used_M "MB;" $swap_warn_used_M ";" $swap_crit_used_M ";0;" $swap_total_M
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


