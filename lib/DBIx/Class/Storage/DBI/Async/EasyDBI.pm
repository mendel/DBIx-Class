package DBIx::Class::Storage::DBI::Async::EasyDBI;

# stolen from Replicated
BEGIN {
  use Carp::Clan qw/^DBIx::Class/;

  ## Modules required for EasyDBI support not required for general DBIC
  ## use, so we explicitly test for these.

  my %easydbi_required = (
    'POE::Component::EasyDBI' => '1.23',
    'POE::Session::YieldCC'   => '0.201',
    'Moose'                   => '0.88',
    'namespace::autoclean'    => '0.05',
  );

  my @didnt_load;

  for my $module (keys %easydbi_required) {
    eval "require $module; ${module}->VERSION($easydbi_required{$module})";
    push @didnt_load, "$module $easydbi_required{$module}"
      if $@;
  }

  croak
"@{[ join ', ', @didnt_load ]} are missing and are required for Async::EasyDBI"
    if @didnt_load;
}

use POE 'Component::EasyDBI';
use namespace::autoclean;
use Moose;
use mro 'c3';
extends 'DBIx::Class::Storage::DBI';

my $EASY_DBI = '__dbic_easydbi'; # session alias

# here we set up the session
sub connect_info {
  my $self = shift;

  $self->next::method(@_);

  my ($dsn, $user, $pass, $opts) = @{ $self->_dbi_connect_info };

  POE::Component::EasyDBI->spawn(
    alias    => $EASY_DBI,
    dsn      => $dsn,
    username => $user,
    password => $pass,
    options  => $opts,
  );
}

has _dbh => (
  is => 'ro',
  isa => 'DBIx::Class::Storage::DBI::Async::EasyDBI::FakeDBH',
  default => sub {
    DBIx::Class::Storage::DBI::Async::EasyDBI::FakeDBH->new(
      storage => shift
    )
  },
);

sub dbh { shift->_dbh }

# we never connect to anything ourselves
sub _populate_dbh {}
sub connected { 1 }

sub DESTROY {
  my $self = shift;

  return unless blessed $self;

  $self->next::method;

# may be in global destruction, in which case just ignore
  eval { POE::Kernel->post($EASY_DBI => 'shutdown') };
}

1;
# vim:sts=2 sw=2:
