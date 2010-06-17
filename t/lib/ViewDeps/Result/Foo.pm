package    # hide from PAUSE
    ViewDeps::Result::Foo;

use strict;
use warnings;
use parent qw(DBIx::Class::Core);
use aliased 'DBIx::Class::ResultSource::View';

__PACKAGE__->table_class(View);
__PACKAGE__->table('foo');
__PACKAGE__->add_columns(
    id => { data_type => 'integer', is_auto_increment => 1 },
    a  => { data_type => 'integer', is_nullable       => 1 }
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to( 'bar', 'ViewDeps::Result::Bar',
    { 'foreign.id' => 'self.a' } );

1;
