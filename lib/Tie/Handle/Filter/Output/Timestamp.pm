package Tie::Handle::Filter::Output::Timestamp;

# ABSTRACT: prepend filehandle output with a timestamp

use 5.008;
use strict;
use warnings;
use base 'Tie::Handle::Filter';
use POSIX 'strftime';
our $VERSION = '0.011';

=head1 SYNOPSIS

    use Tie::Handle::Filter::Output::Timestamp;
    tie *STDOUT, 'Tie::Handle::Filter::Output::Timestamp', *STDOUT;

    print "Everything I print will be prepended with a timestamp.\n";
    print <<'END_OUTPUT';
    The first line of a multi-line string will be prepended.
    Subsequent lines will not.
    END_OUTPUT

=head1 DESCRIPTION

This class may be used with Perl's L<tie|perlfunc/tie> function to
prepend all output with a timestamp, optionally formatted according to
the L<POSIX C<strftime>|POSIX/strftime> function. Only the beginning of
strings given to L<C<print>|perlfunc/print>,
L<C<printf>|perlfunc/printf>, L<C<syswrite>|perlfunc/syswrite>, and
L<C<say>|perlfunc/say> (in Perl > v5.10) get timestamps.

=head1 BUGS AND LIMITATIONS

Because the date and time format is specified using
L<C<strftime>|POSIX/strftime>, portable code should restrict itself to
formats using ANSI C89 specifiers.

=head1 SEE ALSO

L<Tie::Handle::Filter::Output::Timestamp::EveryLine|Tie::Handle::Filter::Output::Timestamp::EveryLine>,
which prefixes every line.

=method TIEHANDLE

Invoked by the command
C<tie *glob, 'Tie::Handle::Filter::Output::Timestamp', *glob>.
You may also specify a L<C<strftime>|POSIX/strftime> string as an
additional parameter to format the timestamp; by default the format is
C<%x %X >, which is the local representation of the date and time
followed by a space.

=cut

sub TIEHANDLE {
    my ( $class, $handle_glob, $format ) = @_;
    $format ||= '%x %X ';
    return $class->SUPER::TIEHANDLE( $handle_glob,
        sub { ( strftime( $format, localtime ), @_ ) } );
}

1;
