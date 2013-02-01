#!/usr/bin/perl -Tw
#
# %{NAME} - Internet connection bandwidth speed test tool.
# Copyright (C) 2013  Brandon Perkins <bperkins@redhat.com>
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

use strict;
use warnings;
use Getopt::Long;

my $name    = "%{NAME}";
my $version = "%{VERSION}";
my $release = "%{RELEASE}";

Getopt::Long::Configure(qw(bundling no_getopt_compat));

my $opthelp;
my $optversion;

GetOptions(
    "h"       => \$opthelp,
    "help"    => \$opthelp,
    "V"       => \$optversion,
    "version" => \$optversion
);

if ($opthelp) {
    print STDERR <<HELP;
usage: $name {-V|--version|-h|--help}
HELP
    exit 0;
}

if ($optversion) {
    print "$name $version ($release)\n";
    exit 0;
}

exit 0;
