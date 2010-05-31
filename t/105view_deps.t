#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use lib qw(t/lib);
use ViewDeps;

BEGIN {
    use_ok('DBIx::Class::ResultSource::View');
}

### SANITY

my $view = DBIx::Class::ResultSource::View->new( { name => 'Quux' } );

isa_ok( $view, 'DBIx::Class::ResultSource', 'A new view' );
isa_ok( $view, 'DBIx::Class', 'A new view also' );

can_ok( $view, $_ ) for qw/new from deploy_depends_on/;

### DEPS

my $schema = ViewDeps->connect;
ok( $schema, 'Connected to ViewDeps schema OK' );


my $bar_rs = $schema->resultset('Bar');

my @bar_deps
    = keys %{ $schema->resultset('Bar')->result_source->deploy_depends_on };

my @foo_deps
    = keys %{ $schema->resultset('Foo')->result_source->deploy_depends_on };

isa_ok( $schema->resultset('Bar')->result_source,
    'DBIx::Class::ResultSource::View', 'Bar' );

is( $bar_deps[0], 'baz',   'which is reported to depend on baz...' );
is( $bar_deps[1], 'mixin', 'and on mixin.' );
is( $foo_deps[0], undef,   'Foo has no declared dependencies...' );



isa_ok(
    $schema->resultset('Foo')->result_source,
    'DBIx::Class::ResultSource::View',
    'though Foo'
);
isa_ok(
    $schema->resultset('Baz')->result_source,
    'DBIx::Class::ResultSource::Table',
    "Baz on the other hand"
);
dies_ok {
    ViewDeps::Result::Baz->result_source_instance
        ->deploy_depends_on("ViewDeps::Result::Mixin");
}
"...and you cannot use deploy_depends_on with that";

is(ViewDeps->source('Foo')->view_definition, $schema->resultset('Bar')->result_source->view_definition, "Package Foo's view definition is equivalent to resultset Bar's view definition");

my $dir = "t/sql";
$schema->create_ddl_dir( ['PostgreSQL','SQLite'], 0.1, $dir );

done_testing;