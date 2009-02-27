{
  package    # hide from PAUSE
    DBICTest::Schema::ArtistFQN;

  use base 'DBIx::Class::Core';

  __PACKAGE__->table(
      defined $ENV{DBICTEST_ORA_USER}
      ? $ENV{DBICTEST_ORA_USER} . '.artist'
      : 'artist'
  );
  __PACKAGE__->add_columns(
      'artistid' => {
          data_type         => 'integer',
          is_auto_increment => 1,
      },
      'name' => {
          data_type   => 'varchar',
          size        => 100,
          is_nullable => 1,
      },
  );
  __PACKAGE__->set_primary_key('artistid');

  1;
}

use strict;
use warnings;  

use Test::More;
use lib qw(t/lib);
use DBICTest;

my ($dsn, $user, $pass) = @ENV{map { "DBICTEST_ORA_${_}" } qw/DSN USER PASS/};

plan skip_all => 'Set $ENV{DBICTEST_ORA_DSN}, _USER and _PASS to run this test. ' .
  'Warning: This test drops and creates tables called \'artist\', \'cd\', \'track\' and \'sequence_test\''.
  ' as well as following sequences: \'pkid1_seq\', \'pkid2_seq\' and \'nonpkid_seq\''
  unless ($dsn && $user && $pass);

plan tests => 34;

DBICTest::Schema->load_classes('ArtistFQN');
my $schema = DBICTest::Schema->connect($dsn, $user, $pass);

my $dbh = $schema->storage->dbh;

eval {
  $dbh->do("DROP SEQUENCE artist_seq");
  $dbh->do("DROP SEQUENCE pkid1_seq");
  $dbh->do("DROP SEQUENCE pkid2_seq");
  $dbh->do("DROP SEQUENCE nonpkid_seq");
  $dbh->do("DROP TABLE artist");
  $dbh->do("DROP TABLE sequence_test");
  $dbh->do("DROP TABLE cd");
  $dbh->do("DROP TABLE track");
};
$dbh->do("CREATE SEQUENCE artist_seq START WITH 1 MAXVALUE 999999 MINVALUE 0");
$dbh->do("CREATE SEQUENCE pkid1_seq START WITH 1 MAXVALUE 999999 MINVALUE 0");
$dbh->do("CREATE SEQUENCE pkid2_seq START WITH 10 MAXVALUE 999999 MINVALUE 0");
$dbh->do("CREATE SEQUENCE nonpkid_seq START WITH 20 MAXVALUE 999999 MINVALUE 0");

$dbh->do("CREATE TABLE artist (artistid NUMBER(12), name VARCHAR(255), parentid NUMBER(12), rank NUMBER(38), charfield VARCHAR2(10))");
$schema->class('Artist')->add_columns('parentid');

$dbh->do("CREATE TABLE sequence_test (pkid1 NUMBER(12), pkid2 NUMBER(12), nonpkid NUMBER(12), name VARCHAR(255))");
$dbh->do("CREATE TABLE cd (cdid NUMBER(12), artist NUMBER(12), title VARCHAR(255), year VARCHAR(4))");
$dbh->do("CREATE TABLE track (trackid NUMBER(12), cd NUMBER(12), position NUMBER(12), title VARCHAR(255), last_updated_on DATE)");

$dbh->do("ALTER TABLE artist ADD (CONSTRAINT artist_pk PRIMARY KEY (artistid))");
$dbh->do("ALTER TABLE sequence_test ADD (CONSTRAINT sequence_test_constraint PRIMARY KEY (pkid1, pkid2))");
$dbh->do(qq{
  CREATE OR REPLACE TRIGGER artist_insert_trg
  BEFORE INSERT ON artist
  FOR EACH ROW
  BEGIN
    IF :new.artistid IS NULL THEN
      SELECT artist_seq.nextval
      INTO :new.artistid
      FROM DUAL;
    END IF;
  END;
});

# This is in Core now, but it's here just to test that it doesn't break
$schema->class('Artist')->load_components('PK::Auto');
# These are compat shims for PK::Auto...
$schema->class('CD')->load_components('PK::Auto::Oracle');
$schema->class('Track')->load_components('PK::Auto::Oracle');

# test primary key handling
my $new = $schema->resultset('Artist')->create({ name => 'foo' });
is($new->artistid, 1, "Oracle Auto-PK worked");

# test again with fully-qualified table name
$new = $schema->resultset('ArtistFQN')->create( { name => 'bar' } );
is( $new->artistid, 2, "Oracle Auto-PK worked with fully-qualified tablename" );

# test join with row count ambiguity
my $cd = $schema->resultset('CD')->create({ cdid => 1, artist => 1, title => 'EP C', year => '2003' });
my $track = $schema->resultset('Track')->create({ trackid => 1, cd => 1, position => 1, title => 'Track1' });
my $tjoin = $schema->resultset('Track')->search({ 'me.title' => 'Track1'},
        { join => 'cd',
          rows => 2 }
);

is($tjoin->next->title, 'Track1', "ambiguous column ok");

# check count distinct with multiple columns
my $other_track = $schema->resultset('Track')->create({ trackid => 2, cd => 1, position => 1, title => 'Track2' });
my $tcount = $schema->resultset('Track')->search(
    {},
    {
        select => [{count => {distinct => ['position', 'title']}}],
        as => ['count']
    }
  );

is($tcount->next->get_column('count'), 2, "multiple column select distinct ok");

# test LIMIT support
for (1..6) {
    $schema->resultset('Artist')->create({ name => 'Artist ' . $_ });
}
my $it = $schema->resultset('Artist')->search( {},
    { rows => 3,
      offset => 3,
      order_by => 'artistid' }
);
is( $it->count, 3, "LIMIT count ok" );
is( $it->next->name, "Artist 2", "iterator->next ok" );
$it->next;
$it->next;
is( $it->next, undef, "next past end of resultset ok" );

