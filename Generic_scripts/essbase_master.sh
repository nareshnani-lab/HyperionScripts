#!/bin/bash
#--------------------------------------------------------------------------------
# essbase_master.sh v8
# This is a master script that will run all of the essbase processing.
# It does essbase backups, lcm backup and restructure operations
# All operations are based off a controlfile that passes the parameters needed to run the script
#
# To run the script you pass the environment_name and the backup_name
# to this script
# environment_name is the name of the environment the script passes this as the first parameter on the command line, it usually
#       consists of the hostname unless it is an Essbase Server that is running more than 1 instance
#       if this is the case it is labelled <server_port>
#
# For example 
# ./essbase_master.sh cphypintq1 ESS_FULL_FS
# The script then goes to the controlfile and retrieves the parameters needed and runs the script with those parameters
# Backup Types are
# LCMBACKUP = LCM backup of Artifacts
# ESS_FULL_FS = Full File level Essbase backup of apps and ARBORPATH
# EXP0 = Level 0 export of the applications and database specified
#
#Version 3 
# Completely rewrote the script and added much more functionality
# Now added Application and database level offline and read only backups with data and without data and to a staging environment (flash)
# for quicker backups
#   QA_ESS_APP_BACKUP_FULL_<APP>
#   QA_ESS_APP_BACKUP_FULL_TOSTAGE_<APP>
#   QA_ESS_APP_BACKUP_NODATA_<APP>
#   QA_ESS_APP_BACKUP_ARCH_FULL_<APP>_<DB>
#   QA_ESS_APP_BACKUP_ARCH_NODATA_<APP><DB>
#
# Version 4
# I have added the new function ErrorExit to allow a line number in the email notification, need to get uuencode installed to add
# an attachment
# I have added logic to display the disk space in the backup directory and abort the backup if it is 100%
# Set essbase environment
# Added the capability to attach files using uuencode for error handling (need to develop it into script)
#
# Version 5
# Added logic in get essabse sessions to check the OS for hypuser jobs
# Changed subject line for emails
# Add developers to email list
# 
# Version 6 ## Added by Yarusha
# This is to facilitate the details of the backup jobs via a table. 
# The details of the job can bew reviewed in a database table in APEX with complete details of the job with the runtime status.
# This will act as a real time dashboard for all the backup jobs being run

# MEP 11/13/15 - LCM modifications for 11.1.2.4
# 1.  hyppj was unable to run 7zip because it needed execute access to the root 7zip directory, i modified this
# 2.  I changed the behavior of the zip command from
#	create a backup directory
#	LCM the artifacts into that directory
#	zip all the directories inside the backup directory
#	try and zip the backup directory (which always seemed not to work)
#	remove the directory (that was not zipped (also did not work)
#  to
#	#create a backup directory
#	LCM the artifacts into that directory
#	zip ONLY the full contents of the backup directory
#	remove the directory upon successful zip
# 3.  Put the backup name in all notifications so you dont see a .
# 4.  cat out the Artifact listing of what was backed up in the backup


# Version 7 ## Mike Paladino
# Consolidated backups to run after each other to save time
# Added another backup to back up application files not gotten by DB backups 
# VERY IMPORTANT DO NOT CREATE ANY VARIABLES STARTING WITH DB(1..n)
# The consolidated backups use the variables in the application list beginning with DB(1..)
# to generate a list of databases for the application to burst out the backups

# Version 8 ## Mike Paladino 06/15/2016
# Modified scripts to work from the new root directory /hyp_util and made modifications to paths based on this, 
# Replaced SCRIPTSDIR/maxl with ROOTBACKDIR/maxl
# Changed the name of the er_qa2_controlfile.ctl to er_nonprod_controlfile.ctl
# Had to add parameter MAXLDIR to ENV section at position 24 to account for filesystem move

# Version 8.1 Miker Paladino 10/28/2016
# Disabled alerting and informational emails for all but critical

# Version 9. Yarusha Nahar
# Adding more details on re-running the backup for Tricore visibility

# Version 10. Nithin Ravichandran 06/10/2018
# Adding export rerun and LCM rerun function for automated re-run in case of failure.

# Version 11. Nithin Ravichandran 12/25/2018
# Adding Ess_serv_status function to check essbase service status beore running CONSOL export

function SetupEnv()
{
export PROGNAME=$(basename $0)
echo " Setting env .."
export HOST=`hostname`
echo "HOST is "$HOST
#This needs to be updated as you change servers if the scripts directory changes, next release will put this in controlfile
#export SCRIPTSDIR=/global/ora_backup/scripts
#export SCRIPTSDIR=/u01/app/backup/scripts
#echo "Scripts Directory is "$SCRIPTSDIR
#
#Set controlfile location
echo "Setting controlfile location ..."
echo "----------------------------------------------------------------------------------------------------"
if [[ "$HOST" = "cphypd.sherwin.com" ]]; then
	echo "Setting for server "$HOST
    FILE=/global/ora_backup/scripts/controlfiles/er_controlfile.ctl		
elif  [[ "$HOST" = "cphypq.sherwin.com" ]]; then
    echo "Setting for server "$HOST
    FILE=/global/ora_backup/scripts/controlfiles/qa_controlfile.ctl
elif  [[ "$HOST" = "cphypp2sherwin.com" ]]; then
    echo "Setting for server "$HOST
    FILE=/global/ora_backup/scripts/controlfiles/prod_controlfile.ctl
elif [[ "$HOST" = "cphypintq1.sherwin.com" ]]; then
    echo "Setting for server "$HOST
    FILE=/global/ora_backup/scripts/controlfiles/er_controlfile.ctl
elif [[ "$HOST" = "xlytwv01-pub" ]]; then
    echo "Setting for server "$HOST
#	FILE=/global/ora_backup/scripts/controlfiles/er_qa_controlfile.ctl
	FILE=/hyp_util/controlfiles/er_nonprod_controlfile.ctl
#	FILE=/global/ora_backup/scripts/controlfiles/er_qa_controlfile_v7.ctl
elif [[ "$HOST" = "xlytwv02-pub" ]]; then
    echo "Setting for server "$HOST
#    FILE=/global/ora_backup/scripts/controlfiles/er_qa_controlfile.ctl
	FILE=/hyp_util/controlfiles/er_nonprod_controlfile.ctl
#	FILE=/global/ora_backup/scripts/controlfiles/er_qa_controlfile_v7.ctl
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
      export MAILSUBJECT="<CRITICAL> essbase_master.sh failed"
      export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
	  MailMessage
	exit 2
fi
echo ""
#Check if the BACKTYPE is valid
isJobValid=`grep -a -w -c $BACKTYPE $FILE`
if [[ $isJobValid -ne 1 ]]; then
   echo "Job is not valid, Error on line: $LINENO"
     echo "Is Job Valid = "$isJobValid
     echo "If this is above 1 then the script found more than 1 job with the same name in the controlfile"
     echo "Please make sure that there is only 1 distinct entry in the controlfile for each jobname, Error on line: $LINENO"
	 ErrorExit "Is Job Valid = "$isJobValid" If this is above 1 then the script found more than 1 job with the same name in the controlfile Please make sure that there is only 1 distinct entry in the controlfile for each jobname, Error on line: $LINENO"
   if [[ $isJobValid -eq 0 ]]; then
      echo "The Job was not found in the controlfile, Please validate the jobname in the job section of the controlfile, Error on line: $LINENO"
	  ErrorExit "The Job was not found in the controlfile, Please validate the jobname in the job section of the controlfile, Error on line: $LINENO"
   else
      echo "Is Job Valid = "$isJobValid
      echo "If this is above 1 then the script found more than 1 job with the same name in the controlfile"
      echo "Please make sure that there is only 1 distinct entry in the controlfile for each jobname, Error on line: $LINENO"
	  ErrorExit "Is Job Valid = "$isJobValid" If this is above 1 then the script found more than 1 job with the same name in the controlfile Please make sure that there is only 1 distinct entry in the controlfile for each jobname, Error on line: $LINENO"
   fi
else 
   echo "Job validation passed, there is a entry for the job in the controlfile"
fi
   
# Read controlfile

#Set environment parameters from controlfile
echo "Reading the environment parameters from the controlfile "$FILE
echo "DEBUG - Setting lookup string to "$ENV_NAME
echo "----------------------------------------------------------------------------------------------------"
export SERVERTYPE=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f2`
echo "Server Type is "$SERVERTYPE
export CLUSTER=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f3`
echo "Cluster Type is "$CLUSTER
export ROOTBACKDIR=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f4`
echo "Root Backup Directory is "$ROOTBACKDIR
export ENVFILE1=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f5`
echo "Environment file 1 is "$ENVFILE1
export ENVFILE2=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f6`
echo "Environment file 2 is "$ENVFILE2
export CLUSTER1=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f7`
echo "For this server cluster 1 is "$CLUSTER1
export CLUSTER2=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f8`
echo "For this server cluster 2 is "$CLUSTER2
export OSUSER=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f9`
echo "OS user for this server is "$OSUSER
export ROOTLOGDIR=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f10`
echo "Root Log Directory is "$ROOTLOGDIR
export STAGEBACKDIR=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f11`
echo "Stage Backup Directory is "$STAGEBACKDIR
export CLUOUTPUTLOC=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f12`
echo "Cluster output location to is "$CLUOUTPUTLOC
export SCRIPTSDIR=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f13`
echo "Root Scripts directory is "$SCRIPTSDIR
export ESSARCHDIR=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f14`
echo "Essbase Archive directory is "$ESSARCHDIR
export EXPDIR=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f15`
echo "Export directory is "$EXPDIR
export LCMROOTBACKDIR=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f16`
echo "LCM Root directory is "$LCMROOTBACKDIR
#export ENVIRONMENT=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f17`
#echo "Environment Name is "$ENVIRONMENT
export DRDIR=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f17`
echo "DR directory is "$DRDIR
export MWHOMEBACKDIR=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f18`
echo "Middleware Home Backup Directory is "$MWHOMEBACKDIR
export MWHOMEEXCLUDE=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f19`
echo "Middleware Home Backup Exclude List is "$MWHOMEEXCLUDE
echo ""
export DBCLIENT_ENV=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f20`
echo "Database Client for the status report load "$DBCLIENT_ENV
export ENVIRONMENT=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f21`
echo "Environment Name is "$ENVIRONMENT
export ARPTHBACKDIR=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f22`
echo "ARBORPATH Backup Directory is "$ARPTHBACKDIR
export ARPTHEXCLUDE=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f23`
echo "ARBORPATH Backup Exclude List is "$ARPTHEXCLUDE
export BKPENV_NAME=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f21 | cut -d_ -f2`
echo "BKPENV_NAME is "$BKPENV_NAME
export MAXLDIR=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f24` 
echo "MAXLDIR is "$MAXLDIR
echo ""
#NR Added BKP_TIME parameter. This will be read from Control file
# export BKP_TIME=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f25`
# echo "Backup Re-run end time is"$BKP_TIME
##CL15373-Modify hard coded timestamp to number of minutes##
#export BKP_TIME=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f25`
export BKP_MAX_DURATION=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f25`
#export BKP_TIME=`cat $FILE | grep -w ^$ENV_NAME | cut -d, -f25`
echo "Backup duration defined in $FILE = $BKP_MAX_DURATION"
export ESS_MASTER_START_TIME=`date +%Y-%m-%d\ %H:%M:%S`
echo "PRESENT TIME=$ESS_MASTER_START_TIME"
export MINUTES_IN_SECONDS=$((${BKP_MAX_DURATION}*60))
export ESS_MASTER_DATE_SECS=$(date +%s --date="$ESS_MASTER_START_TIME")
echo "PRESENT DATE IN SEC = $ESS_MASTER_DATE_SECS"
export BACKUP_MAX_TIME=$(date '+%Y-%m-%d %H:%M:%S' --date="@$((ESS_MASTER_DATE_SECS + MINUTES_IN_SECONDS))")
echo "MAX TIME FOR BACKUP = $BACKUP_MAX_TIME"
export BACKUP_MAX_TIME_IN_SECS=$(date +%s --date="$BACKUP_MAX_TIME")
echo "MAX TIME FOR BACKUP IN SECS = $BACKUP_MAX_TIME_IN_SECS"
echo "BACKUP_MAX_TIME = $BACKUP_MAX_TIME"
echo "Backup Re-run end time is"$BACKUP_MAX_TIME
echo ""
#Set job parameters from controlfile
echo "Reading the job parameters from the controlfile ..."
echo "DEBUG - Setting lookup string to "$BACKTYPE
echo "----------------------------------------------------------------------------------------------------"
export BACKUPNAME=`cat $FILE | grep -w $BACKTYPE | cut -d, -f1`
echo 'BACKUPNAME='$BACKUPNAME
export VERSION=`cat $FILE | grep -w $BACKTYPE | cut -d, -f2`
echo 'VERSION='$VERSION
export LCMEXP=`cat $FILE | grep -w $BACKTYPE | cut -d, -f3`
echo 'LCMEXP='$LCMEXP
export LCMTEMP=`cat $FILE | grep -w $BACKTYPE | cut -d, -f4`
echo 'LCMTEMP='$LCMTEMP
export TEMPLATEDIR=`cat $FILE | grep -w $BACKTYPE | cut -d, -f5`
echo 'TEMPLATEDIR='$TEMPLATEDIR
export ESSBACK=`cat $FILE | grep -w $BACKTYPE | cut -d, -f6`
echo 'ESSBACK='$ESSBACK
export APPCLU=`cat $FILE | grep -w $BACKTYPE | cut -d, -f7`
echo 'APPCLU='$APPCLU
export APPBKTYPE=`cat $FILE | grep -w $BACKTYPE | cut -d, -f8`
echo 'APPBKTYPE='$APPBKTYPE
export APP=`cat $FILE | grep -w $BACKTYPE | cut -d, -f9`
echo 'APP='$APP
export DB=`cat $FILE | grep -w $BACKTYPE | cut -d, -f10`
echo 'DB='$DB
# ASO or BSO
export ASO_BSO=`cat $FILE | grep -w $BACKTYPE | cut -d, -f11`
echo 'ASO_BSO= '$ASO_BSO
# ENV_FILE1 sets environment
export JOB_ENV_FILE1=`cat $FILE | grep -w $BACKTYPE | cut -d, -f12`
echo 'JOB ENV FILE1 = '$JOB_ENV_FILE1
# ENV_FILE2 sets environment
export JOB_ENV_FILE2=`cat $FILE | grep -w $BACKTYPE | cut -d, -f13`
echo 'JOB ENV FILE2 = '$JOB_ENV_FILE2
export ISCLUSTER=`cat $FILE | grep -w $BACKTYPE | cut -d, -f14`
echo 'ISCLUSTER = '$ISCLUSTER
export TOSTAGE=`cat $FILE | grep -w $BACKTYPE | cut -d, -f15`
echo 'TO_STAGE='$TOSTAGE
export PX=`cat $FILE | grep -w $BACKTYPE | cut -d, -f16`
echo 'Parallelism ='$PX
export RESTRUCT=`cat $FILE | grep -w $BACKTYPE | cut -d, -f17`
echo 'RESTRUCT='$RESTRUCT
export DRBAK=`cat $FILE | grep -w $BACKTYPE | cut -d, -f18`
echo 'Is this a DR Backup (Will say DR if so)='$DRBAK
export APPINFO=`cat $FILE | grep -w $BACKTYPE | cut -d, -f19`
echo 'APPINFO is the lookup name to get all the application information it is ='$APPINFO
echo ""
echo "Setting log and host information ..."
echo "----------------------------------------------------------------------------------------------------"
export HOST=`hostname`
echo "HOST is "$HOST
export DATESTAMP=`date +%Y-%m-%d_%H_%M`
echo "DATESTAMP= "$DATESTAMP
export MASTERLOGNAME=$BACKUPNAME"_"$DATESTAMP.log
echo "Master LOGNAME is "$MASTERLOGNAME
export MASTERERLOGNAME=$BACKUPNAME"_"$DATESTAMP.err
echo "Mater ERRLOGNAME = "$MASTERERLOGNAME
export DIRNAME=$DATESTAMP"_"$BACKUPNAME
echo "DIRNAME = "$DIRNAME
echo "----------------------------------------------------------------------------------------------------"

if [ -z $APPINFO ]; then 
   echo "Application Information will not be generated for this backup type"
else
   #Set application information from controlfile
   # VERY IMPORTANT IF YOU ADD MORE DATABASE VARIABLES PREFIX THEN WITH DB and then increase the sequence number (DB1 ...10)
   # That is how the Consol backups id databases
   echo ""
   echo "Reading the application information from the controlfile ..."
   echo "----------------------------------------------------------------------------------------------------"
   export APP_ID=`cat $FILE | grep -w ^$APPINFO | cut -d, -f1`
   echo 'APP_ID = '$APP_ID
   export APPLICATION=`cat $FILE | grep -w ^$APPINFO | cut -d, -f2`
   echo 'APPLICATION = '$APPLICATION
   export DB1=`cat $FILE | grep -w ^$APPINFO | cut -d, -f3`
   echo 'DB1 = '$DB1
   export TYPE_DB1=`cat $FILE | grep -w ^$APPINFO | cut -d, -f4`
   echo $DB1 ' Database type (TYPE_DB1) is = '$TYPE_DB1
   echo "-----"
   
   export DB2=`cat $FILE | grep -w ^$APPINFO | cut -d, -f5`
   if [[ ! -z $DB2 ]]; then
      echo 'DB2 = '$DB2
      export TYPE_DB2=`cat $FILE | grep -w ^$APPINFO | cut -d, -f6`
      echo $DB2 ' Database type (TYPE_DB1) is '$TYPE_DB2
      echo "-----"
   else
      echo "-----"
   fi
   
   export DB3=`cat $FILE | grep -w ^$APPINFO | cut -d, -f7`
   if [[ ! -z $DB3 ]]; then
      echo 'DB3 = '$DB3
      export TYPE_DB3=`cat $FILE | grep -w ^$APPINFO | cut -d, -f8`
   echo $DB3 ' Database type (TYPE_DB1) is '$TYPE_DB3
      echo "-----"
   else
      echo "-----"
   fi
   
   export DB4=`cat $FILE | grep -w ^$APPINFO | cut -d, -f9`
   if [[ ! -z $DB4 ]]; then
      echo 'DB4 = '$DB4
      export TYPE_DB4=`cat $FILE | grep -w ^$APPINFO | cut -d, -f10`
   echo  $DB4 ' Database type (TYPE_DB1) is '$TYPE_DB4
      echo "-----"
   else
      echo "-----"
   fi
   
   export DB5=`cat $FILE | grep -w ^$APPINFO | cut -d, -f11`
   if [[ ! -z $DB5 ]]; then
      echo 'DB5 = '$DB5
      export TYPE_DB5=`cat $FILE | grep -w ^$APPINFO | cut -d, -f12`
      echo $DB5 ' Database type (TYPE_DB1) is '$TYPE_DB5
      echo "-----"
   else
      echo "-----"
   fi
   
   export DB6=`cat $FILE | grep -w ^$APPINFO | cut -d, -f13`
   if [[ ! -z $DB6 ]]; then
      echo 'DB6 = '$DB6
      export TYPE_DB6=`cat $FILE | grep -w ^$APPINFO | cut -d, -f14`
      echo $DB6 ' Database type (TYPE_DB1) is '$TYPE_DB6
      echo "-----"
   else
      echo "-----"
   fi
   
   export DB7=`cat $FILE | grep -w ^$APPINFO | cut -d, -f15`
   if [[ ! -z $DB7 ]]; then
      echo 'DB7 = '$DB7
      export TYPE_DB7=`cat $FILE | grep -w ^$APPINFO | cut -d, -f16`
      echo $DB7 ' Database type (TYPE_DB1) is '$TYPE_DB7
      echo "-----"
   else
      echo "-----"
   fi
   
   export DB8=`cat $FILE | grep -w ^$APPINFO | cut -d, -f17`
   if [[ ! -z $DB8 ]]; then
      echo 'DB8 = '$DB8
      export TYPE_DB8=`cat $FILE | grep -w ^$APPINFO | cut -d, -f18`
      echo $DB8 ' Database type (TYPE_DB1) is '$TYPE_DB8
      echo "-----"
   else
      echo "-----"
   fi
   
   export DB9=`cat $FILE | grep -w ^$APPINFO | cut -d, -f19`
   if [[ ! -z $DB9 ]]; then
      echo 'DB9 = '$DB9
      export TYPE_DB9=`cat $FILE | grep -w ^$APPINFO | cut -d, -f20`
      echo $DB9 ' Database type (TYPE_DB1) is '$TYPE_DB9
      echo "-----"
   else
      echo "-----"
   fi
   
   export DB10=`cat $FILE | grep -w ^$APPINFO | cut -d, -f21`
   if [[ ! -z $DB10 ]]; then
      echo 'DB10 = '$DB10
      export TYPE_DB10=`cat $FILE | grep -w ^$APPINFO | cut -d, -f22`
      echo $DB10 ' Database type (TYPE_DB1) is '$TYPE_DB10
      echo "-----"
   else
      echo "-----"
   fi
   
   export PLANNING=`cat $FILE | grep -w ^$APPINFO | cut -d, -f23`
   echo 'Is this a Planning App (will say Planning) = '$PLANNING
   export PRIMCLU=`cat $FILE | grep -w ^$APPINFO | cut -d, -f24`
   echo 'Primary Cluster ='$PRIMCLU
   export APPVERSION=`cat $FILE | grep -w ^$APPINFO | cut -d, -f25`
   echo 'Application EPM Version ='$APPVERSION
   echo "----------------------------------------------------------------------------------------------------"
fi

echo "Running server config files"

if [ ! -z "$JOB_ENV_FILE1" -a "$JOB_ENV_FILE1" != " " ]; then
   echo 'Setting job environment file 1 ..'
   . $JOB_ENV_FILE1
else
   echo "Not setting a job level environment set server environment"
 . $ENVFILE1
fi
 
if [ ! -z "$JOB_ENV_FILE2" -a "$JOB_ENV_FILE2" != " " ]; then
   echo 'Setting job environment file 2 ..'
   . $JOB_ENV_FILE2
else
   echo "Not setting a job level 2 environment set server environment"
  . $ENVFILE2
fi
#. $ENVFILE2
}

function CheckSpace()
{
echo "----------------------------------------------------------------------------------------------------"
echo "Verifying there is enough space in all the directories that need written to ..."
df -h $ROOTBACKDIR
echo "Checking Root Backup Directory "
export ROOTBACKSPACEAVAIL=`df -h $ROOTBACKDIR | grep -w $ROOTBACKDIR | awk '{print $1;}'`
export ROOTBACKSPACEPERCUSED=`df -h $ROOTBACKDIR | grep -w $ROOTBACKDIR | awk '{print $4;}'`
echo "Space Available on "$ROOTBACKDIR " = "$ROOTBACKSPACEAVAIL
echo "Percent Space Used on "$ROOTBACKDIR " = "$ROOTBACKSPACEPERCUSED
echo ""
# Need to strip the % symbol off to do a comarison
export ROOTBACKSPACEPERCUSEDNOSYMBOL=${ROOTBACKSPACEPERCUSED%?}
#export ROOTBACKSPACEPERCUSEDNOSYMBOL=100
if [ "$ROOTBACKSPACEPERCUSEDNOSYMBOL" -eq "100" ]; then
   echo "The filesystem is full stopping backup, please add more space or remove some files !!!!"
   ErrorExit "essbase_master.sh failed The filesystem is full stopping backup, please add more space or remove some files !!!!, Error on line: $LINENO"
else
   echo "Space usage is under 100% continuing backup"   
fi
}

function ErrorExit ()
{
# I put a variable in my scripts named BACKUPNAME which
# holds the name of the backup being run. 
#	----------------------------------------------------------------
#	Function for exit due to fatal program error
#		Accepts 1 argument:
#			1. string containing descriptive error message if there is no error message it substitutes Unknown Error
#	----------------------------------------------------------------


#	echo "${BACKUPNAME}: ${1:-"Unknown Error"}" 1>&2
	export MAILBODY="${1:-"Unknown Error"}"
    export MAILSUBJECT="<CRITICAL> ${PROGNAME} running ${BACKUPNAME} failed"
    export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
	MailMessage
	exit 2

# Example call of the error_exit function.  Note the inclusion
# of the LINENO environment variable.  It contains the current
# line number.

echo "Example of error with line number and message"
ErrorExit "$LINENO: An error has occurred."
}

function EssbaseStatus()
{
LOGNAME=$BACKUPNAME"_EssbaseStatusOPMNStatus.out"
echo "Validating OPMN Status..."
   cd $EPM_ORACLE_INSTANCE/bin
./opmnctl status > $CLUOUTPUTLOC/$LOGNAME.$DATESTAMP
OUT=$?
cat $CLUOUTPUTLOC/$LOGNAME.$DATESTAMP
export VALIDATESTOP=`cat $CLUOUTPUTLOC/$LOGNAME.$DATESTAMP`
if [[ "$VALIDATESTOP" = "opmnctl status: opmn is not running." ]]; then
	echo "OPMN is not running."
	export OPMNSTATUS=NORUN
else
   echo "Checking OPMNUP Var"
   echo `awk 'NR==6' $CLUOUTPUTLOC/$LOGNAME.$DATESTAMP | cut -d\| -f4 | cut -c2-`
   echo ""
   export OPMNUP=`awk 'NR==6' $CLUOUTPUTLOC/$LOGNAME.$DATESTAMP | cut -d\| -f4 | cut -c2-`
   if [[ $OPMNUP = 'Down    ' ]]; then
	echo "OPMN is down."
	export OPMNSTATUS=DOWN
   fi
   if [[ $OPMNUP = 'Alive   ' ]]; then
	echo "OPMN is Alive."   
	export OPMNSTATUS=UP
   fi
fi
echo "Verifying there are no running server processes ..."
echo "----------------------------------------------------"
   ps -ef | grep ESSSVR | grep Mid | grep -v grep
   echo "-------------------------------------------------"
   echo ""

}

#NR - Added function to check essbase service status - 12/25/2018
function Ess_serv_status ()
{
echo "Checking if essbase services are running by logging in using maxl script"
$ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/ess_serv_test.mxl $PK
export OUT=$?
if [[ $OUT == 0 ]];
then
        echo "Login successful. Essbase service is running. Proceeding with the backup"
else
        echo "Login unsuccessful. Essbase service is not running. Exiting script"
        export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
        export MAILSUBJECT="<CRITICAL-Rerun Manually> Essabase service is down:Export failed for "$APP""
        export MAILBODY="Backup for "$APP" failed as essbase service is down. Please start essbase services and rerun the export manually using $SCRIPTSDIR/${PROGNAME} $ENV_NAME $BACKUPNAME"
        MailMessage
        exit 1;
fi
}

function id_cluster()
{
if [[ $OPMNUP = 'Alive   ' || $OPMNUP = 'Down    ' ]]; then
	echo "Cluster configuration can be read because OPMN is running "
   echo ""
   echo "Identifying the cluster and where we are running from ..."
   echo "----------------------------------------------------------------------------------------------------"
   export CLUNAME=`awk 'NR==6' $CLUOUTPUTLOC/$LOGNAME.$DATESTAMP | cut -d' ' -f1`
   echo "Cluster Name is "$CLUNAME
   export PRIMARY_ESSBASE_SERVER=`cat $FILE | grep -w ^$CLUNAME | cut -d, -f2`
   echo 'PRIMARY ESSBASE SERVER = '$PRIMARY_ESSBASE_SERVER
   export PRIMARY_ESSBASE_ENV_FILE=`cat $FILE | grep -w ^$CLUNAME | cut -d, -f3`
   echo 'PRIMARY ESSBASE ENV FILE = '$PRIMARY_ESSBASE_ENV_FILE
   export SECONDARY_CLUNAME=`cat $FILE | grep -w ^$CLUNAME | cut -d, -f4`
   echo 'SECONDARY ESSBASE CLUSTER = '$SECONDARY_CLUNAME
   export SECONDARY_ESSBASE_SERVER=`cat $FILE | grep -w ^$CLUNAME | cut -d, -f5`
   echo 'SECONDARY ESSBASE SERVER = '$SECONDARY_ESSBASE_SERVER
   export SECONDARY_ESSBASE_ENV_FILE=`cat $FILE | grep -w ^$CLUNAME | cut -d, -f6`
   echo 'SECONDARY ESSBASE ENV FILE = '$SECONDARY_ESSBASE_ENV_FILE
elif [[ $OPMNSTATUS = 'NORUN' ]]; then
   echo "Cannot identify Cluster Name because OPMN is not running ..."
else 
   echo "Fix my code we should not be here "
fi
}
function getEssbaseSession()
{
export DATESTAMP=`date +%Y-%m-%d_%H_%M`
echo "Checking to see if there is anything running by hypuser (such as a batch job) "
echo "Keep in mind for DEV and QA You need to look at where the jobs are running from because the both run on the same servers"
echo "----------------------------------------------------------------------------------------------------"
ps -ef | grep hypuser
echo "----------------------------------------------------------------------------------------------------"
export GETSESSLOGNAME=$BACKUPNAME"_"$SERVER"_"getEssbaseSession.$DATESTAMP.log
export GETSESSERRLOGNAME=$BACKUPNAME"_"$SERVER"_"getEssbaseSession.$DATESTAMP.err
export SESSOUTFILE=$BACKUPNAME"_"$SERVER"_"EssbaseSessionList.$DATESTAMP.lst
echo "In getEssbaseSession"
cd $ARBORPATH/bin
$ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/essbase_getsessions112.maxl $PK
#cat $ROOTLOGDIR/$LOGNAME >> $ROOTLOGDIR/$EMAILLOG
}

function sessionRunning()
{
SESSRUN=`cat $ROOTLOGDIR/$SESSOUTFILE | grep -c in_progress`
echo "There are "$SESSRUN" ACTIVE sessions running at this time ..."
echo ""
echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<    Session Listing   >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
grep in_progress $ROOTLOGDIR/$SESSOUTFILE
}

function beginArchive_Rerun
{
echo "Re-running beginarcive command for $APP.$DB"
export B_RERUN="Begin Archive for $APP.$DB was re-run successfully which failed with the error"
export MAILBODY_OLD=`cat $ROOTLOGDIR/$BEGERRLOGNAME`
export MAILBODY=`echo -e "$B_RERUN ....... $MAILBODY_OLD"`
export MAILSUBJECT="<CLEAR> essbase_master.sh beginArchive re-run success for "$APP"."$DB""
export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
export DATE=`date +%Y-%m-%d`
export EXP_RERUN_FILE=$ROOTLOGDIR/Export_Rerun_Status_"$HOSTNAME"_"$DATE".txt
export SESSION=`cat $ROOTLOGDIR/$SESSOUTFILE | grep -e "in_progress" -e "unknown" | grep $APP | grep $DB`
export B_RERUN_STATUS=1
while [[ $B_RERUN_STATUS == 1 ]]
do

#CL15373-Modify hard coded timestamp to number of minutes
# CURR_TIME=$(date +%H%M)
# if [[ $((10#$CURR_TIME)) -lt  $((10#$BKP_TIME)) ]];

CURRENT_TIME=`date +%Y-%m-%d\ %H:%M:%S`
CURRENT_TIME_IN_SECS=$(date +%s --date="$CURRENT_TIME")

echo "CURRENT TIME=$CURRENT_TIME"
echo "CURRENT TIME IN SECS=$CURRENT_TIME_IN_SECS"
echo "if [ ${CURRENT_TIME_IN_SECS} -le ${BACKUP_MAX_TIME_IN_SECS} ];then"

if [ ${CURRENT_TIME_IN_SECS} -le ${BACKUP_MAX_TIME_IN_SECS} ];then
	sleep 10

	getEssbaseSession
	if cat $ROOTLOGDIR/$SESSOUTFILE | grep -e "in_progress" -e "unknown" | grep $APP | grep $DB;
		then
		echo "There are sessions running. Going to sleep for 3 minutes"
		sleep 180
	else
		echo "Calling beginArchive function"
		beginArchive $APP $DB
		echo "$APP.$DB | beginArchive | Success | `echo $SESSION | awk '{print $1,"performing",$7," ";}' | xargs -d'\n'`" >> $EXP_RERUN_FILE
		export B_RERUN_STATUS=0
		MailMessage
	fi
else
	export MAILBODY_OLD=`cat $ROOTLOGDIR/$BEGERRLOGNAME`
	export B_RERUN="beginArchive re-run failed as backup timeline exceeded : Export of $APP.$DB is not performed "
	export MAILBODY=`echo -e "$B_RERUN......$BKPRERUN_JOB"`
	export MAILSUBJECT="<CRITICAL-Rerun Manually> essbase_master.sh Backup re-run failed:Time exceeded for "$APP"."$DB""
	export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`	
	echo "Backup re-run failed as backup timeline exceeded, please re-run the backup manually : $BKPRERUN_JOB"
	MailMessage
	echo "$APP.$DB | beginArchive,export | Failed | `cat $ROOTLOGDIR/$SESSOUTFILE | grep -e "in_progress" -e "unknown" | grep $APP | grep $DB | awk '{print $1,"performing",$7," ";}' | xargs -d'\n'`" >> $EXP_RERUN_FILE
	echo "$APP.$DB | `cat $ROOTLOGDIR/$SESSOUTFILE | grep -e  "in_progress" -e "unknown" | grep $APP | grep $DB | awk '{print $1,"performing",$7," ";}' | xargs -d'\n'`" >> $EXP_FAIL_FILE
	#echo "---------------------------------------------" >> $EXP_FAIL_FILE
	exit 1
fi
done
}
function beginArchive()
{
#export APPBKSTEP=beginArchive
#echo APPBKSTEP=$APPBKSTEP
if [[ $APPBKTYPE = 'CONSOL' ]]; then
echo APPBKSTEP=$APPBKSTEP
export APPBKSTEP=beginArchive
   echo "First parameter passed to function beginArchive is Application = "$1
   echo "Second parameter passed to function beginArchive is Database = "$2
   export APP=$1
   export DB=$2
else
   echo "Not a consolidated backup, no need to swap variables per application"
fi
export ARCLOGNAME=$BACKUPNAME"_"$DB"_"$SERVER"_"beginArchive.$DATESTAMP.log
export BEGERRLOGNAME=$BACKUPNAME"_"$DB"_"$SERVER"_"beginArchive.$DATESTAMP.err
echo "Calling strpt"
strpt
cd $ARBORPATH/bin
$ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/archive_database.mxl $PK
#cat $ROOTLOGDIR/$LOGNAME >> $ROOTLOGDIR/$EMAILLOG
strpt_update
echo "The command to re-run the job"
echo "===================================================="
export BKPRERUN_JOB="Please re-run the job using $SCRIPTSDIR/${PROGNAME} $ENV_NAME $BACKUPNAME"
echo $BKPRERUN_JOB
echo "===================================================="
if [ -s $ROOTLOGDIR/$BEGERRLOGNAME ]; then
   echo "-------------------------------------------------------------------------------------------------"
   echo "beginarchive for $APPLICATION_$DB failed with the following error "
   cat $ROOTLOGDIR/$BEGERRLOGNAME
   export MAILBODY_OLD=`cat $ROOTLOGDIR/$BEGERRLOGNAME`
   export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
   export MAILSUBJECT="<CRITICAL-Re-running> essbase_master.sh failed to beginArchive "$APP"."$DB" with the following error"
   export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
   echo "Sending exp error mail message 1"
   if cat $ROOTLOGDIR/$BEGERRLOGNAME | grep "1056025"
	then
		echo "Already in archive mode.Continuing the script"
	elif cat $ROOTLOGDIR/$BEGERRLOGNAME | grep "1013204"
	then
		echo "Exiting the script. Begin archive re-run cannot be performed for this kind of error"
		export MAILSUBJECT="<CRITICAL-SKIP> essbase_master.sh failed to beginArchive "$APP"."$DB" with the following error"
		echo "$APP.$DB | beginArchive | Skipped | `echo $MAILBODY_OLD | tr -d '\n'`" >> $EXP_RERUN_FILE
		MailMessage
	elif cat $ROOTLOGDIR/$BEGERRLOGNAME | grep -e "1056024" -e "1051032" -e "1051030"
	then
		echo "Exiting the script. $APP.$DB doesn't exist"
		export MAILSUBJECT="<CRITICAL-Rerun Manually> essbase_master.sh failed to beginArchive "$APP"."$DB" with the following error"
		echo "$APP.$DB | beginArchive,export | Failed | `echo $MAILBODY_OLD | tr -d '\n'`" >> $EXP_RERUN_FILE
		echo "$APP.$DB | `echo $MAILBODY_OLD | tr -d '\n'`" >> $EXP_FAIL_FILE
		MailMessage
		exit 1
	else
		MailMessage
		beginArchive_Rerun
	fi
   echo "-------------------------------------------------------------------------------------------------"
fi
}

