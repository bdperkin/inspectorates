#!/usr/bin/perl -Tw
#
# %{NAME} - Internet connection bandwidth speed test tool.
# Copyright (C) 2013-%{YEAR}  Brandon Perkins <bperkins@redhat.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
# USA.
#

################################################################################
# Import some semantics into the current package from the named modules
################################################################################
use strict;                            # Restrict unsafe constructs
use warnings;                          # Control optional warnings
use File::Basename;                    # File::Basename - Parse file paths into
                                       # directory, filename and suffix.
use Getopt::Long;                      # Getopt::Long - Extended processing of
                                       # command line options
use Math::Trig;                        # Math::Trig - trigonometric functions
use Pod::Usage;                        # Pod::Usage, pod2usage() - print a
                                       # usage message from embedded pod
                                       # documentation
use Time::HiRes qw(gettimeofday);      # Time::HiRes - High resolution alarm,
                                       # sleep, gettimeofday, interval timers
use URI::Split qw(uri_split uri_join); # URI::Split - Parse and compose URI
                                       # strings
use WWW::Curl::Easy;                   # WWW::Curl - Perl extension interface
                                       # for libcurl
use XML::XPath;                        # XML::XPath - a set of modules for
                                       # parsing and evaluating XPath statements

################################################################################
# Declare constants
################################################################################
binmode STDOUT, ":utf8";    # Output UTF-8 using the :utf8 output layer.
                            # This ensures that the output is completely
                            # UTF-8, and removes any debug warnings.

$ENV{PATH}  = "/usr/bin:/bin";    # Keep taint happy
$ENV{PAGER} = "more";             # Keep pod2usage output happy

my $name    = "%{NAME}";          # Name string
my $version = "%{VERSION}";       # Version number
my $release = "%{RELEASE}";       # Release string

my $protocol = "http";            # Use unencrypted HTTP protocol
my $domain   = "speedtest.net";   # Speedtest.net domain
my $host     = "www";             # World-Wide Web host

################################################################################
# Generate composite constants
################################################################################
my $wsnuri = "$protocol://$host.$domain";
my $csnuri = "$protocol://c.$domain";

my $cnfguri = "$wsnuri/speedtest-config.php";
my $srvruri = "$wsnuri/speedtest-servers.php";
my $aapiuri = "$wsnuri/api/api.php";
my $flshuri = "$csnuri/flash/speedtest.swf";
my $rslturi = "$wsnuri/result/%s.png";

################################################################################
# Specify module configuration options to be enabled
################################################################################
# Allow single-character options to be bundled. To distinguish bundles from long
# option names, long options must be introduced with '--' and bundles with '-'.
# Do not allow '+' to start options.
Getopt::Long::Configure(qw(bundling no_getopt_compat));

################################################################################
# Initialize variables
################################################################################
my $DBG          = 1;
my $numservers   = 5;
my $totalservers = 0;
my $numpingtest  = 3;
my $numpingcount = 10;

my $optcount;
my $optdebug;
my $opthelp;
my $optman;
my $optpings;
my $optquiet;
my $optservers;
my $optverbose;
my $optversion;

################################################################################
# Parse command line options.  This function adheres to the POSIX syntax for CLI
# options, with GNU extensions.
################################################################################
GetOptions(
    "c=i"       => \$optcount,
    "count=i"   => \$optcount,
    "d"         => \$optdebug,
    "debug"     => \$optdebug,
    "h"         => \$opthelp,
    "help"      => \$opthelp,
    "m"         => \$optman,
    "man"       => \$optman,
    "p=i"       => \$optpings,
    "pings=i"   => \$optpings,
    "q"         => \$optquiet,
    "quiet"     => \$optquiet,
    "s=i"       => \$optservers,
    "servers=i" => \$optservers,
    "v"         => \$optverbose,
    "verbose"   => \$optverbose,
    "V"         => \$optversion,
    "version"   => \$optversion
) or pod2usage(2);

################################################################################
# Help function
################################################################################
pod2usage(1) if $opthelp;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $optman;

################################################################################
# Version function
################################################################################
if ($optversion) {
    print "$name $version ($release)\n";
    exit 0;
}

