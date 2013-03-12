#! /usr/bin/perl -wT

use Regexp::Common qw /URI/;
use strict;
use Time::HiRes qw(gettimeofday);
use URI::Split qw(uri_split uri_join);
use warnings;
use WWW::Curl::Easy;

my $uri = "";
my $file = "";
if ( @ARGV < 2 || @ARGV > 2 ) {
    die "Usage: $0 [URI] [FILE]: $!\n";
}
else {
    $uri = $ARGV[0];
    chomp($uri);
    $file = $ARGV[1];
    chomp($file);
}

unless(open(FILE, $file)) {
    die "Cannot open $file for reading: $!\n";
}
binmode FILE;
my ($buf, $data, $n);
while (($n = read FILE, $data, 4) != 0) {
    #print "$n bytes read\n";
    $buf .= $data;
    #printf("%d bytes\r", length($buf));
}
#print "\n";

close(FILE);

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

# Create the URL
my $url = $scheme . "://" . $auth . $path;

# Create a request
my $req = WWW::Curl::Easy->new;

$req->setopt( CURLOPT_VERBOSE, 1 );
my $curlversion = $req->version(CURLVERSION_NOW);
chomp $curlversion;
my @curlversions = split( /\s/, $curlversion );

$req->setopt( CURLOPT_USERAGENT,   "$curlversions[0]" );
$req->setopt( CURLOPT_HEADER, 0 );
$req->setopt( CURLOPT_URL,    $url );
$req->setopt( CURLOPT_POST,       1 );
$req->setopt( CURLOPT_POSTFIELDS, $buf );
$req->setopt( CURLOPT_POSTFIELDSIZE, length($buf));

my $res;
$req->setopt( CURLOPT_WRITEDATA, \$res );

( my $s0, my $usec0 ) = gettimeofday();

# Pass request to the user agent and get a response back
my $retcode = $req->perform;
( my $s1, my $usec1 ) = gettimeofday();

# Check the outcome of the response
if ( $retcode == 0 ) {
    print "$res";
    $size = length($res);
}
else {
    print "An error happened: $retcode "
      . $req->strerror($retcode) . " "
      . $req->errbuf . "\n";
}

my $selapsed        = $s1 - $s0;
my $usecelapsed     = $usec1 - $usec0;
my $stomselapsed    = ( $selapsed * 1000 );
my $usectomselapsed = ( $usecelapsed / 1000 );
my $mselapsed       = $stomselapsed + $usectomselapsed;

$time = $mselapsed;

my $rate = ( ( ( $size * 8 ) / 1000000 ) / ( $time / 1000 ) );

#print "SIZE: $size bytes\n";
#print "TIME: $time ms\n";
#print "RATE: $rate Mbps\n";

exit 0;
