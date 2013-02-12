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
use LWP 5.64;                          # LWP - The World-Wide Web library for
                                       # Perl
use Math::Trig;                        # Math::Trig - trigonometric functions
use Pod::Usage;                        # Pod::Usage, pod2usage() - print a
                                       # usage message from embedded pod
                                       # documentation
use Time::HiRes qw(gettimeofday);      # Time::HiRes - High resolution alarm,
                                       # sleep, gettimeofday, interval timers
use URI::Split qw(uri_split uri_join); # URI::Split - Parse and compose URI
                                       # strings
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

my $optdebug;
my $opthelp;
my $optman;
my $optpings;
my $optquiet;
my $optverbose;
my $optversion;
my $optservers;

################################################################################
# Parse command line options.  This function adheres to the POSIX syntax for CLI
# options, with GNU extensions.
################################################################################
GetOptions(
    "h"         => \$opthelp,
    "help"      => \$opthelp,
    "m"         => \$optman,
    "man"       => \$optman,
    "d"         => \$optdebug,
    "debug"     => \$optdebug,
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
}
if ($optdebug) {
    $DBG = 3;
}
if ( $DBG > 2 ) {
    print "== Debugging Level Set to $DBG ==\n";
    print "== $name $version ($release) ==\n";
    print "== This is libwww-perl-$LWP::VERSION ==\n";
}

################################################################################
# Main function
################################################################################
if ( $DBG > 0 ) {
    print "Loading...\n";
}
my $browser = LWP::UserAgent->new;

################################################################################
# Retrieve speedtest.net configuration
################################################################################
if ( $DBG > 1 ) {
    print "= Retrieving $domain configuration...";
}

my $configxml = $browser->get($cnfguri);
die "\nCannot get $cnfguri -- ", $configxml->status_line
  unless $configxml->is_success;
die "\nDid not receive XML, got -- ", $configxml->content_type
  unless $configxml->content_type eq 'text/xml';
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

my $configxp = XML::XPath->new( $configxml->content );

# client settings hash
my %client;
$client{ip}        = $configxp->find('/settings/client/@ip');
$client{lat}       = $configxp->find('/settings/client/@lat')->string_value;
$client{lon}       = $configxp->find('/settings/client/@lon')->string_value;
$client{isp}       = $configxp->find('/settings/client/@isp');
$client{isprating} = $configxp->find('/settings/client/@isprating');
$client{rating}    = $configxp->find('/settings/client/@rating');
$client{ispdlavg}  = $configxp->find('/settings/client/@ispdlavg');
$client{ispulavg}  = $configxp->find('/settings/client/@ispulavg');
$client{loggedin}  = $configxp->find('/settings/client/@loggedin');

# times settings hash
my %times;
$times{dl1} = $configxp->find('/settings/times/@dl1');
$times{dl2} = $configxp->find('/settings/times/@dl2');
$times{dl3} = $configxp->find('/settings/times/@dl3');
$times{ul1} = $configxp->find('/settings/times/@ul1');
$times{ul2} = $configxp->find('/settings/times/@ul2');
$times{ul3} = $configxp->find('/settings/times/@ul3');

# download settings hash
my %download;
$download{testlength}  = $configxp->find('/settings/download/@testlength');
$download{initialtest} = $configxp->find('/settings/download/@initialtest');
$download{mintestsize} = $configxp->find('/settings/download/@mintestsize');

# upload settings hash
my %upload;
$upload{testlength}    = $configxp->find('/settings/upload/@testlength');
$upload{ratio}         = $configxp->find('/settings/upload/@ratio');
$upload{initialtest}   = $configxp->find('/settings/upload/@initialtest');
$upload{mintestsize}   = $configxp->find('/settings/upload/@mintestsize');
$upload{threads}       = $configxp->find('/settings/upload/@threads');
$upload{maxchunksize}  = $configxp->find('/settings/upload/@maxchunksize');
$upload{maxchunkcount} = $configxp->find('/settings/upload/@maxchunkcount');
if ( $DBG > 2 ) {

    foreach my $name ( keys %client ) {
        my $info = $client{$name};
        print "== client:: $name: $info ==\n";
    }
    foreach my $name ( keys %times ) {
        my $info = $times{$name};
        print "== times:: $name: $info ==\n";
    }
    foreach my $name ( keys %download ) {
        my $info = $download{$name};
        print "== download:: $name: $info ==\n";
    }
    foreach my $name ( keys %upload ) {
        my $info = $upload{$name};
        print "== upload:: $name: $info ==\n";
    }
}
if ( $DBG > 1 ) {
    print "done. =\n";
}
if ( $DBG > 0 ) {
    print "Client IP Address: $client{ip}\n";
    print "Client Internet Service Provider: $client{isp}\n";
}
################################################################################
# Retrieve speedtest.net servers list
################################################################################
if ( $DBG > 1 ) {
    print "= Retrieving $domain servers list...";
}

