#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-2015 Al Caughey
# All rights reserved.
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  See <http://www.usage-monitoring.com/license/> for a copy of the
#  GNU General Public License or see <http://www.gnu.org/licenses/>.
#
##########################################################################

##HISTORY
# 2.0.0 (2014-01-29): new version of the script
# 2.0.1 (2014-03-26): fixes to accommodate idiosyncrasies of various firmware versions
# 2.0.2 (2014-03-26): more fixes... undeclared variables, bad regexs, etc.
# 2.0.3 (2014-04-01): removed getPND etc. (will add it back in later); changed d_baseDir
# 2.0.4 (2014-04-01): merge doliveUpdates and updateUsage loops i; b) tweaked iptables regex; c)split downloada & uploads; d) corrected iptables options
# 2.0.5 (2014-04-20): added script to config.js; add _doCurrConnections; modified config.js
# 2.0.6 (2014-04-25): investigating getCV; replacing '0' & '=' with ==/-eq; fixed typo in digitAdd that allowed an integer overflow
# 2.0.7 (2014-05-01): modified regex in GetCV; added parameters for _wwwBU
# 2.0.8 (2014-05-01): more modified regexs, changed calculation for freeMem; added availMem; modified device name for new devices
# 2.0.9 (2014-05-28): added settings password; proc/net/dev data; changed a lot of variables to local
# 2.0.10 (2014-06-15): publish data after checking dates; tweaked send2log settings; changed regexs to Posix format;added uptime
# 2.0.11 (2014-07-27): added config entries for dnsmasq conf & leases; various fixes relating to measured at router values (in updateHourly2Monthly)
# - b/c: variants to fix Aug 1 date rollover;
# - d: fix in digitAdd;
# - e: fixed typo in updateHourly2Monthly())
# 2.0.12 (2014-08-05): started adding mac address for bridge, added digitSub and numerous fixes in updateHourly2Monthly()
# 2.0.13 (2014-08-12): tweaked outputs to log, added checks for _dnsmasq_conf and _dnsmasq_leases; added option for a bridge mac address
#  - a: fixes for bridging;
#  - b/c/d: more corrections to updateHourly2Monthly (to better handle restarts) and more fixes to bridging
# 2.0.14 (2014-08-17): check to see whether bridge mac exists in users.js; added defaults for owner & device names; check static leases & dnsmasq (for new device info) just once a day now...
# - b: added separator for owner & device name; no longer iterate through ARP entries for usage... now use a home-grown mac/ip list
# - c/d: numerous small fixes
# - e/f: new users.js is auto populated from static lease entries; small fixes
# - g: fixed gross oversight in setupIPRules re: currentIP_MAC (doh!)
# - h: went through code to ensure that greps where case did not matter were in fact case insensitive
# - i: fixed totals in updateHourly2Monthly() (by product of multiple IPs/MAC functionality)
# 2.0.15 (2014-09-27): consolidate fixes in 2.0.14
# - a: do a partial update of measured at router totals rather than skipping in updateHourly2Monthly; count reboots in monthly file
# - b: tweaks... make sure all hourly updates are logged
# 2.0.16 (2014-10-27): consolidate local copy functionality from startup into main script; fix daily backups
# 2.0.17 (2014-11-05): option to sync settings via a database; fixed br0 issue???; added option to exclude gateway
# 2.0.18 (2015-03-23): tweaked send2log; added Asuswrt-Merlin
# - b: forced line to uppercase when adding to currentIP_MAC in setupIPRules()
# - c: update acr if _includeBridge==1
# - d: added sendAlert (currently for new devices & issues in checkIPChain only); fixed endless loop if cannot get time upon start
# - e: added sendAlert (via msmtp - Adrian Spann)
# 2.1.0 (2015-03-28): added option to organize data
# - b: (2015-05-16): added symbolic link to data functionality and parameters
# - c: (2015-06-09) bug fixes... organize data issue resolved
# - d: (2015-07-21) added symlinks for all folders in /tmp/www; octal issues
# 2.2 (2015-08-07): `cause it's my birthday
# 2.2.1 (2015-08-12): changed mount/bind to ln - s; removed umount
# 2.2.2 (2015-08-13): removed sed -i (keep things in memory now); tweaked getNewDeviceName for OpenWRT (thanks Robert Micsutka)
# 2.2.3 (2015-08-24): re-tweaked getNewDeviceName for OpenWRT (case insensitive); fixed issue in serverloads
# 2.2.4 (2015-08-26): symlink fixes (thanks to Alex Moore)
# - a (2015-08-29): moved _updatefreq in configtxt string
# 2.2.5 (2015-09-09): tweaked issues with dolocalfiles and password protection for settings

#defaults
_version='2.2.5'
_file_version=2.2
d_firmware=0
_savedconfigMd5=''
_configMd5=''
_connectedUsers='/proc/net/arp'
YAMON_IP4='YAMON'
YAMON_IP6='YAMONv6'

#default parameters - these values may be updated in readConfig()
d_updatefreq=30
d_publishInterval=4
d_baseDir=`dirname $0`
_lang='en'
d_path2strings="$d_baseDir/strings/$_lang/"
d_setupWebDir="Setup/www/"
d_setupWebIndex="yamon2.html"
d_setupWebDev="yamon2.2.html"
d_dataDir="data/"
d_logDir="logs/"
d_wwwPath="/tmp/www/"
d_wwwJS="js/"
d_wwwCSS="css/"
d_wwwImages='images/'
d_wwwData="data/"
d_dowwwBU=0
d_wwwBU="wwwBU/"
d_usersFileName="users.js"
d_hourlyFileName="hourly_data.js"
d_usageFileName="mac_data.js"
d_configWWW="config.js"
d_symlink2data=1
d_enableLogging=1
d_log2file=1
d_loglevel=1
d_ispBillingDay=5
d_doDailyBU=1
d_tarBUs=0
d_doLiveUpdates=0
d_doCurrConnections=0
d_liveFileName="live_data.js"
d_dailyBUPath="daily-bu/"
d_unlimited_usage=0
d_unlimited_start="02:00"
d_unlimited_end="08:00"
d_lan_iface_only=0
d_settings_pswd=''
d_dnsmasq_conf="/tmp/dnsmasq.conf"
d_dnsmasq_leases="/tmp/dnsmasq.leases"
d_do_separator=""
d_includeBridge=0
d_bridgeMAC='XX:XX:XX:XX:XX:XX' #MUST be entered all upper case
d_bridgeIP='###.###.###.###'
d_defaultOwner='Unknown'
d_defaultDeviceName='New Device'
d_includeIPv6=0
d_doLocalFiles=0
d_dbkey=''
d_ignoreGateway=0
d_gatewayMAC=''
d_sendAlerts=0
d_organizeData=0
d_allowMultipleIPsperMAC=0

#globals
_macUsageDB=""
_hourlyUsageDB=""
_liveUsageDB=""
_usersFile=""
_macUsageWWW=""
_usersFileWWW=""
_hourlyFileName=""
_hourlyUsageWWW=""
_hourlyData=""
_currentConnectedUsers=""
_hData=""
_unlimited_usage=""
_unlimited_start=""
_unlimited_end=""
old_inUnlimited=0

_enableLogging=1
_log2file=1
_loglevel=1
_detanod=0
_ndAMS_dailymax=24
_log_str=''

showmsg()
{
	local wm=$1
	msg="$(cat "$d_path2strings$wm" )"
	[ ! -z "$2" ] && msg=$(echo "$msg" | sed -e "s/15 seconds/$2 seconds/g" )
	echo -e "$msg"
}
send2log()
{
	[ "$_enableLogging" -eq "0" ] && return
	[ "$2" -lt "$_loglevel" ] && return
	local ts=$(date +"%H:%M:%S")
	if [ ! -f "$logfilename" ] ; then
		echo "$_ds $ts $2 $1
[ NB - this message is being shown on the screen because
  the path to the log file won't be known until
  the config file has been read. ]
"
		return
	fi
	[ "$_log2file" -gt "0" ] && _log_str="$_log_str
$_ds	$ts $2	$1"
	[ "$_log2file" -ne "1" ] && echo -e "$_ds $ts $2 $1"
}

