#! /bin/bash

bold=$(tput bold)
normal=$(tput sgr0)

#START OF LAB 1B VERIFACTION

reset

#Formatting:
#\e[1m  - Bold
#\e[0m  - Default
#\e[31m - Red colour
#\e[32m - Green colour
#
#Putting output to /dev/null:
# /dev/null is a black hole. Whatever goes in there is discarded, lost, spaghettified
# >/dev/null  - put all command output into /dev/null
# &>/dev/null - put all types of output to /dev/null (including errors)
# 2>/dev/null - put all errors into /dev/null

#Check if UID = 0 (root)
if [ "$EUID" -ne 0 ] ; then
	printf "\e[31mPlease run as root! (sudo doesn't work)\n"
	printf "Press any key to exit\e[0m\n"
	#Takes in one keypress then continues the script
	read -n 1 -s
	exit
fi

#Check if the file "/etc/redhat-release" exists
if [ -e /etc/redhat-release ] ; then
	printf "\e[1mRunning Scan for "
	printf "$(cat /etc/redhat-release)"
	printf "\e[0m\n"
else
	printf "\e[31m\e[1mYou are not on a Red Hat System!\n"
	printf "Press any key to exit\e[0m\n"
	read -n 1 -s
	#Send kill signal 9 (terminate process) to Parent Process ID (in this case, terminal)
	kill -9 $PPID
fi

function ctrl_C() {
	printf "\nCTRL+C Pressed. Program halted.\n"
	printf "Press any key to close terminal..."
	read -n 1 -s
	kill -9 $PPID	
}

function ctrl_Z() {
	kill -9 $PPID
}

#Trap SIGINT (Ctrl+C), run function ctrl_C instead
trap ctrl_C INT
trap ctrl_Z 2 20

printf "Go grab a coffee. This is going to take a while to complete.\n"
printf "\e[31mCtrl+C and Ctrl+Z will immediately close the current terminal window.\e[0m\n"
printf "\e[1mChecks on Partitions and Files\e[0m\n"

printf "Checking if /tmp is on a separate partition: "
#[[:space:]] = any amount of space
if [[ $(grep "[[:space:]]/tmp[[:space:]]" /etc/fstab) ]] ; then
	printf "\e[32mPASS\e[0m\n"

	printf "Checking if /tmp has nodev: "
	#Output to /dev/null [>/dev/null] (supresses output so output is cleaner)
	if [[ $(grep "[[:space:]]/tmp[[:space:]]" /etc/fstab | grep "nodev") ]] ; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi

	printf "Checking if /tmp has nosuid: "
	if [[ $(grep "[[:space:]]/tmp[[:space:]]" /etc/fstab | grep "nosuid") ]] ; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi

	printf "Checking if /tmp has noexec: "
	if [[ $(grep "[[:space:]]/tmp[[:space:]]" /etc/fstab | grep "noexec") ]] ; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var is on a separate partition: "
if [[ $(grep "[[:space:]]/var[[:space:]]" /etc/fstab) ]] ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

#grep -e is to tell grep that the string contains regular expressions
printf "Checking if /var/tmp is bound to /tmp: "
if [[ $(grep -e "^/tmp[[:space:]]" /etc/fstab | grep "/var/tmp") ]] ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log is on a separate partition: "
if [[ $(grep "[[:space:]]/var/log[[:space:]]" /etc/fstab) ]] ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/audit is on a separate partition: "
if [[ $(grep "[[:space:]]/var/log/audit[[:space:]]" /etc/fstab) ]] ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /home is on a separate partition: "
if [[ $(grep "[[:space:]]/home[[:space:]]" /etc/fstab) ]] ; then
	printf "\e[32mPASS\e[0m\n"

	printf "Checking if /home has nodev: "
	if [[ $(grep "[[:space:]]/home[[:space:]]" /etc/fstab | grep "nodev") ]]; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi

else
	printf "\e[31mFAIL\e[0m\n"
fi

#find under '/', ! (not) -permission that is 1000 (sticky bit), but has -permission 0002 (others - write), file type - file. As long as there is a single output (head -n 1), return true.
printf "Checking if sticky bits are enabled: "
if [ -n "$(find / \! -perm /1000 -perm /0002 -type f | head -n 1)" ] ; then
	printf "\e[31mFAIL\e[0m\n"
else
	printf "\e[32mPASS\e[0m\n"
fi

#modprobe -n (dry run - do not execute) -v (verbose) {}. '{}' is a simplified for loop for command line.
printf "\e[1mChecks on System Configurations\e[0m\n"
printf "Checking if legacy file systems are supported on the system: "
if [[ $(modprobe -n -v [cramfs,freexvfs,jffs2,hfs,hfsplus,squashfs,udf]) ]]; then
	printf "\e[31mFAIL\e[0m\n"
else
	printf "\e[32mPASS\e[0m\n"
fi

#subscription-manager version will show if the machine is registered or not
printf "Checking if system is registered to Redhat: "
if [[ $(subscription-manager version | grep "not registered") ]] ; then
	printf "\e[31mFAIL\e[0m\n"
else
	printf "\e[32mPASS\e[0m\n"
fi

#rpm -q: query, -V: verify package, -a: all packages
printf "\e[1mChecks on Packages and Services\e[0m\n"
printf "Checking if any packages are problematic: "
if [[ $(rpm -qVa | awk '$2 != "c" { print $0}' &>/dev/null | head -n 1) ]] ; then
	printf "\e[31mFAIL\e[0m\n"
else
	printf "\e[32mPASS\e[0m\n"
fi

