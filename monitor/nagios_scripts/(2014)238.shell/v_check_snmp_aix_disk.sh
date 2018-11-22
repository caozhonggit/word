#!/bin/bash

#usage: check_snmp_aix_disk.sh -H IP -C community -w warning -c critical [-d diskname]
#description:this shell can fetch os disk information by snmp protocol
#support check AIX5.3/AIX6.1

debug=0   # 1:on 0:off
PATH="/usr/bin:/usr/sbin:/bin:/sbin"
LIBEXEC="/usr/local/nagios/libexec"

OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

snmpversion=1
PROGNAME=`basename $0`
SNMPWALK="/usr/bin/snmpwalk"

#the OID of disk information
hrFSMountPoint=".1.3.6.1.2.1.25.3.8.1.2"
hrStorageType=".1.3.6.1.2.1.25.2.3.1.2"
#hrStorageDescr=".1.3.6.1.2.1.25.2.3.1.3"
hrStorageAllocationUnits=".1.3.6.1.2.1.25.2.3.1.4"
hrStorageSize=".1.3.6.1.2.1.25.2.3.1.5"
hrStorageUsed=".1.3.6.1.2.1.25.2.3.1.6"


#list all storage description which we don't monitor
filters=("hrStorageVirtualMemory" "hrStorageRam")


print_usage() {
    echo "Usage: "
    echo "  $PROGNAME -H IP -C community -w warning -c critical [-d disk]"
		echo "  "
    echo "  Check all disk usage on aix:"
		echo "    $PROGNAME -H IP -C community -w warning -c critical "
		echo " "
		echo "  Check someone disk usage on aix:"
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

	#hrStorageTypes are saved in a array
	disktype_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $hrStorageType | awk -F: '{print $NF}' ))
	r1=$?
	
	#storage allocation units are saved in a array
	unit_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $hrStorageAllocationUnits | awk '{print $4}' ))
	r2=$?
	
	#storage total sizes are saved in a array
	total_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $hrStorageSize | awk '{print $NF}' ))
	r3=$?
	
	#storage used sizes are saved in a array
	used_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $hrStorageUsed | awk '{print $NF}' ))
	r4=$?

	#mount point are saved in a array
	mpoint_array_tmp=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $hrFSMountPoint | awk '{print $NF}' |  sed -e 's/"//g' ))
	r5=$?

	if [[ $r1 -eq 0 && $r2 -eq 0 && $r3 -eq 0 && $r4 -eq 0 && $r5 -eq 0 ]] ; then
	
		x=0
		y=0
		#generate disk_array 
		for k in "${disktype_array[@]}"
		do	
				if [[ "$k" = "hrStorageVirtualMemory" ]] ; then
						disk_array[$x]="hrStorageVirtualMemory";
						((x=x+1))
				elif [[ "$k" = "hrStorageRam" ]] ; then		
						disk_array[$x]="hrStorageRam";						
						((x=x+1))
				else
						if [[ "${mpoint_array_tmp[$y]}" = "/proc" ]] ; then
							((y=y+1))
						elif [[ "${mpoint_array_tmp[$y]}" = "/dev/odm" ]] ; then		
							((y=y+1))
						elif [[ "${mpoint_array_tmp[$y]}" = "/tmp/ab1" ]] ; then	
							((y=y+1))
						elif [[ "${mpoint_array_tmp[$y]}" = "/tmp/ab2" ]] ; then	
							((y=y+1))										
						else	
							disk_array[$x]=${mpoint_array_tmp[$y]};	
							((y=y+1))	
							((x=x+1))
						fi
				fi
		done
	
		while (( $y < (${#mpoint_array_tmp[@]}) ))
		do
				if [[ "${mpoint_array_tmp[$y]}" = "/proc" ]] ; then
					((y=y+1))
				elif [[ "${mpoint_array_tmp[$y]}" = "/dev/odm" ]] ; then		
					((y=y+1))
				elif [[ "${mpoint_array_tmp[$y]}" = "/tmp/ab1" ]] ; then	
					((y=y+1))
				elif [[ "${mpoint_array_tmp[$y]}" = "/tmp/ab2" ]] ; then	
					((y=y+1))										
				else	
					disk_array[$x]=${mpoint_array_tmp[$y]};	
					((y=y+1))	
					((x=x+1))
				fi
		done
		
		
		#the final results after filter are saved in a array
		result=(); 
		#only check someone storage				
		if [[ -n $CHECKDISK ]] ; then
			i=0
			while (( $i < (${#disk_array[@]}) ))
			do
				if [[ "${disk_array[$i]}" = "$CHECKDISK" ]] ; then
					result[0]=$i
					break
				fi
				((i=i+1))
			done
		#check all storage
		else
			i=0
			idx=0
			#filter those we don't care,adopt to all hostname
			while (( $i < (${#disk_array[@]}) ))
			do
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
						result[$idx]=$i
						((idx=idx+1))
					fi
					((i=i+1))		
			done
		fi

		#for display info
		ok_num=0
		warn_num=0
		crit_num=0					

		conf_file="/usr/local/mon_conf/${HOSTNAME}_fsmon.conf"		
		general_file="/usr/local/mon_conf/general_fsmon.conf"

		DWARN=$WARN
		DCRIT=$CRIT

		for k in "${result[@]}"
		do
		  WARN=$DWARN
		  CRIT=$DCRIT

			
			#filter several disk or set individual alert threshold one by one ,adopt to all hostname
			if [[ -e ${general_file} ]]; then
					spec_gen=$(awk -F: -v mm="${disk_array[$k]}" '$1 == mm ' ${general_file})
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
					spec=$(awk -F: -v mm="${disk_array[$k]}" '$1 == mm ' ${conf_file})
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
			(( total_M=${total_array[$k]}*${unit_array[$k]}/1024/1024 ))
			(( used_M=${used_array[$k]}*${unit_array[$k]}/1024/1024 ))
			(( use_percent=${used_array[$k]}*100/(${total_array[$k]}) ))
			(( avail_M=(${total_array[$k]}-${used_array[$k]})*${unit_array[$k]}/1024/1024 ))
			(( warn_used_M=${total_array[$k]}*${unit_array[$k]}*${WARN}/1024/1024/100 ))
			(( crit_used_M=${total_array[$k]}*${unit_array[$k]}*${CRIT}/1024/1024/100 ))
					
			#generate information
			if [[ $use_percent -le $WARN ]];then
					(( ok_num=ok_num+1 ))
			elif [[ $use_percent -gt $WARN && $use_percent -le $CRIT ]];then
						(( warn_num=warn_num+1 ))
						OUTPUT_W="$OUTPUT_W Mounted:${disk_array[$k]} Total_MB:${total_M} Avail_MB:${avail_M} Usage:${use_percent} ;"
			else
						(( crit_num=crit_num+1 ))
						OUTPUT_C="$OUTPUT_C Mounted:${disk_array[$k]} Total_MB:${total_M} Avail_MB:${avail_M} Usage:${use_percent} ;"
			fi
					PERF="$PERF ${disk_array[$k]}_used=${used_M}MB;${warn_used_M};${crit_used_M};0;${total_M}"
					
			if (( $debug == 1)); then
				DEBUG="${DEBUG}${disk_array[$k]} size:${total_M}MB used:${used_M}MB available:${avail_M}MB  used%:${use_percent}%\n"
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
