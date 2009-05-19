package DBICNSTest::S;
use base qw/DBICNSTest::Result::A/;

# init the resultsource instance and point it to the same table as the parent class
__PACKAGE__->table (__PACKAGE__->result_source_instance->name); 

sub submethod {
    return 'this is a new method in this subclass';
}

1;
