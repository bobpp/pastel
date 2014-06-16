use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Plack::Builder;
use Amon2::Lite;
use Digest::SHA1;
use DateTime;
use Encode;

# use Database
__PACKAGE__->load_plugins('DBI');

# put your configuration here
sub config {
	my $database_filename = "$ENV{PLACK_ENV}.db";
	my $initialization_sql_filename = "sqlite.sql";
	+{
		'Text::Xslate' => +{ syntax => 'Kolon', module => [] },
		'database_filename' => $database_filename,
		'DBI' => [ "dbi:SQLite:dbname=$database_filename", '', '' ],
		'initialization_sql_filename' => $initialization_sql_filename,
	}
}

# top
get '/' => sub {
	my $c = shift;
	return $c->render('form.tx');
};

# create
post '/create' => sub {
	my($c) = @_;

	# validation
	my $body = $c->req->param('body') || return $c->redirect('/');

	# init
	if (!-f config->{database_filename}) {
		_initialize_database(config->{database_filename});
	}

	# create
	my $key = sub {
		my $key = Digest::SHA1::sha1_hex(sprintf("%d -- %s -- %f", time, encode_utf8($body), int(rand(10000))));
		$c->dbh->do(
			'INSERT INTO memos (access_key, body, created_at, updated_at) VALUES (?, ?, ?, ?)',
			undef,
			$key, $body, time, time
		);
		return $key;
	}->();

	$c->redirect(sprintf('/memos/%s', $key));
};

# view memo
get '/memos/:key' => sub {
	my($c, $args) = @_;
	my $key = $args->{key};
	unless ($key) {
		return $c->res_404;
	}

	my $memo = $c->dbh->selectrow_hashref(
		'SELECT * FROM memos WHERE access_key = ?',
		undef,
		$key,
	);

	unless ($memo) {
		return $c->res_404;
	}

	return $c->render('memo.tx', +{
		body => $memo->{body},
		created_at => DateTime->from_epoch(time_zone => 'local', epoch => $memo->{created_at})->strftime('%Y/%m/%d %H:%M'),
	});
};

# delete memo
any ['delete'] => '/memos/:key' => sub {
	my ($c, $args) = @_;
	my $key = $args->{key};
	unless ($key) {
		return $c->res_404;
	}
	my $memo = $c->dbh->selectrow_hashref(
		'SELECT access_key FROM memos WHERE access_key = ?',
		undef,
		$key,
	);
	unless ($memo) {
		return $c->res_404;
	}
	my $rows_deleted = $c->dbh->do(q{
		DELETE FROM memos
		WHERE access_key = ?
	}, undef, $key);
	return $c->redirect('/');
};

sub _initialize_database {
	my ($database_filename) = @_;
	my $init_sql_file = config->{initialization_sql_filename};
	system("sqlite3 $database_filename < $init_sql_file");
	if ($? != 0) {
		die "SQLite initialization error ($!)";
	}
}


# for your security
__PACKAGE__->add_trigger(
	AFTER_DISPATCH => sub {
		my ( $c, $res ) = @_;
		$res->header( 'X-Content-Type-Options' => 'nosniff' );
	},
);

builder {
	enable 'Plack::Middleware::Static',
		path => qr{^(?:/static/|/robot\.txt$|/favicon.ico$)},
		root => File::Spec->catdir(dirname(__FILE__));
	enable 'Plack::Middleware::ReverseProxy';

	__PACKAGE__->to_app();
};

__DATA__

@@ form.tx
: cascade layout
: around body -> {
<h3>New memo</h3>

:	if $errors {
		<ul>
:			for $errors -> $e {
				<li><:= $e :></li>
:			}
		</ul>
: 	}

<form method="post" action="/create">
  <p><textarea name="body" cols="95" rows="25"></textarea></p>
  <p><input type="submit" name="submit" value="Create"></p>
</form>
: }

@@ memo.tx
: cascade layout
: around body -> {

<p><textarea style="background:#eee;" readonly cols="95" rows="25"><:= $body :></textarea></p>
<p>Time: <:= $created_at :></p>

<a href="<:= uri_for('/') :>">Back</a>
: }

@@ layout.tx
<!doctype html>
<html>
<head>
  <meta http-equiv="content-type" content="text/html;charset=UTF-8" />
  <title>Pastel!</title>
  <link rel="shortcut icon" type="image/ico" href="/static/favicon.ico" />
  <link rel="stylesheet" type="text/css" href="/static/stylesheets/scaffold.css">
  <link rel="stylesheet" type="text/css" href="/static/stylesheets/main.css">
</head>
<body>
  <h1><a href="<:= uri_for('/') :>">Pastel!</a></h1>
  <h2>Paste, Record, Share.</h2>

: block body -> {}

<hr noshade="noshade" />
<p id="footer">Powered by bobpp</p>

</body>
</html>

