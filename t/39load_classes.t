#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use lib qw(t/lib);
use DBICTest; # do not remove even though it is not used

plan tests => 4;

my $warnings;
eval {
    local $SIG{__WARN__} = sub { $warnings .= shift };
    package DBICNSTest;
    use base qw/DBIx::Class::Schema/;
    __PACKAGE__->load_classes(qw/
        S
    /);
};
ok(!$@) or diag $@;

my $source_s = DBICNSTest->source('S');
isa_ok($source_s, 'DBIx::Class::ResultSource::Table');
my $rset_s   = DBICNSTest->resultset('S');
isa_ok($rset_s, 'DBICNSTest::Result::A');

my $row = $rset_s->new({});

ok($row->can('submethod'), 'method defined in rs subclass');
