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

my $schema = DBICTest::Schema->connect($dsn, $user, $pass);

$schema->storage->ensure_connected;
isa_ok( $schema->storage, 'DBIx::Class::Storage::DBI::ODBC::Microsoft_SQL_Server' );

$schema->storage->dbh_do (sub {
    my ($storage, $dbh) = @_;
    eval { $dbh->do("DROP TABLE Owners") };
    eval { $dbh->do("DROP TABLE Books") };
    $dbh->do(<<'SQL');
CREATE TABLE Books (
   id INT IDENTITY (1, 1) NOT NULL,
   source VARCHAR(100),
   owner INT,
   title VARCHAR(10),
   price INT NULL
)

CREATE TABLE Owners (
   id INT IDENTITY (1, 1) NOT NULL,
   name VARCHAR(100),
)
SQL

});

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

lives_ok ( sub {
  # start a new connection, make sure rebless works
  my $schema = DBICTest::Schema->connect($dsn, $user, $pass);
  $schema->populate ('BooksInLibrary', [
    [qw/source  owner title   /],
    [qw/Library 1     secrets0/],
    [qw/Library 1     secrets1/],
    [qw/Eatery  1     secrets2/],
    [qw/Library 2     secrets3/],
    [qw/Library 3     secrets4/],
    [qw/Eatery  3     secrets5/],
    [qw/Library 4     secrets6/],
    [qw/Library 5     secrets7/],
    [qw/Eatery  5     secrets8/],
    [qw/Library 6     secrets9/],
    [qw/Library 7     secrets10/],
    [qw/Eatery  7     secrets11/],
    [qw/Library 8     secrets12/],
  ]);
}, 'populate without PKs supplied ok' );

done_testing;
