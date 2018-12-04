package MySQL::Workbench::Parser::Index;

# ABSTRACT: An index of the ER model

use strict;
use warnings;

use Moo;
use Scalar::Util qw(blessed);

our $VERSION = '1.02';

=head1 METHODS

=cut

has node => (
    is       => 'ro',
    required => 1,
    isa      => sub {
        blessed $_[0] && $_[0]->isa( 'XML::LibXML::Element' );
    },
);

has table => (
    is       => 'ro',
    required => 1,
    isa      => sub {
        blessed $_[0] && $_[0]->isa( 'MySQL::Workbench::Parser::Table' );
    },
);

=for Pod::Coverage BUILD

=cut

sub BUILD {
    my $self = shift;
    $self->_parse;
}

has id   => ( is => 'rwp' );
has name => ( is => 'rwp' );
has type => ( is => 'rwp' );

has columns => (
    is  => 'rwp',
    isa => sub {
        ref $_[0] && ref $_[0] eq 'ARRAY';
    },
    lazy    => 1,
    default => sub { [] },
);

=head2 as_hash

return info about a column as a hash

    my %info = $index->as_hash;

returns

    (
        name          => 'id',
        columns       => ['col1','col2'],
        type          => 'INDEX', # 'UNIQUE'
    )

=cut

sub as_hash {
    my $self = shift;

    my %info;

    for my $attr ( qw(name type columns) ) {
        $info{$attr} = $self->$attr();
    }

    return \%info;
}

sub _parse {
    my $self = shift;

    my $node = $self->node;

    for my $key ( qw(id) ) {
        my $value  = $node->findvalue( './value[@key="' . $key . '"]' );
        my $method = $self->can( '_set_' . $key );
        $self->$method( $value );
    }

    my $mapping    = $self->table->column_mapping;
    my @column_ids = map{ $_->textContent }$node->findnodes( './/link[@key="referencedColumn"]' );
    my @columns    = map{ $mapping->{$_} }@column_ids;
    $self->_set_columns( \@columns );

    my $name = $node->findvalue( './value[@key="name"]' );
    $self->_set_name( $name );

    my $type = $node->findvalue( './/value[@key="indexType"]' );
    $self->_set_type( $type );
}

1;

=head1 ATTRIBUTES

=over 4

=item * id

=item * name

=item * node

=item * table

=item * type

=back

=head1 MISC

=head2 BUILD

