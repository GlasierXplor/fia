#!/bin/bash

reset

#Start of 1b Remediation
if [ "$EUID" -ne 0 ] ; then
	printf "\e[31mPlease run as root!\n"
	printf "Press any key to exit\e[0m\n"
	read -n 1 -s
	exit
fi

if [ -e /etc/redhat-release ] ; then
	printf "\e[1mRunning Scan for "
	printf "$(cat /etc/redhat-release)"
	printf "\e[0m\n"
else
	printf "\e[31m\e[1mYou are not on a Red Hat System!\n"
	printf "Press any key to exit\e[0m\n"
	read -n 1 -s
	kill -9 $PPID
fi

function ctrl_C() {
	kill -9 $PPID	
}

function ctrl_Z() {
	kill -9 $PPID
}

trap ctrl_C INT
trap ctrl_Z 2 20

#Part 1

#create new hard disk first
printf "\e[1mCreating new hard disk\e[0m\n"
printf "\e[1m\nPLEASE CREATE A NEW HARD DISK WITH 20GB. This will create /dev/sdb.\e[0m\n"
parted -s /dev/sdb mklabel msdos #makes an MSDOS partition table 
parted -s /dev/sdb mkpart primary ext2 0% 100% #make primary partition, from size 0% to 100%
parted -s /dev/sdb set 1 lvm on #make partition 1 of /dev/sdb an lvm partition
pvcreate /dev/sdb1
vgextend rhel /dev/sdb1



#1.1-1.4 /tmp
printf "\e[1mCreating separate /tmp partition and setting options.\e[0m\n"
if lvcreate -l 10%VG -n tmp rhel ; then
	echo "/dev/rhel/tmp	/tmp	ext4	nodev,nosuid,noexec	0 0" >> /etc/fstab
	printf "\e[32mExecuted.\e[0m\n"
else
	printf "\e[31mUnable to create /tmp!\e[0m\n"
fi


#1.5 /var
printf "\e[1mCreating separate /var partition.\e[0m\n"
if lvcreate -l 10%VG -n var rhel ; then
	echo "/dev/rhel/var	/var	ext4	defaults	0 0" >> /etc/fstab
	printf "\e[32mExecuted.\e[0m\n"
else
	printf "\e[31mUnable to create /var!\e[0m\n"
fi


#1.6 bind mount
printf "\e[1mBinding mount.\e[0m\n"
printf "/tmp /var/tmp none bind 0 0" >> /etc/fstab
mount --bind /tmp /var/tmp
printf "\e[32mExecuted.\e[0m\n"


#1.7 /var/log
printf "\e[1mCreating separate partition for /var/log\e[0m\n"
if lvcreate -l 10%VG -n log rhel ; then
	ln -s /log /var/log
	echo "/dev/rhel/log	/var/log	ext4	defaults	0 0" >> /etc/fstab
	printf "\e[32mExecuted.\e[0m\n"
else
	printf "\e[31mUnable to create /var/log! Manual configuration required.\e[0m\n"
fi


#1.8 /var/log/audit
printf "\e[1mCreating separate partition for /var/log/audit\e[0m\n"
if lvcreate -l 10%VG -n audit rhel ; then
	ln -s /audit /var/log/audit
	echo "/dev/rhel/audit	/var/log/audit	ext4	defaults	0 0" >> /etc/fstab
	printf "\e[32mExecuted.\e[0m\n"
else
	printf "\e[31mUnable to create /var/log/audit! Manual configuration required.\e[0m\n"
fi


#1.9-1.10 /home
printf "\e[1mCreating separate partition for /home and setting options.\e[0m\n"
if lvcreate -l 10%VG -n home rhel ; then
	echo "/dev/rhel/home	/home	ext4	nodev	0 0" >> /etc/fstab
	printf "\e[32mExecuted.\e[0m\n"
else
	printf "\e[31mUnable to create /home!\e[0m\n"
fi


#1.11-1.13 removable media partitions
printf "\e[1mSetting options for Removable Media Partitions\e[0m\n"
if grep -e cdrom -e floppy /etc/fstab > /dev/null; then
	printf "\e[34mChanging settings of Removable Media Partitions.\e[0m\n"
	sed -i '/cdrom/ s/defaults/nodev,nosuid,noexec/g' /etc/fstab
	sed -i '/floppy/ s/defaults/nodev,nosuid,noexec/g' /etc/fstab
	printf "\e[32mExecuted.\e[0m\n"
else
	printf "\e[32mNo cdrom or floppy found!\e[0m\n"
fi


#1.14 sticky bit
printf "\e[1mSetting Sticky Bit on All World-Writable Directories\e[0m\n"
if df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type d \(-perm -0002 -a ! -perm -1000 \) 2> /dev/null ; then
df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type d \(-perm -0002 -a ! -perm -1000 \) 2> /dev/null | xargs chmod o+t
printf "\e[32mExecuted.\e[0m\n"
else
printf "\e[31mUnable to set sticky bit.\e[0m\n"
fi

#1.15 legacy filesystems
printf "\e[1mDisabling mounting of Legacy Filesystems.\e[0m\n"
printf "install cramfs /bin/true\n" > /etc/modprobe.d/CIS.conf
printf "install freevxfs /bin/true\n" >> /etc/modprobe.d/CIS.conf
printf "install jffs2 /bin/true\n" >> /etc/modprobe.d/CIS.conf
printf "install hfs /bin/true\n" >> /etc/modprobe.d/CIS.conf
printf "install hfsplus /bin/true\n" >> /etc/modprobe.d/CIS.conf
printf "install squashfs /bin/true\n" >> /etc/modprobe.d/CIS.conf
printf "install udf /bin/true\n" >> /etc/modprobe.d/CIS.conf
printf "\e[32mExecuted.\e[0m\n"


#Verify the package integrity
echo "Verify Package Integrity Using RPM"
echo "Might have unexpected discrepancies identified in the audit step"


#Part 2

#2.1
printf "\e[1mRemove telnet Server & Clients\e[0m\n"
if yum list telnet-server | grep "Available Packages" && yum list telnet | grep "Available Packages" >/dev/null ; then
printf "\e[32mtelnet-server and clients not installed\e[0m\n"
else
printf "\e[34mDisabling server and clients\e[0m\n"
result=`yum -y erase telnet-server`
result=`yum -y erase telnet`
printf "\e[32mExecuted.\e[0m\n" 
fi

#2.2
printf "\e[1mRemove rsh Server and Clients\e[0m\n"
if yum list rsh-server | grep "Available Packages" && yum list rsh | grep "Available Packages" >/dev/null ; then
printf "\e[32mRSH server and clients not installed\e[0m\n"
else
printf "\e[34mDisabling server and clients\e[0m\n"
result=`yum -y erase rsh-server`
result=`yum -y erase rsh`
printf "\e[32mExecuted.\e[0m\n" 
fi

#2.3
printf "\e[1mRemove NIS Server & Clients\e[0m\n"
if yum list ypserv | grep "Available Packages" && yum list ypbind | grep "Available Packages" >/dev/null ; then
printf "\e[32mNIS Server and Clients not installed\e[0m\n"
else
printf "\e[34mDisabling server and clients\e[0m\n"
result=`yum -y erase ypserv`
result=`yum -y erase ypbind`
printf "\e[32mExecuted.\e[0m\n" 
fi

#2.4
printf "\e[1mRemove tftp Server and Clients\e[0m\n"
if yum list tftp-server | grep "Available Packages" && yum list tftp | grep "Available Packages" >/dev/null ; then
printf "\e[32mtftp Server and Clients not installed\e[0m\n"
else
printf "\e[34mDisabling server\e[0m\n"
result=`yum -y erase tftp`
result=`yum -y erase tftp-server`
printf "\e[32mExecuted.\e[0m\n" 
fi

#2.5
printf "\e[1mRemove xinetd\e[0m\n"
if yum list xinetd | grep "Installed Packages" >/dev/null ; then
	printf "\e[31mXinetd installed. Attempting to remove.\e[0m\n"
	result=`yum -y erase xinetd`
	printf "\e[32mExecuted\e[0m\n"
else
printf "\e[32mXinetd is not installed.\e[0m\n"
fi

#2.6
printf "\e[1mDisable chargen-dgram\e[0m\n"
if yum list xinetd | grep "Available Packages" >/dev/null ; then
	printf "\e[32mAlready removed Chargen-Dgram from removing Xinetd.\e[0m\n"
elif yum list xinetd | grep "Installed Packages" && chkconfig --list chargen-dgram | grep "on" >/dev/null ; then
	printf "\e[31m Chargen-Dgram enabled. Attempting to disable.\e[0m\n"
	result=`chkconfig chargen-dgram off`
else 
	printf "\e[32mChargen-Dgram is already disabled.\e[0m\n"
fi

