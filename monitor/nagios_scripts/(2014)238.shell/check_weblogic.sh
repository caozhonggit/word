#! /bin/bash

#check_weblogic.sh --jdbcpool url username password domainname servername poolname
#check_weblogic.sh --server url username password domainname servername

# -H host -p port -v "--type=<[jdbcpool|server]> --username username --password password --domain domainname --server servername [--pool poolname]"

export JAVA_HOME=/BEA/jdk1.5.0_10
export CLASSPATH=$CLASSPATH:$JAVA_HOME/lib:$JAVA_HOME/jre/lib:/BEA/weblogic/weblogic92/server/lib/weblogic.jar
export PATH=$PATH:$JAVA_HOME/bin:$JAVA_HOME/jre/bin:$PATH:$HOME/bin

PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION=`echo '$Revision: 1749 $' | sed -e 's/[^0-9.]//g'`

. $PROGPATH/utils.sh

print_usage() {
    echo "Usage:"
    echo "  $PROGNAME -H host -p port -v --type [jdbcpool|server] --username username --password password --domain domainname --server servername [--pool poolname] " 
    echo "  $PROGNAME --help"
    echo "  $PROGNAME --version"
}

print_help() {
    print_revision $PROGNAME $REVISION
    echo ""
    print_usage
    echo ""
    echo "Check Weblogic status"
    echo ""  
}

#parse weblogic parameters
parse_wls_para() {
#    echo $@
    while [ -n "$1" ]
    do
        case "$1" in
        --type)
            #type
            TYPE="$2"
            shift
            ;;
        --username)
            USER_NAME="$2"
            shift
            ;;
        --password)
            PASS_WORD="$2"
            shift
            ;;
        --domain)
            DOMAIN_NAME="$2"
            shift
            ;;
        --server)
            SERVER_NAME="$2"
            shift
            ;;
        --pool)
            POOL_NAME="$2"
            shift
            ;;
        *)
            print_usage
            exit $STATE_UNKNOWN
            ;;
        esac
        shift
    done
    #echo "TYPE:"$TYPE
    #echo "USER_NAME:"$USER_NAME
    #echo "PASS_WORD:"$PASS_WORD
    #echo "DOMAIN_NAME:"$DOMAIN_NAME
    #echo "SERVER_NAME:"$SERVER_NAME
    #echO "POOL_NAME:"$POOL_NAME

}

