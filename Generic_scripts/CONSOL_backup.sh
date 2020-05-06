#!/bin/bash
#--------------------------------------------------------------------------------
# CONSOL_backup.sh v1
# This is a wrapper script to run the consolidated backups
# MEP 10-31-2016 Disables email log files
#NR 06-10-2018 Added lines to send Backup rerun status emails.
setEnv ()
{
if  [[ "$ENVNAME" = "PROD1" ]]; then
   echo "PROD1"
   echo "Setting for server "$ENVNAME
   export JOBPARM=xlythq01-pub
   export JOBPREFIX=PROD
. /home/oracle/hyperion_epm1.env
elif  [[ "$ENVNAME" = "PROD2" ]]; then
   echo "PROD1"
   echo "Setting for server "$ENVNAME
   export JOBPARM=xlythq02-pub
   export JOBPREFIX=PROD
. /home/oracle/hyperion_epm2.env
else
   echo "Invalid environment name"
   exit 2
fi
export DATESTAMP=`date +%Y-%m-%d_%H_%M`
export SCRIPTSDIR=/hyp_util/scripts
export LOGDIRNAME=$ENVNAME"_CONSOL_"$DATESTAMP
export ROOTLOGDIR=/hyp_util/logs
export USER=`id -un`
#export MAILLIST=`cat $SCRIPTSDIR/maillist/11.1.2_EMAIL_NOTIFY.txt`
export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
#export MAILLIST=`cat $SCRIPTSDIR/maillist/11.1.2_EMAIL_DR_NOTIFY.mep.txt`
}

errorCheck ()
{
echo "Checking to see which databases were backed up ..."
cd $ROOTLOGDIR/$LOGDIRNAME
echo "Switched directory to "$ROOTLOGDIR/$LOGDIRNAME
export OKREPNAME=$ENVNAME"_CONSOL_OK."$DATESTAMP".log"
echo "Creating report "$ROOTLOGDIR/$LOGDIRNAME/$OKREPNAME
grep -a2 "Completed tar and backup for" ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL*.log | uniq
grep -a2 "Completed tar and backup for" ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL*.log | uniq > $ROOTLOGDIR/$LOGDIRNAME/$OKREPNAME


grep "Database export completed" ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL*.log | uniq
grep "Database export completed" ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL*.log | uniq >> $ROOTLOGDIR/$LOGDIRNAME/$OKREPNAME
echo ""
echo "----------------------------------------------------------------------------------------------"
#echo "Looking for "$ROOTLOGDIR/$LOGDIRNAME/$OKREPNAME
#ls -ltr $ROOTLOGDIR/$LOGDIRNAME/$OKREPNAME
if [ -s $ROOTLOGDIR/$LOGDIRNAME/$OKREPNAME ]; then
#   export MAILBODY=`cat $ROOTLOGDIR/$LOGDIRNAME/${ENVNAME}_CONSOL_EXP_OK.${DATESTAMP}.log`
 #  echo "Mailing logfile ..."
    echo "******************************************************************"
    echo "DISABLED EMAIL FOR LOG FILE PLEASE CHECK "$ROOTLOGDIR/$LOGDIRNAME/${ENVNAME}_CONSOL_EXP_OK.${DATESTAMP}.log
	echo "******************************************************************"
   export MAILBODY="<INFO> Full Logfile for "$0" <Action> Please review the log information for databases that have been backed up successfully"
   export MAILSUBJECT="<INFO> EPM "$ENVNAME" CONSOL Backups Informational log information for databases that have been backed up successfully"
#   ( echo $MAILBODY ; /usr/bin/uuencode $ROOTLOGDIR/$LOGDIRNAME/$OKREPNAME $OKREPNAME ) | mailx -s "$MAILSUBJECT" "$MAILLIST"
#    echo "Mailing logfile ..."
#	  export MAILBODY="<INFO> Full Logfile for "$0" <Action> Please review the log information for databases that have been backed up successfully"
#     export MAILSUBJECT="<INFO> EPM "$ENVNAME" CONSOL Backups Informational log information for databases that have been backed up successfully"
#	  export MAILFILE=$SUMMERRORFILE
#	  MailMessage   
else
   echo "The "$ROOTLOGDIR/$LOGDIRNAME/$OKREPNAME" has 0 bytes not sending mail ..."
fi
echo "Checking for errors ..."
export ERRREPNAME=$ENVNAME"_CONSOL_Error."$DATESTAMP".err"
grep -b2 -a1 'ERROR\|ESS_RTN_CODE\=2' ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL*.log
echo "Look in "$ROOTLOGDIR/$LOGDIRNAME" for details" > $ROOTLOGDIR/$LOGDIRNAME/$ERRREPNAME
echo "Errors for all "$ENVNAME"_ESS_APP_BACKUP_CONSOL*.log" >> $ROOTLOGDIR/$LOGDIRNAME/$ERRREPNAME
echo "----------------------------------------------------------------------------------------------" >> $ROOTLOGDIR/$LOGDIRNAME/$ERRREPNAME
grep -b2 -a1 'ERROR\|ESS_RTN_CODE\=2' ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL*.log >> $ROOTLOGDIR/$LOGDIRNAME/$ERRREPNAME
echo ""  >> $ROOTLOGDIR/$LOGDIRNAME/$ERRREPNAME
echo "Checking for Warnings ..."
grep "WARNING" -B 1 ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL*.log
echo "Warnings for all "$ENVNAME"_ESS_APP_BACKUP_CONSOL*.log" >> $ROOTLOGDIR/$LOGDIRNAME/$ERRREPNAME
echo "----------------------------------------------------------------------------------------------" >> $ROOTLOGDIR/$LOGDIRNAME/$ERRREPNAME
grep "WARNING" -B 1  ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL*.log >> $ROOTLOGDIR/$LOGDIRNAME/$ERRREPNAME
echo "----------------------------------------------------------------------------------------------"
#   export MAILBODY=`cat $ROOTLOGDIR/$LOGDIRNAME/${ENVNAME}_EXP0_Error.${DATESTAMP}.err`
if [ -s $ROOTLOGDIR/$LOGDIRNAME/$ERRREPNAME ]; then
   ERROFILEHAVEERRORS=`grep 'ERROR\|WARNING\|ESS_RTN_CODE\=2' $ROOTLOGDIR/$LOGDIRNAME/$ERRREPNAME | wc -l` 
   if [[ $ERROFILEHAVEERRORS -eq 0 ]]; then
         echo "The "$ROOTLOGDIR/$LOGDIRNAME/$ENVNAME"_CONSOL_Error."$DATESTAMP".err is error free not sending mail ..."
   else
#      echo "Mailing errorfile ..."
      echo "******************************************************************"
	  echo "DISABLED EMAIL FOR ERROR FILE PLEASE CHECK "$ROOTLOGDIR/$LOGDIRNAME/$ENVNAME"_CONSOL_Error."$DATESTAMP".err"
	  echo "******************************************************************"
	  export MAILBODY="<CRITICAL> Full Error Summary for "$0" <Action> Please review the errors and correct, All Logs for this run are in "$ROOTLOGDIR/$LOGDIRNAME
      export MAILSUBJECT="<CRITICAL> EPM ER "$ENVNAME" CONSOL Error Summary Information"
      #( echo $MAILBODY ; /usr/bin/uuencode $ROOTLOGDIR/$LOGDIRNAME/${ENVNAME}_CONSOL_Error.$DATESTAMP.err ${ENVNAME}_CONSOL_Error.$DATESTAMP.err ) | mailx -s "$MAILSUBJECT" "$MAILLIST"
      echo $MAILBODY | mailx -s "$MAILSUBJECT" -a $ROOTLOGDIR/$LOGDIRNAME/${ENVNAME}_CONSOL_Error.$DATESTAMP.err $MAILLIST
   fi
# Use this without uuencode
#  else     
#      export SUMMERRORFILE=$ROOTLOGDIR/$LOGDIRNAME/$ERRREPNAME
#      echo "Mailing errorfile ..."
#	  export MAILBODY="<INFO> Full Error Summary for "$0" <Action> Please review the errors and correct, All Logs for this run are in "$ROOTLOGDIR/$LOGDIRNAME
#      export MAILSUBJECT="<INFO> EPM ER "$ENVNAME" CONSOL Error Summary Information"
#	  export MAILFILE=$SUMMERRORFILE
#	  MailMessage
 #   fi
fi
}

