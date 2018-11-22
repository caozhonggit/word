#!/bin/bash
#
#wjiaxiaoyu@cebvendor.com
#7/21/2014
#
#check_port_becm.sh Hostname/IP command 

PROGNAME=`basename $0`

print_usage(){
  echo "Usage: "
  echo "  $PROGNAME Hostname/IP command"
}
if [ -z "$1" -o -z "$2" ] ; then
  print_usage
  exit 0
fi

tmpPath="/tmp/$1"
/usr/local/nagios/libexec/check_nrpe -H $1 -c $2 -t 60 > $tmpPath 2>&1
returnCode=`echo $?`
#echo $returnCode
num=`cat $tmpPath | wc -l ` 
returnText=""

if [ $num -gt 1 ] ; then 
  str1=`cat $tmpPath|\
  awk 'BEGIN{RS="\n";ORS=" "} 
  /is exsit/ {flag=1;print $2} 
  /IS OK/ {flag=1;print $7}'`
  #END{if(flag==1) print("is exist\n")} '
  if [ -n "$str1" ] ; then
    #echo "Port:"$str1"is exist"
    returnText="Port:"$str1"is exist"
  fi

  str2=`cat $tmpPath|\
  awk 'BEGIN{RS="\n";ORS=" "}
  /is not exsit/ {flag=1;print $2}
  /IS DOWN/ {flag=1;print $7}'`
  #END{if(flag==1) print("is not exist")}'
  if [ -n "$str2" ] ; then
    #echo "Port:"$str2"is not exist"
    returnText="Port:"$str2"is not exist"
  fi
else
  returnText=`cat $tmpPath`
fi
rm $tmpPath 2>&1
echo $returnText
exit $returnCode