################################################################################
# Set output level
################################################################################
# If multiple outputs are specified, the most verbose will be used.
if ($optquiet) {
    $DBG = 0;
}
if ($optverbose) {
    $DBG = 2;
    $|   = 1;
}
if ($optdebug) {
    $DBG = 3;
    $|   = 1;
}
if ( $DBG > 2 ) {
    printf( "== Debugging Level Set to %-17s ==\n", $DBG );
    printf( "== %-12s %-12s (%-12s) ==\n",          $name, $version, $release );
    printf( "==         PROCESS_ID: %-20s ==\n",    $$ );
    printf( "==       PROGRAM_NAME: %-20s ==\n",    $0 );
    printf( "==      REAL_GROUP_ID: %-20s ==\n",    $( );
    printf( "== EFFECTIVE_GROUP_ID: %-20s ==\n",    $) );
    printf( "==       REAL_USER_ID: %-20s ==\n",    $< );
    printf( "==  EFFECTIVE_USER_ID: %-20s ==\n",    $> );
    printf( "==             OSNAME: %-20s ==\n",    $^O );
    printf( "==           BASETIME: %-20s ==\n",    $^T );
    printf( "==       PERL_VERSION: %-20s ==\n",    $^V );
    printf( "==    EXECUTABLE_NAME: %-20s ==\n",    $^X );
    printf( "==     File::Basename: %-20s ==\n",    $File::Basename::VERSION );
    printf( "==       Getopt::Long: %-20s ==\n",    $Getopt::Long::VERSION );
    printf( "==         Math::Trig: %-20s ==\n",    $Math::Trig::VERSION );
    printf( "==         Pod::Usage: %-20s ==\n",    $Pod::Usage::VERSION );
    printf( "==        Time::HiRes: %-20s ==\n",    $Time::HiRes::VERSION );
    printf( "==    WWW::Curl::Easy: %-20s ==\n",    $WWW::Curl::Easy::VERSION );
    printf( "==         XML::XPath: %-20s ==\n",    $XML::XPath::VERSION );
}

################################################################################
# Main function
################################################################################
if ( $DBG > 0 ) {
    print "Loading...\n";
}
my $browser = WWW::Curl::Easy->new;
$browser->setopt( CURLOPT_HEADER,        0 );
$browser->setopt( CURLOPT_NOPROGRESS,    1 );
$browser->setopt( CURLOPT_TCP_KEEPALIVE, 1 );
$browser->setopt( CURLOPT_TCP_NODELAY,   1 );
$browser->setopt( CURLOPT_USERAGENT,     "$name/$version" );
my $retcode;

################################################################################
# Retrieve speedtest.net configuration
################################################################################
( my $sepoch, my $usecepoch ) = gettimeofday();
my $msecepoch = ( $usecepoch / 1000 );
my $msepoch = sprintf( "%010d%03.0f", $sepoch, $msecepoch );
$cnfguri = $cnfguri . "?x=" . $msepoch;
if ( $DBG > 1 ) {
    print "= Retrieving $domain configuration...";
    if ( $DBG > 2 ) {
        print "\n== GET $cnfguri ==\n";
    }
}

$browser->setopt( CURLOPT_URL, $cnfguri );
my $configxml;
$browser->setopt( CURLOPT_WRITEDATA, \$configxml );
$retcode = $browser->perform;
die "\nCannot get $cnfguri -- $retcode "
  . $browser->strerror($retcode) . " "
  . $browser->errbuf . "\n"
  unless ( $retcode == 0 );
die "\nDid not receive XML, got -- ", $browser->getinfo(CURLINFO_CONTENT_TYPE)
  unless $browser->getinfo(CURLINFO_CONTENT_TYPE) eq 'text/xml';
if ( $DBG > 1 ) {
    print "done. =\n";
}

################################################################################
# Read speedtest.net configuration
################################################################################
if ( $DBG > 1 ) {
    print "= Reading $domain configuration...";
    if ( $DBG > 2 ) {
        print "\n";
    }
}

my $configxp = XML::XPath->new($configxml);

