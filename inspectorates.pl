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
use strict;                               # Restrict unsafe constructs
use warnings;                             # Control optional warnings
use Data::Dumper::Names;                  # Data::Dumper::Names - Dump variables
                                          # with names (no source filter)
use Data::Random qw(rand_image);          # Data::Random - Perl module to
                                          # generate random data
use File::Basename qw(dirname);           # File::Basename - Parse file paths
                                          # into directory, filename and suffix.
use GD;                                   # GD.pm - Interface to Gd Graphics
                                          # Library
use Getopt::Long;                         # Getopt::Long - Extended processing
                                          # of command line options
use Locale::Country;                      # Locale::Country - standard codes for
                                          # country identification
use Math::Trig qw(deg2rad);               # Math::Trig - trigonometric functions
use Pod::Usage;                           # Pod::Usage, pod2usage() - print a
                                          # usage message from embedded pod
                                          # documentation
use Time::HiRes qw(gettimeofday usleep);  # Time::HiRes - High resolution alarm,
                                          # sleep, gettimeofday, interval timers
use URI::Split qw(uri_split uri_join);    # URI::Split - Parse and compose URI
                                          # strings
use WWW::Curl::Easy;                      # WWW::Curl - Perl extension interface
                                          # for libcurl
use XML::XPath;                           # XML::XPath - a set of modules for
                                          # parsing and evaluating XPath
                                          # statements

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
my $gndomain = "geonames.org";    # GeoNames domain
my $gnhost   = "api";             # API host

my $gnusername = "bdperkin";      # Username for GeoNames API

################################################################################
# Generate composite constants
################################################################################
my $wsnuri = "$protocol://$host.$domain";
my $csnuri = "$protocol://c.$domain";
my $gnouri = "$protocol://$gnhost.$gndomain";

my $cnfguri = "$wsnuri/speedtest-config.php";
my $srvruri = "$wsnuri/speedtest-servers.php";
my $aapiuri = "$wsnuri/api/api.php";
my $flshuri = "$csnuri/flash/speedtest.swf";
my $rslturi = "$wsnuri/result/%s.png";
my $gefnuri = "$gnouri/extendedFindNearby";

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
my $DBG            = 1;  # Set debug output level:
                         #   0 -- quiet
                         #   1 -- normal
                         #   2 -- verbose
                         #   3 -- debug
my $dbgtablewidth  = 47;
my $numservers     = 5;
my $totalservers   = 0;
my $numpingtest    = 3;
my $numpingcount   = 10; # Number of samples to use for calculating HTTP latency
                         # (default = 10), 0 will disable the latency test
my $curloptverbose = 0;  # Set the parameter to 1 to get the library to display
                         # a lot of verbose information about its operations.
                         # Very useful for libcurl and/or protocol debugging and
                         # understanding. The verbose information will be sent
                         # to stderr, or the stream set with CURLOPT_STDERR. The
                         # default value for this parameter is 0.

################################################################################
# Parse command line options.  This function adheres to the POSIX syntax for CLI
# options, with GNU extensions.
################################################################################
# Initialize GetOptions variables
my $optcount;
my $optcurlverbose;
my $optdebug;
my $optid;
my $opthelp;
my $optlist;
my $optman;
my $optpings;
my $optquiet;
my $optservers;
my $opturl;
my $optverbose;
my $optversion;

# Variables with multiple values stored as arrays
my @incnm;
my @excnm;
my @inccntry;
my @exccntry;
my @inccc;
my @exccc;
my @incspnsr;
my @excspnsr;
my @incdskmgt;
my @excdskmgt;
my @incdsmigt;
my @excdsmigt;
my @incdskmlt;
my @excdskmlt;
my @incdsmilt;
my @excdsmilt;

GetOptions(
    "c=i"                      => \$optcount,
    "count=i"                  => \$optcount,
    "C"                        => \$optcurlverbose,
    "curlvrbs"                 => \$optcurlverbose,
    "d"                        => \$optdebug,
    "debug"                    => \$optdebug,
    "exclude-cc=s"             => \@exccc,
    "exclude-country=s"        => \@exccntry,
    "exclude-distance-km-gt=f" => \@excdskmgt,
    "exclude-distance-km-lt=f" => \@excdskmlt,
    "exclude-distance-mi-gt=f" => \@excdsmigt,
    "exclude-distance-mi-lt=f" => \@excdsmilt,
    "exclude-name=s"           => \@excnm,
    "exclude-sponsor=s"        => \@excspnsr,
    "h"                        => \$opthelp,
    "help"                     => \$opthelp,
    "i=i"                      => \$optid,
    "id=i"                     => \$optid,
    "include-cc=s"             => \@inccc,
    "include-country=s"        => \@inccntry,
    "include-distance-km-gt=f" => \@incdskmgt,
    "include-distance-km-lt=f" => \@incdskmlt,
    "include-distance-mi-gt=f" => \@incdsmigt,
    "include-distance-mi-lt=f" => \@incdsmilt,
    "include-name=s"           => \@incnm,
    "include-sponsor=s"        => \@incspnsr,
    "l"                        => \$optlist,
    "list"                     => \$optlist,
    "m"                        => \$optman,
    "man"                      => \$optman,
    "p=i"                      => \$optpings,
    "pings=i"                  => \$optpings,
    "q"                        => \$optquiet,
    "quiet"                    => \$optquiet,
    "s=i"                      => \$optservers,
    "servers=i"                => \$optservers,
    "u=s"                      => \$opturl,
    "url=s"                    => \$opturl,
    "v"                        => \$optverbose,
    "verbose"                  => \$optverbose,
    "V"                        => \$optversion,
    "version"                  => \$optversion
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
    my $title = "general";
    $title =~ tr/a-z/A-Z/;
    my $eqsgns  = ( ( $dbgtablewidth - length($title) - 2 ) / 2 );
    my $eqcount = 0;
    my $eqhr    = "";
    while ( $eqcount < $eqsgns ) {
        $eqhr = $eqhr . "=";
        $eqcount++;
    }
    my $hdr = sprintf( "%s %s %s", $eqhr, $title, $eqhr );
    printf( "%${dbgtablewidth}.${dbgtablewidth}s\n", $hdr );
    printf( "== Debugging Level Set to %-18s ==\n",  $DBG );
    printf( "== %-12s %-12s (%-13s) ==\n",        $name, $version, $release );
    printf( "==          PROCESS_ID: %-20s ==\n", $$ );
    printf( "==        PROGRAM_NAME: %-20s ==\n", $0 );
    printf( "==       REAL_GROUP_ID: %-20s ==\n", $( );
    printf( "==  EFFECTIVE_GROUP_ID: %-20s ==\n", $) );
    printf( "==        REAL_USER_ID: %-20s ==\n", $< );
    printf( "==   EFFECTIVE_USER_ID: %-20s ==\n", $> );
    printf( "==              OSNAME: %-20s ==\n", $^O );
    printf( "==            BASETIME: %-20s ==\n", $^T );
    printf( "==        PERL_VERSION: %-20s ==\n", $^V );
    printf( "==     EXECUTABLE_NAME: %-20s ==\n", $^X );
    $title = "Module VERSION";
    $title =~ tr/a-z/A-Z/;
    $eqsgns  = ( ( $dbgtablewidth - length($title) - 2 ) / 2 );
    $eqcount = 0;
    $eqhr    = "";

    while ( $eqcount < $eqsgns ) {
        $eqhr = $eqhr . "=";
        $eqcount++;
    }
    $hdr = sprintf( "%s %s %s", $eqhr, $title, $eqhr );
    printf( "%${dbgtablewidth}.${dbgtablewidth}s\n", $hdr );
    my $maxmodlength = 0;
    foreach my $name ( keys %INC ) {
        my $modlength = length($name);
        if ( $modlength > $maxmodlength ) {
            $maxmodlength = $modlength;
        }
    } ## end foreach my $name ( keys %INC)
    my $modverlength = ( $dbgtablewidth - $maxmodlength - 8 );
    foreach my $name ( sort ( keys %INC ) ) {
        $name =~ s/\//::/g;
        $name =~ s/\.pm$//i;
        my $modvername = ${name} . "::VERSION";
        my $modver     = eval("\$$modvername");
        printf(
"== %${maxmodlength}.${maxmodlength}s: %-${modverlength}.${modverlength}s ==\n",
            $name, $modver
        ) if defined $modver;
    } ## end foreach my $name ( sort ( keys...))
    $eqcount = 0;
    while ( $eqcount < $dbgtablewidth ) {
        printf("=");
        $eqcount++;
    }
    print "\n";
} ## end if ( $DBG > 2 )