function endArchive()
{
#export APPBKSTEP=endArchive
#echo APPBKSTEP=$APPBKSTEP
if [[ $APPBKTYPE = 'CONSOL' ]]; then
export APPBKSTEP=endArchive
echo APPBKSTEP=$APPBKSTEP
   echo "First parameter passed to function endArchive is Application = "$1
   echo "Second parameter passed to function endArchive is Database = "$2
   export APP=$1
   export DB=$2
else
   echo "Not a consolidated backup, no need to swap variables per application"
fi
export ENDRCLOGNAME=$BACKUPNAME"_"$SERVER"_"endArchive.$DATESTAMP.log
#export ENDARCERRLOGNAME=$BACKUPNAME"_"$SERVER"_"endArchive.$DATESTAMP.err
export ENDERRLOGNAME=$BACKUPNAME"_"$SERVER"_"endArchive.$DATESTAMP.err
echo "In endArchive"
echo "CALLING "$MAXLDIR/end_archive_database.mxl
echo "Log directory = "$LOGDIR
echo "Log name = "$ENDRCLOGNAME
echo "Error log Name = "$ENDERRLOGNAME
cd $ARBORPATH/bin
$ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/end_archive_database.mxl $PK
#cat $ROOTLOGDIR/$LOGNAME >> $ROOTLOGDIR/$EMAILLOG
strpt_update
echo "The command to re-run the job"
echo "===================================================="
export BKPRERUN_JOB="End Archive has failed.Please run the end archive command using EAS - alter database '$APPLICATION'.'$DB' end archive;"
echo $BKPRERUN_JOB
echo "===================================================="
if [ -s $ROOTLOGDIR/$ENDERRLOGNAME ]; then
   echo "-------------------------------------------------------------------------------------------------"
   echo "endarchive for $APPLICATION_$DB failed with the following error "
   cat $ROOTLOGDIR/$ENDERRLOGNAME
   export MAILBODY_OLD=`cat $ROOTLOGDIR/$ENDERRLOGNAME`
   export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
   export MAILSUBJECT="<CRITICAL> essbase_master.sh failed to endArchive "$APP" with the following error"
   export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
   echo "Sending exp error mail message 1"
   MailMessage
   echo "-------------------------------------------------------------------------------------------------"
fi
}

function enableConnect ()
{
export APPBKSTEP=enableConnect
echo APPBKSTEP=$APPBKSTEP
export ENBLCONLOG=enableConnect_$APPLICATION_$DB.log
export ENBLCONERRLOGNAME=enableConnect_$APPLICATION_$DB.err
if [ -z "$CONSOLLOGDIR" ]; then
   export LOGDIR=$ROOTLOGDIR
else  
   export LOGDIR=$CONSOLLOGDIR
fi
echo "In enableConnect"
echo "CALLING "$MAXLDIR/enable_app_connects.mxl
echo "Log directory = "$LOGDIR
echo "Log name = "$ENBLCONLOG
echo "Error log Name = "$ENBLCONERRLOGNAME
echo "The command to re-run the job"
echo "===================================================="
echo "$SCRIPTSDIR/${PROGNAME} $ENV_NAME $BKPRERUN_NAME"
export BKPRERUN_JOB="Please re-run the enable connects command using EAS - alter application $APP enable commands and alter application $APP enable connects"
echo $BKPRERUN_JOB
echo "===================================================="
cd $ARBORPATH/bin
$ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/enable_app_connects.mxl $PK
if [ -s $LOGDIR/$ENBLCONERRLOGNAME ]; then
   echo "-------------------------------------------------------------------------------------------------"
   echo "enableConnect for $APPLICATION failed with the following error "
   cat $LOGDIR/$ENBLCONERRLOGNAME
   export MAILBODY_OLD=`cat $LOGDIR/$ENBLCONERRLOGNAME`
   export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
   export MAILSUBJECT="<CRITICAL> essbase_master.sh failed enableConnect for "$APP" failed with the following error"
   export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
   echo "Sending exp error mail message 1"
   MailMessage
   echo "-------------------------------------------------------------------------------------------------"
else
   cat $LOGDIR/$ENBLCONLOG
fi

#cat $ROOTLOGDIR/$LOGNAME >> $ROOTLOGDIR/$EMAILLOG
}
function stopEssbaseNONCLU()
{
strpt
export LOGNAME=$SERVER"_"nightlyBack.stop.$DATESTAMP.log
export ERRLOGNAME=$SERVER"_"nightlyBack.stop.$DATESTAMP.err
if [[ "$ESSBASESTATUS" = down ]]; then
   echo "Essbase is not running, no need to stop it"
else
   if [[ "$VERSION" = 11.1.1 ]]; then
      echo "The status of Essbase is "$ESSBASESTATUS
      echo "The following Essbase processes are running"
      ps -ef | grep ESS |grep -v "grep ESSBASE" | grep -v pingport | grep -v Mid
      echo
      echo "Shutting down essbase Server "$SERVER
      cd $HYPERION_HOME/products/Essbase/EssbaseServer/bin
      $HYPERION_HOME/products/Essbase/EssbaseServer/bin/startMaxl.sh -D /hyp_util/maxl/shutdown_essbase.mxl $PK
OUT=$?
   echo "Return Code = "$OUT
      if [ $OUT -eq 0 ];then
         echo "Shutdown was successful!"
      elif [ $OUT -eq 141 ];then
         echo "Shutdown was successful!"
      else
         echo "Shutdown failed "
         exit $OUT
      fi
   elif [[ "$VERSION" = 11.1.2 || "$VERSION" = 11.1.2.3 || "$VERSION" = 11.1.2.4 ]]; then
      echo "The following Essbase processes are running"
      ps -ef | grep ESS |grep -v "grep ESSBASE" | grep Mid | grep -v java
      echo
      echo "Shutting down essbase Server "$SERVER
   cd $EPM_ORACLE_INSTANCE/bin
./opmnctl stopall
OUT=$?
   echo "Return Code = "$OUT
      if [ $OUT -eq 0 ];then
         echo "Shutdown was successful!"
      elif [ $OUT -eq 141 ];then
         echo "Shutdown was successful!"
      else
         echo "Shutdown failed "
		 ErrorExit "Shutdown failed, Error on line: $LINENO"
      fi
   else
      echo "Version is incorrect Please use  (11.1.1 | 11.1.2)"
	  ErrorExit "Version is incorrect Please use  (11.1.1 | 11.1.2), Error on line: $LINENO"
   fi
fi
}