#2.7
printf "\e[1mDisable chargen-stream\e[0m\n"
if yum list xinetd | grep "Available Packages" >/dev/null ; then
	printf "\e[32mAlready removed Chargen-stream from removing Xinetd.\e[0m\n"
elif yum list xinetd | grep "Installed Packages" && chkconfig --list chargen-stream | grep "on" >/dev/null ; then
	printf "\e[31m Chargen-stream enabled. Attempting to disable.\e[0m\n"
	result=`chkconfig chargen-stream off`
else 
	printf "\e[32mChargen-stream is already disabled.\e[0m\n"
fi

#2.8
printf "\e[1mDisable daytime-dgram/daytime-stream\e[0m\n"
if yum list xinetd | grep "Available Packages" >/dev/null ; then
	printf "\e[32mAlready removed daytime-dgram and daytime-stream from removing Xinetd.\e[0m\n"
elif yum list xinetd | grep "Installed Packages" && chkconfig --list daytime-dgram | grep "on" && chkconfig --list daytime-stream | grep "on" >/dev/null ; then
	printf "\e[31m Daytime-dgram and Daytime-stream enabled. Attempting to disable.\e[0m\n"
	result=`chkconfig daytime-dgram off`
	result=`chkconfig daytime-stream off`
elif yum list xinetd | grep "Installed Packages" && chkconfig --list daytime-dgram | grep "off" && chkconfig --list daytime-stream | grep "off" >/dev/null ; then
	printf "\e[32mDaytime-dgram and daytime-stream are disabled.\e[0m\n"
else
	printf "\e[34m One is not disabled. Attempting to disable.\e[0m\n"
	result=`chkconfig daytime-dgram off`
	result=`chkconfig daytime-stream off`
	printf "\e[32mDisabled.\e[0m\n"
fi

#2.9
printf "\e[1mDisable echo-dgram/echo-stream\e[0m\n"
if yum list xinetd | grep "Available Packages" >/dev/null ; then
	printf "\e[32mAlready removed echo-dgram and echo-stream from removing Xinetd.\e[0m\n"
elif yum list xinetd | grep "Installed Packages" && chkconfig --list echo-dgram | grep "on" && chkconfig --list echo-stream | grep "on" >/dev/null ; then
	printf "\e[31m Echo-dgram and Echo-stream enabled. Attempting to disable.\e[0m\n"
	result=`chkconfig echo-dgram off`
	result=`chkconfig echo-stream off`
elif yum list xinetd | grep "Installed Packages" && chkconfig --list echo-dgram | grep "off" && chkconfig --list echo-stream | grep "off" >/dev/null ; then
	printf "\e[32mEcho-dgram and Echo-stream are disabled.\e[0m\n"
else
	printf "\e[34m One is not disabled. Attempting to disable.\e[0m\n"
	result=`chkconfig echo-dgram off`
	result=`chkconfig echo-stream off`
	printf "\e[32mDisabled.\e[0m\n"
fi

#2.10
printf "\e[1mDisable tcpmux-server\e[0m\n"
if yum list xinetd | grep "Available Packages" >/dev/null ; then
	printf "\e[32mAlready removed Tcpmux-server from removing Xinetd.\e[0m\n"
elif yum list xinetd | grep "Installed Packages" && chkconfig --list tcpmux-server | grep "on" >/dev/null ; then
	printf "\e[31m Tcpmux-server enabled. Attempting to disable.\e[0m\n"
	result=`chkconfig tcpmux-server off`
else 
	printf "\e[32mTcpmux-server is already disabled.\e[0m\n"
fi

#Part 3

#3.1 Daemon umask
printf "\n\e[1mAttempting to set default umask as 027.\e[0m\n"
if grep ^umask /etc/sysconfig/init | grep "027" >/dev/null ; then
	printf "\e[32mDefault umask is 027.\e[0m\n"
else
	printf "\e[34mChanging default umask to 027.\e[0m\n"
	echo "umask 027" >> /etc/sysconfig/init
	printf "\e[32mDefault umask is 027.\e[0m\n"
fi

#3.2 Remove X Window System	
printf "\n\e[1mAttempting to remove X Window System.\e[0m\n"
yum -y remove xorg-x11-server-common
printf "\n\e[1mChanging boot target.\e[0m\n"
cd /etc/systemd/system/
unlink default.target
ln -s /usr/lib/systemd/system/multi-user.target default.target
if [ ls -l /etc/systemd/system/default.target | grep graphical.target ] ; then
	printf "\e[31mX Windows System is the default user.\e[0m\n"
else
	printf "\e[32mX Windows System is not the default user.\e[0m\n"
fi


#3.3 Disable Avahi Server
printf "\n\e[1mAttempting to disable Avahi Server.\e[0m\n"
if systemctl is-active avahi-daemon | grep "active" >/dev/null && systemctl is-enabled avahi-daemon | grep "enabled" >/dev/null ; then
	printf "\e[34mAvahi Server is not disabled. Attempting to disable now.\e[0m\n"
	systemctl disable avahi-daemon.service avahi-daemon.socket
	systemctl stop avahi-daemon.service avahi-daemon.socket
	printf "\e[32mAvahi Server is now disabled.\e[0m\n"
elif systemctl is-active avahi-daemon | grep "inactive" >/dev/null && systemctl is-enabled avahi-daemon | grep "disabled" >/dev/null ; then
	printf "\e[32mAvahi Server is already disabled.\e[0m\n"
fi

#3.4 Disable CUPS Print Server
printf "\n\e[1mAttempting to disable CUPS Print Server.\e[0m\n"

if systemctl is-active cups | grep "active" >/dev/null && systemctl is-enabled cups | grep "enabled" >/dev/null ; then
	printf "\e[34mCUPS is not disabled. Attempting to disable now.\e[0m\n"
	systemctl stop cups
	systemctl disable cups
	printf "\e[32mCUPS is now disabled.\e[0m\n"
elif systemctl is-active cups | grep "inactive" >/dev/null && systemctl is-enabled cups | grep "disabled" >/dev/null ; then
	printf "\e[32mCUPS Print Server is already disabled.\e[0m\n"
elif systemctl is-active cups | grep "active" >/dev/null && systemctl is-enabled cups | grep "disabled" >/dev/null ; then
	printf "\e[32mCUPS is disabled.\e[0m\n"	
	systemctl stop cups
fi


#3.5 Remove DHCP Server
printf "\n\e[1mAttempting to disable DHCPD if exists.\e[0m\n"
if systemctl is-active dhcpd | grep "active" >/dev/null && systemctl is-enabled dhcpd | grep "enabled" >/dev/null ; then
	printf "\e[31mDHCPD is not disabled. Attempting to disable now.\e[0m\n"
	systemctl stop dhcpd
	systemctl disable dhcpd
	printf "\e[32mDHCPD is now disabled.\e[0m\n"
elif systemctl is-active dhcpd | grep "inactive" >/dev/null && systemctl is-enabled dhcpd | grep "disabled" >/dev/null ; then
	printf "\e[32mDHCPD is already disabled.\e[0m\n"
else
	printf "\e[32mDHCPD is not installed.\e[0m\n"
fi

printf "\n\e[34mAttempting to remove any existing dhcp files.\e[0m\n"
	yum -y erase dhcp

#3.6 Configure Network Time Protocol (NTP)
printf "\n\e[1mAttempting to configure Network Time Protocol(NTP)\e[0m\n"

if grep '^restrict default' /etc/ntp.conf | grep "restrict default kod nomodify notrap nopeer noquery" &&  grep '^restrict -6 default' /etc/ntp.conf | grep "restrict -6 default kod nomodify notrap nopeer noquery" >/dev/null ; then
	printf "\e[32mDefaults are already restricted.\e[0m\n"
else
	printf "\e[34mAttempting to restrict defaults\e[0m\n"
	echo "restrict default kod nomodify notrap nopeer noquery" >> /etc/ntp.conf
	echo "restrict -6 default kod nomodify notrap nopeer noquery" >> /etc/ntp.conf
	printf "\e[32mDefaults are restricted.\e[0m\n"
fi

if grep "^server" /etc/ntp.conf >/dev/null ; then
	printf "\e[32mThere is at least one NTP server specified.\e[0m\n"
else
	printf "\e[34mThere is no NTP server. Adding server 10.10.10.10.\n"
	echo "server 10.10.10.10" >> /etc/ntp.conf
	printf "\e[32mServer 10.10.10.10 added.\e[0m\n"
	
fi

if `grep "ntp:ntp" /etc/sysconfig/ntpd | grep 'OPTIONS="-u ntp:ntp -p /var/run/ntpd.pid"'`>/dev/null ; then
	printf "\e[32mOptions configured.\e[0m\n"
else
	printf "\e[34mOptions not configured. Attempting to configure...\e[0m\n"
	echo 'OPTIONS="-u ntp:ntp -p /var/run/ntpd.pid"'>> /etc/sysconfig/ntpd
