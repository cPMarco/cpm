#!/usr/bin/perl
# SSP - System Status Probe
# Find and print useful troubleshooting info on cPanel servers

use strict;
use warnings;
use File::Find;
use IO::Socket::INET;
use Sys::Hostname;
use Term::ANSIColor qw(:constants);
use Storable;
use POSIX;
use Time::Local;

if ( $< != 0 ) {
    die "SSP must be run as root\n";
}

$ENV{'PATH'} = '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin';

my $version = '4.10';

$| = 1;
$Term::ANSIColor::AUTORESET = 1;

######################
##  BEGIN GLOBALS   ##
######################

my $hostname                    = hostname();
my $os                          = get_os();
my $TIERS                       = get_tiers_file();
my @local_ipaddrs_list          = get_local_ipaddrs();
my @process_list                = get_process_list();
my %hostinfo                    = get_hostinfo();
my %cpuinfo                     = get_cpuinfo();
my $mysql_datadir               = get_mysql_datadir();
my $mysql_error_log             = get_mysql_error_log();
my @apache_version_output       = split /\n/, run( '/usr/local/apache/bin/httpd', '-v' );
my @apache_modules_output       = split /\n/, run( '/usr/local/apache/bin/httpd', '-M' );
my @mysql_rpm_versions;         # certain installed rpms that begin with MySQL- (e.g., MySQL-server, etc)
my @custom_opt_mods;            # items in /var/cpanel/easy/apache/custom_opt_mods/
my @usr_local_cpanel_hooks;     # items in /usr/local/cpanel/hooks/
my @easyapache_templates;       # items in /var/cpanel/easy/apache/profile/
my @rpm_list;                   # rpm -qa

######################
##  END GLOBALS     ##
######################


## [INFO]
print "\n";
check_for_dnsonly();
print_tip();
print_version();
print_hostname();
print_os();
print_kernel_and_cpu();
print_cpanel_info();
check_for_cpanel_update();
print_uptime();
check_for_clustering();
print_apache_info();
print_php_configuration();
check_sysinfo();
check_for_remote_mysql();
print_if_using_mydns_or_nsd();
print_if_using_modruid2();
print_which_php_is_used_internally();

## [WARN]
print "\n";
check_selinux_status();
check_runlevel();
check_for_missing_root_cron();
check_if_upcp_is_running();
check_valid_upcp();
check_for_sandy_bridge();
check_interface_lo();
check_cpanelconfig_filetype();
check_for_cpanelsync_exclude();
check_for_lve_environment();
check_for_rawopts();
check_for_rawenv();
check_for_custom_opt_mods();
check_for_local_apache_templates();
check_for_local_makecpphp_template();
check_for_custom_apache_includes();
check_for_tomcatoptions();
check_for_sneaky_htaccess();
check_perl_sanity();
check_for_non_default_permissions();
check_awstats_permissions();
check_var_cpanel_users_files_ownership();
check_root_suspended();
check_limitsconf();
check_disk_space();
check_disk_inodes();
check_for_hooks_in_scripts_directory();
check_for_huge_apache_logs();
check_easy_skip_cpanelsync();
check_pkgacct_override();
check_for_gdm();
check_for_redhat_firewall();
check_easyapache();
check_for_easyapache_hooks();
check_for_home_noexec();
check_for_nat();
check_for_oracle_linux();
check_for_usr_local_cpanel_hooks();
check_for_sql_safe_mode();
check_mysql_non_default_datadir();
check_for_domain_forwarding();
check_for_empty_apache_templates();
check_for_empty_postgres_config();
check_for_empty_easyapache_profiles();
check_for_missing_timezone_from_phpini();
check_for_proc_mdstat_recovery();
check_usr_local_cpanel_path_for_symlinks();
check_for_system_mem_below_512M();
check_for_options_rotate_redhat_centos_63();
check_pecl_phpini_location();
check_for_empty_yumconf();
check_for_cpanel_files();
check_bash_history_for_certain_commands();
check_wwwacctconf_for_incorrect_minuid();
check_roots_cron_for_certain_commands();
check_for_missing_or_commented_customlog();
check_for_cpsources_conf();
check_for_apache_rlimits();
check_cron_processes();
check_for_usr_local_lib_libz_so();
check_for_non_default_modsec_rules();
check_etc_hosts_sanity();
check_for_empty_or_missing_files();
check_for_apache_listen_host_is_localhost();
check_roundcube_mysql_pass_mismatch();
check_for_kernel_headers_rpm();
check_for_extra_uid0_pwcache_file();
check_for_11_30_scripts_not_a_symlink();
check_for_cpanel_not_updating();
check_for_hooks_from_var_cpanel_hooks_yaml();
check_for_non_default_mysql_error_log_location();
check_for_C_compiler_optimization();
check_perl_version_less_than_588();
check_for_low_ulimit_for_root();
check_for_fork_bomb_protection();
#check_for_cpphpopts();
check_for_cPanel_lower_than_11_30_7_3();
check_for_custom_exim_conf_local();
check_for_maxclients_reached();
check_for_non_default_umask();
check_for_multiple_imagemagick_installs();
check_for_custom_locales();
check_eximstats_size();
check_eximstats_corrupt();
check_for_clock_skew();
check_for_zlib_h();
check_if_httpdconf_ipaddrs_exist();
check_distcache_and_libapr();
check_for_mainip_newline();
check_for_custom_postgres_repo();
check_for_rpm_overrides();
check_for_odd_yum_conf();
check_var_cpanel_immutable_files();
check_for_hordepass_newline();
check_for_noxsave_in_grub_conf();
check_for_cpanel_CN_newline();
check_for_my_cnf_skip_name_resolve();
check_for_my_cnf_sql_mode();

# [3RDP]
print "\n";
check_for_assp();
check_for_varnish();
check_for_litespeed();
check_for_nginx();
check_for_mailscanner();
check_for_apf();
check_for_csf();
check_for_prm();
check_for_les();
check_for_1h();
check_for_webmin();
check_for_symantec();


# This is run closer to the end since it has the potential to take the longest
print "\n";
build_rpm_list();

# These require build_rpm_list() to have been run, so that @rpm_list is populated
populate_mysql_rpm_versions_array();
check_for_mysql_4();
check_for_additional_rpms();
check_mysql_rpm_mismatch();
check_php_libmysqlclient_mismatch();
check_for_percona_rpms();

# All checks for DNSONLY go here
sub check_for_dnsonly {
    if ( -e '/var/cpanel/dnsonly' ) {

        print_version();
        print_start( "\t\tDNSONLY: " );
        print_warning( "/var/cpanel/dnsonly detected, assuming DNSONLY\n" );

        ## [INFO]
        print_hostname();
        print_os();
        print_kernel_and_cpu();
        print_cpanel_info();
        check_for_cpanel_update();
        print_uptime();
        check_for_clustering();
        check_sysinfo();

        ## [WARN]
        check_selinux_status();
        check_runlevel();
        check_for_missing_root_cron();
        check_if_upcp_is_running();
        check_for_sandy_bridge();
        check_interface_lo();
        check_cpanelconfig_filetype();
        check_for_cpanelsync_exclude();
        check_for_lve_environment();
        check_perl_sanity();
        check_for_non_default_permissions();
        check_limitsconf();
        check_disk_space();
        check_disk_inodes();
        check_for_gdm();
        check_for_redhat_firewall();
        check_for_home_noexec();
        check_for_nat();
        check_for_oracle_linux();
        check_for_proc_mdstat_recovery();
        check_usr_local_cpanel_path_for_symlinks();
        check_for_system_mem_below_512M();
        check_for_options_rotate_redhat_centos_63();
        check_for_empty_yumconf();
        check_for_cpanel_files();
        check_bash_history_for_certain_commands();
        check_roots_cron_for_certain_commands();
        # check_for_cpsources_conf();       // does this exist on DNSONLY by default?
        check_cron_processes();
        check_etc_hosts_sanity();
        check_for_missing_limits_h();
        check_for_C_compiler_optimization();
        check_perl_version_less_than_588();
        check_for_fork_bomb_protection();
        check_for_cPanel_lower_than_11_30_7_3();
        check_for_non_default_umask();
        check_for_clock_skew();
        check_for_percona_rpms();
        check_for_mainip_newline();
        check_for_rpm_overrides();
        check_var_cpanel_immutable_files();
        check_for_hordepass_newline();
        check_for_noxsave_in_grub_conf();
        check_for_cpanel_CN_newline();

        ## [3RDP]
        check_for_apf();
        check_for_csf();
        check_for_prm();
        check_for_les();
        check_for_1h();
        check_for_webmin();
        check_for_symantec();
        
        exit;
    }
}

# shameless rip of /usr/local/cpanel/Cpanel/SafeRun/Simple.pm which, along with
# all other current cPanel modules, is not guaranteed to work with 11.35+ apparently.
# so, we take what we need and put it here
sub run {
    my $cmdline = \@_;
    my $output;

    local ($/);
    my ( $pid, $prog_fh );

    open STDERR, '>', '/dev/null';
    if ( $pid = open( $prog_fh, '-|' ) ) { 

    }   
    else {
        ( $ENV{'PATH'} ) = $ENV{'PATH'} =~ m/(.*)/;    # untaint, FB 6622
        exec(@$cmdline);
        exit(127);
    }
    close STDERR;

    if ( !$prog_fh || !$pid ) { 
        $? = -1; 

        return \$output;
    }   
    $output = readline($prog_fh);
    close($prog_fh);

    return $output;
}

sub get_local_ipaddrs {
    my @ifconfig = split /\n/, run( 'ifconfig', '-a' );
    for my $line ( @ifconfig ) {
        if ( $line =~ m{ (\d+\.\d+\.\d+\.\d+) }xms ) {
            my $ipaddr = $1;
            unless ( $ipaddr =~ m{ \A 127\. }xms ) {
                push @local_ipaddrs_list, $ipaddr;
            }
        }
    }

    return @local_ipaddrs_list;
}

sub get_os {
    chomp( my $os = lc run( 'uname' ) );
    return $os;
}

# ripped from /usr/local/cpanel/Cpanel/Sys/OS.pm
sub get_release_version {
    my $ises = 0;
    my $version;

    if ( open my $fh, '<', '/etc/redhat-release' ) { 
        my $line = readline $fh;
        close $fh;
        chomp $line;
        if    ( $line =~ m/(?:Corporate|Advanced\sServer|Enterprise)/i ) { $ises    = 1; }
        elsif ( $line =~ /CloudLinux|CentOS/i )                          { $ises    = 2; }
        elsif ( $line =~ /WhiteBox/i )                                   { $ises    = 3; }
        elsif ( $line =~ /caos/i )                                       { $ises    = 4; }
        if    ( $line =~ /(\d+\.\d+)/ )                                  { $version = $1; }
        elsif ( $line =~ /(\d+)/ )                                       { $version = $1; }
    }

    if ( $os =~ /freebsd/i ) {
        if ( ( POSIX::uname()) [2] =~ m/^(\d+\.\d+)/ ) {
           $version = $1;
        }    
    }

    if ( $ises ) {
        return ( $version, $ises );
    }
    else {
        return ( $version, 0 ); 
    }
}

sub print_version {
    print BOLD YELLOW ON_BLACK "\tSSP $version (use ssp.cptechs.info/ssp.previous for previous version)\n\n";
}

sub print_tip {
    my @tips = (
        "[FB 63193] File Manager showing 'Out of memory' in cPanel error_log? Try renaming \$HOME/\$USER/.cpanel/datastore/SYSTEMMIME",
        "[FB 62819] 'License File Expired: LTD: 1334782495 NOW: 1246416504 FUT!' likely just means the server clock is wrong",
        "[FB 62054] (By design) The 'Dedicated IP' box can only be modified when creating a package - not when editing",
        "[FB 61735] (By design) '/u/l/c/whostmgr/bin/whostmgr2 --updatetweaksettings' destroys custom proxy subdomain records. Use WHM >> Tweak Settings instead.",
        "[FB 58625] Apache 2.0.x links to the wrong PCRE libs. This can cause preg_match*() errors, and 'PCRE is not compiled with UTF-8 support'",
        "[FB 50745] (By design) The cPanel UI displays differently (more columns than rows) when changing your locale",
        "[FB 44884] upcp resets Mailman lists' hostnames. pre/postupcp hooks workaround in ticket 3541643",
        "[FB 43944] layer1/layer2.cpanel.net is deprecated. The correct location is httpupdate.cpanel.net",
        "mod_userdir URLs (/~username) are not compatible with FCGI when Apache's suexec is enabled (cP Docs: tinyurl.com/bbd8fn2)",
        "For a list of obscure issues, see the RareIssues wiki article",
        "11.35+: Use /scripts/check_cpanel_rpms to fix problems in /usr/local/cpanel/3rdparty/  - not checkperlmodules",
        "php.ini for phpMyAdmin, phpPgAdmin, Horde, and RoundCube can be found in /usr/local/cpanel/3rdparty/etc/",
        "If Dovecot/POP/IMAP dies every day around the same time, the server's clock could be skewed. Check /var/log/maillog for 'moved backwards'",
        "'Allowed memory size of x bytes exhausted' when uploading a db via phpMyAdmin may be resolved by increasing max_allowed_packet",
        "Need to edit php.ini for Horde, RoundCube, phpMyAdmin, or phpPgAdmin? Edit /u/l/c/3rdparty/etc/php.ini, then run /u/l/c/b/install_php_inis",
        "Seeing 'domainadmin' errors (e.g. 'domainadmin-domainexistsglobal')? Check the Domainadmin-Errors wiki article",
        "Transfers showing 'sshcmdpermissiondeny'? Check for modified openssh-clients package (see ticket 3664533)",
        "Learn how cPanel 11.36+ handles rpms: http://go.cpanel.net/rpmversions",
        "Learn what's new in 11.36: http://docs.cpanel.net/twiki/bin/vief/AllDocumentation/1136ReleaseNotes",
    );   

    my $size = scalar @tips;
    my $num = int rand $size;

    print BOLD WHITE ON_BLACK "\tDid you know? ";
    print BOLD WHITE ON_BLACK "$tips[$num]\n\n";
}

sub get_tiers_file {
    local $SIG{'ALRM'} = sub { return(); };
    alarm 5;

    my $sock = IO::Socket::INET->new(
        PeerAddr    => 'httpupdate.cpanel.net',
        PeerPort    => '80',
        Proto       => 'tcp',
        Timeout     => 3,
    );

    if ( $sock ) {
        print $sock "GET /cpanelsync/TIERS HTTP/1.1\r\nHost: httpupdate.cpanel.net\r\n\r\n";
        sysread $sock, $TIERS, 1000;
        close $sock;
    }

    alarm 0;

    return $TIERS;
}

sub get_process_list {

    ## used for checking for nginx, litespeed, mailscanner, etc. 
    ## better (?) would be to run lsof and check process names on listening ports.

    my @process_list;
    my $process_list;

    if ( $os eq 'linux' ) {
        @process_list = split /\n/, run( 'ps', 'axwwwf', '-o', 'user,cmd' );
    }
    elsif ( $os eq 'freebsd' ) {
        @process_list = split /\n/, run( 'ps', 'axwwwf', '-o', 'user,comm' );
    }

    return @process_list;
}

sub get_hostinfo {
    my %hostinfo;

    $hostinfo{'kernel'}         = run( 'uname', '-r' );
    $hostinfo{'hardware'}       = run( 'uname', '-i' );
    $hostinfo{'environment'}    = get_environment();

    chomp %hostinfo;
    return %hostinfo;
}

sub get_environment {
    if ( open my $envtype_fh, '<', '/var/cpanel/envtype' ) {
        my $envtype = readline( $envtype_fh );
        close $envtype_fh;
        return $envtype;
    }    
    else {
        return 'Unknown (could not open/read /var/cpanel/envtype ?)';
    }    
}

sub get_cpuinfo {
    my %cpuinfo;

    if ( $os eq 'freebsd' ) {
        my $numcores = run( 'sysctl', 'hw.ncpu' );
        my $model = run( 'sysctl', 'hw.model' );
        $numcores =~ s/^hw.ncpu://g;
        $model =~ s/^hw.model://g;
        $model =~ s/\s+/ /g;
        $cpuinfo{'numcores'} = $numcores;
        $cpuinfo{'model'} = $model;
    }
    else {
        open my $cpuinfo_fh, '<', '/proc/cpuinfo';
        for my $line ( readline $cpuinfo_fh ) {
            if ( $line =~ /^model name/m ) {
                $line =~ s/^model name\s+:\s+//;
                $line =~ s/\(R\)//g;
                $line =~ s/\(tm\)//g;
                $line =~ s/\s{2,}/ /;
                $line =~ s/ \@/\@/;
                $cpuinfo{'model'} = $line;
                $cpuinfo{'numcores'}++;
            }
            if ( $line =~ /^cpu MHz/m ) {
                $line =~ s/^cpu MHz\s+:\s+//;
                $cpuinfo{'mhz'} = $line;
            }
        }    
        close $cpuinfo_fh;
    }

    chomp %cpuinfo;
    return %cpuinfo;
}

sub print_info {
    my $text = shift;
    print BOLD YELLOW ON_BLACK "[INFO] * $text";
}
sub print_warn {
    my $text = shift;
    print BOLD RED ON_BLACK "[WARN] * $text";
}
sub print_3rdp {
    my $text = shift;
    print BOLD GREEN ON_BLACK "[3RDP] * $text";
}
sub print_3rdp2 {
    my $text = shift;
    print BOLD GREEN ON_BLACK "$text\n";
}

