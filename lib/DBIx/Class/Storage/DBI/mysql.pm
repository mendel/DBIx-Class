package DBIx::Class::Storage::DBI::mysql;

use strict;
use warnings;
use Carp::Clan qw/^DBIx::Class/;
use version;

use base qw/DBIx::Class::Storage::DBI/;

# __PACKAGE__->load_components(qw/PK::Auto/);

=head1 NAME

DBIx::Class::Storage::DBI::mysql - Automatic primary key class for MySQL

=head1 SYNOPSIS

  # In your table classes
  __PACKAGE__->load_components(qw/PK::Auto Core/);
  __PACKAGE__->set_primary_key('id');

=head1 DESCRIPTION

This class implements autoincrements for MySQL.

=head1 METHODS

=head2 columns_info_for

Extends L<DBIx::Class::Storage::DBI/columns_info_for>.

=cut

sub columns_info_for {
  my ($self, $table) = @_;

  my $result;
  
  if ($self->dbh->can('column_info')) {
    my $old_raise_err = $self->dbh->{RaiseError};
    my $old_print_err = $self->dbh->{PrintError};
    $self->dbh->{RaiseError} = 1;
    $self->dbh->{PrintError} = 0;
    eval {
      my $sth = $self->dbh->column_info( undef, undef, $table, '%' );
      $sth->execute();
      while ( my $info = $sth->fetchrow_hashref() ){
        my %column_info;
        $column_info{data_type}     = $info->{TYPE_NAME};
        $column_info{size}          = $info->{COLUMN_SIZE};
        $column_info{is_nullable}   = $info->{NULLABLE} ? 1 : 0;
        $column_info{default_value} = $info->{COLUMN_DEF};

        my %info = $self->_extract_mysql_specs($info);
        $column_info{$_} = $info{$_} for keys %info;

        $result->{$info->{COLUMN_NAME}} = \%column_info;
      }
    };
    $self->dbh->{RaiseError} = $old_raise_err;
    $self->dbh->{PrintError} = $old_print_err;
    return {} if $@;
  }

  return $result;
}

sub _extract_mysql_specs {
  my ($self, $info) = @_;
  
  my $basetype   = lc($info->{TYPE_NAME});
  my $mysql_type = lc($info->{mysql_type_name});
  my %column_info;
  
  if ($basetype eq 'char') {
    if ($self->dbh->{mysql_serverinfo} < version->new('4.1')) {
      $column_info{length_in_bytes} = 1;
    }
    $column_info{ignore_trailing_spaces} = 1;
  }
  elsif ($basetype eq 'varchar') {
    if ($self->dbh->{mysql_serverinfo} <= version->new('4.1')) {
      $column_info{ignore_trailing_spaces} = 1;
    }
    if ($self->dbh->{mysql_serverinfo} < version->new('4.1')) {
      $column_info{length_in_bytes} = 1;
    }
  }
  elsif ($basetype =~ /text$/) {
    if ($basetype =~ /blob$/) {
      $column_info{length_in_bytes} = 1;
    }
    elsif ($self->dbh->{mysql_serverinfo} < version->new('4.1')) {
      $column_info{length_in_bytes} = 1;
    }
  }
  elsif ($basetype eq 'binary') {
    $column_info{ignore_trailing_spaces} = 1;
    $column_info{length_in_bytes}        = 1;
  }
  elsif ($basetype eq 'varbinary') {
    if ($self->dbh->{mysql_serverinfo} <= version->new('4.1')) {
      $column_info{ignore_trailing_spaces} = 1;
    }
    $column_info{length_in_bytes} = 1;
  }
  elsif ($basetype =~ /^(enum|set)/) {
    $column_info{data_set} = $info->{mysql_values};
  }
  elsif ($basetype =~ /int$/) {
    if ($mysql_type =~ /unsigned /) {
      my %max = (
        tinyint   => 2**8 - 1,
        smallint  => 2**16 - 1,
        mediumint => 2**24 - 1,
        int       => 2**32 - 1,
        bigint    => 2**64 - 1,
      );
      $column_info{is_unsigned} = 1;
      $column_info{range_min}   = 0;
      $column_info{range_max}   = $max{$basetype};
    }
    else { # not unsigned
      my %min = (
        tinyint   => - 2**7,
        smallint  => - 2**15,
        mediumint => - 2**23,
        int       => - 2**31,
        bigint    => - 2**63,
      );
      my %max = (
        tinyint   => 2**7 - 1,
        smallint  => 2**15 - 1,
        mediumint => 2**23 - 1,
        int       => 2**31 - 1,
        bigint    => 2**63 - 1,
      );
      $column_info{range_min} = $min{$basetype};
      $column_info{range_max} = $max{$basetype};
    }
  }
  elsif ($basetype =~ /^decimal/) {
    if ($self->dbh->{mysql_serverinfo} <= version->new('4.1')) {
      $column_info{decimal_high_positive} = 1;
    }
    if ($self->dbh->{mysql_serverinfo} < version->new('3.23')) {
      $column_info{decimal_literal_range} = 1;
    }
    $column_info{decimal_digits} = $info->{DECIMAL_DIGITS};
  }
    
  return %column_info;
}

sub last_insert_id {
  return $_[0]->_dbh->{mysql_insertid};
}

sub sqlt_type {
  return 'MySQL';
}

=head1 AUTHORS

Matt S. Trout <mst@shadowcatsystems.co.uk>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