function MailMessage()
{
echo $MAILBODY | mailx -s "$MAILSUBJECT" "$MAILLIST"
}

function Start_Email()
{
	export MAILLIST1=`cat /global/ora_backup/scripts/bkupmail.txt`
	echo "Sending backup start email"
	echo "Essbase Backup Started" | mailx -s "EPM $JOBPREFIX Backup Started for Version 11.1.2.4" "$MAILLIST1"
}


function End_Email()
{
export MAILLIST1=`cat /global/ora_backup/scripts/bkupmail.txt`
echo "Checking JOB STATUS and sending backup end email"
export JOB_STATUS=0
if [[ $ENVNAME == 'PROD2' ]];
then
        while [[ $JOB_STATUS == 0 ]]
        do
                if sed 'N;s/\n/ | /' $JOB_STATUS_FILE | grep "PROD1" | grep "PROD2"
                then
                        echo "Jobs are completed on both the nodes.Sending backup completion email"
                        echo "Essbase Backup end" | mailx -s "EPM PROD Backup has finished for Version 11.1.2.4" "$MAILLIST1"
                       export JOB_STATUS=1
	touch /hyp_interfaces/PROD/ess_scripts/Global_Shell/Back_Up_FW/Back_Up_End.txt
	chmod 777 /hyp_interfaces/PROD/ess_scripts/Global_Shell/Back_Up_FW/Back_Up_End.txt

                else
                        echo "Backup jobs are still running. Sleeping for 3 minutes"
                        sleep 180
                fi
        done
else
                echo "The script is in Node-1. Email will not be sent form this Node"
fi
}

function Backup_Rerun_Status()
{
export Output_File=$ROOTLOGDIR/Export_email_"$HOSTANME"_"$DATE".html
export COUNT=`cat $EXP_RERUN_FILE | wc -l`
echo "<html><title>Test</title><body>" > $Output_File
echo "<table border=1 cellspacing=0 cellpadding=3>" >> $Output_File
echo "<br>" >> $Output_File
echo "<tr><th>APP.DB</th><th>Backup Type</th><th>STATUS</th><th>Reason for Failure</th></tr>" >> $Output_File
for((i=1;i<=$COUNT;i++));
do
        export COL1=`cat $EXP_RERUN_FILE | awk -F '|' '{print $1}' | awk 'NR=='$i''`
        export COL2=`cat $EXP_RERUN_FILE | awk -F '|' '{print $2}' | awk 'NR=='$i''`
        export COL3=`cat $EXP_RERUN_FILE | awk -F '|' '{print $3}' | awk 'NR=='$i''`
        export COL4=`cat $EXP_RERUN_FILE | awk -F '|' '{print $4}' | awk 'NR=='$i''`
        echo "<tr><td>$COL1</td><td>$COL2</td><td>$COL3</td><td>$COL4</td></tr>" >> $Output_File
done
echo "</table></body></html>" >> $Output_File
cat - ${Output_File} <<EOF | /usr/sbin/sendmail -oi -t
To: $MAILLIST
Subject: $MAILSUBJECT
Content-Type: text/html; charset=us-ascii
Content-Transfer-Encoding: 7bit
MIME-Version: 1.0
EOF
}

