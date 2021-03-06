use strict;
use warnings;
use t::Util;
use Plack::Test;
use Plack::Util;
use Test::More;
use HTTP::Request::Common;

my $app = Plack::Util::load_psgi 'app.psgi';
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = POST '/create', Content => ['body' => 'foobar'];
        my $res = $cb->($req);
        is $res->code, 302;
        my $location = $res->header('location');
        $req = GET $location;
        $res = $cb->($req);
        is $res->code, 200;
        diag $res->content if $res->code != 200;
    };

done_testing;
