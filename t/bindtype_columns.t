use strict;
use warnings;  
use lib qw(t/lib);

use Test::More;
use DBICTest;

my ($dsn, $dbuser, $dbpass) = @ENV{map { "DBICTEST_PG_${_}" } qw/DSN USER PASS/};

plan skip_all => 'Set $ENV{DBICTEST_PG_DSN}, _USER and _PASS to run this test'
  unless ($dsn && $dbuser);
  
plan tests => 8;

ok my $schema = DBICTest::Schema
	->connection($dsn, $dbuser, $dbpass, { AutoCommit => 1 }) => 'Good Schema';

ok my $dbh = $schema->storage->dbh => "got good database handle";

$dbh->do(qq[drop table artist])
 if $dbh->selectrow_array(qq[select count(*) from pg_class where relname = 'artist']);

$schema->storage->dbh->do(qq[

	CREATE TABLE artist
	(
		artistid		serial	NOT NULL	PRIMARY KEY,
		media			bytea	NOT NULL,
		name			varchar NULL
	);
	
],{ RaiseError => 1, PrintError => 1 });


$schema->class('Artist')->load_components(qw/ 

	PK::Auto 
	Core 
/);

$schema->class('Artist')->add_columns(
	
	"media", { 
	
		data_type => "bytea", 
		is_nullable => 0,
	},
);
# test primary key handling
my $big_long_string	= 'abcd' x 500000;
ok $schema->storage->bind_attribute_by_data_type('bytea') => 'got correct bindtype.';
my $new = $schema->resultset('Artist')->create({ media => $big_long_string });

ok($new->artistid, "Created a blob row");
is($new->media, 	$big_long_string, "Set the blob correctly.");

my $rs = $schema->resultset('Artist')->find({artistid=>$new->artistid});

is($rs->get_column('media'), $big_long_string, "Created the blob correctly.");

## Test bug where if we are calling a blob first, it fails

$schema->storage->disconnect;


CANT_BE_FIRST: {

	my $schema1 = DBICTest::Schema->connection($dsn, $dbuser, $dbpass, { AutoCommit => 1 });
	
	my $new = $schema->resultset('Artist')->create({media => $big_long_string });
	
	ok $schema->storage->bind_attribute_by_data_type('bytea') => 'got correct bindtype.';	

	my $rs = $schema1->resultset('Artist')->find({artistid=>$new->artistid});

	is($rs->get_column('media'), $big_long_string, "Created the blob correctly.");	
	
	$schema1->storage->dbh->do("DROP TABLE artist");
}




