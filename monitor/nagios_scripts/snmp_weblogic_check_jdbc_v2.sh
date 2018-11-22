#!/bin/bash

#snmp_weblogic10_check.sh -H hostname/IP -C community [-p] [-w] [-c] -t <Weblogic_ServerName> -s 
#This nagios plagin is finished by HongRui Wang at 2010-05-18
#2010-06-12  当snmpwalk执行结果为No Such Object available on this agent at this OID时，命令返回状态为0，修正了此种情况的判断
#2010-11-19  更改队列的判断方式，只要队列中出现等待的线程，则进行告警
#2010-11-24  将jvm/queue/jdbc的数据写入文件，为了给应用管理员参考
#2010-11-30  更改队列的判断方式
#            "Execute Thread Total Count" = threadPoolRuntimeExecuteThreadTotalCount
#			 "Execute Thread Idle Count"  = threadPoolRuntimeExecuteThreadIdleCount
#			  "Standby Thread Count"      = threadPoolRuntimeStandbyThreadCount
#             "Active Execute Threads"    = "Execute Thread Total Count" - "Standby Thread Count"
#             Used Thread                 = "Active Execute Threads" - "Execute Thread Idle Count"
#2011-03-28  添加了控 weblogic 中有无独占线程，如果有独占线程（hogging thread）则说明线程缓冲池中有stuck （阻塞）状态的线程
#2011-04-08  由于weblogic10的jvm大小是动态增长的。而我们通过oid只能获取当前总大小，这个值和指定分配给jvm使用的大小还有些出入。
#            通常当前总大小可以随着需要而增长，最大增长到指定分配的jvm大小，因此用当前总大小计算jvm使用率有些不太准确。
#            这次添加了可以指定分配给jvm使用的内存大小，这个值是动态增长的极限，通过它算使用率更合适。如果没有指定分配给jvm使用
#            的内存大小，算法会延续过去的形式。
#2011-04-28  原来检查历史数据写入文件的方式保留，再增加将每天的检查历史数据写入一个单独文件
#2011-05-06  jvm的查询结果中出现了错误类型的提示，导致获取数值出问题
#2011-07-05  queue部分，将取得oid的值改为取最后一个字段，而非第四个
#2011-07-05  jdbc部分，将取值oid的部分改为取最后一个字段，而非以":"为分隔符的第四个字段
#2011-08-08  serverstate和jvm部分，将取值oid的部分改为最后一个字段，而非以“：”为分隔符的第四个字段
#2011-08-31  同一台机器上两个domain，每个domian都有一个AdminServer，历史记录是以IP_SERVER的形式保存，
#            这样导致两个domian的AdminServer数据写入一个文件，现在添加snmp端口来区分
#2011-12-29  hoggingthread部分增加了指定严重告警阀值的功能
#2012-01-31  jdbc部分增加了"$jdbc_pool_g"不等与OID的情况
#2012-03-15  (NOT VERIFY)有时候server的状态会显示成空("AppServer1" status is )，因此在状态的未知情况中添加$status为空的情况
#2012-03-26  将hoggingthread的取第四个字段的命令gawk '{printf $4}'，改为了取最后一个字段 gawk '{printf $NF}'

#Test on SUSE10SP2-x86_64

PATH="/usr/bin:/usr/sbin:/bin:/sbin"
LIBEXEC="/usr/local/nagios/libexec"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

PROGNAME=`basename $0`
SNMPWALK="/usr/bin/snmpwalk"
output="/srv/check_weblogic_output/10"
output1="/srv/check_weblogic_output/10_everyday"

VER=2c
serverRuntimeName=".1.3.6.1.4.1.140.625.360.1.15"                   #version 8 9 10
serverRuntimeState=".1.3.6.1.4.1.140.625.360.1.60"					 #version 8 9 10 


jvmRuntimeName=".1.3.6.1.4.1.140.625.340.1.15"
jvmRuntimeHeapFreeCurrent=".1.3.6.1.4.1.140.625.340.1.25"
jvmRuntimeHeapSizeCurrent=".1.3.6.1.4.1.140.625.340.1.30"

