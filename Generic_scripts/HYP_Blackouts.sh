#!/bin/bash
shopt -s extglob

pause(){
		read -p "Press [Enter] key to continue..." fackEnterKey
}

start_blackout_main(){
       	show_menus_blackout_type
       	read_options_blackout_type
}

show_menus() {
        clear
        echo "~~~~~~~~~~~~~~~~~~~~~"
        echo "  M A I N - M E N U  "
        echo "~~~~~~~~~~~~~~~~~~~~~"
        echo "1. Start Blackout"
        echo "2. End Blackout"
        echo "3. Exit"
}

show_menus_blackout_type() {
        clear
        echo "~~~~~~~~~~~~~~~~~~~~~~~~"
        echo "      Blackout Type     "
        echo "~~~~~~~~~~~~~~~~~~~~~~~~"
        echo "1.  Host"
	    echo "2.  EPM Environment                   *** If clustered will only appear on one node ***"
        echo "3.  WebLogic AdminServer"
        echo "4.  Clustered EPM Application         *** If clustered will only appear on one node ***"
	    echo "5.  Individual EPM Application"
		echo "6.  PDB                               *** If clustered will only appear on one node ***"
	    echo "7.  CDB"
		echo "8.  Essbase Service Tests"
        echo "9.  Exit"
}

start_blackout() {
    local CHOICE
	. /home/oracle/13cagent.env > /dev/null 2>&1
	if [ "$BLACKOUTTYPE" == "weblogic_j2eeserver" ] ; then
			if [[ "$USER" != "oracle" ]]; then
					sudo -u oracle /u01/app/oracle/agent/12c/agent_inst/bin/emctl config agent listtargets|grep $BLACKOUTTYPE | grep -v Welcome | grep -v AdminServer | cut -d "[" -f2 | cut -d "]" -f1 |cut -d "," -f1 >/hyp_util/output/listtargets_${HOST}_${DATESTAMP}_start.txt
			else
					emctl config agent listtargets|grep $BLACKOUTTYPE | grep -v Welcome | grep -v AdminServer | cut -d "[" -f2 | cut -d "]" -f1 |cut -d "," -f1 >/hyp_util/output/listtargets_${HOST}_${DATESTAMP}_start.txt
			fi
	else
			if [[ "$USER" != "oracle" ]]; then
					sudo -u oracle /u01/app/oracle/agent/12c/agent_inst/bin/emctl config agent listtargets|grep $BLACKOUTTYPE | grep -v Welcome | cut -d "[" -f2 | cut -d "]" -f1 |cut -d "," -f1 >/hyp_util/output/listtargets_${HOST}_${DATESTAMP}_start.txt
			else
					emctl config agent listtargets|grep $BLACKOUTTYPE | grep -v Welcome | cut -d "[" -f2 | cut -d "]" -f1 |cut -d "," -f1 >/hyp_util/output/listtargets_${HOST}_${DATESTAMP}_start.txt
			fi
	fi
	export DUMPFILE=/hyp_util/output/listtargets_${HOST}_${DATESTAMP}_start.txt
	echo "~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "         Target         "
    echo "~~~~~~~~~~~~~~~~~~~~~~~~"
	cat -n "$DUMPFILE"
    read -p "Enter choice [x] to Exit " CHOICE
	case $CHOICE in
	+([0-9]))
			read_options_blackout_duration
			export BLACKOUTVARIABLE=$(sed -n "$CHOICE"p "$DUMPFILE")
			if [ "$BLACKOUTTYPE" == "AdminServer" ] ; then
					export BLACKOUTTYPE=weblogic_j2eeserver
					export ISADMIN=YES
			fi
			cd /hyp_util/emcli
			./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP" -add_targets="$BLACKOUTVARIABLE":"$BLACKOUTTYPE" -propagate_targets -reason=blackout -schedule="frequency:once;duration:"$DURATION""
			if [ "$ISADMIN" != "YES" ] && [ "$BLACKOUTTYPE" != "oracle_pdb" ] && [ "$BLACKOUTTYPE" != "rac_database" ] && [ "$BLACKOUTVARIABLE" != "exlwdb03.sherwin.com" ] && [ "$BLACKOUTVARIABLE" != "exlwdb04.sherwin.com" ]; then
					start_blackout_services
			fi
			pause
			;;
    x) rm -f /hyp_util/output/listtargets_${HOST}_${DATESTAMP}_start.txt;exit 0 ;;
    *) echo -e "${RED}Error...${STD}" && sleep 2
	esac
	rm -f /hyp_util/output/listtargets_${HOST}_${DATESTAMP}_start.txt
}

