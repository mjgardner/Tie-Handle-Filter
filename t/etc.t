#!/usr/bin/env perl

use 5.008;
use strict;
use warnings;
use Test::Most;
use Fcntl ':seek';
use Tie::Handle::Filter;

my @unimplemented = qw(readline getc open binmode eof tell seek);
plan tests => 3 + @unimplemented;

subtest 'no coderef' => sub {
    plan tests => 3;
    my $fh = _open();
    lives_ok { _tie($fh) } 'tie';

    my $expected = 'hello world';
    lives_ok { print $fh $expected } 'print';

    untie *$fh;
    seek $fh, 0, SEEK_SET
        or die "can't seek to start of anonymous storage: $!";
    my $written = join '', <$fh>;
    is $written, $expected, 'read back' or show $written;
};

subtest 'explicit syswrite arguments' => sub {
    plan tests => 2;
    my $fh = _open();
    _tie($fh);

    my $input    = 'hello world';
    my $offset   = 6;
    my $expected = substr $input, $offset, 5;
    lives_ok { syswrite $fh, $input, length $expected, $offset } 'syswrite';

    untie *$fh;
    seek $fh, 0, SEEK_SET
        or die "can't seek to start of anonymous storage: $!";
    my $written;
    sysread $fh, $written, length $expected;

    is $written, $expected, 'read back' or show $written;
};

subtest 'explicit close' => sub {
    plan tests => 1;
    my $fh = _open();
    _tie($fh);
    lives_ok { close $fh } 'close';
};

TODO: {
    local $TODO = 'unimplemented';
    for my $function_name (@unimplemented) {
        my $fh = _open();
        _tie($fh);
        lives_ok { eval "$function_name \$fh" and die $? } $function_name;
        close $fh;
    }
}

sub _open {
    open my $fh, '+>', undef
        or die "can't create anonymous storage: $!";
    return $fh;
}

sub _tie {
    my $fh = shift;
    tie *$fh, 'Tie::Handle::Filter', *$fh;
}
