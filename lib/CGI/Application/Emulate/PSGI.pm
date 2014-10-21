package CGI::Application::Emulate::PSGI;

use 5.008;
use strict;
use warnings;
use CGI;

our $VERSION = '0.01';

sub handler {
    my ($class, $code,) = @_;
    
    return sub {
        my $env = shift;
        my $environment = {
            GATEWAY_INTERFACE => 'CGI/1.1',
            # not in RFC 3875
            HTTPS => ( ( $env->{'psgi.url_scheme'} eq 'https' ) ? 'ON' : 'OFF' ),
            SERVER_SOFTWARE => "CGI-Emulate-PSGI",
            REMOTE_ADDR     => '127.0.0.1',
            REMOTE_HOST     => 'localhost',
            REMOTE_PORT     => int( rand(64000) + 1000 ),    # not in RFC 3875
            # REQUEST_URI     => $uri->path_query,             # not in RFC 3875
            ( map { $_ => $env->{$_} } grep !/^psgi\./, keys %$env ),
            CGI_APP_RETURN_ONLY => 1,
        };
        my $output = do {
            local *STDIN  = $env->{'psgi.input'};
            local *STDERR = $env->{'psgi.errors'};
            local @ENV{keys %$environment} = values %$environment;
            CGI::initialize_globals();
            $code->();
        };
        my $status = 200;
        my ($headers, $body) = split /\r?\n\r?\n/, $output, 2;
        my @headers = map { split /:\s*/, $_, 2 } split /\r?\n/, $headers;
        for (my $i = 0; $i < @headers;) {
            if ($headers[$i] =~ /^status$/i) {
                $status = $headers[$i + 1];
                $status =~ s/\s+.*$//; # only keep the digits
                splice @headers, $i, 2;
            } else {
                $i += 2;
            }
        }
        return [
            $status,
            \@headers,
            [ $body ],
        ];
    };
}

1;
__END__

=head1 NAME

CGI::Application::Emulate::PSGI - a legacy-code-friendly PSGI adapter for CGI::Application

=head1 SYNOPSIS

    # if using CGI::Application
    my $app = CGI::Application::Emulate::PSGI->handler(sub {
        my $webapp = WebApp->new();
        $webapp->run();
    });

    # if using CGI::Application::Dispatch
    my $app = CGI::Application::Emulate::PSGI->handler(sub {
        WebApp::Dispatch->dispatch();
    });

=head1 DESCRIPTION

CGI::Application::Emulate::PSGI is a runner to run L<CGI::Application> as a PSGI application.  Differences from L<CGI::Application::PSGI> are:

=over 4

=item uses L<CGI.pm> instead of L<CGI::PSGI>

L<CGI::Application::PSGI> (that uses L<CGI::PSGI>) does not support programs calling L<CGI.pm> in func-style (like CGI::virtual_host()).  CGI::Application::Emulate::PSGI sets up environment variables so that codes using L<CGI.pm> will work.

=item compatible with L<CGI::Application::Dispatch>

The interface of CGI::Application::Emulate::PSGI is different from L<CGI::Application::PSGI>, and is compatible with L<CGI::Application::Dispatch>.

=back

=head1 AUTHOR

Kazuho Oku E<lt>kazuhooku@gmail.comE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<CGI::Application::PSGI>

=cut