# client settings hash
my %client;
$client{ip}  = $configxp->find('/settings/client/@ip')->string_value;
$client{lat} = $configxp->find('/settings/client/@lat')->string_value;
$client{lon} = $configxp->find('/settings/client/@lon')->string_value;
$client{isp} = $configxp->find('/settings/client/@isp')->string_value;
$client{isprating} =
  $configxp->find('/settings/client/@isprating')->string_value;
$client{rating}   = $configxp->find('/settings/client/@rating')->string_value;
$client{ispdlavg} = $configxp->find('/settings/client/@ispdlavg')->string_value;
$client{ispulavg} = $configxp->find('/settings/client/@ispulavg')->string_value;
$client{loggedin} = $configxp->find('/settings/client/@loggedin')->string_value;

# times settings hash
my %times;
$times{dl1} = $configxp->find('/settings/times/@dl1')->string_value;
$times{dl2} = $configxp->find('/settings/times/@dl2')->string_value;
$times{dl3} = $configxp->find('/settings/times/@dl3')->string_value;
$times{ul1} = $configxp->find('/settings/times/@ul1')->string_value;
$times{ul2} = $configxp->find('/settings/times/@ul2')->string_value;
$times{ul3} = $configxp->find('/settings/times/@ul3')->string_value;

# download settings hash
my %download;
$download{testlength} =
  $configxp->find('/settings/download/@testlength')->string_value;
$download{initialtest} =
  $configxp->find('/settings/download/@initialtest')->string_value;
$download{mintestsize} =
  $configxp->find('/settings/download/@mintestsize')->string_value;

# upload settings hash
my %upload;
$upload{testlength} =
  $configxp->find('/settings/upload/@testlength')->string_value;
$upload{ratio} = $configxp->find('/settings/upload/@ratio')->string_value;
$upload{initialtest} =
  $configxp->find('/settings/upload/@initialtest')->string_value;
$upload{mintestsize} =
  $configxp->find('/settings/upload/@mintestsize')->string_value;
$upload{threads} = $configxp->find('/settings/upload/@threads')->string_value;
$upload{maxchunksize} =
  $configxp->find('/settings/upload/@maxchunksize')->string_value;
$upload{maxchunkcount} =
  $configxp->find('/settings/upload/@maxchunkcount')->string_value;

if ( $DBG > 2 ) {

    print "=================== CLIENT ====================\n";
    foreach my $name ( keys %client ) {
        my $info = $client{$name};
        printf( "==   client:: %13s: %-15s ==\n", $name, $info );
    }
    print "==================== TIMES ====================\n";
    foreach my $name ( keys %times ) {
        my $info = $times{$name};
        printf( "==    times:: %13s: %-15s ==\n", $name, $info );
    }
    print "================== DOWNLOAD ===================\n";
    foreach my $name ( keys %download ) {
        my $info = $download{$name};
        printf( "== download:: %13s: %-15s ==\n", $name, $info );
    }
    print "=================== UPLOAD ====================\n";
    foreach my $name ( keys %upload ) {
        my $info = $upload{$name};
        printf( "==   upload:: %13s: %-15s ==\n", $name, $info );
    }
    print "===============================================\n";
}
if ( $DBG > 0 ) {
    if ( $DBG > 1 ) {
        print "done. =\n";
    }
    print "Client IP Address: $client{ip}\n";
    print "Client Internet Service Provider: $client{isp}\n";
}
################################################################################
# Retrieve speedtest.net servers list
################################################################################
( $sepoch, $usecepoch ) = gettimeofday();
$msecepoch = ( $usecepoch / 1000 );
$msepoch   = sprintf( "%010d%03.0f", $sepoch, $msecepoch );
$srvruri   = $srvruri . "?x=" . $msepoch;
if ( $DBG > 1 ) {
    print "= Retrieving $domain servers list...";
    if ( $DBG > 2 ) {
        print "\n== GET $srvruri ==\n";
    }
}

$browser->setopt( CURLOPT_URL, $srvruri );
my $serversxml;
$browser->setopt( CURLOPT_WRITEDATA, \$serversxml );
$retcode = $browser->perform;
die "\nCannot get $srvruri -- $retcode "
  . $browser->strerror($retcode) . " "
  . $browser->errbuf . "\n"
  unless ( $retcode == 0 );
