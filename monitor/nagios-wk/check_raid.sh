#!/bin/bash

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

PROGNAME=`basename $0`
CHKCOM="/opt/MegaRAID/MegaCli/MegaCli64"
check_time=$( date +"%Y-%m-%d %H:%M" )

print_usage() {
        echo "Usage: "
        echo "  $PROGNAME connect"
        echo "  $PROGNAME status"
}

print_help() {
        echo ""
        print_usage
        echo ""
}

    case $1 in
        status)
                ROWN=`${CHKCOM} -pdlist -aALL|grep "Error Count\|Device Id"|sed 'N;N;s/\n/ /g'|wc -l`
            for ((i=1;i<=$ROWN;i++));do
                CHKSTAT=`${CHKCOM} -pdlist -aALL|grep "Error Count\|Device Id"|sed 'N;N;s/\n/ /g'|awk 'NR=="'$i'"{if ($7>0 || $11>0) {print "1";} else {print "0";}}'`
                if [ $CHKSTAT -ne 1 ];then
                    ${CHKCOM} -pdlist -aALL|grep "Error Count\|Device Id"|sed 'N;N;s/\n/ /g'|awk 'NR=="'$i'"{print $0;exit 1}'
                else
                    A=`${CHKCOM} -pdlist -aALL|grep "Error Count\|Device Id"|sed 'N;N;s/\n/ /g'|awk 'NR=="'$i'"{print $0;exit 0}'`
                    echo "$A $check_time"
                fi
            done
        ;;
        connect)
                ROWN=`${CHKCOM} -pdlist -aALL|grep "Error Count\|Device Id"|sed 'N;N;s/\n/ /g'|wc -l`
            for ((i=1;i<=$ROWN;i++));do
                CHKSTAT=`${CHKCOM} -pdlist -aALL|grep "Firmware stat\|Device Id"|sed '$!{N;s/\n/ /g;}'|awk -F ' |,'  'NR=="'$i'"{if ($6="Online") {print"0";} else {print "1";}}'`
                if [ $CHKSTAT -ne 1 ];then
                   ${CHKCOM} -pdlist -aALL|grep "Firmware stat\|Device Id"|sed '$!{N;s/\n/ /g;}'|awk -F ' |,'  'NR=="'$i'"{print $0;exit 1}'
                else
                   A=`${CHKCOM} -pdlist -aALL|grep "Firmware stat\|Device Id"|sed '$!{N;s/\n/ /g;}'|awk -F ' |,'  'NR=="'$i'"{print $0;exit 0}'`
                   echo "$A $check_time"
                fi
            done
        ;;
    esac
	
	
	
	
	
grep "Firmware stat\|Device Id\|Error Count"|sed 'N;N;N;s/\n\|\ /-/g'|awk -F'-' '{if ($7>0 || $11>0) {print "Error "$0;} else {print "Ok "$0;}}'




({172.20.200.153:log[/var/log/check_dell_raid.log].regexp(ERROR)})>0