################################################################################
# Main function
################################################################################
if ( $DBG > 0 ) {
    print "Loading...\n";
}
my $browser = WWW::Curl::Easy->new;
if ($optcurlverbose) {
    $curloptverbose = 1;
}
$browser->setopt( CURLOPT_VERBOSE, $curloptverbose );
my $curlversion = $browser->version(CURLVERSION_NOW);
chomp $curlversion;
my @curlversions = split( /\s/, $curlversion );
my %libversions;
foreach my $curlver (@curlversions) {
    my ( $lib, $ver ) = split( /\//, $curlver );
    if ($ver) {
        my ( $major, $minor, $patch ) = split( /\./, $ver );
        $libversions{$lib}              = $ver;
        $libversions{ $lib . '-major' } = $major;
        $libversions{ $lib . '-minor' } = $minor;
        $libversions{ $lib . '-patch' } = $patch;
    } ## end if ($ver)
} ## end foreach my $curlver (@curlversions)
if ( $DBG > 2 ) {
    my $title = "curl, libcurl, & 3rd party library versions";
    $title =~ tr/a-z/A-Z/;
    my $eqsgns  = ( ( $dbgtablewidth - length($title) - 2 ) / 2 );
    my $eqcount = 0;
    my $eqhr    = "";

    while ( $eqcount < $eqsgns ) {
        $eqhr = $eqhr . "=";
        $eqcount++;
    }
    my $hdr = sprintf( "%s %s %s", $eqhr, $title, $eqhr );
    printf( "%${dbgtablewidth}.${dbgtablewidth}s\n", $hdr );
    my $maxmodlength = 0;
    foreach my $name ( keys %libversions ) {
        my $modlength = length($name);
        if ( $modlength > $maxmodlength ) {
            $maxmodlength = $modlength;
        }
    } ## end foreach my $name ( keys %libversions)
    my $modverlength = ( $dbgtablewidth - $maxmodlength - 8 );
    foreach my $name ( sort ( keys %libversions ) ) {
        my $info = $libversions{$name};
        printf(
"== %${maxmodlength}.${maxmodlength}s: %-${modverlength}.${modverlength}s ==\n",
            $name, $info
        ) if defined $info;
    } ## end foreach my $name ( sort ( keys...))
    $eqcount = 0;
    while ( $eqcount < $dbgtablewidth ) {
        printf("=");
        $eqcount++;
    }
    print "\n";
} ## end if ( $DBG > 2 )

$browser->setopt( CURLOPT_HEADER,      0 );
$browser->setopt( CURLOPT_NOPROGRESS,  1 );
$browser->setopt( CURLOPT_TCP_NODELAY, 1 );
$browser->setopt( CURLOPT_USERAGENT,   "$name/$version" );
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
} ## end if ( $DBG > 1 )

$browser->setopt( CURLOPT_URL, $cnfguri );
my $configxml;
$browser->setopt( CURLOPT_WRITEDATA, \$configxml );
$retcode = $browser->perform;
die "\nCannot get $cnfguri -- $retcode "
  . $browser->strerror($retcode) . " "
  . $browser->errbuf . "\n"
  unless ( $retcode == 0 );
die "\nDid not receive XML, got -- ", $browser->getinfo(CURLINFO_CONTENT_TYPE)
  unless $browser->getinfo(CURLINFO_CONTENT_TYPE) =~ m/^(application|text)\/xml/;
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
} ## end if ( $DBG > 1 )

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

my $clientneighbourhoodurl =
  "$gefnuri?lat=$client{lat}&lng=$client{lon}&username=$gnusername";
if ( $DBG > 1 ) {
    print "\n= Retrieving geographic neighbourhood data for $client{isp}...";
    if ( $DBG > 2 ) {
        print "\n== GET $clientneighbourhoodurl ==\n";
    }
} ## end if ( $DBG > 1 )
$browser->setopt( CURLOPT_URL, $clientneighbourhoodurl );
my $clientneighbourhoodxml;
$browser->setopt( CURLOPT_WRITEDATA, \$clientneighbourhoodxml );
$retcode = $browser->perform;
die "\nCannot get $clientneighbourhoodurl -- $retcode "
  . $browser->strerror($retcode) . " "
  . $browser->errbuf . "\n"
  unless ( $retcode == 0 );
if ( $browser->getinfo(CURLINFO_CONTENT_TYPE) !~ m/^(application|text)\/xml/ ) {
    die "\nDid not receive XML, got -- ",
      $browser->getinfo(CURLINFO_CONTENT_TYPE);
}
if ( $DBG > 1 ) {
    print "done. =\n";
}
my $clientneighbourhoodxp = XML::XPath->new($clientneighbourhoodxml);
my @geoatts               = (
    'placename',  'adminCode2', 'adminName2', 'adminCode1',
    'adminName1', 'countryCode'
);
my $clientneighbourhood = "";
if ( $clientneighbourhoodxp->exists('/geonames/address') ) {
    if ( $DBG > 2 ) {
        print "== Address GeoName Available for $client{isp} ==\n";
    }
    foreach my $geoatt (@geoatts) {
        my $att = "/geonames/address/" . $geoatt;
        $client{$geoatt} = $clientneighbourhoodxp->find($att)->string_value;
    }
    if ( $client{countryCode} ) {
        $clientneighbourhood =
          $clientneighbourhood . " => $client{countryCode}";
    }
    if ( $client{adminCode1} || $client{adminName1} ) {
        $clientneighbourhood = $clientneighbourhood . " =>";
        if ( $client{adminCode1} ) {
            $clientneighbourhood =
              $clientneighbourhood . " $client{adminCode1}";
        }
        if ( $client{adminName1} ) {
            $clientneighbourhood =
              $clientneighbourhood . " ($client{adminName1})";
        }
    } ## end if ( $client{adminCode1...})
    if ( $client{adminCode2} || $client{adminName2} ) {
        $clientneighbourhood = $clientneighbourhood . " =>";
        if ( $client{adminCode2} ) {
            $clientneighbourhood =
              $clientneighbourhood . " $client{adminCode2}";
        }
        if ( $client{adminName2} ) {
            $clientneighbourhood =
              $clientneighbourhood . " ($client{adminName2})";
        }
    } ## end if ( $client{adminCode2...})
    if ( $client{placename} ) {
        $clientneighbourhood = $clientneighbourhood . " => $client{placename}";
    }
} elsif ( $clientneighbourhoodxp->exists('/geonames/geoname') ) {
    if ( $DBG > 2 ) {
        print "== GeoName GeoName Available for $client{isp} ==\n";
    }
    my $geonamenodes = $clientneighbourhoodxp->find('/geonames/geoname');
    $client{countryName} = "";
    $client{adminName1}  = "";
    $client{adminName2}  = "";
    $client{placename}   = "";
    foreach my $geoname ( $geonamenodes->get_nodelist ) {
        my $gvalue = $geoname->find('name')->string_value;
        my $gkey   = $geoname->find('fcode')->string_value;
        $client{countryCode} = $geoname->find('countryCode')->string_value;
        $client{countryName} = $geoname->find('countryName')->string_value;
        if ($gvalue) {
            $clientneighbourhood = $clientneighbourhood . " => $gvalue";
        }
        if ( $gkey =~ m/^PCLI/ ) {
            $client{countryName} = $gvalue;
        }
        $client{adminCode1} = "";
        if ( $gkey =~ m/^ADM1/ ) {
            $client{adminName1} = $gvalue;
        }
        $client{adminCode2} = "";
        if ( $gkey =~ m/^ADM2/ ) {
            $client{adminName2} = $gvalue;
        }
        if ( $gkey =~ m/^PP/ ) {
            $client{placename} = $gvalue;
        }
    } ## end foreach my $geoname ( $geonamenodes...)
} elsif ( $clientneighbourhoodxp->exists('/geonames/ocean') ) {
    if ( $DBG > 2 ) {
        print "== Ocean GeoName Available for $client{isp} ==\n";
    }
    foreach my $geoatt (@geoatts) {
        $client{$geoatt} = "";
    }
    my $ocean =
      $clientneighbourhoodxp->find('/geonames/ocean/name')->string_value;
    if ($ocean) {
        $client{placename} = $ocean;
        $clientneighbourhood = $clientneighbourhood . " => $ocean";
    }
} else {
    warn "Unknown geography description:\n$clientneighbourhoodxml\n";
}
$client{neighbourhood} = $clientneighbourhood;
if ( $DBG > 1 ) {
    print "= $clientneighbourhood =\n";
}

$client{clientneighbourhood} = $clientneighbourhood;

# times settings hash
my %times;
$times{dl1} = $configxp->find('/settings/times/@dl1')->string_value;
$times{dl2} = $configxp->find('/settings/times/@dl2')->string_value;
$times{dl3} = $configxp->find('/settings/times/@dl3')->string_value;
$times{ul1} = $configxp->find('/settings/times/@ul1')->string_value;
$times{ul2} = $configxp->find('/settings/times/@ul2')->string_value;
$times{ul3} = $configxp->find('/settings/times/@ul3')->string_value;

# latency settings hash
my %latency;
$latency{testlength} =
  $configxp->find('/settings/latency/@testlength')->string_value;
$latency{waittime} =
  $configxp->find('/settings/latency/@waittime')->string_value;

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
    my @confighashes = ( \%client, \%times, \%latency, \%download, \%upload );
    my $eqcount = 0;
    foreach my $confighash (@confighashes) {
        my ($hashname) = split( /\n/, Dumper( \%$confighash ) );
        $hashname =~ s/^%//g;
        $hashname =~ s/ = \($//g;
        my $title = $hashname;
        $title =~ tr/a-z/A-Z/;
        my $eqsgns = ( ( $dbgtablewidth - length($title) - 2 ) / 2 );
        $eqcount = 0;
        my $eqhr;

        while ( $eqcount < $eqsgns ) {
            $eqhr = $eqhr . "=";
            $eqcount++;
        }
        my $hdr = sprintf( "%s %s %s", $eqhr, $title, $eqhr );
        printf( "%${dbgtablewidth}.${dbgtablewidth}s\n", $hdr );
        my $maxkeylength = 0;
        foreach my $name ( keys %$confighash ) {
            my $keylength = length($name);
            if ( $keylength > $maxkeylength ) {
                $maxkeylength = $keylength;
            }
        } ## end foreach my $name ( keys %$confighash)
        my $vallength = ( $dbgtablewidth - $maxkeylength - 8 );
        foreach my $name ( sort ( keys %$confighash ) ) {
            my $value = $$confighash{$name};
            printf(
"== %${maxkeylength}.${maxkeylength}s: %-${vallength}.${vallength}s ==\n",
                $name, $value
            ) if defined $value;
        } ## end foreach my $name ( sort ( keys...))
    } ## end foreach my $confighash (@confighashes)
    $eqcount = 0;
    while ( $eqcount < $dbgtablewidth ) {
        printf("=");
        $eqcount++;
    }
    printf("\n");
} ## end if ( $DBG > 2 )
if ( $DBG > 0 ) {
    if ( $DBG > 1 ) {
        print "done. =\n";
    }
    print "Client IP Address: $client{ip}\n";
    print
"Client Internet Service Provider: $client{isp}$client{clientneighbourhood}\n";
} ## end if ( $DBG > 0 )