stop_blackout() {
		local CHOICE
		cd /hyp_util/emcli
		./emcli get_blackouts -format="name:csv"|grep HYP|grep Started| cut -d "," -f1 >/hyp_util/output/listtargets_${HOST}_${DATESTAMP}_stop.txt
		export DUMPFILE=/hyp_util/output/listtargets_${HOST}_${DATESTAMP}_stop.txt
		echo "~~~~~~~~~~~~~~~~~~~~~~~~"
		echo "        Blackout        "
		echo "~~~~~~~~~~~~~~~~~~~~~~~~"
		cat -n "$DUMPFILE"
        read -p "Enter blackout to stop or [x] to Exit " CHOICE
        case $CHOICE in
        +([0-9]))
				cd /hyp_util/emcli
				export DUMPFILE=/hyp_util/output/listtargets_${HOST}_${DATESTAMP}_stop.txt
				export BLACKOUTVARIABLE=$(sed -n "$CHOICE"p "$DUMPFILE")
				echo export JAVA_HOME=/hyp_util/emcli/jdk1.7.0_151\;/hyp_util/emcli/emcli stop_blackout -name="$BLACKOUTVARIABLE"|at now + 10 minute
				echo export JAVA_HOME=/hyp_util/emcli/jdk1.7.0_151\;/hyp_util/emcli/emcli delete_blackout -name="$BLACKOUTVARIABLE"|at now + 11 minute
				pause
				;;
        x) rm -f /hyp_util/output/listtargets_${HOST}_${DATESTAMP}_stop.txt
		   exit 0 
		   ;;
        *) echo -e "${RED}Error...${STD}" && sleep 2
        esac
		rm -f /hyp_util/output/listtargets_${HOST}_${DATESTAMP}_stop.txt
}

