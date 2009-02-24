#!/usr/bin/perl -w

use strict;
use warnings;  

use Test::More;
use lib qw(t/lib);
use DBICTest;

my $schema = DBICTest->init_schema(
    no_populate => 1,
);

$schema->populate('28451::Account', [
    [ qw/account_id username person_id/ ],
    [ 1, 'barney', 3 ],
    [ 2, 'fred', 1 ],
]);

$schema->populate('28451::Group', [
    [ qw/group_id name account_id/ ],
    [ 1, 'foo', 1 ],
    [ 2, 'bar', 2 ],
#    [ 3, 'baz', undef ],
]);

$schema->populate('28451::Person', [
    [ qw/person_id first_name group_id/ ],
    [ 1, 'Fred', 1 ],
    [ 2, 'Wilma', 1 ],
    [ 3, 'Barney', 2 ],
]);

plan tests => 6;

my $rs = $schema->resultset('28451::Group')->search(
    undef,
    {
        '+select' => [ \'COUNT(members.person_id) AS member_count' ],
        '+as'     => [ qw/ member_count / ],
        join      => [ 'members' ],
        group_by  => [ qw/ me.group_id / ],
        order_by  => [ \'member_count DESC' ],
    },
);

$rs = $rs->search(
    undef,
    {
        prefetch  => { account => 'person' },
    },
);

my @rows = $rs->all;
is( $rows[0]->name, 'foo' );
is( $rows[0]->account->person->first_name, 'Barney' );
is( $rows[0]->member_count, '2' );
is( $rows[1]->name, 'bar' );
is( $rows[1]->account->person->first_name, 'Fred' );
is( $rows[1]->member_count, '1' );
