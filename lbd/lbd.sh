#!/bin/bash
# lbd (load balancing detector) detects if a given domain uses
# DNS and/or HTTP Load-Balancing (via Server: and Date: header and diffs between server answers)
# Copyright (C) 2010-2014 Stefan Behte
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# 
# License: GNU General Public License, version 2
# http://www.gnu.org/licenses/gpl-2.0.html
#
# Contact me, if you have any new ideas, bugs/bugfixes, recommondations or questions!
# Please also contact me, if you just like the tool. :)
#  
# craig at haquarter dot de
#
# 0.1:	- initial release
# 0.2:	- fix license for fedora 
#	- fix indenting
# 0.3:	- fix bug if dns server returns same IP multiple times
#         (fix by bit bori, thanks!)
#	- fix bug if there is no date header
#	  (fix by Paul Rib, thanks!)
# 0.4:	- support HTTPs, support different ports
#	  (thanks Bharadwaj Machiraju)

QUERIES=50
DOMAIN=$1
PORT=${2-80} # Use default port 80, if not given
if [ "$3" = "https" ]
then
	HTTPS=true
else
	HTTPS=false
fi
METHODS=""

echo 
echo "lbd - load balancing detector 0.4 - Checks if a given domain uses load-balancing."
echo "                                    Written by Stefan Behte (http://ge.mine.nu)"
echo "                                    Proof-of-concept! Might give false positives."

if [ "$1" = "" ]
then
	echo "usage: $0 domain [port] {https}"
	echo
	exit -1
fi

echo -e -n "\nChecking for DNS-Loadbalancing:"
NR=`host $DOMAIN | grep "has add" | uniq | wc -l`

if [ $NR -gt 1 ]
then
	METHODS="DNS"
	echo " FOUND"
	host $DOMAIN | grep "has add" | uniq
	echo
else
	echo " NOT FOUND"
fi

echo -e "Checking for HTTP-Loadbalancing [Server]: "
for ((i=0 ; i< $QUERIES ; i++))
do
	if [ $HTTPS = true ]
	then
		printf "HEAD / HTTP/1.1\r\nhost: $DOMAIN\r\nConnection: close\r\n\r\n" | openssl s_client -host $DOMAIN -port $PORT -quiet > .nlog 2> /dev/null
	else
		printf "HEAD / HTTP/1.1\r\nhost: $DOMAIN\r\nConnection: close\r\n\r\n" | nc $DOMAIN $PORT > .nlog 2>/dev/null
	fi

	S=`grep -i "Server:" .nlog | awk -F: '{print $2}'`

	if ! grep "`echo ${S}| cut -b2-`" .log &>/dev/null
	then
		echo "${S}"
	fi
	cat .nlog >> .log
done

NR=`sort .log | uniq | grep -c "Server:"`

if [ $NR -gt 1 ]
then
	echo " FOUND"
	METHODS="$METHODS HTTP[Server]"
else
	echo " NOT FOUND"
fi
echo
rm .nlog .log


echo -e -n "Checking for HTTP-Loadbalancing [Date]: "
D4=

for ((i=0 ; i<$QUERIES ; i++))
do
	if [ $HTTPS = true ]
	then
		D=`printf "HEAD / HTTP/1.1\r\nhost: $DOMAIN\r\nConnection: close\r\n\r\n" | openssl s_client -host $DOMAIN -port $PORT -quiet 2> /dev/null | grep "Date:" | awk '{print $6}'`
	else
		D=`printf "HEAD / HTTP/1.1\r\nhost: $DOMAIN\r\nConnection: close\r\n\r\n" | nc $DOMAIN $PORT 2>/dev/null | grep "Date:" | awk '{print $6}'`
	fi
	printf "$D, "

        if [  "$D" == "" ]
	then
		echo "No date header found, skipping."
		break
	fi
	
	Df=$(echo " $D" | sed -e 's/:0/:/g' -e 's/ 0/ /g')
	D1=$(echo ${Df} | awk -F: '{print $1}')
	D2=$(echo ${Df} | awk -F: '{print $2}')
	D3=$(echo ${Df} | awk -F: '{print $3}')

	if [ "$D4" = "" ];  then   D4=0;  fi
	
	if [ $[ $D1 * 3600 + $D2 * 60 + $D3 ] -lt $D4 ]
	then
		echo "FOUND"
		METHODS="$METHODS HTTP[Date]"
		break;
	fi
	
	D4="$[ $D1 * 3600 + $D2 * 60 + $D3 ]"

	if [ $i -eq $[$QUERIES - 1] ]
	then
		echo "NOT FOUND" 
	fi
done

echo -e -n "\nChecking for HTTP-Loadbalancing [Diff]: "
for ((i=0 ; i<$QUERIES ; i++))
do
	if [ $HTTPS = true ]
	then
		printf "HEAD / HTTP/1.1\r\nhost: $DOMAIN\r\nConnection: close\r\n\r\n" | openssl s_client -host $DOMAIN -port $PORT -quiet 2> /dev/null | grep -v -e "Date:" -e "Set-Cookie" > .nlog
	else
		printf "HEAD / HTTP/1.1\r\nhost: $DOMAIN\r\nConnection: close\r\n\r\n" | nc $DOMAIN $PORT 2>/dev/null | grep -v -e "Date:" -e "Set-Cookie" > .nlog
	fi
	
	if ! cmp .log .nlog &>/dev/null && [ -e .log ]
	then
		echo "FOUND"
		diff .log .nlog | grep -e ">" -e "<"
		METHODS="$METHODS HTTP[Diff]"
		break;
	fi
	
	cp .nlog .log
	
	if [ $i -eq $[$QUERIES - 1] ]
	then
		echo "NOT FOUND" 
	fi
done

rm .nlog .log


if [ "$METHODS" != "" ]
then
	echo
	echo $DOMAIN does Load-balancing. Found via Methods: $METHODS
	echo
else
	echo
	echo $DOMAIN does NOT use Load-balancing.
	echo
fi

