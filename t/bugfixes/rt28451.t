#!/usr/bin/perl -w

use strict;
use warnings;  

use Test::More;
use lib qw(t/lib);
use DBICTest;

my $schema = DBICTest->init_schema(
    no_populate => 1,
);
$schema->storage()->debug( 1 );

$schema->populate('DBICTest::Schema::28451::Account', [
    [ qw/account_id username person_id/ ],
    [ 1, 'barney', 3 ],
    [ 2, 'fred', 1 ],
]);

$schema->populate('DBICTest::Schema::28451::Group', [
    [ qw/account_id username person_id/ ],
    [ 1, 'foo', 1 ],
    [ 2, 'bar', 2 ],
    [ 3, 'baz', undef ],
]);

$schema->populate('DBICTest::Schema::28451::Peron', [
    [ qw/account_id username person_id/ ],
    [ 1, 'Fred', 1 ],
    [ 2, 'Wilma', 1 ],
    [ 3, 'Barney', 2 ],
]);

plan tests => 1;

my $rs = $schema->resultset('Group')->search(
    undef,
    {
        '+select' => [ { COUNT => 'members.person_id' } ],
        '+as'     => [ qw/ member_count / ],
        join      => [ 'members' ],
        group_by  => [ qw/ me.group_id / ],
    },
);
warn ${$rs->as_query}->[0], $/;

$rs = $rs->search(
    undef,
    {
        prefetch  => { account => 'person' },
    },
);
warn ${$rs->as_query}->[0], $/;

foreach ( $rs->all() ) {
     print "name:    " . $_->name() . "\n";
     print "owner:   " . $_->account()->person()->first_name() . "\n";
     print "members: " . $_->member_count() . "\n";
     print "\n";
}
