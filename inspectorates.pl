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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

#################################################################################
# Import some semantics into the current package from the named modules
#################################################################################
use strict;         # Restrict unsafe constructs
use warnings;       # Control optional warnings
use Getopt::Long;   # Getopt::Long - Extended processing of command line options
use LWP 5.64;       # LWP - The World-Wide Web library for Perl
use Math::Trig;     # Math::Trig - Trigonometric functions
use Pod::Usage;     # Pod::Usage - Print usage message from embedded pod docs
use XML::XPath;     # XML::XPath - Parsing and evaluating XPath statements

#################################################################################
# Declare constants
#################################################################################
$ENV{PATH}  = "/usr/bin:/bin";    # Keep taint happy
$ENV{PAGER} = "more";             # Keep pod2usage output happy

my $name    = "%{NAME}";          # Name string
my $version = "%{VERSION}";       # Version number
my $release = "%{RELEASE}";       # Release string

my $protocol = "http";            # Use unencrypted HTTP protocol
my $domain   = "speedtest.net";   # Speedtest.net domain
my $host     = "www";             # World-Wide Web host

#################################################################################
# Generate composite constants
#################################################################################
my $wsnuri = "$protocol://$host.$domain";
my $csnuri = "$protocol://c.$domain";

my $cnfguri = "$wsnuri/speedtest-config.php";
my $srvruri = "$wsnuri/speedtest-servers.php";
my $aapiuri = "$wsnuri/api/api.php";
my $flshuri = "$csnuri/flash/speedtest.swf";
my $rslturi = "$wsnuri/result/%s.png";

#################################################################################
# Specify module configuration options to be enabled
#################################################################################
# Allow single-character options to be bundled. To distinguish bundles from long
# option names, long options must be introduced with '--' and bundles with '-'.
# Do not allow '+' to start options.
Getopt::Long::Configure(qw(bundling no_getopt_compat));

#################################################################################
# Initialize variables
#################################################################################
my $DBG = 1;
my $optdebug;
my $opthelp;
my $optman;
my $optquiet;
my $optverbose;
my $optversion;

#################################################################################
# Parse command line options.  This function adheres to the POSIX syntax for CLI
# options, with GNU extensions.
#################################################################################
GetOptions(
    "h"       => \$opthelp,
    "help"    => \$opthelp,
    "m"       => \$optman,
    "man"     => \$optman,
    "d"       => \$optdebug,
    "debug"   => \$optdebug,
    "q"       => \$optquiet,
    "quiet"   => \$optquiet,
    "v"       => \$optverbose,
    "verbose" => \$optverbose,
    "V"       => \$optversion,
    "version" => \$optversion
) or pod2usage(2);

#################################################################################
# Help function
#################################################################################
pod2usage(1) if $opthelp;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $optman;

#################################################################################
# Version function
#################################################################################
if ($optversion) {
    print "$name $version ($release)\n";
    exit 0;
}

#################################################################################
# Set output level
#################################################################################
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

#################################################################################
# Main function
#################################################################################
my $browser = LWP::UserAgent->new;

#################################################################################
# Retrieve speedtest.net configuration
#################################################################################
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

#################################################################################
# Read speedtest.net configuration
#################################################################################
if ( $DBG > 1 ) {
    print "= Read $domain configuration...";
}
my $configxp = XML::XPath->new( $configxml->content );
if ( $DBG > 1 ) {
    print "done. =\n";
}

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

my %times;
$times{dl1} = $configxp->find('/settings/times/@dl1');
$times{dl2} = $configxp->find('/settings/times/@dl2');
$times{dl3} = $configxp->find('/settings/times/@dl3');
$times{ul1} = $configxp->find('/settings/times/@ul1');
$times{ul2} = $configxp->find('/settings/times/@ul2');
$times{ul3} = $configxp->find('/settings/times/@ul3');

my %download;
$download{testlength}  = $configxp->find('/settings/download/@testlength');
$download{initialtest} = $configxp->find('/settings/download/@initialtest');
$download{mintestsize} = $configxp->find('/settings/download/@mintestsize');

my %upload;
$upload{testlength}    = $configxp->find('/settings/upload/@testlength');
$upload{ratio}         = $configxp->find('/settings/upload/@ratio');
$upload{initialtest}   = $configxp->find('/settings/upload/@initialtest');
$upload{mintestsize}   = $configxp->find('/settings/upload/@mintestsize');
$upload{threads}       = $configxp->find('/settings/upload/@threads');
$upload{maxchunksize}  = $configxp->find('/settings/upload/@maxchunksize');
$upload{maxchunkcount} = $configxp->find('/settings/upload/@maxchunkcount');

if ( $DBG > 2 ) {
    foreach my $name ( sort keys %client ) {
        my $info = $client{$name};
        print "== client:: $name: $info ==\n";
    }
    foreach my $name ( sort keys %times ) {
        my $info = $times{$name};
        print "== times:: $name: $info ==\n";
    }
    foreach my $name ( sort keys %download ) {
        my $info = $download{$name};
        print "== download:: $name: $info ==\n";
    }
    foreach my $name ( sort keys %upload ) {
        my $info = $upload{$name};
        print "== upload:: $name: $info ==\n";
    }
}

if ( $DBG > 1 ) {
    print "= Determining the five closest $domain servers =\n";
    print "= based on geographic distance...";
}
my $serversxml = $browser->get($srvruri);
die "\nCannot get $srvruri -- ", $serversxml->status_line
  unless $serversxml->is_success;
die "\nDid not receive XML, got -- ", $serversxml->content_type
  unless $serversxml->content_type eq 'text/xml';
if ( $DBG > 1 ) {
    print "done. =\n";
}

my $serversxp   = XML::XPath->new( $serversxml->content );
my $servernodes = $serversxp->find('/settings/servers/server');

my %serverdistance;
foreach my $serverid ( $servernodes->get_nodelist ) {
    my $id     = $serverid->find('@id')->string_value;
    my $lat    = $serverid->find('@lat')->string_value;
    my $lon    = $serverid->find('@lon')->string_value;
    my $radius = 6371;

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
    $serverdistance{$id} = $d;
}

sub hashValueAscendingNum {
    $serverdistance{$a} <=> $serverdistance{$b};
}

sub hashValueDescendingNum {
    $serverdistance{$b} <=> $serverdistance{$a};
}

my @closestservers = ();
foreach my $name ( sort hashValueAscendingNum ( keys(%serverdistance) ) ) {
    my $info = $serverdistance{$name};
    if ( @closestservers < 5 ) {
        push( @closestservers, $name );
    }
    if ( $DBG > 2 ) {
        print "== serverdistance:: $name: $info ==\n";
    }
}

if ( $DBG > 1 ) {
    print "= Selecting best server based on ping...";
    if ( $DBG > 2 ) {
        print "\n";
    }
}
foreach my $server (@closestservers) {
    if ( $DBG > 2 ) {
        print "== SERVER: $server ==\n";
    }
}
if ( $DBG > 1 ) {
    print "done. =\n";
}

exit 0;

 __END__
