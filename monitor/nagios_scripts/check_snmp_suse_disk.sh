#!/bin/bash

#usage: check_snmp_suse_disk.sh -H IP -C community -w warning -c critical [-d diskname]
#description:this shell can fetch os disk information by snmp protocol
#support check SUSE10.1/SUSE10.2/SUSE10.3/SUSE11.1/SUSE11.2

debug=0   # 1:on 0:off
PATH="/usr/bin:/usr/sbin:/bin:/sbin"
LIBEXEC="/usr/local/nagios/libexec"

OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

snmpversion=2c 
PROGNAME=`basename $0`
SNMPWALK="/usr/bin/snmpwalk"

#the OID of disk information
hrStorageDescr=".1.3.6.1.2.1.25.2.3.1.3"
hrStorageAllocationUnits=".1.3.6.1.2.1.25.2.3.1.4"
hrStorageSize=".1.3.6.1.2.1.25.2.3.1.5"
hrStorageUsed=".1.3.6.1.2.1.25.2.3.1.6"

#list all storage description which we don't monitor
filters=("Memory Buffers" "Real Memory" "Swap Space" "/sys" "/sys/kernel/debug" 
					"/sys/kernel/security" "Physical memory" "Virtual memory" "Memory buffers" 
					"Cached memory" "Shared memory" "Swap space" "/sys/fs/fuse/connections")

print_usage() {
    echo "Usage: "
    echo "  $PROGNAME -H IP -C community -w warning -c critical [-d disk]"
		echo "  "
    echo "  Check all disk usage on suse:"
		echo "    $PROGNAME -H IP -C community -w warning -c critical "
		echo " "
		echo "  Check someone disk usage on suse:"
		echo "    $PROGNAME -H IP -C community -w warning -c critical -d mount_point"
		echo "    $PROGNAME -H 10.1.90.38 -C cebpublic -w 80 -c 90 -d /home"
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
			exit $UNKNOWN
			;;
		-h)
			print_help
			exit $UNKNOWN
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
			exit $UNKNOWN
			;;
	esac
	shift
done