die "\nDid not receive XML, got -- ", $browser->getinfo(CURLINFO_CONTENT_TYPE)
  unless $browser->getinfo(CURLINFO_CONTENT_TYPE) eq 'text/xml';
if ( $DBG > 1 ) {
    print "done. =\n";
}

################################################################################
# Read speedtest.net servers list
################################################################################
if ( $DBG > 1 ) {
    print "= Reading $domain servers list...";
    if ( $DBG > 2 ) {
        print "\n";
    }
}

my $serversxp   = XML::XPath->new($serversxml);
my $servernodes = $serversxp->find('/settings/servers/server');

# server attributes
my @serveratts =
  ( 'url', 'lat', 'lon', 'name', 'country', 'cc', 'sponsor', 'id', 'url2' );

# server list hash
my %servers;
foreach my $serverid ( $servernodes->get_nodelist ) {
    my $id = $serverid->find('@id')->string_value;
    foreach my $serveratt (@serveratts) {
        my $att = "@" . "$serveratt";
        $servers{$id}{$serveratt} = $serverid->find($att)->string_value;
    }
}

# ping latency hash
my %latencyresults;

if ( $DBG > 1 ) {
    if ( $DBG > 2 ) {
        print "=================== SERVERS ===================\n";
        foreach my $name ( keys %servers ) {
            printf( "== servers:: %5.5s: ", $name );
            foreach my $serveratt (@serveratts) {
                printf( " %10.10s: %-20.20s",
                    $serveratt, $servers{$name}{$serveratt} );
            }
            print " ==\n";
        }
        print "===============================================\n";
    }
    print "done. =\n";
}

################################################################################
# Determine the distance between the client and all test servers
################################################################################
if ( $DBG > 1 ) {
    print "= Determining the distance between client and $domain servers...";
    if ( $DBG > 2 ) {
        print "\n================== DISTANCE ===================\n";
    }
}

push( @serveratts, 'distance' );

foreach my $serverid ( keys %servers ) {
    my $id  = $servers{$serverid}{id};
    my $lat = $servers{$serverid}{lat};
    my $lon = $servers{$serverid}{lon};
    my $radius = 6371;    # Several different ways of modeling the Earth as a
                          # sphere each yield a mean radius of 6,371 km
                          # (≈3,959 mi).
    my $dlat = deg2rad( $lat - $client{lat} );
    my $dlon = deg2rad( $lon - $client{lon} );
    my $a    = (
        sin( $dlat / 2 ) *
          sin( $dlat / 2 ) +
          cos( deg2rad( $client{lat} ) ) *
          cos( deg2rad($lat) ) *
          sin( $dlon / 2 ) *
          sin( $dlon / 2 ) );
    my $c = 2 * atan2( sqrt($a), sqrt( 1 - $a ) );
    my $d = $radius * $c;

    if ( $DBG > 2 ) {
        my $df = sprintf( "%05.6f", $d );
        printf( "== %5.5s a: %1.4f c: %1.4f d: %12s ==\n", $id, $a, $c, $df );
    }
    $servers{$id}{distance} = $d;
    $totalservers++;
}
if ( $DBG > 1 ) {
    if ( $DBG > 2 ) {
        print "===============================================\n";
        print "== Total number of test servers: $totalservers ==\n";
    }
    print "done. =\n";
}

################################################################################
# Set number of test servers
################################################################################
# Error if input is less than one or greater than the total number of servers.
if ($optservers) {
    if ( $optservers > 0 && $optservers <= $totalservers ) {
        $numservers = $optservers;
    }
    else {
        print STDERR "Value \"$optservers\" invalid for number of servers ";
        print STDERR "option.\nPlease select an integer between 1 and ";
        print STDERR "$totalservers.\n";
        pod2usage(1);
    }
}
if ( $DBG > 1 ) {
    if ( $DBG > 2 ) {
        print "== Number of Test Servers Set to $numservers ==\n";
    }
    print "= Determining the $numservers closest $domain servers ";
    print "based on geographic distance...";
    if ( $DBG > 2 ) {
        print "\n================== DISTANCE ===================\n";
    }
}