# check weblogic server information
check_wls_server() {
    
    local URL="t3://${HOST_NAME}:${SERVER_PORT}"
    local SERVER_INFO="${DOMAIN_NAME}:${SERVER_NAME}"
    #echo "java weblogic.Admin -url ${URL} -username ${USER_NAME} -password ${PASS_WORD} get -pretty"
    #echo "-mbean "${DOMAIN_NAME}:Location=${SERVER_NAME},Name=${SERVER_NAME},Type=${SERVER_TYPE}"" 
    
    tmpfile=`mktemp -t nagios.XXXXXX`
    #echo "tmpfile"$tmpfile
    java weblogic.Admin -url ${URL} -username ${USER_NAME} -password ${PASS_WORD} get -pretty \
        -mbean "${DOMAIN_NAME}:Location=${SERVER_NAME},Name=${SERVER_NAME},Type=${SERVER_TYPE}" \
        >${tmpfile} 2>&1
    #echo "java weblogic.Admin -url ${URL} -username ${USER_NAME} -password ${PASS_WORD} get -pretty 
    #    -mbean "${DOMAIN_NAME}:Location=${SERVER_NAME},Name=${SERVER_NAME},Type=${SERVER_TYPE}" "
     
    local N=`cat ${tmpfile} | grep ^"-" | wc -l`
    #echo "N:"$N  
    if [ $N -lt  1 ] 
    then
        #error
        #echo "tmpfile"$tmpfile
        #cat ${tmpfile}
        ERR_INFO=`cat ${tmpfile} | awk '{ printf $0 }'`
        #echo "ERR_INFO:"$ERR_INFO
        echo "CRITICAL - ${ERR_INFO}"
        rm -f $tmpfile
        return $STATE_CRITICAL      
        
    fi
    
    if [ $N -ge  1 ] 
    then
        local HEALTH_STATE=""     
        local RUN_STATE=""
        #HealthState State
        while read NAME VALUE
        do
           
            #PoolState WaitingForConnectionCurrentCount State
            #echo "NAME:${NAME} VALUE:${VALUE}"
            case "${NAME}" in
            HealthState:)
              HEALTH_STATE=${VALUE}
            ;;
            State:)
              RUN_STATE=${VALUE}
            ;;
            esac
        done < ${tmpfile}
        
        rm -f $tmpfile
        #echo "HEALTH_STATE:${HEALTH_STATE}"
        #echo "RUN_STATE:${RUN_STATE}"
      
        local HEALTH_STATE_INFO=${HEALTH_STATE}
      
        echo ${HEALTH_STATE_INFO} | awk -F, '{ print $1 }' | awk -F: '{ print $2 }' | read HEALTH_STATE
            
        #echo "HEALTH_STATE:${HEALTH_STATE}"
        #HEALTH_OK HEALTH_WARN HEALTH_CRITICAL HEALTH_FAILED
      
        if [[ "${RUN_STATE}" != "RUNNING" ]]
        then
            echo "CRITICAL - ${SERVER_INFO} State is ${RUN_STATE}"
            return $STATE_CRITICAL  
        fi
      
        case "${HEALTH_STATE}" in
        EALTH_OK)
        
            ;;
        HEALTH_WARN)
            echo "WARN - ${SERVER_INFO} HealthState is ${HEALTH_STATE_INFO}"
            return $STATE_WARNING 
            ;;
        HEALTH_CRITICAL)
            echo "CRITICAL - ${SERVER_INFO} HealthState is ${HEALTH_STATE_INFO}"
            return $STATE_CRITICAL
            ;;
        HEALTH_FAILED)
            echo "FAILED - ${SERVER_INFO} HealthState is ${HEALTH_STATE_INFO}"
            return $STATE_CRITICAL
            ;;
        esac
      
    fi
    echo "OK - ${SERVER_INFO} State is ${RUN_STATE},HealthState is ${HEALTH_STATE_INFO}"
    return $STATE_OK
    
}

# check weblogic jdbc pool information
check_wls_jdbcpool() {
    local URL="t3://${HOST_NAME}:${SERVER_PORT}"
    local POOL_INFO="${DOMAIN_NAME}:${SERVER_NAME}:${POOL_NAME}"
    
    tmpfile=`mktemp -t nagios.XXXXXX`
    java weblogic.Admin -url ${URL} -username ${USER_NAME} -password ${PASS_WORD} GET -pretty \
        -mbean "${DOMAIN_NAME}:Location=${SERVER_NAME},Name=${POOL_NAME},ServerRuntime=${SERVER_NAME},Type=${JDBC_TYPE}" \
        > ${tmpfile} 2>&1
    
    local N=`cat ${tmpfile} | grep ^"-" | wc -l`
    
    if [[ "$N" -lt  "1" ]] 
    then    
        #error
        ERR_INFO=`cat ${tmpfile} | awk '{ printf $0 }'`
        echo "CRITICAL - ${ERR_INFO}"
        rm -f $tmpfile
        return $STATE_CRITICAL
    fi
    
    if [[ "$N" -ge  "1" ]] 
    then
        local POOL_STATE=""
        local WAIT_CNT=""
        local RUN_STATE=""
        while read NAME VALUE
        do
            #PoolState WaitingForConnectionCurrentCount State
            #echo "NAME:${NAME} VALUE:${VALUE}"
            case "${NAME}" in
            PoolState:)
                POOL_STATE=${VALUE}
            ;;
            WaitingForConnectionCurrentCount:)
                WAIT_CNT=${VALUE}
            ;;
            State:)
                RUN_STATE=${VALUE}
            ;;
            esac
        done < ${tmpfile}
        
        rm -f ${tmpfile}
        #echo "POOL_STATE:${POOL_STATE}"
        #echo "WAIT_CNT:${WAIT_CNT}"
        #echo "RUN_STATE:${RUN_STATE}"
        if [[ "${POOL_STATE}" != "true" ]]
        then
            echo "CRITICAL - ${POOL_INFO} PoolState is ${POOL_STATE}"
            return $STATE_CRITICAL
        fi
        
        if [[ "${RUN_STATE}" != "Running" ]]
        then
            echo "CRITICAL - ${POOL_INFO} State is ${RUN_STATE}"
            return $STATE_CRITICAL
        fi
        
        if [[ "${WAIT_CNT}" -gt "0" ]]
        then
            echo "WARNING - ${POOL_INFO} WaitingForConnectionCurrentCount is ${WAIT_CNT}"
            return $STATE_WARNING
        fi        
    fi
    echo "OK - ${POOL_INFO} State is ${RUN_STATE},PoolState is ${POOL_STATE},WaitingForConnectionCurrentCount is ${WAIT_CNT}"
    
    return $STATE_OK
}

