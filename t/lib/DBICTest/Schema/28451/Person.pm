package # hide from PAUSE 
    DBICTest::Schema::28451::Person;

use strict;
use warnings;

use base qw/DBIx::Class/;

__PACKAGE__->load_components( qw/ Core PK::Auto / );
__PACKAGE__->table( '28451_people' );
__PACKAGE__->add_columns( qw/ person_id first_name group_id / );
__PACKAGE__->set_primary_key( qw/ person_id / );

__PACKAGE__->belongs_to( 'group', 'DBICTest::Schema::28451::Group', 'group_id' );

1;
