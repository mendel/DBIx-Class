use strict;
use warnings;

use Test::More;
use Test::Exception;
use lib qw(t/lib);

{
  throws_ok {
    eval <<'END' or die $@;
      package # hide from PAUSE
        DBICTest::Schema::UniqueConstraintWarningTest;

      use base qw/DBIx::Class::Core/;

      __PACKAGE__->table('dummy');

      __PACKAGE__->add_column(qw/ foo bar /);

      __PACKAGE__->add_unique_constraint(
        constraint1 => [qw/ foo /],
        constraint2 => [qw/ bar /],
      );

      1;
END
  } qr/"add_unique_constraint" does not work with multiple constraints, see "add_unique_constraints" instead/,
    'add_unique_constraint throws when more than one constraint specified';
}

done_testing;
