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
use Pod::Usage;     # Pod::Usage - Print usage message from embedded pod docs

#################################################################################
# Declare constants
#################################################################################
$ENV{PATH}  = "/usr/bin";    # Keep taint happy
$ENV{PAGER} = "more";        # Keep pod2usage output happy
my $name    = "%{NAME}";     # Name string
my $version = "%{VERSION}";  # Version number
my $release = "%{RELEASE}";  # Release string

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
}

exit 0;

 __END__