################################################################################
# Hash sorting functions
################################################################################
sub hashValueAscendingDist {
    $servers{$a}{distance} <=> $servers{$b}{distance};
}

sub hashValueDescendingDist {
    $servers{$b}{distance} <=> $servers{$a}{distance};
}

################################################################################
# Create list of closest servers
################################################################################
my @closestservers = ();
foreach my $name ( sort hashValueAscendingDist ( keys(%servers) ) ) {
    my $info = $servers{$name}{distance};
    if ( @closestservers < $numservers ) {
        push( @closestservers, $name );
    }
    if ( $DBG > 2 ) {
        my $df = sprintf( "%05.11f", $info );
        printf( "== serverdistance:: %5.5s: %17s ==\n", $name, $df );
    }
}
if ( $DBG > 1 ) {
    if ( $DBG > 2 ) {
        print "===============================================\n";
    }
    print "done. =\n";
}

################################################################################
# Set number of ping tests against candidate servers
################################################################################
# Error if input is less than one.
if ($optpings) {
    if ( $optpings > 0 ) {
        $numpingtest = $optpings;
    }
    else {
        print STDERR "Value \"$optpings\" invalid for number of ping tests ";
        print STDERR "option.\nPlease select an integer greater than zero.\n";
        pod2usage(1);
    }
}
if ( $DBG > 2 ) {
    print "== Number of Ping Tests Set to $numpingtest ==\n";
}

################################################################################
# Hash sorting functions
################################################################################
sub hashValueAscendingPing {
    $latencyresults{$a}{avgelapsed} <=> $latencyresults{$b}{avgelapsed};
}

sub hashValueDescendingPing {
    $latencyresults{$b}{avgelapsed} <=> $latencyresults{$a}{avgelapsed};
}

