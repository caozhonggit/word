#!/bin/bash

#This script is used as nagios event handler.
#当linux平台上的weblogic队列超过了nagios的告警阀值，产生严重告警时，会触发此脚本（此脚本作为nagios的事件触发来使用）
#此脚本会通过check_nrpe 调用被监管平台上的jvm内存dump脚本


#$PROGNAME -H HOST -S ServerName -s $SERVICESTATE$ -t $SERVICESTATETYPE$ -n $SERVICEATTEMPT$
#其中 -H HOST, -S ServerName 这两个参数用于指定对哪个weblogic server进行快照抓取
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
#					        command_name                    weblogic_jstack_snapshot
#				    	    command_line                    $USER1$/eventhandlers/nagios_eventhandle_weblogic_jstack.sh -H #$HOSTADDRESS$ -S $ARG1$ -s $SERVICESTATE$ -t $SERVICESTATETYPE$ -n $SERVICEATTEMPT$
#						}
#
#三、 在要触发此事件命令的服务检查项中添加如下定义：
#					event_handler                   weblogic_jstack_snapshot!PerServer
#					event_handler_enabled           1
#

#Finished by HRWANG at  2011-09-01 and Published at 10.1.37.238


PROGNAME=`basename $0`

print_usage() {
        echo "Usage: "
        echo "  $PROGNAME -H HOST -S ServerName -s SERVICESTATE -t SERVICESTATETYPE -n SERVICEATTEMPT"
		echo " "
        echo "Get event queue of weblogic server through t3 when assgined nagios state is happened"
		echo " "
		echo "eg:    "
		echo "  $PROGNAME -H 10.1.8.74 -S PerServer -s CRITICAL -t HARD -n 1"
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


if [[ -n ${WEBLOGIC_HOSTNAME} && -n ${WEBLOGIC_SERVERNAME} ]];then
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
					echo "${CUR_TIME} - Execute weblogic event handler jstack" >> /var/log/jstack_event.log
					/usr/local/nagios/libexec/check_nrpe -H ${WEBLOGIC_HOSTNAME} -t 30 -c jstack_dump -a ${WEBLOGIC_SERVERNAME}
					;;
			esac
			;;
	esac
else
	print_help
fi

exit 0