fi


if grep "^restrict default" /etc/ntp.conf >/dev/null && grep "^restrict -6 default" /etc/ntp.conf >/dev/null && grep "^server" /etc/ntp.conf >/dev/null && grep "ntp:ntp" /etc/sysconfig/ntpd >/dev/null ; then
	printf "\e[32mNTP fully configured.\e[0m\n"
else
	printf "\e[31mNTP is not fully configured.\e[0m\n"
fi

#3.7 Remove LDAP
printf "\n\e[1mAttempting to remove Lightweight Directory Access Protocol(LDAP)if existing.\e[0m\n"
yum -y erase openldap-clients
yum -y erase openldap-servers
printf "\e[32mLDAP not installed.\e[0m\n"


#3.8 Disable NFS and RPC
printf "\n\e[1mAttempting to disable NFS and RPC\e[0m\n"

if systemctl is-enabled nfs-lock | grep "enabled" >/dev/null && systemctl is-enabled nfs-secure | grep "enabled" >/dev/null && systemctl is-enabled rpcbind | grep "enabled" >/dev/null && systemctl is-enabled nfs-idmap | grep "enabled" >/dev/null && systemctl is-enabled nfs-secure-server | grep "enabled" ; then
	printf "\e[31mNFS and RPC are not disabled. Attempting to disable\e[0m\n"
	systemctl disable nfs-lock
	systemctl disable nfs-secure
	systemctl disable rpcbind
	systemctl disable nfs-idmap
	systemctl disable nfs-secure-server
	printf "\e[32mNFS and RPC now disabled.\e[0m\n"
elif systemctl is-enabled nfs-lock | grep "disabled" >/dev/null && systemctl is-enabled nfs-secure | grep "disabled" >/dev/null && systemctl is-enabled rpcbind | grep "disabled" >/dev/null && systemctl is-enabled nfs-idmap | grep "disabled" >/dev/null && systemctl is-enabled nfs-secure-server | grep "disabled" ; then
	printf "\e[32mNFS and RPC already disabled.\e[0m\n"
else
	systemctl disable nfs-lock
	systemctl disable nfs-secure
	systemctl disable rpcbind
	systemctl disable nfs-idmap
	systemctl disable nfs-secure-server
	printf "\e[32mNFS and RPC disabled.\e[0m\n"
fi

#3.9 Remove DNS, FTP, HTTP, HTTP-Proxy, SNMP
printf "\n\e[1mAttempting to disable DNS\e[0m\n"
if systemctl is-enabled named | grep "enabled" >/dev/null && systemctl is-active named | grep "active" >/dev/null; then
	printf "\e[31mDNS is not disabled. Attempting to disable.\e[0m\n"
	systemctl stop named
	systemctl disable named
	printf "\e[32mDNS is now disabled.\e[0m\n"
elif systemctl is-active named | grep "inactive" >/dev/null && systemctl is-enabled named | grep "disabled" >/dev/null ; then
	printf "\e[32mDNS is already disabled.\e[0m\n"
else
	printf "\e[32mDNS is not installed.\e[0m\n"
fi


printf "\n\e[1mAttempting to remove FTP\e[0m\n"
yum -y erase ftp
printf "\e[32mFTP not installed.\e[0m\n"


printf "\n\e[1mAttempting to remove HTTP\e[0m\n"
yum -y erase httpd
printf "\e[32mHTTPD not installed.\e[0m\n"


printf "\n\e[1mAttempting to remove HTTP Proxy Service\e[0m\n"
yum -y erase squid
printf "\e[32mHTTP Proxy Server not installed.\e[0m\n"


printf "\n\e[1mAttempting to remove SNMP\e[0m\n"
yum -y erase net-snmp
printf "\e[32mSNMP Service not installed.\e[0m\n"

#3.10
printf "\n\e[1mConfiguring Mail Transfer Agent for Local-Only Mode.\e[0m\n"
if netstat -an | grep LIST | grep ":25[[:space:]]" ; then
	printf "\e[32mMTA is listening on 127.0.0.1.\e[0m\n"
else
	printf "\e[31mMTA is not listening on 127.0.0.1.\e[0m\n"
fi

if grep "inet_interfaces = localhost" /etc/postfix/main.cf ; then
  	sed -i '/receiving mail/ s/inet_interfaces = localhost/inet_interfaces = localhost/g' /etc/postfix/main.cf
	printf "\e[32mLine already exists. Replacing line.\e[0m\n"
else
  	sed '/#inet_interfaces = $myhostname, localhost/a inet_interfaces = localhost' /etc/postfix/main.cf
	printf "\e[32mLine added.\e[0m\n"
fi
	
systemctl restart postfix

#End of 1b Remediation
#Start of 2b Remediation
#4.1
#Set User/Group Owner on /boot/grub2/grub.cfg
#set the owner & group to the root user

printf "Checking if grub.cfg belongs to root: "

if stat -L -c "owner=%U group=%G" /boot/grub2/grub.cfg | grep "owner=root group=root" >/dev/null ; then
	printf "\e[32mNo remediation needed\e[0m\n"
else
	chown root:root /boot/grub2/grub.cfg
fi


#4.2
#Set Permissions on /boot/grub2/grub.cfg
#set permission to read+write for root only

printf "Checking if grub.cfg file is set to read and write for root only: "

if stat -L -c "%a" /boot/grub2/grub.cfg | grep "00" >/dev/null ; then
	printf "\e[32mNo remediation needed\e[0m\n"
else
	chmod og-rwx /boot/grub2/grub.cfg
fi

#4.3
#Set Boot Loader Password
#set boot loader pw for anyone rebooting the system

printf "Checking if boot loader password is set: \n"

grep "set superusers" /boot/grub2/grub.cfg
grep "password" /boot/grub2/grub.cfg

if grep "password" /boot/grub2/grub.cfg >/dev/null ; then
	 printf "\e[32mNo remediation needed\e[0m\n"
else
	touch test1.pwd
	echo "password\npassword\n" >> test1.pwd
	grub2-mkpasswd-pbkdf2 < test1.pwd > test.md5
	grub2-mkconfig -o /boot/grub2/grub.cfg
fi

#5.1
#Restrict Core Dumps
#prevent users from overriding the soft variables

printf "Checking if core dumps are restricted: \n"

if grep "hard" /etc/security/limits.conf > /dev/null ; then
	printf "\e[32mNo remediation needed\e[0m\n"
else
	echo "* hard core 0" >> /etc/security/limits.conf
	echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
fi

#5.2
#Enable Randomized Virtual Memory Region Placement
#set the system flag to force randomized virtual memory region placement

printf "Checking if virtual memory is randomized: "

if sysctl kernel.randomize_va_space >/dev/null ; then
	printf "\e[32mNo remediation needed\e[0m\n"
else	
	echo "kernel.randomize_va_space = 2" >> /etc/sysctl.conf
fi

#6.1.1
#Install the rsyslogpackage

printf "Checking if rsyslog package is installed: "

if rpm -q rsyslog | grep "rsyslog" >/dev/null ; then
	printf "\e[32mNo remediation needed\e[0m\n"
else
	yum install rsyslog
	systemctl enable rsyslog
	systemctl start rsyslog
fi

#6.1.2
#Activate the rsyslogService
#ensure rsyslog service is turned on

printf "Checking if rsyslog is enabled: "

if systemctl is-enabled rsyslog | grep "enabled" >/dev/null ; then
	printf "\e[32mNo remediation needed\e[0m\n"
else
	systemctl enable rsyslog
fi

#6.1.3
#Configure /etc/rsyslog.conf
#ensure appropriate logging is set according to environment

printf "Checking if appropriate logging is set: "

if (cat /etc/rsyslog.conf | grep "auth,user.* /var/log/messages" >/dev/null) || (cat /etc/rsyslog.conf | grep "kern.* /var/log/kern.log" >/dev/null) || (cat /etc/rsyslog.conf | grep "daemon.* /var/log/daemon.log" >/dev/null) || (cat /etc/rsyslog.conf | grep "syslog.* /var/log/daemon.log" >/dev/null) || (cat /etc/rsyslog.conf | grep "lpr,news,uucp,local0,local1,local2,local3,local4,local5,local6.* /var/log/unused.log") ; then
	printf "\e[32mNo remediation needed\e[0m\n"
else
	sed -i 's/dev/var/g' /etc/rsyslog.conf
	sed -i 's/console/log\/kern.log/g' /etc/rsyslog.conf
fi

#6.1.4
#Create and Set Permissions on rsyslogLog Files
#ensure that log files exist & correct permissions are set

touch /var/log/messages
chown root:root /var/log/messages
chmod og-rwx /var/log/messages

touch /var/log/secure	
chown root:root /var/log/secure
chmod og-rwx /var/log/secure