################################################################################
# Process specific Ookla Speedtest® connection testing server
################################################################################
# server attributes
my @settingsserveratts =
  ( 'url', 'lat', 'lon', 'name', 'country', 'cc', 'sponsor', 'id' );
my %settings;
my %settingsservers;
if ($opturl) {
    if ( $DBG > 1 ) {
        print "= Processing URL: $opturl...";
    }
    my ( $scheme, $auth, $path, $query, $frag ) = uri_split($opturl);
    my $dirname = $path;
    $dirname =~ s/\/crossdomain.(php|xml)$//g;
    $dirname =~ s/\/expressInstall.swf$//g;
    $dirname =~ s/\/functions.js$//g;
    $dirname =~ s/\/index.html$//g;
    $dirname =~ s/\/settings.(php|xml)$//g;
    $dirname =~ s/\/speedtest.swf$//g;
    $dirname =~ s/\/swfobject.js$//g;
    $dirname =~ s/\/speedtest\/latency.txt$//g;
    $dirname =~ s/\/speedtest\/random(.)*.jpg$//g;
    $dirname =~ s/\/speedtest\/upload.(php|jsp|aspx|asp)$//g;
    $dirname =~ s/\/$//g;
    my @fqdn     = split( /\./, $auth );
    my $fqdnsize = @fqdn;
    my $namenum  = 0;
    $protocol = $scheme;
    $host     = "";

    while ( $namenum < $fqdnsize ) {
        if ( $namenum < ( $fqdnsize - 2 ) ) {
            $host = $host . "." . $fqdn[$namenum];
        }
        $namenum++;
    } ## end while ( $namenum < $fqdnsize)

    $host =~ s/^\.//g;
    $domain  = $fqdn[ $fqdnsize - 2 ] . "." . $fqdn[ $fqdnsize - 1 ];
    $wsnuri  = "$protocol://$host.$domain" . "$dirname";
    $flshuri = "$wsnuri/speedtest.swf";
    if ( $DBG > 1 ) {
        print "done. =\n";
    }

################################################################################
    # Retrieve speedtest.net settings
################################################################################
    ( $sepoch, $usecepoch ) = gettimeofday();
    $msecepoch = ( $usecepoch / 1000 );
    $msepoch = sprintf( "%010d%03.0f", $sepoch, $msecepoch );
    my $validsettings = 0;
    my $settingsxml;
    my @langs = ( "php", "jsp", "aspx", "asp", "xml" );
    foreach my $lang (@langs) {

        if ( $validsettings == 0 ) {
            my $sttngsuri = $wsnuri . "/settings." . $lang . "?x=" . $msepoch;
            if ( $DBG > 1 ) {
                print "= Retrieving $domain configuration...";
                if ( $DBG > 2 ) {
                    print "\n== GET $sttngsuri ==\n";
                }
            } ## end if ( $DBG > 1 )

            $browser->setopt( CURLOPT_URL,       $sttngsuri );
            $browser->setopt( CURLOPT_WRITEDATA, \$settingsxml );
            $retcode = $browser->perform;
            die "\nCannot get $sttngsuri -- $retcode "
              . $browser->strerror($retcode) . " "
              . $browser->errbuf . "\n"
              unless ( $retcode == 0 );
            if ( $browser->getinfo(CURLINFO_CONTENT_TYPE) =~
                m/^(application|text)\/xml/ )
            {
                $validsettings = 1;
            } else {
                undef $settingsxml;
            }
            if ( $DBG > 1 ) {
                if ( $DBG > 2 ) {
                    print "== ";
                    if ($validsettings) {
                        print "GOT SETTINGS";
                    } else {
                        print "NO SETTINGS FOUND";
                    }
                    print " ==\n";
                } ## end if ( $DBG > 2 )
                print "done. =\n";
            } ## end if ( $DBG > 1 )
        } ## end if ( $validsettings ==...)
    } ## end foreach my $lang (@langs)
    if ( $validsettings == 0 ) {
        die "Cannot retrieve $domain settings!\n";
    }

################################################################################
    # Read speedtest.net settings
################################################################################
    if ( $DBG > 1 ) {
        print "= Reading $domain settings...\n";
    }

    my $settingsxp = XML::XPath->new($settingsxml);

    # settings hash
    $settings{customer} = $settingsxp->find('/settings/customer')->string_value;
    $settings{customerregion} =
      $settingsxp->find('/settings/customer/@region')->string_value;
    $settings{ipenabled} =
      $settingsxp->find('/settings/ip/@enabled')->string_value;
    $settings{ipip} = $settingsxp->find('/settings/ip/@ip')->string_value;
    $settings{licensekey} =
      $settingsxp->find('/settings/licensekey')->string_value;
    $settings{reportingapireporting} =
      $settingsxp->find('/settings/reporting/@apireporting')->string_value;
    $settings{reportingapiurl} =
      $settingsxp->find('/settings/reporting/@apiurl')->string_value;
    $settings{reportinghitdefaultapi} =
      $settingsxp->find('/settings/reporting/@hitdefaultapi')->string_value;
    $settings{uploadthreading} =
      $settingsxp->find('/settings/upload-threading')->string_value;

    # settingsclient hash
    my %settingsclient;
    $settingsclient{ip} =
      $settingsxp->find('/settings/client/@ip')->string_value;

    # settingslatency hash
    my %settingslatency;
    $settingslatency{testlength} =
      $settingsxp->find('/settings/latency/@testlength')->string_value;
    $settingslatency{waittime} =
      $settingsxp->find('/settings/latency/@waittime')->string_value;

    # settingsdownload hash
    my %settingsdownload;
    $settingsdownload{testlength} =
      $settingsxp->find('/settings/download/@testlength')->string_value;
    $settingsdownload{initialtest} =
      $settingsxp->find('/settings/download/@initialtest')->string_value;
    $settingsdownload{mintestsize} =
      $settingsxp->find('/settings/download/@mintestsize')->string_value;
    $settingsdownload{threads} =
      $settingsxp->find('/settings/download/@threads')->string_value;
    $settingsdownload{maximagesize} =
      $settingsxp->find('/settings/download/@maximagesize')->string_value;
    $settingsdownload{disabled} =
      $settingsxp->find('/settings/download/@disabled')->string_value;

    # settingsupload hash
    my %settingsupload;
    $settingsupload{testlength} =
      $settingsxp->find('/settings/upload/@testlength')->string_value;
    $settingsupload{ratio} =
      $settingsxp->find('/settings/upload/@ratio')->string_value;
    $settingsupload{initialtest} =
      $settingsxp->find('/settings/upload/@initialtest')->string_value;
    $settingsupload{mintestsize} =
      $settingsxp->find('/settings/upload/@mintestsize')->string_value;
    $settingsupload{threads} =
      $settingsxp->find('/settings/upload/@threads')->string_value;
    $settingsupload{maxchunksize} =
      $settingsxp->find('/settings/upload/@maxchunksize')->string_value;
    $settingsupload{maxchunkcount} =
      $settingsxp->find('/settings/upload/@maxchunkcount')->string_value;
    $settingsupload{disabled} =
      $settingsxp->find('/settings/upload/@disabled')->string_value;

    # settingsservers hash
    my $settingsservernodes = $settingsxp->find('/settings/servers/server');

    # server list hash
    foreach my $settingsserverid ( $settingsservernodes->get_nodelist ) {
        my $settingsid = $settingsserverid->find('@id')->string_value;
        foreach my $settingsserveratt (@settingsserveratts) {
            my $settingsatt = "@" . "$settingsserveratt";
            $settingsservers{$settingsid}{$settingsserveratt} =
              $settingsserverid->find($settingsatt)->string_value;
        }
    } ## end foreach my $settingsserverid...

    my @confighashes = (
        \%settings,         \%settingsclient, \%settingslatency,
        \%settingsdownload, \%settingsupload
    );

    my %hashmap = (
        settings         => \%client,
        settingsclient   => \%client,
        settingslatency  => \%latency,
        settingsdownload => \%download,
        settingsupload   => \%upload
    );

    my $eqcount = 0;
    foreach my $confighash (@confighashes) {
        my ($hashname) = split( /\n/, Dumper( \%$confighash ) );
        $hashname =~ s/^%//g;
        $hashname =~ s/ = \($//g;
        my $orighash = $hashname;
        $orighash =~ s/settings//g;
        my $title = $hashname;
        $title =~ tr/a-z/A-Z/;
        my $eqsgns = ( ( $dbgtablewidth - length($title) - 2 ) / 2 );
        $eqcount = 0;
        my $eqhr;

        while ( $eqcount < $eqsgns ) {
            $eqhr = $eqhr . "=";
            $eqcount++;
        }
        if ( $DBG > 1 ) {
            if ( $DBG > 2 ) {
                my $hdr = sprintf( "%s %s %s", $eqhr, $title, $eqhr );
                printf( "%${dbgtablewidth}.${dbgtablewidth}s\n", $hdr );
            }
        } ## end if ( $DBG > 1 )
        my $titlelength  = length($title);
        my $maxkeylength = 0;
        foreach my $name ( keys %$confighash ) {
            my $keylength = length($name);
            if ( $keylength > $maxkeylength ) {
                $maxkeylength = $keylength;
            }
        } ## end foreach my $name ( keys %$confighash)
        my $vallength = ( $dbgtablewidth - $maxkeylength - 8 );
        foreach my $name ( sort ( keys %$confighash ) ) {
            my $info = $confighash->{$name};
            if ( $info !~ m/^$/ ) {
                if ( $DBG > 1 ) {
                    if ( $DBG > 2 ) {
                        printf(
"== %${maxkeylength}.${maxkeylength}s: %-${vallength}.${vallength}s ==\n",
                            $name, $info
                        );
                    } ## end if ( $DBG > 2 )
                } ## end if ( $DBG > 1 )
                if ( defined $hashmap{$hashname}{$name} ) {
                    if ( $DBG > 1 ) {
                        if ( $DBG > 2 ) {
                            my $subvallength = sprintf(
                                "%0.0d",
                                (
                                    (
                                        $dbgtablewidth -
                                          $titlelength -
                                          $maxkeylength - 13
                                    ) / 2
                                )
                            );
                            my $arrow = "==>";
                            my $totallinewidth =
                              ( $subvallength * 2 + 13 +
                                  $maxkeylength +
                                  $titlelength );
                            if ( $totallinewidth == $dbgtablewidth ) {
                                $arrow = "=>";
                            }
                            printf(
"== %${titlelength}.${titlelength}s %-${maxkeylength}.${maxkeylength}s: %${subvallength}.${subvallength}s %s %-${subvallength}.${subvallength}s ==\n",
                                $hashname, $name, $hashmap{$hashname}{$name},
                                $arrow,    $info
                            );
                        } ## end if ( $DBG > 2 )
                        if ( $hashmap{$hashname}{$name} !~ $info ) {
                            my $shorthashname = $hashname;
                            $shorthashname =~ s/settings//;
                            printf(
                                "= Override %7.7s %-8.8s: %6.6s to %-6.6s =\n",
                                $shorthashname,             $name,
                                $hashmap{$hashname}{$name}, $info
                            );
                        } ## end if ( $hashmap{$hashname...})
                    } ## end if ( $DBG > 1 )
                    if ( $hashmap{$hashname}{$name} !~ $info ) {
                        $hashmap{$hashname}{$name} = $info;
                    }
                } ## end if ( defined $hashmap{...})
            } ## end if ( $info !~ m/^$/ )
        } ## end foreach my $name ( sort ( keys...))
    } ## end foreach my $confighash (@confighashes)
    if ( $DBG > 1 ) {
        if ( $DBG > 2 ) {
            $eqcount = 0;
            while ( $eqcount < $dbgtablewidth ) {
                printf("=");
                $eqcount++;
            }
            print "\n";
        } ## end if ( $DBG > 2 )
        print "done. =\n";
    } ## end if ( $DBG > 1 )
} ## end if ($opturl)

################################################################################
# Retrieve speedtest.net servers list
################################################################################
( $sepoch, $usecepoch ) = gettimeofday();
$msecepoch = ( $usecepoch / 1000 );
$msepoch   = sprintf( "%010d%03.0f", $sepoch, $msecepoch );
$srvruri   = $srvruri . "?x=" . $msepoch;

$browser->setopt( CURLOPT_URL, $srvruri );
my $serversxml;
if ($opturl) {
    if ( $DBG > 1 ) {
        print "= Generating servers configuration...";
        if ( $DBG > 2 ) {
            print "\n=============== SETTINGSSERVERS ===============\n";
        }
    } ## end if ( $DBG > 1 )
    $serversxml = $serversxml . "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    $serversxml = $serversxml . "<settings>\n";
    $serversxml = $serversxml . "<servers>";
    foreach my $settingsname ( keys %settingsservers ) {
        $serversxml = $serversxml . "<server ";
        if ( $DBG > 2 ) {
            printf( "== settingsservers:: %5.5s:", $settingsname );
            printf("                  ==\n");
        }
        my $settingsgenid = 1;
        foreach my $settingsserveratt (@settingsserveratts) {
            if (   $settingsserveratt eq "url"
                && $settingsservers{$settingsname}{$settingsserveratt} eq "" )
            {
                $settingsservers{$settingsname}{$settingsserveratt} =
                  $wsnuri . "/speedtest/upload.php";
            } ## end if ( $settingsserveratt...)
            if (   $settingsserveratt eq "lat"
                && $settingsservers{$settingsname}{$settingsserveratt} eq "" )
            {
                $settingsservers{$settingsname}{$settingsserveratt} =
                  $client{lat};
            } ## end if ( $settingsserveratt...)
            if (   $settingsserveratt eq "lon"
                && $settingsservers{$settingsname}{$settingsserveratt} eq "" )
            {
                $settingsservers{$settingsname}{$settingsserveratt} =
                  $client{lon};
            } ## end if ( $settingsserveratt...)
            if (   $settingsserveratt eq "name"
                && $settingsservers{$settingsname}{$settingsserveratt} eq "" )
            {
                $settingsservers{$settingsname}{$settingsserveratt} =
                  $settings{customerregion};
            } ## end if ( $settingsserveratt...)
            if (   $settingsserveratt eq "country"
                && $settingsservers{$settingsname}{$settingsserveratt} eq "" )
            {
                $settingsservers{$settingsname}{$settingsserveratt} = "";
            }
            if (   $settingsserveratt eq "cc"
                && $settingsservers{$settingsname}{$settingsserveratt} eq "" )
            {
                $settingsservers{$settingsname}{$settingsserveratt} = "";
            }
            if (   $settingsserveratt eq "sponsor"
                && $settingsservers{$settingsname}{$settingsserveratt} eq "" )
            {
                $settingsservers{$settingsname}{$settingsserveratt} =
                  $settings{customer};
            } ## end if ( $settingsserveratt...)
            if (   $settingsserveratt eq "id"
                && $settingsservers{$settingsname}{$settingsserveratt} eq "" )
            {
                $settingsservers{$settingsname}{$settingsserveratt} =
                  $settingsgenid;
                $settingsgenid++;
            } ## end if ( $settingsserveratt...)
            if (   $settingsserveratt eq "id"
                && $settingsservers{$settingsname}{$settingsserveratt} <=
                $settingsgenid++ )
            {
                $settingsgenid =
                  ( $settingsservers{$settingsname}{$settingsserveratt} + 1 );
            } ## end if ( $settingsserveratt...)

            $serversxml = $serversxml
              . "$settingsserveratt=\"$settingsservers{$settingsname}{$settingsserveratt}\" ";
            if ( $DBG > 2 ) {
                printf( "== \t%11.11s:", $settingsserveratt );
                printf(
                    " %-23.23s ==\n",
                    $settingsservers{$settingsname}{$settingsserveratt}
                );
            } ## end if ( $DBG > 2 )
        } ## end foreach my $settingsserveratt...
        $serversxml = $serversxml . " />\n";
    } ## end foreach my $settingsname ( ...)

    $serversxml = $serversxml . "</servers>\n";
    $serversxml = $serversxml . "</settings>\n";
    if ( $DBG > 2 ) {
        print "===============================================\n";
    }

} else {
    if ( $DBG > 1 ) {
        print "= Retrieving $domain servers list...";
        if ( $DBG > 2 ) {
            print "\n== GET $srvruri ==\n";
        }
    } ## end if ( $DBG > 1 )
    $browser->setopt( CURLOPT_WRITEDATA, \$serversxml );
    $retcode = $browser->perform;
    die "\nCannot get $srvruri -- $retcode "
      . $browser->strerror($retcode) . " "
      . $browser->errbuf . "\n"
      unless ( $retcode == 0 );
    die "\nDid not receive XML, got -- ",
      $browser->getinfo(CURLINFO_CONTENT_TYPE)
      unless $browser->getinfo(CURLINFO_CONTENT_TYPE) =~ m/^(application|text)\/xml/;
} ## end else [ if ($opturl) ]
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
} ## end if ( $DBG > 1 )

