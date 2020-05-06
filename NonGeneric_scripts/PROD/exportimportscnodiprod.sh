DateTimeScr=`date +%d%m%y_%H%M`
ENVI_SCR=~/accelatis.env
Dir=/hyp_util/ODIImportExports
WorkDir=$Dir/WorkingDir
Emailid="naresh.k.mopala@sherwin.com"
logs=$Dir/logs
ENV=xlythq01-pub

echo -e " This Script will migrate scenario from""\033[1;31m \e[4m QA --> PROD \033[m\e[0m"".Do you want to continue please enter Y/y for Yes and N/n for No. "

read option

if [ "$option" = "Y" ] || [ "$option" = "y" ] ;then
echo " Enter the scenario name. If there are multiple scenarios, separate by comma.Dont use Version 001 at the end.If you are migrating multiple scenarios and any one of the scenario name is invalid/not exist  then entire script will fail . Please pass correct scenario name and run again. "

read red_scn_name

if [ -z "$red_scn_name" ] ;then
        echo " No scenario name entered.Exiting from Script...... "
        exit 1;

elif [ "$ENV" != `hostname` ]   ; then
        echo " Script cannot be executed from this server.Script can be executed from xlythq01-pub server. Please login into the server and execute the script. "
        exit 1;
else
        echo $red_scn_name > $Dir/impexpodiscn.txt
        tr -s ','  '\n'< $Dir/impexpodiscn.txt  > $Dir/impexpodiscnfinal.txt
        rm $Dir/impexpodiscn.txt
        chmod 777 $Dir/impexpodiscnfinal.txt
fi


. $ENVI_SCR
        echo " $DateTimeScr: Loading $red_scn_name Scenario name to the Temporary Table. "
        sqlldr apex_hyperion/QyUx5sUdtm@APEXPROD bad=$logs/loadscndatatotable_$DateTimeScr.bad control=$Dir/scnexportimport.ctl  log=$logs/loadscndatatotable_$DateTimeScr.log ERRORS=999999 &> $logs/tableload_$DateTimeScr.log


cntvar=`echo -ne "set heading off \n select count(*) from scnexports ;" | sqlplus -s apex_hyperion/QyUx5sUdtm@APEXPROD`
cntvar1=$(echo $cntvar | tr -d ' ')

if [ "$cntvar1" = "0" ] ;then
        echo " $DateTimeScr:No Records added to scnexports table in APEX. Please try running script again. Exiting from the script...... "
        rm -f $Dir/impexpodiscnfinal.txt
        exit 1;

else
        echo " $DateTimeScr: Scenario name is loaded into temporary table "
        echo " $DateTimeScr: Executing ODI Export Scenario Job in QA ODI. Exporting Scenario from QA Servers and Copying to Prod Servers "
	ssh oracle@xlytwv01-pub /hyp_util/ODIImportExports/PROD/exportqaodiscntoprod.sh        
	status=$?
#	echo $status
#       chmod 777 $WorkDir/*
        rm -f $Dir/impexpodiscnfinal.txt

fi

if [ $status -ne 0 ];then
        rm -f $WorkDir/*
	echo "Exiting from script ......"
        exit 1;

else
	chmod 777 $WorkDir/*
        echo " $DateTimeScr: Executing ODI Import Scenario Commands in PROD ODI "
	/u01/app/oracle/product/11.1.1/Oracle_ODI_1/oracledi/agent/bin/startscen.sh IMPORTSCENARIOPROD 001 PROD &>  $logs/ProdODIImport.log

        exportPrododistatus=`awk -F "[()]" '{ for (i=2; i<NF; i+=2) print $i }'  $logs/ProdODIImport.log`
        mv $logs/ProdODIImport.log $logs/ProdODIImport_$DateTimeScr.log
if [ "$exportPrododistatus" = "DONE" ];then

        echo " $DateTimeScr: Scenario Migration Completed Successfully in Prod "
        rm -f $WorkDir/*
        echo " $DateTimeScr: Truncating Temporary table in APEX "
. $ENVI_SCR
        echo "truncate table scnexports;" | sqlplus -s apex_hyperion/QyUx5sUdtm@APEXPROD
else
echo " $DateTimeScr: Scenario Migration Completed with $exportPrododistatus status. Please login into Prod ODI Studio and verify whether scenario migrated correctly or not.Generally we get Warning status if scenario doesnt exist in Prod. It fails to take backup and delete thats why jobs end with Warning Status. There might be other cases also please check Prod Operator sessions logs for more details  "
        rm -f $WorkDir/*
        echo " $DateTimeScr: Truncating scenario name from the APEX table "
. $ENVI_SCR
        echo "truncate table scnexports;" | sqlplus -s apex_hyperion/QyUx5sUdtm@APEXPROD

fi






fi

else
echo " No Proper Input.Exiting from script...... "
exit 1;

fi

