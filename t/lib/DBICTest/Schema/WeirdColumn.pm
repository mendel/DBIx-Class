package # hide from PAUSE 
    DBICTest::Schema::WeirdColumn;

use strict;
use warnings;
use base qw/DBICTest::BaseResult/;

__PACKAGE__->table('weird_column');

__PACKAGE__->add_columns(
  "id" => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  "foo ' bar" => {
    data_type => 'varchar',
    size      => 100,
    accessor  => 'foo_bar',
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key('id');

1;