touch /var/log/maillog
chown root:root /var/log/maillog
chmod og-rwx /var/log/maillog

touch /var/log/cron
chown root:root /var/log/cron
chmod og-rwx /var/log/cron

touch /var/log/spooler
chown root:root /var/log/spooler
chmod og-rwx /var/log/spooler

touch /var/log/boot.log
chown root:root /var/log/boot.log
chmod og-rwx /var/log/boot.log

#6.1.5
#Configure rsyslogto Send Logs to a Remote Log Host

printf "Checking if rsyslog sends logs to remote log host: "

if grep "^*.*[^|][^|]*@" /etc/rsyslog.conf *.* >/dev/null ; then
	printf "\e[32mNo remediation needed\e[0m\n"
else
	echo "*.* @@localhost" >> /etc/rsyslog.conf
	pkill -HUP rsyslogd
	printf "\e[32mRsyslog sends logs to remote log host\e[0m\n"
fi

#6.1.6
#Accept Remote rsyslogMessages Only onDesignated Log Hosts

printf "Checking if rsyslog is listening for remote messages: "
printf "ModLoad imtcp.so: "

if grep '$ModLoad imtcp.so' /etc/rsyslog.conf >/dev/null ; then
	printf "\e[32mNo remediation needed\e[0m\n"
else

	sed -i 's/#$ModLoad imtcp/$ModLoad imtcp.so/g' /etc/rsyslog.conf
	sed -i 's/#$InputTCPServerRun 514/$InputTCPServerRun 514/g' /etc/rsyslog.conf
	pkill -HUP rsyslogd
fi

#6.2.1.1 Configure Audit Log Storage Size
sed -i '/max_log_file/s/= .*/= 5/' /etc/audit/auditd.conf

#6.2.1.2 Keep All Auditing Information (add 'max_log...' into this file)
sed -i '/max_log_file_action/s/= .*/= keep_logs/' /etc/audit/auditd.conf

#6.2.1.3 Disable System on Audit Log Full (add following lines into this file)
sed -i '/space_left_action/s/= .*/= email/' /etc/audit/auditd.conf
sed -i '/action_mail_acct/s/= .*/= root/' /etc/audit/auditd.conf
sed -i '/admin_space_left_action/s/= .*/= halt/' /etc/audit/auditd.conf

#6.2.1.4 Enable auditdService (allows admin to determine if unauthorized access to their system is occurring.)
systemctl enable auditd

#6.2.1.5 Enable Auditing for Processes That Start Prior to auditd
#(Audit events need to be captured on processes that start up prior to auditd, so that potential malicious activity cannot go undetected.)

checkgrub=$(grep "linux" /boot/grub2/grub.cfg | grep "audit=1")
if [ -z "$checkgrub"  ]
then
        var="GRUB_CMDLINE_LINUX"
        sed -i /$var/d /etc/default/grub
        printf "\nGRUB_CMDLINE_LINUX=\"audit=1\"" >> /etc/default/grub
else
        echo "audit 1 is pr"
fi

grub2-mkconfig -o /boot/grub2/grub.cfg

#6.2.1.6 Record Events That Modify Date and Time Information
#(Unexpected changes in system date and/or time could be a sign of malicious activity on the system.)
checksystem=`uname -m | grep "64"`
checkmodifydatetimeadjtimex=`egrep 'adjtimex' /etc/audit/audit.rules`

if [ -z "$checksystem" ]
then
        echo "It is a 32-bit system."

        if [ -z "$checkmodifydatetimeadjtimex" ]
        then
                echo "Date & Time Modified Events - FAILED (Adjtimex is not configured)"
                echo "-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change" >> /etc/audit/rules.d/audit.rules
                        echo "-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change" >> /etc/audit/audit.rules
                echo "Adjtimex is now configured"

        else
echo "Date & Time Modified Events - PASSED (Adjtimex is configured)"
        fi

else
        echo "It is a 64-bit system."

        if [ -z "$checkmodifydatetimeadjtimex" ]
        then
                echo "Date & Time Modified Events - FAILED (Adjtimex is not configured)"
                        echo "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change" >> /etc/audit/rules.d/audit.rules
                        echo "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change" >> /etc/audit/audit.rules
                echo "-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change" >> /etc/audit/rules.d/audit.rules
                        echo "-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change" >> /etc/audit/audit.rules
                echo "Adjtimex is now configured"
 else
                echo "Date & Time Modified Events - PASSED (Adjtimex is configured)"
        fi

fi

checkmodifydatetimesettime=`egrep 'settimeofday' /etc/audit/audit.rules`

if [ -z "$checksystem" ]
then

        if [ -z "$checkmodifydatetimesettime" ]
        then
                echo "Date & Time Modified Events - FAILED (Settimeofday is not configured)"
                echo "-a always,exit -F arch=b32 -S clock_settime -k time-change" >> /etc/audit/rules.d/audit.rules
                        echo "-a always,exit -F arch=b32 -S clock_settime -k time-change" >> /etc/audit/audit.rules
                echo "Settimeofday is now configured"
else
                echo "Date & Time Modified Events - PASSED (Settimeofday is configured)"
        fi

else

        if [ -z "$checkmodifydatetimesettime" ]
        then
                echo "Date & Time Modified Events - FAILED (Settimeofday is not configured)"
                        echo "-a always,exit -F arch=b64 -S clock_settime -k time-change" >> /etc/audit/rules.d/audit.rules
                        echo "-a always,exit -F arch=b64 -S clock_settime -k time-change" >> /etc/audit/audit.rules
                echo "-a always,exit -F arch=b32 -S clock_settime -k time-change" >> /etc/audit/rules.d/audit.rules
                        echo "-a always,exit -F arch=b32 -S clock_settime -k time-change" >> /etc/audit/audit.rules
                echo "Settimeofday is now configured"
else
                echo "Date & Time Modified Events - PASSED (Settimeofday is configured)"
        fi

fi

checkmodifydatetimeclock=`egrep 'clock_settime' /etc/audit/audit.rules`

if [ -z "$checkmodifydatetimeclock" ]
then
        echo "Date & Time Modified Events - FAILED (Clock Settime is not configured)"
        echo "-w /etc/localtime -p wa -k time-change" >> /etc/audit/rules.d/audit.rules
                echo "-w /etc/localtime -p wa -k time-change" >> /etc/audit/audit.rules
        echo "Clock Settime is now configured"

else
        echo "Date & Time Modified Events - PASSED (Clock Settime is configured)"
fi

pkill -P 1 -HUP auditd


#6.2.1.7 Record Events That Modify User/Group Information
#(Unexpected changes to these files could be an indication that the system has been compromised and that an unauthorized user is attempting to hide their activities or compromise additional accounts.)
printf "Checking if events that modify user/group information are recorded:\n"
if (egrep '\/etc\/group|\/etc\/passwd|\/etc\/gshadow|\/etc\/shadow|\/etc\/security\/opasswd' /etc/audit/audit.rules | grep "w /etc/group -p wa -k identity" >/dev/null) && (egrep '\/etc\/group|\/etc\/passwd|\/etc\/gshadow|\/etc\/shadow|\/etc\/security\/opasswd' /etc/audit/audit.rules | grep "w /etc/passwd -p wa -k identity" >/dev/null) && (egrep '\/etc\/group|\/etc\/passwd|\/etc\/gshadow|\/etc\/shadow|\/etc\/security\/opasswd' /etc/audit/audit.rules | grep "w /etc/gshadow -p wa -k identity" >/dev/null) && (egrep '\/etc\/group|\/etc\/passwd|\/etc\/gshadow|\/etc\/shadow|\/etc\/security\/opasswd' /etc/audit/audit.rules | grep "w /etc/shadow -p wa -k identity" >/dev/null) && (egrep '\/etc\/group|\/etc\/passwd|\/etc\/gshadow|\/etc\/shadow|\/etc\/security\/opasswd' /etc/audit/audit.rules | grep "w /etc/security/opasswd -p wa -k identity" >/dev/null) ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    echo "-w /etc/group -p wa -k identity" >> /etc/audit/audit.rules
    echo "-w /etc/passwd -p wa -k identity" >> /etc/audit/audit.rules
    echo "-w /etc/gshadow -p wa -k identity" >> /etc/audit/audit.rules
    echo "-w /etc/shadow -p wa -k identity" >> /etc/audit/audit.rules
    echo "-w /etc/security/opasswd -p wa -k identity" >> /etc/audit/audit.rules
    pkill -P 1 -HUP auditd
    printf "\e[32mEvents that modify user/group information are recorded\e[0m\n"
fi