threadPoolRuntimeObjectName=".1.3.6.1.4.1.140.625.367.1.5"                          #version 9 10
threadPoolRuntimeExecuteThreadTotalCount=".1.3.6.1.4.1.140.625.367.1.25"	        #version 9 10
threadPoolRuntimeExecuteThreadIdleCount=".1.3.6.1.4.1.140.625.367.1.30"	            #version 9 10
#threadPoolRuntimeQueueLength=".1.3.6.1.4.1.140.625.367.1.35"                        #version 9 10
#threadPoolRuntimePendingUserRequestCount=".1.3.6.1.4.1.140.625.367.1.40"            #version 9 10
threadPoolRuntimeStandbyThreadCount=".1.3.6.1.4.1.140.625.367.1.60"                 #version 9 10


executeQueueRuntimeName=".1.3.6.1.4.1.140.625.180.1.15"                             #version 8    find the string "weblogic.kernel.Default"                 
executeQueueRuntimeParent=".1.3.6.1.4.1.140.625.180.1.20" 							#version 8
executeQueueRuntimeExecuteThreadCurrentIdleCount=".1.3.6.1.4.1.140.625.180.1.25"	#version 8    "The number of idle threads assigned to the queue."

jdbcConnectionPoolRuntimeName=".1.3.6.1.4.1.140.625.190.1.15"						#"BEA-proprietary MBean name"
jdbcConnectionPoolRuntimeParent=".1.3.6.1.4.1.140.625.190.1.20"		
jdbcConnectionPoolRuntimeActiveConnectionsCurrentCount=".1.3.6.1.4.1.140.625.190.1.25"		#"The current total active connections."				
jdbcConnectionPoolRuntimeWaitingForConnectionCurrentCount=".1.3.6.1.4.1.140.625.190.1.30"	#"The current total waiting for a connection."
jdbcConnectionPoolRuntimeActiveConnectionsHighCount=".1.3.6.1.4.1.140.625.190.1.40"		    #The high water mark of active connections in this JDBCConnectionPoolRuntimeMBean.
																							#The count starts at zero each time the JDBCConnectionPoolRuntimeMBean
																							#is instantiated
jdbcConnectionPoolRuntimeWaitingForConnectionHighCount=".1.3.6.1.4.1.140.625.190.1.45"      #The high water mark of waiters for a connection in this JDBCConnectionPoolRuntimeMBean.
																							#The count starts at zero each time the JDBCConnectionPoolRuntimeMBean
																							#is instantiated.
jdbcConnectionPoolRuntimeMaxCapacity=".1.3.6.1.4.1.140.625.190.1.60"						#"The maximum capacity of this JDBC pool"#

#jdbc state 
jdbcConnectionPoolRuntimeState=".1.3.6.1.4.1.140.625.190.1.75"                              #The current state of the connection pool. Running...
jdbcDataSourceRuntimeState=".1.3.6.1.4.1.140.625.191.1.35"				    #The current state of datasource, Running... for weblogic  10.3.0
threadPoolRuntimeHoggingThreadCount=".1.3.6.1.4.1.140.625.367.1.55"                         #监控 weblogic 中有无独占线程，则如果有独占线程（hogging thread）说明线程缓冲池中将要有stuck （阻塞）状态的线程

print_usage() {
        echo "Usage: "
        echo "		$PROGNAME [-v version]  -H HOST -C community [-p port] -t Weblogic_ServerName [-w warning] [-c critical] -s [serverstate|jvm|queue|jdbc|jdbcstat]"
        echo "Check Weblogic Status:"
		echo "		$PROGNAME [-v 1|2c] -H HOST -C community [-p port] -t Weblogic_ServerName -s serverstate"
		echo "Check Weblogic JVM Heap Usage:"
		echo "		$PROGNAME [-v 1|2c] -H HOST -C community [-p port] -t Weblogic_ServerName -w warning -c critical -a assign-memory -s jvm"
		echo "Check Weblogic Queue Runing Num:"
		echo " 		$PROGNAME [-v 1|2c] -H HOST -C community [-p port] -t Weblogic_ServerName -w warning -c cirtical -s queue"
		echo "Check Weblogic JDBC Pool:"
		echo " 		$PROGNAME [-v 1|2c] -H HOST -C community [-p port] -t Weblogic_ServerName -s jdbc"
		echo "Check Weblogic JDBC state:"
		echo " 		$PROGNAME [-v 1|2c] -H HOST -C community [-p port] -t Weblogic_ServerName -s jdbcstat"
		echo "Check Weblogic Hogging Thread:"
		echo "		$PROGNAME [-v 1|2c] -H HOST -C community [-p port] -t Weblogic_ServerName [-c critical] [-w warning]  -s hoggingthread"
		echo " "
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
		-v)
			VER="$2"
			shift
			;;
		-H)
			HOSTNAME="$2"
			shift
			;;
		-C)
			COMMUNITY="$2"
			shift
			;;
		-p)
			PORT="$2"
			shift
			;;
		-s)
			PR="$2"
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
		-a)                             #2011-04-08 增加了指定jvm大小的参数
			AssignJVM="$2"
			shift
			;;
		-t)
			TITLE1="$2"					#servername，不包含双引号，用于命令行中public@servername中，带双引号在脚本中无法执行
			TITLE='"'$TITLE1'"'
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

