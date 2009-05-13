package DBICNSTest::S;
use base qw/DBICNSTest::Result::A/;

sub submethod {
    return 'this is a new method in this subclass';
}

1;
