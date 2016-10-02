#!/bin/env perl

use 5.008;
use strict;
use warnings;
use Test::Most;
use Fcntl ':seek';
use Tie::Handle::Filter;

my $prefix_start = 1;
my $prefix       = 'FOOBAR';
open my $fh, '+>', undef or die "can't create anonymous storage: $!";
tie *$fh, 'Tie::Handle::Filter', *$fh, sub {
    my $res = join q(), @_;
    $res =~ s/(\R)(?=.)/$1$prefix: /g;
    $res =~ s/\A/$prefix: / if $prefix_start;
    $prefix_start = $res =~ /\R\z/s;
    return $res;
};

lives_ok {
    print $fh <<'END_PRINT' } 'print with prefix';
hello world
goodbye and good luck
END_PRINT

untie *$fh;
seek $fh, 0, SEEK_SET
    or die "can't seek to start of anonymous storage: $!";
my $written = join q(), <$fh>;

is $written, <<"END_EXPECTED", 'lines were prefixed';
$prefix: hello world
$prefix: goodbye and good luck
END_EXPECTED

done_testing();