################################################################################
# Select best server based on ping from pool of closest servers
################################################################################
if ( $DBG > 1 ) {
    print "= Selecting best server based on ping...\n";
    if ( $DBG > 2 ) {
        print "\n";
    }
}
foreach my $server (@closestservers) {
    if ( $DBG > 1 ) {
        print "= Checking $servers{$server}{name} Hosted by ";
        print "$servers{$server}{sponsor}";
        if ( $DBG > 2 ) {
            printf( "\n================ SERVER: %5.5s ================\n",
                $server );
            foreach my $serveratt (@serveratts) {
                printf( "== %8.8s: %-31.31s ==\n",
                    $serveratt, $servers{$server}{$serveratt} );
            }
            print "===============================================\n";
        }
    }
    my ( $scheme, $auth, $path, $query, $frag ) =
      uri_split( $servers{$server}{url} );
    my $dirname   = dirname($path);
    my $url       = uri_join( $scheme, $auth, $dirname );
    my $pingcount = 0;
    $latencyresults{$server}{totalelapsed} = 0;
    $latencyresults{$server}{totalpings}   = 0;
    while ( $pingcount < $numpingtest ) {

        if ( $DBG > 1 ) {
            print ".";
            if ( $DBG > 2 ) {
                print "\n";
            }
        }

        ( $sepoch, $usecepoch ) = gettimeofday();
        $msecepoch = ( $usecepoch / 1000 );
        $msepoch = sprintf( "%010d%03.0f", $sepoch, $msecepoch );
        my $latencyuri = $url . "/latency.txt?x=" . $msepoch;
        if ( $DBG > 2 ) {
            print "== Retrieving $latencyuri latency $pingcount took ";
        }

        $browser->setopt( CURLOPT_URL, $latencyuri );
        my $latencytxt;
        $browser->setopt( CURLOPT_WRITEDATA, \$latencytxt );
        ( my $s0, my $usec0 ) = gettimeofday();
        $retcode = $browser->perform;
        ( my $s1, my $usec1 ) = gettimeofday();
        warn "\nCannot get $latencyuri -- $retcode "
          . $browser->strerror($retcode) . " "
          . $browser->errbuf . "\n"
          unless ( $retcode == 0 );
        warn "\nDid not receive TXT, got -- ",
          $browser->getinfo(CURLINFO_CONTENT_TYPE)
          unless $browser->getinfo(CURLINFO_CONTENT_TYPE) =~ m/^text\/plain/;
        my $selapsed        = $s1 - $s0;
        my $usecelapsed     = $usec1 - $usec0;
        my $stomselapsed    = ( $selapsed * 1000 );
        my $usectomselapsed = ( $usecelapsed / 1000 );
        my $mselapsed       = $stomselapsed + $usectomselapsed;

        if (   $latencytxt =~ m/^test=test/
            && $browser->getinfo(CURLINFO_CONTENT_TYPE) =~ m/^text\/plain/
            && ( $retcode == 0 ) )
        {
            $latencyresults{$server}{totalelapsed} =
              $latencyresults{$server}{totalelapsed} + $mselapsed;
            $latencyresults{$server}{totalpings}++;
        }
        if ( $DBG > 2 ) {
            print "$mselapsed milliseconds. done. ==\n";
        }

        $pingcount++;
    }
    if ( $DBG > 2 ) {
        print "== $latencyresults{$server}{totalpings} runs took ";
        print "$latencyresults{$server}{totalelapsed} milliseconds. ==\n";
    }
    $latencyresults{$server}{avgelapsed} =
      $latencyresults{$server}{totalelapsed} /
      $latencyresults{$server}{totalpings};

    if ( $DBG > 1 ) {
        printf( "done: %.${DBG}f millisecond average. =\n",
            $latencyresults{$server}{avgelapsed} );
    }
}
my $bestserver = -1;
if ( $DBG > 2 ) {
    print "================ PING AVERAGE =================\n";
}
foreach my $name ( sort hashValueDescendingPing ( keys(%latencyresults) ) ) {
    my $info = $latencyresults{$name}{avgelapsed};
    if ( $DBG > 2 ) {
        printf( "== pingaverage:: %5.5s: %-20.20s ==\n", $name, $info );
    }
    $bestserver = $name;
}
if ( $DBG > 0 ) {
    if ( $DBG > 2 ) {
        print "===============================================\n";
    }
    my $distancekm = sprintf( "%.${DBG}f", $servers{$bestserver}{distance} );
    my $distancemi =
      sprintf( "%.${DBG}f", ( $servers{$bestserver}{distance} * 0.621371 ) );
    print "Server Selected: $servers{$bestserver}{name} Hosted by ";
    print "$servers{$bestserver}{sponsor}\n";
    print "Distance Between Client and Server: $distancekm km ";
    print "($distancemi mi)\n";
    if ( $DBG > 1 ) {
        print "done. =\n";
    }
}

################################################################################
# Set number of latency tests against selected server
################################################################################
# Error if input is less than one.
if ($optcount) {
    if ( $optcount > 0 ) {
        $numpingcount = $optcount;
    }
    else {
        print STDERR "Value \"$optcount\" invalid for count of latency tests ";
        print STDERR "option.\nPlease select an integer greater than zero.\n";
        pod2usage(1);
    }
}
if ( $DBG > 2 ) {
    print "== Count of Latency Tests Set to $numpingcount ==\n";
}

################################################################################
# PING/latency test against selected server
################################################################################
if ( $DBG > 1 ) {
    print "= Checking ping against $servers{$bestserver}{name} Hosted by ";
    print "$servers{$bestserver}{sponsor}\n";
    if ( $DBG > 2 ) {
        printf( "\n================ SERVER: %5.5s ================\n",
            $bestserver );
        foreach my $serveratt (@serveratts) {
            printf( "== %8.8s: %-31.31s ==\n",
                $serveratt, $servers{$bestserver}{$serveratt} );
        }
        print "===============================================\n";
    }
}
my ( $scheme, $auth, $path, $query, $frag ) =
  uri_split( $servers{$bestserver}{url} );
my $dirname = dirname($path);
my $url = uri_join( $scheme, $auth, $dirname );
my ( $scheme2, $auth2, $path2, $query2, $frag2 ) =
  uri_split( $servers{$bestserver}{url2} );