#6.2.1.8 Record Events That Modify the System's Network Environment
printf "Checking if events that modify the system's environment are recorded:\n"
if (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale" >/dev/null) && (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale" >/dev/null) && (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "w /etc/issue -p wa -k system-locale" >/dev/null) && (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "w /etc/issue.net -p wa -k system-locale" >/dev/null) && (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "w /etc/hosts -p wa -k system-locale" >/dev/null) && (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "w /etc/sysconfig/network -p wa -k system-locale" >/dev/null) ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    echo "-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale" >> /etc/audit/audit.rules
    echo "-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale" >> /etc/audit/audit.rules
    echo "-w /etc/issue -p wa -k system-locale" >> /etc/audit/audit.rules
    echo "-w /etc/issue.net -p wa -k system-locale" >> /etc/audit/audit.rules
    echo "-w /etc/hosts -p wa -k system-locale" >> /etc/audit/audit.rules
    echo "-w /etc/sysconfig/network -p wa -k system-locale" >> /etc/audit/audit.rules
    pkill -P 1 -HUP auditd
    printf "\e[32mEvents that modify the system's environment are recorded\e[0m\n"
fi

#6.2.1.9 Record Events That Modify the System's Mandatory Access Controls
#(indicate that an unauthorized user is attempting to modify access controls and change security contexts, leading to a compromise of the system.)
printf "Checking if events that modify the system's mandatory access controls are recorded:\n"
if grep \/etc\/selinux /etc/audit/audit.rules | grep "w /etc/selinux/ -p wa -k MAC-policy" >/dev/null; then
    printf "\e[32mNo remediation needed\e[0m\n"
else 
    echo "-w /etc/selinux/ -p wa -k MAC-policy" >> /etc/audit/audit.rules
    pkill -P 1 -HUP auditd
    printf "\e[32mEvents that modify the system's mandatory access controls are recorded\e[0m\n"
fi

#6.2.1.10 Collect Login and Logout Events
printf "Checking if login and logout events are recorded:\n"
if (grep logins /etc/audit/audit.rules | grep "w /var/log/faillog -p wa -k logins" >/dev/null) && (grep logins /etc/audit/audit.rules | grep "w /var/log/lastlog -p wa -k logins" >/dev/null) && (grep logins /etc/audit/audit.rules | grep "w /var/log/tallylog -p wa -k logins" >/dev/null); then
    printf "\e[32mNo remediation needed\e[0m\n"
else #(Monitoring login/logout events could provide a system administrator with information associated with brute force attacks against user logins)
    echo "-w /var/log/faillog -p wa -k logins" >> /etc/audit/audit.rules
    echo "-w /var/log/lastlog -p wa -k logins" >> /etc/audit/audit.rules
    echo "-w /var/log/tallylog -p wa -k logins" >>  /etc/audit/audit.rules
    pkill -P 1 -HUP auditd
    printf "\e[32mLogin and logout events are recorded\e[0m\n"
fi

#6.2.1.11 Collect session initiation information
printf "Checking if session initiation information is collected:\n"
if (egrep 'wtmp|btmp|utmp' /etc/audit/audit.rules | grep "w /var/run/utmp -p wa -k session" >/dev/null) && (egrep 'wtmp|btmp|utmp' /etc/audit/audit.rules | grep "w /var/log/wtmp -p wa -k session" >/dev/null) && (egrep 'wtmp|btmp|utmp' /etc/audit/audit.rules | grep "w /var/log/btmp -p wa -k session" >/dev/null) ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else #Add the following lines to /etc/audit/audit.rules file
    echo "-w /var/run/utmp -p wa -k session" >> /etc/audit/audit.rules
    echo "-w /var/log/wtmp -p wa -k session" >> /etc/audit/audit.rules
    echo "-w /var/log/btmp -p wa -k session" >> /etc/audit/audit.rules
    #Execute following command to restart auditd
    pkill -HUP -P 1 auditd
    printf "\e[32mSession initiation information collected\e[0m\n"
fi

