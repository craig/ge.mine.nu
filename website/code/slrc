#!/bin/bash
# simple linux rar cracker (slrc) v0.2 by Stefan Behte (http://ge.mine.nu)
#
# I wrote this to practise/test bash getopts and also because I didn't find any
# rar cracker for linux when I wanted to check a file against a wordlist.
# I know doing it this way is slow but I wanted a quick hack ;)
#
# Copyright (c) 2006 by Stefan Behte
#
# slrc is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# slrc is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with slrc; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# Written by Stefan Behte
#
# Please send bugs, comments, wishes and success stories to:
# Stefan.Behte at gmx dot net 
#
# Also have a look at my page:
# http://ge.mine.nu/
#

echo -e "\nsimple linux rar cracker (slrc) v0.2 by Stefan Behte (http://ge.mine.nu)"

usage()
{
        printf "\n$0 [-b /path/to/unrar] [-B /path/to/john] [-f rarfile] [-w wordlist] [-i maxlen:chartype] [-r]\n"
	printf "       \"chartype\" may be alpha, digits, alnum or all\n"
	printf "\nexamples:\n"
	printf "$0 -f /tmp/test.rar -w ./passwords.txt\n"
	printf "$0 -b /opt/rar/bin/unrar -B /usr/sbin/john -f /tmp/test.rar -i 4:digits\n\n"
	exit 1
}

die()
{
        printf "$@\n"
        exit 1
}

if [ ! -n "`which unrar`" ]
then
	die "\nunrar not found.\n"
fi

fcnt=0;
RAR=unrar
RARPARAMS="t -p"
JOHN=john

while getopts ":f:w:l:i:b:B:r" Option
do
	case $Option in
		f) if [ -e ${OPTARG} ]; then FILE=${OPTARG};else die "$OPTARG does not exist.\n";fi;;
		w) if [ -e ${OPTARG} ]; then total=`wc -l ${OPTARG} | awk '{print $1}'`;cmd="cat ${OPTARG}";else die "$OPTARG does not exist.\n";fi;;
		l) fcnt=${OPTARG};;
		i) john=y;cmd="$JOHN -stdout:`echo ${OPTARG} | awk -F: '{print $1}'` -i:`echo ${OPTARG} | awk -F: '{print $2}'`";;
		b) RAR=${OPTARG};;
		B) JOHN=${OPTARG};;
		r) john=y;cmd="john -restore";;
		*) usage;;
	esac
done

if [ "$cmd" = "" ]
then
	usage
fi

cnt=0
starttime=`date +'%s'`
RETVAL=0
echo

$cmd | while read pwd
do

	cnt=$[$cnt + 1]

	if [ $fcnt -le $cnt ]
	then
		if [ "${pwd}" != "" ]
		then
			$RAR $RARPARAMS"${pwd}" $FILE &>/dev/null
			RETVAL=$?
		fi

		diff=$[ `date +'%s'` - $starttime ]

		if [ $diff -eq 0 ]
		then
			diff=1
		fi
		persec=$[${cnt} / ${diff}]

		if [ $persec -eq 0 ]
		then
			persec=1
		fi

		if [ "$john" != "y" ]
		then
			todo=$[$total - $cnt]
			echo "[$cnt/$todo/$total] [${persec}/s] [$diff/$[ ${todo} / ${persec} ]s]: ${pwd}"
		else
			# (todo &) total ausrechnen -> alpha=26 * stellen
			echo "[$cnt] [${persec}/s]: ${pwd}"
		fi

		if [ $RETVAL -eq 0 ]
		then
			$RAR $RARPARAMS"${pwd}" $FILE &>/dev/null
			if [ $? -eq 0 ]
			then
				echo -e "\nPassword found: ${pwd}"
			fi
			exit
		fi
	fi

done
echo

if [ ! $RETVAL -eq 0 ]
then
	echo -e "Sorry, password not found.\n"
fi