my $dirname2  = dirname($path2);
my $url2      = uri_join( $scheme2, $auth2, $dirname2 );
my $pingcount = 0;
$latencyresults{$bestserver}{totalelapsed} = 0;
$latencyresults{$bestserver}{totalpings}   = 0;

while ( $pingcount < $numpingcount ) {

    ( $sepoch, $usecepoch ) = gettimeofday();
    $msecepoch = ( $usecepoch / 1000 );
    $msepoch = sprintf( "%010d%03.0f", $sepoch, $msecepoch );
    my $latencyuri = $url . "/latency.txt?x=" . $msepoch;
    if ( $DBG > 2 ) {
        print "\n== Retrieving $latencyuri latency $pingcount took ";
    }

    $browser->setopt( CURLOPT_URL, $latencyuri );
    my $latencytxt;
    $browser->setopt( CURLOPT_WRITEDATA, \$latencytxt );
    ( my $s0, my $usec0 ) = gettimeofday();
    $retcode = $browser->perform;
    ( my $s1, my $usec1 ) = gettimeofday();
    warn "\nCannot get $latencyuri -- $retcode "
      . $browser->strerror($retcode) . " "
      . $browser->errbuf . "\n"
      unless ( $retcode == 0 );
    warn "\nDid not receive TXT, got -- ",
      $browser->getinfo(CURLINFO_CONTENT_TYPE)
      unless $browser->getinfo(CURLINFO_CONTENT_TYPE) =~ m/^text\/plain/;
    my $selapsed        = $s1 - $s0;
    my $usecelapsed     = $usec1 - $usec0;
    my $stomselapsed    = ( $selapsed * 1000 );
    my $usectomselapsed = ( $usecelapsed / 1000 );
    my $mselapsed       = $stomselapsed + $usectomselapsed;

    if (   $latencytxt =~ m/^test=test/
        && $browser->getinfo(CURLINFO_CONTENT_TYPE) =~ m/^text\/plain/
        && ( $retcode == 0 ) )
    {
        $latencyresults{$bestserver}{totalelapsed} =
          $latencyresults{$bestserver}{totalelapsed} + $mselapsed;
        $latencyresults{$bestserver}{totalpings}++;
    }
    if ( $DBG > 1 ) {
        if ( $DBG > 2 ) {
            print "$mselapsed milliseconds. done. ==\n";
        }
        $latencyresults{$bestserver}{avgelapsed} =
          $latencyresults{$bestserver}{totalelapsed} /
          $latencyresults{$bestserver}{totalpings};
        printf( "Ping: %.${DBG}f ms\r",
            $latencyresults{$bestserver}{avgelapsed} );
    }

    $pingcount++;
}
$latencyresults{$bestserver}{avgelapsed} =
  $latencyresults{$bestserver}{totalelapsed} /
  $latencyresults{$bestserver}{totalpings};
printf( "Ping: %.${DBG}f ms\n", $latencyresults{$bestserver}{avgelapsed} );

if ( $DBG > 1 ) {
    if ( $DBG > 2 ) {
        print "== $latencyresults{$bestserver}{totalpings} runs took ";
        printf( "%.${DBG}f milliseconds. ==\n",
            $latencyresults{$bestserver}{totalelapsed} );
    }
    printf( "done: %.${DBG}f millisecond average. =\n",
        $latencyresults{$bestserver}{avgelapsed} );
}

################################################################################
# DOWNLOAD test against selected server
################################################################################
if ( $DBG > 1 ) {
    print "= Checking download against $servers{$bestserver}{name} Hosted by ";
    print "$servers{$bestserver}{sponsor}\n";
}

my @jpghwpixels = (
    "350",  "500",  "750",  "1000", "1500", "2000",
    "2500", "3000", "3500", "4000", "-1"
);
my $totaldltime = 0;
my $totaldlsize = 0;
my $avgdlspeed  = 0;
my $lastjpghwpixel;

