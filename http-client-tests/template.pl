#! /usr/bin/perl -wT

use Regexp::Common qw /URI/;
use strict;
use URI::Split qw(uri_split uri_join);
use warnings;
# USE GOES HERE

my $uri = "";
if ( @ARGV < 1 || @ARGV > 1 ) {
    die "Usage: $0 [URI]: $!\n";
}
else {
    $uri = $ARGV[0];
    chomp($uri);
}

#print "URI: $uri\n";

if ( $uri =~ m/$RE{URI}{HTTP}/ ) {
    #print "'$uri' IS a valid HTTP URI.\n";
}
else {
    die "'$uri' is NOT a valid HTTP URI: $!\n";
}

( my $scheme, my $auth, my $path, my $query, my $frag ) = uri_split($uri);

#printf("scheme: %-40s\n  auth: %-40s\n  path: %-40s\n query: %-40s\n  frag: %-40s\n", $scheme, $auth, $path, $query, $frag );

my $size = 0;
my $time = 0;

# HTTP GET GOES HERE

print "SIZE: $size\n";
print "TIME: $time\n";

exit 0;
