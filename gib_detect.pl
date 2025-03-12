#!/usr/bin/perl

use strict;
use warnings;

use Storable qw(retrieve);
require('gib_detect_train.pl');

my $model_file     = 'gib_model.dat';
my $exception_file = 'exception.txt';

my $model_data = retrieve($model_file);

# Read exceptions (one per line)
my %exceptions;
{
    open my $fh, '<', $exception_file
      or die "Can't open file $exception_file: $!";
    while ( defined( my $line = <$fh> ) ) {
        $line = join( ' ', split( ' ', lc($line) ) );    # normalize
        $exceptions{$line} = 1;
    }
    close $fh;
}

while (1) {
    print "Input: ";
    my $line = <STDIN>;

    if ( not defined $line ) {
        last;
    }

    # Slits the line into words
    my @words = split( ' ', lc($line) );

    my %result;
    foreach my $word (@words) {

        # Word exists in the exceptions list
        if ( exists $exceptions{$word} ) {
            $result{$word} += 1;
            next;
        }

        my $model_mat = $model_data->{mat};
        my $threshold = $model_data->{thresh};

        my $prob = avg_transition_prob( $word, $model_mat );

        if ( $prob > $threshold ) {
            $result{$word} += 1;
        }
        else {
            $result{$word} -= 1;
        }
    }

    if ( not @words ) {
        next;
    }

    my $sum  = sum( values %result );
    my $diff = $sum - @words;

    if ( $diff == 0 ) {
        print "Line does not contain gibberish words.\n";
    }
    else {
        my @gibberish = grep { $result{$_} < 0 } @words;
        my $count = scalar @gibberish;
        print "Line contains $count gibberish words.\n";
        print "The gibberish words are: ";
        print join( ', ', @gibberish ), "\n";
    }
}
