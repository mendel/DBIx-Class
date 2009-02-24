package # hide from PAUSE 
    DBICTest::Schema::28451::Account;

use strict;
use warnings;

use base qw/DBIx::Class/;

__PACKAGE__->load_components( qw/ Core PK::Auto / );
__PACKAGE__->table( 'rt28451_accounts' );
__PACKAGE__->add_columns( qw/ account_id username person_id / );
__PACKAGE__->set_primary_key( qw/ account_id / );

__PACKAGE__->belongs_to( person => 'DBICTest::Schema::28451::Person', 'person_id' );
__PACKAGE__->has_many( administered_groups => 'DBICTest::Schema::28451::Group', 'account_id' );

1;
