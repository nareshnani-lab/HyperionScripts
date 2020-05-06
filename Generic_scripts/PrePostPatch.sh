#!/bin/sh

######################################################################################################
# Name: PrePostPatch.sh
# Purpose: This script handles the following,
#
#     1. OPatch Prerequiste checks to see if the patch planned to be applied is compatible
#
#     2. EPM backup: This option allows to handle backups directly through this script.     
#        Below options are available:
#        1. Cancel existing backup (Cloud control): Choose this option if you need to cancel an 
#           existing cloud control backup. Using emcli the job is rescheduled job to day + 1. 
#
#        2. Schedule a one time backup (Cloud control): Choose this option if you need to schedule
#           a one time backup before or after the regular scheduled one. Next screen would ask 
#           for user input on the schedule which should be in YYYY-MM-DD HH:MM:SS format 
#
#        3. Execute backup immediately from this server: Choose this option if any backup needs to
#           be executed immediately from this server. The next screen displays the job names available
#           for the environment and additional option to use essbase_master.sh in case the user needs
#           to execute individual jobs. The user should provide a valid job name from 
#           er_<nonprod>_controlfile.ctl when prompted in the next screen.
#
#        4. Execute backup immediately from Cloud control: Choose this option if you need to execute 
#           a backup immediately from Cloud control. The next screen displays all the available cloud 
#           control jobs. 
#
#        5. Last Execution status for Cloud control backup jobs: This option when chosen will fetch 
#           the last execution status of the jobs for the specific environment from cloud control.
#  
# Usage:  ./PrePostPatch.sh <ENV>
#        <ENV> = INFRA1 / INFRA2 / PJ / DEV / QA1 / QA2 / PROD1 / PROD2 / DR 
#
#	echo  "DB environment unknown. Execution format ./<script-name> <DB ENV> "
#	echo "<DB ENV> = INFRA_DB1 / INFRA_DB2 / PJ_DB1 / PJ_DB2 / DEV_DB1 / DEV_DB2 / QA_DB1 / QA_DB22 / PROD_DB1 / PROD_DB2 / DR_DB1 / DR_DB2 "
#
# Version: V2.0
# Change: Sep-17 - Refer documentation on connections
# http://connections.sherwin.com/communities/service/html/communityview?communityUuid=e1fd8841-12fc-40b0-85c4-8c4dcd253311#fullpageWidgetId=W334bc2519d36_496c_8138_133f2bb012fa&file=50d4eea0-7d7c-42b5-95c5-3033ad609a39
#
#
#
######################################################################################################


DateTime=`date +%d%m%y_%H%M%S`
Day=`date +%Y-%m-%d`
Day1=`date +%Y%m%d`
Fulldate=`date +%c`

export ENV=$1
export HOSTNAME=`hostname`
export OSUSER=`whoami`



export EMCLITEMPLATE=/hyp_util/controlfiles/PREPOST/emcli_templates
export PPLOGDIR=/hyp_util/logs/PREPOST/${ENV}
export OUTPUT=/hyp_util/output/PREPOST/${ENV}
export CTRLLOC=/hyp_util/controlfiles/PREPOST
#GENERIC LOCATION - SPECIFIC TO INFRA SET WHEN ENV IS LOADED#
export SCRIPTDIR=/hyp_util/scripts
export BACKUPDIR=/global/ora_backup
#export DBBACKUPDIR=/global/ora_backup/CPMTEXLW
export EMCLIHOME=/hyp_util/emcli
#export EMCLITEMPLATE=/hyp_util/scripts/INFRA/controlfiles/PREPOST/emcli_templates
#export CTRLLOC=/hyp_util/scripts/INFRA/controlfiles/PREPOST
#export summary_report=${PPLOGDIR}/${ENV}_PATCH_Summary_report_${CHNGID}_${Day}.html
#export master_log=${PPLOGDIR}/${ENV}_PATCH_Master_Log_${CHNGID}_${Day}.log

echo "####################################################################################################"
echo "`date`: START "
echo "####################################################################################################"


function buildPREREQ() {

echo ""
echo ""


	cat ${CTRLLOC}/planning_prereq_instructions.txt

	echo ""
	echo ""

	# Listing out all the Prepatching Activities in comments
	echo ""
	date
	read -p "If the above steps have already been performed, press 1 to Continue, 0 to Exit - " PROG
	if [ $PROG = '0' ]; then
		echo "----------"
		echo "Selection = ${PROG}, exiting script..."
		optionsScreen
	elif [ $PROG = '1' ]; then 	
		echo "Selection = ${PROG}"
		echo "----------"
		read -p "Please enter the patch numbers (if more than one patch, please seperate them by comma (,) - " PATCHNUM
		read -p "Please enter the server location where the patches are downloaded to - " PATCHLOC
	else
		echo "ERROR: Invalid option selected"
		echo "Exiting script"
		exit 1;
	fi
	
	
	read -p "DBA conducting this step (enter your sherwin id): " EMPID
	read -p "Enter the Change Log Request ID (if change log entry is not created, hit Enter): " CHNGID
	echo "DBA conducting this step is "$EMPID
	echo "Change Log request ID is "$CHNGID
	
	
	if [[ "x${CHNGID}" = "x" ]]; then
		echo "No change ID input for "$ENV
		
		export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_PREREQ_${EMPID}_${Day}.html
		export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report_PREPATCH_${EMPID}_${Day}.html
		export summary_report_backup=${PPLOGDIR}/${ENV}_PATCH_report_BACKUP_${EMPID}_${Day}.html
		export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_POSTPATCH_${EMPID}_${Day}.html
		export master_log_prereq=${PPLOGDIR}/${ENV}_PATCH_Master_Log_PREREQ_${EMPID}_${Day}.log
	else
		echo "Input file $INPUT_FILE sourced in for "$ENV
		echo "Change Log Request ID is "$CHNGID
		
		export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_PREREQ_${CHNGID}_${Day}.html
		export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report_PREPATCH_${CHNGID}_${Day}.html
		export summary_report_backup=${PPLOGDIR}/${ENV}_PATCH_report_BACKUP_${CHNGID}_${Day}.html
		export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_POSTPATCH_${CHNGID}_${Day}.html
		export master_log_prereq=${PPLOGDIR}/${ENV}_PATCH_Master_Log_PREREQ_${CHNGID}_${Day}.log
	fi

	
	echo "----------"
	echo "<br>" >> $summary_report_prereq 
	echo "<table border="1">" >> $summary_report_prereq  
	echo "<tr>" >> $summary_report_prereq  
	echo "     <td><b>DBA</b></td>" >> $summary_report_prereq  
	echo "	   <td>$EMPID</td>" >> $summary_report_prereq  
	echo "</tr>" >> $summary_report_prereq  
	echo "<tr>" >> $summary_report_prereq 
	echo "     <td><b>Step performed</b></td>" >> $summary_report_prereq  
	echo "	   <td>EPM OPatch Prerequisite Check</td>" >> $summary_report_prereq  
	echo "</tr>" >> $summary_report_prereq  
	echo "<tr>" >> $summary_report_prereq  
	echo "     <td><b>Date</b></td>" >> $summary_report_prereq  
	echo "	   <td>`date`</td>" >> $summary_report_prereq  
	echo "</tr>" >> $summary_report_prereq 
	echo "<tr>" >> $summary_report_prereq  
	echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_prereq  
	echo "	   <td>$CHNGID</td>" >> $summary_report_prereq	
	echo "</tr>" >> $summary_report_prereq 
	echo "<tr>" >> $summary_report_prereq  
	echo "     <td><b>Method</b></td>" >> $summary_report_prereq  
	echo "	   <td>Manual</td>" >> $summary_report_prereq  
	echo "</tr>" >> $summary_report_prereq 	
	echo "</table>" >> $summary_report_prereq  
	echo "<br>" >> $summary_report_prereq 
	echo "<br>" >> $summary_report_prereq 
	
	echo "#################################################################################################################################################" >> $master_log_prereq
	echo "DBA: $EMPID" >> $master_log_prereq
	echo "Step performed: OPatch Prerequisite Check" >> $master_log_prereq
	echo "Date: `date`" >> $master_log_prereq
	echo "Change Log Request ID: $CHNGID" >> $master_log_prereq
	echo "Method: Manual" >> $master_log_prereq
		
	
	
	export REFDateTime=`date +%d%m%y_%H%M%S`
	cd $EPM_ORACLE_HOME/OPatch/
	export PREREQ_DIR=${OUTPUT}/${ENV}_PREREQ_${REFDateTime}
	export USR_PREREQ_INPUT=${OUTPUT}/${ENV}_PREREQ_${REFDateTime}.cfg
	mkdir ${PREREQ_DIR}
	
	echo "DBA=$EMPID" > ${USR_PREREQ_INPUT}
	echo "PATCHNUM=$PATCHNUM" >> ${USR_PREREQ_INPUT}
	echo "PATCHLOC=$PATCHLOC" >> ${USR_PREREQ_INPUT}
	echo "----------"
	cat ${USR_PREREQ_INPUT}
	
	echo "<br>" >> $summary_report_prereq 
	echo "<b>OPatch Prequisite Check Activity </b>" >> $summary_report_prereq  
	echo "<table border="1">" >> $summary_report_prereq  
	echo "<tr>" >> $summary_report_prereq  
	echo "    <td><b>Patch Number(s)</b></th>" >> $summary_report_prereq 
	echo "    <td>$PATCHNUM</th>" >> $summary_report_prereq
	echo "</tr>" >> $summary_report_prereq  
	echo "<tr>" >> $summary_report_prereq  
	echo "    <td><b>Patch Location</b></td>" >> $summary_report_prereq 
	echo "    <td>$PATCHLOC</td>" >> $summary_report_prereq 
	echo "</tr>" >> $summary_report_prereq 	
	echo "</table>" >> $summary_report_prereq
	echo "<br>" >> $summary_report_prereq 	
	
	echo "OPatch Prequisite Check Activity " >> $master_log_prereq
	echo "    Patch Number(s): $PATCHNUM" >> $master_log_prereq
	echo "    Patch Location: $PATCHLOC" >> $master_log_prereq
	echo "#################################################################################################################################################" >> $master_log_prereq
	
	echo "Executing lsinventory command..."
	cd $EPM_ORACLE_HOME/OPatch/
	./opatch lsinventory -oh $EPM_ORACLE_HOME -jdk $MIDDLEWARE_HOME/jdk160_35 -invPtrLoc $EPM_ORACLE_HOME/oraInst.loc > ${PREREQ_DIR}/${ENV}_lsinventory.txt
				
	
	checkMulti=`echo $PATCHNUM | grep -o "," | wc -l`
	echo $PATCHNUM | sed 's/,/\n/g' > ${PREREQ_DIR}/${ENV}_Patch_numbers.txt
	if [ $checkMulti -eq 0 ]; then
		echo "Single patch to be applied"
		echo ${PATCHNUM}
		echo "TASK 1: Checking if the patch file ${PATCHNUM} is in the given patch location $PATCHLOC"
			fndPatch=`find ${PATCHLOC} -maxdepth 1 -name "*${PATCHNUM}*.zip"`
			find ${PATCHLOC} -maxdepth 1 -name "*${PATCHNUM}*.zip"
			ret=$?
			if [ $ret -eq 0 ]; then
				echo "Patch file $fndPatch present, unzipping it...."
				echo "unzip -o $fndPatch"
				cd $EPM_ORACLE_HOME/OPatch/
				unzip -o $fndPatch
				echo ""
				echo "TASK 2: Creating & executing Prereq script for patch $PATCHNUM"
				tmp_script=${PREREQ_DIR}/epm_opatch_prereq_tmp_${PATCHNUM}.sh
				new_script=${PREREQ_DIR}/epm_opatch_prereq_${PATCHNUM}.sh
				
				echo "<br>" >> $summary_report_prereq 
				echo "<b>OPatch Prequisite Check for patch ${PATCHNUM} </b>" >> $summary_report_prereq  
				echo "<table border="1">" >> $summary_report_prereq  
				echo "<tr>" >> $summary_report_prereq  
				echo "    <th>Timestamp</th>" >> $summary_report_prereq 
				echo "    <th>Prereq Check</th>" >> $summary_report_prereq
				echo "    <th>Status</th>" >> $summary_report_prereq 
				echo "    <th>Details</th>" >> $summary_report_prereq 
				echo "</tr>" >> $summary_report_prereq 		
				
				echo "OPatch Prequisite Check for patch ${PATCHNUM} " >> $master_log_prereq
				echo "Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
				echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
				
				
				echo "Checking the lsinventory to see if the patch is applied on the environment"
				grep -wi ${PATCHNUM} ${PREREQ_DIR}/${ENV}_lsinventory.txt > ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}.txt
				tret=$?
				if [[ $tret -eq 0 ]];then
					echo "$PATCHNUM present in lsinventory and already applied in this environment"
					echo ""
					cat ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}.txt
					mv ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}.txt ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}_present.txt
					
					echo "<tr>" >> $summary_report_prereq  
					echo "    <td>`date`</td>" >> $summary_report_prereq 
					echo "    <td>Check the patch in lsinventory</td>" >> $summary_report_prereq
					echo "    <td>Failure</td>" >> $summary_report_prereq 
					echo "    <td>The patch is already applied in the environment. Please verify</td>" >> $summary_report_prereq 
					echo "</tr>" >> $summary_report_prereq 
					echo "</table>" >> $summary_report_prereq
					echo ""
					echo " `date`|Check the patch in lsinventory | Failure     | The patch is already applied in the environment. Please verify" >> $master_log_prereq 
					echo "" >> $master_log_prereq 
					cat $master_log_prereq
					echo "Please verify the patch number, exiting the script now.."
					exit 1;
				else
					echo "$PATCHNUM not present in lsinventory, proceeding further..."
					echo ""
				fi
				
				
				cp ${CTRLLOC}/epm_opatch_prereq.sh $tmp_script
				export patchNN=$PATCHNUM
				eval "echo \"`cat $tmp_script`\"" > $new_script
				chmod +x $new_script
				cd ${PREREQ_DIR}
				. $new_script > ${new_script}.log
				ret=$?
				if [ $ret -eq 0 ]; then
					echo "PREREQ check script executed"
					echo ""
				else
					echo "PREREQ check script execution failed"
					echo ""
					echo "PREREQ check script execution failed" >> $master_log_prereq
					echo "" >> $master_log_prereq 
					cat $master_log_prereq
					exit 1;
				fi
				
				grep Prereq ${new_script}.log > ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log
				prereq_stat_SysSpace=`grep -wi checkSystemSpace ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
				prereq_stat_appliProduct=`grep -wi checkApplicableProduct ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
				prereq_stat_component=`grep -wi checkComponents ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
				prereq_stat_conDetail=`grep -wi checkConflictAmongPatchesWithDetail ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
				prereq_stat_appDepend=`grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
				prereq_stat_applica=`grep -wi checkApplicable ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
				prereq_stat_conOHDetail=`grep -wi checkConflictAgainstOHWithDetail ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
				prereq_stat_InputValues=`grep -wi checkForInputValues ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
				
				export prereq_status_tidy=${PREREQ_DIR}/PREREQ_status_${PATCHNUM}_tidy.log
				echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace" > ${prereq_status_tidy}
				echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct" >> ${prereq_status_tidy}
				echo "PREREQ:checkComponents:$prereq_stat_component" >> ${prereq_status_tidy}
				echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail" >> ${prereq_status_tidy}
				echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend" >> ${prereq_status_tidy}
				echo "PREREQ:checkApplicable:$prereq_stat_applica" >> ${prereq_status_tidy}
				echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail" >> ${prereq_status_tidy}
				echo "PREREQ:checkForInputValues:$prereq_stat_InputValues" >> ${prereq_status_tidy}
				
						
				for n in `cat ${prereq_status_tidy}`
				do
				prereq_chkk=`echo $n |cut -d":" -f2`
				prereq_chkk_stat=`echo $n |cut -d":" -f3`
				
					echo "<tr>" >> $summary_report_prereq  
					echo "    <td>`date`</td>" >> $summary_report_prereq 
					echo "    <td>${prereq_chkk}</td>" >> $summary_report_prereq
					echo "    <td>${prereq_chkk_stat}</td>" >> $summary_report_prereq 
					echo "    <td></td>" >> $summary_report_prereq 
					echo "</tr>" >> $summary_report_prereq
					
					echo "`date`|${prereq_chkk} | ${prereq_chkk_stat} | " >> $master_log_prereq 
										
				done
				
				if [ "$prereq_stat_SysSpace" = "passed." ]; then
					echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace"  
				elif [ "$prereq_stat_SysSpace" = " " ]; then	
					echo "PREREQ status is blank, please check"
					
				else
					echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details"
					echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi	
				
				if [ "$prereq_stat_appliProduct" = "passed." ]; then
					echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct"
				elif [ "$prereq_stat_appliProduct" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi
				
				if [ "$prereq_stat_component" = "passed." ]; then
					echo "PREREQ:checkComponents:$prereq_stat_component"
				elif [ "$prereq_stat_component" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi				
				
				if [ "$prereq_stat_conDetail" = "passed." ]; then
					echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail"
				elif [ "$prereq_stat_conDetail" = " " ]; then	
					echo "PREREQ status is blank, please check"
				else
					echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi
				
				if [ "$prereq_stat_appDepend" = "passed." ]; then
					echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend"
				elif [ "$prereq_stat_appDepend" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi
				
				if [ "$prereq_stat_applica" = "passed." ]; then
					echo "PREREQ:checkApplicable:$prereq_stat_applica"
				elif [ "$prereq_stat_applica" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi
				
				if [ "$prereq_stat_conOHDetail" = "passed." ]; then
					echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail"
				elif [ "$prereq_stat_conOHDetail" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi	
				
				if [ "$prereq_stat_InputValues" = "passed." ]; then
					echo "PREREQ:checkForInputValues:$prereq_stat_InputValues"
				elif [ "$prereq_stat_InputValues" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi	
				
				echo ""
				echo "PREREQ Checks successful"
				echo "<table border="1">" >> $summary_report_prereq  
				echo "PREREQ Checks successful" >> $master_log_prereq
				echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
						
			
			
			else
				echo "Unable to find patch file, please check the location"
				echo "Unable to find patch file, please check the location" >> $master_log_prereq
				cat $master_log_prereq
				exit 1;
			fi
	else
		echo "Multiple patches to be applied"
		cat ${PREREQ_DIR}/${ENV}_Patch_numbers.txt
		for i in `cat ${PREREQ_DIR}/${ENV}_Patch_numbers.txt`
		do
			echo $i
			echo "TASK 1: Checking the lsinventory to see if the patch is applied on the environment"
			grep -wi ${i} ${PREREQ_DIR}/${ENV}_lsinventory.txt > ${PREREQ_DIR}/${ENV}_lsinventory_${i}.txt
			tret=$?
				if [[ $tret -eq 0 ]];then
					echo "$i present in lsinventory and already applied in this environment"
					echo ""
					cat ${PREREQ_DIR}/${ENV}_lsinventory_${i}.txt
					mv ${PREREQ_DIR}/${ENV}_lsinventory_${i}.txt ${PREREQ_DIR}/${ENV}_lsinventory_${i}_present.txt
					
					echo "<br>" >> $summary_report_prereq 
					echo "<b>OPatch Prequisite Check for patch ${i}</b>" >> $summary_report_prereq  
					echo "<table border="1">" >> $summary_report_prereq  
					echo "<tr>" >> $summary_report_prereq  
					echo "    <th>Timestamp</th>" >> $summary_report_prereq 
					echo "    <th>Prereq Check</th>" >> $summary_report_prereq
					echo "    <th>Status</th>" >> $summary_report_prereq 
					echo "    <th>Details</th>" >> $summary_report_prereq 
					echo "</tr>" >> $summary_report_prereq 
					
					echo "<tr>" >> $summary_report_prereq  
					echo "    <td>`date`</td>" >> $summary_report_prereq 
					echo "    <td>Check the patch $i in lsinventory</td>" >> $summary_report_prereq
					echo "    <td>Failure</td>" >> $summary_report_prereq 
					echo "    <td>The patch $i is already applied in the environment. Please verify</td>" >> $summary_report_prereq 
					echo "</tr>" >> $summary_report_prereq
					echo "</table>" >> $summary_report_prereq
					echo "<br>" >> $summary_report_prereq
					
					echo "OPatch Prequisite Check for patch ${i} " >> $master_log_prereq
					echo " Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
					echo " `date`|Check the patch in lsinventory | Failure     | The patch is already applied in the environment. Please verify" >> $master_log_prereq 
					echo "" >> $master_log_prereq 
					echo ""
					echo "Please verify the patch number.."
				else
					echo "$i not present in lsinventory, proceeding further..."
					echo ""
					echo "TASK 2: Checking if the patch file $i is in the given patch location $PATCHLOC"
					fndPatch=`find ${PATCHLOC} -maxdepth 1 -name "*${i}*.zip"`
					find ${PATCHLOC} -maxdepth 1 -name "*${i}*.zip"
					ret=$?
					if [ $ret -eq 0 ]; then
						echo "Patch file $fndPatch present, unzipping it...."
						echo "unzip -o $fndPatch"
						cd $EPM_ORACLE_HOME/OPatch/
						unzip -o $fndPatch
						echo ""
						echo "TASK 2: Creating & executing Prereq script for patch $i"
						tmp_script=${PREREQ_DIR}/epm_opatch_prereq_tmp_${i}.sh
						new_script=${PREREQ_DIR}/epm_opatch_prereq_${i}.sh
								
			
						
						cp ${CTRLLOC}/epm_opatch_prereq.sh $tmp_script
						export patchNN=$i
						eval "echo \"`cat $tmp_script`\"" > $new_script
						chmod +x $new_script
						. $new_script > ${new_script}.log
						ret=$?
						if [ $ret -eq 0 ]; then
							echo "PREREQ check script executed"
							echo ""
						else
							echo "PREREQ check script execution failed"
							echo "PREREQ check script execution failed" >> $master_log_prereq 
							echo "" >> $master_log_prereq 
							echo ""
							exit 1;
						fi
						
						grep Prereq ${new_script}.log > ${PREREQ_DIR}/PREREQ_status_${i}.log
										
						prereq_stat_SysSpace=`grep -wi checkSystemSpace ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
						prereq_stat_conDetail=`grep -wi checkConflictAmongPatchesWithDetail ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
						prereq_stat_conOHDetail=`grep -wi checkConflictAgainstOHWithDetail ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
						prereq_stat_InputValues=`grep -wi checkForInputValues ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
						prereq_stat_appliProduct=`grep -wi checkApplicableProduct ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
						prereq_stat_component=`grep -wi checkComponents ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
						prereq_stat_appDepend=`grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
						prereq_stat_applica=`grep -wi checkApplicable ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
						
						
						export prereq_status_tidy=${PREREQ_DIR}/PREREQ_status_${i}_tidy.log
						echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace" > ${prereq_status_tidy}
						echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct" >> ${prereq_status_tidy}
						echo "PREREQ:checkComponents:$prereq_stat_component" >> ${prereq_status_tidy}
						echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail" >> ${prereq_status_tidy}
						echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend" >> ${prereq_status_tidy}
						echo "PREREQ:checkApplicable:$prereq_stat_applica" >> ${prereq_status_tidy}
						echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail" >> ${prereq_status_tidy}
						echo "PREREQ:checkForInputValues:$prereq_stat_InputValues" >> ${prereq_status_tidy}
						
						echo "<br>" >> $summary_report_prereq 
						echo "<b>OPatch Prequisite Check for patch ${i}</b>" >> $summary_report_prereq  
						echo "<table border="1">" >> $summary_report_prereq  
						echo "<tr>" >> $summary_report_prereq  
						echo "    <th>Timestamp</th>" >> $summary_report_prereq 
						echo "    <th>Prereq Check</th>" >> $summary_report_prereq
						echo "    <th>Status</th>" >> $summary_report_prereq 
						echo "    <th>Details</th>" >> $summary_report_prereq 
						echo "</tr>" >> $summary_report_prereq 		
						
						echo "OPatch Prequisite Check for patch ${i} " >> $master_log_prereq
						echo " Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
						echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
						
						for n in `cat ${prereq_status_tidy}`
						do
						prereq_chkk=`echo $n |cut -d":" -f2`
						prereq_chkk_stat=`echo $n |cut -d":" -f3`
						
							echo "<tr>" >> $summary_report_prereq  
							echo "    <td>`date`</td>" >> $summary_report_prereq 
							echo "    <td>${prereq_chkk}</td>" >> $summary_report_prereq
							echo "    <td>${prereq_chkk_stat}</td>" >> $summary_report_prereq 
							echo "    <td></td>" >> $summary_report_prereq 
							echo "</tr>" >> $summary_report_prereq 
							
							echo "`date`|${prereq_chkk} | ${prereq_chkk_stat} | " >> $master_log_prereq 
							
						done
						
						
						if [ "$prereq_stat_SysSpace" = "passed." ]; then
							echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace"  
						elif [ "$prereq_stat_SysSpace" = " " ]; then	
							echo "PREREQ status is blank, please check"
							
						else
							echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details"
							echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi	
						
						if [ "$prereq_stat_appliProduct" = "passed." ]; then
							echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct"
						elif [ "$prereq_stat_appliProduct" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi
						
						if [ "$prereq_stat_component" = "passed." ]; then
							echo "PREREQ:checkComponents:$prereq_stat_component"
						elif [ "$prereq_stat_component" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi				
						
						if [ "$prereq_stat_conDetail" = "passed." ]; then
							echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail"
						elif [ "$prereq_stat_conDetail" = " " ]; then	
							echo "PREREQ status is blank, please check"
						else
							echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi
						
						if [ "$prereq_stat_appDepend" = "passed." ]; then
							echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend"
						elif [ "$prereq_stat_appDepend" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi
						
						if [ "$prereq_stat_applica" = "passed." ]; then
							echo "PREREQ:checkApplicable:$prereq_stat_applica"
						elif [ "$prereq_stat_applica" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi
						
						if [ "$prereq_stat_conOHDetail" = "passed." ]; then
							echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail"
						elif [ "$prereq_stat_conOHDetail" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi	
						
						if [ "$prereq_stat_InputValues" = "passed." ]; then
							echo "PREREQ:checkForInputValues:$prereq_stat_InputValues"
						elif [ "$prereq_stat_InputValues" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi
						
						echo ""
						echo "PREREQ Checks successful"
						echo "" >> $master_log_prereq
						echo "PREREQ Checks successful" >> $master_log_prereq
						echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
						echo "</table>" >> $summary_report_prereq
						echo "<br>" >> $summary_report_prereq
					else
						echo "Unable to find patch file, please check the location"
						echo "Unable to find patch file, please check the location" >> $master_log_prereq
						cat $master_log_prereq
						exit 1;
					fi	
				fi
		done
		ls -ltr ${PREREQ_DIR}/${ENV}_lsinventory_*_present.txt 
		uret=$?
		echo $uret
		if [[ $uret -eq 0 ]];then
			echo "Few patches are already applied in this environment, please verify. Exiting script...."
			echo "Few patches are already applied in this environment, please verify." >> $master_log_prereq
			cat $master_log_prereq
			exit 1;
		else
			echo "All the patches are good to go"
		fi
		
		
		
	fi
cat $master_log_prereq	
echo ""
echo ""
		
	optionsScreen
}


function Questionnaire() {

echo ""
echo ""
# Listing out all the Prepatching Activities in comments
echo "####################################################################################################"
echo "Prepatching steps Manual Confirmation"
echo "Please Verify all steps have been confirmed with Y"
echo "####################################################################################################"
echo ""
date
read -p "DBA conducting the Maintenance (enter your sherwin id) " EMPID
echo "DBA conducting the Maintenance is "$EMPID
echo "----------"
echo "<br>" >> $summary_report
echo "<table border="1">" >> $summary_report  
echo "<tr>" >> $summary_report  
echo "     <td><b>Change performed by</b></td>" >> $summary_report  
echo "	   <td>$EMPID</td>" >> $summary_report  
echo "</tr>" >> $summary_report  
echo "<tr>" >> $summary_report  
echo "     <td><b>Date</b></td>" >> $summary_report  
echo "	   <td>`date`</td>" >> $summary_report  
echo "</tr>" >> $summary_report  
echo "</table>" >> $summary_report  
echo "<br>" >> $summary_report 
echo "<br>" >> $summary_report 
#
# 1. Download the patch and readme
read -p "Has the patch and readme been downloaded? (Y/N)" DWNLD

if [ $DWNLD = 'N' -o $DWNLD = 'No' -o $DWNLD = 'NO' -o  $DWNLD = 'n' ]; then
   read -p "Please explain why the patch and readme been downloaded?" EXPDWNLD
   echo "The patch and readme have NOT been downloaded because "$EXPDWNLD
else 
   echo "Patch download has occurred and readme has been read = " $DWNLD
fi
echo "----------"
echo "<br>" >> $summary_report
echo "<table border="1">" >> $summary_report  
echo "<tr>" >> $summary_report  
echo "    <th>Timestamp</th>" >> $summary_report 
echo "   <th>Question</th>" >> $summary_report 
echo "    <th>Answer</th>" >> $summary_report 
echo "    <th>Explanation</th>" >> $summary_report 
echo "</tr>" >> $summary_report 
echo "<tr>" >> $summary_report  
echo "    <td>`date`</td>" >> $summary_report 
echo "   <td>Has the patch and readme been downloaded? (Y/N)</td>" >> $summary_report 
echo "    <td>$DWNLD</td>" >> $summary_report 
echo "    <td>$EXPDWNLD</td>" >> $summary_report 
echo "</tr>" >> $summary_report
#
# 2. Make Sure the patch can be applied to the current version of hyperion
read -p  "Has it been verified that the patch can be applied to the current version of hyperion? " PCHAPPLY
if [ $PCHAPPLY = 'N' -o $PCHAPPLY = 'No' -o $PCHAPPLY = 'NO' -o  $PCHAPPLY = 'n' ]; then
   read -p "Why are you applying this then?" EXPPCHAPPLY 
   echo "Patch cannot be applied to this version and applying it because "$EXPPCHAPPLY #Write to master log
else
   echo "Verified that the patch can be applied to the current version of hyperion = " $PCHAPPLY #Write to master log
fi
echo "<tr>" >> $summary_report  
echo "    <td>`date`</td>" >> $summary_report 
echo "   <td>Has it been verified that the patch can be applied to the current version of hyperion?</td>" >> $summary_report 
echo "    <td>$PCHAPPLY</td>" >> $summary_report 
echo "    <td>$EXPPCHAPPLY</td>" >> $summary_report 
echo "</tr>" >> $summary_report

echo "----------"
#
# 3. Copy the software into Opatch folder
# This could be done as a Manual step for now or we could automate it
read -p "Has patch software been copied into Opatch folder? " PCHCP
if [ $PCHCP = 'N' -o $PCHCP = 'No' -o $PCHCP = 'NO' -o  $PCHCP = 'n' ]; then
   read -p "Please explain why patch software been copied into Opatch folder " EXPPCHCP 
   echo "Patch software been copied into Opatch folder because "$EXPPCHCP #Write to master log
else
echo "Patch software been copied into Opatch folder = "$PCHCP #Write to master log
fi
echo "----------"

echo "<tr>" >> $summary_report  
echo "    <td>`date`</td>" >> $summary_report 
echo "   <td>Has patch software been copied into Opatch folder? </td>" >> $summary_report 
echo "    <td>$PCHCP</td>" >> $summary_report 
echo "    <td>$EXPPCHCP</td>" >> $summary_report 
echo "</tr>" >> $summary_report

#
# 4. Put an entry in the change log to update
read -p "Is entry in Change Log in http://apexp.consumer.sherwin.com/apexp_cgapexdb1/f?p=163:34:9590272764607::NO::: ? " CHGLOG
if [ $CHGLOG = 'N' -o $CHGLOG = 'No' -o $CHGLOG = 'NO' -o  $CHGLOG = 'n' ]; then
   read -p "Why is there no Change Log entry? "EXPCHGLOG
   echo "There is no Change Log Entry Because "$EXPCHGLOG #Write to master log
   echo "Stopping program go update the change log and come back when its done ..." #Write to master log
   sleep 3
   exit 
else
echo "Change Log has been updated "$CHGLOG #Write to master log
fi
echo "----------"
echo "<tr>" >> $summary_report  
echo "    <td>`date`</td>" >> $summary_report 
echo "   <td>Is entry in Change Log in http://apexp.consumer.sherwin.com/apexp_cgapexdb1/f?p=163:34:9590272764607::NO::: ? </td>" >> $summary_report 
echo "    <td>$CHGLOG</td>" >> $summary_report 
echo "    <td>$EXPCHGLOG</td>" >> $summary_report 
echo "</tr>" >> $summary_report
#
# 5. Review the timeline with Beth of applying patches with Beth"
# echo "Has timeline been reviewed with Beth"
echo "</table>" >> $summary_report

echo "<br>" >> $summary_report 
echo "<br>" >> $summary_report 

echo ""
echo ""

}


function prePatchSteps() {
echo ""
echo ""


read -p "DBA conducting this step (enter your sherwin id) " EMPID
read -p "Enter the Change Log Request ID : " CHNGID
echo "DBA conducting this step is "$EMPID
echo "Change Log request ID is "$CHNGID


if [[ "$CHNGID" = "" ]]; then
	echo "No change ID input for "$ENV
	
	export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_PREREQ_${EMPID}_${Day}.html
	export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report_PREPATCH_${EMPID}_${Day}.html
	export summary_report_backup=${PPLOGDIR}/${ENV}_PATCH_report_BACKUP_${EMPID}_${Day}.html
	export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_POSTPATCH_${EMPID}_${Day}.html
	export master_log_prepatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_PREPATCH_${EMPID}_${Day}.log
else
	echo "Input file $INPUT_FILE sourced in for "$ENV
	echo "Change Log Request ID is "$CHNGID
	
	export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_PREREQ_${CHNGID}_${Day}.html
	export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report_PREPATCH_${CHNGID}_${Day}.html
	export summary_report_backup=${PPLOGDIR}/${ENV}_PATCH_report_BACKUP_${CHNGID}_${Day}.html
	export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_POSTPATCH_${CHNGID}_${Day}.html
	export master_log_prepatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_PREPATCH_${CHNGID}_${Day}.log
fi
echo "----------"
echo "<br>" >> $summary_report_prepatch
echo "<table border="1">" >> $summary_report_prepatch  
echo "<tr>" >> $summary_report_prepatch  
echo "     <td><b>DBA</b></td>" >> $summary_report_prepatch  
echo "	   <td>$EMPID</td>" >> $summary_report_prepatch
echo "</tr>" >> $summary_report_prepatch 
echo "<tr>" >> $summary_report_prepatch  
echo "     <td><b>Step performed</b></td>" >> $summary_report_prepatch  
echo "	   <td>EPM Prepatch Steps</td>" >> $summary_report_prepatch    
echo "</tr>" >> $summary_report_prepatch  
echo "<tr>" >> $summary_report_prepatch  
echo "     <td><b>Date</b></td>" >> $summary_report_prepatch  
echo "	   <td>`date`</td>" >> $summary_report_prepatch  
echo "</tr>" >> $summary_report_prepatch  
echo "<tr>" >> $summary_report_prepatch 
echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_prepatch
echo "	   <td>$CHNGID</td>" >> $summary_report_prepatch
echo "</tr>" >> $summary_report_prepatch
echo "<tr>" >> $summary_report_prepatch  
echo "     <td><b>Method</b></td>" >> $summary_report_prepatch
echo "	   <td>Manual</td>" >> $summary_report_prepatch 
echo "</tr>" >> $summary_report_prepatch
echo "</table>" >> $summary_report_prepatch  
echo "<br>" >> $summary_report_prepatch 
echo "<br>" >> $summary_report_prepatch 

echo "#################################################################################################################################################" > $master_log_prepatch
echo "DBA: $EMPID" >> $master_log_prepatch
echo "Step performed: EPM Prepatch Steps" >> $master_log_prepatch
echo "Date: `date`" >> $master_log_prepatch
echo "Change Log Request ID: $CHNGID" >> $master_log_prepatch
echo "Method: Manual" >> $master_log_prepatch
echo "#################################################################################################################################################" >> $master_log_prepatch

### Create flag file to put Critical_file_copy script on hold during patching"
echo " Creating flag file to put Critical_file_copy script on hold during patching"
echo " Creating flag file to put Critical_file_copy script on hold during patching" >> $master_log_prepatch
echo "#################################################################################################################################################" >> $master_log_prepatch
touch /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt

##File at end of backup Change##
#echo "Creating file at end of backup in Prepatch step - /hyp_interfaces/${LCMENV}/ess_scripts/Global_Shell/Back_Up_FW/Back_Up_Start.txt"
#touch /hyp_interfaces/${LCMENV}/ess_scripts/Global_Shell/Back_Up_FW/Back_Up_Start.txt
#chmod 777 /hyp_interfaces/${LCMENV}/ess_scripts/Global_Shell/Back_Up_FW/Back_Up_Start.txt

#Prepatching step 1: lsinventory command
echo "####################################################################################################"
echo "Prepatching step 1: lsinventory command"
echo "####################################################################################################"echo ""
echo ""
cd $EPM_ORACLE_HOME/OPatch
echo "./opatch lsinventory -oh $EPM_ORACLE_HOME -jdk $MIDDLEWARE_HOME/jdk160_35 -invPtrLoc $EPM_ORACLE_HOME/oraInst.loc"
export TodayDate=`date +%d_%m_%Y`
export PREPATCHDIR=${BACKUPDIR}/PREPOST/PREPATCH_${ENV}_${CHNGID}_${TodayDate}
export lsinvDate=`date +%Y-%m-%d_%H-%M`
./opatch lsinventory -oh $EPM_ORACLE_HOME -jdk $MIDDLEWARE_HOME/jdk160_35 -invPtrLoc $EPM_ORACLE_HOME/oraInst.loc > ${OUTPUT}/lsinventory_prepatch_${ENV}.txt
VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Executing lsinventory command for $ENV"
		echo "<br>" >> $summary_report_prepatch
		echo "<b>Pre Patching</b>" >> $summary_report_prepatch  
		echo "<table border="1">" >> $summary_report_prepatch  
		echo "<tr>" >> $summary_report_prepatch  
		echo "    <th>Timestamp</th>" >> $summary_report_prepatch 
		echo "    <th>Step</th>" >> $summary_report_prepatch
		echo "    <th>Status</th>" >> $summary_report_prepatch 
		echo "    <th>Details</th>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		
		echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>Prepatching step 1: Execute lsinventory command</td>" >> $summary_report_prepatch
		echo "    <td>Failure</td>" >> $summary_report_prepatch 
		echo "    <td></td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		
		echo "" >> $master_log_prepatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
		echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_prepatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
		echo "`date`|Prepatching step 1: Execute lsinventory command |Failure      | " >> $master_log_prepatch
		cat $master_log_prepatch	
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Executing lsinventory command for $ENV"
	 #cd $EPM_ORACLE_HOME/cfgtoollogs/opatch/lsinv/
	 filename=`grep "Lsinventory Output file location " ${OUTPUT}/lsinventory_prepatch_${ENV}.txt | cut -d":" -f2`
	 echo $filename
	 
	 mkdir ${PREPATCHDIR}
	 cp $filename ${PREPATCHDIR}
	 echo "$DateTime: Copied lsinventory file to ${PREPATCHDIR}"
	 ls -ltr ${PREPATCHDIR}
	 	echo "<br>" >> $summary_report_prepatch
		echo "<b>Pre Patching</b>" >> $summary_report_prepatch  
		echo "<table border="1">" >> $summary_report_prepatch  
		echo "<tr>" >> $summary_report_prepatch  
		echo "    <th>Timestamp</th>" >> $summary_report_prepatch 
		echo "    <th>Step</th>" >> $summary_report_prepatch
		echo "    <th>Status</th>" >> $summary_report_prepatch 
		echo "    <th>Details</th>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		
		echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>Prepatching step 1: Execute lsinventory command</td>" >> $summary_report_prepatch
		echo "    <td>Success</td>" >> $summary_report_prepatch 
		echo "    <td>Copied lsinventory file $filename to ${PREPATCHDIR}</td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		echo "" >> $master_log_prepatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
		echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_prepatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
		echo "`date`|Prepatching step 1: Execute lsinventory command |Success      |Copied lsinventory file $filename to ${PREPATCHDIR} " >> $master_log_prepatch
 fi

echo ""
echo ""


 #Prepatching step 2: EPM registry command
 echo "####################################################################################################"
 echo "Prepatching step 2: EPM registry command"
 echo "####################################################################################################"
 echo ""
echo ""
 cd $EPM_ORACLE_INSTANCE/bin
 echo "./epmsys_registry.sh"
./epmsys_registry.sh
VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Prepatching step 2: EPM registry command for $ENV"
	  	echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>Prepatching step 2: Generate EPM registry report</td>" >> $summary_report_prepatch
		echo "    <td>Failure</td>" >> $summary_report_prepatch 
		echo "    <td></td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		echo "`date`|Prepatching step 2: Generate EPM registry report |Failure      | " >> $master_log_prepatch
		cat $master_log_prepatch	
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Prepatching step 2: EPM registry command for $ENV"
	 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
	 cp registry.html ${PREPATCHDIR}
	 echo "$DateTime: Copied registry.html file to ${PREPATCHDIR}"
	 ls -ltr ${PREPATCHDIR}
		echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>Prepatching step 2: Generate EPM registry report</td>" >> $summary_report_prepatch
		echo "    <td>Success</td>" >> $summary_report_prepatch 
		echo "    <td>Copied registry.html file to ${PREPATCHDIR}</td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		echo "`date`|Prepatching step 2: Generate EPM registry report |Success      |Copied registry.html file to ${PREPATCHDIR}" >> $master_log_prepatch
		
 fi
echo ""
echo ""

#Prepatching step 3: Generate deployment report
 echo "####################################################################################################"
 echo "Prepatching step 3: Generate EPM deployment report"
 echo "####################################################################################################"
 echo ""
echo ""
cd $EPM_ORACLE_INSTANCE/bin
echo "./epmsys_registry.sh report deployment"
deplreptDate=`date +%Y%m%d_%H%M`
./epmsys_registry.sh report deployment
VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Generating EPM deployment report for $ENV"
	  	echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>Prepatching step 3: Generate EPM Deployment report</td>" >> $summary_report_prepatch
		echo "    <td>Failure</td>" >> $summary_report_prepatch 
		echo "    <td></td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		echo "`date`|Prepatching step 3: Generate EPM Deployment report |Failure      | " >> $master_log_prepatch
		cat $master_log_prepatch	
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Generating EPM deployment report for $ENV"
	 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
	 filename=`ls -lrt |awk '{print $9}' |tail -1`
	 cp $filename ${PREPATCHDIR}
	 echo "$DateTime: Copied EPM deployment reportfile to ${PREPATCHDIR}"
	 ls -ltr ${PREPATCHDIR}
		echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>Prepatching step 3: Generate EPM Deployment report</td>" >> $summary_report_prepatch
		echo "    <td>Success</td>" >> $summary_report_prepatch 
		echo "    <td>Copied $filename to ${PREPATCHDIR}</td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		echo "`date`|Prepatching step 3: Generate EPM Deployment report |Success      |Copied $filename to ${PREPATCHDIR} " >> $master_log_prepatch
 fi
 
 
 #Prepatching step 4: Backup of oraInventory
 echo "####################################################################################################"
 echo "Prepatching step 4: Backup of oraInventory"
 echo "####################################################################################################"
 echo ""
 echo ""
 INVLOC=`grep inventory_loc $EPM_ORACLE_HOME/oraInst.loc | cut -d"=" -f2`
 echo "Oracle Inventory location: $INVLOC"
tar -cvf ${BACKUPDIR}/INV_BACKUPS/${Day1}_${ENV}_${CHNGID}_PREPATCH_OraInventory.tar ${INVLOC}
 VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Backup of oraInventory for $ENV"
	  	echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>Prepatching step 4: Backup of oraInventory</td>" >> $summary_report_prepatch
		echo "    <td>Failure</td>" >> $summary_report_prepatch 
		echo "    <td></td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		echo "`date`|Prepatching step 4: Backup of oraInventory |Failure      | " >> $master_log_prepatch
		cat $master_log_prepatch
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Backup of oraInventory for $ENV"
	 ls -ltr ${BACKUPDIR}/INV_BACKUPS/
	 	echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>Prepatching step 4: Backup of oraInventory</td>" >> $summary_report_prepatch
		echo "    <td>Success</td>" >> $summary_report_prepatch 
		echo "    <td>Copied ${Day1}_${ENV}_PREPATCH_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/</td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		echo "`date`|Prepatching step 4: Backup of oraInventory |Success      |Copied ${Day1}_${ENV}_PREPATCH_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/ " >> $master_log_prepatch
 fi
 
 #Prepatching step 5: Critial file copy
 echo "####################################################################################################"
  echo "Prepatching step 5: Critial file copy"
 echo "####################################################################################################"
 echo ""
 echo ""
 cd ${SCRIPTDIR}/
  export Day3=`date +%Y-%m-%d_%H_%M`
 ./Critical_File_copy.sh
VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Executing Critial file copy for $ENV"
	  	  	echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>Prepatching step 5: Critial file copy</td>" >> $summary_report_prepatch
		echo "    <td>Failure</td>" >> $summary_report_prepatch 
		echo "    <td></td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		echo "`date`|Prepatching step 5: Critial file copy |Failure      | " >> $master_log_prepatch
		cat $master_log_prepatch
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Executing Critial file copy for $ENV"
	 crit_dir=`ls ${BACKUPDIR}/Critical_File_Copy | grep ${Day3}`
	 export prepatch_crit_dir=${BACKUPDIR}/Critical_File_Copy/${ENV}_${CHNGID}_PREPATCH_EPM_${Day3}
	 echo "Critical files copied to directory $crit_dir under ${BACKUPDIR}/Critical_File_Copy"
	 mv ${BACKUPDIR}/Critical_File_Copy/${Day3} ${prepatch_crit_dir}
	 echo "Listing files in ${prepatch_crit_dir}"
	 ls -ltr ${prepatch_crit_dir}
	 	echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>Prepatching step 5: Critial file copy</td>" >> $summary_report_prepatch
		echo "    <td>Success</td>" >> $summary_report_prepatch 
		echo "    <td>Copied ${ENV}_${CHNGID}_PREPATCH_${Day3} to ${BACKUPDIR}/Critical_File_Copy</td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		echo "</table>" >> $summary_report_prepatch 
		echo "<br>" >> $summary_report_prepatch 
		echo "<br>" >> $summary_report_prepatch
		echo "`date`|Prepatching step 5: Critial file copy |Success      |Copied ${ENV}_${CHNGID}_PREPATCH_${Day3} to ${BACKUPDIR}/Critical_File_Copy " >> $master_log_prepatch
 fi

		echo "##############################################################################################################################################" >> $master_log_prepatch
echo ""
echo ""
echo ""
		echo "Checking the last execution status for cloud control jobs for $ENV"
		echo ""
		echo "Listing backups for $ENV..."
		echo ""
		cat ${CTRLLOC}/${ENV}_status_all_backup_jobs.cfg
		echo ""
		echo "Fetching the last execution status of jobs"
		echo "Last execution status for cloud control jobs for $ENV" >> $master_log_prepatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
		echo "" >> $master_log_prepatch
		echo "" 
		for n in `cat ${CTRLLOC}/${ENV}_status_all_backup_jobs.cfg`
		do
		${EMCLIHOME}/emcli get_jobs -name="${n}" -owner="SW_JOBADMIN" > ${OUTPUT}/job_exec_${n}.txt	
		
		tail -2 ${OUTPUT}/job_exec_${n}.txt | head -1 > ${OUTPUT}/last_job_exec_${n}.txt	
		#cat ${OUTPUT}/last_job_exec_${n}.txt	
		fromdate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f9`
		fromtime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f10`
		todate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f12`
		totime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f13`
		status=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f17`
		
		echo "Last execution status for backup ${n}: ${status}"
		echo "Execution Start Time: $fromdate $fromtime "
		echo "Execution End Time: $todate $totime "
		echo ""
		
		echo "Last execution status for backup ${n}: ${status}" >> $master_log_prepatch
		echo "Execution Start Time: $fromdate $fromtime " >> $master_log_prepatch
		echo "Execution End Time: $todate $totime " >> $master_log_prepatch
		echo "" >> $master_log_prepatch
		echo "##############################################################################################################################################" >> $master_log_prepatch
		
		done
		echo ""
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch

cat $master_log_prepatch
		
echo ""
echo ""
echo "Redirecting to the options screen.."
echo ""
optionsScreen

}


function Multi_CC_job_cancel() {

	for i in `cat ${OUTPUT}/${ENV}_bkp_cc_names.txt`
		do
					echo "Job to be cancelled in Cloud Control: "$i
					echo "Job to be cancelled in Cloud Control: $i" >> $master_log_backup
					#export NEXTDAY=`date --date="next day" +%Y-%m-%d`
					export NEWJOB_TEMPL=${OUTPUT}/${ENV}_${i}_exp_template.txt
					$EMCLIHOME/emcli describe_job -name=${i} > ${OUTPUT}/${ENV}_${i}_exp.txt
					RET=$?
					echo $RET
						if [ $RET -ne 0 ];then
							echo "$DateTime: ERROR: Getting job description for cloud control job $i using emcli failed"
							echo "$DateTime: ERROR: Getting job description for cloud control job $i using emcli failed" >> $master_log_backup
							exit 1;
						else
							echo "$DateTime: SUCCESS: Getting job description for cloud control job $i"
						fi
					export JOBFREQ="`grep "schedule.frequency" ${OUTPUT}/${ENV}_${i}_exp.txt | cut -d"=" -f2`"
					export JOBSCH_DAYS="`grep "schedule.days" ${OUTPUT}/${ENV}_${i}_exp.txt | cut -d"=" -f2`"
					export JOBSCHTIME="`grep "schedule.startTime" ${OUTPUT}/${ENV}_${i}_exp.txt | cut -d"=" -f2 | cut -d " " -f2`"
					echo ${JOBSCH_DAYS//[[:blank:]]/} | sed 's/,/\n/g' > ${OUTPUT}/cc_job_sch_days.txt
					for n in `cat ${OUTPUT}/cc_job_sch_days.txt`
					do
					DAY_NAME=`grep $n ${CTRLLOC}/cloud_control_schedule.txt | cut -d":" -f2`
					echo "#################################################################################################################################################"
					echo "Cloud control job ${i} is scheduled to execute $JOBFREQ on $DAY_NAME at $JOBSCHTIME" 
					echo "#################################################################################################################################################"
					done
					echo -n "Please provide the next execution date for this job in YYYY-MM-DD format, to exit 0 (zero): "
					read userscheduledate1
					if [ "$userscheduledate1" == "0" ]; then
						echo ""
						echo "0 entered, exiting to Main screen"
						optionsScreen
					else
						echo "Next execution date for job $i: $userscheduledate1 at $JOBSCHTIME"
						echo -n "To confirm 1, to exit 0: "
						read confirmation
						if [ $confirmation -eq 0 ]; then
							echo ""
							echo "0 entered, exiting script.."
							exit 0;
						else
							echo ""
							echo "1 entered, Next execution date confirmed"
							export NEXT_DATE=${userscheduledate1}
							echo "Job start date being changed to date $NEXT_DATE"
							sed "/schedule.startTime/ c\schedule.startTime=${NEXT_DATE} ${JOBSCHTIME}" ${OUTPUT}/${ENV}_${i}_exp.txt > ${NEWJOB_TEMPL}
							echo "$DateTime: Executing command to delete job from cloud control"
							echo "$EMCLI_HOME/emcli stop_job -name=$i"
							## EMCLI command to stop job, need to change status to STOPPED to delete job
							$EMCLIHOME/emcli stop_job -name=$i
							RET=$?
							echo $RET
								if [ $RET -ne 0 ];then
									echo "$DateTime: ERROR: stop cloud control job $i using emcli failed"
									echo "$DateTime: ERROR: stop cloud control job $i using emcli failed" >> $master_log_backup
									exit 1;
								else
									echo "$DateTime: SUCCESS: stop cloud control job $i using emcli"
								fi
							echo "$EMCLI_HOME/emcli delete_job -name=$i -owner=SW_JOBADMIN"
							## EMCLI command to delete the job ##
							$EMCLIHOME/emcli delete_job -name=$i -owner=SW_JOBADMIN
							STAT=$?
							echo $STAT
								if [ $STAT -ne 0 ];then
									echo "$DateTime: ERROR: delete cloud control  job $i using emcli failed"
									echo "$DateTime: ERROR: delete cloud control  job $i using emcli failed" >> $master_log_backup
									exit 1;
								else
									echo "$DateTime: SUCCESS: deleted cloud control $i using emcli"
								fi
							echo "$DateTime: Executing command to schedule job from cloud control"
							export CC_JOB_NAME=$i
							$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:${NEWJOB_TEMPL}"
							RSTAT=$?
							echo $RSTAT
							if [ $RSTAT -ne 0 ];then
								echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
								echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
								echo "<tr>" >> $summary_report_backup
								echo "    <td>`date`</td>" >> $summary_report_backup
								echo "    <td>Backup step 1: Cancel existing backup (Cloud control)</td>" >> $summary_report_backup
								echo "    <td>$i</td>" >> $summary_report_backup
								echo "    <td>Failure</td>" >> $summary_report_backup
								echo "    <td>Schedule start date is $NEXT_DATE</td>" >> $summary_report_backup
								echo "</tr>" >> $summary_report_backup
								exit 1;
							else
								echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
								echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME} with execution start date $NEXT_DATE" >> $master_log_backup
								echo "<tr>" >> $summary_report_backup
								echo "    <td>`date`</td>" >> $summary_report_backup
								echo "    <td>Backup step 1: Cancel existing backup (Cloud control)</td>" >> $summary_report_backup
								echo "    <td>$i</td>" >> $summary_report_backup
								echo "    <td>Success</td>" >> $summary_report_backup
								echo "    <td>Schedule start date is $NEXT_DATE</td>" >> $summary_report_backup
								echo "</tr>" >> $summary_report_backup
								#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
								$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
								JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
								SC=""""					
								echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
								#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
								$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
								RET=$?
								if [ $RET -ne 0 ];then
								   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
								   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
						
								else
									echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
									echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
								
								fi	
							fi		
						fi
					fi			
		done


}


function Single_CC_job_cancel() {
	
	export NEWJOB_TEMPL=${OUTPUT}/${ENV}_${jobname}_exp_template.txt
				$EMCLIHOME/emcli describe_job -name=${jobname} > ${OUTPUT}/${ENV}_${jobname}_exp.txt
				RET=$?
				echo $RET
					if [ $RET -ne 0 ];then
						echo "$DateTime: ERROR: Getting job description for cloud control job $jobname using emcli failed"
						echo "$DateTime: ERROR: Getting job description for cloud control job $jobname using emcli failed" >> $master_log_backup
						exit 1;
					else
						echo "$DateTime: SUCCESS: Getting job description for cloud control job $jobname"
					fi
				export JOBFREQ="`grep "schedule.frequency" ${OUTPUT}/${ENV}_${jobname}_exp.txt | cut -d"=" -f2`"
				export JOBSCH_DAYS="`grep "schedule.days" ${OUTPUT}/${ENV}_${jobname}_exp.txt | cut -d"=" -f2`"
				export JOBSCHTIME="`grep "schedule.startTime" ${OUTPUT}/${ENV}_${jobname}_exp.txt | cut -d"=" -f2 | cut -d " " -f2`"
				echo ${JOBSCH_DAYS//[[:blank:]]/} | sed 's/,/\n/g' > ${OUTPUT}/cc_job_sch_days.txt
				for n in `cat ${OUTPUT}/cc_job_sch_days.txt`
				do
				DAY_NAME=`grep $n ${CTRLLOC}/cloud_control_schedule.txt | cut -d":" -f2`
					echo "#################################################################################################################################################"
					echo "Cloud control job ${i} is scheduled to execute $JOBFREQ on $DAY_NAME at $JOBSCHTIME" 
					echo "#################################################################################################################################################"
				done
				echo -n "Please provide the next execution date for this job in YYYY-MM-DD format, to exit 0 (zero): "
				read userscheduledate1
				if [ "$userscheduledate1" == "0" ]; then
					echo ""
					echo "0 entered, exiting to Main screen"
					optionsScreen
				else
					echo "Next execution date for job $jobname: $userscheduledate1 at $JOBSCHTIME"
					echo -n "To confirm 1, to exit 0: "
					read confirmation
					if [ $confirmation -eq 0 ]; then
						echo ""
						echo "0 entered, exiting script.."
						exit 1;
					else
						echo ""
						echo "1 entered, Next execution date confirmed"
						export NEXT_DATE=${userscheduledate1}
						echo "Job start date being changed to date $NEXT_DATE"
						sed "/schedule.startTime/ c\schedule.startTime=${NEXT_DATE} ${JOBSCHTIME}" ${OUTPUT}/${ENV}_${jobname}_exp.txt > ${NEWJOB_TEMPL}
						echo "$DateTime: Executing command to delete job from cloud control"
						echo "$EMCLI_HOME/emcli stop_job -name=$jobname"
						## EMCLI command to stop job, need to change status to STOPPED to delete job
						$EMCLIHOME/emcli stop_job -name=$jobname
						RET=$?
						echo $RET
							if [ $RET -ne 0 ];then
								echo "$DateTime: ERROR: stop cloud control job $jobname using emcli failed"
								echo "$DateTime: ERROR: stop cloud control job $jobname using emcli failed" >> $master_log_backup
								exit 1;
							else
								echo "$DateTime: SUCCESS: stop cloud control job $jobname using emcli"
							fi
						echo "$EMCLI_HOME/emcli delete_job -name=$jobname -owner=SW_JOBADMIN"
						## EMCLI command to delete the job ##
						$EMCLIHOME/emcli delete_job -name=$jobname -owner=SW_JOBADMIN
						STAT=$?
						echo $STAT
							if [ $STAT -ne 0 ];then
								echo "$DateTime: ERROR: delete cloud control  job $jobname using emcli failed"
								echo "$DateTime: ERROR: delete cloud control  job $jobname using emcli failed" >> $master_log_backup
								exit 1;
							else
								echo "$DateTime: SUCCESS: deleted cloud control $jobname using emcli"
							fi
						echo "$DateTime: Executing command to schedule job from cloud control"
						export CC_JOB_NAME=$jobname
						$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:${NEWJOB_TEMPL}"
						RSTAT=$?
						echo $RSTAT
						if [ $RSTAT -ne 0 ];then
							echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
							echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
							echo "<tr>" >> $summary_report_backup
							echo "    <td>`date`</td>" >> $summary_report_backup
							echo "    <td>Backup step 1: Cancel existing backup (Cloud control)</td>" >> $summary_report_backup
							echo "    <td>$jobname</td>" >> $summary_report_backup
							echo "    <td>Failure</td>" >> $summary_report_backup
							echo "    <td>Schedule start date is $NEXT_DATE</td>" >> $summary_report_backup
							echo "</tr>" >> $summary_report_backup
							exit 1;
						else
							echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
							echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME} with execution start date $NEXT_DATE" >> $master_log_backup
							echo "<tr>" >> $summary_report_backup
							echo "    <td>`date`</td>" >> $summary_report_backup
							echo "    <td>Backup step 1: Cancel existing backup (Cloud control)</td>" >> $summary_report_backup
							echo "    <td>$jobname</td>" >> $summary_report_backup
							echo "    <td>Success</td>" >> $summary_report_backup
							echo "    <td>Schedule start date is $NEXT_DATE</td>" >> $summary_report_backup
							echo "</tr>" >> $summary_report_backup
							#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
							$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
							JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
							SC=""""					
							echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
							#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
							$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
							RET=$?
							if [ $RET -ne 0 ];then
							   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
							   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
					
							else
								echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
								echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
							
							fi	
						fi		
					fi
				fi	
}


function Multi_CC_DB_job_cancel() {

		for i in `cat ${OUTPUT}/bkp_cc_db_names1.txt`
			do
					echo "Job to be cancelled in Cloud Control: "$i
					echo "Job to be cancelled in Cloud Control: $i" >> $master_log_backup
					#export NEXTDAY=`date --date="next day" +%Y-%m-%d`
					export NEWJOB_TEMPL=${OUTPUT}/${ENV}_${i}_exp_template.txt
					$EMCLIHOME/emcli describe_job -name=${i} > ${OUTPUT}/${ENV}_${i}_exp.txt
					RET=$?
					echo $RET
						if [ $RET -ne 0 ];then
							echo "$DateTime: ERROR: Getting job description for cloud control job $i using emcli failed"
							echo "$DateTime: ERROR: Getting job description for cloud control job $i using emcli failed" >> $master_log_backup
							exit 1;
						else
							echo "$DateTime: SUCCESS: Getting job description for cloud control job $i"
						fi
					export JOBFREQ="`grep "schedule.frequency" ${OUTPUT}/${ENV}_${i}_exp.txt | cut -d"=" -f2`"
					export JOBSCH_DAYS="`grep "schedule.days" ${OUTPUT}/${ENV}_${i}_exp.txt | cut -d"=" -f2`"
					export JOBSCHTIME="`grep "schedule.startTime" ${OUTPUT}/${ENV}_${i}_exp.txt | cut -d"=" -f2 | cut -d " " -f2`"
					echo ${JOBSCH_DAYS//[[:blank:]]/} | sed 's/,/\n/g' > ${OUTPUT}/cc_job_sch_days.txt
					for n in `cat ${OUTPUT}/cc_job_sch_days.txt`
					do
					DAY_NAME=`grep $n ${CTRLLOC}/cloud_control_schedule.txt | cut -d":" -f2`
					echo "Cloud control job ${i} is scheduled to execute $JOBFREQ on $DAY_NAME at $JOBSCHTIME" 
					done
					echo -n "Please provide the next execution date for this job in YYYY-MM-DD format, to exit 0 (zero): "
					read userscheduledate1
					if [ "$userscheduledate1" == "0" ]; then
						echo ""
						echo "0 entered, exiting to Main screen"
						optionsScreen
					else
						echo "Next execution date for job $i: $userscheduledate1 at $JOBSCHTIME"
						echo -n "To confirm 1, to exit 0: "
						read confirmation
						if [ $confirmation -eq 0 ]; then
							echo ""
							echo "0 entered, exiting script.."
							exit 1;
						else
							echo ""
							echo "1 entered, Next execution date confirmed"
							export NEXT_DATE=${userscheduledate1}
							echo "Job start date being changed to date $NEXT_DATE"
							sed "/schedule.startTime/ c\schedule.startTime=${NEXT_DATE} ${JOBSCHTIME}" ${OUTPUT}/${ENV}_${i}_exp.txt > ${NEWJOB_TEMPL}
							echo "$DateTime: Executing command to delete job from cloud control"
							echo "$EMCLI_HOME/emcli stop_job -name=$i"
							## EMCLI command to stop job, need to change status to STOPPED to delete job
							$EMCLIHOME/emcli stop_job -name=$i
							RET=$?
							echo $RET
								if [ $RET -ne 0 ];then
									echo "$DateTime: ERROR: stop cloud control job $i using emcli failed"
									echo "$DateTime: ERROR: stop cloud control job $i using emcli failed" >> $master_log_backup
									exit 1;
								else
									echo "$DateTime: SUCCESS: stop cloud control job $i using emcli"
								fi
							echo "$EMCLI_HOME/emcli delete_job -name=$i -owner=SW_JOBADMIN"
							## EMCLI command to delete the job ##
							$EMCLIHOME/emcli delete_job -name=$i -owner=SW_JOBADMIN
							STAT=$?
							echo $STAT
								if [ $STAT -ne 0 ];then
									echo "$DateTime: ERROR: delete cloud control  job $i using emcli failed"
									echo "$DateTime: ERROR: delete cloud control  job $i using emcli failed" >> $master_log_backup
									exit 1;
								else
									echo "$DateTime: SUCCESS: deleted cloud control $i using emcli"
								fi
							echo "$DateTime: Executing command to schedule job from cloud control"
							export CC_JOB_NAME=$i
							$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:${NEWJOB_TEMPL}"
							RSTAT=$?
							echo $RSTAT
							if [ $RSTAT -ne 0 ];then
								echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
								echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
								echo "<tr>" >> $summary_report_backup
								echo "    <td>`date`</td>" >> $summary_report_backup
								echo "    <td>Backup step 1: Cancel existing backup (Cloud control)</td>" >> $summary_report_backup
								echo "    <td>$i</td>" >> $summary_report_backup
								echo "    <td>Failure</td>" >> $summary_report_backup
								echo "    <td>Schedule start date is $NEXT_DATE</td>" >> $summary_report_backup
								echo "</tr>" >> $summary_report_backup
								exit 1;
							else
								echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
								echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME} with execution start date $NEXT_DATE" >> $master_log_backup
								echo "<tr>" >> $summary_report_backup
								echo "    <td>`date`</td>" >> $summary_report_backup
								echo "    <td>Backup step 1: Cancel existing backup (Cloud control)</td>" >> $summary_report_backup
								echo "    <td>$i</td>" >> $summary_report_backup
								echo "    <td>Success</td>" >> $summary_report_backup
								echo "    <td>Schedule start date is $NEXT_DATE</td>" >> $summary_report_backup
								echo "</tr>" >> $summary_report_backup
								#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
								$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
								JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
								SC=""""					
								echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
								#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
								$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
								RET=$?
								if [ $RET -ne 0 ];then
								   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
								   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
						
								else
									echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
									echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
								
								fi	
							fi		
						fi
					fi					
			done
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup


}


function Single_CC_DB_job_cancel() {
	
				export NEWJOB_TEMPL=${OUTPUT}/${ENV}_${jobname}_exp_template.txt
				$EMCLIHOME/emcli describe_job -name="${jobname}" > ${OUTPUT}/${ENV}_${jobname}_exp.txt
				RET=$?
				echo $RET
					if [ $RET -ne 0 ];then
						echo "$DateTime: ERROR: Getting job description for cloud control job $jobname using emcli failed"
						echo "$DateTime: ERROR: Getting job description for cloud control job $jobname using emcli failed" >> $master_log_backup
						exit 1;
					else
						echo "$DateTime: SUCCESS: Getting job description for cloud control job $jobname"
					fi
				export JOBFREQ="`grep "schedule.frequency" ${OUTPUT}/${ENV}_${jobname}_exp.txt | cut -d"=" -f2`"
				export JOBSCH_DAYS="`grep "schedule.days" ${OUTPUT}/${ENV}_${jobname}_exp.txt | cut -d"=" -f2`"
				export JOBSCHTIME="`grep "schedule.startTime" ${OUTPUT}/${ENV}_${jobname}_exp.txt | cut -d"=" -f2 | cut -d " " -f2`"
				echo ${JOBSCH_DAYS//[[:blank:]]/} | sed 's/,/\n/g' > ${OUTPUT}/cc_job_sch_days.txt
				for n in `cat ${OUTPUT}/cc_job_sch_days.txt`
				do
				DAY_NAME=`grep $n ${CTRLLOC}/cloud_control_schedule.txt | cut -d":" -f2`
									echo "#################################################################################################################################################"
					echo "Cloud control job ${i} is scheduled to execute $JOBFREQ on $DAY_NAME at $JOBSCHTIME" 
					echo "#################################################################################################################################################"
				done
				echo -n "Please provide the next execution date for this job in YYYY-MM-DD format, to exit 0 (zero): "
				read userscheduledate1
				if [ "$userscheduledate1" == "0" ]; then
					echo ""
					echo "0 entered, exiting to Main screen"
					optionsScreen
				else
					echo "Next execution date for job $jobname: $userscheduledate1 at $JOBSCHTIME"
					echo -n "To confirm 1, to exit 0: "
					read confirmation
					if [ $confirmation -eq 0 ]; then
						echo ""
						echo "0 entered, exiting script.."
						exit 1;
					else
						echo ""
						echo "1 entered, Next execution date confirmed"
						export NEXT_DATE=${userscheduledate1}
						echo "Job start date being changed to date $NEXT_DATE"
						sed "/schedule.startTime/ c\schedule.startTime=${NEXT_DATE} ${JOBSCHTIME}" ${OUTPUT}/${ENV}_${jobname}_exp.txt > ${NEWJOB_TEMPL}
						echo "$DateTime: Executing command to delete job from cloud control"
						echo "$EMCLI_HOME/emcli stop_job -name=$jobname"
						## EMCLI command to stop job, need to change status to STOPPED to delete job
						$EMCLIHOME/emcli stop_job -name="$jobname"
						RET=$?
						echo $RET
							if [ $RET -ne 0 ];then
								echo "$DateTime: ERROR: stop cloud control job $jobname using emcli failed"
								echo "$DateTime: ERROR: stop cloud control job $jobname using emcli failed" >> $master_log_backup
								exit 1;
							else
								echo "$DateTime: SUCCESS: stop cloud control job $jobname using emcli"
							fi
						echo "$EMCLI_HOME/emcli delete_job -name=$jobname -owner=SW_JOBADMIN"
						## EMCLI command to delete the job ##
						$EMCLIHOME/emcli delete_job -name="$jobname" -owner=SW_JOBADMIN
						STAT=$?
						echo $STAT
							if [ $STAT -ne 0 ];then
								echo "$DateTime: ERROR: delete cloud control  job $jobname using emcli failed"
								echo "$DateTime: ERROR: delete cloud control  job $jobname using emcli failed" >> $master_log_backup
								exit 1;
							else
								echo "$DateTime: SUCCESS: deleted cloud control $jobname using emcli"
							fi
						echo "$DateTime: Executing command to schedule job from cloud control"
						export CC_JOB_NAME=$jobname
						$EMCLIHOME/emcli create_job -name="${CC_JOB_NAME}" -input_file="property_file:${NEWJOB_TEMPL}"
						RSTAT=$?
						echo $RSTAT
						if [ $RSTAT -ne 0 ];then
							echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
							echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
							echo "<tr>" >> $summary_report_backup
							echo "    <td>`date`</td>" >> $summary_report_backup
							echo "    <td>Backup step 1: Cancel existing backup (Cloud control)</td>" >> $summary_report_backup
							echo "    <td>$jobname</td>" >> $summary_report_backup
							echo "    <td>Failure</td>" >> $summary_report_backup
							echo "    <td>Schedule start date is $NEXT_DATE</td>" >> $summary_report_backup
							echo "</tr>" >> $summary_report_backup
							exit 1;
						else
							echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
							echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME} with execution start date $NEXT_DATE" >> $master_log_backup
							echo "<tr>" >> $summary_report_backup
							echo "    <td>`date`</td>" >> $summary_report_backup
							echo "    <td>Backup step 1: Cancel existing backup (Cloud control)</td>" >> $summary_report_backup
							echo "    <td>$jobname</td>" >> $summary_report_backup
							echo "    <td>Success</td>" >> $summary_report_backup
							echo "    <td>Schedule start date is $NEXT_DATE</td>" >> $summary_report_backup
							echo "</tr>" >> $summary_report_backup
							#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
							$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
							JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
							SC=""""					
							echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
							#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
							$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
							RET=$?
							if [ $RET -ne 0 ];then
							   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
							   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
					
							else
								echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
								echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
							
							fi	
						fi		
					fi
				fi
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
	
}


function Mutli_CC_job_schedule() {

			echo -n "Enter schedule date & time in format YYYY-MM-DD HH:MM:SS (Ex. 2017-05-01 23:30:00) : "
			echo ""
			read jobschdate
			echo " Job one time execution to be scheduled at $jobschdate"
			for i in `cat ${OUTPUT}/bkp_names1.txt`
			do
				echo $i
				DateTime1=`date +%d%m%y%H%M%S`
				##Get Cloud control job description#
				##Fields to be changed name,variable.default_shell_command,schedule.startTime,schedule.frequency,schedule.gracePeriod##
			
				$EMCLIHOME/emcli describe_job -name=$i > ${OUTPUT}/${i}_describe_${DateTime1}.txt
				if [[ "$i" == *"CONSOL_BACKUP"* ]]; then 
					echo "Job is a CONSOL_BACKUP backup  job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENV} ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ "$i" == "LCM_CONSOL"* ]]; then 
					echo "Job is a LCM_CONSOL backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_lcm_consol_wrapper.sh ${LCMENV} ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ "$i" == *"MIDDLEWARE"* ]]; then 
					echo "Job is a MIDDLEWARE backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_MWHOME ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ "$i" == *"ARBORPATH"* ]]; then 
					echo "Job is a ARBORPATH backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_ARPTH ${CHNGID} \'"
					#echo $VAR_SHELL
				else 	
					echo "Job is some other job"
				fi
								
				CC_JOB_INPUTFILE=${OUTPUT}/${i}_template_${DateTime1}.txt
				#CC_JOB_TEMPFILE=${OUTPUT}/${i}_template_${DateTime1}.txt
				export JOB_SCH_DATE=$jobschdate
				echo $JOB_SCH_DATE
				export CC_JOB_NAME=${i}_${DateTime1}
				#cp ${EMCLITEMPLATE}/${i}_template.txt $CC_JOB_TEMPFILE
				#eval "echo \"`cat $CC_JOB_TEMPFILE`\"" > $CC_JOB_INPUTFILE
				echo "Backup of ${OUTPUT}/${i}_describe_${DateTime1}.txt taken as ${OUTPUT}/${i}_describe_bkp_${DateTime1}.txt"
				cp ${OUTPUT}/${i}_describe_${DateTime1}.txt ${OUTPUT}/${i}_describe_bkp_${DateTime1}.txt
				sed -i "/name=/ c\name=${CC_JOB_NAME}" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				if [[ ${VAR_SHELL}x == "x" ]]; then
					echo "Job $i , variable.default_shell_command is not being replaced in Cloud control input file "
				else
					echo "Replacing variable.default_shell_command in Cloud control input file"	
					#echo $VAR_SHELL
					sed -i "/variable.default_shell_command/ c\ $VAR_SHELL" ${OUTPUT}/${i}_describe_${DateTime1}.txt 
				fi
				sed -i "/schedule.startTime/ c\schedule.startTime=$JOB_SCH_DATE" ${OUTPUT}/${i}_describe_${DateTime1}.txt 
				sed -i "/schedule.frequency/ c\schedule.frequency=ONCE" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				sed -i "/schedule.gracePeriod/ c\schedule.gracePeriod=15" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				sed -i "/schedule.days/d" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				cp ${OUTPUT}/${i}_describe_${DateTime1}.txt $CC_JOB_INPUTFILE
				
				echo "Backup job ${i} one time execution being scheduled at $jobschdate" >> $master_log_backup
				echo "$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file=\"property_file:$CC_JOB_INPUTFILE\""
				$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:$CC_JOB_INPUTFILE"
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 2: Schedule a one time backup (Cloud control)</td>" >> $summary_report_backup
					echo "    <td>$i</td>" >> $summary_report_backup
					echo "    <td>Failure</td>" >> $summary_report_backup
					echo "    <td>Job scheduled date is $JOB_SCH_DATE</td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
				else
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "$DateTime: adding privileges to proj_hyperion role for job  using emcli"
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 2: Schedule a one time backup (Cloud control)</td>" >> $summary_report_backup
					echo "    <td>$i</td>" >> $summary_report_backup
					echo "    <td>Success</td>" >> $summary_report_backup
					echo "    <td>Job scheduled date is $JOB_SCH_DATE</td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
					#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
					$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
					JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
					SC=""""					
					echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
					#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
					$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					    echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup					   
					fi	
				fi
			done
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup



}


function Single_CC_job_schedule() {
				
				echo -n "Enter schedule date & time in format YYYY-MM-DD HH:MM:SS (Ex. 2017-05-01 23:30:00) : "
				echo ""
				read jobschdate
				echo "Job one time execution to be scheduled at $jobschdate"
				echo $jobname
				CC_JOB_INPUTFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				CC_JOB_TEMPFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				export JOB_SCH_DATE=$jobschdate
				echo $JOB_SCH_DATE
				DateTime1=`date +%d%m%y%H%M%S`
				
				##Get Cloud control job description#
				##Fields to be changed name,variable.default_shell_command,schedule.startTime,schedule.frequency,schedule.gracePeriod##
			
				$EMCLIHOME/emcli describe_job -name=$jobname > ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				if [[ $jobname == *"CONSOL_BACKUP"* ]]; then 
					echo "Job is a CONSOL_BACKUP backup  job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENV} ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ $jobname == "LCM_CONSOL"* ]]; then 
					echo "Job is a LCM_CONSOL backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_lcm_consol_wrapper.sh ${LCMENV} ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ $jobname == *"MIDDLEWARE"* ]]; then 
					echo "Job is a MIDDLEWARE backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_MWHOME ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ $jobname == *"ARBORPATH"* ]]; then 
					echo "Job is a ARBORPATH backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_ARPTH ${CHNGID} \'"
					#echo $VAR_SHELL
				else 	
					echo "Job is some other job"
				fi
				
				CC_JOB_INPUTFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				#CC_JOB_TEMPFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				#export JOB_SCH_DATE=$jobschdate
				#echo $JOB_SCH_DATE
				export CC_JOB_NAME=${jobname}_${DateTime1}
				#cp ${EMCLITEMPLATE}/${jobname}_template.txt $CC_JOB_TEMPFILE
				#eval "echo \"`cat $CC_JOB_TEMPFILE`\"" > $CC_JOB_INPUTFILE
				echo "Backup of ${OUTPUT}/${jobname}_describe_${DateTime1}.txt taken as ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt"
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt
				sed -i "/name=/ c\name=${CC_JOB_NAME}" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				if [[ ${VAR_SHELL}x == "x" ]]; then
					echo "Job $jobname, variable.default_shell_command is not being replaced in Cloud control input file "
				else
					echo "Replacing variable.default_shell_command in Cloud control input file"	
					#echo "$VAR_SHELL"
					sed -i "/variable.default_shell_command/ c\ $VAR_SHELL" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt 
				fi	
				sed -i "/schedule.startTime/ c\schedule.startTime=$JOB_SCH_DATE" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt 
				sed -i "/schedule.frequency/ c\schedule.frequency=ONCE" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.gracePeriod/ c\schedule.gracePeriod=15" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.days/d" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt $CC_JOB_INPUTFILE
				
				
				export CC_JOB_NAME=${jobname}_${DateTime1}
				#cp ${EMCLITEMPLATE}/${jobname}_template.txt $CC_JOB_TEMPFILE
				#eval "echo \"`cat $CC_JOB_TEMPFILE`\"" > $CC_JOB_INPUTFILE
				echo "Backup job ${jobname} one time execution being scheduled at $jobschdate" >> $master_log_backup
				#echo "$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file=\"property_file:$CC_JOB_INPUTFILE\""
				$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:$CC_JOB_INPUTFILE"
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 2: Schedule a one time backup (Cloud control)</td>" >> $summary_report_backup
					echo "    <td>$jobname</td>" >> $summary_report_backup
					echo "    <td>Failure</td>" >> $summary_report_backup
					echo "    <td>Job scheduled date is $JOB_SCH_DATE</td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
				else
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "$DateTime: adding privileges to proj_hyperion role for job  using emcli"
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 2: Schedule a one time backup (Cloud control)</td>" >> $summary_report_backup
					echo "    <td>$jobname</td>" >> $summary_report_backup
					echo "    <td>Success</td>" >> $summary_report_backup
					echo "    <td>Job scheduled date is $JOB_SCH_DATE</td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
					#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
					$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
					JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
					SC=""""					
					echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
					#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
					$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					    echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup					   
					fi	
				fi	
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
}


function Mutli_CC_DB_job_schedule() {

			echo -n "Enter schedule date & time in format YYYY-MM-DD HH:MM:SS (Ex. 2017-05-01 23:30:00) : "
			echo ""
			read jobschdate
			echo " Job one time execution to be scheduled at $jobschdate"
			for i in `cat ${OUTPUT}/bkp_names1.txt`
			do
				echo $i
				DateTime1=`date +%d%m%y%H%M%S`
				##Get Cloud control job description#
				##Fields to be changed name,variable.default_shell_command,schedule.startTime,schedule.frequency,schedule.gracePeriod##
			
				$EMCLIHOME/emcli describe_job -name=$i > ${OUTPUT}/${i}_describe_${DateTime1}.txt
												
				CC_JOB_INPUTFILE=${OUTPUT}/${i}_template_${DateTime1}.txt
				#CC_JOB_TEMPFILE=${OUTPUT}/${i}_template_${DateTime1}.txt
				export JOB_SCH_DATE=$jobschdate
				echo $JOB_SCH_DATE
				export CC_JOB_NAME=${i}_${DateTime1}
				#cp ${EMCLITEMPLATE}/${i}_template.txt $CC_JOB_TEMPFILE
				#eval "echo \"`cat $CC_JOB_TEMPFILE`\"" > $CC_JOB_INPUTFILE
				echo "Backup of ${OUTPUT}/${i}_describe_${DateTime1}.txt taken as ${OUTPUT}/${i}_describe_bkp_${DateTime1}.txt"
				cp ${OUTPUT}/${i}_describe_${DateTime1}.txt ${OUTPUT}/${i}_describe_bkp_${DateTime1}.txt
				sed -i "/name=/ c\name=${CC_JOB_NAME}" ${OUTPUT}/${i}_describe_${DateTime1}.txt
	
				sed -i "/schedule.startTime/ c\schedule.startTime=$JOB_SCH_DATE" ${OUTPUT}/${i}_describe_${DateTime1}.txt 
				sed -i "/schedule.frequency/ c\schedule.frequency=ONCE" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				sed -i "/schedule.gracePeriod/ c\schedule.gracePeriod=15" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				sed -i "/schedule.days/d" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				cp ${OUTPUT}/${i}_describe_${DateTime1}.txt $CC_JOB_INPUTFILE
				
				echo "Backup job ${i} one time execution being scheduled at $jobschdate" >> $master_log_backup
				echo "$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file=\"property_file:$CC_JOB_INPUTFILE\""
				$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:$CC_JOB_INPUTFILE"
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 2: Schedule a one time backup (Cloud control)</td>" >> $summary_report_backup
					echo "    <td>$i</td>" >> $summary_report_backup
					echo "    <td>Failure</td>" >> $summary_report_backup
					echo "    <td>Job scheduled date is $JOB_SCH_DATE</td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
				else
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "$DateTime: adding privileges to proj_hyperion role for job  using emcli"
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 2: Schedule a one time backup (Cloud control)</td>" >> $summary_report_backup
					echo "    <td>$i</td>" >> $summary_report_backup
					echo "    <td>Success</td>" >> $summary_report_backup
					echo "    <td>Job scheduled date is $JOB_SCH_DATE</td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
					#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
					$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
					JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
					SC=""""					
					echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
					#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
					$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					    echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup					   
					fi	
				fi
			done
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup



}


function Single_CC_DB_job_schedule() {
				
				echo -n "Enter schedule date & time in format YYYY-MM-DD HH:MM:SS (Ex. 2017-05-01 23:30:00) : "
				echo ""
				read jobschdate
				echo "Job one time execution to be scheduled at $jobschdate"
				echo $jobname
				CC_JOB_INPUTFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				CC_JOB_TEMPFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				export JOB_SCH_DATE=$jobschdate
				echo $JOB_SCH_DATE
				DateTime1=`date +%d%m%y%H%M%S`
				
				##Get Cloud control job description#
				##Fields to be changed name,variable.default_shell_command,schedule.startTime,schedule.frequency,schedule.gracePeriod##
			
				$EMCLIHOME/emcli describe_job -name="$jobname" > ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				
				CC_JOB_INPUTFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				#CC_JOB_TEMPFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				#export JOB_SCH_DATE=$jobschdate
				#echo $JOB_SCH_DATE
				export CC_JOB_NAME=${jobname}_${DateTime1}
				#cp ${EMCLITEMPLATE}/${jobname}_template.txt $CC_JOB_TEMPFILE
				#eval "echo \"`cat $CC_JOB_TEMPFILE`\"" > $CC_JOB_INPUTFILE
				echo "Backup of ${OUTPUT}/${jobname}_describe_${DateTime1}.txt taken as ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt"
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt
				sed -i "/name=/ c\name=${CC_JOB_NAME}" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				if [[ ${VAR_SHELL}x == "x" ]]; then
					echo "Job $jobname, variable.default_shell_command is not being replaced in Cloud control input file "
				else
					echo "Replacing variable.default_shell_command in Cloud control input file"	
					#echo "$VAR_SHELL"
					sed -i "/variable.default_shell_command/ c\ $VAR_SHELL" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt 
				fi	
				sed -i "/schedule.startTime/ c\schedule.startTime=$JOB_SCH_DATE" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt 
				sed -i "/schedule.frequency/ c\schedule.frequency=ONCE" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.gracePeriod/ c\schedule.gracePeriod=15" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.days/d" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt $CC_JOB_INPUTFILE
				
				
				export CC_JOB_NAME=${jobname}_${DateTime1}
				#cp ${EMCLITEMPLATE}/${jobname}_template.txt $CC_JOB_TEMPFILE
				#eval "echo \"`cat $CC_JOB_TEMPFILE`\"" > $CC_JOB_INPUTFILE
				echo "Backup job ${jobname} one time execution being scheduled at $jobschdate" >> $master_log_backup
				#echo "$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file=\"property_file:$CC_JOB_INPUTFILE\""
				$EMCLIHOME/emcli create_job -name="${CC_JOB_NAME}" -input_file="property_file:$CC_JOB_INPUTFILE"
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 2: Schedule a one time backup (Cloud control)</td>" >> $summary_report_backup
					echo "    <td>$jobname</td>" >> $summary_report_backup
					echo "    <td>Failure</td>" >> $summary_report_backup
					echo "    <td>Job scheduled date is $JOB_SCH_DATE</td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
				else
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "$DateTime: adding privileges to proj_hyperion role for job  using emcli"
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 2: Schedule a one time backup (Cloud control)</td>" >> $summary_report_backup
					echo "    <td>$jobname</td>" >> $summary_report_backup
					echo "    <td>Success</td>" >> $summary_report_backup
					echo "    <td>Job scheduled date is $JOB_SCH_DATE</td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
					#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
					$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
					JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
					SC=""""					
					echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
					#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
					$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					    echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup					   
					fi	
				fi	
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
}


function Multi_CC_job_Immediate() {

			for i in `cat ${OUTPUT}/bkp_names1.txt`
			do
				echo $i
				DateTime1=`date +%d%m%y%H%M%S`
				##Get Cloud control job description#
				##Fields to be changed name,variable.default_shell_command,schedule.startTime,schedule.frequency,schedule.gracePeriod##
			
				$EMCLIHOME/emcli describe_job -name=$i > ${OUTPUT}/${i}_describe_${DateTime1}.txt
				if [[ "$i" == *"CONSOL_BACKUP"* ]]; then 
					echo "Job is a CONSOL_BACKUP backup  job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENV} ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ "$i" == "LCM_CONSOL"* ]]; then 
					echo "Job is a LCM_CONSOL backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_lcm_consol_wrapper.sh ${LCMENV} ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ "$i" == *"MIDDLEWARE"* ]]; then 
					echo "Job is a MIDDLEWARE backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_MWHOME ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ "$i" == *"ARBORPATH"* ]]; then 
					echo "Job is a ARBORPATH backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_ARPTH ${CHNGID} \'"
					#echo $VAR_SHELL
				else 	
					echo "Job is some other job"
				fi
								
				CC_JOB_INPUTFILE=${OUTPUT}/${i}_template_${DateTime1}.txt
				#CC_JOB_TEMPFILE=${OUTPUT}/${i}_template_${DateTime1}.txt
				export JOB_SCH_DATE=$jobschdate
				echo $JOB_SCH_DATE
				export CC_JOB_NAME=${i}_${DateTime1}
				#cp ${EMCLITEMPLATE}/${i}_template.txt $CC_JOB_TEMPFILE
				#eval "echo \"`cat $CC_JOB_TEMPFILE`\"" > $CC_JOB_INPUTFILE
				echo "Backup of ${OUTPUT}/${i}_describe_${DateTime1}.txt taken as ${OUTPUT}/${i}_describe_bkp_${DateTime1}.txt"
				cp ${OUTPUT}/${i}_describe_${DateTime1}.txt ${OUTPUT}/${i}_describe_bkp_${DateTime1}.txt
				sed -i "/name=/ c\name=${CC_JOB_NAME}" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				if [[ ${VAR_SHELL}x == "x" ]]; then
					echo "Job $i , variable.default_shell_command is not being replaced in Cloud control input file "
				else
					echo "Replacing variable.default_shell_command in Cloud control input file"	
					#echo $VAR_SHELL
					sed -i "/variable.default_shell_command/ c\ $VAR_SHELL" ${OUTPUT}/${i}_describe_${DateTime1}.txt 
				fi
				sed -i "/schedule.startTime/d" ${OUTPUT}/${i}_describe_${DateTime1}.txt 
				sed -i "/schedule.frequency/ c\schedule.frequency=IMMEDIATE" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				sed -i "/schedule.gracePeriod/ c\schedule.gracePeriod=15" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				sed -i "/schedule.days/d" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				cp ${OUTPUT}/${i}_describe_${DateTime1}.txt $CC_JOB_INPUTFILE
				
				echo "Backup job ${i} one time execution  immediate" >> $master_log_backup
				echo "$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file=\"property_file:$CC_JOB_INPUTFILE\""
				$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:$CC_JOB_INPUTFILE"
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 4: Execute backup now from Cloud control</td>" >> $summary_report_backup
					echo "    <td>$i</td>" >> $summary_report_backup
					echo "    <td>Failure</td>" >> $summary_report_backup
					echo "    <td></td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
				else
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "$DateTime: adding privileges to proj_hyperion role for job  using emcli"
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 4: Execute backup now from Cloud control</td>" >> $summary_report_backup
					echo "    <td>$i</td>" >> $summary_report_backup
					echo "    <td>Success</td>" >> $summary_report_backup
					echo "    <td></td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
					#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
					$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
					JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
					SC=""""					
					echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
					#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
					$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					    echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup					   
					fi	
				fi
			done
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				

}


function Single_CC_job_Immediate() {

				echo ${jobname}
				DateTime1=`date +%d%m%y%H%M%S`
				##Get Cloud control job description#
				##Fields to be changed name,variable.default_shell_command,schedule.startTime,schedule.frequency,schedule.gracePeriod##
			
				$EMCLIHOME/emcli describe_job -name=${jobname} > ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				if [[ $jobname == *"CONSOL_BACKUP"* ]]; then 
					echo "Job is a CONSOL_BACKUP backup  job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENV} ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ $jobname == "LCM_CONSOL"* ]]; then 
					echo "Job is a LCM_CONSOL backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_lcm_consol_wrapper.sh ${LCMENV} ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ $jobname == *"MIDDLEWARE"* ]]; then 
					echo "Job is a MIDDLEWARE backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_MWHOME ${CHNGID} \'"
					#echo $VAR_SHELL
				elif [[ $jobname == *"ARBORPATH"* ]]; then 
					echo "Job is a ARBORPATH backup job"
					#export VAR_SHELL="variable.default_shell_command=\'bash ${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_ARPTH ${CHNGID} \'"
					#echo $VAR_SHELL
				else 	
					echo "Job is some other job"
				fi
								
				CC_JOB_INPUTFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				#CC_JOB_TEMPFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				export JOB_SCH_DATE=$jobschdate
				echo $JOB_SCH_DATE
				export CC_JOB_NAME=${jobname}_${DateTime1}
				#cp ${EMCLITEMPLATE}/${jobname}_template.txt $CC_JOB_TEMPFILE
				#eval "echo \"`cat $CC_JOB_TEMPFILE`\"" > $CC_JOB_INPUTFILE
				echo "Backup of ${OUTPUT}/${jobname}_describe_${DateTime1}.txt taken as ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt"
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt
				sed -i "/name=/ c\name=${CC_JOB_NAME}" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				if [[ ${VAR_SHELL}x == "x" ]]; then
					echo "Job ${jobname} , variable.default_shell_command is not being replaced in Cloud control input file "
				else
					echo "Replacing variable.default_shell_command in Cloud control input file"	
					#echo $VAR_SHELL
					sed -i "/variable.default_shell_command/ c\ $VAR_SHELL" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt 
				fi
				sed -i "/schedule.startTime/d" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt 
				sed -i "/schedule.frequency/ c\schedule.frequency=IMMEDIATE" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.gracePeriod/ c\schedule.gracePeriod=15" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.days/d" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt $CC_JOB_INPUTFILE
				
				echo "Backup job ${jobname} one time execution immediate" >> $master_log_backup
				echo "$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file=\"property_file:$CC_JOB_INPUTFILE\""
				$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:$CC_JOB_INPUTFILE"
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 4: Execute backup now from Cloud control</td>" >> $summary_report_backup
					echo "    <td>${jobname}</td>" >> $summary_report_backup
					echo "    <td>Failure</td>" >> $summary_report_backup
					echo "    <td></td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
				else
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "$DateTime: adding privileges to proj_hyperion role for job  using emcli"
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 4: Execute backup now from Cloud control</td>" >> $summary_report_backup
					echo "    <td>${jobname}</td>" >> $summary_report_backup
					echo "    <td>Success</td>" >> $summary_report_backup
					echo "    <td></td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
					#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
					$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
					JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
					SC=""""					
					echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
					#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
					$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					    echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup					   
					fi	
				fi
			
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				

}


function Multi_CC_DB_job_Immediate() {

			for i in `cat ${OUTPUT}/bkp_names1.txt`
			do
				echo $i
				DateTime1=`date +%d%m%y%H%M%S`
				##Get Cloud control job description#
				##Fields to be changed name,variable.default_shell_command,schedule.startTime,schedule.frequency,schedule.gracePeriod##
			
				$EMCLIHOME/emcli describe_job -name=$i > ${OUTPUT}/${i}_describe_${DateTime1}.txt
								
				CC_JOB_INPUTFILE=${OUTPUT}/${i}_template_${DateTime1}.txt
				#CC_JOB_TEMPFILE=${OUTPUT}/${i}_template_${DateTime1}.txt
				export JOB_SCH_DATE=$jobschdate
				echo $JOB_SCH_DATE
				export CC_JOB_NAME=${i}_${DateTime1}
				#cp ${EMCLITEMPLATE}/${i}_template.txt $CC_JOB_TEMPFILE
				#eval "echo \"`cat $CC_JOB_TEMPFILE`\"" > $CC_JOB_INPUTFILE
				echo "Backup of ${OUTPUT}/${i}_describe_${DateTime1}.txt taken as ${OUTPUT}/${i}_describe_bkp_${DateTime1}.txt"
				cp ${OUTPUT}/${i}_describe_${DateTime1}.txt ${OUTPUT}/${i}_describe_bkp_${DateTime1}.txt
				sed -i "/name=/ c\name=${CC_JOB_NAME}" ${OUTPUT}/${i}_describe_${DateTime1}.txt

				sed -i "/schedule.startTime/d" ${OUTPUT}/${i}_describe_${DateTime1}.txt 
				sed -i "/schedule.frequency/ c\schedule.frequency=IMMEDIATE" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				sed -i "/schedule.gracePeriod/ c\schedule.gracePeriod=15" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				sed -i "/schedule.days/d" ${OUTPUT}/${i}_describe_${DateTime1}.txt
				cp ${OUTPUT}/${i}_describe_${DateTime1}.txt $CC_JOB_INPUTFILE
				
				echo "Backup job ${i} one time execution  immediate" >> $master_log_backup
				echo "$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file=\"property_file:$CC_JOB_INPUTFILE\""
				$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:$CC_JOB_INPUTFILE"
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 4: Execute backup now from Cloud control</td>" >> $summary_report_backup
					echo "    <td>$i</td>" >> $summary_report_backup
					echo "    <td>Failure</td>" >> $summary_report_backup
					echo "    <td></td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
				else
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "$DateTime: adding privileges to proj_hyperion role for job  using emcli"
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 4: Execute backup now from Cloud control</td>" >> $summary_report_backup
					echo "    <td>$i</td>" >> $summary_report_backup
					echo "    <td>Success</td>" >> $summary_report_backup
					echo "    <td></td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
					#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
					$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
					JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
					SC=""""					
					echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
					#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
					$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					    echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup					   
					fi	
				fi
			done
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				

}


function Single_CC_DB_job_Immediate() {

				echo ${jobname}
				DateTime1=`date +%d%m%y%H%M%S`
				##Get Cloud control job description#
				##Fields to be changed name,variable.default_shell_command,schedule.startTime,schedule.frequency,schedule.gracePeriod##
			
				$EMCLIHOME/emcli describe_job -name=${jobname} > ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
												
				CC_JOB_INPUTFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				#CC_JOB_TEMPFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				export JOB_SCH_DATE=$jobschdate
				echo $JOB_SCH_DATE
				export CC_JOB_NAME=${jobname}_${DateTime1}
				#cp ${EMCLITEMPLATE}/${jobname}_template.txt $CC_JOB_TEMPFILE
				#eval "echo \"`cat $CC_JOB_TEMPFILE`\"" > $CC_JOB_INPUTFILE
				echo "Backup of ${OUTPUT}/${jobname}_describe_${DateTime1}.txt taken as ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt"
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt
				sed -i "/name=/ c\name=${CC_JOB_NAME}" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt

				sed -i "/schedule.startTime/d" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt 
				sed -i "/schedule.frequency/ c\schedule.frequency=IMMEDIATE" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.gracePeriod/ c\schedule.gracePeriod=15" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.days/d" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt $CC_JOB_INPUTFILE
				
				echo "Backup job ${jobname} one time execution immediate" >> $master_log_backup
				echo "$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file=\"property_file:$CC_JOB_INPUTFILE\""
				$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:$CC_JOB_INPUTFILE"
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 4: Execute backup now from Cloud control</td>" >> $summary_report_backup
					echo "    <td>${jobname}</td>" >> $summary_report_backup
					echo "    <td>Failure</td>" >> $summary_report_backup
					echo "    <td></td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
				else
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}" >> $master_log_backup
					echo "$DateTime: adding privileges to proj_hyperion role for job  using emcli"
					echo "<tr>" >> $summary_report_backup
					echo "    <td>`date`</td>" >> $summary_report_backup
					echo "    <td>Backup step 4: Execute backup now from Cloud control</td>" >> $summary_report_backup
					echo "    <td>${jobname}</td>" >> $summary_report_backup
					echo "    <td>Success</td>" >> $summary_report_backup
					echo "    <td></td>" >> $summary_report_backup
					echo "</tr>" >> $summary_report_backup
					#echo "Executing command - $EMCLIHOME/emcli get_jobs -name="${CC_JOB_NAME}" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt"
					$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
					JOBID=`grep $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | awk '{print $3}'`
					SC=""""					
					echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
					#echo "Executing command - $EMCLIHOME/emcli grant_privs -name=\"PROJ_HYPERION\" -privilege=\"VIEW_JOB;$JOBID\""
					$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					    echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME" >> $master_log_backup					   
					fi	
				fi
			
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				

}


function BACKUPS() {

echo "#################################################################################################################################################"
echo  "Checking emcli status.."
$EMCLIHOME/emcli describe_job -name="QA1_CONSOL_BACKUP" > ${OUTPUT}/emcli_test.txt
RET=$?
echo ""
	if [ $RET -ne 0 ];then
		echo ""
		echo "$DateTime: ERROR: emcli setup on server is lost, follow the instruction below to execute Cloud control jobs, else only backup action which will work is 3. Execute backup immediately from this server"
		echo "Execute $EMCLIHOME/emcli setup -url=https://prod-em.sherwin.com/em -username=sw_jobadmin -trustall -autologin"
		echo "Provide the password for SW_JOBADMIN when prompted"
		echo ""
	else
		echo ""
		echo "$DateTime: SUCCESS: emcli setup on server is valid"
		echo ""
	fi
echo "#################################################################################################################################################"
	
read -p "DBA conducting the Maintenance (enter your sherwin id) " EMPID
read -p "Enter the Change Log Request ID : " CHNGID
echo "DBA conducting this step is "$EMPID
echo "Change Log request ID is "$CHNGID

if [[ "$CHNGID" = "" ]]; then
	echo "No change ID input for "$ENV
	
	export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_PREREQ_${EMPID}_${Day}.html
	export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report_PREPATCH_${EMPID}_${Day}.html
	export summary_report_backup=${PPLOGDIR}/${ENV}_PATCH_report_BACKUP_${EMPID}_${Day}.html
	export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_POSTPATCH_${EMPID}_${Day}.html
	export master_log_backup=${PPLOGDIR}/${ENV}_PATCH_Master_Log_BACKUP_${EMPID}_${Day}.log
	
else
	echo "Input file $INPUT_FILE sourced in for "$ENV
	echo "Change Log Request ID is "$CHNGID
	
	export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_PREREQ_${CHNGID}_${Day}.html
	export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report_PREPATCH_${CHNGID}_${Day}.html
	export summary_report_backup=${PPLOGDIR}/${ENV}_PATCH_report_BACKUP_${CHNGID}_${Day}.html
	export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_POSTPATCH_${CHNGID}_${Day}.html
	export master_log_backup=${PPLOGDIR}/${ENV}_PATCH_Master_Log_BACKUP_${CHNGID}_${Day}.log
	
fi
echo "----------"
echo "<br>" >> $summary_report_backup
echo "<table border="1">" >> $summary_report_backup  
echo "<tr>" >> $summary_report_backup  
echo "     <td><b>DBA</b></td>" >> $summary_report_backup  
echo "	   <td>$EMPID</td>" >> $summary_report_backup
echo "</tr>" >> $summary_report_backup  
echo "<tr>" >> $summary_report_backup 
echo "     <td><b>Step performed</b></td>" >> $summary_report_backup  
echo "	   <td>EPM Backups</td>" >> $summary_report_backup    
echo "</tr>" >> $summary_report_backup  
echo "<tr>" >> $summary_report_backup  
echo "     <td><b>Date</b></td>" >> $summary_report_backup  
echo "	   <td>`date`</td>" >> $summary_report_backup  
echo "</tr>" >> $summary_report_backup 
echo "<tr>" >> $summary_report_backup
echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_backup
echo "	   <td>$CHNGID</td>" >> $summary_report_backup
echo "</tr>" >> $summary_report_backup 
echo "<tr>" >> $summary_report_backup
echo "     <td><b>Method</b></td>" >> $summary_report_backup
echo "	   <td>Manual</td>" >> $summary_report_backup
echo "</tr>" >> $summary_report_backup
echo "</table>" >> $summary_report_backup  
echo "<br>" >> $summary_report_backup 

echo "<br>" >> $summary_report_backup
echo "<b>Backup execution</b>" >> $summary_report_backup
echo "<table border="1">" >> $summary_report_backup
echo "<tr>" >> $summary_report_backup
echo "    <th>Timestamp</th>" >> $summary_report_backup
echo "    <th>Step</th>" >> $summary_report_backup
echo "    <th>Backup Name</th>" >> $summary_report_backup
echo "    <th>Status</th>" >> $summary_report_backup
echo "    <th>Details</th>" >> $summary_report_backup
echo "</tr>" >> $summary_report_backup

echo "#################################################################################################################################################" >> $master_log_backup
echo "DBA: $EMPID" >> $master_log_backup
echo "Step performed: EPM Backups" >> $master_log_backup
echo "Date: `date`" >> $master_log_backup
echo "Change Log Request ID: $CHNGID" >> $master_log_backup
echo "Method: Manual" >> $master_log_backup
echo "#################################################################################################################################################" >> $master_log_backup

echo "Backup action to be performed:"
echo ""
echo "1. Cancel existing backup (Cloud control)
2. Schedule a one time backup (Cloud control)
3. Execute backup immediately from this server
4. Execute backup immediately from Cloud control 
5. Last Execution status for Cloud control backup jobs"
echo ""

		echo -n "Select Option, to exit 0 (zero): "
		read usrselec
		if [ $usrselec -eq 1 ]; then
			echo ""
			echo "Option $usrselec selected, Cancel existing backups scheduled in Cloud control. Listing backups for $ENV..."
			echo "Option $usrselec selected, Cancel existing backups scheduled in Cloud control. " >> $master_log_backup
			echo "------------------------------------------------------------------------------" >> $master_log_backup
			
			echo "" >> $master_log_backup
						
			echo ""
			cat ${CTRLLOC}/${ENV}_CC_backup_jobs.cfg
			echo ""
			echo -n "Select Job name option, to exit 0 (zero): "
			echo ""
			read usrselecjob
			if [ $usrselecjob = 1 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				linename=`grep "1#" ${CTRLLOC}/${ENV}_CC_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/${ENV}_bkp_cc_names.txt
				Multi_CC_job_cancel
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
			elif [ $usrselecjob -eq 2 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				linename=`grep "2#" ${CTRLLOC}/${ENV}_CC_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/${ENV}_bkp_cc_names.txt
				Multi_CC_job_cancel
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
			elif [ $usrselecjob -eq 3 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				linename=`grep "3#" ${CTRLLOC}/${ENV}_CC_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/${ENV}_bkp_cc_names.txt
				Multi_CC_job_cancel
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
			elif [ $usrselecjob -eq 4 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				linename=`grep "4#" ${CTRLLOC}/${ENV}_CC_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/${ENV}_bkp_cc_names.txt
				Multi_CC_job_cancel
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
			elif [ $usrselecjob -eq 5 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				linename=`grep "5#" ${CTRLLOC}/${ENV}_CC_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/${ENV}_bkp_cc_names.txt
				Multi_CC_job_cancel
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup

				
			elif [ $usrselecjob -eq 6 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname=`grep "6#" ${CTRLLOC}/${ENV}_CC_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				#export NEXTDAY=`date --date="next day" +%Y-%m-%d`
				Single_CC_job_cancel

				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup

			
			elif [ $usrselecjob -eq 7 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname=`grep "7#" ${CTRLLOC}/${ENV}_CC_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				#export NEXTDAY=`date --date="next day" +%Y-%m-%d`
				Single_CC_job_cancel
												
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup

			
			elif [ $usrselecjob -eq 8 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname=`grep "8#" ${CTRLLOC}/${ENV}_CC_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				#export NEXTDAY=`date --date="next day" +%Y-%m-%d`
				Single_CC_job_cancel
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup

				
			elif [ $usrselecjob -eq 9 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname=`grep "9#" ${CTRLLOC}/${ENV}_CC_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				#export NEXTDAY=`date --date="next day" +%Y-%m-%d`
				Single_CC_job_cancel

				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
		
			elif [ $usrselecjob -eq 10 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname=`grep "10#" ${CTRLLOC}/${ENV}_CC_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				#export NEXTDAY=`date --date="next day" +%Y-%m-%d`
				Single_CC_job_cancel
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
			
			elif [ $usrselecjob -eq 0 ]; then
				echo ""
				echo "Exiting to main screen"
				echo "Exited to main screen" >> $master_log_backup
				echo ""
				optionsScreen
			else
				echo ""
				echo "ERROR: Invalid option"
				echo "Exiting script"
				echo "ERROR: Invalid option used. Exiting script" >> $master_log_backup
				exit 1;
			fi
###############SCHEDULE JOB FROM CLOUD CONTROL - Template #####################		
		elif [ $usrselec -eq 2 ]; then	
			echo ""
			echo "Option $usrselec selected. Schedule a one time backup from cloud control. Listing backups for $ENV..."
			echo "Option $usrselec selected, Schedule a one time backup from cloud control. " >> $master_log_backup
			echo "------------------------------------------------------------------------------" >> $master_log_backup
			echo ""
			cat ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg
			echo ""
			echo -n "Select Job name option, to exit 0 (zero): "
			echo ""
			read usrselecjob1
			if [ $usrselecjob1 -eq 1 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "1#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names1.txt
				echo "Jobs to be scheduled for a one time run in Cloud Control: "$linename
				Mutli_CC_job_schedule
				
			elif [ $usrselecjob1 -eq 2 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "2#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names2.txt
				echo "Jobs to be scheduled for a one time run in Cloud Control: "$linename
				Mutli_CC_job_schedule
				
			elif [ $usrselecjob1 -eq 3 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "3#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names1.txt
				echo "Jobs to be scheduled for a one time run in Cloud Control: "$linename
				Mutli_CC_job_schedule
				
			elif [ $usrselecjob1 -eq 4 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "4#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names1.txt
				echo "Jobs to be scheduled for a one time run in Cloud Control: "$linename
				Mutli_CC_job_schedule
				
			elif [ $usrselecjob1 -eq 5 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "5#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names1.txt
				echo "Jobs to be scheduled for a one time run in Cloud Control: "$linename
				Mutli_CC_job_schedule
				
			elif [ $usrselecjob1 -eq 6 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "6#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be scheduled for a one time run in Cloud Control: "$jobname
				Single_CC_job_schedule
		
			elif [ $usrselecjob1 -eq 7 ]; then
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				echo "Job option selected="$usrselecjob1
				echo ""
				jobname=`grep "7#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be scheduled for a one time run in Cloud Control: "$jobname
				Single_CC_job_schedule
				
			elif [ $usrselecjob1 -eq 8 ]; then
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				echo "Job option selected="$usrselecjob1
				echo ""
				jobname=`grep "8#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be scheduled for a one time run in Cloud Control: "$jobname
				Single_CC_job_schedule
				
			elif [ $usrselecjob1 -eq 9 ]; then
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				echo "Job option selected="$usrselecjob1
				echo ""
				jobname=`grep "9#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be scheduled for a one time run in Cloud Control: "$jobname
				Single_CC_job_schedule
			
			elif [ $usrselecjob1 -eq 10 ]; then
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				echo "Job option selected="$usrselecjob1
				echo ""
				jobname=`grep "10#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be scheduled for a one time run in Cloud Control: "$jobname
				Single_CC_job_schedule
				
			elif [ $usrselecjob1 -eq 0 ]; then
				echo ""
				echo "Exiting to main screen"
				echo "Exited to main screen" >> $master_log_backup
				echo ""
				optionsScreen
			
			else
				echo ""
				echo "ERROR: Invalid option"
				echo "ERROR: Invalid option used. Exiting script" >> $master_log_backup
				echo "Exiting script"
				exit 1;
			fi
###############EXECUTE FROM SERVER IMMEDIATELY#####################			
		elif [ $usrselec -eq 3 ]; then	
			echo ""
			echo "Option $usrselec selected. Execute backup now on this server. Listing backups for $ENV..."
			echo "$DateTime: Option $usrselec selected. Execute backup now on this server. Listing backups for $ENV..." >> $master_log_backup
			echo "------------------------------------------------------------------------------" >> $master_log_backup
			echo ""
			cat ${CTRLLOC}/${ENV}_manual_run_backup_jobs.cfg
			echo ""
			echo ""
			echo -n "Select Job name option, to exit 0 (zero): "
			echo ""
			read usrselecjob2
			if [ $usrselecjob2 -eq 1 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				linename=`grep "1#" ${CTRLLOC}/${ENV}_manual_run_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names1_now.txt
				
				export ATINPUT1=${OUTPUT}/atinputfile_cons_opt1_${ENV}_${DateTime}.txt
				export ATINPUT2=${OUTPUT}/atinputfile_cons_opt1_${ENVT1}_${DateTime}.txt
				export ATINPUT3=${OUTPUT}/atinputfile_lcm_opt1_${ENV}_${DateTime}.txt
				
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$linename</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				
				if [[ "$ENV" = "QA1" || "$ENV" = "PROD1" || "$ENV" = "INFRA1"  ]]; then
					echo "${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENV} ${CHNGID}" > ${ATINPUT1}
					echo "${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENVT1} ${CHNGID}" > ${ATINPUT2}
					echo "CONSOL Wrapper Job manual execution from this server starting"
					echo "$DateTime: CONSOL Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ATINPUT1} now
					echo "Remotely executing CONSOL Wrapper Job on other node.."
					echo "$DateTime: Remotely executing CONSOL Wrapper Job on other node.." >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${ATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote CONSOL Wrapper Job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote CONSOL Wrapper Job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote CONSOL Wrapper Job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote CONSOL Wrapper Job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
					echo "${SCRIPTDIR}/prepost_lcm_consol_wrapper.sh ${LCMENV} ${CHNGID}" > ${ATINPUT3}
					echo "LCM CONSOL Wrapper Job manual execution from this server starting"
					echo "$DateTime: LCM CONSOL Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ATINPUT3} now
					
				elif [[ "$ENV" = "QA2" || "$ENV" = "PROD2" || "$ENV" = "INFRA2"  ]]; then
					echo "${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENV} ${CHNGID}" > ${ATINPUT1}
					echo "${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENVT1} ${CHNGID}" > ${ATINPUT2}
					echo "CONSOL Wrapper Job manual execution from this server starting"
					echo "$DateTime: CONSOL Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ATINPUT1} now
					echo "Remotely executing job on other node.."
					echo "$DateTime: Remotely executing CONSOL Wrapper Job on other node.." >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${ATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote CONSOL Wrapper Job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote CONSOL Wrapper Job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote CONSOL Wrapper Job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote CONSOL Wrapper Job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
					echo "${SCRIPTDIR}/prepost_lcm_consol_wrapper.sh ${LCMENV} ${CHNGID}" > ${ATINPUT3}
					echo "LCM CONSOL Wrapper Job manual execution from this server starting"
					echo "$DateTime: LCM CONSOL Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ATINPUT3} now
				
				else 
					echo "${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENV} ${CHNGID}" > ${ATINPUT1}
					echo "CONSOL Wrapper Job manual execution from this server starting"
					echo "$DateTime: CONSOL Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ATINPUT1} now	
					echo "${SCRIPTDIR}/prepost_lcm_consol_wrapper.sh ${LCMENV} ${CHNGID}" > ${ATINPUT3}
					echo "LCM CONSOL Wrapper Job manual execution from this server starting"
					echo "$DateTime: LCM CONSOL Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ATINPUT3} now
				fi
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
			elif [ $usrselecjob2 -eq 2 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				linename=`grep "2#" ${CTRLLOC}/${ENV}_manual_run_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names2_now.txt
						
				export MWATINPUT1=${OUTPUT}/atinputfile_mw_opt2_${ENV}_${DateTime}.txt
				export MWATINPUT2=${OUTPUT}/atinputfile_mw_opt2_${ENVT1}_${DateTime}.txt
				export ARPTHATINPUT1=${OUTPUT}/atinputfile_arpth_opt2_${ENV}_${DateTime}.txt
				export ARPTHATINPUT2=${OUTPUT}/atinputfile_arpth_opt2_${ENVT1}_${DateTime}.txt
				
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$linename</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				
				if [[ "$ENV" = "QA1" || "$ENV" = "PROD1" || "$ENV" = "INFRA1"  ]]; then
					echo "${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_MWHOME ${CHNGID}" > ${MWATINPUT1}
					echo "${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENVT1} ${BKPENVT1} ${LCMENV}_NODE2_MWHOME ${CHNGID}" > ${MWATINPUT2}
					echo "Job manual execution from this server starting"
					echo "$DateTime: MW HOME Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${MWATINPUT1} now
					echo "Remotely executing job on other node.."
					echo "$DateTime: Remotely executing MW HOME Wrapper Job on other node" >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${MWATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote MW HOME job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote MW HOME job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote MW HOME job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote MW HOME job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
					echo "${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_ARPTH ${CHNGID}" > ${ARPTHATINPUT1}
					echo "${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENVT1} ${BKPENVT1} ${LCMENV}_NODE2_ARPTH ${CHNGID}" > ${ARPTHATINPUT2}
					echo "Job manual execution from this server starting"
					echo "$DateTime: ARBORPATH Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ARPTHATINPUT1} now
					echo "Remotely executing job on other node.."
					echo "$DateTime: Remotely executing ARBORPATH Wrapper Job on other node" >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${ARPTHATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote ARBORPATH job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote ARBORPATH job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote ARBORPATH job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote ARBORPATH job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
					
				elif [[ "$ENV" = "QA2" || "$ENV" = "PROD2" || "$ENV" = "INFRA2"  ]]; then
					echo "${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE2_MWHOME ${CHNGID}" > ${MWATINPUT1}
					echo "${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENVT1} ${BKPENVT1} ${LCMENV}_NODE1_MWHOME ${CHNGID}" > ${MWATINPUT2}
					echo "Job manual execution from this server starting"
					echo "$DateTime: MW HOME Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${MWATINPUT1} now
					echo "Remotely executing job on other node.."
					echo "$DateTime: Remotely executing MW HOME Wrapper Job on other node" >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${MWATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote MW HOME job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote MW HOME job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote MW HOME job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote MW HOME job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
					echo "${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE2_ARPTH ${CHNGID}" > ${ARPTHATINPUT1}
					echo "${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENVT1} ${BKPENVT1} ${LCMENV}_NODE1_ARPTH ${CHNGID}" > ${ARPTHATINPUT2}
					echo "Job manual execution from this server starting"
					echo "$DateTime: ARBORPATH Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ARPTHATINPUT1} now
					echo "Remotely executing job on other node.."
					echo "$DateTime: Remotely executing ARBORPATH Wrapper Job on other node" >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${ARPTHATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote ARBORPATH job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote ARBORPATH job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote ARBORPATH job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote ARBORPATH job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
				
				else 
					echo "${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_MWHOME ${CHNGID}" > ${MWATINPUT1}
					echo "Job manual execution from this server starting"
					echo "$DateTime: MW HOME Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${MWATINPUT1} now	
					echo "${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_ARPTH  ${CHNGID}" > ${ARPTHATINPUT1}
					echo "Job manual execution from this server starting"
					echo "$DateTime: ARBORPATH Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ARPTHATINPUT1} now
				fi
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
			elif [ $usrselecjob2 -eq 3 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				linename=`grep "3#" ${CTRLLOC}/${ENV}_manual_run_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names2_now.txt
						
				export MWATINPUT1=${OUTPUT}/atinputfile_mw_opt2_${ENV}_${DateTime}.txt
				export MWATINPUT2=${OUTPUT}/atinputfile_mw_opt2_${ENVT1}_${DateTime}.txt
								
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$linename</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				
				if [[ "$ENV" = "QA1" || "$ENV" = "PROD1" || "$ENV" = "INFRA1"  ]]; then
					echo "${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_MWHOME ${CHNGID}" > ${MWATINPUT1}
					echo "${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENVT1} ${BKPENVT1} ${LCMENV}_NODE2_MWHOME ${CHNGID}" > ${MWATINPUT2}
					echo "Job manual execution from this server starting"
					echo "$DateTime: MW HOME Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${MWATINPUT1} now
					echo "Remotely executing job on other node.."
					echo "$DateTime: Remotely executing MW HOME Wrapper Job on other node" >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${MWATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote MW HOME job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote MW HOME job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote MW HOME job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote MW HOME job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
					
					
				elif [[ "$ENV" = "QA2" || "$ENV" = "PROD2" || "$ENV" = "INFRA2"  ]]; then
					echo "${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE2_MWHOME ${CHNGID}" > ${MWATINPUT1}
					echo "${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENVT1} ${BKPENVT1} ${LCMENV}_NODE1_MWHOME ${CHNGID}" > ${MWATINPUT2}
					echo "Job manual execution from this server starting"
					echo "$DateTime: MW HOME Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${MWATINPUT1} now
					echo "Remotely executing job on other node.."
					echo "$DateTime: Remotely executing MW HOME Wrapper Job on other node" >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${MWATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote MW HOME job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote MW HOME job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote MW HOME job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote MW HOME job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
					
				
				else 
					echo "${SCRIPTDIR}/prepost_MW_HOME_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_MWHOME ${CHNGID}" > ${MWATINPUT1}
					echo "Job manual execution from this server starting"
					echo "$DateTime: MW HOME Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${MWATINPUT1} now	
					
				fi
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup

			elif [ $usrselecjob2 -eq 4 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				linename=`grep "4#" ${CTRLLOC}/${ENV}_manual_run_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names2_now.txt
						
				export ARPTHATINPUT1=${OUTPUT}/atinputfile_arpth_opt2_${ENV}_${DateTime}.txt
				export ARPTHATINPUT2=${OUTPUT}/atinputfile_arpth_opt2_${ENVT1}_${DateTime}.txt
				
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$linename</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				
				if [[ "$ENV" = "QA1" || "$ENV" = "PROD1" || "$ENV" = "INFRA1"  ]]; then
					
					echo "${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_ARPTH ${CHNGID}" > ${ARPTHATINPUT1}
					echo "${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENVT1} ${BKPENVT1} ${LCMENV}_NODE2_ARPTH ${CHNGID}" > ${ARPTHATINPUT2}
					echo "Job manual execution from this server starting"
					echo "$DateTime: ARBORPATH Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ARPTHATINPUT1} now
					echo "Remotely executing job on other node.."
					echo "$DateTime: Remotely executing ARBORPATH Wrapper Job on other node" >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${ARPTHATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote ARBORPATH job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote ARBORPATH job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote ARBORPATH job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote ARBORPATH job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
					
				elif [[ "$ENV" = "QA2" || "$ENV" = "PROD2" || "$ENV" = "INFRA2"  ]]; then
					
					echo "${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE2_ARPTH ${CHNGID}" > ${ARPTHATINPUT1}
					echo "${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENVT1} ${BKPENVT1} ${LCMENV}_NODE1_ARPTH ${CHNGID}" > ${ARPTHATINPUT2}
					echo "Job manual execution from this server starting"
					echo "$DateTime: ARBORPATH Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ARPTHATINPUT1} now
					echo "Remotely executing job on other node.."
					echo "$DateTime: Remotely executing ARBORPATH Wrapper Job on other node" >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${ARPTHATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote ARBORPATH job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote ARBORPATH job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote ARBORPATH job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote ARBORPATH job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
				
				else 
					echo "${SCRIPTDIR}/prepost_ARPTH_backup_wrapper.sh ${ENV} ${BKPENVT} ${LCMENV}_NODE1_ARPTH  ${CHNGID}" > ${ARPTHATINPUT1}
					echo "Job manual execution from this server starting"
					echo "$DateTime: ARBORPATH Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ARPTHATINPUT1} now
				fi
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup

			elif [ $usrselecjob2 -eq 5 ]; then
			
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				jobname=`grep "5#" ${CTRLLOC}/${ENV}_manual_run_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be run now from this server: "$jobname	
				echo "$DateTime: Job to be run now from this server: "$jobname >> $master_log_backup
				export ATINPUT1=${OUTPUT}/atinputfile_cons_opt1_${ENV}_${DateTime}.txt
				export ATINPUT2=${OUTPUT}/atinputfile_cons_opt1_${ENVT1}_${DateTime}.txt
				export ATINPUT3=${OUTPUT}/atinputfile_lcm_opt1_${ENV}_${DateTime}.txt
				
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$jobname</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				
				if [[ "$ENV" = "QA1" || "$ENV" = "PROD1" || "$ENV" = "INFRA1"  ]]; then
					echo "${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENV} ${CHNGID}" > ${ATINPUT1}
					echo "CONSOL Wrapper Job manual execution from this server starting"
					echo "$DateTime: CONSOL Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ATINPUT1} now
													
				elif [[ "$ENV" = "QA2" || "$ENV" = "PROD2" || "$ENV" = "INFRA2"  ]]; then
					
					echo "${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENVT1} ${CHNGID}" > ${ATINPUT2}
					echo "Remotely executing job on other node.."
					echo "$DateTime: Remotely executing CONSOL Wrapper Job on other node.." >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${ATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote CONSOL Wrapper Job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote CONSOL Wrapper Job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote CONSOL Wrapper Job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote CONSOL Wrapper Job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
												
				else 
					echo "${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENV} ${CHNGID}" > ${ATINPUT1}
					echo "CONSOL Wrapper Job manual execution from this server starting"
					echo "$DateTime: CONSOL Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ATINPUT} now	
				fi
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
			
			elif [ $usrselecjob2 -eq 6 ]; then
			
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				jobname=`grep "6#" ${CTRLLOC}/${ENV}_manual_run_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be run now from this server: "$jobname	
				echo "$DateTime: Job to be run now from this server: "$jobname >> $master_log_backup
				export ATINPUT1=${OUTPUT}/atinputfile_cons_opt1_${ENV}_${DateTime}.txt
				export ATINPUT2=${OUTPUT}/atinputfile_cons_opt1_${ENVT1}_${DateTime}.txt
				export ATINPUT3=${OUTPUT}/atinputfile_lcm_opt1_${ENV}_${DateTime}.txt
				
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$jobname</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				
				if [[ "$ENV" = "QA1" || "$ENV" = "PROD1" || "$ENV" = "INFRA1"  ]]; then
									
					echo "${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENVT1} ${CHNGID}" > ${ATINPUT2}
					echo "Remotely executing job on other node.."
					echo "$DateTime: Remotely executing CONSOL Wrapper Job on other node.." >> $master_log_backup
					export SHELL_PATH_PARAM="at -f ${ATINPUT2} now"
					ssh ${OSUSER}@${OTHR_NODE} "${SHELL_PATH_PARAM}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: Remote CONSOL Wrapper Job execution on ${OTHR_NODE} failed"
					   echo "$DateTime: Remote CONSOL Wrapper Job execution on ${OTHR_NODE} failed" >> $master_log_backup
					else
					   echo "$DateTime: SUCCESS - Remote CONSOL Wrapper Job execution on ${OTHR_NODE}"
					   echo "$DateTime: SUCCESS - Remote CONSOL Wrapper Job execution on ${OTHR_NODE}" >> $master_log_backup
					fi
													
				elif [[ "$ENV" = "QA2" || "$ENV" = "PROD2" || "$ENV" = "INFRA2"  ]]; then
					
					echo "${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENV} ${CHNGID}" > ${ATINPUT1}
					echo "CONSOL Wrapper Job manual execution from this server starting"
					echo "$DateTime: CONSOL Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ATINPUT1} now
					
				else 
					echo "${SCRIPTDIR}/prepost_consol_wrapper.sh ${ENV} ${CHNGID}" > ${ATINPUT1}
					echo "CONSOL Wrapper Job manual execution from this server starting"
					echo "$DateTime: CONSOL Wrapper Job manual execution from this server starting" >> $master_log_backup
					at -f ${ATINPUT} now	
				fi
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
			elif [ $usrselecjob2 -eq 7 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				jobname=`grep "7#" ${CTRLLOC}/${ENV}_manual_run_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be run now from this server: "$jobname
				echo "$DateTime: Job to be run now from this server: "$jobname >> $master_log_backup
				export ATINPUT1=${OUTPUT}/atinputfile_cons_opt1_${ENV}_${DateTime}.txt
				export ATINPUT2=${OUTPUT}/atinputfile_cons_opt1_${ENVT1}_${DateTime}.txt
				export ATINPUT3=${OUTPUT}/atinputfile_lcm_opt1_${ENV}_${DateTime}.txt

				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$jobname</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				
				echo "${SCRIPTDIR}/prepost_lcm_consol_wrapper.sh ${LCMENV} ${CHNGID}" > ${ATINPUT3}
				echo "LCM CONSOL Wrapper Job manual execution from this server starting"
				echo "$DateTime: LCM CONSOL Wrapper Job manual execution from this server starting" >> $master_log_backup
				at -f ${ATINPUT3} now

				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
						
			elif [ $usrselecjob2 -eq 8 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				jobname=`grep "8#" ${CTRLLOC}/${ENV}_manual_run_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be run now from this server: "$jobname
				echo -n "Enter the job name from the control file: "
				echo ""
				read dbajobname
				BKPNAME=$dbajobname
				echo "$DateTime: Job to be run now from this server: "$jobname >> $master_log_backup
				echo "$DateTime: Job name to be executed = $BKPNAME" >> $master_log_backup
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$jobname</td>" >> $summary_report_backup
				echo "    <td>$dbajobname</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				export ATINPUT=${OUTPUT}/atinputfile_ess_master_${DateTime}.txt
				echo "${SCRIPTDIR}/prepost_essbase_master_wrapper.sh ${ENV} ${BKPENVT} ${BKPNAME} ${CHNGID}" > ${ATINPUT}
				echo "$DateTime: Job manual execution from this server starting"
				echo "$DateTime: Job manual execution from this server starting" >> $master_log_backup
				cat ${ATINPUT}
				at -f ${ATINPUT} now
				
			
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
			
			elif [ $usrselecjob2 -eq 9 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				jobname=`grep "9#" ${CTRLLOC}/${ENV}_manual_run_backup_jobs.cfg | cut -d"#" -f2`
				echo "LCM Job to be run now from this server: "$jobname
				echo -n "Enter the job name from the control file: "
				echo ""
				read dbajobname1
				BKPNAME=$dbajobname1
				echo "$DateTime: LCM Job to be run now from this server: "$jobname >> $master_log_backup
				echo "$DateTime: LCM Job name to be executed = $BKPNAME" >> $master_log_backup
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$jobname</td>" >> $summary_report_backup
				echo "    <td>$dbajobname1</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				export ATINPUT=${OUTPUT}/atinputfile_lcm_master_${DateTime}.txt
				echo "${SCRIPTDIR}/prepost_lcm_master_wrapper.sh ${ENV} ${BKPENVT} ${BKPNAME} ${CHNGID}" > ${ATINPUT}
				echo "$DateTime: LCM Job manual execution from this server starting"
				echo "$DateTime: LCM Job manual execution from this server starting" >> $master_log_backup
				cat ${ATINPUT}
				at -f ${ATINPUT} now
				
			
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup	
			
			elif [ $usrselecjob2 -eq 0 ]; then
				echo ""
				echo "Exiting to main screen"
				echo "Exited to main screen" >> $master_log_backup
				echo ""
				optionsScreen
			
			else
				echo ""
				echo "ERROR: Invalid option"
				echo "Exiting script"
				echo "ERROR: Invalid option used. Exiting script." >> $master_log_backup
				exit 1;
			fi
###############EXECUTE FROM CLOUD CONTROL IMMEDIATELY - Library job#####################
		elif [ $usrselec -eq 4 ]; then	
			echo ""
			echo "Option $usrselec selected. Execute backup immediately from Cloud control. Listing backups for $ENV..."
			echo "Option $usrselec selected. Execute backup immediately from Cloud control. Listing backups for $ENV..." >> $master_log_backup
			echo "------------------------------------------------------------------------------" >> $master_log_backup
			echo ""
			cat ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg
			echo ""
			echo -n "Select Job name option, to exit 0 (zero): "
			echo ""
			read usrselecjob3
			if [ $usrselecjob3 -eq 1 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "1#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names1.txt
				Multi_CC_job_Immediate
				
			elif [ $usrselecjob3 -eq 2 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "2#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names2.txt
				echo "Job to be executed immediately from Cloud Control: "$jobname
				Multi_CC_job_Immediate
				
			elif [ $usrselecjob3 -eq 3 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "3#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names1.txt
				Multi_CC_job_Immediate
				
			elif [ $usrselecjob3 -eq 4 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "4#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names1.txt
				Multi_CC_job_Immediate
				
			elif [ $usrselecjob3 -eq 5 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "5#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names1.txt
				Multi_CC_job_Immediate
				
			elif [ $usrselecjob3 -eq 6 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "6#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				Single_CC_job_Immediate	
			
			elif [ $usrselecjob3 -eq 7 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "7#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be executed immediately from Cloud Control: "$jobname
				Single_CC_job_Immediate
			
			elif [ $usrselecjob3 -eq 8 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "8#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be executed immediately from Cloud Control: "$jobname
				Single_CC_job_Immediate
				
			elif [ $usrselecjob3 -eq 9 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "9#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be executed immediately from Cloud Control: "$jobname
				Single_CC_job_Immediate
			
			elif [ $usrselecjob3 -eq 10 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "10#" ${CTRLLOC}/${ENV}_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be executed immediately from Cloud Control: "$jobname
				Single_CC_job_Immediate
			
			elif [ $usrselecjob3 -eq 0 ]; then
				echo ""
				echo "Exiting to main screen"
				echo ""
				optionsScreen
			
			else
				echo ""
				echo "ERROR: Invalid option"
				echo "Exiting script"
				exit 1;
			fi
###############CLOUD CONTROL JOB STATUS#####################		
		elif [ $usrselec -eq 5 ]; then
				echo ""
				echo "Checking the last execution status for cloud control jobs for $ENV"
				echo "$DateTime: Checking the last execution status for cloud control jobs for $ENV" >> $master_log_backup
				echo "------------------------------------------------------------------------------" >> $master_log_backup
				echo ""
				echo "Listing backups for $ENV..."
				echo ""
				cat ${CTRLLOC}/${ENV}_status_all_backup_jobs.cfg
				echo ""
				echo "Fetching the last execution status of jobs"
				echo ""
				for n in `cat ${CTRLLOC}/${ENV}_status_all_backup_jobs.cfg`
				do
				${EMCLIHOME}/emcli get_jobs -name="${n}" -owner="SW_JOBADMIN" > ${OUTPUT}/job_exec_${n}.txt	
				
				tail -2 ${OUTPUT}/job_exec_${n}.txt | head -1 > ${OUTPUT}/last_job_exec_${n}.txt	
				#cat ${OUTPUT}/last_job_exec_${n}.txt	
				fromdate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $5}'`
				fromtime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $6}'`
				todate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $7}'`
				totime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $8}'`
				status=`cat ${OUTPUT}/last_job_exec_${n}.txt | awk '{print $10}'`
				
				echo "Last execution status for backup ${n}: ${status}"
				echo "Execution Start Time: $fromdate $fromtime "
				echo "Execution End Time: $todate $totime "
				
				echo "Last execution status for backup ${n}: ${status}" >> $master_log_backup
				echo "Execution Start Time: $fromdate $fromtime " >> $master_log_backup 
				echo "Execution End Time: $todate $totime " >> $master_log_backup
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 5: Last Execution status for Cloud control backup jobs </td>" >> $summary_report_backup
				echo "    <td>$n</td>" >> $summary_report_backup
				echo "    <td>${status}</td>" >> $summary_report_backup
				echo "    <td>Execution Start Time: $fromdate $fromtime , Execution End Time: $todate $totime </td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				echo "<br>" >> $summary_report_backup
				echo ""
				
				done
				echo ""
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
		elif [ $usrselec -eq 0 ]; then
				echo ""
				echo "Exiting to main screen"
				optionsScreen	
		else 
			echo ""
			echo "ERROR: Invalid option"
			echo "Exiting script"
			exit 1;
		fi
echo "<br>" >> $summary_report_backup		
echo ""
echo ""
optionsScreen
}


function postPatchSteps() {
echo ""
echo ""

read -p "DBA conducting the Maintenance (enter your sherwin id) " EMPID
read -p "Enter the Change Log Request ID : " CHNGID
echo "DBA conducting this step is "$EMPID
echo "Change Log request ID is "$CHNGID


if [[ "$CHNGID" = "" ]]; then
	echo "No change ID input for "$ENV
	
	export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_PREREQ_${EMPID}_${Day}.html
	export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report_PREPATCH_${EMPID}_${Day}.html
	export summary_report_backup=${PPLOGDIR}/${ENV}_PATCH_report_BACKUP_${EMPID}_${Day}.html
	export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_POSTPATCH_${EMPID}_${Day}.html
	export master_log_postpatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_POSTPATCH_${EMPID}_${Day}.log
else
	echo "Input file $INPUT_FILE sourced in for "$ENV
	echo "Change Log Request ID is "$CHNGID
	
	export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_PREREQ_${CHNGID}_${Day}.html
	export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report_PREPATCH_${CHNGID}_${Day}.html
	export summary_report_backup=${PPLOGDIR}/${ENV}_PATCH_report_BACKUP_${CHNGID}_${Day}.html
	export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_POSTPATCH_${CHNGID}_${Day}.html
	export master_log_postpatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_POSTPATCH_${CHNGID}_${Day}.log
fi
echo "----------"
echo "<br>" >> $summary_report_postpatch
echo "<table border="1">" >> $summary_report_postpatch  
echo "<tr>" >> $summary_report_postpatch  
echo "     <td><b>DBA</b></td>" >> $summary_report_postpatch  
echo "	   <td>$EMPID</td>" >> $summary_report_postpatch
echo "</tr>" >> $summary_report_postpatch
echo "<tr>" >> $summary_report_postpatch  
echo "     <td><b>Step Performed</b></td>" >> $summary_report_postpatch  
echo "	   <td>EPM Postpatch Steps</td>" >> $summary_report_postpatch    
echo "</tr>" >> $summary_report_postpatch  
echo "<tr>" >> $summary_report_postpatch  
echo "     <td><b>Date</b></td>" >> $summary_report_postpatch  
echo "	   <td>`date`</td>" >> $summary_report_postpatch  
echo "</tr>" >> $summary_report_postpatch
echo "<tr>" >> $summary_report_postpatch
echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_postpatch
echo "	   <td>$CHNGID</td>" >> $summary_report_postpatch
echo "</tr>" >> $summary_report_postpatch
echo "<tr>" >> $summary_report_postpatch
echo "     <td><b>Method</b></td>" >> $summary_report_postpatch
echo "	   <td>Manual</td>" >> $summary_report_postpatch
echo "</tr>" >> $summary_report_postpatch
echo "</table>" >> $summary_report_postpatch  
echo "<br>" >> $summary_report_postpatch 
echo "<br>" >> $summary_report_postpatch 

echo "#################################################################################################################################################" > $master_log_postpatch
echo "DBA: $EMPID" >> $master_log_postpatch
echo "Step performed: EPM Postpatch Steps" >> $master_log_postpatch
echo "Date: `date`" >> $master_log_postpatch
echo "Change Log Request ID: $CHNGID" >> $master_log_postpatch
echo "Method: Manual" >> $master_log_postpatch
echo "#################################################################################################################################################" >> $master_log_postpatch


#Post patching step 1: lsinventory command
echo "####################################################################################################"
echo "Post patching step 1: lsinventory command"
echo "####################################################################################################"echo ""
echo ""
cd $EPM_ORACLE_HOME/OPatch
echo "./opatch lsinventory -oh $EPM_ORACLE_HOME -jdk $MIDDLEWARE_HOME/jdk160_35 -invPtrLoc $EPM_ORACLE_HOME/oraInst.loc"
export TodayDate=`date +%d_%m_%Y`
export lsinvDate1=`date +%Y-%m-%d_%I-%M`
export POSTPATCHDIR=${BACKUPDIR}/PREPOST/POSTPATCH_${ENV}_${CHNGID}_${TodayDate}
./opatch lsinventory -oh $EPM_ORACLE_HOME -jdk $MIDDLEWARE_HOME/jdk160_35 -invPtrLoc $EPM_ORACLE_HOME/oraInst.loc > ${OUTPUT}/lsinventory_postpatch_${ENV}.txt
VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Executing lsinventory command for $ENV"
		echo "<br>" >> $summary_report_postpatch
		echo "<b>Post Patching</b>" >> $summary_report_postpatch  
		echo "<table border="1">" >> $summary_report_postpatch  
		echo "<tr>" >> $summary_report_postpatch  
		echo "    <th>Timestamp</th>" >> $summary_report_postpatch 
		echo "    <th>Step</th>" >> $summary_report_postpatch
		echo "    <th>Status</th>" >> $summary_report_postpatch 
		echo "    <th>Details</th>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 		
		echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>Fulldate</td>" >> $summary_report_postpatch 
		echo "    <td>Post patching step 1: Execute lsinventory command</td>" >> $summary_report_postpatch
		echo "    <td>Failure</td>" >> $summary_report_postpatch 
		echo "    <td></td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "" >> $master_log_postpatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
		echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_postpatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
		echo "`date`|Post patching step 1: Execute lsinventory command |Failure      | " >> $master_log_postpatch
		cat $master_log_postpatch
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Executing lsinventory command for $ENV"
	 # cd $EPM_ORACLE_HOME/cfgtoollogs/opatch/lsinv/
	 # filename=`ls | grep ${lsinvDate1}`
	 filename=`grep "Lsinventory Output file location " ${OUTPUT}/lsinventory_postpatch_${ENV}.txt | cut -d":" -f2`
	 echo $filename
	 export POSTPATCHDIR=${BACKUPDIR}/PREPOST/POSTPATCH_${ENV}_${CHNGID}_${TodayDate}
	 mkdir ${POSTPATCHDIR}
	 cp $filename ${POSTPATCHDIR}
	 echo "$DateTime: Copied lsinventory file to ${POSTPATCHDIR}"
	 ls -ltr ${POSTPATCHDIR}
	 	echo "<br>" >> $summary_report_backup
		echo "<b>Post Patching</b>" >> $summary_report_postpatch  
		echo "<table border="1">" >> $summary_report_postpatch  
		echo "<tr>" >> $summary_report_postpatch  
		echo "    <th>Timestamp</th>" >> $summary_report_postpatch 
		echo "    <th>Step</th>" >> $summary_report_postpatch
		echo "    <th>Status</th>" >> $summary_report_postpatch 
		echo "    <th>Details</th>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>Post patching step 1: Execute lsinventory command</td>" >> $summary_report_postpatch
		echo "    <td>Success</td>" >> $summary_report_postpatch 
		echo "    <td>Copied lsinventory file $filename to ${POSTPATCHDIR}</td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
		echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_postpatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
		echo "`date`|Post patching step 1: Execute lsinventory command |Success      |Copied lsinventory file $filename to ${POSTPATCHDIR} " >> $master_log_postpatch
 fi

echo ""
echo ""


 #Post patching step 2: EPM registry command
 echo "####################################################################################################"
 echo "Post patching step 2: EPM registry command"
 echo "####################################################################################################"
 echo ""
echo ""
 cd $EPM_ORACLE_INSTANCE/bin
 echo "./epmsys_registry.sh"
./epmsys_registry.sh
VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Post patching step 2: EPM registry command for $ENV"
	  	echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>Post patching step 2: Generate EPM registry report</td>" >> $summary_report_postpatch
		echo "    <td>Failure</td>" >> $summary_report_postpatch 
		echo "    <td></td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch
		echo "`date`|Post patching step 2: Generate EPM registry report |Failure      | " >> $master_log_postpatch
		cat $master_log_postpatch
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Post patching step 2: EPM registry command for $ENV"
	 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
	 cp registry.html ${POSTPATCHDIR}
	 echo "$DateTime: Copied registry.html file to ${POSTPATCHDIR}"
	 ls -ltr ${POSTPATCHDIR}
		echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>Post patching step 2: Generate EPM registry report</td>" >> $summary_report_postpatch
		echo "    <td>Success</td>" >> $summary_report_postpatch 
		echo "    <td>Copied registry.html file to ${POSTPATCHDIR}</td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "`date`|Post patching step 2: Generate EPM registry report |Success      |Copied registry.html file to ${POSTPATCHDIR} " >> $master_log_postpatch
 fi
echo ""
echo ""

#Post patching step 3: Generate deployment report
 echo "####################################################################################################"
 echo "Post patching step 3: Generate EPM deployment report"
 echo "####################################################################################################"
 echo ""
echo ""
cd $EPM_ORACLE_INSTANCE/bin
echo "./epmsys_registry.sh report deployment"
export deplreptDate1=`date +%Y%m%d_%H%M`
./epmsys_registry.sh report deployment
VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Generating EPM deployment report for $ENV"
	  	echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>Post patching step 3: Generate EPM Deployment report</td>" >> $summary_report_postpatch
		echo "    <td>Failure</td>" >> $summary_report_postpatch 
		echo "    <td></td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "`date`|Post patching step 3: Generate EPM Deployment report |Failure      | " >> $master_log_postpatch
		cat $master_log_postpatch
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Generating EPM deployment report for $ENV"
	 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
	 filename=`ls -lrt |awk '{print $9}' |tail -1`
	 cp $filename ${POSTPATCHDIR}
	 echo "$DateTime: Copied EPM deployment reportfile to ${POSTPATCHDIR}"
	 ls -ltr ${POSTPATCHDIR}
		echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>Post patching step 3: Generate EPM Deployment report</td>" >> $summary_report_postpatch
		echo "    <td>Success</td>" >> $summary_report_postpatch 
		echo "    <td>Copied $filename to ${POSTPATCHDIR}</td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "`date`|Post patching step 3: Generate EPM Deployment report |Success      |Copied $filename to ${POSTPATCHDIR} " >> $master_log_postpatch
 fi
 
 
 #Post patching step 4: Backup of oraInventory
 echo "####################################################################################################"
 echo "Post patching step 4: Backup of oraInventory"
 echo "####################################################################################################"
 echo ""
 echo ""
 INVLOC=`grep inventory_loc $EPM_ORACLE_HOME/oraInst.loc | cut -d"=" -f2`
 echo "Oracle Inventory location: $INVLOC"
tar -cvf ${BACKUPDIR}/INV_BACKUPS/${Day1}_${ENV}_POSTPATCH_OraInventory.tar ${INVLOC}
 VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Backup of oraInventory for $ENV"
	  	echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>Post patching step 4: Backup of oraInventory</td>" >> $summary_report_postpatch
		echo "    <td>Failure</td>" >> $summary_report_postpatch 
		echo "    <td></td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "" >> $master_log_postpatch
		echo "`date`|Post patching step 4: Backup of oraInventory |Failure      | " >> $master_log_postpatch
		cat $master_log_postpatch
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Backup of oraInventory for $ENV"
	 ls -ltr ${BACKUPDIR}/INV_BACKUPS/
	 	echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>Post patching step 4: Backup of oraInventory</td>" >> $summary_report_postpatch
		echo "    <td>Success</td>" >> $summary_report_postpatch 
		echo "    <td>Copied ${Day1}_${ENV}_POSTPATCH_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/</td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "`date`|Post patching step 4: Backup of oraInventory |Success      |Copied ${Day1}_${ENV}_POSTPATCH_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/ " >> $master_log_postpatch
 fi
 
 #Post patching step 5: Critial file copy
 echo "####################################################################################################"
  echo "Post patching step 5: Critial file copy"
 echo "####################################################################################################"
 echo ""
 echo ""
 cd ${SCRIPTDIR}/
 export Day33=`date +%Y-%m-%d_%H_%M`
./Critical_File_copy.sh
VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Executing Critial file copy for $ENV"
	  	  	echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>Post patching step 5: Critial file copy</td>" >> $summary_report_postpatch
		echo "    <td>Failure</td>" >> $summary_report_postpatch 
		echo "    <td></td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "`date`|Post patching step 5: Critial file copy |Failure      | " >> $master_log_postpatch
		cat $master_log_postpatch
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Executing Critial file copy for $ENV"
	 crit_dir=`ls ${BACKUPDIR}/Critical_File_Copy | grep ${Day33}`
	 export postpatch_crit_dir=${BACKUPDIR}/Critical_File_Copy/${ENV}_${CHNGID}_POSTPATCH_EPM_${Day33}
	 echo "Critical files copied to directory $crit_dir under ${BACKUPDIR}/Critical_File_Copy"
	 mv ${BACKUPDIR}/Critical_File_Copy/${Day33} ${postpatch_crit_dir}
	 echo "Listing files in ${postpatch_crit_dir}"
	 ls -ltr ${postpatch_crit_dir}
	 	echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>Post patching step 5: Critial file copy</td>" >> $summary_report_postpatch
		echo "    <td>Success</td>" >> $summary_report_postpatch 
		echo "    <td>Copied ${ENV}_${CHNGID}_POSTPATCH_${Day33} to ${BACKUPDIR}/Critical_File_Copy</td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "</table>" >> $summary_report_postpatch 
		echo "<br>" >> $summary_report_postpatch 
		echo "<br>" >> $summary_report_postpatch 
		echo "`date`|Post patching step 5: Critial file copy |Success      |Copied ${ENV}_${CHNGID}_POSTPATCH_${Day33} to ${BACKUPDIR}/Critical_File_Copy " >> $master_log_postpatch
 fi

echo ""
echo ""
echo "Post patching differences check"
cd ${BACKUPDIR}/Critical_File_Copy
echo ""
##3 cases to be checked - change id not provided. wrong change id. multiple post patch folders for same change id, multiple prepatch folders for same change id##

if [ "x${CHNGID}" = "x" ]; then
        echo "###############################################################################################################################################"
        echo "Change ID not input by user. Using the Gold copy of Critical Files for comparison"
        echo "###############################################################################################################################################"
        export prepatch_crit_dir1=${GOLD_CRIT_FILE_DIR}
         cd /global/ora_backup/Critical_File_Copy
        export postpatch_crit_dir1=`ls |grep ${ENV}_${CHNGID}_POSTPATCH_EPM_${Day33}`
        #export gold_copy_crit_dir=${GOLD_CRIT_FILE_DIR}
        echo "Checking differences between ${prepatch_crit_dir1} and ${postpatch_crit_dir1}"

else

        echo "###############################################################################################################################################"
        echo "Change ID input by user. Checking if change log id was input during PrePatch step"
        echo "###############################################################################################################################################"
        Prepatch_dir_present=`ls |grep -q ${ENV}_${CHNGID}_PREPATCH_EPM ; echo $?`
		if [ $Prepatch_dir_present -eq 0 ]; then
                echo "Critical file backup during Prepatch step has change ID. Using the Critical Files backup taken during PrePatch step for comparison"
                export number_prepatch_crit_dir1=`ls |grep ${ENV}_${CHNGID}_PREPATCH_EPM| wc -l`
                export postpatch_crit_dir1=`ls | grep ${ENV}_${CHNGID}_POSTPATCH_EPM_${Day33}`
				if [ ${number_prepatch_crit_dir1} -eq 1 ];then 
					echo "One prepatch critical directory found for change id ${CHNGID}"
					export prepatch_crit_dir1=`ls |grep ${ENV}_${CHNGID}_PREPATCH_EPM`
					echo "Checking differences between ${prepatch_crit_dir1} and ${postpatch_crit_dir1}"
				else 
					echo "Multiple prepatch critcal directories found for change id ${CHNGID}. last directory will be compared"
					export prepatch_crit_dir1=`ls |grep ${ENV}_${CHNGID}_PREPATCH_EPM |tail -1`
					echo "Checking differences between ${prepatch_crit_dir1} and ${postpatch_crit_dir1}"
				fi	
        else
                echo "Change ID not found for Prepatch step - Critical file backup folder. Using the Gold copy of Critical Files for comparison"
                export prepatch_crit_dir1=${GOLD_CRIT_FILE_DIR}
                #export postpatch_crit_dir1=`ls |grep ${ENV}_${CHNGID}_POSTPATCH_EPM`
                export postpatch_crit_dir1=`ls | grep ${ENV}_${CHNGID}_POSTPATCH_EPM_${Day33}`
				echo "Checking differences between ${prepatch_crit_dir1} and ${postpatch_crit_dir1}"

        fi

fi


export fold_diff_tmp=${OUTPUT}/${ENV}_PRE_POST_DIR_DIFF_tmp.txt
export fold_diff=${OUTPUT}/${ENV}_PRE_POST_DIR_DIFF.txt


diff --brief -Nr ${prepatch_crit_dir1} ${postpatch_crit_dir1} > ${fold_diff_tmp}

cat ${fold_diff_tmp} | awk '{print $2,$4}' | tr " " "#" >  ${fold_diff}

if [ -s ${fold_diff} ]; then
	echo "PREPATCH & POST PATCH has differences"
	echo ""
	echo ""
	cat ${fold_diff_tmp}
	for i in `cat ${fold_diff}`
	do 
		filediff1=`echo "$i" | cut -d"#" -f1 `
		filediff2=`echo "$i" | cut -d"#" -f2 `
		ex_file=`basename $filediff1`
		
	
		diff $filediff1 $filediff2 >  ${OUTPUT}/${ex_file}_diff.txt
		
		cat ${OUTPUT}/${ex_file}_diff.txt
			
		echo "<br>" >> $summary_report_backup
		echo "<b>Differences found in Critical files post patching </b>" >> $summary_report_postpatch
		echo "<br>" >> $summary_report_postpatch 		
		echo "<table border="1">" >> $summary_report_postpatch 
		echo "<tr>" >> $summary_report_postpatch 
		echo "<th><b>File with differences</b></th>" >> $summary_report_postpatch 
		echo "<th><b>Differences found (Prepatching ---> Postpatching)</b></th>" >> $summary_report_postpatch  
		echo "</tr>" >> $summary_report_postpatch 
		echo "<tr>" >> $summary_report_postpatch 
		echo "<td>`echo "$ex_file"`</td>" >> $summary_report_postpatch 
		echo "<td>`cat ${OUTPUT}/${ex_file}_diff.txt`</td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "</table>" >> $summary_report_postpatch 
		echo "<br>" >> $summary_report_postpatch 
		
		echo "" >> $master_log_postpatch
		echo "###############################################################################################################################################" >> $master_log_postpatch
		echo " Differences found for Critical files (Prepatch & Post patch)" >> $master_log_postpatch
		echo "###############################################################################################################################################" >> $master_log_postpatch
		echo "`date`  |   Filename: $ex_file " >> $master_log_postpatch
		echo "" >> $master_log_postpatch
		echo "Differences: " >> $master_log_postpatch
		echo "`cat ${OUTPUT}/${ex_file}_diff.txt`" >> $master_log_postpatch
		
			
	done
	
	echo "Correct all the differences and remove flag file /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt manually to resume Critical_File_Copy script"
	echo ""
	echo "###############################################################################################################################################" >> $master_log_postpatch
	echo "Correct all the differences and remove flag file /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt manually to resume Critical_File_Copy script" >> $master_log_postpatch
	echo "###############################################################################################################################################" >> $master_log_postpatch
	
	echo "<b>Correct all the differences and remove flag file /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt manually to resume Critical_File_Copy script</b>" >> $summary_report_postpatch
	echo "<br>" >> $summary_report_postpatch
	
	cat $master_log_postpatch
	
	echo ""
	echo ""
else
	echo "No differences found in PREPATCH & POST PATCH directories"
	echo "<b>No differences found in Critical files post patching </b>" >> $summary_report_postpatch
	echo "" >> $master_log_postpatch
		echo "###############################################################################################################################################" >> $master_log_postpatch
		echo " No differences found for Critical files (Prepatch & Post patch)" >> $master_log_postpatch
		echo "###############################################################################################################################################" >> $master_log_postpatch
		echo "`date`  |   No difference found" >> $master_log_postpatch
	
	###Remove flag file to resume Critical_File_Copy script ###
	rm /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt
	
	echo "<br>" >> $summary_report_postpatch
	echo "<b>Removed flag file to resume scheduled Critical_File_Copy script</b>" >> $summary_report_postpatch
	echo "<br>" >> $summary_report_postpatch
	echo "###############################################################################################################################################" >> $master_log_postpatch
	echo "Removed flag file to resume scheduled Critical_File_Copy script" >> $master_log_postpatch
		
	cat $master_log_postpatch
fi

###File at end of the backup to be created post patching###
#echo "Creating file at end of backup post patching - /hyp_interfaces/${LCMENV}/ess_scripts/Global_Shell/Back_Up_FW/Back_Up_End.txt"
#touch /hyp_interfaces/${LCMENV}/ess_scripts/Global_Shell/Back_Up_FW/Back_Up_End.txt
#chmod 777 /hyp_interfaces/${LCMENV}/ess_scripts/Global_Shell/Back_Up_FW/Back_Up_End.txt





export summary_report=${PPLOGDIR}/${ENV}_PATCH_Summary_report_${CHNGID}_${Day}.html
export master_log=${PPLOGDIR}/${ENV}_PATCH_Master_Log_${CHNGID}_${Day}.log

echo "<html>" > $summary_report
echo "<h2>$ENV: PATCH SUMMARY REPORT</h2>" >> $summary_report  

ls -ltr ${PPLOGDIR}/${ENV}_PATCH_report_*${CHNGID}* | awk '{print $9}' > ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt

if [ -s ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt ]; then
	echo " "
	echo " "
	
	echo "Patch summary report: $summary_report"
	for i in `cat ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt`
	do 
	#filnm=`echo $i | awk '{print $9}'`
	cat $i >> $summary_report
	done
else
	echo " "
	echo " "
	echo "No other activities performed for this change id"
fi

echo "$ENV: PATCH LOG" > $master_log
 echo "" >> $master_log 

ls -ltr ${PPLOGDIR}/${ENV}_PATCH_Master_Log_*${CHNGID}* | awk '{print $9}' > ${PPLOGDIR}/patch_step_logs_${CHNGID}_${ENV}.txts

if [ -s ${PPLOGDIR}/patch_step_logs_${CHNGID}_${ENV}.txt ]; then
	echo " "
	echo " "
	echo "Patch Master Log: $master_log"
	for i in `cat ${PPLOGDIR}/patch_step_logs_${ENV}.txt`
	do 
	#filnme=`echo $i | awk '{print $9}'`
	cat $i >> $master_log
	done
else
	echo " "
	echo " "
	echo "No other activities performed for this change id"
fi

echo ""
echo "Redirecting to the options screen.."
echo ""
optionsScreen
echo ""
echo ""

} 


function MWHOME_oracle_common() {

echo ""
echo ""

echo "MWHOME oracle_common patching available options:"
echo ""
echo "1. Prerequisite check
2. Prepatch steps (Regular) 
3. Postpatch steps (Regular)"
echo ""

		echo -n "Select Option, to exit 0 (zero): "
		read usrselec
		if [ $usrselec -eq 1 ]; then
			echo "Option $usrselec selected, Prerequisite check for Middleware oracle_common location"
			cat ${CTRLLOC}/planning_prereq_instructions.txt
			echo ""
			echo ""

			# Listing out all the Prepatching Activities in comments
			echo ""
			date
			read -p "If the above steps have already been performed, press 1 to Continue, 0 to Exit - " PROG
			if [ $PROG = '0' ]; then
				echo "----------"
				echo "Selection = ${PROG}, exiting script..."
				optionsScreen
			elif [ $PROG = '1' ]; then 	
				echo "Selection = ${PROG}"
				echo "----------"
				read -p "Please enter the patch numbers (if more than one patch, please seperate them by comma (,) - " PATCHNUM
				read -p "Please enter the server location where the patches are downloaded to - " PATCHLOC
			else
				echo "ERROR: Invalid option selected"
				echo "Exiting script"
				exit 1;
			fi
			
			
			read -p "DBA conducting this step (enter your sherwin id): " EMPID
			read -p "Enter the Change Log Request ID (if change log entry is not created, hit Enter): " CHNGID
			echo "DBA conducting this step is "$EMPID
			echo "Change Log request ID is "$CHNGID
			
			
			if [[ "x${CHNGID}" = "x" ]]; then
				echo "No change ID input for "$ENV
				
				export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_MWHOME_orcl_common_PREREQ_${EMPID}_${Day}.html
				export master_log_prereq=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_oracle_common_PREREQ_${EMPID}_${Day}.log
			else
				echo "Input file $INPUT_FILE sourced in for "$ENV
				echo "Change Log Request ID is "$CHNGID
				
				export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_MWHOME_orcl_common_PREREQ_${CHNGID}_${Day}.html
				export master_log_prereq=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_oracle_common_PREREQ_${CHNGID}_${Day}.log
				
			fi

			
			echo "----------"
			echo "<br>" >> $summary_report_prereq 
			echo "<table border="1">" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "     <td><b>DBA</b></td>" >> $summary_report_prereq  
			echo "	   <td>$EMPID</td>" >> $summary_report_prereq  
			echo "</tr>" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq 
			echo "     <td><b>Step performed</b></td>" >> $summary_report_prereq  
			echo "	   <td>MWHOME oracle_common OPatch Prerequisite Check</td>" >> $summary_report_prereq  
			echo "</tr>" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "     <td><b>Date</b></td>" >> $summary_report_prereq  
			echo "	   <td>`date`</td>" >> $summary_report_prereq  
			echo "</tr>" >> $summary_report_prereq 
			echo "<tr>" >> $summary_report_prereq  
			echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_prereq  
			echo "	   <td>$CHNGID</td>" >> $summary_report_prereq	
			echo "</tr>" >> $summary_report_prereq 
			echo "<tr>" >> $summary_report_prereq  
			echo "     <td><b>Method</b></td>" >> $summary_report_prereq  
			echo "	   <td>Manual</td>" >> $summary_report_prereq  
			echo "</tr>" >> $summary_report_prereq 	
			echo "</table>" >> $summary_report_prereq  
			echo "<br>" >> $summary_report_prereq 
			echo "<br>" >> $summary_report_prereq 
			
			echo "#################################################################################################################################################" >> $master_log_prereq
			echo "DBA: $EMPID" >> $master_log_prereq
			echo "Step performed: MWHOME oracle_common OPatch Prerequisite Check" >> $master_log_prereq
			echo "Date: `date`" >> $master_log_prereq
			echo "Change Log Request ID: $CHNGID" >> $master_log_prereq
			echo "Method: Manual" >> $master_log_prereq
				
			
			
			export REFDateTime=`date +%d%m%y_%H%M%S`
			cd $MIDDLEWARE_HOME/oracle_common/OPatch/
			export PREREQ_DIR=${OUTPUT}/${ENV}_MWHOME_common_PREREQ_${REFDateTime}
			export USR_PREREQ_INPUT=${OUTPUT}/${ENV}_MWHOME_common_PREREQ_${REFDateTime}.cfg
			mkdir ${PREREQ_DIR}
			
			echo "DBA=$EMPID" > ${USR_PREREQ_INPUT}
			echo "PATCHNUM=$PATCHNUM" >> ${USR_PREREQ_INPUT}
			echo "PATCHLOC=$PATCHLOC" >> ${USR_PREREQ_INPUT}
			echo "----------"
			cat ${USR_PREREQ_INPUT}
			
			echo "<br>" >> $summary_report_prereq 
			echo "<b>MWHOME oracle_common OPatch Prequisite Check Activity </b>" >> $summary_report_prereq  
			echo "<table border="1">" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "    <td><b>Patch Number(s)</b></th>" >> $summary_report_prereq 
			echo "    <td>$PATCHNUM</th>" >> $summary_report_prereq
			echo "</tr>" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "    <td><b>Patch Location</b></td>" >> $summary_report_prereq 
			echo "    <td>$PATCHLOC</td>" >> $summary_report_prereq 
			echo "</tr>" >> $summary_report_prereq 	
			echo "</table>" >> $summary_report_prereq
			echo "<br>" >> $summary_report_prereq 	
			
			echo "MWHOME oracle_common OPatch Prequisite Check Activity " >> $master_log_prereq
			echo "    Patch Number(s): $PATCHNUM" >> $master_log_prereq
			echo "    Patch Location: $PATCHLOC" >> $master_log_prereq
			echo "#################################################################################################################################################" >> $master_log_prereq
			
			echo "Executing lsinventory command..."
			cd $MIDDLEWARE_HOME/oracle_common/OPatch/
			./opatch lsinventory -oh $MIDDLEWARE_HOME/oracle_common -jdk $MIDDLEWARE_HOME/jdk160_35 -invPtrLoc $MIDDLEWARE_HOME/oracle_common/oraInst.loc > ${PREREQ_DIR}/${ENV}_lsinventory.txt
						
			
			checkMulti=`echo $PATCHNUM | grep -o "," | wc -l`
			echo $PATCHNUM | sed 's/,/\n/g' > ${PREREQ_DIR}/${ENV}_Patch_numbers.txt
			if [ $checkMulti -eq 0 ]; then
				echo "Single patch to be applied"
				echo ${PATCHNUM}
				echo "TASK 1: Checking if the patch file ${PATCHNUM} is in the given patch location $PATCHLOC"
					fndPatch=`find ${PATCHLOC} -maxdepth 1 -name "*${PATCHNUM}*.zip"`
					find ${PATCHLOC} -maxdepth 1 -name "*${PATCHNUM}*.zip"
					ret=$?
					if [ $ret -eq 0 ]; then
						echo "Patch file $fndPatch present, unzipping it...."
						echo "unzip -o $fndPatch"
						cd $MIDDLEWARE_HOME/oracle_common/OPatch/
						unzip -o $fndPatch
						echo ""
						echo "TASK 2: Creating & executing Prereq script for patch $PATCHNUM"
						tmp_script=${PREREQ_DIR}/mwhome_common_opatch_prereq_tmp_${PATCHNUM}.sh
						new_script=${PREREQ_DIR}/mwhome_common_opatch_prereq_${PATCHNUM}.sh
						
						echo "<br>" >> $summary_report_prereq 
						echo "<b>MWHOME oracle_common OPatch Prequisite Check for patch ${PATCHNUM} </b>" >> $summary_report_prereq  
						echo "<table border="1">" >> $summary_report_prereq  
						echo "<tr>" >> $summary_report_prereq  
						echo "    <th>Timestamp</th>" >> $summary_report_prereq 
						echo "    <th>Prereq Check</th>" >> $summary_report_prereq
						echo "    <th>Status</th>" >> $summary_report_prereq 
						echo "    <th>Details</th>" >> $summary_report_prereq 
						echo "</tr>" >> $summary_report_prereq 		
						
						echo "MWHOME oracle_common OPatch Prequisite Check for patch ${PATCHNUM} " >> $master_log_prereq
						echo "Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
						echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
						
						
						echo "Checking the lsinventory to see if the patch is applied on the environment"
						grep -wi ${PATCHNUM} ${PREREQ_DIR}/${ENV}_lsinventory.txt > ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}.txt
						tret=$?
						if [[ $tret -eq 0 ]];then
							echo "$PATCHNUM present in lsinventory and already applied in this environment"
							echo ""
							cat ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}.txt
							mv ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}.txt ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}_present.txt
							
							echo "<tr>" >> $summary_report_prereq  
							echo "    <td>`date`</td>" >> $summary_report_prereq 
							echo "    <td>Check the patch in lsinventory</td>" >> $summary_report_prereq
							echo "    <td>Failure</td>" >> $summary_report_prereq 
							echo "    <td>The patch is already applied in the environment. Please verify</td>" >> $summary_report_prereq 
							echo "</tr>" >> $summary_report_prereq 
							echo "</table>" >> $summary_report_prereq
							echo ""
							echo " `date`|Check the patch in lsinventory | Failure     | The patch is already applied in the environment. Please verify" >> $master_log_prereq 
							echo "" >> $master_log_prereq 
							cat $master_log_prereq
							echo "Please verify the patch number, exiting the script now.."
							exit 1;
						else
							echo "$PATCHNUM not present in lsinventory, proceeding further..."
							echo " `date`|Check the patch in lsinventory | Success     | Patch is not applied" >> $master_log_prereq 
							echo ""
						fi
						
						
						cp ${CTRLLOC}/mwhome_oracle_common_opatch_prereq.sh $tmp_script
						export patchNN=$PATCHNUM
						eval "echo \"`cat $tmp_script`\"" > $new_script
						chmod +x $new_script
						cd ${PREREQ_DIR}
						. $new_script > ${new_script}.log
						ret=$?
						if [ $ret -eq 0 ]; then
							echo "PREREQ check script executed"
							echo ""
						else
							echo "PREREQ check script execution failed"
							echo ""
							echo "PREREQ check script execution failed" >> $master_log_prereq
							echo "" >> $master_log_prereq 
							cat $master_log_prereq
							exit 1;
						fi
						
						grep Prereq ${new_script}.log > ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log
						prereq_stat_SysSpace=`grep -wi checkSystemSpace ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
						#prereq_stat_appliProduct=`grep -wi checkApplicableProduct ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
						#prereq_stat_component=`grep -wi checkComponents ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
						prereq_stat_conDetail=`grep -wi checkConflictAmongPatchesWithDetail ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
						prereq_stat_appDepend=`grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
						#prereq_stat_applica=`grep -wi checkApplicable ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
						prereq_stat_conOHDetail=`grep -wi checkConflictAgainstOHWithDetail ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
						prereq_stat_InputValues=`grep -wi checkForInputValues ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
						
						export prereq_status_tidy=${PREREQ_DIR}/PREREQ_status_${PATCHNUM}_tidy.log
						echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace" > ${prereq_status_tidy}
						#echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct" >> ${prereq_status_tidy}
						#echo "PREREQ:checkComponents:$prereq_stat_component" >> ${prereq_status_tidy}
						echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail" >> ${prereq_status_tidy}
						echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend" >> ${prereq_status_tidy}
						#echo "PREREQ:checkApplicable:$prereq_stat_applica" >> ${prereq_status_tidy}
						echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail" >> ${prereq_status_tidy}
						echo "PREREQ:checkForInputValues:$prereq_stat_InputValues" >> ${prereq_status_tidy}
						
								
						for n in `cat ${prereq_status_tidy}`
						do
						prereq_chkk=`echo $n |cut -d":" -f2`
						prereq_chkk_stat=`echo $n |cut -d":" -f3`
						
							echo "<tr>" >> $summary_report_prereq  
							echo "    <td>`date`</td>" >> $summary_report_prereq 
							echo "    <td>${prereq_chkk}</td>" >> $summary_report_prereq
							echo "    <td>${prereq_chkk_stat}</td>" >> $summary_report_prereq 
							echo "    <td></td>" >> $summary_report_prereq 
							echo "</tr>" >> $summary_report_prereq
							
							echo "`date`|${prereq_chkk} | ${prereq_chkk_stat} | " >> $master_log_prereq 
												
						done
						
						if [ "$prereq_stat_SysSpace" = "passed." ]; then
							echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace"  
						elif [ "$prereq_stat_SysSpace" = " " ]; then	
							echo "PREREQ status is blank, please check"
							
						else
							echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details"
							echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi	
						
						# if [ "$prereq_stat_appliProduct" = "passed." ]; then
							# echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct"
						# elif [ "$prereq_stat_appliProduct" = " " ]; then	
							# echo "PREREQ status is blank, please check"
							# echo "PREREQ status is blank, please check" >> $master_log_prereq
						# else
							# echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details"
							# echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details" >> $master_log_prereq
							# cat $master_log_prereq
							# exit 1;
						# fi
						
						# if [ "$prereq_stat_component" = "passed." ]; then
							# echo "PREREQ:checkComponents:$prereq_stat_component"
						# elif [ "$prereq_stat_component" = " " ]; then	
							# echo "PREREQ status is blank, please check"
							# echo "PREREQ status is blank, please check" >> $master_log_prereq
						# else
							# echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details"
							# echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details" >> $master_log_prereq
							# cat $master_log_prereq
							# exit 1;
						# fi				
						
						if [ "$prereq_stat_conDetail" = "passed." ]; then
							echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail"
						elif [ "$prereq_stat_conDetail" = " " ]; then	
							echo "PREREQ status is blank, please check"
						else
							echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi
						
						if [ "$prereq_stat_appDepend" = "passed." ]; then
							echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend"
						elif [ "$prereq_stat_appDepend" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi
						
						# if [ "$prereq_stat_applica" = "passed." ]; then
							# echo "PREREQ:checkApplicable:$prereq_stat_applica"
						# elif [ "$prereq_stat_applica" = " " ]; then	
							# echo "PREREQ status is blank, please check"
							# echo "PREREQ status is blank, please check" >> $master_log_prereq
						# else
							# echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details"
							# echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details" >> $master_log_prereq
							# cat $master_log_prereq
							# exit 1;
						# fi
						
						if [ "$prereq_stat_conOHDetail" = "passed." ]; then
							echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail"
						elif [ "$prereq_stat_conOHDetail" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi	
						
						if [ "$prereq_stat_InputValues" = "passed." ]; then
							echo "PREREQ:checkForInputValues:$prereq_stat_InputValues"
						elif [ "$prereq_stat_InputValues" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi	
						
						echo ""
						echo "PREREQ Checks successful"
						echo "<table border="1">" >> $summary_report_prereq  
						echo "PREREQ Checks successful" >> $master_log_prereq
						echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
								
					
					
					else
						echo "Unable to find patch file, please check the location"
						echo "Unable to find patch file, please check the location" >> $master_log_prereq
						cat $master_log_prereq
						exit 1;
					fi
			else
				echo "Multiple patches to be applied"
				cat ${PREREQ_DIR}/${ENV}_Patch_numbers.txt
				for i in `cat ${PREREQ_DIR}/${ENV}_Patch_numbers.txt`
				do
					echo $i
					echo "TASK 1: Checking the lsinventory to see if the patch is applied on the environment"
					grep -wi ${i} ${PREREQ_DIR}/${ENV}_lsinventory.txt > ${PREREQ_DIR}/${ENV}_lsinventory_${i}.txt
					tret=$?
						if [[ $tret -eq 0 ]];then
							echo "$i present in lsinventory and already applied in this environment"
							echo ""
							cat ${PREREQ_DIR}/${ENV}_lsinventory_${i}.txt
							mv ${PREREQ_DIR}/${ENV}_lsinventory_${i}.txt ${PREREQ_DIR}/${ENV}_lsinventory_${i}_present.txt
							
							echo "<br>" >> $summary_report_prereq 
							echo "<b>MWHOME oracle_common OPatch Prequisite Check for patch ${i}</b>" >> $summary_report_prereq  
							echo "<table border="1">" >> $summary_report_prereq  
							echo "<tr>" >> $summary_report_prereq  
							echo "    <th>Timestamp</th>" >> $summary_report_prereq 
							echo "    <th>Prereq Check</th>" >> $summary_report_prereq
							echo "    <th>Status</th>" >> $summary_report_prereq 
							echo "    <th>Details</th>" >> $summary_report_prereq 
							echo "</tr>" >> $summary_report_prereq 
							
							echo "<tr>" >> $summary_report_prereq  
							echo "    <td>`date`</td>" >> $summary_report_prereq 
							echo "    <td>Check the patch $i in lsinventory</td>" >> $summary_report_prereq
							echo "    <td>Failure</td>" >> $summary_report_prereq 
							echo "    <td>The patch $i is already applied in the environment. Please verify</td>" >> $summary_report_prereq 
							echo "</tr>" >> $summary_report_prereq
							echo "</table>" >> $summary_report_prereq
							echo "<br>" >> $summary_report_prereq
							
							echo "MWHOME oracle_common OPatch Prequisite Check for patch ${i} " >> $master_log_prereq
							echo " Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
							echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
							echo " `date`|Check the patch in lsinventory | Failure     | The patch is already applied in the environment. Please verify" >> $master_log_prereq 
							echo "" >> $master_log_prereq 
							echo ""
							echo "Please verify the patch number.."
						else
							echo "$i not present in lsinventory, proceeding further..."
							echo ""
							echo "TASK 2: Checking if the patch file $i is in the given patch location $PATCHLOC"
							fndPatch=`find ${PATCHLOC} -maxdepth 1 -name "*${i}*.zip"`
							find ${PATCHLOC} -maxdepth 1 -name "*${i}*.zip"
							ret=$?
							if [ $ret -eq 0 ]; then
								echo "Patch file $fndPatch present, unzipping it...."
								echo "unzip -o $fndPatch"
								cd $MIDDLEWARE_HOME/oracle_common/OPatch/
								unzip -o $fndPatch
								echo ""
								echo "TASK 2: Creating & executing Prereq script for patch $i"
								tmp_script=${PREREQ_DIR}/epm_opatch_prereq_tmp_${i}.sh
								new_script=${PREREQ_DIR}/epm_opatch_prereq_${i}.sh
										
					
								
								cp ${CTRLLOC}/epm_opatch_prereq.sh $tmp_script
								export patchNN=$i
								eval "echo \"`cat $tmp_script`\"" > $new_script
								chmod +x $new_script
								. $new_script > ${new_script}.log
								ret=$?
								if [ $ret -eq 0 ]; then
									echo "PREREQ check script executed"
									echo ""
								else
									echo "PREREQ check script execution failed"
									echo "PREREQ check script execution failed" >> $master_log_prereq 
									echo "" >> $master_log_prereq 
									echo ""
									exit 1;
								fi
								
								grep Prereq ${new_script}.log > ${PREREQ_DIR}/PREREQ_status_${i}.log
												
								prereq_stat_SysSpace=`grep -wi checkSystemSpace ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
								prereq_stat_conDetail=`grep -wi checkConflictAmongPatchesWithDetail ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
								prereq_stat_conOHDetail=`grep -wi checkConflictAgainstOHWithDetail ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
								prereq_stat_InputValues=`grep -wi checkForInputValues ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
								#prereq_stat_appliProduct=`grep -wi checkApplicableProduct ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
								#prereq_stat_component=`grep -wi checkComponents ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
								prereq_stat_appDepend=`grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
								#prereq_stat_applica=`grep -wi checkApplicable ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
								
								
								export prereq_status_tidy=${PREREQ_DIR}/PREREQ_status_${i}_tidy.log
								echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace" > ${prereq_status_tidy}
								#echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct" >> ${prereq_status_tidy}
								#echo "PREREQ:checkComponents:$prereq_stat_component" >> ${prereq_status_tidy}
								echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail" >> ${prereq_status_tidy}
								echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend" >> ${prereq_status_tidy}
								#echo "PREREQ:checkApplicable:$prereq_stat_applica" >> ${prereq_status_tidy}
								echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail" >> ${prereq_status_tidy}
								echo "PREREQ:checkForInputValues:$prereq_stat_InputValues" >> ${prereq_status_tidy}
								
								echo "<br>" >> $summary_report_prereq 
								echo "<b>MWHOME oracle_common OPatch Prequisite Check for patch ${i}</b>" >> $summary_report_prereq  
								echo "<table border="1">" >> $summary_report_prereq  
								echo "<tr>" >> $summary_report_prereq  
								echo "    <th>Timestamp</th>" >> $summary_report_prereq 
								echo "    <th>Prereq Check</th>" >> $summary_report_prereq
								echo "    <th>Status</th>" >> $summary_report_prereq 
								echo "    <th>Details</th>" >> $summary_report_prereq 
								echo "</tr>" >> $summary_report_prereq 		
								
								echo "MWHOME oracle_common OPatch Prequisite Check for patch ${i} " >> $master_log_prereq
								echo " Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
								echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
								
								for n in `cat ${prereq_status_tidy}`
								do
								prereq_chkk=`echo $n |cut -d":" -f2`
								prereq_chkk_stat=`echo $n |cut -d":" -f3`
								
									echo "<tr>" >> $summary_report_prereq  
									echo "    <td>`date`</td>" >> $summary_report_prereq 
									echo "    <td>${prereq_chkk}</td>" >> $summary_report_prereq
									echo "    <td>${prereq_chkk_stat}</td>" >> $summary_report_prereq 
									echo "    <td></td>" >> $summary_report_prereq 
									echo "</tr>" >> $summary_report_prereq 
									
									echo "`date`|${prereq_chkk} | ${prereq_chkk_stat} | " >> $master_log_prereq 
									
								done
								
								
								if [ "$prereq_stat_SysSpace" = "passed." ]; then
									echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace"  
								elif [ "$prereq_stat_SysSpace" = " " ]; then	
									echo "PREREQ status is blank, please check"
									
								else
									echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details"
									echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi	
								
								# if [ "$prereq_stat_appliProduct" = "passed." ]; then
									# echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct"
								# elif [ "$prereq_stat_appliProduct" = " " ]; then	
									# echo "PREREQ status is blank, please check"
									# echo "PREREQ status is blank, please check" >> $master_log_prereq
								# else
									# echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details"
									# echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details" >> $master_log_prereq
									# cat $master_log_prereq
									# exit 1;
								# fi
								
								# if [ "$prereq_stat_component" = "passed." ]; then
									# echo "PREREQ:checkComponents:$prereq_stat_component"
								# elif [ "$prereq_stat_component" = " " ]; then	
									# echo "PREREQ status is blank, please check"
									# echo "PREREQ status is blank, please check" >> $master_log_prereq
								# else
									# echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details"
									# echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details" >> $master_log_prereq
									# cat $master_log_prereq
									# exit 1;
								# fi				
								
								if [ "$prereq_stat_conDetail" = "passed." ]; then
									echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail"
								elif [ "$prereq_stat_conDetail" = " " ]; then	
									echo "PREREQ status is blank, please check"
								else
									echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								if [ "$prereq_stat_appDepend" = "passed." ]; then
									echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend"
								elif [ "$prereq_stat_appDepend" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								# if [ "$prereq_stat_applica" = "passed." ]; then
									# echo "PREREQ:checkApplicable:$prereq_stat_applica"
								# elif [ "$prereq_stat_applica" = " " ]; then	
									# echo "PREREQ status is blank, please check"
									# echo "PREREQ status is blank, please check" >> $master_log_prereq
								# else
									# echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details"
									# echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details" >> $master_log_prereq
									# cat $master_log_prereq
									# exit 1;
								# fi
								
								if [ "$prereq_stat_conOHDetail" = "passed." ]; then
									echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail"
								elif [ "$prereq_stat_conOHDetail" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi	
								
								if [ "$prereq_stat_InputValues" = "passed." ]; then
									echo "PREREQ:checkForInputValues:$prereq_stat_InputValues"
								elif [ "$prereq_stat_InputValues" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								echo ""
								echo "PREREQ Checks successful"
								echo "" >> $master_log_prereq
								echo "PREREQ Checks successful" >> $master_log_prereq
								echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
								echo "</table>" >> $summary_report_prereq
								echo "<br>" >> $summary_report_prereq
							else
								echo "Unable to find patch file, please check the location"
								echo "Unable to find patch file, please check the location" >> $master_log_prereq
								cat $master_log_prereq
								exit 1;
							fi	
						fi
				done
				ls -ltr ${PREREQ_DIR}/${ENV}_lsinventory_*_present.txt 
				uret=$?
				echo $uret
				if [[ $uret -eq 0 ]];then
					echo "Few patches are already applied in this environment, please verify. Exiting script...."
					echo "Few patches are already applied in this environment, please verify." >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				else
					echo "All the patches are good to go"
				fi
									
			fi
			cat $master_log_prereq	
			echo ""
			echo ""
					
			optionsScreen

		elif [ $usrselec -eq 2 ]; then
			echo ""
			echo "Option $usrselec selected, backup of oraInventory, lsinventory from Middleware oracle_common location"
			echo ""
			read -p "DBA conducting this step (enter your sherwin id) " EMPID
			read -p "Enter the Change Log Request ID : " CHNGID
			echo "DBA conducting this step is "$EMPID
			echo "Change Log request ID is "$CHNGID


			if [[ "$CHNGID" = "" ]]; then
				echo "No change ID input for "$ENV
				
				export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report_MWHOME_oracle_common_PREPATCH_${EMPID}_${Day}.html
				export master_log_prepatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_oracle_common_PREPATCH_${EMPID}_${Day}.log
							
			else
				echo "Input file $INPUT_FILE sourced in for "$ENV
				echo "Change Log Request ID is "$CHNGID
				
				export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report__MWHOME_oracle_common_PREPATCH_${CHNGID}_${Day}.html
				export master_log_prepatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_oracle_common_PREPATCH_${CHNGID}_${Day}.log
		
			fi
			echo "----------"
			echo "<br>" >> $summary_report_prepatch
			echo "<table border="1">" >> $summary_report_prepatch  
			echo "<tr>" >> $summary_report_prepatch  
			echo "     <td><b>DBA</b></td>" >> $summary_report_prepatch  
			echo "	   <td>$EMPID</td>" >> $summary_report_prepatch
			echo "</tr>" >> $summary_report_prepatch 
			echo "<tr>" >> $summary_report_prepatch  
			echo "     <td><b>Step performed</b></td>" >> $summary_report_prepatch  
			echo "	   <td>MWHOME oracle_common Prepatch Steps</td>" >> $summary_report_prepatch    
			echo "</tr>" >> $summary_report_prepatch  
			echo "<tr>" >> $summary_report_prepatch  
			echo "     <td><b>Date</b></td>" >> $summary_report_prepatch  
			echo "	   <td>`date`</td>" >> $summary_report_prepatch  
			echo "</tr>" >> $summary_report_prepatch  
			echo "<tr>" >> $summary_report_prepatch 
			echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_prepatch
			echo "	   <td>$CHNGID</td>" >> $summary_report_prepatch
			echo "</tr>" >> $summary_report_prepatch
			echo "<tr>" >> $summary_report_prepatch  
			echo "     <td><b>Method</b></td>" >> $summary_report_prepatch
			echo "	   <td>Manual</td>" >> $summary_report_prepatch 
			echo "</tr>" >> $summary_report_prepatch
			echo "</table>" >> $summary_report_prepatch  
			echo "<br>" >> $summary_report_prepatch 
			echo "<br>" >> $summary_report_prepatch 

			echo "#################################################################################################################################################" > $master_log_prepatch
			echo "DBA: $EMPID" >> $master_log_prepatch
			echo "Step performed: MWHOME oracle_common Prepatch Steps" >> $master_log_prepatch
			echo "Date: `date`" >> $master_log_prepatch
			echo "Change Log Request ID: $CHNGID" >> $master_log_prepatch
			echo "Method: Manual" >> $master_log_prepatch
			echo "#################################################################################################################################################" >> $master_log_prepatch

			### Create flag file to put Critical_file_copy script on hold during patching"
			echo " Creating flag file to put Critical_file_copy script on hold during patching"
			echo " Creating flag file to put Critical_file_copy script on hold during patching" >> $master_log_prepatch
			echo "#################################################################################################################################################" >> $master_log_prepatch
			touch /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt

			#Prepatching step 1: lsinventory command
			echo "####################################################################################################"
			echo "MWHOME oracle_common Prepatching step 1: lsinventory command"
			echo "####################################################################################################"echo ""
			echo ""
			cd $MIDDLEWARE_HOME/oracle_common/OPatch/
			
			export TodayDate=`date +%d_%m_%Y`
			export PREPATCHDIR=${BACKUPDIR}/PREPOST/PREPATCH_MWHOME_oracle_common_${ENV}_${CHNGID}_${TodayDate}
			export lsinvDate=`date +%Y-%m-%d_%I-%M`
			./opatch lsinventory -oh $MIDDLEWARE_HOME/oracle_common -jdk $MIDDLEWARE_HOME/jdk160_35 -invPtrLoc $MIDDLEWARE_HOME/oracle_common/oraInst.loc
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Executing lsinventory command of MWHOME oracle_common for $ENV"
					echo "<br>" >> $summary_report_prepatch
					echo "<b>MWHOME oracle_common Pre Patching</b>" >> $summary_report_prepatch  
					echo "<table border="1">" >> $summary_report_prepatch  
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <th>Timestamp</th>" >> $summary_report_prepatch 
					echo "    <th>Step</th>" >> $summary_report_prepatch
					echo "    <th>Status</th>" >> $summary_report_prepatch 
					echo "    <th>Details</th>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME oracle_commonPrepatching step: Execute lsinventory command of MWHOME oracle_common</td>" >> $summary_report_prepatch
					echo "    <td>Failure</td>" >> $summary_report_prepatch 
					echo "    <td></td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					
					echo "" >> $master_log_prepatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
					echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_prepatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
					echo "`date`|MWHOME oracle_common Prepatching step 1: Execute MWHOME oracle_common lsinventory command |Failure      | " >> $master_log_prepatch
					cat $master_log_prepatch	
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Executing MWHOME oracle_common lsinventory command of MWHOME oracle_common for $ENV"
				 cd $MIDDLEWARE_HOME/oracle_common/cfgtoollogs/opatch/lsinv/
				 filename=`ls | grep ${lsinvDate}`
				 echo $filename
				 
				 mkdir ${PREPATCHDIR}
				 cp $filename ${PREPATCHDIR}
				 echo "$DateTime: Copied MWHOME oracle_common lsinventory file to ${PREPATCHDIR}"
				 ls -ltr ${PREPATCHDIR}
					echo "<br>" >> $summary_report_prepatch
					echo "<b>MWHOME oracle_common Pre Patching</b>" >> $summary_report_prepatch  
					echo "<table border="1">" >> $summary_report_prepatch  
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <th>Timestamp</th>" >> $summary_report_prepatch 
					echo "    <th>Step</th>" >> $summary_report_prepatch
					echo "    <th>Status</th>" >> $summary_report_prepatch 
					echo "    <th>Details</th>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>Prepatching step 1: Execute MWHOME oracle_common lsinventory command</td>" >> $summary_report_prepatch
					echo "    <td>Success</td>" >> $summary_report_prepatch 
					echo "    <td>Copied lsinventory file $filename to ${PREPATCHDIR}</td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "" >> $master_log_prepatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
					echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_prepatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
					echo "`date`|MWHOME oracle_common Prepatching step 1: Execute MWHOME oracle_common lsinventory command |Success      |Copied lsinventory file $filename to ${PREPATCHDIR} " >> $master_log_prepatch
			 fi

			echo ""
			echo ""


			 #Prepatching step 2: EPM registry command
			 echo "####################################################################################################"
			 echo "MWHOME oracle_common Prepatching step 2: EPM registry command"
			 echo "####################################################################################################"
			 echo ""
			echo ""
			 cd $EPM_ORACLE_INSTANCE/bin
			 echo "./epmsys_registry.sh"
			./epmsys_registry.sh
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Prepatching step 2: EPM registry command for $ENV"
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME oracle_common Prepatching step 2: Generate EPM registry report</td>" >> $summary_report_prepatch
					echo "    <td>Failure</td>" >> $summary_report_prepatch 
					echo "    <td></td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME oracle_common Prepatching step 2: Generate EPM registry report |Failure      | " >> $master_log_prepatch
					cat $master_log_prepatch	
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Prepatching step 2: EPM registry command for $ENV"
				 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
				 cp registry.html ${PREPATCHDIR}
				 echo "$DateTime: Copied registry.html file to ${PREPATCHDIR}"
				 ls -ltr ${PREPATCHDIR}
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME oracle_common Prepatching step 2: Generate EPM registry report</td>" >> $summary_report_prepatch
					echo "    <td>Success</td>" >> $summary_report_prepatch 
					echo "    <td>Copied registry.html file to ${PREPATCHDIR}</td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME oracle_common Prepatching step 2: Generate EPM registry report |Success      |Copied registry.html file to ${PREPATCHDIR}" >> $master_log_prepatch
					
			 fi
			echo ""
			echo ""

			#Prepatching step 3: Generate deployment report
			 echo "####################################################################################################"
			 echo "MWHOME oracle_common Prepatching step 3: Generate EPM deployment report"
			 echo "####################################################################################################"
			 echo ""
			echo ""
			cd $EPM_ORACLE_INSTANCE/bin
			echo "./epmsys_registry.sh report deployment"
			deplreptDate=`date +%Y%m%d_%H`
			./epmsys_registry.sh report deployment
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Generating EPM deployment report for $ENV"
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME oracle_common Prepatching step 3: Generate EPM Deployment report</td>" >> $summary_report_prepatch
					echo "    <td>Failure</td>" >> $summary_report_prepatch 
					echo "    <td></td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME oracle_common Prepatching step 3: Generate EPM Deployment report |Failure      | " >> $master_log_prepatch
					cat $master_log_prepatch	
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Generating EPM deployment report for $ENV"
				 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
				 filename=`ls -lrt |awk '{print $9}' |tail -1`
				 cp $filename ${PREPATCHDIR}
				 echo "$DateTime: Copied EPM deployment reportfile to ${PREPATCHDIR}"
				 ls -ltr ${PREPATCHDIR}
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME oracle_common Prepatching step 3: Generate EPM Deployment report</td>" >> $summary_report_prepatch
					echo "    <td>Success</td>" >> $summary_report_prepatch 
					echo "    <td>Copied $filename to ${PREPATCHDIR}</td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME oracle_common Prepatching step 3: Generate EPM Deployment report |Success      |Copied $filename to ${PREPATCHDIR} " >> $master_log_prepatch
			 fi
			 
			 
			 #Prepatching step 4: Backup of oraInventory
			 echo "####################################################################################################"
			 echo "MWHOME oracle_common Prepatching step 4: Backup of oraInventory"
			 echo "####################################################################################################"
			 echo ""
			 echo ""
			 INVLOC=`grep inventory_loc $MIDDLEWARE_HOME/oracle_common/oraInst.loc | cut -d"=" -f2`
			 echo "Oracle Inventory location: $INVLOC"
			tar -cvf ${BACKUPDIR}/INV_BACKUPS/${Day1}_${ENV}_${CHNGID}_PREPATCH_MWHOME_orcl_common_OraInventory.tar ${INVLOC}
			 VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Backup of oraInventory for $ENV"
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME oracle_common Prepatching step 4: Backup of oraInventory</td>" >> $summary_report_prepatch
					echo "    <td>Failure</td>" >> $summary_report_prepatch 
					echo "    <td></td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME oracle_common Prepatching step 4: Backup of oraInventory |Failure      | " >> $master_log_prepatch
					cat $master_log_prepatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Backup of oraInventory for $ENV"
				 ls -ltr ${BACKUPDIR}/INV_BACKUPS/
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME oracle_common Prepatching step 4: Backup of oraInventory</td>" >> $summary_report_prepatch
					echo "    <td>Success</td>" >> $summary_report_prepatch 
					echo "    <td>Copied ${Day1}_${ENV}_PREPATCH_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/</td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME oracle_common Prepatching step 4: Backup of oraInventory |Success      |Copied ${Day1}_${ENV}_PREPATCH_MWHOME_orcl_common_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/ " >> $master_log_prepatch
			 fi
			 
			 #Prepatching step 5: Critial file copy
			 echo "####################################################################################################"
			  echo "MWHOME oracle_common Prepatching step 5: Critial file copy"
			 echo "####################################################################################################"
			 echo ""
			 echo ""
			 cd ${SCRIPTDIR}/
			  export Day3=`date +%Y-%m-%d_%H_%M`
			 ./Critical_File_copy.sh
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Executing Critial file copy for $ENV"
						echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME oracle_common Prepatching step 5: Critial file copy</td>" >> $summary_report_prepatch
					echo "    <td>Failure</td>" >> $summary_report_prepatch 
					echo "    <td></td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME oracle_common Prepatching step 5: Critial file copy |Failure      | " >> $master_log_prepatch
					cat $master_log_prepatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Executing Critial file copy for $ENV"
				 crit_dir=`ls ${BACKUPDIR}/Critical_File_Copy | grep ${Day3}`
				 export prepatch_crit_dir=${BACKUPDIR}/Critical_File_Copy/${ENV}_${CHNGID}_PREPATCH_ORCL_COMM_${Day3}
				 echo "Critical files copied to directory $crit_dir under ${BACKUPDIR}/Critical_File_Copy"
				 mv ${BACKUPDIR}/Critical_File_Copy/${Day3} ${prepatch_crit_dir}
				 echo "Listing files in ${prepatch_crit_dir}"
				 ls -ltr ${prepatch_crit_dir}
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME oracle_common Prepatching step 5: Critial file copy</td>" >> $summary_report_prepatch
					echo "    <td>Success</td>" >> $summary_report_prepatch 
					echo "    <td>Copied ${ENV}_${CHNGID}_PREPATCH_${Day3} to ${BACKUPDIR}/Critical_File_Copy</td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "</table>" >> $summary_report_prepatch 
					echo "<br>" >> $summary_report_prepatch 
					echo "<br>" >> $summary_report_prepatch
					echo "`date`|MWHOME oracle_common Prepatching step 5: Critial file copy |Success      |Copied ${ENV}_${CHNGID}_PREPATCH_${Day3} to ${BACKUPDIR}/Critical_File_Copy " >> $master_log_prepatch
			 fi

					echo "##############################################################################################################################################" >> $master_log_prepatch
			echo ""
			echo ""
			echo ""
					echo "Checking the last execution status for cloud control jobs for $ENV"
					echo ""
					echo "Listing backups for $ENV..."
					echo ""
					cat ${CTRLLOC}/${ENV}_status_all_backup_jobs.cfg
					echo ""
					echo "Fetching the last execution status of jobs"
					echo "Last execution status for cloud control jobs for $ENV" >> $master_log_prepatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
					echo "" >> $master_log_prepatch
					echo "" 
					for n in `cat ${CTRLLOC}/${ENV}_status_all_backup_jobs.cfg`
					do
					${EMCLIHOME}/emcli get_jobs -name="${n}" -owner="SW_JOBADMIN" > ${OUTPUT}/job_exec_${n}.txt	
					
					tail -2 ${OUTPUT}/job_exec_${n}.txt | head -1 > ${OUTPUT}/last_job_exec_${n}.txt	
					#cat ${OUTPUT}/last_job_exec_${n}.txt	
					fromdate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f9`
					fromtime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f10`
					todate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f12`
					totime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f13`
					status=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f17`
					
					echo "Last execution status for backup ${n}: ${status}"
					echo "Execution Start Time: $fromdate $fromtime "
					echo "Execution End Time: $todate $totime "
					echo ""
					
					echo "Last execution status for backup ${n}: ${status}" >> $master_log_prepatch
					echo "Execution Start Time: $fromdate $fromtime " >> $master_log_prepatch
					echo "Execution End Time: $todate $totime " >> $master_log_prepatch
					echo "" >> $master_log_prepatch
					echo "##############################################################################################################################################" >> $master_log_prepatch
					
					done
					echo ""
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch

			cat $master_log_prepatch
					
			echo ""
			echo ""
			echo "Redirecting to the options screen.."
			echo ""
			optionsScreen


			
		elif [ $usrselec -eq 3 ]; then
			echo ""
			echo "Option $usrselec selected, postptach step for Middleware oracle_common location"
			echo ""

			read -p "DBA conducting the Maintenance (enter your sherwin id) " EMPID
			read -p "Enter the Change Log Request ID : " CHNGID
			echo "DBA conducting this step is "$EMPID
			echo "Change Log request ID is "$CHNGID


			if [[ "$CHNGID" = "" ]]; then
				echo "No change ID input for "$ENV
				
				export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_MWHOME_oracle_common_POSTPATCH_${EMPID}_${Day}.html
				export master_log_postpatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_oracle_common_POSTPATCH_${EMPID}_${Day}.log
			else
				echo "Input file $INPUT_FILE sourced in for "$ENV
				echo "Change Log Request ID is "$CHNGID
				
				export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_MWHOME_oracle_common_POSTPATCH_${CHNGID}_${Day}.html
				export master_log_postpatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_oracle_common_POSTPATCH_${CHNGID}_${Day}.log
			fi
			echo "----------"
			echo "<br>" >> $summary_report_postpatch
			echo "<table border="1">" >> $summary_report_postpatch  
			echo "<tr>" >> $summary_report_postpatch  
			echo "     <td><b>DBA</b></td>" >> $summary_report_postpatch  
			echo "	   <td>$EMPID</td>" >> $summary_report_postpatch
			echo "</tr>" >> $summary_report_postpatch
			echo "<tr>" >> $summary_report_postpatch  
			echo "     <td><b>Step Performed</b></td>" >> $summary_report_postpatch  
			echo "	   <td>MWHOME oracle_common Postpatch Steps</td>" >> $summary_report_postpatch    
			echo "</tr>" >> $summary_report_postpatch  
			echo "<tr>" >> $summary_report_postpatch  
			echo "     <td><b>Date</b></td>" >> $summary_report_postpatch  
			echo "	   <td>`date`</td>" >> $summary_report_postpatch  
			echo "</tr>" >> $summary_report_postpatch
			echo "<tr>" >> $summary_report_postpatch
			echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_postpatch
			echo "	   <td>$CHNGID</td>" >> $summary_report_postpatch
			echo "</tr>" >> $summary_report_postpatch
			echo "<tr>" >> $summary_report_postpatch
			echo "     <td><b>Method</b></td>" >> $summary_report_postpatch
			echo "	   <td>Manual</td>" >> $summary_report_postpatch
			echo "</tr>" >> $summary_report_postpatch
			echo "</table>" >> $summary_report_postpatch  
			echo "<br>" >> $summary_report_postpatch 
			echo "<br>" >> $summary_report_postpatch 

			echo "#################################################################################################################################################" > $master_log_postpatch
			echo "DBA: $EMPID" >> $master_log_postpatch
			echo "Step performed: MWHOME oracle_common Postpatch Steps" >> $master_log_postpatch
			echo "Date: `date`" >> $master_log_postpatch
			echo "Change Log Request ID: $CHNGID" >> $master_log_postpatch
			echo "Method: Manual" >> $master_log_postpatch
			echo "#################################################################################################################################################" >> $master_log_postpatch


			#Post patching step 1: lsinventory command
			echo "####################################################################################################"
			echo "MWHOME oracle_common Post patching step 1: lsinventory command"
			echo "####################################################################################################"echo ""
			echo ""
			cd $MIDDLEWARE_HOME/oracle_common/OPatch/
			export TodayDate=`date +%d_%m_%Y`
			export lsinvDate1=`date +%Y-%m-%d_%I-%M`
			export POSTPATCHDIR=${BACKUPDIR}/PREPOST/POSTPATCH_MWHOME_oracle_common_${ENV}_${CHNGID}_${TodayDate}
			./opatch lsinventory -oh $MIDDLEWARE_HOME/oracle_common -jdk $MIDDLEWARE_HOME/jdk160_35 -invPtrLoc $MIDDLEWARE_HOME/oracle_common/oraInst.loc
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Executing lsinventory command for $ENV"
					echo "<br>" >> $summary_report_postpatch
					echo "<b>MWHOME oracle_common Post Patching</b>" >> $summary_report_postpatch  
					echo "<table border="1">" >> $summary_report_postpatch  
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <th>Timestamp</th>" >> $summary_report_postpatch 
					echo "    <th>Step</th>" >> $summary_report_postpatch
					echo "    <th>Status</th>" >> $summary_report_postpatch 
					echo "    <th>Details</th>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 		
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>Fulldate</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME oracle_common Post patching step 1: Execute MWHOME oracle_common lsinventory command</td>" >> $summary_report_postpatch
					echo "    <td>Failure</td>" >> $summary_report_postpatch 
					echo "    <td></td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "" >> $master_log_postpatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
					echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_postpatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
					echo "`date`|MWHOME oracle_common  Post patching step 1: Execute MWHOME oracle_common lsinventory command |Failure      | " >> $master_log_postpatch
					cat $master_log_postpatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Executing lsinventory command for $ENV"
				 cd $MIDDLEWARE_HOME/oracle_common/cfgtoollogs/opatch/lsinv/
				 filename=`ls | grep ${lsinvDate1}`
				 export POSTPATCHDIR=${BACKUPDIR}/PREPOST/POSTPATCH_MWHOME_oracle_common_${ENV}_${CHNGID}_${TodayDate}
				 mkdir ${POSTPATCHDIR}
				 cp $filename ${POSTPATCHDIR}
				 echo "$DateTime: Copied lsinventory file to ${POSTPATCHDIR}"
				 ls -ltr ${POSTPATCHDIR}
					echo "<br>" >> $summary_report_postpatch
					echo "<b>MWHOME oracle_common Post Patching</b>" >> $summary_report_postpatch  
					echo "<table border="1">" >> $summary_report_postpatch  
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <th>Timestamp</th>" >> $summary_report_postpatch 
					echo "    <th>Step</th>" >> $summary_report_postpatch
					echo "    <th>Status</th>" >> $summary_report_postpatch 
					echo "    <th>Details</th>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME oracle_common Post patching step 1: Execute lsinventory command</td>" >> $summary_report_postpatch
					echo "    <td>Success</td>" >> $summary_report_postpatch 
					echo "    <td>Copied lsinventory file $filename to ${POSTPATCHDIR}</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
					echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_postpatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
					echo "`date`|MWHOME oracle_common Post patching step 1: Execute MWHOME oracle_common lsinventory command |Success      |Copied lsinventory file $filename to ${POSTPATCHDIR} " >> $master_log_postpatch
			 fi

			echo ""
			echo ""


			 #Post patching step 2: EPM registry command
			 echo "####################################################################################################"
			 echo "MWHOME oracle_common Post patching step 2: EPM registry command"
			 echo "####################################################################################################"
			 echo ""
			echo ""
			 cd $EPM_ORACLE_INSTANCE/bin
			 echo "./epmsys_registry.sh"
			./epmsys_registry.sh
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Post patching step 2: EPM registry command for $ENV"
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME oracle_common Post patching step 2: Generate EPM registry report</td>" >> $summary_report_postpatch
					echo "    <td>Failure</td>" >> $summary_report_postpatch 
					echo "    <td></td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch
					echo "`date`|Post patching step 2: Generate EPM registry report |Failure      | " >> $master_log_postpatch
					cat $master_log_postpatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Post patching step 2: EPM registry command for $ENV"
				 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
				 cp registry.html ${POSTPATCHDIR}
				 echo "$DateTime: Copied registry.html file to ${POSTPATCHDIR}"
				 ls -ltr ${POSTPATCHDIR}
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>Post patching step 2: Generate EPM registry report</td>" >> $summary_report_postpatch
					echo "    <td>Success</td>" >> $summary_report_postpatch 
					echo "    <td>Copied registry.html file to ${POSTPATCHDIR}</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "`date`|MWHOME oracle_common Post patching step 2: Generate EPM registry report |Success      |Copied registry.html file to ${POSTPATCHDIR} " >> $master_log_postpatch
			 fi
			echo ""
			echo ""

			#Post patching step 3: Generate deployment report
			 echo "####################################################################################################"
			 echo "MWHOME oracle_common Post patching step 3: Generate EPM deployment report"
			 echo "####################################################################################################"
			 echo ""
			echo ""
			cd $EPM_ORACLE_INSTANCE/bin
			echo "./epmsys_registry.sh report deployment"
			export deplreptDate1=`date +%Y%m%d_%H`
			./epmsys_registry.sh report deployment
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Generating EPM deployment report for $ENV"
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME oracle_common Post patching step 3: Generate EPM Deployment report</td>" >> $summary_report_postpatch
					echo "    <td>Failure</td>" >> $summary_report_postpatch 
					echo "    <td></td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "`date`|MWHOME oracle_common Post patching step 3: Generate EPM Deployment report |Failure      | " >> $master_log_postpatch
					cat $master_log_postpatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Generating EPM deployment report for $ENV"
				 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
				 filename=`ls -lrt |awk '{print $9}' |tail -1`
				 cp $filename ${POSTPATCHDIR}
				 echo "$DateTime: Copied EPM deployment reportfile to ${POSTPATCHDIR}"
				 ls -ltr ${POSTPATCHDIR}
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME oracle_common Post patching step 3: Generate EPM Deployment report</td>" >> $summary_report_postpatch
					echo "    <td>Success</td>" >> $summary_report_postpatch 
					echo "    <td>Copied $filename to ${POSTPATCHDIR}</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "`date`|MWHOME oracle_common Post patching step 3: Generate EPM Deployment report |Success      |Copied $filename to ${POSTPATCHDIR} " >> $master_log_postpatch
			 fi
			 
			 
			 #Post patching step 4: Backup of oraInventory
			 echo "####################################################################################################"
			 echo "MWHOME oracle_common Post patching step 4: Backup of oraInventory"
			 echo "####################################################################################################"
			 echo ""
			 echo ""
			 INVLOC=`grep inventory_loc $MIDDLEWARE_HOME/oracle_common/oraInst.loc | cut -d"=" -f2`
			 echo "Oracle Inventory location: $INVLOC"
			tar -cvf ${BACKUPDIR}/INV_BACKUPS/${Day1}_${ENV}_${CHNGID}_POSTPATCH_MWHOME_orcl_common_OraInventory.tar ${INVLOC}
			 VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Backup of oraInventory for $ENV"
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME oracle_common Post patching step 4: Backup of oraInventory</td>" >> $summary_report_postpatch
					echo "    <td>Failure</td>" >> $summary_report_postpatch 
					echo "    <td></td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "" >> $master_log_postpatch
					echo "`date`|MWHOME oracle_commonc Post patching step 4: Backup of oraInventory |Failure      | " >> $master_log_postpatch
					cat $master_log_postpatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Backup of oraInventory for $ENV"
				 ls -ltr ${BACKUPDIR}/INV_BACKUPS/
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME oracle_common Post patching step 4: Backup of oraInventory</td>" >> $summary_report_postpatch
					echo "    <td>Success</td>" >> $summary_report_postpatch 
					echo "    <td>Copied ${Day1}_${ENV}_POSTPATCH_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "`date`|MWHOME oracle_common Post patching step 4: Backup of oraInventory |Success      |Copied ${Day1}_${ENV}_POSTPATCH_orcl_common_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/ " >> $master_log_postpatch
			 fi
			 
			 #Post patching step 5: Critial file copy
			 echo "####################################################################################################"
			  echo "MWHOME oracle_common Post patching step 5: Critial file copy"
			 echo "####################################################################################################"
			 echo ""
			 echo ""
			 cd ${SCRIPTDIR}/
			 export Day33=`date +%Y-%m-%d_%H_%M`
			./Critical_File_copy.sh
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Executing Critial file copy for $ENV"
						echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME oracle_common Post patching step 5: Critial file copy</td>" >> $summary_report_postpatch
					echo "    <td>Failure</td>" >> $summary_report_postpatch 
					echo "    <td></td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "`date`|MWHOME oracle_common Post patching step 5: Critial file copy |Failure      | " >> $master_log_postpatch
					cat $master_log_postpatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Executing Critial file copy for $ENV"
				 crit_dir=`ls ${BACKUPDIR}/Critical_File_Copy | grep ${Day33}`
				 export postpatch_crit_dir=${BACKUPDIR}/Critical_File_Copy/${ENV}_${CHNGID}_POSTPATCH_ORCL_COMM_${Day33}
				 echo "Critical files copied to directory $crit_dir under ${BACKUPDIR}/Critical_File_Copy"
				 mv ${BACKUPDIR}/Critical_File_Copy/${Day33} ${postpatch_crit_dir}
				 echo "Listing files in ${postpatch_crit_dir}"
				 ls -ltr ${postpatch_crit_dir}
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME oracle_common Post patching step 5: Critial file copy</td>" >> $summary_report_postpatch
					echo "    <td>Success</td>" >> $summary_report_postpatch 
					echo "    <td>Copied ${ENV}_${CHNGID}_POSTPATCH_${Day33} to ${BACKUPDIR}/Critical_File_Copy</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "</table>" >> $summary_report_postpatch 
					echo "<br>" >> $summary_report_postpatch 
					echo "<br>" >> $summary_report_postpatch 
					echo "`date`|MWHOME oracle_common Post patching step 5: Critial file copy |Success      |Copied ${ENV}_${CHNGID}_POSTPATCH_${Day33} to ${BACKUPDIR}/Critical_File_Copy " >> $master_log_postpatch
			 fi

			echo ""
			echo ""
			echo "Post patching differences check"
			cd ${BACKUPDIR}/Critical_File_Copy
			echo ""
			export prepatch_crit_dir1=`ls |grep ${ENV}_${CHNGID}_PREPATCH_ORCL_COMM`
			export postpatch_crit_dir1=`ls |grep ${ENV}_${CHNGID}_POSTPATCH_ORCL_COMM`
			echo "Checking differences between ${prepatch_crit_dir1} and ${postpatch_crit_dir1}"

			export fold_diff_tmp=${OUTPUT}/${ENV}_PRE_POST_DIR_DIFF_tmp.txt
			export fold_diff=${OUTPUT}/${ENV}_PRE_POST_DIR_DIFF.txt


			diff --brief -Nr ${prepatch_crit_dir1} ${postpatch_crit_dir1} > ${fold_diff_tmp}

			cat ${fold_diff_tmp} | awk '{print $2,$4}' | tr " " "#" >  ${fold_diff}

			if [ -s ${fold_diff} ]; then
				echo "PREPATCH & POST PATCH has differences"
				echo ""
				echo ""
				cat ${fold_diff_tmp}
				for i in `cat ${fold_diff}`
				do 
					filediff1=`echo "$i" | cut -d"#" -f1 `
					filediff2=`echo "$i" | cut -d"#" -f2 `
					ex_file=`basename $filediff1`
					
				
					diff $filediff1 $filediff2 >  ${OUTPUT}/${ex_file}_diff.txt
					
					cat ${OUTPUT}/${ex_file}_diff.txt
						
					echo "<br>" >> $summary_report_backup
					echo "<b>Differences found in Critical files post patching </b>" >> $summary_report_postpatch
					echo "<br>" >> $summary_report_postpatch 		
					echo "<table border="1">" >> $summary_report_postpatch 
					echo "<tr>" >> $summary_report_postpatch 
					echo "<th><b>File with differences</b></th>" >> $summary_report_postpatch 
					echo "<th><b>Differences found (Prepatching ---> Postpatching)</b></th>" >> $summary_report_postpatch  
					echo "</tr>" >> $summary_report_postpatch 
					echo "<tr>" >> $summary_report_postpatch 
					echo "<td>`echo "$ex_file"`</td>" >> $summary_report_postpatch 
					echo "<td>`cat ${OUTPUT}/${ex_file}_diff.txt`</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "</table>" >> $summary_report_postpatch 
					echo "<br>" >> $summary_report_postpatch 
					
					echo "" >> $master_log_postpatch
					echo "###############################################################################################################################################" >> $master_log_postpatch
					echo " Differences found for Critical files (Prepatch & Post patch)" >> $master_log_postpatch
					echo "###############################################################################################################################################" >> $master_log_postpatch
					echo "`date`  |   Filename: $ex_file " >> $master_log_postpatch
					echo "" >> $master_log_postpatch
					echo "Differences: " >> $master_log_postpatch
					echo "`cat ${OUTPUT}/${ex_file}_diff.txt`" >> $master_log_postpatch
					
						
				done
				
				echo "Correct all the differences and remove flag file /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt manually to resume Critical_File_Copy script"
				echo ""
				echo "###############################################################################################################################################" >> $master_log_postpatch
				echo "Correct all the differences and remove flag file /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt manually to resume Critical_File_Copy script" >> $master_log_postpatch
				echo "###############################################################################################################################################" >> $master_log_postpatch
				
				echo "<b>Correct all the differences and remove flag file /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt manually to resume Critical_File_Copy script</b>" >> $summary_report_postpatch
				echo "<br>" >> $summary_report_postpatch
				
				cat $master_log_postpatch
				
				echo ""
				echo ""
			else
				echo "No differences found in PREPATCH & POST PATCH directories"
				echo "<b>No differences found in Critical files post patching </b>" >> $summary_report_postpatch
				echo "" >> $master_log_postpatch
					echo "###############################################################################################################################################" >> $master_log_postpatch
					echo " No differences found for Critical files (Prepatch & Post patch)" >> $master_log_postpatch
					echo "###############################################################################################################################################" >> $master_log_postpatch
					echo "`date`  |   No difference found" >> $master_log_postpatch
				
				###Remove flag file to resume Critical_File_Copy script ###
				rm /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt
				
				echo "<br>" >> $summary_report_postpatch
				echo "<b>Removed flag file to resume scheduled Critical_File_Copy script</b>" >> $summary_report_postpatch
				echo "<br>" >> $summary_report_postpatch
				echo "###############################################################################################################################################" >> $master_log_postpatch
				echo "Removed flag file to resume scheduled Critical_File_Copy script" >> $master_log_postpatch
					
				cat $master_log_postpatch
			fi

			export summary_report=${PPLOGDIR}/${ENV}_PATCH_Summary_report_${CHNGID}_${Day}.html
			export master_log=${PPLOGDIR}/${ENV}_PATCH_Master_Log_${CHNGID}_${Day}.log

			echo "<html>" > $summary_report
			echo "<h2>$ENV: PATCH SUMMARY REPORT</h2>" >> $summary_report  

			ls -ltr ${PPLOGDIR}/${ENV}_PATCH_report_*${CHNGID}* | awk '{print $9}' > ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt

			if [ -s ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt ]; then
				echo " "
				echo " "
				
				echo "Patch summary report: $summary_report"
				for i in `cat ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt`
				do 
				#filnm=`echo $i | awk '{print $9}'`
				cat $i >> $summary_report
				done
			else
				echo " "
				echo " "
				echo "No other activities performed for this change id"
			fi

			echo "$ENV: PATCH LOG" > $master_log
			 echo "" >> $master_log 

			ls -ltr ${PPLOGDIR}/${ENV}_PATCH_Master_Log_*${CHNGID}* | awk '{print $9}' > ${PPLOGDIR}/patch_step_logs_${CHNGID}_${ENV}.txts

			if [ -s ${PPLOGDIR}/patch_step_logs_${CHNGID}_${ENV}.txt ]; then
				echo " "
				echo " "
				echo "Patch Master Log: $master_log"
				for i in `cat ${PPLOGDIR}/patch_step_logs_${ENV}.txt`
				do 
				#filnme=`echo $i | awk '{print $9}'`
				cat $i >> $master_log
				done
			else
				echo " "
				echo " "
				echo "No other activities performed for this change id"
			fi

			echo ""
			echo "Redirecting to the options screen.."
			echo ""
			optionsScreen
			echo ""
			echo ""

		elif [ $usrselec -eq 0 ]; then
			echo "$usrselec entered. Exiting script.."
			exit 0;
			
		else 
		
			echo "Invalid option chosen. Exiting script....."
			exit 1;
		fi	
} 


function MWHOME_ohs() {

echo ""
echo "1. Prerequisite check
2. Prepatch steps (Regular) 
3. Postpatch steps (Regular)"
echo ""

		echo -n "Select Option, to exit 0 (zero): "
		read usrselec
		if [ $usrselec -eq 1 ]; then
			echo "Option $usrselec selected, Prerequisite check for Middleware ohs location"
			cat ${CTRLLOC}/planning_prereq_instructions.txt
			echo ""
			echo ""

			# Listing out all the Prepatching Activities in comments
			echo ""
			date
			read -p "If the above steps have already been performed, press 1 to Continue, 0 to Exit - " PROG
			if [ $PROG = '0' ]; then
				echo "----------"
				echo "Selection = ${PROG}, exiting script..."
				optionsScreen
			elif [ $PROG = '1' ]; then 	
				echo "Selection = ${PROG}"
				echo "----------"
				read -p "Please enter the patch numbers (if more than one patch, please seperate them by comma (,) - " PATCHNUM
				read -p "Please enter the server location where the patches are downloaded to - " PATCHLOC
			else
				echo "ERROR: Invalid option selected"
				echo "Exiting script"
				exit 1;
			fi
			
			
			read -p "DBA conducting this step (enter your sherwin id): " EMPID
			read -p "Enter the Change Log Request ID (if change log entry is not created, hit Enter): " CHNGID
			echo "DBA conducting this step is "$EMPID
			echo "Change Log request ID is "$CHNGID
			
			
			if [[ "x${CHNGID}" = "x" ]]; then
				echo "No change ID input for "$ENV
				
				export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_MWHOME_ohs_PREREQ_${EMPID}_${Day}.html
				export master_log_prereq=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_ohs_PREREQ_${EMPID}_${Day}.log
			else
				echo "Input file $INPUT_FILE sourced in for "$ENV
				echo "Change Log Request ID is "$CHNGID
				
				export summary_report_prereq=${PPLOGDIR}/${ENV}_PATCH_report_MWHOME_ohs_PREREQ_${CHNGID}_${Day}.html
				export master_log_prereq=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_ohs_PREREQ_${CHNGID}_${Day}.log
				
			fi

			
			echo "----------"
			echo "<br>" >> $summary_report_prereq 
			echo "<table border="1">" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "     <td><b>DBA</b></td>" >> $summary_report_prereq  
			echo "	   <td>$EMPID</td>" >> $summary_report_prereq  
			echo "</tr>" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq 
			echo "     <td><b>Step performed</b></td>" >> $summary_report_prereq  
			echo "	   <td>MWHOME ohs OPatch Prerequisite Check</td>" >> $summary_report_prereq  
			echo "</tr>" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "     <td><b>Date</b></td>" >> $summary_report_prereq  
			echo "	   <td>`date`</td>" >> $summary_report_prereq  
			echo "</tr>" >> $summary_report_prereq 
			echo "<tr>" >> $summary_report_prereq  
			echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_prereq  
			echo "	   <td>$CHNGID</td>" >> $summary_report_prereq	
			echo "</tr>" >> $summary_report_prereq 
			echo "<tr>" >> $summary_report_prereq  
			echo "     <td><b>Method</b></td>" >> $summary_report_prereq  
			echo "	   <td>Manual</td>" >> $summary_report_prereq  
			echo "</tr>" >> $summary_report_prereq 	
			echo "</table>" >> $summary_report_prereq  
			echo "<br>" >> $summary_report_prereq 
			echo "<br>" >> $summary_report_prereq 
			
			echo "#################################################################################################################################################" >> $master_log_prereq
			echo "DBA: $EMPID" >> $master_log_prereq
			echo "Step performed: MWHOME ohs OPatch Prerequisite Check" >> $master_log_prereq
			echo "Date: `date`" >> $master_log_prereq
			echo "Change Log Request ID: $CHNGID" >> $master_log_prereq
			echo "Method: Manual" >> $master_log_prereq
				
			
			
			export REFDateTime=`date +%d%m%y_%H%M%S`
			cd $MIDDLEWARE_HOME/ohs/OPatch/
			export PREREQ_DIR=${OUTPUT}/${ENV}_MWHOME_ohs_PREREQ_${REFDateTime}
			export USR_PREREQ_INPUT=${OUTPUT}/${ENV}_MWHOME_ohs_PREREQ_${REFDateTime}.cfg
			mkdir ${PREREQ_DIR}
			
			echo "DBA=$EMPID" > ${USR_PREREQ_INPUT}
			echo "PATCHNUM=$PATCHNUM" >> ${USR_PREREQ_INPUT}
			echo "PATCHLOC=$PATCHLOC" >> ${USR_PREREQ_INPUT}
			echo "----------"
			cat ${USR_PREREQ_INPUT}
			
			echo "<br>" >> $summary_report_prereq 
			echo "<b>MWHOME ohs OPatch Prequisite Check Activity </b>" >> $summary_report_prereq  
			echo "<table border="1">" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "    <td><b>Patch Number(s)</b></th>" >> $summary_report_prereq 
			echo "    <td>$PATCHNUM</th>" >> $summary_report_prereq
			echo "</tr>" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "    <td><b>Patch Location</b></td>" >> $summary_report_prereq 
			echo "    <td>$PATCHLOC</td>" >> $summary_report_prereq 
			echo "</tr>" >> $summary_report_prereq 	
			echo "</table>" >> $summary_report_prereq
			echo "<br>" >> $summary_report_prereq 	
			
			echo "MWHOME ohs OPatch Prequisite Check Activity " >> $master_log_prereq
			echo "    Patch Number(s): $PATCHNUM" >> $master_log_prereq
			echo "    Patch Location: $PATCHLOC" >> $master_log_prereq
			echo "#################################################################################################################################################" >> $master_log_prereq
			
			echo "Executing lsinventory command..."
			cd $MIDDLEWARE_HOME/ohs/OPatch/
			./opatch lsinventory -oh $MIDDLEWARE_HOME/ohs -jdk $MIDDLEWARE_HOME/jdk160_35 -invPtrLoc $MIDDLEWARE_HOME/ohs/oraInst.loc > ${PREREQ_DIR}/${ENV}_lsinventory.txt
						
			
			checkMulti=`echo $PATCHNUM | grep -o "," | wc -l`
			echo $PATCHNUM | sed 's/,/\n/g' > ${PREREQ_DIR}/${ENV}_Patch_numbers.txt
			if [ $checkMulti -eq 0 ]; then
				echo "Single patch to be applied"
				echo ${PATCHNUM}
				echo "TASK 1: Checking if the patch file ${PATCHNUM} is in the given patch location $PATCHLOC"
					fndPatch=`find ${PATCHLOC} -maxdepth 1 -name "*${PATCHNUM}*.zip"`
					find ${PATCHLOC} -maxdepth 1 -name "*${PATCHNUM}*.zip"
					ret=$?
					if [ $ret -eq 0 ]; then
						echo "Patch file $fndPatch present, unzipping it...."
						echo "unzip -o $fndPatch"
						cd $MIDDLEWARE_HOME/ohs/OPatch/
						unzip -o $fndPatch
						echo ""
						echo "TASK 2: Creating & executing Prereq script for patch $PATCHNUM"
						tmp_script=${PREREQ_DIR}/mwhome_ohs_opatch_prereq_tmp_${PATCHNUM}.sh
						new_script=${PREREQ_DIR}/mwhome_ohs_opatch_prereq_${PATCHNUM}.sh
						
						echo "<br>" >> $summary_report_prereq 
						echo "<b>MWHOME ohs OPatch Prequisite Check for patch ${PATCHNUM} </b>" >> $summary_report_prereq  
						echo "<table border="1">" >> $summary_report_prereq  
						echo "<tr>" >> $summary_report_prereq  
						echo "    <th>Timestamp</th>" >> $summary_report_prereq 
						echo "    <th>Prereq Check</th>" >> $summary_report_prereq
						echo "    <th>Status</th>" >> $summary_report_prereq 
						echo "    <th>Details</th>" >> $summary_report_prereq 
						echo "</tr>" >> $summary_report_prereq 		
						
						echo "MWHOME ohs OPatch Prequisite Check for patch ${PATCHNUM} " >> $master_log_prereq
						echo "Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
						echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
						
						
						echo "Checking the lsinventory to see if the patch is applied on the environment"
						grep -wi ${PATCHNUM} ${PREREQ_DIR}/${ENV}_lsinventory.txt > ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}.txt
						tret=$?
						if [[ $tret -eq 0 ]];then
							echo "$PATCHNUM present in lsinventory and already applied in this environment"
							echo ""
							cat ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}.txt
							mv ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}.txt ${PREREQ_DIR}/${ENV}_lsinventory_${PATCHNUM}_present.txt
							
							echo "<tr>" >> $summary_report_prereq  
							echo "    <td>`date`</td>" >> $summary_report_prereq 
							echo "    <td>Check the patch in lsinventory</td>" >> $summary_report_prereq
							echo "    <td>Failure</td>" >> $summary_report_prereq 
							echo "    <td>The patch is already applied in the environment. Please verify</td>" >> $summary_report_prereq 
							echo "</tr>" >> $summary_report_prereq 
							echo "</table>" >> $summary_report_prereq
							echo ""
							echo " `date`|Check the patch in lsinventory | Failure     | The patch is already applied in the environment. Please verify" >> $master_log_prereq 
							echo "" >> $master_log_prereq 
							cat $master_log_prereq
							echo "Please verify the patch number, exiting the script now.."
							exit 1;
						else
							echo "$PATCHNUM not present in lsinventory, proceeding further..."
							echo " `date`|Check the patch in lsinventory | Success     | Patch is not applied" >> $master_log_prereq 
							echo ""
						fi
						
						
						cp ${CTRLLOC}/mwhome_ohs_opatch_prereq.sh $tmp_script
						export patchNN=$PATCHNUM
						eval "echo \"`cat $tmp_script`\"" > $new_script
						chmod +x $new_script
						cd ${PREREQ_DIR}
						. $new_script > ${new_script}.log
						ret=$?
						if [ $ret -eq 0 ]; then
							echo "PREREQ check script executed"
							echo ""
						else
							echo "PREREQ check script execution failed"
							echo ""
							echo "PREREQ check script execution failed" >> $master_log_prereq
							echo "" >> $master_log_prereq 
							cat $master_log_prereq
							exit 1;
						fi
						
						grep Prereq ${new_script}.log > ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log
						prereq_stat_SysSpace=`grep -wi checkSystemSpace ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
						prereq_stat_appliProduct=`grep -wi checkApplicableProduct ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
						prereq_stat_component=`grep -wi checkComponents ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
						prereq_stat_conDetail=`grep -wi checkConflictAmongPatchesWithDetail ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
						prereq_stat_appDepend=`grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
						prereq_stat_applica=`grep -wi checkApplicable ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f6`
						prereq_stat_conOHDetail=`grep -wi checkConflictAgainstOHWithDetail ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
						prereq_stat_InputValues=`grep -wi checkForInputValues ${PREREQ_DIR}/PREREQ_status_${PATCHNUM}.log | cut -d" " -f3`
						
						export prereq_status_tidy=${PREREQ_DIR}/PREREQ_status_${PATCHNUM}_tidy.log
						echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace" > ${prereq_status_tidy}
						echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct" >> ${prereq_status_tidy}
						echo "PREREQ:checkComponents:$prereq_stat_component" >> ${prereq_status_tidy}
						echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail" >> ${prereq_status_tidy}
						echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend" >> ${prereq_status_tidy}
						echo "PREREQ:checkApplicable:$prereq_stat_applica" >> ${prereq_status_tidy}
						echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail" >> ${prereq_status_tidy}
						echo "PREREQ:checkForInputValues:$prereq_stat_InputValues" >> ${prereq_status_tidy}
						
								
						for n in `cat ${prereq_status_tidy}`
						do
						prereq_chkk=`echo $n |cut -d":" -f2`
						prereq_chkk_stat=`echo $n |cut -d":" -f3`
						
							echo "<tr>" >> $summary_report_prereq  
							echo "    <td>`date`</td>" >> $summary_report_prereq 
							echo "    <td>${prereq_chkk}</td>" >> $summary_report_prereq
							echo "    <td>${prereq_chkk_stat}</td>" >> $summary_report_prereq 
							echo "    <td></td>" >> $summary_report_prereq 
							echo "</tr>" >> $summary_report_prereq
							
							echo "`date`|${prereq_chkk} | ${prereq_chkk_stat} | " >> $master_log_prereq 
												
						done
						
						if [ "$prereq_stat_SysSpace" = "passed." ]; then
							echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace"  
						elif [ "$prereq_stat_SysSpace" = " " ]; then	
							echo "PREREQ status is blank, please check"
							
						else
							echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details"
							echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi	
						
						 if [ "$prereq_stat_appliProduct" = "passed." ]; then
							 echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct"
						 elif [ "$prereq_stat_appliProduct" = " " ]; then	
							 echo "PREREQ status is blank, please check"
							 echo "PREREQ status is blank, please check" >> $master_log_prereq
						 else
							 echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details"
							 echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details" >> $master_log_prereq
							 cat $master_log_prereq
							 exit 1;
						 fi
						
						 if [ "$prereq_stat_component" = "passed." ]; then
							 echo "PREREQ:checkComponents:$prereq_stat_component"
						 elif [ "$prereq_stat_component" = " " ]; then	
							 echo "PREREQ status is blank, please check"
							 echo "PREREQ status is blank, please check" >> $master_log_prereq
						 else
							 echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details"
							 echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details" >> $master_log_prereq
							 cat $master_log_prereq
							 exit 1;
						 fi				
						
						if [ "$prereq_stat_conDetail" = "passed." ]; then
							echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail"
						elif [ "$prereq_stat_conDetail" = " " ]; then	
							echo "PREREQ status is blank, please check"
						else
							echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi
						
						if [ "$prereq_stat_appDepend" = "passed." ]; then
							echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend"
						elif [ "$prereq_stat_appDepend" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi
						
						 if [ "$prereq_stat_applica" = "passed." ]; then
							 echo "PREREQ:checkApplicable:$prereq_stat_applica"
						 elif [ "$prereq_stat_applica" = " " ]; then	
							 echo "PREREQ status is blank, please check"
							 echo "PREREQ status is blank, please check" >> $master_log_prereq
						 else
							 echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details"
							 echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details" >> $master_log_prereq
							 cat $master_log_prereq
							 exit 1;
						 fi
						
						if [ "$prereq_stat_conOHDetail" = "passed." ]; then
							echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail"
						elif [ "$prereq_stat_conOHDetail" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi	
						
						if [ "$prereq_stat_InputValues" = "passed." ]; then
							echo "PREREQ:checkForInputValues:$prereq_stat_InputValues"
						elif [ "$prereq_stat_InputValues" = " " ]; then	
							echo "PREREQ status is blank, please check"
							echo "PREREQ status is blank, please check" >> $master_log_prereq
						else
							echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details"
							echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details" >> $master_log_prereq
							cat $master_log_prereq
							exit 1;
						fi	
						
						echo ""
						echo "PREREQ Checks successful"
						echo "<table border="1">" >> $summary_report_prereq  
						echo "PREREQ Checks successful" >> $master_log_prereq
						echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
								
					
					
					else
						echo "Unable to find patch file, please check the location"
						echo "Unable to find patch file, please check the location" >> $master_log_prereq
						cat $master_log_prereq
						exit 1;
					fi
			else
				echo "Multiple patches to be applied"
				cat ${PREREQ_DIR}/${ENV}_Patch_numbers.txt
				for i in `cat ${PREREQ_DIR}/${ENV}_Patch_numbers.txt`
				do
					echo $i
					echo "TASK 1: Checking the lsinventory to see if the patch is applied on the environment"
					grep -wi ${i} ${PREREQ_DIR}/${ENV}_lsinventory.txt > ${PREREQ_DIR}/${ENV}_lsinventory_${i}.txt
					tret=$?
						if [[ $tret -eq 0 ]];then
							echo "$i present in lsinventory and already applied in this environment"
							echo ""
							cat ${PREREQ_DIR}/${ENV}_lsinventory_${i}.txt
							mv ${PREREQ_DIR}/${ENV}_lsinventory_${i}.txt ${PREREQ_DIR}/${ENV}_lsinventory_${i}_present.txt
							
							echo "<br>" >> $summary_report_prereq 
							echo "<b>MWHOME ohs OPatch Prequisite Check for patch ${i}</b>" >> $summary_report_prereq  
							echo "<table border="1">" >> $summary_report_prereq  
							echo "<tr>" >> $summary_report_prereq  
							echo "    <th>Timestamp</th>" >> $summary_report_prereq 
							echo "    <th>Prereq Check</th>" >> $summary_report_prereq
							echo "    <th>Status</th>" >> $summary_report_prereq 
							echo "    <th>Details</th>" >> $summary_report_prereq 
							echo "</tr>" >> $summary_report_prereq 
							
							echo "<tr>" >> $summary_report_prereq  
							echo "    <td>`date`</td>" >> $summary_report_prereq 
							echo "    <td>Check the patch $i in lsinventory</td>" >> $summary_report_prereq
							echo "    <td>Failure</td>" >> $summary_report_prereq 
							echo "    <td>The patch $i is already applied in the environment. Please verify</td>" >> $summary_report_prereq 
							echo "</tr>" >> $summary_report_prereq
							echo "</table>" >> $summary_report_prereq
							echo "<br>" >> $summary_report_prereq
							
							echo "MWHOME ohs OPatch Prequisite Check for patch ${i} " >> $master_log_prereq
							echo " Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
							echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
							echo " `date`|Check the patch in lsinventory | Failure     | The patch is already applied in the environment. Please verify" >> $master_log_prereq 
							echo "" >> $master_log_prereq 
							echo ""
							echo "Please verify the patch number.."
						else
							echo "$i not present in lsinventory, proceeding further..."
							echo ""
							echo "TASK 2: Checking if the patch file $i is in the given patch location $PATCHLOC"
							fndPatch=`find ${PATCHLOC} -maxdepth 1 -name "*${i}*.zip"`
							find ${PATCHLOC} -maxdepth 1 -name "*${i}*.zip"
							ret=$?
							if [ $ret -eq 0 ]; then
								echo "Patch file $fndPatch present, unzipping it...."
								echo "unzip -o $fndPatch"
								cd $MIDDLEWARE_HOME/ohs/OPatch/
								unzip -o $fndPatch
								echo ""
								echo "TASK 2: Creating & executing Prereq script for patch $i"
								tmp_script=${PREREQ_DIR}/mwhome_ohs_opatch_prereq_tmp_${i}.sh
								new_script=${PREREQ_DIR}/mwhome_ohs_opatch_prereq_${i}.sh
										
					
								
								cp ${CTRLLOC}/mwhome_ohs_opatch_prereq.sh $tmp_script
								export patchNN=$i
								eval "echo \"`cat $tmp_script`\"" > $new_script
								chmod +x $new_script
								. $new_script > ${new_script}.log
								ret=$?
								if [ $ret -eq 0 ]; then
									echo "PREREQ check script executed"
									echo ""
								else
									echo "PREREQ check script execution failed"
									echo "PREREQ check script execution failed" >> $master_log_prereq 
									echo "" >> $master_log_prereq 
									echo ""
									exit 1;
								fi
								
								grep Prereq ${new_script}.log > ${PREREQ_DIR}/PREREQ_status_${i}.log
												
								prereq_stat_SysSpace=`grep -wi checkSystemSpace ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
								prereq_stat_conDetail=`grep -wi checkConflictAmongPatchesWithDetail ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
								prereq_stat_conOHDetail=`grep -wi checkConflictAgainstOHWithDetail ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
								prereq_stat_InputValues=`grep -wi checkForInputValues ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f3`
								prereq_stat_appliProduct=`grep -wi checkApplicableProduct ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
								prereq_stat_component=`grep -wi checkComponents ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
								prereq_stat_appDepend=`grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
								prereq_stat_applica=`grep -wi checkApplicable ${PREREQ_DIR}/PREREQ_status_${i}.log | cut -d" " -f6`
								
								
								export prereq_status_tidy=${PREREQ_DIR}/PREREQ_status_${i}_tidy.log
								echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace" > ${prereq_status_tidy}
								echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct" >> ${prereq_status_tidy}
								echo "PREREQ:checkComponents:$prereq_stat_component" >> ${prereq_status_tidy}
								echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail" >> ${prereq_status_tidy}
								echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend" >> ${prereq_status_tidy}
								echo "PREREQ:checkApplicable:$prereq_stat_applica" >> ${prereq_status_tidy}
								echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail" >> ${prereq_status_tidy}
								echo "PREREQ:checkForInputValues:$prereq_stat_InputValues" >> ${prereq_status_tidy}
								
								echo "<br>" >> $summary_report_prereq 
								echo "<b>MWHOME ohs OPatch Prequisite Check for patch ${i}</b>" >> $summary_report_prereq  
								echo "<table border="1">" >> $summary_report_prereq  
								echo "<tr>" >> $summary_report_prereq  
								echo "    <th>Timestamp</th>" >> $summary_report_prereq 
								echo "    <th>Prereq Check</th>" >> $summary_report_prereq
								echo "    <th>Status</th>" >> $summary_report_prereq 
								echo "    <th>Details</th>" >> $summary_report_prereq 
								echo "</tr>" >> $summary_report_prereq 		
								
								echo "MWHOME ohs OPatch Prequisite Check for patch ${i} " >> $master_log_prereq
								echo " Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
								echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
								
								for n in `cat ${prereq_status_tidy}`
								do
								prereq_chkk=`echo $n |cut -d":" -f2`
								prereq_chkk_stat=`echo $n |cut -d":" -f3`
								
									echo "<tr>" >> $summary_report_prereq  
									echo "    <td>`date`</td>" >> $summary_report_prereq 
									echo "    <td>${prereq_chkk}</td>" >> $summary_report_prereq
									echo "    <td>${prereq_chkk_stat}</td>" >> $summary_report_prereq 
									echo "    <td></td>" >> $summary_report_prereq 
									echo "</tr>" >> $summary_report_prereq 
									
									echo "`date`|${prereq_chkk} | ${prereq_chkk_stat} | " >> $master_log_prereq 
									
								done
								
								
								if [ "$prereq_stat_SysSpace" = "passed." ]; then
									echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace"  
								elif [ "$prereq_stat_SysSpace" = " " ]; then	
									echo "PREREQ status is blank, please check"
									
								else
									echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details"
									echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi	
								
								 if [ "$prereq_stat_appliProduct" = "passed." ]; then
									 echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct"
								 elif [ "$prereq_stat_appliProduct" = " " ]; then	
									 echo "PREREQ status is blank, please check"
									 echo "PREREQ status is blank, please check" >> $master_log_prereq
								 else
									 echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details"
									 echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details" >> $master_log_prereq
									 cat $master_log_prereq
									 exit 1;
								 fi
								
								 if [ "$prereq_stat_component" = "passed." ]; then
									 echo "PREREQ:checkComponents:$prereq_stat_component"
								 elif [ "$prereq_stat_component" = " " ]; then	
									 echo "PREREQ status is blank, please check"
									 echo "PREREQ status is blank, please check" >> $master_log_prereq
								 else
									 echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details"
									 echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details" >> $master_log_prereq
									 cat $master_log_prereq
									 exit 1;
								 fi				
								
								if [ "$prereq_stat_conDetail" = "passed." ]; then
									echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail"
								elif [ "$prereq_stat_conDetail" = " " ]; then	
									echo "PREREQ status is blank, please check"
								else
									echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								if [ "$prereq_stat_appDepend" = "passed." ]; then
									echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend"
								elif [ "$prereq_stat_appDepend" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								 if [ "$prereq_stat_applica" = "passed." ]; then
									 echo "PREREQ:checkApplicable:$prereq_stat_applica"
								 elif [ "$prereq_stat_applica" = " " ]; then	
									 echo "PREREQ status is blank, please check"
									 echo "PREREQ status is blank, please check" >> $master_log_prereq
								 else
									 echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details"
									 echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details" >> $master_log_prereq
									 cat $master_log_prereq
									 exit 1;
								 fi
								
								if [ "$prereq_stat_conOHDetail" = "passed." ]; then
									echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail"
								elif [ "$prereq_stat_conOHDetail" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi	
								
								if [ "$prereq_stat_InputValues" = "passed." ]; then
									echo "PREREQ:checkForInputValues:$prereq_stat_InputValues"
								elif [ "$prereq_stat_InputValues" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								echo ""
								echo "PREREQ Checks successful"
								echo "" >> $master_log_prereq
								echo "PREREQ Checks successful" >> $master_log_prereq
								echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
								echo "</table>" >> $summary_report_prereq
								echo "<br>" >> $summary_report_prereq
							else
								echo "Unable to find patch file, please check the location"
								echo "Unable to find patch file, please check the location" >> $master_log_prereq
								cat $master_log_prereq
								exit 1;
							fi	
						fi
				done
				ls -ltr ${PREREQ_DIR}/${ENV}_lsinventory_*_present.txt 
				uret=$?
				echo $uret
				if [[ $uret -eq 0 ]];then
					echo "Few patches are already applied in this environment, please verify. Exiting script...."
					echo "Few patches are already applied in this environment, please verify." >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				else
					echo "All the patches are good to go"
				fi
									
			fi
			cat $master_log_prereq	
			echo ""
			echo ""
					
			optionsScreen

		elif [ $usrselec -eq 2 ]; then
			echo ""
			echo "Option $usrselec selected, backup of oraInventory, lsinventory from Middleware ohs location"
			echo ""
			read -p "DBA conducting this step (enter your sherwin id) " EMPID
			read -p "Enter the Change Log Request ID : " CHNGID
			echo "DBA conducting this step is "$EMPID
			echo "Change Log request ID is "$CHNGID


			if [[ "$CHNGID" = "" ]]; then
				echo "No change ID input for "$ENV
				
				export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report_MWHOME_ohs_PREPATCH_${EMPID}_${Day}.html
				export master_log_prepatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_ohs_PREPATCH_${EMPID}_${Day}.log
							
			else
				echo "Input file $INPUT_FILE sourced in for "$ENV
				echo "Change Log Request ID is "$CHNGID
				
				export summary_report_prepatch=${PPLOGDIR}/${ENV}_PATCH_report__MWHOME_ohs_PREPATCH_${CHNGID}_${Day}.html
				export master_log_prepatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_ohs_PREPATCH_${CHNGID}_${Day}.log
		
			fi
			echo "----------"
			echo "<br>" >> $summary_report_prepatch
			echo "<table border="1">" >> $summary_report_prepatch  
			echo "<tr>" >> $summary_report_prepatch  
			echo "     <td><b>DBA</b></td>" >> $summary_report_prepatch  
			echo "	   <td>$EMPID</td>" >> $summary_report_prepatch
			echo "</tr>" >> $summary_report_prepatch 
			echo "<tr>" >> $summary_report_prepatch  
			echo "     <td><b>Step performed</b></td>" >> $summary_report_prepatch  
			echo "	   <td>MWHOME ohs Prepatch Steps</td>" >> $summary_report_prepatch    
			echo "</tr>" >> $summary_report_prepatch  
			echo "<tr>" >> $summary_report_prepatch  
			echo "     <td><b>Date</b></td>" >> $summary_report_prepatch  
			echo "	   <td>`date`</td>" >> $summary_report_prepatch  
			echo "</tr>" >> $summary_report_prepatch  
			echo "<tr>" >> $summary_report_prepatch 
			echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_prepatch
			echo "	   <td>$CHNGID</td>" >> $summary_report_prepatch
			echo "</tr>" >> $summary_report_prepatch
			echo "<tr>" >> $summary_report_prepatch  
			echo "     <td><b>Method</b></td>" >> $summary_report_prepatch
			echo "	   <td>Manual</td>" >> $summary_report_prepatch 
			echo "</tr>" >> $summary_report_prepatch
			echo "</table>" >> $summary_report_prepatch  
			echo "<br>" >> $summary_report_prepatch 
			echo "<br>" >> $summary_report_prepatch 

			echo "#################################################################################################################################################" > $master_log_prepatch
			echo "DBA: $EMPID" >> $master_log_prepatch
			echo "Step performed: MWHOME ohs Prepatch Steps" >> $master_log_prepatch
			echo "Date: `date`" >> $master_log_prepatch
			echo "Change Log Request ID: $CHNGID" >> $master_log_prepatch
			echo "Method: Manual" >> $master_log_prepatch
			echo "#################################################################################################################################################" >> $master_log_prepatch

			### Create flag file to put Critical_file_copy script on hold during patching"
			echo " Creating flag file to put Critical_file_copy script on hold during patching"
			echo " Creating flag file to put Critical_file_copy script on hold during patching" >> $master_log_prepatch
			echo "#################################################################################################################################################" >> $master_log_prepatch
			touch /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt

			#Prepatching step 1: lsinventory command
			echo "####################################################################################################"
			echo "MWHOME ohs Prepatching step 1: lsinventory command"
			echo "####################################################################################################"echo ""
			echo ""
			cd $MIDDLEWARE_HOME/ohs/OPatch/
			
			export TodayDate=`date +%d_%m_%Y`
			export PREPATCHDIR=${BACKUPDIR}/PREPOST/PREPATCH_MWHOME_ohs_${ENV}_${CHNGID}_${TodayDate}
			export lsinvDate=`date +%Y-%m-%d_%I-%M-%S%p`
			./opatch lsinventory -oh $MIDDLEWARE_HOME/ohs -jdk $MIDDLEWARE_HOME/jdk160_35 -invPtrLoc $MIDDLEWARE_HOME/ohs/oraInst.loc
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Executing lsinventory command of MWHOME ohs for $ENV"
					echo "<br>" >> $summary_report_prepatch
					echo "<b>MWHOME ohs Pre Patching</b>" >> $summary_report_prepatch  
					echo "<table border="1">" >> $summary_report_prepatch  
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <th>Timestamp</th>" >> $summary_report_prepatch 
					echo "    <th>Step</th>" >> $summary_report_prepatch
					echo "    <th>Status</th>" >> $summary_report_prepatch 
					echo "    <th>Details</th>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME ohs Prepatching step: Execute lsinventory command of MWHOME ohs</td>" >> $summary_report_prepatch
					echo "    <td>Failure</td>" >> $summary_report_prepatch 
					echo "    <td></td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					
					echo "" >> $master_log_prepatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
					echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_prepatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
					echo "`date`|MWHOME ohs Prepatching step 1: Execute MWHOME ohs lsinventory command |Failure      | " >> $master_log_prepatch
					cat $master_log_prepatch	
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Executing MWHOME ohs lsinventory command of MWHOME ohs for $ENV"
				 cd $MIDDLEWARE_HOME/ohs/cfgtoollogs/opatch/lsinv/
				 filename=`ls | grep ${lsinvDate}`
				 echo $filename
				 
				 mkdir ${PREPATCHDIR}
				 cp $filename ${PREPATCHDIR}
				 echo "$DateTime: Copied MWHOME ohs lsinventory file to ${PREPATCHDIR}"
				 ls -ltr ${PREPATCHDIR}
					echo "<br>" >> $summary_report_prepatch
					echo "<b>MWHOME ohs Pre Patching</b>" >> $summary_report_prepatch  
					echo "<table border="1">" >> $summary_report_prepatch  
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <th>Timestamp</th>" >> $summary_report_prepatch 
					echo "    <th>Step</th>" >> $summary_report_prepatch
					echo "    <th>Status</th>" >> $summary_report_prepatch 
					echo "    <th>Details</th>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME ohs Prepatching step 1: Execute MWHOME ohs lsinventory command</td>" >> $summary_report_prepatch
					echo "    <td>Success</td>" >> $summary_report_prepatch 
					echo "    <td>Copied lsinventory file $filename to ${PREPATCHDIR}</td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "" >> $master_log_prepatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
					echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_prepatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
					echo "`date`|MWHOME ohs Prepatching step 1: Execute MWHOME ohs lsinventory command |Success      |Copied lsinventory file $filename to ${PREPATCHDIR} " >> $master_log_prepatch
			 fi

			echo ""
			echo ""


			 #Prepatching step 2: EPM registry command
			 echo "####################################################################################################"
			 echo "MWHOME ohs Prepatching step 2: EPM registry command"
			 echo "####################################################################################################"
			 echo ""
			echo ""
			 cd $EPM_ORACLE_INSTANCE/bin
			 echo "./epmsys_registry.sh"
			./epmsys_registry.sh
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Prepatching step 2: EPM registry command for $ENV"
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME ohs Prepatching step 2: Generate EPM registry report</td>" >> $summary_report_prepatch
					echo "    <td>Failure</td>" >> $summary_report_prepatch 
					echo "    <td></td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME ohs Prepatching step 2: Generate EPM registry report |Failure      | " >> $master_log_prepatch
					cat $master_log_prepatch	
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Prepatching step 2: EPM registry command for $ENV"
				 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
				 cp registry.html ${PREPATCHDIR}
				 echo "$DateTime: Copied registry.html file to ${PREPATCHDIR}"
				 ls -ltr ${PREPATCHDIR}
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME ohs Prepatching step 2: Generate EPM registry report</td>" >> $summary_report_prepatch
					echo "    <td>Success</td>" >> $summary_report_prepatch 
					echo "    <td>Copied registry.html file to ${PREPATCHDIR}</td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME ohs Prepatching step 2: Generate EPM registry report |Success      |Copied registry.html file to ${PREPATCHDIR}" >> $master_log_prepatch
					
			 fi
			echo ""
			echo ""

			#Prepatching step 3: Generate deployment report
			 echo "####################################################################################################"
			 echo "MWHOME ohs Prepatching step 3: Generate EPM deployment report"
			 echo "####################################################################################################"
			 echo ""
			echo ""
			cd $EPM_ORACLE_INSTANCE/bin
			echo "./epmsys_registry.sh report deployment"
			export deplreptDate=`date +%Y%m%d_%H`
			echo $deplreptDate
			./epmsys_registry.sh report deployment
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Generating EPM deployment report for $ENV"
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME ohs Prepatching step 3: Generate EPM Deployment report</td>" >> $summary_report_prepatch
					echo "    <td>Failure</td>" >> $summary_report_prepatch 
					echo "    <td></td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME ohsPrepatching step 3: Generate EPM Deployment report |Failure      | " >> $master_log_prepatch
					cat $master_log_prepatch	
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Generating EPM deployment report for $ENV"
				 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
				 filename=`ls -lrt |awk '{print $9}' |tail -1`
				 cp $filename ${PREPATCHDIR}
				 echo "$DateTime: Copied EPM deployment reportfile to ${PREPATCHDIR}"
				 ls -ltr ${PREPATCHDIR}
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME ohs Prepatching step 3: Generate EPM Deployment report</td>" >> $summary_report_prepatch
					echo "    <td>Success</td>" >> $summary_report_prepatch 
					echo "    <td>Copied $filename to ${PREPATCHDIR}</td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME ohsPrepatching step 3: Generate EPM Deployment report |Success      |Copied $filename to ${PREPATCHDIR} " >> $master_log_prepatch
			 fi
			 
			 
			 #Prepatching step 4: Backup of oraInventory
			 echo "####################################################################################################"
			 echo "MWHOME ohs Prepatching step 4: Backup of oraInventory"
			 echo "####################################################################################################"
			 echo ""
			 echo ""
			 INVLOC=`grep inventory_loc $MIDDLEWARE_HOME/ohs/oraInst.loc | cut -d"=" -f2`
			 echo "Oracle Inventory location: $INVLOC"
			tar -cvf ${BACKUPDIR}/INV_BACKUPS/${Day1}_${ENV}_${CHNGID}_PREPATCH_MWHOME_ohs_OraInventory.tar ${INVLOC}
			 VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Backup of oraInventory for $ENV"
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME ohs Prepatching step 4: Backup of oraInventory</td>" >> $summary_report_prepatch
					echo "    <td>Failure</td>" >> $summary_report_prepatch 
					echo "    <td></td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME ohs Prepatching step 4: Backup of oraInventory |Failure      | " >> $master_log_prepatch
					cat $master_log_prepatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Backup of oraInventory for $ENV"
				 ls -ltr ${BACKUPDIR}/INV_BACKUPS/
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME ohs Prepatching step 4: Backup of oraInventory</td>" >> $summary_report_prepatch
					echo "    <td>Success</td>" >> $summary_report_prepatch 
					echo "    <td>Copied ${Day1}_${ENV}_PREPATCH_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/</td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME ohs Prepatching step 4: Backup of oraInventory |Success      |Copied ${Day1}_${ENV}_PREPATCH_MWHOME_ohs_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/ " >> $master_log_prepatch
			 fi
			 
			 #Prepatching step 5: Critial file copy
			 echo "####################################################################################################"
			  echo "MWHOME ohs Prepatching step 5: Critial file copy"
			 echo "####################################################################################################"
			 echo ""
			 echo ""
			 cd ${SCRIPTDIR}/
			  export Day3=`date +%Y-%m-%d_%H_%M`
			 ./Critical_File_copy.sh
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Executing Critial file copy for $ENV"
						echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME ohs Prepatching step 5: Critial file copy</td>" >> $summary_report_prepatch
					echo "    <td>Failure</td>" >> $summary_report_prepatch 
					echo "    <td></td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "`date`|MWHOME ohs Prepatching step 5: Critial file copy |Failure      | " >> $master_log_prepatch
					cat $master_log_prepatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Executing Critial file copy for $ENV"
				 crit_dir=`ls ${BACKUPDIR}/Critical_File_Copy | grep ${Day3}`
				 export prepatch_crit_dir=${BACKUPDIR}/Critical_File_Copy/${ENV}_${CHNGID}_PREPATCH_OHS_${Day3}
				 echo "Critical files copied to directory $crit_dir under ${BACKUPDIR}/Critical_File_Copy"
				 mv ${BACKUPDIR}/Critical_File_Copy/${Day3} ${prepatch_crit_dir}
				 echo "Listing files in ${prepatch_crit_dir}"
				 ls -ltr ${prepatch_crit_dir}
					echo "<tr>" >> $summary_report_prepatch  
					echo "    <td>`date`</td>" >> $summary_report_prepatch 
					echo "    <td>MWHOME ohs Prepatching step 5: Critial file copy</td>" >> $summary_report_prepatch
					echo "    <td>Success</td>" >> $summary_report_prepatch 
					echo "    <td>Copied ${ENV}_${CHNGID}_PREPATCH_${Day3} to ${BACKUPDIR}/Critical_File_Copy</td>" >> $summary_report_prepatch 
					echo "</tr>" >> $summary_report_prepatch 
					echo "</table>" >> $summary_report_prepatch 
					echo "<br>" >> $summary_report_prepatch 
					echo "<br>" >> $summary_report_prepatch
					echo "`date`|MWHOME ohs Prepatching step 5: Critial file copy |Success      |Copied ${ENV}_${CHNGID}_PREPATCH_${Day3} to ${BACKUPDIR}/Critical_File_Copy " >> $master_log_prepatch
			 fi

					echo "##############################################################################################################################################" >> $master_log_prepatch
			echo ""
			echo ""
			echo ""
					echo "Checking the last execution status for cloud control jobs for $ENV"
					echo ""
					echo "Listing backups for $ENV..."
					echo ""
					cat ${CTRLLOC}/${ENV}_status_all_backup_jobs.cfg
					echo ""
					echo "Fetching the last execution status of jobs"
					echo "Last execution status for cloud control jobs for $ENV" >> $master_log_prepatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
					echo "" >> $master_log_prepatch
					echo "" 
					for n in `cat ${CTRLLOC}/${ENV}_status_all_backup_jobs.cfg`
					do
					${EMCLIHOME}/emcli get_jobs -name="${n}" -owner="SW_JOBADMIN" > ${OUTPUT}/job_exec_${n}.txt	
					
					tail -2 ${OUTPUT}/job_exec_${n}.txt | head -1 > ${OUTPUT}/last_job_exec_${n}.txt	
					#cat ${OUTPUT}/last_job_exec_${n}.txt	
					fromdate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f9`
					fromtime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f10`
					todate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f12`
					totime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f13`
					status=`cat ${OUTPUT}/last_job_exec_${n}.txt |  cut -d" " -f17`
					
					echo "Last execution status for backup ${n}: ${status}"
					echo "Execution Start Time: $fromdate $fromtime "
					echo "Execution End Time: $todate $totime "
					echo ""
					
					echo "Last execution status for backup ${n}: ${status}" >> $master_log_prepatch
					echo "Execution Start Time: $fromdate $fromtime " >> $master_log_prepatch
					echo "Execution End Time: $todate $totime " >> $master_log_prepatch
					echo "" >> $master_log_prepatch
					echo "##############################################################################################################################################" >> $master_log_prepatch
					
					done
					echo ""
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch

			cat $master_log_prepatch
					
			echo ""
			echo ""
			echo "Redirecting to the options screen.."
			echo ""
			optionsScreen


			
		elif [ $usrselec -eq 3 ]; then
			echo ""
			echo "Option $usrselec selected, postptach step for Middleware ohs location"
			echo ""

			read -p "DBA conducting the Maintenance (enter your sherwin id) " EMPID
			read -p "Enter the Change Log Request ID : " CHNGID
			echo "DBA conducting this step is "$EMPID
			echo "Change Log request ID is "$CHNGID


			if [[ "$CHNGID" = "" ]]; then
				echo "No change ID input for "$ENV
				
				export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_MWHOME_ohs_POSTPATCH_${EMPID}_${Day}.html
				export master_log_postpatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_ohs_POSTPATCH_${EMPID}_${Day}.log
			else
				echo "Input file $INPUT_FILE sourced in for "$ENV
				echo "Change Log Request ID is "$CHNGID
				
				export summary_report_postpatch=${PPLOGDIR}/${ENV}_PATCH_report_MWHOME_ohs_POSTPATCH_${CHNGID}_${Day}.html
				export master_log_postpatch=${PPLOGDIR}/${ENV}_PATCH_Master_Log_MWHOME_ohs_POSTPATCH_${CHNGID}_${Day}.log
			fi
			echo "----------"
			echo "<br>" >> $summary_report_postpatch
			echo "<table border="1">" >> $summary_report_postpatch  
			echo "<tr>" >> $summary_report_postpatch  
			echo "     <td><b>DBA</b></td>" >> $summary_report_postpatch  
			echo "	   <td>$EMPID</td>" >> $summary_report_postpatch
			echo "</tr>" >> $summary_report_postpatch
			echo "<tr>" >> $summary_report_postpatch  
			echo "     <td><b>Step Performed</b></td>" >> $summary_report_postpatch  
			echo "	   <td>MWHOME ohs Postpatch Steps</td>" >> $summary_report_postpatch    
			echo "</tr>" >> $summary_report_postpatch  
			echo "<tr>" >> $summary_report_postpatch  
			echo "     <td><b>Date</b></td>" >> $summary_report_postpatch  
			echo "	   <td>`date`</td>" >> $summary_report_postpatch  
			echo "</tr>" >> $summary_report_postpatch
			echo "<tr>" >> $summary_report_postpatch
			echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_postpatch
			echo "	   <td>$CHNGID</td>" >> $summary_report_postpatch
			echo "</tr>" >> $summary_report_postpatch
			echo "<tr>" >> $summary_report_postpatch
			echo "     <td><b>Method</b></td>" >> $summary_report_postpatch
			echo "	   <td>Manual</td>" >> $summary_report_postpatch
			echo "</tr>" >> $summary_report_postpatch
			echo "</table>" >> $summary_report_postpatch  
			echo "<br>" >> $summary_report_postpatch 
			echo "<br>" >> $summary_report_postpatch 

			echo "#################################################################################################################################################" > $master_log_postpatch
			echo "DBA: $EMPID" >> $master_log_postpatch
			echo "Step performed: MWHOME ohs Postpatch Steps" >> $master_log_postpatch
			echo "Date: `date`" >> $master_log_postpatch
			echo "Change Log Request ID: $CHNGID" >> $master_log_postpatch
			echo "Method: Manual" >> $master_log_postpatch
			echo "#################################################################################################################################################" >> $master_log_postpatch


			#Post patching step 1: lsinventory command
			echo "####################################################################################################"
			echo "MWHOME ohs Post patching step 1: lsinventory command"
			echo "####################################################################################################"echo ""
			echo ""
			cd $MIDDLEWARE_HOME/ohs/OPatch/
			export TodayDate=`date +%d_%m_%Y`
			export lsinvDate1=`date +%Y-%m-%d_%I-%M`
			export POSTPATCHDIR=${BACKUPDIR}/PREPOST/POSTPATCH_MWHOME_ohs_${ENV}_${CHNGID}_${TodayDate}
			./opatch lsinventory -oh $MIDDLEWARE_HOME/ohs -jdk $MIDDLEWARE_HOME/jdk160_35 -invPtrLoc $MIDDLEWARE_HOME/ohs/oraInst.loc
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Executing lsinventory command for $ENV"
					echo "<br>" >> $summary_report_postpatch
					echo "<b>MWHOME ohs Post Patching</b>" >> $summary_report_postpatch  
					echo "<table border="1">" >> $summary_report_postpatch  
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <th>Timestamp</th>" >> $summary_report_postpatch 
					echo "    <th>Step</th>" >> $summary_report_postpatch
					echo "    <th>Status</th>" >> $summary_report_postpatch 
					echo "    <th>Details</th>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 		
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>Fulldate</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME ohs Post patching step 1: Execute MWHOME ohs lsinventory command</td>" >> $summary_report_postpatch
					echo "    <td>Failure</td>" >> $summary_report_postpatch 
					echo "    <td></td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "" >> $master_log_postpatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
					echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_postpatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
					echo "`date`|MWHOME ohs  Post patching step 1: Execute MWHOME ohs lsinventory command |Failure      | " >> $master_log_postpatch
					cat $master_log_postpatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Executing lsinventory command for $ENV"
				 cd $MIDDLEWARE_HOME/ohs/cfgtoollogs/opatch/lsinv/
				 filename=`ls | grep ${lsinvDate1}`
				 export POSTPATCHDIR=${BACKUPDIR}/PREPOST/POSTPATCH_MWHOME_ohs_${ENV}_${CHNGID}_${TodayDate}
				 mkdir ${POSTPATCHDIR}
				 cp $filename ${POSTPATCHDIR}
				 echo "$DateTime: Copied lsinventory file to ${POSTPATCHDIR}"
				 ls -ltr ${POSTPATCHDIR}
					echo "<br>" >> $summary_report_postpatch
					echo "<b>MWHOME ohs Post Patching</b>" >> $summary_report_postpatch  
					echo "<table border="1">" >> $summary_report_postpatch  
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <th>Timestamp</th>" >> $summary_report_postpatch 
					echo "    <th>Step</th>" >> $summary_report_postpatch
					echo "    <th>Status</th>" >> $summary_report_postpatch 
					echo "    <th>Details</th>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME ohs Post patching step 1: Execute lsinventory command</td>" >> $summary_report_postpatch
					echo "    <td>Success</td>" >> $summary_report_postpatch 
					echo "    <td>Copied lsinventory file $filename to ${POSTPATCHDIR}</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
					echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_postpatch
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
					echo "`date`|MWHOME ohs Post patching step 1: Execute lsinventory command |Success      |Copied lsinventory file $filename to ${POSTPATCHDIR} " >> $master_log_postpatch
			 fi

			echo ""
			echo ""


			 #Post patching step 2: EPM registry command
			 echo "####################################################################################################"
			 echo "MWHOME ohs Post patching step 2: EPM registry command"
			 echo "####################################################################################################"
			 echo ""
			echo ""
			 cd $EPM_ORACLE_INSTANCE/bin
			 echo "./epmsys_registry.sh"
			./epmsys_registry.sh
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Post patching step 2: EPM registry command for $ENV"
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME ohs Post patching step 2: Generate EPM registry report</td>" >> $summary_report_postpatch
					echo "    <td>Failure</td>" >> $summary_report_postpatch 
					echo "    <td></td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch
					echo "`date`|Post patching step 2: Generate EPM registry report |Failure      | " >> $master_log_postpatch
					cat $master_log_postpatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Post patching step 2: EPM registry command for $ENV"
				 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
				 cp registry.html ${POSTPATCHDIR}
				 echo "$DateTime: Copied registry.html file to ${POSTPATCHDIR}"
				 ls -ltr ${POSTPATCHDIR}
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>Post patching step 2: Generate EPM registry report</td>" >> $summary_report_postpatch
					echo "    <td>Success</td>" >> $summary_report_postpatch 
					echo "    <td>Copied registry.html file to ${POSTPATCHDIR}</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "`date`|MWHOME ohs Post patching step 2: Generate EPM registry report |Success      |Copied registry.html file to ${POSTPATCHDIR} " >> $master_log_postpatch
			 fi
			echo ""
			echo ""

			#Post patching step 3: Generate deployment report
			 echo "####################################################################################################"
			 echo "MWHOME ohs Post patching step 3: Generate EPM deployment report"
			 echo "####################################################################################################"
			 echo ""
			echo ""
			cd $EPM_ORACLE_INSTANCE/bin
			echo "./epmsys_registry.sh report deployment"
			export deplreptDate1=`date +%Y%m%d_%H`
			./epmsys_registry.sh report deployment
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Generating EPM deployment report for $ENV"
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME ohs Post patching step 3: Generate EPM Deployment report</td>" >> $summary_report_postpatch
					echo "    <td>Failure</td>" >> $summary_report_postpatch 
					echo "    <td></td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "`date`|MWHOME ohs Post patching step 3: Generate EPM Deployment report |Failure      | " >> $master_log_postpatch
					cat $master_log_postpatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Generating EPM deployment report for $ENV"
				 cd $EPM_ORACLE_INSTANCE/diagnostics/reports
				 filename=`ls -lrt |awk '{print $9}' |tail -1`
				 echo ${deplreptDate1}
				 cp $filename ${POSTPATCHDIR}
				 echo "$DateTime: Copied EPM deployment reportfile to ${POSTPATCHDIR}"
				 ls -ltr ${POSTPATCHDIR}
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME ohs Post patching step 3: Generate EPM Deployment report</td>" >> $summary_report_postpatch
					echo "    <td>Success</td>" >> $summary_report_postpatch 
					echo "    <td>Copied $filename to ${POSTPATCHDIR}</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "`date`|MWHOME ohs Post patching step 3: Generate EPM Deployment report |Success      |Copied $filename to ${POSTPATCHDIR} " >> $master_log_postpatch
			 fi
			 
			 
			 #Post patching step 4: Backup of oraInventory
			 echo "####################################################################################################"
			 echo "MWHOME ohs Post patching step 4: Backup of oraInventory"
			 echo "####################################################################################################"
			 echo ""
			 echo ""
			 INVLOC=`grep inventory_loc $MIDDLEWARE_HOME/ohs/oraInst.loc | cut -d"=" -f2`
			 echo "Oracle Inventory location: $INVLOC"
			tar -cvf ${BACKUPDIR}/INV_BACKUPS/${Day1}_${ENV}_POSTPATCH_MWHOME_ohs_OraInventory.tar ${INVLOC}
			 VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Backup of oraInventory for $ENV"
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME ohs Post patching step 4: Backup of oraInventory</td>" >> $summary_report_postpatch
					echo "    <td>Failure</td>" >> $summary_report_postpatch 
					echo "    <td></td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "" >> $master_log_postpatch
					echo "`date`|MWHOME ohs Post patching step 4: Backup of oraInventory |Failure      | " >> $master_log_postpatch
					cat $master_log_postpatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Backup of oraInventory for $ENV"
				 ls -ltr ${BACKUPDIR}/INV_BACKUPS/
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME ohs Post patching step 4: Backup of oraInventory</td>" >> $summary_report_postpatch
					echo "    <td>Success</td>" >> $summary_report_postpatch 
					echo "    <td>Copied ${Day1}_${ENV}_POSTPATCH_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "`date`|MWHOME ohs Post patching step 4: Backup of oraInventory |Success      |Copied ${Day1}_${ENV}_POSTPATCH_ohs_OraInventory.tar to ${BACKUPDIR}/INV_BACKUPS/ " >> $master_log_postpatch
			 fi
			 
			 #Post patching step 5: Critial file copy
			 echo "####################################################################################################"
			  echo "MWHOME ohs Post patching step 5: Critial file copy"
			 echo "####################################################################################################"
			 echo ""
			 echo ""
			 cd ${SCRIPTDIR}/
			 export Day33=`date +%Y-%m-%d_%H_%M`
			./Critical_File_copy.sh
			VRET=$?
			echo $VRET
			 if [ $VRET -ne 0 ];then
				  echo "$DateTime: ERROR - Executing Critial file copy for $ENV"
						echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME ohs Post patching step 5: Critial file copy</td>" >> $summary_report_postpatch
					echo "    <td>Failure</td>" >> $summary_report_postpatch 
					echo "    <td></td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "`date`|MWHOME ohs Post patching step 5: Critial file copy |Failure      | " >> $master_log_postpatch
					cat $master_log_postpatch
					exit 1;
			 else
				 echo "$DateTime: SUCCESS - Executing Critial file copy for $ENV"
				 crit_dir=`ls ${BACKUPDIR}/Critical_File_Copy | grep ${Day33}`
				 export postpatch_crit_dir=${BACKUPDIR}/Critical_File_Copy/${ENV}_${CHNGID}_POSTPATCH_OHS_${Day33}
				 echo "Critical files copied to directory $crit_dir under ${BACKUPDIR}/Critical_File_Copy"
				 mv ${BACKUPDIR}/Critical_File_Copy/${Day33} ${postpatch_crit_dir}
				 echo "Listing files in ${postpatch_crit_dir}"
				 ls -ltr ${postpatch_crit_dir}
					echo "<tr>" >> $summary_report_postpatch  
					echo "    <td>`date`</td>" >> $summary_report_postpatch 
					echo "    <td>MWHOME ohs Post patching step 5: Critial file copy</td>" >> $summary_report_postpatch
					echo "    <td>Success</td>" >> $summary_report_postpatch 
					echo "    <td>Copied ${ENV}_${CHNGID}_POSTPATCH_${Day33} to ${BACKUPDIR}/Critical_File_Copy</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "</table>" >> $summary_report_postpatch 
					echo "<br>" >> $summary_report_postpatch 
					echo "<br>" >> $summary_report_postpatch 
					echo "`date`|MWHOME ohs Post patching step 5: Critial file copy |Success      |Copied ${ENV}_${CHNGID}_POSTPATCH_${Day33} to ${BACKUPDIR}/Critical_File_Copy " >> $master_log_postpatch
			 fi

			echo ""
			echo ""
			echo "Post patching differences check"
			cd ${BACKUPDIR}/Critical_File_Copy
			echo ""
			export prepatch_crit_dir1=`ls |grep ${ENV}_${CHNGID}_PREPATCH_OHS`
			export postpatch_crit_dir1=`ls |grep ${ENV}_${CHNGID}_POSTPATCH_OHS`
			echo "Checking differences between ${prepatch_crit_dir1} and ${postpatch_crit_dir1}"

			export fold_diff_tmp=${OUTPUT}/${ENV}_PRE_POST_DIR_DIFF_tmp.txt
			export fold_diff=${OUTPUT}/${ENV}_PRE_POST_DIR_DIFF.txt


			diff --brief -Nr ${prepatch_crit_dir1} ${postpatch_crit_dir1} > ${fold_diff_tmp}

			cat ${fold_diff_tmp} | awk '{print $2,$4}' | tr " " "#" >  ${fold_diff}

			if [ -s ${fold_diff} ]; then
				echo "PREPATCH & POST PATCH has differences"
				echo ""
				echo ""
				cat ${fold_diff_tmp}
				for i in `cat ${fold_diff}`
				do 
					filediff1=`echo "$i" | cut -d"#" -f1 `
					filediff2=`echo "$i" | cut -d"#" -f2 `
					ex_file=`basename $filediff1`
					
				
					diff $filediff1 $filediff2 >  ${OUTPUT}/${ex_file}_diff.txt
					
					cat ${OUTPUT}/${ex_file}_diff.txt
						
					echo "<br>" >> $summary_report_backup
					echo "<b>Differences found in Critical files post patching </b>" >> $summary_report_postpatch
					echo "<br>" >> $summary_report_postpatch 		
					echo "<table border="1">" >> $summary_report_postpatch 
					echo "<tr>" >> $summary_report_postpatch 
					echo "<th><b>File with differences</b></th>" >> $summary_report_postpatch 
					echo "<th><b>Differences found (Prepatching ---> Postpatching)</b></th>" >> $summary_report_postpatch  
					echo "</tr>" >> $summary_report_postpatch 
					echo "<tr>" >> $summary_report_postpatch 
					echo "<td>`echo "$ex_file"`</td>" >> $summary_report_postpatch 
					echo "<td>`cat ${OUTPUT}/${ex_file}_diff.txt`</td>" >> $summary_report_postpatch 
					echo "</tr>" >> $summary_report_postpatch 
					echo "</table>" >> $summary_report_postpatch 
					echo "<br>" >> $summary_report_postpatch 
					
					echo "" >> $master_log_postpatch
					echo "###############################################################################################################################################" >> $master_log_postpatch
					echo " Differences found for Critical files (Prepatch & Post patch)" >> $master_log_postpatch
					echo "###############################################################################################################################################" >> $master_log_postpatch
					echo "`date`  |   Filename: $ex_file " >> $master_log_postpatch
					echo "" >> $master_log_postpatch
					echo "Differences: " >> $master_log_postpatch
					echo "`cat ${OUTPUT}/${ex_file}_diff.txt`" >> $master_log_postpatch
					
						
				done
				
				echo "Correct all the differences and remove flag file /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt manually to resume Critical_File_Copy script"
				echo ""
				echo "###############################################################################################################################################" >> $master_log_postpatch
				echo "Correct all the differences and remove flag file /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt manually to resume Critical_File_Copy script" >> $master_log_postpatch
				echo "###############################################################################################################################################" >> $master_log_postpatch
				
				echo "<b>Correct all the differences and remove flag file /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt manually to resume Critical_File_Copy script</b>" >> $summary_report_postpatch
				echo "<br>" >> $summary_report_postpatch
				
				cat $master_log_postpatch
				
				echo ""
				echo ""
			else
				echo "No differences found in PREPATCH & POST PATCH directories"
				echo "<b>No differences found in Critical files post patching </b>" >> $summary_report_postpatch
				echo "" >> $master_log_postpatch
					echo "###############################################################################################################################################" >> $master_log_postpatch
					echo " No differences found for Critical files (Prepatch & Post patch)" >> $master_log_postpatch
					echo "###############################################################################################################################################" >> $master_log_postpatch
					echo "`date`  |   No difference found" >> $master_log_postpatch
				
				###Remove flag file to resume Critical_File_Copy script ###
				rm /hyp_util/logs/Critical_File_preserve/${ENV}/Maintenanceepm.txt
				
				echo "<br>" >> $summary_report_postpatch
				echo "<b>Removed flag file to resume scheduled Critical_File_Copy script</b>" >> $summary_report_postpatch
				echo "<br>" >> $summary_report_postpatch
				echo "###############################################################################################################################################" >> $master_log_postpatch
				echo "Removed flag file to resume scheduled Critical_File_Copy script" >> $master_log_postpatch
					
				cat $master_log_postpatch
			fi

			export summary_report=${PPLOGDIR}/${ENV}_PATCH_Summary_report_${CHNGID}_${Day}.html
			export master_log=${PPLOGDIR}/${ENV}_PATCH_Master_Log_${CHNGID}_${Day}.log

			echo "<html>" > $summary_report
			echo "<h2>$ENV: PATCH SUMMARY REPORT</h2>" >> $summary_report  

			ls -ltr ${PPLOGDIR}/${ENV}_PATCH_report_*${CHNGID}* | awk '{print $9}' > ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt

			if [ -s ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt ]; then
				echo " "
				echo " "
				
				echo "Patch summary report: $summary_report"
				for i in `cat ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt`
				do 
				#filnm=`echo $i | awk '{print $9}'`
				cat $i >> $summary_report
				done
			else
				echo " "
				echo " "
				echo "No other activities performed for this change id"
			fi

			echo "$ENV: PATCH LOG" > $master_log
			 echo "" >> $master_log 

			ls -ltr ${PPLOGDIR}/${ENV}_PATCH_Master_Log_*${CHNGID}* | awk '{print $9}' > ${PPLOGDIR}/patch_step_logs_${CHNGID}_${ENV}.txts

			if [ -s ${PPLOGDIR}/patch_step_logs_${CHNGID}_${ENV}.txt ]; then
				echo " "
				echo " "
				echo "Patch Master Log: $master_log"
				for i in `cat ${PPLOGDIR}/patch_step_logs_${ENV}.txt`
				do 
				#filnme=`echo $i | awk '{print $9}'`
				cat $i >> $master_log
				done
			else
				echo " "
				echo " "
				echo "No other activities performed for this change id"
			fi

			echo ""
			echo "Redirecting to the options screen.."
			echo ""
			optionsScreen
			echo ""
			echo ""

		elif [ $usrselec -eq 0 ]; then
			echo "$usrselec entered. Exiting script.."
			exit 0;
		
		else 
		
			echo "Invalid option chosen. Exiting script....."
			exit 1;
		fi	


}


function DBbuildPREREQ() {

echo ""
echo ""


	cat ${CTRLLOC}/DB_prereq_instructions.txt

	echo ""
	echo ""
	DateTimeN=`date +%d%m%y_%H%M%S`
	# Listing out all the Prepatching Activities in comments
	echo ""
	date
	read -p "If the above steps have already been performed, press 1 to Continue, 0 to Exit - " PROG
	if [ $PROG = '0' ]; then
		echo "----------"
		echo "Selection = ${PROG}, exiting script..."
		DBoptionsScreen
	elif [ $PROG = '1' ]; then 	
		echo "Selection = ${PROG}"
		echo "----------"
		read -p "Is this a DB bundle patch (Enter y for yes, n for no, x to exit) - " BUNDLPTCH
		if [ $BUNDLPTCH = "y" ]; then
			read -p "Please enter the DB Bundle patch number - " BUNDLPATCHNUM
			echo $BUNDLPATCHNUM > ${OUTPUT}/${ENV}_DB_Bundle_${DateTimeN}.txt
			read -p "Please enter the DB patch number present under the bundle patch - " BUNDLPATCH_DB
			echo $BUNDLPATCH_DB >> ${OUTPUT}/${ENV}_DB_Bundle_${DateTimeN}.txt
			read -p "Please enter the OCW patch number present under the bundle patch - " BUNDLPATCH_OCW
			echo $BUNDLPATCH_OCW >> ${OUTPUT}/${ENV}_DB_Bundle_${DateTimeN}.txt
			read -p "Please enter the server location where the Bundle DB patch are downloaded to - " BUNDLPATCHLOC
			echo $BUNDLPATCHLOC >> ${OUTPUT}/${ENV}_DB_Bundle_${DateTimeN}.txt
		elif [ $BUNDLPTCH = 'n' ]; then	
			read -p "Please enter the patch numbers (if more than one patch, please seperate them by comma (,)  ) - " PATCHNUM
			echo $PATCHNUM > ${OUTPUT}/${ENV}_DB_Indiv_${DateTimeN}.txt
			read -p "Please enter the server location where the patches are downloaded to - " PATCHLOC
			echo $PATCHLOC >> ${OUTPUT}/${ENV}_DB_Indiv_${DateTimeN}.txt
		elif [ $BUNDLPTCH = 'x' ]; then	
			echo "User entered: x"
			echo "Exiting script"
			exit 0;
		else
			echo "ERROR: Invalid option selected"
			echo "Exiting script"
			exit 1;
		fi	
	else
		echo "ERROR: Invalid option selected"
		echo "Exiting script"
		exit 1;
	fi
	
	
	read -p "DBA conducting this step (enter your sherwin id): " EMPID
	read -p "Enter the Change Log Request ID (if change log entry is not created, hit Enter): " CHNGID
	echo "DBA conducting this step is "$EMPID
	echo "Change Log request ID is "$CHNGID
	
	
	if [[ "x${CHNGID}" = "x" ]]; then
		echo "No change ID input for "$ENV
		
		export summary_report_prereq=${PPLOGDIR}/${ENV}_DB_PATCH_report_PREREQ_${EMPID}_${Day}.html
		export master_log_prereq=${PPLOGDIR}/${ENV}_DB_PATCH_Master_Log_PREREQ_${EMPID}_${Day}.log
	else
		echo "Input file $INPUT_FILE sourced in for "$ENV
		echo "Change Log Request ID is "$CHNGID
		
		export summary_report_prereq=${PPLOGDIR}/${ENV}_DB_PATCH_report_PREREQ_${CHNGID}_${Day}.html
		export master_log_prereq=${PPLOGDIR}/${ENV}_DB_PATCH_Master_Log_PREREQ_${CHNGID}_${Day}.log
	fi

	
	echo "----------"
	echo "<br>" >> $summary_report_prereq
	echo "<table border="1">" >> $summary_report_prereq  
	echo "<tr>" >> $summary_report_prereq  
	echo "     <td><b>DBA</b></td>" >> $summary_report_prereq  
	echo "	   <td>$EMPID</td>" >> $summary_report_prereq  
	echo "</tr>" >> $summary_report_prereq  
	echo "<tr>" >> $summary_report_prereq 
	echo "     <td><b>Step performed</b></td>" >> $summary_report_prereq  
	echo "	   <td>DB OPatch Prerequisite Check</td>" >> $summary_report_prereq  
	echo "</tr>" >> $summary_report_prereq  
	echo "<tr>" >> $summary_report_prereq  
	echo "     <td><b>Date</b></td>" >> $summary_report_prereq  
	echo "	   <td>`date`</td>" >> $summary_report_prereq  
	echo "</tr>" >> $summary_report_prereq 
	echo "<tr>" >> $summary_report_prereq  
	echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_prereq  
	echo "	   <td>$CHNGID</td>" >> $summary_report_prereq	
	echo "</tr>" >> $summary_report_prereq 
	echo "<tr>" >> $summary_report_prereq  
	echo "     <td><b>Method</b></td>" >> $summary_report_prereq  
	echo "	   <td>Manual</td>" >> $summary_report_prereq  
	echo "</tr>" >> $summary_report_prereq 	
	echo "</table>" >> $summary_report_prereq  
	echo "<br>" >> $summary_report_prereq 
	echo "<br>" >> $summary_report_prereq 
	
	echo "#################################################################################################################################################" >> $master_log_prereq
	echo "DBA: $EMPID" >> $master_log_prereq
	echo "Step performed: DB OPatch Prerequisite Check" >> $master_log_prereq
	echo "Date: `date`" >> $master_log_prereq
	echo "Change Log Request ID: $CHNGID" >> $master_log_prereq
	echo "Method: Manual" >> $master_log_prereq
		
	
	
	export REFDateTime=`date +%d%m%y_%H%M%S`
	cd $ORACLE_HOME/OPatch/
	export PREREQ_DIR=${OUTPUT}/PREREQ_${REFDateTime}
	export USR_PREREQ_INPUT=${OUTPUT}/${ENV}_PREREQ_${REFDateTime}.cfg
	mkdir ${PREREQ_DIR}
	
	echo "Executing lsinventory command..."
	cd $ORACLE_HOME/OPatch/
	./opatch lsinventory > ${PREREQ_DIR}/lsinventory.txt

	if [[ -s ${OUTPUT}/${ENV}_DB_Bundle_${DateTimeN}.txt ]]; then
		
		echo "DBA=$EMPID" > ${USR_PREREQ_INPUT}
		echo "PATCHNUM=$BUNDLPATCHNUM" >> ${OUTPUT}/${ENV}_PREREQ_${REFDateTime}.cfg
		echo "PATCHLOC=$BUNDLPATCHLOC" >> ${OUTPUT}/${ENV}_PREREQ_${REFDateTime}.cfg
		echo "----------"

		echo "<br>" >> $summary_report_prereq
		echo "<b>OPatch Prequisite Check Activity </b>" >> $summary_report_prereq  
		echo "<table border="1">" >> $summary_report_prereq  
		echo "<tr>" >> $summary_report_prereq  
		echo "    <td><b>Bundle Patch Number(s)</b></th>" >> $summary_report_prereq 
		echo "    <td>$BUNDLPATCHNUM</th>" >> $summary_report_prereq
		echo "</tr>" >> $summary_report_prereq  
		echo "<tr>" >> $summary_report_prereq  
		echo "    <td><b>Bundle Patch Location</b></td>" >> $summary_report_prereq 
		echo "    <td>$BUNDLPATCHLOC</td>" >> $summary_report_prereq 
		echo "</tr>" >> $summary_report_prereq 	
		echo "</table>" >> $summary_report_prereq
		echo "<br>" >> $summary_report_prereq 	
		
		echo "OPatch Prequisite Check Activity " >> $master_log_prereq
		echo "   Bundle Patch Number(s): $BUNDLPATCHNUM" >> $master_log_prereq
		echo "   Bundle Patch Location: $BUNDLPATCHLOC" >> $master_log_prereq
		echo "#################################################################################################################################################" >> $master_log_prereq
		
	
			echo "Bundle patch to be checked"
			echo ${BUNDLPATCHNUM}
			echo "TASK 1: Checking if the patch file ${BUNDLPATCHNUM} is in the given patch location $PATCHLOC"
			fndPatch=`find ${BUNDLPATCHLOC} -maxdepth 1 -name "*${BUNDLPATCHNUM}*.zip"`
			find ${BUNDLPATCHLOC} -name "*${PBUNDLATCHNUM}*.zip"
			ret=$?
			if [ $ret -eq 0 ]; then
				echo "Patch file $fndPatch present, unzipping it...."
				echo "unzip -o $fndPatch"
				cd ${BUNDLPATCHLOC}
				#cd $ORACLE_HOME/OPatch/
				unzip -o $fndPatch
				echo ""
									
				tmp_script=${PREREQ_DIR}/opatch_prereq_tmp_${BUNDLPATCHNUM}_${BUNDLPATCH_DB}.sh
				new_script=${PREREQ_DIR}/opatch_prereq_${BUNDLPATCHNUM}_${BUNDLPATCH_DB}.sh
		
				echo "TASK 2: Creating & executing Prereq script for DB patch ${BUNDLPATCH_DB} under Bundle DB patch ${BUNDLPATCHNUM}"
				echo "<br>" >> $summary_report_prereq
				echo "<b>DB OPatch Prequisite Check for DB patch ${BUNDLPATCH_DB} under Bundle DB patch ${BUNDLDBPATCH} </b>" >> $summary_report_prereq  
				echo "<table border="1">" >> $summary_report_prereq  
				echo "<tr>" >> $summary_report_prereq  
				echo "    <th>Timestamp</th>" >> $summary_report_prereq 
				echo "    <th>Prereq Check</th>" >> $summary_report_prereq
				echo "    <th>Prereq Patch Number</th>" >> $summary_report_prereq
				echo "    <th>Status</th>" >> $summary_report_prereq 
				echo "    <th>Details</th>" >> $summary_report_prereq 
				echo "</tr>" >> $summary_report_prereq 		
				
				echo "Checking the lsinventory to see if the DB patch is applied on the environment"
				grep -wi ${BUNDLPATCH_DB} ${PREREQ_DIR}/lsinventory.txt > ${PREREQ_DIR}/lsinventory_${BUNDLPATCH_DB}.txt
				tret=$?
				if [[ $tret -eq 0 ]];then
					echo "DB patch $BUNDLPATCH_DB present in lsinventory and already applied in this environment"
					echo ""
					cat ${PREREQ_DIR}/lsinventory_${BUNDLPATCH_DB}.txt
					mv ${PREREQ_DIR}/lsinventory_${BUNDLPATCH_DB}.txt ${PREREQ_DIR}/lsinventory_${BUNDLPATCH_DB}_present.txt
				
					echo "DB OPatch Prequisite Check for patch ${BUNDLPATCH_DB} " >> $master_log_prereq
					echo "Timestamp                   |Prereq Check     | Patch number	|Status       |Details  " >> $master_log_prereq
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
					echo "<tr>" >> $summary_report_prereq  
					echo "    <td>`date`</td>" >> $summary_report_prereq 
					echo "    <td>Check the DB patch in lsinventory</td>" >> $summary_report_prereq
					echo "    <td>${BUNDLPATCH_DB}</td>" >> $summary_report_prereq 
					echo "    <td>Failure</td>" >> $summary_report_prereq 
					echo "    <td>The DB patch is already applied in the environment. Please verify</td>" >> $summary_report_prereq 
					echo "</tr>" >> $summary_report_prereq 
					echo "</table>" >> $summary_report_prereq
					echo ""
					echo " `date`|Check the DB patch in lsinventory | ${BUNDLPATCH_DB}	|Failure     | The patch is already applied in the environment. Please verify" >> $master_log_prereq 
					echo "" >> $master_log_prereq 
					cat $master_log_prereq
					echo "Please verify the patch number, exiting the script now.."
					exit 1;
				else
					echo "$BUNDLPATCH_DB not present in lsinventory, proceeding further..."
					echo "Preparing Prerequisite checks against the patch, this may take a while..."
					echo ""
				fi
		
							
				cp ${CTRLLOC}/db_opatch_prereq.sh $tmp_script
				export PATCHLOC=${BUNDLPATCHLOC}
				export patchNN=${BUNDLPATCHLOC}/${BUNDLPATCHNUM}/${BUNDLPATCH_DB}
				eval "echo \"`cat $tmp_script`\"" > $new_script
				chmod +x $new_script
				cd ${PREREQ_DIR}
				. $new_script > ${new_script}.log
				ret=$?
				if [ $ret -eq 0 ]; then
					echo "PREREQ check script executed"
					echo ""
				else
					echo "PREREQ check script execution failed"
					echo ""
					echo "PREREQ check script execution failed" >> $master_log_prereq
					echo "" >> $master_log_prereq 
					cat $master_log_prereq
					exit 1;
				fi
				
				grep Prereq ${new_script}.log > ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_DB}.log
				prereq_stat_SysSpace=`grep -wi checkSystemSpace ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_DB}.log | cut -d" " -f3`
				prereq_stat_conDetail=`grep -wi checkConflictAmongPatchesWithDetail ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_DB}.log | cut -d" " -f3`
				prereq_stat_InputValues=`grep -wi checkForInputValues ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_DB}.log | cut -d" " -f3`
				prereq_stat_conOHDetail=`grep -wi checkConflictAgainstOHWithDetail ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_DB}.log | cut -d" " -f3`
				
				grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_DB}.log > ${PREREQ_DIR}/PREREQ_status_appDepend_${BUNDLPATCH_DB}.log
				grep -wi checkApplicableProduct ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_DB}.log | tr " " "#" > ${PREREQ_DIR}/PREREQ_status_appliProduct_${BUNDLPATCH_DB}.log
				grep -wi checkComponents ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_DB}.log | tr " " "#" > ${PREREQ_DIR}/PREREQ_status_component_${BUNDLPATCH_DB}.log
				grep -wi checkApplicable ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_DB}.log | tr " " "#" > ${PREREQ_DIR}/PREREQ_status_applica_${BUNDLPATCH_DB}.log
				
				export prereq_status_tidy=${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_DB}_tidy.log
				
				echo "PREREQ:checkSystemSpace::$prereq_stat_SysSpace" > ${prereq_status_tidy}
				echo "PREREQ:checkConflictAmongPatchesWithDetail::$prereq_stat_conDetail" >> ${prereq_status_tidy}
				echo "PREREQ:checkForInputValues::$prereq_stat_InputValues" >> ${prereq_status_tidy}
				
				
				##Treatment for prereqs with different format##
				prereq_stat_appDepend=`grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_appDepend_${BUNDLPATCH_DB}.log | cut -d" " -f6`
				prereq_stat_appDepend_patchnum=`grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_appDepend_${BUNDLPATCH_DB}.log | cut -d" " -f5`
				
				echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend_patchnum:$prereq_stat_appDepend" >> ${prereq_status_tidy}
				
				for x in `cat ${PREREQ_DIR}/PREREQ_status_appliProduct_${BUNDLPATCH_DB}.log`
				do
				prereq_stat_appliProduct=`echo ${x} | cut -d"#" -f6`
				prereq_stat_appliProduct_patchnum=`echo ${x} | cut -d"#" -f5`
				echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct_patchnum:$prereq_stat_appliProduct" >> ${prereq_status_tidy}
				done
				
				for y in `cat ${PREREQ_DIR}/PREREQ_status_component_${BUNDLPATCH_DB}.log`
				do
				prereq_stat_component=`echo ${y} | cut -d"#" -f6`
				prereq_stat_component_patchnum=`echo ${y} | cut -d"#" -f5`
				echo "PREREQ:checkComponents:$prereq_stat_component_patchnum:$prereq_stat_component" >> ${prereq_status_tidy}
				done
				
				for z in `cat ${PREREQ_DIR}/PREREQ_status_applica_${BUNDLPATCH_DB}.log`
				do
				
				prereq_stat_applica=`echo ${z} | cut -d"#" -f6`
				prereq_stat_applica_patchnum=`echo ${z} | cut -d"#" -f5`
				echo "PREREQ:checkApplicable:$prereq_stat_applica_patchnum:$prereq_stat_applica" >> ${prereq_status_tidy}
				done
				
				echo "PREREQ:checkConflictAgainstOHWithDetail::$prereq_stat_conOHDetail" >> ${prereq_status_tidy}
						
				for n in `cat ${prereq_status_tidy}`
				do
				prereq_chkk=`echo $n |cut -d":" -f2`
				prereq_chkk_patchnum=`echo $n |cut -d":" -f3`
				prereq_chkk_stat=`echo $n |cut -d":" -f4`
				
				
					echo "<tr>" >> $summary_report_prereq  
					echo "    <td>`date`</td>" >> $summary_report_prereq 
					echo "    <td>${prereq_chkk}</td>" >> $summary_report_prereq
					echo "    <td>${prereq_chkk_patchnum}</td>" >> $summary_report_prereq
					echo "    <td>${prereq_chkk_stat}</td>" >> $summary_report_prereq 
					echo "    <td></td>" >> $summary_report_prereq 
					echo "</tr>" >> $summary_report_prereq
					
					echo "`date`|${prereq_chkk}| ${prereq_chkk_patchnum} | ${prereq_chkk_stat} | " >> $master_log_prereq 
										
				done
				
				grep -wi "failed" ${prereq_status_tidy}
				return=$?
				if [ $return -eq 0 ]; then
					echo "PREREQ checks have failed"
					echo " " >> $master_log_prereq 
					echo "PREREQ checks have failed" >> $master_log_prereq 
					echo "Check ${new_script}.log for details" >> $master_log_prereq
					echo "#################################################################################################"
					#cat $master_log_prereq 
					echo "#################################################################################################"
					
				else
					echo "PREREQ checks have passed"
					echo " " >> $master_log_prereq 
					echo "PREREQ checks have passed" >> $master_log_prereq 
					echo "Check ${new_script}.log for details" >> $master_log_prereq
				fi	
				
			
				echo ""
				echo "<table border="1">" >> $summary_report_prereq  
				echo "PREREQ Checks  execution successful for DB patch under the Bundle patch" >> $master_log_prereq
				echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
			
				tmp_script=${PREREQ_DIR}/opatch_prereq_tmp_${BUNDLPATCHNUM}_${BUNDLPATCH_OCW}.sh
				new_script=${PREREQ_DIR}/opatch_prereq_${BUNDLPATCHNUM}_${BUNDLPATCH_OCW}.sh
		
				echo "TASK 2: Creating & executing Prereq script for OCW patch ${BUNDLPATCH_OCW} under Bundle DB patch ${BUNDLDBPATCH}"
				echo "<br>" >> $summary_report_prereq
				echo "<b>DB OPatch Prequisite Check for OCW patch ${BUNDLPATCH_OCW} under Bundle DB patch ${BUNDLDBPATCH} </b>" >> $summary_report_prereq  
				echo "<table border="1">" >> $summary_report_prereq  
				echo "<tr>" >> $summary_report_prereq  
				echo "    <th>Timestamp</th>" >> $summary_report_prereq 
				echo "    <th>Prereq Check</th>" >> $summary_report_prereq
				echo "    <th>Status</th>" >> $summary_report_prereq 
				echo "    <th>Details</th>" >> $summary_report_prereq 
				echo "</tr>" >> $summary_report_prereq 		
				
				echo "Checking the lsinventory to see if the OCW patch is applied on the environment"
				grep -wi ${BUNDLPATCH_OCW} ${PREREQ_DIR}/lsinventory.txt > ${PREREQ_DIR}/lsinventory_${BUNDLPATCH_OCW}.txt
				tret=$?
				if [[ $tret -eq 0 ]];then
					echo "DB patch $BUNDLPATCH_OCW present in lsinventory and already applied in this environment"
					echo ""
					cat ${PREREQ_DIR}/lsinventory_${BUNDLPATCH_OCW}.txt
					mv ${PREREQ_DIR}/lsinventory_${BUNDLPATCH_OCW}.txt ${PREREQ_DIR}/lsinventory_${BUNDLPATCH_OCW}_present.txt
				
					echo "DB OPatch Prequisite Check for patch ${BUNDLPATCH_OCW} " >> $master_log_prereq
					echo "Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
					echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
					echo "<tr>" >> $summary_report_prereq  
					echo "    <td>`date`</td>" >> $summary_report_prereq 
					echo "    <td>Check the OCW patch in lsinventory</td>" >> $summary_report_prereq
					echo "    <td>Failure</td>" >> $summary_report_prereq 
					echo "    <td>The OCW patch is already applied in the environment. Please verify</td>" >> $summary_report_prereq 
					echo "</tr>" >> $summary_report_prereq 
					echo "</table>" >> $summary_report_prereq
					echo ""
					echo " `date`|Check the OCW patch in lsinventory | Failure     | The patch is already applied in the environment. Please verify" >> $master_log_prereq 
					echo "" >> $master_log_prereq 
					cat $master_log_prereq
					echo "Please verify the patch number, exiting the script now.."
					exit 1;
				else
					echo "$BUNDLPATCH_OCW not present in lsinventory, proceeding further..."
					echo ""
				fi
		
							
				cp ${CTRLLOC}/db_opatch_prereq.sh $tmp_script
				export PATCHLOC=${BUNDLPATCHLOC}
				export patchNN=${BUNDLPATCHLOC}/${BUNDLPATCHNUM}/${BUNDLPATCH_OCW}
				eval "echo \"`cat $tmp_script`\"" > $new_script
				chmod +x $new_script
				cd ${PREREQ_DIR}
				. $new_script > ${new_script}.log
				ret=$?
				if [ $ret -eq 0 ]; then
					echo "PREREQ check script executed"
					echo ""
				else
					echo "PREREQ check script execution failed"
					echo ""
					echo "PREREQ check script execution failed" >> $master_log_prereq
					echo "" >> $master_log_prereq 
					cat $master_log_prereq
					exit 1;
				fi
				
				grep Prereq ${new_script}.log > ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_OCW}.log
				prereq_stat_SysSpace=`grep -wi checkSystemSpace ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_OCW}.log | cut -d" " -f3`
				prereq_stat_appliProduct=`grep -wi checkApplicableProduct ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_OCW}.log | cut -d" " -f6`
				prereq_stat_component=`grep -wi checkComponents ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_OCW}.log | cut -d" " -f6`
				prereq_stat_conDetail=`grep -wi checkConflictAmongPatchesWithDetail ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_OCW}.log | cut -d" " -f3`
				prereq_stat_appDepend=`grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_OCW}.log | cut -d" " -f6`
				prereq_stat_applica=`grep -wi checkApplicable ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_OCW}.log | cut -d" " -f6`
				prereq_stat_conOHDetail=`grep -wi checkConflictAgainstOHWithDetail ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_OCW}.log | cut -d" " -f3`
				prereq_stat_InputValues=`grep -wi checkForInputValues ${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_OCW}.log | cut -d" " -f3`
				
				export prereq_status_tidy=${PREREQ_DIR}/PREREQ_status_${BUNDLPATCH_OCW}_tidy.log
				echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace" > ${prereq_status_tidy}
				echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct" >> ${prereq_status_tidy}
				echo "PREREQ:checkComponents:$prereq_stat_component" >> ${prereq_status_tidy}
				echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail" >> ${prereq_status_tidy}
				echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend" >> ${prereq_status_tidy}
				echo "PREREQ:checkApplicable:$prereq_stat_applica" >> ${prereq_status_tidy}
				echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail" >> ${prereq_status_tidy}
				echo "PREREQ:checkForInputValues:$prereq_stat_InputValues" >> ${prereq_status_tidy}
				
						
				for n in `cat ${prereq_status_tidy}`
				do
				prereq_chkk=`echo $n |cut -d":" -f2`
				prereq_chkk_stat=`echo $n |cut -d":" -f3`
				
					echo "<tr>" >> $summary_report_prereq  
					echo "    <td>`date`</td>" >> $summary_report_prereq 
					echo "    <td>${prereq_chkk}</td>" >> $summary_report_prereq
					echo "    <td>${prereq_chkk_stat}</td>" >> $summary_report_prereq 
					echo "    <td></td>" >> $summary_report_prereq 
					echo "</tr>" >> $summary_report_prereq
					
					echo "`date`|${prereq_chkk} | ${prereq_chkk_stat} | " >> $master_log_prereq 
										
				done
				
				if [ "$prereq_stat_SysSpace" = "passed." ]; then
					echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace"  
				elif [ "$prereq_stat_SysSpace" = " " ]; then	
					echo "PREREQ status is blank, please check"
					
				else
					echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details"
					echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi	
				
				if [ "$prereq_stat_appliProduct" = "passed." ]; then
					echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct"
				elif [ "$prereq_stat_appliProduct" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi
				
				if [ "$prereq_stat_component" = "passed." ]; then
					echo "PREREQ:checkComponents:$prereq_stat_component"
				elif [ "$prereq_stat_component" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi				
				
				if [ "$prereq_stat_conDetail" = "passed." ]; then
					echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail"
				elif [ "$prereq_stat_conDetail" = " " ]; then	
					echo "PREREQ status is blank, please check"
				else
					echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi
				
				if [ "$prereq_stat_appDepend" = "passed." ]; then
					echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend"
				elif [ "$prereq_stat_appDepend" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi
				
				if [ "$prereq_stat_applica" = "passed." ]; then
					echo "PREREQ:checkApplicable:$prereq_stat_applica"
				elif [ "$prereq_stat_applica" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi
				
				if [ "$prereq_stat_conOHDetail" = "passed." ]; then
					echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail"
				elif [ "$prereq_stat_conOHDetail" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi	
				
				if [ "$prereq_stat_InputValues" = "passed." ]; then
					echo "PREREQ:checkForInputValues:$prereq_stat_InputValues"
				elif [ "$prereq_stat_InputValues" = " " ]; then	
					echo "PREREQ status is blank, please check"
					echo "PREREQ status is blank, please check" >> $master_log_prereq
				else
					echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details"
					echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details" >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				fi	
				
				echo ""
				echo "PREREQ Checks successful for OCW patch under the DB Patch bundle"
				echo "<table border="1">" >> $summary_report_prereq  
				echo "PREREQ Checks successful for OCW patch under the DB Patch bundle" >> $master_log_prereq
				echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
					
							
			else
				echo "Unable to find patch file, please check the location"
				echo "Unable to find patch file, please check the location" >> $master_log_prereq
				cat $master_log_prereq
				exit 1;
			fi
			
	elif [[ -s ${OUTPUT}/${ENV}_DB_Indiv_${DateTimeN}.txt ]]; then
			
			echo "<br>" >> $summary_report_prereq
			echo "<b>OPatch Prequisite Check Activity </b>" >> $summary_report_prereq  
			echo "<table border="1">" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "    <td><b>Patch Number(s)</b></th>" >> $summary_report_prereq 
			echo "    <td>$PATCHNUM</th>" >> $summary_report_prereq
			echo "</tr>" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "    <td><b>Patch Location</b></td>" >> $summary_report_prereq 
			echo "    <td>$PATCHLOC</td>" >> $summary_report_prereq 
			echo "</tr>" >> $summary_report_prereq 	
			echo "</table>" >> $summary_report_prereq
			echo "<br>" >> $summary_report_prereq 	
			
			echo "OPatch Prequisite Check Activity " >> $master_log_prereq
			echo "    Patch Number(s): $PATCHNUM" >> $master_log_prereq
			echo "    Patch Location: $PATCHLOC" >> $master_log_prereq
			echo "#################################################################################################################################################" >> $master_log_prereq
			echo "DBA=$EMPID" > ${USR_PREREQ_INPUT}
			echo "PATCHNUM=$PATCHNUM" >> ${OUTPUT}/${ENV}_PREREQ_${REFDateTime}.cfg
			echo "PATCHLOC=$PATCHLOC" >> ${OUTPUT}/${ENV}_PREREQ_${REFDateTime}.cfg
			echo "----------"

			echo "<br>" >> $summary_report_prereq
			echo "<b>OPatch Prequisite Check Activity </b>" >> $summary_report_prereq  
			echo "<table border="1">" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "    <td><b>Patch Number(s)</b></th>" >> $summary_report_prereq 
			echo "    <td>$PATCHNUM</th>" >> $summary_report_prereq
			echo "</tr>" >> $summary_report_prereq  
			echo "<tr>" >> $summary_report_prereq  
			echo "    <td><b>Patch Location</b></td>" >> $summary_report_prereq 
			echo "    <td>$PATCHLOC</td>" >> $summary_report_prereq 
			echo "</tr>" >> $summary_report_prereq 	
			echo "</table>" >> $summary_report_prereq
			echo "<br>" >> $summary_report_prereq 	
			
			echo "OPatch Prequisite Check Activity " >> $master_log_prereq
			echo "    Patch Number(s): $PATCHNUM" >> $master_log_prereq
			echo "    Patch Location: $PATCHLOC" >> $master_log_prereq
			echo "#################################################################################################################################################" >> $master_log_prereq
			
			echo "Executing lsinventory command..."
			cd $ORACLE_HOME/OPatch/
			./opatch lsinventory > ${PREREQ_DIR}/lsinventory.txt
						
			
			checkMulti=`echo $PATCHNUM | grep -o "," | wc -l`
			echo $PATCHNUM | sed 's/,/\n/g' > ${PREREQ_DIR}/Patch_numbers.txt
			if [ $checkMulti -eq 0 ]; then
				echo "Single patch to be applied"
				echo ${PATCHNUM}
				echo "TASK 1: Checking if the patch file ${PATCHNUM} is in the given patch location $PATCHLOC"
					fndPatch=`find ${PATCHLOC} -maxdepth 1 -name "*${PATCHNUM}*.zip"`
					find ${PATCHLOC} -maxdepth 1 -name "*${PATCHNUM}*.zip"
					ret=$?
					if [ $ret -eq 0 ]; then
						echo "Patch file $fndPatch present, unzipping it...."
						echo "unzip -o $fndPatch"
						cd ${PATCHLOC}
						#cd $ORACLE_HOME/OPatch/
						unzip -o $fndPatch
						echo ""
										
						
						export PATCHFILE=${OUTPUT}/${PATCHNUM}_${DateTime}.txt
						find $PATCHNUM -type d -name etc | tr "etc" " " >> ${PATCHFILE}
						for i in `cat ${PATCHFILE}`
						do
								SUBPATCH=`basename $i`
								tmp_script=${PREREQ_DIR}/opatch_prereq_tmp_${SUBPATCH}.sh
								new_script=${PREREQ_DIR}/opatch_prereq_${SUBPATCH}.sh
						
								echo "TASK 2: Creating & executing Prereq script for patch $SUBPATCH"
								echo "<br>" >> $summary_report_prereq
								echo "<b>DB OPatch Prequisite Check for patch ${SUBPATCH} </b>" >> $summary_report_prereq  
								echo "<table border="1">" >> $summary_report_prereq  
								echo "<tr>" >> $summary_report_prereq  
								echo "    <th>Timestamp</th>" >> $summary_report_prereq 
								echo "    <th>Prereq Check</th>" >> $summary_report_prereq
								echo "    <th>Status</th>" >> $summary_report_prereq 
								echo "    <th>Details</th>" >> $summary_report_prereq 
								echo "</tr>" >> $summary_report_prereq 		
								
								echo "Checking the lsinventory to see if the patch is applied on the environment"
								grep -wi ${SUBPATCH} ${PREREQ_DIR}/lsinventory.txt > ${PREREQ_DIR}/lsinventory_${SUBPATCH}.txt
								tret=$?
								if [[ $tret -eq 0 ]];then
									echo "$SUBPATCH present in lsinventory and already applied in this environment"
									echo ""
									cat ${PREREQ_DIR}/lsinventory_${SUBPATCH}.txt
									mv ${PREREQ_DIR}/lsinventory_${SUBPATCH}.txt ${PREREQ_DIR}/lsinventory_${SUBPATCH}_present.txt
								
									echo "DB OPatch Prequisite Check for patch ${SUBPATCH} " >> $master_log_prereq
									echo "Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
									echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
									echo "<tr>" >> $summary_report_prereq  
									echo "    <td>`date`</td>" >> $summary_report_prereq 
									echo "    <td>Check the patch in lsinventory</td>" >> $summary_report_prereq
									echo "    <td>Failure</td>" >> $summary_report_prereq 
									echo "    <td>The patch is already applied in the environment. Please verify</td>" >> $summary_report_prereq 
									echo "</tr>" >> $summary_report_prereq 
									echo "</table>" >> $summary_report_prereq
									echo ""
									echo " `date`|Check the patch in lsinventory | Failure     | The patch is already applied in the environment. Please verify" >> $master_log_prereq 
									echo "" >> $master_log_prereq 
									cat $master_log_prereq
									echo "Please verify the patch number, exiting the script now.."
									exit 1;
								else
									echo "$SUBPATCH not present in lsinventory, proceeding further..."
									echo ""
								fi
						
											
								cp ${CTRLLOC}/db_opatch_prereq.sh $tmp_script
								export patchNN=${PATCHLOC}/$i
								eval "echo \"`cat $tmp_script`\"" > $new_script
								chmod +x $new_script
								cd ${PREREQ_DIR}
								. $new_script > ${new_script}.log
								ret=$?
								if [ $ret -eq 0 ]; then
									echo "PREREQ check script executed"
									echo ""
								else
									echo "PREREQ check script execution failed"
									echo ""
									echo "PREREQ check script execution failed" >> $master_log_prereq
									echo "" >> $master_log_prereq 
									cat $master_log_prereq
									exit 1;
								fi
								
								grep Prereq ${new_script}.log > ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log
								prereq_stat_SysSpace=`grep -wi checkSystemSpace ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f3`
								prereq_stat_appliProduct=`grep -wi checkApplicableProduct ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f6`
								prereq_stat_component=`grep -wi checkComponents ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f6`
								prereq_stat_conDetail=`grep -wi checkConflictAmongPatchesWithDetail ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f3`
								prereq_stat_appDepend=`grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f6`
								prereq_stat_applica=`grep -wi checkApplicable ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f6`
								prereq_stat_conOHDetail=`grep -wi checkConflictAgainstOHWithDetail ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f3`
								prereq_stat_InputValues=`grep -wi checkForInputValues ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f3`
								
								export prereq_status_tidy=${PREREQ_DIR}/PREREQ_status_${SUBPATCH}_tidy.log
								echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace" > ${prereq_status_tidy}
								echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct" >> ${prereq_status_tidy}
								echo "PREREQ:checkComponents:$prereq_stat_component" >> ${prereq_status_tidy}
								echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail" >> ${prereq_status_tidy}
								echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend" >> ${prereq_status_tidy}
								echo "PREREQ:checkApplicable:$prereq_stat_applica" >> ${prereq_status_tidy}
								echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail" >> ${prereq_status_tidy}
								echo "PREREQ:checkForInputValues:$prereq_stat_InputValues" >> ${prereq_status_tidy}
								
										
								for n in `cat ${prereq_status_tidy}`
								do
								prereq_chkk=`echo $n |cut -d":" -f2`
								prereq_chkk_stat=`echo $n |cut -d":" -f3`
								
									echo "<tr>" >> $summary_report_prereq  
									echo "    <td>`date`</td>" >> $summary_report_prereq 
									echo "    <td>${prereq_chkk}</td>" >> $summary_report_prereq
									echo "    <td>${prereq_chkk_stat}</td>" >> $summary_report_prereq 
									echo "    <td></td>" >> $summary_report_prereq 
									echo "</tr>" >> $summary_report_prereq
									
									echo "`date`|${prereq_chkk} | ${prereq_chkk_stat} | " >> $master_log_prereq 
														
								done
								
								if [ "$prereq_stat_SysSpace" = "passed." ]; then
									echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace"  
								elif [ "$prereq_stat_SysSpace" = " " ]; then	
									echo "PREREQ status is blank, please check"
									
								else
									echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details"
									echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi	
								
								if [ "$prereq_stat_appliProduct" = "passed." ]; then
									echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct"
								elif [ "$prereq_stat_appliProduct" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								if [ "$prereq_stat_component" = "passed." ]; then
									echo "PREREQ:checkComponents:$prereq_stat_component"
								elif [ "$prereq_stat_component" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi				
								
								if [ "$prereq_stat_conDetail" = "passed." ]; then
									echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail"
								elif [ "$prereq_stat_conDetail" = " " ]; then	
									echo "PREREQ status is blank, please check"
								else
									echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								if [ "$prereq_stat_appDepend" = "passed." ]; then
									echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend"
								elif [ "$prereq_stat_appDepend" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								if [ "$prereq_stat_applica" = "passed." ]; then
									echo "PREREQ:checkApplicable:$prereq_stat_applica"
								elif [ "$prereq_stat_applica" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								if [ "$prereq_stat_conOHDetail" = "passed." ]; then
									echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail"
								elif [ "$prereq_stat_conOHDetail" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi	
								
								if [ "$prereq_stat_InputValues" = "passed." ]; then
									echo "PREREQ:checkForInputValues:$prereq_stat_InputValues"
								elif [ "$prereq_stat_InputValues" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi	
								
								echo ""
								echo "PREREQ Checks successful"
								echo "<table border="1">" >> $summary_report_prereq  
								echo "PREREQ Checks successful" >> $master_log_prereq
								echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
						done				
					
					
					else
						echo "Unable to find patch file, please check the location"
						echo "Unable to find patch file, please check the location" >> $master_log_prereq
						cat $master_log_prereq
						exit 1;
					fi
			else
				echo "Multiple patches to be applied"
				cat ${PREREQ_DIR}/Patch_numbers.txt
				for i in `cat ${PREREQ_DIR}/Patch_numbers.txt`
				do
					
					fndPatch=`find ${PATCHLOC} -maxdepth 1 -name "*${i}*.zip"`
					find ${PATCHLOC} -maxdepth 1 -name "*${i}*.zip"
					ret=$?
					if [ $ret -eq 0 ]; then
						echo "Patch file $fndPatch present, unzipping it...."
						echo "unzip -o $fndPatch"
						#cd $ORACLE_HOME/OPatch/
						cd ${PATCHLOC}
						unzip -o $fndPatch
						echo ""
					else
						echo "Unable to find patch file, please check the location"
						echo "Unable to find patch file, please check the location" >> $master_log_prereq
						cat $master_log_prereq
						exit 1;
					fi	
						
						
					export PATCHFILE=${OUTPUT}/${i}_${DateTime}.txt
					find $i -type d -name etc | tr "etc" " " >> ${PATCHFILE}
					for n in `cat ${PATCHFILE}`
					do
						SUBPATCH=`basename $n`
						tmp_script=${PREREQ_DIR}/opatch_prereq_tmp_${foldername}.sh
						new_script=${PREREQ_DIR}/opatch_prereq_${foldername}.sh
						
					
						echo "TASK 1: Checking the lsinventory to see if the patch is applied on the environment"
						grep -wi ${SUBPATCH} ${PREREQ_DIR}/lsinventory.txt > ${PREREQ_DIR}/lsinventory_${SUBPATCH}.txt
						tret=$?
							if [[ $tret -eq 0 ]];then
								echo "$SUBPATCH present in lsinventory and already applied in this environment"
								echo ""
								cat ${PREREQ_DIR}/lsinventory_${SUBPATCH}.txt
								mv ${PREREQ_DIR}/lsinventory_${SUBPATCH}.txt ${PREREQ_DIR}/lsinventory_${SUBPATCH}_present.txt
								
								echo "<br>" >> $summary_report_prereq
								echo "<b>OPatch Prequisite Check for patch ${SUBPATCH}</b>" >> $summary_report_prereq  
								echo "<table border="1">" >> $summary_report_prereq  
								echo "<tr>" >> $summary_report_prereq  
								echo "    <th>Timestamp</th>" >> $summary_report_prereq 
								echo "    <th>Prereq Check</th>" >> $summary_report_prereq
								echo "    <th>Status</th>" >> $summary_report_prereq 
								echo "    <th>Details</th>" >> $summary_report_prereq 
								echo "</tr>" >> $summary_report_prereq 
								
								echo "<tr>" >> $summary_report_prereq  
								echo "    <td>`date`</td>" >> $summary_report_prereq 
								echo "    <td>Check the patch $SUBPATCH in lsinventory</td>" >> $summary_report_prereq
								echo "    <td>Failure</td>" >> $summary_report_prereq 
								echo "    <td>The patch $SUBPATCH is already applied in the environment. Please verify</td>" >> $summary_report_prereq 
								echo "</tr>" >> $summary_report_prereq
								echo "</table>" >> $summary_report_prereq
								echo "<br>" >> $summary_report_prereq
								
								echo "OPatch Prequisite Check for patch ${SUBPATCH} " >> $master_log_prereq
								echo " Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
								echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
								echo " `date`|Check the patch in lsinventory | Failure     | The patch is already applied in the environment. Please verify" >> $master_log_prereq 
								echo "" >> $master_log_prereq 
								echo ""
								echo "Please verify the patch number.."
							else
								echo "$SUBPATCH not present in lsinventory, proceeding further..."
								echo ""
								echo "TASK 2: Checking if the patch file $SUBPATCH is in the given patch location $PATCHLOC"
								
								echo "TASK 2: Creating & executing Prereq script for patch $SUBPATCH"
								tmp_script=${PREREQ_DIR}/epm_opatch_prereq_tmp_${SUBPATCH}.sh
								new_script=${PREREQ_DIR}/epm_opatch_prereq_${SUBPATCH}.sh
												
									
								cp ${CTRLLOC}/db_opatch_prereq.sh $tmp_script
								export patchNN=${PATCHLOC}/$SUBPATCH
								eval "echo \"`cat $tmp_script`\"" > $new_script
								chmod +x $new_script
								cd ${PREREQ_DIR}
								. $new_script > ${new_script}.log
								ret=$?
								if [ $ret -eq 0 ]; then
									echo "PREREQ check script executed"
									echo ""
								else
									echo "PREREQ check script execution failed"
									echo ""
									echo "PREREQ check script execution failed" >> $master_log_prereq
									echo "" >> $master_log_prereq 
									cat $master_log_prereq
									exit 1;
								fi
									
								grep Prereq ${new_script}.log > ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log
												
								prereq_stat_SysSpace=`grep -wi checkSystemSpace ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f3`
								prereq_stat_conDetail=`grep -wi checkConflictAmongPatchesWithDetail ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f3`
								prereq_stat_conOHDetail=`grep -wi checkConflictAgainstOHWithDetail ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f3`
								prereq_stat_InputValues=`grep -wi checkForInputValues ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f3`
								prereq_stat_appliProduct=`grep -wi checkApplicableProduct ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f6`
								prereq_stat_component=`grep -wi checkComponents ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f6`
								prereq_stat_appDepend=`grep -wi checkPatchApplyDependents ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f6`
								prereq_stat_applica=`grep -wi checkApplicable ${PREREQ_DIR}/PREREQ_status_${SUBPATCH}.log | cut -d" " -f6`
								
								
								export prereq_status_tidy=${PREREQ_DIR}/PREREQ_status_${SUBPATCH}_tidy.log
								echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace" > ${prereq_status_tidy}
								echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct" >> ${prereq_status_tidy}
								echo "PREREQ:checkComponents:$prereq_stat_component" >> ${prereq_status_tidy}
								echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail" >> ${prereq_status_tidy}
								echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend" >> ${prereq_status_tidy}
								echo "PREREQ:checkApplicable:$prereq_stat_applica" >> ${prereq_status_tidy}
								echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail" >> ${prereq_status_tidy}
								echo "PREREQ:checkForInputValues:$prereq_stat_InputValues" >> ${prereq_status_tidy}
								
								echo "<br>" >> $summary_report_prereq
								echo "<b>OPatch Prequisite Check for patch ${SUBPATCH}</b>" >> $summary_report_prereq  
								echo "<table border="1">" >> $summary_report_prereq  
								echo "<tr>" >> $summary_report_prereq  
								echo "    <th>Timestamp</th>" >> $summary_report_prereq 
								echo "    <th>Prereq Check</th>" >> $summary_report_prereq
								echo "    <th>Status</th>" >> $summary_report_prereq 
								echo "    <th>Details</th>" >> $summary_report_prereq 
								echo "</tr>" >> $summary_report_prereq 		
								
								echo "OPatch Prequisite Check for patch ${SUBPATCH} " >> $master_log_prereq
								echo " Timestamp                   |Prereq Check     |Status       |Details  " >> $master_log_prereq
								echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
								
								for n in `cat ${prereq_status_tidy}`
								do
								prereq_chkk=`echo $n |cut -d":" -f2`
								prereq_chkk_stat=`echo $n |cut -d":" -f3`
								
									echo "<tr>" >> $summary_report_prereq  
									echo "    <td>`date`</td>" >> $summary_report_prereq 
									echo "    <td>${prereq_chkk}</td>" >> $summary_report_prereq
									echo "    <td>${prereq_chkk_stat}</td>" >> $summary_report_prereq 
									echo "    <td></td>" >> $summary_report_prereq 
									echo "</tr>" >> $summary_report_prereq 
									
									echo "`date`|${prereq_chkk} | ${prereq_chkk_stat} | " >> $master_log_prereq 
									
								done
								
								
								if [ "$prereq_stat_SysSpace" = "passed." ]; then
									echo "PREREQ:checkSystemSpace:$prereq_stat_SysSpace"  
								elif [ "$prereq_stat_SysSpace" = " " ]; then	
									echo "PREREQ status is blank, please check"
									
								else
									echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details"
									echo "PREREQ:CheckSystemSpace:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi	
								
								if [ "$prereq_stat_appliProduct" = "passed." ]; then
									echo "PREREQ:checkApplicableProduct:$prereq_stat_appliProduct"
								elif [ "$prereq_stat_appliProduct" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkApplicableProduct:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								if [ "$prereq_stat_component" = "passed." ]; then
									echo "PREREQ:checkComponents:$prereq_stat_component"
								elif [ "$prereq_stat_component" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkComponents:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi				
								
								if [ "$prereq_stat_conDetail" = "passed." ]; then
									echo "PREREQ:checkConflictAmongPatchesWithDetail:$prereq_stat_conDetail"
								elif [ "$prereq_stat_conDetail" = " " ]; then	
									echo "PREREQ status is blank, please check"
								else
									echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkConflictAmongPatchesWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								if [ "$prereq_stat_appDepend" = "passed." ]; then
									echo "PREREQ:checkPatchApplyDependents:$prereq_stat_appDepend"
								elif [ "$prereq_stat_appDepend" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkPatchApplyDependents:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								if [ "$prereq_stat_applica" = "passed." ]; then
									echo "PREREQ:checkApplicable:$prereq_stat_applica"
								elif [ "$prereq_stat_applica" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkApplicable:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								if [ "$prereq_stat_conOHDetail" = "passed." ]; then
									echo "PREREQ:checkConflictAgainstOHWithDetail:$prereq_stat_conOHDetail"
								elif [ "$prereq_stat_conOHDetail" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkConflictAgainstOHWithDetail:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi	
								
								if [ "$prereq_stat_InputValues" = "passed." ]; then
									echo "PREREQ:checkForInputValues:$prereq_stat_InputValues"
								elif [ "$prereq_stat_InputValues" = " " ]; then	
									echo "PREREQ status is blank, please check"
									echo "PREREQ status is blank, please check" >> $master_log_prereq
								else
									echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details"
									echo "PREREQ:checkForInputValues:failed. Check ${new_script}.log for details" >> $master_log_prereq
									cat $master_log_prereq
									exit 1;
								fi
								
								echo ""
								echo "PREREQ Checks successful"
								echo "" >> $master_log_prereq
								echo "PREREQ Checks successful" >> $master_log_prereq
								echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prereq
								echo "</table>" >> $summary_report_prereq
								echo "<br>" >> $summary_report_prereq
						
							fi
					done	
				done
				ls -ltr ${PREREQ_DIR}/lsinventory_*_present.txt 
				uret=$?
				echo $uret
				if [[ $uret -eq 0 ]];then
					echo "Few patches are already applied in this environment, please verify. Exiting script...."
					echo "Few patches are already applied in this environment, please verify." >> $master_log_prereq
					cat $master_log_prereq
					exit 1;
				else
					echo "All the patches are good to go"
				fi
				
				
				
			fi
	else
		echo "ERROR: Patch details not found"
		echo "Exiting...."
		exit 1;
	fi	
echo "<br>" >> $summary_report_prereq	
cat $master_log_prereq	
echo ""
echo ""
		
	DBoptionsScreen
}


function DBBACKUPS() {

echo "#################################################################################################################################################"
echo  "Checking emcli status.."
$EMCLIHOME/emcli describe_job -name="QA1_CONSOL_BACKUP" > ${OUTPUT}/emcli_test.txt
RET=$?
echo ""
	if [ $RET -ne 0 ];then
		echo ""
		echo "$DateTime: ERROR: emcli setup on server is lost, follow the instruction below to execute Cloud control jobs, else only backup action which will work is 3. Execute backup immediately from this server "
		echo "Execute $EMCLIHOME/emcli setup -url=https://prod-em.sherwin.com/em -username=sw_jobadmin -trustall -autologin"
		echo "Provide the password for SW_JOBADMIN when prompted"
		echo ""
	else
		echo ""
		echo "$DateTime: SUCCESS: emcli setup on server is valid"
		echo ""
	fi
echo "#################################################################################################################################################"

read -p "DBA conducting the Maintenance (enter your sherwin id) " EMPID
read -p "Enter the Change Log Request ID : " CHNGID
echo "DBA conducting this step is "$EMPID
echo "Change Log request ID is "$CHNGID

if [[ "$CHNGID" = "" ]]; then
	echo "No change ID input for "$ENV
	
	export summary_report_backup=${PPLOGDIR}/${ENV}_DB_PATCH_report_BACKUP_${EMPID}_${DateTime}.html
	export master_log_backup=${PPLOGDIR}/${ENV}_DB_PATCH_Master_Log_BACKUP_${EMPID}_${DateTime}.log
	
else
	echo "Input file $INPUT_FILE sourced in for "$ENV
	echo "Change Log Request ID is "$CHNGID
	
	export summary_report_backup=${PPLOGDIR}/${ENV}_DB_PATCH_report_BACKUP_${CHNGID}_${DateTime}.html
	export master_log_backup=${PPLOGDIR}/${ENV}_DB_PATCH_Master_Log_BACKUP_${CHNGID}_${DateTime}.log
	
fi
echo "----------"
echo "<br>" >> $summary_report_backup
echo "<table border="1">" >> $summary_report_backup  
echo "<tr>" >> $summary_report_backup  
echo "     <td><b>DBA</b></td>" >> $summary_report_backup  
echo "	   <td>$EMPID</td>" >> $summary_report_backup
echo "</tr>" >> $summary_report_backup  
echo "<tr>" >> $summary_report_backup 
echo "     <td><b>Step performed</b></td>" >> $summary_report_backup  
echo "	   <td>DB Backups</td>" >> $summary_report_backup    
echo "</tr>" >> $summary_report_backup  
echo "<tr>" >> $summary_report_backup  
echo "     <td><b>Date</b></td>" >> $summary_report_backup  
echo "	   <td>`date`</td>" >> $summary_report_backup  
echo "</tr>" >> $summary_report_backup 
echo "<tr>" >> $summary_report_backup
echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_backup
echo "	   <td>$CHNGID</td>" >> $summary_report_backup
echo "</tr>" >> $summary_report_backup 
echo "<tr>" >> $summary_report_backup
echo "     <td><b>Method</b></td>" >> $summary_report_backup
echo "	   <td>Manual</td>" >> $summary_report_backup
echo "</tr>" >> $summary_report_backup
echo "</table>" >> $summary_report_backup  
echo "<br>" >> $summary_report_backup 
echo "<br>" >> $summary_report_backup 

echo "<br>" >> $summary_report_backup
echo "<b>Backup execution</b>" >> $summary_report_backup
echo "<table border="1">" >> $summary_report_backup
echo "<tr>" >> $summary_report_backup
echo "    <th>Timestamp</th>" >> $summary_report_backup
echo "    <th>Step</th>" >> $summary_report_backup
echo "    <th>Backup Name</th>" >> $summary_report_backup
echo "    <th>Status</th>" >> $summary_report_backup
echo "    <th>Details</th>" >> $summary_report_backup
echo "</tr>" >> $summary_report_backup

echo "#################################################################################################################################################" >> $master_log_backup
echo "DBA: $EMPID" >> $master_log_backup
echo "Step performed: DB Backups" >> $master_log_backup
echo "Date: `date`" >> $master_log_backup
echo "Change Log Request ID: $CHNGID" >> $master_log_backup
echo "Method: Manual" >> $master_log_backup
echo "#################################################################################################################################################" >> $master_log_backup

echo "Backup action to be performed:"
echo ""
echo "1. Cancel existing backup (Cloud control - RMAN, EXPDP)
2. Schedule a one time backup (Cloud control - RMAN, EXPDP)
3. Execute backup immediately from this server (RMAN, EXPDP)
4. Execute backup immediately from Cloud control (RMAN, EXPDP)
5. Last Execution status for Cloud control backup jobs"
echo ""

		echo -n "Select Option, to exit 0 (zero): "
		read usrselec
		if [ $usrselec -eq 1 ]; then
			echo ""
			echo "Option $usrselec selected, Cancel existing backups scheduled in Cloud control. Listing backups for $ENV..."
			echo "Option $usrselec selected, Cancel existing backups scheduled in Cloud control. " >> $master_log_backup
			echo "------------------------------------------------------------------------------" >> $master_log_backup
			
			echo "" >> $master_log_backup
						
			echo ""
			cat ${CTRLLOC}/${ENV}_CC_DB_backup_jobs.cfg
			echo ""
			echo -n "Select Job name option, to exit 0 (zero): "
			echo ""
			read usrselecjob
			if [ $usrselecjob = 1 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				linename=`grep "1#" ${CTRLLOC}/${ENV}_CC_DB_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_cc_db_names1.txt
				echo "Job to be cancelled in Cloud Control: "$linename
				Multi_CC_DB_job_cancel
				
							
			elif [ $usrselecjob -eq 2 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname1=`grep "2#" ${CTRLLOC}/${ENV}_CC_DB_backup_jobs.cfg | cut -d"#" -f2`
				sanjobname=`echo $jobname1 | tr "_" " "`
				jobname=$sanjobname
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				#export NEXTDAY=`date --date="next day" +%Y-%m-%d`
				Single_CC_DB_job_cancel
				
			elif [ $usrselecjob -eq 3 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname1=`grep "3#" ${CTRLLOC}/${ENV}_CC_DB_backup_jobs.cfg | cut -d"#" -f2`
				sanjobname=`echo $jobname1 | tr "_" " "`
				jobname=$sanjobname
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				Single_CC_DB_job_cancel
				
			elif [ $usrselecjob -eq 4 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname=`grep "4#" ${CTRLLOC}/${ENV}_CC_DB_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				Single_CC_DB_job_cancel
				
			elif [ $usrselecjob -eq 5 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname=`grep "5#" ${CTRLLOC}/${ENV}_CC_DB_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				Single_CC_DB_job_cancel
			
			elif [ $usrselecjob -eq 6 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname=`grep "6#" ${CTRLLOC}/${ENV}_CC_DB_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				Single_CC_DB_job_cancel
			
			elif [ $usrselecjob -eq 7 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname=`grep "7#" ${CTRLLOC}/${ENV}_CC_DB_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				Single_CC_DB_job_cancel
				
			elif [ $usrselecjob -eq 8 ]; then
				echo ""
				echo "Job option selected="$usrselecjob
				echo ""
				jobname=`grep "8#" ${CTRLLOC}/${ENV}_CC_DB_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be cancelled in Cloud Control: "$jobname
				echo "Job to be cancelled in Cloud Control: $jobname" >> $master_log_backup
				Single_CC_DB_job_cancel
				
			elif [ $usrselecjob -eq 0 ]; then
				echo ""
				echo "Exiting to main screen"
				echo "Exited to main screen" >> $master_log_backup
				echo ""
				DBoptionsScreen
			else
				echo ""
				echo "ERROR: Invalid option"
				echo "Exiting script"
				echo "ERROR: Invalid option used. Exiting script." >> $master_log_backup
				exit 1;
			fi
###############SCHEDULE JOB FROM CLOUD CONTROL - Template #####################		
		elif [ $usrselec -eq 2 ]; then	
			echo ""
			echo "Option $usrselec selected. Schedule a one time backup from cloud control. Listing backups for $ENV..."
			echo "Option $usrselec selected, Schedule a one time backup from cloud control. " >> $master_log_backup
			echo "------------------------------------------------------------------------------" >> $master_log_backup
			echo ""
			cat ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg
			echo ""
			echo -n "Select Job name option, to exit 0 (zero): "
			echo ""
			read usrselecjob1
			if [ $usrselecjob1 -eq 1 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "1#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names1.txt
				Mutli_CC_DB_job_schedule
							
			elif [ $usrselecjob1 -eq 2 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname1=`grep "2#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				sanjobname=`echo $jobname1 | tr "_" " "`
				jobname=$sanjobname
				Single_CC_DB_job_schedule
				
			elif [ $usrselecjob1 -eq 3 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname1=`grep "3#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				sanjobname=`echo $jobname1 | tr "_" " "`
				jobname=$sanjobname
				Single_CC_DB_job_schedule
				
			elif [ $usrselecjob1 -eq 4 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "4#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				Single_CC_DB_job_schedule
				
			elif [ $usrselecjob1 -eq 5 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "5#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				Single_CC_DB_job_schedule
				
			elif [ $usrselecjob1 -eq 6 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "6#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				Single_CC_DB_job_schedule
				
			elif [ $usrselecjob1 -eq 7 ]; then
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				echo "Job option selected="$usrselecjob1
				echo ""
				jobname=`grep "7#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				Single_CC_DB_job_schedule
				
			elif [ $usrselecjob1 -eq 8 ]; then
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				echo "Job option selected="$usrselecjob1
				echo ""
				jobname=`grep "8#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				Single_CC_DB_job_schedule
				
			elif [ $usrselecjob1 -eq 0 ]; then
				echo ""
				echo "Exiting to main screen"
				echo "Exited to main screen" >> $master_log_backup
				echo ""
				DBoptionsScreen
			
			else
				echo ""
				echo "ERROR: Invalid option"
				echo "ERROR: Invalid option used. Exiting script." >> $master_log_backup
				echo "Exiting script"
				exit 1;
			fi
###############EXECUTE FROM SERVER IMMEDIATELY#####################			
		elif [ $usrselec -eq 3 ]; then	
			echo ""
			echo "Option $usrselec selected. Execute backup now on this server. Listing backups for $ENV..."
			echo "$DateTime: Option $usrselec selected. Execute backup now on this server. Listing backups for $ENV..." >> $master_log_backup
			echo "------------------------------------------------------------------------------" >> $master_log_backup
			echo ""
			cat ${CTRLLOC}/${ENV}_manual_run_DB_backup_jobs.cfg
			echo ""
			echo -n "Select Job name option, to exit 0 (zero): "
			echo ""
			read usrselecjob2
			if [ $usrselecjob2 -eq 1 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				linename=`grep "1#" ${CTRLLOC}/${ENV}_manual_run_DB_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names_Db1_now.txt
				echo "$DateTime: Job to be run now from this server: "$linename >> $master_log_backup
				read -p "Enter the user name for the EXPDP execution: " UNAME
				read -p "Enter the password for the above user :" PWDS
								
				for i in ${OUTPUT}/bkp_names_Db1_now.txt
				do
				#export PDBNAME=`echo ${i} | cut -d"_" -f2`
				export EXPDP_TODAY=${OUTPUT}/${i}_${DateTime}.sh
				export ATINPUT=${OUTPUT}/atinputfile_expdp_opt1_${PDBNAME}_${DateTime}.txt
				cp ${CTRLLOC}/${i}.sh ${EXPDP_TODAY}
				
				#echo "${EXPDP_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME}" > ${ATINPUT}
				echo "EXPDP job ${i}.sh manual execution from this server starting"
				echo "EXPDP job ${EXPDP_TODAY} manual execution from this server" >> $master_log_backup
				${EXPDP_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME} ${UNAME} ${PWDS} > ${PPLOGDIR}/${ENV}_${jobname}_${DateTime}.log 2>&1 &
				#at -f ${ATINPUT} now
				
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$i</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				echo "<br>" >> $summary_report_backup
				
				done			
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
							
			elif [ $usrselecjob2 -eq 2 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo "RMAN job"
				jobname=`grep "2#" ${CTRLLOC}/${ENV}_manual_run_DB_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be run now from this server: "$jobname	
				echo "$DateTime: Job to be run now from this server: "$jobname >> $master_log_backup
				
				export ATINPUT1=${OUTPUT}/atinputfile_rman_opt1_${PDBNAME}_${DateTime}.txt
				export RMAN_TODAY=${OUTPUT}/${jobname}_${DateTime}.sh
				export ATINPUT=${OUTPUT}/atinputfile_rman_opt1_${PDBNAME}_${DateTime}.txt
				export SQL_RMAN_VALID=${CTRLLOC}/RMAN_validate.sql
				export RMAN_SETUP=${CTRLLOC}/RMAN_Setup.txt
				export SQL_RMAN_RSTR_PT=${CTRLLOC}/RMAN_RESTR_PT.sql
				cp ${CTRLLOC}/RMAN_Complete.sh ${RMAN_TODAY}
				
				#echo "${RMAN_TODAY}" > ${ATINPUT1}
				echo "RMAN backup job ${RMAN_TODAY} manual execution from this server starting"
				#at -f ${ATINPUT} now	
				#echo "${RMAN_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME} ${SQL_RMAN_VALID} ${RMAN_SETUP} ${SQL_RMAN_RSTR_PT} > ${PPLOGDIR}/${ENV}_${jobname}_${DateTime}.log"
				${RMAN_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME} ${SQL_RMAN_VALID} ${RMAN_SETUP} ${SQL_RMAN_RSTR_PT} > ${PPLOGDIR}/${ENV}_${jobname}_${DateTime}.log 2>&1 &
				
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$jobname</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				echo "<br>" >> $summary_report_backup
				
			elif [ $usrselecjob2 -eq 3 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				jobname=`grep "3#" ${CTRLLOC}/${ENV}_manual_run_DB_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be run now from this server: "$jobname
				echo "$DateTime: Job to be run now from this server: "$jobname >> $master_log_backup
				
				read -p "Enter the user name for the EXPDP execution: " UNAME
				read -p "Enter the password for the above user :" PWDS
				
				export ATINPUT1=${OUTPUT}/atinputfile_expdp_opt1_${PDBNAME}_${DateTime}.txt
				export EXPDP_TODAY=${OUTPUT}/${jobname}_${DateTime}.sh
				export ATINPUT=${OUTPUT}/atinputfile_expdp_opt1_${PDBNAME}_${DateTime}.txt
				cp ${CTRLLOC}/${jobname}.sh ${EXPDP_TODAY}
				
				#echo "${EXPDP_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME}" > ${ATINPUT1}
				echo "EXPDP job ${EXPDP_TODAY} manual execution from this server starting"
				#at -f ${ATINPUT} now	
				${EXPDP_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME} ${UNAME} ${PWDS} > ${PPLOGDIR}/${ENV}_${jobname}_${DateTime}.log 2>&1 &
				
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$jobname</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				echo "<br>" >> $summary_report_backup
				
			elif [ $usrselecjob2 -eq 4 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				jobname=`grep "4#" ${CTRLLOC}/${ENV}_manual_run_DB_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be run now from this server: "$jobname
				echo "$DateTime: Job to be run now from this server: "$jobname >> $master_log_backup
				
				export ATINPUT1=${OUTPUT}/atinputfile_expdp_opt1_${PDBNAME}_${DateTime}.txt
				export EXPDP_TODAY=${OUTPUT}/${jobname}_${DateTime}.sh
				export ATINPUT=${OUTPUT}/atinputfile_expdp_opt1_${PDBNAME}_${DateTime}.txt
				cp ${CTRLLOC}/${jobname}.sh ${EXPDP_TODAY}
				
				read -p "Enter the user name for the EXPDP execution: " UNAME
				read -p "Enter the password for the above user :" PWDS
				
				#echo "${EXPDP_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME}" > ${ATINPUT1}
				echo "EXPDP job ${EXPDP_TODAY} manual execution from this server starting"
				#at -f ${ATINPUT} now	
				${EXPDP_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME} ${UNAME} ${PWDS} > ${PPLOGDIR}/${ENV}_${jobname}_${DateTime}.log 2>&1 &
				
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$jobname</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				echo "<br>" >> $summary_report_backup
				
			elif [ $usrselecjob2 -eq 5 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				jobname=`grep "5#" ${CTRLLOC}/${ENV}_manual_run_DB_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be run now from this server: "$jobname
				echo "$DateTime: Job to be run now from this server: "$jobname >> $master_log_backup
				
				read -p "Enter the user name for the EXPDP execution: " UNAME
				read -p "Enter the password for the above user :" PWDS
				
				
				export ATINPUT1=${OUTPUT}/atinputfile_expdp_opt1_${PDBNAME}_${DateTime}.txt
				export EXPDP_TODAY=${OUTPUT}/${jobname}_${DateTime}.sh
				export ATINPUT=${OUTPUT}/atinputfile_expdp_opt1_${PDBNAME}_${DateTime}.txt
				cp ${CTRLLOC}/${jobname}.sh ${EXPDP_TODAY}
				
				#echo "${EXPDP_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME}" > ${ATINPUT1}
				echo "EXPDP job ${EXPDP_TODAY} manual execution from this server starting"
				#at -f ${ATINPUT} now	
				${EXPDP_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME} ${UNAME} ${PWDS} > ${PPLOGDIR}/${ENV}_${jobname}_${DateTime}.log 2>&1 &
				
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$jobname</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				echo "<br>" >> $summary_report_backup
			
			elif [ $usrselecjob2 -eq 6 ]; then
				echo ""
				echo "Job option selected="$usrselecjob2
				echo ""
				jobname=`grep "6#" ${CTRLLOC}/${ENV}_manual_run_DB_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be run now from this server: "$jobname
				echo "$DateTime: Job to be run now from this server: "$jobname >> $master_log_backup
				
				read -p "Enter the user name for the EXPDP execution: " UNAME
				read -p "Enter the password for the above user :" PWDS
				
				export ATINPUT1=${OUTPUT}/atinputfile_expdp_opt1_${PDBNAME}_${DateTime}.txt
				export EXPDP_TODAY=${OUTPUT}/${jobname}_${DateTime}.sh
				export ATINPUT=${OUTPUT}/atinputfile_expdp_opt1_${PDBNAME}_${DateTime}.txt
				cp ${CTRLLOC}/${jobname}.sh ${EXPDP_TODAY}
				
				#echo "${EXPDP_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME}" > ${ATINPUT1}
				echo "EXPDP job ${EXPDP_TODAY} manual execution from this server starting"
				#at -f ${ATINPUT} now
				${EXPDP_TODAY} ${ENVFILE} ${CDBNAME} ${PDBNAME} ${UNAME} ${PWDS} > ${PPLOGDIR}/${ENV}_${jobname}_${DateTime}.log 2>&1 &
								
				echo "<tr>" >> $summary_report_backup
				echo "    <td>`date`</td>" >> $summary_report_backup
				echo "    <td>Backup step 3: Execute backup Now (Execute from this server)</td>" >> $summary_report_backup
				echo "    <td>$jobname</td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "    <td></td>" >> $summary_report_backup
				echo "</tr>" >> $summary_report_backup
				echo "<br>" >> $summary_report_backup
				
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
			
			elif [ $usrselecjob2 -eq 0 ]; then
				echo ""
				echo "Exiting to main screen"
				echo "Exited to main screen" >> $master_log_backup
				echo ""
				DBoptionsScreen
			
			else
				echo ""
				echo "ERROR: Invalid option"
				echo "Exiting script"
				echo "ERROR: Invalid option used. Exiting script." >> $master_log_backup
				exit 1;
			fi
###############EXECUTE FROM CLOUD CONTROL IMMEDIATELY - Library job#####################
		elif [ $usrselec -eq 4 ]; then	
			echo ""
			echo "Option $usrselec selected. Schedule a one time backup from cloud control. Listing backups for $ENV..."
			echo "Option $usrselec selected. Schedule a one time backup from cloud control. Listing backups for $ENV..." >> $master_log_backup
			echo "------------------------------------------------------------------------------" >> $master_log_backup
			echo ""
			cat ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg
			echo ""
			echo -n "Select Job name option, to exit 0 (zero): "
			echo ""
			read usrselecjob3
			if [ $usrselecjob3 -eq 1 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				linename=`grep "1#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d":" -f2`
				echo $linename | sed 's/,/\n/g' > ${OUTPUT}/bkp_names1.txt
				echo "Job to be executed immediately from Cloud Control: "$linename
				Multi_CC_DB_job_Immediate
				
						
			elif [ $usrselecjob3 -eq 2 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname1=`grep "2#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				sanjobname=`echo $jobname1`
				jobname=$sanjobname
				echo "Job to be executed immediately from Cloud Control: "$jobname
				Single_CC_DB_job_Immediate
				
			elif [ $usrselecjob3 -eq 3 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname1=`grep "3#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				sanjobname=`echo $jobname1`
				jobname=$sanjobname
				echo "Job to be executed immediately from Cloud Control: "$jobname
				Single_CC_DB_job_Immediate
				
			elif [ $usrselecjob3 -eq 4 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "4#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be executed immediately from Cloud Control: "$jobname
				Single_CC_DB_job_Immediate
				
			elif [ $usrselecjob3 -eq 5 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "5#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				echo "Job to be executed immediately from Cloud Control: "$jobname
				Single_CC_DB_job_Immediate
							
			elif [ $usrselecjob3 -eq 6 ]; then
				echo ""
				echo "Job option selected="$usrselecjob1
				echo ""
				DateTime1=`date +%d%m%y%H%M%S`
				jobname=`grep "6#" ${CTRLLOC}/${ENV}_DB_CC_onetime_backup_jobs.cfg | cut -d"#" -f2`
				Single_CC_DB_job_Immediate
			
			elif [ $usrselecjob3 -eq 0 ]; then
				echo ""
				echo "Exiting to main screen"
				echo ""
				DBoptionsScreen
			
			else
				echo ""
				echo "ERROR: Invalid option"
				echo "Exiting script"
				exit 1;
			fi
###############CLOUD CONTROL JOB STATUS#####################		
		elif [ $usrselec -eq 5 ]; then
				echo ""
				echo "Checking the last execution status for cloud control jobs for $ENV"
				echo "$DateTime: Checking the last execution status for cloud control jobs for $ENV" >> $master_log_backup
				echo "------------------------------------------------------------------------------" >> $master_log_backup
				echo ""
				echo "Listing backups for $ENV..."
				echo ""
				cat ${CTRLLOC}/${ENV}_status_all_DB_backup_jobs.cfg
				echo ""
				echo "Fetching the last execution status of jobs"
				echo ""
				for n in `cat ${CTRLLOC}/${ENV}_status_all_DB_backup_jobs.cfg`
				do
				jobx=`echo $n | grep RMAN`
				ret=$?
				if [ $ret -eq 0 ];then
				
					san_job=`echo $n | tr "_" " "`
					${EMCLIHOME}/emcli get_jobs -name="${san_job}" -owner="SW_JOBADMIN" > ${OUTPUT}/job_exec_${n}.txt	
					tail -2 ${OUTPUT}/job_exec_${n}.txt | head -1 > ${OUTPUT}/last_job_exec_${n}.txt	
								
					fromdate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $10}'`
					fromtime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $11}'`
					todate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $12}'`
					totime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $13}'`
					status=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $15}'`
					
					if [ $status = "Failed" ];then
						grep "$fromdate" ${OUTPUT}/job_exec_${n}.txt | tr " " "#"  > ${OUTPUT}/job_exec_fail_${n}.txt
						for i in `cat ${OUTPUT}/job_exec_fail_${n}.txt`
						do
							fromdate=`echo $i | tr "#" " " | awk '{print $10}'`
							fromtime=`echo $i | tr "#" " " | awk '{print $11}'`
							todate=`echo $i | tr "#" " " | awk '{print $12}'`
							totime=`echo $i | tr "#" " " | awk '{print $13}'`
							status=`echo $i | tr "#" " " | awk '{print $15}'`
						
							echo "Last execution status for backup ${n}: ${status}"
							echo "Execution Start Time: $fromdate $fromtime "
							echo "Execution End Time: $todate $totime "
							echo "Last execution status for backup ${n}: ${status}" >> $master_log_backup
							echo "Execution Start Time: $fromdate $fromtime " >> $master_log_backup 
							echo "Execution End Time: $todate $totime " >> $master_log_backup
							echo "<tr>" >> $summary_report_backup
							echo "    <td>`date`</td>" >> $summary_report_backup
							echo "    <td>Backup step 5: Last Execution status for Cloud control backup jobs </td>" >> $summary_report_backup
							echo "    <td>$n</td>" >> $summary_report_backup
							echo "    <td>${status}</td>" >> $summary_report_backup
							echo "    <td>Execution Start Time: $fromdate $fromtime , Execution End Time: $todate $totime </td>" >> $summary_report_backup
							echo "</tr>" >> $summary_report_backup
							echo "<br>" >> $summary_report_backup
							echo ""
						done
					else
					
						echo "Last execution status for backup ${n}: ${status}"
						echo "Execution Start Time: $fromdate $fromtime "
						echo "Execution End Time: $todate $totime "
						
						echo "Last execution status for backup ${n}: ${status}" >> $master_log_backup
						echo "Execution Start Time: $fromdate $fromtime " >> $master_log_backup 
						echo "Execution End Time: $todate $totime " >> $master_log_backup
						echo "<tr>" >> $summary_report_backup
						echo "    <td>`date`</td>" >> $summary_report_backup
						echo "    <td>Backup step 5: Last Execution status for Cloud control backup jobs </td>" >> $summary_report_backup
						echo "    <td>$n</td>" >> $summary_report_backup
						echo "    <td>${status}</td>" >> $summary_report_backup
						echo "    <td>Execution Start Time: $fromdate $fromtime , Execution End Time: $todate $totime </td>" >> $summary_report_backup
						echo "</tr>" >> $summary_report_backup
						echo "<br>" >> $summary_report_backup
						echo ""
					fi
					
					
				elif [ $ret -eq 1 ];then
					
					${EMCLIHOME}/emcli get_jobs -name="${n}" -owner="SW_JOBADMIN" > ${OUTPUT}/job_exec_${n}.txt	
					tail -2 ${OUTPUT}/job_exec_${n}.txt | head -1 > ${OUTPUT}/last_job_exec_${n}.txt	
						
					export fromdate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $5}'`
					export fromtime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $6}'`
					export todate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $7}'`
					export totime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $8}'`
					export status=`cat ${OUTPUT}/last_job_exec_${n}.txt | awk '{print $10}'`
					
					if [ "$status" = "Failed" ];then

						echo "Last execution status for backup ${n}: ${status}"
						echo "Execution Start Time: $fromdate $fromtime "
						echo "Execution End Time: $todate $totime "
						echo ""
						echo "Checking & listing other executions which were tried for this day..."
						
						echo "Last execution status for backup ${n}: ${status}" >> $master_log_backup
						echo "Execution Start Time: $fromdate $fromtime " >> $master_log_backup 
						echo "Execution End Time: $todate $totime " >> $master_log_backup
						echo "" >> $master_log_backup
						echo "Checking if other executions were tried for this day..." >> $master_log_backup
						echo "<tr>" >> $summary_report_backup
						echo "    <td>`date`</td>" >> $summary_report_backup
						echo "    <td>Backup step 5: Last Execution status for Cloud control backup jobs </td>" >> $summary_report_backup
						echo "    <td>$n</td>" >> $summary_report_backup
						echo "    <td>${status}</td>" >> $summary_report_backup
						echo "    <td>Execution Start Time: $fromdate $fromtime , Execution End Time: $todate $totime </td>" >> $summary_report_backup
						echo "</tr>" >> $summary_report_backup
						echo "<br>" >> $summary_report_backup
						echo "<b>Checking if other executions were tried for this day..." >> $summary_report_backup
						echo "<br>" >> $summary_report_backup
						echo ""
						
						grep "$fromdate" ${OUTPUT}/job_exec_${n}.txt | tr " " "#" > ${OUTPUT}/job_exec_fail_${n}.txt
						for i in `cat ${OUTPUT}/job_exec_fail_${n}.txt`
						do
							fa_fromdate=`echo $i | tr "#" " " | awk '{print $5}'`
							fa_fromtime=`echo $i | tr "#" " " | awk '{print $6}'`
							fa_todate=`echo $i | tr "#" " " | awk '{print $7}'`
							fa_totime=`echo $i | tr "#" " " | awk '{print $8}'`
							fa_status=`echo $i | tr "#" " " | awk '{print $10}'`
						
							echo "Last execution status for backup ${n}: ${fa_status}"
							echo "Execution Start Time: $fa_fromdate $fa_fromtime "
							echo "Execution End Time: $fa_todate $fa_totime "
							echo "Last execution status for backup ${n}: ${fa_status}" >> $master_log_backup
							echo "Execution Start Time: $fa_fromdate $fa_fromtime " >> $master_log_backup 
							echo "Execution End Time: $fa_todate $fa_totime " >> $master_log_backup
							echo "<tr>" >> $summary_report_backup
							echo "    <td>`date`</td>" >> $summary_report_backup
							echo "    <td>Backup step 5: Last Execution status for Cloud control backup jobs </td>" >> $summary_report_backup
							echo "    <td>$n</td>" >> $summary_report_backup
							echo "    <td>${fa_status}</td>" >> $summary_report_backup
							echo "    <td>Execution Start Time: $fa_fromdate $fa_fromtime , Execution End Time: $fa_todate $fa_totime </td>" >> $summary_report_backup
							echo "</tr>" >> $summary_report_backup
							echo ""
						done
					else
					
						echo "Last execution status for backup ${n}: ${status}"
						echo "Execution Start Time: $fromdate $fromtime "
						echo "Execution End Time: $todate $totime "
						
						echo "Last execution status for backup ${n}: ${status}" >> $master_log_backup
						echo "Execution Start Time: $fromdate $fromtime " >> $master_log_backup 
						echo "Execution End Time: $todate $totime " >> $master_log_backup
						echo "<tr>" >> $summary_report_backup
						echo "    <td>`date`</td>" >> $summary_report_backup
						echo "    <td>Backup step 5: Last Execution status for Cloud control backup jobs </td>" >> $summary_report_backup
						echo "    <td>$n</td>" >> $summary_report_backup
						echo "    <td>${status}</td>" >> $summary_report_backup
						echo "    <td>Execution Start Time: $fromdate $fromtime , Execution End Time: $todate $totime </td>" >> $summary_report_backup
						echo "</tr>" >> $summary_report_backup
						echo "<br>" >> $summary_report_backup
						echo ""
					fi
												
				else
				
					echo "Invalid job name. Check manually"
				
				fi	
				
				done
				echo ""
				echo "#################################################################################################################################################" >> $master_log_backup
				cat $master_log_backup
				
		elif [ $usrselec -eq 0 ]; then
				echo ""
				echo "Exiting to main screen"
				DBoptionsScreen	
		else 
			echo ""
			echo "ERROR: Invalid option"
			echo "Exiting script"
			exit 1;
		fi	
echo "<br>" >> $summary_report_backup		
echo ""
echo ""
DBoptionsScreen
}


function DBprePatchSteps() {

read -p "DBA conducting the Maintenance (enter your sherwin id) " EMPID
read -p "Enter the Change Log Request ID : " CHNGID
echo "DBA conducting this step is "$EMPID
echo "Change Log request ID is "$CHNGID

if [[ "$CHNGID" = "" ]]; then
	echo "No change ID input for "$ENV
	
	export summary_report_prepatch=${PPLOGDIR}/${ENV}_DB_PATCH_report_PREPATCH_${EMPID}_${DateTime}.html
	export master_log_prepatch=${PPLOGDIR}/${ENV}_DB_PATCH_Master_Log_PREPATCH_${EMPID}_${DateTime}.log
	
else
	echo "Input file $INPUT_FILE sourced in for "$ENV
	echo "Change Log Request ID is "$CHNGID
	
	export summary_report_prepatch=${PPLOGDIR}/${ENV}_DB_PATCH_report_PREPATCH_${CHNGID}_${DateTime}.html
	export master_log_prepatch=${PPLOGDIR}/${ENV}_DB_PATCH_Master_Log_PREPATCH_${CHNGID}_${DateTime}.log
	
fi
echo "----------"
echo "<br>" >> $summary_report_prepatch
echo "<table border="1">" >> $summary_report_prepatch  
echo "<tr>" >> $summary_report_prepatch  
echo "     <td><b>DBA</b></td>" >> $summary_report_prepatch  
echo "	   <td>$EMPID</td>" >> $summary_report_prepatch
echo "</tr>" >> $summary_report_prepatch  
echo "<tr>" >> $summary_report_prepatch 
echo "     <td><b>Step performed</b></td>" >> $summary_report_prepatch  
echo "	   <td>DB Prepatch Steps</td>" >> $summary_report_prepatch    
echo "</tr>" >> $summary_report_prepatch  
echo "<tr>" >> $summary_report_prepatch  
echo "     <td><b>Date</b></td>" >> $summary_report_prepatch  
echo "	   <td>`date`</td>" >> $summary_report_prepatch  
echo "</tr>" >> $summary_report_prepatch 
echo "<tr>" >> $summary_report_prepatch
echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_prepatch
echo "	   <td>$CHNGID</td>" >> $summary_report_prepatch
echo "</tr>" >> $summary_report_prepatch 
echo "<tr>" >> $summary_report_prepatch
echo "     <td><b>Method</b></td>" >> $summary_report_prepatch
echo "	   <td>Manual</td>" >> $summary_report_prepatch
echo "</tr>" >> $summary_report_prepatch
echo "</table>" >> $summary_report_prepatch  
echo "<br>" >> $summary_report_prepatch 
echo "<br>" >> $summary_report_prepatch 


echo "#################################################################################################################################################" >> $master_log_prepatch
echo "DBA: $EMPID" >> $master_log_prepatch
echo "Step performed: Prepatch Steps" >> $master_log_prepatch
echo "Date: `date`" >> $master_log_prepatch
echo "Change Log Request ID: $CHNGID" >> $master_log_prepatch
echo "Method: Manual" >> $master_log_prepatch
echo "#################################################################################################################################################" >> $master_log_prepatch

#Prepatching step 1: lsinventory command
echo "####################################################################################################"
echo "DB Prepatching step 1: lsinventory command"
echo "####################################################################################################"echo ""
echo ""
cd $ORACLE_HOME/OPatch
echo "./opatch lsinventory"
export TodayDate=`date +%d_%m_%Y`
export PREPATCHDIR=${DBBACKUPDIR}/PREPATCH_${ENV}_${CHNGID}_${TodayDate}
lsinvDate=`date +%Y-%m-%d_%H-%M`
./opatch lsinventory > ${OUTPUT}/lsinventory_prepatch_${ENV}.txt
VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Executing DB lsinventory command for $ENV"
		echo "<b>DB Pre Patch</b>" >> $summary_report_prepatch  
		echo "<table border="1">" >> $summary_report_prepatch  
		echo "<tr>" >> $summary_report_prepatch  
		echo "    <th>Timestamp</th>" >> $summary_report_prepatch 
		echo "    <th>Step</th>" >> $summary_report_prepatch
		echo "    <th>Status</th>" >> $summary_report_prepatch 
		echo "    <th>Details</th>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		
		echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>DB Prepatching step 1: Execute lsinventory command</td>" >> $summary_report_prepatch
		echo "    <td>Failure</td>" >> $summary_report_prepatch 
		echo "    <td></td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		
		echo "" >> $master_log_prepatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
		echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_prepatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
		echo "`date`|Prepatching step 1: Execute DB lsinventory command |Failure      | " >> $master_log_prepatch
		cat $master_log_prepatch	
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Executing DB lsinventory command for $ENV"
	 # cd $ORACLE_HOME/cfgtoollogs/opatch/lsinv
	 # filename=`ls | grep ${lsinvDate}`
	 filename=`grep "Lsinventory Output file location " ${OUTPUT}/lsinventory_prepatch_${ENV}.txt | cut -d":" -f2`
	 echo $filename
	 
	 mkdir ${PREPATCHDIR}
	 cp $filename ${PREPATCHDIR}
	 echo "$DateTime: Copied lsinventory file to ${PREPATCHDIR}"
	 ls -ltr ${PREPATCHDIR}
	 	echo "<b>DB Pre Patch</b>" >> $summary_report_prepatch  
		echo "<table border="1">" >> $summary_report_prepatch  
		echo "<tr>" >> $summary_report_prepatch  
		echo "    <th>Timestamp</th>" >> $summary_report_prepatch 
		echo "    <th>Step</th>" >> $summary_report_prepatch
		echo "    <th>Status</th>" >> $summary_report_prepatch 
		echo "    <th>Details</th>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		
		echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>DB Prepatching step 1: Execute DB lsinventory command</td>" >> $summary_report_prepatch
		echo "    <td>Success</td>" >> $summary_report_prepatch 
		echo "    <td>Copied lsinventory file $filename to ${PREPATCHDIR}</td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		echo "" >> $master_log_prepatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
		echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_prepatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
		echo "`date`|Prepatching step 1: Execute DB lsinventory command |Success      |Copied lsinventory file $filename to ${PREPATCHDIR} " >> $master_log_prepatch
 fi

echo ""
echo ""

#Prepatching step 2: Backup of oraInventory
 echo "####################################################################################################"
 echo "DB Prepatching step 2: Backup of oraInventory"
 echo "####################################################################################################"
 echo ""
 echo ""
 INVLOC=`grep inventory_loc $ORACLE_HOME/oraInst.loc | cut -d"=" -f2`
 echo "DB Oracle Inventory location: $INVLOC"
tar -cvf ${DBBACKUPDIR}/INV_BACKUPS/${Day1}_${ENV}_${CHNGID}_PREPATCH_OraInventory.tar ${INVLOC} --exclude=$INVLOC/logs
 VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Backup of DB oraInventory for $ENV"
	  	echo "<tr>" >> $summary_report_prepatch  
		echo "    <td>`date`</td>" >> $summary_report_prepatch 
		echo "    <td>DB Prepatching step 2: Backup of oraInventory</td>" >> $summary_report_prepatch
		echo "    <td>Failure</td>" >> $summary_report_prepatch 
		echo "    <td></td>" >> $summary_report_prepatch 
		echo "</tr>" >> $summary_report_prepatch 
		echo "`date`|DB Prepatching step 2: Backup of DB oraInventory |Failure      | " >> $master_log_prepatch
		cat $master_log_prepatch
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Backup of oraInventory for $ENV"
	 ls -ltr ${DBBACKUPDIR}/INV_BACKUPS/
	 echo "<tr>" >> $summary_report_prepatch  
	 echo "    <td>`date`</td>" >> $summary_report_prepatch 
	 echo "    <td>DB Prepatching step 2: Backup of oraInventory</td>" >> $summary_report_prepatch
	 echo "    <td>Success</td>" >> $summary_report_prepatch 
	 echo "    <td>Copied ${Day1}_${ENV}_PREPATCH_OraInventory.tar.gz to ${BACKUPDIR}/INV_BACKUPS/</td>" >> $summary_report_prepatch 
	 echo "</tr>" >> $summary_report_prepatch 
	 echo "</table>" >> $summary_report_prepatch 
	 echo "<br>" >> $summary_report_prepatch 
	 echo "`date`|DB Prepatching step 2: Backup of DB oraInventory |Success      |Copied ${Day1}_${ENV}_PREPATCH_OraInventory.tar.gz to ${DBBACKUPDIR}/INV_BACKUPS/ " >> $master_log_prepatch
	 echo "-----------------------------------------------------------------------------------------------------" >> $master_log_prepatch
	 
 fi

 #cat $master_log_prepatch
 
echo "##############################################################################################################################################" >> $master_log_prepatch
echo ""
echo ""
echo ""
		echo "Checking the last execution status for cloud control jobs for $ENV"
		echo "$DateTime: Checking the last execution status for cloud control jobs for $ENV" >> $master_log_prepatch
		echo "<b>$DateTime:Checking Last Execution status for Cloud control backup jobs </b>" >> $summary_report_prepatch
		echo "<br>" >> $summary_report_prepatch
		
		HOST=`hostname`
		echo "Checking EMCLI status on the server"
		${EMCLIHOME}/emcli get_jobs -name="QA1_CONSOL_BACKUP" -owner="SW_JOBADMIN" > ${OUTPUT}/emcli_test.txt
		RET=$?
		echo $RET
		if [ $RET -ne 0 ];then
			  echo "$DateTime: ERROR - EMCLI setup on ${HOST} is lost"
			  echo "$DateTime: ERROR - EMCLI setup on ${HOST} is lost" >> $master_log_prepatch
			  echo "$DateTime: ERROR - Unable to check the last execution status of Cloud control jobs " >> $master_log_prepatch
			  echo "<b>$DateTime: ERROR - EMCLI setup on ${HOST} is lost</b>" >> $summary_report_prepatch
			  echo "<b>$DateTime: ERROR - Unable to check the last execution status of Cloud control jobs </b>" >> $summary_report_prepatch
			  echo "<br>" >> $summary_report_prepatch
			  echo "Execute the below command and provide SW_JOBADMIN password when prompted"
			  echo "${EMCLIHOME}/emcli setup -url=https://prod-em.sherwin.com/em -username=sw_jobadmin -trustall -autologin"
			  echo ""
			  echo "##############################################################################################################################################" >> $master_log_prepatch
			  cat $master_log_prepatch
			  exit 1;
		else	  
				echo "EMCLI setup on ${HOST} is valid"
				echo "$DateTime: EMCLI setup on ${HOST} is valid" >> $master_log_prepatch
				echo "------------------------------------------------------------------------------" >> $master_log_prepatch
				echo ""
				echo "Listing backups for $ENV..."
				echo ""
				cat ${CTRLLOC}/${ENV}_status_all_DB_backup_jobs.cfg
				echo ""
				echo "Fetching the last execution status of jobs"
				echo ""
				echo "<b>Last Execution status for Cloud control backup jobs</b>" >> $summary_report_prepatch
				echo "<table border="1">" >> $summary_report_prepatch
				echo "<tr>" >> $summary_report_prepatch  
				echo "    <th>Timestamp</th>" >> $summary_report_prepatch 
				echo "    <th>Step</th>" >> $summary_report_prepatch
				echo "    <th>Job name</th>" >> $summary_report_prepatch 
				echo "    <th>Status</th>" >> $summary_report_prepatch 
				echo "    <th>Details</th>" >> $summary_report_prepatch 
				echo "</tr>" >> $summary_report_prepatch 
				for n in `cat ${CTRLLOC}/${ENV}_status_all_DB_backup_jobs.cfg`
				do
				jobx=`echo $n | grep RMAN`
				ret=$?
				if [ $ret -eq 0 ];then
				
					san_job=`echo $n | tr "_" " "`
					${EMCLIHOME}/emcli get_jobs -name="${san_job}" -owner="SW_JOBADMIN" > ${OUTPUT}/job_exec_${n}.txt	
					tail -2 ${OUTPUT}/job_exec_${n}.txt | head -1 > ${OUTPUT}/last_job_exec_${n}.txt	
								
					fromdate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $10}'`
					fromtime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $11}'`
					todate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $12}'`
					totime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $13}'`
					status=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $15}'`
					
					if [ $status = "Failed" ];then
						grep "$fromdate" ${OUTPUT}/job_exec_${n}.txt | tr " " "#"  > ${OUTPUT}/job_exec_fail_${n}.txt
						for i in `cat ${OUTPUT}/job_exec_fail_${n}.txt`
						do
							fromdate=`echo $i | tr "#" " " | awk '{print $10}'`
							fromtime=`echo $i | tr "#" " " | awk '{print $11}'`
							todate=`echo $i | tr "#" " " | awk '{print $12}'`
							totime=`echo $i | tr "#" " " | awk '{print $13}'`
							status=`echo $i | tr "#" " " | awk '{print $15}'`
						
							echo "Last execution status for backup ${n}: ${status}"
							echo "Execution Start Time: $fromdate $fromtime "
							echo "Execution End Time: $todate $totime "
							echo "Last execution status for backup ${n}: ${status}" >> $master_log_prepatch
							echo "Execution Start Time: $fromdate $fromtime " >> $master_log_prepatch 
							echo "Execution End Time: $todate $totime " >> $master_log_prepatch
							echo "<tr>" >> $summary_report_prepatch
							echo "    <td>`date`</td>" >> $summary_report_prepatch
							echo "    <td>DB Prepatching step 3: Last Execution status for Cloud control backup jobs </td>" >> $summary_report_prepatch
							echo "    <td>$n</td>" >> $summary_report_prepatch
							echo "    <td>${status}</td>" >> $summary_report_prepatch
							echo "    <td>Execution Start Time: $fromdate $fromtime , Execution End Time: $todate $totime </td>" >> $summary_report_prepatch
							echo "</tr>" >> $summary_report_prepatch
							echo "<br>" >> $summary_report_prepatch
							echo ""
						done
					else
					
						echo "Last execution status for backup ${n}: ${status}"
						echo "Execution Start Time: $fromdate $fromtime "
						echo "Execution End Time: $todate $totime "
						
						echo "Last execution status for backup ${n}: ${status}" >> $master_log_prepatch
						echo "Execution Start Time: $fromdate $fromtime " >> $master_log_prepatch 
						echo "Execution End Time: $todate $totime " >> $master_log_prepatch
						echo "<tr>" >> $summary_report_prepatch
						echo "    <td>`date`</td>" >> $summary_report_prepatch
						echo "    <td>DB Prepatching step 3: Last Execution status for Cloud control backup jobs </td>" >> $summary_report_prepatch
						echo "    <td>$n</td>" >> $summary_report_prepatch
						echo "    <td>${status}</td>" >> $summary_report_prepatch
						echo "    <td>Execution Start Time: $fromdate $fromtime , Execution End Time: $todate $totime </td>" >> $summary_report_prepatch
						echo "</tr>" >> $summary_report_prepatch
						echo "<br>" >> $summary_report_prepatch
						echo ""
					fi
					
					
				elif [ $ret -eq 1 ];then
					
					${EMCLIHOME}/emcli get_jobs -name="${n}" -owner="SW_JOBADMIN" > ${OUTPUT}/job_exec_${n}.txt	
					tail -2 ${OUTPUT}/job_exec_${n}.txt | head -1 > ${OUTPUT}/last_job_exec_${n}.txt	
						
					export fromdate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $5}'`
					export fromtime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $6}'`
					export todate=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $7}'`
					export totime=`cat ${OUTPUT}/last_job_exec_${n}.txt |  awk '{print $8}'`
					export status=`cat ${OUTPUT}/last_job_exec_${n}.txt | awk '{print $10}'`
					
					if [ "$status" = "Failed" ];then

						echo "Last execution status for backup ${n}: ${status}"
						echo "Execution Start Time: $fromdate $fromtime "
						echo "Execution End Time: $todate $totime "
						echo ""
						echo "Checking & listing other executions which were tried for this day..."
						
						echo "Last execution status for backup ${n}: ${status}" >> $master_log_prepatch
						echo "Execution Start Time: $fromdate $fromtime " >> $master_log_prepatch 
						echo "Execution End Time: $todate $totime " >> $master_log_prepatch
						echo "" >> $master_log_prepatch
						echo "Checking if other executions were tried for this day..." >> $master_log_prepatch
						echo "<tr>" >> $summary_report_prepatch
						echo "    <td>`date`</td>" >> $summary_report_prepatch
						echo "    <td>DB Prepatching step 3: Last Execution status for Cloud control backup jobs </td>" >> $summary_report_prepatch
						echo "    <td>$n</td>" >> $summary_report_prepatch
						echo "    <td>${status}</td>" >> $summary_report_prepatch
						echo "    <td>Execution Start Time: $fromdate $fromtime , Execution End Time: $todate $totime </td>" >> $summary_report_prepatch
						echo "</tr>" >> $summary_report_prepatch
						
						echo "<br>" >> $summary_report_prepatch
						echo "<b>Checking if other executions were tried for this day..." >> $summary_report_prepatch
						echo ""
						
						grep "$fromdate" ${OUTPUT}/job_exec_${n}.txt | tr " " "#" > ${OUTPUT}/job_exec_fail_${n}.txt
						for i in `cat ${OUTPUT}/job_exec_fail_${n}.txt`
						do
							fa_fromdate=`echo $i | tr "#" " " | awk '{print $5}'`
							fa_fromtime=`echo $i | tr "#" " " | awk '{print $6}'`
							fa_todate=`echo $i | tr "#" " " | awk '{print $7}'`
							fa_totime=`echo $i | tr "#" " " | awk '{print $8}'`
							fa_status=`echo $i | tr "#" " " | awk '{print $10}'`
						
							echo "Last execution status for backup ${n}: ${fa_status}"
							echo "Execution Start Time: $fa_fromdate $fa_fromtime "
							echo "Execution End Time: $fa_todate $fa_totime "
							echo "Last execution status for backup ${n}: ${fa_status}" >> $master_log_prepatch
							echo "Execution Start Time: $fa_fromdate $fa_fromtime " >> $master_log_prepatch 
							echo "Execution End Time: $fa_todate $fa_totime " >> $master_log_prepatch
							echo "<tr>" >> $summary_report_prepatch
							echo "    <td>`date`</td>" >> $summary_report_prepatch
							echo "    <td>DB Prepatching step 3: Last Execution status for Cloud control backup jobs </td>" >> $summary_report_prepatch
							echo "    <td>$n</td>" >> $summary_report_prepatch
							echo "    <td>${fa_status}</td>" >> $summary_report_prepatch
							echo "    <td>Execution Start Time: $fa_fromdate $fa_fromtime , Execution End Time: $fa_todate $fa_totime </td>" >> $summary_report_prepatch
							echo "</tr>" >> $summary_report_prepatch
							echo ""
						done
					else
					
						echo "Last execution status for backup ${n}: ${status}"
						echo "Execution Start Time: $fromdate $fromtime "
						echo "Execution End Time: $todate $totime "
						
						echo "Last execution status for backup ${n}: ${status}" >> $master_log_prepatch
						echo "Execution Start Time: $fromdate $fromtime " >> $master_log_prepatch 
						echo "Execution End Time: $todate $totime " >> $master_log_prepatch
						echo "<tr>" >> $summary_report_prepatch
						echo "    <td>`date`</td>" >> $summary_report_prepatch
						echo "    <td>DB Prepatching step 3: Last Execution status for Cloud control backup jobs </td>" >> $summary_report_prepatch
						echo "    <td>$n</td>" >> $summary_report_prepatch
						echo "    <td>${status}</td>" >> $summary_report_prepatch
						echo "    <td>Execution Start Time: $fromdate $fromtime , Execution End Time: $todate $totime </td>" >> $summary_report_prepatch
						echo "</tr>" >> $summary_report_prepatch
						echo ""
					fi
												
				else
				
					echo "Invalid job name. Check manually"
				
				fi	
		
				done
				echo ""
				echo "#################################################################################################################################################" >> $master_log_prepatch
				cat $master_log_prepatch
		fi	
				
echo "<br>" >> $summary_report_prepatch
echo ""
echo ""
echo "Prepatch Steps Summary Report: $summary_report_prepatch"
echo "Prepatch Steps Summary Log: $master_log_prepatch"
				
echo ""
echo ""
echo "Redirecting to the options screen.."
echo ""
 
 DBoptionsScreen

}


function DBpostPatchSteps() {

read -p "DBA conducting the Maintenance (enter your sherwin id) " EMPID
read -p "Enter the Change Log Request ID : " CHNGID
echo "DBA conducting this step is "$EMPID
echo "Change Log request ID is "$CHNGID

if [[ "$CHNGID" = "" ]]; then
	echo "No change ID input for "$ENV
	
	export summary_report_postpatch=${PPLOGDIR}/${ENV}_DB_PATCH_report_POSTPATCH_${EMPID}_${DateTime}.html
	export master_log_postpatch=${PPLOGDIR}/${ENV}_DB_PATCH_Master_Log_POSTPATCH_${EMPID}_${DateTime}.log
	
else
	echo "Input file $INPUT_FILE sourced in for "$ENV
	echo "Change Log Request ID is "$CHNGID
	
	export summary_report_postpatch=${PPLOGDIR}/${ENV}_DB_PATCH_report_POSTPATCH_${CHNGID}_${DateTime}.html
	export master_log_postpatch=${PPLOGDIR}/${ENV}_DB_PATCH_Master_Log_POSTPATCH_${CHNGID}_${DateTime}.log
	
fi
echo "----------"
echo "<br>" >> $summary_report_postpatch
echo "<table border="1">" >> $summary_report_postpatch  
echo "<tr>" >> $summary_report_postpatch  
echo "     <td><b>DBA</b></td>" >> $summary_report_postpatch  
echo "	   <td>$EMPID</td>" >> $summary_report_postpatch
echo "</tr>" >> $summary_report_postpatch  
echo "<tr>" >> $summary_report_postpatch 
echo "     <td><b>Step performed</b></td>" >> $summary_report_postpatch  
echo "	   <td>DB PostPatch Steps</td>" >> $summary_report_postpatch    
echo "</tr>" >> $summary_report_postpatch  
echo "<tr>" >> $summary_report_postpatch  
echo "     <td><b>Date</b></td>" >> $summary_report_postpatch  
echo "	   <td>`date`</td>" >> $summary_report_postpatch  
echo "</tr>" >> $summary_report_postpatch 
echo "<tr>" >> $summary_report_postpatch
echo "     <td><b>Change Log Request ID</b></td>" >> $summary_report_postpatch
echo "	   <td>$CHNGID</td>" >> $summary_report_postpatch
echo "</tr>" >> $summary_report_postpatch 
echo "<tr>" >> $summary_report_postpatch
echo "     <td><b>Method</b></td>" >> $summary_report_postpatch
echo "	   <td>Manual</td>" >> $summary_report_postpatch
echo "</tr>" >> $summary_report_postpatch
echo "</table>" >> $summary_report_postpatch  
echo "<br>" >> $summary_report_postpatch 
echo "<br>" >> $summary_report_postpatch 


echo "#################################################################################################################################################" >> $master_log_postpatch
echo "DBA: $EMPID" >> $master_log_postpatch
echo "Step performed: DB PostPatch Steps" >> $master_log_postpatch
echo "Date: `date`" >> $master_log_postpatch
echo "Change Log Request ID: $CHNGID" >> $master_log_postpatch
echo "Method: Manual" >> $master_log_postpatch
echo "#################################################################################################################################################" >> $master_log_postpatch

#PostPatching step 1: lsinventory command
echo "####################################################################################################"
echo "DB PostPatching step 1: lsinventory command"
echo "####################################################################################################"echo ""
echo ""
cd $ORACLE_HOME/OPatch
echo "./opatch lsinventory"
export TodayDate=`date +%d_%m_%Y`
export POSTPATCHDIR=${DBBACKUPDIR}/POSTPATCH_${ENV}_${CHNGID}_${TodayDate}
lsinvDate=`date +%Y-%m-%d_%H-%M`
./opatch lsinventory > ${OUTPUT}/lsinventory_prepatch_${ENV}.txt
VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Executing DB lsinventory command for $ENV"
		echo "<br>" >> $summary_report_postpatch
		echo "<b>DB Post Patch</b>" >> $summary_report_postpatch  
		echo "<table border="1">" >> $summary_report_postpatch  
		echo "<tr>" >> $summary_report_postpatch  
		echo "    <th>Timestamp</th>" >> $summary_report_postpatch 
		echo "    <th>Step</th>" >> $summary_report_postpatch
		echo "    <th>Status</th>" >> $summary_report_postpatch 
		echo "    <th>Details</th>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		
		echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>DB PostPatching step 1: Execute lsinventory command</td>" >> $summary_report_postpatch
		echo "    <td>Failure</td>" >> $summary_report_postpatch 
		echo "    <td></td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		
		echo "" >> $master_log_postpatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
		echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_postpatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
		echo "`date`|PostPatching step 1: Execute DB lsinventory command |Failure      | " >> $master_log_postpatch
		cat $master_log_postpatch	
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Executing DB lsinventory command for $ENV"
	 # cd $ORACLE_HOME/cfgtoollogs/opatch/lsinv
	 # filename=`ls | grep ${lsinvDate}`
	 
	 filename=`grep "Lsinventory Output file location " ${OUTPUT}/lsinventory_postpatch_${ENV}.txt | cut -d":" -f2`
	 echo $filename
	 
	 mkdir ${POSTPATCHDIR}
	 cp $filename ${POSTPATCHDIR}
	 echo "$DateTime: Copied lsinventory file to ${POSTPATCHDIR}"
	 ls -ltr ${POSTPATCHDIR}
	 	echo "<br>" >> $summary_report_postpatch
		echo "<b>DB Post Patch</b>" >> $summary_report_postpatch  
		echo "<table border="1">" >> $summary_report_postpatch  
		echo "<tr>" >> $summary_report_postpatch  
		echo "    <th>Timestamp</th>" >> $summary_report_postpatch 
		echo "    <th>Step</th>" >> $summary_report_postpatch
		echo "    <th>Status</th>" >> $summary_report_postpatch 
		echo "    <th>Details</th>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		
		echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>DB PostPatching step 1: Execute DB lsinventory command</td>" >> $summary_report_postpatch
		echo "    <td>Success</td>" >> $summary_report_postpatch 
		echo "    <td>Copied lsinventory file $filename to ${POSTPATCHDIR}</td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "" >> $master_log_postpatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
		echo "Timestamp                   |Step                                            |Status       |Details  " >> $master_log_postpatch
		echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
		echo "`date`|PostPatching step 1: Execute DB lsinventory command |Success      |Copied lsinventory file $filename to ${POSTPATCHDIR} " >> $master_log_postpatch
 fi

echo ""
echo ""

#PostPatching step 2: Backup of oraInventory
 echo "####################################################################################################"
 echo "DB PostPatching step 2: Backup of oraInventory"
 echo "####################################################################################################"
 echo ""
 echo ""
 INVLOC=`grep inventory_loc $ORACLE_HOME/oraInst.loc | cut -d"=" -f2`
 echo "DB Oracle Inventory location: $INVLOC"
tar -cvf ${DBBACKUPDIR}/INV_BACKUPS/${Day1}_${ENV}_${CHNGID}_POSTPATCH_OraInventory.tar ${INVLOC} --exclude=$INVLOC/logs
 VRET=$?
echo $VRET
 if [ $VRET -ne 0 ];then
	  echo "$DateTime: ERROR - Backup of DB oraInventory for $ENV"
	  	echo "<tr>" >> $summary_report_postpatch  
		echo "    <td>`date`</td>" >> $summary_report_postpatch 
		echo "    <td>DB PostPatching step 2: Backup of oraInventory</td>" >> $summary_report_postpatch
		echo "    <td>Failure</td>" >> $summary_report_postpatch 
		echo "    <td></td>" >> $summary_report_postpatch 
		echo "</tr>" >> $summary_report_postpatch 
		echo "`date`|DB PostPatching step 2: Backup of DB oraInventory |Failure      | " >> $master_log_postpatch
		cat $master_log_postpatch
		exit 1;
 else
	 echo "$DateTime: SUCCESS - Backup of oraInventory for $ENV"
	 ls -ltr ${DBBACKUPDIR}/INV_BACKUPS/
	 echo "<tr>" >> $summary_report_postpatch  
	 echo "    <td>`date`</td>" >> $summary_report_postpatch 
	 echo "    <td>DB Prepatching step 2: Backup of oraInventory</td>" >> $summary_report_postpatch  
	 echo "    <td>Success</td>" >> $summary_report_postpatch  
	 echo "    <td>Copied ${Day1}_${ENV}_PREPATCH_OraInventory.tar.gz to ${BACKUPDIR}/INV_BACKUPS/</td>" >> $summary_report_postpatch  
	 echo "</tr>" >> $summary_report_postpatch  
	 echo "`date`|DB Postpatching step 2: Backup of DB oraInventory |Success      |Copied ${Day1}_${ENV}_PREPATCH_OraInventory.tar.gz to ${DBBACKUPDIR}/INV_BACKUPS/ " >> $master_log_postpatch
	 echo "-----------------------------------------------------------------------------------------------------" >> $master_log_postpatch
 fi

 cat $master_log_postpatch

echo ""
echo ""
echo "Postpatch Steps Summary Report: $summary_report_postpatch"
echo "Postpatch Steps Summary Log: $master_log_postpatch"
export summary_report_DB=${PPLOGDIR}/${ENV}_DB_PATCH_Summary_report_${CHNGID}_${Day}.html
export master_log_DB=${PPLOGDIR}/${ENV}_DB_PATCH_Master_Log_${CHNGID}_${Day}.log
echo "<html>" > $summary_report_DB
echo "<h2>$ENV: PATCH SUMMARY REPORT</h2>" >> $summary_report_DB  

ls -ltr ${PPLOGDIR}/${ENV}_DB_PATCH_report_*${CHNGID}* | awk '{print $9}' > ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt

if [ -s ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt ]; then
	echo " "
	echo " "
	
	echo "Patch summary report: $summary_report_DB"
	for i in `cat ${PPLOGDIR}/patch_reports_${CHNGID}_${ENV}.txt`
	do 
	#filnm=`echo $i | awk '{print $9}'`
	cat $i >> $summary_report_DB
	done
else
	echo " "
	echo " "
	echo "No other activities performed for this change id"
fi

echo "$ENV: PATCH LOG" > $master_log_DB
 echo "" >> $master_log_DB

ls -ltr ${PPLOGDIR}/${ENV}_DB_PATCH_Master_Log_*${CHNGID}* | awk '{print $9}' > ${PPLOGDIR}/patch_step_logs_${CHNGID}_${ENV}.txts

if [ -s ${PPLOGDIR}/patch_step_logs_${CHNGID}_${ENV}.txt ]; then
	echo " "
	echo " "
	echo "Patch Master Log: $master_log"
	for i in `cat ${PPLOGDIR}/patch_step_logs_${ENV}.txt`
	do 
	#filnme=`echo $i | awk '{print $9}'`
	cat $i >> $master_log_DB
	done
else
	echo " "
	echo " "
	echo "No other activities performed for this change id"
fi

echo "<br>" >> $summary_report_postpatch				
echo ""
echo ""
echo "Redirecting to the options screen.."
echo ""

 DBoptionsScreen

}


function HealthCheckFunc() {

echo "#################################################################################################################################################"
echo  "Checking emcli status.."
$EMCLIHOME/emcli describe_job -name="QA1_CONSOL_BACKUP" > ${OUTPUT}/emcli_test.txt
RET=$?
echo ""
	if [ $RET -ne 0 ];then
		echo ""
		echo "$DateTime: ERROR: emcli setup on server is lost, follow the instruction below to execute Cloud control jobs, else only backup action which will work is 3. Execute backup immediately from this server"
		echo "Execute $EMCLIHOME/emcli setup -url=https://prod-em.sherwin.com/em -username=sw_jobadmin -trustall -autologin"
		echo "Provide the password for SW_JOBADMIN when prompted"
		echo ""
		exit 1;
	else
		echo ""
		echo "$DateTime: SUCCESS: emcli setup on server is valid"
		echo ""
	fi
echo "#################################################################################################################################################"

echo "Action to be performed"
echo ""
echo "1. Execute EPM Health check immediately from Cloud control.
2. Schedule EPM health check execution from Cloud control."

echo ""
		echo -n "Option: "
		read usroption
		if [ $usroption -eq 1 ]; then
			echo "Option $usroption selected, Executing EPM health check for $ENV immediately from Cloud control.."
			if [ "$ENV" == "DEV" ]; then
				export jobname="DEV_HEALTHCHECK_REPORT"
				echo "EPM health check for this environment is $jobname"
			elif [ "$ENV" == "PJ" ]; then
				export jobname="PJ_HEALTHCHECK_REPORT"
				echo "EPM health check for this environment is $jobname"
			elif [ "$ENV" == "QA1" ]; then
				export jobname="QA_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either QA1 or QA2 sufficient"
			elif [ "$ENV" == "QA2" ]; then
				export jobname="QA_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either QA1 or QA2 sufficient"
			elif [ "$ENV" == "PROD1" ]; then
				export jobname="PROD_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either PROD1 or PROD2 sufficient"
			elif [ "$ENV" == "PROD2" ]; then
				export jobname="PROD_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either PROD1 or PROD2 sufficient"	
			elif [ "$ENV" == "INFRA1" ];then
				export jobname="INFRA_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either INFRA1 or INFRA2 sufficient"
			elif [ "$ENV" == "INFRA2" ];then
				export jobname="INFRA_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either INFRA1 or INFRA2 sufficient"
			else
				echo "unknown environment...exiting..."
				exit 1;
			fi	
			
				echo ${jobname}
				DateTime1=`date +%d%m%y%H%M%S`
				##Get Cloud control job description#
				##Fields to be changed name,variable.default_shell_command,schedule.startTime,schedule.frequency,schedule.gracePeriod##
			
				$EMCLIHOME/emcli describe_job -name=${jobname} > ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Describe cloud control job ${jobname} failed"
					exit 1;
				else
					echo "$DateTime: SUCCESS - Describe cloud control job ${jobname} successful"
				fi	
				
								
				CC_JOB_INPUTFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				export JOB_SCH_DATE=$jobschdate
				echo $JOB_SCH_DATE
				export CC_JOB_NAME=${jobname}_${DateTime1}
				echo "Backup of ${OUTPUT}/${jobname}_describe_${DateTime1}.txt taken as ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt"
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt
				sed -i "/name=/ c\name=${CC_JOB_NAME}" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.startTime/d" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt 
				sed -i "/schedule.frequency/ c\schedule.frequency=IMMEDIATE" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.gracePeriod/ c\schedule.gracePeriod=15" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.days/d" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt $CC_JOB_INPUTFILE
				
				echo "Health check ${jobname} one time execution creation in progress.."
				echo "$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file=\"property_file:$CC_JOB_INPUTFILE\""
				$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:$CC_JOB_INPUTFILE"
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
					
				else
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
					
					$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
					JOBID=`head -2 $CC_JOB_NAME ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | tail -1 | awk '{print $3}'`
					SC=""""					
					echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
					
					$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					    
					else
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					   			   
					fi	
				fi	
			
		elif [ $usroption -eq 2 ]; then
			echo "Option $usroption selected, Schedule EPM health check execution for $ENV from Cloud control"
					if [ "$ENV" == "DEV" ]; then
				export jobname="DEV_HEALTHCHECK_REPORT"
				echo "EPM health check for this environment is $jobname"
			elif [ "$ENV" == "PJ" ]; then
				export jobname="PJ_HEALTHCHECK_REPORT"
				echo "EPM health check for this environment is $jobname"
			elif [ "$ENV" == "QA1" ]; then
				export jobname="QA_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either QA1 or QA2 sufficient"
			elif [ "$ENV" == "QA2" ]; then
				export jobname="QA_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either QA1 or QA2 sufficient"
			elif [ "$ENV" == "PROD1" ]; then
				export jobname="PROD_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either PROD1 or PROD2 sufficient"
			elif [ "$ENV" == "PROD2" ]; then
				export jobname="PROD_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either PROD1 or PROD2 sufficient"	
			elif [ "$ENV" == "INFRA1" ];then
				export jobname="INFRA_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either INFRA1 or INFRA2 sufficient"
			elif [ "$ENV" == "INFRA2" ];then
				export jobname="INFRA_HEALTHCHECK_REPORT_PARALLEL"
				echo "EPM health check for this environment is ${jobname}..Execution from either INFRA1 or INFRA2 sufficient"
			else
				echo "unknown environment...exiting..."
				exit 1;
			fi
			
			echo -n "Enter schedule date & time in format YYYY-MM-DD HH:MM:SS (Ex. 2017-05-01 23:30:00) : "
			echo ""
			read jobschdate
			echo "$jobname one time execution to be scheduled at $jobschdate"
			echo $jobname
			CC_JOB_INPUTFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
			CC_JOB_TEMPFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
			export JOB_SCH_DATE=$jobschdate
			echo $JOB_SCH_DATE
			DateTime1=`date +%d%m%y%H%M%S`
				
				##Get Cloud control job description#
				##Fields to be changed name,variable.default_shell_command,schedule.startTime,schedule.frequency,schedule.gracePeriod##
			
				$EMCLIHOME/emcli describe_job -name=$jobname > ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Describe cloud control job ${jobname} failed"
					exit 1;
				else
					echo "$DateTime: SUCCESS - Describe cloud control job ${jobname} successful"
				fi	
				
				CC_JOB_INPUTFILE=${OUTPUT}/${jobname}_template_${DateTime1}.txt
				
				export CC_JOB_NAME=${jobname}_${DateTime1}
				
				echo "Backup of ${OUTPUT}/${jobname}_describe_${DateTime1}.txt taken as ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt"
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt ${OUTPUT}/${jobname}_describe_bkp_${DateTime1}.txt
				sed -i "/name=/ c\name=${CC_JOB_NAME}" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.startTime/ c\schedule.startTime=$JOB_SCH_DATE" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt 
				sed -i "/schedule.frequency/ c\schedule.frequency=ONCE" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.gracePeriod/ c\schedule.gracePeriod=15" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				sed -i "/schedule.days/d" ${OUTPUT}/${jobname}_describe_${DateTime1}.txt
				cp ${OUTPUT}/${jobname}_describe_${DateTime1}.txt $CC_JOB_INPUTFILE
				
				
				export CC_JOB_NAME=${jobname}_${DateTime1}
				
				echo "Health check ${jobname} one time execution being scheduled at $jobschdate" 
				
				$EMCLIHOME/emcli create_job -name=${CC_JOB_NAME} -input_file="property_file:$CC_JOB_INPUTFILE"
				RSTAT=$?
				echo $RSTAT
				if [ $RSTAT -ne 0 ];then
					echo "$DateTime: ERROR - Adding cloud control job ${CC_JOB_NAME}"
					
				else
					echo "$DateTime: SUCCESS - Added cloud control job ${CC_JOB_NAME}"
									
					$EMCLIHOME/emcli get_jobs -name="$CC_JOB_NAME" -owner="SW_JOBADMIN" > ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt
					JOBID=`head -2 ${OUTPUT}/${CC_JOB_NAME}_${DateTime}_jobid.txt | tail -1 | awk '{print $3}'`
					SC=""""					
					echo "JOBID for JOB $CC_JOB_NAME = $JOBID"
				
					$EMCLIHOME/emcli grant_privs -name="PROJ_HYPERION" -privilege=${SC}"VIEW_JOB;${SC}${JOBID}${SC}"
					RET=$?
					if [ $RET -ne 0 ];then
					   echo "$DateTime: ERROR - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					    
					else
					   echo "$DateTime: SUCCESS - adding privileges to proj_hyperion role for job $CC_JOB_NAME"
					  		   
					fi	
				fi		
		else
			echo "Invalid option..Exiting script.."
			exit 1;
		fi
}


function optionsScreen() {

echo "Action to be performed"
echo ""
echo "1. EPM OPatch Prerequisite Check
2. EPM Backup
3. EPM Prepatch Steps (EPM lsinventory, EPM System registry, EPM deployment report, Backup of oraInventory, Backup of critical files, Last execution status of Cloud control jobs)
4. EPM Post Patching Steps (EPM lsinventory, EPM System registry, EPM deployment report, Backup of oraInventory, Backup of critical files & Compares Critical files with Prepatch folder)
5. Middleware oracle_common patching (Prerequisite check, Prepatch steps, Postpatch steps)
6. Middleware OHS patching (Prerequisite check, Prepatch steps, Postpatch steps)
7. Health Check
8. Exit script"
echo ""
		echo -n "Option: "
		read usroption
		if [ $usroption -eq 1 ]; then
			echo "Option $usroption selected, OPatch Prerequisite Check starting.."
			buildPREREQ

		elif [ $usroption -eq 2 ]; then	
			echo "Option $usroption selected"
			BACKUPS

		elif [ $usroption -eq 3 ]; then	
			echo "Option $usroption selected"
			prePatchSteps

		elif [ $usroption -eq 4 ]; then	
			echo "Option $usroption selected"
			postPatchSteps
		elif [ $usroption -eq 5 ]; then	
			echo "Option $usroption selected"
			MWHOME_oracle_common
		elif [ $usroption -eq 6 ]; then	
			echo "Option $usroption selected"
			MWHOME_ohs	
		elif [ $usroption -eq 7 ]; then	
			echo "Option $usroption selected"
			HealthCheckFunc		
		elif [ $usroption -eq 8 ]; then	
			echo "Option $usroption selected"
			echo "Option $usroption selected. Exiting script..."
			echo ""
			echo "####################################################################################################"
			echo "`date`: Finish"
			echo "####################################################################################################"
			exit 0;		
		else 
			echo "ERROR: Invalid option"
			echo "Exiting script"
			exit 1;
		fi	

}


function DBoptionsScreen() {

echo "Action to be performed"
echo ""
echo "1. DB OPatch Prerequisite Check
2. DB Backup
3. DB Prepatch Steps (DB lsinventory, Backup of oraInventory, Last execution status of Cloud control jobs)
4. DB Post Patching Steps (DB lsinventory, Backup of oraInventory)
5. Exit script"
echo ""
		echo -n "Option: "
		read usroption
		if [ $usroption -eq 1 ]; then
			echo "Option $usroption selected, OPatch Prerequisite Check starting.."
			DBbuildPREREQ

		elif [ $usroption -eq 2 ]; then	
			echo "Option $usroption selected"
			DBBACKUPS

		elif [ $usroption -eq 3 ]; then	
			echo "Option $usroption selected"
			DBprePatchSteps

		elif [ $usroption -eq 4 ]; then	
			echo "Option $usroption selected"
			DBpostPatchSteps

		elif [ $usroption -eq 5 ]; then	
			echo "Option $usroption selected"
			echo "Option $usroption selected. Exiting script..."
			echo ""
			echo "####################################################################################################"
			echo "`date`: Finish"
			echo "####################################################################################################"
			exit 0;		
		else 
			echo "ERROR: Invalid option"
			echo "Exiting script"
			exit 1;
		fi	

}



##MAIN##

if [[ "$ENV" = "PROD1" ]]; then
    
	if [ $HOSTNAME = "xlythq01-pub" ] && [ $OSUSER = "oracle" ]; then
		echo "Setting environment for server "$ENV
		echo ""
		echo ""
		. /home/oracle/hyperion_epm1.env
		export HOME=/home/oracle
		export BKPENVT="xlythq01-pub"
		export BKPENVT1="xlythq02-pub"
		export ENVT1="PROD2"	
		export LCMENV="PROD"
		export OTHR_NODE="xlythq02-pub.sherwin.com"
		export OSUSER=oracle
		export SCRIPTDIR=/hyp_util/scripts
		export BACKUPDIR=/global/ora_backup
		export GOLD_CRIT_FILE_DIR=/hyp_util/Gold_File_Dir/PROD1
		export JAVA_HOME=/hyp_util/emcli/jdk1.7.0_151
		optionsScreen
	else
		echo "ERROR: PROD1 environment should be executed on xlythq01-pub as oracle OS user. Exiting..."
		exit 1;
	fi	
	
elif [[ "$ENV" = "PROD2" ]]; then
	
	if [ $HOSTNAME = "xlythq02-pub" ] && [ $OSUSER = "oracle" ]; then
		echo "Setting environment for server "$ENV
		echo ""
		echo ""
		. /home/oracle/hyperion_epm1.env
		export HOME=/home/oracle
		export BKPENVT="xlythq02-pub"
		export BKPENVT1="xlythq01-pub"
		export ENVT1="PROD1"
		export LCMENV="PROD"
		export OTHR_NODE="xlythq01-pub.sherwin.com"
		export OSUSER=oracle
		export SCRIPTDIR=/hyp_util/scripts
		export BACKUPDIR=/global/ora_backup
		export GOLD_CRIT_FILE_DIR=/hyp_util/Gold_File_Dir/PROD2
		export JAVA_HOME=/hyp_util/emcli/jdk1.7.0_151
		optionsScreen
	else
		echo "ERROR: PROD2 environment should be executed on xlythq02-pub as oracle OS user. Exiting..."
		exit 1;
	fi	
	
elif [[ "$ENV" = "DR" ]]; then
	
	if [ $HOSTNAME = "xlytwv01-pub" ] && [ $OSUSER = "hypdr" ]; then
		echo "Setting environment for server "$ENV
		echo ""
		echo ""
		. /home/hypdr/hypdr.env
		export HOME=/home/hypdr
		export OSUSER=hypdr
		export BKPENVT="dr-xlytwv01-pub"
		export LCMENV="DR"
		export OSUSER=hypdr
		export SCRIPTDIR=/hyp_util/scripts
		export BACKUPDIR=/global/ora_backup
		export GOLD_CRIT_FILE_DIR=/hyp_util/Gold_File_Dir/DR
		export JAVA_HOME=$MIDDLEWARE_HOME/jdk1.7.0_171/
		optionsScreen
	else
		echo "ERROR: DR environment should be executed on xlytwv01-pub as hypdr OS user. Exiting..."
		exit 1;
	fi	
	
elif [ "$ENV" = "QA1" ] && [ $OSUSER = "oracle" ]; then	
	
	if [[ $HOSTNAME = "xlytwv01-pub" ]]; then
		echo "Setting environment for server "$ENV
		echo ""
		echo ""
		. /home/oracle/hyperion_epm1.env
		export HOME=/home/oracle
		export BKPENVT="xlytwv01-pub"
		export BKPENVT1="xlytwv02-pub"
		export ENVT1="QA2"
		export LCMENV="QA"
		export OTHR_NODE="xlytwv02-pub.sherwin.com"
		export OSUSER=oracle
		export SCRIPTDIR=/hyp_util/scripts
		export BACKUPDIR=/global/ora_backup
		export GOLD_CRIT_FILE_DIR=/hyp_util/Gold_File_Dir/QA1
		export JAVA_HOME=$MIDDLEWARE_HOME/jdk1.7.0_171/
		optionsScreen
	else
		echo "ERROR: QA1 environment should be executed on xlytwv01-pub as oracle OS user. Exiting..."
		exit 1;
	fi	
	
elif [[ "$ENV" = "QA2" ]]; then
	
	if [ $HOSTNAME = "xlytwv02-pub" ] && [ $OSUSER = "oracle" ]; then
		echo "Setting environment for server "$ENV
		echo ""
		echo ""
		. /home/oracle/hyperion_epm1.env
		export HOME=/home/oracle
		export ENVT1="QA1"
		export BKPENVT="xlytwv02-pub"
		export BKPENVT1="xlytwv01-pub"
		export LCMENV="QA"
		export OTHR_NODE="xlytwv01-pub.sherwin.com"
		export OSUSER=oracle
		export SCRIPTDIR=/hyp_util/scripts
		export BACKUPDIR=/global/ora_backup
		export GOLD_CRIT_FILE_DIR=/hyp_util/Gold_File_Dir/QA2
		export JAVA_HOME=$MIDDLEWARE_HOME/jdk1.7.0_171/
		optionsScreen
	else
		echo "ERROR: QA2 environment should be executed on xlytwv02-pub as oracle OS user. Exiting..."
		exit 1;
	fi	
	
	
elif [[ "$ENV" = "DEV" ]]; then
	
	if [ $HOSTNAME = "xlytwv02-pub" ] && [ $OSUSER = "hyperion" ]; then
		echo "Setting environment for server "$ENV
		. /home/hyperion/hyperion-dev.env
		echo ""
		echo ""
		export HOME=/home/hyperion
		export BKPENVT="dev-xlytwv02-pub"
		export LCMENV="DEV"
		export OSUSER=hyperion
		export SCRIPTDIR=/hyp_util/scripts
		export BACKUPDIR=/global/ora_backup
		export GOLD_CRIT_FILE_DIR=/hyp_util/Gold_File_Dir/DEV
		export JAVA_HOME=$MIDDLEWARE_HOME/jdk1.7.0_171/
		optionsScreen
	else
		echo "ERROR: DEV environment should be executed on xlytwv02-pub as hyperion OS user. Exiting..."
		exit 1;
	fi	
	
elif [[ "$ENV" = "PJ" ]]; then
	
	if [ $HOSTNAME = "xlytwv01-pub" ] && [ $OSUSER = "hyppj" ]; then
		echo "Setting environment for server "$ENV
		. /home/hyppj/hyperion-pj.env
		echo ""
		echo ""
		export HOME=/home/hyppj
		export BKPENVT="pj-xlytwv01-pub"
		export LCMENV="PJ"
		export OSUSER=hyppj
		export SCRIPTDIR=/hyp_util/scripts
		export BACKUPDIR=/global/ora_backup
		export GOLD_CRIT_FILE_DIR=/hyp_util/Gold_File_Dir/PJ
		export JAVA_HOME=$MIDDLEWARE_HOME/jdk1.7.0_171/
		optionsScreen
	else
		echo "ERROR: PJ environment should be executed on xlytwv01-pub as hyppj OS user. Exiting..."
		exit 1;
	fi	
	
elif [[ "$ENV" = "INFRA1" ]]; then
	
	if [ $HOSTNAME = "xlytwv01-pub" ] && [ $OSUSER = "hypinfra" ]; then
		echo "Setting environment for server "$ENV
		. /home/hypinfra/hypinfra_epm1.env
		export HOME=/home/oracle
		export ENVT1="INFRA2"
		export BKPENVT="infra-xlytwv01-pub"
		export BKPENVT1="infra-xlytwv02-pub"
		export LCMENV="INFRA"
		export OTHR_NODE="xlytwv02-pub.sherwin.com"
		export OSUSER=hypinfra
		export SCRIPTDIR=/hyp_util/scripts
		export BACKUPDIR=/global/ora_backup
		export GOLD_CRIT_FILE_DIR=/hyp_util/Gold_File_Dir/INFRA1
		export JAVA_HOME=$MIDDLEWARE_HOME/jdk1.7.0_171/
		optionsScreen
	else
		echo "ERROR: INFRA1 environment should be executed on xlytwv01-pub as hypinfra OS user. Exiting..."
		exit 1;
	fi	
	
elif [[ "$ENV" = "INFRA2" ]]; then
		
	if [ $HOSTNAME = "xlytwv02-pub" ] && [ $OSUSER = "hypinfra" ]; then	
		echo "Setting environment for server "$ENV
		. /home/hypinfra/hypinfra_epm1.env
		export HOME=/home/oracle
		export ENVT1="INFRA1"
		export BKPENVT="infra-xlytwv02-pub"
		export BKPENVT1="infra-xlytwv01-pub"
		export LCMENV="INFRA"
		export OTHR_NODE="xlytwv01-pub.sherwin.com"
		export OSUSER=hypinfra
		export SCRIPTDIR=/hyp_util/scripts
		export BACKUPDIR=/global/ora_backup
		export GOLD_CRIT_FILE_DIR=/hyp_util/Gold_File_Dir/INFRA2
		export JAVA_HOME=$MIDDLEWARE_HOME/jdk1.7.0_171/
		optionsScreen
	else
		echo "ERROR: INFRA2 environment should be executed on xlytwv02-pub as hypinfra OS user. Exiting..."
		exit 1;
	fi	
	
elif [[ "$ENV" = "PROD_DB1" ]]; then
	
	if [ $HOSTNAME = "exepdb03.sherwin.com" ] && [ $OSUSER = "oracle" ]; then	
		echo "Setting environment for server "$ENV
		. /home/oracle/cpmtexep.env
		export HOME=/home/oracle
		export OTHR_NODE="exepdb04.sherwin.com"
		export OSUSER=oracle
		export PDBNAME=HYPENTP
		export CDBNAME=CPMTEXEP
		export ENVFILE=cpmtexep.env
		export SCRIPTDIR=/hyp_util/scripts
		export DBBACKUPDIR=/hyp_util/output/PREPOST/PROD_DB
		DBoptionsScreen
	else
		echo "ERROR: PROD_DB1 environment should be executed on exepdb03.sherwin.com as oracle OS user. Exiting..."
		exit 1;
	fi		

elif [[ "$ENV" = "PROD_DB2" ]]; then
	
	if [ $HOSTNAME = "exepdb04.sherwin.com" ] && [ $OSUSER = "oracle" ]; then	
		echo "Setting environment for server "$ENV
		. /home/oracle/cpmtexep.env
		export HOME=/home/oracle
		export OTHR_NODE="exepdb03.sherwin.com"
		export OSUSER=oracle
		export PDBNAME=HYPENTP
		export CDBNAME=CPMTEXEP
		export ENVFILE=cpmtexep.env
		export SCRIPTDIR=/hyp_util/scripts
		export DBBACKUPDIR=/hyp_util/output/PREPOST/PROD_DB
		DBoptionsScreen
	else
		echo "ERROR: PROD_DB2 environment should be executed on exepdb04.sherwin.com as oracle OS user. Exiting..."
		exit 1;
	fi		

elif [[ "$ENV" = "QA_DB1" ]]; then
	
	if [ $HOSTNAME = "exetdb03.sherwin.com" ] && [ $OSUSER = "oracle" ]; then	
		echo "Setting environment for server "$ENV
		. /home/oracle/cpchypq.env
		export HOME=/home/oracle
		export OTHR_NODE="exetdb04.sherwin.com"
		export OSUSER=oracle
		export PDBNAME=HYPENTQ
		export CDBNAME=CPCHYPQ
		export ENVFILE=cpchypq.env
		export SCRIPTDIR=/hyp_util/scripts
		export DBBACKUPDIR=/hyp_util/output/PREPOST/QA_DB
		DBoptionsScreen
	else
		echo "ERROR: QA_DB1 environment should be executed on exetdb03.sherwin.com as oracle OS user. Exiting..."
		exit 1;
	fi		

elif [[ "$ENV" = "QA_DB2" ]]; then
	
	if [ $HOSTNAME = "exetdb04.sherwin.com" ] && [ $OSUSER = "oracle" ]; then	
		echo "Setting environment for server "$ENV
		. /home/oracle/cpchypq.env
		export HOME=/home/oracle
		export OTHR_NODE="exetdb03.sherwin.com"
		export OSUSER=oracle
		export PDBNAME=HYPENTQ
		export CDBNAME=CPCHYPQ
		export ENVFILE=cpchypq.env
		export SCRIPTDIR=/hyp_util/scripts
		export DBBACKUPDIR=/hyp_util/output/PREPOST/QA_DB
		DBoptionsScreen
	else
		echo "ERROR: QA_DB2 environment should be executed on exetdb04.sherwin.com as oracle OS user. Exiting..."
		exit 1;
	fi		

elif [[ "$ENV" = "DEV_DB1" ]]; then
	
	if [ $HOSTNAME = "exetdb03.sherwin.com" ] && [ $OSUSER = "oracle" ]; then	
		echo "Setting environment for server "$ENV
		. /home/oracle/cpchypd.env
		export HOME=/home/oracle
		export OTHR_NODE="exetdb04.sherwin.com"
		export OSUSER=oracle
		export PDBNAME=HYPENTD
		export CDBNAME=CPCHYPD
		export ENVFILE=cpchypd.env
		export SCRIPTDIR=/hyp_util/scripts
		export DBBACKUPDIR=/hyp_util/output/PREPOST/DEV_DB
		DBoptionsScreen
	else
		echo "ERROR: DEV_DB1 environment should be executed on exetdb03.sherwin.com as oracle OS user. Exiting..."
		exit 1;
	fi		

elif [[ "$ENV" = "DEV_DB2" ]]; then
	
	if [ $HOSTNAME = "exetdb04.sherwin.com" ] && [ $OSUSER = "oracle" ]; then	
		echo "Setting environment for server "$ENV
		. /home/oracle/cpchypd.env
		export HOME=/home/oracle
		export OTHR_NODE="exetdb03.sherwin.com"
		export OSUSER=oracle
		export PDBNAME=HYPENTD
		export CDBNAME=CPCHYPD
		export ENVFILE=cpchypd.env
		export SCRIPTDIR=/hyp_util/scripts
		export DBBACKUPDIR=/hyp_util/output/PREPOST/DEV_DB
		DBoptionsScreen
	else
		echo "ERROR: DEV_DB2 environment should be executed on exetdb04.sherwin.com as oracle OS user. Exiting..."
		exit 1;
	fi
	
elif [[ "$ENV" = "PJ_DB1" ]]; then
	
	if [ $HOSTNAME = "exetdb03.sherwin.com" ] && [ $OSUSER = "oracle" ]; then	
		echo "Setting environment for server "$ENV
		. /home/oracle/cpchyppj.env
		export HOME=/home/oracle
		export OTHR_NODE="exetdb04.sherwin.com"
		export OSUSER=oracle
		export PDBNAME=HYPENTPJ
		export CDBNAME=CPCHYPPJ
		export ENVFILE=cpchyppj.env
		export SCRIPTDIR=/hyp_util/scripts
		export DBBACKUPDIR=/hyp_util/output/PREPOST/PJ_DB
		DBoptionsScreen
	else
		echo "ERROR: PJ_DB1 environment should be executed on exetdb03.sherwin.com as oracle OS user. Exiting..."
		exit 1;
	fi		

elif [[ "$ENV" = "PJ_DB2" ]]; then
	
	if [ $HOSTNAME = "exetdb04.sherwin.com" ] && [ $OSUSER = "oracle" ]; then	
		echo "Setting environment for server "$ENV
		. /home/oracle/cpchyppj.env
		export HOME=/home/oracle
		export OTHR_NODE="exetdb03.sherwin.com"
		export OSUSER=oracle
		export PDBNAME=HYPENTPJ
		export CDBNAME=CPCHYPPJ
		export ENVFILE=cpchyppj.env
		export SCRIPTDIR=/hyp_util/scripts
		export DBBACKUPDIR=/hyp_util/output/PREPOST/PJ_DB
		DBoptionsScreen
	else
		echo "ERROR: PJ_DB2 environment should be executed on exetdb04.sherwin.com as oracle OS user. Exiting..."
		exit 1;
	fi		

elif [[ "$ENV" = "INFRA_DB1" ]]; then

	if [ $HOSTNAME = "exetdb03.sherwin.com" ] && [ $OSUSER = "oracle" ]; then	
		echo "Setting environment for server "$ENV
		. /home/oracle/cpchypi.env
		export HOME=/home/oracle
		export OTHR_NODE="exetdb04.sherwin.com"
		export OSUSER=oracle
		export PDBNAME=HYPENTI
		export CDBNAME=CPCHYPI
		export ENVFILE=cpchypi.env
		export SCRIPTDIR=/hyp_util/scripts
		export DBBACKUPDIR=/hyp_util/output/PREPOST/INFRA_DB
		DBoptionsScreen
	else
		echo "ERROR: INFRA_DB1 environment should be executed on exetdb03.sherwin.com as oracle OS user. Exiting..."
		exit 1;
	fi		

elif [[ "$ENV" = "INFRA_DB2" ]]; then
	
	if [ $HOSTNAME = "exetdb04.sherwin.com" ] && [ $OSUSER = "oracle" ]; then	
		echo "Setting environment for server "$ENV
		. /home/oracle/cpchypi.env
		export HOME=/home/oracle
		export OTHR_NODE="exetdb03.sherwin.com"
		export OSUSER=oracle
		export PDBNAME=HYPENTI
		export CDBNAME=CPCHYPI
		export ENVFILE=cpchypi.env
		export SCRIPTDIR=/hyp_util/scripts
		export DBBACKUPDIR=/hyp_util/output/PREPOST/INFRA_DB
		DBoptionsScreen
	else
		echo "ERROR: INFRA_DB2 environment should be executed on exetdb04.sherwin.com as oracle OS user. Exiting..."
		exit 1;
	fi		

elif [[ "$ENV" = "DR_DB1" ]]; then

        if [ $HOSTNAME = "exdrdb03.us1.ocm.s1540146.oraclecloudatcustomer.com" ] && [ $OSUSER = "oracle" ]; then
                echo "Setting environment for server "$ENV
                . /home/oracle/dgmtexep.env
                export HOME=/home/oracle
                export OTHR_NODE="exdrdb04.sherwin.com"
                export OSUSER=oracle
                export PDBNAME=HYPENTP
                export CDBNAME=DGMTEXEP
                export ENVFILE=dgmtexep.env
                export SCRIPTDIR=/hyp_util/scripts
                export DBBACKUPDIR=/hyp_util/output/PREPOST/DR_DB
                DBoptionsScreen
        else
                echo "ERROR: DR_DB1 environment should be executed on exdrdb03.us1.ocm.s1540146.oraclecloudatcustomer.com as oracle OS user. Exiting..."
                exit 1;
        fi

elif [[ "$ENV" = "DR_DB2" ]]; then

        if [ $HOSTNAME = "exdrdb04.us1.ocm.s1540146.oraclecloudatcustomer.com" ] && [ $OSUSER = "oracle" ]; then
                echo "Setting environment for server "$ENV
                . /home/oracle/dgmtexep.env
                export HOME=/home/oracle
                export OTHR_NODE="exdrdb04.sherwin.com"
                export OSUSER=oracle
                export PDBNAME=HYPENTP
                export CDBNAME=DGMTEXEP
                export ENVFILE=dgmtexep.env
                export SCRIPTDIR=/hyp_util/scripts
                export DBBACKUPDIR=/hyp_util/output/PREPOST/DR_DB
                DBoptionsScreen
        else
                echo "ERROR: DR_DB2 environment should be executed on exdrdb04.us1.ocm.s1540146.oraclecloudatcustomer.com as oracle OS user. Exiting..."
                exit 1;
        fi
else
	echo  "ERROR: EPM/DB Environment unknown. Execution format ./<script-name> <ENV> "
	echo "<ENV> = INFRA1 / INFRA2 / PJ / DEV / QA1 / QA2 / PROD1 / PROD2 / DR "
	echo " "
	echo "<DB ENV> = INFRA_DB1 / INFRA_DB2 / PJ_DB1 / PJ_DB2 / DEV_DB1 / DEV_DB2 / QA_DB1 / QA_DB22 / PROD_DB1 / PROD_DB2 / DR_DB1 / DR_DB2 "
	echo " "
	echo "Refer usage document on connections: http://connections.sherwin.com/files/app/file/8384a247-f7e8-4cf2-a333-e18c61723933"
	exit 1;
fi





