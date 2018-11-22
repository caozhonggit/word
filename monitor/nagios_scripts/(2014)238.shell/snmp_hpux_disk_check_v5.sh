#!/bin/bash

#check_snmp_hpux_disk.sh -H hostname/IP -C community -w warning -c critical [-d diskname]
#This nagios plagin is finished by HongRui Wang at 2010-04-23
#2012-04-16 此版本可以监控单个挂载点，也可以监控所有挂载点。如果监控所有挂载点，只显示超过阀值的。
#2012-04-23 发现通过snmp获取值时，会出现：“Timeout: No Response from 10.1.41.24”的问题，其实没有获取到任何值，但是返回状态却正常。
#            出现这样的情况，在检查所有磁盘时，会跳过while循环，导致显示"OK - ALL File System is normal"，但检查状态未未知。
#            在判断部分增加了 -n $disknum ,来确保能获取信息。
#2012-04-25  发现通过snmp获取值时，会出现"SNMPv2-SMI::enterprises.11.2.3.1.2.1.0 = No Such Object available on this agent at this OID",过滤第四个字段
#            后为Such，disknum变量等于“Such”也是没有获取到任何值，需要排除这种情况。在判断部分添加 ${disknum} != "Such"
#Test on SUSE10SP2-x86_64

PATH="/usr/bin:/usr/sbin:/bin:/sbin"
LIBEXEC="/usr/local/nagios/libexec"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

o_perf=1
PROGNAME=`basename $0`
SNMPWALK="/usr/bin/snmpwalk"
computerSystemDiskNum=".1.3.6.1.4.1.11.2.3.1.2.1.0"
computerSystemDiskName=".1.3.6.1.4.1.11.2.3.1.2.2.1.3"
SystemDiskTotalBlocks=".1.3.6.1.4.1.11.2.3.1.2.2.1.4"
#SystemDiskFreeBlocks=".1.3.6.1.4.1.11.2.3.1.2.2.1.5"
SYstemDiskIdleBlocks=".1.3.6.1.4.1.11.2.3.1.2.2.1.6"
SYstemDiskBlockSize=".1.3.6.1.4.1.11.2.3.1.2.2.1.7"
computerSystemDiskDir=".1.3.6.1.4.1.11.2.3.1.2.2.1.10"



print_usage() {
        echo "Usage: "
        echo "  $PROGNAME -H HOST -C community [-w warning] [-c critical] [-d disk]"
		echo " "
        echo "Check the diskusage of all disks on HP-UX:"
		echo "  $PROGNAME -H HOST -C community -w warning -c critical"
		echo "  $PROGNAME -H 10.1.90.38 -C cebpublic -w 80 -c 90"
		echo " "
		echo "Check the diskusage of only one disk:"
		echo "  $PROGNAME -H HOST -C community -w warning -c critical -d mount_point"
		echo "  $PROGNAME -H 10.1.90.38 -c cebpublic -w 80 -c 90 -d /home"
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
			CHECKDISK='"'$CHECKDISK'"'
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
    disknum=$( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $computerSystemDiskNum | gawk '{print $4}' )
	r1=$?
	#Name of each disk
	#disk_name_g=($(	$SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $computerSystemDiskName | gawk '{print $4}' ))
	#r2=$?
	#Mount point of each disk
	disk_mnt_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $computerSystemDiskDir | gawk '{print $4}' ))
	r3=$?
	#The Total Blocks of each disk
	total_cnt_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $SystemDiskTotalBlocks | gawk '{print $4}' ))
	r4=$?
	#The Idle Blocks of each disk	
	avail_cnt_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $SYstemDiskIdleBlocks | gawk '{print $4}' ))
	r5=$?
	#The Block Size of each disk
	unit_g=($( $SNMPWALK -v 2c -c $COMMUNITY $HOSTNAME $SYstemDiskBlockSize| gawk '{print $4}' ))
	r6=$?
	if [[ ${r1} -eq 0 && ${r3} -eq 0 && ${r4} -eq 0 && ${r5} -eq 0 && ${r6} -eq 0 && -n ${disknum} && ${disknum} != "Such" ]];then
		#echo "Filesystem Mounted VOLUME Available Use%" | awk '{printf "%30s%20s%10s%10s%10s%\n",$1,$2,$3,$4,$5}'						
		if [[ -n $CHECKDISK ]];then
			n=0
			for dn in "${disk_mnt_g[@]}"
			do
				if [[ "$dn" == "$CHECKDISK" ]];then
					break 1
				fi
				(( n=$n+1 ))
			done
			(( total_M=${total_cnt_g[$n]}*${unit_g[$n]}/1024/1024 ))
			(( avail_M=${avail_cnt_g[$n]}*${unit_g[$n]}/1024/1024 ))
			(( used_M=(${total_cnt_g[$n]}-${avail_cnt_g[$n]})*${unit_g[$n]}/1024/1024 ))
			(( usage=(${total_cnt_g[$n]}-${avail_cnt_g[$n]})*100/${total_cnt_g[$n]} ))
			(( warn_used_M=${total_cnt_g[$n]}*${unit_g[$n]}*${WARN}/1024/1024/100 ))
			(( crit_used_M=${total_cnt_g[$n]}*${unit_g[$n]}*${CRIT}/1024/1024/100 ))
							
			#compare with warning and critical value
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
			j=0
			while [[ "$j" -lt "$disknum" ]]
			do	
				if [[ ${total_cnt_g[${j}]} -eq 0 ]];then
					(( j=${j}+1 ))
					continue
				else
					(( total_M_g[${j}]=(${total_cnt_g[${j}]}*${unit_g[${j}]})/1024/1024 ))
					(( avail_M_g[${j}]=${avail_cnt_g[${j}]}*${unit_g[${j}]}/1024/1024 ))
					(( used_M_g[${j}]=(${total_cnt_g[${j}]}-${avail_cnt_g[${j}]})*${unit_g[${j}]}/1024/1024 ))
					(( usage_g[${j}]=(${total_cnt_g[${j}]}-${avail_cnt_g[${j}]})*100/${total_cnt_g[${j}]} ))	
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
					#printf "%s %s %sMB %sMB %s%% \n" ${diskname[$n]} ${diskmount[$n]} $volume $availab $diskusage | awk '{printf "%30s%20s%10s%10s%10s%\n",$1,$2,$3,$4,$5}'
					#printf "%-30s%10s%10s%10s%%\n" ${disk_mnt_g[${j}]} ${total_M_g[${j}]} ${avail_M_g[${j}]} ${usage_g[${j}]}
					(( j=${j}+1 ))
		        fi
			done
			if [[ ${warn_num} -eq 0 && ${crit_num} -eq 0 ]];then
				echo "OK - ALL File System is normal"
			fi
			k=0
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
		echo "CRITICAL - Can't get the disk information through snmp."
		exit $STATE_UNKNOWN
	fi

else
	print_help
	exit $STATE_UNKNOWN
fi

#fi

