#!/bin/sh

export ENV=$1
export DateTime=`date +%d%m%y_%H%M`
export DATESTAMP=`date +%Y-%m-%d_%H_%M`;

export LOGDIR=/hyp_util/logs/${ENV}

if [ ! -d ${LOGDIR} ];then
	mkdir $LOGDIR
fi
	
export ERRFILE=/hyp_util/logs/${ENV}/${ENV}_planning_sec_${DateTime}.err
export OUTFILE=/hyp_util/logs/${ENV}/${ENV}_planning_sec_${DateTime}.log
export ERRMAIL=/hyp_util/logs/${ENV}/${ENV}_planning_email_${DateTime}.err

if [ "$ENV" == "INFRA" ];then
	export BACKUP_LOCATION=/global/ora_backup/INFRA
	export PASSFILE=/u08/app/oracle/product/EPM/Middleware/user_projects/epmsystem1/Planning/planning1/hypadminpass.txt
	export CTLFILE=/hyp_util/controlfiles/INFRA/er_infra.ctl
	echo "Sourcing in environment for $ENV"
	. $HOME/hypinfra_epm1.env
	
elif [ "$ENV" == "DEV" ];then
	export BACKUP_LOCATION=/global/ora_backup/HYPENTD_SECFILE
	export PASSFILE=/u05/app/oracle/product/EPM/Middleware/user_projects/epmsystem1/Planning/planning1/hypadminpass.txt
	export CTLFILE=/hyp_util/controlfiles/er_nonprod_controlfile.ctl
	echo "Sourcing in environment for $ENV"
	. $HOME/hyperion-dev.env
	
elif [ "$ENV" == "QA" ];then
	export BACKUP_LOCATION=/global/ora_backup/HYPENTQ_SECFILE
	export PASSFILE=/u01/app/oracle/product/EPM/Middleware/user_projects/epmsystem1/Planning/planning1/hypadminpass.txt
	export CTLFILE=/hyp_util/controlfiles/er_nonprod_controlfile.ctl
	echo "Sourcing in environment for $ENV"
	. $HOME/hyperion_epm1.env
	
elif [ "$ENV" == "PROD" ];then
	export BACKUP_LOCATION=/global/ora_backup/HYPENTP_SECFILE
	export PASSFILE=/u01/app/oracle/product/EPM/Middleware/user_projects/epmsystem1/Planning/planning1/hypadminpass.txt
	export CTLFILE=/hyp_util/controlfiles/er_prod_controlfile.ctl
	echo "Sourcing in environment for $ENV"
	. $HOME/hyperion_epm1.env
	
else
	echo "Unknown environment"
	exit 1;
fi	


if [ -s ${PASSFILE} ]; then
        echo "Password file $PASSFILE present"
else
        echo "Password file $PASSFILE missing "
        exit 1;
fi


grep ",Planning," ${CTLFILE} | grep ER_${ENV} > ${LOGDIR}/${ENV}_planning_sec_apps.txt
if [ -s ${LOGDIR}/${ENV}_planning_sec_apps.txt ];then

	while IFS= read -r lines;
	do

	export APPNAME=`echo $lines | cut -d"," -f2`
	echo "Executing Planning security back up for ${APPNAME}"
	echo "${EPM_ORACLE_INSTANCE}/Planning/planning1/ExportSecurity.sh -f:${PASSFILE} /A=${APPNAME},/U=hypadmin,/TO_FILE=${BACKUP_LOCATION}/${APPNAME}_$DATESTAMP 2> ${LOGDIR}/${APPNAME}_exp_sec_${DateTime}.log"
	
	${EPM_ORACLE_INSTANCE}/Planning/planning1/ExportSecurity.sh -f:${PASSFILE} /A=${APPNAME},/U=hypadmin,/TO_FILE=${BACKUP_LOCATION}/${APPNAME}_$DATESTAMP 2> ${LOGDIR}/${APPNAME}_exp_sec_${DateTime}.log

	RET=`grep -q "Exception" ${LOGDIR}/${APPNAME}_exp_sec_${DateTime}.log; echo $?`
	if [ $RET -eq 0 ];then
	   echo "$DateTime;${ENV};planning_security.sh - Export Planning Security for $APPNAME failed"
	   echo "$DateTime;${ENV};planning_security.sh;${APPNAME};FAILURE" >>  $ERRMAIL
	else
	   if [ -s ${BACKUP_LOCATION}/${APPNAME}_${DATESTAMP}.txt ];then
			echo "$DateTime;${ENV};planning_security.sh - Export Planning Security for $APPNAME successful. Contents available in ${BACKUP_LOCATION}/${APPNAME}_${DATESTAMP}.txt"
			echo "$DateTime;${ENV};planning_security.sh;${APPNAME};SUCCESS" >>  $OUTFILE
	   else
			echo "$DateTime;${ENV};planning_security.sh - Export Planning Security for $APPNAME successful. Exported file empty ${BACKUP_LOCATION}/${APPNAME}_${DATESTAMP}.txt"
			echo "$DateTime;${ENV};planning_security.sh;${APPNAME};PARTIAL_SUCCESS:ExportFile_Empty" >>  $OUTFILE
		fi	
	fi

	done < ${LOGDIR}/${ENV}_planning_sec_apps.txt

else
	echo "File ${LOGDIR}/${ENV}_planning_sec_apps.txt missing"
	echo "Need this file to get the Planning application names for $ENV"
	echo "Script performing - grep \",Planning,\" ${CTLFILE} | grep ER_${ENV} > ${LOGDIR}/${ENV}_planning_sec_apps.txt" 
	exit 1;

fi



if [ -s ${ERRMAIL} ]; then
        echo "Failures in ${ERRMAIL}"
        echo "Printing failed exports"
        echo "##############################################################################################"
        cat $ERRMAIL
        echo "##############################################################################################"
	mailx -s "$ENV: planning_security.sh - Planning security export failures reported" corp.hyperion.dba@sherwin.com < $ERRMAIL
       	exit 1;

else
        echo "Planning Security export successful"
        echo "Printing successful exports"
        echo "##############################################################################################"
        cat $OUTFILE
        echo "##############################################################################################"
        exit 0;
fi


