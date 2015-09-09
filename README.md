# openwrt-yamon
<h1>YAMon2 configuration for openwrt</h1>

YAMon2 version: <b>v2.1.0d (Script v2.0.15)</b>

OpenWrt version: <b>CHAOS CALMER (15.05-rc3, r46163)</b>

<h2>Download YAMon2</h2>
* http://usage-monitoring.com/

<h2>Installation</h2>
Review these changes then follow the readme.txt (in the download zip) for installation. Make these changes before starting.

<h2>Configuration / Setup file changes</h2>
<code>BASEDIR="/mnt/sda1/yamon"</code>

<h3>1ds.sh</h3>
* set <code>_baseDir</code> to BASEDIR

<h3>h2m.sh</h3>
* set <code>_baseDir</code> to BASEDIR

<h3>yamon2.sh</h3>
* replace <code>local conntrack="/proc/net/ip_conntrack"</code> with <code>local conntrack="/proc/net/nf_conntrack"</code>

<h3>yamon.startup</h3>
All curl operations were replaced with equivalent wget as curl is not installed, and is not an available pacakge.
* set <code>path</code> to BASEDIR

<h3>yamon.shutdown</h3>
* set <code>path</code> to BASEDIR

<h3>config.file</h3>
* <code>_firmware=1</code>
* <code>_baseDir=BASEDIR</code>
* <code>_logDir="/tmp/yamon/logs"</code> [optional]
* <code>_dnsmasq_conf="/tmp/dnsmasq.conf"</code>
* <code>_dnsmasq_leases="/mnt/sda1/etc/dhcp.leases"</code> configured in /etc/config/dhcp, preserves leases across reboots, normally it's in /tmp/.

<h2>nvram replacement</h2>
Openwrt does not have nvram, I don't know what it's replacement is but I found this script which supports the necessary operations.  See: https://forum.openwrt.org/viewtopic.php?pid=14020#p14020
* copy <code>nvram.openwrt</code> to <code>/usr/bin/nvram</code>

<h2>web access</h2>
The default configuration will copy the web reports to /tmp/www which is not by default accessible.  I choose to make a soft link (below). The yamon page is then available at <code>http://router_name/yamon/yamon2.html</code>
* <code> cd /www; ln -s /tmp/www yamon</code>

<h2>init rc / start at boot</h2>
<h3>yamon.rc</h3>
<ol>
<li> set <code>BASE_DIR</code> to BASEDIR</li>
<li> copy <code>yamon.rc</code> to <code>/etc/init.d/yamon</code> </li>
<li> execute <code>/etc/init.d/yamon enable</code> </li>
<li> execute <code>/etc/init.d/yamon start</code> </li>
</ol>