start_blackout_services() {
    local CHOICE
	case $BLACKOUTTYPE in
    host)
			case $BLACKOUTVARIABLE in
			xlytwv01-pub.sherwin.com) 
					cd /hyp_util/emcli
					./emcli get_targets -targets="Hyperion%QA1%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Essbase%QA1%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="QA1%Essbase Studio%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Hyperion%PJ%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Essbase%PJ%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="PJ%Essbase Studio%%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Hyperion%INFRA1%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Essbase%INFRA1%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="INFRA1%Essbase Studio%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			xlytwv02-pub.sherwin.com)
					cd /hyp_util/emcli
					./emcli get_targets -targets="Hyperion%QA2%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Essbase%QA2%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Hyperion%DEV%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Essbase%DEV%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="DEV%Essbase Studio%%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Hyperion%INFRA2%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Essbase%INFRA2%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			xlythq01-pub.sherwin.com) 
					cd /hyp_util/emcli
					./emcli get_targets -targets="Hyperion%PROD1%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Essbase%PROD1%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="PROD1%Essbase Studio%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			xlythq02-pub.sherwin.com) 
					cd /hyp_util/emcli
					./emcli get_targets -targets="Hyperion%PROD2%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="Essbase%PROD2%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*) echo -e "${RED}Error...${STD}";sleep 2;exit 99 ;;		
			esac ;;
    oracle_ias_farm)
			case $BLACKOUTVARIABLE in
			EPM_EPMPJSystem) export ENVVARIABLE="PJ" ;;
			HyperionEnterpriseDev_EPMDevSystem) export ENVVARIABLE="DEV" ;;
			HyperionEnterpriseQA_EPMSystem) export ENVVARIABLE="QA" ;;
			HyperionEnterprisePRD_EPMSystem) export ENVVARIABLE="PROD" ;;
			EPM_EPMINFSystem) export ENVVARIABLE="INFRA" ;;
			*) echo -e "${RED}Error...${STD}";sleep 2;exit 99 ;;
			esac
			cd /hyp_util/emcli
			./emcli get_targets -targets="Hyperion%"$ENVVARIABLE"%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
			./emcli get_targets -targets="Essbase%"$ENVVARIABLE"%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
			./emcli get_targets -targets=""$ENVVARIABLE"%Essbase Studio%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
			while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
			./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
			;;
    weblogic_cluster)
			case $BLACKOUTVARIABLE in
			*EPM_EPMPJSystem*) export ENVVARIABLE="PJ" ;;
			*HyperionEnterpriseDev_EPMDevSystem*) export ENVVARIABLE="DEV" ;;
			*HyperionEnterpriseQA_EPMSystem*) export ENVVARIABLE="QA" ;;
			*HyperionEnterprisePRD_EPMSystem*) export ENVVARIABLE="PROD" ;;
			*EPM_EPMINFSystem*) export ENVVARIABLE="INFRA" ;;
			*) echo -e "${RED}Error...${STD}";sleep 2;exit 99 ;;
			esac
			case $BLACKOUTVARIABLE in
			*WebAnalysis*)
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%Web Analysis%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_WebAnalysis_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*Epma*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%EPMA%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_Epma_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*AnalyticProviderServices*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%APS%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_AnalyticProviderServices_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*CalcMgr*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%Calc%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_CalcMgr_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*EssbaseAdminServices*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%EAS%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_EssbaseAdminServices_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*FinancialReporting*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%Financial Reporting%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_FinancialReporting_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*FoundationServices*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%Foundation%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="%"$ENVVARIABLE"%Workspace%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_FoundationServices_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*RaFramework*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%RA%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="%"$ENVVARIABLE"%RaF%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_RaFramework_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*Planning*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%Planning%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_Planning_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			esac ;;
    weblogic_j2eeserver)
			case $BLACKOUTVARIABLE in
			*EPM_EPMPJSystem*) export ENVVARIABLE="PJ" ;;
			*HyperionEnterpriseDev_EPMDevSystem*) export ENVVARIABLE="DEV" ;;
			*HyperionEnterpriseQA_EPMSystem*0) export ENVVARIABLE="QA1" ;;
			*HyperionEnterpriseQA_EPMSystem*1) export ENVVARIABLE="QA2" ;;
			*HyperionEnterprisePRD_EPMSystem*0) export ENVVARIABLE="PROD1" ;;
			*HyperionEnterprisePRD_EPMSystem*1) export ENVVARIABLE="PROD2" ;;
			*EPM_EPMINFSystem*0) export ENVVARIABLE="INFRA1" ;;
			*EPM_EPMINFSystem*1) export ENVVARIABLE="INFRA2" ;;
			*) echo -e "${RED}Error...${STD}";sleep 2;exit 99 ;;
			esac
			case $BLACKOUTVARIABLE in
			*WebAnalysis*)
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%Web Analysis%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_WebAnalysis_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*Epma*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%EPMA%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_Epma_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*AnalyticProviderServices*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%APS%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_AnalyticProviderServices_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*CalcMgr*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%Calc%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_CalcMgr_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*EssbaseAdminServices*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%EAS%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_EssbaseAdminServices_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*FinancialReporting*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%Financial Reporting%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_FinancialReporting_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*FoundationServices*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%Foundation%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="%"$ENVVARIABLE"%Workspace%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_FoundationServices_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*RaFramework*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%RA%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="%"$ENVVARIABLE"%RaF%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_RaFramework_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*Planning*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%Planning%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_Planning_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*ErpIntegrator*)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%FDMEE%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli get_targets -targets="%"$ENVVARIABLE"%DRM WSDL%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_ErpIntegrator_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			*DRMServer)		
					cd /hyp_util/emcli
					./emcli get_targets -targets="%"$ENVVARIABLE"%DRM Analytics%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
					./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_DRMServer_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
					;;
			esac ;;			
    generic_service) 
			clear
			echo "~~~~~~~~~~~~~~~~~~~~~~~~"
			echo "         Target         "
			echo "~~~~~~~~~~~~~~~~~~~~~~~~"
			echo "1. PJ                   "
            echo "2. DEV                  "
            echo "3. QA                   "
			echo "4. PROD                 "
			echo "5. INFRA                "
			read -p "Enter choice [x] to Exit " CHOICE
			read_options_blackout_duration
			case $CHOICE in
			1) export ENVVARIABLE="PJ" ;;
			2) export ENVVARIABLE="DEV" ;;
			3) export ENVVARIABLE="QA" ;;
			4) export ENVVARIABLE="PROD" ;;
			5) export ENVVARIABLE="INFRA" ;;
			x) exit 0;;
			*) echo -e "${RED}Error...${STD}" && sleep 2	
			esac
			cd /hyp_util/emcli
			./emcli get_targets -targets="Essbase%"$ENVVARIABLE"%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
			./emcli get_targets -targets="%"$ENVVARIABLE"%Essbase Studio%%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
			while read -r line;do printf "$line"":generic_service;"; done < /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt >/hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
			./emcli create_blackout -name=HYP_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP"_services -add_targets="$(cat /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt)" -reason=blackout -schedule="frequency:once;duration:"$DURATION""
			pause 
			;;
    *) echo -e "${RED}Error...${STD}" && sleep 2
    esac
	rm -f /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
	rm -f /hyp_util/output/listtargets_blackout_${ENVVARIABLE}_${HOST}_${DATESTAMP}_${BLACKOUTTYPE}.txt
}

