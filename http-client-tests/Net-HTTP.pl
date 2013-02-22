#! /usr/bin/perl -wT

use Regexp::Common qw /URI/;
use strict;
use Time::HiRes qw(gettimeofday);
use URI::Split qw(uri_split uri_join);
use warnings;
use Net::HTTP;

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

my $s = Net::HTTP->new( Host => $auth ) || die $@;

( my $s0, my $usec0 ) = gettimeofday();

# Pass request to the user agent and get a response back
$s->write_request( GET => $path, 'User-Agent' => "MyApp/0.1 " );
my ( $code, $mess, %h ) = $s->read_response_headers;
while (1) {
    my $buf;
    my $n = $s->read_entity_body( $buf, 1024 );
    die "read failed: $!" unless defined $n;
    last unless $n;
    $size = $size + length($buf);
}
( my $s1, my $usec1 ) = gettimeofday();

# Check the outcome of the response
if ($size) {
    print "SUCCESS!\n";
}
else {
    print "HTTP status code: $code textual message: $mess\n";
}

my $selapsed        = $s1 - $s0;
my $usecelapsed     = $usec1 - $usec0;
my $stomselapsed    = ( $selapsed * 1000 );
my $usectomselapsed = ( $usecelapsed / 1000 );
my $mselapsed       = $stomselapsed + $usectomselapsed;

$time = $mselapsed;

my $rate = ( ( ( $size * 8 ) / 1000000 ) / ( $time / 1000 ) );

print "SIZE: $size bytes\n";
print "TIME: $time ms\n";
print "RATE: $rate Mbps\n";

exit 0;
