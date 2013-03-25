#! /usr/bin/perl -w

use strict;
use warnings;
use Cwd;
my $dir  = getcwd;
my $adir = $dir . "/alien";
my $bdir = $dir . "/build";
my $ddir = $dir . "/debhelper";
my $acmd = $adir . "/alien.pl";
$ENV{PATH}     = $ddir . ":" . $ENV{PATH};
$ENV{PERL5LIB} = $ddir;
my $email = `git config user.email`;
chomp $email;
$ENV{EMAIL} = $email;
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

if ( !-d $bdir ) {
    mkdir($bdir);
}

if ( !-d $ddir ) {
    die "Cannot find debhelper directory \"$ddir\": $!\n";
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

my $name   = `rpm -qp --queryformat="%{NAME}" $infile`;
my $outdir = `rpm -qp --queryformat="%{NAME}-%{VERSION}" $infile`;

chdir($adir);

foreach my $pkg (@pkgs) {

    if ( -d $pkg ) {
        system("rm -r $pkg");
    }

    if ( -d "orig" ) {
        system("rm -r orig");
    }

    my $return = system("/usr/bin/fakeroot $acmd --to-$pkg -g -c -k $infile");

    #my $return=system("/usr/bin/fakeroot $acmd --to-$pkg -c -k $infile");

    if ($return) {
        die "Something went wrong running $acmd: $!\n";
    }
    rename( $outdir, $pkg );
    if ( -d "$outdir.orig" ) {
        rename( "$outdir.orig", "orig" );
        my $rsyncorig =
          system("/usr/bin/rsync -ax --remove-source-files orig/ $bdir/");
        if ($rsyncorig) {
            die "Something went wrong running rsync of original content: $!\n";
        }
    }
    my $rsyncout =
      system("/usr/bin/rsync -ax --remove-source-files $pkg/ $bdir/");
    if ($rsyncout) {
        die "Something went wrong running rsync of $pkg content: $!\n";
    }
}

system("mv $bdir/$name-*.spec $bdir/$name.spec");
system("mv $bdir/lsb-$name-*.spec $bdir/lsb-$name.spec");
system("sed -i -e '/^Buildroot: */ d' $bdir/*$name.spec");
