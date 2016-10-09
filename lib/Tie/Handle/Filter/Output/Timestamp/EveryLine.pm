package Tie::Handle::Filter::Output::Timestamp::EveryLine;

# ABSTRACT: prepend every line of filehandle output with a timestamp

use 5.008;
use strict;
use warnings;
use base 'Tie::Handle::Filter';
use English '-no_match_vars';
use POSIX 'strftime';
our $VERSION = '0.010';

=head1 SYNOPSIS

    use Tie::Handle::Filter::Output::Timestamp::EveryLine;
    tie *STDOUT, 'Tie::Handle::Filter::Output::Timestamp::EveryLine', *STDOUT;

    print "Everything I print will be prepended with a timestamp.\n";
    print <<'END_OUTPUT';
    Even multi-line output will have every line prepended.
    Including this one.
    END_OUTPUT

=cut

=head1 DESCRIPTION

This class may be used with Perl's L<tie|perlfunc/tie> function to
prepend all output with a timestamp, optionally formatted according to
the L<POSIX C<strftime>|POSIX/strftime> function. Unlike
L<C<Tie::Handle::Filter::Output::Timestamp>|Tie::Handle::Filter::Output::Timestamp>,
I<every> line gets a timestamp, rather than just the beginning of
strings given to L<C<print>|perlfunc/print>,
L<C<printf>|perlfunc/printf>, L<C<syswrite>|perlfunc/syswrite>, and
L<C<say>|perlfunc/say> (in Perl > v5.10).

=head1 BUGS AND LIMITATIONS

Because the date and time format is specified using
L<C<strftime>|POSIX/strftime>, portable code should restrict itself to
formats using ANSI C89 specifiers.

=cut

my $NEWLINE = $PERL_VERSION lt 'v5.10'
    ? '(?>\x0D\x0A|\n)'    ## no critic (RequireInterpolationOfMetachars)
    : '\R';

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
    return $class->SUPER::TIEHANDLE( $handle_glob,
        _filter_closure( $format || '%x %X ' ) );
}

sub _filter_closure {
    my $format           = shift;
    my $string_beginning = 1;
    return sub {
        my $string = join q() => @_;
        $string
            =~ s/ ($NEWLINE) (?=.) / $1 . strftime($format, localtime) /egmsx;
        if ($string_beginning) {
            $string =~ s/ \A / strftime($format, localtime) /emsx;
        }
        $string_beginning = $string =~ / $NEWLINE \z/msx
            || $OUTPUT_RECORD_SEPARATOR eq "\n";
        return $string;
    };
}

1;
