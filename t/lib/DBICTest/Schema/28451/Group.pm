package # hide from PAUSE 
    DBICTest::Schema::28451::Group;

use strict;
use warnings;

use base qw/DBIx::Class/;

__PACKAGE__->load_components( qw/ Core PK::Auto / );
__PACKAGE__->table( 'rt28451_groups' );
__PACKAGE__->add_columns( qw/ group_id name account_id / );
__PACKAGE__->set_primary_key( qw/ group_id / );

__PACKAGE__->mk_group_accessors( column => 'member_count' );

__PACKAGE__->belongs_to( account => 'DBICTest::Schema::28451::Account', 'account_id' );
#__PACKAGE__->has_many( person => 'DBICTest::Schema::28451::Person', 'group_id' );
__PACKAGE__->has_many( members => 'DBICTest::Schema::28451::Person', 'group_id' );

1;