function stopEssbase()
{
# Here is where things get interesting
# We need to stop both secondary nodes for both essbase clusters first 
# One will be locally where this script is run and the other will be called via a remote script
# First thing we do is understand what kind of backup we are running
# if it is a full backup then we need to shut down both clusters
# If not then we only need to shut down 1
#Step 1 - Determine the Backup 
#if [[ $BACKUPNAME = 'ESS_FULL_FS' ]]; then 
strpt
   echo "The Full backup for all clusters is configured ..."
   echo ""
   echo "Stopping secondary essbase server on "$CLUSTER1
   echo "--------------------------------------------------------------------------------------------------------"
   if [[ $HOST = $CLUSTER1_SECONDARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the passive essbase server running locally ..."
	  echo "Running environment file "$CLUSTER1_SECONDARY_ESSBASE_ENV_FILE
	  . $CLUSTER1_SECONDARY_ESSBASE_ENV_FILE
	  echo "Running environment file "$CLUSTER1_SECONDARY_ESSBASE_ENV_FILE2
	  . $CLUSTER1_SECONDARY_ESSBASE_ENV_FILE2
	  cd $EPM_ORACLE_INSTANCE/bin
	  echo "Running ./opmnctl stopall"
	  ./opmnctl stopall
	  EssbaseStatus
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	     echo "OPMN is validated as down."   
	     export CLU1_2ESSSERV_OPMN=DOWN
	  else
	     echo "OPMN is validated "$OPMNSTATUS
		 echo "Shutdown failed exiting program . "
		 ErrorExit "essbase_master.sh failed Stopping secondary essbase server on $CLUSTER1 OPMN is validated "$OPMNSTATUS" Shutdown failed exiting program, Error on line: $LINENO"
	  fi
   else
      echo "This host is NOT home of the passive essbase server need to run via ssh ..."
	  echo "ssh oracle@"$CLUSTER1_SECONDARY_ESSBASE_SERVER $SCRIPTSDIR"/stop_essbase_cluster1.sh "$CLUSTER1" "$CLUSTER1_SECONDARY_ESSBASE_ENV_FILE $CLUSTER1_SECONDARY_ESSBASE_ENV_FILE2
	  ssh oracle@$CLUSTER1_SECONDARY_ESSBASE_SERVER $SCRIPTSDIR/stop_essbase_cluster1.sh $CLUSTER1 $CLUSTER1_SECONDARY_ESSBASE_ENV_FILE $CLUSTER1_SECONDARY_ESSBASE_ENV_FILE2
	  echo ""
	  export VALDATEESSLOG=$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_SECONDARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  echo "Checking log from remote OPMN operation on "$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_SECONDARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  ls $CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_SECONDARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  validateRemoteEssbase
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	     echo "OPMN is validated as down."   
	     export CLU1_2ESSSERV_OPMN=DOWN
	  else
	     echo "OPMN is validated "$OPMNSTATUS
		 echo "Shutdown failed exiting program . "
		 ErrorExit "essbase_master.sh failed Stopping secondary essbase server on $CLUSTER1 OPMN is validated "$OPMNSTATUS" Shutdown failed exiting program, Error on line: $LINENO"
		 exit 2
	  fi
   fi
        echo ""
     echo "Stopping secondary essbase server on "$CLUSTER2
	 echo "--------------------------------------------------------------------------------------------------------"
   if [[ $HOST = $CLUSTER2_SECONDARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the passive essbase server running locally ..."
	  echo "Running environment file "$CLUSTER2_SECONDARY_ESSBASE_ENV_FILE
	  . $CLUSTER2_SECONDARY_ESSBASE_ENV_FILE
	  echo "Running environment file "$CLUSTER2_SECONDARY_ESSBASE_ENV_FILE2
	  . $CLUSTER2_SECONDARY_ESSBASE_ENV_FILE2
	  cd $EPM_ORACLE_INSTANCE/bin
	  echo "Running ./opmnctl stopall"
	  ./opmnctl stopall
	  EssbaseStatus
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	     echo "OPMN is validated as down."   
	     export CLU1_2ESSSERV_OPMN=DOWN
	  else
	     echo "OPMN is validated "$OPMNSTATUS
		 echo "Shutdown failed exiting program . "
		 ErrorExit "essbase_master.sh failed Stopping secondary essbase server on $CLUSTER2 OPMN is validated "$OPMNSTATUS" Shutdown failed exiting program, Error on line: $LINENO"
	  fi
   else
      echo "This host is NOT home of the passive essbase server need to run via ssh ..."
	  echo "ssh oracle@"$CLUSTER2_SECONDARY_ESSBASE_SERVER $SCRIPTSDIR"/stop_essbase_cluster1.sh "$CLUSTER2" "$CLUSTER2_SECONDARY_ESSBASE_ENV_FILE $CLUSTER2_SECONDARY_ESSBASE_ENV_FILE2
	  ssh oracle@$CLUSTER2_SECONDARY_ESSBASE_SERVER $SCRIPTSDIR/stop_essbase_cluster1.sh $CLUSTER2 $CLUSTER2_SECONDARY_ESSBASE_ENV_FILE $CLUSTER2_SECONDARY_ESSBASE_ENV_FILE2
	  echo ""
	  export VALDATEESSLOG=$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_SECONDARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  echo "Checking log from remote OPMN operation on "$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_SECONDARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  ls $CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_SECONDARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  validateRemoteEssbase
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	     echo "OPMN is validated as down."   
	     export CLU2_2ESSSERV_OPMN=DOWN
	  else
	     echo "OPMN is validated "$OPMNSTATUS
		 echo "Shutdown failed exiting program . "
		 ErrorExit "essbase_master.sh failed Stopping secondary essbase server on $CLUSTER2 OPMN is validated "$OPMNSTATUS" Shutdown failed exiting program, Error on line: $LINENO"
	  fi
   fi
      echo ""
      echo "Stopping primary essbase server on "$CLUSTER1
	  echo "--------------------------------------------------------------------------------------------------------"
   if [[ $HOST = $CLUSTER1_PRIMARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the passive essbase server running locally ..."
	  echo "Running environment file "$CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
	  . $CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
	  echo "Running environment file "$CLUSTER1_PRIMARY_ESSBASE_ENV_FILE2
	  . $CLUSTER1_PRIMARY_ESSBASE_ENV_FILE2
	  getEssbaseSession
	  sessionRunning
	  cd $EPM_ORACLE_INSTANCE/bin
	  echo "Running ./opmnctl stopall"
	  ./opmnctl stopall
	  EssbaseStatus
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	     echo "OPMN is validated as down."   
	     export CLU1_2ESSSERV_OPMN=DOWN
	  else
	     echo "OPMN is validated "$OPMNSTATUS
		 echo "Shutdown failed exiting program . "
		 ErrorExit "essbase_master.sh failed Stopping primary essbase server on $CLUSTER1 OPMN is validated "$OPMNSTATUS" Shutdown failed exiting program, Error on line: $LINENO"
	  fi
   else
      echo "This host is NOT home of the active essbase server need to run via ssh ..."
	  echo "ssh oracle@"$CLUSTER1_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR"/stop_essbase_cluster1.sh "$CLUSTER1" "$CLUSTER1_PRIMARY_ESSBASE_ENV_FILE $CLUSTER1_PRIMARY_ESSBASE_ENV_FILE2
	  ssh oracle@$CLUSTER1_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR/stop_essbase_cluster1.sh $CLUSTER1 $CLUSTER1_PRIMARY_ESSBASE_ENV_FILE $CLUSTER1_PRIMARY_ESSBASE_ENV_FILE2
	  echo ""
	  export VALDATEESSLOG=$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_PRIMARY_ESSBASE_SERVER"_"$CLUSTER1".log"
      echo "Checking log from remote OPMN operation on "$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_PRIMARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  ls $CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_PRIMARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  validateRemoteEssbase
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	     echo "OPMN is validated as down."   
	     export CLU1_1ESSSERV_OPMN=DOWN
	  else
	     echo "OPMN is validated "$OPMNSTATUS
		 echo "Shutdown failed exiting program . "
		 ErrorExit "essbase_master.sh failed Stopping primary essbase server on $CLUSTER1 OPMN is validated "$OPMNSTATUS" Shutdown failed exiting program, Error on line: $LINENO"
	  fi
   fi
      echo ""
      echo "Stopping primary essbase server on "$CLUSTER2
	  echo "--------------------------------------------------------------------------------------------------------"
   if [[ $HOST = $CLUSTER2_PRIMARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the active essbase server running locally ..."
	  echo "Running environment file "$CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
	  . $CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
	  echo "Running environment file "$CLUSTER2_PRIMARY_ESSBASE_ENV_FILE2
	  . $CLUSTER2_PRIMARY_ESSBASE_ENV_FILE2
	  getEssbaseSession
	  sessionRunning
	  cd $EPM_ORACLE_INSTANCE/bin
	  echo "Running ./opmnctl stopall"
	  ./opmnctl stopall
	  EssbaseStatus
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	     echo "OPMN is validated as down."   
	     export CLU1_2ESSSERV_OPMN=DOWN
	  else
	     echo "OPMN is validated "$OPMNSTATUS
		 echo "Shutdown failed exiting program . "
		 ErrorExit "essbase_master.sh failed Stopping primary essbase server on $CLUSTER2 OPMN is validated "$OPMNSTATUS" Shutdown failed exiting program, Error on line: $LINENO"
	  fi
   else
      echo "This host is NOT home of the active essbase server need to run via ssh ..."
	  echo "ssh oracle@"$CLUSTER2_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR"/stop_essbase_cluster1.sh "$CLUSTER2" "$CLUSTER2_PRIMARY_ESSBASE_ENV_FILE $CLUSTER2_PRIMARY_ESSBASE_ENV_FILE2
	  ssh oracle@$CLUSTER2_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR/stop_essbase_cluster1.sh $CLUSTER2 $CLUSTER2_PRIMARY_ESSBASE_ENV_FILE $CLUSTER2_PRIMARY_ESSBASE_ENV_FILE2
	  echo ""
	  export VALDATEESSLOG=$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_PRIMARY_ESSBASE_SERVER"_"$CLUSTER2".log"
      echo "Checking log from remote OPMN operation on "$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_PRIMARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  ls $CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_PRIMARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  validateRemoteEssbase
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	     echo "OPMN is validated as down."   
	     export CLU2_1ESSSERV_OPMN=DOWN
	  else
	     echo "OPMN is validated "$OPMNSTATUS
		 echo "Shutdown failed exiting program . "
		 ErrorExit "essbase_master.sh failed Stopping primary essbase server on $CLUSTER2 OPMN is validated "$OPMNSTATUS" Shutdown failed exiting program, Error on line: $LINENO"
	  fi
   fi
#fi
}

function validateRemoteEssbase()
{
echo ""
echo "Validating the status of Essbase on the remote server "
echo "--------------------------------------------------------------------------------------------------------"
echo "OPMN output is "
cat $VALDATEESSLOG
export VALIDATESTOP=`cat $VALDATEESSLOG`
if [[ "$VALIDATESTOP" = "opmnctl status: opmn is not running." ]]; then
	echo "OPMN is not running."
	export OPMNSTATUS=NORUN
else	
   echo `awk 'NR==6' $VALDATEESSLOG | cut -d\| -f4 | cut -c2-`
   echo ""
   export OPMNUP=`awk 'NR==6' $VALDATEESSLOG | cut -d\| -f4 | cut -c2-`
   if [[ $OPMNUP = 'Down    ' ]]; then
       echo "OPMN is down."
	   export OPMNSTATUS=DOWN
   fi
   if [[ $OPMNUP = 'Alive   ' ]]; then
	  echo "OPMN is Alive."   
	  export OPMNSTATUS=UP
   fi
fi
}

function killESSSVRAll()
{
   echo "ESSSVR processes running after shutdown ..."
   ps -ef | grep ESSSVR | grep Mid | grep -v grep
   echo "----------------------------------------------------------------------------------------------"
   echo ""
   echo "Killing leftover ESSSVR processes ..."
   PID=`ps -ef | grep ESSSVR | grep Mid | grep -v grep | awk '{print $2}'`
   if [[ $PID -ne "" ]]; then
      sleep 90
      echo "Killing processes "$PID
      kill $PID
   else
      echo "no process to kill ..."
   fi
   echo "ESSSVR processes still running ..."
   ps -ef | grep ESSSVR | grep Mid | grep -v grep
}

function killESSSVRApp()
{
   echo "Checking to see if the Application server process is running for application "$APP
   ps -ef | grep ESSSVR | grep Mid | grep -v grep | grep $APP | grep $OSUSER
   echo "----------------------------------------------------------------------------------------------"
   echo ""
   echo "Killing leftover ESSSVR processes ..."
   PID=`ps -ef | grep ESSSVR | grep Mid | grep -v grep | grep $APP | grep $OSUSER | awk '{print $2}'`
   if [[ $PID -ne "" ]]; then
      sleep 90
      echo "Killing processes "$PID
#      kill $PID
   else
      echo "no process to kill ..."
   fi
   echo "ESSSVR processes still running ..."
   ps -ef | grep ESSSVR | grep Mid | grep -v grep | grep $APP | grep $OSUSER
}
# This function will start the essbase server from a full cluster shutdown
# It needs to do the following
# 1. Start and validate the start for the OPMN process on active server on cluster 1
# 2. Start and validate the start for the OPMN process on active server on cluster 2
# 3. Start and validate the start for the OPMN process on passive server on cluster 1
# 4. Start and validate the start for the OPMN process on passive server on cluster 2
# 5. Start and validate the start for the OPMN based Essbase Agent on active server on cluster 1
# 6. Start and validate the start for the OPMN based Essbase Agent on active server on cluster 2

function startEssbase ()
{
echo "Starting Essbase Server "
echo "----------------------------------------------------------------------------------------------------"
# 1. Start and validate the start for the OPMN process on active server on cluster 1
      echo "Starting primary essbase server on "$CLUSTER1
	  echo "--------------------------------------------------------------------------------------------------------"
   if [[ $HOST = $CLUSTER1_PRIMARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the active essbase server running locally ..."
	  echo "Running environment file "$CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
	  . $CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
	  cd $EPM_ORACLE_INSTANCE/bin
	  echo "Running ./opmnctl startall"
	  ./opmnctl startall
	  EssbaseStatus
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting primary essbase server on $CLUSTER1 OPMN is validated "$OPMNSTATUS" Startup failed exiting program, Error on line: $LINENO"
	  else
	     echo "OPMN is validated "$OPMNSTATUS
	  fi
   else
      echo "This host is NOT home of the active essbase server need to run via ssh ..."
	  echo "ssh oracle@"$CLUSTER1_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR"/start_essbase_cluster1.sh "$CLUSTER1" "$CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
	  ssh oracle@$CLUSTER1_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR/start_essbase_cluster1.sh $CLUSTER1 $CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
	  echo ""
	  export VALDATEESSLOG=$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_PRIMARY_ESSBASE_SERVER"_"$CLUSTER1".log"
      echo "Checking log from remote OPMN operation on "$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_PRIMARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  ls $CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_PRIMARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  validateRemoteEssbase
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting primary essbase server on $CLUSTER1 OPMN is validated "$OPMNSTATUS" Startup failed exiting program, Error on line: $LINENO"
	  else
	     echo "OPMN is validated "$OPMNSTATUS
	  fi
   fi
# 2. Start and validate the start for the OPMN process on active server on cluster 2
      echo "Starting primary essbase server on "$CLUSTER2
	  echo "--------------------------------------------------------------------------------------------------------"
   if [[ $HOST = $CLUSTER2_PRIMARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the active essbase server running locally ..."
	  echo "Running environment file "$CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
	  . $CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
	  cd $EPM_ORACLE_INSTANCE/bin
	  echo "Running ./opmnctl startall"
	  ./opmnctl startall
	  EssbaseStatus
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting primary essbase server on $CLUSTER2 OPMN is validated "$OPMNSTATUS" Startup failed exiting program, Error on line: $LINENO"
	  else
	     echo "OPMN is validated "$OPMNSTATUS
	  fi
   else
      echo "This host is NOT home of the active essbase server need to run via ssh ..."
	  echo "ssh oracle@"$CLUSTER2_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR"/start_essbase_cluster1.sh "$CLUSTER2" "$CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
	  ssh oracle@$CLUSTER2_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR/start_essbase_cluster1.sh $CLUSTER2 $CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
	  echo ""
	  export VALDATEESSLOG=$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_PRIMARY_ESSBASE_SERVER"_"$CLUSTER2".log"
      echo "Checking log from remote OPMN operation on "$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_PRIMARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  ls $CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_PRIMARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  validateRemoteEssbase
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting primary essbase server on $CLUSTER2 OPMN is validated "$OPMNSTATUS" Startup failed exiting program, Error on line: $LINENO"
	  else
	     echo "OPMN is validated "$OPMNSTATUS
	  fi
   fi
# 3. Start and validate the start for the OPMN process on passive server on cluster 1
   echo "Starting secondary essbase server on "$CLUSTER1
   echo "--------------------------------------------------------------------------------------------------------"
   if [[ $HOST = $CLUSTER1_SECONDARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the passive essbase server running locally ..."
	  echo "Running environment file "$CLUSTER1_SECONDARY_ESSBASE_ENV_FILE
	  . $CLUSTER1_SECONDARY_ESSBASE_ENV_FILE
	  cd $EPM_ORACLE_INSTANCE/bin
	  echo "Running ./opmnctl startall"
	  ./opmnctl startall
	  EssbaseStatus
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting secondary essbase server on $CLUSTER1 OPMN is validated "$OPMNSTATUS" Startup failed exiting program, Error on line: $LINENO"
      else
	     echo "OPMN is validated "$OPMNSTATUS
	  fi
   else
      echo "This host is NOT home of the passive essbase server need to run via ssh ..."
	  echo "ssh oracle@"$CLUSTER1_SECONDARY_ESSBASE_SERVER $SCRIPTSDIR"/start_essbase_cluster1.sh "$CLUSTER1" "$CLUSTER1_SECONDARY_ESSBASE_ENV_FILE
	  ssh oracle@$CLUSTER1_SECONDARY_ESSBASE_SERVER $SCRIPTSDIR/start_essbase_cluster1.sh $CLUSTER1 $CLUSTER1_SECONDARY_ESSBASE_ENV_FILE
	  echo ""
	  export VALDATEESSLOG=$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_SECONDARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  echo "Checking log from remote OPMN operation on "$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_SECONDARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  ls $CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_SECONDARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  validateRemoteEssbase
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting secondary essbase server on $CLUSTER1 OPMN is validated "$OPMNSTATUS" Startup failed exiting program, Error on line: $LINENO"
	  else
	     echo "OPMN is validated "$OPMNSTATUS
	  fi
   fi
# 4. Start and validate the start for the OPMN process on passive server on cluster 2
   echo "Starting secondary essbase server on "$CLUSTER2
   echo "--------------------------------------------------------------------------------------------------------"
   if [[ $HOST = $CLUSTER2_SECONDARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the passive essbase server running locally ..."
	  echo "Running environment file "$CLUSTER2_SECONDARY_ESSBASE_ENV_FILE
	  . $CLUSTER2_SECONDARY_ESSBASE_ENV_FILE
	  cd $EPM_ORACLE_INSTANCE/bin
	  echo "Running ./opmnctl startall"
	  ./opmnctl startall
	  EssbaseStatus
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting secondary essbase server on $CLUSTER2 OPMN is validated "$OPMNSTATUS" Startup failed exiting program, Error on line: $LINENO"
	  else
	     echo "OPMN is validated "$OPMNSTATUS
	  fi
   else
      echo "This host is NOT home of the passive essbase server need to run via ssh ..."
	  echo "ssh oracle@"$CLUSTER2_SECONDARY_ESSBASE_SERVER $SCRIPTSDIR"/start_essbase_cluster1.sh "$CLUSTER2" "$CLUSTER2_SECONDARY_ESSBASE_ENV_FILE
	  ssh oracle@$CLUSTER2_SECONDARY_ESSBASE_SERVER $SCRIPTSDIR/start_essbase_cluster1.sh $CLUSTER2 $CLUSTER2_SECONDARY_ESSBASE_ENV_FILE
	  echo ""
	  export VALDATEESSLOG=$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_SECONDARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  echo "Checking log from remote OPMN operation on "$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_SECONDARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  ls $CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_SECONDARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  validateRemoteEssbase
	  if [[ $OPMNSTATUS = 'NORUN' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting secondary essbase server on $CLUSTER2 OPMN is validated "$OPMNSTATUS" Startup failed exiting program, Error on line: $LINENO"
	  else
	     echo "OPMN is validated "$OPMNSTATUS
	  fi
   fi
# 5. Start and validate the start for the OPMN based Essbase Agent on active server on cluster 1
      echo "Starting essbase agent on "$CLUSTER1
	  echo "--------------------------------------------------------------------------------------------------------"
   if [[ $HOST = $CLUSTER1_PRIMARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the active essbase server running locally ..."
	  echo "Running environment file "$CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
	  . $CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
	  cd $EPM_ORACLE_INSTANCE/bin
	  echo "Running ./opmnctl startproc ias-component="$CLUSTER1
	  ./opmnctl startproc ias-component=$CLUSTER1
	  EssbaseStatus
      if [[ $OPMNUP = 'NORUN' || $OPMNUP = 'Down    ' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup Agent process failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting secondary essbase agent on $CLUSTER1 OPMN is validated "$OPMNSTATUS" Startup failed for essbase agent exiting program, Error on line: $LINENO"
	  else
	     echo "Essbase Agent startup is validated "$OPMNSTATUS
	  fi
   else
      echo "This host is NOT home of the active essbase server need to run via ssh ..."
	  echo "ssh oracle@"$CLUSTER1_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR"/start_essbase_agent.sh "$CLUSTER1" "$CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
	  ssh oracle@$CLUSTER1_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR/start_essbase_agent.sh $CLUSTER1 $CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
	  echo ""
	  export VALDATEESSLOG=$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_PRIMARY_ESSBASE_SERVER"_"$CLUSTER1".log"
      echo "Checking log from remote OPMN operation on "$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_PRIMARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  ls $CLUOUTPUTLOC/"OPMN.status_"$CLUSTER1_PRIMARY_ESSBASE_SERVER"_"$CLUSTER1".log"
	  validateRemoteEssbase
	  if [[ $OPMNUP = 'NORUN' || $OPMNUP = 'Down    ' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting secondary essbase agent on $CLUSTER1 OPMN is validated "$OPMNSTATUS" Startup failed for essbase agent exiting program, Error on line: $LINENO"
	  else
	     echo "OPMN is validated "$OPMNSTATUS
	  fi
   fi
# 6. Start and validate the start for the OPMN based Essbase Agent on active server on cluster 2
   echo "Starting essbase agent on "$CLUSTER2
   echo "--------------------------------------------------------------------------------------------------------"
   if [[ $HOST = $CLUSTER2_PRIMARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the passive essbase server running locally ..."
	  echo "Running environment file "$CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
	  . $CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
	  cd $EPM_ORACLE_INSTANCE/bin
	  echo "Running ./opmnctl startproc ias-component="$CLUSTER2
	  ./opmnctl startproc ias-component=$CLUSTER2
	  EssbaseStatus
      if [[ $OPMNUP = 'NORUN' || $OPMNUP = 'Down    ' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup Agent process failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting secondary essbase agent on $CLUSTER2 OPMN is validated "$OPMNSTATUS" Startup failed for essbase agent exiting program, Error on line: $LINENO"
	  else
	     echo "Essbase Agent startup is validated "$OPMNSTATUS
	  fi
   else
      echo "This host is NOT home of the passive essbase server need to run via ssh ..."
	  echo "ssh oracle@"$CLUSTER2_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR"/start_essbase_agent.sh "$CLUSTER2" "$CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
	  ssh oracle@$CLUSTER2_PRIMARY_ESSBASE_SERVER $SCRIPTSDIR/start_essbase_agent.sh $CLUSTER2 $CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
	  echo ""
	  export VALDATEESSLOG=$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_PRIMARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  echo "Checking log from remote OPMN operation on "$CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_PRIMARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  ls $CLUOUTPUTLOC/"OPMN.status_"$CLUSTER2_PRIMARY_ESSBASE_SERVER"_"$CLUSTER2".log"
	  validateRemoteEssbase
      if [[ $OPMNUP = 'NORUN' || $OPMNUP = 'Down    ' ]]; then
	  	 echo "OPMN is validated "$OPMNSTATUS
		 echo "Startup Agent process failed exiting program . "
		 ErrorExit "essbase_master.sh failed Starting secondary essbase agent on $CLUSTER2 OPMN is validated "$OPMNSTATUS" Startup failed for essbase agent exiting program, Error on line: $LINENO"
	  else
	     echo "Essbase Agent startup is validated "$OPMNSTATUS
	  fi
  fi
echo ""
echo "----------------------------------------------------------------------------------------------------"
strpt_update
}

function StartEssbaseNONCLU()
{
export LOGNAME=$SERVER"_"nightlyBack.start.$DATESTAMP.log
export ERRLOGNAME=$SERVER"_"nightlyBack.start..$DATESTAMP.err
if [[ "$VERSION" = 11.1.1 ]]; then
   echo "Starting $SERVER"
   cd $HYPERION_HOME/products/bin/
./start.sh &
OUT=$?
   echo "Return Code = "$OUT
   if [ $OUT -eq 0 ];then
      echo "Startup was successful!"
   else
      
      echo "Startup failed "
      exit $OUT
   fi
   echo "Started "
   cd $HYPERION_HOME/products/Essbase/EssbaseServer/bin
$HYPERION_HOME/products/Essbase/EssbaseServer/bin/startMaxl.sh -D /hyp_util/maxl/startup_apps.mxl $PK
OUT=$?
   echo "Return Code = "$OUT
   if [ $OUT -eq 0 ];then
      echo "Startup APPS was successful!"
   else
      ErrorExit "Startup APPS failed, on line number "$LINENO
      echo "Startup APPS failed "
   exit $OUT
   fi
#fi
elif [[ "$VERSION" = 11.1.2 || "$VERSION" = 11.1.2.3 || "$VERSION" = 11.1.2.4 ]]; then
   echo "Starting $SERVER"
cd $EPM_ORACLE_INSTANCE/bin
./opmnctl startall
OUT=$?
   echo "Return Code = "$OUT
   if [ $OUT -eq 0 ];then
      echo "Startup was successful!"
   else
      echo "Startup failed "
	  ErrorExit "essbase_master.sh failed Starting Essbase Server exiting program, Error on line: $LINENO"
   fi
else
   echo "Version is incorrect Please use  (11.1.1 | 11.1.2)"
   ErrorExit "essbase_master.sh Version is incorrect Please use  (11.1.1 | 11.1.2) exiting program, Error on line: $LINENO"
   exit 2
fi
strpt_update
}

function CopyEssbaseFull()
{
echo ""
echo "To restore please be sure to read the comments in this script to apply the offset values to lzop and tar"
echo "If not very bad things could happen"
echo "---------------------------------"
#  Added logic into to use lzop in a tar command to zip up the backup
#  I had to include the full path in the tar file because of inconsistencies.
#  When extracting it will include all the directories possibly causing the files to be nested incorrectly
#  VERY IMPORTANT ---------------------------------------------------------------------
#  When you go to restore a file you will want to 
#  1.  cd <to the directory above the resore location>
#  2.  use the following command 
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components <number of directories in front of the base directory
#  For Example
#  In DEV the $AROBORPATH directory is set to /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer/essbaseserver1
#  If you need to restore the backup you would 
#  cd /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components 8
#  This would extract only the essbaseserver1 directory and below, it would leave off the 8 preceding directories so that the paths would be ok
if [[ "$VERSION" = 11.1.1 ]]; then
   echo "Essbase is down proceeding to backup"
   echo "Creating directory for backup"
   mkdir $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   ls -ltr $BACKUPDIR
   echo "Copying and zipping HYPERION HOME to $BACKUPDIR/$SERVER"_backup_"$DATESTAMP"
    tar --use-compress-program=lzop -cvf $BACKUPDIR/$SERVER"_backup_"$DATESTAMP".tar.lzop" $HYPERION_HOME
#   cp -rp $HYPERION_HOME $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   echo "Comparing to verify backup is complete ..."
#   diff -r  $BACKUPDIR/$SERVER"_backup_"$DATESTAMP $HYPERION_HOME/..
elif [[ "$VERSION" = 11.1.2 || "$VERSION" = 11.1.2.3 || "$VERSION" = 11.1.2.4 ]]; then
   echo "Essbase is down proceeding to backup"
   export BACKUPFILENAME="ARBORPATH."$DATESTAMP".tar.lzop"
   BACKUPDIR=$ROOTBACKDIR/$BACKCLU
#   ls -ltr $STAGEBACKDIR/$BACKUPFILENAME
   echo "Backup file name = "$BACKUPFILENAME
   if [[ $TOSTAGE = "STAGE" ]]; then
      echo "Backing up to a staging area "$STAGEBACKDIR " before the copy to "$BACKUPDIR
	  echo "Copying  and zipping Essbase Application with data and index files"$APP" to "$STAGEBACKDIR/$BACKUPFILENAME
      tar --use-compress-program=lzop -cvf $STAGEBACKDIR"/"$BACKUPFILENAME $ARBORPATH
	  OUT=$?
      echo "Return Code = "$OUT
      if [ $OUT -eq 0 ];then
         echo "Essbase Backup to stage was Successful!" 
	     echo "----------------------------------------------------------------------------------------------------"
	     echo ""
      else
         echo "Essbase Backup failed exiting script"
	     echo "----------------------------------------------------------------------------------------------------"
		 ErrorExit "essbase_master.sh Essbase file copy failed Copying and zipping Essbase Application with data and index files"$APP" to   $STAGEBACKDIR/$BACKUPFILENAME, Error on line: $LINENO"
      fi
	  echo "Completed tar and backup to staging area "
	  ls -ltr $STAGEBACKDIR
   elif [[ $TOSTAGE = "NOSTAGE" ]]; then
       echo "Copying Essbase ARBORPATH for "$BACKCLU" to "$BACKUPDIR
	   echo "Listing of all files in the backup directory "$BACKUPDIR
       ls -ltr $BACKUPDIR
#   echo "Copying and zipping MIDDLEWARE HOME to $BACKUPDIR/$SERVER"_backup_Middleware."$DATESTAMP".tar.lzop
#   tar --use-compress-program=lzop -cvf $BACKUPDIR/$SERVER"_backup_Middleware."$DATESTAMP".tar.lzop" $MIDDLEWARE_HOME
#   cp -rp $MIDDLEWARE_HOME $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
       echo "Copying  and zipping Essbase Applications to "$BACKUPDIR"/ARBORPATH."$DATESTAMP".tar.lzop"
       tar --use-compress-program=lzop -cvf $BACKUPDIR/$BACKUPFILENAME $ARBORPATH
     OUT=$?
      echo "Return Code = "$OUT
      if [ $OUT -eq 0 ];then
         echo "Essbase Backup was Successful!" 
	     echo "----------------------------------------------------------------------------------------------------"
	     echo ""
      else
         echo "Essbase Backup failed exiting script"
	     echo "----------------------------------------------------------------------------------------------------"
		 ErrorExit "essbase_master.sh Essbase file copy failed Copying  and zipping Essbase Applications to "$BACKUPDIR"/ARBORPATH."$DATESTAMP".tar.lzop, Error on line: $LINENO"
      fi
   else
      echo "Not sure where to back this up to "
	  ErrorExit "Error on line: $LINENO"
   fi
else
   echo "Version is incorrect Please use  (11.1.1 | 11.1.2)"
   ErrorExit "essbase_master.sh Version is incorrect Please use  (11.1.1 | 11.1.2) exiting program, Error on line: $LINENO"
   exit 2
fi
}

function setAllCLuInfo()
{
echo "Determined that this is a clustered Essbase instance, setting the clustering info now For cluster "$CLUSTER1
echo "----------------------------------------------------------------------------------------------------"
export $"CLUSTER1"_PRIMARY_ESSBASE_SERVER=`cat $FILE | grep -w ^$CLUSTER1 | cut -d, -f2`
echo 'PRIMARY ESSBASE SERVER = '$CLUSTER1_PRIMARY_ESSBASE_SERVER
export $"CLUSTER1"_PRIMARY_ESSBASE_ENV_FILE=`cat $FILE | grep -w ^$CLUSTER1 | cut -d, -f3`
echo 'PRIMARY ESSBASE ENV FILE = '$CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
export $"CLUSTER1"_PRIMARY_ESSBASE_ENV_FILE2=`cat $FILE | grep -w ^$CLUSTER1 | cut -d, -f4`
echo 'PRIMARY ESSBASE ENV FILE2 = '$CLUSTER1_PRIMARY_ESSBASE_ENV_FILE2
export $"CLUSTER1"_SECONDARY_CLUNAME=`cat $FILE | grep -w ^$CLUSTER1 | cut -d, -f5`
echo 'SECONDARY ESSBASE CLUSTER = '$CLUSTER1_SECONDARY_CLUNAME
export $"CLUSTER1"_SECONDARY_ESSBASE_SERVER=`cat $FILE | grep -w ^$CLUSTER1 | cut -d, -f6`
echo 'SECONDARY ESSBASE SERVER = '$CLUSTER1_SECONDARY_ESSBASE_SERVER
export $"CLUSTER1"_SECONDARY_ESSBASE_ENV_FILE=`cat $FILE | grep -w ^$CLUSTER1 | cut -d, -f7`
echo 'SECONDARY_ESSBASE_ENV_FILE = '$CLUSTER1_SECONDARY_ESSBASE_ENV_FILE
export $"CLUSTER1"_SECONDARY_ESSBASE_ENV_FILE2=`cat $FILE | grep -w ^$CLUSTER1 | cut -d, -f8`
echo 'SECONDARY_ESSBASE_ENV_FILE2 = '$CLUSTER1_SECONDARY_ESSBASE_ENV_FILE2

echo "For cluster "$CLUSTER2
export $"CLUSTER2"_PRIMARY_ESSBASE_SERVER=`cat $FILE | grep -w ^$CLUSTER2 | cut -d, -f2`
echo 'PRIMARY ESSBASE SERVER = '$CLUSTER2_PRIMARY_ESSBASE_SERVER
export $"CLUSTER2"_PRIMARY_ESSBASE_ENV_FILE=`cat $FILE | grep -w ^$CLUSTER2 | cut -d, -f3`
echo 'PRIMARY ESSBASE ENV FILE = '$CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
export $"CLUSTER2"_PRIMARY_ESSBASE_ENV_FILE2=`cat $FILE | grep -w ^$CLUSTER2 | cut -d, -f4`
echo 'PRIMARY ESSBASE ENV FILE2 = '$CLUSTER2_PRIMARY_ESSBASE_ENV_FILE2
export $"CLUSTER2"_SECONDARY_CLUNAME=`cat $FILE | grep -w ^$CLUSTER2 | cut -d, -f5`
echo 'SECONDARY ESSBASE CLUSTER = '$CLUSTER2_SECONDARY_CLUNAME
export $"CLUSTER2"_SECONDARY_ESSBASE_SERVER=`cat $FILE | grep -w ^$CLUSTER2 | cut -d, -f6`
echo 'SECONDARY ESSBASE SERVER = '$CLUSTER2_SECONDARY_ESSBASE_SERVER
export $"CLUSTER2"_SECONDARY_ESSBASE_ENV_FILE=`cat $FILE | grep -w ^$CLUSTER2 | cut -d, -f7`
echo 'SECONDARY_ESSBASE_ENV_FILE = '$CLUSTER2_SECONDARY_ESSBASE_ENV_FILE
export $"CLUSTER2"_SECONDARY_ESSBASE_ENV_FILE2=`cat $FILE | grep -w ^$CLUSTER2 | cut -d, -f8`
echo 'SECONDARY_ESSBASE_ENV_FILE2 = '$CLUSTER2_SECONDARY_ESSBASE_ENV_FILE2
echo ""
}

function stopApplication()
{
export LOGNAME=$BACKUPNAME"_"$HOST"_"stopApp.$DATESTAMP.log
export ERRLOGNAME=$BACKUPNAME"_"$HOST"_"stopApp.$DATESTAMP.err
# This function will stop an essbase application for backup it gets a variable passed to it that is the application name
strpt
echo ""
echo "Stopping Application "$APP"."$DB
echo "--------------------------------------------------------------------------------------------------------"
# Find out what cluster the application is running on this will be at a later date when we add more failover protection in
# Run a a shutdown command either locally or remotely (this will be at a later date when we add more failover protection in), 
# right now we will run the script on the node we know the app is running on and change the controlfile in the case of a failover
# In a future release I would like to make it agnostic

cd $ARBORPATH/bin
#$ARBORPATH/bin/startMaxl.sh -D $SCRIPTSDIR/maxl/stop_essbase_app.mxl $PK
$ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/stop_essbase_app_force.mxl $PK
if [ -s $ROOTLOGDIR/$ERRLOGNAME ]; then
#   grep 'ERROR - 1054004' $ROOTLOGDIR/$ERRLOGNAME
# Make sure that the error ERROR - 1054004 is not the cause of the abort"
   if $(grep -q 'ERROR - 1013204' $ROOTLOGDIR/$ERRLOGNAME); then 
      echo "The error is expected the app is down"
   elif $(grep -q 'ERROR - 1054004' $ROOTLOGDIR/$ERRLOGNAME); then
      echo "The error is expected the app is down"
# Check to see if the app is in a state where it cannot be shut down"
   elif $(grep -q 'ERROR - 1051544' $ROOTLOGDIR/$ERRLOGNAME); then
      echo "The application is returning an error "
	  export MAILBODY=`cat $ROOTLOGDIR/$ERRLOGNAME`
      export MAILSUBJECT="<WARNING> The application "$APP"."$DB" is returning an error shutting down sleeping for 90 seconds and trying again"
      export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
	  MailMessage
      cat $ROOTLOGDIR/$ERRLOGNAME
      echo "Lets sleep for 90 seconds and see if this clears ..."
      sleep 90
      $ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/stop_essbase_app_force.mxl $PK
      if $(grep -q 'ERROR - 1051544' $ROOTLOGDIR/$ERRLOGNAME); then
         echo "At this point in time i think we need to kill the server processs ..."
	     echo "Killing process "
		 export MAILBODY=`cat $ROOTLOGDIR/$ERRLOGNAME`
         export MAILSUBJECT="<CRITICAL> The application "$APP"."$DB" is returning an error shutting down killing the server process"
         export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
	     MailMessage
      else
         echo "Seems like it cleared, moving on."
      fi	  
   else
      echo "There is an error Please review this error and restart. " 
      cat $ROOTLOGDIR/$ERRLOGNAME
	  export MAILBODY=`cat $ROOTLOGDIR/$ERRLOGNAME`
      export MAILSUBJECT="<CRITICAL> The application "$APP"."$DB" is returning an error, Please review this error and restart. "
      export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
	  MailMessage
      exit 2
   fi
else
 echo "Shutdown was successful!"
fi
}

function StartApplication()
{
export LOGNAME=$BACKUPNAME"_"$HOST"_"startApp.$DATESTAMP.log
export ERRLOGNAME=$BACKUPNAME"_"$HOST"_"startApp.$DATESTAMP.err
# This function will start an essbase application for backup it gets a variable passed to it that is the application name
echo ""
echo "Starting Application "$APP"."$DB
echo "--------------------------------------------------------------------------------------------------------"
# Find out what cluster the application is running on this will be at a later date when we add more failover protection in
# Run a a startup command either locally or remotely (this will be at a later date when we add more failover protection in), 
# right now we will run the script on the node we know the app is running on and change the controlfile in the case of a failover
# In a future release I would like to make it agnostic

echo "Starting  $SERVER"
cd $ARBORPATH/bin
$ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/start_essbase_app.mxl $PK
if [ -s $ROOTLOGDIR/$ERRLOGNAME ]; then
   echo "There is an error Please review this error and restart. "
   cat $ROOTLOGDIR/$ERRLOGNAME
   export MAILBODY=`cat $ROOTLOGDIR/$ERRLOGNAME`
   export MAILSUBJECT="<CRITICAL> The application "$APP"."$DB" is returning an error starting"
   export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
   MailMessage
   exit 2
else 
   echo "Startup was successful!"
fi
strpt_update
}

function CopyEssbaseAppFull()
{
echo ""
echo "To restore please be sure to read the comments in this script to apply the offset values to lzop and tar"
echo "If not very bad things could happen"
echo "---------------------------------"
#  Added logic into to use lzop in a tar command to zip up the backup
#  I had to include the full path in the tar file because of inconsistencies.
#  When extracting it will include all the directories possibly causing the files to be nested incorrectly
#  VERY IMPORTANT ---------------------------------------------------------------------
#  When you go to restore a file you will want to 
#  1.  cd <to the directory above the resore location>
#  2.  use the following command 
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components <number of directories in front of the base directory
#  For Example
#  In DEV the $AROBORPATH directory is set to /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer/essbaseserver1
#  If you need to restore the backup you would 
#  cd /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components 8
#  This would extract only the essbaseserver1 directory and below, it would leave off the 8 preceding directories so that the paths would be ok
if [[ "$VERSION" = 11.1.1 ]]; then
   echo "Essbase is down proceeding to backup"
   echo "Creating directory for backup"
   mkdir $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   ls -ltr $BACKUPDIR
   echo "Copying and zipping HYPERION HOME to $BACKUPDIR/$SERVER"_backup_"$DATESTAMP"
    tar --use-compress-program=lzop -cvf $BACKUPDIR/$SERVER"_backup_"$DATESTAMP".tar.lzop" $HYPERION_HOME
#   cp -rp $HYPERION_HOME $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   echo "Comparing to verify backup is complete ..."
#   diff -r  $BACKUPDIR/$SERVER"_backup_"$DATESTAMP $HYPERION_HOME/..
elif [[ "$VERSION" = 11.1.2 || "$VERSION" = 11.1.2.3 || "$VERSION" = 11.1.2.4 ]]; then
   echo $APP" is down proceeding to backup"
   export BACKUPFILENAME='APP_FULL_'$APP'.'$DATESTAMP'.tar.lzop'
   BACKUPDIR=$ROOTBACKDIR/$APPCLU
   echo "Backup file name = "$BACKUPFILENAME
   if [[ $TOSTAGE = "STAGE" ]]; then
      echo "Backing up to a staging area "$STAGEBACKDIR " before the copy to "$BACKUPDIR
	  echo "Copying  and zipping Essbase Application with data and index files "$APP" to "$STAGEBACKDIR/$BACKUPFILENAME
      tar --use-compress-program=lzop -cvf $STAGEBACKDIR"/"$BACKUPFILENAME $ARBORPATH/app/$APP
	  OUT=$?
      echo "Return Code = "$OUT
      if [ $OUT -eq 0 ];then
         echo "Essbase Backup to stage was Successful!" 
	     echo "----------------------------------------------------------------------------------------------------"
	     echo ""
      else
         echo "Essbase Backup failed exiting script"
	     echo "----------------------------------------------------------------------------------------------------"
		 ErrorExit "essbase_master.sh Essbase file copy failed Copying and zipping Essbase Application with data and index files "$APP" to $STAGEBACKDIR/$BACKUPFILENAME, Error on line: $LINENO"
      fi
	  echo "Completed tar and backup to staging area "
	  ls -ltr $STAGEBACKDIR
   elif [[ $TOSTAGE = "NOSTAGE" ]]; then
      echo "Backup location is "$TOSTAGE
	  echo "Backup directory is "$BACKUPDIR
	  echo "Copying  and zipping Essbase Application with data and index files "$APP" to "$BACKUPDIR/$BACKUPFILENAME
      tar --use-compress-program=lzop -cvf $BACKUPDIR/$BACKUPFILENAME $ARBORPATH/app/$APP
OUT=$?
      echo "Return Code = "$OUT
      if [ $OUT -eq 0 ];then
         echo "Essbase Backup was Successful!" 
		 echo "Completed tar and backup "
		 ls -ltr $BACKUPDIR/$BACKUPFILENAME
	     echo "----------------------------------------------------------------------------------------------------"
	     echo ""
      else
         echo "Essbase Backup failed exiting script"
	     echo "----------------------------------------------------------------------------------------------------"
		 ErrorExit "essbase_master.sh Essbase file copy failed Copying  and zipping Essbase Application with data and index files "$APP" to $STAGEBACKDIR/$BACKUPFILENAME, Error on line: $LINENO"
      fi
   else
   echo "Not sure where to back this up to "
   ErrorExit "Error on line: $LINENO"
   fi
else
   echo "Version is incorrect Please use  (11.1.1 | 11.1.2)"
   ErrorExit "essbase_master.sh Version is incorrect Please use  (11.1.1 | 11.1.2) exiting program, Error on line: $LINENO"
fi
}

function CopyEssbaseDBFull()
{
echo ""
echo "To restore please be sure to read the comments in this script to apply the offset values to lzop and tar"
echo "If not very bad things could happen"
echo "---------------------------------"
#  Added logic into to use lzop in a tar command to zip up the backup
#  I had to include the full path in the tar file because of inconsistencies.
#  When extracting it will include all the directories possibly causing the files to be nested incorrectly
#  VERY IMPORTANT ---------------------------------------------------------------------
#  When you go to restore a file you will want to 
#  1.  cd <to the directory above the resore location>
#  2.  use the following command 
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components <number of directories in front of the base directory
#  For Example
#  In DEV the $AROBORPATH directory is set to /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer/essbaseserver1
#  If you need to restore the backup you would 
#  cd /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components 8
#  This would extract only the essbaseserver1 directory and below, it would leave off the 8 preceding directories so that the paths would be ok
if [[ "$VERSION" = 11.1.1 ]]; then
   echo "Essbase is down proceeding to backup"
   echo "Creating directory for backup"
   mkdir $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   ls -ltr $BACKUPDIR
   echo "Copying and zipping HYPERION HOME to $BACKUPDIR/$SERVER"_backup_"$DATESTAMP"
    tar --use-compress-program=lzop -cvf $BACKUPDIR/$SERVER"_backup_"$DATESTAMP".tar.lzop" $HYPERION_HOME
#   cp -rp $HYPERION_HOME $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   echo "Comparing to verify backup is complete ..."
#   diff -r  $BACKUPDIR/$SERVER"_backup_"$DATESTAMP $HYPERION_HOME/..
elif [[ "$VERSION" = 11.1.2 || "$VERSION" = 11.1.2.3 || "$VERSION" = 11.1.2.4 ]]; then
   echo $APP"."$DB" is down proceeding to backup"
   export BACKUPFILENAME='APP_DB_FULL_'$APP'.'$DB'.'$DATESTAMP'.tar.lzop'
   BACKUPDIR=$ROOTBACKDIR/$APPCLU
   echo "Backup file name = "$BACKUPFILENAME
   if [[ $TOSTAGE = "STAGE" ]]; then
      echo "Backing up to a staging area "$STAGEBACKDIR " before the copy to "$BACKUPDIR
	  echo "Copying  and zipping Essbase Application with data and index files "$APP"."$DB" to "$STAGEBACKDIR/$BACKUPFILENAME
      tar --use-compress-program=lzop -cvf $STAGEBACKDIR"/"$BACKUPFILENAME $ARBORPATH/app/$APP/$DB
	  OUT=$?
      echo "Return Code = "$OUT
      if [ $OUT -eq 0 ];then
         echo "Essbase Backup to stage was Successful!" 
	     echo "----------------------------------------------------------------------------------------------------"
	     echo ""
      else
         echo "Essbase Backup failed exiting script"
	     echo "----------------------------------------------------------------------------------------------------"
		 ErrorExit "essbase_master.sh Essbase file copy failed Copying and zipping Essbase Application with data and index files "$APP"."$DB" to $STAGEBACKDIR/$BACKUPFILENAME, Error on line: $LINENO"
      fi
	  echo "Completed tar and backup to staging area "
	  ls -ltr $STAGEBACKDIR
   elif [[ $TOSTAGE = "NOSTAGE" ]]; then
      echo "Backup location is "$TOSTAGE
	  echo "Backup directory is "$BACKUPDIR
	  echo "Copying  and zipping Essbase Application with data and index files "$APP"."$DB" to "$BACKUPDIR/$BACKUPFILENAME
      tar --use-compress-program=lzop -cvf $BACKUPDIR/$BACKUPFILENAME $ARBORPATH/app/$APP/$DB
OUT=$?
      echo "Return Code = "$OUT
      if [ $OUT -eq 0 ];then
         echo "Essbase Backup was Successful!" 
		 echo "Completed tar and backup "
		 ls -ltr $BACKUPDIR/$BACKUPFILENAME
	     echo "----------------------------------------------------------------------------------------------------"
	     echo ""
      else
         echo "Essbase Backup failed exiting script"
	     echo "----------------------------------------------------------------------------------------------------"
		 ErrorExit "essbase_master.sh Essbase file copy failed Copying and zipping Essbase Application with data and index files "$APP"."$DB" to $BACKUPDIR/$BACKUPFILENAME, Error on line: $LINENO"
	  fi
   else
   echo "Not sure where to back this up to "
   ErrorExit "Error on line: $LINENO"
   fi
else
   echo "Version is incorrect Please use  (11.1.1 | 11.1.2)"
   ErrorExit "essbase_master.sh Version is incorrect Please use  (11.1.1 | 11.1.2) exiting program, Error on line: $LINENO"
fi
}

function CopyEssbaseAppNoData()
{
echo ""
echo "To restore please be sure to read the comments in this script to apply the offset values to lzop and tar"
echo "If not very bad things could happen"
echo "---------------------------------"
#  Added logic into to use lzop in a tar command to zip up the backup
#  I had to include the full path in the tar file because of inconsistencies.
#  When extracting it will include all the directories possibly causing the files to be nested incorrectly
#  VERY IMPORTANT ---------------------------------------------------------------------
#  When you go to restore a file you will want to 
#  1.  cd <to the directory above the resore location>
#  2.  use the following command 
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components <number of directories in front of the base directory
#  For Example
#  In DEV the $AROBORPATH directory is set to /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer/essbaseserver1
#  If you need to restore the backup you would 
#  cd /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components 8
#  This would extract only the essbaseserver1 directory and below, it would leave off the 8 preceding directories so that the paths would be ok
#
# Also for the backup location I am using APPCLU from the controlfile, this will need to be changed if the application fails over, this will 
# Be revised in the next version
# FOR RIGHT NOW UPDATE THE CONTROLFILE FOR THE APP CLUSTER LOCATION IN THE JOB SECTION IF FAIL OVER OCCURS
#
if [[ "$VERSION" = 11.1.1 ]]; then
   echo "Essbase is down proceeding to backup"
   echo "Creating directory for backup"
   mkdir $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   ls -ltr $BACKUPDIR
   echo "Copying and zipping HYPERION HOME to $BACKUPDIR/$SERVER"_backup_"$DATESTAMP"
    tar --use-compress-program=lzop -cvf $BACKUPDIR/$SERVER"_backup_"$DATESTAMP".tar.lzop" $HYPERION_HOME
#   cp -rp $HYPERION_HOME $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   echo "Comparing to verify backup is complete ..."
#   diff -r  $BACKUPDIR/$SERVER"_backup_"$DATESTAMP $HYPERION_HOME/..
elif [[ "$VERSION" = 11.1.2 || "$VERSION" = 11.1.2.3 || "$VERSION" = 11.1.2.4 ]]; then
   echo "Essbase is down proceeding to backup"
#THIS WILL FAIL IF CLUSTER FAILS OVER APPCLU will need updated in the controlfile
   BACKUPDIR=$ROOTBACKDIR/$APPCLU
   echo "Copying Essbase Files other than data files for "$APP
   ls -ltr $BACKUPDIR
#   echo "Copying and zipping MIDDLEWARE HOME to $BACKUPDIR/$SERVER"_backup_Middleware."$DATESTAMP".tar.lzop
#   tar --use-compress-program=lzop -cvf $BACKUPDIR/$SERVER"_backup_Middleware."$DATESTAMP".tar.lzop" $MIDDLEWARE_HOME
#   cp -rp $MIDDLEWARE_HOME $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   export BACKUPFILENAME="APP_NODATA_"$APP"."$DATESTAMP".tar.lzop"
   echo "Copying  and zipping Essbase Application NO data and index files "$APP" to "$BACKUPDIR/$BACKUPFILENAME
#   tar --use-compress-program=lzop -cvf $BACKUPDIR/"APP_FULL"$APP"."$DATESTAMP".tar.lzop" $ARBORPATH/app/$APP
   tar --use-compress-program=lzop -cvf $BACKUPDIR/$BACKUPFILENAME `find $ARBORPATH/app/$APP | grep '.otl\|.csc\|.rul\|.rep\|.eqd\|.sel\|ADM.*txt'`
#   cp -rp $ARBORPATH $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
OUT=$?
   echo "Return Code = "$OUT
   if [ $OUT -eq 0 ];then
      echo "Essbase Backup was Successful!" 
	  echo "Completed tar and backup "
	  ls -ltr $BACKUPDIR/$BACKUPFILENAME
	  echo "----------------------------------------------------------------------------------------------------"
	  echo ""
   else
      echo "Essbase Backup failed exiting script"
	  echo "----------------------------------------------------------------------------------------------------"
	  ErrorExit "Essbase file copy failed Copying  and zipping Essbase Application NO data and index files "$APP" to "$BACKUPDIR/$BACKUPFILENAME", Error on line: $LINENO"
   fi
else
   echo "Version is incorrect Please use  (11.1.1 | 11.1.2)"
   ErrorExit "essbase_master.sh Version is incorrect Please use  (11.1.1 | 11.1.2) exiting program, Error on line: $LINENO"
fi
}

function CopyEssbaseDBNoData()
{
echo ""
echo "To restore please be sure to read the comments in this script to apply the offset values to lzop and tar"
echo "If not very bad things could happen"
echo "---------------------------------"
#  Added logic into to use lzop in a tar command to zip up the backup
#  I had to include the full path in the tar file because of inconsistencies.
#  When extracting it will include all the directories possibly causing the files to be nested incorrectly
#  VERY IMPORTANT ---------------------------------------------------------------------
#  When you go to restore a file you will want to 
#  1.  cd <to the directory above the resore location>
#  2.  use the following command 
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components <number of directories in front of the base directory
#  For Example
#  In DEV the $AROBORPATH directory is set to /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer/essbaseserver1
#  If you need to restore the backup you would 
#  cd /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components 8
#  This would extract only the essbaseserver1 directory and below, it would leave off the 8 preceding directories so that the paths would be ok
#
# Also for the backup location I am using APPCLU from the controlfile, this will need to be changed if the application fails over, this will 
# Be revised in the next version
# FOR RIGHT NOW UPDATE THE CONTROLFILE FOR THE APP CLUSTER LOCATION IN THE JOB SECTION IF FAIL OVER OCCURS
#
if [[ "$VERSION" = 11.1.1 ]]; then
   echo "Essbase is down proceeding to backup"
   echo "Creating directory for backup"
   mkdir $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   ls -ltr $BACKUPDIR
   echo "Copying and zipping HYPERION HOME to $BACKUPDIR/$SERVER"_backup_"$DATESTAMP"
    tar --use-compress-program=lzop -cvf $BACKUPDIR/$SERVER"_backup_"$DATESTAMP".tar.lzop" $HYPERION_HOME
#   cp -rp $HYPERION_HOME $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   echo "Comparing to verify backup is complete ..."
#   diff -r  $BACKUPDIR/$SERVER"_backup_"$DATESTAMP $HYPERION_HOME/..
elif [[ "$VERSION" = 11.1.2 || "$VERSION" = 11.1.2.3 || "$VERSION" = 11.1.2.4 ]]; then
   echo "Essbase is down proceeding to backup"
# New parameters put in for CONSOL backup
if [[ $APPBKTYPE = 'CONSOL' ]]; then
   export APPBKSTEP=CopyEssbaseDBNoData
   echo "APPBKSTEP= "$APPBKSTEP
   echo "First parameter passed to function CopyEssbaseDBNoData is Application = "$1
   echo "Second parameter passed to function CopyEssbaseDBNoData is Database = "$2
   export APP=$1
   export DB=$2
          if [[ -z $DRBAK ]]; then
          ##export BKPRERUN_NAME=$BKPENV_NAME$DRBAK'_EXP0_'$APP'_'$DB
	  export BKPRERUN_NAME=$BKPENV_NAME$DRBAK'_ESS_APP_BACKUP_NODATA_'$APP
          echo "The non-dr backup name is:"$BKPRERUN_NAME
          else
          ##export BKPRERUN_NAME=$BKPENV_NAME'_'$DRBAK'_EXP0_'$APP'_'$DB
 	  export BKPRERUN_NAME=$BKPENV_NAME$DRBAK'_ESS_APP_BACKUP_NODATA_'$APP
          echo "The DR backup name is:"$BKPRERUN_NAME
          fi 
else
   echo "Not a consolidated backup, no need to swap varaibles per application"
fi

#THIS WILL FAIL IF CLUSTER FAILS OVER APPCLU will need updated in the controlfile
   BACKUPDIR=$ROOTBACKDIR/$APPCLU
   echo "Copying Essbase Files other than data files for "$APP"."$DB
#   ls -ltr $BACKUPDIR
#   echo "Copying and zipping MIDDLEWARE HOME to $BACKUPDIR/$SERVER"_backup_Middleware."$DATESTAMP".tar.lzop
#   tar --use-compress-program=lzop -cvf $BACKUPDIR/$SERVER"_backup_Middleware."$DATESTAMP".tar.lzop" $MIDDLEWARE_HOME
#   cp -rp $MIDDLEWARE_HOME $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   export BACKUPFILENAME="APP_DB_NODATA_"$APP"."$DB"."$DATESTAMP".tar.lzop"
   echo "Copying  and zipping Essbase Application NO data and index files "$APP"."$DB" to "$BACKUPDIR/$BACKUPFILENAME
#   tar --use-compress-program=lzop -cvf $BACKUPDIR/"APP_FULL"$APP"."$DATESTAMP".tar.lzop" $ARBORPATH/app/$APP
   tar --use-compress-program=lzop -cvf $BACKUPDIR/$BACKUPFILENAME `find $ARBORPATH/app/$APP/$DB | grep '.otl\|.csc\|.rul\|.rep\|.eqd\|.sel\|ADM.*txt'`
#   cp -rp $ARBORPATH $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
OUT=$?
   echo "Return Code = "$OUT
   if [ $OUT -eq 0 ];then
      echo "Essbase Backup was Successful!" 
	  echo "Completed tar and backup for "$APP"."$DB
	  ls -ltr $BACKUPDIR/$BACKUPFILENAME
	  echo "----------------------------------------------------------------------------------------------------"
	  echo ""
   else
      echo "Essbase Backup failed exiting script"
	  echo "----------------------------------------------------------------------------------------------------"
	  ErrorExit "essbase_master.sh Essbase file copy failed Copying  and zipping Essbase Application NO data and index files "$APP" to "$BACKUPDIR/$BACKUPFILENAME", Error on line: $LINENO"
	fi  
else
   echo "Version is incorrect Please use  (11.1.1 | 11.1.2)"
   ErrorExit "essbase_master.sh Version is incorrect Please use  (11.1.1 | 11.1.2) exiting program, Error on line: $LINENO"
fi
}

function CopyEssbaseDBNoDataConsol()
{
echo ""
echo "To restore please be sure to read the comments in this script to apply the offset values to lzop and tar"
echo "If not very bad things could happen"
echo "---------------------------------"
#  Added logic into to use lzop in a tar command to zip up the backup
#  I had to include the full path in the tar file because of inconsistencies.
#  When extracting it will include all the directories possibly causing the files to be nested incorrectly
#  VERY IMPORTANT ---------------------------------------------------------------------
#  When you go to restore a file you will want to 
#  1.  cd <to the directory above the resore location>
#  2.  use the following command 
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components <number of directories in front of the base directory
#  For Example
#  In DEV the $AROBORPATH directory is set to /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer/essbaseserver1
#  If you need to restore the backup you would 
#  cd /swdata/db/hyperion/Oracle/Middleware/user_projects/epmsystem3/EssbaseServer
#  tar --use-compress-program=lzop -xvf <tarfile.tar.lzop> --strip-components 8
#  This would extract only the essbaseserver1 directory and below, it would leave off the 8 preceding directories so that the paths would be ok
#
# Also for the backup location I am using APPCLU from the controlfile, this will need to be changed if the application fails over, this will 
# Be revised in the next version
# FOR RIGHT NOW UPDATE THE CONTROLFILE FOR THE APP CLUSTER LOCATION IN THE JOB SECTION IF FAIL OVER OCCURS
#
if [[ "$VERSION" = 11.1.1 ]]; then
   echo "Essbase is down proceeding to backup"
   echo "Creating directory for backup"
   mkdir $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   ls -ltr $BACKUPDIR
   echo "Copying and zipping HYPERION HOME to $BACKUPDIR/$SERVER"_backup_"$DATESTAMP"
    tar --use-compress-program=lzop -cvf $BACKUPDIR/$SERVER"_backup_"$DATESTAMP".tar.lzop" $HYPERION_HOME
#   cp -rp $HYPERION_HOME $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   echo "Comparing to verify backup is complete ..."
#   diff -r  $BACKUPDIR/$SERVER"_backup_"$DATESTAMP $HYPERION_HOME/..
elif [[ "$VERSION" = 11.1.2 || "$VERSION" = 11.1.2.3 || "$VERSION" = 11.1.2.4 ]]; then
   echo "Essbase is down proceeding to backup"
# New parameters put in for CONSOL backup
if [[ $APPBKTYPE = 'CONSOL' ]]; then
   export APPBKSTEP=CopyEssbaseDBNoData
   echo "APPBKSTEP= "$APPBKSTEP
   echo "First parameter passed to function CopyEssbaseDBNoData is Application = "$1
   echo "Second parameter passed to function CopyEssbaseDBNoData is Database = "$2
   export APP=$1
   export DB=$2
else
   echo "Not a consolidated backup, no need to swap varaibles per application"
fi
echo "The command to re-run the job"
echo "===================================================="
echo "$SCRIPTSDIR/${PROGNAME} $ENV_NAME $BKPRERUN_NAME"
export BKPRERUN_JOB="Please re-run the job using $SCRIPTSDIR/${PROGNAME} $ENV_NAME $BKPRERUN_NAME"
echo $BKPRERUN_JOB
echo "===================================================="

#THIS WILL FAIL IF CLUSTER FAILS OVER APPCLU will need updated in the controlfile
   BACKUPDIR=$ROOTBACKDIR/$APPCLU
   echo "Copying Essbase Files other than data files for "$APP"."$DB
#   ls -ltr $BACKUPDIR
#   echo "Copying and zipping MIDDLEWARE HOME to $BACKUPDIR/$SERVER"_backup_Middleware."$DATESTAMP".tar.lzop
#   tar --use-compress-program=lzop -cvf $BACKUPDIR/$SERVER"_backup_Middleware."$DATESTAMP".tar.lzop" $MIDDLEWARE_HOME
#   cp -rp $MIDDLEWARE_HOME $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
   export BACKUPFILENAME="APP_DB_NODATA_"$APP"."$DB"."$DATESTAMP".tar.lzop"
   echo "Copying  and zipping Essbase Application NO data and index files "$APP"."$DB" to "$BACKUPDIR/$BACKUPFILENAME
#   tar --use-compress-program=lzop -cvf $BACKUPDIR/"APP_FULL"$APP"."$DATESTAMP".tar.lzop" $ARBORPATH/app/$APP
   tar --use-compress-program=lzop -cvf $BACKUPDIR/$BACKUPFILENAME `find $ARBORPATH/app/$APP/$DB | grep '.otl\|.csc\|.rul\|.rep\|.eqd\|.sel\|ADM.*txt'`
#   cp -rp $ARBORPATH $BACKUPDIR/$SERVER"_backup_"$DATESTAMP
OUT=$?
   echo "Return Code = "$OUT
   if [ $OUT -eq 0 ];then
      echo "Essbase Backup was Successful!" 
	  echo "Completed tar and backup for "$APP"."$DB
	  ls -ltr $BACKUPDIR/$BACKUPFILENAME
	  echo "----------------------------------------------------------------------------------------------------"
	  echo ""
	  if [[ $DRBAK = 'DR' ]]; then
	     echo "This is a DR backup copying the backup file to the DR directory ..."
         CopyBackupToDR &
      else
         echo "This is not a DR backup"
      fi
   else
      echo "Essbase Backup failed exiting script"
	  echo "----------------------------------------------------------------------------------------------------"
	  ErrorExit "essbase_master.sh Essbase file copy failed Copying  and zipping Essbase Application NO data and index files "$APP" to "$BACKUPDIR/$BACKUPFILENAME", Error on line: $LINENO"
	fi  
else
   echo "Version is incorrect Please use  (11.1.1 | 11.1.2) version passed is "$VERSION
   ErrorExit "essbase_master.sh Version is incorrect Please use  (11.1.1 | 11.1.2 | 11.1.2.3 | 11.1.2.4) version passed is "$VERSION" exiting program, Error on line: $LINENO"
fi
}

function CopyBackupToNAS()
{
echo "Copying backupfile "$STAGEBACKDIR/$BACKUPFILENAME " to "$BACKUPDIR/$BACKUPFILENAME
cp -rp $STAGEBACKDIR/$BACKUPFILENAME $BACKUPDIR/$BACKUPFILENAME
OUT=$?
echo "Return Code = "$OUT
if [ $OUT -eq 0 ];then
   echo "Essbase Backup from stage to NAS was Successful!" 
   echo "----------------------------------------------------------------------------------------------------"
   echo ""
   rm $STAGEBACKDIR/$BACKUPFILENAME
else
   echo "Essbase Backup failed exiting script but keeping "$STAGEBACKDIR/$BACKUPFILENAME
   echo "----------------------------------------------------------------------------------------------------"
   ErrorExit "essbase_master.sh Essbase file copy failed Copying backupfile "$STAGEBACKDIR/$BACKUPFILENAME " to "$BACKUPDIR/$BACKUPFILENAME" but keeping $STAGEBACKDIR/$BACKUPFILENAME, Error on line: $LINENO"
fi
}

function CopyExpBackupToDR()
{

echo "Exportfile base name is "$EXPFILENOTXT
echo "Listing ls -ltr $BACKUPDIR/$EXPFILENOTXT*"
ls -ltr $BACKUPDIR/$EXPFILENOTXT*
echo "Copying exportfile/s "
echo " to "$DRDIR/
cp -rp $BACKUPDIR/$EXPFILENOTXT* $DRDIR/
OUT=$?
echo "Return Code = "$OUT
if [ $OUT -eq 0 ];then
   echo "Export Backup from "$BACKUPDIR" to "$DRDIR" was Successful!" 
   ls -ltr $DRDIR/$EXPFILENOTXT*
   echo "----------------------------------------------------------------------------------------------------"
   echo ""

else
   echo "Export Backup failed exiting script"
   echo "----------------------------------------------------------------------------------------------------"
   ErrorExit "essbase_master.sh Essbase file copy failed Copying backupfile "$BACKUPDIR/$EXPFILENOTXT*" to "$DRDIR/", Error on line: $LINENO"
fi
}

function CopyBackupToDR()
{
echo "Copying backupfile "$BACKUPDIR/$BACKUPFILENAME" to "$DRDIR/$BACKUPFILENAME
cp -rp $BACKUPDIR/$BACKUPFILENAME $DRDIR/$BACKUPFILENAME
OUT=$?
echo "Return Code = "$OUT
if [ $OUT -eq 0 ];then
   echo "Essbase Backup copy from "$BACKUPDIR" to "$DRDIR" was Successful!" 
   ls -ltr $DRDIR/$EXPFILE
   echo "----------------------------------------------------------------------------------------------------"
   echo ""

else
   echo "Essbase Backup failed exiting script"
   echo "----------------------------------------------------------------------------------------------------"
   ErrorExit "essbase_master.sh Essbase file copy failed Copying backupfile "$BACKUPDIR/$BACKUPFILENAME" to "$DRDIR/$EXPFILE", Error on line: $LINENO"
fi
}

#NR - Added backup rerun function
#This fnction will re-run the failed export
#In case of backup failure, this function will check if there are any sessions running for the particular APP.DB, if it is running, then will wait until the session completes and re-run the backup.
#This function will not re-run the backup if the time exceeds backup end time.
# Backup end time is set via BKP_TIME parameter in SetupEnv function. The BKP_TIME will be retrieved from Control file.
function Backup_Rerun()
{
echo "Re-running the failed backup job"
export RERUN="Backup for $APP.$DB was re-run successfully which failed with the error"
export MAILBODY_OLD=`cat $ROOTLOGDIR/$ERRLOGNAME`
export MAILBODY=`echo -e "$RERUN.......$MAILBODY_OLD"`
export MAILSUBJECT="<CLEAR> essbase_master.sh Backup Re-run success for "$APP"."$DB""
export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
export DATE=`date +%Y-%m-%d`
export EXP_RERUN_FILE=$ROOTLOGDIR/Export_Rerun_Status_"$HOSTNAME"_"$DATE".txt
export SESSION=`cat $ROOTLOGDIR/$SESSOUTFILE | grep -e "in_progress" -e "unknown" | grep $APP | grep $DB`
export RERUN_STATUS=1
while [[ $RERUN_STATUS == 1 ]]
do

#CL15373-Modify hard coded timestamp to number of minutes
# CURR_TIME=$(date +%H%M)
# if [[ $((10#$CURR_TIME)) -lt  $((10#$BKP_TIME)) ]];
CURRENT_TIME=`date +%Y-%m-%d\ %H:%M:%S`
CURRENT_TIME_IN_SECS=$(date +%s --date="$CURRENT_TIME")

echo "CURRENT TIME=$CURRENT_TIME"
echo "CURRENT TIME IN SECS=$CURRENT_TIME_IN_SECS"
echo "if [ ${CURRENT_TIME_IN_SECS} -le ${BACKUP_MAX_TIME_IN_SECS} ];then"

if [ ${CURRENT_TIME_IN_SECS} -le ${BACKUP_MAX_TIME_IN_SECS} ];then
	sleep 10

	getEssbaseSession
	if cat $ROOTLOGDIR/$SESSOUTFILE | grep -e "in_progress" -e "unknown" | grep $APP | grep $DB;
		then
		echo "There are sessions running. Going to sleep for 3 minutes"
		sleep 180
	else
		if [[ $APPBKTYPE = 'CONSOL' ]]; then
			echo "Calling expConsolDB function"
			export MAILBODY_OLD=`cat $LOGDIR/$ERRLOGNAME`
			export MAILBODY=`echo -e "$RERUN ....... $MAILBODY_OLD"`
			expConsolDB $APP $DB
		else
			echo "Calling expDB function"
			expDB
		fi	
		echo "$APP.$DB | export | Success | `echo $SESSION | awk '{print $1,"performing",$7,"|";}' | xargs -d'\n'`" >> $EXP_RERUN_FILE
		export RERUN_STATUS=0
		MailMessage
	fi
else
	export MAILBODY_OLD=`cat $ROOTLOGDIR/$ERRLOGNAME`
	export RERUN="Backup re-run failed as backup timeline exceeded : "
	export MAILBODY=`echo -e "$RERUN......$BKPRERUN_JOB"`
	export MAILSUBJECT="<CRITICAL-Rerun Manually> essbase_master.sh Backup re-run failed:Time exceeded for "$APP"."$DB""
	export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`	
	echo "Backup re-run failed as backup timeline exceeded, please re-run the backup manually : $BKPRERUN_JOB"
	MailMessage
	echo "$APP.$DB | export | Failed | `cat $ROOTLOGDIR/$SESSOUTFILE | grep -e "in_progress" -e "unknown" | grep $APP | grep $DB | awk '{print $1,"performing",$7," ";}' | xargs -d'\n'`" >> $EXP_RERUN_FILE
	echo "$APP.$DB | `cat $ROOTLOGDIR/$SESSOUTFILE | grep -e "in_progress" -e "unknown "| grep $APP | grep $DB | awk '{print $1,"performing",$7," ";}' | xargs -d'\n'`" >> $EXP_FAIL_FILE
#	echo "---------------------------------------------" >> $EXP_FAIL_FILE
	exit 1
fi
done
}

function expDB ()
{
echo ""
echo "-------------------------------------------------------------------------------------------------"
echo ""
export BACKUPDIR=$EXPDIR
echo "Exporting to "$BACKUPDIR
#Setting this for backward compatibility remove when we use this for exports
export LOGDIR=$ROOTLOGDIR
#
export LOGNAME=$BACKUPNAME"_"$APP"."$DB"_"exp.$DATESTAMP.log
export ERRLOGNAME=$BACKUPNAME"_"$APP"."$DB"_"exp.$DATESTAMP.err
export DATESTAMP=`date +%Y-%m-%d_%H_%M`
if [ "$PX" -gt 1 ]; then
   echo "The export job will be run in parallel with the parallelism of "$PX
   STARTPX=1
   END=$PX
## save $START, just in case if we need it later ##
   i=$STARTPX
   while [[ $i -le $END ]]
   do
     export BASEEXPFILE=$APP"."$DB"_"$DATESTAMP
     export EXPFILE_$i=$BASEEXPFILE"_"$i.txt
     echo "Setting variable "$"EXPFILE_"$i
         echo $EXPFILE_$i
     ((i = i + 1))
   done
else
   echo "Setting Export file information ..."
   export EXPFILE=$APP"."$DB"_"$DATESTAMP.txt
   export EXPFILENOTXT=$APP"."$DB"_"$DATESTAMP
   echo "Export file is "$EXPFILE
fi

if [[ -z $DRBAK ]]; then
export BKPRERUN_NAME=$BKPENV_NAME$DRBAK'_EXP0_'$APP'_'$DB
echo "The non-dr backup name is:"$BKPRERUN_NAME
else
export BKPRERUN_NAME=$BKPENV_NAME'_'$DRBAK'_EXP0_'$APP'_'$DB
echo "The DR backup name is:"$BKPRERUN_NAME
fi

echo "The command to re-run the job"
echo "===================================================="
echo "$SCRIPTSDIR/${PROGNAME} $ENV_NAME $BKPRERUN_NAME"
export BKPRERUN_JOB=`echo ...Please re-run the job using $SCRIPTSDIR/${PROGNAME} $ENV_NAME $BKPRERUN_NAME`
echo $BKPRERUN_JOB
echo "===================================================="

        if [[ "$VERSION" = 11.1.1 ]]; then
                if [ $APP = PSG_ASO ]
                then
                        echo "Starting Level 0 export for database $DB ..."
strpt
                cd $HYPERION_HOME/products/Essbase/EssbaseServer/bin
                $HYPERION_HOME/products/Essbase/EssbaseServer/bin/startMaxl.sh -D $MAXLDIR/exp0_ASO_db.mxl $PK
                OUT=$?
                echo "Return Code = "$OUT
                        if [ $OUT -eq 0 ];then
                                echo "Export for $APP.$DB was successful!"
                        else
                                echo "Export for $APP.$DB failed with the following error "
                                cat $ROOTLOGDIR/$ERRLOGNAME
                                exit $OUT
strpt_update
                        fi
                else
strpt
                        echo "Starting Level 0 export for database $DB ..."
                        cd $HYPERION_HOME/products/Essbase/EssbaseServer/bin
                        $HYPERION_HOME/products/Essbase/EssbaseServer/bin/startMaxl.sh -D $MAXLDIR/exp0_db.mxl $PK
                        OUT=$?
                        echo "Return Code = "$OUT
                        if [ $OUT -eq 0 ];then
                                echo "Export for $APP.$DB was successful!"
strpt_update
                        else
                                echo "Export for $APP.$DB failed with the following error "
                                cat $ROOTLOGDIR/$ERRLOGNAME
                                exit $OUT
                        fi
                fi
#        elif [[ "$VERSION " = 11.1.2 ]]; then
#Dummy
                 else
                if [ $ASO_BSO = "ASO" ]
                        then
                        echo "Starting Level 0 export for database $DB ..."
strpt
                                            echo "CALLING "$MAXLDIR/exp0_db2.mxl
                                                echo "Log directory = "$LOGDIR
                                                echo "Log name = "$LOGNAME
                                                echo "Error log Name = "$ERRLOGNAME
                        cd $ARBORPATH/bin
                        $ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/exp0_db2.mxl $PK
                                                OUT=$?
                        echo "Return Code = "$OUT
                        if [ $OUT -eq 0 ];then
                                echo "Export for $APP.$DB was successful!"
strpt_update
                        else
                                                        echo "-------------------------------------------------------------------------------------------------"
                                echo "Export for $APP.$DB failed with the following error "
                                cat $ROOTLOGDIR/$ERRLOGNAME
				export MAILBODY_OLD=`cat $ROOTLOGDIR/$ERRLOGNAME`
				export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
                                export MAILSUBJECT="<CRITICAL> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
                                export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
                                echo "Sending exp error mail message 1"
                                MailMessage
                                echo "-------------------------------------------------------------------------------------------------"
                                exit $OUT
                        fi
                        if [ -s $ROOTLOGDIR/$ERRLOGNAME ]; then
                        echo "-------------------------------------------------------------------------------------------------"
                        echo "Export for $APP.$DB failed with the following error "
                        cat $ROOTLOGDIR/$ERRLOGNAME
			export MAILBODY_OLD=`cat $ROOTLOGDIR/$ERRLOGNAME`
			export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
                        export MAILSUBJECT="<CRITICAL-Re-running> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
                        export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
			echo "Sending exp error mail message 2"
			if cat $ROOTLOGDIR/$ERRLOGNAME | grep -e "1051544" -e "1042013" -e "1270033" -e "1056024" -e "1051032" -e "1051030"
                        then
                        export MAILSUBJECT="<CRITICAL-Rerun Manually> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
			echo "$APP.$DB | export | Failed | `echo $MAILBODY_OLD | tr -d '\n'`" >> $EXP_RERUN_FILE
			MailMessage
                        elif cat $ROOTLOGDIR/$ERRLOGNAME | grep -e "1270028"
                        then
                                echo "Application has no data"
				export MAILSUBJECT="<CRITICAL> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
                               MailMessage
                        else
                                MailMessage
                                Backup_Rerun
                        fi
			echo "-------------------------------------------------------------------------------------------------"
                        fi

                else
                        echo "Starting Level 0 export for database $DB ..."
strpt
                                                echo "CALLING "$MAXLDIR/exp0_db_col.mxl
                                                echo "Log directory = "$LOGDIR
                                                echo "Log name = "$LOGNAME
                                                echo "Error log Name = "$ERRLOGNAME
                        cd $ARBORPATH/bin
                        $ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/exp0_db_col.mxl $PK
                                                OUT=$?
                        echo "Return Code = "$OUT
                        if [ $OUT -eq 0 ];then
                                echo "Export for $APP.$DB was successful!"
strpt_update
                        else
                                 echo "-------------------------------------------------------------------------------------------------"
                                echo "Export for $APP.$DB failed with the following error "
                                cat $ROOTLOGDIR/$ERRLOGNAME
				export MAILBODY_OLD=`cat $ROOTLOGDIR/$ERRLOGNAME`
				export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
                                export MAILSUBJECT="<CRITICAL> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
                                export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
                                echo "Sending exp error mail message 1"
                                MailMessage
                                echo "-------------------------------------------------------------------------------------------------"
                                exit $OUT
                        fi
			if cat $ROOTLOGDIR/$LOGNAME | grep "1005045 - The cube has no data"
                        then
                                export MAILBODY_OLD="WARNING - 1005045 - The cube has no data....."
                                export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
                                export MAILSUBJECT="<CRITICAL> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
                                export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
                                echo "Sending exp error mail message 2" 
                                MailMessage
                        fi
                        if [ -s $ROOTLOGDIR/$ERRLOGNAME ]; then
                        echo "-------------------------------------------------------------------------------------------------"
                        echo "Export for $APP.$DB failed with the following error "
                        cat $ROOTLOGDIR/$ERRLOGNAME
						export MAILBODY_OLD=`cat $ROOTLOGDIR/$ERRLOGNAME`
						export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
                        export MAILSUBJECT="<CRITICAL-Re-running> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
                        export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
			echo "Sending exp error mail message 2"
			if cat $ROOTLOGDIR/$ERRLOGNAME | grep -e "1051544" -e "1042013" -e "1270033" -e "1056024" -e "1051032" -e "1051030"
			then
				export MAILSUBJECT="<CRITICAL-Rerun Manually> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
				echo "$APP.$DB | export | Failed | `echo $MAILBODY_OLD | tr -d '\n'`" >> $EXP_RERUN_FILE
				MailMessage
			elif cat $ROOTLOGDIR/$ERRLOGNAME | grep -e "1270028"
			then
				echo "Application has no data"	
				export MAILSUBJECT="<CRITICAL> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
							MailMessage
						else
							MailMessage
							Backup_Rerun
						fi
						echo "-------------------------------------------------------------------------------------------------"
                        fi
                fi
        fi
}

function expConsolDB ()
{
echo ""
echo "-------------------------------------------------------------------------------------------------"
echo ""
export BACKUPDIR=$EXPDIR
echo "Exporting to "$BACKUPDIR
export DATE=`date +%Y-%m-%d`
export CUBE_NODATA_FILE=$ROOTLOGDIR/CUBE_NODATA_"$HOSTNAME"_"$DATE".txt
# New parameters put in for CONSOL backup
echo "First parameter passed to function expConsolDB is Application = "$1
echo "Second parameter passed to function expConsolDB is Database = "$2
# New parameters put in for CONSOL backup
if [[ $APPBKTYPE = 'CONSOL' ]]; then
   export APPBKSTEP=expConsolDB
   echo APPBKSTEP=$APPBKSTEP
   echo "First parameter passed to function expConsolDB is Application = "$1
   echo "Second parameter passed to function expConsolDB is Database = "$2
   export APP=$1
   export DB=$2
else
   echo "Not a consolidated backup, no need to swap varaibles per application"
fi
#Setting this for backward compatibility remove when we use this for exports
export LOGDIR=$CONSOLLOGDIR
#
export LOGNAME=$BACKUPNAME"_"$APP"."$DB"_"exp.$DATESTAMP.log
export ERRLOGNAME=$BACKUPNAME"_"$APP"."$DB"_"exp.$DATESTAMP.err
export DATESTAMP=`date +%Y-%m-%d_%H_%M`

if [[ -z $DRBAK ]]; then
export BKPRERUN_NAME=$BKPENV_NAME$DRBAK'_EXP0_'$APP'_'$DB
echo "The non-dr backup name is:"$BKPRERUN_NAME
else 
export BKPRERUN_NAME=$BKPENV_NAME'_'$DRBAK'_EXP0_'$APP'_'$DB
echo "The DR backup name is:"$BKPRERUN_NAME
fi

echo "The command to re-run the job"
echo "===================================================="
echo "$SCRIPTSDIR/${PROGNAME} $ENV_NAME $BKPRERUN_NAME"
export BKPRERUN_JOB=`echo ...Please re-run the job using $SCRIPTSDIR/${PROGNAME} $ENV_NAME $BKPRERUN_NAME`
echo $BKPRERUN_JOB
echo "===================================================="

if [[ "$PX" -gt 1 ]]; then
   echo "The export job will be run in parallel with the parallelism of "$PX
   STARTPX=1
   END=$PX
## save $START, just in case if we need it later ##
   i=$STARTPX
   while [[ $i -le $END ]]
   do
     export BASEEXPFILE=$APP"."$DB"_"$DATESTAMP
     export EXPFILE_$i=$BASEEXPFILE"_"$i.txt
     echo "Setting variable "$"EXPFILE_"$i
	 echo $EXPFILE_$i
     ((i = i + 1))
   done
else
   echo "Setting Export file information ..."
   export EXPFILE=$APP"."$DB"_"$DATESTAMP.txt
   export EXPFILENOTXT=$APP"."$DB"_"$DATESTAMP
   echo "Export file is "$EXPFILE
fi

        if [[ "$VERSION" = 11.1.1 ]]; then
                if [ $APP = PSG_ASO ]
                then
                        echo "Starting Level 0 export for database $DB ..."
strpt
                cd $HYPERION_HOME/products/Essbase/EssbaseServer/bin
                $HYPERION_HOME/products/Essbase/EssbaseServer/bin/startMaxl.sh -D $MAXLDIR/exp0_ASO_db.mxl $PK
                OUT=$?
                echo "Return Code = "$OUT
                        if [ $OUT -eq 0 ];then
                                echo "Export for $APP.$DB was successful!"
                        else
                                echo "Export for $APP.$DB failed with the following error "
                                cat $ROOTLOGDIR/$ERRLOGNAME
                                exit $OUT
strpt_update
                        fi
                else
strpt
                        echo "Starting Level 0 export for database $DB ..."
                        cd $HYPERION_HOME/products/Essbase/EssbaseServer/bin
                        $HYPERION_HOME/products/Essbase/EssbaseServer/bin/startMaxl.sh -D $MAXLDIR/exp0_db.mxl $PK
                        OUT=$?
                        echo "Return Code = "$OUT
                        if [ $OUT -eq 0 ];then
                                echo "Export for $APP.$DB was successful!"
strpt_update
                        else
                                echo "Export for $APP.$DB failed with the following error "
                                cat $ROOTLOGDIR/$ERRLOGNAME
                                exit $OUT
                        fi
                fi
#        elif [[ "$VERSION " = 11.1.2 ]]; then
#Dummy
		 else
                if [ $ASO_BSO = "ASO" ]
                        then
                        echo "Starting Level 0 export for database $DB ..."
strpt
					    echo "CALLING "$MAXLDIR/exp0_db2.mxl
						echo "Log directory = "$LOGDIR
						echo "Log name = "$LOGNAME
						echo "Error log Name = "$ERRLOGNAME
                        cd $ARBORPATH/bin
                        $ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/exp0_db2.mxl $PK
						OUT=$?
                        echo "Return Code = "$OUT
                        if [ $OUT -eq 0 ];then
								grep "Database export completed" $LOGDIR/$LOGNAME
                                echo "Export for $APP.$DB was successful!"
								echo "DR setting is (If it says DR it is on)"$DRBAK
                                echo "----------------------------------------------------------------------------------------------------"
                                if [[ $DRBAK = 'DR' ]]; then
                                   echo "This is a DR backup copying the export file to the DR directory ..."
                                   CopyExpBackupToDR &
                                else
                                   echo "This is not a DR backup"
                                fi
strpt_update
                        else
						        echo "-------------------------------------------------------------------------------------------------"
                                echo "Export for $APP.$DB failed with the following error "
                                cat $LOGDIR/$ERRLOGNAME
								export MAILBODY_OLD=`cat $LOGDIR/$ERRLOGNAME`
								export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
                                export MAILSUBJECT="<CRITICAL> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
                                export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
								echo "Sending exp error mail message 1"
                                MailMessage
								echo "-------------------------------------------------------------------------------------------------"
                                exit $OUT
                        fi
			if [ -s $LOGDIR/$ERRLOGNAME ]; then
			echo "-------------------------------------------------------------------------------------------------" 
			echo "Export for $APP.$DB failed with the following error "
			cat $LOGDIR/$ERRLOGNAME
			export MAILBODY_OLD=`cat $LOGDIR/$ERRLOGNAME`
			export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
			export MAILSUBJECT="<CRITICAL-Re-running> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
			export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
			echo "Sending exp error mail message 2"
			if cat $LOGDIR/$ERRLOGNAME | grep -e "1051544" -e "1042013" -e "1270033" -e "1056024" -e "1051032" -e "1051030"
			then
				export MAILSUBJECT="<CRITICAL-Rerun Manually> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
				echo "$APP.$DB | export | Failed | `echo $MAILBODY_OLD | tr -d '\n'` " >> $EXP_RERUN_FILE
				echo "$APP.$DB | `echo $MAILBODY_OLD | tr -d '\n'` " >> $EXP_FAIL_FILE
	#			echo "---------------------------------------------" >> $EXP_FAIL_FILE
				MailMessage
			elif cat $LOGDIR/$ERRLOGNAME | grep -e "1270028"
			then
				echo "Application has no data"
				echo "$APP.$DB" >> $CUBE_NODATA_FILE
				#MailMessage
			else
				MailMessage
				Backup_Rerun
			fi
			echo "-------------------------------------------------------------------------------------------------"
                        fi
						                       
                else
                        echo "Starting Level 0 export for database $DB ..."
strpt
			echo "CALLING "$MAXLDIR/exp0_db_col.mxl
			echo "Log directory = "$LOGDIR
			echo "Log name = "$LOGNAME
			echo "Error log Name = "$ERRLOGNAME
                        cd $ARBORPATH/bin
                        $ARBORPATH/bin/startMaxl.sh -D $MAXLDIR/exp0_db_col.mxl $PK
			OUT=$?
                        echo "Return Code = "$OUT
                        if [ $OUT -eq 0 ];then
				grep "Database export completed" $LOGDIR/$LOGNAME
                                echo "Export for $APP.$DB was successful!"
				echo "DR setting is (If it says DR it is on)"$DRBAK
                                echo "----------------------------------------------------------------------------------------------------"
                                if [[ $DRBAK = 'DR' ]]; then
                                   echo "This is a DR backup copying the export file to the DR directory ..."
                                   CopyExpBackupToDR &
                                else
                                   echo "This is not a DR backup"
                                fi
strpt_update
                        else
				echo "-------------------------------------------------------------------------------------------------"
                                echo "Export for $APP.$DB failed with the following error "
                                cat $LOGDIR/$ERRLOGNAME
				export MAILBODY_OLD=`cat $LOGDIR/$ERRLOGNAME`
				export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
                                export MAILSUBJECT="<CRITICAL> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
                                export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
				echo "Sending exp error mail message 1"
                                MailMessage
				echo "-------------------------------------------------------------------------------------------------"
                                exit $OUT
                        fi
			if cat $LOGDIR/$LOGNAME | grep "1005045 - The cube has no data" 
			then
				echo "Application has no data"
				echo "$APP.$DB" >> $CUBE_NODATA_FILE
			fi
			if [ -s $LOGDIR/$ERRLOGNAME ]; then
				echo "-------------------------------------------------------------------------------------------------"
				echo "Export for $APP.$DB failed with the following error "
				cat $LOGDIR/$ERRLOGNAME
				export MAILBODY_OLD=`cat $LOGDIR/$ERRLOGNAME`
				export MAILBODY=`echo $MAILBODY_OLD $BKPRERUN_JOB`
				export MAILSUBJECT="<CRITICAL-Re-running> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
				export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
				echo "Sending exp error mail message 2"
				if cat $LOGDIR/$ERRLOGNAME | grep -e "1051544" -e "1042013" -e "1270033" -e "1056024" -e "1051032" -e "1051030"
				then
					export MAILSUBJECT="<CRITICAL-Rerun Manually> essbase_master.sh failed Export for "$APP"."$DB" failed with the following error"
					echo "$APP.$DB | export | Failed | `echo $MAILBODY_OLD | tr -d '\n'` " >> $EXP_RERUN_FILE
					echo "$APP.$DB | `echo $MAILBODY_OLD | tr -d '\n'` " >> $EXP_FAIL_FILE
	#				echo "---------------------------------------------" >> $EXP_FAIL_FILE
					MailMessage
				elif cat $LOGDIR/$ERRLOGNAME | grep -e "1270028"
				then
					echo "Application has no data"
					echo "$APP.$DB" >> $CUBE_NODATA_FILE
					#MailMessage
				else
					MailMessage
					Backup_Rerun
				fi
			echo "-------------------------------------------------------------------------------------------------"
                        fi
                fi
        fi
}
function compressExp ()
{
# Loop through the exports created and compress the with lzop
echo "Compressing export backup"
#time lzop -1 -v -U $BACKUPDIR/$EXPFILENOTXT*
time $ROOTBACKDIR/lzop -1 -v -U $BACKUPDIR/$EXPFILENOTXT*
}

#NR - Added LCM rerun function
#This function will re-run the export in case of export failure. This will re-run the job for 2 tries.
function LCM_Rerun
{
		echo "Re-running the failed $BACKUPNAME"
		echo "In LCM re-run function"
		export MAILBODY="lcm_master.sh LCM Migration for $BACKUPNAME failed:-Unknown Error. Re-running LCM backup"
		export MAILSUBJECT="<CRITICAL-Re-running> ${PROGNAME} running ${BACKUPNAME} failed. Re-running"
		export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
                case $LCM_RSTATUS in
                1) MailMessage;echo "sleeping for 1 minute"; sleep 60;echo "Re-running LCM : 1st attempt";runLCM;;
                2) MailMessage;echo "sleeping for 10 minute";sleep 600;echo "Re-running for the 2nd time";runLCM;;
                *) echo "$BACKUPNAME | Failed" >> $LCM_RERUN_FILE;export MAILBODY="lcm_master.sh LCM Migration for $BACKUPNAME failed Please Review the LCM Migration Report in Shared Services, Error on line: $LINENO";export MAILSUBJECT="<CRITICAL-Rerun Manually> ${PROGNAME} running ${BACKUPNAME} failed";MailMessage;exit 2;; 
                esac
}

function runLCM()
{
export LCMERRLOGNAME=${BACKUPNAME}_${SERVERTYPE}_${HOST}_${DATESTAMP}.err
export DATE=`date +%Y-%m-%d`
if [[ $LCM_RSTATUS == 1 || $LCM_RSTATUS == 2 ]]; then
	export DATESTAMP=`date +%Y-%m-%d_%H_%M`
fi
export LCM_RERUN_FILE=$ROOTLOGDIR/LCM_Rerun_Status_"$HOSTNAME"_"$DATE".txt
export DIRNAME=$DATESTAMP"_"$BACKUPNAME
echo "Defining log file as "$ROOTLOGDIR/$LCMERRLOGNAME
if [[ "$VERSION" = 11.1.1 ]]; then
   echo "This version does not have the abitity to run LCM backups"

else
# Set Variables for LCM Backup

   if [[ "$SERVERTYPE" = 'FULLEPMINSTALL' ]]; then

		echo "Making LCM Directory ..."
        mkdir $LCMROOTBACKDIR/$DIRNAME
		OUT=$?
		echo "Return Code = "$OUT
        if [ $OUT -eq 0 ];then
           echo "Directory created successfully"
		else
			echo "Directory creation failed aborting backup"
			echo "$BACKUPNAME - Failed - Directory creation failed aborting backup" >> $LCM_RERUN_FILE		   
			ErrorExit "essbase_master.sh LCM Export for "$BACKUPNAME" Directory creation failed aborting backup, Error on line: $LINENO"
		fi   
        export BACKUPDIR=$LCMROOTBACKDIR/$DIRNAME
        export ZIPPATH=$ROOTBACKDIR/scripts/p7zip_9.20.1/bin
   elif [[ "$SERVERTYPE" =  "FOUND" ]]; then
      export LCMROOTBACKDIR=/util/hyperion/lcmbackup
      mkdir $LCMROOTBACKDIR/$DIRNAME
      if [ $OUT -eq 0 ];then
         echo "Directory created successfully"
	  else
			echo "Directory creation failed aborting backup"
			echo "$BACKUPNAME - Failed - Directory creation failed aborting backup" >> $LCM_RERUN_FILE
			ErrorExit "essbase_master.sh LCM Export for "$BACKUPNAME" Directory creation failed aborting backup, Error on line: $LINENO"
      fi		
      export BACKUPDIR=$LCMROOTBACKDIR/$DIRNAME
      export TEMPLATEDIR=$EPM_ORACLE_INSTANCE/bin/lcm_dev_templates

   else

      mkdir $ROOTBACKDIR/LCM/$DIRNAME
      if [ $OUT -eq 0 ];then
         echo "Directory created successfully"
      else
			echo "Directory creation failed aborting backup"
			echo "$BACKUPNAME - Failed - Directory creation failed aborting backup" >> $LCM_RERUN_FILE
			ErrorExit "essbase_master.sh LCM Export for "$BACKUPNAME" Directory creation failed aborting backup, Error on line: $LINENO"

      fi
      export BACKUPDIR=$ROOTBACKDIR/LCM/$DIRNAME
      echo "Creating backup directory "$BACKUPDIR
   fi

echo "Starting LCM Migration for database $DB ..."
strpt
echo "Using Template "$TEMPLATEDIR/$LCMTEMP.xml
echo "Running Command ..."
echo $EPM_ORACLE_INSTANCE"/bin/Utility.sh "$TEMPLATEDIR/$LCMTEMP".xml -b" $BACKUPDIR" > "$ROOTLOGDIR/$LCMERRLOGNAME
$EPM_ORACLE_INSTANCE/bin/Utility.sh $TEMPLATEDIR/$LCMTEMP.xml -b $BACKUPDIR > $ROOTLOGDIR/$LCMERRLOGNAME

OUT=$?
echo "Return Code = "$OUT
if [ $OUT -eq 0 ];then
   echo "Migration for $BACKUPNAME was successful!"
   echo "Listing the artifacts migrated "
   echo "-------------------------------------------------------------------------------------------------"
   cat $ROOTLOGDIR/$LCMERRLOGNAME
   echo "-------------------------------------------------------------------------------------------------"
   if [[ $LCM_RSTATUS == 1 || $LCM_RSTATUS == 2 ]]; then
		echo "Sending Re-run success mail"
		export MAILBODY="LCM Backup for $BACKUPNAME was re-run successfully"
		export MAILSUBJECT="<CLEAR> LCM Backup Re-run success"
		export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
		MailMessage
		echo "$BACKUPNAME - Success" >> $LCM_RERUN_FILE;
	fi
strpt_update

else
strpt_update
   echo "LCM Migration for $BACKUPNAME failed Please Review the LCM Migration Report in Shared Services"
   export LCM_RSTATUS=$((LCM_RSTATUS + 1 ))
	if [[ $LCM_RSTATUS == 1 || $LCM_RSTATUS == 2 ]]; then
		LCM_Rerun
	else
		echo "$BACKUPNAME - Failed" >> $LCM_RERUN_FILE;
		export MAILSUBJECT="<CRITICAL-Rerun Manually> ${PROGNAME} running ${BACKUPNAME} failed"
                export MAILBODY="lcm_master.sh LCM Migration for $BACKUPNAME failed Please Review the LCM Migration Report in Shared Services, Error on line: $LINENO"
                MailMessage
                exit 2
#		ErrorExit "lcm_master.sh LCM Migration for $BACKUPNAME failed Please Review the LCM Migration Report in Shared Services, Error on line: $LINENO"
	fi
fi
#YXN 11/21/2016
#Removing the compression on the LCM package as the compression occurs at the FS level.

#   echo "Entering the part where we check to see if the file needs zipped"
#   echo "-------------------------------------------------------------------------------------------------"
#   echo "Changing directory to "$BACKUPDIR
#
#   cd $BACKUPDIR
#   if [[ "$VERSION" = 11.1.2 || "$VERSION" = 11.1.2.3 || "$VERSION" = 11.1.2.4 ]]; then
#      echo "Checking if the LCM file is already zipped ..."
#
#	  echo "doing a cd .."
#	  cd ..
#	  echo "You are in "
#
#	  pwd
##	  ls -ltr
#	  echo "Looking for "
#	  echo $DIRNAME'.zip'
#	  ls -ltr $DIRNAME'.zip'
#         if [[ -f $DIRNAME'.zip' ]]; then
#            echo "LCM already extracts in zip format, nothing to do here, moving on ..."
#
#         else
#            echo "Did not find a zipped file proceeding to use 7zip ..."
#		    cd $BACKUPDIR


# MEP 11/12
# This originally was a block to go into the LCM directory provided to the Utility.sh script and zip everything inside
# The original intention of this was that there may be multiple 
# Lets not do that anymore
#            for DIR in `ls -d *`
#            do
#               echo "Zipping up Directory "$DIR

#			   echo "Running command ..."
#			   echo $ZIPPATH"/7za a -r -mx9 -t7z "$DIR".7z "$DIR"/*"
#         	   $ZIPPATH/7za a -r -mx9 -t7z $DIR.7z $DIR/*

#		       OUT=$?
#		       echo "Return Code = "$OUT
#               if [ $OUT -eq 0 ];then
#                  echo "Removing Directory "$DIR


#			      rm -rf $DIR
#			   else
#                  echo "Zip failed, keeping directory in tact "
#			      ErrorExit "essbase_master.sh LCM Migration for $APP.$DB failed Zip failed, keeping directory in tact, Error on line: $LINENO"


#               fi
#            done
# MEP 11/12
# In this release I have changed my mind on this approach, lets just zip the highest level directory, the logic being, if it is not already
# zipped up then LCM is looking for it unzipped so why zip unzip it twice
#YXN 11/21/2016
#		cd $LCMROOTBACKDIR
#			echo "Executing below command from "$(pwd)
#			echo $ZIPPATH"/7za a -r -mx9 -t7z "$DIRNAME".7z "$DIRNAME
#			$ZIPPATH/7za a -mx9 -t7z ${DIRNAME}.7z $DIRNAME
#			OUT=$?
#            echo "Return Code = "$OUT
#
#               if [ $OUT -eq 0 ];then
#                  echo "Removing Directory "$DIRNAME
#
#
#                  rm -rf $DIRNAME
#               else
#			      echo "Error code is "$OUT
#				  echo "Not removing the directory"
#                 ErrorExit "essbase_master.sh LCM Migration for $BACKUPNAME failed Zip failed, keeping directory in tact, Error on line: $LINENO"
#               fi
#             fi
#         fi   
   fi   
}

function delOldLCM () {
# Go to the backup diirecotry and find all directories over 30 days old and list then
echo ""
echo "Cleaning up old LCM exports ..."
echo "Deleting the following exports ..."
echo "-------------------------------------------------------------------------------------------------"
cd $LCMROOTBACKDIR
find  -type d -ctime +10 -exec ls -ltr {} \;
find  -type d -ctime +10 -exec rm -rf {} \;
}


function delOldExp () {
# Change the first number in the below line to change number of days of backup files to keep
        for n in {31..36}
        do
                date +%Y-%m-%d  -d $n" days ago" > /tmp/expdate.txt
#Set vatiable to identify folder name of backup directory to clean up
                BACKDATE=`cat /tmp/expdate.txt`*
                export OLD_EXPFILE=$APP"."$DB"_"$BACKDATE
                echo "Appending datestamp to delete backup directory is "$BACKDATE
                echo "Looking for files in "$BACKUPDIR
                echo "Named "$OLD_EXPFILE
#ls -ltr $BACKUPDIR/$BACKDIRNAME
                oldbackdir=$(ls $BACKUPDIR/$OLD_EXPFILE 2> /dev/null | wc -l)
                if [ "$oldbackdir" != "0" ]
                then
                        echo $BACKUPDIR/$OLD_EXPFILE " exist: removing"
                        rm -rf $BACKUPDIR/$OLD_EXPFILE
                else
                        echo $BACKUPDIR/$OLD_EXPFILE " Does not exist..."
                fi
        done
}

function MailMessage()
{
echo $MAILBODY | mailx -s "$MAILSUBJECT for Backup Name $BACKUPNAME" "$MAILLIST"
}

function CleanUp()
{
# Clean up files from the backup will only get called if successful
# Clean up cluster output directory
echo "Clean up cluster output and log directories"
echo "-------------------------------------------------------------------------------------------------"
cd $CLUOUTPUTLOC
#tar cvf $CLUOUTPUTLOC/cluster_output_$DATESTAMP.tar $CLUOUTPUTLOC/*
#rm $CLUOUTPUTLOC/*
echo "Removing old output files from "$CLUOUTPUTLOC
find . -name '*' -mtime +7 -exec ls -ltr {} \;
find . -name '*.out' -mtime +7 -exec rm -f {} \;
find . -name '*.log' -mtime +7 -exec rm -f {} \;
#find $CLUOUTPUTLOC -name '*' -mtime +7 -exec rm {}\;
echo "Removing old log files from "$ROOTLOGDIR
cd $ROOTLOGDIR
find . -name '*.log' -mtime +7 -exec ls -ltr {} \;
find . -name '*.log' -mtime +7 -exec rm -f {} \;
find . -name '*.lst' -mtime +7 -exec ls -ltr {} \;
find . -name '*.lst' -mtime +7 -exec rm -f {} \;
# Remove all empty error files
find . -name '*.err' -type f -empty  -exec ls -ltr -- {} \;
find . -name '*.err' -type f -empty  -exec rm -f -- {} \;
}

function bkpMWH()
{
strpt

#Middleware Backup Script

#Todays date in ISO-8601 format:
DAY0=`date -I`

#Yesterdays date in ISO-8601 format:
DAY1=`date -I -d "1 day ago"`

#The source directory:
SRC="$MIDDLEWARE_HOME/"

#The target directory:
TRG="$MWHOMEBACKDIR/$DAY0"

#The link destination directory:
LNK="$MWHOMEBACKDIR/$DAY1"

#The rsync options:
OPT="-avh --delete $MWHOMEEXCLUDE --link-dest=$LNK"

#Execute the backup
echo ""
echo "-------------------------------------------------------------------------------------------------"
echo ""
echo "Exporting to "$TRG
rsync $OPT $SRC $TRG > $ROOTLOGDIR/$MASTERLOGNAME 2> $ROOTLOGDIR/$MASTERERLOGNAME
        OUT=$?
        echo "Return Code = "$OUT
        if [ $OUT -eq 0 -o $OUT -eq 24 ];then
                echo "Middleware Home backup was successful!"
        else
                        echo "-------------------------------------------------------------------------------------------------"
                echo "Middleware Home backup for $BACKUPNAME failed with the following error "
                cat $ROOTLOGDIR/$MASTERERLOGNAME
                export MAILBODY=`cat $ROOTLOGDIR/$MASTERERLOGNAME`
                export MAILSUBJECT="<CRITICAL> essbase_master.sh failed Middleware Home backup for "$BACKUPNAME" failed with the following error"
                export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
                echo "Sending mwh error mail message 1"
                MailMessage
                echo "-------------------------------------------------------------------------------------------------"
                exit $OUT
        fi

#7 days ago in ISO-8601 format
DAY7=`date -I -d "7 days ago"`

#Delete the backup from 7 days ago, if it exists
echo "Looking for files in "$MWHOMEBACKDIR
echo "Named "$MWHOMEBACKDIR/$DAY7
if [ -d $MWHOMEBACKDIR/$DAY7 ]
        then
                echo $MWHOMEBACKDIR/$DAY7 " exist: removing"
        rm -rf $MWHOMEBACKDIR/$DAY7
                OUT=$?
        echo "Return Code = "$OUT
        if [ $OUT -eq 0 ];then
                echo "Backup cleanup was successful!"
        else
                echo "Backup cleanup for $BACKUPNAME failed"
                exit $OUT
        fi
else
        echo $MWHOMEBACKDIR/$DAY7 " Does not exist..."
fi
strpt_update
}

function bkpARB()
{
#ARBORPATH Backup Script
#Todays date in ISO-8601 format:
DAY0=`date -I`
#Yesterdays date in ISO-8601 format:
DAY1=`date -I -d "1 day ago"`
#The source directory:
SRC="$ARBORPATH/"
#The target directory:
TRG="$ARPTHBACKDIR/$DAY0"
#The link destination directory:
LNK="$ARPTHBACKDIR/$DAY1"
#The rsync options:
OPT="-avh --delete $ARPTHEXCLUDE --link-dest=$LNK"

#Execute the backup
echo ""
echo "-------------------------------------------------------------------------------------------------"
echo ""
echo "Exporting to "$TRG
echo "Running the following command. "
echo "rsync "$OPT" "$SRC" "$TRG" > "$ROOTLOGDIR"/"$MASTERLOGNAME" 2> "$ROOTLOGDIR"/"$MASTERERLOGNAME
rsync $OPT $SRC $TRG > $ROOTLOGDIR/$MASTERLOGNAME 2> $ROOTLOGDIR/$MASTERERLOGNAME
ARBORRETURN=$?

#7 days ago in ISO-8601 format
DAY7=`date -I -d "7 days ago"`
strpt

#Delete the backup from 7 days ago, if it exists
echo "Looking for files in "$ARPTHBACKDIR
echo "Named "$ARPTHBACKDIR/$DAY7
if [ -d $ARPTHBACKDIR/$DAY7 ]
        then
                echo $ARPTHBACKDIR/$DAY7 " exist: removing"
        rm -rf $ARPTHBACKDIR/$DAY7
                OUT=$?
        echo "Return Code = "$OUT
        if [ $OUT -eq 0 ];then
                echo "Backup cleanup was successful!"
        else
                echo "Backup cleanup for $BACKUPNAME failed"
                exit $OUT
strpt_update
        fi
else
        echo $ARPTHBACKDIR/$DAY7 " Does not exist..."
strpt_update
fi
#Compare the ARVORPATH with the files that are in the backup directory to make sure we have them all
cd $ARBORPATH
# Set up report header
export outfilepath=/global/ora_backup/file_compare
export difffile=files_not_in_sync.rtf
echo "Differences between ARBORPATH "$outfilepath"/"$arboutfile" and BACKUP DIRECTORY "$outfilepath"/"$backoutfile > $outfilepath"/"$difffile
# Get a listing of all file extensions
for file in `find . -type f | perl -ne 'print $1 if m/\.([^.\/]+)$/' | sort -u`
   do
   # Loop through the ARBORPATH and get the number of files per extension and a list of them
   cd $ARBORPATH
   echo ""
   echo "File extension = "$file
   echo "Number of files for this extention in "$ARBORPATH" is"
   find . -name '*.'$file | wc -l
   export arboutfile=$file".arborpath.filelisting.txt"
   export backoutfile=$file".backup.filelisting.txt"
   echo "Listing out all the files of type "$file" in "$outfilepath"/"$arboutfile
   find . -name '*.'$file | sort -u > $outfilepath"/"$arboutfile
   # Loop through the Backup Target directory and get the number of files per extension and a list of them
   cd $TRG
   echo "Number of files for this extention in Backup Directory "TRG" is"
   find . -name '*.'$file | wc -l
   echo "Listing out all the files of type "$file" in "$outfilepath"/"$backoutfile
   find . -name '*.'$file | sort -u > $outfilepath"/"$backoutfile
# Compare the output of the files
   cd $outfilepath
   echo "--------------------------------------------------------------------"
   echo "Differences between ARBORPATH "$outfilepath"/"$arboutfile" and BACKUP DIRECTORY "$outfilepath"/"$backoutfile 
      DIFF=`diff $outfilepath"/"$arboutfile $outfilepath"/"$backoutfile`
   if [ "$DIFF" != "" ]; then
      diff $outfilepath"/"$arboutfile $outfilepath"/"$backoutfile
	  diff $outfilepath"/"$arboutfile $outfilepath"/"$backoutfile >> $outfilepath"/"$difffile
   else 
      echo "THERE ARE NO DIFFERENCES !"
   fi
   echo "--------------------------------------------------------------------"
   done
if [ -s $ROOTLOGDIR/$MASTERERLOGNAME ] && [ $ARBORRETURN != "24" ]; then
    echo "-------------------------------------------------------------------------------------------------"
    echo "ARBORPATH backup for $BACKUPNAME failed with the following error "
    cat $ROOTLOGDIR/$MASTERERLOGNAME
    export MAILBODY=`cat $ROOTLOGDIR/$MASTERERLOGNAME`
    export MAILSUBJECT="<CRITICAL> essbase_master.sh failed ARBORPATH backup for "$BACKUPNAME" failed with the following error"
    export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
    echo "Sending mwh error mail message 1"
    MailMessage
    echo "-------------------------------------------------------------------------------------------------"
    exit $OUT
else
   echo "ARBORPATH backup was successful!"
#   echo "Mailing errorfile ..."
   echo "******************************************************************"
   echo "DISABLED EMAIL FOR ERROR FILE PLEASE CHECK "$outfilepath"/"$difffile
   echo "******************************************************************"
   export MAILBODY="<INFO> ARBORPATH backup was successful! <Action> Please review the log to determine if any files did not get copied, All Logs for this run are in $ROOTLOGDIR/$MASTERLOGNAME and $ROOTLOGDIR/$MASTERERLOGNAME"
   export MAILSUBJECT="<INFO> ARBORPATH backup was successful! summary information"
   export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
#   ( echo $MAILBODY ; /usr/bin/uuencode $outfilepath"/"$difffile $outfilepath"/"$difffile ) | mailx -s "$MAILSUBJECT" "$MAILLIST"
fi
strpt_update
}

function strpt()
{
export DATE=`date +%Y-%m-%d`
echo "DATE= "$DATE
export DATE1=`date --date='1 day ago' +%Y-%m-%d`
export DATESTAMP=`date +%Y-%m-%d-%H%M`
#export DATE1=`date +%Y-%m-%d`
echo "DATE1= "$DATE1
if [[ "$ENV_NAME" = "dev-xlytwv02-pub" && "$OSUSER" = "hyperion" ]]; then
#export ENV="DEV"
export ENV=$ENVIRONMENT
elif [[ "$ENV_NAME" = "xlytwv02-pub" && "$OSUSER" = "oracle" ]]; then
#export ENV="QA"
export ENV=$ENVIRONMENT
elif [[ "$ENV_NAME" = "xlytwv01-pub" && "$OSUSER" = "oracle" ]]; then
#export ENV="QA"
export ENV=$ENVIRONMENT
elif [[ "$ENV_NAME" = "xlythq01-pub" && "$OSUSER" = "oracle" ]]; then
#export ENV="PROD"
export ENV=$ENVIRONMENT
elif [[ "$ENV_NAME" = "xlythq02-pub" && "$OSUSER" = "oracle" ]]; then
#export ENV="PROD"
export ENV=$ENVIRONMENT
elif [[ "$ENV_NAME" = "cphypargq" && "$OSUSER" = "oracle" ]]; then
#export ENV="BRKFIX"
export ENV=$ENVIRONMENT
elif [[ "$ENV_NAME" = "pj-xlytwv01-pub" && "$OSUSER" = "hyppj" ]]; then
export ENV=$ENVIRONMENT
fi

echo "In strpt"
echo "-----------------------------------"

#if [[ ! -s "/hyp_util/output/status_"$DATE".txt" ]] && [[ "$DATE" = "$DATE1" ]] ; then
#echo "ENV,BACKUP_TYPE,APP,DB,STATUS,START_TIME,STOP_TIME,SIZE,ERROR" >> /hyp_util/output/status_"$DATE".txt
#chmod 777 /hyp_util/output/status_"$DATE".txt
#echo "date is $DATE"
#echo "date is $DATE1"
#else
#echo "dates are different or the file already exists with $DATE"
#Y#echo "ENV,BACKUP_TYPE,APP,DB,STATUS,START_TIME,STOP_TIME,SIZE,ERROR" >> /hyp_util/output/status_"$DATE".txt
#echo "$ENV_NAME,$BACKTYPE,$APP,$DB,,$DATESTAMP,$DATESTAMP" >>/hyp_util/output/status_"$DATE".txt
#fi

if [[ "$APPBKTYPE" = "ESSFULLBACKUP" ]] || [[ "$APP" = "" ]] ; then
export SIZE="FULLFS"
else
{
cd $ARBORPATH/app
export SIZE=`du -sh $APP | awk {'print $1'}`

#Y#export x=$SIZE
#Y#export numval=`echo "${x%?}"`
#Y#export isgig=`echo "$SIZE" | sed -e "s/^.*\(.\)$/\1/"`
#Y#
#Y#  if [[ "$ISGIG" == "G" ]]; then
#Y# export $SIZE
#Y#  else
#Y#  {
#Y#    gnumval=`expr $numval \\/ 1024`
#Y#    export gnumval
#Y#    SIZE=`echo "$gnumval" | echo "$isgig"`
#Y#    export SIZE = "$SIZE"
#Y#  }
#Y#  fi

}
fi

#ESS_RTN_CODE need to add it with out to compare the result
## Add the insert here for the "in progress" status and change the orig insert to update with the new status

export STATUS="IN PROGRESS"
echo "$STATUS"
echo "$APPBKTYPE"
echo "$LCMEXP"
echo "$BACKUPFILENAME"

if [ -n "$APPBKTYPE" ] ; then
case $APPBKTYPE in
MWHOME|LCMEXP|LCMBACKUP) export DB_MODE="LOADED" ;;
ESSARCDBBACKUP|ESSARCDBBACKUPNODATA|EXP|CONSOLEXP|CONSOL) export DB_MODE="READ_ONLY";;
NODATA|ESSDBBACKUPNODATA|FULL|CONSOLNODATA) export DB_MODE="UNLOADED";;
ESSFULLBACKUP) export DB_MODE="DOWN";;
esac
else
case $LCMEXP in
LCMEXP|LCMBACKUP) export DB_MODE="LOADED" ;;
esac
fi

#export ERROR=`cat $ROOTLOGDIR/$ERRLOGNAME`

#chmod 777 /hyp_util/output/status_"$DATE".txt
#cat /dev/null > /hyp_util/output/status_"$DATE".txt
#chmod 777 /hyp_util/output/status_"$DATE".txt
#echo "$ENV,$APPBKTYPE,$DB,$APP,$STATUS,$DATESTAMP,$DATESTAMP,$SIZE,$ERROR" >> /hyp_util/output/status_"$DATE".txt

if [ -z "$APPBKTYPE" ] ; then
#cd
#. /home/oracle/hypepmbf.env
#. /home/hyperion/accelatis.env
. $DBCLIENT_ENV
#sqlldr userid=capacity/capacity@HYPEPMBF control=/global/ora_backup/scripts/status.ctl log=/global/ora_backup/scripts/status_ldr.log
#sqlplus -s / as sysdba << EOF >$ROOTLOGDIR/insert_$APPBKTYPE_$DATESTAMP.log
sqlplus -s apex_hyperion/QyUx5sUdtm@APEXPROD << EOF >$ROOTLOGDIR/insert_$APPBKTYPE_$DATESTAMP.log
insert into BACKUP_STATUS values ('$ENV','$BACKUPNAME','$APP','$DB','$STATUS',to_date('$DATESTAMP','YYYY-MM-DD-hh24mi'),'','$SIZE','$ERROR','$DB_MODE');
--insert into BACKUP_STATUS values ('$ENV','$BACKUPNAME','$APP','$DB','$STATUS','$DATESTAMP','','$SIZE','$ERROR','$DB_MODE');
commit;
EOF
elif [[ -n "$APPBKTYPE" && "$APPBKSTEP" != "beginArchive" && "$APPBKSTEP" != "expConsolDB" ]] ; then
#cd
#. /home/oracle/hypepmbf.env
#. /home/hyperion/accelatis.env
. $DBCLIENT_ENV
#sqlldr userid=capacity/capacity@HYPEPMBF control=/global/ora_backup/scripts/status.ctl log=/global/ora_backup/scripts/status_ldr.log
#sqlplus -s / as sysdba << EOF >$ROOTLOGDIR/insert_$APPBKTYPE_$DATESTAMP.log
sqlplus -s apex_hyperion/QyUx5sUdtm@APEXPROD << EOF >$ROOTLOGDIR/insert_$APPBKTYPE_$DATESTAMP.log
SET TERMOUT OFF
SET HEADING OFF
SET PAGESIZE 50000
SET LINESIZE 500
SET TRIMSPOOL OFF
SET WRAP OFF
SET FEEDBACK OFF
SET ECHO OFF
insert into BACKUP_STATUS values ('$ENV','$APPBKTYPE','$APP','$DB','$STATUS',to_date('$DATESTAMP','YYYY-MM-DD-hh24mi'),'','$SIZE','$ERROR','$DB_MODE');
--insert into BACKUP_STATUS values ('$ENV','$APPBKTYPE','$APP','$DB','$STATUS','$DATESTAMP','','$SIZE','$ERROR','$DB_MODE');
commit;
EOF
#Y#sleep 30s
##sleep 90s
elif [[ -n "$APPBKTYPE" && "$APPBKSTEP" = "beginArchive" ]] ; then
##elif [[ -n "$APPBKTYPE" && -n "$CONSOL_beginArchive_log" && -n "$BACKUPFILENAME" ]] ; then
. $DBCLIENT_ENV
export CONSOL_BKUPTYPE=NODATA
echo "variable for consol nodata$CONSOL_BKUPTYPE"
echo "loop1 with non-null APPBKTYPE and non-null BACKUPFILENAME" $BACKUPFILENAME $ARCLOGNAME
echo $CONSOL_beginArchive_log $ARCLOGNAME $CONSOLLOGDIR
#sqlldr userid=capacity/capacity@HYPEPMBF control=/global/ora_backup/scripts/status.ctl log=/global/ora_backup/scripts/status_ldr.log
#sqlplus -s / as sysdba << EOF >$ROOTLOGDIR/insert_$APPBKTYPE_$DATESTAMP.log
sqlplus apex_hyperion/QyUx5sUdtm@APEXPROD << EOF >$ROOTLOGDIR/insert_$APPBKTYPE_$DATESTAMP.log
SET TERMOUT OFF
SET HEADING OFF
SET PAGESIZE 50000
SET LINESIZE 500
SET TRIMSPOOL OFF
SET WRAP OFF
SET FEEDBACK OFF
SET ECHO OFF
insert into BACKUP_STATUS values ('$ENV','$APPBKTYPE$CONSOL_BKUPTYPE','$APP','$DB','$STATUS',to_date('$DATESTAMP','YYYY-MM-DD-hh24mi'),'','$SIZE','$ERROR','$DB_MODE');
--insert into BACKUP_STATUS values ('$ENV','$APPBKTYPE','$APP','$DB','$STATUS','$DATESTAMP','','$SIZE','$ERROR','$DB_MODE');
commit;
EOF
#elif [[ -n "$APPBKTYPE" || -z "$BACKUPFILENAME" ]] ; then
elif [[ -n "$APPBKTYPE" && "$APPBKSTEP" = "expConsolDB" ]] ; then
. $DBCLIENT_ENV
export CONSOL_BKUPTYPE=EXP
echo "variable for consol export$CONSOL_BKUPTYPE"
echo "loop2 with non-null APPBKTYPE and null BACKUPFILENAME" $BACKUPFILENAME $ARCLOGNAME
echo $CONSOL_beginArchive_log $LOGNAME $CONSOLLOGDIR
#sqlldr userid=capacity/capacity@HYPEPMBF control=/global/ora_backup/scripts/status.ctl log=/global/ora_backup/scripts/status_ldr.log
#sqlplus -s / as sysdba << EOF >$ROOTLOGDIR/insert_$APPBKTYPE_$DATESTAMP.log
sqlplus apex_hyperion/QyUx5sUdtm@APEXPROD << EOF >$ROOTLOGDIR/insert_$APPBKTYPE_$DATESTAMP.log
SET TERMOUT OFF
SET HEADING OFF
SET PAGESIZE 50000
SET LINESIZE 500
SET TRIMSPOOL OFF
SET WRAP OFF
SET FEEDBACK OFF
SET ECHO OFF
insert into BACKUP_STATUS values ('$ENV','$APPBKTYPE$CONSOL_BKUPTYPE','$APP','$DB','$STATUS',to_date('$DATESTAMP','YYYY-MM-DD-hh24mi'),'','$SIZE','$ERROR','$DB_MODE');
--insert into BACKUP_STATUS values ('$ENV','$APPBKTYPE','$APP','$DB','$STATUS','$DATESTAMP','','$SIZE','$ERROR','$DB_MODE');
commit;
EOF
#Y#sleep 30s
fi
}

function strpt_update()
{
echo "In strpt_update"
echo "-----------------------------------"
#. /home/oracle/hypepmbf.env
#. /home/hyperion/accelatis.env
. $DBCLIENT_ENV
#sqlldr userid=capacity/capacity@HYPEPMBF control=/global/ora_backup/scripts/status.ctl log=/global/ora_backup/scripts/status_ldr.log
export DATESTAMP=`date +%Y-%m-%d-%H%M`
#export WCOUNT=`grep WARNING $ROOTLOGDIR/$ERRLOGNAME | wc -l`
#export CONSOLWCOUNT=`grep WARNING $CONSOLLOGDIR/$ERRLOGNAME | wc -l`
export LCMCOUNT=`grep -i failures $ROOTLOGDIR/$LCMERRLOGNAME | wc -l`
#export DB_MODE="LOADED"
export UPDATEERRLOGNAME=update_$APPBKTYPE_$DATESTAMP.log
#chmod 777 $ROOTLOGDIR/$UPDATEERRLOGNAME ## AddedA
echo "backup file name"$BACKUPFILENAME


cd $ROOTLOGDIR
pwd
echo "Entering into if logic "
if [[ -s $MASTERERLOGNAME ]]; then
echo "Found the Master Logfile "$MASTERERLOGNAME
export ERROR=`tail $ROOTLOGDIR/$MASTERERLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
else
    if [[ -s $LCMERRLOGNAME && $LCMCOUNT -ge 1 ]]; then
        echo "Found the LCM Logfile "$LCMERRLOGNAME
export ERROR=`tail -1 $ROOTLOGDIR/$LCMERRLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
#Needed to add to check for CONSOL errors
##   elif [[ -s $CONSOLLOGDIR ]]; then
#   echo "In new consolidated code"
#   echo "Found the Consol Logfile "$CONSOLLOGDIR/$ERRLOGNAME
#   export ERROR=`tail $CONSOLLOGDIR/$ERRLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
# End v7 update
    elif [[ -s $ERRLOGNAME || -s $BEGERRLOGNAME || -s $ENDERRLOGNAME ]]; then
        echo "Found the ERRLOGNAME Logfile "$ROOTLOGDIR/$ERRLOGNAME
        echo "Found the BEGERRLOGNAME Logfile "$ROOTLOGDIR/$BEGERRLOGNAME
	echo "Found the ENDERRLOGNAME Logfile "$ROOTLOGDIR/$ENDERRLOGNAME
   export WCOUNT=`grep WARNING $ROOTLOGDIR/$ERRLOGNAME | wc -l`
   export ARCERROR=`grep ERROR $ROOTLOGDIR/$ERRLOGNAME | wc -l`
   export TRANSERROR=`grep 1013239 $ENDERRLOGNAME | wc -l`
   export ERROR=`tail $ROOTLOGDIR/$ERRLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
    elif [[ -s $ARCERRLOGNAME ]]; then
        echo "Found the ARCERRLOGNAME Logfile "$ROOTLOGDIR/$ARCERRLOGNAME
   export ERROR=`tail $ROOTLOGDIR/$ARCERRLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
   elif [[ -s $ENDERRLOGNAME ]]; then
   echo "Found the ENDERRLOGNAME Logfile "$ROOTLOGDIR/$ENDERRLOGNAME
   export ERROR=`tail $ROOTLOGDIR/$ENDERRLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
   elif [[ -s $BEGERRLOGNAME && $BTRANSERROR -gt 1 ]]; then
         echo "Found the BEGERRLOGNAME Logfile "$ROOTLOGDIR/$BEGERRLOGNAME
     export ERROR=`tail $ROOTLOGDIR/$BEGERRLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
   else
        export ERROR=''
   fi
fi

#cd $CONSOLLOGDIR
#if [[ -s $ERRLOGNAME ]]; then
#echo "In new consolidated code"
#echo "Found the Consol Logfile$ERRLOGNAME "
#export ERROR=`tail $ERRLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
#    if [[ -s $ARCERRLOGNAME ]]; then
#      echo "Found the CONSOL ARCERRLOGNAME Logfile $CONSOLLOGDIR/$ARCERRLOGNAME"
#      export ERROR=`tail $CONSOLLOGDIR/$ARCERRLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
#    fi
#fi

#export ERROR=`cat $ROOTLOGDIR/$LCMERRLOGNAME`
#echo "DATESTAMP= "$DATESTAMP
echo $LCMERRLOGNAME
echo "ERRLOGNAME is " $ERRLOGNAME
echo "ARCERRLOGNAME is " $ARCERRLOGNAME
echo "CONSOLLOGDIR is " $CONSOLLOGDIR
echo "MASTERERLOGNAME is " $MASTERERLOGNAME
echo "OPMNSTATUS is " $OPMNSTATUS
echo "BEGERRLOGNAME is " $BEGERRLOGNAME
echo "ENDERRLOGNAME is " $ENDERRLOGNAME


cd $ROOTLOGDIR
echo "current dir"
pwd
#if [[ "$APPBKTYPE" == "ESSFULLBACKUP" ]]; then
#  if [[ -f $ROOTLOGDIR/$ERRLOGNAME || -f $ROOTLOGDIR/$ARCERRLOGNAME || -f $ROOTLOGDIR/$MASTERERLOGNAME || $OPMNSTATUS = 'NORUN' ]]; then
  if [[ -s $ERRLOGNAME || -s $ARCERRLOGNAME || -s $MASTERERLOGNAME || $OPMNSTATUS = 'NORUN' || -s $ENDERRLOGNAME || -s $BEGERRLOGNAME  ]]; then
export STATUS="FAILED"
#elif [[ -s $ROOTLOGDIR/$ERRLOGNAME ]] ; then
  #PJ#   if [[ -s $ROOTLOGDIR/$ERRLOGNAME && $WCOUNT -ge 1 ]] ; then
     if [[ -s $ROOTLOGDIR/$ERRLOGNAME && $WCOUNT -ge 1 ]] ; then
      export STATUS="WARNING"
     fi
     if [[ -s $ROOTLOGDIR/$ERRLOGNAME && $ARCERROR -ge 1 ]] ; then
     export STATUS="FAILED"
     export DB_MODE="READ_ONLY"
     fi
      if [[ -s $ENDERRLOGNAME && $TRANSERROR -ge 1 ]] ; then
      export STATUS="FAILED"
     fi
     if [[ -s $BEGERRLOGNAME && $BTRANSERROR -ge 1 ]] ; then
       export STATUS="FAILED"
     fi
  else
export STATUS="SUCCESS"
export DB_MODE="LOADED"
  fi
#elif [[ -s $ROOTLOGDIR/$ERRLOGNAME || -s $ROOTLOGDIR/$ARCERRLOGNAME || -f $ROOTLOGDIR/$MASTERERLOGNAME || -z $OPMNSTATUS ]]; then

if [ -z "$APPBKTYPE" ]; then
  if [[ -s $LCMERRLOGNAME && $LCMCOUNT -ge 1 ]]; then
    export STATUS="FAILED"
  else
    export STATUS="SUCCESS"
  fi
fi

#cd $CONSOLLOGDIR
#echo "The console export logfile is "$CONSOLLOGDIR/$ERRLOGNAME
#if [[ -s $CONSOLLOGDIR/$ERRLOGNAME && $WCOUNT -ge 1 ]]; then
#export STATUS="WARNING"
#else
#export STATUS="SUCCESS"
#fi
#cd $CONSOLLOGDIR
#echo "current dir"
#pwd
#  if [[ -s $CONSOLLOGDIR/$ERRLOGNAME || -s $ROOTLOGDIR/$ARCERRLOGNAME ]]; then
#echo "In new consolidated code"
#echo "Found the Consol Logfile$ERRLOGNAME "
#export STATUS="FAILED"
#  else
#export STATUS="SUCCESS"
#  fi
#
#if [[ -s $CONSOLLOGDIR/$ERRLOGNAME && $CONSOLWCOUNT -ge 1 && "$APPBKSTEP" = "expConsolDB" ]] ; then
#      export STATUS="WARNING"
#fi


cd $CONSOLLOGDIR
echo "root dir is CONSOLLOGDIR:"$CONSOLLOGDIR
#if [[ -s $ERRLOGNAME && $CONSOLWCOUNT -ge 1 ]]; then
if [[ -s $ERRLOGNAME ]]; then
echo "In new consolidated code"
echo "Found the Consol Logfile$ERRLOGNAME "
export ERROR=`tail $CONSOLLOGDIR/$ERRLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
export CONSOLWCOUNT=`grep WARNING $CONSOLLOGDIR/$ERRLOGNAME | wc -l`
    if [[ -s $ARCERRLOGNAME ]]; then
      echo "Found the CONSOL ARCERRLOGNAME Logfile $CONSOLLOGDIR/$ARCERRLOGNAME"
      export ERROR=`tail $CONSOLLOGDIR/$ARCERRLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
   fi
      if [[ -s $ENBLCONERRLOGNAME ]]; then
    echo "Found the CONSOL enableconnect Errfile $CONSOLLOGDIR/$ENBLCONERRLOGNAME"
    export ERROR=`tail $CONSOLLOGDIR/$ENBLCONERRLOGNAME | sed 's/^ *//g' | sed '/^$/d'`
      fi
fi

if [[ -d $CONSOLLOGDIR ]]; then
cd $CONSOLLOGDIR
echo "current dir"
echo "errfile in consoldir: $CONSOLLOGDIR/$ERRLOGNAME"
echo "errfile in rootdir: $ROOTLOGDIR/$ERRLOGNAME"
pwd
  if [[ -s $ERRLOGNAME || -s $ARCERRLOGNAME || -s $ENBLCONERRLOGNAME ]]; then
echo "In new consolidated code"
echo "Found the Consol Logfile$ERRLOGNAME "
export STATUS="FAILED"
export DB_MODE="READ_ONLY"
#elif [[ -s $ROOTLOGDIR/$ERRLOGNAME ]] ; then
  #PJ#   if [[ -s $ROOTLOGDIR/$ERRLOGNAME && $WCOUNT -ge 1 ]] ; then
     ##if [[ -s $CONSOLLOGDIR/$ERRLOGNAME && $CONSOLWCOUNT -ge 1 ]] ; then
     if [[ -s $CONSOLLOGDIR/$ERRLOGNAME && $CONSOLWCOUNT -ge 1 ]] ; then
      export STATUS="WARNING"
     fi
  else
export STATUS="SUCCESS"
  fi
else
echo "Non-consol backup ran"
fi

cd $ROOTLOGDIR
if [[ -s $ENDERRLOGNAME ]]; then
export STATUS="FAILED"
export DB_MODE="READ_ONLY"
fi

echo "$DB"
echo "$ENV"
echo "$APPBKTYPE"
echo "$APP"
##select * from BACKUP_STATUS where STATUS='IN PROGRESS' and ENVRIONMENT_NAME='$ENV' and (APP_NAME='$APP' or APP_NAME is NULL) and (BACKUP_TYPE='$APPBKTYPE' or BACKUP_TYPE='$LCMEXP');
#sqlplus -s / as sysdba << EOF >$ROOTLOGDIR/$UPDATEERRLOGNAME
sqlplus  apex_hyperion/QyUx5sUdtm@APEXPROD << EOF >$ROOTLOGDIR/$UPDATEERRLOGNAME
SET TERMOUT OFF
SET HEADING OFF
SET PAGESIZE 50000
SET LINESIZE 500
SET TRIMSPOOL OFF
SET WRAP OFF
SET FEEDBACK OFF
SET ECHO ON
update BACKUP_STATUS set END_TIME=to_date('$DATESTAMP','YYYY-MM-DD-hh24mi'),STATUS='$STATUS',ERROR='$ERROR',DB_MODE='$DB_MODE' where STATUS='IN PROGRESS' and ENV_NAME='$ENV' and (APP_NAME='$APP' or APP_NAME is NULL) and (DB_NAME='$DB' or DB_NAME is NULL) and (BACKUP_TYPE='$APPBKTYPE$CONSOL_BKUPTYPE' or BACKUP_TYPE='$BACKUPNAME');
--update BACKUP_STATUS set END_TIME='$DATESTAMP',STATUS='$STATUS',ERROR='$ERROR',DB_MODE='$DB_MODE' where STATUS='IN PROGRESS' and ENV_NAME='$ENV' and (APP_NAME='$APP' or APP_NAME is NULL) and (DB_NAME='$DB' or DB_NAME is NULL) and (BACKUP_TYPE='$APPBKTYPE' or BACKUP_TYPE='$BACKUPNAME');
commit;
EOF

UPDATEERRCOUNT=`grep ORA- $ROOTLOGDIR/$UPDATEERRLOGNAME | wc -l`

if [[ $UPDATEERRCOUNT -ge 1 ]]; then
export MAILBODY=`tail -10 $ROOTLOGDIR/$UPDATEERRLOGNAME`
export MAILSUBJECT="Table load for "$ENV" "$APPBKTYPE" "$LCMEXP" failed" ##Added
export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
MailMessage
fi

chmod 777 $ROOTLOGDIR/$UPDATEERRLOGNAME ## AddedA

}

function CONSOL_EXPORT
{
		APPLICATION=$1
		APPDBNAME=$2
		echo "Executing the beginArchive function for the Consolidated Backup"
		export CONSOL_beginArchive_log=$CONSOLLOGDIR/beginArchive_${APPLICATION}_${APPDBNAME}.log
		beginArchive $APPLICATION ${APPDBNAME} >> $CONSOL_beginArchive_log	
		chmod 755 $CONSOL_beginArchive_log
		echo "Logfile for beginArchive"
		echo "-----------------------------------"
		cat $CONSOL_beginArchive_log
		echo "-----------------------------------"
		echo "Executing the CopyEssbaseDBNoData function for the Consolidated Backup in the background"
		export CONSOL_CopyEssbaseDBNoData_log=$CONSOLLOGDIR/CopyEssbaseDBNoData_${APPLICATION}_${APPDBNAME}.log
		CopyEssbaseDBNoDataConsol $APPLICATION ${APPDBNAME} >> $CONSOL_CopyEssbaseDBNoData_log &
		echo "Executing the expConsolDB function for the Consolidated Backup"
		export CONSOL_expConsolDB_log=$CONSOLLOGDIR/expConsolDB_${APPLICATION}_${APPDBNAME}.log 
		expConsolDB $APPLICATION ${APPDBNAME} >> $CONSOL_expConsolDB_log
}

function MailErr ()
{

export $DATESTAMP=`date +%Y-%m-%d-%H%M`
export $SENDERRBKUP=/global/ora_backup/log/mailerr_$DATESTAMP.log

#sqlplus -s / as sysdba << EOF >$SENDERRBKUP
sqlplus -s apex_hyperion/QyUx5sUdtm@APEXPROD << EOF >$SENDERRBKUP
SET TERMOUT OFF
SET HEADING OFF
SET PAGESIZE 50000
SET LINESIZE 500
SET TRIMSPOOL OFF
SET WRAP OFF
SET FEEDBACK OFF
SET ECHO OFF
select * from BACKUP_STATUS where STATUS != "SUCCESS";
EOF

if [[ -s $SENDERRBKUP ]]; then
export MAILBODY=`cat $SENDERRBKUP`
export MAILSUBJECT="<CRITICAL> $ENVIRONMENT $DATESTAMP failures"
export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY_ytest.txt`
fi

}

# Main
if [ $# -ne 2 ]
then
        echo "You entered Parameter 1 = "$1
		echo "You entered Parameter 2 = "$2
        echo "Usage: $0 environment_name BACKTYPE "
		ErrorExit "essbase_master.sh Usage: $0 environment_name BACKTYPE, Error on line: $LINENO"
fi

echo "Beginning script"
echo ""
export ENV_NAME=$1
echo "Environment Name is "$ENV_NAME
export BACKTYPE=$2
echo "Backup type is "$BACKTYPE
#NR - Added variable for LCM Rerun
export LCM_RSTATUS=0
# Check if backup type is level 0 export
#export LEVOEXP=`echo $BACKTYPE | cut -f1 -d_`
#echo 'LEVOEXP= '$LEVOEXP
export DATE=`date +%Y-%m-%d`
export EXP_RERUN_FILE=$ROOTLOGDIR/Export_Rerun_Status_"$HOSTNAME"_"$DATE".txt
export EXP_FAIL_FILE=$ROOTLOGDIR/Export_Failure_"$DATE".txt
SetupEnv

CheckSpace


if [[ $CLUSTER = 'CLU' ]]; then
	echo "Identified that this is a cluster getting cluster info."
	EssbaseStatus
	id_cluster
else 
   echo "This is not a cluster ."
fi
if [[ $APPBKTYPE = 'EXP' ]]; then
   echo 'Beginning Level 0 backup for '$APP'.'$DB
	Ess_serv_status
   getEssbaseSession
   sessionRunning
   export MAILBODY="Export has begun, application "$APP" will be in read only mode"
   export MAILSUBJECT="<INFO> Application 11.1.2 export for Application "$APP
   export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
# 	Uncomment to send start mail
#   MailMessage
   expDB
   export MAILSUBJECT="<INFO> Application 11.1.2 export for Application "$APP
   export MAILBODY="Export has completed, application "$APP" is now available"
   MailMessage
   echo "DR setting is (If it says DR it is on)"$DRBAK
   echo "----------------------------------------------------------------------------------------------------"
   if [[ $DRBAK = 'DR' ]]; then
      echo "This is a DR backup copying the export file to the DR directory ..."
      CopyExpBackupToDR
   else
      echo "This is not a DR backup"
   fi
 else
 echo "Not a level 0 backup"
fi

if [[ $APPBKTYPE = 'ESSFULLBACKUP' ]]; then
   echo 'Beginning Full Filesystem backup'
   EssbaseStatus
   if [[ $ISCLUSTER = 'CLU' ]]; then
   echo "Calling setAllCLuInfo"
   setAllCLuInfo
   getEssbaseSession
   sessionRunning
   export MAILBODY="Full Essbase offline backup has begun Essbase will be offline"
   export MAILSUBJECT="<INFO> Essbase full filesystem backup"
   export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
   echo "Calling mailMessage with "
   echo $MAILBODY
   echo $MAILLIST
   echo $MAILSUBJECT
# 	Uncomment to send start mail
#   MailMessage
   echo "Calling stopEssbase"
   stopEssbase
   # Since this is a full backup both clusters will be backed up so we will set the BACKCLU variable and back up that ARBORPATH
   export BACKCLU=$CLUSTER1
   echo "Running backup for cluster "$BACKCLU
   echo "-------------------------------------------------------------------------------------------------"
#    Set the environment for the cluster, check the host first
   if [[ $HOST = $CLUSTER1_PRIMARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the active essbase server running locally ..."
	  echo "Running environment file "$CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
	. $CLUSTER1_PRIMARY_ESSBASE_ENV_FILE
    else 
      echo "This host is home of the passive essbase server running locally ..."
	  echo "Running environment file "$CLUSTER1_SECONDARY_ESSBASE_ENV_FILE
	 . $CLUSTER1_SECONDARY_ESSBASE_ENV_FILE
    fi
   sleep 90
   CopyEssbaseFull
   export BACKCLU=$CLUSTER2
   echo "Running backup for cluster "$BACKCLU
   echo "-------------------------------------------------------------------------------------------------"
# Set the environment for the cluster, check the host first
   if [[ $HOST = $CLUSTER2_PRIMARY_ESSBASE_SERVER ]]; then
      echo "This host is home of the active essbase server running locally ..."
	  echo "Running environment file "$CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
	  . $CLUSTER2_PRIMARY_ESSBASE_ENV_FILE
   else 
      echo "This host is home of the passive essbase server running locally ..."
	  echo "Running environment file "$CLUSTER2_SECONDARY_ESSBASE_ENV_FILE
	  . $CLUSTER2_SECONDARY_ESSBASE_ENV_FILE
   fi
   CopyEssbaseFull
   startEssbase
   export MAILSUBJECT="<INFO> Essbase full filesystem backup"
   export MAILBODY="Full Essbase offline backup has completed Essbase is available"
# 	Uncomment to send Completion Success mail
#   MailMessage
elif [[ $ISCLUSTER = 'NOCLU' ]]; then
   echo "Calling stopEssbaseNONCLU"
   echo "Stopping Essbase in a NON Cluatered install"
   stopEssbaseNONCLU
   echo "Dont freak out sleeping to make sure it is down before the copy"
   sleep 90
# Setting backup directory to clustername.  Since this is not clustered use the logical name of the essbase server.  
# This is only to put it into a directory with this same name un=der the backup root directory
   export BACKCLU=$APPCLU
   CopyEssbaseFull
   StartEssbaseNONCLU
   export MAILSUBJECT="<INFO> Essbase full filesystem backup"
   export MAILBODY="Full Essbase offline backup has completed Essbase is available"
# 	Uncomment to send Completion Success mail
#   MailMessage
else
   echo "Please check the controlfile and indicate whether this is a clustered or nonclustered full backup"
fi
else
 echo "Not a full backup"
fi

if [[ $ESSBACK = 'ESSAPPBACKUP' ]]; then
   echo 'Beginning Application backup'
   if [[ $APPBKTYPE = 'FULL' ]]; then
      EssbaseStatus
	  getEssbaseSession
	  sessionRunning
	  export MAILBODY="Full Application backup has begun for Application "$APP" will be offline"
      export MAILSUBJECT="<INFO> Full Application backup for "$APP
      export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
      echo "Calling mailMessage with "
      echo $MAILBODY
      echo $MAILLIST
      echo $MAILSUBJECT
      MailMessage
      stopApplication
      CopyEssbaseAppFull
      StartApplication
	  export MAILBODY="Full Application backup has completed for Application "$APP" is available"
# 	Uncomment to send Completion Success mail
#   MailMessage
	  if [[ $TOSTAGE = "STAGE" ]]; then
	     CopyBackupToNAS
	  else
	     echo "Backup was written directly to the NAS no copy needed"
	  fi
   elif [[ $APPBKTYPE = 'NODATA' ]]; then
      EssbaseStatus
	  getEssbaseSession
	  sessionRunning
	  export MAILBODY="Application artifact backup has begun for Application "$APP" will be offline"
      export MAILSUBJECT="Application artifact backup for "$APP
      export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
      echo "Calling mailMessage with "
      echo $MAILBODY
      echo $MAILLIST
      echo $MAILSUBJECT
	  MailMessage
      stopApplication
      CopyEssbaseAppNoData
      StartApplication
	  export MAILSUBJECT="<INFO> Application backup for "$APP
	  export MAILBODY="Application artifact backup has completed for Application "$APP" is available"
# 	Uncomment to send Completion Success mail
#   MailMessage
	  echo "----------------------------------------------------------------------------------------------------"
	  if [[ $DRBAK = 'DR' ]]; then
         echo "This is a DR backup copying the backup file to the DR directory ..."
         CopyBackupToDR
      else
         echo "This is not a DR backup"
      fi
   elif [[ $APPBKTYPE = 'OTL' ]]; then
      echo "Need to create outline only backup option"
   elif [[ $APPBKTYPE = 'CONSOL' ]]; then
      echo "Doing an Consolidated backup with no data or index files in Archive mode and a level 0 export of "$APP"."$DB
	Ess_serv_status
      EssbaseStatus
	  getEssbaseSession
	  sessionRunning
#	  beginArchive
# Create a directory in the logs directory to house the following logs because running them in the background gets messy in stdout
# Redirect the output to the log directory and cat it all out
      echo "----------------------------------------------------------------------------------------------------"
	  echo "The main root log directory is "$ROOTLOGDIR
	  echo "Create a directory for the Consolidated backups "
	  mkdir $ROOTLOGDIR/$ENVIRONMENT"_ESS_APP_BACKUP_CONSOL_"$APPLICATION"_"$DATESTAMP
	  export CONSOLLOGDIR=$ROOTLOGDIR/$ENVIRONMENT"_ESS_APP_BACKUP_CONSOL_"$APPLICATION"_"$DATESTAMP
	  echo "Created a directory for the Consolidated backups "$CONSOLLOGDIR
# Logic to run the filesystem backups and export backups all at once
# First we have to generate a list of variables from the application section of the controlfile
# This is a list of all the databases in the application, all these variables should be prefixed by DB
# Looping through a list of variables i got from looking at all variables defined beginning with a DB(1..10)
# I then echo out the variable name and its value

for APPDBNAME in `compgen -A variable | grep ^DB[0-9]`
do
echo "-----------------------------------"
echo "Looping through the controlfile to get the Database Names for the Application "$APPLICATION
# Check to see if the database name is set or null
if [ -z "${!APPDBNAME}" ]; then
   echo "There are no other databases in this application"
else
echo "Variable name referred to as APPDBNAME in array = "$APPDBNAME
# This is a real goofy syntax what happens is i look through all the database variables, read the database variable into APPDBNAME
# The value for that is ${!APPDBNAME} is the actual database nanme
echo "Variable value "${!APPDBNAME} 
# If set run the backups
		echo "Begin backup routine"
		echo "-----------------------------------"
		echo "-----------------------------------"
		export CONSOL_LOG=$CONSOLLOGDIR/CONSOL_LOG_${APPLICATION}_${!APPDBNAME}.log
		CONSOL_EXPORT $APPLICATION ${!APPDBNAME} >> $CONSOL_LOG &
		sleep 20
fi
done
wait
 echo "-------------------------------------------------------------------------------------------------"
 echo "Logfiles for database copy"
 echo "-------------------------------------------------------------------------------------------------"
 cat $CONSOLLOGDIR/CopyEssbaseDBNoData*.log
 echo "-------------------------------------------------------------------------------------------------"
 echo "Logfiles for exports"
 echo "-------------------------------------------------------------------------------------------------"
 cat $CONSOLLOGDIR/expConsolDB*.log
for APPDBNAME in `compgen -A variable | grep ^DB[0-9]`
do
echo "-----------------------------------"
echo "Looping through the controlfile to get the Database Names for the Application "$APPLICATION
# Check to see if the database name is set or null
if [ -z "${!APPDBNAME}" ]; then
   echo "There are no other databases in this application"
else
echo "Variable name referred to as APPDBNAME in array = "$APPDBNAME
# This is a real goofy syntax what happens is i look through all the database variables, read the database variable into APPDBNAME
# The value for that is ${!APPDBNAME} is the actual database nanme
echo "Variable value "${!APPDBNAME} 
# End the Archive process
echo "Executing the endArchive function for the Consolidated Backup"
export CONSOL_endArchive_log=$CONSOLLOGDIR/endArchive_${APPLICATION}_${!APPDBNAME}.log
endArchive $APPLICATION ${!APPDBNAME} >> $CONSOL_endArchive_log
	  echo "Logfile for endArchive"
	  echo "-----------------------------------"
	  cat $CONSOL_endArchive_log
fi
done
wait
echo "Executing the enableConnect function for the Consolidated Backup"
enableConnect 
#	  >> $CONSOLLOGDIR/enableConnect_${APPLICATION}_${DB1}.log
	  echo "Contents of "$CONSOLLOGDIR/enableConnect_${APPLICATION}_${DB1}.log
#	  cat $CONSOLLOGDIR/enableConnect_${APPLICATION}_${DB1}.log
	  if [[ $TOSTAGE = "STAGE" ]]; then
	     CopyBackupToNAS &
	  else
	     echo "Backup was written directly to the NAS no copy needed"
	  fi
	  
# Copy archive file to backup area
	  echo "----------------------------------------------------------------------------------------------------"
	  echo "Original Archive file is "
	  echo $ESSARCHDIR/$APP.$DB.$DATESTAMP.arc
	  export BACKUPDIR=$ROOTBACKDIR/$APPCLU
	  echo "BACKUPDIR is set to "$BACKUPDIR
      echo "Copying archive file "$ESSARCHDIR/$APP.$DB.$DATESTAMP.arc" to "$BACKUPDIR" to make sure it is with the backup file"
      #cp $ESSARCHDIR/$APP.$DB.$DATESTAMP.arc $BACKUPDIR
       find $ESSARCHDIR/$APP.$DB.*.arc -type f -user $OSUSER -exec mv {} $BACKUPDIR \;
	  echo "For restore please use both of these files ..."
#	  ls -ltr $BACKUPDIR/*$APP.*.$DATESTAMP.*
	  echo "----------------------------------------------------------------------------------------------------"
#	  expDB
      export MAILSUBJECT="<INFO> Application 11.1.2 export for Application "$APP
      export MAILBODY="Export has completed, application "$APP" is now available"
# 	Uncomment to send Completion Success mail
#   MailMessage
   else 
      echo "Invalid backup option for Application Backup"
	  ErrorExit "essbase_master.sh Invalid backup option for Application Backup: $LINENO"
   fi
 echo "Not an Application Backup"
fi
if [[ $APPBKTYPE = 'ESSARCDBBACKUP' ]]; then
   echo "Doing an database backup in Archive mode of "$APP"."$DB
      EssbaseStatus
	  getEssbaseSession
	  sessionRunning
	  beginArchive
#      stopApplication
      CopyEssbaseDBFull
	  if [[ $TOSTAGE = "STAGE" ]]; then
	     CopyBackupToNAS
	  else
	     echo "Backup was written directly to the NAS no copy needed"
	  fi
#      StartApplication
      endArchive
	  echo "----------------------------------------------------------------------------------------------------"
	  echo "Original Archive file is "
	  echo $ESSARCHDIR/$APP.$DB.$DATESTAMP.arc
      echo "Copying archive file "$ESSARCHDIR/$APP.$DB.$DATESTAMP.arc" to "$BACKUPDIR" to make sure it is with the backup file"
      #cp $ESSARCHDIR/$APP.$DB.$DATESTAMP.arc $BACKUPDIR
       find $ESSARCHDIR/$APP.$DB.*.arc -type f -user $OSUSER -exec mv {} $BACKUPDIR \;
	  echo "For restore please use both of these files ..."
	  ls -ltr $BACKUPDIR/*$APP.*.$DATESTAMP.*
	  echo "----------------------------------------------------------------------------------------------------"
	  if [[ $DRBAK = 'DR' ]]; then
         echo "This is a DR backup copying the backup file to the DR directory ..."
		 CopyBackupToDR
      else
         echo "This is not a DR backup"
      fi
fi
if [[ $APPBKTYPE = 'ESSARCDBBACKUPNODATA' ]]; then
   echo "Doing an database backup with no data or index files in Archive mode of "$APP"."$DB
      EssbaseStatus
	  getEssbaseSession
	  sessionRunning
	  beginArchive
#      stopApplication
      CopyEssbaseDBNoData
	  if [[ $TOSTAGE = "STAGE" ]]; then
	     CopyBackupToNAS
	  else
	     echo "Backup was written directly to the NAS no copy needed"
	  fi
#      StartApplication
      endArchive
# Copy archive file to backup area
	  echo "----------------------------------------------------------------------------------------------------"
	  echo "Original Archive file is "
	  echo $ESSARCHDIR/$APP.$DB.$DATESTAMP.arc
      echo "Copying archive file "$ESSARCHDIR/$APP.$DB.$DATESTAMP.arc" to "$BACKUPDIR" to make sure it is with the backup file"
      #cp $ESSARCHDIR/$APP.$DB.$DATESTAMP.arc $BACKUPDIR
       find $ESSARCHDIR/$APP.$DB.*.arc -type f -user $OSUSER -exec mv {} $BACKUPDIR \;
	  echo "For restore please use both of these files ..."
	  ls -ltr $BACKUPDIR/*$APP.*.$DATESTAMP.*
	  echo "----------------------------------------------------------------------------------------------------"
	  if [[ $DRBAK = 'DR' ]]; then
         echo "This is a DR backup copying the backup file to the DR directory ..."
		 CopyBackupToDR
      else
         echo "This is not a DR backup"
      fi
fi
if [[ $LCMEXP = 'LCMBACKUP' ]]; then
   echo 'Beginning LCM Export'
   runLCM
else
 echo "Not a LCM Export"
fi
if [[ $APPBKTYPE = 'MWHOME' ]]; then
        echo "Beginning Middleware Home backup for $BACKUPNAME"
        export MAILBODY="Middleware Home backup has begun for "$BACKUPNAME""
        export MAILSUBJECT="<INFO> Middleware Home backup for "$BACKUPNAME
        export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
# 	Uncomment to send Start Success mail
#   MailMessage
        bkpMWH
        export MAILSUBJECT="<INFO> Middleware Home backup for "$BACKUPNAME
        export MAILBODY="Middleware Home backup has completed for "$BACKUPNAME""
# 	Uncomment to send Completion Success mail
#   MailMessage
else
        echo "Not a Middleware Home backup"
fi
if [[ $APPBKTYPE = 'ARPTH' ]]; then
        echo "Beginning ARBORRPATH backup for $BACKUPNAME"
        export MAILBODY="ARBORRPATH backup has begun for "$BACKUPNAME""
        export MAILSUBJECT="<INFO> ARBORRPATH backup for "$BACKUPNAME
        export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
# 	Uncomment to send StartSuccess mail
#   MailMessage
        bkpARB
        export MAILSUBJECT="<INFO> ARBORRPATH backup for "$BACKUPNAME
        export MAILBODY="ARBORRPATH backup has completed for "$BACKUPNAME""
# 	Uncomment to send Completion Success mail
#   MailMessage
else
        echo "Not a ARBORRPATH backup"
fi
#CleanUp

if [[ $APPBKTYPE = 'CONSOL' || $APPBKTYPE = 'ESSARCDBBACKUP' || $APPBKTYPE = 'NODATA' || $APPBKTYPE = 'ESSARCDBBACKUPNODATA' ]]; then
echo "Adding tnd re-running the endArchive procedure again to re-run in case of the backup failiure"
sleep 1m
echo "Appbkuptye is " $APPBKTYPE
echo "starting to endarchive application '$APP.$DB' before exiting the script"
export ERRLOGNAME=$BACKUPNAME"_"$SERVER"_"endArchive.$DATESTAMP.err
for APPDBNAME in `compgen -A variable | grep ^DB[0-9]`
do
{
echo "-----------------------------------"
echo "Looping through the controlfile to get the Database Names for the Application "$APPLICATION
echo "Check to see if the database name is set or null"
   if [[ -z "${!APPDBNAME}" ]]; then
   echo "There are no other databases in this application"
  else
echo "Variable name referred to as APPDBNAME in array = "$APPDBNAME
echo "Variable value "${!APPDBNAME}
echo "Begin endarchive routine"
      echo "-----------------------------------"
      echo "Executing the rerun endarchive function for the the application"
      endArchive $APPLICATION ${!APPDBNAME} >> $CONSOLLOGDIR/endArchive_${APPLICATION}_${!APPDBNAME}_endrerun.log
          echo "Logfile for rerun endarchive"
          echo "-----------------------------------"
          cat $CONSOLLOGDIR/endArchive_${APPLICATION}_${!APPDBNAME}_endrerun.log
          echo "-----------------------------------"
echo "Endarchive complete"
  fi

if [ -s $LOGDIR/$ERRLOGNAME ]; then
   echo "-------------------------------------------------------------------------------------------------"
   echo "endarchive for $APPLICATION_$DB failed with the following error "
   cat $LOGDIR/$ERRLOGNAME
   export MAILBODY_OLD=`cat $LOGDIR/$ERRLOGNAME`
   export MAILBODY=`cat $MAILBODY_OLD $BKPRERUN_JOB`
   export MAILSUBJECT="<CRITICAL> essbase_master.sh failed to endArchive "$APP" with the following error"
   export MAILLIST=`cat /hyp_util/maillist/11.1.2_EMAIL_NOTIFY.txt`
   echo "Sending exp error mail message 1"
   MailMessage
   echo "-------------------------------------------------------------------------------------------------"
fi

}
done
fi

