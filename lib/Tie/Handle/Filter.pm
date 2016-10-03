package Tie::Handle::Filter;

# ABSTRACT: filters the output to a filehandle through a coderef

=head1 SYNOPSIS

    use Tie::Handle::Filter;

    # prefix output to STDERR with standard Greenwich time
    BEGIN {
        tie *STDERR, 'Tie::Handle::Filter', *STDERR,
            sub { scalar(gmtime) . ': ', @_ };
    }

    # or prefix every output line, even on multi-line output
    BEGIN {
        # deal with perl 5.8 lack of \R
        my $newline = $] < 5.010 ? '(?>\x0D\x0A|\n)' : '\R';

        my $prefix_start = 1;
        tie *STDOUT, 'Tie::Handle::Filter', *STDOUT, sub {
            my $res = join '', @_;
            $res =~ s/($newline)(?=.)/$1 . gmtime() . ': '/eg;
            $res =~ s/\A/            gmtime() . ': '/e if $prefix_start;
            $prefix_start = $res =~ /$newline\z/s;
            return $res;
        };
    }

=head1 DESCRIPTION

This is a small module for changing output when it is sent to a given
file handle. By default it passes everything unchanged, but when
provided a code reference, that reference is passed the string being
sent to the tied file handle and may return a transformed result.

=head1 DEPENDENCIES

=head2 Core

=over

=item L<base|base>

=item L<Carp|Carp>

=item L<English|English>

=item L<Fcntl|Fcntl>

=item L<Tie::Handle|Tie::Handle>

=back

=head2 Non-Core

=over

=item L<FileHandle::Fmode|FileHandle::Fmode>

=back

=cut

use 5.008;
use strict;
use warnings;

# VERSION
use base 'Tie::Handle';
use Carp;
use English '-no_match_vars';
use FileHandle::Fmode ':all';

=head1 DIAGNOSTICS

Wherever possible this module attempts to emulate the built-in functions
it ties, so it will return values as expected from whatever function is
called. Certain operations may also L<C<croak>|Carp> (throw a fatal
exception) if they fail, such as duplicating the file handle during a
L<C<tie>|perlfunc/tie> or attempting to perform an
L<unsupported operation|/"BUGS AND LIMITATIONS"> on a tied file handle.

=cut

sub TIEHANDLE {
    my ( $class, $handle_glob, $writer_ref ) = @_;

    ## no critic (InputOutput::RequireBriefOpen)
    open my $fh, _get_filehandle_open_mode($handle_glob) . q(&), $handle_glob
        or croak $OS_ERROR;

    return bless {
        filehandle => $fh,
        writer     => (
            ( defined $writer_ref and 'CODE' eq ref $writer_ref )
            ? $writer_ref
            : sub { return @_ }
        ),
    }, $class;
}

sub _get_filehandle_open_mode {
    my $fh = shift;
    for ($fh) {
        return '>>'  if is_WO($_) and is_A($_);
        return '>'   if is_WO($_);
        return '<'   if is_RO($_);
        return '+>>' if is_RW($_) and is_A($_);
        return '+<'  if is_RW($_);
    }
    return '+>';
}

## no critic (Subroutines::RequireArgUnpacking)
## no critic (Subroutines::RequireFinalReturn)

=method PRINT

All arguments to L<C<print>|perlfunc/print> and L<C<say>|perlfunc/say>
directed at the tied file handle are passed to the user-defined
function, and the result is then passed to L<C<print>|perlfunc/print>.

=cut

sub PRINT {
    my $self = shift;
    ## no critic (InputOutput::RequireCheckedSyscalls)
    print { $self->{filehandle} } $self->{writer}->(@_);
}

=method PRINTF

The second and subsequent arguments to L<C<printf>|perlfunc/printf>
(i.e., everything but the format string) directed at the tied file
handle are passed to the user-defined function, and the result is then
passed preceded by the format string to L<C<printf>|perlfunc/printf>.

Please note that this does not include calls to
L<C<sprintf>|perlfunc/sprintf>.

=cut

sub PRINTF {
    my ( $self, $format ) = splice @_, 0, 2;
    printf { $self->{filehandle} } $format, $self->{writer}->(@_);
}

=method WRITE

The first argument to L<C<syswrite>|perlfunc/syswrite> (i.e., the buffer
scalar variable) directed at the tied file handle is passed to the
user-defined function, and the result is then passed along with the
optional second and third arguments (i.e., length of data in bytes and
offset within the string) to L<C<syswrite>|perlfunc/syswrite>.

Note that if you do not provide a length argument to
L<C<syswrite>|perlfunc/syswrite>, it will be computed from the result of
the user-defined function. However, if you do provide a length (and
possibly offset), they will be relative to the results of the
user-defined function, not the input.

=cut

sub WRITE {
    my ( $self, $original ) = splice @_, 0, 2;
    my $buffer = ( $self->{writer}->($original) )[0];
    syswrite $self->{filehandle}, $buffer,
        ( defined $_[0] ? $_[0] : length $buffer ),
        ( defined $_[1] ? $_[1] : 0 );
}

sub CLOSE {
    my $self = shift;
    ## no critic (InputOutput::RequireCheckedSyscalls)
    ## no critic (InputOutput::RequireCheckedClose)
    close $self->{filehandle};
}

=head1 BUGS AND LIMITATIONS

If your function needs to know what operation was used to call it,
consider using C<(caller 1)[3]> to determine the method used to call
it, which will return C<Tie::Handle::Filter::PRINT>,
C<Tie::Handle::Filter::PRINTF>, or C<Tie::Handle::Filter::WRITE> per
L<perltie/"Tying FileHandles">.

Currently this module is biased towards write-only file handles, such as
C<STDOUT>, C<STDERR>, or ones used for logging. It does not (yet) define
the following methods and their associated functions, so don't do them
with file handles tied to this class.

=head2 READ

=over

=item L<C<read>|perlfunc/read>

=item L<C<sysread>|perlfunc/sysread>

=back

=head2 READLINE

=over

=item L<C<E<lt>HANDLEE<gt>>|perlop/"I/O Operators">

=item L<C<readline>|perlfunc/readline>

=back

=head2 GETC

=over

=item L<C<getc>|perlfunc/getc>

=back

=head2 OPEN

=over

=item L<C<open>|perlfunc/open> (e.g., re-opening the file handle)

=back

=head2 BINMODE

=over

=item L<C<binmode>|perlfunc/binmode>

=back

=head2 EOF

=over

=item L<C<eof>|perlfunc/eof>

=back

=head2 TELL

=over

=item L<C<tell>|perlfunc/tell>

=back

=head2 SEEK

=over

=item L<C<seek>|perlfunc/seek>

=back

=cut

my $unimplemented_ref = sub {
## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    my $package = ( caller 0 )[0];
    my $method  = ( caller 1 )[3];
    $method =~ s/\A ${package} :: //xms;
    croak "$package doesn't define a $method method";
};

sub OPEN    { $unimplemented_ref->() }
sub BINMODE { $unimplemented_ref->() }
sub EOF     { $unimplemented_ref->() }
sub TELL    { $unimplemented_ref->() }
sub SEEK    { $unimplemented_ref->() }

1;