read_options(){
        local CHOICE
        read -p "Enter choice [ 1 - 3] " CHOICE
        case $CHOICE in
        1) start_blackout_main ;;
        2) stop_blackout ;;
        3) exit 0 ;;
        *) echo -e "${RED}Error...${STD}" && sleep 2
        esac
}

read_options_blackout_type(){
        local CHOICE
        read -p "Enter choice [ 1 - 8] " CHOICE
        case $CHOICE in
        1) export BLACKOUTTYPE=host;start_blackout ;;
        2) export BLACKOUTTYPE=oracle_ias_farm;start_blackout ;;
        3) export BLACKOUTTYPE=AdminServer;start_blackout ;;
        4) export BLACKOUTTYPE=weblogic_cluster;start_blackout ;;
		5) export BLACKOUTTYPE=weblogic_j2eeserver;start_blackout ;;
        6) export BLACKOUTTYPE=oracle_pdb;start_blackout ;;
        7) export BLACKOUTTYPE=rac_database;start_blackout ;;
		8) export BLACKOUTTYPE=generic_service;export DATESTAMP=`date +%Y-%m-%d_%H_%M_%S`;start_blackout_services ;;
        9) exit 0 ;;
        *) echo -e "${RED}Error...${STD}" && sleep 2
        esac
}

read_options_blackout_services(){
        local CHOICE
        read -p "Enter choice [ 1 - 7] " CHOICE
        case $CHOICE in
        1) export BLACKOUTTYPE=host;start_blackout ;;
        2) export BLACKOUTTYPE=oracle_ias_farm;start_blackout ;;
        3) export BLACKOUTTYPE=AdminServer;start_blackout ;;
        4) export BLACKOUTTYPE=weblogic_cluster;start_blackout ;;
        5) export BLACKOUTTYPE=oracle_pdb;start_blackout ;;
        6) export BLACKOUTTYPE=rac_database;start_blackout ;;
        7) exit 0 ;;
        *) echo -e "${RED}Error...${STD}" && sleep 2
        esac
}