## precedes informational items (e.g., "Hostname:")
sub print_start {
    my $text = shift;
    print BOLD YELLOW ON_BLACK $text;
}
## for informational items (e.g., the server's hostname)
sub print_normal {
    my $text = shift;
    print BOLD CYAN ON_BLACK "$text\n";
}
## for important things (e.g., "Hostname is not a FQDN")
sub print_warning {
    my $text = shift;
    print BOLD RED ON_BLACK "$text\n";
}
## for other imporant things (e.g., "You are in an LVE, do not restart services")
sub print_warning_underline {
    my $text = shift;
    print BOLD UNDERLINE "$text\n";
}
sub print_info2 {
    my $text = shift;
    print BOLD GREEN ON_BLACK "$text\n";
}

sub print_magenta {
    my $text = shift;
    print BOLD MAGENTA ON_BLACK "$text\n";
}

##############################
#  BEGIN [INFO] CHECKS
##############################

sub print_hostname {

    print_info( 'Hostname: ' );

    if ( $hostname !~ /([\w-]+)\.([\w-]+)\.(\w+)/ ) { 
        print_warning( "$hostname is not a FQDN ( en.wikipedia.org/wiki/Fully_qualified_domain_name )" );
    }   
    else {
        print_normal( $hostname );
    }   
}

sub print_os {
    my $release_info;
    my $os_info;
    my $is_cloudlinux = 0;
    my $php_selector_conf = '/usr/local/cpanel/base/frontend/x3/dynamicui/dynamicui_lvephpsel.conf';
    my $php_selector_disabled = 0;

    if ( -e '/etc/redhat-release' ) { 
        if ( open my $rr_fh, '<', '/etc/redhat-release' ) { 
            while ( <$rr_fh> ) { 
                chomp( $release_info = $_ );
            }
            close $rr_fh;
        }
        $os_info = $release_info . " [$hostinfo{'environment'}]";
    }    
    elsif ( $os eq 'freebsd' ) { 
        $os_info = 'FreeBSD';
    }
    else {
        $os_info = 'Unknown (no /etc/redhat-release, and not FreeBSD)';
    }

    if ( $release_info and $release_info =~ /cloudlinux/i ) {
        $is_cloudlinux = 1;
        if ( -f $php_selector_conf ) {
            if ( open my $file_fh, '<', $php_selector_conf ) {
                while ( <$file_fh> ) {
                    if ( /^file=>lvephpsel,skipobj=>1/ ) {
                        $php_selector_disabled = 1;
                        last;
                    }
                }
                close $file_fh;
            }
        }
        else {
            $php_selector_disabled = 'status unknown';
        }
    }

    if ( $is_cloudlinux == 1 ) {
        if ( $php_selector_disabled eq 1 ) {
            $os_info .= ' [PHP Selector: disabled for x3]';
        }
        elsif ( $php_selector_disabled eq 0 ) {
            $os_info .= ' [PHP Selector: enabled for x3]';
        }
        elsif ( $php_selector_disabled eq 'status unknown' ) {
            $os_info .= ' [PHP Selector: status unknown]';
        }
    }

    print_info( 'OS: ' );
    print_normal( $os_info );
}

sub print_kernel_and_cpu {
    print_info( 'Kernel/CPU: ');
    print_normal( "$hostinfo{'kernel'} $hostinfo{'hardware'} $hostinfo{'environment'} $cpuinfo{'model'} w/ $cpuinfo{'numcores'} core(s)" );
}

sub print_cpanel_info {
    my ( $cpanel_version, $cpanel_tier );
    my ( $birthday_file, $birthday, $atime );
    my $output;

    ## cpanel-install-thread0.log is better to be checked before cpanel-install.log
    if ( -f '/var/log/cpanel-install-thread0.log' ) {
        $birthday_file = '/var/log/cpanel-install-thread0.log';
    }    
    elsif ( -f '/var/log/cpanel-install.log' ) {
        $birthday_file = '/var/log/cpanel-install.log';
    }    

    if ( $birthday_file ) {
        my $ctime = ( stat( $birthday_file ))[9];
        $birthday = localtime $ctime;
    }    

    if ( open my $version_fh, '<', '/usr/local/cpanel/version' ) {
        while ( <$version_fh> ) {
            chomp( $cpanel_version = $_ );
        }
        close $version_fh;
    }
    else {
        $cpanel_version = 'Unknown (could not open/read /u/l/c/version ?)';
    }

    if ( open my $cpupdate_fh, '<', '/etc/cpupdate.conf' ) {
        while ( <$cpupdate_fh> ) {
            if ( m{ \A CPANEL=(.*) }xmsi ) {
                chomp( $cpanel_tier = $1 );
            }
        }
        close $cpupdate_fh;
    }
    else {
        $cpanel_tier = 'Unknown (could not open/read /etc/cpupdate.conf ?)';
    }

    my $ctime = ( stat( '/usr/local/cpanel/version' ))[10];
    my $last_update = time() - $ctime;
    $last_update = $last_update / 86400;
    $last_update = sprintf '%.1f', $last_update;

    if ( $birthday ) {
        $output = "${cpanel_version} " . '(' . uc( $cpanel_tier ) . ' tier)' . " Last update: $last_update days ago" . " [ Installed $birthday ]";
    }
    else {
        $output = "${cpanel_version} " . '(' . uc( $cpanel_tier ) . ' tier)' . " Last update: $last_update days ago";
    }

    print_info( 'cPanel Info: ' );
    print_normal( $output );
}

sub check_for_cpanel_update {
    my ( $TIERS, @tiers );
    my ( $tier, $available_tier_version );
    my ( $local_tier_name, $local_tier_version );
    my $match = 0;

    #
    # get local tier name (e.g., edge)
    #
    my $cpupdate_conf = '/etc/cpupdate.conf';
    return if !$cpupdate_conf;

    if ( open my $file_fh, '<', $cpupdate_conf ) {
        while ( <$file_fh> ) {
            if ( /\bcpanel=(.*)/i ) {
                $local_tier_name = $1;
                last;
            }
        }
        close $file_fh;
    }

    return if !$local_tier_name;

    #
    # get local tier version (e.g., 11.36.0.4)
    #
    my $cpanel_version = '/usr/local/cpanel/version';
    return if !$cpanel_version;
    
    if ( open my $file_fh, '<', $cpanel_version ) {
        chomp( $local_tier_version = readline $file_fh );
        close $file_fh;
    }

    if ( $local_tier_version !~ /(\d+\.\d+\.\d+\.\d+)/ ) {
        print_info( 'cPanel update check: ' );
        print_warning( "unknown or old cPanel version: $local_tier_version" );
        return;
    }

    #
    # get available tiers and versions (e.g., edge:11.36.0.4)
    #
    local $SIG{'ALRM'} = sub { return(); };

    alarm 5;

    my $sock = IO::Socket::INET->new(
        PeerAddr    => 'httpupdate.cpanel.net',
        PeerPort    => 80,
        Proto       => 'tcp',
        Timeout     => 3,
    );   

    if ( $sock ) {
        print $sock "GET /cpanelsync/TIERS HTTP/1.1\r\nHost: httpupdate.cpanel.net\r\n\r\n";
        sysread $sock, $TIERS, 1000;
        close $sock;
    }

    alarm 0;

    return if !$TIERS;

    @tiers = split /\n/, $TIERS;


    #
    # does the local server use a recognized tier?
    #
    for my $line ( @tiers ) {
        if ( $line =~ m{ \A (.*) : (\d+\.\d+\.\d+\.\d+) \z }xms ) {
            ( $tier, $available_tier_version ) = ( $1, $2 );
            if ( $tier eq $local_tier_name ) {
                $match = 1;
                last;
            }
        }
    }

    if ( $match == 0 ) {
        print_info( 'cPanel update check: ' );
        print_warning( "server is configured to use an unknown tier ($local_tier_name)" );
        return;
    }

    #
    # does the local tier version match the available tier version?
    #
    return if ( $local_tier_version eq $available_tier_version );


    my $local_tier_version_tmp = $local_tier_version;
    my $available_tier_version_tmp = $available_tier_version;
    $local_tier_version_tmp =~ s/\.//g;
    $available_tier_version_tmp =~ s/\.//g;

    #
    # FreeBSD won't ever go past 11.30
    # http://www.cpanel.net/products/cpanelwhm/system-requirements.html
    #
    return if ( ( $os eq 'freebsd' ) && substr( $local_tier_version_tmp, 0, 4 ) == '1130' );

    #
    # is the available tier version higher than the local tier version?
    #
    if ( $local_tier_version_tmp < $available_tier_version_tmp ) {
        print_info( 'cPanel update check: ' );
        print_warning( "UPDATE AVAILABLE ($local_tier_version -> $available_tier_version)" );
    }
    else {
        print_info( 'cPanel update check: ' );
        print_warning( "local version ($local_tier_version) is higher than available version ($available_tier_version) [configured tier is: $local_tier_name]" );
    }
}

sub check_perl_version_less_than_588 {
    my @perl_v = split /\n/, run( 'perl', '-v' );

    my $perl_version;
    for my $line ( @perl_v ) {
        if ( $line =~ m{ \A This \s is \s perl, \s v(\d+\.\d+\.\d+) \s }xms ) {
            $perl_version = $1;
            last;
        }
    }    

    return if ! $perl_version;

    my $perl_version_tmp = $perl_version;
    $perl_version_tmp =~ s/\.//g;

    if ( $perl_version_tmp < 588 ) { # 5.10 shows as 5.10.0, so there shouldn't be any false positives for that
        print_warn( 'Perl Version: ' );
        print_warning( "less than 5.8.8.: $perl_version" );
    }
}

sub print_uptime {
    chomp( my $uptime = run( 'uptime' ) ); 
    print_info( 'Uptime: ');
    print_normal( $uptime );
}

sub check_for_clustering {
    if ( -e '/var/cpanel/useclusteringdns' ) {
        print_info( 'DNS Clustering: ' );
        print_normal( 'is enabled' );
    }
    else {
        return;
    }

    my $cluster_dir = '/var/cpanel/cluster/root/config';
    my @dir_contents;
    my @cluster_members;
    my ( $cluster_member_ipaddr, $cluster_member_hostname, $cluster_member_role );

    if ( -d $cluster_dir ) {
        opendir( my $dir_fh, $cluster_dir );
        @dir_contents = grep { ! /^\.(\.?)$/ } readdir $dir_fh;
        closedir $dir_fh;
    }

    chdir $cluster_dir or return;

    for my $dirent ( @dir_contents ) {
        # only active cluster members have -dnsrole files
        if ( $dirent =~ m{ \A (\d+\.\d+\.\d+\.\d+)-dnsrole \z }xms ) {
            $cluster_member_ipaddr = $1;

            if ( open my $file_fh, '<', "${cluster_member_ipaddr}.cache" ) {
                my $cache_ref;
                eval 'local $SIG{__DIE__}; local $SIG{__WARN__}; $cache_ref = Storable::fd_retrieve($file_fh);'; # from upcp.static
                close $file_fh;
                if ( $cache_ref ) {
                    $cluster_member_hostname = $cache_ref->{'host'};
                }
                close $file_fh;
            }
            else {
                $cluster_member_hostname = '?';
            }

            if ( !$cluster_member_hostname ) {
                $cluster_member_hostname = '?';
            }

            if ( open my $file_fh, '<', "${cluster_member_ipaddr}-dnsrole" ) {
                while ( <$file_fh> ) {
                    $cluster_member_role = $_;
                }
                close $file_fh;
            }
            else {
                $cluster_member_role = '?';
            }

            push @cluster_members, $cluster_member_hostname . '_SSP_' . $cluster_member_ipaddr . '_SSP_' . "[${cluster_member_role}]";
        }
    }

    ## print sorted output for cluster members, by hostname
    if ( @cluster_members ) {
        @cluster_members = sort @cluster_members;

        for my $member ( @cluster_members ) {
            $member =~ s/_SSP_/ /g;
            print_magenta( "\t \\_ $member" );
        }
    }
}

sub print_apache_info {
    my $output;
    my $apache_status;
   
    if ( @apache_version_output ) { # httpd -v

        my ( $apache_version, $apache_built, $apache_ea_version );

        for my $line ( @apache_version_output ) {
            if ( $line =~ m{ \A Server \s version: \s (.*) \z }xms ) {
                $apache_version = $1;
            }
            if ( $line =~ m{ \A Server \s built: \s (.*) \z }xms ) {
                $apache_built = $1;
                $apache_built =~ s/^\s+//g;
            }
            if ( $line =~ m{ \A Cpanel::Easy::Apache \s (.*) \z }xms ) {
                $apache_ea_version = $1;
            }
        }

        if ( ! $apache_version or ! $apache_built or ! $apache_ea_version ) {
            $output .= 'could not determine Apache info!';
        }
        else {
            $output .= "[ $apache_version ] [ $apache_built w/ $apache_ea_version ]";
        }
    }

    my ( $apache_uptime, $apache_generations );

    local $SIG{'ALRM'} = sub {};
    alarm 5;

    my $sock = IO::Socket::INET->new(
        PeerAddr    => '127.0.0.1',
        PeerPort    => 80,
        Proto       => 'tcp',
        Timeout     => 3,
    );

    if ( $sock ) {
        print $sock "GET /whm-server-status HTTP/1.0\r\n\r\n";
        sysread $sock, $apache_status, 10_000;
        close $sock
    }

    alarm 0;

    if ( $apache_status ) {
        my @apache_status = split /\n/, $apache_status;

        for my $line ( @apache_status ) {
            if ( $line =~ m{ Server \s uptime: \s+ (.*) </dt> }xms ) {
                $apache_uptime = $1;
                $apache_uptime = 'Up ' . $apache_uptime;
            }
            if ( $line =~ m{ Parent \s Server \s Generation: (.*) </dt> }xms ) {
                $apache_generations = $1;
            }
        }
        if ( $apache_uptime and $apache_generations ) {
            $output .= " [ $apache_uptime w/ $apache_generations generation(s) ]";
        }
    }    
    else {
        print_info( 'Apache: ' );
        print_warning( 'Apache is not up (failed: http://localhost/whm-server-status)' );
        return;
    }

    if ( $output ) {
        print_info( 'Apache: ' );
        print_normal ( $output );
    }

}    

sub print_php_configuration {
    my $phpconf = '/usr/local/apache/conf/php.conf.yaml';
    return if ! -f $phpconf;

    my ( $phpversion, $php5version, $php4version, $php4handler, $php5handler, $suexec );

    open my $phpconf_fh, '<', $phpconf;
    while ( <$phpconf_fh> ) {
        if ( /^phpversion: (\d)/ ) {
            $phpversion = $1;
        }
        if ( /^php4: (.*)/ ) {
            $php4handler = $1;
        }
        if ( /^php5: (.*)/ ) {
            $php5handler = $1;
        }
        if ( /^suexec: (.*)/ ) {
            $suexec = $1;
        }
    }    
    close $phpconf_fh;

    if ( $suexec eq 1 ) {
        $suexec = '/w suexec';
    }    
    else {
        $suexec = 'without suexec';
    }    

    if ( $phpversion == 5 ) {
        if ( -x '/usr/bin/php' ) {
            my @php_v = split /\n/, run( '/usr/bin/php', '-v' );
            if ( $php_v[0] =~ /^PHP\s(\S+)\s(\S+)/ ) {
                $php5version = $1;
            }
            else {
                $php5version = '(version unknown)';
            }

            print_info( 'PHP Default: ' );
            print_normal( "PHP $php5version $php5handler $suexec" );
        }

        if ( $php4handler ne 'none' ) {
            my @php_v = split /\n/, run( '/usr/local/php4/bin/php', '-v' );
            if ( $php_v[0] =~ /^PHP\s(\S+)\s(\S+)/ ) {
                $php4version = $1;
            }
            else {
                $php4version = '(version unknown)';
            }

            print_info( 'PHP Secondary: ' );
            print_normal( "PHP $php4version $php4handler $suexec" );
        }
    }

    if ( $phpversion == 4 ) {
        if ( -x '/usr/local/php4/bin/php' ) {
            my @php_v = split /\n/, run( '/usr/local/php4/bin/php', '-v' );
            if ( $php_v[0] =~ /^PHP\s(\S+)\s(\S+)/ ) {
                $php4version = $1;
            }
            else {
                $php4version = '(version unknown)';
            }

            print_info( 'PHP Default: ' );
            print_normal( "PHP $php4version $php4handler $suexec" );
        }

        if ( $php5handler ne 'none' ) {
            my @php_v = split /\n/, run( '/usr/bin/php', '-v' );
            if ( $php_v[0] =~ /^PHP\s(\S+)\s(\S+)/ ) {
                $php5version = $1;
            }
            else {
                $php5version = '(version unknown)';
            }

            print_info( 'PHP Secondary: ' );
            print_normal( "PHP $php5version $php5handler $suexec" );
        }
    }
}

sub check_sysinfo {
    return if ! -x '/scripts/gensysinfo';

    my $sysinfo_config = '/var/cpanel/sysinfo.config';

    my ( $release, $ises ) = get_release_version(); # 5.8, 2
    chomp( my $arch = run( 'uname', '-i' ) );

    my $rebuild = 0;

    if ( ! -e $sysinfo_config ) {
        print_info( 'sysinfo: ' );
        print_warning( 'does not exist, running /scripts/gensysinfo to fix' );
        run( '/scripts/gensysinfo' );
    }
    else {
        open my $sysinfo_fh, '<', $sysinfo_config;
        while ( <$sysinfo_fh> ) {
            chomp;
            if ( m{ \A rpm_arch=(.*) }xms ) {
                if ( $os eq 'freebsd' ) {
                    $rebuild = 0;
                }
                elsif ( $arch ne $1 ) {
                    $rebuild = 1;
                }
            }
            if ( m{ \A release=(.*) }xms ) {
                if ( $release ne $1 ) {
                    $rebuild = 1;
                }
            }
            if ( m{ \A ises=(.*) }xms ) {
                if ( $ises ne $1 ) {
                    $rebuild = 1;
                }
            }
        }
        close $sysinfo_fh;
    }

    if ( $rebuild == 1 ) {
        run( 'mv', $sysinfo_config, "${sysinfo_config}.ssp.$^T" );
        run( '/scripts/gensysinfo' );
        print_info( 'sysinfo: ' );
        print_warning( '/var/cpanel/sysinfo.config contained errors and was rebuilt' );
    }
}