my $serversxp   = XML::XPath->new($serversxml);
my $servernodes = $serversxp->find('/settings/servers/server');

# server attributes
my @serveratts =
  ( 'url', 'lat', 'lon', 'name', 'country', 'cc', 'sponsor', 'id' );

# server list hash
my %servers;
foreach my $serverid ( $servernodes->get_nodelist ) {
    my $id = $serverid->find('@id')->string_value;
    foreach my $serveratt (@serveratts) {
        my $att = "@" . "$serveratt";
        $servers{$id}{$serveratt} = $serverid->find($att)->string_value;
    }
} ## end foreach my $serverid ( $servernodes...)

# ping latency hash
my %latencyresults;

if ( $DBG > 1 ) {
    if ( $DBG > 2 ) {
        print "=================== SERVERS ===================\n";
        foreach my $name ( keys %servers ) {
            printf( "== servers:: %5.5s:", $name );
            printf("                          ==\n");
            foreach my $serveratt (@serveratts) {
                printf( "== \t%10.10s:",  $serveratt );
                printf( " %-24.24s ==\n", $servers{$name}{$serveratt} );
            }
        } ## end foreach my $name ( keys %servers)
        print "===============================================\n";
    } ## end if ( $DBG > 2 )
    print "done. =\n";
} ## end if ( $DBG > 1 )

################################################################################
# Determine the distance between the client and all test servers
################################################################################
if ( $DBG > 1 ) {
    print "= Determining the distance between client and $domain servers...";
    if ( $DBG > 2 ) {
        print "\n================== DISTANCE ===================\n";
    }
} ## end if ( $DBG > 1 )

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
} ## end foreach my $serverid ( keys...)
if ( $DBG > 1 ) {
    if ( $DBG > 2 ) {
        print "===============================================\n";
        print "== Total number of test servers: $totalservers ==\n";
    }
    print "done. =\n";
} ## end if ( $DBG > 1 )

################################################################################
# Set number of test servers
################################################################################
if ($opturl) {
    $numservers = $totalservers;
}

