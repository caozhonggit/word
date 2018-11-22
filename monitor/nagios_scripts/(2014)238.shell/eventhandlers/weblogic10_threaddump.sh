#!/bin/bash

#This script is used as nagios event handler.
#当weblogic10队列超过了nagios的告警阀值，产生严重告警时，会触发此脚本（此脚本作为nagios的事件触发来使用）
#此脚本会通过调用Nagios服务器上的WLSThreadsMonitor.class java程序来获取远程weblogic10的threaddump


#$PROGNAME -H HOST -S ServerName -P port -u username -p password -s $SERVICESTATE$ -t $SERVICESTATETYPE$ -n $SERVICEATTEMPT$
#其中 -H HOST, -S ServerName,  -P port, -u username, -p password 这些参数用于指定对哪个weblogic server进行threaddump
#另外 -s $SERVICESTATE$,-t $SERVICESTATETYPE$, -n $SERVICEATTEMPT$ 这三个参数是nagios的宏，是服务事件处理脚本中必须处理的
#  $SERVICESTATE$  				分为OK,WARNING,UNKNOWN,CRITICAL
#  $SERVICESTATETYPE$			分为SOFT,HARD
#  $SERVICEATTEMPT$				为服务检查重试的次数

#此脚本在nagios中用法如下：
#一、 在nagios.cfg中添加如下定义(开启允许事件):
#		enable_event_handlers=1
#
#
#
#二、 在nagios check_commands.cfg中添加命令定义：
#          define command{
#					        command_name                    weblogic10_threaddump
#				    	    command_line                    $USER1$/eventhandlers/weblogic10_threaddump.sh -H $HOSTADDRESS$ -S $ARG1$ -P $ARG2$ -u $ARG3$ -p $ARG4$ -s $SERVICESTATE$ -t $SERVICESTATETYPE$ -n $SERVICEATTEMPT$
#						}
#
#三、 在要触发此事件命令的服务检查项中添加如下定义：
#					event_handler                   weblogic10_threaddump!PerServer!8001!weblogic!Weblogic123
#					event_handler_enabled           1
#

#Finished by HRWANG at  2011-10-25 and Published at 10.1.37.238

JAVA_HOME=/BEA/jdk1.6.0_16
CLASSPATH=:/BEA/jdk1.6.0_16/lib:/BEA/jdk1.6.0_16/jre/lib
PATH=/BEA/jdk1.6.0_16/bin/:/BEA/jdk1.6.0_16/jre/bin/:/sbin:/usr/sbin:/usr/local/sbin:/opt/gnome/sbin:/root/bin:/usr/local/bin:/usr/bin:/usr/X11R6/bin:/bin:/usr/games:/opt/gnome/bin:/opt/kde3/bin:/usr/lib/mit/bin:/usr/lib/mit/sbin:/root/bin:/opt/perf/bin

DumpDir="/srv/weblogic_thread_dump/10"
PROGNAME=`basename $0`

print_usage() {
        echo "Usage: "
        echo "  $PROGNAME -H HOST -S ServerName -P Port -u User -p Pass -s SERVICESTATE -t SERVICESTATETYPE -n SERVICEATTEMPT"
		echo " "
        echo "Get thread dump of weblogic server through t3 when assgined nagios state is happened"
		echo " "
		echo "eg:    "
		echo "  $PROGNAME -H 10.1.8.74 -S PerServer -P 8001 -u weblogic -p Weblogic123 -s CRITICAL -t HARD -n 1"
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
			exit 0
			;;
		-h)
			print_help
			exit 0
			;;
		-H)
			WEBLOGIC_HOSTNAME="$2"
			shift
			;;
		-S)
			WEBLOGIC_SERVERNAME="$2"
			shift
			;;
		-P)
			WEBLOGIC_PORT="$2"
			shift
			;;
		-u)
			WEBLOGIC_USER="$2"
			shift
			;;
		-p)
			WEBLOGIC_PASS="$2"
			shift
			;;
		-s)
			NAGIOS_STATE="$2"
			shift
			;;
		-t)
			NAGIOS_STATETYPE="$2"
			shift
			;;
		-n)
			NAIGOS_ATTEMPT="$2"
			shift
			;;
		*)
			print_help
			exit 0
			;;
	esac
	shift
done


CUR_TIME=$(date +%Y%m%d%H%M%S)


if [[ -n ${WEBLOGIC_HOSTNAME} && -n ${WEBLOGIC_SERVERNAME} && -n ${WEBLOGIC_PORT} && -n ${WEBLOGIC_USER} && -n ${WEBLOGIC_PASS} ]];then
	case "${NAGIOS_STATE}" in
		OK)
			#nothing to do 
			;;
		WARNING)
			#nothing to do 
			;;
		UNKNOWN)
			#nothing to do 
			;;
		CRITICAL)
			case "${NAGIOS_STATETYPE}" in
				SOFT)
					#nothing to do 
					;;
				HARD)
					cd /usr/local/nagios/libexec/eventhandlers/weblogic10
					/BEA/jdk1.6.0_16/bin/java -cp .:/BEA/weblogic10/wlserver_10.3/server/lib/weblogic.jar WLSThreadsMonitor ${WEBLOGIC_HOSTNAME} ${WEBLOGIC_SERVERNAME} ${WEBLOGIC_PORT} ${WEBLOGIC_USER} ${WEBLOGIC_PASS} > ${DumpDir}/${WEBLOGIC_HOSTNAME}_${WEBLOGIC_SERVERNAME}_${WEBLOGIC_PORT}_${CUR_TIME} 2>&1
					;;
			esac
			;;
	esac
else
	print_help
fi

exit 0