#6.2.1.12 Collect discretionary access control permission modification events
printf "Checking if permission modifications are being recorded:\n"
if (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) && (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) && (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) && (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) && (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) && (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else #Add the following lines to /etc/audit/audit.rules file
    echo "-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/audit.rules
    echo "-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/audit.rules
    echo "-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/audit.rules
    echo "-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/audit.rules
    echo "-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/audit.rules
    echo "a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod" >> /etc/audit/audit.rules
    #Execute the following command to restart auditd
    pkill -HUP -P 1 auditd
    printf "\e[32mPermission modifications are being recorded\e[0m\n"
fi


#6.2.1.13 Collect unsuccessful unauthorized access attempts to files
printf "Checking if there are unsuccessful attempts to access files:\n"
if (grep access /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access" >/dev/null) && (grep access /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access" >/dev/null) && (grep access /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access" >/dev/null) && (grep access /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access" >/dev/null) ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else #Add the following lines to /etc/audit/audit.rules file
    echo "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access" >> /etc/audit/audit.rules
    echo "-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access" >> /etc/audit/audit.rules
    echo "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access" >> /etc/audit/audit.rules
    echo "-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access" >> /etc/audit/audit.rules
    #Execute following command to restart auditd
    pkill -HUP -P 1 auditd
    printf "\e[32mCollected unsuccessful unauthorised access attempts\e[0m\n"
fi

#6.2.1.14 Collect use of privileged commands
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f | awk '{print "-a always,exit -F path="$1" -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged" }' >> /etc/audit/audit.rules

#6.2.1.15 Collect successful file system mounts
printf "Checking if filesystem mounts are recorded:\n"
if (grep mounts /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts" >/dev/null) && (grep mounts /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts" >/dev/null) ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else #Add the following lines to /etc/audit/audit.rules file
    echo "-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts" >> /etc/audit/audit.rules
    echo "-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts" >> /etc/audit/audit.rules
    #Execute the following command to restart auditd
    pkill -HUP -P 1 auditd
    printf "\e[32mFile system mounts are recorded\e[0m\n"
fi


#6.2.1.16 Collect file deletion events by user
printf "Checking if file deletion events by user are recorded:\n"
if (grep delete /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete" >/dev/null) && (grep delete /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete" >/dev/null) ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else #Add the following lines to /etc/audit/audit.rules file
    echo "-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete" >> /etc/audit/audit.rules
    echo "-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete" >> /etc/audit/audit.rules
    #Execute the following command to restart auditd
    pkill -P 1 -HUP auditd
    printf "\e[32mFile deletion events by user are recorded\e[0m\n"
fi

#6.2.1.17 Collect changes to system administration scope
printf "Checking if changes to /etc/sudoers are recorded:\n"
if grep scope /etc/audit/audit.rules | grep "w /etc/sudoers -p wa -k scope" >/dev/null ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else #Add the following lines to /etc/audit/audit.rules file
    echo "-w /etc/sudoers -p wa -k scope" >> /etc/audit/audit.rules
    #Execute the following command to restart auditd
    pkill -HUP -P 1 auditd
    printf "\e[32mChanges to /etc/sudoers are recorded\e[0m\n"
fi

#6.2.1.18 Collect system administrator actions (syslog)
printf "Checking if administrator activity is recorded:\n"
if grep actions /etc/audit/audit.rules | grep "w /var/log/sudo.log -p wa -k actions" >/dev/null ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else #Add the following lines to /etc/audit/audit.rules file
    echo "-w /var/log/sudo.log -p wa -k actions" >> /etc/audit/audit.rules
    #Execute the following command to restart auditd
    pkill -HUP -P 1 auditd
    printf "\e[32mAdministratory activities are recorded\e[0m\n"
fi

#6.2.1.19 Collect kernel module loading and unloading
printf "Checking if kernel module loading and unloading are recorded:\n"
if (grep modules /etc/audit/audit.rules |grep "w /sbin/insmod -p x -k modules" >/dev/null) && (grep modules /etc/audit/audit.rules |grep "w /sbin/rmmod -p x -k modules" >/dev/null) && (grep modules /etc/audit/audit.rules |grep "w /sbin/modprobe -p x -k modules" >/dev/null) && (grep modules /etc/audit/audit.rules |grep "w /sbin/insmod -p x -k modules" >/dev/null) && (grep modules /etc/audit/audit.rules |grep "a always,exit -F arch=b64 -S init_module -S delete_module -k modules" >/dev/null) ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else #Add the following lines to /etc/audit/audit.rules file
    echo "-w /sbin/insmod -p x -k modules" >> /etc/audit/audit.rules
    echo "-w /sbin/rmmod -p x -k modules" >> /etc/audit/audit.rules
    echo "-w /sbin/modprobe -p x -k modules" >> /etc/audit/audit.rules
    echo "-a always,exit -F arch=b64 -S init_module -S delete_module -k modules" >> /etc/audit/audit.rules
    printf "\e[32mKernal module loading and unloading are recorded\e[0m\n"
fi

#6.2.1.20 Make the audit configuration immutable
printf "Checking if audit configuration is immutable:\n"
if grep "^-e 2" /etc/audit/audit.rules >/dev/null; then
    printf "\e[32mNo remediation needed\e[0m\n"
else #Add the following lines to /etc/audit/audit.rules file
    echo "-e 2" >> /etc/audit/audit.rules
    printf "\e[32mAudit configuration is immutable\e[0m\n"
fi

#6.2.1.21 Configure logrotate
printf "Checking if appropriate system logs are rotated:\n"
if (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/messages" >/dev/null) && (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/secure" >/dev/null) && (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/maillog" >/dev/null) && (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/spooler" >/dev/null) && (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/boot.log" >/dev/null) && (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/cron" >/dev/null) ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else #Edit the /etc/logrotate.d/syslog file to include appropriate system logs
    echo "/var/log/messages /var/log/secure /var/log/maillog /var/log/spooler /var/log/boot.log /var/log/cron {" >> /etc/logrotate.d/syslog
    printf "\e[32mAppropriate system logs are rotated\e[0m\n"
fi

#End of 2b Remediation
#Start of 3b Remediation
#!/bin/bash

#7.1
#Set the PASS_MAX_DAYS parameter to 90 in /etc/login.defs
sudo nano /etc/login.defs
PASS_MAX_DAYS 90

#Modify user parameters for all users with a password set to match
chage --maxdays 90 <user>

#7.2 
#Set the PASS_MIN_DAYS parameter to 7 in /etc/login.defs
sudo nano /etc/login.defs

#Modify user parameters for all users with a password set to match: 
chage --mindays 7 <user>

#7.3
#Set the PASS_WARN_AGE parameter to 7 in /etc/login.defs: 
sudo nano /etc/login.defs

#Modify user parameters for all users with a password set to match: 
chage --warndays 7 <user>

#7.4
#Execute the following commands for each misconfigured system account,
usermod -L <user name>
usermod -s /sbin/nologin <user name> 

#7.5
#Run the following command to set the root user default group to GID 0: 
usermod -g 0 root

#7.6
#Edit the /etc/bashrc and /etc/profile.d/cis.sh files (and the appropriate files for any other shell supported on your system) and add the following the UMASK parameter as shown:
umask 077

#7.7
#Run the following command to disable accounts that are inactive for 35 or more days
useradd -D -f 35

#7.8
#If any accounts in the /etc/shadow file do not have a password, run the following command to lock the account until it can be determined why it does not have a password
/usr/bin/passwd -l <username>
#Also, check to see if the account is logged in and investigate what it is being used for to determine if it needs to be forced off. 

#7.9
#Run the following command and verify that no output is returned:
grep '^+:' /etc/passwd
grep '^+:' /etc/shadow
grep ‘^+:’ /etc/group
#Delete these entries if they exist using userdel.

#This script will give the information of legacy account.
LG=$(grep '^+:' /etc/passwd) #if they're in passwd, they're a user
if [$? -eq 0]; then 
    #We've found a user
    echo "We've found the user '+'!"
    sudo userdel '+'
    echo "Deleted."
else
    echo "Couldn't find the user '+'."
fi

#7.10
#Run the following command and verify that only the word "root" is returned:
/bin/cat /etc/passwd | /bin/awk -F: '($3 == 0) { print $1 }‘
root
#Delete any other entries that are displayed using userdel
userdel -r <username>
#7.11
#Rectify or justify any questionable entries found in the path.
- none of the path entries should be empty
- none of the path entries should be the “.” (current directory)
- path entries should be directories
- path entries should only be writable by the owner (use the chmod command to rectify)
- path entries should preferably be owned by root (use the chown command to rectify)
#7.12
printf "It is recommended that a monitoring policy be established to report user file permissions."
#7.13
printf "It is recommended that a monitoring policy be established to report user dot file permissions."
#7.14
printf "It is recommended that a monitoring policy be established to report users’ use of .netrc and .netrc file permissions."
#7.15
#If any users have .rhosts files determine why they have them. These files should be deleted if they are not needed.
#To search for and remove .rhosts files by using the find(1) command
find /export/home -name .rhosts -print | xargs -i -t rm{}
#7.16
printf "Analyze the output of the Verification step on the right and perform the appropriate action to correct any discrepancies found."
#7.17
#If any users' home directories do not exist, create them and make sure the respective user owns the directory. 
#Users without assigned home directories should be removed or assigned a home directory as appropriate. 

useradd john
mkdir -p /home/john
chown john:john /home/john

#To remove users
userdel john

#7.18
#Based on the results of the script, establish unique UIDs and review all files owned by the shared UID to determine which UID they are supposed to belong to.

#7.19
#Based on the results of the script, establish unique GIDs and review all files owned by the shared GID to determine which group they are supposed to belong to.

#7.20
#Based on the results of the above, change any UIDs that are in the reserved range to one that is in the user range. 
#Review all files owned by the reserved UID to determine which UID they are supposed to belong to.

#7.21
#Based on the results of the script, establish unique user names for the users. 
#File ownerships will automatically reflect the change as long as the users have unique UIDs.

#7.22
#Based on the results of the script, establish unique names for the user groups. 
#File group ownerships will automatically reflect the change as long as the groups have unique GIDs.


#7.23
#Making global modifications to users' files without alerting the user community can result in unexpected outages and unhappy users. 
#Therefore, it is recommended that a monitoring policy be established to report user .forward files and determine the action to be taken in accordance with site policy.

#8.1
touch /etc/motd
echo "Authorized uses only. All activity may be \monitored and reported." > /etc/issue
echo "Authorized uses only. All activity may be \monitored and reported." > /etc/issue.net
chown root:root /etc/motd; chmod 644 /etc/motd
chown root:root /etc/issue; chmod 644 /etc/issue
chown root:root /etc/issue.net; chmod 644 /etc/issue.net

#8.2
#Edit the /etc/motd, /etc/issue and /etc/issue.net files and remove any lines containing \m, \r, \s or \v.
sed -i '/\m/ d' /etc/motd
sed -i '/\r/ d' /etc/motd
sed -i '/\s/ d' /etc/motd
sed -i '/\v/ d' /etc/motd
sed -i '/\m/ d' /etc/issue
sed -i '/\r/ d' /etc/issue
sed -i '/\s/ d' /etc/issue
sed -i '/\v/ d' /etc/issue
sed -i '/\m/ d' /etc/issue.net
sed -i '/\r/ d' /etc/issue.net
sed -i '/\s/ d' /etc/issue.net
#End of 3b Remediation
#Start of 4b Remediation

#9.1 Enable anacron Daemon
printf "Checking if anacron is enabled:\n"
if rpm -q cronie-anacron | grep "not installed" ; then # Install the package if it hasnt already been installed
    yum -y install cronie-anacron
    printf "\e[32mAnacron enabled\e[0m\n"
else
    printf "\e[32mNo remediation needed\e[0m\n"
fi

#9.2 Enable crond Daemon
printf "Checking if cron is enabled:\n"
if systemctl is-enabled crond | grep "enabled" ; then # Enable crond if it hasnt been enabled yet
    printf "\e[32mNo remediation needed\e[0m\n"
else
    systemctl enable crond
    printf "\e[32mCron Enabled\e[0m\n"
fi

#9.3  Set User/Group Owner and Permission on /etc/anacrontab
printf "Checking if the /etc/anacrontab file has the correct permissions:\n"
if ls -l /etc/anacrontab | grep -e -rw------- ; then # Modify the file permissions to allow only users to read and write
    printf "\e[32mNo remediation needed\e[0m\n"
else
    chown root:root /etc/anarontab
    chmod og-rwx /etc/anacrontab
    printf "\e[32mChanged to correct permission\e[0m\n"
fi

#9.4 Set User/Group Owner and Permission on /etc/crontab
printf "Checking if the /etc/crontab file has the correct permissions:\n"
if ls -ld /etc/crontab | grep -e -rw------- ; then # Modify the file permissions to allow only users to read and write
    printf "\e[32mNo remediation needed\e[0m\n"
else
    chown root:root /etc/crontab
    chmod og-rwx /etc/crontab
    printf "\e[32mChanged to correct permission\e[0m\n"
fi

#9.5 Set User/Group Owner and Permission on /etc/cron.[hourly,daily,weekly,monthly]
printf "Checking if /etc/cron.hourly has the correct permissions:\n"
if ls -ld /etc/cron.hourly | grep -e drwx------ ; then # Modify the file permissions to allow only users to read, write and execute
    printf "\e[32mNo remediation needed\e[0m\n"
else
    chown root:root /etc/cron.hourly
    chmod og-rwx /etc/cron.hourly
    printf "\e[32mChanged to correct permission\e[0m\n"
fi

printf "Checking if /etc/cron.daily has the correct permissions:\n"
if ls -ld /etc/cron.daily | grep -e drwx------ ; then
     printf "\e[32mNo remediation needed\e[0m\n"
else
    chown root:root /etc/cron.daily
    chmod og-rwx /etc/cron.daily
    printf "\e[32mChanged to correct permission\e[0m\n"
fi

printf "Checking if /etc/cron.weekly has the correct permissions:\n"
if ls -ld /etc/cron.weekly | grep -e drwx------ ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    chown root:root /etc/cron.weekly
    chmod og-rwx /etc/cron.weekly
    printf "\e[32mChanged to correct permission\e[0m\n"
fi

printf "Checking if /etc/cron.monthly has the correct permissions:\n"
if ls -ld /etc/cron.monthly | grep -e drwx------ ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    chown root:root /etc/cron.monthly
    chmod og-rwx /etc/cron.monthly
    printf "\e[32mChanged to correct permission\e[0m\n"
fi


#9.6 Set User/Group Owner and Permission on /etc/cron.d
printf "Checking if the /etc/cron.d directory has the correct permissions:\n"
if ls -ld /etc/cron.d | grep -e drwx------ ; then # Modify the file permissions to allow only users to read, write and execute
    printf "\e[32mNo remediation needed\e[0m\n"
else
    chown root:root /etc/cron.d
    chmod og-rwx /etc/cron.d
    printf "\e[32mChanged to correct permission\e[0m\n"
fi

#9.7 Restrict at Daemon
printf "Checking if at jobs are restricted:\n"
if ! stat -L /etc/at.deny > /dev/null | grep "No such file or directory" ; then # Remove file if it hasnt been removed
    printf "\e[32mNo remediation needed\e[0m\n"
else
    rm /etc/at.deny
    printf "\e[32m /etc/at.deny has been removed\e[0m\n"
fi

printf "Checking if /etc/at.allow has been created with the correct permissions:\n"
if stat -L -c "%a %u %g" /etc/at.allow | egrep ".00 0 0" ; then # Create file with the correct permissions
    printf "\e[32mNo remediation needed\e[0m\n"
else
    touch /etc/at.allow
    chown root:root /etc/at.allow
    chmod og-rwx /etc/at.allow
    printf "\e[32mChanged to correct permission\e[0m\n"
fi

#9.8 Restrict at/cron to Authorized Users
printf "Checking if /etc/cron.deny has been removed:\n"
if [ -e "cron.deny" ]; then
   printf "\e[32m /etc/at.deny has been removed\e[0m\n"
    /bin/rm /etc/cron.deny
else
     printf "\e[32mNo remediation needed\e[0m\n"
fi

printf "Checking if /etc/at.deny has been removed:\n"
if [ -e "at.deny" ]; then
    printf "\e[32m /etc/at.deny has been removed\e[0m\n"
    /bin/rm /etc/at.deny
else
    printf "\e[32mNo remediation needed\e[0m\n"
fi

if [ -e "cron.allow" ]; then
     printf "\e[32mNo remediation needed\e[0m\n"
else
    touch /etc/cron.allow
     printf "\e[32m /etc/cron.allow has been created\e[0m\n"

fi

printf "Checking if /etc/cron.allow has changed restrictions:\n"
if ls -l /etc/cron.allow | grep -e "-rw-------" ; then
     printf "\e[32mNo remediation needed\e[0m\n"
else
    chown root:root /etc/cron.allow
    chmod og-rwx /etc/cron.allow
     printf "\e[32mChanged restrictions\e[0m\n"
fi

if [ -e "at.allow" ]; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    touch /etc/at.allow
    printf "\e[32m /etc/at.allow has been created\e[0m\n"

fi

printf "Checking if /etc/at.allow has changed restrictions:\n"
if ls -l /etc/at.allow | grep -e "-rw-------" ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    chown root:root /etc/at.allow
    chmod og-rwx /etc/at.allow
    printf "\e[32mChanged restrictions\e[0m\n"
fi


#10.1 Set SSH Protocol to 2
printf "Checking if SSH Protocol is set to 2:\n"
if grep "^Protocol[[:space:]]2" "/etc/ssh/sshd_config"; then 
    printf "\e[32mNo remediation needed\e[0m\n"
else    
    sed -i 's/^#Protocol[[:space:]]2/Protocol 2/' /etc/ssh/sshd_config
    printf "\e[32mSSH Protocol is set to 2\e[0m\n"      
fi

#10.2 Set LogLevelto INFO
printf "Checking if LogLevel is set to INFO:\n"
if grep "^LogLevel INFO" "/etc/ssh/sshd_config"; then
    printf "\e[32mNo remediation needed\e[0m\n"       
else
    sed -i 's/^#LogLevel INFO/LogLevel INFO/' /etc/ssh/sshd_config
    printf "\e[32mLogLevel is set to INFO\e[0m\n"      
fi

#10.3 Set Permissions on /etc/ssh/sshd_config (ROOT & CHMOD600)
printf "Checking if /etc/ssh/sshd_config file's owner and group is set to ROOT:\n"
if ls -l /etc/ssh/sshd_config | grep "root root"; then 
    printf "\e[32mNo remediation needed\e[0m\n"
else 
    chown root:root /etc/ssh/sshd_config 
    printf "\e[32m/etc/ssh/sshd_config file's owner and group is set to ROOT\e[0m\n"  
fi

printf "Checking if /etc/ssh/sshd_config file's permissions is correct:\n"
if ls -l /etc/ssh/sshd_config | grep -e -rw-------; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    chmod 600 /etc/ssh/sshd_config
    printf "\e[32m/etc/ssh/sshd_config file's permissions is correct\e[0m\n"
fi

#10.4 Disable X11Forwarding
printf "Checking if X11Forwarding is disabled:\n"
if grep "^X11Forwarding[[:space:]]no" "/etc/ssh/sshd_config"; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i 's/^X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
    printf "\e[32mX11Fowarding is disabled\e[0m\n"    
fi

#10.5 Set SSH MaxAuthTries to 4 
printf "Checking if SSH MaxAuthTries is set to 4:\n"
if grep "^MaxAuthTries[[:space:]]4" "/etc/ssh/sshd_config"; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i 's/^#MaxAuthTries 6/MaxAuthTries 4/' /etc/ssh/sshd_config
    printf "\e[32mSSH MaxAuthTries is set to 4\e[0m\n"
fi

#10.6 Set SSH IgnoreRhosts to yes
printf "Checking if SSH IgnoreRhosts is set to yes:\n"
if grep "^IgnoreRhosts[[:space:]]yes" "/etc/ssh/sshd_config"; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i 's/^#IgnoreRhosts yes/IgnoreRhosts yes/' /etc/ssh/sshd_config
    printf "\e[32mSSH IgnoreRhosts is set to yes\e[0m\n"
fi

#10.7 Set SSH HostbasedAuthentication to No
printf "Checking if SSH HostbasedAuthentication is set to No:\n"
if grep "^HostbasedAuthentication[[:space:]]no" "/etc/ssh/sshd_config"; then
    printf "\e[32mNo remediation neede\e[0m\n"
else
    sed -i 's/^#HostbasedAuthentication no/HostbasedAuthentication no/' /etc/ssh/sshd_config
    printf "\e[32m SSH HostbasedAuthentication is set to No\e[0m\n"
fi

#10.8 Disable SSH Root Login
printf "Checking if SSH Root login is disabled:\n"
if grep "^PermitRootLogin[[:space:]]no" "/etc/ssh/sshd_config"; then       
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    printf "\e[32mSSH Root login is disabled\e[0m\n"
          
fi

#10.9 Set SSH PermitEmptyPasswords to No
printf "Checking if SSH PermitEmptyPasswords is set to No:\n"
if grep "^PermitEmptyPasswords[[:space:]]no" "/etc/ssh/sshd_config"; then    
    printf "\e[32mNo remediation needed\e[0m\n"   
else
    sed -i 's/^#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    printf "\e[32mSSH PermitEmptyPasswords is set to No\e[0m\n"
fi

#10.10 Use only approved cipher in counter mode 
printf "Checking if only approved cipher is used in counter mode:\n"
if grep "^Ciphers aes128-ctr,aes192-ctr,aes256-ctr" "/etc/ssh/sshd_config"; then       
    printf "\e[32mNo remediation needed\e[0m\n"
else
    echo "Ciphers aes128-ctr,aes192-ctr,aes256-ctr" >> /etc/ssh/sshd_config
    printf "\e[32mOnly approved cipher is used in counter mode\e[0m\n"       
fi

#10.11 Set Idle Timeout Interval for User Login
printf "Checking if ClientAliveInterval is set to 300:\n"
if grep "^ClientAliveInterval[[:space:]]300" "/etc/ssh/sshd_config"; then
    printf "\e[32mNo remediation needed\e[0m\n"       
else
    sed -i 's/^#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
    printf "\e[32mClientAliveInterval is set to 300\e[0m\n"       
fi

printf "Checking if ClientAliveCountMax is set to 0:\n"
if grep  "^ClientAliveCountMax[[:space:]]0" "/etc/ssh/sshd_config"; then   
    printf "\e[32mNo remediation needed\e[0m\n"    
else
    sed -i 's/^#ClientAliveCountMax 3/ClientAliveCountMax 0/' /etc/ssh/sshd_config
    printf "\e[32mClientAliveCountMax is set to 0\e[0m\n"
fi

#10.12 Limit Access via SSH 
printf "Checking access via SSH:\n"
remsshalwusrs=`grep "^AllowUsers" /etc/ssh/sshd_config`
remsshalwgrps=`grep "^AllowGroups" /etc/ssh/sshd_config`
remsshdnyusrs=`grep "^DenyUsers" /etc/ssh/sshd_config`
remsshdnygrps=`grep "^DenyGroups" /etc/ssh/sshd_config`

if [ -z "$remsshalwusrs" -o "$remsshalwusrs" == "AllowUsers[[:space:]]" ]
then
    echo "AllowUsers user1" >> /etc/ssh/sshd_config
    echo -e "\e[32m AllowUsers added\e[0m\n"
    echo -e "\e[32m $remsshalwusrs\e[0m"
else
    echo -e "\e[32m $remsshalwusrs\e[0m"
fi

if [ -z "$remsshalwgrps" -o "$remsshalwgrps" == "AllowUsers[[:space:]]" ]
then
    echo "AllowGroups group1" >> /etc/ssh/sshd_config
    echo -e "\e[32m AllowGroups added\e[0m\n"
    echo -e "\e[32m $remsshalwgrps\e[0m"
else
    echo -e "\e[32m $remsshalwgrps\e[0m"
fi

if [ -z "$remsshdnyusrs" -o "$remsshdnyusrs" == "AllowUsers[[:space:]]" ]
then
    echo "DenyUsers user2 user3" >> /etc/ssh/sshd_config
    echo -e "\e[32m DenyUsers Added\e[0m\n"
    echo -e "\e[32m $remsshdnyusrs\e[0m"
else
    echo -e "\e[32m $remsshdnyusrs\e[0m"
fi

if [ -z "$remsshdnygrps" -o "$remsshdnygrps" == "AllowUsers[[:space:]]" ]
then
    echo "DenyGroups group2" >> /etc/ssh/sshd_config
    echo -e "\e[32m DenyGroups Added\e[0m"
    echo -e "\e[32m $remsshdnygrps\e[0m"
else
    echo -e "\e[32m $remsshdnygrps\e[0m"
fi

#10.13 Set SSH Banner
printf "Check if SSH Banner is set:\n"
if grep "^Banner[[:space:]]/etc/issue.net" "/etc/ssh/sshd_config"; then   
    printf "\e[32mNo remediation needed\e[0m\n"   
else
    sed -i 's/^#Banner none/Banner \/etc\/issue.net/' /etc/ssh/sshd_config
    printf "\e[32mBanner is set\e[0m\n"
fi


#11.1 Upgrade Password Hashing Algorithm to SHA-512
printf "Checking if the password-hashing algorithm is set to SHA-512:\n"
if authconfig --test | grep hashing | grep sha512 ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    authconfig --passalgo=sha512 --update
    cat /etc/passwd | awk -F: '($3 >= 1000 && $1 != "nfsnobody") {print $1}' | \xargs -n 1 chage -d 0
    printf "\e[32mPassword-hashing algorthim is set to SHA-512\e[0m\n"
fi

#11.2 Set Password Creation Requirement Parameters using pam_pwquality
printf "Checking the settings in the /etc/pam.d/system-auth file:\n"
if grep "pam_pwquality.so" "/etc/pam.d/system-auth" ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i -e '/#account\trequired\tpam_permit.so/a password requisite pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=' /etc/pam.d/system-auth
    printf "\e[32mPam_pwquality.so has been set\e[0m\n"
fi

printf "Checking minlen:\n"
if grep "^minlen[[:space:]]=[[:space:]]14" "/etc/security/pwquality.conf" ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i -e 's/.*minlen.*/minlen = 14/' /etc/security/pwquality.conf
    printf "\e[32mminlen has been set\e[0m\n"
fi

printf "Checking dcredit:\n"
if grep "^dcredit[[:space:]]=[[:space:]]-1" "/etc/security/pwquality.conf" ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i -e 's/.*dcredit.*/dcredit = -1/' /etc/security/pwquality.conf
    printf "\e[32mdcredit has been set\e[0m\n"
fi

printf "Checking ucredit:\n"
if grep  "^ucredit[[:space:]]=[[:space:]]-1" "/etc/security/pwquality.conf" ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i -e 's/.*ucredit.*/ucredit = -1/' /etc/security/pwquality.conf
    printf "\e[32mdcredit has been set\e[0m\n"
fi

printf "Checking ocredit:\n"
if grep  "^ocredit[[:space:]]=[[:space:]]-1" "/etc/security/pwquality.conf" ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i -e 's/.*ocredit.*/ocredit = -1/' /etc/security/pwquality.conf
    printf "\e[32mocredit has been set\e[0m\n"
fi

printf "Checking lcredit:\n"
if grep  "^lcredit[[:space:]]=[[:space:]]-1" "/etc/security/pwquality.conf" ; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i -e 's/.*lcredit.*/lcredit = -1/' /etc/security/pwquality.conf
    printf "\e[32mlcredit has been set\e[0m\n"
fi

#11.3  Set Lockout for Failed Password Attempts
printf "Checking for pam_faillock in /etc/pam.d/password-auth:\n"
if grep "pam_faillock" "/etc/pam.d/password-auth"; then  
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i /etc/pam.d/password-auth -e '/# User changes will be destroyed the next time authconfig is run./a auth\trequired\tpam_faillock.so preauth audit silent deny=5 unlock_time=900'
    sed -i /etc/pam.d/password-auth -e '/# User changes will be destroyed the next time authconfig is run./a auth\t[default=die]\tpam_faillock.so authfail audit deny=5'
    sed -i /etc/pam.d/password-auth -e '/# User changes will be destroyed the next time authconfig is run./a auth\tsufficient\tpam_faillock.so authsucc audit deny=5'
    sed -i /etc/pam.d/password-auth -e '/# User changes will be destroyed the next time authconfig is run./a account\trequired\tpam_faillock.so'
    printf "\e[32mpam_faillock added\e[0m\n"
fi
printf "Checking for pam_faillock in /etc/pam.d/system-auth:\n"
if grep "pam_faillock" "/etc/pam.d/system-auth"; then 
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i /etc/pam.d/system-auth -e '/# User changes will be destroyed the next time authconfig is run./a auth\trequired\tpam_faillock.so preauth audit silent deny=5 unlock_time=900'
    sed -i /etc/pam.d/system-auth -e '/# User changes will be destroyed the next time authconfig is run./a auth\t[default=die]\tpam_faillock.so authfail audit deny=5'
    sed -i /etc/pam.d/system-auth -e '/# User changes will be destroyed the next time authconfig is run./a auth\tsufficient\tpam_faillock.so authsucc audit deny=5'
    sed -i /etc/pam.d/system-auth -e' /# User changes will be destroyed the next time authconfig is run./a account\trequired\tpam_faillock.so'
    printf "\e[32mpam_faillock added\e[0m\n"
fi

#11.4 Limit Password Reuse
printf "Checking for Limit Password Reuse:\n"
if grep "remember" /etc/pam.d/system-auth; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    sed -i -e 's/password.*sufficient.*/password\tsufficient\tpam_unix.so sha512 shadow nullok remember=5 try_first_pass use_authtok/' /etc/pam.d/system-auth
    printf "\e[32mLimit password reuse has been set\e[0m\n"
fi

#11.5 Restrict root Login to System Console
printf "Checking if /etc/securetty is empty:\n"
if [ -s "/etc/securetty" ] ; then
    cp /dev/null /etc/securetty
    printf "\e[32m/etc/Removed entries not in a physically secure location\e[0m\n"
else
    printf "\e[32mNo remediation needed\e[0m\n"
fi

#11.6 Restrict Access to the su Command 
printf "Checking for restrict access to su command:\n"
if grep "^auth		required	pam_wheel.so use_uid" "/etc/pam.d/su"; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    echo -e "auth		required	pam_wheel.so use_uid" >> /etc/pam.d/su
    printf "\e[32mRestrict access has been set\e[0m\n"
fi

if cat /etc/group | grep "wheel" | grep "root"; then
    printf "\e[32mNo remediation needed\e[0m\n"
else
    usermod -aG wheel root
    printf "\e[32mUser added\e[0m\n"
fi

#End of 4b Remediation

printf "\e[32mCompleted!\n"
printf "Press any key to exit\e[0m\n"
read -n 1 -s
kill -9 $PPID

#End of Entire Script