foreach my $jpghwpixel (@jpghwpixels) {
    if (   ( $jpghwpixel == 350 && $avgdlspeed < 1.225 && $avgdlspeed >= 0 )
        || ( $jpghwpixel == 500 && $avgdlspeed < 2.5   && $avgdlspeed >= 1.225 )
        || ( $jpghwpixel == 750 && $avgdlspeed < 5.626 && $avgdlspeed >= 2.5 )
        || ( $jpghwpixel == 1000 && $avgdlspeed < 10   && $avgdlspeed >= 5.626 )
        || ( $jpghwpixel == 1500 && $avgdlspeed < 22.5 && $avgdlspeed >= 10 )
        || ( $jpghwpixel == 2000 && $avgdlspeed < 40   && $avgdlspeed >= 22.5 )
        || ( $jpghwpixel == 2500 && $avgdlspeed < 62.5 && $avgdlspeed >= 40 )
        || ( $jpghwpixel == 3000 && $avgdlspeed < 90   && $avgdlspeed >= 62.5 )
        || ( $jpghwpixel == 3500 && $avgdlspeed < 122.5 && $avgdlspeed >= 90 )
        || ( $jpghwpixel == 4000 && $avgdlspeed >= 122.5 )
        || ( $jpghwpixel == -1 ) )
    {
        my $dlurl  = $url;
        my $ycount = 3;
        my $y      = 1;
        if ( $jpghwpixel == -1 ) {
            $jpghwpixel = $lastjpghwpixel;
            $dlurl      = $url2;
            $ycount     = 5;
            $y          = 3;
        }
        else {
            $lastjpghwpixel = $jpghwpixel;
            $dlurl          = $url;
            $ycount         = 3;
            $y              = 1;
        }
        while ( $y < $ycount ) {
            print "∨";    ## ∧ (logical and) and ∨ (logical or) characters
            ( $sepoch, $usecepoch ) = gettimeofday();
            $msecepoch = ( $usecepoch / 1000 );
            $msepoch = sprintf( "%010d%03.0f", $sepoch, $msecepoch );
            my $dlspeeduri =
                $dlurl
              . "/random${jpghwpixel}x${jpghwpixel}.jpg?x="
              . $msepoch . "&y="
              . $y;
            if ( $DBG > 2 ) {
                print "\n== Retrieving $dlspeeduri dlspeed $y took ";
            }

            $browser->setopt( CURLOPT_URL, $dlspeeduri );
            my $dlspeedjpg;
            $browser->setopt( CURLOPT_WRITEDATA, \$dlspeedjpg );
            ( my $s0, my $usec0 ) = gettimeofday();
            $retcode = $browser->perform;
            ( my $s1, my $usec1 ) = gettimeofday();
            warn "\nCannot get $dlspeeduri -- $retcode "
              . $browser->strerror($retcode) . " "
              . $browser->errbuf . "\n"
              unless ( $retcode == 0 );
            warn "\nDid not receive JPG, got -- ",
              $browser->getinfo(CURLINFO_CONTENT_TYPE)
              unless $browser->getinfo(CURLINFO_CONTENT_TYPE) eq 'image/jpeg';
            my $selapsed        = $s1 - $s0;
            my $usecelapsed     = $usec1 - $usec0;
            my $stomselapsed    = ( $selapsed * 1000 );
            my $usectomselapsed = ( $usecelapsed / 1000 );
            my $mselapsed       = $stomselapsed + $usectomselapsed;

            if ( $browser->getinfo(CURLINFO_CONTENT_TYPE) eq 'image/jpeg'
                && ( $retcode == 0 ) )
            {
                $totaldltime = $totaldltime + ( $mselapsed / 1000 );
                $totaldlsize =
                  $totaldlsize + ( length($dlspeedjpg) * 8 / 1000000 );
                $avgdlspeed = $totaldlsize / $totaldltime;
            }
            undef $dlspeedjpg;
            if ( $DBG > 1 ) {
                if ( $DBG > 2 ) {
                    print "$mselapsed milliseconds. done. ==\n";
                }
                printf( "Download Speed: %.${DBG}f Mbps\r", $avgdlspeed );
            }
            $y++;
        }
        print "\r";
    }
}

printf( "Download Speed: %.${DBG}f Mbps\n", $avgdlspeed );
if ( $DBG > 1 ) {
    printf( "done: %.${DBG}f Megabits per second. =\n", $avgdlspeed );
}

################################################################################
# All done
################################################################################
exit 0;

 __END__
