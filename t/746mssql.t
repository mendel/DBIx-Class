use strict;
use warnings;

use Test::More;
use Test::Exception;
use lib qw(t/lib);
use DBICTest;
use DBIC::SqlMakerTest;

my ($dsn, $user, $pass) = @ENV{map { "DBICTEST_MSSQL_ODBC_${_}" } qw/DSN USER PASS/};

plan skip_all => 'Set $ENV{DBICTEST_MSSQL_ODBC_DSN}, _USER and _PASS to run this test'
  unless ($dsn && $user);

lives_ok ( sub {
  # start a new connection, make sure rebless works
  my $schema = DBICTest::Schema->connect($dsn, $user, $pass);
  $schema->populate ('Owners', [
    [qw/id  name  /],
    [qw/1   wiggle/],
    [qw/2   woggle/],
    [qw/3   boggle/],
    [qw/4   fREW/],
    [qw/5   fRIOUX/],
    [qw/6   fROOH/],
    [qw/7   fRUE/],
    [qw/8   fISMBoC/],
    [qw/9   station/],
    [qw/10   mirror/],
    [qw/11   dimly/],
    [qw/12   face_to_face/],
    [qw/13   icarus/],
    [qw/14   dream/],
    [qw/15   dyrstyggyr/],
  ]);
}, 'populate with PKs supplied ok' );

done_testing;
