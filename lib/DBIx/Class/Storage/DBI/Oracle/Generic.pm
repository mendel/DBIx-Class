package DBIx::Class::Storage::DBI::Oracle::Generic;
# -*- mode: cperl; cperl-indent-level: 2 -*-

use strict;
use warnings;

=head1 NAME

DBIx::Class::Storage::DBI::Oracle::Generic - Automatic primary key class and
connect_by support for Oracle

=head1 SYNOPSIS

  # In your table classes
  __PACKAGE__->load_components(qw/PK::Auto Core/);
  __PACKAGE__->add_columns({ id => { sequence => 'mysequence', auto_nextval => 1 } });
  __PACKAGE__->set_primary_key('id');
  __PACKAGE__->sequence('mysequence');

  # with a resultset using a hierarchical relationship
  my $rs = $schema->resultset('Person')->search({},
                {
                  'start_with' => { 'firstname' => 'Foo', 'lastname' => 'Bar' },
                  'connect_by' => { 'parentid' => 'prior persionid'},
                  'order_siblings_by' => 'firstname ASC',
                };
  );

=head1 DESCRIPTION

This class implements autoincrements for Oracle and adds support for Oracle
specific hierarchical queries.

=head1 METHODS

=head1 ATTRIBUTES

Following additional attributes can be used in resultsets.

=head2 connect_by

=over 4

=item Value: \%connect_by

=back

A hashref of conditions used to specify the relationship between parent rows
and child rows of the hierarchy.

  connect_by => { parentid => 'prior personid' }

=head2 start_with

=over 4

=item Value: \%condition

=back

A hashref of conditions which specify the root row(s) of the hierarchy.

It uses the same syntax as L<DBIx::Class::ResultSet/search>

  start_with => { firstname => 'Foo', lastname => 'Bar' }

=head2 order_siblings_by

=over 4

=item Value: ($order_siblings_by | \@order_siblings_by)

=back

Which column(s) to order the siblings by.

It uses the same syntax as L<DBIx::Class::ResultSet/order_by>

  'order_siblings_by' => 'firstname ASC'

=cut

use Carp::Clan qw/^DBIx::Class/;

use base qw/DBIx::Class::Storage::DBI::MultiDistinctEmulation/;

# __PACKAGE__->load_components(qw/PK::Auto/);

{
  package 
    DBIC::SQL::Abstract::Oracle;

  use base qw( DBIC::SQL::Abstract );

  sub select {
    my ($self, $table, $fields, $where, $order, @rest) = @_;

    $self->{_db_specific_attrs} = pop @rest;

    my ($sql, @bind) = $self->SUPER::select($table, $fields, $where, $order, @rest);
    push @bind, @{$self->{_oracle_connect_by_binds}};

    return wantarray ? ($sql, @bind) : $sql;
  }

  sub _emulate_limit {
    my ( $self, $syntax, $sql, $order, $rows, $offset ) = @_;

    my ($cb_sql, @cb_bind) = $self->_connect_by();
    $sql .= $cb_sql;
    $self->{_oracle_connect_by_binds} = \@cb_bind;

    return $self->SUPER::_emulate_limit($syntax, $sql, $order, $rows, $offset);
  }

  sub _connect_by {
    my ($self) = @_;
    my $attrs = $self->{_db_specific_attrs};
    my $sql = '';
    my @bind;

    if ( ref($attrs) eq 'HASH' ) {
      if ( $attrs->{'start_with'} ) {
        my ($ws, @wb) = $self->_recurse_where( $attrs->{'start_with'} );
        $sql .= $self->_sqlcase(' start with ') . $ws;
        push @bind, @wb;
      }
      if ( my $connect_by = $attrs->{'connect_by'}) {
        $sql .= $self->_sqlcase(' connect by');
        foreach my $key ( keys %$connect_by ) {
          $sql .= " $key = " . $connect_by->{$key};
        }
      }
      if ( $attrs->{'order_siblings_by'} ) {
        $sql .= $self->_order_siblings_by( $attrs->{'order_siblings_by'} );
      }
    }

    return wantarray ? ($sql, @bind) : $sql;
  }

  sub _order_siblings_by {
    my $self = shift;
    my $ref = ref $_[0];

    my @vals = $ref eq 'ARRAY'  ? @{$_[0]} :
               $ref eq 'SCALAR' ? ${$_[0]} :
               $ref eq ''       ? $_[0]    :
               puke( "Unsupported data struct $ref for ORDER SIBILINGS BY" );

    my $val = join ', ', map { $self->_quote($_) } @vals;
    return $val ? $self->_sqlcase(' order siblings by')." $val" : '';
  }
}

sub _db_specific_attrs {
  my ($self, $attrs) = @_;

  my $rv = {};
  if ( $attrs->{connect_by} || $attrs->{start_with} || $attrs->{order_siblings_by} ) {
    $rv = {
      connect_by => $attrs->{connect_by},
      start_with => $attrs->{start_with},
      order_siblings_by => $attrs->{order_siblings_by},
    }
  }

  return $rv;
} # end of DBIC::SQL::Abstract::Oracle