my $serversxml = $browser->get($srvruri);
die "\nCannot get $srvruri -- ", $serversxml->status_line
  unless $serversxml->is_success;
die "\nDid not receive XML, got -- ", $serversxml->content_type
  unless $serversxml->content_type eq 'text/xml';
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

my $serversxp   = XML::XPath->new( $serversxml->content );
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

if ( $DBG > 2 ) {
    foreach my $name ( keys %servers ) {
        print "== servers:: $name: ";
        foreach my $serveratt (@serveratts) {
            print " $serveratt: $servers{$name}{$serveratt}";
        }
        print " ==\n";
    }
}
if ( $DBG > 1 ) {
    print "done. =\n";
}

################################################################################
# Determine the distance between the client and all test servers
################################################################################
if ( $DBG > 1 ) {
    print "= Determining the distance between client and $domain servers...";
    if ( $DBG > 2 ) {
        print "\n";
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
        print "== $id a: $a c: $c d: $d ==\n";
    }
    $servers{$id}{distance} = $d;
    $totalservers++;
}
if ( $DBG > 2 ) {
    print "== Total number of test servers: $totalservers ==\n";
}
if ( $DBG > 1 ) {
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
if ( $DBG > 2 ) {
    print "== Number of Test Servers Set to $numservers ==\n";
}
if ( $DBG > 1 ) {
    print "= Determining the $numservers closest $domain servers =\n";
    print "= based on geographic distance...";
    if ( $DBG > 2 ) {
        print "\n";
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
        print "== serverdistance:: $name: $info ==\n";
    }
}
if ( $DBG > 1 ) {
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
            print "== SERVER: $server ==\n";
            foreach my $serveratt (@serveratts) {
                print "== \t $serveratt: $servers{$server}{$serveratt} ==\n";
            }
            print " ==\n";
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
        my $latencyuri = $url . "/latency.txt";
        if ( $DBG > 2 ) {
            print "== Retrieving $url latency $pingcount took ";
        }

        my $t0         = gettimeofday;
        my $latencytxt = $browser->get($latencyuri);
        my $t1         = gettimeofday;
        warn "\nCannot get $latencyuri -- ", $latencytxt->status_line
          unless $latencytxt->is_success;
        warn "\nDid not receive TXT, got -- ", $latencytxt->content_type
          unless $latencytxt->content_type eq 'text/plain';
        my $elapsed = $t1 - $t0;
        if (   $latencytxt->decoded_content =~ m/^test=test/
            && $latencytxt->content_type eq 'text/plain'
            && $latencytxt->is_success )
        {
            $latencyresults{$server}{totalelapsed} =
              $latencyresults{$server}{totalelapsed} + $elapsed;
            $latencyresults{$server}{totalpings}++;
        }
        if ( $DBG > 2 ) {
            print "$elapsed seconds. done. ==\n";
        }

        $pingcount++;
    }
    if ( $DBG > 2 ) {
        print "== $latencyresults{$server}{totalpings} runs took ";
        print "$latencyresults{$server}{totalelapsed} seconds. ==\n";
    }
    $latencyresults{$server}{avgelapsed} =
      $latencyresults{$server}{totalelapsed} /
      $latencyresults{$server}{totalpings};

    if ( $DBG > 1 ) {
        print "done: $latencyresults{$server}{avgelapsed} second average. =\n";
    }
}
my $bestserver = -1;
foreach my $name ( sort hashValueDescendingPing ( keys(%latencyresults) ) ) {
    my $info = $latencyresults{$name}{avgelapsed};
    if ( $DBG > 2 ) {
        print "== pingaverage:: $name: $info ==\n";
    }
    $bestserver = $name;
}
if ( $DBG > 0 ) {
    print "Server Selected: $servers{$bestserver}{name} Hosted by ";
    print "$servers{$bestserver}{sponsor}\n";
}
if ( $DBG > 1 ) {
    print "done. =\n";
}

################################################################################
# All done
################################################################################
exit 0;

 __END__