# Error if input is less than one or greater than the total number of servers.
if ($optservers) {
    if ( $optservers > 0 && $optservers <= $totalservers ) {
        $numservers = $optservers;
    } else {
        print STDERR "Value \"$optservers\" invalid for number of servers ";
        print STDERR "option.\nPlease select an integer between 1 and ";
        print STDERR "$totalservers.\n";
        pod2usage(1);
    } ## end else [ if ( $optservers > 0 &&...)]
} ## end if ($optservers)
if ( $DBG > 1 ) {
    if ( $DBG > 2 ) {
        print "== Number of Test Servers Set to $numservers ==\n";
    }
    print "= Determining the $numservers closest $domain servers =\n";
    print "= based on geographic distance...";
    if ( $DBG > 2 ) {
        print "\n================== DISTANCE ===================\n";
    }
} ## end if ( $DBG > 1 )

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
    my $passfilter = 1;
    my $failfilter = 0;
    if ($optid) {
        my $incfilter = 0;
        if ( $servers{$name}{id} == $optid ) {
            $incfilter++;
            if ( $DBG > 2 ) {
                printf( "== INCLUDE: %-5.5s\n", $name );
            }
        } ## end if ( $servers{$name}{id...})
        if   ( $incfilter > 0 ) { $passfilter++; }
        else                    { $failfilter++; }
    } ## end if ($optid)
    if (@exccc) {
        foreach my $cc (@exccc) {
            my $country = code2country($cc);
            if ( !$country ) {
                print STDERR
                  "\nUnable to find country code \"$cc\". Aborting!\n";
                exit 1;
            }
            if ( $servers{$name}{cc} =~ m/$cc/i ) {
                if ( $country !~ m/$servers{$name}{country}/i ) {
                    print STDERR
"\nCountry code \"$cc\" does not match country \"$servers{$name}{country}\". Excluding!\n";
                    $failfilter++;
                }
                $failfilter++;
                if ( $DBG > 2 ) {
                    printf( "== EXCLUDE: %-5.5s\n", $name );
                }
            } else {
                $passfilter++;
            }
        } ## end foreach my $cc (@exccc)
    } ## end if (@exccc)
    if (@inccc) {
        my $incfilter = 0;
        foreach my $cc (@inccc) {
            my $country = code2country($cc);
            if ( !$country ) {
                print STDERR
                  "\nUnable to find country code \"$cc\". Aborting!\n";
                exit 1;
            }
            if ( $servers{$name}{cc} =~ m/$cc/i ) {
                if ( $country !~ m/$servers{$name}{country}/i ) {
                    print STDERR
"\nCountry code \"$cc\" does not match country \"$servers{$name}{country}\". Excluding!\n";
                    $failfilter++;
                }
                $incfilter++;
                if ( $DBG > 2 ) {
                    printf( "== INCLUDE: %-5.5s\n", $name );
                }
            } ## end if ( $servers{$name}{cc...})
        } ## end foreach my $cc (@inccc)
        if   ( $incfilter > 0 ) { $passfilter++; }
        else                    { $failfilter++; }
    } ## end if (@inccc)
    if (@exccntry) {
        foreach my $country (@exccntry) {
            my $cc = country2code($country);
            if ( !$cc ) {
                print STDERR
                  "\nUnable to find country code for \"$country\". Aborting!\n";
                exit 1;
            }
            if ( $servers{$name}{country} =~ m/$country/i ) {
                if ( $cc !~ m/$servers{$name}{cc}/i ) {
                    print STDERR
"\nCountry \"$country\" does not match country code \"$servers{$name}{cc}\". Excluding!\n";
                    $failfilter++;
                }
                $failfilter++;
                if ( $DBG > 2 ) {
                    printf( "== EXCLUDE: %-5.5s\n", $name );
                }
            } else {
                $passfilter++;
            }
        } ## end foreach my $country (@exccntry)
    } ## end if (@exccntry)
    if (@inccntry) {
        my $incfilter = 0;
        foreach my $country (@inccntry) {
            my $cc = country2code($country);
            if ( !$cc ) {
                print STDERR
                  "\nUnable to find country code for \"$country\". Aborting!\n";
                exit 1;
            }
            if ( $servers{$name}{country} =~ m/$country/i ) {
                if ( $cc !~ m/$servers{$name}{cc}/i ) {
                    print STDERR
"\nCountry \"$country\" does not match country code \"$servers{$name}{cc}\". Excluding!\n";
                    $failfilter++;
                }
                $incfilter++;
                if ( $DBG > 2 ) {
                    printf( "== INCLUDE: %-5.5s\n", $name );
                }
            } ## end if ( $servers{$name}{country...})
        } ## end foreach my $country (@inccntry)
        if   ( $incfilter > 0 ) { $passfilter++; }
        else                    { $failfilter++; }
    } ## end if (@inccntry)
    if (@excnm) {
        foreach my $nm (@excnm) {
            if ( $servers{$name}{name} =~ m/$nm/i ) {
                $failfilter++;
                if ( $DBG > 2 ) {
                    printf( "== EXCLUDE: %-5.5s\n", $name );
                }
            } else {
                $passfilter++;
            }
        } ## end foreach my $nm (@excnm)
    } ## end if (@excnm)
    if (@incnm) {
        my $incfilter = 0;
        foreach my $nm (@incnm) {
            if ( $servers{$name}{name} =~ m/$nm/i ) {
                $incfilter++;
                if ( $DBG > 2 ) {
                    printf( "== INCLUDE: %-5.5s\n", $name );
                }
            } ## end if ( $servers{$name}{name...})
        } ## end foreach my $nm (@incnm)
        if   ( $incfilter > 0 ) { $passfilter++; }
        else                    { $failfilter++; }
    } ## end if (@incnm)
    if (@excspnsr) {
        foreach my $spnsr (@excspnsr) {
            if ( $servers{$name}{sponsor} =~ m/$spnsr/i ) {
                $failfilter++;
                if ( $DBG > 2 ) {
                    printf( "== EXCLUDE: %-5.5s\n", $name );
                }
            } else {
                $passfilter++;
            }
        } ## end foreach my $spnsr (@excspnsr)
    } ## end if (@excspnsr)
    if (@incspnsr) {
        my $incfilter = 0;
        foreach my $spnsr (@incspnsr) {
            if ( $servers{$name}{sponsor} =~ m/$spnsr/i ) {
                $incfilter++;
                if ( $DBG > 2 ) {
                    printf( "== INCLUDE: %-5.5s\n", $name );
                }
            } ## end if ( $servers{$name}{sponsor...})
        } ## end foreach my $spnsr (@incspnsr)
        if   ( $incfilter > 0 ) { $passfilter++; }
        else                    { $failfilter++; }
    } ## end if (@incspnsr)
    if (@excdskmgt) {
        foreach my $dskmgt (@excdskmgt) {
            if ( $servers{$name}{distance} > $dskmgt ) {
                $failfilter++;
                if ( $DBG > 2 ) {
                    printf( "== EXCLUDE: %-5.5s\n", $name );
                }
            } else {
                $passfilter++;
            }
        } ## end foreach my $dskmgt (@excdskmgt)
    } ## end if (@excdskmgt)
    if (@incdskmgt) {
        my $incfilter = 0;
        foreach my $dskmgt (@incdskmgt) {
            if ( $servers{$name}{distance} > $dskmgt ) {
                $incfilter++;
                if ( $DBG > 2 ) {
                    printf( "== INCLUDE: %-5.5s\n", $name );
                }
            } ## end if ( $servers{$name}{distance...})
        } ## end foreach my $dskmgt (@incdskmgt)
        if   ( $incfilter > 0 ) { $passfilter++; }
        else                    { $failfilter++; }
    } ## end if (@incdskmgt)
    if (@excdskmlt) {
        foreach my $dskmlt (@excdskmlt) {
            if ( $servers{$name}{distance} < $dskmlt ) {
                $failfilter++;
                if ( $DBG > 2 ) {
                    printf( "== EXCLUDE: %-5.5s\n", $name );
                }
            } else {
                $passfilter++;
            }
        } ## end foreach my $dskmlt (@excdskmlt)
    } ## end if (@excdskmlt)
    if (@incdskmlt) {
        my $incfilter = 0;
        foreach my $dskmlt (@incdskmlt) {
            if ( $servers{$name}{distance} < $dskmlt ) {
                $incfilter++;
                if ( $DBG > 2 ) {
                    printf( "== INCLUDE: %-5.5s\n", $name );
                }
            } ## end if ( $servers{$name}{distance...})
        } ## end foreach my $dskmlt (@incdskmlt)
        if   ( $incfilter > 0 ) { $passfilter++; }
        else                    { $failfilter++; }
    } ## end if (@incdskmlt)
    if (@excdsmigt) {
        foreach my $dsmigt (@excdsmigt) {
            my $dskmgt = ( $dsmigt * 1.60934 );
            if ( $servers{$name}{distance} > $dskmgt ) {
                $failfilter++;
                if ( $DBG > 2 ) {
                    printf( "== EXCLUDE: %-5.5s\n", $name );
                }
            } else {
                $passfilter++;
            }
        } ## end foreach my $dsmigt (@excdsmigt)
    } ## end if (@excdsmigt)
    if (@incdsmigt) {
        my $incfilter = 0;
        foreach my $dsmigt (@incdsmigt) {
            my $dskmgt = ( $dsmigt * 1.60934 );
            if ( $servers{$name}{distance} > $dskmgt ) {
                $incfilter++;
                if ( $DBG > 2 ) {
                    printf( "== INCLUDE: %-5.5s\n", $name );
                }
            } ## end if ( $servers{$name}{distance...})
        } ## end foreach my $dsmigt (@incdsmigt)
        if   ( $incfilter > 0 ) { $passfilter++; }
        else                    { $failfilter++; }
    } ## end if (@incdsmigt)
    if (@excdsmilt) {
        foreach my $dsmilt (@excdsmilt) {
            my $dskmlt = ( $dsmilt * 1.60934 );
            if ( $servers{$name}{distance} < $dskmlt ) {
                $failfilter++;
                if ( $DBG > 2 ) {
                    printf( "== EXCLUDE: %-5.5s\n", $name );
                }
            } else {
                $passfilter++;
            }
        } ## end foreach my $dsmilt (@excdsmilt)
    } ## end if (@excdsmilt)
    if (@incdsmilt) {
        my $incfilter = 0;
        foreach my $dsmilt (@incdsmilt) {
            my $dskmlt = ( $dsmilt * 1.60934 );
            if ( $servers{$name}{distance} < $dskmlt ) {
                $incfilter++;
                if ( $DBG > 2 ) {
                    printf( "== INCLUDE: %-5.5s\n", $name );
                }
            } ## end if ( $servers{$name}{distance...})
        } ## end foreach my $dsmilt (@incdsmilt)
        if   ( $incfilter > 0 ) { $passfilter++; }
        else                    { $failfilter++; }
    } ## end if (@incdsmilt)
    my $info = $servers{$name}{distance};
    if ( @closestservers < $numservers && $passfilter > 0 && $failfilter < 1 ) {
        push( @closestservers, $name );
        if ( $DBG > 2 ) {
            my $df = sprintf( "%05.11f", $info );
            printf( "== serverdistance:: %5.5s: %17s ==\n", $name, $df );
        }
    } ## end if ( @closestservers <...)
} ## end foreach my $name ( sort hashValueAscendingDist...)
if ( $DBG > 1 ) {
    if ( $DBG > 2 ) {
        print "===============================================\n";
    }
    print "done. =\n";
} ## end if ( $DBG > 1 )