#rpm -q: query package, package name - will show if package is installed
printf "Checking if Telnet is not installed: "
if [[ $(rpm -q telnet-server | grep "not installed") ]] ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mTelnet is installed. Replace with SSH\e[0m\n"
fi

printf "Checking if RSH is not installed: "
if [[ $(rpm -q rsh-server | grep "not installed" >/dev/null && rpm -q rsh | grep "not installed") ]] ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mRSH is installed. Replace with SSH\e[0m\n"
fi

printf "Checking if NIS is not installed: "
if [[ $(rpm -q ypserv | grep "not installed" >/dev/null && rpm -q ypbind | grep "not installed") ]] ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mNIS is installed. Replace with other protocols such as LDAP\e[0m\n"
fi

printf "Checking if TFTP is not installed: "
if [[ $(rpm -q tftp | grep "not installed" >/dev/null && rpm -q tftp-server | grep "not installed") ]] ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mTFTP is installed. Consider replacing with SFTP\e[0m\n"
fi

printf "Checking if xinetd is not installed: "
if [[ $(rpm -q xinetd | grep "not installed") ]] ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mxinetd is installed. Remove if not needed\e[0m\n"
	printf "Checking if chargen-dgram is disabled: "
	if [[ $(chkconfig --list chargen-dgram 2>/dev/null | grep "chargen-dgram[[:space:]]off") ]] ; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi

	printf "Checking if chargen-stream is disabled: "
	if [[ $(chkconfig --list chargen-stream 2>/dev/null | grep "chargen-stream[[:space:]]off") ]] ; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi

	printf "Checking if daytime-dgram is disabled: "
	if [[ $(chkconfig --list daytime-dgram 2>/dev/null | grep "daytime-dgram[[:space:]]off") ]] ; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi

	printf "Checking if daytime-stream is disabled: "
	if [[ $(chkconfig --list daytime-stream 2>/dev/null | grep "daytime-stream[[:space:]]off") ]] ; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi

	printf "Checking if echo-dgram is disabled: "
	if [[ $(chkconfig --list echo-dgram 2>/dev/null | grep "echo-dgram[[:space:]]off") ]] ; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi

	printf "Checking if echo-stream is disabled: "
	if [[ $(chkconfig --list echo-stream 2>/dev/null | grep "echo-stream[[:space:]]off") ]] ; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi

	printf "Checking if tcpmux-server is disabled: "
	if [[ $(chkconfig --list tcpmux-serer 2>/dev/null | grep "tcpmux-server[[:space:]]off") ]]  ; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi
fi

printf "Checking if umask is of the recommended value: "
if [[ $(grep ^umask /etc/sysconfig/init | grep "027") ]]; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if GUI is the default boot target: "
if [[ $(systemctl get-default | grep "graphical.target") ]] ; then
	printf "\e[32mGUI is the default boot target. Check if CLI is preferred and X11 can be removed\e[0m\n"
else
	printf "\e[31mGUI is not the default boot target - please check and decide if X11 can be removed\e[0m\n"
fi

printf "Checking if Avahi Daemon is disabled: "
if [[ $(systemctl is-active avahi-daemon | grep "active") ]] || [[ $(systemctl is-enabled avahi-daemon | grep "enabled") ]] ; then
	printf "\e[31mFAIL\e[0m\n"
else
	printf "\e[32mPASS\e[0m\n"
fi

printf "Checking if CUPS has been disabled: "
if [[ $(systemctl is-active cups | grep "active") ]] || [[ $(systemctl is-enabled cups | grep "enabled") ]] ; then
	printf "\e[31mCUPS enabled. Remove if not needed\e[0m\n"
else
	printf "\e[32mCUPS has been disabled\e[0m\n"
fi

printf "Checking if DHCPD is removed: "
if [[ $(yum list dhcpd &>/dev/null | grep "Installed Packages") ]] ; then
	printf "\e[31mDHCPD is installed. Remove if not needed\e[0m\n"
else
	printf "\e[32mDHCPD is not installed\e[0m\n"
fi

printf "Checking NTP configurations: "
if [[ $(yum list ntp &>/dev/null | grep "Installed Packages") ]] ; then
	if [[ $(grep "^restrict default" /etc/ntp.conf) ]] && [[ $(grep "^restrict -6 default" /etc/ntp.conf) ]] && [[ $(grep "^server" /etc/ntp.conf) ]] && [[ $(grep "ntp:ntp" /etc/sysconfig/ntpd) ]] ; then
		printf "\e[32mPASS\e[0m\n"
	else
		printf "\e[31mFAIL\e[0m\n"
	fi
else
	printf "NTP is not installed. Skipping checks..."
fi

printf "Checking if LDAP is removed: "
if [[ $(yum list { openldap-clients, openldap-servers } &>/dev/null | grep "Installed Packages") ]] ; then
	printf "\e[31mLDAP is installed. Remove if not needed\e[0m\n"
else
	printf "\e[32mLDAP is not installed\e[0m\n"
fi
printf "Checking if NFS and RPC are disabled: "
if [[ $(systemctl is-enabled nfs-lock | grep "enabled") ]] && [[ $(systemctl is-enabled nfs-secure | grep "enabled") ]] && [[ $(systemctl is-enabled rpcbind | grep "enabled") ]] && [[ $(systemctl is-enabled nfs-idmap | grep "enabled") ]] && [[ $(systemctl is-enabled nfs-secure-server | grep "enabled") ]] ; then
	printf "\e[31mNFS and RPC are enabled. Disable if not needed\e[0m\n"
else
	printf "\e[32mNFS and RPC are disabled\e[0m\n"
fi
printf "Checking if DNS is disabled: "
if [[ $(systemctl is-enabled named &>/dev/null | grep "enabled") ]] ; then
	printf "\e[31mDNS is enabled. Disable if not needed\e[0m\n"
else
	printf "\e[32mDNS is disabled\e[0m\n"
fi
printf "Checking if FTP is removed: "
if [[ $(rpm -qa &>/dev/null | grep "ftp") ]] ; then
	printf "\e[31mFTP is installed. Consider switching to VSFTPD\e[0m\n"
else
	printf "\e[32mFTP is not installed\e[0m\n"
fi
printf "Checking if HTTP service is removed: "
if [[ $(rpm -qa &>/dev/null | grep "httpd") ]] ; then
	printf "\e[31mHTTPD is installed\e[0m\n"
else
	printf "\e[32mHTTPD is not installed\e[0m\n"
fi
printf "Checking if HTTP Proxy Server is removed: "
if [[ $(rpm -qa &>/dev/null | grep "squid") ]] ; then
	printf "\e[31mHTTPD Proxy Server installed\e[0m\n"
else
	printf "\e[32mHTTP Proxy Server is not installed\e[0m\n"
fi
printf "Checking if SNMP Service is removed: "
if [[ $(rpm -qa &>/dev/null | grep "net-snmp") ]] ; then
	printf "\e[31mSNMP Service is installed\e[0m\n"
else
	printf "\e[32mSNMP Service is not installed\e[0m\n"
fi
printf "Checking if Mail Transfer Agent is Local-Only: "
if [ "$(netstat -an | grep LIST | grep ':25[[:space:]]' | wc -l)" -lt 3 ] ; then
	if [ "$(netstat -an | grep LIST | grep ':25[[:space:]]' | wc -l)" -eq 2 ] ; then
		if [[ $(netstat -an | grep LIST | grep ':25[[:space:]]' | grep "127.0.0.1:25") ]] && [[ $(netstat -an | grep LIST | grep ':25[[:space:]]' | grep "::1:25") ]] ; then
			printf "\e[32mMTA is Local-Only\e[0m\n"
		else
			printf "\e[31mMTA is not Local-Only\e[0m\n"
		fi
	elif [[ $(netstat -an | grep LIST | grep ':25[[:space:]]' | grep "127.0.0.1") ]] ; then
		printf "\e[32mMTA is Local-Only\e[0m\n"
	else
		printf "\e[31mMTA is not Local-Only\e[0m\n"
	fi
else
	printf "\e[31mMTA is not Local-Only\e[0m\n"
fi
#END OF LAB 1B VERIFICAITON
#START OF LAB 2B VERIFCATION

#4.1 Check if editing prevention is done
printf "Checking if grub.cfg belongs to root: "
if stat -L -c "owner=%U group=%G" /boot/grub2/grub.cfg | grep "owner=root group=root" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#4.2 Disable non-root users from seeing the boot parameters or changing them unnecessarily 
printf "Checking if grub.cfg file is set to read and write for root only: "
if stat -L -c "%a" /boot/grub2/grub.cfg | grep "00" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#4.3 To prevent any unauthorized user from entering boot parameters
printf "Checking if boot loader password is set: \n"
grep "set superusers" /boot/grub2/grub.cfg
grep "password" /boot/grub2/grub.cfg
#5.1 Prevents core dump snooping
printf "Checking if core dumps are restricted: \n"
grep "hard" /etc/security/limits.conf
printf "fs.suid_dumpable == 0? "
if sysctl fs.suid_dumpable >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#5.2 Check if randomized virtual memory region is active
printf "Checking if virtual memory is randomized: "
if sysctl kernel.randomize_va_space >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[32mFAIL\e[0m\n"
fi
#6.1.1 Security enhancements of rsyslog
printf "Checking if rsyslog package is installed: "
if rpm -q rsyslog | grep "rsyslog" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.1.2 Is rsyslog running?
printf "Checking if rsyslog is enabled: "
if systemctl is-enabled rsyslog | grep "enabled" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.1.3 Configuration is secure?
printf "Checking if appropriate logging is set: "
if (cat /etc/rsyslog.conf | grep "auth,user.* /var/log/messages" >/dev/null) || (cat /etc/rsyslog.conf | grep "kern.* /var/log/kern.log" >/dev/null) || (cat /etc/rsyslog.conf | grep "daemon.* /var/log/daemon.log" >/dev/null) || (cat /etc/rsyslog.conf | grep "syslog.* /var/log/daemon.log" >/dev/null) || (cat /etc/rsyslog.conf | grep "lpr,news,uucp,local0,local1,local2,local3,local4,local5,local6.* /var/log/unused.log") ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.1.4 Permission for said logs
printf "Checking if /var/log/messages is root root: "
if ls -l /var/log/messages | grep "root root" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/messages is 600: "
if stat -c "%a %n"  /var/log/messages | grep "600" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/messages is 640: "
if stat -c "%a %n"  /var/log/messages | grep "640" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/secure is root root: "
if ls -l /var/log/secure | grep "root root" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/secure is 600: "
if stat -c "%a %n"  /var/log/secure | grep "600" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/secure is 640: "
if stat -c "%a %n"  /var/log/secure | grep "640" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/maillog is root root: "
if ls -l /var/log/maillog | grep "root root" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/maillog is 600: "
if stat -c "%a %n"  /var/log/maillog | grep "600" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/maillog is 0640: "
if stat -c "%a %n"  /var/log/maillog | grep "640" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/cron is root root: "
if ls -l /var/log/cron | grep "root root" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/cron is 600: "
if stat -c "%a %n"  /var/log/cron | grep "600" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/cron is 640: "
if stat -c "%a %n"  /var/log/cron | grep "640" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/spooler is root root: "
if ls -l /var/log/spooler | grep "root root" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/spooler is 600: "
if stat -c "%a %n"  /var/log/spooler | grep "600" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/spooler is 640: "
if stat -c "%a %n"  /var/log/spooler | grep "640" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/boot.log is root root: "
if ls -l /var/log/boot.log | grep "root root" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/boot.log is 600: "
if stat -c "%a %n"  /var/log/boot.log | grep "600" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if /var/log/boot.log is 640: "
if stat -c "%a %n"  /var/log/boot.log | grep "640" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

#6.1.5 Sending of logs to remote host
printf "Checking if rsyslog sends logs to remote log host: "
if grep "^*.*[^|][^|]*@" /etc/rsyslog.conf >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.1.6 Prevents spoofed log data
printf "Checking if rsyslog is listening for remote messages: "
printf "ModLoad imtcp.so: "
if grep '$ModLoad imtcp.so' /etc/rsyslog.conf >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "InputTCPServerRun 514: "
if grep '$InputTCPServerRun' /etc/rsyslog.conf >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.1 View audit log file size limit
printf "Maximum size of the audit log files (MB): \n"
grep max_log_file /etc/audit/auditd.conf
#6.2.1.2 Ensure logs are kept
printf "Checking if audit logs are retained: "
if grep max_log_file_action /etc/audit/auditd.conf | grep "keep_logs" > /dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.3 Prevents flooding of system
printf "Checking if space_left_action = email: "
if grep space_left_action /etc/audit/auditd.conf | grep "email" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking the action_mail_acct = root: "
if grep action_mail_acct /etc/audit/auditd.conf | grep "root" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

printf "Checking if admin_space_left_action = halt: "
if grep admin_space_left_action /etc/audit/auditd.conf | grep "halt" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.4 Reports unauthorized system access
printf "Checking if auditd is enabled: "
if systemctl is-enabled auditd | grep "enabled" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.5 Detects potential malicious activity
printf "Checking if /boot/grub2/grub.cfg is configured to log: "
if grep "[[:space:]]linux" /boot/grub2/grub.cfg | grep "audit=1" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.6 If time is manipulated, could be a sign of malicious activity
printf "Checking if system date/time are captured when modified: "
if (egrep 'adjtimex|settimeofday|clock_settime' /etc/audit/audit.rules | grep "a always, exit -F arch=b64 -S adjtimex -S settimeofday -k time-change" >/dev/null) && (egrep 'adjtimex|settimeofday|clock_settime' /etc/audit/audit.rules | grep "a always, exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change" >/dev/null) && (egrep 'adjtimex|settimeofday|clock_settime' /etc/audit/audit.rules | grep "a always, exit -F arch=b64 -S clock_settime -k time-change" >/dev/null) && (egrep 'adjtimex|settimeofday|clock_settime' /etc/audit/audit.rules | grep "a always, exit -F arch=b32 -S clock_settime -k time-change" >/dev/null) ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.7 Check if any records are manipulated, if it is, could be sign of 'covering up' of malicious activities
printf "Checking if modifying user/group information are recorded: "
if (egrep '\/etc\/group|\/etc\/passwd|\/etc\/gshadow|\/etc\/shadow|\/etc\/security\/opasswd' /etc/audit/audit.rules | grep "w /etc/group -p wa -k identity" >/dev/null) && (egrep '\/etc\/group|\/etc\/passwd|\/etc\/gshadow|\/etc\/shadow|\/etc\/security\/opasswd' /etc/audit/audit.rules | grep "w /etc/passwd -p wa -k identity" >/dev/null) && (egrep '\/etc\/group|\/etc\/passwd|\/etc\/gshadow|\/etc\/shadow|\/etc\/security\/opasswd' /etc/audit/audit.rules | grep "w /etc/gshadow -p wa -k identity" >/dev/null) && (egrep '\/etc\/group|\/etc\/passwd|\/etc\/gshadow|\/etc\/shadow|\/etc\/security\/opasswd' /etc/audit/audit.rules | grep "w /etc/shadow -p wa -k identity" >/dev/null) && (egrep '\/etc\/group|\/etc\/passwd|\/etc\/gshadow|\/etc\/shadow|\/etc\/security\/opasswd' /etc/audit/audit.rules | grep "w /etc/security/opasswd -p wa -k identity" >/dev/null) ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.8 Malicious user may modify system's environment for phishing
printf "Checking if modification of the system's environment are recorded: "
if (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale" >/dev/null) && (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale" >/dev/null) && (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "w /etc/issue -p wa -k system-locale" >/dev/null) && (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "w /etc/issue.net -p wa -k system-locale" >/dev/null) && (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "w /etc/hosts -p wa -k system-locale" >/dev/null) && (egrep 'sethostname | setdomainname |\/etc\/issue|\/etc\/hosts|\/etc\/sysconfig\/network' /etc/audit/audit.rules | grep "w /etc/sysconfig/network -p wa -k system-locale" >/dev/null) ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.9 MAC policy manipulation check
printf "Checking if modification of system's mandatory access controls are recorded: "
if grep \/etc\/selinux /etc/audit/audit.rules | grep "w /etc/selinux/ -p wa -k MAC-policy" >/dev/null; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.10 Logins and logout
printf "Checking if login and logout events are recorded: "
if (grep logins /etc/audit/audit.rules | grep "w /var/log/faillog -p wa -k logins" >/dev/null) && (grep logins /etc/audit/audit.rules | grep "w /var/log/lastlog -p wa -k logins" >/dev/null) && (grep logins /etc/audit/audit.rules | grep "w /var/log/tallylog -p wa -k logins" >/dev/null); then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.11 Anomalies in login timing may be useful
printf "Checking if session initiation information is collected: "
if (egrep 'wtmp|btmp|utmp' /etc/audit/audit.rules | grep "w /var/run/utmp -p wa -k session" >/dev/null) && (egrep 'wtmp|btmp|utmp' /etc/audit/audit.rules | grep "w /var/log/wtmp -p wa -k session" >/dev/null) && (egrep 'wtmp|btmp|utmp' /etc/audit/audit.rules | grep "w /var/log/btmp -p wa -k session" >/dev/null) ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.12 May indicate intruder activity or policy violation
printf "Checking if permission modifications are being recorded: "
if (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) && (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) && (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) && (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) && (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) && (grep perm_mod /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod" >/dev/null) ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.13 Logs failed login attempts
printf "Checking if there are unsuccessful attempts: "
if (grep access /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access" >/dev/null) && (grep access /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access" >/dev/null) && (grep access /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access" >/dev/null) && (grep access /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access" >/dev/null) ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi

#6.2.1.14 Logs 'sudo' commands?
printf "Checking if privileged commands are in audit: "
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f | awk '{print "-a always,exit-F path=" $1 " -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged" }' > /tmp/1.log

checkpriviledge=`cat /tmp/1.log`
cat /etc/audit/audit.rules | grep -- "$checkpriviledge" > /tmp/2.log

checkpriviledgenotinfile=`grep -F -x -v -f /tmp/2.log /tmp/1.log`

if [ -n "$checkpriviledgenotinfile" ]
then
	printf "\e[31mFAIL\e[0m\n"
else
	printf "\e[32mPASS\e[0m\n"
fi

rm /tmp/1.log
rm /tmp/2.log
#6.2.1.15 Logs 'mounted' devices
printf "Checking if filesystem mounts are recorded: "
if (grep mounts /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts" >/dev/null) && (grep mounts /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts" >/dev/null) ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.16 Logs any deletion or alteration activities done by users
printf "Checking if file deletion events by user are recorded: "
if (grep delete /etc/audit/audit.rules | grep "a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete" >/dev/null) && (grep delete /etc/audit/audit.rules | grep "a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete" >/dev/null) ; then
	printf "\e[32mPASS\e[0m\n"	
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.17 Logs changes to file /etc/sudoers 
printf "Checking if changes to /etc/sudoers are recorded: "
if grep scope /etc/audit/audit.rules | grep "w /etc/sudoers -p wa -k scope" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.18 Is 'sudologs' enabled?
printf "Checking if administrator activity is recorded: "
if grep actions /etc/audit/audit.rules | grep "w /var/log/sudo.log -p wa -k actions" >/dev/null ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.19 Logs kernel module activities, suspicious activity can subsequently be reviewed
printf "Checking if kernel module loading and unloading is recorded: "
if (grep modules /etc/audit/audit.rules |grep "w /sbin/insmod -p x -k modules" >/dev/null) && (grep modules /etc/audit/audit.rules |grep "w /sbin/rmmod -p x -k modules" >/dev/null) && (grep modules /etc/audit/audit.rules |grep "w /sbin/modprobe -p x -k modules" >/dev/null) && (grep modules /etc/audit/audit.rules |grep "w /sbin/insmod -p x -k modules" >/dev/null) && (grep modules /etc/audit/audit.rules |grep "a always,exit -F arch=b64 -S init_module -S delete_module -k modules" >/dev/null) ; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.20 Unauthorised changes to system would be recorded
printf "Checking if the audit configuration is immutable: "
if grep "^-e 2" /etc/audit/audit.rules >/dev/null; then
	printf "\e[32mPASS\e[0m\n"
else
	printf "\e[31mFAIL\e[0m\n"
fi
#6.2.1.21 Organised system logs
printf "Checking if the appropriate system logs are rotated: "
if (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/messages" >/dev/null) && (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/secure" >/dev/null) && (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/maillog" >/dev/null) && (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/spooler" >/dev/null) && (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/boot.log" >/dev/null) && (grep 'var' /etc/logrotate.d/syslog |grep "/var/log/cron" >/dev/null) ; then
	printf "\e[32mPASS\e[0m\n" 
else
	printf "\e[31mFAIL\e[0m\n"
fi

#END OF LAB 2B VERIFICATION
#START OF LAB 3B VERIFICATION

printf "\n \033[0;30m${bold}7.1 Set Password Expiration Days${normal} \n\n"
printf "Checking user account defaults: (Password Max Days)\n"
#Checks the defaults for password max days, only gets the numbers
maxDays=$(grep ^PASS_MAX_DAYS /etc/login.defs | grep -o '[0-9]*')
if [ $maxDays -le 90 ]; then
	printf "\e[32m$maxDays Pass\e[0m\n"
else
	printf "\e[31m$maxDays Fail\e[0m\n"
	printf "Please run remediation\n"
fi
#Gets existing users
USER=$(cat /etc/passwd | grep "/bin/bash" | cut -d : -f 1)
list=(${USER})
printf "Checking existing user accounts: (Password Max Days)\n"
#For loop through each existing user to check max days
for i in "${list[@]}"
do
	day=$(chage -l $i | grep "Maximum number" | cut -d : -f 2)
	if [ $day -le 90 ]; then 
		printf "\e[32m$i $day Pass\e[0m\n"
	else
		printf "\e[31m$i $day Fail\e[0m\n"
		printf "Please run remediation\n"
	fi
done


printf "\n \033[0;30m${bold}7.2 Set Password Change Minimum Number of Days${normal} \n\n"
#Checks the defaults for password min days, only gets the numbers
printf "Checking user account defaults: (Password Min Days)\n"
minDays=$(grep ^PASS_MIN_DAYS /etc/login.defs | grep -o '[0-9]*')
if [ $minDays -ge 7 ]; then
	printf "\e[32m$minDays Pass\e[0m\n"
else
	printf "\e[31m$minDays Fail\e[0m\n"
	printf "Please run remediation\n"
fi
#Gets existing users
USER=$(cat /etc/passwd | grep "/bin/bash" | cut -d : -f 1)
list=(${USER})
printf "Checking existing user accounts: (Password Min Days)\n"
#For loop through each existing user to check min days
for i in "${list[@]}"
do
	day=$(chage -l $i | grep "Minimum number" | cut -d : -f 2)
	if [ $day -ge 7 ]; then 
		printf "\e[32m$i $day Pass\e[0m\n"
	else
		printf "\e[31m$i $day Fail\e[0m\n"
		printf "Please run remediation\n"
	fi
done


printf "\n \033[0;30m${bold}7.3 Set Password Expiring Warning Days${normal} \n\n"
printf "Checking user account defaults: (Password Exp Warning Days)\n"
#Checks the defaults for password expiring warning days, only gets the numbers
expDays=$(grep ^PASS_WARN_AGE /etc/login.defs | grep -o '[0-9]*')
if [ $expDays -ge 7 ]; then
	printf "\e[32m$expDays Pass\e[0m\n"
else
	printf "\e[31m$expDays Fail\e[0m\n"
	printf "Please run remediation\n"
fi
#Gets existing users
USER=$(cat /etc/passwd | grep "/bin/bash" | cut -d : -f 1)
list=(${USER})
printf "Checking existing user accounts: (Password Exp Warning Days)\n"
#For loop through each existing user to check password expiring warning days
for i in "${list[@]}"
do
	day=$(chage -l $i | grep "warning" | cut -d : -f 2)
	if [ $day -ge 7 ]; then 
		printf "\e[32m$i $day Pass\e[0m\n"
	else
		printf "\e[31m$i $day Fail\e[0m\n"
		printf "Please run remediation\n"
	fi
done


printf "\n \033[0;30m${bold}7.4 Disable User Accounts${normal} \n\n"
#Checks that users with UID of <1000, not named "sync", "shutdown", "halt" and "root" are locked and shells are set to /sbin/nologin
RESULT=$(egrep -v "^\+" /etc/passwd | awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $3<1000 && $7!="/usr/sbin/nologin" && $7!="/sbin/nologin" && $7!="/bin/false")')
if [ -z $RESULT ]; then
  printf "\e[32mSuccessful\e[0m\n"
else
  printf "\e[31mYour account should be locked! Please run remediation!\e[0m\n"
  egrep -v "^\+" /etc/passwd | awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $3<1000 && $7!="/usr/sbin/nologin" && $7!="/sbin/nologin")' |  cut -d : -f 1 
fi


printf "\n \033[0;30m${bold}7.5 Set Default Group for root Account${normal} \n\n"
printf "Checking for root's default group\n"
#Checks whether GID = 0
DGROUP=$(grep "^root:" /etc/passwd | cut -f4 -d:)
if [ "$DGROUP" -eq 0 ]; then
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi
echo  -en "\e[0m"


printf "\n \033[0;30m${bold}7.6 Set Default umask for Users${normal} \n\n"
printf "Checking umask for users\n "
#Checks if Umask is set to 077
if grep "umask 077" /etc/bashrc | grep "umask 077" /etc/profile.d/* >/dev/null; then
	printf "\033[33;32mPASSED, umask is already set to 077. \n"
else
	printf "\033[33;31mFAILED, please set umask to 077. \n"
fi 
echo  -en "\e[0m"


printf "\n \033[0;30m${bold}7.7 Lock Inactive User Accounts${normal} \n\n"
#Checks if Inactive Days are more than or equal to 35
printf "Checking for days until accounts deactivates\n"
if useradd -D | grep INACTIVE=35 >/dev/null; then
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi
echo  -en "\e[0m"


printf "\n \033[0;30m${bold}7.8 Ensure Password Fields are Not Empty${normal} \n\n"
#Verifies that there are no accounts with empty password fields
printf "Checking that password fields are not empty"
PFieldsNEmpty= $(cat /etc/shadow | awk -F: '($2 == "" ) { print $1 " does not have a password "}')
echo $PFieldsNEmpty
if [ -z "$PFieldsNEmpty" ]; then
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi
echo  -en "\e[0m"


printf "\n \033[0;30m${bold}7.9 Verify No Legacy "+" Entries Exist in /etc/passwd, /etc/shadow and /etc/group files${normal} \n\n"
#Checks Legacy Entries for '^+:'
printf "Checking that no Legacy Entries exist in etc/passwd, /etc/shadow and /etc/group files\n"
PASSWD=$(grep '^+:' /etc/passwd)
SHADOW=$(grep '^+:' /etc/shadow)
GROUP=$(grep '^+:' /etc/group)
#echo $PASSWD
#echo $SHADOW
#echo $GROUP
#Checks that there is no output for all accounts
if [ -z "$PASSWD" ] && [ -z "$SHADOW" ] && [ -z "$GROUP" ]; then
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi
echo  -en "\e[0m"


printf "\n \033[0;30m${bold}7.10 Verify No UID 0 Accounts Exist Other Than root${normal} \n\n"
#Checks that only root has UID of 0
printf "Checking that no UID 0 exist besides root\n"
VerifyUIDRoot=$(/bin/cat /etc/passwd | /bin/awk -F: '($3 == 0){print $1}')
if [ "$VerifyUIDRoot" = 'root' ]
then
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi
echo  -en "\e[0m"


printf "\n \033[0;30m${bold}7.11 Ensure root PATH Integrity${normal} \n\n"
#Checks that none of the path entries are empty
printf "Checking root path integrity\n"
if [ "`echo $PATH | grep :: `" != "" ]; then
	echo "Empty Directory in PATH (::)"
fi
#Checks that none of the path entries is a '.'
p=`echo $PATH | sed -e 's/::/:/' -e 's/:$//' -e 's/:/ /g'`
set -- $p
while [ "$1" != "" ]; do
	if [ "$1" = "." ]; then
		echo "PATH contains ."
		shift
		continue
	fi
#Checks that 6th and 9th character of permissions are not 'w'
	if [ -d $1 ]; then
		perm6=$(ls -ldH $1 | grep "^.....w....")
		perm9=$(ls -ldH $1 | grep "^........w.")
		if [ -z "$perm6" ]; then
			printf "\e[32mPass - Group Write permission not set on directory $1\e[0m\n"
		else
			printf "\e[31mFail - Group Write permission set on directory $1\e[0m\n"
			printf "Please run remediation\n"
		fi
		if [ -z "$perm9" ]; then
			printf "\e[32mPass - Other Write permission not set on directory $1\e[0m\n"
		else
			printf "\e[31mFail - Other Write permission set on directory $1\e[0m\n"
			printf "Please run remediation\n"
		fi
#Checks if owner is root
		dirown=`ls -ldH $1 | awk '{print $3}'`
		if [ "$dirown" == "root" ] ; then
			printf "\e[32mPass - $1 is owned by root\e[0m\n\n"
		else
			printf "\e[31mFail - $1 is not owned by root\e[0m\n"
			printf "Please run remediation\n\n"
		fi
	else
		printf "\e[31m$1 is not a directory\e[0m\n"
	fi
shift
done


printf "\n \033[0;30m${bold}7.12 Check Permissions on User Home Directories${normal} \n\n"
#For loop to get accounts that can log in interactively to the system
for RESULT in `cat /etc/passwd | egrep -v '(root|halt|sync|shutdown)' |awk -F: '($7!="/usr/sbin/nologin" && $7!="/sbin/nologin" && $7!="/bin/false") { print $6 }'`; do
resultperm=$(ls -ld $RESULT)
#Checks that 6th character of permissions is not 'w'
if [[ ` echo $resultperm | grep "^......w..." ` ]]; then 
	echo "Fail, Group Write permission is set on directory $RESULT"
else
	echo "Pass, Group Write permission is not set on directory $RESULT"
fi
#Checks that 8th character of permissions is '-'
if [[ ` echo $resultperm | grep "^.......-.." `  ]]; then
	echo "Pass, Other Read permission is not set on directory $RESULT"
else
	echo "Fail, Other Read permission is set on directory $RESULT"
fi
#Checks that 9th character of permissions is '-'
if [[ `echo $resultperm | grep "^........-."` ]]; then
	echo "Pass, Other Write permission is not set on directory $RESULT"
else
	echo "Fail, Other Write permission is set on directory $RESULT"
fi
#Check that 10th character of permissions is '-'
if [[ `echo $resultperm | grep "^.........-"` ]]; then
	echo "Pass, Other Execute permission is not set on directory $RESULT"
else
	echo "Fail, Other Execute permission is set on directory $RESULT"
fi
done


printf "\n \033[0;30m${bold}7.13 Check User Dot File Permissions${normal} \n\n"
#For loop to get hidden files in the user's home directory
printf "Checking user dot file permissions\n"
for dir in `cat /etc/passwd | egrep -v '(root|sync|halt|shutdown)' | awk -F: '($7 != "/sbin/nologin" && $7 != "/usr/sbin/nologin" && $7 != "/bin/false") { print $6 }'`; do
for file in $dir/.[A-Za-z0-9]*; do
#Checks that 6th and 9th character of permissions are not 'w'
perm6=$(ls -ld $file | grep "^.....w....")
perm9=$(ls -ld $file | grep "^........w.")
if [ -z "$perm6" ] && [ -z "$perm9" ]; then
	printf "\e[32mPass - $file\e[0m\n"
else
	printf "\e[31mFail - $file\e[0m\n"
	printf "Please run remediation\n"
fi
done
done


printf "\n \033[0;30m${bold}7.14 Checking for Existence and Permission of User .netrc Files${normal} \n\n" 

#Determines the home directory of interactive user accounts
for dir in `/bin/cat /etc/passwd | /bin/egrep -v '(root|halt|sync|shutdown)' |/bin/awk -F: '($7 != "/sbin/nologin") { print $6 }'`; do

#Searches the home directory of interactive user accounts for .netrc file
for file in $dir/.netrc; do
if [ ! -h "$file" -a -f "$file" ]; then
printf "\033[33;30m Found! .netrc file found in directory $dir, checking file permissions... \n"
else
printf "\033[33;35m No .netrc file found in directory $dir. \n"
fi

#Checks the permissions of the .netrc file
if [ ! -h "$file" -a -f "$file" ]; then
fileperm=`/bin/ls -ld $file | /bin/cut -f1 -d" "`

#Checks the Group Read permission (5th Character) 
if [ `echo $fileperm | /bin/cut -c5 ` != "-" ]
then
printf "\033[33;32m Group Read set on $file. \n"
else
printf "\033[33;31m Group Read not set on $file. \n"
fi

#Checks the Group Write permission (6th Character) 
if [ `echo $fileperm | /bin/cut -c6 ` != "-" ]
then
printf "\033[33;32m Group Write set on $file. \n"
else
printf "\033[33;31m Group Write not set on $file. \n"
fi

#Checks the Group Execute permission (7th Character) 
if [ `echo $fileperm | /bin/cut -c7 ` != "-" ]
then
printf "\033[33;32m Group Execute set on $file. \n"
else
printf "\033[33;31m Group Execute not set on $file. \n"
fi

#Checks the Others Read permission (8th Character) 
if [ `echo $fileperm | /bin/cut -c8 ` != "-" ]
then
printf "\033[33;32m Others Read set on $file. \n"
else
printf "\033[33;31m Others Read not set on $file. \n"
fi

#Checks the Others Write permission (9th Character) 
if [ `echo $fileperm | /bin/cut -c9 ` != "-" ]
then
printf "\033[33;32m Others Write set on $file. \n"
else
printf "\033[33;31m Others Write not set on $file. \n"
fi

#Checks the Others Execute permission (10th Character) 
if [ `echo $fileperm | /bin/cut -c10 ` != "-" ]
then
printf "\033[33;32m Others Execute set on $file. \n"
else
printf "\033[33;31m Others Execute not set on $file. \n"
fi
fi
echo  -en "\e[0m \n"
done
done

printf "\n \033[0;30m${bold}7.15 Check for Presence of User .rhosts Files${normal} \n\n"
#Get interactive user accounts
printf "\033[0;30mChecking for Presence of User .rhosts Files \n"
for dir in `/bin/cat /etc/passwd | /bin/egrep -v '(root|halt|sync|shutdown)' |/bin/awk -F: '($7 != "/sbin/nologin") { print $6 }'`; do
#For loop to see if rhost file exists in user's home directory
for file in $dir/.rhosts; do
#Checks if rhosts file is needed
if [ ! -h "$file" -a -f "$file" ]; then
printf "\033[33;31m.rhosts file found in $dir, please delete file if it is not needed. \n"
else
printf "\033[33;32mNo .rhosts file found in $dir \n"
fi
echo  -en "\e[0m"
done
done


printf "\n \033[0;30m${bold}7.16 Check Groups in /etc/passwd${normal} \n\n"
#For every row in /etc/passwd
for i in $(cat /etc/passwd | cut -d : -f 4 | sort -u); do 
#Verifies GID defined in /etc/group
	grep -q -P "^.*?:x:$i:" /etc/group
		if [ $? -ne 0 ]; then 
			echo "Group $i is referenced by /etc/passwd but does not exists in /etc/group"
		else
			printf "\e[32mPass - Group: $i\e[0m\n"
		fi
done


printf "\n \033[0;30m${bold}7.17 Check That Users Are Assigned Valid Home Directories and Home Directory Ownership is Correct${normal} \n\n"
#In etc/passwd, check if home directory is defined in field no. 6. See if valid and exist
cat /etc/passwd | awk -F : '{print $1, $3, $6}' | while read user uid dir; do 
	if [ $uid -ge 1000 -a ! -d "$dir" -a $user != "nfsnobody" ]; then 
		printf "\e[31mHome directory ($dir) of user $user does not exist.\e[0m\n"
	elif [ ! -d $dir ] ; then
		printf "\e[31mHome Directory of $user cannot be found!\e[0m\n"
	else 
		printf "\e[32mPass - $user $dir\e[0m\n"
		echo "Checking if Home directory ownership of $user is correct"
		ls -ld $dir | awk '{print $3, $4}' | while read owner user1; do
		if [ "$owner" != "$user1" ] && [ $? -eq 0 ]; then
			printf "\e[31mThe home directory ($dir) of user $user1 is owned by $owner.\e[0m\n"
		else 
			printf "\e[32mPass\e[0m\n"
		fi
		done
	fi
done


printf "\n \033[0;30m${bold}7.18 Check for Duplicate UIDs${normal} \n\n"
printf "Checking for duplicate UIDs\n"
#Get etc/passwd file
cat /etc/passwd| cut -f3 -d":" | sort -n | uniq -c | while read x ; do
[ -z "${x}" ] && break
set - $x
if [ $1 -gt 1 ]; then
#Checks for duplicate UIDs
	users=`/bin/gawk -F: '($3 == n) { print $1 }' n=$2 /etc/passwd| /usr/bin/xargs`
	printf "\e[31mFail - Duplicate UID ($2)\e[0m\n"
	printf "Please run remediation"
else
	printf "\e[32mPass - UID ($2)\e[0m\n"
fi
done


printf "\n \033[0;30m${bold}7.19 Check for Duplicate GIDs${normal} \n\n"
printf "Checking for duplicate GIDs\n"
#Get etc/group file
cat /etc/group | cut -f3 -d":" | sort -n | uniq -c | while read x ; do
[ -z "${x}" ] && break
set - $x
if [ $1 -gt 1 ]; then
#Checks for duplicate GIDs
	grps=`/bin/gawk -F: '($3 == n) { print $1 }' n=$2 /etc/group | /usr/bin/xargs`
	printf "\e[31mFail - Duplicate GID ($2)\e[0m\n"
	printf "Please run remediation"
else
	printf "\e[32mPass - GID ($2)\e[0m\n"
fi
done


printf "\n \033[0;30m${bold}7.20 Check That Reserved UIDs Are Assigned to only System Accounts${normal} \n\n"
#All System Accounts
checkUsers="root bin daemon adm lp sync shutdown halt mail news uucp operator games gopher ftp nobody nscd vcsa rpc nscd vcsa rpc mailnull smmsp pcap ntp dbus avahi sshd rpcuser nfsnobody haldaemon avahi-autoipd distcache apache oprofile webalizer dovecot squid named xfs gdm sabayon usbmuxd rtkit abrt saslauth pulse postfix tcpdump"
#Checks that reserved UIDs are assigned to system accounts
cat /etc/passwd | awk -F : '($3 < 500) {print $1, $3}' | while read user uid; do found=0
for tUser in ${checkUsers}
	do
		if [ ${user} = ${tUser} ]; then
		found=1
		fi
	done
	if [ $found -eq 0 ]; then
	echo "User $user has a reserved UID ($uid)."
	fi
done


printf "\n \033[0;30m${bold}7.21 Check for Duplicate User Names${normal} \n\n"
#Get etc/passwd file
cat /etc/passwd | cut -f1 -d":" | /bin/sort -n | /usr/bin/uniq -c | while read x ; do
[ -z "${x}" ] && break
set - $x
#Checks for duplicate user names
if [ $1 -gt 1 ]; then
uids=`/bin/gawk -F: '($1 == n) { print $3 }' n=$2 \/etc/passwd | xargs`
printf "\e[31mFail - Duplicate User Name ($2)\e[0m\n"
printf "Please run remediation"
else
printf "\e[32mPass - ($2)\e[0m\n"
fi
done

printf "\n \033[0;30m${bold}7.22 Check for Duplicate Group Names${normal} \n\n"
#Get etc/group file
cat /etc/group | cut -f1 -d":" | /bin/sort -n | /usr/bin/uniq -c | while read x ; do
[ -z "${x}" ] && break
set - $x
#Checks for duplicate group names
if [ $1 -gt 1 ]; then
gids=`/bin/gawk -F: '($1 == n) { print $3 }' n=$2 /etc/group | xargs`
printf "\e[31mFail - Duplicate Group Name ($2)\e[0m\n"
printf "Please run remediation"
else 
printf "\e[32mPass - ($2)\e[0m\n"
fi
done


printf "\n \033[0;30m${bold}7.23 Check for Presence of User .forward Files${normal} \n\n"
#Get users then check for the presence of .forward files
for dir in `/bin/cat /etc/passwd| /bin/awk -F: '{ print $6 }'`; do
if [ ! -h "$dir/.forward" -a -f "$dir/.forward" ]; then
echo ".forward file $dir/.forward exists"
else 
printf "\e[32mPass - $dir\e[0m\n"
fi
done


printf "\n \033[0;30m${bold}8.1 Set Warning Banner for Standard Login Services${normal} \n\n"
#Set counter to 0 and cut user and group of /etc/motd, /etc/issue and /etc/issue.net
counter=0
motdper=$(ls -l /etc/motd | cut -d " " -f 3 )
motdper1=$(ls -l /etc/motd | cut -d " " -f 4 )
issueper=$(ls -l /etc/issue | cut -d " " -f 3 )
issueper1=$(ls -l /etc/issue | cut -d " " -f 4 )
issuenetper=$(ls -l /etc/issue.net | cut -d " " -f 3 )
issuenetper1=$(ls -l /etc/issue.net | cut -d " " -f 4 )
#Checks if all are set as root 
printf "Checking that /etc/motd /etc/issue /etc/issue.net have root as user and group:\n"
if [ "$motdper" == "root" ] && [ "$motdper1" == "root" ] && [ "$issueper" == "root" ] && [ "$issueper1" == "root" ] && [ "$issuenetper" == "root" ] && [ "$issuenetper1" == "root" ]
then 
	printf "\033[33;32m PASS \n"
else
	counter=$((counter+1))
	printf "\033[33;31m FAIL \n"

fi
echo  -en "\e[0m"
#chmod of the 3 files
chmodmotd=$( stat --format '%a' /etc/motd)
chmodissue=$( stat --format '%a' /etc/issue)
chmodissuenet=$( stat --format '%a' /etc/issue.net)
#Checks if all files' chmod equals 644
printf "Checking that /etc/motd /etc/issue /etc/issue.net have chmod of 644 :\n"
if [ "$chmodmotd" -eq 644 ] && [ "$chmodissue" -eq 644 ] && [ "$chmodissuenet" -eq 644 ]
then 
	printf "\033[33;32m PASS \n"
else	
	counter=$((counter+1))
	printf "\033[33;31m FAIL \n"
fi
echo  -en "\e[0m"
#Checks if correct banner is set in issue and issue.net
mp="Authorized uses only. All activity may be \ monitored and reported."
catissue=$(cat /etc/issue)
catissuenet=$(cat /etc/issue.net)
printf "Checking that /etc/issue /etc/issue.net have proper motd :\n"
if [ "$catissue" == "$mp" ] && [ "$catissuenet" == "$mp" ]
then
	printf "\033[33;32m PASS \n"
else
	counter=$((counter+1))
	printf "\033[33;31m FAIL \n"
fi
echo  -en "\e[0m"
#If counter more than 0 then fails
if [ $counter -gt 0 ]; then
	printf "\e[31mOverall Fail\e[0m\n"
	printf "Please run remediation\n"
else
	printf "\e[32mOverall Pass\e[0m\n"
fi


printf "\n \033[0;30m${bold}8.2 Remove OS information from Login Banners${normal} \n\n"
#Greps if match 3 files
issue=$(egrep '(\\v|\\r|\\m|\\s)' /etc/issue)
motd=$(egrep '(\\v|\\r|\\m|\\s)' /etc/motd)
issuenet=$(egrep '(\\v|\\r|\\m|\\s)' /etc/issue.net)
#Set regular expression and counter
regex='(\\v|\\r|\\m|\\s)'
counter=0
#echo $issue
#Checks if match regex
printf "Checking /etc/issue:\n"
if [[ $issue =~ $regex ]]
then 
	counter=$((counter+1))
	printf "\033[33;31m FAIL \n"
else
	printf "\033[33;32m PASS \n"
fi
echo  -en "\e[0m"
#echo $motd
#Checks if match regex
printf "Checking /etc/motd:\n"
if [[ $motd =~ $regex ]]
then 
	counter=$((counter+1))
	printf "\033[33;31m FAIL \n"
else
	printf "\033[33;32m PASS \n"

fi
echo  -en "\e[0m"
#echo $issuenet
#Checks if match regex
printf "Checking /etc/issue.net:\n"
if [[ $issuenet =~ $regex ]]
then 
	counter=$((counter+1))
	printf "\033[33;31m FAIL \n"
else
	printf "\033[33;32m PASS \n"
fi
echo  -en "\e[0m"
#echo $counter
#Checks if counter greater than 0
if [ $counter -gt 0 ]; then
	printf "\e[31mOverall Fail\e[0m\n"
	printf "Please run remediation\n"
else
	printf "\e[32mOverall Pass\e[0m\n"
fi

#END OF LAB 3B VERIFICATION
#START OF LAB 4B VERIFICATION

#9
clear
printf "Checking if Anacron is enabled \n"
if rpm -q cronie-anacron | grep "not installed" >/dev/null ; then # Check if anacron is installed or not
	printf "\033[33;32m FAIL \n"
else
	printf "\033[33;31m PASS \n"
fi

printf "\e[0m Checking if Cron is enabled \n"
if systemctl is-enabled crond | grep enabled >/dev/null; then #Use systemctl to check if cron is enabled
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if /etc/anacrontab file has the correct permissions \n"
if ls -l /etc/anacrontab | grep -e -rw------- >/dev/null; then # Grep the permissions from ls -l /etc/anacrontab to ensure permissions is correct and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if /etc/crontab file has the correct permissions \n"
if ls -ld /etc/crontab | grep -e -rw------- >/dev/null; then  # Grep the permissions from ls -ld /etc/crontab to ensure permissions is correct and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if /etc/cron.hourly file has the correct permissions \n"
if ls -ld /etc/cron.hourly | grep drwx------ >/dev/null; then # Grep the permissions from ls -l /etc/cron.hourly to ensure permissions is correct and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if /etc/cron.daily file has the correct permissions \n"
if ls -ld /etc/cron.daily | grep drwx------ >/dev/null; then # Grep the permissions from ls -ld /etc/cron.daily to ensure permissions is correct and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if /etc/cron.weekly file has the correct permissions \n"
if ls -ld /etc/cron.weekly | grep drwx------ >/dev/null; then  # Grep the permissions from ls -ld /etc/cron.weekly to ensure permissions is correct and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if /etc/cron.monthly file has the correct permissions \n"
if ls -ld /etc/cron.monthly | grep drwx------ >/dev/null; then # Grep the permissions from ls -ld /etc/cron.monthly to ensure permissions is correct and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if /etc/cron.d directory has the correct permissions \n"
if ls -ld /etc/cron.d | grep drwx------ >/dev/null; then # Grep the permissions from ls -ld /etc/cron.d to ensure permissions is correct and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if at jobs are restricted \n"
if stat -L -c "%a %u %g" /etc/at.allow | egrep ".00 0 0" >/dev/null; then #Issing this command with an output shows that the system is configured correctly
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if cron is restricted to Authorized Users \n"
if ls -l /etc/cron.allow | grep -e -rw------- >/dev/null; then # Grep the permissions from ls -l /etc/cron.allow to ensure permissions is correct and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if at is restricted to Authorized Users \n"
if ls -l /etc/at.allow | grep -e -rw------- >/dev/null; then # Grep the permissions from ls -l /etc/at.allow to ensure permissions is correct and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

#10

printf "\e[0m Checking if the SSH protocol is correct:  \n"
if grep "^Protocol 2" /etc/ssh/sshd_config > /dev/null; then # Grep "Protocol 2" to ensure settings is correct and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if the SSH loglevel is correct:  \n"
if grep "^LogLevel INFO" /etc/ssh/sshd_config > /dev/null; then # Grep "LogLevel INFO" to ensure settings is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n"
else
        printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking the SSH permissions:  \n"
if /bin/ls -l  /etc/ssh/sshd_config | grep -e "-rw-------. 1 root root" > /dev/null ; then # Grep the permissions from ls -l /etc/ssh/sshd_config to ensure permissions is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n"
else
        printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if X11Forwarding is disabled:  \n"
if grep "^X11Forwarding no" /etc/ssh/sshd_config > /dev/null; then # Grep "X11Forwarding no" to ensure settings is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n"
else
        printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if the MaxAuthTries is correct:  \n"
if grep "^MaxAuthTries 4" /etc/ssh/sshd_config > /dev/null; then # Grep "MaxAuthTries 4" to ensure settings is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n"
else
        printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if IgnoreRhosts is enabled:  \n"
if grep "^IgnoreRhosts yes" /etc/ssh/sshd_config > /dev/null; then # Grep "IgnoreRhosts yes" to ensure settings is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n"
else
        printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if HostbasedAuthentication is disabled:  \n"
if grep "^HostbasedAuthentication no" /etc/ssh/sshd_config > /dev/null; then # Grep "HostbasedAuthentication no" to ensure settings is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n" 
else
        printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if PermitRootLogin is disabled:  \n"
if grep "^PermitRootLogin no" /etc/ssh/sshd_config > /dev/null; then # Grep "PermitRootLogin no" to ensure settings is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n"
else
        printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if PermitEmptyPasswords is disabled:  \n"
if grep "^PermitEmptyPasswords no" /etc/ssh/sshd_config > /dev/null; then # Grep "PermitEmptyPasswords no" to ensure settings is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n"
else
        printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if the Approved Cipers is correct:  \n"
if grep "^Ciphers aes128-ctr,aes192-ctr,aes256-ctr" /etc/ssh/sshd_config > /dev/null; then # Grep "Ciphers aes128-ctr,aes192-ctr,aes256-ctr" to ensure settings is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n"
else
        printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if ClientAliveInterval is correct:  \n"
if grep "^ClientAliveInterval 300" /etc/ssh/sshd_config > /dev/null; then # Grep "ClientAliveInterval 300" to ensure settings is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n"
else
        printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking if ClientAliveCountMax is correct:  \n"
if grep "^ClientAliveCountMax 0" /etc/ssh/sshd_config > /dev/null; then # Grep "ClientAliveCountMax 0" to ensure settings is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n"
else
        printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking the Allowed Users:  \n \033[33;32m"
if grep "^AllowUsers[[:space:]]" /etc/ssh/sshd_config > /dev/null; then # Grep "AllowUsers[[:space:]]" to check if there are any users and remove the output with "/dev/null"
	grep "^AllowUsers" /etc/ssh/sshd_config | sed -n -e 's/^.*AllowUsers //p'
else
        printf "\033[33;31m Empty \n"
fi

printf "\e[0m Checking the Allowed Groups:  \n \033[33;32m"
if grep "^AllowGroups[[:space:]]" /etc/ssh/sshd_config > /dev/null; then # Grep "AllowGroups[[:space:]]" to check if there are any groups and remove the output with "/dev/null"
	grep "^AllowGroups" /etc/ssh/sshd_config | sed -n -e 's/^.*AllowGroups //p'
else
        printf "\033[33;31m Empty \n"
fi

printf "\e[0m Checking the Denied Users:  \n \033[33;32m"
if grep "^DenyUsers[[:space:]]" /etc/ssh/sshd_config > /dev/null; then # Grep "DenyUsers[[:space:]]" to check if there are any users and remove the output with "/dev/null"
	grep "^DenyUsers" /etc/ssh/sshd_config | sed -n -e 's/^.*DenyUsers //p'
else
        printf "\033[33;31m Empty \n"
fi

printf "\e[0m Checking the Denied Groups:  \n \033[33;32m"
if grep "^DenyGroups[[:space:]]" /etc/ssh/sshd_config > /dev/null; then # Grep "DenyGroups[[:space:]]" to check if there are any groups and remove the output with "/dev/null"
	grep "^DenyGroups" /etc/ssh/sshd_config | sed -n -e 's/^.*DenyGroups //p'
else
        printf "\033[33;31m Empty \n"
fi

printf "\e[0m Checking if SSH Banner is correct:  \n"
if grep "^Banner" /etc/ssh/sshd_config > /dev/null ; then # Grep "Banner" to ensure settings is correct and remove the output with "/dev/null"
        printf "\033[33;32m PASS \n"
else
        printf "\033[33;31m FAIL \n"
fi

#11

printf "\e[0m Checking if password-hashing algorithm is set to SHA-512 \n "
if authconfig --test | grep hashing | grep sha512 >/dev/null; then
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi



printf "\e[0m Determine the current settings in /etc/pam.d/systemauth \n "
if grep pam_pwquality.so /etc/pam.d/system-auth >/dev/null; then # Grep "pam_pwquality.so" to ensure settings is correct and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi



printf "\e[0m Settings in /etc/security/pwquality.conf \n "

printf "\e[0m Checking minlen \n"
if cat /etc/security/pwquality.conf | grep "^minlen = 14" > /dev/null; then # Grep "minlen = 14" from /etc/security/pwquality.conf and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking dcredit \n"
if cat /etc/security/pwquality.conf | grep "^dcredit = -1" >/dev/null; then # Grep "dcredit = -1" from /etc/security/pwquality.conf and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking ucredit \n"
if cat /etc/security/pwquality.conf | grep "^ucredit = -1" >/dev/null; then # Grep "ucredit = -1" from /etc/security/pwquality.conf and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking ocredit \n"
if cat /etc/security/pwquality.conf | grep "ocredit = -1" >/dev/null; then # Grep "ocredit = -1" from /etc/security/pwquality.conf and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Checking lcredit \n"
if cat /etc/security/pwquality.conf | grep "lcredit = -1" >/dev/null; then # Grep "lcredit = -1" from /etc/security/pwquality.conf and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi


printf "\e[0m Determine the current settings in userID lockout \n "
printf "\e[0m Password-auth \n"
if grep pam_faillock /etc/pam.d/password-auth > /dev/null; then # Grep "pam_faillock" from /etc/pam.d/password-auth and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m System-auth \n"
if grep pam_faillock /etc/pam.d/system-auth > /dev/null; then # Grep "pam_faillock" from /etc/pam.d/system-auth and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi

printf "\e[0m Determine the current settings for reusing of older passwords \n "
if grep "remember=5" /etc/pam.d/system-auth >/dev/null; then # Grep "remember=5" from /etc/pam.d/system-auth and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi


printf "\e[0m Determine if restriction of login to system console is configured correctly \n "
if ls -ld /etc/securetty| cut -d " " -f 5 | grep 0 > /dev/null; then
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi
	


printf "\e[0m \n Restrict Access to the su command \n "

if cat /etc/pam.d/su | grep "^auth		required	pam_wheel.so use_uid" > /dev/null; then # Grep "auth		required	pam_wheel.so use_uid" from /etc/pam.d/su and remove the output with "/dev/null"
	printf "\033[33;32m PASS \n"
else
	printf "\033[33;31m FAIL \n"
fi
printf "\e[0m Users that are allowed to issue su command: \n "
echo -en "\033[33;31m" > /dev/null
cat /etc/group | grep wheel | cut -d : -f 4 #Grep "wheel" from /etc/group and cut out the 4th field 

echo -en "\e[0m" #reverts the text color to black

#END OF 4B VERIFICATION
printf "\e[32mScan completed!\n"
printf "Press any key to exit\e[0m\n"
read -n 1 -s
kill -9 $PPID
#END OF ENTIRE SCRIPT!#