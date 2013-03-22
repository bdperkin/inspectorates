#! /usr/bin/perl -w

use strict;
use warnings;

my $DBG = 0;

if ( @ARGV > 2 || @ARGV < 2 ) {
    print "Usage: $0 [groff document input] [pod document output]\n";
    exit 1;
}

my $infile  = $ARGV[0];
my $outfile = $ARGV[1];

unless ( open( GROFFFILE, "$infile" ) ) {
    die "Cannot open $infile for reading: $!\n";
}

unless ( open( PODFILE, ">$outfile" ) ) {
    die "Cannot open $outfile for writing: $!\n";
}

my $dropblank = 1;
my $li        = 0;
my $lines     = 0;
while (<GROFFFILE>) {
    my $proc = 0;
    my $line = $_;
    chomp $line;
    $line =~ s/®/(R)/g;
    $lines++;
    if ($DBG) {
        printf( "%5d: ", $lines );
    }
    if ( $line =~ m/^\e/ ) {
        $dropblank = 0;
    }
    if ( $line =~ m/^\w+/ ) {
        if ($DBG) {
            print "SKIP: $line\n";
        }
    }
    elsif ( $line =~ m/^$/ && $dropblank == 1 ) {
        if ($DBG) {
            print "SKIP: $line\n";
        }
    }
    else {
        if ( $line =~ m/^\e\[1m/ && $line =~ m/\e\[0m$/ ) {
            $line =~ s/^\e\[1m/=head1 /g;
            $line =~ s/\e\[0m$/\n/g;
            if ( $li == 1 ) {
                $line =~ s/^/=back\n\n\n/;
                $li = 0;
            }
        }
        if ( $line =~ m/^       / ) {
            $line =~ s/^       //g;
        }

        if ( $line =~ m/:$/ ) {
            $line =~ s/:$/:\n\n\n=over 5/g;
            $li = 1;
        }
        $line =~ s/\e\[4m\e\[22m/>I</g;
        if ( $li == 1 && $line =~ m/^\e\[1m/ && $line =~ m/\e\[0m$/ ) {
            $line =~ s/^\e\[1m/\n=item B</g;
            $line =~ s/\e\[0m$/>\n\n\n\n/g;
        }
        if ( $line =~ m/^    / ) {
            $line =~ s/^    //g;
        }

        $line =~ s/\e\[1m/B</g;
        $line =~ s/\e\[4m/I</g;
        $line =~ s/\e\[0m/>/g;
        $line =~ s/\e\[22m/>/g;
        $line =~ s/\e\[24m/>/g;
        if ( $line =~ m/\e/ && $DBG ) {
            print "TODO: ";
        }
        if ($DBG) {
            print "$line\n";
        }
        print PODFILE "$line\n";
    }
}

print PODFILE "=cut\n";

if ($DBG) {
    print "\n";
}

close(PODFILE);

close(GROFFFILE);