if [[ -n $HOSTNAME && -n $COMMUNITY && -n $PR && -n $TITLE ]];then 
	case $PR in 
		#Check Weblogic Status
		serverstate)
			if [[ -n $PORT ]];then
				status=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $serverRuntimeState |gawk '{print $NF}' )
				#2012-02-02 增加如下行是为了判断是否能够正常获取snmp信息
				$SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $serverRuntimeState >/dev/null 2>&1
				r1=$?
			else
				status=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $serverRuntimeState |gawk '{print $NF}' )
				$SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $serverRuntimeState >/dev/null 2>&1
				r1=$?
			fi
			if [[ "$r1" -eq 0 ]];then
				if [[ "$status" = '"RUNNING"' ]];then
					printf "%s%s%s\n" $TITLE " status is " $status
					exit $STATE_OK
				elif [[ "$status" = "Such" || "$status" = "more" || "$status" = "OID" || -z ${status} ]];then
					echo "ERROR -Can't get Server State"
					exit $STATE_UNKNOWN
				else
					printf "%s%s%s\n" $TITLE " status is " $status
					exit $STATE_CRITICAL
				fi
			else
				echo "ERROR -Can't get Server State"
				exit $STATE_UNKNOWN
			fi
			;;
		#Check Weblogic JVM Heap
		jvm)
			if [[ -n $PORT ]];then
				server=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jvmRuntimeName | gawk '{print $NF}' )
				jvm_cur_free=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jvmRuntimeHeapFreeCurrent |gawk '{print $NF}' )
				jvm_cur_size=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jvmRuntimeHeapSizeCurrent |gawk '{print $NF}' )
			else
				server=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jvmRuntimeName | gawk '{print $NF}' )
				jvm_cur_free=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jvmRuntimeHeapFreeCurrent |gawk '{print $NF}' )
				jvm_cur_size=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jvmRuntimeHeapSizeCurrent |gawk '{print $NF}' )				
			fi
			
			
			if [[ -n $jvm_cur_free && -n $jvm_cur_size && "$jvm_cur_size" != "Such" && "$jvm_cur_size" != "OID" ]];then
				if [[ -n $WARN && -n $CRIT ]];then
					#2011-04-08 指定分配给JVM的内存大小为jvm的总大小，如果没有指定分配的jvm容量，则按获取的当前总大小来计算
					if [[ -n $AssignJVM ]];then
						(( jvm_cur_usage=(${jvm_cur_size}-${jvm_cur_free})*100/${AssignJVM} ))
						(( jvm_cur_use=${jvm_cur_size}-${jvm_cur_free} ))
						(( jvm_cur_warn=${AssignJVM}*${WARN}/100 ))
						(( jvm_cur_cirt=${AssignJVM}*${CRIT}/100 ))
						jvm_cur_size=${AssignJVM}	
					else		
					(( jvm_cur_usage=(${jvm_cur_size}-${jvm_cur_free})*100/${jvm_cur_size} ))
					(( jvm_cur_use=${jvm_cur_size}-${jvm_cur_free} ))
					(( jvm_cur_warn=${jvm_cur_size}*${WARN}/100 ))
					(( jvm_cur_cirt=${jvm_cur_size}*${CRIT}/100 ))
					fi
										
					if [[ $jvm_cur_usage -le $WARN ]];then
						printf "%s%s%s%s%%%s%s" "OK - " $TITLE " JVM Heap is used: " $jvm_cur_usage "  Total is: " $jvm_cur_size
						STATUS=$STATE_OK
					elif [[ $jvm_cur_usage -gt $WARN && $jvm_cur_usage -le $CRIT ]];then
						printf "%s%s%s%s%%%s%s" "WARN - " $TITLE " JVM Heap is used: " $jvm_cur_usage "  Total is: " $jvm_cur_size
						STATUS=$STATE_WARNING
					else
						printf "%s%s%s%s%%%s%s" "CRITICAL - " $TITLE " JVM Heap is used: " $jvm_cur_usage "  Total is: " $jvm_cur_size
						STATUS=$STATE_CRITICAL
					fi
					printf "%s%s%s%s%s%s%s%s\n" "| used=" $jvm_cur_use ";" $jvm_cur_warn ";" $jvm_cur_cirt ";0;" $jvm_cur_size 
					#2011-11-24 write data to file for administrator
					DATE_TIME=$( /bin/date "+%Y-%m-%d %H:%M:%S" )
					printf "%-10s %s\tTotal : %-15s Free : %-15s Used : %-15s Usage : %2s%% \n" $DATE_TIME $jvm_cur_size $jvm_cur_free $jvm_cur_use $jvm_cur_usage >>${output}/${HOSTNAME}_${TITLE1}_${PORT}_jvm.out
					#2011-04-28 write data to file order by date
				    File_Date=$( /bin/date +%Y%m%d )
					printf "%-10s %s\tTotal : %-15s Free : %-15s Used : %-15s Usage : %2s%% \n" $DATE_TIME $jvm_cur_size $jvm_cur_free $jvm_cur_use $jvm_cur_usage >>${output1}/${HOSTNAME}_${TITLE1}_${PORT}_jvm.${File_Date}
					exit $STATUS
				else
					print_help
					exit $STATE_UNKNOWN
				fi
			else
				echo "ERROR -Can't get JVM Heap"
				exit $STATE_UNKNOWN
			fi
			;;
		#Check Weblogic Queue
		queue)
			if [[ -n $PORT ]];then				
				#2010-11-30 write data to file for administrator
				queue_total_count=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $threadPoolRuntimeExecuteThreadTotalCount | gawk '{print $NF}' )
				queue_idle_count=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $threadPoolRuntimeExecuteThreadIdleCount | gawk '{print $NF}' )
				queue_standby_count=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $threadPoolRuntimeStandbyThreadCount | gawk '{print $NF}' )
			else				
				#2010-11-30 write data to file for administrator
				queue_total_count=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $threadPoolRuntimeExecuteThreadTotalCount | gawk '{print $NF}' )
				queue_idle_count=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $threadPoolRuntimeExecuteThreadIdleCount | gawk '{print $NF}' )
				queue_standby_count=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $threadPoolRuntimeStandbyThreadCount | gawk '{print $NF}' )
			fi
			if [[ -n $WARN && -n $CRIT ]];then		
				if [[ -n $queue_total_count && "$queue_total_count" != "OID" && -n $queue_idle_count && "$queue_idle_count" != "OID" && -n $queue_standby_count && "$queue_standby_count" != "OID" ]];then
						#2010-11-30 write data to file for administrator
						(( active_Q=${queue_total_count}-${queue_standby_count} ))
						(( used_Q=${active_Q}-${queue_idle_count} ))
					
						if [[ $used_Q -le $WARN ]];then
							printf "%s%s%s%s%s%s%s%s\n" "OK - Active_Execute_Threads: " $active_Q " Execute_Thread_Total_Count: " $queue_total_count " Execute_Thread_Idle_Count: " $queue_idle_count " Used_Thread_Count: " $used_Q 
							STATUS=$STATE_OK
						elif [[ $used_Q -gt $WARN && $used_Q -le $CRIT ]];then
							printf "%s%s%s%s%s%s%s%s\n" "WARN - Active_Execute_Threads: " $active_Q " Execute_Thread_Total_Count: " $queue_total_count " Execute_Thread_Idle_Count: " $queue_idle_count " Used_Thread_Count: " $used_Q 
							STATUS=$STATE_WARNING
						else
							printf "%s%s%s%s%s%s%s%s\n" "CRIT - Active_Execute_Threads: " $active_Q " Execute_Thread_Total_Count: " $queue_total_count " Execute_Thread_Idle_Count: " $queue_idle_count " Used_Thread_Count: " $used_Q 
							STATUS=$STATE_CRITICAL
						fi
						#性能数据
						printf "%s%s%s%s%s%s%s%s\n" "| used=" $used_Q ";" $WARN ";" $CRIT ";0;" $queue_total_count
						#2011-11-30 write data to file for administrator
						DATE_TIME=$( /bin/date "+%Y-%m-%d %H:%M:%S" )
						printf "%-10s %s\tActive_Execute_Threads : %-7s Execute_Thread_Total_Count : %-7s Execute_Thread_Idle_Count : %-7s Execute_Thread_Used_Count : %-7s \n" $DATE_TIME $active_Q $queue_total_count $queue_idle_count $used_Q >>${output}/${HOSTNAME}_${TITLE1}_${PORT}_queue.out
						#2011-04-28 write data to file order by date
						File_Date=$( /bin/date +%Y%m%d )
						printf "%-10s %s\tActive_Execute_Threads : %-7s Execute_Thread_Total_Count : %-7s Execute_Thread_Idle_Count : %-7s Execute_Thread_Used_Count : %-7s \n" $DATE_TIME $active_Q $queue_total_count $queue_idle_count $used_Q >>${output1}/${HOSTNAME}_${TITLE1}_${PORT}_queue.${File_Date}
						exit $STATUS
				else
					echo "ERROR -Can't get Weblogic Queue"
					exit $STATE_UNKNOWN
				fi
			else
				print_help
				exit $STATE_UNKNOWN
			fi
			;;
		#Check Weblogic JDBC
		jdbc)
			#servername可能在多个jdbc pool中都有连接，检查此servername所在任何一个jdbc pool中是否有等待连接，如果有就告警
			if [[ -n $PORT ]];then
				#增加这条测试命令，是为了确定当前可以正常获取OID值。因为snmp命令跟上管道符处理部分后，返回值总为0
				jdbc_pool_test=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeName )
				r1=$?
				jdbc_pool_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeName |gawk -F: '{print $NF}'| sed -e 's/"//g' -e 's/ //g' ))
				jdbc_wait_count_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeWaitingForConnectionCurrentCount |gawk '{print $NF}' ))
				
				#2010-11-24 write data to file for administrator
				jdbc_active_count_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeActiveConnectionsCurrentCount |gawk '{print $NF}' ))
				jdbc_wait_highcount_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeWaitingForConnectionHighCount |gawk '{print $NF}' ))
				jdbc_active_highcount_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeActiveConnectionsHighCount |gawk '{print $NF}' ))
				jdbc_capacity_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeMaxCapacity |gawk '{print $NF}' ))
			else
				jdbc_pool_test=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeName )
				r1=$?
				jdbc_pool_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeName |gawk -F: '{print $NF}'| sed -e 's/"//g' -e 's/ //g' ))
				jdbc_wait_count_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeWaitingForConnectionCurrentCount |gawk '{print $NF}' ))
				
				#2010-11-24 write jdbc data to file for administrator
				jdbc_active_count_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeActiveConnectionsCurrentCount |gawk '{print $NF}' ))
				jdbc_wait_highcount_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeWaitingForConnectionHighCount |gawk '{print $NF}' ))
				jdbc_active_highcount_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeActiveConnectionsHighCount |gawk '{print $NF}' ))
				jdbc_capacity_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeMaxCapacity |gawk '{print $NF}' ))
			fi
			
			if [[ "$r1" -eq 0 && "$jdbc_pool_g" != "Such"  && "$jdbc_pool_g" != "jdbcConnectionPoolRuntimeName=NoSuchObjectavailableonthisagentatthisOID" && "$jdbc_pool_g" != "OID" ]];then
				n=0
				crit_num=0
				for i in "${jdbc_pool_g[@]}";do
					if [[ ${jdbc_wait_count_g[$n]} -gt 0 ]];then
						printf "%s%s%s%s%s" " <= CRIT - JDBC Pool : " ${jdbc_pool_g[$n]} " - Current Waiting Connections Num:" ${jdbc_wait_count_g[$n]} "=>" 
						(( crit_num=${crit_num}+1 ))
					else		
						printf "%s%s%s%s%s" " <= JDBC Pool : " ${jdbc_pool_g[$n]} " - Current Waiting Connections Num:" ${jdbc_wait_count_g[$n]} "=>"         						
					fi
					(( n=${n}+1 ))			
				done

				#2010-11-24 write jdbc data to file for administrator
				DATE_TIME=$( /bin/date "+%Y-%m-%d %H:%M:%S" )
				#2011-04-28 write data to file order by date
				File_Date=$( /bin/date +%Y%m%d )
				for ((j=0;j<${#jdbc_pool_g[@]};j++))
				do
					printf "%-10s %s\tPool: %-10s Capacity: %-3s Active_High: %-3s Waiting_High: %-3s Current_Active: %-3s Current_Waiting: %-3s \n" ${DATE_TIME} ${jdbc_pool_g[$j]} ${jdbc_capacity_g[$j]} ${jdbc_active_highcount_g[$j]} ${jdbc_wait_highcount_g[$j]} ${jdbc_active_count_g[$j]} ${jdbc_wait_count_g[$j]} >> ${output}/${HOSTNAME}_${TITLE1}_${PORT}_jdbc.out
					printf "%-10s %s\tPool: %-10s Capacity: %-3s Active_High: %-3s Waiting_High: %-3s Current_Active: %-3s Current_Waiting: %-3s \n" ${DATE_TIME} ${jdbc_pool_g[$j]} ${jdbc_capacity_g[$j]} ${jdbc_active_highcount_g[$j]} ${jdbc_wait_highcount_g[$j]} ${jdbc_active_count_g[$j]} ${jdbc_wait_count_g[$j]} >> ${output1}/${HOSTNAME}_${TITLE1}_${PORT}_jdbc.${File_Date}
				done
				
				if [[ ${crit_num} -gt 0 ]];then
					exit $STATE_CRITICAL
				else
					exit $STATE_OK
				fi
			else
				echo "ERROR -Can't get Weblogic JDBC INFO"
				exit $STATE_UNKNOWN
			fi
			;;
		jdbcstat)
		    #servername可能在多个jdbc pool中都有连接，检查此servername所在任何一个jdbc pool中是否有等待连接，如果有就告警
			if [[ -n $PORT ]];then
				#增加这条测试命令，是为了确定当前可以正常获取OID值。因为snmp命令跟上管道符处理部分后，返回值总为0
				jdbc_pool_test=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeName )
				r1=$?
				if [[ $r1 -ne 0 ]] ; then
					echo "ERROR -Can't get Weblogic JDBC state"
					exit $STATE_UNKNOWN
				fi
				jdbc_pool_li=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeName | wc -l )
				jdbc_pool_stat_li=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcDataSourceRuntimeState | wc -l)
				if [[ $jdbc_pool_li -ne $jdbc_pool_stat_li ]]; then
					echo "ERROR - Weblogic JDBC state is unknown"
					exit $STATE_UNKNOWN
				fi
				jdbc_pool_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeName |gawk -F: '{print $NF}'| sed -e 's/"//g' -e 's/ //g' ))
				jdbc_pool_stat_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcDataSourceRuntimeState |gawk -F: '{print $NF}'| sed -e 's/"//g' -e 's/ //g' ))
			else
				jdbc_pool_test=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeName )
				r1=$?
				if [[ $r1 -ne 0 ]] ; then
					echo "ERROR -Can't get Weblogic JDBC state"
					exit $STATE_UNKNOWN
				fi
				jdbc_pool_li=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeName | wc -l )
				jdbc_pool_stat_li=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcDataSourceRuntimeState | wc -l)
				if [[ $jdbc_pool_li -ne $jdbc_pool_stat_li ]]; then
					echo "ERROR - Weblogic JDBC state is unknown"
					exit $STATE_UNKNOWN
				fi
				jdbc_pool_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeName |gawk -F: '{print $NF}'| sed -e 's/"//g' -e 's/ //g' ))
				jdbc_pool_stat_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcDataSourceRuntimeState |gawk -F: '{print $NF}'| sed -e 's/"//g' -e 's/ //g' ))
			fi
			
			if [[ "$r1" -eq 0 && "$jdbc_pool_g" != "Such"  && "$jdbc_pool_g" != "jdbcConnectionPoolRuntimeName=NoSuchObjectavailableonthisagentatthisOID" && "$jdbc_pool_g" != "OID" ]];then
				n=0
				crit_num=0
				for i in "${jdbc_pool_g[@]}";do
					if [[ ${jdbc_pool_stat_g[$n]} != "Running" ]];then
						if [ -n "`echo ${jdbc_pool_stat_g[$n]} | grep NoSuchObjectavailableonthisagentatthisOID`" ] ; then
							printf "%s%s%s%s%s" " <=  OK - JDBC Pool : " ${jdbc_pool_g[$n]} " - Current state:" ${jdbc_pool_stat_g[$n]} "=>" 
						else
							printf "%s%s%s%s%s" " <= CRIT - JDBC Pool : " ${jdbc_pool_g[$n]} " - Current state:" ${jdbc_pool_stat_g[$n]} "=>" 
							(( crit_num=${crit_num}+1 ))
						fi
					else		
						printf "%s%s%s%s%s" " <= JDBC Pool : " ${jdbc_pool_g[$n]} " - Current state:" ${jdbc_pool_stat_g[$n]} "=>"         						
					fi
					(( n=${n}+1 ))			
				done
				if [[ ${crit_num} -gt 0 ]];then
					exit $STATE_CRITICAL
				else
					exit $STATE_OK
				fi
			else
				echo "ERROR -Can't get Weblogic JDBC INFO"
				exit $STATE_UNKNOWN
			fi
			;;
		#check jdbc state(warning)
		jdbcstatwarn)
                    #servername可能在多个jdbc pool中都有连接，检查此servername所在任何一个jdbc pool中是否有等待连接，如果有就告警
                        if [[ -n $PORT ]];then
                                #增加这条测试命令，是为了确定当前可以正常获取OID值。因为snmp命令跟上管道符处理部分后，返回值总为0
                                jdbc_pool_test=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeName )
                                r1=$?
                                if [[ $r1 -ne 0 ]] ; then
                                        echo "ERROR -Can't get Weblogic JDBC state"
                                        exit $STATE_UNKNOWN
                                fi
                                jdbc_pool_li=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeName | wc -l )
                                jdbc_pool_stat_li=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcDataSourceRuntimeState | wc -l)
                                if [[ $jdbc_pool_li -ne $jdbc_pool_stat_li ]]; then
                                        echo "ERROR - Weblogic JDBC state is unknown"
                                        exit $STATE_UNKNOWN
                                fi
                                jdbc_pool_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcConnectionPoolRuntimeName |gawk -F: '{print $NF}'| sed -e 's/"//g' -e 's/ //g' ))
                                jdbc_pool_stat_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $jdbcDataSourceRuntimeState |gawk -F: '{print $NF}'| sed -e 's/"//g' -e 's/ //g' ))
                        else
                                jdbc_pool_test=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeName )
                                r1=$?
                                if [[ $r1 -ne 0 ]] ; then
                                        echo "ERROR -Can't get Weblogic JDBC state"
                                        exit $STATE_UNKNOWN
                                fi
                                jdbc_pool_li=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeName | wc -l )
                                jdbc_pool_stat_li=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcDataSourceRuntimeState | wc -l)
                                if [[ $jdbc_pool_li -ne $jdbc_pool_stat_li ]]; then
                                        echo "ERROR - Weblogic JDBC state is unknown"
                                        exit $STATE_UNKNOWN
                                fi
                                jdbc_pool_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcConnectionPoolRuntimeName |gawk -F: '{print $NF}'| sed -e 's/"//g' -e 's/ //g' ))
                                jdbc_pool_stat_g=($( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $jdbcDataSourceRuntimeState |gawk -F: '{print $NF}'| sed -e 's/"//g' -e 's/ //g' ))
                        fi

                        if [[ "$r1" -eq 0 && "$jdbc_pool_g" != "Such"  && "$jdbc_pool_g" != "jdbcConnectionPoolRuntimeName=NoSuchObjectavailableonthisagentatthisOID" && "$jdbc_pool_g" != "OID" ]];then
                                n=0
                                crit_num=0
				warn_num=0
                                for i in "${jdbc_pool_g[@]}";do
                                        if [[ ${jdbc_pool_stat_g[$n]} != "Running" ]];then
                                                if [ -n "`echo ${jdbc_pool_stat_g[$n]} | grep NoSuchObjectavailableonthisagentatthisOID`" ] ; then
                                                        printf "%s%s%s%s%s" " <=  OK - JDBC Pool : " ${jdbc_pool_g[$n]} " - Current state:" ${jdbc_pool_stat_g[$n]} "=>"
                                                else
							if [[ ${jdbc_pool_stat_g[$n]} = "Overloaded" ]];then
								printf "%s%s%s%s%s" " <= WARN - JDBC Pool : " ${jdbc_pool_g[$n]} " - Current state:" ${jdbc_pool_stat_g[$n]} "=>"
								(( warn_num=${warn_num}+1 ))
							else
                                                        	printf "%s%s%s%s%s" " <= CRIT - JDBC Pool : " ${jdbc_pool_g[$n]} " - Current state:" ${jdbc_pool_stat_g[$n]} "=>"
                                                        	(( crit_num=${crit_num}+1 ))
							fi
                                                fi
                                        else
                                                printf "%s%s%s%s%s" " <= JDBC Pool : " ${jdbc_pool_g[$n]} " - Current state:" ${jdbc_pool_stat_g[$n]} "=>"              
                                        fi
                                        (( n=${n}+1 ))
                                done
                                if [[ ${crit_num} -gt 0 ]];then
                                        exit $STATE_CRITICAL
                                else
					if [[ ${warn_num} -gt 0 ]]; then
						exit $STATE_WARNING
					else
                                        	exit $STATE_OK
					fi
                                fi
                        else
                                echo "ERROR -Can't get Weblogic JDBC STATE INFO"
                                exit $STATE_UNKNOWN
                        fi
                        ;;	
		#Check Hogging Thread    
		#2011-03-28 add below check portion
		hoggingthread)
			if [[ -n $PORT ]];then
				hogging_thread=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME}:${PORT} $threadPoolRuntimeHoggingThreadCount | gawk '{print $NF}' )
			else
				hogging_thread=$( $SNMPWALK -v $VER -c ${COMMUNITY}@${TITLE1} ${HOSTNAME} $threadPoolRuntimeHoggingThreadCount | gawk '{print $NF}' )
			fi
			if [[ -n ${hogging_thread} && ${hogging_thread} != "Such" ]];then
				DATE_TIME=$( /bin/date "+%Y-%m-%d %H:%M:%S" )
				printf "%-10s %s\tHoggingThread: %-10s \n" ${DATE_TIME} ${hogging_thread} >>${output}/${HOSTNAME}_${TITLE1}_${PORT}_hoggingthread.out
				#2011-04-28 write data to file order by date
				File_Date=$( /bin/date +%Y%m%d )
				printf "%-10s %s\tHoggingThread: %-10s \n" ${DATE_TIME} ${hogging_thread} >>${output1}/${HOSTNAME}_${TITLE1}_${PORT}_hoggingthread.${File_Date}
				if [[ -n $CRIT ]] || [[ -n $WARN ]];then
					if [[ -n $CRIT ]];then
						if [[ ${hogging_thread} -gt $CRIT ]];then
							printf "%s%s%s%s\n" "CRIT - " ${TITLE1} " Hogging Thread Count: " ${hogging_thread}
							exit $STATE_UNKNOWN
						fi
					fi
					if [[ -n $WARN ]];then
						if [[ ${hogging_thread} -gt $WARN ]];then
							printf "%s%s%s%s\n" "WARN - " ${TITLE1} " Hogging Thread Count: " ${hogging_thread}
							exit $STATE_WARNING
						fi
					fi
					printf "%s%s%s%s\n" "OK - " ${TITLE1} " Hogging Thread Count: " ${hogging_thread}
					exit $STATE_OK
							
				else
					if [[ ${hogging_thread} -gt 0 ]];then
						printf "%s%s%s%s\n" "CRIT - " ${TITLE1} " Hogging Thread Count: " ${hogging_thread}
						exit $STATE_UNKNOWN
					else
						printf "%s%s\n"  "OK - There is no hogging thread on " ${TITLE1}
						exit $STATE_OK
					fi
				fi
			else
				echo "ERROR -Can't get Weblogic Hogging Thread INFO"
				exit $STATE_UNKNOWN
			fi			
			;;
	esac
else
	print_help
	exit $STATE_UNKNOWN
fi

