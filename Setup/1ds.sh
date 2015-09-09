#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-2014 Al Caughey
# All rights reserved.
#
#  This program recreates a single entry in the  monthly usage files
#  based upon the hourly age file for the specified day.
#
#  The original files are not altered in any way but you should
#  back things up beforehand just in case!  Use at your own risk.
#
#  Updated: Apr 21, 2014 - added this header
#
##########################################################################

_loglevel=1
_unlimited_usage=1
_baseDir="/mnt/sda1/yamon/"
_dataDir="data/"
_hourlyFileName="hourly_data.js"
_usageFileName="mac_data2.js"

send2log(){
	[ "$2" -ge "$_loglevel" ] && echo "$1"
}
getCV()
{
	result=$(echo "$1" | grep -o "\"$2\":[\"0-9]*" | grep -o "[0-9]*");
	[ -z $result ] && result='0'
	echo "$result"
}

digitAdd()
{
	local n1=$1
	local n2=$2
	local l1=${#n1}
	local l2=${#n2}
	if [ "$l1" -lt "10" ] && [ "$l1" -lt "10" ] ; then
		echo $(($n1+$n2))
		return
	fi
	local carry=0
	local total=''
	local d1=0
	local d2=0
	local s=0
	local sum=0
	while [ "$l1" -gt "0" ] || [ "$l2" -gt "0" ]; do
		d1=0
		d2=0
		l1=$(($l1-1))
		l2=$(($l2-1))
		[ "$l1" -ge "0" ] && d1=${n1:$l1:1}
		[ "$l2" -ge "0" ] && d2=${n2:$l2:1}
		s=$(($d1+$d2+$carry))
		sum=$(($s%10))
		carry=$(($s/10))
		total="$sum$total"
	done
	[ "$carry" -eq "1" ] && total="$carry$total"
	echo $total
}
digitSub()
{
	local n1=$(echo "$1" | sed 's/-*//')
	local n2=$(echo "$2" | sed 's/-*//')
	local l1=${#n1}
	local l2=${#n2}
	if [ "$l1" -lt "10" ] && [ "$l1" -lt "10" ] ; then
		echo $(($n1-$n2))
		return
	fi
	local b=0
	local total=''
	local d1=0
	local d2=0
	local d=0
	while [ "$l1" -gt "0" ] || [ "$l2" -gt "0" ]; do
		d1=0
		d2=0
		l1=$(($l1-1))
		l2=$(($l2-1))
		[ "$l1" -ge "0" ] && d1=${n1:$l1:1}
		[ "$l2" -ge "0" ] && d2=${n2:$l2:1}
		[ "$d2" == "-" ] && d2=0
		d1=$(($d1-$b))
		b=0
		[ $d2 -gt $d1 ] && b="1"
		d=$(($d1+$b*10-$d2))
		total="$d$total"
	done
	[ "$b" -eq "1" ] && total="-$total"
	echo $(echo "$total" | sed 's/0*//')
}

updateHourly2Monthly()
{
	send2log "=== updateHourly2Monthly === " 0
	#local _pMonth=$_cMonth
	#local _pYear=$_cYear
	local _pDay=$1
	local _pMonth=$2
	local _pYear=$3

	local _prevhourlyUsageDB="$_baseDir$_dataDir$_pYear-$_pMonth-$_pDay-$_hourlyFileName"
	if [ ! -f "$_prevhourlyUsageDB" ]; then
		send2log "*** Hourly usage file not found ($_prevhourlyUsageDB)" 2
		return
	fi
	local hsum=''
	local p_pnd_d=0
	local p_pnd_u=0
	local p_uptime=0
	local p_do_tot=0
	local p_up_tot=0
	local _maxInt="4294967295"
	local findstr=".*\"hour\":\"start\".*"
	local srch=$(cat "$_prevhourlyUsageDB")
	local cLine=$(echo "$srch" | grep -i "$findstr")
	local p_uptime=$(getCV "$cLine" "uptime")
	send2log "  >>> reading from $_prevhourlyUsageDB " 0
	while read hline
	do
		local mac=$(echo "$hline" | grep -io '\"mac\":\"[a-z0-9\:]*\"' | grep -io '\([a-z0-9]\{2\}\:\)\{5,\}[a-z0-9]\{2\}');
		local down=$(getCV "$hline" "down")
		local up=$(getCV "$hline" "up")
		local hr=$(getCV "$hline" "hour")
		if [ -z "$mac" ] && [ "$up" == "0" ] && [ "$down" == "0" ]; then
			send2log "  >>> skipping: $hline " 0
			continue
		elif [ -z "$mac" ] ; then
			fn="dtp"
			m_nm=''
			[ "$p_pnd_d" == "0" ] && p_pnd_d=$down
			[ "$p_pnd_u" == "0" ] && p_pnd_u=$up
		else
			fn="dt"
			m_nm="\"mac\":\"$mac\","
		fi
		local findstr="$fn({$m_nm\"day\":\"$_pDay\".*})"
		local cLine=$(echo "$hsum" | grep -i "$findstr")
		[ "$fn" == "dt" ] && [ "$_unlimited_usage" -eq "1" ] && ul_do=$(getCV "$hline" "ul_do")
		[ "$fn" == "dt" ] &&  [ "$_unlimited_usage" -eq "1" ] && ul_up=$(getCV "$hline" "ul_up")

		if [ -z "$cLine" ] ; then		#Add a new line
			local newentry="$fn({$m_nm\"day\":\"$_pDay\",\"down\":$down,\"up\":$up})"
			[ "$fn" == "dt" ] && [ "$_unlimited_usage" -eq "1" ] && newentry="$fn({$m_nm\"day\":\"$_pDay\",\"down\":$down,\"up\":$up,\"ul_do\":$ul_do,\"ul_up\":$ul_up})"
			hsum="$hsum
$newentry"
			send2log "  >>> Add new line:\t$newentry " 0
		elif [ "$fn" == "dt" ] ; then	#Update an existing hourly line
			local do_tot=$(getCV "$cLine" "down")
			local up_tot=$(getCV "$cLine" "up")
			do_tot=$(digitAdd "$do_tot" "$down")
			up_tot=$(digitAdd "$up_tot" "$up")
			[ "$do_tot" \< "0" ] && do_tot=$(digitSub "$_maxInt" "$do_tot")
			[ "$up_tot" \< "0" ] && up_tot=$(digitSub "$_maxInt" "$up_tot")
			if [ "$_unlimited_usage" -eq "1" ] ; then
				local ul_do_tot=$(getCV "$cLine" "ul_do")
				local ul_up_tot=$(getCV "$cLine" "ul_up")
				ul_do_tot=$(digitAdd "$ul_do_tot" "$ul_do")
				ul_up_tot=$(digitAdd "$ul_up_tot" "$ul_up")
				local newentry="$fn({$m_nm\"day\":\"$_pDay\",\"down\":$do_tot,\"up\":$up_tot,\"ul_do\":$ul_do_tot,\"ul_up\":$ul_up_tot})"
			else
				local newentry="$fn({$m_nm\"day\":\"$_pDay\",\"down\":$do_tot,\"up\":$up_tot})"
			fi
			hsum=$(echo "$hsum" | sed "s/$findstr/$newentry/g")
			send2log "  >>> update existing line:\t$newentry " 0

		else	#Update an existing PND line
			   svd=$(digitSub "$down" "$p_pnd_d")
			svu=$(digitSub "$up" "$p_pnd_u")
			local uptime=$(getCV "$hline" "uptime")
			uptime="$(echo $uptime | sed 's/\.[0-9]{2}//')"
			if [ "$uptime" -gt "$p_uptime" ] ; then
				[ "$svd" \< "0" ] && svd=$(digitSub "$_maxInt" "$svd")
				[ "$svu" \< "0" ] && svu=$(digitSub "$_maxInt" "$svu")
				p_do_tot=$(digitAdd "$p_do_tot" "$svd")
				p_up_tot=$(digitAdd "$p_up_tot" "$svu")
				local newentry="$fn({$m_nm\"day\":\"$_pDay\",\"down\":$p_do_tot,\"up\":$p_up_tot})"
				hsum=$(echo "$hsum" | sed "s/$findstr/$newentry/g")
				send2log "  >>> update existing dtp line:\t$newentry " 1
			else
				send2log "  >>> Server rebooted... $hr - no update /tuptime:$uptime\t p_uptime:$p_uptime" 2
			fi
			p_pnd_d=$down
			p_pnd_u=$up
			p_uptime=$uptime
		fi
	done < $_prevhourlyUsageDB

	echo "$hsum" >> $_macUsageDB
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	sed -i "s~var monthly_updated=.*~var monthly_updated=\"$ds\"~" $_macUsageDB
	#copyfiles "$_macUsageDB" "$_macUsageWWW"
	send2log "=== done updateHourly2Monthly === " 0
}

send2log "=== updateHourly2Monthly === " 2
if [ -z $1 ] && [ -z $2 ] ; then
	send2log "You must specify at least two parameters!
***************************
usage h2m.sh [startday] [month] [[year]] --> process all days for the billing period start on
	 \`startday\` of \`month\` and going to \`startday -1\` of the next month
  if year is omitted, it is assumed to be the current year
***************************" 2
	exit 0
fi

rday=$(printf %02d $1)
rMonth=$(printf %02d $2)
if [ -z $3 ] ;  then
	rYear=$(date +%Y)
else
	rYear=$3
fi
_macUsageDB="$_baseDir$_dataDir$rYear-$rMonth-$rday-$_usageFileName"
ds=$(date +"%Y-%m-%d %H:%M:%S")
touch $_macUsageDB

send2log "Processing data file: $rYear-$rMonth-$rday" 2
send2log ">>> saving to: $_macUsageDB" 2

local c=$1


local d=$(printf %02d $c)
updateHourly2Monthly "$d" "$rMonth" "$rYear"


















send2log "=== done updateHourly2Monthly ===

Note: the new monthly usage files have been named *.$_usageFileName...
You may have to rename them before they can be used by the reports
(By default a 2 is appended to the base name so that the original files
are not overwritten)." 2