{
  my $rs = $schema->resultset('Track')->search( undef, { columns=>[qw/trackid position/], group_by=> [ qw/trackid position/ ] , rows => 2, offset=>1 });
  my @results = $rs->all;
  is( scalar @results, 1, "Group by with limit OK" );
}

# test auto increment using sequences WITHOUT triggers
for (1..5) {
    my $st = $schema->resultset('SequenceTest')->create({ name => 'foo' });
    is($st->pkid1, $_, "Oracle Auto-PK without trigger: First primary key");
    is($st->pkid2, $_ + 9, "Oracle Auto-PK without trigger: Second primary key");
    is($st->nonpkid, $_ + 19, "Oracle Auto-PK without trigger: Non-primary key");
}
my $st = $schema->resultset('SequenceTest')->create({ name => 'foo', pkid1 => 55 });
is($st->pkid1, 55, "Oracle Auto-PK without trigger: First primary key set manually");

# create a tree of artists
my $afoo_id = $schema->resultset('Artist')->create({ name => 'afoo', parentid => 1 })->id;
$schema->resultset('Artist')->create({ name => 'bfoo', parentid => 1 });
my $cfoo_id = $schema->resultset('Artist')->create({ name => 'cfoo', parentid => $afoo_id })->id;
$schema->resultset('Artist')->create({ name => 'dfoo', parentid => $cfoo_id });
my $xfoo_id = $schema->resultset('Artist')->create({ name => 'xfoo' })->id;

# create some cds and tracks
$schema->resultset('CD')->create({ cdid => 2, artist => $cfoo_id, title => "cfoo's cd", year => '2008' });
$schema->resultset('Track')->create({ trackid => 2, cd => 2, position => 1, title => 'Track1 cfoo' });
$schema->resultset('CD')->create({ cdid => 3, artist => $xfoo_id, title => "xfoo's cd", year => '2008' });
$schema->resultset('Track')->create({ trackid => 3, cd => 3, position => 1, title => 'Track1 xfoo' });

{
  my $rs = $schema->resultset('Artist')->search({}, # get the whole tree
                          {
                            'start_with' => { 'name' => 'foo' },
                            'connect_by' => { 'parentid' => 'prior artistid'},
                          });
  is( $rs->count, 5, 'Connect By count ok' );
  my $ok = 1;
  foreach my $node_name (qw(foo afoo cfoo dfoo bfoo)) {
    $ok = 0 if $rs->next->name ne $node_name;
  }
  ok( $ok, 'got artist tree');
}

{
  # use order siblings by statement
  my $rs = $schema->resultset('Artist')->search({},
                          {
                            'start_with' => { 'name' => 'foo' },
                            'connect_by' => { 'parentid' => 'prior artistid'},
                            'order_siblings_by' => 'name DESC',
                          });
  my $ok = 1;
  foreach my $node_name (qw(foo bfoo afoo cfoo dfoo)) {
    $ok = 0 if $rs->next->name ne $node_name;
  }
  ok( $ok, 'Order Siblings By ok');
}

{
  # get the root node
  my $rs = $schema->resultset('Artist')->search({ parentid => undef },
                          {
                            'start_with' => { 'name' => 'dfoo' },
                            'connect_by' => { 'prior parentid' => 'artistid'},
                          });
  is( $rs->count, 1, 'root node count ok' );
  ok( $rs->next->name eq 'foo', 'found root node');
}

{
  # combine a connect by with a join
  my $rs = $schema->resultset('Artist')->search({'cds.title' => { 'like' => '%cd'}},
                          {
                            'join' => 'cds',
                            'start_with' => { 'name' => 'foo' },
                            'connect_by' => { 'parentid' => 'prior artistid'},
                          });
  is( $rs->count, 1, 'Connect By with a join; count ok' );
  ok( $rs->next->name eq 'cfoo', 'Connect By with a join; result name ok')
}

{
  # combine a connect by with order_by
  my $rs = $schema->resultset('Artist')->search({},
                          {
                            'start_with' => { 'name' => 'dfoo' },
                            'connect_by' => { 'prior parentid' => 'artistid'},
                            'order_by' => 'name ASC',
                          });
  my $ok = 1;
  foreach my $node_name (qw(afoo cfoo dfoo foo)) {
    $ok = 0 if $rs->next->name ne $node_name;
  }
  ok( $ok, 'Connect By with a order_by; result name ok');
}

{
  # limit a connect by
  my $rs = $schema->resultset('Artist')->search({},
                          {
                            'start_with' => { 'name' => 'dfoo' },
                            'connect_by' => { 'prior parentid' => 'artistid'},
                            'order_by' => 'name ASC',
                            'rows' => 2,
                            'page' => 1,
                          });
  is( $rs->count(), 2, 'Connect By; LIMIT count ok' );
  my $ok = 1;
  foreach my $node_name (qw(afoo cfoo)) {
    $ok = 0 if $rs->next->name ne $node_name;
  }
  ok( $ok, 'LIMIT a Connect By query ok');
}

# clean up our mess
END {
    if($schema && ($dbh = $schema->storage->dbh)) {
        $dbh->do("DROP SEQUENCE artist_seq");
        $dbh->do("DROP SEQUENCE pkid1_seq");
        $dbh->do("DROP SEQUENCE pkid2_seq");
        $dbh->do("DROP SEQUENCE nonpkid_seq");
        $dbh->do("DROP TABLE artist");
        $dbh->do("DROP TABLE sequence_test");
        $dbh->do("DROP TABLE cd");
        $dbh->do("DROP TABLE track");
    }
}