################################################################################
# Get more geographic data on closest servers
################################################################################
foreach my $server (@closestservers) {
    my $neighbourhoodurl =
"$gefnuri?lat=$servers{$server}{lat}&lng=$servers{$server}{lon}&username=$gnusername";
    if ( $DBG > 1 ) {
        print
"= Retrieving geographic neighbourhood data for $servers{$server}{name}...";
        if ( $DBG > 2 ) {
            print "\n== GET $neighbourhoodurl ==\n";
        }
    } ## end if ( $DBG > 1 )
    $browser->setopt( CURLOPT_URL, $neighbourhoodurl );
    my $neighbourhoodxml;
    $browser->setopt( CURLOPT_WRITEDATA, \$neighbourhoodxml );
    $retcode = $browser->perform;
    die "\nCannot get $neighbourhoodurl -- $retcode "
      . $browser->strerror($retcode) . " "
      . $browser->errbuf . "\n"
      unless ( $retcode == 0 );
    if ( $browser->getinfo(CURLINFO_CONTENT_TYPE) !~
        m/^(application|text)\/xml/ )
    {
        die "\nDid not receive XML, got -- ",
          $browser->getinfo(CURLINFO_CONTENT_TYPE);
    } ## end if ( $browser->getinfo...)
    if ( $DBG > 1 ) {
        print "done. =\n";
    }
    my $neighbourhoodxp = XML::XPath->new($neighbourhoodxml);
    my $neighbourhood   = "";
    if ( $neighbourhoodxp->exists('/geonames/address') ) {
        if ( $DBG > 2 ) {
            print
              "== Address GeoName Available for $servers{$server}{name} ==\n";
        }
        foreach my $geoatt (@geoatts) {
            my $att = "/geonames/address/" . $geoatt;
            $servers{$server}{$geoatt} =
              $neighbourhoodxp->find($att)->string_value;
        }
        if ( $servers{$server}{countryCode} ) {
            my $country = code2country( $servers{$server}{countryCode} );
            if ( !$country ) {
                print STDERR
"\nUnable to find country code \"$servers{$server}{countryCode}\". Aborting!\n";
                exit 1;
            }
            if ( $servers{$server}{countryCode} !~ m/^$servers{$server}{cc}$/ )
            {
                print STDERR
"\nGeographic country code \"$servers{$server}{countryCode}\" does not match server metadata country code \"$servers{$server}{cc}\"\n";
            }
            if ( $country !~ m/^$servers{$server}{country}$/ ) {
                print STDERR
"\nGeographic country \"$country\" does not match server metadata country \"$servers{$server}{country}\"\n";
            }
            $neighbourhood =
              $neighbourhood . " => $servers{$server}{countryCode}";
        } ## end if ( $servers{$server}...)
        if ( $servers{$server}{adminCode1} || $servers{$server}{adminName1} ) {
            $neighbourhood = $neighbourhood . " =>";
            if ( $servers{$server}{adminCode1} ) {
                $neighbourhood =
                  $neighbourhood . " $servers{$server}{adminCode1}";
            }
            if ( $servers{$server}{adminName1} ) {
                $neighbourhood =
                  $neighbourhood . " ($servers{$server}{adminName1})";
            }
        } ## end if ( $servers{$server}...)
        if ( $servers{$server}{adminCode2} || $servers{$server}{adminName2} ) {
            $neighbourhood = $neighbourhood . " =>";
            if ( $servers{$server}{adminCode2} ) {
                $neighbourhood =
                  $neighbourhood . " $servers{$server}{adminCode2}";
            }
            if ( $servers{$server}{adminName2} ) {
                $neighbourhood =
                  $neighbourhood . " ($servers{$server}{adminName2})";
            }
        } ## end if ( $servers{$server}...)
        if ( $servers{$server}{placename} ) {
            $neighbourhood =
              $neighbourhood . " => $servers{$server}{placename}";
        }
    } elsif ( $neighbourhoodxp->exists('/geonames/geoname') ) {
        if ( $DBG > 2 ) {
            print
              "== GeoName GeoName Available for $servers{$server}{name} ==\n";
        }
        my $geonamenodes = $neighbourhoodxp->find('/geonames/geoname');
        $servers{$server}{countryName} = "";
        $servers{$server}{adminName1}  = "";
        $servers{$server}{adminName2}  = "";
        $servers{$server}{placename}   = "";
        foreach my $geoname ( $geonamenodes->get_nodelist ) {
            my $gvalue = $geoname->find('name')->string_value;
            my $gkey   = $geoname->find('fcode')->string_value;
            $servers{$server}{countryCode} =
              $geoname->find('countryCode')->string_value;
            $servers{$server}{countryName} =
              $geoname->find('countryName')->string_value;
            if ($gvalue) {
                $neighbourhood = $neighbourhood . " => $gvalue";
            }
            if ( $gkey =~ m/^PCLI/ ) {
                if ( $servers{$server}{countryCode} !~
                    m/^$servers{$server}{cc}$/ )
                {
                    print STDERR
"\nGeographic country code \"$servers{$server}{countryCode}\" does not match server metadata country code \"$servers{$server}{cc}\"\n";
                } ## end if ( $servers{$server}...)
                if ( $servers{$server}{countryName} !~
                    m/^$servers{$server}{country}$/ )
                {
                    print STDERR
"\nGeographic country \"$servers{$server}{countryName}\" does not match server metadata country \"$servers{$server}{country}\"\n";
                } ## end if ( $servers{$server}...)
                $servers{$server}{countryName} = $gvalue;
            } ## end if ( $gkey =~ m/^PCLI/)
            $servers{$server}{adminCode1} = "";
            if ( $gkey =~ m/^ADM1/ ) {
                $servers{$server}{adminName1} = $gvalue;
            }
            $servers{$server}{adminCode2} = "";
            if ( $gkey =~ m/^ADM2/ ) {
                $servers{$server}{adminName2} = $gvalue;
            }
            if ( $gkey =~ m/^PP/ ) {
                $servers{$server}{placename} = $gvalue;
            }
        } ## end foreach my $geoname ( $geonamenodes...)
    } elsif ( $neighbourhoodxp->exists('/geonames/ocean') ) {
        if ( $DBG > 2 ) {
            print "== Ocean GeoName Available for $servers{$server}{name} ==\n";
        }
        foreach my $geoatt (@geoatts) {
            $servers{$server}{$geoatt} = "";
        }
        my $ocean =
          $neighbourhoodxp->find('/geonames/ocean/name')->string_value;
        if ($ocean) {
            $servers{$server}{placename} = $ocean;
            $neighbourhood = $neighbourhood . " => $ocean";
        }
    } else {
        warn "Unknown geography description:\n$neighbourhoodxml\n";
    }
    $servers{$server}{neighbourhood} = $neighbourhood;
    if ( $DBG > 1 ) {
        print "= $neighbourhood =\n";
    }
} ## end foreach my $server (@closestservers)

################################################################################
# Print a list of candidate servers
################################################################################
if ($optlist) {
    my @serverattslist = (
        "id",         "name",       "country",    "cc",
        "sponsor",    "distance",   "placename",  "adminCode2",
        "adminName2", "adminCode1", "adminName1", "countryCode"
    );
    my %maxwidth;
    my $rows = 0;
    foreach my $serveratt (@serverattslist) {
        $maxwidth{$serveratt} = length($serveratt);
        foreach my $server (@closestservers) {
            if ( $serveratt eq "distance" ) {
                $maxwidth{distancekm} = 3;
                $maxwidth{distancemi} = 3;
                my $prettydistancekm =
                  sprintf( "%.${DBG}f km", $servers{$server}{distance} );
                my $prettydistancemi = sprintf(
                    "%.${DBG}f mi",
                    ( $servers{$server}{distance} * 0.621371 )
                );
                my $prettydistance =
                  $prettydistancekm . " | " . $prettydistancemi;
                if ( length($prettydistancekm) > $maxwidth{distancekm} ) {
                    $maxwidth{distancekm} = length($prettydistancekm);
                }
                if ( length($prettydistancemi) > $maxwidth{distancemi} ) {
                    $maxwidth{distancemi} = length($prettydistancemi);
                }
                if ( length($prettydistance) > $maxwidth{distance} ) {
                    $maxwidth{distance} = length($prettydistance);
                }
            } elsif (
                length( $servers{$server}{$serveratt} ) >
                $maxwidth{$serveratt} )
            {
                $maxwidth{$serveratt} = length( $servers{$server}{$serveratt} );
            } ## end elsif ( length( $servers{...}))
        } ## end foreach my $server (@closestservers)
    } ## end foreach my $serveratt (@serverattslist)
    my $hr = "+";
    foreach my $serveratt (@serverattslist) {
        my $hyphen = 0;
        while ( $hyphen <= $maxwidth{$serveratt} ) {
            $hr = "$hr" . "-";
            $hyphen++;
        }
        $hr = "$hr" . "-+";
    } ## end foreach my $serveratt (@serverattslist)
    $hr = "$hr" . "\n";

    printf("$hr");
    printf("|");
    foreach my $serveratt (@serverattslist) {
        my $colwidth = $maxwidth{$serveratt};
        my $thwidth  = length($serveratt);
        my $thpad    = ( ( $colwidth - $thwidth ) / 2 );
        my $thnbsp   = "";
        while ( length($thnbsp) < $thpad ) {
            $thnbsp = $thnbsp . " ";
        }
        my $serverattth = $thnbsp . $serveratt;
        printf( " %-${colwidth}.${colwidth}s |", $serverattth );
    } ## end foreach my $serveratt (@serverattslist)
    printf("\n");
    printf("$hr");

    foreach my $server (@closestservers) {
        printf("|");
        foreach my $serveratt (@serverattslist) {
            my $colwidth = $maxwidth{$serveratt};
            my $lj       = "";
            if ( $servers{$server}{$serveratt} =~ m/^\D/ ) {
                $lj = "-";
            }
            if ( $serveratt eq "distance" ) {
                my $prettydistancekm =
                  sprintf( "%.${DBG}f km", $servers{$server}{distance} );
                my $prettydistancemi = sprintf(
                    "%.${DBG}f mi",
                    ( $servers{$server}{distance} * 0.621371 )
                );
                my $colwidthkm = $maxwidth{distancekm};
                my $colwidthmi = $maxwidth{distancemi};
                printf(
" %${lj}${colwidthkm}.${colwidthkm}s | %${lj}${colwidthmi}.${colwidthmi}s |",
                    $prettydistancekm, $prettydistancemi
                );
            } else {
                printf(
                    " %${lj}${colwidth}.${colwidth}s |",
                    $servers{$server}{$serveratt}
                );
            } ## end else [ if ( $serveratt eq "distance")]
        } ## end foreach my $serveratt (@serverattslist)
        printf("\n");
        $rows++;
    } ## end foreach my $server (@closestservers)
    printf("$hr");
    my $plural = "s";
    if ( $rows == 1 ) {
        $plural = "";
    }
    printf( "%d row$plural in set\n\n", $rows );

    exit 0;
} ## end if ($optlist)

