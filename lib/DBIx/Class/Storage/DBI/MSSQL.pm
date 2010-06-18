package DBIx::Class::Storage::DBI::MSSQL;

use strict;
use warnings;

use base qw/DBIx::Class::Storage::DBI::AmbiguousGlob DBIx::Class::Storage::DBI/;
use mro 'c3';

use List::Util();

__PACKAGE__->mk_group_accessors(simple => qw/
  _identity _identity_method
/);

__PACKAGE__->sql_maker_class('DBIx::Class::SQLAHacks::MSSQL');

sub insert_bulk {
  my $self = shift;
  my ($source, $cols, $data) = @_;

  my $identity_insert = 0;

  COLUMNS:
  foreach my $col (@{$cols}) {
    if ($source->column_info($col)->{is_auto_increment}) {
      $identity_insert = 1;
      last COLUMNS;
    }
  }

  if ($identity_insert) {
    my $table = $source->from;
    $self->_get_dbh->do("SET IDENTITY_INSERT $table ON");
  }

  $self->next::method(@_);

  if ($identity_insert) {
    my $table = $source->from;
    $self->_get_dbh->do("SET IDENTITY_INSERT $table OFF");
  }
}

# support MSSQL GUID column types

sub insert {
  my $self = shift;
  my ($source, $to_insert) = @_;

  my $updated_cols = {};

  my %guid_cols;
  my @pk_cols = $source->primary_columns;
  my %pk_cols;
  @pk_cols{@pk_cols} = ();

  my @pk_guids = grep {
    $source->column_info($_)->{data_type}
    &&
    $source->column_info($_)->{data_type} =~ /^uniqueidentifier/i
  } @pk_cols;

  my @auto_guids = grep {
    $source->column_info($_)->{data_type}
    &&
    $source->column_info($_)->{data_type} =~ /^uniqueidentifier/i
    &&
    $source->column_info($_)->{auto_nextval}
  } grep { not exists $pk_cols{$_} } $source->columns;

  my @get_guids_for =
    grep { not exists $to_insert->{$_} } (@pk_guids, @auto_guids);

  for my $guid_col (@get_guids_for) {
    my ($new_guid) = $self->_get_dbh->selectrow_array('SELECT NEWID()');
    $updated_cols->{$guid_col} = $to_insert->{$guid_col} = $new_guid;
  }

  $updated_cols = { %$updated_cols, %{ $self->next::method(@_) } };

  return $updated_cols;
}

sub _prep_for_execute {
  my $self = shift;
  my ($op, $extra_bind, $ident, $args) = @_;

# cast MONEY values properly
  if ($op eq 'insert' || $op eq 'update') {
    my $fields = $args->[0];

    for my $col (keys %$fields) {
      # $ident is a result source object with INSERT/UPDATE ops
      if ($ident->column_info ($col)->{data_type}
         &&
         $ident->column_info ($col)->{data_type} =~ /^money\z/i) {
        my $val = $fields->{$col};
        $fields->{$col} = \['CAST(? AS MONEY)', [ $col => $val ]];
      }
    }
  }

  my ($sql, $bind) = $self->next::method (@_);

  if ($op eq 'insert') {
    $sql .= ';SELECT SCOPE_IDENTITY()';

    my $col_info = $self->_resolve_column_info($ident, [map $_->[0], @{$bind}]);
    if (List::Util::first { $_->{is_auto_increment} } (values %$col_info) ) {

      my $table = $ident->from;
      my $identity_insert_on = "SET IDENTITY_INSERT $table ON";
      my $identity_insert_off = "SET IDENTITY_INSERT $table OFF";
      $sql = "$identity_insert_on; $sql; $identity_insert_off";
    }
  }

  return ($sql, $bind);
}

sub _execute {
  my $self = shift;
  my ($op) = @_;

  my ($rv, $sth, @bind) = $self->dbh_do($self->can('_dbh_execute'), @_);

  if ($op eq 'insert') {

    # this should bring back the result of SELECT SCOPE_IDENTITY() we tacked
    # on in _prep_for_execute above
    my ($identity) = $sth->fetchrow_array;

    # SCOPE_IDENTITY failed, but we can do something else
    if ( (! $identity) && $self->_identity_method) {
      ($identity) = $self->_dbh->selectrow_array(
        'select ' . $self->_identity_method
      );
    }

    $self->_identity($identity);
    $sth->finish;
  }

  return wantarray ? ($rv, $sth, @bind) : $rv;
}

sub last_insert_id { shift->_identity }

# savepoint syntax is the same as in Sybase ASE

sub _svp_begin {
  my ($self, $name) = @_;

  $self->_get_dbh->do("SAVE TRANSACTION $name");
}

# A new SAVE TRANSACTION with the same name releases the previous one.
sub _svp_release { 1 }

sub _svp_rollback {
  my ($self, $name) = @_;

  $self->_get_dbh->do("ROLLBACK TRANSACTION $name");
}

sub build_datetime_parser {
  my $self = shift;
  my $type = "DateTime::Format::Strptime";
  eval "use ${type}";
  $self->throw_exception("Couldn't load ${type}: $@") if $@;
  return $type->new( pattern => '%Y-%m-%d %H:%M:%S' );  # %F %T
}

sub sqlt_type { 'SQLServer' }

sub _sql_maker_opts {
  my ( $self, $opts ) = @_;

  if ( $opts ) {
    $self->{_sql_maker_opts} = { %$opts };
  }

  return { limit_dialect => 'Top', %{$self->{_sql_maker_opts}||{}} };
}

1;

=head1 NAME

DBIx::Class::Storage::DBI::MSSQL - Base Class for Microsoft SQL Server support
in DBIx::Class

=head1 SYNOPSIS

This is the base class for Microsoft SQL Server support, used by
L<DBIx::Class::Storage::DBI::ODBC::Microsoft_SQL_Server> and
L<DBIx::Class::Storage::DBI::Sybase::Microsoft_SQL_Server>.

=head1 IMPLEMENTATION NOTES

=head2 IDENTITY information

Microsoft SQL Server supports three methods of retrieving the IDENTITY
value for inserted row: IDENT_CURRENT, @@IDENTITY, and SCOPE_IDENTITY().
SCOPE_IDENTITY is used here because it is the safest.  However, it must
be called is the same execute statement, not just the same connection.

So, this implementation appends a SELECT SCOPE_IDENTITY() statement
onto each INSERT to accommodate that requirement.

C<SELECT @@IDENTITY> can also be used by issuing:

  $self->_identity_method('@@identity');

it will only be used if SCOPE_IDENTITY() fails.

This is more dangerous, as inserting into a table with an on insert trigger that
inserts into another table with an identity will give erroneous results on
recent versions of SQL Server.

=head2 bulk_insert

Be aware that we have tried to make things as simple as possible for our users.
For MSSQL that means that when a user tries to do a populate/bulk_insert which
includes an autoincrementing column, we will try to tell the database to allow
the insertion of the autoinc column.  But the user must have the db_ddladmin
role membership, otherwise you will get a fairly opaque error message.

=head1 AUTHOR

See L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
