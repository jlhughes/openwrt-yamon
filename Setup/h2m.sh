#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-2015 Al Caughey
# All rights reserved.
#
#  This program recreates the monthly usage files from the hourlies.
#
#  The original files are not altered in any way but you should
#  back things up beforehand just in case!  Use at your own risk.
#
#  Updated:
#  - Apr 21, 2014 - added this header
#  - Oct 19, 2014 - now counts server reboots
#  - Mar 29, 2015 - now reads config.file and accounts for the value of _organizeData
#  - Aug 9, 2015 - fixed octal issues (leading zeroes on months)
#  - Aug 18, 2015 - replaced for...seq with while (for old firmware versions)
#
##########################################################################
d_baseDir=`dirname $0`
_configFile="$d_baseDir"'/config.file'
d_usageFileName="mac_data2.js"
_loglevel=0

send2log(){
	[ "$2" -ge "$_loglevel" ] && echo "$1"
}
getCV()
{
	local result=$(echo "$1" | grep -io "\"$2\":[\"0-9]\{1,\}" | grep -o "[0-9]\{1,\}");
	[ -z $result ] && result=0
	echo "$result"
}
digitAdd()
{
	local n1=$1
	local n2=$2
	local l1=${#n1}
	local l2=${#n2}
	if [ "$l1" -lt "10" ] && [ "$l2" -lt "10" ] ; then
		total=$(($n1+$n2))
		echo $total
		return
	fi
	local carry=0
	local total=''
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
	if [ "$l1" -lt "10" ] && [ "$l2" -lt "10" ] ; then
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
	local _pMonth=${_pMonth#0}
	local _pYear=$3
	local rMonth=$_pMonth
	local rYear=$_pYear

	if [ "$_pDay" -lt "$_ispBillingDay" ] ; then
		local rMonth=$(($rMonth-1))
		if [ "$rMonth" == "0" ] ; then
			rMonth=12
			local rYear=$(($rYear-1))
		fi
	fi
	_pMonth=$(printf %02d $_pMonth)
	rMonth=$(printf %02d $rMonth)
	#local savePath="$_baseDir$_dataDir"
	#case $_organizeData in
	#	(*"0"*)
	#		local savePath="$_baseDir$_dataDir"
	#	;;
	#	(*"1"*)
	#		local savePath="$_baseDir$_dataDir$rYear/"
	#	;;
	#	(*"2"*)
	#		local savePath="$_baseDir$_dataDir$rYear/$rMonth/"
	#	;;
	#esac

	local _prevhourlyUsageDB="$savePath$_pYear-$_pMonth-$_pDay-$_hourlyFileName"
	if [ ! -f "$_prevhourlyUsageDB" ]; then
		send2log "*** Hourly usage file not found ($_prevhourlyUsageDB)  (_organizeData:$_organizeData)" 2
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
	local srb=0
	local reboots=''
	while read hline
	do
		local mac=$(echo "$hline" | grep -io '\"mac\":\"[a-z0-9\:\-]*\"' | cut -f4 -d"\"");
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
		if [ "$fn" == "dt" ] && [ "$_unlimited_usage" -eq "1" ] ; then
			ul_do=$(getCV "$hline" "ul_do")
			ul_up=$(getCV "$hline" "ul_up")
		fi
		send2log "  >>> fn: $fn	mac: $mac   hline: $hline" 0
		if [ -z "$cLine" ] ; then		#Add a new line
			local newentry="$fn({$m_nm\"day\":\"$_pDay\",\"down\":$down,\"up\":$up})"
			[ "$fn" == "dt" ] && [ "$_unlimited_usage" -eq "1" ] && newentry="$fn({$m_nm\"day\":\"$_pDay\",\"down\":$down,\"up\":$up,\"ul_do\":$ul_do,\"ul_up\":$ul_up})"
			hsum="$hsum
$newentry"
			send2log "  >>> Add new line:	$newentry " 0
		elif [ "$fn" == "dt" ] ; then	#Update an existing hourly line
			local do_tot=$(getCV "$cLine" "down")
			local up_tot=$(getCV "$cLine" "up")

			do_tot=$(digitAdd "$do_tot" "$down")
			up_tot=$(digitAdd "$up_tot" "$up")
			[ "$do_tot" \< "0" ] && send2log "  >>> do_tot rolled over --> $do_tot" 0
			[ "$up_tot" \< "0" ] && send2log "  >>> up_tot rolled over --> $up_tot" 0
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
			hsum=$(echo "$hsum" | sed -e "s/$findstr/$newentry/g")
			send2log "  >>> update existing line:	$newentry " 0

		else	#Update an existing PND line
			local uptime=$(getCV "$hline" "uptime")
			send2log "  >>> hline: $hline" 0
			if [ "$uptime" -gt "$p_uptime" ] ; then
				svd=$(digitSub "$down" "$p_pnd_d")
				svu=$(digitSub "$up" "$p_pnd_u")
				[ "$svd" \< "0" ] && send2log "  >>> svd rolled over --> $svd" 0
				[ "$svu" \< "0" ] && send2log "  >>> svu rolled over --> $svu" 0
				[ "$svd" \< "0" ] && svd=$(digitSub "$_maxInt" "$svd")
				[ "$svu" \< "0" ] && svu=$(digitSub "$_maxInt" "$svu")
				p_do_tot=$(digitAdd "$p_do_tot" "$svd")
				p_up_tot=$(digitAdd "$p_up_tot" "$svu")
				send2log "  >>> update existing dtp line:	$newentry " 0
			else
				svd=$down
				svu=$up
				p_do_tot=$(digitAdd "$p_do_tot" "$svd")
				p_up_tot=$(digitAdd "$p_up_tot" "$svu")
				srb=$(($srb + 1))
				reboots=",\"reboots\":\"$srb\""
				send2log "  >>> Server rebooted... $hr - partial update /tuptime:$uptime	 p_uptime:$p_uptime$reboots" 2
			fi
			send2log "  >>> fn: $fn	hr: $hr	uptime: $uptime	 p_uptime: $p_uptime	svd: $svd	svu: $svu " 0
			local newentry="$fn({$m_nm\"day\":\"$_pDay\",\"down\":$p_do_tot,\"up\":$p_up_tot$reboots})"
			hsum=$(echo "$hsum" | sed -e "s/$findstr/$newentry/g")
			send2log "  >>> p_do_tot: $p_do_tot	p_up_tot: $p_up_tot " 0
			p_pnd_d=$down
			p_pnd_u=$up
			p_uptime=$uptime
		fi
	done < $_prevhourlyUsageDB

	echo "$hsum" >> $_macUsageDB
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	sed -i "s~var monthly_updated=.*~var monthly_updated=\"$ds\"~" $_macUsageDB
	send2log "=== done updateHourly2Monthly === " 0
}

send2log "=== updateHourly2Monthly === " 2
if [ ! -f "$_configFile" ] ; then
	send2log "*** Cannot find  \`config.file\` in the following location:
>>>	$_configFile
If you are using a different default directory (other than the one specified above),
you must edit lines 19-20 in this file to point to your file location.
Otherwise, check spelling and permissions." 0
	exit 0
fi

if [ -z $1 ] && [ -z $2 ] ; then
	send2log "You must specify at least two parameters!
***************************
usage h2m.sh [startday] [month] [[year]] [[just]] --> process all days for the billing period start on
	 \`startday\` of \`month\` and going to \`startday -1\` of the next month
  if \`year\` is omitted, it is assumed to be the current year
  if \`just\` is included, then just that day in the specified interval will be updated
***************************" 0
	exit 0
fi

send2log "  Reading config.file " 0
while read row
do
	eval $row
done < $_configFile

_usageFileName=$d_usageFileName
local c=$1
local mo=$2
mo=${mo#0}
rday=$(printf %02d $c)
rMonth=$(printf %02d $mo)

if [ -z $3 ] ;  then
	rYear=$(date +%Y)
else
	rYear=$3
fi
if [ ! -z $4 ] ; then
	just=$4
fi

local savePath="$_baseDir$_dataDir"
case $_organizeData in
	(*"0"*)
		local savePath="$_baseDir$_dataDir"
	;;
	(*"1"*)
		local savePath="$_baseDir$_dataDir$rYear/"
	;;
	(*"2"*)
		local savePath="$_baseDir$_dataDir$rYear/$rMonth/"
	;;
esac

local _prevhourlyUsageDB="$savePath$rYear-$rMonth-$rday-$_hourlyFileName"

_macUsageDB="$savePath$rYear-$rMonth-$rday-$_usageFileName"
ds=$(date +"%Y-%m-%d %H:%M:%S")
[ ! -f "$_macUsageDB" ] && touch $_macUsageDB

echo "var monthly_created=\"$ds\"
var monthly_updated=\"$ds\"" > $_macUsageDB

send2log "Processing data files for billing interval: $rYear-$rMonth-$rday" 2
send2log ">>> saving to: $_macUsageDB" 2
send2log ">>> just: $just" 2

local i=$c
while [  $i -le "31" ]; do
	[ ! -z $just ] && [ "$just" -ne "$i" ] && continue
	echo "$i"
	local d=$(printf %02d $i)
	updateHourly2Monthly "$d" "$rMonth" "$rYear"
    i=$(($i+1))
done
send2log ">>> Finished to end of month" 2
if [ "$2" -eq "12" ]; then
	rMonth='01'
	rYear=$(($rYear+1))
else
	local nm=$(($mo+1))
	rMonth=$(printf %02d $nm)
fi

i=1
while [  $i -lt "$c" ]; do
	[ ! -z $just ] && [ "$just" -ne "$i" ] && continue
	echo "$i"
	d=$(printf %02d $i)
	updateHourly2Monthly "$d" "$rMonth" "$rYear"
    i=$(($i+1))
done
send2log ">>> Finished start to end of next interval" 2

ds=$(date +"%Y-%m-%d %H:%M:%S")
sed -i "s~var monthly_updated=.*~var monthly_updated=\"$ds\"~" $_macUsageDB

send2log "=== done updateHourly2Monthly ===

Note: the new monthly usage files have been named *.$_usageFileName...
You may have to rename them before they can be used by the reports
(By default a 2 is appended to the base name so that the original files
are not overwritten)." 2