# do exit to delete tmpfile
do_exit() {
    if [ -n "$tmpfile" ] && [ -f $tmpfile ]
    then
        rm -f ${tmpfile}
    fi
}


if [ -z "$JAVA_HOME" ] 
then
    echo "Please set JAVA_HOME!"
    exit $STATE_UNKNOWN
fi

if [ -z "$CLASSPATH" ]
then
    echo "Please set CLASSPATH!"
    exit $STATE_UNKNOWN
else   
    echo $CLASSPATH | grep -q "weblogic.jar" 
    if [ $? -ne 0 ]
    then
        echo "Please add weblogic.jar to CLASSPATH!"
        exit $STATE_UNKNOWN
    fi
fi

PATH=$JAVA_HOME/bin:$PATH
export PATH

JDBC_TYPE="JDBCConnectionPoolRuntime"
SERVER_TYPE="ServerRuntime"

cmd="$1"

# Information options
case "$cmd" in
--help)
    print_help
    exit $STATE_OK
    ;;
-h)
    print_help
    exit $STATE_OK
    ;;
--version)
    print_revision $PROGNAME $REVISION
    exit $STATE_OK
    ;;
-V)
    print_revision $PROGNAME $REVISION
    exit $STATE_OK
    ;;
esac


#set -- `getopt -q H:p:v: "$@"`

#echo "$@"

#parse input args 
while [ -n "$1" ]
do
#    echo "\$1:"$1
    case "$1" in
    -H)
        #host
        HOST_NAME="$2"
        shift
        ;;
    -p)
        #port
        SERVER_PORT="$2"
        shift
        ;;
    -v)
        WL_ARGS="$2"
        shift
        ;;
    --)
        shift
        break
        ;;
    *)
        print_usage
        #exit $STATE_UNKNOWN
        ;;
    esac
    shift
done

#echo "parse weblogic parameters"
#parse weblogic parameters
parse_wls_para $WL_ARGS
#echo "end parse weblogic parameters"


case "${TYPE}" in
server)
    #server
    CHK_INFO=`check_wls_server`
    EXIT_STATE=$?
    echo $CHK_INFO
    do_exit
    exit $EXIT_STATE
    ;;
jdbcpool)
    #jdbc pool
    CHK_INFO=`check_wls_jdbcpool`
    EXIT_STATE=$?
    echo $CHK_INFO
    do_exit
    exit $EXIT_STATE
    ;;
*)
    print_usage
    exit $STATE_UNKNOWN
    ;;
esac


