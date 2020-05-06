function SetupEnv()
{
##Setting the first parameter to match the control file
export HOST=`hostname`
echo "HOST is "$HOST

if [[ "$ENVNAME" = "PJ" ]]; then
   echo "PJ"
   echo "Setting for server "$ENVNAME
   export JOBPARM1=pj-xlytwv01-pub
   export JOBPREFIX=PJ_LCM
. /home/hyppj/hyperion-pj.env
elif  [[ "$ENVNAME" = "DEV" ]]; then
   echo "DEV"
   echo "Setting for server "$ENVNAME
   export JOBPARM1=dev-xlytwv02-pub
   export JOBPREFIX=DEV_LCM
. /home/hyperion/hyperion-dev.env
elif  [[ "$ENVNAME" = "INFRA" ]]; then
   echo "INFRA"
   echo "Setting for server "$ENVNAME
   export JOBPARM1=infra-xlytwv02-pub
   export JOBPREFIX=INFRA_LCM
. /home/hypinfra/hyperion-inf.env
elif  [[ "$ENVNAME" = "QA" ]]; then
   echo "QA1"
   echo "Setting for server "$ENVNAME
   export JOBPARM1=xlytwv01-pub
   export JOBPREFIX=QA_LCM
. /home/oracle/hyperion_epm1.env
elif  [[ "$ENVNAME" = "QA2" ]]; then
   echo "QA2"
   echo "Setting for server "$ENVNAME
   export JOBPARM1=xlytwv02-pub
   export JOBPREFIX=QA_LCM
. /home/oracle/hyperion_epm2.env
. /home/oracle/hyperion_epm2.env
elif  [[ "$ENVNAME" = "PROD" ]]; then
   echo "QA1"
   echo "Setting for server "$ENVNAME
   export JOBPARM1=xlythq01-pub
   export JOBPREFIX=PROD_LCM
. /home/oracle/hyperion_epm1.env
elif  [[ "$ENVNAME" = "PROD" ]]; then
   echo "QA2"
   echo "Setting for server "$ENVNAME
   export JOBPARM1=xlythq01-pub
   export JOBPREFIX=PROD_LCM
. /home/oracle/hyperion_epm2.env
else
   echo "Invalid environment name"
   exit 2
fi
export DATESTAMP=`date +%Y-%m-%d_%H_%M`
export SCRIPTSDIR=/hyp_util/scripts
export SCRIPTNAME=/hyp_util/scripts/lcm_master.sh
export RASCRIPTNAME=/hyp_util/scripts/lcm_master_ra.sh
export CTLFILEDIR=/hyp_util/controlfiles
export LOGDIRNAME=$ENVNAME"_LCMCONSOL_"$DATESTAMP
export ROOTLOGDIR=/hyp_util/logs
export USER=`id -un`
export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
#export MAILLIST=`cat $SCRIPTSDIR/maillist/11.1.2_EMAIL_DR_NOTIFY.mep.txt`
export DATE=`date +%Y-%m-%d`
export LCM_RERUN_FILE=$ROOTLOGDIR/LCM_Rerun_Status_"$HOSTNAME"_"$DATE".txt

#Set controlfile location
echo "Setting controlfile location ..."
echo "----------------------------------------------------------------------------------------------------"
if [[ "$HOST" = "xlytwv01-pub" ]]; then
    echo "Setting for server "$HOST
#       FILE=/global/ora_backup/scripts/controlfiles/er_qa_controlfile.ctl
        FILE=/hyp_util/controlfiles/er_nonprod_controlfile.ctl
#       FILE=/global/ora_backup/scripts/controlfiles/er_qa_controlfile_v7.ctl
elif [[ "$HOST" = "xlytwv02-pub" ]]; then
    echo "Setting for server "$HOST
#    FILE=/global/ora_backup/scripts/controlfiles/er_qa_controlfile.ctl
        FILE=/hyp_util/controlfiles/er_nonprod_controlfile.ctl
#       FILE=/global/ora_backup/scripts/controlfiles/er_qa_controlfile_v7.ctl
elif [[ "$HOST" = "xlythq01-pub" ]]; then
    echo "Setting for server "$HOST
        FILE=/hyp_util/controlfiles/er_prod_controlfile.ctl
#    FILE=/global/ora_backup/scripts/controlfiles/er_qa_controlfile.ctl
elif [[ "$HOST" = "xlythq02-pub" ]]; then
    echo "Setting for server "$HOST
    FILE=/hyp_util/controlfiles/er_prod_controlfile.ctl
else
        echo "Invalid hostname"
      export MAILBODY="Invalid hostname"
      export MAILSUBJECT="<CRITICAL> lcm_master.sh failed"
      export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
##          MailMessage
        exit 2
fi

}
function LCM_Rerun_Status()
{
export Output_File=$ROOTLOGDIR/LCM_email_"$HOSTNAME"_"$DATE".html
export COUNT=`cat $LCM_RERUN_FILE | wc -l`
echo "<html><title>Test</title><body>" > $Output_File
echo "<table border=1 cellspacing=0 cellpadding=3>" >> $Output_File
echo "<br>" >> $Output_File
echo "<tr><th>JOB NAME</th><th>STATUS</th></tr>" >> $Output_File
for((i=1;i<=$COUNT;i++));
do
        export COL1=`cat $LCM_RERUN_FILE | awk -F '|' '{print $1}' | awk 'NR=='$i''`
        export COL2=`cat $LCM_RERUN_FILE | awk -F '|' '{print $2}' | awk 'NR=='$i''`
        echo "<tr><td>$COL1</td><td>$COL2</td></tr>" >> $Output_File
done
echo "</table></body></html>" >> $Output_File
cat - ${Output_File} <<EOF | /usr/sbin/sendmail -oi -t
To: ${MAILLIST}
Subject: $MAILSUBJECT
Content-Type: text/html; charset=us-ascii
Content-Transfer-Encoding: 7bit
MIME-Version: 1.0
EOF
}

