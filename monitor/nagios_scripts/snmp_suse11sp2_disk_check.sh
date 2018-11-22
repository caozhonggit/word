#!/bin/bash

#snmp_linux_disk_check.sh -H hostname/IP -C community -w warning -c critical [-d diskname]
#This nagios plagin is finished by HongRui Wang at 2011-12-3
#2012-12-3 过滤掉开始的6项跟挂载点无关的项,
#2012-12-3 并且不再按顺序采值，因为hrStorageUsed中的顺序会漏掉
#          HOST-RESOURCES-MIB::hrStorageDescr.8 = STRING: Shared memory
#Test on SUSE10SP2-x86_64 For SUSE11 SP1 X86_64

PATH="/usr/bin:/usr/sbin:/bin:/sbin"
LIBEXEC="/usr/local/nagios/libexec"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
OUTPUT=""
PERF=""

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
			i=6
			for dm in "${disk_mnt_g[@]}";do
				if [[ $dm = $CHECKDISK ]];then
					break
				fi
				(( i=${i}+1 ))			
			done
			(( k=i-1 ))
			(( total_M=${total_cnt_g[${i}]}*${unit_g[${i}]}/1024/1024 ))
			if [[ ${used_cnt_g[${k}]} -gt 0 ]];then
				(( used_M=(${used_cnt_g[${k}]}*${unit_g[${i}]})/1024/1024 ))
			else
				used_M=0
			fi							
			(( usage=(${used_cnt_g[${k}]})*100/${total_cnt_g[${i}]} ))
								
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
			#only differents between snmp_linux_disk_check.sh
			#过滤掉前6项，从第七项开始
			j=6
			while [[ "$j" -lt "$disknum" ]]
			do	
				if [[ ${total_cnt_g[${j}]} -eq 0 ]];then
					(( j=${j}+1 ))
					continue
				else
					(( k=j-1 ))
					(( total_M_g[${j}]=(${total_cnt_g[${j}]}*${unit_g[${j}]})/1024/1024 ))
					(( used_M_g[${j}]=${used_cnt_g[${k}]}*${unit_g[${j}]}/1024/1024 ))
					(( avail_M_g[${j}]=(${total_cnt_g[${j}]}-${used_cnt_g[${k}]})*${unit_g[${j}]}/1024/1024 ))
					(( usage_g[${j}]=${used_cnt_g[${k}]}*100/${total_cnt_g[${j}]} ))
					(( warn_used_M_g[${j}]=${total_cnt_g[${j}]}*${unit_g[${j}]}*${WARN}/1024/1024/100 ))
					(( crit_used_M_g[${j}]=${total_cnt_g[${j}]}*${unit_g[${j}]}*${CRIT}/1024/1024/100 ))
#				    echo "--------------${disk_mnt_g[${j}]}------------------"
#					echo "--------------------------${total_cnt_g[${j}]}"
#					echo "--------------------------${used_cnt_g[${k}]}"

					
					if [[ ${usage_g[${j}]} -le $WARN ]];then
						(( ok_num=${ok_num}+1 ))
					elif [[ ${usage_g[${j}]} -gt $WARN && ${usage_g[${j}]} -le $CRIT ]];then
						(( warn_num=${warn_num}+1 ))
						OUTPUT="$OUTPUT Mounted:${disk_mnt_g[${j}]} Total_MB:${total_M_g[${j}]} Avail_MB:${avail_M_g[${j}]} Usage:${usage_g[${j}]} ;"
					else
						(( crit_num=${crit_num}+1 ))
						OUTPUT="$OUTPUT Mounted:${disk_mnt_g[${j}]} Total_MB:${total_M_g[${j}]} Avail_MB:${avail_M_g[${j}]} Usage:${usage_g[${j}]} ;"
					fi
					PERF="$PERF ${disk_mnt_g[$j]}_used=${used_M_g[$j]}MB;${warn_used_M_g[${j}]};${crit_used_M_g[${j}]};0;${total_M_g[${j}]}"		
					(( j=${j}+1 ))
				fi
			done
			
			if [[ ${warn_num} -eq 0 && ${crit_num} -eq 0 ]];then
				echo "OK - ALL File System is normal |$PERF"
			elif [[ ${warn_num} -gt 0 && ${crit_num} -eq 0 ]];then
				echo "Warn - $OUTPUT |$PERF"
			else
				echo "Crit - $OUTPUT |$PERF"
			fi
			
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

