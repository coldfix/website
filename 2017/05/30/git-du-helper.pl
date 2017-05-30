#! /usr/bin/env perl

use strict;
use warnings;

use File::Basename qw(dirname);
use List::Util qw(sum max);

my $just_files = scalar(@ARGV) > 0 && $ARGV[0] eq '-f';
my %folder_contents;

while (<>) {
    chomp;
    my ($mode, $kind, $hash, $size, $filename) = split(/\s+/, $_, 5);
    do {
        $folder_contents{$filename}{$hash} = $size
    } until ($just_files || (($filename = dirname($filename) . "/") eq './'));
}

while (my ($path, $objects) = each %folder_contents) {
    print(sum(values %$objects), " ",
          max(values %$objects), " ",
          scalar(keys %$objects), " ",
          $path, "\n");
}
