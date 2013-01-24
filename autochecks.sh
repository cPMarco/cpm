# Auto-checks by cPanel Marco
# These are some quick checks for a variety of settings and configurations
# No configuration files are changed or saved in this script

# Establish colors (White for heading, red for errors)
white="\E[37;44m\033[7m";
clroff="\033[0m";
red="\E[37;41m\033[4m";

echo -e $white"Some quick checks by cPanel Analyst:"$clroff;

h=`hostname -i`;
PROMPT_COMMAND='echo -ne "\033]0;${h}: ${PWD}\007"' ;

export PS1="[\[\e[4;32m\]\u@\h \w\[\e[0m\]]# ";

hn=`hostname`. ;
hip=`dig +short $hn`;
if [ "$hip" ];
 then hrip=`dig +short -x $hip`;
 if [ "$hn" == "$hrip" ];
  then echo ;
  else echo -e $red"Reverse DNS: "$clroff$hn" != "$hrip;
 fi;
 else echo -e $red"Hostname not resolvable"$clroff;
fi;

echo -ne $white$hn": "$h"\n"$clroff;
/usr/local/cpanel/cpanel -V;

# Look for Cloudlinux
lsmod|grep lve;
uname -a|grep -o lve;
echo;

cat /proc/loadavg;
echo -ne "\nEnvironment: ";
strings -1 /var/cpanel/envtype;
if [ -e /proc/user_beancounters ];
 then vzerr=$(awk 'NR>2{if($1~/[0-9]/&&$7>0)print$2" failcnt "$7; else if($1!~/[0-9]/&&$6>0)print$1" failcnt "$6}' /proc/user_beancounters;);
 echo -e $red$vzerr$clroff;
fi;
echo;
\ls -l /usr/bin/perl /usr/local/bin/perl ;

echo -ne "\n\nSELinux: ";
if [ -e /etc/selinux/config ];
 then grep ^SELINUX /etc/selinux/config|cut -d"=" -f2;
 else echo "none";
fi;
ps -ef | grep gd[m];

echo -e "\nCluster Function, Status:";
if [ -e /var/cpanel/cluster/root/config ];
 then cl='/var/cpanel/cluster/root/config';
 for i in `\ls $cl | grep dnsrole`;
  do echo -n $i": ";
  cat $cl/$i;
  clip=/var/cpanel/clusterqueue/status/$(echo $i|cut -d"-" -f1);
  echo -n ", status: ";
  if [ -e $clip ];
   then cat $clip;
   else echo NA;
  fi;
 done;
 else echo "no cluster files";
fi;
echo;

w; echo;
dfi=$(df -i|awk 'split($5,a,"%") {if(a[1]~/[0-9]/ && a[1]>85) print}');
dff=$(df -ah|awk 'split($5,a,"%") {if(a[1]~/[0-9]/ && a[1]>85) print}');
if [ "$dff" -o "$dfi" ];
 then echo -e $red$dff"\nInodes:\n"$dfi$clroff;
fi;
echo;

lsattr -ld /;
dmesg | egrep -i "failed|timed out|[^c]hang|BAD|SeekComplete Error|DriveStatusError|UncorrectableError" | uniq ;

echo "Segfaults in messages:";
tail -1000 /var/log/messages|egrep -i "segfault|I/O error"|uniq;

echo -e "\n\nDisable Files:";
\ls /etc|grep --color disable|egrep -v "entropy|interch";

hta=$(\ls / /home | grep htaccess);
echo -e $red$hta$clroff;

# Checkservd log
# https://staffwiki.cpanel.net/LinuxSupport/OneLiners#Show_chksrvd_failures
echo -e "\nRecent chksrvd errors:";
every_n_min=10; tail -3200 /var/log/chkservd.log |awk -v n=$every_n_min '{if ($1~/\[20/) lastdate=$1" "$2" "$3; split($2,curdate,":"); dmin=(curdate[2]-lastmin); dhr=(curdate[1]-lasthr); if ($0!~/Restarting|nable|\*\*|imeout|ailure|terrupt/ && $0~/:-]/) print lastdate"....."; for (i=1;i<=NF;i=i+1) if ($i~/Restarting|nable|\*\*|imeout|ailure|terrupt|100%|9[89]%|second/) if ($1~/\[20/) print $1,$2,$3,$(i-1),$i,$(i+1); else print lastdate,$(i-1),$i,$(i+1); if($1~/\[20/ && (lastmin!=0 || lasthr!=0) && (dmin>n || (dhr==1 && (dmin>-(60-n))) || dhr>1 )) print $1,$2,$3" check took longer than "n" minutes. (hr:min): "dhr":"dmin; if ($1~/\[20/) {lastmin=curdate[2]; lasthr=curdate[1]} }'

a='/usr/local/apache';
conf=$a/conf/httpd.conf;
c='/usr/local/cpanel';
ea='/usr/local/cpanel/logs/easy/apache';
# hn=$(hostname);

alias lf='echo `\ls -lrt|tail -1|awk "{print \\$9}"`';
alias lf2='echo `\ls -lrt|tail -2|awk "{print \\$9}"|head -1`';
alias ifm='ifconfig |egrep -o "venet...|lo|eth[^ ]*|ppp|:(.{1,3}\.){3}.{1,3}"|grep -v 255|uniq';
alias ips=$(ifconfig|grep inet|awk '{if ($2!~"127.0"&&$2!~":$") print $2}'|cut -d":" -f2|awk '{print "echo "$0}');
alias localips='ips';
alias ssl='openssl x509 -noout -text -in';
alias mysqlerr='date; echo /var/lib/mysql/$hn.err; less -I /var/lib/mysql/$hn.err';
function efind() { find "$1" -regextype egrep -regex "$2" ; } ;
alias lsp='ls -d -1 $PWD/**';

# Temporary checks
echo;
unamefail=`egrep "^USER" /var/cpanel/users/* | egrep "/.*\..*"`;
echo -e $red$unamefail$clroff;

# I should add this to chksrvd, as I found it on 130123 in 3665403
spamd_fail_chksrvd=$(tail -1200 /var/log/chkservd.log |grep 'spamd \[Service' |awk '{print $1,$2,$3}');
if [ spamd_fail_chksrvd ];
 then echo -e $red"Spamd error in chksrvd:"$clroff"\n"$spamd_fail_chksrvd;
fi;

rooterror=$(tail -1000 /usr/local/cpanel/logs/error_log|egrep "Illegal instruction|root' is empty or non-existent"|egrep "2012-0[89]");
echo -e $red$rooterror$clroff;

egrep -i "Illegal instruction|Undefined subroutine" /var/cpanel/updatelogs/*
egrep -i "Illegal instruction|Undefined subroutine" /usr/local/cpanel/logs/easy/apache/*
badrepo=$(egrep "alt\.ru|ksplice-up" /etc/yum.repos.d/*);
echo -e $red$badrepo$clroff;

cd /usr/local/cpanel/logs/cpbackup;
lf | xargs grep EOF | tail -3;
cd ~;

cd $ea;
eafail1=$(for i in $(\ls); do tail -3 $i; done | grep -i "Failed");
cd ~;
if [ "$eafail1" ];
 then echo -e $red$eafail1$clroff;
 ls -la /bin/egrep;
fi #FB 60087

rcbug=$(ps auxfwww | grep template.sto[r]);
echo -e $red$rcbug$clroff; #FB62001