function Backup_Failures_email()
{
Output_File=$ROOTLOGDIR/FAIL_email_"$DATE".html
export COUNT=`cat $EXP_FAIL_FILE | wc -l`
echo -e "EPM Team,<br><br>Below are the essbase level0 backup failures for PROD environment.<br><br>Please let us know when can we re-run the backups for the following applications.<br>" > $Output_File
echo "<html><title>Test</title><body>" >> $Output_File
echo "<table border=1 cellspacing=0 cellpadding=3>" >> $Output_File
echo "<br>" >> $Output_File
echo "<tr><th><b>APP.DB</th><th><b>Reason for Failure</th></tr>" >> $Output_File
for((i=1;i<=$COUNT;i++));
do
                export ROW1=`cat $EXP_FAIL_FILE | awk -F '|' '{print $1}' | awk 'NR=='$i''`
                export ROW2=`cat $EXP_FAIL_FILE | awk -F '|' '{print $2}' | awk 'NR=='$i''`
                echo "<tr><td>$ROW1</td><td>$ROW2</td></tr>" >> $Output_File
done
echo "</table></body>" >> $Output_File
echo "</html>" >> $Output_File
echo -e "<br><br>Regards,<br>Hyperion DBA Team" >> $Output_File
export MAILLIST2=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY_EPMTEAM.txt`
MAILTO=$MAILLIST2
SUBJECT="<CRITICAL> $ENVNAME Essbase Level0 Backup Failures"
#cat - ${Output_File} <<EOF | /usr/sbin/sendmail -oi -t
#To: ${MAILTO}
#Subject: $SUBJECT
#Content-Type: text/html; charset=us-ascii
#Content-Transfer-Encoding: 7bit
#MIME-Version: 1.0
#EOF

export EMAIL=corp.hyperion.dba@sherwin.com
mutt -e "set content_type=text/html" -s "$SUBJECT" "$MAILLIST2" < $Output_File


}

# Main
echo "Beginning script "$0
date
echo "----------------------------------------------------------------------------------------------"
echo "Setting variables ..."
echo "Param 1 = "$1
export ENVNAME=$1
setEnv
if [[ $ENVNAME = 'PROD2' ]]; then
Start_Email
fi
export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
export DATE=`date +%Y-%m-%d`
export EXP_RERUN_FILE=$ROOTLOGDIR/Export_Rerun_Status_"$HOSTNAME"_"$DATE".txt
export CUBE_NODATA_FILE=$ROOTLOGDIR/CUBE_NODATA_"$HOSTNAME"_"$DATE".txt
export JOB_STATUS_FILE=$ROOTLOGDIR/JOB_STATUS_FILE_"$DATE".txt
export EXP_FAIL_FILE=$ROOTLOGDIR/Export_Failure_"$DATE".txt
echo "Creating "$ENVNAME "CONSOL directory "$ROOTLOGDIR/$LOGDIRNAME" Check this directory for all mater log files"
mkdir $ROOTLOGDIR/$LOGDIRNAME
echo "Running Backups for all databases ..."
echo "----------------------------------------------------------------------------------------------"

if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Agg > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Agg.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Agg > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Agg.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Bud > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Bud.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Bud > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Bud.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Fst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Fst.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Fst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Fst.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Hst.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Hst.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Othr > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Othr.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Othr > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Othr.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Rpt.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_PSG_Rpt.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComWFP > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComWFP.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComWFP > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComWFP.log &
fi
sleep 120
# End of PSG sleep to allow CPU TO catch up
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Agg > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Agg.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Agg > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Agg.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Hst.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Hst.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_PA > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_PA.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_PA > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_PA.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Rpt.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Rpt.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Bud > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Bud.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Bud > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Bud.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Fst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Fst.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Fst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CORP_Fst.log &
fi
#sleep 120
# End of CORP sleep to allow CPU TO catch up
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Bud > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Bud.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Bud > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Bud.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Fst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Fst.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Fst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Fst.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Agg > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Agg.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Agg > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Agg.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Hst.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Hst.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_PA > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_PA.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_PA > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_PA.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Rpt.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CG_Rpt.log &
fi
sleep 120
# End of CG sleep to allow CPU TO catch up
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_Hst.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_Hst.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_PA > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_PA.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_PA > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_PA.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_Rpt.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CNSL_Rpt.log &
fi
sleep 120
# End of CNSL sleep to allow CPU TO catch up
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Bud > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Bud.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Bud > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Bud.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Fst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Fst.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Fst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Fst.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Agg > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Agg.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Agg > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Agg.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Hst.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Hst.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_PA > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_PA.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_PA > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_PA.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Rpt.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_GFG_Rpt.log &
fi
sleep 120
# End of GFG sleep to allow CPU TO catch up
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Bud > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Bud.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Bud > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Bud.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Fst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Fst.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Fst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Fst.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Agg > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Agg.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Agg > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Agg.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Hst.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Hst > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Hst.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_PA > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_PA.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_PA > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_PA.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Rpt.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Rpt > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_Rpt.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_CF > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_CF.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_CF > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_LACG_CF.log &
fi
sleep 120
# End of LACG sleep to allow CPU TO catch up

if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_Vision > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_Vision.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_Vision > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_Vision.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CMXSales > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CMXSales.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CMXSales > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CMXSales.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_SWBalanz > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_SWBalanz.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_SWBalanz > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_SWBalanz.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_cmxusa > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_cmxusa.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_cmxusa > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_cmxusa.log &
fi
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_sipcube > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_sipcube.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_sipcube > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_sipcube.log &
fi
sleep 120
# End of Comex sleep to allow CPU TO catch up

if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_STR_Hrs > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_STR_Hrs.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_STR_Hrs > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_STR_Hrs.log &
fi

sleep 120
if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CPCoil > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CPCoil.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CPCoil > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CPCoil.log &
fi

sleep 120
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_SHWPAY > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_SHWPAY.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_SHWPAY > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_SHWPAY.log &
fi

if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComPFP > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComPFP.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComPFP > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComPFP.log &
fi
if [[ $ENVNAME = 'PROD2' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComPFP_A > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComPFP_A.log &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComPFP_A > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_ComPFP_A.log &
fi

if [[ $ENVNAME = 'PROD1' ]]; then
     echo "Executing Command "
     echo "$SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CAPSpnd > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CAPSpnd &"
     $SCRIPTSDIR/essbase_master.sh $JOBPARM ${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CAPSpnd > $ROOTLOGDIR/$LOGDIRNAME/${JOBPREFIX}_ESS_APP_BACKUP_CONSOL_CAPSpnd &
fi

sleep 120
# End of Compfp sleep to allow CPU TO catch up


wait
echo ""
echo "All jobs are done ..."
date
echo ""
echo "----------------------------------------------------------------------------------------------"
echo "$ENVNAME" >> $JOB_STATUS_FILE
echo "----------------------------------------------------------------------------------------------"
echo "Checking if there were backup re-run performed"
if [ -s $EXP_RERUN_FILE ]; then
	chmod 755 $EXP_RERUN_FILE
	echo "Sending mail for Backup Re-run status"
	export MAILSUBJECT="<INFO> "$ENVNAME" Export Re-run Status"
	export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
	#mailx -s "$MAILSUBJECT" "$MAILLIST" < $EXP_RERUN_FILE
	Backup_Rerun_Status
fi
echo ""
echo "----------------------------------------------------------------------------------------------"
echo "Checking Application backup failed with NO DATA"
if [ -s $CUBE_NODATA_FILE ]; then
        echo "Sending mail for Cubes with NO DATA"
        export MAILSUBJECT="<INFO> "$ENVNAME" APPLICATION.DATABASE with NO DATA"
	export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
        mailx -s "$MAILSUBJECT" "$MAILLIST" < $CUBE_NODATA_FILE
fi
echo ""
echo "----------------------------------------------------------------------------------------------"
End_Email
echo "----------------------------------------------------------------------------------------------"
echo "Checking if there are any backup failed after the backup window"
if [[ $ENVNAME == 'PROD2' ]];
then
if [ -s $EXP_FAIL_FILE ];
        then
                export FILE=$ROOTLOGDIR/Fail_File_"$DATE".txt
                echo "Backups have failed. Sending email to EPM team to check when it can be re-run"
               # export MAILSUBJECT="<CRITICAL> "$JOBPREFIX" Essbase level0 Backup Failures." >> $FILE
		#export MAILLIST2=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY_EPMTEAM.txt`
                #echo -e "EPM Team,\n\nBelow are the essbase level0 backup failures for $JOBPREFIX environment.\n\nPlease let us know when can we re-run the backups for the following applications.\n" >> $FILE
                #echo "APP.DB         || Reason for failure" >> $FILE
                #echo "------------------------------------------------------" >> $FILE
                #cat $EXP_FAIL_FILE >> $FILE
                #echo "------------------------------------------------------" >> $FILE
                #echo -e "\nRegards,\nHyperion DBA Team" >> $FILE
                #mailx -s "$MAILSUBJECT" "$MAILLIST2" < $FILE
		Backup_Failures_email
#               rm $FILE
        fi
fi
echo "----------------------------------------------------------------------------------------------"
errorCheck
echo "----------------------------------------------------------------------------------------------"
