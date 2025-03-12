#!/usr/bin/perl

use strict;
use warnings;

use Storable qw(store);
use List::Util qw(sum min max);

my $big_file   = 'big.txt';
my $bad_file   = 'bad.txt';
my $good_file  = 'good.txt';
my $model_file = 'gib_model.dat';

my @accepted_chars = split( //, 'abcdefghijklmnopqrstuvwxyz ' );

my %pos = map { $accepted_chars[$_] => $_ } 0 .. $#accepted_chars;

sub normalize {
    my ($line) = @_;

    # Return only the subset of chars from accepted_chars.
    # This helps keep the  model relatively small by ignoring punctuation,
    # infrequently symbols, etc.
    grep { exists( $pos{$_} ) } split( //, lc($line) );
}

sub ngram {
    my ( $n, $l ) = @_;

    # Return all n grams from l after normalizing
    my @filtered = normalize($l);

    my @ngram;
    foreach my $start ( 0 .. @filtered - $n ) {
        push @ngram, [ @filtered[ $start .. $start + $n - 1 ] ];
    }

    return @ngram;
}

sub train {

    # Write a simple model as a pickle file
    my $k = scalar(@accepted_chars);

    # Assume we have seen 10 of each character pair.  This acts as a kind of
    # prior or smoothing factor.  This way, if we see a character transition
    # live that we've never observed in the past, we won't assume the entire
    # string has 0 probability.
    my @counts = map { [ (10) x $k ] } 1 .. $k;

    # Count transitions from big text file, taken
    # from http://norvig.com/spell-correct.html
    {
        open my $fh, '<', $big_file
          or die "Can't open file $big_file: $!";

        while ( defined( my $line = <$fh> ) ) {
            foreach my $pair ( ngram( 2, $line ) ) {

                my $a = $pair->[0];
                my $b = $pair->[1];

                $counts[ $pos{$a} ][ $pos{$b} ] += 1;
            }
        }

        close $fh;
    }

# Normalize the counts so that they become log probabilities.
# We use log probabilities rather than straight probabilities to avoid
# numeric underflow issues with long texts.
# This contains a justification:
# http://squarecog.wordpress.com/2009/01/10/dealing-with-underflow-in-joint-probability-calculations/
    foreach my $row (@counts) {
        my $s = sum(@$row);
        foreach my $j ( 0 .. $#{$row} ) {
            $row->[$j] = log( $row->[$j] / $s );
        }
    }

    # Find the probability of generating a few arbitrarily choosen good and
    # bad phrases.
    my @good_probs;
    {
        open my $fh, '<', $good_file
          or die "Can't open file $good_file: $!";
        while ( defined( my $line = <$fh> ) ) {
            push @good_probs, avg_transition_prob( $line, \@counts );
        }
        close $fh;
    }

    my @bad_probs;
    {
        open my $fh, '<', $bad_file
          or die "Can't open file $bad_file: $!";
        while ( defined( my $line = <$fh> ) ) {
            push @bad_probs, avg_transition_prob( $line, \@counts );
        }
        close $fh;
    }

    my $min = min(@good_probs);
    my $max = max(@bad_probs);

    # Assert that we actually are capable of detecting the junk.
    unless ( $min > $max ) {
        die "Failed detection test: $min > $max";
    }

    # And pick a threshold halfway between the worst good and best bad inputs.
    my $thresh = ( $min + $max ) / 2;

    store( { mat => \@counts, thresh => $thresh }, $model_file );
}

sub avg_transition_prob {
    my ( $l, $log_prob_mat ) = @_;

    # Return the average transition prob from l through log_prob_mat.
    my $log_prob      = 0;
    my $transition_ct = 0;

    foreach my $pair ( ngram( 2, $l ) ) {
        my $a = $pair->[0];
        my $b = $pair->[1];
        $log_prob += $log_prob_mat->[ $pos{$a} ][ $pos{$b} ];
        $transition_ct += 1;
    }

    # The exponentiation translates from log probs to probs.
    return exp( $log_prob / ( $transition_ct || 1 ) );
}

if ( not caller ) {
    train();
}

1;    # must return true
