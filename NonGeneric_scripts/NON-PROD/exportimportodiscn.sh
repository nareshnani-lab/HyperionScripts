#!/bin/sh

######################################################################################################
# Name: exportimportodiscn.sh
# Purpose: This script handles the following,
#
#     1. This Script Migrates requested scenario from Dev to QA ODI environment. If there are multple scenarios separate by comma.If you are migrating multiple scenarios and  #     any one of the  scenario name is invalid/not exisit then entire script will fail. Please pass correct scenario name and run again.
#
#     2. Backups: This script takes neccessary backups before importing into respective environment. All the backups are appended with date and time stamp.All the backups are #        present in respective folder in /hyp_util/ODIImportExports
#     
# Usage:  ./exportimportodiscn.sh 
#
#
#
#
#
######################################################################################################

DateTimeScr=`date +%d%m%y_%H%M`
ENVI_SCR=~/accelatis.env
ENV=xlytwv02-pub
DEVUSERID=1103
Dir=/hyp_util/ODIImportExports
WorkDir=$Dir/WorkingDir
Emailid="naresh.k.mopala@sherwin.com"
logs=$Dir/logs

echo -e "This Script will migrate scenario from""\033[1;31m \e[4m DEV --> QA \033[m\e[0m"".Do you want to continue please enter Y/y for Yes and N/n for No."

read option

if [ "$option" = "Y" ] || [ "$option" = "y" ] ;then
echo "Enter the scenario name. If there are multiple scenarios, separate by comma.Don't use Version 001 at the end.If you are migrating multiple scenarios and any one of the scenario name is invalid/not exist  then entire script will fail . Please pass correct scenario name and run again."

read red_scn_name
if [ -z "$red_scn_name" ] ;then
	echo "No scenario name input.Exiting from Script......"
	exit 1;

elif [ "$ENV" != `hostname` ]  && [ `id -u` != $DEVUSERID ] ; then
	echo "Script cannot be executed from this server.Script can be executed from xlytwv02-pub server using hyperion user only. Please login into xlytwv02-pub and execute the script."
	exit 1;

else
	echo $red_scn_name > $Dir/impexpodiscn.txt
	tr -s ','  '\n'< $Dir/impexpodiscn.txt  > $Dir/impexpodiscnfinal.txt
	rm $Dir/impexpodiscn.txt
	chmod 777 $Dir/impexpodiscnfinal.txt
fi

. $ENVI_SCR
	echo " $DateTimeScr: Loading $red_scn_name Scenario to the Temporary Table "
	sqlldr apex_hyperion/QyUx5sUdtm@APEXPROD bad=$logs/loadscndatatotable.bad control=$Dir/scnexportimport.ctl  log=$logs/loadscndatatotable_$DateTimeScr.log ERRORS=999999 &> $logs/tableload_$DateTimeScr.log

cntvar=`echo -ne "set heading off \n select count(*) from scnexports ;" | sqlplus -s apex_hyperion/QyUx5sUdtm@APEXPROD`
cntvar1=$(echo $cntvar | tr -d ' ')

if [ "$cntvar1" = "0" ] ;then
        echo " $DateTimeScr: No Records added to scnexports table in APEX. Please try running script again. Exiting from the script...... "
	rm -f $Dir/impexpodiscnfinal.txt
        exit 1;
else
	echo " $DateTimeScr: Scenario name is loaded into table "
        echo " $DateTimeScr: Executing ODI Export Scenario Job in DEV ODI "
        /u05/app/oracle/product/11.1.1/Oracle_ODI_11117/oracledi/agent/bin/startscen.sh EXPORTSCENARIO 001 DEV &> $logs/DevODIExport_$DateTimeScr.log
        status=$?
#        chmod 777 $WorkDir/*
	rm -f $Dir/impexpodiscnfinal.txt
#echo $status

fi


if [ $status -ne 0 ];then
	echo " $DateTimeScr: Dev ODI Scenario Export Failed.Please Check ODI and Script log files for more details. Log files locatd at /hyp_util/ODIImportExports/logs folder "
	echo " Exporting ODI Scenario Failed" |  mailx -s "Exporting ODI Scenario Failed.Please Check ODI and Script log files for more details.Log Files located at /hyp_util/ODIImportExports/logs folder " $Emailid
        rm -f $WorkDir/*
        echo " $DateTimeScr: Truncating Temporary table in APEX "
. $ENVI_SCR
        echo "truncate table scnexports;" | sqlplus -s apex_hyperion/QyUx5sUdtm@APEXPROD 
	exit 1;

else

	chmod 777 $WorkDir/*
	echo " $DateTimeScr: Dev Export Scenario is Completed "
	echo " $DateTimeScr: Now Executing ODI Import Scenario Job in QA ODI "
	sudo -u oracle /u01/app/oracle/product/11.1.1/Oracle_ODI_1/oracledi/agent/bin/startscen.sh IMPORTSCENARIO 001 QA  &>  $logs/QAODIImport.log
	
	exportqaodistatus=`awk -F "[()]" '{ for (i=2; i<NF; i+=2) print $i }'  $logs/QAODIImport.log`
	mv $logs/QAODIImport.log $logs/QAODIImport_$DateTimeScr.log
if [ "$exportqaodistatus" = "DONE" ];then

 	echo " $DateTimeScr: Scenario Migration Completed Successfully in QA  "
        rm -f $WorkDir/*
        echo " $DateTimeScr: Truncating Temporary table in APEX "
. $ENVI_SCR
        echo "truncate table scnexports;" | sqlplus -s apex_hyperion/QyUx5sUdtm@APEXPROD
else
echo " $DateTimeScr: Scenario Migration Completed with $exportqaodistatus status. Please login into QA ODI Studio and verify whether scenario migrated correctly or not. Logs files located at /hyp_util/ODIImportExports/logs location. Generally we get Warning status if scenario doesnt exist in QA. It fails to take backup and delete thats why jobs endwith Warning Status. There might be other cases also please check QA Operator sessions for more details  "
        rm -f $WorkDir/*
        echo " $DateTimeScr: Truncating scenario name from the APEX table "
. $ENVI_SCR
        echo "truncate table scnexports;" | sqlplus -s apex_hyperion/QyUx5sUdtm@APEXPROD

fi


fi

else
echo "No Proper Input.Exiting from script......"
exit 1;

fi

