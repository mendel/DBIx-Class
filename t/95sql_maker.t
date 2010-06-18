use strict;
use warnings;

use Test::More;
use Test::Exception;

use lib qw(t/lib);
use DBIC::SqlMakerTest;

plan tests => 4;

use_ok('DBICTest');

my $schema = DBICTest->init_schema();

my $sql_maker = $schema->storage->sql_maker;


{
  my ($sql, @bind) = $sql_maker->insert(
            'lottery',
            {
              'day' => '2008-11-16',
              'numbers' => [13, 21, 34, 55, 89]
            }
  );

  is_same_sql_bind(
    $sql, \@bind,
    q/INSERT INTO lottery (day, numbers) VALUES (?, ?)/,
      [ ['day' => '2008-11-16'], ['numbers' => [13, 21, 34, 55, 89]] ],
    'sql_maker passes arrayrefs in insert'
  );


  ($sql, @bind) = $sql_maker->update(
            'lottery',
            {
              'day' => '2008-11-16',
              'numbers' => [13, 21, 34, 55, 89]
            }
  );

  is_same_sql_bind(
    $sql, \@bind,
    q/UPDATE lottery SET day = ?, numbers = ?/,
      [ ['day' => '2008-11-16'], ['numbers' => [13, 21, 34, 55, 89]] ],
    'sql_maker passes arrayrefs in update'
  );
}

# Make sure the carp/croak override in SQLA works (via SQLAHacks)
my $file = __FILE__;
$file = "\Q$file\E";
throws_ok (sub {
  $schema->resultset ('Artist')->search ({}, { order_by => { -asc => 'stuff', -desc => 'staff' } } )->as_query;
}, qr/$file/, 'Exception correctly croak()ed');