if [[ -n $HOSTNAME && -n $COMMUNITY && -n $WARN && -n $CRIT ]] ; then 

	#storage descriptions or mount pionts are saved in a array
	disk_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $hrStorageDescr | awk -F. '{print $2}' | awk '{print $1,$4 $5}' | sed -e 's/"//g' ))
	r1=$?
	
	#storage allocation units are saved in a array
	unit_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $hrStorageAllocationUnits | awk -F. '{print $2}' | awk '{print $1,$4}' ))
	r2=$?
	
	#storage total sizes are saved in a array
	total_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $hrStorageSize | awk -F. '{print $2}' | awk '{print $1,$4}' ))
	r3=$?
	
	#storage used sizes are saved in a array
	used_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $hrStorageUsed | awk -F. '{print $2}' | awk '{print $1,$4}' ))
	r4=$?

	if [[ $r1 -eq 0 && $r2 -eq 0 && $r3 -eq 0 && $r4 -eq 0 ]] ; then	
		#the final results after filter are saved in a array
		result=(); 
		#only check someone storage				
		if [[ -n $CHECKDISK ]] ; then
			i=0
			j=0
			while (( $j < (${#disk_array[@]}/2) ))
			do
				(( i=2*j+1 ))	
				if [[ "${disk_array[$i]}" = "$CHECKDISK" ]] ; then
					result[0]=$j
					break
				fi
				((j=j+1))
			done
		#check all storage
		else
			i=0
			j=0
			idx=0
			#filter those we don't care,adopt to all hostname
			while (( $j < (${#disk_array[@]}/2) ))
			do
					(( i=2*j+1 ))	
					in="isnotfilter"
					for filter in "${filters[@]}"
					do
						if [[ "${disk_array[$i]}" = $(echo "$filter" | sed -e 's/[ ]//g') ]] ; then
								in="isfilter"
								break
							fi
					done
		
					#disk is not filtered, total size is not equal 0
					if [[ "$in" = "isnotfilter" &&  ${total_array[$i]} -ne 0 ]] ; then
						result[$idx]=$j
						((idx=idx+1))
					fi
					((j=j+1))		
			done
		fi

		#for display info
		ok_num=0
		warn_num=0
		crit_num=0					
		x=0
		y=0		
		z=0
		kk=0
		zz=0
		
		conf_file="/usr/local/mon_conf/${HOSTNAME}_fsmon.conf"
		general_file="/usr/local/mon_conf/general_fsmon.conf"
				
		DWARN=$WARN
		DCRIT=$CRIT
		
		for k in "${result[@]}"
		do
		  WARN=$DWARN
		  CRIT=$DCRIT
			flag="inused_array"
		  ((z=2*k))
			while ((kk < (${#used_array[@]}/2)))
			do
				((zz=2*kk))
				if ((${disk_array[$z]} == ${used_array[$zz]}	)) ; then
					break
				elif ((${disk_array[$z]} > ${used_array[$zz]})) ; then
					((kk=kk+1))
				else
					flag="notinused_array"
					break
				fi
			done
	
			if [[ "$flag" ==  "notinused_array" ]] ; then
				continue
			fi
	
			((x=2*k+1))
			((y=2*kk+1))
			
		  
		  
			#filter several disk or set individual alert threshold one by one ,adopt to all hostname
			if [[ -e ${general_file} ]]; then
					spec_gen=$(awk -F: -v mm="${disk_array[$x]}" '$1 == mm ' ${general_file})
					if [ -n "$spec_gen" ] ; then
							warn=$(echo $spec_gen | awk  -F: '{print $2}')
							crit=$(echo $spec_gen | awk  -F: '{print $3}')
						
							if (($warn == "N" || $crit == "N")); then
									continue
							else
								WARN=$warn
								CRIT=$crit
							fi				
					fi
			fi		  
		  
		  	
			#filter several disk or set individual alert threshold one by one ,adopt to current hostname
			if [[ -e ${conf_file} ]]; then
					spec=$(awk -F: -v mm="${disk_array[$x]}" '$1 == mm ' ${conf_file})
					if [ -n "$spec" ] ; then
							warn=$(echo $spec | awk  -F: '{print $2}')
							crit=$(echo $spec | awk  -F: '{print $3}')
						
							if (($warn == "N" || $crit == "N")); then
									continue
							else
								WARN=$warn
								CRIT=$crit
							fi				
					fi
			fi
						
			
			#convert size to MB
			(( total_M=${total_array[$x]}*${unit_array[$x]}/1024/1024 ))
			(( used_M=${used_array[$y]}*${unit_array[$x]}/1024/1024 ))
			(( use_percent=${used_array[$y]}*100/(${total_array[$x]}) ))
			(( avail_M=(${total_array[$x]}-${used_array[$y]})*${unit_array[$x]}/1024/1024 ))
			(( warn_used_M=${total_array[$x]}*${unit_array[$x]}*${WARN}/1024/1024/100 ))
			(( crit_used_M=${total_array[$x]}*${unit_array[$x]}*${CRIT}/1024/1024/100 ))
			
			
			disk_info=${disk_array[$x]}
			
			#generate information
			if [[ $use_percent -le $WARN ]];then
					(( ok_num=ok_num+1 ))
			elif [[ $use_percent -gt $WARN && $use_percent -le $CRIT ]];then
						(( warn_num=warn_num+1 ))
						OUTPUT_W="$OUTPUT_W Mounted:${disk_info} Total_MB:${total_M} Avail_MB:${avail_M} Usage:${use_percent} ;"
			else
						(( crit_num=crit_num+1 ))
						OUTPUT_C="$OUTPUT_C Mounted:${disk_info} Total_MB:${total_M} Avail_MB:${avail_M} Usage:${use_percent} ;"
			fi
					PERF="$PERF ${disk_info}_used=${used_M}MB;${warn_used_M};${crit_used_M};0;${total_M}"
					
			if (( $debug == 1)); then
				DEBUG="${DEBUG}${disk_info} size:${total_M}MB used:${used_M}MB available:${avail_M}MB  used%:${use_percent}%\n"
			fi
										
		done	

		if (( $debug == 1)); then
				echo "debug infor:"
				echo -e "$DEBUG"
		fi

	
		if [[ ${warn_num} -eq 0 && ${crit_num} -eq 0 ]];then
			echo "OK - ALL File System is normal |$PERF"
		elif [[ ${warn_num} -gt 0 && ${crit_num} -eq 0 ]];then
			echo "Warn - $OUTPUT_W |$PERF"
		elif [[ ${warn_num} -eq 0 && ${crit_num} -gt 0 ]];then	
			echo "Crit - $OUTPUT_C |$PERF"
		# have warning and critical	
		else
			echo -e "Crit - $OUTPUT_C \t Warn - $OUTPUT_W |$PERF"
		fi					
						
		if [[ ${crit_num} -gt 0 ]];then
			exit $CRITICAL
		elif [[ ${warn_num} -gt 0 ]];then
			exit $WARNING
		elif [[ ${ok_num} -gt 0 ]];then
			exit $OK
		else
			exit $UNKNOWN
		fi

	else
		echo "UNKNOWN - Can't get the disk info through snmp"
		exit $UNKNOWN
	fi
	
else
	print_usage
	exit $UNKNOWN	
fi