__PACKAGE__->sql_maker_class('DBIC::SQL::Abstract::Oracle');

sub _dbh_last_insert_id {
  my ($self, $dbh, $source, @columns) = @_;
  my @ids = ();
  foreach my $col (@columns) {
    my $seq = ($source->column_info($col)->{sequence} ||= $self->get_autoinc_seq($source,$col));
    my $id = $self->_sequence_fetch( 'currval', $seq );
    push @ids, $id;
  }
  return @ids;
}

sub _dbh_get_autoinc_seq {
  my ($self, $dbh, $source, $col) = @_;

  # look up the correct sequence automatically
  my $sql = q{
    SELECT trigger_body FROM ALL_TRIGGERS t
    WHERE t.table_name = ?
    AND t.triggering_event = 'INSERT'
    AND t.status = 'ENABLED'
  };

  # trigger_body is a LONG
  $dbh->{LongReadLen} = 64 * 1024 if ($dbh->{LongReadLen} < 64 * 1024);

  my $sth;

  # check for fully-qualified name (eg. SCHEMA.TABLENAME)
  if ( my ( $schema, $table ) = $source->name =~ /(\w+)\.(\w+)/ ) {
    $sql = q{
      SELECT trigger_body FROM ALL_TRIGGERS t
      WHERE t.owner = ? AND t.table_name = ?
      AND t.triggering_event = 'INSERT'
      AND t.status = 'ENABLED'
    };
    $sth = $dbh->prepare($sql);
    $sth->execute( uc($schema), uc($table) );
  }
  else {
    $sth = $dbh->prepare($sql);
    $sth->execute( uc( $source->name ) );
  }
  while (my ($insert_trigger) = $sth->fetchrow_array) {
    return uc($1) if $insert_trigger =~ m!(\w+)\.nextval!i; # col name goes here???
  }
  $self->throw_exception("Unable to find a sequence INSERT trigger on table '" . $source->name . "'.");
}

sub _sequence_fetch {
  my ( $self, $type, $seq ) = @_;
  my ($id) = $self->dbh->selectrow_array("SELECT ${seq}.${type} FROM DUAL");
  return $id;
}

=head2 connected

Returns true if we have an open (and working) database connection, false if it is not (yet)
open (or does not work). (Executes a simple SELECT to make sure it works.)

The reason this is needed is that L<DBD::Oracle>'s ping() does not do a real
OCIPing but just gets the server version, which doesn't help if someone killed
your session.

=cut

sub connected {
  my $self = shift;

  if (not $self->SUPER::connected(@_)) {
    return 0;
  }
  else {
    my $dbh = $self->_dbh;

    local $dbh->{RaiseError} = 1;

    eval {
      my $ping_sth = $dbh->prepare_cached("select 1 from dual");
      $ping_sth->execute;
      $ping_sth->finish;
    };

    return $@ ? 0 : 1;
  }
}

sub _dbh_execute {
  my $self = shift;
  my ($dbh, $op, $extra_bind, $ident, $bind_attributes, @args) = @_;

  my $wantarray = wantarray;

  my (@res, $exception, $retried);

  RETRY: {
    do {
      eval {
        if ($wantarray) {
          @res    = $self->SUPER::_dbh_execute(@_);
        } else {
          $res[0] = $self->SUPER::_dbh_execute(@_);
        }
      };
      $exception = $@;
      if ($exception =~ /ORA-01003/) {
        # ORA-01003: no statement parsed (someone changed the table somehow,
        # invalidating your cursor.)
        my ($sql, $bind) = $self->_prep_for_execute($op, $extra_bind, $ident, \@args);
        delete $dbh->{CachedKids}{$sql};
      } else {
        last RETRY;
      }
    } while (not $retried++);
  }

  $self->throw_exception($exception) if $exception;

  wantarray ? @res : $res[0]
}

=head2 get_autoinc_seq

Returns the sequence name for an autoincrement column

=cut

sub get_autoinc_seq {
  my ($self, $source, $col) = @_;
    
  $self->dbh_do('_dbh_get_autoinc_seq', $source, $col);
}

=head2 columns_info_for

This wraps the superclass version of this method to force table
names to uppercase

=cut

sub columns_info_for {
  my ($self, $table) = @_;

  $self->next::method(uc($table));
}

=head2 datetime_parser_type

This sets the proper DateTime::Format module for use with
L<DBIx::Class::InflateColumn::DateTime>.

=cut

sub datetime_parser_type { return "DateTime::Format::Oracle"; }

sub _svp_begin {
    my ($self, $name) = @_;
 
    $self->dbh->do("SAVEPOINT $name");
}

# Oracle automatically releases a savepoint when you start another one with the
# same name.
sub _svp_release { 1 }

sub _svp_rollback {
    my ($self, $name) = @_;

    $self->dbh->do("ROLLBACK TO SAVEPOINT $name")
}

=head1 AUTHORS

Andy Grundman <andy@hybridized.org>

Scott Connelly <scottsweep@yahoo.com>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
