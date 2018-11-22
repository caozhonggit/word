#!/bin/bash

#snmp_linux_disk_check.sh -H hostname/IP -C community -w warning -c critical [-d diskname]
#This nagios plagin is finished by HongRui Wang at 2011-08-30
#2012-04-17 此版本支持监控某个节点，也支持监控所有节点。当监控所有节点时，只显示超过阀值的信息。
#Test on SUSE10SP2-x86_64 For SUSE11 SP1 X86_64

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
        echo "  $PROGNAME -H HOST -C community -w warning -c critical [-d disk]"
		echo " "
        echo "Check the diskusage of all disks on Linux:"
		echo "  $PROGNAME -H HOST -C community -w warning -c critical "
		echo " "
		echo "Check the diskusage of only one disk:"
		echo "  $PROGNAME -H HOST -C community -w warning -c critical -d mount_point"
		echo "  $PROGNAME -H 10.1.90.38 -C cebpublic -w 80 -c 90 -d /home"
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
		-d)
			CHECKDISK="$2"
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

if [[ -n $HOSTNAME && -n $COMMUNITY && -n $WARN && -n $CRIT ]];then 
	#How many disk 
    disknum=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $hrStorageIndex | wc -l )
	r1=$?
	#Mount point of each disk
	disk_mnt_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $hrStorageDescr | gawk '{print $4 $5}' ))
	r2=$?
	#The size unit of each disk
	unit_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $hrStorageAllocationUnits | gawk '{print $4}' ))
	r3=$?
	#The total count of each disk	
	total_cnt_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $hrStorageSize | gawk '{print $4}' ))
	r4=$?
	#The used count of each disk
	used_cnt_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $hrStorageUsed | gawk '{print $4}' ))
	r5=$?
	if [[ $r1 -eq 0 && $r2 -eq 0 && $r3 -eq 0 && $r4 -eq 0 && $r5 -eq 0 ]];then					
		#echo "Filesystem Mounted VOLUME Available Use%" | awk '{printf "%30s%20s%10s%10s%10s%\n",$1,$2,$3,$4,$5}'						
		if [[ -n $CHECKDISK ]];then
			i=0
			for dm in "${disk_mnt_g[@]}";do
				if [[ $dm = $CHECKDISK ]];then
					break
				fi
				(( i=${i}+1 ))			
			done						
			(( total_M=${total_cnt_g[${i}]}*${unit_g[${i}]}/1024/1024 ))
			if [[ ${used_cnt_g[${i}]} -gt 0 ]];then
				(( used_M=(${used_cnt_g[${i}]}*${unit_g[${i}]})/1024/1024 ))
			else
				used_M=0
			fi							
			(( usage=(${used_cnt_g[${i}]})*100/${total_cnt_g[${i}]} ))
								
			#compare with warning and critical value
			(( warn_used_M=${total_cnt_g[${i}]}*${unit_g[${i}]}*${WARN}/1024/1024/100 ))
			(( crit_used_M=${total_cnt_g[${i}]}*${unit_g[${i}]}*${CRIT}/1024/1024/100 ))
			if [[ $usage -le $WARN ]];then
				printf "%s%s%%%s%s%s%s" "OK: Usage:" $usage "  Total(MB):" $total_M " Used(MB):" $used_M  
				printf "%s%s%s%s%s%s%s%s\n" "| used=" $used_M "MB;" $warn_used_M ";" $crit_used_M ";0;" $total_M	
				exit $STATE_OK
			elif [[ $usage -gt $WARN && $usage -le $CRIT ]];then
				printf "%s%s%%%s%s%s%s" "WARN: Usage:" $usage "  Total(MB):" $total_M " Used(MB):" $used_M
				printf "%s%s%s%s%s%s%s%s\n" "| used=" $used_M "MB;" $warn_used_M ";" $crit_used_M ";0;" $total_M	
				exit $STATE_WARNING
			else
				printf "%s%s%%%s%s%s%s" "CRIT: Usage:" $usage "  Total(MB):" $total_M " Used(MB):" $used_M
				printf "%s%s%s%s%s%s%s%s\n" "| used=" $used_M "MB;" $warn_used_M ";" $crit_used_M ";0;" $total_M
				exit $STATE_CRITICAL
			fi

		else
			ok_num=0
			warn_num=0
			crit_num=0
			#echo "$check_time    $HOSTNAME"
			#printf "%-30s%10s%10s%10s%%\n"  Mounted Total_MB Avail_MB Usage
			#only differents between snmp_linux_disk_check.sh
			j=5
			while [[ "$j" -lt "$disknum" ]]
			do	
				if [[ ${total_cnt_g[${j}]} -eq 0 ]];then
					(( j=${j}+1 ))
					continue
				else
					(( total_M_g[${j}]=(${total_cnt_g[${j}]}*${unit_g[${j}]})/1024/1024 ))
					(( used_M_g[${j}]=${used_cnt_g[${j}]}*${unit_g[${j}]}/1024/1024 ))
					(( avail_M_g[${j}]=(${total_cnt_g[${j}]}-${used_cnt_g[${j}]})*${unit_g[${j}]}/1024/1024 ))
					(( usage_g[${j}]=${used_cnt_g[${j}]}*100/${total_cnt_g[${j}]} ))
					(( warn_used_M_g[${j}]=${total_cnt_g[${j}]}*${unit_g[${j}]}*${WARN}/1024/1024/100 ))
					(( crit_used_M_g[${j}]=${total_cnt_g[${j}]}*${unit_g[${j}]}*${CRIT}/1024/1024/100 ))
				
					if [[ ${usage_g[${j}]} -le $WARN ]];then
						(( ok_num=${ok_num}+1 ))
					elif [[ ${usage_g[${j}]} -gt $WARN && ${usage_g[${j}]} -le $CRIT ]];then
						(( warn_num=${warn_num}+1 ))
						printf "%s%s%s%s%s%s%s%s%%%s" " [WARN Mounted: " ${disk_mnt_g[${j}]} "   Total_MB: " ${total_M_g[${j}]} "   Avail_MB: " ${avail_M_g[${j}]} "   Usage: " ${usage_g[${j}]} "]"
					else
						(( crit_num=${crit_num}+1 ))
						printf "%s%s%s%s%s%s%s%s%%%s" " [CRIT Mounted: " ${disk_mnt_g[${j}]} "   Total_MB: " ${total_M_g[${j}]} "   Avail_MB: " ${avail_M_g[${j}]} "   Usage: " ${usage_g[${j}]} "]"
					fi
					
					#printf "%-30s%10s%10s%10s%%\n" ${disk_mnt_g[${j}]} ${total_M_g[${j}]} ${avail_M_g[${j}]} ${usage_g[${j}]}
					(( j=${j}+1 ))
				fi
			done
			
			if [[ ${warn_num} -eq 0 && ${crit_num} -eq 0 ]];then
				echo "OK - ALL File System is normal"
			fi
			
			k=5
			printf "%s" "| "
			while [[ "$k" -lt "$disknum" ]]
			do
				if [[ ${total_cnt_g[${k}]} -eq 0 ]];then
					(( k=${k}+1 ))
					continue
				else
					printf "%s%s%s%s%s%s%s%s%s%s" ${disk_mnt_g[$k]} "_used=" ${used_M_g[$k]} "MB;" ${warn_used_M_g[${k}]} ";" ${crit_used_M_g[${k}]} ";0;" ${total_M_g[${k}]} " "
					(( k=${k}+1 ))
				fi
			done	
			echo ""
			
			if [[ ${crit_num} -gt 0 ]];then
				exit $STATE_CRITICAL
			elif [[ ${warn_num} -gt 0 ]];then
				exit $STATE_WARNING
			elif [[ ${ok_num} -gt 0 ]];then
				exit $STATE_OK
			else
				exit $STATE_UNKNOWN
			fi
			
		fi						
	else
		echo "CRITICAL - Can't get the disk info through snmp"
		exit $STATE_UNKNOWN
	fi
else
	print_usage
	exit $STATE_UNKNOWN	
fi

