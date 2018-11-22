#!/bin/bash
#这个Nagios插件调用check_nt来检查验印服务器10.1.5.128和10.1.5.129上跑着的14个验印程序。
#这些进程可以任何组合跑在两台机器上，只要14个都运行，就OK
#Finished by HongRui Wang at 2012-1-13
#出现异常时，显示对10.1.5.128运行的结果和10.1.5.129运行check_nt的结果，用于track。
#Test on SUSE10SP2 x86_64


CHECK_NT=/usr/local/nagios/libexec/check_nt 
YY_HOST1="10.1.5.128"
YY_HOST2="10.1.5.129"
NRPE_PORT=12489

#要检查的所有进程
procs="901221_ZDYY1.exe,901222_ZDYY2.exe,901223_ZDYY3.exe,901227_PLYY1.exe,901233_TCPJ1.exe,901234_TCPJ2.exe,901235_TCPJ3.exe,901224_ZDYY4.exe,901225_ZDYY5.exe,901226_ZDYY6.exe,901236_TCPJ4.exe,901237_TCPJ5.exe,901238_TCPJ6.exe,901239_PLYY2.exe"
#通过check_nt检查运行在10.1.5.128上的进程，会返回没有运行的进程名及状态
R_ON_YYHOST1=$( ${CHECK_NT} -H ${YY_HOST1} -t 20 -p ${NRPE_PORT} -v PROCSTATE -l ${procs} )
#过滤出没有运行在10.1.5.128上的进程列表
UNRUN_ON_YYHOST1=$( echo ${R_ON_YYHOST1} |gawk -F" " '{printf $1$5$9$13$17$21$25}'|sed -e 's/:$//g' -e 's/:/,/g' )
#检查没有运行在10.1.5.128上的进程是否在10.1.5.129上运行
R_ON_YYHOST2=$( ${CHECK_NT} -H ${YY_HOST2} -t 20 -p ${NRPE_PORT} -v PROCSTATE -l ${UNRUN_ON_YYHOST1} )
#看是否OK
OK_ON_BOTH=$( echo ${R_ON_YYHOST2} | gawk -F":" '{printf $1}' )
if [[ ${OK_ON_BOTH} == "OK" ]];then
	echo "OK - 14 YanYin Services are running on ${YY_HOST1} and ${YY_HOST2}"
	exit 0
else
	ERR_ON_BOTH=$( echo ${R_ON_YYHOST2} |gawk -F" " '{printf $1$5$9$13$17$21$25}'|sed -e 's/:$//g' -e 's/:/,/g' )
	echo "ERR - Below YANYIN Services: ${ERR_ON_BOTH} are not running on ${YY_HOST1} or ${YY_HOST2}"
	echo "check_nt Result from 10.1.5.128: $R_ON_YYHOST1"
	echo "Not running on 10.1.5.128 : $UNRUN_ON_YYHOST1"
	echo "check_nt Result from 10.1.5.129: $R_ON_YYHOST2"
	exit 2
fi