sub check_for_remote_mysql {
    my $mysql_host;
    my $mysql_is_local;

    ## obtain mysql host, if exists
    my $my_cnf = '/root/.my.cnf';
    if ( open my $my_cnf_fh, '<', $my_cnf ) {
        while ( <$my_cnf_fh> ) {
            chomp( my $line = $_ );
            if ( $line =~ m{ \A host \s* = \s* (?:["']?) ([^"']+) }xms ) {
                $mysql_host = $1;
            }
        }
        close $my_cnf;
    }

    if ( $mysql_host ) {
        if ( $mysql_host =~ m{ ( \d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3} )  }xms ) {
            return if ( $mysql_host eq '127.0.0.1' );
            for my $ipaddr ( @local_ipaddrs_list ) {
                if ( $ipaddr eq $mysql_host ) {
                    $mysql_is_local = 1;
                    last;
                }
            }
        }
        elsif ( $mysql_host eq 'localhost' or $mysql_host eq hostname() ) {
            $mysql_is_local = 1;
        }
        if ( !$mysql_is_local ) {
            print_info( 'Remote MySQL Host: ' );
            print_warning( $mysql_host );
        }
    }
}

sub print_if_using_mydns_or_nsd {
    if ( -e '/var/cpanel/usensd' ) {
        print_info( 'DNS Service: ' );
        print_normal( 'NSD ' );
    }
    elsif ( -e '/var/cpanel/usemydns' ) {
        print_info( 'DNS Service: ' );
        print_normal( 'MyDNS ' );
    }
}

sub print_if_using_modruid2 {
    for ( @apache_modules_output ) {
        if ( /ruid2_module/ ) {
            print_info( 'mod_ruid2: ' );
            print_normal( 'is enabled' );
            last;
        }
    }
}

sub print_which_php_is_used_internally {
    # http://docs.cpanel.net/twiki/bin/view/AllDocumentation/WHMDocs/CpsrvdAndPhp

    my $whm_php;
    my $cpanel_php;

    # WHM, Webmail, phpMyAdmin, phpPgAdmin
    if ( -f '/var/cpanel/usecpphp' ) {
        if ( -x '/var/cpanel/3rdparty/bin/php-cgi' ) {
            $whm_php = '/var/cpanel/3rdparty/bin/php-cgi';
        }
        else {
            if ( -x '/var/cpanel/3rdparty/bin/php' ) {
                $whm_php = '/var/cpanel/3rdparty/bin/php';
            }
            else {
                if ( -x '/usr/local/cpanel/3rdparty/bin/php-cgi' ) {
                    $whm_php = '/usr/local/cpanel/3rdparty/bin/php-cgi';
                }
                else {
                    $whm_php = '/usr/local/cpanel/3rdparty/bin/php';
                }
            }
        }
    }
    else {
        if ( -x '/usr/local/cpanel/3rdparty/bin/php-cgi' ) {
            $whm_php = '/usr/local/cpanel/3rdparty/bin/php-cgi';
        }
        else {
            $whm_php = '/usr/local/cpanel/3rdparty/bin/php';
        }
    }
    

    # cPanel
    if ( -f '/var/cpanel/usecpphp' ) {
        $cpanel_php = $whm_php;
    }
    else {
        if ( -x '/usr/bin/php-cgi' ) {
            $cpanel_php = '/usr/bin/php-cgi';
        }
        else {
            $cpanel_php = '/usr/bin/php';
        }
    }

    if ( $whm_php eq $cpanel_php ) {
        print_info( 'Internal PHP: ' );
        print_normal( "$whm_php (used by WHM, cPanel, webmail, phpMyAdmin, phpPgAdmin)" );
    }
    else {
        print_info( 'Internal PHP: ' );
        print_normal( "$whm_php (used by WHM, webmail, phpMyAdmin, phpPgAdmin) $cpanel_php (used by cPanel)" );
    }
}

##############################
#  END [INFO] CHECKS
##############################

##############################
#  BEGIN [WARN] CHECKS
##############################

sub check_selinux_status {
    my @selinux_status = split /\n/, run( 'sestatus' );

    return if ! @selinux_status;

    for my $line ( @selinux_status ) {
        if ( $line =~ m{ \A Current \s mode: \s+ enforcing }xms ) {
            print_warn( 'SELinux: ' );
            print_warning( 'enabled and enforcing!' );
        }
    }    
}

sub check_runlevel {
    if ( $os eq 'linux' ) {
        my $runlevel;
        my $who_r = run( 'who', '-r' );

        # CentOS 5.7, 5.8:
        #         run-level 3  2012-01-25 10:38                   last=S
        if ( $who_r =~ m{ \A \s+ run-level \s (\d) }xms ) {
            $runlevel = $1;

            if ( $runlevel != '3' ) {
                print_warn( 'Runlevel: ' );
                print_warning(  "runlevel is not 3 (current runlevel: $runlevel)" );
            }
        }
    }    
}

sub check_for_missing_root_cron {
    my $cron;
    if ( $os eq 'linux' ) {
        $cron = '/var/spool/cron/root';
    }
    elsif ( $os eq 'freebsd' ) {
        $cron = '/var/cron/tabs/root';
    }
    
    if ( ! -f $cron ) {
        print_warn( 'Missing cron: ' );
        print_warning( "root's cron file $cron is missing!" );
    }
}

sub check_if_upcp_is_running {
    my $upcp_running = 0;
    
    for my $line ( @process_list ) {
        if ( $line =~ m{ \A root (?:.*) upcp }xms ) {
            $upcp_running = 1;
            last;
        }
    }

    if ( $upcp_running == 1 ) {
        print_warn( 'upcp check: ' );
        print_warning( 'upcp is currently running' );
    }
}

sub check_valid_upcp {
    my $updatenow_static = '/scripts/updatenow.static';
    my $updatenow_valid = 0;

    if ( ! -f $updatenow_static ) {
        print_warn( 'Valid updatenow.static: ' );
        print_warning( "$updatenow_static does not exist as a file!" );
    }
    else {
        open my $updatenow_fh, '<', $updatenow_static;
        while ( <$updatenow_fh> ) {
            if ( /our \$VERSION_BUILD/ ) {
                $updatenow_valid = 1;
                last;
            }
        }
        close $updatenow_fh;
    }
    if ( ! $updatenow_valid ) {
        print_warn( 'Valid updatenow.static: ' );
        print_warning( "No VERSION_BUILD info found in $updatenow_static, could be broken!" );
    }
}

sub check_for_sandy_bridge {
    return if ! -e '/proc/cpuinfo';

    my $sandy_bridge = 0; 

    my ( $release_version, undef ) = get_release_version();
    $release_version =~ s/\.//g;

    # CentOS/RHEL 5 is not affected
    return if ( $release_version < 60 );

    # QEMU + CentOS 6.3 could be affected if using Sandy Bridge.
    # No way to determine if using Sandy Bridge, however.
    if ( $release_version == 63 and $cpuinfo{'model'} =~ m{ QEMU }ixms ) {
        print_warn( 'QEMU + CentOS 6.3: ' );
        print_warning( 'if server is using Sandy Bridge CPU, could be affected by the AVX issue' );
        return;
    }

    # If we make it here, only check CentOS/RHEL 6.0 - 6.2
    if ( $release_version !~ m{ \A ( 6[0-2] ) \z }xms ) {
        return;
    }

    if ( open my $cpuinfo_fh, '<', '/proc/cpuinfo' ) {
        while ( <$cpuinfo_fh> ) {
            chomp;

            # http://en.wikipedia.org/wiki/Sandy_Bridge#Server_platform
            if ( /^model name/ && /Xeon/ && m{    46(\d{2})
                                                | 12(2|6)0L
                                                | 24(3|5)0L
                                                | 26(3|5)0L
                                                | 12([2-4]|7)5
                                                | 12([2-4]|[7-9])0
                                                | 16(2|[5-6])0
                                                | 240(3|7)
                                                | 24([2-5]|7)0
                                                | 260(3|9)
                                                | 26([2-9])0
                                                | 26(37|43)
                                                | 266(5|7)
                                                | 2687W
                                            }xms && ! /E(\d{5})/ ) {
                $sandy_bridge = 1; 
            }
        }
        close $cpuinfo_fh;
    }    

    if ( $sandy_bridge == 1 ) {
        print_warn( 'AVX / Sandy Bridge: ' );
        print_warning( 'detected! compile ssp.cptechs.info/glibc_avx.tar.gz and run ./exe (check for "Illegal instruction")' );
    }
}


sub check_interface_lo {
    my $is_up = 0;
   
    if ( $os eq 'freebsd' ) {
        my $iconfig_lo = run( 'ifconfig', 'lo0' );
        if ( $iconfig_lo =~ /UP,/ ) {
            $is_up = 1;
        }
    }
    else { 
        my $ifconfig_lo = run( 'ifconfig', 'lo' );

        if ( $ifconfig_lo =~ /UP LOOPBACK/ ) {
            $is_up = 1;
        }
    }

    if ( ! $is_up ) {
        print_warn( 'Loopback Interface: ' );
        print_warning( 'loopback interface is not up!' );
    }
    else {
        check_loopback_connection();
    }
}

sub check_loopback_connection {
    my @ports = qw( 25 80 143 );
    my $connected = 0;

    for my $port ( @ports ) {
        my $sock = IO::Socket::INET->new(
            PeerAddr    => '127.0.0.1',
            PeerPort    => $port,
            Proto       => 'tcp',
            Timeout     => '1',
        );
    
        if ( $sock ) {
            $connected = 1;
            close $sock;
        }

        last if $connected == 1;
    }

    if ( !$connected ) {
        print_warn( 'Loopback connectivity: ' );
        print_warning( 'could not connect to 127.0.0.1 on ports 25, 80, or 143' );
    }
}

sub check_cpanelconfig_filetype {
    if ( ! -e '/var/cpanel/cpanel.config' ) {
        print_warn( '/var/cpanel/cpanel.config: ' );
        print_warning( 'missing!' );
    }
    else {
        chomp( my $file = run( 'file', '/var/cpanel/cpanel.config' ) ); 
        if ( $file !~ m{ \A /var/cpanel/cpanel.config: \s ASCII \s text \z }xms ) {
            print_warn( '/var/cpanel/cpanel.config: ' );
            print_warning( "filetype is something other than 'ASCII text'! ($file)" );
        }
    }
}

sub check_for_cpanelsync_exclude {
    my $cpanelsync_exclude = '/etc/cpanelsync.exclude';
    if ( -f $cpanelsync_exclude and ! -z $cpanelsync_exclude ) {
        print_warn( 'cpanelsync exclude: ' );
        print_warning( "$cpanelsync_exclude is not empty!" );
    }    
}

sub check_for_lve_environment {

# pam_lve 0.2 prints this after su or sudo:
#
# # /bin/su -
# Password: 
# ***************************************************************************
# *                                                                         *
# *             !!!!  WARNING: YOU ARE INSIDE LVE !!!!                      *
# *IF YOU RESTART ANY SERVICES STABILITY OF YOUR SYSTEM WILL BE COMPROMIZED *
# *        CHANGE UID OF THE USER YOU ARE USING TO SU/SUDO                  *
# *                             MORE INFO:                                  *
# *http://www.cloudlinux.com/blog/clnews/read-this-if-you-use-su-or-sudo.php*
# *                                                                         *
# ***************************************************************************

# pam_lve 0.3 won't put wheel users in an LVE after su or sudo:
# http://cloudlinux.com/blog/clnews/read-this-if-you-use-su-or-sudo.php

    if ( $hostinfo{'kernel'} =~ /\.lve/ and -x '/usr/sbin/lveps' ) {
        my $lve_check = `/usr/sbin/lveps -p | grep " $$ "`;
        if ( $lve_check ) {
            print "\n";
            print_warning_underline( ' !! YOU ARE IN AN LVE - DO *NOT* RESTART ANY SERVICES !!' );
            print_warning_underline( ' !! YOU ARE IN AN LVE - DO *NOT* RESTART ANY SERVICES !!' );
            print_warning_underline( ' !! YOU ARE IN AN LVE - DO *NOT* RESTART ANY SERVICES !!' );
            print "\n";
        }
    }    
}

sub check_for_rawopts {
    my $rawopts_dir = '/var/cpanel/easy/apache/rawopts';
    my @dir_contents;

    if ( -d $rawopts_dir ) {
        opendir( my $dir_fh, $rawopts_dir );
        @dir_contents = grep { ! /^\.(\.?)$/ } readdir $dir_fh;
        closedir $dir_fh;
    }
 
    if ( @dir_contents ) {
        print_warn( 'Rawopts Detected: ' );
        print_warning( 'check /var/cpanel/easy/apache/rawopts !' );
    }       
}

sub check_for_rawenv {
    my $rawenv_dir = '/var/cpanel/easy/apache/rawenv';
    my @dir_contents;

    if ( -d $rawenv_dir ) {
        opendir( my $dir_fh, $rawenv_dir );
        @dir_contents = grep { ! /^\.(\.?)$/ } readdir $dir_fh;
        closedir $dir_fh;
    }

    if ( @dir_contents ) {
        print_warn( 'Rawenv detected: ' );
        print_warning( 'check /var/cpanel/easy/apache/rawenv !' );
    }
}

sub check_for_custom_opt_mods {
    my $custom_opt_mods;
    my $dir = '/var/cpanel/easy/apache/custom_opt_mods';

    return if ! -e $dir;

    find( \&find_custom_opt_mods, $dir );

    if ( scalar @custom_opt_mods > 10 ) {
        print_warn( "$dir: " );
        print_warning( 'many custom opt mods exist, check manually' );
    }
    elsif ( @custom_opt_mods ) {
        for my $custom_opt_mod ( @custom_opt_mods ) {
            $custom_opt_mods .= "$custom_opt_mod ";
        }

        print_warn( "$dir: " );
        print_warning( $custom_opt_mods );
    }
}

sub find_custom_opt_mods {
    # ignore these, Attracta:
    #  /var/cpanel/easy/apache/custom_opt_mods/Cpanel/Easy/ModFastInclude.pm
    #  /var/cpanel/easy/apache/custom_opt_mods/Cpanel/Easy/ModFastInclude.pm.tar.gz

    my $file = $File::Find::name;
    if ( -f $file and $file !~ m{ /ModFastInclude\.pm(.*) }xms ) {
        $file =~ s#/var/cpanel/easy/apache/custom_opt_mods/##;
        push @custom_opt_mods, $file;
    }
}

sub check_for_local_apache_templates {
    my $apache2_template_dir = '/var/cpanel/templates/apache2';
    my @dir_contents;

    if ( -d $apache2_template_dir ) {
        opendir( my $dir_fh, $apache2_template_dir );
        @dir_contents = readdir $dir_fh;
        closedir $dir_fh;
    }    

    my $templates;
    for my $template ( @dir_contents ) {
        if ( $template =~ m{ \.local \z }xms ) {
            $templates .= " $template";
        }
    }

    if ( $templates ) {
        print_warn( 'Custom apache2 templates: ' );
        print_warning( $templates );
    }
}

sub check_for_local_makecpphp_template {
    my $makecpphp_local_profile = '/var/cpanel/easy/apache/profile/makecpphp.profile.yaml.local';

    if ( -e $makecpphp_local_profile ) {
        print_warn( 'makecpphp Local Profile: ' );
        print_warning( "exists at $makecpphp_local_profile !" );
    }
}

sub check_for_custom_apache_includes {
    my $include_dir = '/usr/local/apache/conf/includes';

    return if ! $include_dir;

    my @includes = qw(
        post_virtualhost_1.conf
        post_virtualhost_2.conf
        post_virtualhost_global.conf
        pre_main_1.conf
        pre_main_2.conf
        pre_main_global.conf
        pre_virtualhost_1.conf
        pre_virtualhost_2.conf
        pre_virtualhost_global.conf
    );

    my $custom_includes;
    for my $include ( @includes ) {
        if ( ! -z "${include_dir}/${include}" ) {
            if ( $include eq 'pre_virtualhost_global.conf' ) {
                my $md5 = run( 'md5sum', '/usr/local/apache/conf/includes/pre_virtualhost_global.conf' );
                next if ( $md5 =~ m{ \A 1693b9075fa54ede224bfeb8ad42a182 \s }xms );
                $custom_includes .= " $include";
            }
        }
    }

    if ( $custom_includes ) {
        print_warn( 'Apache Includes: ' );
        print_warning( $custom_includes );
    }
}

sub check_for_tomcatoptions {
    my $tomcat_options = '/var/cpanel/tomcat.options';
    if ( -f $tomcat_options and ! -z $tomcat_options ) {
        print_warn( 'Tomcat options: ' );
        print_warning( "$tomcat_options exists" );
    }
}

sub check_for_sneaky_htaccess {
    ## this is lazy checking. ideally we'd check HOMEMATCH from wwwacct.conf and go from there.
    ## but then, nothing guarantees the current HOMEMATCH has always been the same, either.
    my @dirs = qw( / /home/ /home2/ /home3/ /home4/ /home5/ /home6/ /home7/ /home8/ /home9/ );
    my $htaccess;

    for my $dir ( @dirs ) {
        if ( -f $dir . '.htaccess' and ! -z $dir . '.htaccess' ) {
            $htaccess .= $dir . '.htaccess ';
        }
    }

    if ( $htaccess ) {
        print_warn( 'Sneaky .htaccess file(s) found: ' );
        print_warning( $htaccess );
    }
}

sub check_perl_sanity {
    my $usr_bin_perl = '/usr/bin/perl';
    my $usr_local_bin_perl = '/usr/local/bin/perl';

    if ( ! $usr_bin_perl ) {
        print_warn( 'perl: ' );
        print_warning( "$usr_bin_perl does not exist!" );
    }
    if ( ! $usr_local_bin_perl ) {
        print_warn( 'perl: ' );
        print_warning( "$usr_local_bin_perl does not exist!" );
    }

    if ( -l $usr_bin_perl and -l $usr_local_bin_perl ) {
        my $usr_bin_perl_link = readlink $usr_bin_perl;
        my $usr_local_bin_perl_link = readlink $usr_local_bin_perl;
        if ( -l $usr_bin_perl_link and -l $usr_local_bin_perl_link ) {
            print_warn( 'perl: ' );
            print_warning( "$usr_bin_perl and $usr_local_bin_perl are both symlinks!" );
        }
    }

    ## a symlink will test true for both -x AND -l
    if ( -x $usr_bin_perl and ! -l $usr_bin_perl ) {
        if ( -x $usr_local_bin_perl and ! -l $usr_local_bin_perl ) {
            print_warn( 'perl: ' );
            print_warning( "$usr_bin_perl and $usr_local_bin_perl are both binaries!" );
        }
    }

    if ( -x $usr_bin_perl and ! -l $usr_bin_perl ) {
        my $mode = ( stat( $usr_bin_perl ))[2] & 07777;
        $mode = sprintf "%lo", $mode;
        if ( $mode != '755' ) {
            print_warn( 'Perl Permissions: ' );
            print_warning( "$usr_bin_perl is $mode" );
        }
    }

    if ( -x $usr_local_bin_perl and ! -l $usr_local_bin_perl ) {
        my $mode = ( stat( $usr_local_bin_perl ))[2] & 07777;
        $mode = sprintf "%lo", $mode;
        if ( $mode != '755' ) {
            print_warn( 'Perl Permissions: ' );
            print_warning( "$usr_local_bin_perl is $mode" );
        }
    }
}

sub check_for_non_default_permissions {
    my %resources_and_perms = (
        '/'                             => '755',
        '/bin'                          => '755',
        '/bin/bash'                     => '755',
        '/dev/null'                     => '666',
        '/etc/group'                    => '644',
        '/etc/hosts'                    => '644',
        '/etc/nsswitch.conf'            => '644',
        '/etc/passwd'                   => '644',
        '/etc/stats.conf'               => '644',
        '/opt'                          => '755',
        '/root/cpanel3-skel'            => '755',
        '/sbin'                         => '755',
        '/tmp'                          => '1777',
        '/usr'                          => '755',
        '/usr/bin'                      => '755',
        '/usr/sbin'                     => '755',
        '/usr/local/apache'             => '755',
        '/usr/local/apache/bin/httpd'   => '755',
        '/usr/local/cpanel/bin/cpwrap'  => '4755',
        '/usr/local/bin'                => '755',
        '/usr/local/sbin'               => '755',
        '/var'                          => '755',
        '/var/cpanel/locale'            => '755',
        '/var/cpanel/resellers'         => '644',
    );

    for my $resource ( keys %resources_and_perms ) {
        if ( -e $resource ) {
            my $mode = ( stat( $resource ))[2] & 07777;
            $mode = sprintf "%lo", $mode;
            if ( $mode != $resources_and_perms{$resource} ) {
                next if ( $resource =~ '^(/(s?)bin|/usr/(s?)bin|/)$' and $mode == '555' ); # CentOS 6.2+
                next if ( $resource =~ '^/(var|sbin|usr/local/sbin|usr|usr/sbin)?$' and $mode == '711' );
                print_warn( 'Non-default Permissions: ' );
                print_warning( "$resource (mode: $mode | default: $resources_and_perms{$resource})" );
            }
        }
    }

    ## cPanel changes /etc/shadow from 0400 to 0600 (and possibly 0200?)
    if ( -e '/etc/shadow' ) {
        my $mode = ( stat( '/etc/shadow' ))[2] & 07777;
        $mode = sprintf "%lo", $mode;
        if ( $mode != '600' and $mode != '400' and $mode != '200' ) {
            print_warn( 'Non-default Permissions: ' );
            print_warning( "/etc/shadow (mode: $mode | default: 0400 or 0600)" );
        }
    }

    if ( -e '/usr/bin/crontab' ) {
        my $mode = ( stat( '/usr/bin/crontab' ))[2] & 07777;
        $mode = sprintf "%lo", $mode;
        if ( $mode != '4755' and $mode != '6755' and $mode != '4555' ) {
            print_warn( 'Non-default Permissions: ' );
            print_warning( "/usr/bin/crontab (mode: $mode | default: 4755 or 6755 or 4555)" );
        }
    }

    if ( -e '/usr/bin/passwd' ) {
        my $mode = ( stat( '/usr/bin/passwd' ))[2] & 07777;
        $mode = sprintf "%lo", $mode;
        if ( $mode !~ m{ \A ( 4755 | 6755 | 4511 | 4555 ) \z }xms ) {
            print_warn( 'Non-default Permissions: ' );
            print_warning( "/usr/bin/passwd (mode: $mode | default: 4755 or 6755 or 4511 or 4555)" );
        }
    }

    if ( -e '/sbin/ifconfig' ) {
        my $mode = ( stat( '/sbin/ifconfig' ))[2] & 07777;
        $mode = sprintf "%lo", $mode;
        if ( $mode != '755' and $mode != '555' ) {
              print_warn( 'Non-default Permissions: ' );
              print_warning( "/sbin/ifconfig (mode: $mode | default: 755 or 555)" );
        }
    }

    if ( -e '/bin/ln' ) {
        my $mode = ( stat( '/bin/ln' ))[2] & 07777;
        $mode = sprintf "%lo", $mode;
        if ( $mode != '755' and $mode != '555' ) {
              print_warn( 'Non-default Permissions: ' );
              print_warning( "/bin/ln (mode: $mode | default: 755 or 555)" );
        }
    }
}

sub check_awstats_permissions {
    my $cpanel_config = '/var/cpanel/cpanel.config';
    my $awstats = '/usr/local/cpanel/3rdparty/bin/awstats.pl';
    my $skipawstats = 0;

    return if ! -e $cpanel_config;

    if ( open my $cpanel_config_fh, '<', $cpanel_config ) {
        while ( <$cpanel_config_fh> ) {
            if ( /^skipawstats=(\d)/ ) {
                $skipawstats = $1;
            }
        }
        close $cpanel_config_fh;
    }

    if ( $skipawstats == 0 ) {
        if ( -e $awstats ) {
            my $mode = ( stat( $awstats ))[2] & 07777;
            $mode = sprintf "%lo", $mode;
            if ( $mode != '755' ) {
                print_warn( 'Awstats: ' );
                print_warning( " enabled, but $awstats isn't 755 !" );
            }
        }
    }
}   

sub check_var_cpanel_users_files_ownership {
    my $var_cpanel_users = '/var/cpanel/users';

    my @files;
    if ( -d $var_cpanel_users ) {
        opendir( my $dir_fh, $var_cpanel_users );
        @files = grep { ! /^\.(\.?)$/ and ! /^(root|system|nobody)$/ } readdir $dir_fh;
        closedir $dir_fh;
    }

    my $group_root_files;
    for my $file ( @files ) {
        next if ( $file !~ /^[a-z0-9]+$/ );
        my $gid = ( stat( '/var/cpanel/users/' . $file ))[5];
        if ( $gid == 0 ) {
            $group_root_files .= " $file";
        }
    }

    if ( $group_root_files ) {
        print_warn( '/v/c/users file(s) owned by group "root": ' );
        print_warning( $group_root_files );
    }
}

sub check_root_suspended {
    if ( -e '/var/cpanel/suspended/root' ) {
        print_warn( 'root suspended: ' );
        print_warning( 'the root account is suspended! Unsuspend it to avoid problems.' );
    }
}

sub check_limitsconf {
    my @limitsconf;

    if ( open my $limitsconf_fh, '<', '/etc/security/limits.conf' ) {
        while ( <$limitsconf_fh> ) {
            push @limitsconf, $_;
        }
        close $limitsconf_fh;
    }

    @limitsconf = grep { ! /^(\s+|#)/ } @limitsconf;

    if ( @limitsconf ) {
        print_warn( 'limits.conf: ' );
        print_warning( 'custom limits defined in /etc/security/limits.conf!' );
    }
}

sub check_disk_space {
    my @df = split /\n/, run( 'df' );
    for my $line ( @df ) {
        if ( $line =~ m{ (9[8-9]|100)% \s+ (.*) }xms ) {
            my ( $usage, $partition ) = ( $1, $2 );
            unless ( $line =~ m{ /virtfs | /(dev|proc) \z }xms ) {
                print_warn( 'Disk space: ' );
                print_warning( "${usage}% usage on $partition" );
            }
        }
    }
}

sub check_disk_inodes {
    my @df_i = split /\n/, run( 'df', '-i' );
    for my $line ( @df_i ) {
        if ( $line =~ m{ (9[8-9]|100)% \s+ (.*) }xms ) {
            my ( $usage, $partition ) = ( $1, $2 );
            unless ( $line =~ m{ /virtfs | /(dev|proc) \z }xms ) {
                print_warn( 'Disk inodes: ' );
                print_warning( "${usage}% inode usage on $partition" );
            }
        }
    }
}

sub check_for_hooks_in_scripts_directory {
    if ( -f '/usr/local/cpanel/Cpanel/CustomEventHandler.pm' ) {
        print_warn( 'Hooks: ' );
        print_warning( '/usr/local/cpanel/Cpanel/CustomEventHandler.pm exists!' );
    }

    # default CloudLinux, cPGs hooks that can be ignored
    my %hooks_ignore = qw(
        e5e13640299ec439fb4c7f79a054e42b    /scripts/posteasyapache
        42a624c843f34085f1532b0b4e17fe8c    /scripts/postmodifyacct
        22cf7db1c069fd9672cd9dad3a3d371d    /scripts/postupcp
        57f8ea2d494e299827cc365c86a357ac    /scripts/postupcp
        e464adf0531fea2af4fe57361d9a43fb    /scripts/postupcp
        941772daaa48999f1d5ae5fe2f881e36    /scripts/postupcp
        4988be925a6f50ec505618a7cec702e2    /scripts/postkillacct
        a4df04a6440073fe40363cfd241b1fe7    /scripts/postwwwacct
        03a0dc919c892bde254c52cefe4d0673    /scripts/postwwwacct
        2401d6260dac6215596be1652b394200    /scripts/postwwwacct
        44caf075fc0f9847ede43de5dd563edc    /scripts/prekillacct
        86f9b53c81a8f2fd77a8626ddd3b2c71    /scripts/prekillacct
        46fee9faf2d5f83cbcda17ce0178a465    /scripts/prekillacct

    );

    my @hooks;
    if ( -d '/scripts' ) {
        opendir( my $scripts_fh, '/scripts' );
        @hooks = grep { /^(pre|post)/ } readdir $scripts_fh;
        closedir $scripts_fh;
    }

    # these exist by default
    @hooks = grep { ! /postsuexecinstall/ && ! /post_sync_cleanup/ } @hooks;

    # CloudLinux stuff
    @hooks = grep { ! /postwwwacct\.l\.v\.e-manager\.bak/ } @hooks;

    my $hooks_output;
    if ( @hooks ) {
        for my $hook ( @hooks ) {
            $hook = '/scripts/' . $hook;
            unless ( $os eq 'freebsd' ) {
                chomp( my $checksum = run( 'md5sum', $hook ) );
                $checksum =~ s/\s.*//g;
                next if exists $hooks_ignore{$checksum};
            }
            if ( ! -z $hook ) {
               $hooks_output .= " $hook ";
            }
        }
    }
    
    if ( $hooks_output ) {
        print_warn( 'Hooks: ' );
        print_warning( $hooks_output );
    }
}

sub check_for_huge_apache_logs {
    my @logs = qw( access_log error_log suphp_log suexec_log mod_jk.log modsec_audit.log modsec_debug.log );
    for my $log ( @logs ) {
        $log = '/usr/local/apache/logs/' . $log;
        if ( -e $log ) {
            my $size = ( stat( $log ) )[7];
            if ( $size > 2_100_000_000 ) {
                $size = sprintf("%0.2fGB", $size/1073741824);
                print_warn( 'M-M-M-MONSTER LOG!: ' );
                print_warning( "$log ($size)" );
            }
        }
    }    
}

sub check_easy_skip_cpanelsync {
    if ( -e '/var/cpanel/easy_skip_cpanelsync' ) {
        print_warn( 'Touchfile: ' );
        print_warning( '/var/cpanel/easy_skip_cpanelsync exists! ');
    }
}

sub check_pkgacct_override {
    if ( -d '/var/cpanel/lib/Whostmgr' ) {
        print_warn( 'pkgacct override: ' );
        print_warning(' /var/cpanel/lib/Whostmgr exists, override may exist' );
    }    
}

sub check_for_gdm {
    my $gdm = 0; 

    for my $line ( @process_list ) {
        if ( $line =~ m{ \A root (?:.*) gdm }xms ) {
            $gdm = 1; 
            last;
        }
    }    

    if ( $gdm == 1 ) {
        print_warn( 'gdm Process: ' );
        print_warning( 'is running' );
    }    
}

sub check_for_redhat_firewall {
    my $iptables = run( 'iptables', '-L', 'RH-Firewall-1-INPUT' );

    if ( $iptables ) {
        print_warn( 'Default Redhat Firewall Check: ' );
        print_warning( 'RH-Firewall-1-INPUT table exists. /scripts/configure_rh_firewall_for_cpanel to open ports.' );
    }    
}

sub check_easyapache {
    my $ea_is_running_file = '/usr/local/apache/AN_EASYAPACHE_BUILD_IS_CURRENTLY_RUNNING';
    my $ea_in_process_list = 0; 
    my $apache_update_no_restart = '/var/cpanel/mgmt_queue/apache_update_no_restart';
    my $ea_is_running = 0;

    if ( -e $ea_is_running_file ) {
        for my $process ( @process_list ) {
            if ( $process =~ m{ \A root (?:.*) easyapache }xms ) {
                $ea_in_process_list = 1; 
                last;
            }
            else {
                $ea_in_process_list = 0;
            }
        }
        if ( $ea_in_process_list == 0 ) {
            print_warn( 'EasyApache: ' );
            print_warning( "$ea_is_running_file exists, but 'easyapache' not found in process list" );
        }
        else {
            $ea_is_running = 1;
            print_warn( 'EasyApache: ' );
            print_warning( 'is running' );
        }
    }    

    if ( -e $apache_update_no_restart and $ea_is_running == 0 ) {
        print_warn( 'EasyApache: ' );
        print_warning( "$apache_update_no_restart exists! This will prevent EA from completing successfully." );
    }
}

sub check_for_easyapache_hooks {
    my $hooks;

    my @hooks = qw( /scripts/before_apache_make
                    /scripts/after_apache_make_install
                    /scripts/before_httpd_restart_tests
                    /scripts/after_httpd_restart_tests
                );
 
    # default CloudLinux hooks that can be ignored
    my %hooks_ignore = qw(
        41ec2d3f35d8cd7cb01b60485fb3bdbb    /scripts/before_apache_make
    );

    for my $hook ( @hooks ) {
        if ( -f $hook and ! -z $hook ) {
            unless ( $os eq 'freebsd' ) {
                chomp( my $checksum = run( 'md5sum', $hook ) );
                $checksum =~ s/\s.*//g;
                next if exists $hooks_ignore{$checksum};
            }
            $hooks .= " $hook";
        }
    }

    if ( $hooks ) {
        print_warn( 'EA hooks: ' );
        print_warning( $hooks );
    }
}

sub check_for_home_noexec {
    my @mount = split /\n/, run( 'mount' );

    for my $mount ( @mount ) {
        if ( $mount =~ m{ \s on \s (/home([^\s]?)) \s (:?.*) noexec }xms ) {
            my $noexec_partition = $1;
            print_warn( 'mounted noexec: ');
            print_warning( $noexec_partition );
        }
    }
}

## compare external IP addr with local IP addrs, OR
## check if only internal IP addrs are bound to server (this is not as reliable,
## as NAT can still be used with external IP addrs of course)
sub check_for_nat {
    my @external_ipaddrs;
    my $external_ip_address;
    my $reply;
    my $count = 0;

    for ( 1 .. 3 ) {
        local $SIG{'ALRM'} = sub {
            $count++;
            print_warn( 'NAT check timed out: ' );
            print_warning( "attempt $count of 3" );
        };
        alarm 3;

        my $sock = IO::Socket::INET->new(
            PeerAddr    => 'cpanel.net',
            PeerPort    => '80',
            Proto       => 'tcp',
            Timeout     => 3,
        );

        if ( $sock ) {
            print $sock "GET /showip.cgi HTTP/1.0\r\n\r\n";
            sysread $sock, $reply, 1000;
            close $sock;
        }

        if ( $reply =~ m{ (\d+\.\d+\.\d+\.\d+) }xms ) {
            $external_ip_address = $1;
        }        

        if ( $external_ip_address ) {
            chomp $external_ip_address;
        }
        alarm 0;

        if ( $external_ip_address ) {
            last;
        }
    }

    if ( $external_ip_address =~ m{ \A \d+\.\d+\.\d+\.\d+ }xms ) {
        if ( ! grep { /$external_ip_address/ } @local_ipaddrs_list ) {
            print_warn( 'NAT: ' );
            print_warning( "external IP address $external_ip_address is not bound to server" );
        }
    }
    else {
        for my $ipaddr ( @local_ipaddrs_list ) {
            if ( $ipaddr !~ m{ \A ( ?: 127\. | 192\.168\. | 10\. | 172\.(1[6-9]|2[0-9]|3[0-1]) ) }xms ) {
                push @external_ipaddrs, $ipaddr;
            }
        }
        if ( !@external_ipaddrs ) {
            print_warn( 'NAT: ' );
            print_warning( 'no external IP addresses detected' );
        }
    }
}

sub check_for_oracle_linux {
    my $centos_5_oracle_release_file = '/etc/enterprise-release';
    my $centos_6_oracle_release_file = '/etc/oracle-release';

    if ( -f $centos_5_oracle_release_file ) {
        print_warn( 'Oracle Linux: ' );
        print_warning( "$centos_5_oracle_release_file detected!" );
    }
    elsif ( -f $centos_6_oracle_release_file ) {
        print_warn( 'Oracle Linux: ' );
        print_warning( "$centos_6_oracle_release_file detected!" );
    }
}

sub check_for_usr_local_cpanel_hooks {
    my $hooks;
    my $dir = '/usr/local/cpanel/hooks';
    find( \&find_usr_local_cpanel_hooks, $dir );

    # default CloudLinux hooks that can be ignored
    my %hooks_ignore = qw(
        677da3bdd8fbd16d4b8917a9fe0f6f89    /usr/local/cpanel/hooks/addondomain/addaddondomain
        677da3bdd8fbd16d4b8917a9fe0f6f89    /usr/local/cpanel/hooks/addondomain/deladdondomain
        677da3bdd8fbd16d4b8917a9fe0f6f89    /usr/local/cpanel/hooks/subdomain/addsubdomain
        677da3bdd8fbd16d4b8917a9fe0f6f89    /usr/local/cpanel/hooks/subdomain/delsubdomain
    );

    if ( @usr_local_cpanel_hooks ) {
        for my $hook ( @usr_local_cpanel_hooks ) {
            my $tmp_hook = '/usr/local/cpanel/hooks/' . $hook;
            if ( -f $tmp_hook and ! -z $tmp_hook ) {
                unless ( $os eq 'freebsd' ) {
                    chomp( my $checksum = run( 'md5sum', $tmp_hook ) );
                    $checksum =~ s/\s.*//g;
                    next if exists $hooks_ignore{$checksum};
                    $hooks .= "$hook ";
                }
            }
        }
    }

    if ( $hooks ) {
        print_warn( "$dir: " );
        print_warning( $hooks );
    }
}

sub find_usr_local_cpanel_hooks {
    my $file = $File::Find::name;
    if ( -f $file and $file !~ m{ ( README | \.example ) \z }xms ) {
        $file =~ s#/usr/local/cpanel/hooks/##;
        push @usr_local_cpanel_hooks, $file;
    }
}

sub check_for_sql_safe_mode {
    my @phpinis = qw( /usr/local/lib/php.ini /usr/local/php4/lib/php.ini );

    for my $phpini ( @phpinis ) {
        if ( open my $file_fh, '<', $phpini ) {
            while ( <$file_fh> ) {
                chomp( my $line = $_ );
                if ( $line =~ m{ \A sql\.safe_mode \s* = \s* on }ixms ) {
                    print_warn( "$phpini: " );
                    print_warning( 'sql.safe_mode is enabled!' );
                }
            }
            close $file_fh;
        }
    }
}

sub get_mysql_datadir {
    my $my_cnf = '/etc/my.cnf';
    my $mysql_datadir = '/var/lib/mysql/';

    if ( open my $my_cnf_fh, '<', $my_cnf ) {
        while ( <$my_cnf_fh> ) {
            chomp ( my $line = $_ );
            if ( $line =~ m{ \A datadir \s* = \s* (?:["']?) ([^"']+) }xms ) {
                $mysql_datadir = $1;
                last;
            }
        }
        close $my_cnf_fh;
    }

    return $mysql_datadir;
}

sub check_mysql_non_default_datadir {
    if ( $mysql_datadir !~ m{ /var/lib/mysql(/?) \z }xms ) {
        print_warn( 'MySQL non-default datadir: ' );
        print_warning( $mysql_datadir );
    }
}

sub check_for_domain_forwarding {
    my $domainfwdip = '/var/cpanel/domainfwdip';

    if ( -f $domainfwdip and ! -z $domainfwdip ) {
        print_warn( 'Domain Forwarding: ' );
        print_warning( "cat $domainfwdip to see what is being forwarded!" );
    }
}

sub check_for_empty_apache_templates {
    my $apache2_template_dir = '/var/cpanel/templates/apache2';
    my @dir_contents;
    my $empty_templates;

    if ( -d $apache2_template_dir ) {
        opendir( my $dir_fh, $apache2_template_dir );
        @dir_contents = grep { ! /^\.(\.?)$/ } readdir $dir_fh;
        closedir $dir_fh;
    }    

    if ( ! @dir_contents ) {
        print_warn( 'Apache templates: ' );
        print_warning( "none found in $apache2_template_dir !" );
    }
    else {
        for my $template ( @dir_contents ) {
            if ( -z "$apache2_template_dir/$template" ) {
                $empty_templates .= "$template ";
            }
        }
    }

    if ( $empty_templates ) {
        print_warn( "Empty Apache templates in $apache2_template_dir (this can affect the ability to remove domains): ");
        print_warning( "$empty_templates" );
    }
}

sub check_for_empty_postgres_config {
    my $postgres_config = '/var/lib/pgsql/data/pg_hba.conf';
    if ( -f $postgres_config and -z $postgres_config ) {
        print_warn( 'Postgres config: ' );
        print_warning( "$postgres_config is empty (install via WHM >> Postgres Config)" );
    }
}

sub check_for_empty_easyapache_profiles {
    my $templates;
    my $dir = '/var/cpanel/easy/apache/profile';
    find( \&find_easyapache_templates, $dir );

    if ( @easyapache_templates ) {
        for my $template ( @easyapache_templates ) {
            $templates .= "$template ";
        }

        print_warn( "Empty template(s) in $dir: " );
        print_warning( $templates );
    }    
}

sub find_easyapache_templates {
    my $file = $File::Find::name;
    if ( -f $file and -z $file ) {
        $file =~ s#/var/cpanel/easy/apache/profile/##g;
        push @easyapache_templates, $file;
    }    
}

sub check_for_missing_timezone_from_phpini {
    my $phpini = '/usr/local/lib/php.ini';

    return if ! -f $phpini;

    my $timezone;

    if ( open my $phpini_fh, '<', $phpini ) {
        while ( <$phpini_fh> ) {
            my $line = $_;
            chomp $line;
            if ( $line =~ m{ \A date\.timezone (?:\s+)? = (?:\s+)? (?:["'])? ([^/"']+) / ([^/"']+) (?:["'])? (?:\s+)? \z }xms ) {
                $timezone = $1 . '/' . $2;
                last;
            }
        }
        close $phpini_fh;
    }

    if ( $timezone ) {
        my ( $tz1, $tz2 ) = split /\//, $timezone;
        my $path = '/usr/share/zoneinfo/' . $tz1 . '/' . $tz2;

        if ( ! -f $path ) {
            print_warn( "date.timezone from $phpini: ");
            print_warning( "$path not found!" );
        }
    }
}

sub check_for_proc_mdstat_recovery {
    my $mdstat = '/proc/mdstat';

    my $recovery = 0;

    if ( open my $mdstat_fh, '<', $mdstat ) {
        while ( <$mdstat_fh> ) {
            if ( /recovery/ ) {
                $recovery = 1;
                last;
            }
        }
        close $mdstat_fh;
    }

    if ( $recovery == 1 ) {
        print_warn( 'Software RAID recovery: ' );
        print_warning( "cat $mdstat to check the status" );
    }
}

sub check_usr_local_cpanel_path_for_symlinks {
    my @dirs = qw(  /usr
                    /usr/local
                    /usr/local/cpanel
               );

    for my $dir ( @dirs ) {
        if ( -l $dir ) {
            print_warn( 'Directory is a symlink: ');
            print_warning( "$dir (this can cause Internal Server Errors for redirects like /cpanel, etc)" );
        }
    }
}

sub populate_mysql_rpm_versions_array {
    return if ! @rpm_list;

    for my $rpm ( @rpm_list ) {
        if ( $rpm =~ m{ \A MySQL-server-(.*) \z }xms ) {
            push @mysql_rpm_versions, $1;
        }
        elsif ( $rpm =~ m{ \A MySQL-shared-(.*) \z }xms ) {
            push @mysql_rpm_versions, $1;
        }
        elsif ( $rpm =~ m{ \A MySQL-devel-(.*) \z }xms ) {
            push @mysql_rpm_versions, $1;
        }    
        elsif ( $rpm =~ m{ \A MySQL-client-(.*) \z }xms ) {
            push @mysql_rpm_versions, $1;
        }
        elsif ( $rpm =~ m{ \A MySQL-test-(.*) \z }xms ) {
            push @mysql_rpm_versions, $1;
        }
        elsif ( $rpm =~ m{ \A MySQL-embedded-(.*) \z }xms ) {
            push @mysql_rpm_versions, $1;
        }
    }    
}

sub check_for_mysql_4 {
    return if ! @mysql_rpm_versions;

    my $mysql_4 = 0;

    for my $rpm ( @mysql_rpm_versions ) {
        if ( $rpm =~ m{ \A 4 }xms ) {
            $mysql_4 = 1;
            last;
        }
    }

    if ( $mysql_4 == 1 ) {
        print_warn( 'MySQL 4.x RPM: ' );
        print_warning( 'found! This can interfere with cPanel updates' );
    }
}

sub check_for_additional_rpms {
    return if ! @rpm_list;

    my @additional_rpms = grep { /^(php-|kde-|psa-|clamav|clamd|rrdtool-)|(http|apache|pear|sendmail)/ } @rpm_list;
    if ( @additional_rpms ) {
        @additional_rpms = sort @additional_rpms;
        for my $additional_rpm ( @additional_rpms ) {
            next if ( $additional_rpm =~ /sendmail-(cf|doc|devel)-|httpd-tools|cpanel-|alt-php/ );
            print_start( 'Additional RPM: ' );
            print_warning( $additional_rpm );
        }
    }    
}

sub check_mysql_rpm_mismatch {
    return if ! @rpm_list;

    my $first_rpm = pop @mysql_rpm_versions;
    for ( 1 .. scalar @mysql_rpm_versions ) {
        my $next_rpm = pop @mysql_rpm_versions;
        if ( $first_rpm ne $next_rpm ) {
            print_warn( 'MySQL RPMs: ' );
            print_warning( 'version mismatch!' );
            last;
        }
    }    
}

sub check_php_libmysqlclient_mismatch {
    return if ! @rpm_list;

    my ( @php4_ldd, @php5_ldd );
    my ( $php4_libmysqlclient_version, $php5_libmysqlclient_version );

    my $php4_binary = '/usr/local/php4/bin/php';
    my $php5_binary = '/usr/bin/php';

    my $php4_mismatch = 0;
    my $php5_mismatch = 0;
    
    my $mysql_shared_rpm_version_orig;
    my $mysql_shared_rpm_version;

    ## Get the MySQL-shared rpm major and minor version.
    for my $rpm ( @rpm_list ) {
        if ( $rpm =~ /MySQL-shared-(\d)\.(\d)/ ) {
            $mysql_shared_rpm_version_orig = $rpm;
            $mysql_shared_rpm_version = $1 . $2;
            last;
        }
    }

    return if ! $mysql_shared_rpm_version;

    ## Run ldd against whichever major php version is active
    if ( open my $phpconfyaml_fh, '<', '/usr/local/apache/conf/php.conf.yaml' ) {
        while ( my $line = <$phpconfyaml_fh> ) {
            if ( $line =~ m{ \A php4: \s (.*) }xms ) {
                if ( $1 ne 'none' ) {
                    @php4_ldd = split /\n/, run( 'ldd', $php4_binary );
                }
            }
            elsif ( $line =~ m{ \A php5: \s (.*) }xms ) {
                if ( $1 ne 'none' ) {
                    @php5_ldd = split /\n/, run( 'ldd', $php5_binary );
                }
            }
        }
        close $phpconfyaml_fh;
    }

    ## Get the linked libmysqlclient version
    if ( @php4_ldd ) {
        for my $libs ( @php4_ldd ) {
            if ( $libs =~ m{ \A \s+ libmysqlclient\.so\.(\d+) \s => \s (?:\S+) \s (?:\S+) \z }xms ) {
                $php4_libmysqlclient_version = $1;
                last;
            }
        }
    }

    if ( @php5_ldd ) {
        for my $libs ( @php5_ldd ) {
            if ( $libs =~ m{ \A \s+ libmysqlclient\.so\.(\d+) \s => \s (?:\S+) \s (?:\S+) \z }xms ) {
                $php5_libmysqlclient_version = $1;
                last;
            }
        }
    }

    ## Compare the linked libmysqlclient lib with the MySQL-shared rpm version
    ##
    ## libmysqlclient.so.18 = MySQL-shared 5.5
    ## libmysqlclient.so.16 = MySQL-shared 5.1
    ## libmysqlclient.so.15 = MySQL-shared 5.0

    if ( $php4_libmysqlclient_version ) {
        if ( $php4_libmysqlclient_version == 18 and $mysql_shared_rpm_version != 55 ) {
            $php4_mismatch = 1;
        }
        elsif ( $php4_libmysqlclient_version == 16 and $mysql_shared_rpm_version != 51 ) {
            $php4_mismatch = 1;
        }
        elsif ( $php4_libmysqlclient_version == 15 and $mysql_shared_rpm_version != 50 ) {
            $php4_mismatch = 1;
        }

        if ( $php4_mismatch == 1 ) {
            print_warn( 'PHP/libmysqlclient mismatch: ' );
            print_warning( "$php4_binary linked against libmysqlclient.so.$php4_libmysqlclient_version, but MySQL-shared rpm is $mysql_shared_rpm_version_orig" );
        }
    }

    if ( $php5_libmysqlclient_version ) {
        if ( $php5_libmysqlclient_version == 18 and $mysql_shared_rpm_version != 55 ) {
            $php5_mismatch = 1;
        }
        elsif ( $php5_libmysqlclient_version == 16 and $mysql_shared_rpm_version != 51 ) {
            $php5_mismatch = 1;
        }
        elsif ( $php5_libmysqlclient_version == 15 and $mysql_shared_rpm_version != 50 ) {
            $php5_mismatch = 1;
        }

        if ( $php5_mismatch == 1 ) {
            print_warn( 'PHP/libmysqlclient mismatch: ' );
            print_warning( "$php5_binary linked against libmysqlclient.so.$php5_libmysqlclient_version, but MySQL-shared rpm is $mysql_shared_rpm_version_orig" );
        }
    }
}

sub check_for_system_mem_below_512M {
    if ( $os eq 'freebsd' ) {
        my $memtotal = run( 'sysctl', 'hw.realmem' );

        if ( $memtotal =~ m{ \A hw\.realmem: \s (\d+) }xms ) {
            $memtotal = $1 / 1024 / 1024;
        }

        if ( $memtotal < 512 ) {
            print_warn( 'Memory: ' );
            print_warning( "Server has less than 512M physical memory! [$memtotal MB]" );
        }

        return;
    }

    my $meminfo = '/proc/meminfo';
    my $memtotal;

    if ( open my $meminfo_fh, '<', $meminfo ) {
        while ( <$meminfo_fh> ) {
            if ( m{ \A MemTotal: \s+ (\d+) \s+ kB \s+ \z }xms ) {
                $memtotal = $1 / 1024;
            }
        }
        close $meminfo_fh;
    }

    if ( $memtotal < 512 ) {
        print_warn( 'Memory: ' );
        print_warning( "Server has less than 512M physical memory! [$memtotal MB]" );
    }
}


## This is already fixed: http://rhn.redhat.com/errata/RHBA-2012-1158.html
sub check_for_options_rotate_redhat_centos_63 {
    my $sysinfo_config = '/var/cpanel/sysinfo.config';
    my $os_release;
    my $resolv_conf = '/etc/resolv.conf';
    my $options_rotate = 0;

    if ( open my $sysinfo_config_fh, '<', $sysinfo_config ) {
        while ( my $line = <$sysinfo_config_fh> ) {
            if ( $line =~ m{ \A release=(\d\.\d) }xms ) {
                $os_release = $1;
                last;
            }
        }
        close $sysinfo_config_fh;
    }

    if ( $os_release and $os_release eq '6.3' ) {
        if ( open my $resolv_conf_fh, '<', $resolv_conf ) {
            while ( my $line = <$resolv_conf_fh> ) {
                if ( $line =~ m{ options \s+ rotate }xms ) {
                    $options_rotate = 1;
                    last;
                }
            }
            close $resolv_conf_fh;
        }
    }

    if ( $options_rotate == 1 ) {
        print_warn( 'RH/CentOS 6.3 resolv.conf: ' );
        print_warning( 'contains "options rotate", can break lookups. See FB 60347. Already fixed upstream.' );
    }
}

sub check_pecl_phpini_location {
    my $pecl_phpini = run( 'pecl', 'config-get', 'php_ini' );
    chomp $pecl_phpini;
    if ( $pecl_phpini and $pecl_phpini =~ /cpanel/ ) {
        print_warn( 'pecl php.ini: ' );
        print_warning( "'pecl config-get php_ini' shows php.ini path of $pecl_phpini . See FB 59764 for more info" );
    }
}

sub check_for_empty_yumconf {
    return if ( $os eq 'freebsd' );

    my $yumconf = '/etc/yum.conf';

    if ( ! -e $yumconf ) {
        print_warn( 'YUM: ' );
        print_warning( "$yumconf is missing!" );
    }
    elsif ( -z $yumconf ) {
        print_warn( 'YUM: ' );
        print_warning( "$yumconf is empty!" );
    }
}

sub check_for_cpanel_files {
    my @files = qw(
                /usr/local/cpanel/cpanel
                /usr/local/cpanel/cpsrvd
                /usr/local/cpanel/cpsrvd-ssl
                );

    for my $file ( @files ) {
        if ( ! -e $file ) {
            print_warn( 'Critical file missing: ' );
            print_warning( "$file" );
        }
    }
}

sub check_bash_history_for_certain_commands {
    my $bash_history = '/root/.bash_history';
    my %history_commands = ();
    my $commands;

    if ( -l $bash_history ) {
        my $link = readlink $bash_history;
        print_warn( "$bash_history: " );
        print_warning( "is a symlink! Linked to $link" );
    }
    elsif ( -f $bash_history ) {
        if ( open my $history_fh, '<', $bash_history ) {
            while ( <$history_fh> ) {
                if ( /chattr/ ) {
                    $history_commands{'chattr'} = 1;
                }
                if ( /chmod/ ) {
                    $history_commands{'chmod'} = 1;
                }
                if ( /openssl(?:.*)\.tar/ ) {
                    $history_commands{'openssl*.tar'} = 1;
                }
            }
            close $history_fh;
        }
    }

    if ( %history_commands ) {
        while ( my ( $key, $value ) = each ( %history_commands ) ) {
            $commands .= "[$key] ";
        }

        print_warn( "$bash_history commands found: " );
        print_warning( $commands );
    }
}

sub check_wwwacctconf_for_incorrect_minuid {
    my $wwwacctconf = '/etc/wwwacct.conf';
    my $minuid;

    if ( open my $wwwacctconf_fh, '<', $wwwacctconf ) {
        while ( <$wwwacctconf_fh> ) {
            if ( /^MINUID\s(\d+)$/ ) {
                $minuid = $1;
            }
        }
        close $wwwacctconf_fh;
    }

    if ( $minuid and $minuid =~ /\d+/ ) {
        if ( $minuid < 500 or $minuid > 60000 ) {
            print_warn( 'MINUID: ' );
            print_warning( "$wwwacctconf has a MINUID value of $minuid (should be between 500 and 60000)" );
        }
    }
}

sub check_roots_cron_for_certain_commands {
    my $cron;

    if ( $os eq 'linux' ) {
        $cron = '/var/spool/cron/root';
    }
    elsif ( $os eq 'freebsd' ) {
        $cron = '/var/cron/tabs/root';
    }

    return if ! -e $cron;

    my %commands = ();
    my $commands;

    if ( open my $cron_fh, '<', $cron ) {
        while ( <$cron_fh> ) {
            if ( m{ \A [^#]+ (\s|\/)rm\s }xms ) {
                $commands{'rm'} = 1;
            }
            if ( m{ \A [^#]+ (\s|\/)unlink\s }xms ) {
                $commands{'unlink'} = 1;
            }
            if ( m{ \A [^#]+ (\s|\/)chmod\s }xms ) {
                $commands{'chmod'} = 1;
            }
            if ( m{ \A [^#]+ (\s|\/)chown\s }xms ) {
                $commands{'chown'} = 1;
            }
            if ( m{ \A [^#]+ (\s|\/)chattr\s }xms ) {
                $commands{'chattr'} = 1;
            }
            if ( m{ \A [^#]+ (\s|\/)kill\s }xms ) {
                $commands{'kill'} = 1;
            }
            if ( m{ \A [^#]+ (\s|\/)pkill\s }xms ) {
                $commands{'pkill'} = 1;
            }
            if ( m{ \A [^#]+ (\s|\/)skill\s }xms ) {
                $commands{'skill'} = 1;
            }
        }
        close $cron_fh;
    }

    if ( %commands ) {
        while ( my ( $key, $value ) = each ( %commands ) ) {
            $commands .= "[$key] ";
        }

        print_warn( "$cron commands found: " );
        print_warning( $commands );
    }
}

sub check_for_missing_or_commented_customlog {
    my $apache_version;
    my $templates_dir = '/var/cpanel/templates/apache';
    my $commented_templates;
    my $missing_customlog_templates;
    my $httpdconf = '/usr/local/apache/conf/httpd.conf';
    my $httpdconf_commented_customlog;
    my $httpdconf_customlog_exists;

    if ( @apache_version_output ) {
        for my $line ( @apache_version_output ) {
            if ( $line =~ m{ \A Server \s version: \s Apache/(\d) (?:.*) \z }xms ) {
                $apache_version = $1;
            }
        }
    }

    return if ! $apache_version;
    $apache_version == 1 ? $templates_dir .= 1 : $templates_dir .= 2;

    my %templates = (
        'main.default'      => 0,
        'main.local'        => 0,
        'vhost.default'     => 0,
        'vhost.local'       => 0,
        'ssl_vhost.default' => 0,
        'ssl_vhost.local'   => 0,
    );

    for my $template ( keys %templates ) {
        my $template_full_path = $templates_dir . '/' . $template;
        if ( -f $template_full_path ) {
            if ( open my $template_fh, '<', $template_full_path ) {
                while ( <$template_fh> ) {
                    if ( /#(?:\s+)?CustomLog\s/i ) {
                        $commented_templates .= "$template_full_path ";
                        $templates{$template} = 1;
                        last;
                    }
                    elsif ( /CustomLog\s/i ) {
                        $templates{$template} = 1;
                    }
                }
                close $template_fh;
            }
        }
    }

    while ( my ( $template, $value ) = each ( %templates ) ) {
        if ( $value == 0 and -f "$templates_dir/$template" ) {
            $missing_customlog_templates .= "$templates_dir/$template ";
        }
    }

    if ( open my $httpdconf_fh, '<', $httpdconf ) {
        while ( <$httpdconf_fh> ) {
            if ( /#(?:\s+)?CustomLog\s/i ) {
                $httpdconf_commented_customlog = 1;
                last;
            }
            elsif ( /CustomLog\s/i ) {
                $httpdconf_customlog_exists = 1;
            }
        }
        close $httpdconf_fh;
    }

    if ( $httpdconf_commented_customlog ) {
        $commented_templates .= ' httpd.conf';
    }
    elsif ( !$httpdconf_customlog_exists ) {
        $missing_customlog_templates .= ' httpd.conf';
    }

    if ( $commented_templates ) {
        print_warn( 'CustomLog commented out: ' );
        print_warning( $commented_templates );
    }

    if ( $missing_customlog_templates ) {
        print_warn( 'CustomLog entries missing: ' );
        print_warning( $missing_customlog_templates );
    }
}

sub check_for_cpsources_conf {
    my $cpsources_conf = '/etc/cpsources.conf';

    if ( -f $cpsources_conf and ! -z $cpsources_conf ) {
        print_warn( '/etc/cpsources.conf: ' );
        print_warning( 'exists!' );
    }
}

sub check_for_apache_rlimits {
    my $httpdconf = '/usr/local/apache/conf/httpd.conf';
    my ( $rlimitmem, $rlimitcpu );
    my $output;

    if ( open my $httpdconf_fh, '<', $httpdconf ) {
        while ( <$httpdconf_fh> ) {
            if ( /^RLimitMEM (\d+)/ ) {
                $rlimitmem = $1;
            }
            if ( /^RLimitCPU (\d+)/ ) {
                $rlimitcpu = $1;
            }
        }
        close $httpdconf_fh;
    }

    if ( $rlimitmem ) {
        my $rlimitmem_converted = sprintf('%.0f MB', $rlimitmem / 1024 / 1024);
        $output = "RLimitMEM $rlimitmem [$rlimitmem_converted]";
    }

    if ( $rlimitcpu ) {
        $output .= " RLimitCPU $rlimitcpu";
    }

    if ( $output ) {
        print_warn( 'Apache RLimits: ' );
        print_warning( $output );
    }
}

sub check_cron_processes {
    my $crond_is_running = 0;
    my $number_of_cron_processes = 0;

    for my $process ( @process_list ) {
        if ( $os eq 'linux' ) {
            if ( $process =~ m{ \A root (?:.*) crond }xms ) {
                $crond_is_running = 1;
                $number_of_cron_processes += 1;
            }
        }
        elsif ( $os eq 'freebsd' ) {
            if ( $process =~ m{ \A root (?:.*) cron }xms ) {
                $crond_is_running = 1;
                $number_of_cron_processes += 1;
            }
        }
    }

    if ( $crond_is_running == 0 ) {
        print_warn( 'crond: ' );
        print_warning( 'not found in the process list!' );
    }
    elsif ( $number_of_cron_processes > 1 ) {
        print_warn( 'crond: ' );
        print_warning( 'multiple cron processes found; this can cause "Cpanel update hanging" emails' );
    }
}

sub check_for_usr_local_lib_libz_so {
    if ( -f '/usr/local/lib/libz.so' ) {
        print_warn( '/usr/local/lib/libz.so: ' );
        print_warning( 'exists. This can prevent EA from completing' );
    }
}

sub check_for_non_default_modsec_rules {
    my $modsec_enabled = 0;

    my $modsec2_conf        = '/usr/local/apache/conf/modsec2.conf';
    my $modsec2_user_conf   = '/usr/local/apache/conf/modsec2.user.conf';
    my $modsec_rules_dir    = '/usr/local/apache/conf/modsec_rules';

    for my $module ( @apache_modules_output ) {
        if ( $module =~ /security2_module/ ) {
            $modsec_enabled = 1;
            last;
        }
    }

    return if ( $modsec_enabled == 0 );

    if ( -f $modsec2_conf ) {
        ## On 11.32.5.9 with EA v3.14.13, default modsec2.conf is 650 bytes.
        ## It's always been small in size.
        my $modsec2_conf_size = ( stat( $modsec2_conf ))[7];
        my $modsec2_conf_max_size = 1200;
        if ( $modsec2_conf_size > $modsec2_conf_max_size ) {
            print_warn( 'modsec: ' );
            print_warning( "$modsec2_conf is > $modsec2_conf_max_size bytes, may contain custom rules" );
        }
    }

    if ( -f $modsec2_user_conf ) {
        my $modsec2_user_conf_size = ( stat( $modsec2_user_conf ))[7];
        if ( $modsec2_user_conf_size != 0 ) {
            print_warn( 'modsec: ' );
            print_warning( "$modsec2_user_conf is not empty, may contain rules" );
        }
    }

    if ( -d $modsec_rules_dir ) {
        print_warn( 'modsec: ' );
        print_warning( "$modsec_rules_dir exists, 3rd party rules may be in use" );
    }
}

sub check_etc_hosts_sanity {
    my $hosts = '/etc/hosts';
    my $localhost = 0;
    my $httpupdate = 0;
    my $localhost_not_127 = 0;
    my $hostname_entry = 0;

    if ( ! -f $hosts ) {
        print_warn( '/etc/hosts: ' );
        print_warning( 'missing!' );
        return;
    }    
    else {
        if ( open my $hosts_fh, '<', $hosts ) {
            while ( my $line = <$hosts_fh> ) {
                chomp $line;

                next if ( $line =~ /^(\s+)?#/ );

                if ( $line =~ m{  127\.0\.0\.1 (.*) localhost }xms )  {
                    $localhost = 1; 
                }
                if ( ( $line =~ m{ \s localhost (\s|\z) }xmsi ) and ( $line !~ m{ 127\.0\.0\.1 | ::1 }xms ) ) {
                    $localhost_not_127 = 1;
                }
                if ( $line =~ m{ httpupdate\.cpanel\.net }xmsi ) {
                    $httpupdate = 1;
                }
                if ( $line =~ m{ $hostname }xmsi ) {
                    $hostname_entry = 1;
                }
            }
            close $hosts_fh;
        }
    }    

    if ( $localhost == 0 ) {
        print_warn( '/etc/hosts: ' );
        print_warning( 'no entry for localhost, or commented out' );
    }    

    if ( $httpupdate == 1 ) {
        print_warn( '/etc/hosts: ' );
        print_warning( 'contains an entry for httpupdate.cpanel.net' );
    }

    if ( $localhost_not_127 == 1 ) {
        print_warn( '/etc/hosts: ' );
        print_warning( 'contains an entry for "localhost" that isn\'t 127.0.0.1 ! This can break EA' );
    }

    if ( $hostname_entry == 0 ) {
        print_warn( '/etc/hosts: ' );
        print_warning( "no entry found for the server's hostname! [$hostname]" );
    }
}

sub check_for_empty_or_missing_files {
    opendir( my $dir_fh, '/var/cpanel/users' );
    my @dir_contents = grep { ! /^\.(\.?)$/ } readdir $dir_fh;
    closedir $dir_fh;

    # if there are no users on the box, don't warn about userdatadomains
    return if scalar @dir_contents == 0;

    my $userdatadomains = '/etc/userdatadomains';

    if ( ! -e $userdatadomains ) {
        print_warn( 'Missing file: ' );
        print_warning( $userdatadomains );
    }
    elsif ( -f $userdatadomains and -z $userdatadomains ) {
        print_warn( 'Empty file: ' );
        print_warning( "$userdatadomains (generate it with /scripts/updateuserdatacache --force)" );
    }
}

sub check_for_apache_listen_host_is_localhost {
    my $cpanel_config = '/var/cpanel/cpanel.config';
    my $localhost_80;

    return if ! $cpanel_config;

    if ( open my $cpanel_config_fh, '<', $cpanel_config ) {
        while ( <$cpanel_config_fh> ) {
            if ( /^apache_port=(\d+\.\d+\.\d+\.\d+):(?:\d+)/ ) {
                if ( $1 eq '127.0.0.1' ) {
                    $localhost_80 = 1;
                }
            }
        }
        close $cpanel_config_fh;
    }

    if ( $localhost_80 ) {
        print_warn( 'Apache listen host: ' );
        print_warning( 'Apache may only be listening on 127.0.0.1' );
    }
}

sub check_roundcube_mysql_pass_mismatch {
    my $roundcube_mysql = 0;
    my $roundcubepass;
    my $rc_mysql_pass;

    if ( open my $cpanelconf_fh, '<', '/var/cpanel/cpanel.config' ) {
        while ( <$cpanelconf_fh> ) {
            if ( /roundcube_db=mysql/ ) {
                $roundcube_mysql = 1;
                last;
            }
        }
        close $cpanelconf_fh;
    }

    return if ( $roundcube_mysql == 0 );

    if ( open my $rc_pass_fh, '<', '/var/cpanel/roundcubepass' ) {
        while ( <$rc_pass_fh> ) {
            chomp( $roundcubepass = $_ );
        }
        close $rc_pass_fh;
    }
    else {
        return;
    }

    if ( open my $db_inc_fh, '<', '/usr/local/cpanel/base/3rdparty/roundcube/config/db.inc.php' ) {
        while ( <$db_inc_fh> ) {
            if ( m{ \A \$rcmail_config\['db_dsnw'\] \s = \s 'mysql://roundcube:(.*)\@(?:.*)/roundcube';  }xms ) {
                $rc_mysql_pass = $1;
            }
        }
        close $db_inc_fh;
    }
    else {
        return;
    }

    if ( ! $roundcubepass or ! $rc_mysql_pass ) {
        return;
    }

    if ( $roundcubepass ne $rc_mysql_pass ) {
        print_warn( 'RoundCube: ' );
        print_warning( 'password mismatch [/var/cpanel/roundcubepass] [/usr/local/cpanel/base/3rdparty/roundcube/config/db.inc.php]' );
    }
}

sub check_for_extra_uid0_pwcache_file {
    if ( -f '/var/cpanel/pw.cache/2:0' ) {
        print_warn( 'MySQL: ' );
        print_warning( '/var/cpanel/pw.cache/2:0 exists. If MySQL shows as offline in cPanel, please update FB 59670' );
    }
}

sub check_for_11_30_scripts_not_a_symlink {
    my ( $cpanel_version, $cpanel_version_orig );

    if ( open my $cpanel_version_fh, '<', '/usr/local/cpanel/version' ) {
        while ( <$cpanel_version_fh> ) {
            chomp( $cpanel_version = $_ );
        }
        close $cpanel_version_fh;
    }    

    $cpanel_version_orig = $cpanel_version;
    $cpanel_version =~ s/\.//g;
    $cpanel_version = substr( $cpanel_version, 0, 4 );
    
    if ( $cpanel_version >= 1130 ) {
        if ( ! -l '/scripts' ) {
            print_warn( '/scripts: ' );
            print_warning( "cPanel is >= 11.30 [$cpanel_version_orig] and /scripts is not a symlink" );
        }
    }
}

# ripped some of Cpanel::Sys::GetOS::getos() for this
sub check_for_cpanel_not_updating {
    my $os_vendor;
    my $release_string;
    my ( $cpanel_version, $cpanel_version_orig );
    my $updates;
    my @release_files = qw(
        fedora-release
        whitebox-release
        trustix-release
        caos-release
        gentoo-release
        SuSE-release
        mandrake-release
        CentOS-release
        redhat-release
        debian_version
    );

    if ( $^O =~ /freebsd/i ) {
        $os_vendor = 'freebsd';
    }
    else {
        for my $release_file ( @release_files ) {
            if ( -e '/etc/' . $release_file ) { 
                if ( ( ( $os_vendor ) = $release_file =~ m/^([^\-_]+)/ )[0] ) { 
                    $os_vendor              = lc $os_vendor;
                    last;
                }
            }
        }
    }        

    ## Ignore FBSD, Fedora, RHEL 3-4, Redhat 7-9
    return if ( $os_vendor =~ /(freebsd|fedora)/ );

    if ( -f '/etc/redhat-release' ) {
        if ( open my $rr_fh, '<', '/etc/redhat-release' ) {
            $release_string = readline $rr_fh;
            close $rr_fh;
        }
        else {
            $release_string = 'unknown';
        }
    }

    return if ( $release_string =~ /Red Hat Enterprise Linux (?:.*) release (3|4)/ );
    return if ( $release_string =~ /Red Hat Linux release ([7-9])/ );


    if ( open my $cpanel_version_fh, '<', '/usr/local/cpanel/version' ) {
        $cpanel_version = readline $cpanel_version_fh;
        $cpanel_version_orig = $cpanel_version;
        $cpanel_version =~ s/\.//g;
        $cpanel_version = substr( $cpanel_version, 0, 4 );
        close $cpanel_version_fh;
    }
    else {
        $cpanel_version = 'unknown'
    }

    if ( open my $cpupdate_conf_fh, '<', '/etc/cpupdate.conf' ) {
        while ( <$cpupdate_conf_fh> ) {
            if ( /UPDATES=(.*)/ ) {
                $updates = lc $1;
                last;
            }
        }
        close $cpupdate_conf_fh;
    }

    $updates = 'unknown' if ! $updates;


    ## TEST 1: cPanel < 11.29, updates set to daily
    if ( $cpanel_version < 1129 ) {
        if ( $updates eq 'daily' ) {
            print "\n!! cPanel may not be updating on this server !!\n";
            print_warn( 'L1/L2: ' );
            print_warning( 'escalate the ticket to L3 now' );
            print_warn( 'L3: ' );
            print_warning( 'check cP updatelogs, see why cPanel isn\'t updated, try to update if needed. Escalate to L4 if it can\'t update' );
            print "\n\n";
        }
    }
    ## TEST 2: cPanel >= 11.29, updates set to daily, not updated in >= 24 hours
    ## Check removed for now due to false positives
}

sub check_for_hooks_from_var_cpanel_hooks_yaml {
    my $hooks_yaml = '/var/cpanel/hooks.yaml';
    my ( @hooks_tmp, @hooks );

    if ( open my $file_fh, '<', $hooks_yaml ) {
        while ( <$file_fh> ) {
            if ( /hook: (.*)/ ) {
                # Ignore default Attracta hooks
                next if ( $1 =~ m{ \A ( /usr/local/cpanel/3rdparty/attracta/scripts/pkgacct-restore | /usr/local/cpanel/Cpanel/ThirdParty/Attracta/Hooks/pkgacct-restore ) \z }xms );
                push @hooks_tmp, "$1 ";
            }
        }
        close $file_fh;
    }

    for my $hook ( @hooks_tmp ) {
        if ( -e $hook and ! -z $hook ) {
            push @hooks, $hook;
        }
    }

    if ( scalar @hooks == 1 ) {
        print_warn( 'Hooks in /var/cpanel/hooks.yaml: ' );
        print_warning( @hooks );
    }
    elsif ( scalar @hooks > 1 ) {
        print_warn( "Hooks in /var/cpanel/hooks.yaml:\n" );
        for my $hook ( @hooks ) {
            print_magenta( "\t \\_ $hook" );
        }
    }
}

sub get_mysql_error_log {
    if ( open my $file_fh, '<', '/etc/my.cnf' ) {
        while ( <$file_fh> ) {
            if ( m{ \A log-error \s? = \s? (.*) \z }xms ) {
                $mysql_error_log = $1;
                $mysql_error_log =~ s/\"//g;
                $mysql_error_log =~ s/\'//g;
                chomp $mysql_error_log;
                last;
            }
        }
        close $file_fh;
    }

    if ( $mysql_error_log ) {
        return $mysql_error_log;
    }
    else {
        return '/var/lib/mysql/' . $hostname . '.err';
    }
}

sub check_for_non_default_mysql_error_log_location {
    if ( $mysql_error_log and $mysql_error_log !~ m# \A /var/lib/mysql/${hostname}\.err \z #xms ) {
        print_warn( 'MySQL: ' );
        print_warning( "error log configured in /etc/my.cnf as $mysql_error_log" );
    }
}

sub check_for_C_compiler_optimization {
    my $enablecompileroptimizations = 0;

    if ( open my $file_fh, '<', '/var/cpanel/cpanel.config' ) {
        while ( <$file_fh> ) {
            if ( m{ \A enablecompileroptimizations=(\d) }xms ) {
                $enablecompileroptimizations = $1;
                last;
            }
        }
        close $file_fh;
    }

    if ( $enablecompileroptimizations == 1 ) {
        print_warn( 'Tweak Setting: ' );
        print_warning( '"Enable optimizations for the C compiler" enabled. If Sandy Bridge CPU, problems MAY occur (see ticket 3355885)' );
    }
}

sub check_for_low_ulimit_for_root {
    my $ulimit_m = run( 'echo `ulimit -m`' );
    my $ulimit_v = run( 'echo `ulimit -v`' );

    chomp ( $ulimit_m, $ulimit_v );

    if ( $ulimit_m =~ /\d+/ ) {
        $ulimit_m = sprintf('%.0f', $ulimit_m / 1024 );
    }
    if ( $ulimit_v =~ /\d+/ ) {
        $ulimit_v = sprintf('%.0f', $ulimit_v / 1024 );
    }

    if ( $ulimit_m =~ /\d+/ and $ulimit_m <= 256 or $ulimit_v =~ /\d+/ and $ulimit_v <= 256 ) {
        if ( $ulimit_m =~ /\d+/ ) {
            $ulimit_m .= 'MB';
        }
        if ( $ulimit_v =~ /\d+/ ) {
            $ulimit_v .= 'MB';
        }

        print_warn( 'ulimit: ' );
        print_warning( "-m [ $ulimit_m ] -v [ $ulimit_v ] Low ulimits can cause EA to fail when run via the shell" );
    }
}

sub check_for_cpphpopts {
    my $state_yaml = '/var/cpanel/easy/apache/state.yaml';
    my $cPPHPOpts = 0;

    if ( open my $file_fh, '<', $state_yaml ) {
        while ( <$file_fh> ) {
            if ( /Cpanel::Easy::PHP5::cPPHPOpts: 1/ ) {
                $cPPHPOpts = 1;
                last;
            }
        }
        close $file_fh;
    }

    if ( $cPPHPOpts == 1 ) {
        print_warn( 'EA: ' );
        print_warning( '"Save my profile (...) so that it is compatible with cpphp" enabled. EA can fail if Postgres isn\'t installed (see FB 59092)' );
    }
}

sub check_for_fork_bomb_protection {
    if ( -f '/etc/profile.d/limits.sh' or -f '/etc/profile.d/limits.csh' ) {
        print_warn( 'Fork Bomb Protection: ' );
        print_warning( 'enabled!' );
    }
}

# cPanel < 11.30.7.3 will get YAML::Syck from CPAN. If this causes any issues with
# Cpanel::TaskQueue, cPanel's position is to upgrade cPanel.
sub check_for_cPanel_lower_than_11_30_7_3 {
    my $cpanel_version;
    my $could_be_affected = 0;

    if ( open my $version_fh, '<', '/usr/local/cpanel/version' ) {
        while ( <$version_fh> ) {
            chomp( $cpanel_version = $_ );
        }
        close $version_fh;
    }    

    return if !$cpanel_version;

    if ( $cpanel_version =~ m{ \A (\d+)\.(\d+)\.(\d+)\.(\d+) \z }xms ) {
        if ( $1 < 11 ) {
            $could_be_affected = 1;
        }
        elsif ( $1 == 11 ) {
            if ( $2 < 30 ) {
                $could_be_affected = 1;
            }
            elsif ( $2 == 30 and $3 < 7 ) {
                $could_be_affected = 1;
            }
            elsif ( $2 == 30 and $3 == 7 and $4 < 3 ) {
                $could_be_affected = 1;
            }
        }
    }

    if ( $could_be_affected == 1 ) {
        print_warn( 'cPanel: ' );
        print_warning( 'versions < 11.30.7.3 use YAML::Syck from CPAN. If problems with Cpanel::TaskQueue, cPanel needs to be updated' );
    }
}

sub check_for_custom_exim_conf_local {
    my $exim_conf_local = '/etc/exim.conf.local';
    my $is_customized = 0;

    if ( open my $file_fh, '<', $exim_conf_local ) {
        while ( my $line = <$file_fh> ) {
            chomp $line;
            if ( $line !~ m{ \A ( @ | $ ) }xms ) {
                $is_customized = 1;
                last;
            }
        }
        close $file_fh;
    }

    if ( $is_customized == 1 ) {
        print_warn( 'Exim: ' );
        print_warning( "$exim_conf_local contains customizations" );
    }
}

sub check_for_maxclients_reached {
    my $log = '/usr/local/apache/logs/error_log';
    my $size = ( stat( $log ))[7];
    my $bytes_to_check = 20_971_520; # 20M limit of logs to check, may need adjusting, depending how much time it adds to SSP
    my $seek_position = 0;
    my $log_data;
    my @logs;
    my $max_clients_last_hit_date;

    if ( $size > $bytes_to_check ) {
        $seek_position = ( $size - $bytes_to_check );
    }

    if ( open my $file_fh, '<', $log ) {
        seek $file_fh, $seek_position, 0;
        read $file_fh, $log_data, $bytes_to_check;
        close $file_fh;
    }

    @logs = split /\n/, $log_data;
    undef $log_data;
    @logs = reverse @logs;

    for my $log_line ( @logs ) {
        if ( $log_line =~ m{ \A \[ (\S+ \s+ \S+ \s+ \S+ \s+ \S+ \s+ \S+ ) \] \s+ \[error\] \s+ server \s+ reached \s+ MaxClients }xms ) {
            $max_clients_last_hit_date = "$1";
            last;
        }
    }

    if ( $max_clients_last_hit_date ) {
        print_warn( 'MaxClients: ' );
        print_warning( "limit last reached at $max_clients_last_hit_date" );
    }
}

sub check_for_non_default_umask {
    my $umask = run( 'echo `umask`' );

    return if !$umask;

    chomp $umask;

    if ( $umask !~ /2$/ ) {
        print_warn( 'umask: ' );
        print_warning( "Non-default value [$umask] (check FB 62683 if permissions error when running convert_roundcube_mysql2sqlite)" );
    }
}

sub check_for_multiple_imagemagick_installs {
    if ( -e '/usr/bin/convert' and -e '/usr/local/bin/convert' ) {
        print_warn( 'ImageMagick: ' );
        print_warning( 'multiple "convert" binaries found [/usr/bin/convert] [/usr/local/bin/convert]' );
    }
}

sub check_for_kernel_headers_rpm {
    return if ( $os eq 'freebsd' );

    if ( ! -f '/usr/include/linux/limits.h' ) {
        print_warn( 'Missing file: /usr/include/linux/limits.h not found; can cause problems with EA. kernel-headers RPM missing/broken?' );
    }
    else {
        my $rpm_check = run( 'rpm', '-q', 'kernel-headers' );

        if ( $rpm_check =~ /not installed/ ) {
            print_warn( 'kernel-headers RPM: ' );
            print_warning( 'not found; can cause problems with EA' );
        }
    }
}

sub check_for_custom_locales {
    # FB 62119

    my $locale_dir = '/var/cpanel/locale.local';
    my $users_dir  = '/var/cpanel/users';

    return if !$locale_dir;
    return if !$users_dir;

    my ( @locale_dir_contents_tmp, @locale_dir_contents, @cpanel_users );
    my ( @users_locales, @users_with_custom_locales );

    opendir( my $locale_dir_fh, $locale_dir );
    @locale_dir_contents_tmp = grep { ! /^\.(\.?)$/ } readdir $locale_dir_fh;
    closedir $locale_dir_fh;

    return if !@locale_dir_contents_tmp;

    for my $locale ( @locale_dir_contents_tmp ) {
        $locale =~ s/^en\.yaml//g; # doesn't seem to be affected
        $locale =~ s/\.yaml$//g;
        push @locale_dir_contents, $locale;
    }

    return if !@locale_dir_contents;

    opendir( my $users_dir_fh, $users_dir );
    @cpanel_users = grep { ! /^(\.(\.?)|root)$/ } readdir $users_dir_fh;
    closedir $users_dir_fh;

    return if !@cpanel_users;   
    
    for my $user ( @cpanel_users ) {
        if ( open my $user_fh, '<', "${users_dir}/${user}" ) {
            while ( <$user_fh> ) {
                if ( /^LOCALE=(.*)/ ) {
                    push @users_locales, "${user}:${1}\n";
                    last;
                }
            }
            close $user_fh;
        }
    }

    return if !@users_locales;

    for my $user_and_locale ( @users_locales ) {
        my ( $user, $locale ) = split /:/, $user_and_locale;
        if ( grep { m{ \A $locale \z }xms } @locale_dir_contents ) {
            push @users_with_custom_locales, $user;
            last;
        }
    }

    return if !@users_with_custom_locales;

    print_warn( 'locales: ' );
    print_warning( '[FB 62119] Users with custom locales detected. Seeing "500 Internal Server Error" in cPanel? May be related, check the FB' );
}

sub check_eximstats_size {
    return if !$mysql_datadir;

    my $eximstats_dir = $mysql_datadir . 'eximstats/';
    my @dir_contents;
    my $size;

    if ( -d $eximstats_dir ) {
        opendir( my $dir_fh, $eximstats_dir );
        @dir_contents = grep { /(defers|failures|sends|smtp)\.(frm|MYI|MYD)$/ } readdir $dir_fh;
        closedir $dir_fh;
    }

    for my $file ( @dir_contents ) {
        $file = $eximstats_dir . $file;
        $size += ( stat( $file ) )[7];
    }

    if ( $size > 5_000_000_000 ) {
        $size = sprintf("%0.2fGB", $size/1073741824);
        print_warn( 'eximstats db: ' );
        print_warning( $size );
    }
}

sub check_eximstats_corrupt {
    return if !$mysql_error_log;

    my $size = ( stat( $mysql_error_log ))[7];
    my $bytes_to_check = 20_971_520; # 20M limit of logs to check
    my $seek_position = 0;
    my $log_data;
    my @logs;
    my $eximstats_is_crashed;

    if ( $size > $bytes_to_check ) {
        $seek_position = ( $size - $bytes_to_check );
    }

    if ( open my $file_fh, '<', $mysql_error_log ) {
        seek $file_fh, $seek_position, 0;
        read $file_fh, $log_data, $bytes_to_check;
        close $file_fh;
    }

    @logs = split /\n/, $log_data;
    undef $log_data;
    @logs = reverse @logs;

    for my $log_line ( @logs ) {
        # /usr/sbin/mysqld: Table './eximstats/smtp' is marked as crashed and should be repaired
        if ( $log_line =~ m{ /eximstats/ (.*) marked \s as \s crashed }xms  ) {
            $eximstats_is_crashed = $log_line;
            last;
        }
    }

    if ( $eximstats_is_crashed ) {
        print_warn( 'eximstats: ' );
        print_warning( "latest crash: $eximstats_is_crashed" );
    }
}

sub check_for_clock_skew {
    my $localtime = time();
    my $rdate_time;
    my $clock_skew;
    my $has_dovecot = 0;

    if ( $os eq 'linux' ) {
        $rdate_time = run( 'rdate', '-p', '-t', '1', 'rdate.cpanel.net' );

        # fall back to UDP if necessary
        if ( !$rdate_time ) {
            $rdate_time = run( 'rdate', '-p', '-t', '1', '-u', 'rdate.cpanel.net' );
        }
    }
    elsif ( $os eq 'freebsd' ) {
        local $SIG{'ALRM'} = sub { return(); };
        alarm 1;
        $rdate_time = run( 'rdate', '-p', 'rdate.cpanel.net' );
        alarm 0;
    }

    return if !$rdate_time;

    $rdate_time =~ s/\A rdate: \s \[rdate\.cpanel\.net\] \s+//gxms;

    if ( $rdate_time =~ m{ \A \S+ \s (\S+) \s (\d+) \s (\d+):(\d+):(\d+) \s (\d+) }xms ) {
        my ( $mon, $mday, $hour, $min, $sec, $year ) = ( $1, $2, $3, $4, $5, $6 );
        $rdate_time = timelocal( $sec, $min, $hour, $mday, $mon, $year );
    }

    return if ( $rdate_time !~ /\d{10}/ );

    $clock_skew = ( $rdate_time - $localtime );
    $clock_skew = abs $clock_skew; # convert negative numbers to positive

    return if ( $clock_skew < 60 );

    if ( $clock_skew >= 31536000 ) {
        $clock_skew = sprintf '%.1f', ( $clock_skew / 31536000 );
        $clock_skew .= ' years';
    }
    elsif ( $clock_skew >= 86400 ) {
        $clock_skew = sprintf '%.1f', ( $clock_skew / 86400 );
        $clock_skew .= ' days';
    }
    elsif ( $clock_skew >= 3600 ) {
        $clock_skew = sprintf '%.1f', ( $clock_skew / 3600 );
        $clock_skew .= ' hours';
    }
    elsif ( $clock_skew >= 60 ) {
        $clock_skew = sprintf '%.1f', ( $clock_skew / 60 );
        $clock_skew .= ' minutes';
    }

    for my $process ( @process_list ) {
        if ( $process =~ m{ \A root (.*) dovecot }xms ) {
            $has_dovecot = 1;
            last;
        }
    }
    
    if ( $has_dovecot == 0 and $clock_skew !~ /minutes/ ) {
        print_warn( 'Clock skew: ' );
        print_warning( "servers time may be off by $clock_skew" );
    }
    elsif ( $has_dovecot == 1 ) {
        print_warn( 'Clock skew: ' );
        print_warning( "server time may be off by ${clock_skew}; this can cause Dovecot to die during upcp" );
    }
}

sub check_for_zlib_h {
    if ( -f '/usr/local/include/zlib.h' ) {
        print_warn( '/usr/local/include/zlib.h: ' );
        print_warning( 'This file can cause EA to fail with libxml issues; may need to mv it, run EA again' );
    }        
}

sub check_for_percona_rpms {
    return if !@rpm_list;

    my $has_percona = 0;

    for my $rpm ( @rpm_list ) {
        if ( $rpm =~ /^Percona-/i ) {
            $has_percona = 1;
            last;
        }
    }
    
    if ( $has_percona == 1 ) {
        print_warn( 'Percona: ' );
        print_warning( 'rpms found. If Exim is segfaulting after STARTTLS, this may be why. See ticket 3658929' );
    }
}

sub check_if_httpdconf_ipaddrs_exist {
    my $httpdconf = '/usr/local/apache/conf/httpd.conf';
    my @vhost_ipaddrs;
    my ( @unbound_ipaddrs, $unbound_ipaddrs );

    return if !$httpdconf;

    if ( open my $httpdconf_fh, '<', $httpdconf ) {
        while ( <$httpdconf_fh> ) {
            if ( /<VirtualHost\s+(\d+\.\d+\.\d+\.\d+):(?:\d+)>/i ) {
                push @vhost_ipaddrs, $1;
            }
        }
        close $httpdconf_fh;
    }

    # uniq IP addrs only
    @vhost_ipaddrs = do { my %seen; grep { !$seen{$_}++ } @vhost_ipaddrs };

    for my $vhost_ipaddr ( @vhost_ipaddrs ) {
        my $is_bound = 0;
        for my $local_ipaddr ( @local_ipaddrs_list ) {
            if ( $vhost_ipaddr eq $local_ipaddr ) {
                $is_bound = 1;
                last;
            }
        }
        if ( $is_bound == 0 ) {
            push @unbound_ipaddrs, $vhost_ipaddr;
        }
    }

    if ( @unbound_ipaddrs ) {
        print_warn( 'Apache: ' );
        print_warning( 'httpd.conf has VirtualHosts for these IP addrs, which aren\'t bound to the server:' );

        for my $unbound_ipaddr ( @unbound_ipaddrs ) {
            print_magenta( "\t \\_ $unbound_ipaddr" );
        }
    }
}

sub check_distcache_and_libapr {
    my $last_success_profile = '/var/cpanel/easy/apache/profile/_last_success.yaml';
    my $has_distcache = 0;
    my $httpd_not_linked_to_system_apr = 0;

    if ( open my $profile_fh, '<', $last_success_profile ) {
        while ( <$profile_fh> ) {
            if ( /Distcache:/ ) {
                $has_distcache = 1;
                last;
            }
        }
        close $profile_fh;
    }

    if ( $has_distcache == 1 ) {
        my @ldd = split /\n/, run( 'ldd', '/usr/local/apache/bin/httpd' );
        for my $line ( @ldd ) {
            if ( $line =~ m{ libapr(?:.*) \s+ => \s+ (\S+) }xms ) {
                if ( $1 !~ m{ \A /usr/local/apache/lib/libapr }xms ) {
                    $httpd_not_linked_to_system_apr = 1;
                    last;
                }
            }
        }
    }

    if ( $httpd_not_linked_to_system_apr == 1 ) {
        print_warn( 'Apache: ' );
        print_warning( 'httpd linked to system APR, not APR in /usr/local/apache/lib/ (see 62676)' );
    }
}

sub check_for_mainip_newline {
    my $mainip = '/var/cpanel/mainip';
    my $has_newline = 0;

    if ( ! -e $mainip ) {
        print_warn( "$mainip: " );
        print_warning( 'missing!' );
    }
    else {
        if ( open my $mainip_fh, '<', $mainip ) {
            while ( <$mainip_fh> ) {
                if ( /\n/ ) {
                    $has_newline = 1;
                    last;
                }
            }
            close $mainip_fh;
        }
    }

    if ( $has_newline == 1 ) {
        print_warn( "$mainip: " );
        print_warning( 'contains a newline; /scripts/ipcheck may send incorrect "hostname [..] should resolve to" emails; see FB 54844' );
    }                
}

sub check_for_custom_postgres_repo {
    return if ( $os eq 'freebsd' );

    my $yum_repos_dir = '/etc/yum.repos.d/';
    my @dir_contents;
    my $has_postgres_repo = 0;

    return if !-d $yum_repos_dir;

    opendir( my $dir_fh, $yum_repos_dir );
    @dir_contents = grep { ! /^\.(\.?)$/ } readdir $dir_fh;
    closedir $dir_fh;

    for my $repos ( @dir_contents ) {
        if ( $repos =~ m{ \A pgdg-(\d+)-centos\.repo }xms ) {
            $has_postgres_repo = 1;
            last;
        }
    }

    if ( $has_postgres_repo == 1 ) {
        print_warn( 'PostgreSQL: ' );
        print_warning( 'custom Postgres repo (pgdg-*) found in /etc/yum.repos.d/ . See tickets 3690445, 3568781' );
    }
}

sub check_for_rpm_overrides {
    return if ( $os eq 'freebsd' );

    my $rpm_override_dir = '/var/cpanel/rpm.versions.d/';
    my $local_versions = '/var/cpanel/rpm.versions.d/local.versions';
    my $md5;
    my $is_default = 0;

    if ( -f $local_versions ) {
        $md5 = run( 'md5sum', $local_versions );
    }

    if ( $md5 =~ m{ \A fd3f270edda79575343e910369b75ab7 \s }xms ) {
        $is_default = 1;
    }

    opendir( my $dir_fh, $rpm_override_dir );
    my @dir_contents = grep { ! /^\.(\.?)$/ } readdir $dir_fh;
    closedir $dir_fh;

    if ( scalar @dir_contents == 1 ) {
        if ( $dir_contents[0] eq 'local.versions' and $is_default == 1 ) {
            return;
        }
    }

    if ( @dir_contents ) {
        print_warn( 'RPM override: ' );
        print_warning( "$rpm_override_dir contains entries; manually review. More info: http://go.cpanel.net/rpmversions" );
    }    
}

sub check_for_odd_yum_conf {
    return if ( $os eq 'freebsd' );

    my $yum_conf = '/etc/yum.conf';

    return if !$yum_conf;

    my $exclude_line_count = 0;
    my $exclude_kernel = 0;
    

    if ( open my $file_fh, '<', $yum_conf ) {
        while ( <$file_fh> ) {
            if ( /^exclude/i ) {
                $exclude_line_count += 1;
            }
            if ( /exclude(.*)kernel/ ) {
                $exclude_kernel = 1;
            }
        }
        close $file_fh;
    }

    if ( $exclude_line_count > 1 ) {
        print_warn( 'yum.conf: ' );
        print_warning( 'contains multiple "exclude" lines! See FB 63311' );
    }

    if ( $exclude_kernel == 1 ) {
        print_warn( 'yum.conf: ' );
        print_warning( 'may be excluding kernel updates! See FB 63311' );
    }
}

sub check_var_cpanel_immutable_files {
    my $immutable_files = '/var/cpanel/immutable_files';

    if ( -e $immutable_files and !-z $immutable_files ) {
        print_warn( 'immutable files: ' );
        print_warning( "$immutable_files is not empty!" );
    }
}

sub check_for_hordepass_newline {
    my $hordepass = '/var/cpanel/hordepass';
    my $has_newline = 0; 

    if ( ! -e $hordepass ) {
        print_warn( "$hordepass: " );
        print_warning( 'missing!' );
    }    
    else {
        if ( open my $hordepass_fh, '<', $hordepass ) {
            while ( <$hordepass_fh> ) {
                if ( /\n/ ) {
                    $has_newline = 1; 
                    last;
                }
            }
            close $hordepass_fh;
        }
    }    

    if ( $has_newline == 1 ) {
        print_warn( "$hordepass: " );
        print_warning( 'contains a newline; can cause leftover cptmpdb_* MySQL dbs; see FB 63364' );
    }     
}

sub check_for_noxsave_in_grub_conf {
    my $grub_conf = '/boot/grub/grub.conf';
    my $has_noxsave = 0;

    return if !$grub_conf;

    if ( open my $grub_fh, '<', $grub_conf ) {
        while ( <$grub_fh> ) {
            if ( /noxsave/ ) {
                $has_noxsave = 1;
                last;
            }
        }
        close $grub_fh;
    }

    if ( $has_noxsave == 1 ) {
        print_warn( 'noxsave: ' );
        print_warning( "found in ${grub_conf}. kernel panics? segfaults? see ticket 3689211" );
    }
}

sub check_for_cpanel_CN_newline {
    my $cpanel_CN = '/var/cpanel/ssl/cpanel-CN';
    my $has_newline = 0; 

    if ( ! -e $cpanel_CN ) {
        print_warn( "$cpanel_CN: " );
        print_warning( 'missing!' );
    }    
    else {
        if ( open my $cpanel_CN_fh, '<', $cpanel_CN ) {
            while ( <$cpanel_CN_fh> ) {
                if ( /\n/ ) {
                    $has_newline = 1; 
                    last;
                }
            }
            close $cpanel_CN_fh;
        }
    }    

    if ( $has_newline == 1 ) {
        print_warn( "$cpanel_CN: " );
        print_warning( 'contains a newline; can cause "Access Web Disk" menus to not work; see FB 63425' );
    }     
}

sub check_for_my_cnf_skip_name_resolve {
    my $skip_name_resolve = 0;

    my $my_cnf = '/etc/my.cnf';
    if ( open my $my_cnf_fh, '<', $my_cnf ) {
        while ( <$my_cnf_fh> ) {
            chomp( my $line = $_ );
            if ( $line =~ m{ \A skip_name_resolve }xms ) {
                $skip_name_resolve = 1;
                last;
            }
        }
        close $my_cnf;
    }

    if ( $skip_name_resolve == 1 ) {
        print_warn( '/etc/my.cnf: ' );
        print_warning( 'skip_name_resolve found; seeing "Can\'t find any matching row"? That may be why' );
    }
}


sub check_for_my_cnf_sql_mode {
    my $sql_mode = 0; 

    my $my_cnf = '/etc/my.cnf';
    if ( open my $my_cnf_fh, '<', $my_cnf ) {
        while ( <$my_cnf_fh> ) {
            chomp( my $line = $_ );
            if ( $line =~ m{ \A sql[-_]mode }xms ) {
                $sql_mode = 1; 
                last;
            }
        }
        close $my_cnf;
    }    

    if ( $sql_mode == 1 ) {
        print_warn( '/etc/my.cnf: ' );
        print_warning( 'sql_mode or sql-mode found; seeing "Field \'ssl_cipher\' doesn\'t have a default value"? That may be why' );
    }    
}


##############################
#  END [WARN] CHECKS
##############################


##############################
#  BEGIN [3RDP] CHECKS
##############################

sub check_for_assp {
    my $assp;
    my @port_25_processes;

    if ( $os eq 'linux' ) {
        my @lsof_25 = split /\n/, run( 'lsof', '-n', '-i', 'tcp:25' );
        if ( @lsof_25 ) {

            for my $line ( @lsof_25 ) {
                if ( $line =~ m{ (\S+) \s+ (?:.*) \s TCP (?:.*):smtp \s \(LISTEN\) }xms ) {
                    push( @port_25_processes, $1 );
                }
            }

            if ( grep { m{ \A assp\.pl }xms } @port_25_processes ) {
                print_3rdp( 'ASSP: ' );
                print_warning( 'assp.pl is listening on port 25' );
            }

            if ( grep { m{ \A perl \z }xms } @port_25_processes ) {
                print_3rdp( 'Exim: ' );
                print_3rdp2( 'something other than Exim found listening on port 25' );
            }
        }
    }
}

sub check_for_varnish {
    my $varnish;
    my @port_80_processes;

    if ( $os eq 'linux' ) { 
        my @lsof_80 = run( 'lsof', '-n', '-i', 'tcp:80' );
        for my $line ( @lsof_80 ) {
            if ( $line =~ m{ (\S+) \s+ (?:.*) \s TCP (?:.*):http \s \(LISTEN\) }xms ) { 
                push( @port_80_processes, $1 );
            }
        }

        if ( grep { m{ \A varnish }xms } @port_80_processes ) { 
            print_3rdp( 'Varnish: ' );
            print_3rdp2( 'varnish is listening on port 80' );
        }
    }   
}

sub check_for_litespeed {
    my $litespeed = 0;

    for my $line ( @process_list ) {
        if ( $line =~ /litespeed|lshttp/ and $line !~ /\_/ ) {
            $litespeed = 1;
            last;
        }
    }

    if ( $litespeed == 1 ) {
        print_3rdp( 'litespeed: ' );
        print_3rdp2( 'is running' );
    }
}

sub check_for_nginx {
    my $nginx = 0;

    for my $line ( @process_list ) {
        if ( $line =~ m{ \A root (?:.*) nginx: }xms ) {
            $nginx = 1;
            last;
        }
    }

    if ( $nginx == 1 ) {
        print_3rdp( 'nginx: ' );
        print_3rdp2( 'is running' );
    }
}

sub check_for_mailscanner {
    my $mailscanner = 0;

    for my $line ( @process_list ) {
        if ( $line =~ m{ \A mailnull (?:.*) MailScanner }xms ) {
            $mailscanner = 1;
            last;
        }
    }

    if ( $mailscanner == 1 ) {
        print_3rdp( 'MailScanner: ' );
        print_3rdp2( 'is running' );
    }
}

sub check_for_apf {
    my $chkconfig_apf = run( 'chkconfig', '--list', 'apf');
    if ( $chkconfig_apf ) {
        if ( $chkconfig_apf =~ /3:on/ ) {
            print_3rdp( 'APF: ' );
            print_3rdp2( 'installed, may be enabled.' );
        }
    }
}

sub check_for_csf {
    my $lfd = 0;
    my $csf = run( 'whereis', 'csf' );

    if ( $csf =~ /\// ) {
        print_3rdp( 'CSF: ' );
    }
    else {
        return;
    }

    for my $line ( @process_list ) {
        if ( $line  =~ m{ \A root (?:.*) lfd }xms ) {
            $lfd = 1;
            last;
        }
    }

    if ( $lfd ) {
        print_3rdp2( 'installed, LFD is running' );
    }
    else {
        print_3rdp2( 'installed, LFD is not running' );
    }
}

sub check_for_prm {
    if ( -e '/usr/local/prm' ) {
        print_3rdp( 'PRM: ' );
        print_3rdp2( 'PRM exists at /usr/local/prm' );
    }
}

sub check_for_les {
    if ( -e '/usr/local/sbin/les' ) {
        print_3rdp( 'LES: ' );
        print_3rdp2( 'Linux Environment Security is installed at /usr/local/sbin/les' );
    }
}

sub check_for_1h {
    my $one_h = 0;
    my ( $hive_module, $guardian );

    if ( -d '/usr/local/1h' ) {
        $one_h = 1;
        if ( @apache_modules_output ) {
            for my $line ( @apache_modules_output ) {
                if ( $line =~ /hive/ ) {
                    $hive_module = 'loaded';
                }
                else {
                    $hive_module = 'not active';
                }
            }
        }
        if ( -x '/usr/local/1h/sbin/guardian' ) {
            for my $line ( @process_list ) {
                if ( $line =~ /Guardian/ ) {
                    $guardian = 'running';
                }
                else {
                    $guardian = 'not running';
                }
            }
        }
        else {
            $guardian = 'not running'
        }
    }

    if ( $one_h == 1 ) {
        print_3rdp( '1H Software: ' );
        print_3rdp2( "/usr/local/1h exists. hive apache module: [ $hive_module ] Guardian process: [ $guardian ]" );
    }
}

sub check_for_webmin {
    my @lsof_10000 = split /\n/, run( 'lsof', '-n', '-i', 'tcp:10000' );

    if ( @lsof_10000 ) {
        print_3rdp( 'Webmin: ' );
        print_3rdp2( 'Port 10000 is listening, webmin may be running' );
    }
}

sub check_for_symantec {
    my $symantec = 0;

    for my $process ( @process_list ) {
        if ( $process  =~ m{ \A root (?:.*) /opt/Symantec/symantec_antivirus }xms ) {
            $symantec = 1;
            last;
        }
    }

    if ( $symantec == 1 ) {
        print_3rdp( 'Symantec: ' );
        print_3rdp2( 'found /opt/Symantec/symantec_antivirus in process list' );
    }
}

sub check_for_haproxy {
    my $haproxy = 0;

    for my $process ( @process_list ) {
        if ( $process =~ m{ \A root (?:.*) haproxy }xms ) {
            $haproxy = 1;
            last;
        }
    }

    if ( $haproxy == 1 ) {
        print_3rdp( 'HAProxy: ' );
        print_3rdp2( 'found haproxy in process list' );
    }
}

##############################
#  END [3RDP] CHECKS
##############################

sub build_rpm_list {
    return if ( $os eq 'freebsd' );

    my $timeout = 15;

    print_info2( "RPM check (running \"rpm -qa\"). This will timeout after $timeout seconds." );

    local $SIG{'ALRM'} = sub {
        print_warning( 'Additional RPM: check timed out' );
    };
    alarm $timeout;
    @rpm_list = split /\n/, run( 'rpm', '-qa' );
    alarm 0;

    return @rpm_list;
}