# Main
echo "Beginning script "$0
date
echo "----------------------------------------------------------------------------------------------"
echo "Setting variables ..."
echo "Param 1 = "$1
export ENVNAME=$1
SetupEnv

for i in $(cat $FILE | grep -i $JOBPREFIX | cut -d, -f1 | grep -v FOUND | grep -v RA)
#for i in $(cat $FILE | grep -i $JOBPREFIX | grep -i GFG | cut -d, -f1 | grep -v FOUND)
do
#echo "The Lcm Jobname without found" $i
echo "Executing the LCM job in background"
echo "$SCRIPTNAME $JOBPARM1 $i"
$SCRIPTNAME $JOBPARM1 $i &
done

echo " Sleeping for 5 minutes before starting Foundations"
sleep 1m

for j in $(cat $FILE | grep -i $JOBPREFIX | cut -d, -f1 | grep -i FOUND | grep -v FOUND_EPMA)
#for j in $(cat $FILE | grep -i yarusha | cut -d, -f1 | grep -i yarusha)
do
echo "The LCM jobname for only found" $j
echo "$SCRIPTNAME $JOBPARM1 $j"
$SCRIPTNAME $JOBPARM1 $j &
done

#echo " sleeping for 2 minutes before starting epma foundation"
#sleep 2m
echo "Waiting for finishing epma to avoid errors"
wait

for k in $(cat $FILE | grep -i $JOBPREFIX | cut -d, -f1 | grep -i FOUND_EPMA)
#for j in $(cat $FILE | grep -i yarusha | cut -d, -f1 | grep -i yarusha)
do
echo "The LCM jobname for only found" $k
echo "$SCRIPTNAME $JOBPARM1 $k"
$SCRIPTNAME $JOBPARM1 $k &
done
wait
echo "All LCMs but RA are complete and returning the exit status"
echo "--------------------------------------------------------------"
sleep 11h

for l in $(cat $FILE | grep -i $JOBPREFIX | cut -d, -f1 | grep -i RA)
do
echo "The LCM jobname for only found" $l
echo "$RASCRIPTNAME $JOBPARM1 $l"
$RASCRIPTNAME $JOBPARM1 $l
done


wait
echo ""
echo "All LCMs are complete and returning the exit status "
echo ""
echo "----------------------------------------------------------------------------------------------"
echo "Checking LCM Re-run status"
if [ -s $LCM_RERUN_FILE ]; then
	chmod 755 $LCM_RERUN_FILE
	echo "Sending mail for Backup Re-run status"
	export MAILSUBJECT="<INFO> "$ENVNAME" LCM Re-run Status"
#	mailx -s "$MAILSUBJECT" "$MAILLIST" < $LCM_RERUN_FILE
LCM_Rerun_Status
fi
echo ""
echo "----------------------------------------------------------------------------------------------"