sendAlert()
{

	local subj="$1"
	local msg="$2"
	if [ -z "$_sendAlertTo" ] ; then
		send2log "sendAlert:: _sendAlertTo is null... cannot send subj: $subj  msg: $msg" 2
		return
	fi
	[ -z "$ndAMS" ] && ndAMS=0
	if [ "$ndAMS" -gt "$_ndAMS_dailymax" ] ; then
		send2log "sendAlert:: exceeded daily alerts max... cannot send subj: $subj  msg: $msg" 0
		return
	fi

	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	msg="$msg \n\n Message sent: $ds"

	if [ "$ndAMS" -eq "$_ndAMS_dailymax" ] ; then
 		send2log "sendAlert:: exceeded daily alerts max... cannot send subj: $subj  msg: $msg" 2
		subj="Please check your YAMon Settings!"
		msg="You have exceeded your alerts allocation (max $_ndAMS_dailymax messages per day).  This typically means that there is something wrong in your settings or configuration.  Please contact Al if you have any questions."
	fi

	if [ "$_sendAlerts" -eq "1" ] ; then
		subj=$(echo "$subj" | tr ' ' '_')
		msg=$(echo "$msg" | tr ' ' '_')
		local url="http://usage-monitoring.com/current/sendmail.php?1&t=$_sendAlertTo&s=$subj&m=$msg"
		wget "$url" -q -O /tmp/sndm.txt
		local res=$(cat /tmp/sndm.txt)
		send2log "calling sendAlert via usage-monitoring.com - url: $url  subj: $subj  msg: $msg  res: $res" 2
	elif [ "$_sendAlerts" -eq "2" ] ; then
		ECHO=/bin/echo
		$ECHO -e "Subject: $subj\n\n$msg\n\n" | $_path2MSMTP -C $_MSMTP_CONFIG -a gmail $_sendAlertTo
		send2log "calling sendAlert via msmtp - subj: $subj  msg: $msg" 2
	fi
	ndAMS=$(($ndAMS+1))
}
copyfiles(){
	local src=$1
	local dst=$2
	$(cp -a $src $dst)
	local res=$?
	if [ "$res" -eq "1" ] ; then
		local pre='  !!!'
		local pos=' failed '
	else
		local pre='  >>>'
		local pos=' successful'
	fi
	local lvl=$(($res+1))
	send2log "$pre Copy from $src to $dst$pos ($res)" $lvl
}
setDefaults()
{
	if [ "$_configFile" == "--help" ] ; then
		showmsg 'help.txt'
		exit 0
	fi
	if [ "$_configFile" == "--stop" ] ; then

		if [ -d "$_lockDir" ] ; then
			local dv=$(cat "$d_baseDir/config.file" | grep -io  "_updatefreq=[0-9]\{1,\}" | cut -d= -f2)
   			showmsg 'stop.txt' "$dv"
			rmdir "$_lockDir"
		else
			showmsg 'notrunning.txt'
		fi
		exit 0
	fi
	#enough of the special parameters... now down to business
	if [ ! -d "$_lockDir" ] ; then
		mkdir "$_lockDir"
		showmsg 'title.txt'
		echo "
YAMon :: $_version

"
	else
		showmsg 'running.txt'
		exit 0
	fi
	send2log "=== Checking the script parameters ===" 0
	if [ -z "$_configFile" ] ; then
		showmsg 'started.txt'
		_configFile="$d_baseDir"'/config.file'
		send2log "=== _configFile: $_configFile" 0
	elif [ ! -f "$_configFile" ] ; then
		showmsg 'noconfig.txt'
		rmdir $_lockDir
		exit 0
	elif [ ! -s "$_configFile" ] ; then
		showmsg 'zeroconfig.txt'
		rmdir $_lockDir
		exit 0
	fi
}
readConfig(){
	[ "$started" -eq "1" ] && send2log "=== Read the Configuration file ===" 1
	local _configMd5=$(md5sum $_configFile | cut -f1 -d" ")
	if [ "$_configMd5" == "$_savedconfigMd5" ] ; then
		send2log '  >>> _configMd5 == _savedconfigMd5' -1
		return
	fi
	_savedconfigMd5="$_configMd5"
	[ "$started" -eq "1" ] && send2log "  >>> _configMd5 --> $_configMd5   _savedconfigMd5 --> $_savedconfigMd5  " -1
	local configString=$(cat $_configFile)
	while read row
	do
		eval $row
	done < $_configFile
	if [ -z "$_updatefreq" ] || [ -z "$_publishInterval" ] ; then
		send2log '  >>> Problems in config.file... paremeters not set properly... using defaults' 2
	fi
	#if the parameters are missing then set them to the defaults
	[ -z "$_firmware" ] && _firmware=$d_firmware
	[ -z "$_updatefreq" ] && _updatefreq=$d_updatefreq
	[ -z "$_publishInterval" ] && _publishInterval=$d_publishInterval
	[ -z "$_enableLogging" ] && _enableLogging=$d_enableLogging
	[ -z "$_log2file" ] && _log2file=$d_log2file
	[ -z "$_loglevel" ] && _loglevel=$d_loglevel
	[ -z "$_ispBillingDay" ] && _ispBillingDay=$d_ispBillingDay
	[ -z "$_usersFileName" ] && _usersFileName=$d_usersFileName
	[ -z "$_usageFileName" ] && _usageFileName=$d_usageFileName
	[ -z "$_hourlyFileName" ] && _hourlyFileName=$d_hourlyFileName
	[ -z "$_doLiveUpdates" ] && _doLiveUpdates=$d_doLiveUpdates
	[ -z "$_doCurrConnections" ] && _doCurrConnections=$d_doCurrConnections
	[ -z "$_liveFileName" ] && _liveFileName=$d_liveFileName
	[ -z "$_doDailyBU" ] && _doDailyBU=$d_doDailyBU
	[ -z "$_dailyBUPath" ] && _dailyBUPath=$d_dailyBUPath
	[ -z "$_tarBUs" ] && _tarBUs=$d_tarBUs
	[ -z "$_baseDir" ] && _baseDir=$d_baseDir
	[ -z "$_setupWebDir" ] && _setupWebDir=$d_setupWebDir
	[ -z "$_setupWebIndex" ] && _setupWebIndex=$d_setupWebIndex
	[ -z "$_setupWebDev" ] && _setupWebDev=$d_setupWebDev
	[ -z "$_dataDir" ] && _dataDir=$d_dataDir
	[ -z "$_logDir" ] && _logDir=$d_logDir
	[ -z "$_wwwPath" ] && _wwwPath=$d_wwwPath
	[ -z "$_wwwJS" ] && _wwwJS=$d_wwwJS
	[ -z "$_wwwCSS" ] && _wwwCSS=$d_wwwCSS
	[ -z "$_wwwImages" ] && _wwwImages=$d_wwwImages
	[ -z "$_wwwData" ] && _wwwData=$d_wwwData
	[ -z "$_dowwwBU" ] && _dowwwBU=$d_dowwwBU
	[ -z "$_wwwBU" ] && _wwwBU=$d_wwwBU
	[ -z "$_configWWW" ] && _configWWW=$d_configWWW
	[ -z "$_unlimited_usage" ] && _unlimited_usage=$d_unlimited_usage
	[ -z "$_unlimited_start" ] && _unlimited_start=$d_unlimited_start
	[ -z "$_unlimited_end" ] && _unlimited_end=$d_unlimited_end
	[ -z "$_lan_iface_only" ] && _lan_iface_only=$d_lan_iface_only
	[ -z "$_settings_pswd" ] && _settings_pswd=$d_settings_pswd
	[ -z "$_dnsmasq_conf" ] && _dnsmasq_conf=$d_dnsmasq_conf
	[ -z "$_dnsmasq_leases" ] && _dnsmasq_leases=$d_dnsmasq_leases
	[ -z "$_do_separator" ] && _do_separator=$d_do_separator
	[ -z "$_includeBridge" ] && _includeBridge=$d_includeBridge
	[ -z "$_defaultOwner" ] && _defaultOwner=$d_defaultOwner
	[ -z "$_defaultDeviceName" ] && _defaultDeviceName=$d_defaultDeviceName
	[ -z "$_doLocalFiles" ] && _doLocalFiles=$d_doLocalFiles
	[ -z "$_dbkey" ] && _dbkey=$d_dbkey
	[ -z "$_sendAlerts" ] && _sendAlerts=$d_sendAlerts
	[ -z "$_ignoreGateway" ] && _ignoreGateway=$d_ignoreGateway
	[ -z "$_gatewayMAC" ] && _gatewayMAC=$d_gatewayMAC
	[ -z "$_organizeData" ] && _organizeData=$d_organizeData
	[ -z "$_allowMultipleIPsperMAC" ] && _allowMultipleIPsperMAC=$d_allowMultipleIPsperMAC
	[ -z "$_symlink2data" ] && _symlink2data=$d_symlink2data
	if [ "$_includeBridge" == "1" ] ; then
		[ -z "$_bridgeMAC" ] && _bridgeMAC=$d_bridgeMAC
		[ -z "$_bridgeIP" ] && _bridgeIP=$d_bridgeIP
		_bridgeMAC=$(echo "$_bridgeMAC" | tr '[a-z]' '[A-Z]')
	fi
	[ -z "$_includeIPv6" ] && _includeIPv6=$d_includeIPv6

	if [ "$_firmware" -eq "0" ]; then
		_lan_iface=$(nvram get lan_ifname)
		_conntrack="/proc/net/ip_conntrack"
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport)=/, ""); printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$1,$1 == "tcp" ? $5 : $4,$1 == "tcp" ? $7 : $6,$1 == "tcp" ? $6 : $5,$1 == "tcp" ? $8 : $7; } END { print "[ null ] ]"}'
	elif [ "$_firmware" -eq "1" ]; then
		_lan_iface="br-lan"
		_conntrack="/proc/net/nf_conntrack"
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport)=/, ""); printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$3,$3 == "tcp" ? $7 : $6,$3 == "tcp" ? $9 : $8,$3 == "tcp" ? $8 : $7,$3 == "tcp" ? $10 : $9; } END { print "[ null ] ]"}'
	elif [ "$_firmware" -eq "2" ]; then
		_lan_iface=$(nvram get lan_ifname)
		_conntrack="/proc/net/ip_conntrack"
		_conntrack_awk='BEGIN { printf "var curr_connections=[ "} { gsub(/(src|dst|sport|dport)=/, ""); printf "[ '\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'','\''%s'\'' ],",$3,$3 == "tcp" ? $7 : $6,$3 == "tcp" ? $9 : $8,$3 == "tcp" ? $8 : $7,$3 == "tcp" ? $10 : $9; } END { print "[ null ] ]"}'
	fi

	_usersFile="$_baseDir$_dataDir$_usersFileName"

	[ "$_symlink2data" -eq "0" ] && _usersFileWWW="$_wwwPath$_wwwData$_usersFileName"

	[ ! -d "$_wwwPath$_wwwJS" ] && mkdir -p "$_wwwPath$_wwwJS"

	local configjs="$_wwwPath$_wwwJS$_configWWW"

	_liveFilePath="$_wwwPath$_wwwJS$_liveFileName"



	#Check for directories
	if [ "${_logDir:0:1}" == "/" ] ; then
		lfpath=$_logDir
	else
		lfpath=$_baseDir$_logDir
	fi
	logfilename="${lfpath}monitor-$_ds.log"
	ts=$(date +"%H:%M:%S")

	[ ! -d "$lfpath" ] && mkdir -p "$lfpath"
	[ ! -f "$logfilename" ] && echo "$_ds	$ts