read_options_blackout_duration(){
        local CHOICE
		clear
		echo "~~~~~~~~~~~~~~~~~~~~~~~~"
		echo "   Blackout Duration    "
		echo "~~~~~~~~~~~~~~~~~~~~~~~~"
		read -p "Enter hours [1-999999] or enter for indefinite [x] to Exit " CHOICE
		if [ "$CHOICE" == "" ]; then
				export DURATION="-1"
		elif [ "$CHOICE" == "x" ]; then
				rm -f /hyp_util/output/listtargets_${HOST}_${DATESTAMP}_start.txt;exit 0
		elif ! [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
				echo -e "Non-numeric entered, entry must be [1-999999]";sleep 2;read_options_blackout_duration
		elif [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le 999999 ]; then
				export DURATION="$CHOICE"		
		else
				echo -e "${RED}Error...${STD}";sleep 2;rm -f /hyp_util/output/listtargets_${HOST}_${DATESTAMP}_start.txt;exit 99
		fi
}

trap '' SIGINT SIGQUIT SIGTSTP

export USER=$(whoami)
export HOST=$(hostname)
if [[ "$USER" = "hyperion" ]]; then
        export ENVVARIABLE="DEV"
		export DOMVARIABLE="Dev"
elif [[ "$USER" = "hyppj" ]]; then
        export ENVVARIABLE="PJ"
		export DOMVARIABLE="$ENVVARIABLE"
elif [[ "$USER" = "hypinfra" ]]; then
        export ENVVARIABLE="INF"
		export DOMVARIABLE="$ENVVARIABLE"
elif [[ "$USER" = "oracle" && "$HOST" = "xlytwv01-pub" ]]; then
        export ENVVARIABLE="QA"
		export DOMVARIABLE="$ENVVARIABLE"
elif [[ "$USER" = "oracle" && "$HOST" = "xlytwv02-pub" ]]; then
        export ENVVARIABLE="QA"
		export DOMVARIABLE="$ENVVARIABLE"
elif [[ "$USER" = "oracle" && "$HOST" = "xlythq01-pub" ]]; then
        export ENVVARIABLE="PROD"
		export DOMVARIABLE="PRD"
elif [[ "$USER" = "oracle" && "$HOST" = "xlythq02-pub" ]]; then
        export ENVVARIABLE="PROD"
		export DOMVARIABLE="PRD"
else
        echo "Invalid Environment"
fi	
export JAVA_HOME=/hyp_util/emcli/jdk1.7.0_151
export DATESTAMP=`date +%Y-%m-%d_%H_%M_%S`
export LOGFILE=/hyp_util/logs/$ENVVARIABLE-login_$DATESTAMP.log
export ERRFILE=/hyp_util/logs/$ENVVARIABLE-login_$DATESTAMP.err
echo "******************************************" >> $LOGFILE
echo "generating password through getpass" >> $LOGFILE
echo "******************************************" >> $LOGFILE

export PASSWORD=`/hyp_util/scripts/getpass/getpass -p CLOUD_CONTROL SW_JOBADMIN`>> $LOGFILE
cd /hyp_util/emcli
echo "password generated successfully" >> $LOGFILE
echo "emcli login through getpass" >> $LOGFILE
./emcli logout >> $LOGFILE
./emcli login -username=SW_JOBADMIN -password=$PASSWORD >> $LOGFILE
echo "check for successful login" >> $LOGFILE
ERROFILEHAVEERRORS=`grep -i 'Login successful' $LOGFILE |wc -l` >> $LOGFILE
if [ $ERROFILEHAVEERRORS -ne 0 ];then
 echo " No errors, able to login" >> $LOGFILE
    else
        echo "check for emcli log updated date" >> $LOGFILE
        Logdate=`ls -ltra $HOME/.emcli/.emcli.log|awk '{print $6,$7,$8}'`
        echo "Log date is: $(basename "$Logdate")" >> $LOGFILE
        export tdate=`date '+%b %d %H:%M'`
        echo "date : $(basename "$tdate")" >> $LOGFILE
                if [[ $Logdate == $tdate ]];then
                        echo "****** copying failed log to error file******">> $LOGFILE
                        tail -20 $HOME/.emcli/.emcli.log >> $ERRFILE
                        grep -i 'FailedLoginException'  $ERRFILE >> $LOGFILE
                        echo "use correct credentials" >> $LOGFILE
                        exit
                fi
fi
while [[ $SHLVL ==  2 ]]
do
        export HOST=$(hostname)
                export DATESTAMP=`date +%Y-%m-%d_%H_%M_%S`
                show_menus
        read_options
done

echo $(basename $1) | grep 'start' &> /dev/null
if [ $? == 0 ]; then
        . /home/oracle/13cagent.env > /dev/null 2>&1
        if [ $(basename $1) == startOHS.sh ]; then
		        exit;
		elif [ $(basename $1) == startEssbase.sh ]; then
		        export SCRIPT="generic_service"		
		elif [ $(basename $1) == start.sh ]; then
		        export SCRIPT="oracle_ias_farm"				
		else
				export SCRIPT=$(echo $(basename $1)|sed 's/^.*start//g'|sed 's/.sh//g')
		fi
        for LINE in $(grep -o '"HYP_.*"' /hyp_util/output/automated_blackouts_${ENVVARIABLE}_${HOST}_${SCRIPT} | sed 's/"//g')
        do
		        cd /hyp_util/emcli
                echo export JAVA_HOME=/hyp_util/emcli/jdk1.7.0_151\;/hyp_util/emcli/emcli stop_blackout -name="$LINE"|at now + 10 minute
                echo export JAVA_HOME=/hyp_util/emcli/jdk1.7.0_151\;/hyp_util/emcli/emcli delete_blackout -name="$LINE"|at now + 11 minute
        done
        rm -f /hyp_util/output/automated_blackouts_${ENVVARIABLE}_${HOST}_${SCRIPT}
		if [ $(basename $1) == start.sh ]; then
				shopt -s nullglob
				for fname in /hyp_util/output/automated_blackouts_${ENVVARIABLE}_${HOST}_*; do
		        		for LINE in $(grep -o '"HYP_.*"' $fname | sed 's/"//g')
						do
		                		cd /hyp_util/emcli
                        		echo export JAVA_HOME=/hyp_util/emcli/jdk1.7.0_151\;/hyp_util/emcli/emcli stop_blackout -name="$LINE"|at now + 10 minute
                        		echo export JAVA_HOME=/hyp_util/emcli/jdk1.7.0_151\;/hyp_util/emcli/emcli delete_blackout -name="$LINE"|at now + 11 minute
                		done
						rm -f $fname
				done
				shopt -u nullglob
		fi
		exit
fi		
echo $(basename $1) | grep 'stop' &> /dev/null
if [ $? == 0 ]; then
        . /home/oracle/13cagent.env > /dev/null 2>&1
        export DURATION="-1"
		export DATESTAMP=`date +%Y-%m-%d_%H_%M_%S`
        if [ $(basename $1) == stopRMI.sh ]; then
		        export SCRIPT=$(echo $(basename $1)|sed 's/^.*stop//g'|sed 's/.sh//g')
				export BLACKOUTTYPE="generic_service"
		        if [[ "$ENVVARIABLE" = "DEV" ]]; then
				        echo "Hyperion DEV RMI Port">/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				elif [[ "$ENVVARIABLE" = "PJ" ]]; then
				        echo "Hyperion PJ RMI Port">/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				elif [[ "$ENVVARIABLE" = "QA" && "$HOST" = "xlytwv01-pub" ]]; then
				       echo "Hyperion QA1 RMI Port">/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				elif [[ "$ENVVARIABLE" = "QA" && "$HOST" = "xlytwv02-pub" ]]; then
				        echo "Hyperion QA2 RMI Port">/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				elif [[ "$ENVVARIABLE" = "PROD" && "$HOST" = "xlytwv01-pub" ]]; then
				        echo "Hyperion PROD1 RMI Port">/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				elif [[ "$ENVVARIABLE" = "PROD" && "$HOST" = "xlytwv02-pub" ]]; then
				        echo "Hyperion PROD2 RMI Port">/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				else
				        echo "Invalid RMI environment"
				fi
		elif [ $(basename $1) == stopOHS.sh ]; then
		        exit;
		elif [ $(basename $1) == stopEssbase.sh ]; then
				cd /hyp_util/emcli
				export BLACKOUTTYPE="generic_service"
				export SCRIPT="generic_service"
				./emcli get_targets -targets="Essbase%"$ENVVARIABLE"%:%service%" -format="name:csv" -noheader| cut -d "," -f4 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				#./emcli get_targets -targets="%"$ENVVARIABLE"%Essbase Studio%%" -format="name:csv" -noheader| cut -d "," -f4 >>/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
		elif [ $(basename $1) == stop.sh ]; then
				export BLACKOUTTYPE="oracle_ias_farm"
				export SCRIPT="oracle_ias_farm"
				if [[ "$ENVVARIABLE" != "DEV" && "$HOST" = "xlytwv02-pub" ]]; then
				        echo "Not Blacking out this node as it is non-primary"
						exit
				fi
				if [[ "$USER" != "oracle" ]]; then
						sudo -u oracle /u01/app/oracle/agent/12c/agent_inst/bin/emctl config agent listtargets| grep $BLACKOUTTYPE | grep $DOMVARIABLE | cut -d "[" -f2 | cut -d "]" -f1 |cut -d "," -f1 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				else
						emctl config agent listtargets|grep $BLACKOUTTYPE |  grep $DOMVARIABLE | cut -d "[" -f2 | cut -d "]" -f1 |cut -d "," -f1 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				fi
		elif [ $(basename $1) == stopEssbaseStudio.sh ]; then
		        export SCRIPT=$(echo $(basename $1)|sed 's/^.*stop//g'|sed 's/.sh//g')
				export BLACKOUTTYPE="generic_service"
		        if [[ "$ENVVARIABLE" = "DEV" ]]; then
				        echo "Hyperion DEV Essbase Studio Port Check">/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				elif [[ "$ENVVARIABLE" = "PJ" ]]; then
				        echo "Hyperion PJ Essbase Studio Port Check">/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				elif [[ "$ENVVARIABLE" = "QA" ]]; then
				        echo "Hyperion QA1 Essbase Studio Port Check">/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				elif [[ "$ENVVARIABLE" = "PROD" ]]; then
				        echo "Hyperion PROD1 Essbase Studio Port Check">/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				else
				        echo "Invalid studio environment"
				fi
		else
				export BLACKOUTTYPE="weblogic_j2eeserver"
				export SCRIPT=$(echo $(basename $1)|sed 's/^.*stop//g'|sed 's/.sh//g')
				if [[ "$USER" != "oracle" ]]; then
				        sudo -u oracle /u01/app/oracle/agent/12c/agent_inst/bin/emctl config agent listtargets| grep $BLACKOUTTYPE | grep $SCRIPT | grep $DOMVARIABLE | grep -v Welcome | grep -v AdminServer | cut -d "[" -f2 | cut -d "]" -f1 |cut -d "," -f1 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				else
				        emctl config agent listtargets| grep $BLACKOUTTYPE | grep $SCRIPT | grep $DOMVARIABLE | grep -v Welcome | grep -v AdminServer | cut -d "[" -f2 | cut -d "]" -f1 |cut -d "," -f1 >/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
				fi
		fi
		export DUMPFILE=/hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
		chmod 777 /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
		export BLACKOUTVARIABLE=$(cat "$DUMPFILE")
		cd /hyp_util/emcli
		./emcli create_blackout -name=HYP_"$ENVVARIABLE"_"$HOSTNAME"_"$BLACKOUTTYPE"_"$DATESTAMP" -add_targets="$BLACKOUTVARIABLE":"$BLACKOUTTYPE" -propagate_targets -reason=blackout -schedule="frequency:once;duration:"$DURATION"" | tee -a /hyp_util/output/automated_blackouts_${ENVVARIABLE}_${HOST}_${SCRIPT}
		if [ $(basename $1) != stopEssbase.sh ] && [ $(basename $1) != stopEssbaseStudio.sh ] && [ $(basename $1) != stopRMI.sh ]; then
		        start_blackout_services | tee -a /hyp_util/output/automated_blackouts_${ENVVARIABLE}_${HOST}_${SCRIPT}
		fi
		chmod 777 /hyp_util/output/automated_blackouts_${ENVVARIABLE}_${HOST}_${SCRIPT}
		fi
		rm -f /hyp_util/output/listtargets_${ENVVARIABLE}_${HOST}.txt
        exit
else
        echo "Invalid invocation of automated blackout"
fi

