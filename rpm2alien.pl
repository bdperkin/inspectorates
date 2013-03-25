#! /usr/bin/perl -w

use strict;
use warnings;
use Cwd;
my $dir  = getcwd;
my $adir = $dir . "/alien";
my $ddir = $dir . "/debhelper";
my $acmd = $adir . "/alien.pl";
$ENV{PATH}     = $ddir . ":" . $ENV{PATH};
$ENV{PERL5LIB} = $ddir;
my @pkgs = ( "deb", "lsb", "rpm", "slp", "tgz" );

my $DBG = 0;

if ( @ARGV > 1 || @ARGV < 1 ) {
    print "Usage: $0 [Binary RPM Input]\n";
    exit 1;
}

my $infile = $ARGV[0];

if ( !-d $adir ) {
    die "Cannot find alien directory \"$adir\": $!\n";
}

if ( !-f $acmd ) {
    die "Cannot find alien command \"$acmd\": $!\n";
}
elsif ( !-x $acmd ) {
    die "Cannot execute alien command \"$acmd\": $!\n";
}

if ( !-f $infile ) {
    die "Cannot find rpm file \"$infile\": $!\n";
}
elsif ( !-r $acmd ) {
    die "Cannot read rpm file \"$infile\": $!\n";
}

my $outdir = `rpm -qp --queryformat="%{NAME}-%{VERSION}" $infile`;

chdir($adir);

foreach my $pkg (@pkgs) {
    my $return = system("/usr/bin/fakeroot $acmd --to-$pkg -g -c -k $infile");

    #my $return=system("/usr/bin/fakeroot $acmd --to-$pkg -c -k $infile");
    if ($return) {
        die "Something went wrong running $acmd: $!\n";
    }
    rename( $outdir, $pkg );
    if ( -d "$outdir.orig" ) {
        rename( "$outdir.orig", "orig" );
    }
}