---------------------------------------
YAMon :: version $_version
=======================================">>$logfilename
	[ "$started" -eq "0" ] && send2log "
---------------------------------------
Starting the Yet Another Monitor script [ log ]
version $_version
=======================================
" 2
	send2log "--- Configuration Settings ---
$configString
date	time	level	message	mac address	down	up" 2

	if [ ! -d "$_baseDir$_dataDir" ] ; then
		send2log "  >>> Creating data directory" 1
		mkdir -p "$_baseDir$_dataDir"
	fi

	if [ ! -f "$configjs" ] ; then
		send2log "  >>> config.js not found... creating new file: $configjs" 2
		touch $configjs
	fi
	configtxt="var _ispBillingDay=$_ispBillingDay
var _wwwData='$_wwwData'
var _scriptVersion='$_version'
var _usersFileName='$_usersFileName'
var _usageFileName='$_usageFileName'
var _hourlyFileName='$_hourlyFileName'
var _processors='$processors'
var _doLiveUpdates='$_doLiveUpdates'
var _updatefreq='$_updatefreq'"
	[ "$_doLiveUpdates" -eq "1" ] && configtxt="$configtxt
var _liveFileName='./$_wwwJS$_liveFileName'
var _doCurrConnections='$_doCurrConnections'"
configtxt="$configtxt
var _unlimited_usage='$_unlimited_usage'
var _doLocalFiles='$_doLocalFiles'
var _organizeData='$_organizeData'"
	[ "$_unlimited_usage" -eq "1" ] && configtxt="$configtxt
var _unlimited_start='$_unlimited_start'
var _unlimited_end='$_unlimited_end'
"
	[ "$_detanod" -eq 1 ] && configtxt="$configtxt
