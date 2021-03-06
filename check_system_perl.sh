#/bin/sh
# bash script to verify system perl location is correct
# does not work for cpanel perl rpm yet
# only designed for supported server OS's
# http://staffwiki.cpanel.net/LinuxSupport/PerlIssues

# Colors and formatting
green='\033[0;32m'
greenbold='\033[1;32m'
red='\033[0;31m'
redbold='\033[1;31m'
clroff="\033[0m";

printf "\nNote: This is for pre-11.36 only\n"

# Print out the ls of all the perls
printf "\nHere are the common perl binary paths.  This can be copy/pasted to document the system:"
printf "%b\n" "${greenbold}\n# \ls -l /usr/bin/perl /usr/local/bin/perl /usr/local/cpanel/3rdparty/bin/perl ${clroff}"
\ls -l /usr/bin/perl /usr/local/bin/perl /usr/local/cpanel/3rdparty/bin/perl ;

serverenv=$(strings -1 /var/cpanel/envtype)

printf "\ncPanel claims this server is a ${greenbold}*$serverenv*${clroff} server, so we'll test it as such.\n\n"


# set the two link vars.  if they are links, these vars will be full

ubp="$(readlink /usr/bin/perl)"
ulbp="$(readlink /usr/local/bin/perl)"
verdict=1

if [ "$serverenv" = "standard" ]; then

 if [ $ubp ]; then
  printf "/usr/bin/perl is a link to $ubp. This is not correct. Just to check, here it is:";
  printf "%b\n" "${red}\n# ls -la /usr/bin/perl ${clroff}";
  \ls -la /usr/bin/perl;
  verdict=2;
 fi
 
 if [ ! $ulbp ]; then
  printf "\n/usr/local/bin/perl is not a link. This is not correct. Just to check, here it is:";
  printf "%b\n" "${red}\n# ls -la /usr/local/bin/perl ${clroff}";
  \ls -la /usr/local/bin/perl;
  verdict=2;
 fi
 
 if [[ ! $(perl -v | grep thread) ]];
  then printf "\nSystem perl is not threaded.  This is not correct. Just to check, here it is:";
  printf "%b\n" "${red}\n# /usr/bin/perl -v | grep built ${clroff}";
  \/usr/bin/perl -v | grep built;
  verdict=2;
 fi

elif [ "$serverenv" ]; then

 if [ ! $ubp ]; then
  printf "\n/usr/bin/perl is not a link. This is not correct.  Just to check, here it is:";
  printf "%b\n" "${red}\n# ls -la /usr/bin/perl ${clroff}";
  \ls -la /usr/bin/perl;
  verdict=2;
 fi
 
 if [ $ulbp ]; then
  printf "\n/usr/local/bin/perl is a link. This is not correct. Just to check, here it is:";
  printf "%b\n" "${red}\n# ls -la /usr/local/bin/perl ${clroff}";
  \ls -la /usr/local/bin/perl;
  verdict=2;
 fi
 
 if [[ $(perl -v | grep thread) ]]; then
  printf "System perl is threaded.  This is not correct. Just to check, here it is:";
  printf "%b\n" "${red}\n# /usr/bin/perl -v | grep built ${clroff}";
  \/usr/bin/perl -v | grep built;
  verdict=2;
 fi

else

 printf "There was a problem determining server environment.  You can try installing & running 'virt-what'.  Also, please let Marco know.\n"
 verdict=2;

fi

if [ $verdict == 1 ]; then
 printf "\n%b\n" "${greenbold}PASS${clroff}: The system perl appears to be set correctly.\n";
else
 printf "\n%b\n" "${redbold}FAIL${clroff}: The system perl appears incorrect.\n"
fi

