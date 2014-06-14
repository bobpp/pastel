use strict;
use warnings;
use t::Util;
use Plack::Test;
use Plack::Util;
use Test::More;
use HTTP::Request::Common qw(GET POST DELETE);

my $app = Plack::Util::load_psgi 'app.psgi';
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = POST '/create', Content => ['body' => 'foobar'];
        my $res = $cb->($req);
        is $res->code, 302;
        my $location = $res->header('location');
        $req = DELETE $location;
        $res = $cb->($req);
        is $res->code, 302;
        diag $res->content if $res->code != 302;
        is $res->header('location'), 'http://localhost/';
        $req = GET $location;
        $res = $cb->($req);
        is $res->code, 404;
        diag $res->content if $res->code != 404;
    };

done_testing;
