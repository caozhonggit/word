#!/bin/bash

#usage: check_snmp_hpux_disk.sh -H IP -C community -w warning -c critical [-d diskname]
#description:this shell can fetch os disk information by snmp protocol
#support check  HP-UX B.11.11/HP-UX B.11.23/HP-UX B.11.31

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
SystemDiskTotalBlocks=".1.3.6.1.4.1.11.2.3.1.2.2.1.4"
SYstemDiskIdleBlocks=".1.3.6.1.4.1.11.2.3.1.2.2.1.6"
SYstemDiskBlockSize=".1.3.6.1.4.1.11.2.3.1.2.2.1.7"
computerSystemDiskDir=".1.3.6.1.4.1.11.2.3.1.2.2.1.10"



#list all storage description which we don't monitor
filters=()

print_usage() {
    echo "Usage: "
    echo "  $PROGNAME -H IP -C community -w warning -c critical [-d disk]"
		echo "  "
    echo "  Check all disk usage on hpux:"
		echo "    $PROGNAME -H IP -C community -w warning -c critical "
		echo " "
		echo "  Check someone disk usage on hpux:"
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

	#storage allocation units are saved in a array
	unit_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $SYstemDiskBlockSize | awk '{print $4}' ))
	r1=$?
	
	#storage total sizes are saved in a array
	total_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $SystemDiskTotalBlocks | awk '{print $4}' ))
	r2=$?
	
	#storage free sizes are saved in a array
	free_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $SYstemDiskIdleBlocks | awk '{print $4}' ))
	r3=$?

	#mount point are saved in a array
	mpoint_array=($( $SNMPWALK -v $snmpversion -c $COMMUNITY $HOSTNAME $computerSystemDiskDir | awk '{print $4}' |  sed -e 's/"//g' ))
	r4=$?

	if [[ $r1 -eq 0 && $r2 -eq 0 && $r3 -eq 0 && $r4 -eq 0 ]] ; then
	
		
		#the final results after filter are saved in a array
		result=(); 
		#only check someone storage				
		if [[ -n $CHECKDISK ]] ; then
			i=0
			while (( $i < ${#mpoint_array[@]} ))
			do
				if [[ "${mpoint_array[$i]}" = "$CHECKDISK" ]] ; then
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
			while (( $i < ${#mpoint_array[@]} ))
			do
					in="isnotfilter"
					for filter in "${filters[@]}"
					do
						if [[ "${mpoint_array[$i]}" = $(echo "$filter" | sed -e 's/[ ]//g') ]] ; then
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
					spec_gen=$(awk -F: -v mm="${mpoint_array[$k]}" '$1 == mm ' ${general_file})
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
					spec=$(awk -F: -v mm="${mpoint_array[$k]}" '$1 == mm ' ${conf_file})
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
			(( used_M=(${total_array[$k]}-${free_array[$k]})*${unit_array[$k]}/1024/1024 ))
			(( use_percent=(${total_array[$k]}-${free_array[$k]})*100/(${total_array[$k]}) ))
			(( avail_M=${free_array[$k]}*${unit_array[$k]}/1024/1024 ))
			(( warn_used_M=${total_array[$k]}*${unit_array[$k]}*${WARN}/1024/1024/100 ))
			(( crit_used_M=${total_array[$k]}*${unit_array[$k]}*${CRIT}/1024/1024/100 ))
					
			#generate information
			if [[ $use_percent -le $WARN ]];then
					(( ok_num=ok_num+1 ))
			elif [[ $use_percent -gt $WARN && $use_percent -le $CRIT ]];then
						(( warn_num=warn_num+1 ))
						OUTPUT_W="$OUTPUT_W Mounted:${mpoint_array[$k]} Total_MB:${total_M} Avail_MB:${avail_M} Usage:${use_percent} ;"
			else
						(( crit_num=crit_num+1 ))
						OUTPUT_C="$OUTPUT_C Mounted:${mpoint_array[$k]} Total_MB:${total_M} Avail_MB:${avail_M} Usage:${use_percent} ;"
			fi
					PERF="$PERF ${mpoint_array[$k]}_used=${used_M}MB;${warn_used_M};${crit_used_M};0;${total_M}"
					
			if (( $debug == 1)); then
				DEBUG="${DEBUG}${mpoint_array[$k]} size:${total_M}MB used:${used_M}MB available:${avail_M}MB  used%:${use_percent}%\n"
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