################################################################################
# Set number of ping tests against candidate servers
################################################################################
# Error if input is less than one.
if ($optpings) {
    if ( $optpings > 0 ) {
        $numpingtest = $optpings;
    } else {
        print STDERR "Value \"$optpings\" invalid for number of ping tests ";
        print STDERR "option.\nPlease select an integer greater than zero.\n";
        pod2usage(1);
    }
} ## end if ($optpings)
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
# Select best server based on command line or ping from pool of closest servers
################################################################################
# Set invalid best server for catching errors
my $bestserver = -1;
if ($optid) {
    if ( $DBG > 1 ) {
        print "= Selecting best server based on command-line option...";
    }
    foreach my $serverid ( keys %servers ) {
        my $id = $servers{$serverid}{id};
        if ( $id eq $optid ) {
            $bestserver = $id;
        }
    } ## end foreach my $serverid ( keys...)
    if ( $DBG > 1 ) {
        print "\n";
    }
} else {
    if ( $DBG > 1 ) {
        print "= Selecting best server based on ping...\n";
        if ( $DBG > 2 ) {
            print "\n";
        }
    } ## end if ( $DBG > 1 )
    foreach my $server (@closestservers) {
        if ( $DBG > 1 ) {
            print "= Checking $servers{$server}{name} Hosted by ";
            print "$servers{$server}{sponsor}";
            if ( $DBG > 2 ) {
                printf("\n================ SERVER:");
                printf( " %5.5s ================\n", $server );
                foreach my $serveratt (@serveratts) {
                    printf( "== %8.8s:",      $serveratt );
                    printf( " %-31.31s ==\n", $servers{$server}{$serveratt} );
                }
                print "===============================================\n";
            } ## end if ( $DBG > 2 )
        } ## end if ( $DBG > 1 )
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
            } ## end if ( $DBG > 1 )

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
              unless $browser->getinfo(CURLINFO_CONTENT_TYPE) =~
              m/^text\/plain/;
            my $selapsed        = $s1 - $s0;
            my $usecelapsed     = $usec1 - $usec0;
            my $stomselapsed    = ( $selapsed * 1000 );
            my $usectomselapsed = ( $usecelapsed / 1000 );
            my $mselapsed       = $stomselapsed + $usectomselapsed;

            if (   $latencytxt =~ m/^test=test/
                && $browser->getinfo(CURLINFO_CONTENT_TYPE) =~ m/^text\/plain/
                && $retcode == 0 )
            {
                $latencyresults{$server}{totalelapsed} =
                  $latencyresults{$server}{totalelapsed} + $mselapsed;
                $latencyresults{$server}{totalpings}++;
            } ## end if ( $latencytxt =~ m/^test=test/...)
            if ( $DBG > 2 ) {
                print "$mselapsed milliseconds. done. ==\n";
            }

            usleep( $latency{waittime} * 1000 );
            $pingcount++;
        } ## end while ( $pingcount < $numpingtest)
        if ( $DBG > 2 ) {
            print "== $latencyresults{$server}{totalpings} runs took ";
            print "$latencyresults{$server}{totalelapsed} milliseconds. ==\n";
        }
        $latencyresults{$server}{avgelapsed} =
          $latencyresults{$server}{totalelapsed} /
          $latencyresults{$server}{totalpings};

        if ( $DBG > 1 ) {
            printf("done: =\n= \t");
            printf( "%.${DBG}f ", $latencyresults{$server}{avgelapsed} );
            printf("millisecond average. =\n");
        }
    } ## end foreach my $server (@closestservers)
    if ( $DBG > 2 ) {
        print "================ PING AVERAGE =================\n";
    }
    foreach my $name ( sort hashValueDescendingPing ( keys(%latencyresults) ) )
    {
        my $info = $latencyresults{$name}{avgelapsed};
        if ( $DBG > 2 ) {
            printf( "== pingaverage:: %5.5s: %-20.20s ==\n", $name, $info );
        }
        $bestserver = $name;
    } ## end foreach my $name ( sort hashValueDescendingPing...)
} ## end else [ if ($optid) ]
if ( $bestserver == -1 ) {
    if ($optid) {
        print STDERR "Value \"$optid\" is an invalid server id ";
        print STDERR "option.\nPlease select an id from the output of the ";
        print STDERR "list option.\n";
    } else {
        print STDERR "Unable to find a useable server. Aborting!\n";
    }
    exit 1;
} ## end if ( $bestserver == -1)
if ( $DBG > 0 ) {
    if ( $DBG > 2 ) {
        print "===============================================\n";
    }
    my $distancekm = sprintf( "%.${DBG}f", $servers{$bestserver}{distance} );
    my $distancemi =
      sprintf( "%.${DBG}f", ( $servers{$bestserver}{distance} * 0.621371 ) );
    print "Server Selected: $servers{$bestserver}{name} Hosted by ";
    print
      "$servers{$bestserver}{sponsor}$servers{$bestserver}{neighbourhood}\n";
    print "Distance Between Client and Server: $distancekm km ";
    print "($distancemi mi)\n";
    if ( $DBG > 1 ) {
        print "done. =\n";
    }
} ## end if ( $DBG > 0 )

################################################################################
# Set number of latency tests against selected server
################################################################################
# Set samples for calculating HTTP latency to remote settings/configuration.
$numpingcount = $latency{testlength};

# Error if input is less than zero.
if ($optcount) {
    if ( $optcount >= 0 ) {
        $numpingcount = $optcount;
    } else {
        print STDERR "Value \"$optcount\" invalid for number of samples to ";
        print STDERR "use for calculating HTTP latency (default = ";
        print STDERR "$numpingcount), 0 will disable the latency test.\n";
        pod2usage(1);
    } ## end else [ if ( $optcount >= 0 ) ]
} ## end if ($optcount)
if ( $DBG > 2 ) {
    print "== Count of Latency Tests Set to $numpingcount ==\n";
}

################################################################################
# PING/latency test against selected server
################################################################################
if ( $DBG > 1 ) {
    print "= Checking ping against $servers{$bestserver}{name} Hosted by ";
    print
      "$servers{$bestserver}{sponsor}$servers{$bestserver}{neighbourhood}\n";
    if ( $DBG > 2 ) {
        printf("\n================ SERVER:");
        printf( " %5.5s ================\n", $bestserver );
        foreach my $serveratt (@serveratts) {
            printf( "== %8.8s:",      $serveratt );
            printf( " %-31.31s ==\n", $servers{$bestserver}{$serveratt} );
        }
        print "===============================================\n";
    } ## end if ( $DBG > 2 )
} ## end if ( $DBG > 1 )
my ( $scheme, $auth, $path, $query, $frag ) =
  uri_split( $servers{$bestserver}{url} );
my $dirname   = dirname($path);
my $url       = uri_join( $scheme, $auth, $dirname );
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
        && $retcode == 0 )
    {
        $latencyresults{$bestserver}{totalelapsed} =
          $latencyresults{$bestserver}{totalelapsed} + $mselapsed;
        $latencyresults{$bestserver}{totalpings}++;
    } ## end if ( $latencytxt =~ m/^test=test/...)
    if ( $DBG > 1 ) {
        if ( $DBG > 2 ) {
            print "$mselapsed milliseconds. done. ==\n";
        }
        $latencyresults{$bestserver}{avgelapsed} =
          $latencyresults{$bestserver}{totalelapsed} /
          $latencyresults{$bestserver}{totalpings};
        printf( "Ping: %.${DBG}f", $latencyresults{$bestserver}{avgelapsed} );
        printf(" ms\r");
    } ## end if ( $DBG > 1 )

    usleep( $latency{waittime} * 1000 );
    $pingcount++;
} ## end while ( $pingcount < $numpingcount)
$latencyresults{$bestserver}{avgelapsed} =
  $latencyresults{$bestserver}{totalelapsed} /
  $latencyresults{$bestserver}{totalpings};
printf( "Ping: %.${DBG}f ms\n", $latencyresults{$bestserver}{avgelapsed} );

