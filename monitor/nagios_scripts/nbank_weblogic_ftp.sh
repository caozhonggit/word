#!/bin/sh
#This shell is used as crontab.Put the nbank weblogic check result file on 10.1.106.20 every day

nbank_weblogic_output_dir=/srv/check_weblogic_output/8
today_time=$( date +%Y%m%d )
tar_name="nbank_weblogic_output_${today_time}.tar.gz"
yesterday=$( date -d yesterday +%Y%m%d )
del_name="nbank_weblogic_output_${yesterday}.tar.gz"

cd ${nbank_weblogic_output_dir}
tar czf ${tar_name} *

if [[ -f ${tar_name} ]];then
	ftp -v -n 10.1.106.20 <<EOF
	user test login106
	cd /home/yzt/OVO-Defend/nbank
	del ${del_name}
	bin
	put ${tar_name}
	bye
EOF
rm -f ${tar_name}
fi
