#! /bin/sh

#debug flag   1:on   0:off
debug=0

#warning level
ok=0
unknow=-1
warning=1
critical=2

#declare constants fields
event_system_name=CEB-HA
event_name=HAStatus
component_type=OS
component=HA
event_level=5

#declare variable from option param
ip_address=
host_name=
check_service_flag=0 
check_process_flag=0
check_name=

#declare variable from /usr/local/nagios/etc/WindowInfo.txt
business_system_name=
managed_organization=
belonged_organization=
sub_component=
event_description=
instance_id=

#declare variable from shell
instance_value=
occur_time=

#declare check type
check_state_type=
reulst_type=

#temp variable
tmp=


#define function
function print_usage()
{
	echo "Usage:"
	echo "	`basename $0` -H ip  -N  hostname -c varialbe -v varialbe"
	echo ""
	echo "option:"
	echo "	-H"
	echo "		ip address  of the host to check"
	echo "	-N"
	echo "		host name of the host to check"
	echo "	-c"
	echo "		type of the host to check, \"service\" or \"process\""
	echo "	-v"
	echo "		process or service name of the host to check"
	echo ""
	echo "example:"
	echo "	check_primary_secondary.sh -H 192.168.1.1 -N N4003 -c service -v WinSSHD"
	echo "	check_primary_secondary.sh -H 192.168.1.1 -N N4003 -c process -v nginx.exe"
	echo ""
}

#step1: get parm from 
while getopts :H:N:c:v: OPTION
do
	case $OPTION in
	H) ip_address="$OPTARG"
	   ;;
	N) host_name="$OPTARG"
	   ;;
	c) tmp="$OPTARG"
		if [ "$tmp" = "service" ] ; then
			check_service_flag=1
		fi
		
		if [ "$tmp" = "process" ] ; then
			check_process_flag=1
		fi
	   ;;

	v) check_name="$OPTARG"
	   ;;
	\?) print_usage
	    exit $warning
	   ;;
	esac
done


#debug output information
if [ $debug -eq 1 ] ; then
	echo "==>input parameter:"
	echo "        $ip_address,$host_name,$check_service_flag,$check_process_flag,$check_name"
fi

#step2: get variable value from  WindowInfo.txt
tmp=`grep "$ip_address"  /usr/local/nagios/etc/WindowInfo.txt | sed -e 's/\s//g' | awk 'BEGIN{FS="#";OFS="#";mm="'$ip_address'"} {if($1==mm) print} '`
if [ -z "$tmp" ] ;  then
	echo "WARNING: checking primary or secondary failed. casue: ip[$ip_address] is not in /usr/local/nagios/etc/WindowInfo.txt"
	exit $warning
fi
business_system_name=`echo $tmp | awk  -F# '{print $2}' | sed -e 's/\s//'`
managed_organization=`echo $tmp | awk  -F# '{print $3}' | sed -e 's/\s//'`
belonged_organization=`echo $tmp | awk -F# '{print $4}' | sed -e 's/\s//'`
sub_component=`echo $tmp | awk -F# '{print $5}' | sed -e 's/\s//'`
event_description=`echo $tmp | awk -F# '{print $6}' |  sed -e 's/\s//'`
instance_id=`echo $tmp | awk -F# '{print $7}' | sed -e 's/\s//'`


#debug output information
if [ $debug -eq 1 ] ; then
	echo "==>parameter in file:"
	echo "          $business_system_name,$managed_organization,$belonged_organization,$sub_component,$event_description,$instance_id"
fi

#step3:get instance value by check_nt
if [ $check_service_flag -eq 1 ] ; then
	check_state_type=SERVICESTATE
	reulst_type=service
fi
 
if [ $check_process_flag -eq 1 ] ; then
	check_state_type=PROCSTATE
	reulst_type=process
fi

tmp="`/usr/local/nagios/libexec/check_nt -H $ip_address -p 12489 -v $check_state_type -l $check_name -d SHOWALL`"


if echo "$tmp" | grep -i "$check_name: Started" >/dev/null 2>&1 ; then
	instance_value="Primary"
elif echo "$tmp" | grep -i "$check_name: Running" >/dev/null 2>&1 ; then
	instance_value="Primary"
elif echo "$tmp" | grep -i "$check_name: Not found" >/dev/null 2>&1 ; then
  instance_value="Secondary"
elif echo "$tmp" | grep -i "$check_name: Stopped" >/dev/null 2>&1 ; then
	instance_value="Secondary"
elif echo "$tmp" | grep -i "$check_name: not running" >/dev/null 2>&1 ; then
	instance_value="Secondary"
else
	echo "WARNING: checking primary or secondary failed. cause: ip[$ip_address] $tmp"	
	exit $warning
fi

if [ $debug -eq 1 ] ; then
	echo "==>check_name=[$check_name]"
	echo "   ip=[${ip_address}],instances=[${tmp}]"
fi


#get seconds from 1970-1-1
occur_time=`date +%s`


#step4:organze information 
if [ $debug -eq 1 ] ; then
	echo "==>stancce_value=${instance_value}"
	echo "==>output syslog information:"
fi

#step5:tansfer infromation by nagios server's syslog-ng
goal="${event_system_name}|+|${business_system_name}|+|${managed_organization}|+|${belonged_organization}|+|${ip_address}|+|${host_name}|+|${event_name}|+|${instance_id}|+|${instance_value}|+|${component_type}|+|${component}|+|${sub_component}|+|${event_level}|+|${event_description}|+|${occur_time}"

if [ $debug -eq 1 ] ; then
        echo "$goal"      
fi                        

#output to nagios monitor service

echo "check $reulst_type[${check_name}],host[${ip_address}] is ${instance_value}"

logger -t 2OMNIBUS  -p local7.debug $goal

exit $ok
