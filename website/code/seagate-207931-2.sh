#!/bin/bash
# Seagate drives (Barracuda 7200.11, DiamondMax 22, Barracuda ES.2 SATA, SV35) fail after powering on, KB 207931:
# http://seagate.custkb.com/seagate/crm/selfservice/search.jsp?Tab=search&Module=selfservice&TargetLanguage=selfservice&DocId=207931&NewLang=en
#
# There is no Linux tool (yet) to help the overworked linux admin,
# so I wrote this - have fun mass-checking your servers.
#
# Currently supports hdparm, tw_cli (3ware), arcconf (adaptec)
# You have to use the corresponding RAID-Tool in order to get the model, serial and firmware version.
#
# Hint: 
# do something like this:
# ssh host "curl -s https://deploysrv/seagate-207931.sh | sh"
#
# The script has return codes:
# 0: everything ok
# 1: one of the models was found (you still need to check the firmware version)
#
# If you have code additions, mail me, I'd like to add support for more cli raid-tools.
# Please supply me with complete output - or just buy me an areca, lsi and I'll add support for those, too ;)
#
# Written by Stefan Behte (http://ge.mine.nu)
# Stefan dot Behte at gmx dot net

# from KB 207931
MODEL=(ST31000340AS ST31000640AS ST3750330AS ST3750630AS ST3640330AS ST3640630AS ST3500320AS ST3500620AS ST3500820AS ST31500341AS ST31000333AS ST3640323AS ST3640623AS ST3320613AS ST3320813AS ST3160813AS ST31000340NS ST3750330NS ST3500320NS ST3250310NS STM31000340AS STM31000640AS STM3750330AS STM3750630AS STM3500320AS STM3500620AS STM3500820AS STM31000334AS STM3320614AS STM3160813AS)

HDPARM=$(which hdparm 2>/dev/null)
TW_CLI=$(which tw_cli 2>/dev/null)

# not in PATH, rpm installed it there
ARCCONF="/usr/StorMan/arcconf"
CURL=$(which curl 2>/dev/null)

FOUND=0

checkserial()
{
	if [ ! -x $CURL ]
	then
		echo "cannot execute curl."
	fi

	RESULT=$($CURL -s https://apps1.seagate.com/rms_af_srl_chk/checkSerialServlet --data "serialno=${@}&serialnumber=${@}" -A http://ge.mine.nu/seagate-207931.html)

	if [ ! -n "$(echo "${RESULT}" | grep -q "is NOT affected")" ]
	then
		echo "Serial not found, good luck."
		echo
		FOUND=0
	else
		echo "Serial found, bad luck."
		echo
		FOUND=1
	fi
}

checkmodel()
{
	for ((k=0; k<${#MODEL[@]}; k++))
	do
		if [ -n "$(echo $@ | grep ${MODEL[${k}]})" ]
		then
			return 1
		fi
	done
	return 0
}

checkperms()
{
	if [ -r "${@}" ]
	then
		return 1
	else
		return 0
	fi
}

# as you get this for free, I'll add a banner at least ;)
echo
echo "seagate-207931.sh v2 by Stefan Behte (http://ge.mine.nu)"
echo

# hdparm
if [ -e "${HDPARM}" ]
then
	DEVICE=($(sed -e 's/[0-9]//g' /proc/partitions | grep -v -e ^major -e dm- -e ^$ | awk '{print $1}' | uniq))
	for ((i=0; i<${#DEVICE[@]}; i++))
	do
		checkperms /dev/${DEVICE[${i}]}
		if [ $? -eq 0 ]
		then
			echo "Error reading /dev/${DEVICE[${i}]}"
			break
		fi

		DUMP=$($HDPARM -I /dev/${DEVICE[${i}]} 2>/dev/null | grep -e "Model Number" -e "Serial Number" -e "Firmware Revision")
		checkmodel ${DUMP}
		if [ $? -eq 1 ]
		then
			echo "Model might be affected."
			echo ${DUMP}
			echo -n "Querying seagate server..."
			checkserial $($HDPARM -I /dev/${DEVICE[${i}]} 2>/dev/null | awk '/Serial Number/ {print $3}')
		else
			echo "hdparm /dev/${DEVICE[${i}]} ok"
		fi
	done
else
	echo "hdparm not found"
fi

echo

# 3ware RAID, check every port on every controller
if [ -e "${TW_CLI}" ]
then
	CONTROLLER=$(${TW_CLI} show | awk '/^c/ {print $1}')

	if [ ! -x "${TW_CLI}" ]
	then
		echo "Error: cannot execute ${TW_CLI}. Results will be wrong!"
	fi

	for ((i=0; i<${#CONTROLLER[@]}; i++))
	do
		PORT=($(${TW_CLI} /${CONTROLLER[${i}]} show | awk '/^p/ {print $1}'))

		for ((j=0; j<${#PORT[@]}; j++))
		do
			DUMP=$(${TW_CLI} /${CONTROLLER[${i}]}/${PORT[${j}]} show model serial firmware)
			checkmodel ${DUMP}
			if [ $? -eq 1 ]
			then
				FOUND=1

				echo "Your model might be affected."
				echo ${DUMP}
				echo -n "Querying seagate server: "
				checkserial $(${TW_CLI} /${CONTROLLER[${i}]}/${PORT[${j}]} show serial | awk '{print $4}')
			else
				echo "3ware (tw_cli) /${CONTROLLER[${i}]}/${PORT[${j}]}: ok"
			fi
		done
	done
else
	echo "tw_cli not found"
fi

# Adaptec, only tested with Version 6.0 (B17914), query physical drives on all controllers
if [ -e "${ARCCONF}" ]
then
	NR=$(${ARCCONF} GETSTATUS 23 | awk -F: '/Controllers found/ {print $2}')
	for ((i=0;i<$NR;i++))
	do
		DUMP=$(${ARCCONF} GETCONFIG $[${i} + 1] PD | grep -e Model -e Firmware -e Serial)
		checkmodel ${DUMP}
		if [ $? -eq 1 ]
		then
			FOUND=1

			echo "Your model might be affected."
			echo ${DUMP}
			echo -n "Querying seagate server: "

			SERIAL=($(${ARCCONF} GETCONFIG $[${i} + 1] PD | awk '/Serial number/ {printf $4 " "}'))
			for ((l=0; l<${#SERIAL[@]}; l++))
			do
				checkserial ${SERIAL[${l}]}
			done
	else
			echo "Adaptec (arcconf) $[${i} + 1]: ok"
		fi
	done
else
	echo "arcconf not found"
fi

if [ "${FOUND}" = "0" ]
then
	echo
	echo "Good luck, no Seagate drives for KB 207931 found."
	echo "If this machine has a RAID-Controller other than 3ware or adaptec (used with arcconf), this tool probably has failed."
	echo "Please review the code and send your changes. ;)"
	echo
	exit 0	
else
	echo
	exit 1
fi