if ( $DBG > 1 ) {
    if ( $DBG > 2 ) {
        print "== $latencyresults{$bestserver}{totalpings} runs took ";
        printf( "%.${DBG}f", $latencyresults{$bestserver}{totalelapsed} );
        printf(" milliseconds. ==\n");
    }
    printf( "done: %.${DBG}f ", $latencyresults{$bestserver}{avgelapsed} );
    printf("millisecond average. =\n");
} ## end if ( $DBG > 1 )

################################################################################
# DOWNLOAD test against selected server
################################################################################
if ( $DBG > 1 ) {
    print "= Checking download against $servers{$bestserver}{name} Hosted by ";
    print
      "$servers{$bestserver}{sponsor}$servers{$bestserver}{neighbourhood}\n";
}

my @hwpixels = (
    "350",  "500",  "750",  "1000", "1500", "2000",
    "2500", "3000", "3500", "4000"
);
my $totaldltime   = 0;
my $totaldlsize   = 0;
my $avgdlspeed    = 0;
my $mbpsl         = 0;
my $mbpsh         = 0;
my $mindltestsize = $download{mintestsize};
$mindltestsize =~ s/K$/000/g;
$mindltestsize =~ s/M$/000000/g;

foreach my $hwpixel (@hwpixels) {
    $mbpsl = $mbpsh;
    my $bytes    = ( $hwpixel**2 * 2 );
    my $bits     = ( $bytes * 8 );
    my $kilobits = ( $bits / 1000 );
    my $megabits = ( $kilobits / 1000 );
    $mbpsh = ( $megabits / 2 );
    if (   $mbpsl <= $avgdlspeed
        && $avgdlspeed < $mbpsh
        && $mindltestsize < $bits )
    {
        my $dlurl  = $url;
        my $ycount = 3;
        my $y      = 1;
        while ( $y < $ycount ) {
            print "∨"; ## ∧ (logical and) and ∨ (logical or) characters
            ( $sepoch, $usecepoch ) = gettimeofday();
            $msecepoch = ( $usecepoch / 1000 );
            $msepoch = sprintf( "%010d%03.0f", $sepoch, $msecepoch );
            my $dlspeeduri =
                $dlurl
              . "/random${hwpixel}x${hwpixel}.jpg?x="
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

            if (   $browser->getinfo(CURLINFO_CONTENT_TYPE) eq 'image/jpeg'
                && $retcode == 0 )
            {
                $totaldltime = $totaldltime + ( $mselapsed / 1000 );
                $totaldlsize =
                  $totaldlsize + ( length($dlspeedjpg) * 8 / 1000000 );
                $avgdlspeed = $totaldlsize / $totaldltime;
            } ## end if ( $browser->getinfo...)
            undef $dlspeedjpg;
            if ( $DBG > 1 ) {
                if ( $DBG > 2 ) {
                    print "$mselapsed milliseconds. done. ==\n";
                }
                printf( "Download Speed: %.${DBG}f Mbps\r", $avgdlspeed );
            } ## end if ( $DBG > 1 )
            $y++;
        } ## end while ( $y < $ycount )
        print "\r";
    } ## end if ( $mbpsl <= $avgdlspeed...)
} ## end foreach my $hwpixel (@hwpixels)

printf( "Download Speed: %.${DBG}f Mbps\n", $avgdlspeed );
if ( $DBG > 1 ) {
    printf( "done: %.${DBG}f Megabits per second. =\n", $avgdlspeed );
}

################################################################################
# UPLOAD test against selected server
################################################################################
if ( $DBG > 1 ) {
    print "= Checking upload against $servers{$bestserver}{name} Hosted by ";
    print
      "$servers{$bestserver}{sponsor}$servers{$bestserver}{neighbourhood}\n";
}

my $totalultime = 0;
my $totalulsize = 0;
my $avgulspeed  = 0;
$mbpsl = 0;
$mbpsh = 0;
my $minultestsize = $upload{mintestsize};
$minultestsize =~ s/K$/000/g;
$minultestsize =~ s/M$/000000/g;

foreach my $hwpixel (@hwpixels) {
    $mbpsl = $mbpsh;
    my $bytes    = ( $hwpixel**2 * 2 );
    my $bits     = ( $bytes * 8 );
    my $kilobits = ( $bits / 1000 );
    my $megabits = ( $kilobits / 1000 );
    $mbpsh = ( ( $megabits / 2 ) / $upload{ratio} );
    if (   $mbpsl <= $avgulspeed
        && $avgulspeed < $mbpsh
        && $minultestsize < $bits )
    {
        my $ulurl       = $servers{$bestserver}{url};
        my $ycount      = 3;
        my $y           = 1;
        my $ulrandimage = rand_image( width => $hwpixel, height => $hwpixel );
        my $ulrandimagesize = length($ulrandimage);

        while ( $y < $ycount ) {
            print "∧"; ## ∧ (logical and) and ∨ (logical or) characters
            ( $sepoch, $usecepoch ) = gettimeofday();
            $msecepoch = ( $usecepoch / 1000 );
            $msepoch = sprintf( "%010d%03.0f", $sepoch, $msecepoch );
            my $ulspeeduri = $ulurl . "?x=" . $msepoch . "&y=" . $y;
            if ( $DBG > 2 ) {
                print "\n== Sending $ulspeeduri ulspeed $y took ";
            }

            $browser->setopt( CURLOPT_URL,           $ulspeeduri );
            $browser->setopt( CURLOPT_POST,          1 );
            $browser->setopt( CURLOPT_POSTFIELDS,    $ulrandimage );
            $browser->setopt( CURLOPT_POSTFIELDSIZE, $ulrandimagesize );
            my @postheaders = ();
            $postheaders[0] = "Content-Type: image/png";
            $browser->setopt( CURLOPT_HTTPHEADER, \@postheaders );
            $browser->setopt( CURLOPT_REFERER,    $flshuri );
            my $ulspeedout;
            $browser->setopt( CURLOPT_WRITEDATA, \$ulspeedout );
            ( my $s0, my $usec0 ) = gettimeofday();
            $retcode = $browser->perform;
            ( my $s1, my $usec1 ) = gettimeofday();
            warn "\nCannot get $ulspeeduri -- $retcode "
              . $browser->strerror($retcode) . " "
              . $browser->errbuf . "\n"
              unless ( $retcode == 0 );
            warn "\nDid not receive HTML, got -- ",
              $browser->getinfo(CURLINFO_CONTENT_TYPE)
              unless $browser->getinfo(CURLINFO_CONTENT_TYPE) =~ m/^text\/html/;
            warn "\nDid not receive valid 'size=' content, got == ",
              $ulspeedout
              unless $ulspeedout =~ m/^size=\d+$/;
            chomp $ulspeedout;
            my ( $x, $stnsize ) = split( /=/, $ulspeedout );
            my $postsizeissue = 0;

            if (   $ulrandimagesize != $browser->getinfo(CURLINFO_SIZE_UPLOAD)
                || $ulrandimagesize !=
                $browser->getinfo(CURLINFO_CONTENT_LENGTH_UPLOAD) )
            {

                if ( $DBG > 1 ) {
                    warn "\n= Something wrong in size. Expected "
                      . "$ulrandimagesize. Got CURLINFO_SIZE_UPLOAD="
                      . $browser->getinfo(CURLINFO_SIZE_UPLOAD)
                      . " and CURLINFO_CONTENT_LENGTH_UPLOAD="
                      . $browser->getinfo(CURLINFO_CONTENT_LENGTH_UPLOAD)
                      . ". =\n";
                } ## end if ( $DBG > 1 )
                $postsizeissue = 1;
            } ## end if ( $ulrandimagesize ...)
            if (   $stnsize > $browser->getinfo(CURLINFO_SIZE_UPLOAD)
                || $stnsize >
                $browser->getinfo(CURLINFO_CONTENT_LENGTH_UPLOAD) )
            {
                if ( $DBG > 1 ) {
                    warn "\n= Something wrong in size. Expected "
                      . "CURLINFO_SIZE_UPLOAD="
                      . $browser->getinfo(CURLINFO_SIZE_UPLOAD)
                      . " and CURLINFO_CONTENT_LENGTH_UPLOAD="
                      . $browser->getinfo(CURLINFO_CONTENT_LENGTH_UPLOAD)
                      . ". Got $stnsize. =\n";
                } ## end if ( $DBG > 1 )
                $postsizeissue = 1;
            } ## end if ( $stnsize > $browser...)
            my $selapsed        = $s1 - $s0;
            my $usecelapsed     = $usec1 - $usec0;
            my $stomselapsed    = ( $selapsed * 1000 );
            my $usectomselapsed = ( $usecelapsed / 1000 );
            my $mselapsed       = $stomselapsed + $usectomselapsed;

            if (   $browser->getinfo(CURLINFO_CONTENT_TYPE) =~ m/^text\/html/
                && $ulspeedout =~ m/^size=\d+$/
                && $retcode == 0
                && $postsizeissue == 0 )
            {
                $totalultime = $totalultime + ( $mselapsed / 1000 );
                $totalulsize =
                  $totalulsize + ( $ulrandimagesize * 8 / 1000000 );
                $avgulspeed = $totalulsize / $totalultime;
            } ## end if ( $browser->getinfo...)
            undef $ulspeedout;
            if ( $DBG > 1 ) {
                if ( $DBG > 2 ) {
                    print "$mselapsed milliseconds. done. ==\n";
                }
                printf( "Upload Speed: %.${DBG}f Mbps\r", $avgulspeed );
            } ## end if ( $DBG > 1 )
            $y++;
        } ## end while ( $y < $ycount )
        print "\r";
    } ## end if ( $mbpsl <= $avgulspeed...)
} ## end foreach my $hwpixel (@hwpixels)

printf( "Upload Speed: %.${DBG}f Mbps\n", $avgulspeed );
if ( $DBG > 1 ) {
    printf( "done: %.${DBG}f Megabits per second. =\n", $avgulspeed );
}

################################################################################
# All done
################################################################################
exit 0;

 __END__