\$(document).ready(function (){\$(\"#_detanod\").hide()})"
	if [ ! "$_settings_pswd" == "" ] ; then
		_md5_pswd=$(echo -n "$_settings_pswd" | md5sum | awk '{print $1}')
		configtxt="$configtxt
var _settings_pswd='$_md5_pswd'"
	fi
	[ ! "$_dbkey" == "" ] && configtxt="$configtxt
var _dbkey='$_dbkey'"
	echo "$configtxt" > $configjs
	send2log "  >>> configjs --> $configjs" -1
	send2log "  >>> configtxt --> $configtxt" -1
}
checkIPv4Chain()
{
	local chain=$1
	send2log "=== checkIPv4Chain for $chain ===" 0
	foundRule=$(iptables -L FORWARD | grep -ic "$chain")
	if [ "$foundRule" -eq "1" ]; then
		send2log "  >>> Rule $chain exists in chain FORWARD ==> $foundRule" 0
	elif [ "$foundRule" -eq "0" ]; then
		send2log "  >>> Created rule $chain in chain FORWARD ==> $foundRule" 2
		iptables -N "$chain"
		iptables -I FORWARD -j "$chain"
	else
		send2log "  !!! Found $foundRule instances of $chain in chain FORWARD...  (Flushing FORWARD!)" 2
		[ "$_sendAlerts" -gt "0" ] && sendAlert "Problem in iptables!" "Found $foundRule instances of $chain in chain FORWARD...  (Flushing FORWARD!)"

		iptables -F FORWARD
		sleep 5
		iptables -I FORWARD -j "$chain"
	fi
}
checkIPv6Chain()
{
	local chain=$1
	send2log "=== checkIPv6Chain for $chain ===" 0
	foundRule=$(ip6tables -L FORWARD | grep -c "$chain")
	if [ "$foundRule" -eq "1" ]; then
		send2log "  >>> Rule $chain exists in chain FORWARD ==> $foundRule" 0
	elif [ "$foundRule" -eq "0" ]; then
		send2log "  >>> Created rule $chain in chain FORWARD ==> $foundRule" 2
		ip6tables -N "$chain"
		ip6tables -I FORWARD -j "$chain"
	else
		send2log "  !!! Found $foundRule instances of $chain in chain FORWARD...  (Flushed FORWARD!)" 2
		ip6tables -F FORWARD
		sleep 5
		ip6tables -I FORWARD -j "$chain"
	fi
}
checkIPv4()
{
	local chain=$1
	local ip=$2
	local tb=$3
	if [ -z "$tb" ] ; then
		send2log "  !!! checkIPv4 \`acr\` is null string?!?" 2
		[ "$_sendAlerts" -gt "0" ] && sendAlert "Problem in checkIPv4!" "checkIPv4 \`acr\` is null string?!?"
		return
	fi
	nm=$(echo "$tb" | grep -ic "$ip " )
	if [ "$nm" -eq "2" ]; then
		send2log "	>>> $ip -> $nm" -1
		send2log "		>>> Rules exist in $chain for $ip" 0
	elif [ "$nm" -eq "0" ]; then
		send2log "		>>> Added rules to $chain for $ip" 1
		iptables -I "$chain" -d ${ip} -j RETURN
		iptables -I "$chain" -s ${ip} -j RETURN
	else
		send2log "	!!! Incorrect number of rules for $ip in $chain -> $nm (Flushed $chain!)" 2
		[ "$_sendAlerts" -gt "0" ] && sendAlert "Problem in checkIPv4!" "Incorrect number of rules for $ip in $chain -> $nm (Flushed $chain!)"
		iptables -F $chain
	fi
}
checkIPv6()
{
	local chain=$1
	local ip=$2
	local tb=$3
	if [ -z "$tb" ] ; then
		send2log "  !!! checkIPv6 \`acr\` is null string?!?" 2
		[ "$_sendAlerts" -gt "0" ] && sendAlert "Problem in checkIPv6!" "checkIPv6 \`acr\` is null string?!?"
		return
	fi
	nm=$(echo "$tb" | grep -c "$ip " )
	if [ "$nm" -eq "2" ]; then
		send2log "	>>> $ip -> $nm" -1
		send2log "		>>> Rules exist in $chain for $ip" 0
	elif [ "$nm" -eq "0" ]; then
		send2log "		>>> Added rules to $chain for $ip" 1
		ip6tables -I "$chain" -d ${ip} -j RETURN
		ip6tables -I "$chain" -s ${ip} -j RETURN
	else
		send2log "	!!! Incorrect number of rules for $ip in $chain -> $nm (Flushed $chain!)" 2
		ip6tables -F $chain
	fi
}
getMACbyIP()
{
	local tip=$1
	local owsIP=$(echo "$_currentUsers" | grep -ic "\"$tip\"")
	if [ "$owsIP" -eq "1" ] ; then
		local mac=$(echo "$_currentUsers" | grep -i "\"$tip\"" | grep -io '\([a-z0-9]\{2\}\:\)\{5,\}[a-z0-9]\{2\}')
		echo "$mac"
	elif [ "$owsIP" -eq "0" ] ; then
		local mac=$(echo "$_currentConnectedUsers" | grep -i "\"$tip\"" | grep -io '\([a-z0-9]\{2\}\:\)\{5,\}[a-z0-9]\{2\}' )
		if [ -z "$mac" ] ; then
			echo "0"
		else
			echo "$mac"
		fi
	else
		echo "-1"
	fi
}
getNewDeviceName()
{
	send2log "=== getNewDeviceName ===" 0
	local dMac=$1
	local dName=$2
	local _nvr=''
	local result=''
	local _dnsc=''
	local _dnsl=''
	if [ ! -f "$_dnsmasq_conf" ] ; then
		send2log "  >>> specified path to _dnsmasq_conf ($_dnsmasq_conf) does not exist" 1
	else
		_dnsc=$(cat "$_dnsmasq_conf" | grep -i "dhcp-host=")
	fi
	if [ ! -f "$_dnsmasq_leases" ] ; then
		send2log "  >>> specified path to _dnsmasq_leases ($_dnsmasq_leases) does not exist" 1
	else
		_dnsl=$(cat "$_dnsmasq_leases")
	fi
	if [ "$_firmware" -eq "0" ] ; then
		_nvr=$(nvram show 2>&1 | grep -i "static_leases=")
		result=$(echo "$_nvr" | grep -io "$dMac=.*=" | cut -d= -f2)
	elif [ "$_firmware" -eq "1" ] ; then
		# thanks to Robert Micsutka for providing this code
		local ucihostid=$(uci show dhcp | grep dhcp.@host....mac= | grep -i $dMac | cut -d. -f2)
		[ -n "$ucihostid" ] && result=$(uci get dhcp.$ucihostid.name)
	elif [ "$_firmware" -eq "2" ] ; then
		#thanks to Chris Dougherty for providing this code
		_nvr=$(nvram show 2>&1 | grep -i "dhcp_staticlist=")
		local nvrt=$_nvr
		local nvrfix=''
		while [ "$nvrt" ] ;do
		iter=${nvrt%%<*}
		nvrfix="$nvrfix$iter="
		[ "$nvrt" = "$iter" ] && \
				nvrt='' || \
				nvrt="${nvrt#*<}"
		done
		_nvr=${nvrfix//>/=}
		result=$(echo "$_nvr" | grep -io "$dMac=.*=.*=" | cut -d= -f3)
	else
		send2log "  >>> Invalid value for \`firmware\` parameter in config.file" 2
	fi
	[ -z "$result" ] && result=$(echo "$_dnsc" | grep -i "$dMac" | cut -d, -f2)
	[ -z "$result" ] && result=$(echo "$_dnsl" | grep -i "$dMac" | cut -d' ' -f4)
	[ -z "$result" ] && result="$dName"
	echo "$result"
}

getCurrentIP_MAC()
{
	send2log "=== getCurrentIP_MAC ===" 0
	#For each host in the ARP table... check that there is a matching entry in currentIP_MAC list
	_currentConnectedUsers=$(cat "$_connectedUsers" | tr -s ' ' | cut -d' ' -f1,4 )

	IFS=$'\n'
	for line in $_currentConnectedUsers
	do
		[ "$line" == "IP type" ] && continue
		local cle=$(echo "$currentIP_MAC" | grep -ic "$line")
		if [ "$cle" -gt "0" ] ; then
			send2log " >>> line exists in currentIP_MAC... skipping --> $line" -1
			continue
		fi
		local mac=$(echo "$line" | cut -d' ' -f2 | tr '[a-z]' '[A-Z]')
		local cIP=$(echo "$line" | cut -d' ' -f1)
		if [ "$mac" == "00:00:00:00:00:00" ] ; then
			send2log "  >>> Null MAC address for $cIP not added to currentIP_MAC" 0
			continue
		fi

		local cme=$(echo "$currentIP_MAC" | grep -ic "$mac")
		local cipe=$(echo "$currentIP_MAC" | grep -ic "$cIP ")
		if [ "$cipe" -gt "0" ] ; then
			send2log " >>> duplicate IP in currentIP_MAC --> $cipe instance(s) of '$cIP' in currentIP_MAC changed to 'duplicate'" 0
			currentIP_MAC=$(echo "$currentIP_MAC" | sed -e "s/$cIP/duplicate/g")
		fi
		if [ "$cme" -eq "0" ] ; then
			send2log " >>> added new MAC with new IP to currentIP_MAC --> $cIP $mac" 0
			currentIP_MAC="$currentIP_MAC
$cIP $mac"
		elif [ "$cme" -eq "1" ] ; then
			send2log " >>> updated IP for unique MAC in currentIP_MAC --> $cIP $mac" 0
			currentIP_MAC=$(echo "$currentIP_MAC" | sed -e "s/.* $mac/$cIP $mac/g")
		elif [ "$cme" -gt "1" ] && [ "$_allowMultipleIPsperMAC" -eq "1" ] ; then
			send2log " >>> added new MAC with multiple IPs to currentIP_MAC --> $cIP $mac" 0
			currentIP_MAC="$currentIP_MAC
$cIP $mac"
		else
			send2log " >>> unexpected result in getCurrentIP_MAC --> $line $cme $cipe" 0
		fi
	done
}
setupIPv4Rules()
{
	send2log "=== setupIPv4Rules ===" 0
	checkIPv4Chain "$YAMON_IP4"
	local acr=$(iptables -nL "$YAMON_IP4")
	local ds=$(date +"%Y-%m-%d %H:%M:%S")

	send2log " >>> before currentIP_MAC --> $currentIP_MAC" -1
	if [ "$_includeBridge" -eq "1" ] ; then
		checkIPv4 "$YAMON_IP4" "$_bridgeIP" "$acr"
		local acr=$(iptables -nL "$YAMON_IP4")
	fi
	u_changes=0

	getCurrentIP_MAC

	for line in $currentIP_MAC
	do
		local cIP=$(echo "$line" | cut -d' ' -f1)
		local cMAC=$(echo "$line" | cut -d' ' -f2)
		[ "$cIP" == 'IP' ] || [ "$cIP" == 'type' ] || [ "$cIP" == 'duplicate' ] && continue
		send2log " >>> line --> $line : cIP --> $cIP : cMAC -->  $cMAC" 0
		local ucm=$(echo "$cMAC" | tr '[a-z]' '[A-Z]')
		if [ "$_ignoreGateway" -eq "1" ] && [ "$cMAC" == "$_gatewayMAC" ] ; then
			send2log " >>> Ignoring IP address for change for : $cMAC" 1
			continue
		fi
		send2log "  >>> checkIPv4 for $cIP in $YAMON_IP4 rule" 0
		checkIPv4 "$YAMON_IP4" "$cIP" "$acr"
		local foundMAC=$(echo "$_currentUsers" | grep -i "$ucm")
		local countMAC=$(echo "$_currentUsers" | grep -ic "$ucm")
		local cMACIP=$(echo "$foundMAC" | grep -io '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
		local owsIP=$(echo "$_currentUsers" | grep -ic "\"$cIP\"")
		send2log "	>>> Found $countMAC matching entries for $ucm" 0

		#new MAC & IP
		if [ "$countMAC" -eq "0" ] ; then
			deviceName=$(getNewDeviceName "$ucm" "$_defaultDeviceName")
			if [ ! -z "$_do_separator" ] ; then
				case $deviceName in
					(*"$_do_separator"*)
						oname=${deviceName%%"$_do_separator"*}
						dname=${deviceName#*"$_do_separator"}
					;;
					(*)
						oname="$_defaultOwner"
						dname="$deviceName"
					;;
				esac
			else
				oname="$_defaultOwner"
				dname="$deviceName"
			fi

			local newuser="ud_a({\"mac\":\"$ucm\",\"ip\":\"$cIP\",\"owner\":\"$oname\",\"name\":\"$dname\",\"colour\":\"\",\"added\":\"$ds\",\"updated\":\"$ds\"})"
			send2log "	>>> Added new device: $ucm & $cIP & $deviceName" 1
			[ "$_sendAlerts" -gt "0" ] && sendAlert "New device detected!" "New device added to users.js MAC: $ucm; IP: $cIP; Device name: $deviceName"
			#new MAC (& duplicate IP?)
			if [ "$owsIP" -gt 0 ] ; then
				send2log "	>>> Eliminated $owsIP duplicate IP(s): $cIP " 1
				_currentUsers=$(echo "$_currentUsers" | sed -e "s~\"$cIP\"~\"x$cIP\"~Ig")
			fi
			send2log "	>>> newuser -- > $newuser" 1
			send2log "	>>> newuser-->$newuser   _usersFile-->$_usersFile" 1
			_currentUsers="$_currentUsers
$newuser"
			u_changes=$(($u_changes + 1))
		#existing MAC (& new IP?)
		elif [ "$cMACIP" == "$cIP" ] ; then
			continue
		elif [ "$_includeBridge" -eq "1" ] && [ "$ucm" == "$_bridgeMAC" ] ; then
			send2log "	>>> Skipping potential IP change for $_bridgeMAC - cMACIP: $cMACIP  cIP:$cIP" 1
		elif [ "$countMAC" -eq "1" ] ; then
			local owner=$(echo "$foundMAC" | cut -d, -f3)
			local name=$(echo "$foundMAC" | cut -d, -f4)
			local colour=$(echo "$foundMAC" | cut -d, -f5)
			local added=$(echo "$foundMAC" | cut -d, -f6)
			send2log "	>>> Updated IP address for: $ucm -> from: $cMACIP - to: $cIP - $owsIP" 1
			if [ "$owsIP" -gt 0 ] ; then
				send2log "	>>> Eliminated $owsIP duplicate IP(s): $cIP -->  sed -i \"s~\"$cIP\"~\"y$cIP\"~\" $_usersFile" 1
				_currentUsers=$(echo "$_currentUsers" | sed -e "s~\"$cIP\"~\"y$cIP\"~Ig")
			fi
			local newuser="ud_a({\"mac\":\"$ucm\",\"ip\":\"$cIP\",$owner,$name,$colour,$added,\"updated\":\"$ds\"})"
			send2log "	>>> sed -i \"s~.*\"mac\":\"$ucm\".*})~$newuser~I\"" -1
			_currentUsers=$(echo "$_currentUsers" | sed -e "s~.*\"mac\":\"$ucm\".*})~$newuser~Ig")
			send2log "	>>> newuser -- > $newuser" 1
			u_changes=$(($u_changes + 1))
		else
			send2log "	>>> Skipping IP change for $ucm - not sure which of $countMAC IP's to change ==> cMACIP: $cMACIP  cIP:$cIP" 0
		fi
	done
	unset IFS
	if [ "$u_changes" -gt "0" ] ; then
 		send2log "  >>> $u_changes change(s) in \`setupIPv4Rules\`... $_usersFile updated " 2
		echo "$_currentUsers" > $_usersFile
 		send2log "  >>> Updated 'users_updated' in $_hourlyUsageDB ($ds)" 1
		_hourlyData=$(echo "$_hourlyData" | sed -e "s~var users_updated=.*~var users_updated=\"$ds\"~Ig")
		echo "$_hourlyData" > $_hourlyUsageDB
		[ "$_symlink2data" -eq "0" ] && copyfiles "$_usersFile" "$_usersFileWWW"
	else
		send2log "	>>> No changes to users" 0
	fi
	send2log " >>> after currentIP_MAC --> $currentIP_MAC" -1
}

setupIPv6Rules()
{
	send2log "=== setupIPv6Rules ===" 0
	checkIPv6Chain "$YAMON_IP6"
}
setwebdirectories()
{

	send2log "=== setwebdirectories ===" 0
	if [ "$_symlink2data" -eq "1" ] ; then

		local lcss=${_wwwCSS%/}
		local limages=${_wwwImages%/}
		local ldata=${_wwwData%/}

		[ ! -h "$_wwwPath$lcss" ] && ln -s "$_baseDir$_setupWebDir$lcss" "$_wwwPath$lcss"
		[ ! -h "$_wwwPath$limages" ] && ln -s "$_baseDir$_setupWebDir$limages" "$_wwwPath$limages"

		[ ! -h "$_wwwPath$ldata" ] && ln -s "$_baseDir$_dataDir" "$_wwwPath$ldata"

		[ ! -h "$_wwwPath$_setupWebIndex" ] && ln -s "$_baseDir$_setupWebDir$_setupWebIndex" "$_wwwPath$_setupWebIndex"
		#[ ! -h "$_wwwPath$_setupWebDev" ] && ln -s "$_baseDir$_setupWebDir$_setupWebDev" "$_wwwPath$_setupWebDev"

	elif [ "$_symlink2data" -eq "0"  ] ; then
		copyfiles "$_baseDir$_setupWebDir*" "$_wwwPath"
	fi


}
setlogdatafiles()
{
	send2log "=== setlogdatafiles ===" 0
	local dts=$(date +"%Y-%m-%d %H:%M:%S")

	logfilename="${lfpath}monitor-$_cYear-$_cMonth-$_cDay.log"
	local ts=$(date +"%H:%M:%S")
	[ ! -f "$logfilename" ] && echo "$_ds	$ts
---------------------------------------
YAMon :: $_version
=======================================">>$logfilename
	local rMonth=${_cMonth#0}
	local rYear="$_cYear"
	local rday=$(printf %02d $_ispBillingDay)
	if [ "$_cDay" -lt "$_ispBillingDay" ] ; then
		rMonth=$(($rMonth-1))
		if [ "$rMonth" == "0" ] ; then
			rMonth=12
			rYear=$(($rYear-1))
		fi
	fi
	_pMonth="$rMonth"
	rMonth=$(printf %02d $rMonth)
	case $_organizeData in
		(*"0"*)
			local savePath="$_baseDir$_dataDir"
			local wwwsavePath="$_wwwPath$_wwwData"
		;;
		(*"1"*)
			local savePath="$_baseDir$_dataDir$rYear/"
			local wwwsavePath="$_wwwPath$_wwwData$rYear/"
		;;
		(*"2"*)
			local savePath="$_baseDir$_dataDir$rYear/$rMonth/"
			local wwwsavePath="$_wwwPath$_wwwData$rYear/$rMonth/"
		;;
	esac
	if [ ! -d "$savePath" ] ; then
		send2log "  >>> Adding data directory - $savePath " 0
		mkdir -p "$savePath"
	else
		send2log "  >>> data directory exists - $savePath " -1
	fi
	if [ ! -d "$wwwsavePath" ] && [ "$_symlink2data" -eq "0" ] ; then
		send2log "  >>> Adding web directory - $wwwsavePath " 0
		mkdir -p "$wwwsavePath"
	else
		send2log "  >>> web directory exists - $wwwsavePath " -1
	fi
	[ "$_symlink2data" -eq "0" ] &&  [ "$(ls -A $_baseDir$_dataDir)" ] && copyfiles "$_baseDir$_dataDir*" "$_wwwPath$_wwwData"

	_macUsageDB="$savePath$rYear-$rMonth-$rday-$_usageFileName"
	_macUsageWWW="$wwwsavePath$rYear-$rMonth-$rday-$_usageFileName"
	if [ ! -f "$_macUsageDB" ]; then
		send2log "  >>> Monthly usage file not found... creating new file: $_macUsageDB" 2
		touch $_macUsageDB
		echo "var monthly_created=\"$dts\"
var monthly_updated=\"$dts\"" > $_macUsageDB
		[ "$_symlink2data" -eq "0" ] && copyfiles "$_macUsageDB" "$_macUsageWWW"
	fi
	_hourlyUsageDB="$savePath$_cYear-$_cMonth-$_cDay-$_hourlyFileName"
	_hourlyUsageWWW="$wwwsavePath$_cYear-$_cMonth-$_cDay-$_hourlyFileName"
	if [ ! -f "$_hourlyUsageDB" ]; then
		send2log "  >>> Hourly usage file not found... creating new file: $_hourlyUsageDB" 2
		touch $_hourlyUsageDB
		local upsec=$(echo "$(cat /proc/uptime)" | cut -d' ' -f1);
		local meminfo=$(cat /proc/meminfo)
		local freeMem=$(getMI "$meminfo" "MemFree")
		local bufferMem=$(getMI "$meminfo" "Buffers")
		local cacheMem=$(getMI "$meminfo" "Cached")
		local totMem=$(getMI "$meminfo" "MemTotal")
		local availMem=$(($freeMem+$bufferMem+$cacheMem))
		local br0=$(grep -i "$_lan_iface" /proc/net/dev | tr ':' ' '| tr -s ' ')
		send2log "  *** PND: br0: [$br0]" 0

		local br_d=$(echo $br0 | cut -d' ' -f10)
		local br_u=$(echo $br0 | cut -d' ' -f2)
		[ "$br_d" == '0' ] && br_d=$(echo $br0 | cut -d' ' -f11)
		[ "$br_u" == 'br0' ] && br_u=$(echo $br0 | cut -d' ' -f3)
		send2log "  *** PND: br_d: $br_d  br_u: $br_u" -1

		_hourlyData="var hourly_created=\"$dts\"
var hourly_updated=\"$dts\"
var users_updated=\"$dts\"
var disk_utilization=\"0%\"
var serverUptime=\"$upsec\"
var freeMem=\"$freeMem\",availMem=\"$availMem\",totMem=\"$totMem\"
serverloads(\"$sl_min\",\"$sl_min_ts\",\"$sl_max\",\"$sl_max_ts\")
pnd({\"hour\":\"start\",\"uptime\":$upsec,\"down\":$br_d,\"up\":$br_u,\"hr-loads\":\"$hr_min1,$hr_min5,$hr_max5,$hr_max1\"})
"
		echo "$_hourlyData" > $_hourlyUsageDB
		[ "$_symlink2data" -eq "0" ] && copyfiles "$_hourlyUsageDB" "$_hourlyUsageWWW"
	fi
}
checkDates()
{
	_cDay=$(date +%d)
	send2log "=== Setting dates === started: $started  _cDay: $_cDay  _pDay: $_pDay" 0
	[ "$started" == "1" ] && [ "$_cDay" == "$_pDay" ] && return
	if [ "$started" == "1" ] && [ "$_cDay" != "$_pDay" ] ;  then
		sl_max=''
		sl_min=''
		hr_max5=''
		hr_min5=''
		hr_max1=''
		hr_min1=''
		sl_max_ts=''
		sl_min_ts=''
		ndAMS=0
		send2log "	>>> Active IP & MACs today:
$currentIP_MAC " 1
		currentIP_MAC=""
		_hourlyData=""
		send2log "	>>> Reset usage globals:
currentIP_MAC-->$currentIP_MAC
_hourlyData-->$_hourlyData
 " -1
		getCurrentIP_MAC
		send2log "	>>> date change: $_pDay --> $_cDay " 0
		updateHourly2Monthly &
		_cMonth=$(date +%m)
		_cYear=$(date +%Y)
		_ds="$_cYear-$_cMonth-$_cDay"
		[ "$_doDailyBU" -eq "1" ] && dailyBU
		setlogdatafiles
	fi
	_pDay="$_cDay"
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
getCV()
{
	local result=$(echo "$1" | grep -io "\"$2\":[\"0-9]\{1,\}" | grep -o "[0-9]\{1,\}");
	[ -z $result ] && result=0
	echo "$result"
}
getMI()
{
	local result=$(echo "$1" | grep -i "^$2:" | grep -o "[0-9]\{1,\}")
	[ -z $result ] && result=0
	echo "$result"
}
checkIptablesIPs()
{
	for line in $1
	do
		local tip=$(echo "$line" | cut -d' ' -f2)
		local fx=$(echo "$currentIP_MAC" | grep -ic "$tip ")
		if [ "$fx" -eq "0" ] ; then
			local foundMAC=$(getMACbyIP "$tip")
			send2log "	>>> $2 IP address not found in currentIP_MAC 	$tip	foundMAC: $foundMAC" 1
			if [ "$foundMAC" == "0" ] ; then
				send2log "	>>> No matching entry in users.js for ip: $tip" 2
			elif [ "$foundMAC" == "-1" ] ; then
				send2log "	>>> Multiple matching entries in users.js for ip: $tip" 2
			else
				local cme=$(echo "$currentIP_MAC" | grep -ic "$mac")
				local cipe=$(echo "$currentIP_MAC" | grep -ic "$tip ")
				if [ "$cipe" -gt "0" ] ; then
					send2log " >>> checkItableIPs--> duplicate IP in currentIP_MAC --> $cipe instance(s) of '$tip' in currentIP_MAC changed to 'duplicate'" 0
					currentIP_MAC=$(echo "$currentIP_MAC" | sed -e "s/$tip/duplicate/g")
				fi
				if [ "$cme" -eq "0" ] ; then
					send2log " >>> checkItableIPs--> added new MAC with new IP to currentIP_MAC --> $tip $mac" 0
					currentIP_MAC="$currentIP_MAC
$tip $mac"
				elif [ "$cme" -eq "1" ] ; then
					send2log " >>> checkItableIPs-->updated IP for unique MAC in currentIP_MAC --> $tip $mac" 0
					currentIP_MAC=$(echo "$currentIP_MAC" | sed -e "s/.* $mac/$tip $mac/g")
				elif [ "$cme" -gt "1" ] && [ "$_allowMultipleIPsperMAC" -eq "1" ] ; then
					send2log " >>> checkItableIPs--> added new MAC with multiple IPs to currentIP_MAC --> $tip $mac" 0
					currentIP_MAC="$currentIP_MAC
$tip $mac"
				else
					send2log " >>> checkItableIPs--> unexpected result in getCurrentIP_MAC --> $line $cme $cipe" 0
				fi
			fi
		fi
	done
}

updateUsage()
{
	send2log '=== Update usage === '"($_iteration)" 0
	send2log "	--- Reading data from $_hourlyUsageDB" 0
	local rHour=$(date +%H)
	local inUnlimited=0
	if [ "$_unlimited_usage" -eq "1" ] ; then
		send2log "	--- checking if in unlimited usage interval " 0
		local currTime=$(date +%s);
		local ul_start=$(date -d "$_unlimited_start" +%s);
		local ul_end=$(date -d "$_unlimited_end" +%s);
		[ "$currTime" -ge "$ul_start" ] && [ "$currTime" -lt "$ul_end" ] && inUnlimited=1
		[ "$old_inUnlimited" -eq "0" ] && [ "$inUnlimited" -eq "1" ] && send2log "	--- starting unlimited usage interval: $_unlimited_start" 0
		[ "$old_inUnlimited" -eq "1" ] && [ "$inUnlimited" -eq "0" ] && send2log "	--- ending unlimited usage interval: $_unlimited_end" 0
		old_inUnlimited=$inUnlimited
	fi

	local iptablesData=$(iptables -L "$YAMON_IP4" -vnxZ | tr -s ' ' )
	local downloads=$(echo "$iptablesData" | cut -d' ' -f3,10 | grep "^[1-9][0-9]* [1-9][0-9]*" | sed 's/$/ /g' )
	local uploads=$(echo "$iptablesData" | cut -d' ' -f3,9 | grep "^[1-9][0-9]* [1-9][0-9]*" | sed 's/$/ /g' )
	send2log "	--- Getting iptablesData
iptablesData
$iptablesData" -1
	send2log "
+++++++++++++++++++++++++++++
downloads
$downloads
+++++++++++++++++++++++++++++
uploads
$uploads
" 0
	if [ -z "$downloads" ] && [ -z "$uploads" ] ; then
		send2log "	>>> no downloads or uploads..." 0
		return
	fi

	getCurrentIP_MAC

	checkIptablesIPs "$downloads" 'downloads'
	checkIptablesIPs "$uploads" 'uploads'

	send2log "  >>> currentIP_MAC: $currentIP_MAC" -1
	unset IFS
	local d_changes=0
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	local liveusage=''
	local ls=''
	local newentry=''
	local findstr=''
	local down=0
	local up=0
	local do_tot=0
	local up_tot=0
	if [ "$inUnlimited" -eq "1" ] ; then
		local ul_do=0
		local ul_up=0
		local ul_do_tot=0
		local ul_up_tot=0
	fi
	IFS=$'\n'
	for line in $currentIP_MAC
	do
		local cIP=$(echo "$line" | cut -d' ' -f1)
		local mac=$(echo "$line" | cut -d' ' -f2)
		send2log " >>> line --> $line" -1
		local ucm=$(echo "$mac" | tr '[a-z]' '[A-Z]')

		[ "$cIP" == 'IP' ] || [ "$cIP" == 'duplicate' ] || [ "$type" == "0x0" ] || [ "$flags" == "0x0" ] && continue
		[ "$_lan_iface_only" -eq "1" ] && [ "$iface" != "$_lan_iface" ] && continue
		[ "$mac" == "00:00:00:00:00:00" ] || [ "$mac" == "" ] && continue
		[ "$_ignoreGateway" -eq "1" ] && [ "$mac" == "$_gatewayMAC" ] && continue
		local ndown=$(echo "$downloads" | grep -i "$cIP " | cut -d' ' -f1)
		local nup=$(echo "$uploads" | grep -i "$cIP " | cut -d' ' -f1)
		send2log "	cIP:	$cIP	mac:	$mac	ndown:	$ndown	nup:	$nup" 0
		[ -z $ndown ] && [ -z $nup ] && continue
		[ -z $ndown ] && ndown=0
		[ -z $nup ] && nup=0
		if [ "$_includeBridge" -eq "1" ] && [ "$ucm" == "$_bridgeMAC" ] ; then
			local ipcount=$(echo "$_currentUsers" | grep -ic "\"$cIP\"")
			if [ "$ipcount" -eq 0 ] ;  then
				send2log "	--- matched bridge mac but no matching entry for $cIP.  Data will be tallied under bridge mac" 0
			elif [ "$ipcount" -eq 1 ] ;  then
				local pmac="$mac"
				mac=$(echo "$_currentUsers" | grep -i "\"$cIP\"" | grep -io '\([a-z0-9]\{2\}\:\)\{5,\}[a-z0-9]\{2\}')
				ucm=$(echo "$mac" | tr '[a-z]' '[A-Z]')
				send2log "	--- matched bridge mac and found a unique entry for associated IP: $cIP" 0
				send2log "	--- changing from $pmac (bridge) to $ucm (device)" 0
			else
				send2log "	--- matched bridge mac but found $ipcount matching entries for $cIP.  Data will be tallied under bridge mac" 2
			fi
		fi
		local countMAC=$(echo "$_currentUsers" | grep -ic "$ucm")
		send2log "	cIP:	$cIP	mac:	$mac	countMAC:	$countMAC" 0
		if [ "$countMAC" -gt "1" ] ; then
			local kvl=$(echo "$_currentUsers" | grep -i "\"$ucm\"" | grep -i "\"$cIP\"")
			local kv=$(getCV "$kvl" "key")
			send2log "	--- kvl: $kvl kv: $kv" -1
			if [ "$kv" -eq "0" ] ;  then
				send2log "	--- matched $countMAC entries for $ucm but did not find a key value in users.js.  Data will be tallied under $ucm" 2
			else
				ucm="$ucm-$kv"
			fi
		fi
		local currentLine=$(echo "$_hourlyData" | grep -i "hu({\"mac\":\"$ucm\",\"hour\":\"$rHour\".*})")
		send2log "	--- currentLine:	$currentLine" 0
		if [ -z "$currentLine" ] ; then		#Add a new line
			d_changes=1
			ls='New'
			newentry="hu({\"mac\":\"$ucm\",\"hour\":\"$rHour\",\"down\":$ndown,\"up\":$nup})"
			[ "$inUnlimited" -eq "1" ] && newentry="hu({\"mac\":\"$ucm\",\"hour\":\"$rHour\",\"down\":$ndown,\"up\":$nup,\"ul_do\":$ndown,\"ul_up\":$nup})"
			_hourlyData="$_hourlyData
$newentry"
		else		#Update an existing line
			d_changes=1
			ls='Update'
			down=$(getCV "$currentLine" "down")
			up=$(getCV "$currentLine" "up")
			send2log "	--- values from currentLine:	$ucm	$down	$up" 0

			do_tot=$(digitAdd "$ndown" "$down")
			send2log "  >>> digitAdd do_tot	$ndown	$down	$do_tot" 0
			up_tot=$(digitAdd "$nup" "$up")
			send2log "  >>> digitAdd up_tot	$nup	$up	$up_tot" 0

			if [ "$inUnlimited" -eq "1" ] ; then
				ul_do=$(getCV "$currentLine" "ul_do")
				ul_up=$(getCV "$currentLine" "ul_up")
				send2log "	--- Unlimited values from currentLine:	$ucm	$ul_do	$ul_up" 0
				ul_do_tot=$(digitAdd "$ndown" "$ul_do")
				ul_up_tot=$(digitAdd "$nup" "$ul_up")
				newentry="hu({\"mac\":\"$ucm\",\"hour\":\"$rHour\",\"down\":$do_tot,\"up\":$up_tot,\"ul_do\":$ul_do_tot,\"ul_up\":$ul_up_tot})"
			else
				newentry="hu({\"mac\":\"$ucm\",\"hour\":\"$rHour\",\"down\":$do_tot,\"up\":$up_tot})"
			fi

			findstr="hu({\"mac\":\"$ucm\",\"hour\":\"$rHour\".*})"
			_hourlyData=$(echo "$_hourlyData" | sed -e "s/$findstr/$newentry/Ig")

		fi
		liveusage="$liveusage
curr_users({mac:'$ucm',ip:'$cIP',down:$ndown,up:$nup})"
		send2log "	>>> $ls newentry	$newentry" 1
		[ $(($_iteration%$_publishInterval)) -eq 0 ] && send2log "	>>> Publishing: $ls newentry	$newentry" 1
	done
	unset IFS

	if [ "$_doLiveUpdates" -eq "1" ] ; then
		send2log "	>>> liveusage: $liveusage" -1
		echo "$liveusage" >> $_liveFilePath
	fi

	if [ "$d_changes" -eq "1" ] ; then
		local changestr="var hourly_updated=.*"
		local newtime="var hourly_updated=\"$ds\""
		_hourlyData=$(echo "$_hourlyData" | sed -e "s/$changestr/$newtime/Ig")
		echo "$_hourlyData" > $_hourlyUsageDB
		send2log "  >>> Updated hourly_updated in $_hourlyUsageDB ($ds)" 0
	else
		send2log "	>>> No changes to hourly usage file" 0
	fi
}
publishData()
{
	send2log "=== Publishing Usage ===" 1
	if [ "$_symlink2data" -eq "0" ] ;  then
		local _usersMd5=`md5sum $_usersFile | awk '{print $1}'`
		if [ "$_usersMd5" != "$_savedusersMd5" ] ; then
			local ds=$(date +"%Y-%m-%d %H:%M:%S")
			local changestr="var users_updated=.*"
			local newtime="var users_updated=\"$ds\""
			_hourlyData=$(echo "$_hourlyData" | sed -e "s/$changestr/$newtime/Ig")
			send2log "  >>> _usersMd5 --> $_usersMd5   _savedusersMd5 --> $_savedusersMd5  " 1
			send2log "  >>> Users file ($_usersFile) was changed" 2
			copyfiles "$_usersFile" "$_usersFileWWW"
		else
			send2log "  >>> No changes to users file" 0
		fi
		_savedusersMd5="$_usersMd5"
	fi

	local disk_utilization=$(df $_baseDir | grep -o "[0-9]\{1,\}%")
	local oldval="var disk_utilization=\"[0-9]\{1,\}%\""
	local newval="var disk_utilization=\"$disk_utilization\""
	_hourlyData=$(echo "$_hourlyData" | sed -e "s/$oldval/$newval/g")
	send2log "  *** Disk Utilization on drive $_baseDir: $disk_utilization" 0
	local upsec=$(echo "$(cat /proc/uptime)" | cut -d' ' -f1);
	local br0=$(grep -i "$_lan_iface" /proc/net/dev | tr ':' ' '| tr -s ' ')
	send2log "  *** PND: br0: [$br0]" 0
	local br_d=$(echo $br0 | cut -d' ' -f10)
	local br_u=$(echo $br0 | cut -d' ' -f2)
	[ "$br_d" == '0' ] && br_d=$(echo $br0 | cut -d' ' -f11)
	[ "$br_u" == 'br0' ] && br_u=$(echo $br0 | cut -d' ' -f3)
	send2log "  *** PND: br_d: $br_d  br_u: $br_u" -1
	local findstr="pnd({\"hour\":\"start\".*})"
	local pndLine=$(echo "$_hourlyData" | grep -i "$findstr")
	if [ -z "$pndLine" ] ; then
		local newentry="pnd({\"hour\":\"start\",\"uptime\":$upsec,\"down\":$br_d,\"up\":$br_u,\"hr-loads\":\"$hr_min1,$hr_min5,$hr_max5,$hr_max1\"})"
		_hourlyData="$_hourlyData
$newentry"
		send2log "  *** PND: Inserted Start line: $newentry" 1
	fi
	local rHour=$(date +%H)
	findstr="pnd({\"hour\":\"$rHour\".*})"
	pndLine=$(echo "$_hourlyData" | grep -i "$findstr")
	newentry="pnd({\"hour\":\"$rHour\",\"uptime\":$upsec,\"down\":$br_d,\"up\":$br_u,\"hr-loads\":\"$hr_min1,$hr_min5,$hr_max5,$hr_max1\"})"
	local act=''
	if [ -z "$pndLine" ] ; then
		act='added '
		_hourlyData="$_hourlyData
$newentry"
	else
		act='updated '
		_hourlyData=$(echo "$_hourlyData" | sed -e "s/$findstr/$newentry/Ig")
	fi
	send2log "  *** PND: $act $newentry" 1
	local oldupsec="var serverUptime=\"[0-9\.]\{1,\}\""
	local newupsec="var serverUptime=\"$upsec\""
	_hourlyData=$(echo "$_hourlyData" | sed -e "s/$oldupsec/$newupsec/Ig")
	local meminfo=$(cat /proc/meminfo)
	local freeMem=$(getMI "$meminfo" "MemFree")
	local bufferMem=$(getMI "$meminfo" "Buffers")
	local cacheMem=$(getMI "$meminfo" "Cached")
	local totMem=$(getMI "$meminfo" "MemTotal")
	local availMem=$(($freeMem+$bufferMem+$cacheMem))
	local oldval="var freeMem=\"[0-9]\{1,\}\".*"
	local newval="var freeMem=\"$freeMem\",availMem=\"$availMem\",totMem=\"$totMem\""
	_hourlyData=$(echo "$_hourlyData" | sed -e "s/$oldval/$newval/Ig")
	send2log "  *** Memory usage: freeMem=\"$freeMem\",availMem=\"$availMem\",totMem=\"$totMem\"" 0

	local findsl="serverloads(.*)"
	local newsl="serverloads(\"$sl_min\",\"$sl_min_ts\",\"$sl_max\",\"$sl_max_ts\")"
	_hourlyData=$(echo "$_hourlyData" | sed -e "s/$findsl/$newsl/Ig")
	send2log "  *** Max/min Server Loads: min=$sl_min at $sl_min_ts  max=$sl_max at $sl_max_ts" 0
	send2log "  *** Hourly Server Loads: \"hr-loads\":\"$hr_min1,$hr_min5,$hr_max5,$hr_max1\"" 0
	echo "$_hourlyData" > $_hourlyUsageDB
	[ "$_symlink2data" -eq "0" ] && copyfiles "$_hourlyUsageDB" "$_hourlyUsageWWW"

}
doliveUpdates()
{
	send2log "=== doliveUpdates === " 0
	local cTime=$(date +"%T")
	local loadavg=$(echo "$(cat /proc/loadavg)")
	send2log "  >>> loadavg: $loadavg" 0
	local load1=$(echo "$loadavg" | cut -f1 -d" ")
	local load5=$(echo "$loadavg" | cut -f2 -d" ")
	local load15=$(echo "$loadavg" | cut -f3 -d" ")
	send2log "  >>> load1: $load1, load5: $load5, load15: $load15" 0
	echo "var last_update='$_cYear/$_cMonth/$_cDay $cTime'
serverload($load1,$load5,$load15)" > $_liveFilePath

	if [ "$sl_max" == "" ] || [ "$sl_max" \< "$load5" ]; then
		sl_max=$load5
		sl_max_ts="$cTime"
	fi
	if [ "$sl_min" == "" ] || [ "$load5" \< "$sl_min" ] ; then
		sl_min="$load5"
		sl_min_ts="$cTime"
	fi
	[ "$hr_max1" == "" ] || [ "$hr_max1" \< "$load1" ] && hr_max1=$load1
	[ "$hr_min1" == "" ] || [ "$load1" \< "$hr_min1" ] && hr_min1=$load1
	[ "$hr_max5" == "" ] || [ "$hr_max5" \< "$load5" ] && hr_max5=$load5
	[ "$hr_min5" == "" ] || [ "$load5" \< "$hr_min5" ] && hr_min5=$load5

	if [ "$_doCurrConnections" -eq "1" ] ; then
		send2log "	>>> curr_connections" 0
		awk "$_conntrack_awk" "$_conntrack" >> $_liveFilePath
	fi

}
updateHourly2Monthly()
{
	send2log "=== updateHourly2Monthly === " 0
	local _pMonth=${_cMonth#0}
	local _pYear=$_cYear
	#local _pDay=$1
	#local _pMonth=$2
	#local _pYear=$3
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
	send2log "  >>> reading from $_prevhourlyUsageDB & writing to $_macUsageDB" 0
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

	hsum=$(echo "$hsum" | sed -e "s~var monthly_updated=.*~var monthly_updated=\"$ds\"~")

	echo "$hsum" >> $_macUsageDB
	send2log "hsum: $hsum" -1
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	[ "$_symlink2data" -eq "0" ] && copyfiles "$_macUsageDB" "$_macUsageWWW"
	send2log "=== done updateHourly2Monthly === " 0
}

dailyBU()
{
	local bupath=$_dailyBUPath
	[ ! "${_dailyBUPath:0:1}" == "/" ] && bupath=$_baseDir$_dailyBUPath

	if [ ! -d "$bupath" ] ; then
		send2log "  >>> Creating Daily BackUp directory - $bupath" 1
		mkdir -p "$bupath"
	fi

	local bu_ds="$_cYear-$_cMonth-$_pDay"
	send2log "=== Daily Backups === " 1

	if [ "$_tarBUs" -eq "1" ]; then
		send2log "  >>> Compressed back-ups for $bu_ds to $bupath"'bu-'"$bu_ds.tar" 1
		if [ "$_enableLogging" -eq "1" ] ; then
			tar -czf $bupath"bu-$bu_ds.tar" "$_usersFile" "$_macUsageDB" "$_hourlyUsageDB" "$logfilename"
		else
			tar -czf $bupath"bu-$bu_ds.tar" "$_usersFile" "$_macUsageDB" "$_hourlyUsageDB"
		fi
		local return=$?
		if [ "$return" -ne "0" ] ; then
			send2log "  >>> Back-up compression for $bu_ds failed! Tar returned $return" 2
		else
			send2log "  >>> Back-ups for $bu_ds compressed - tar exited successfully." 0
		fi
	else
		local budir="$bupath"'bu-'"$bu_ds/"
		send2log "  >>> Copy back-ups for $bu_ds to $budir" 1
		[ ! -d "$bupath"'/bu-'"$bu_ds/" ] && mkdir -p "$budir"
   		copyfiles "$_usersFile" "$budir"
   		copyfiles "$_macUsageDB" "$budir"
   		copyfiles "$_hourlyUsageDB" "$budir"
		[ "$_enableLogging" -eq "1" ] && copyfiles "$logfilename" "$budir"
	fi
}
createUsersFile()
{
	local ds=$(date +"%Y-%m-%d %H:%M:%S")
	local users=''
	send2log "  >>> Creating empty users file: $_usersFile" 1
	touch $_usersFile
	users="var users_created=\"$ds\"
"
	IFS=$'\n'
	_dnsc=$(cat "$_dnsmasq_conf" | grep -i "dhcp-host=")
	for line in $_dnsc
	do
		local mac=$(echo "$line" | cut -d, -f1 | sed 's/dhcp-host=//' | tr '[a-z]' '[A-Z]' )
		local device=$(echo "$line" | cut -d, -f2)
		local cIP=$(echo "$line" | cut -d, -f3)
		local kv=$(echo "$users" | grep -ic "$mac")
		if [ "$kv" -eq "0" ] ; then
			kvs=''
		else
			kvs="\"key\":$kv,"
		fi
		if [ ! -z "$_do_separator" ] ; then
			case $device in
				(*"$_do_separator"*)
					oname=${device%%"$_do_separator"*}
					dname=${device#*"$_do_separator"}
				;;
				(*)
					oname="$_defaultOwner"
					dname="$device"
				;;
			esac
		else
			oname="$_defaultOwner"
			dname="$device"
		fi
		local newuser="ud_a({\"mac\":\"$mac\",\"ip\":\"$cIP\",\"owner\":\"$oname\",\"name\":\"$dname\",$kvs\"colour\":\"\",\"added\":\"$ds\",\"updated\":\"$ds\"})"
		users="$users
$newuser"
	done
	echo "$users" > $_usersFile
}
getLocalCopies()
{
	send2log "=== Getting a local copy of JS & CSS files === $_doLocalFiles" 2
	local path="$_baseDir$_setupWebDir"
	path=${path%/}
	local webpath="$_wwwPath$_wwwJS"
	webpath=${webpath%/}
	local web="http://usage-monitoring.com/current"

	local _yamonhtml="$path/yamon2.html"
	local _yamonjs="$webpath/yamon$_file_version.js"
	local _utiljs="$webpath/util$_file_version.js"
	local _md5js="$webpath/jquery.md5.min.js"


	local _yamoncss="$path/css/yamon$_file_version.css"
	local _resetcss="$path/css/normalize.css"

	if [ "$_doLocalFiles" -eq "1" ] ;  then
		send2log "  >>> local copy via curl " 1
		#get js files from usage-monitoring:
		curl --request GET "$web/js/yamon$_file_version.js" --header "Pragma: no-cache" --header "Cache-Control: no-cache" > $_yamonjs
		curl --request GET "$web/js/util$_file_version.js" --header "Pragma: no-cache" --header "Cache-Control: no-cache" > $_utiljs
		[ ! "$_settings_pswd" == "" ] && curl --request GET "$web/js/jquery.md5.min.js" --header "Pragma: no-cache" --header "Cache-Control: no-cache" > $_md5js

		#get css files from usage-monitoring:
		curl --request GET "$web/css/normalize.css" --header "Pragma: no-cache" --header "Cache-Control: no-cache" > $_resetcss
		curl --request GET "$web/css/yamon$_file_version.css" --header "Pragma: no-cache" --header "Cache-Control: no-cache" > $_yamoncss
	elif [ "$_doLocalFiles" -eq "2" ] ;  then
		send2log "  >>> local copy via wget " 1
		#get js files from usage-monitoring:
		wget "$web/js/yamon.js" -O $_yamonjs
		wget "$web/js/util.js" -O $_utiljs
		[ ! "$_settings_pswd" == "" ] && wget "$web/js/jquery.md5.min.js" -O $_md5js

		#get css files from usage-monitoring:
		wget "$web/css/normalize.css" -O $_resetcss
		wget "$web/css/yamon.css" -O $_yamoncss
	fi
	send2log "  >>> local copy done" 1
}

# ==========================================================
#				  Main program
# ========================================================

started=0
sl_max=""
sl_max_ts=""
sl_min=""
sl_min_ts=""
ndAMS=0
_cYear=$(date +%Y)
local numdateset=0
while [ "$_cYear" -le "2000" ]; do
	numdateset=$(($numdateset+1))
	sleep 2
	_cYear=$(date +%Y)
	if [ "$numdateset" -gt 60 ] ;  then
		showmsg 'cannotgettime.txt'
		exit 0
	fi
done
_cDay=$(date +%d)
_cMonth=$(date +%m)
_ds="$_cYear-$_cMonth-$_cDay"
p_hr=-1
logfilename="${_logDir}monitor-$_ds.log"
_lockDir="/tmp/YAMon-running"
[ "$numdateset" -gt "0" ] && send2log "  >>> It took $numdateset loops to get the date right!" 2
#set _configFile to the first parameter passed to the script (if any)
_configFile=$1

setDefaults

processors=$(grep -i processor /proc/cpuinfo -c)
readConfig

[ "$_doLocalFiles" -gt "0" ] && getLocalCopies
[ "$_doLocalFiles" -eq "0" ] && send2log "  >>> Using JS & CSS files at usage-monitoring.com" 2

checkDates
setwebdirectories
setlogdatafiles
started=1

[ ! -f "$_usersFile" ] && createUsersFile
_currentUsers=$(cat "$_usersFile")
if [ "$_includeBridge" -eq "1" ] ; then
	local foundBridge=$(echo "$_currentUsers" | grep -i "$_bridgeMAC")
	if [ -z "$foundBridge" ] ; then
		ds=$(date +"%Y-%m-%d %H:%M:%S")
		bridgeName=$(getNewDeviceName "$_bridgeMAC" "New Bridge")
		if [ ! -z "$_do_separator" ] ; then
			case $bridgeName in
				(*"$_do_separator"*)
					oname=${bridgeName%%"$_do_separator"*}
					dname=${bridgeName#*"$_do_separator"}
				;;
				(*)
					oname="$_defaultOwner"
					dname="$bridgeName"
				;;
			esac
		else
			oname="$_defaultOwner"
			dname="$bridgeName"
		fi
		local newuser="ud_a({\"mac\":\"$_bridgeMAC\",\"ip\":\"$_bridgeIP\",\"owner\":\"$oname\",\"name\":\"$dname\",\"colour\":\"\",\"added\":\"$ds\",\"updated\":\"$ds\"})"

		send2log "	>>> Added new bridge: $_bridgeMAC & $_bridgeIP " 2
		#append new line to _usersFile
		sed -i "$ a$newuser" $_usersFile
		_currentUsers="$_currentUsers
$newuser"
	fi
fi
_iteration=0
currentIP_MAC=""
getCurrentIP_MAC
send2log "  >>> currentIP_MAC: $currentIP_MAC" 0
_hourlyData=$(cat "$_hourlyUsageDB")

# main loop... to break the loop either edit config.file or delete _lockDir (/tmp/ac_mon.lock)
while [ -d $_lockDir ]; do

	start=$(date +%s)
	hr=$(date +%H)
	if [ "$hr" -ne "$p_hr" ] ; then
		hr_max5=''
		hr_min5=''
		hr_max1=''
		hr_min1=''
	p_hr=$hr
	fi
	[ $(($_iteration%$_publishInterval)) -eq 0 ] && setupIPv4Rules
	[ "$_includeIPv6" -eq "1" ] && [ $(($_iteration%$_publishInterval)) -eq 0 ] && setupIPv6Rules
	_iteration=$(($_iteration%$_publishInterval + 1))
	#Check for updates
	[ "$_doLiveUpdates" -eq "1" ] && doliveUpdates
	updateUsage

	end=$(date +%s)
	runtime=$(($end-$start))
	pause=$(($_updatefreq-$runtime>1?$_updatefreq-$runtime:1))
	send2log "  >>> Execution time: $runtime seconds - pause: $pause seconds" 0
	sleep "$pause"

	#Check to see whether config.file has changed
	[ $(($_iteration%$_publishInterval)) -eq 0 ] && readConfig

	#Check to see whether the date has changed
	checkDates

	#Check for a publish
	if [ $(($_iteration%$_publishInterval)) -eq 0 ] ; then

		publishData
		[ ! -z "$_log_str" ] && echo "$_log_str" >> $logfilename
		_log_str=''

	fi
	if [ ! -d $_lockDir ]; then
		#one last backup before shutting down
		ds=$(date +"%Y-%m-%d_%H-%M-%S")
		if [ "$_symlink2data" -eq "0" ] && [ "$_dowwwBU" -eq 1 ] ; then
			if [ "${_wwwBU:0:1}" == "/" ] ; then
				w3BUpath=$_wwwBU
			else
				w3BUpath=$_baseDir$_wwwBU
			fi
			if [ ! -d "$w3BUpath" ] ; then
				send2log "  >>> Creating Web BackUp directory - $w3BUpath" 1
				mkdir -p "$w3BUpath"
			fi
			mkdir "$w3BUpath$ds"
			copyfiles "$_wwwPath" "$w3BUpath$ds"
		fi
		send2log "
=====================================
  \`yamon.sh\` has stopped.
-------------------------------------" 2
		showmsg 'stopped.txt'
		[ -d $_lockDir ] && rmdir $_lockDir
	fi
done &