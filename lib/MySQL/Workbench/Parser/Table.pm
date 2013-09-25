package MySQL::Workbench::Parser::Table;

# ABSTRACT: A table of the ER model

use strict;
use warnings;

use List::MoreUtils qw(all);
use Moo;
use Scalar::Util qw(blessed);
use YAML::Tiny;

use MySQL::Workbench::Parser::Column;

our $VERSION = 0.01;

has node => (
    is       => 'ro',
    required => 1,
    isa      => sub {
        blessed $_[0] && $_[0]->isa( 'XML::LibXML::Node' );
    },
);

has parser => (
    is       => 'ro',
    required => 1,
    isa      => sub {
        blessed $_[0] && $_[0]->isa( 'MySQL::Workbench::Parser' );
    },
); 

has columns => (
    is  => 'rwp',
    isa => sub {
        ref $_[0] && ref $_[0] eq 'ARRAY' &&
        all{ blessed $_ && $_->isa( 'MySQL::Workbench::Parser::Column' ) }@{$_[0]}
    },
    lazy    => 1,
    default => sub { [] },
);

has foreign_keys => (
    is  => 'rwp',
    isa => sub {
        ref $_[0] && ref $_[0] eq 'HASH'
    },
    default => sub { {} },
);

has primary_key => (
    is => 'rwp',
    isa => sub {
        ref $_[0] && ref $_[0] eq 'ARRAY'
    },
    default => sub { [] },
);

has name => ( is => 'rwp' );

around new => sub {
    my ($code,$class,@arg) = @_;

    my $obj = $code->($class, @arg);
    $obj->_parse;

    return $obj;
};

sub as_hash {
    my $self = shift;

    my @columns;
    for my $column ( @{$self->columns} ) {
        push @columns, $column->as_hash;
    }

    my %info = (
        name         => $self->name,
        columns      => \@columns,
        foreign_keys => $self->foreign_keys,
        primary_key  => $self->primary_key,
    );

    return \%info;
}

sub _parse {
    my $self = shift;

    my $node = $self->node;

    my @columns;
    my @column_nodes = $node->findnodes( './/value[@struct-name="db.mysql.Column"]' );
    for my $column_node ( @column_nodes ) {
        my $column_obj = MySQL::Workbench::Parser::Column->new(
            node  => $column_node,
            table => $self,
        );
        push @columns, $column_obj;
    }
    $self->_set_columns( \@columns );

    my $name = $node->findvalue( './value[@key="name"]' );
    $self->_set_name( $name );

    my %foreign_keys;
    my @foreign_key_nodes = $node->findnodes( './value[@key="foreignKeys"]/value[@struct-name="db.mysql.ForeignKey"]' );
    for my $foreign_key_node ( @foreign_key_nodes ) {
        my $foreign_table_id  = $foreign_key_node->findvalue( 'link[@key="referencedTable"]' );
        my $foreign_column_id = $foreign_key_node->findvalue( 'value[@key="referencedColumns"]/link' );

        my $foreign_data      = $self->_foreign_data(
            table_id  => $foreign_table_id,
            column_id => $foreign_column_id,
        );

        my $table  = $foreign_data->{table};
        my $column = $foreign_data->{column};

        my $me_column_id = $foreign_key_node->findvalue( './/value[@key="columns"]/link' );
        my $me_column    = $node->findvalue( './/value[@id="' . $me_column_id . '"]/value[@key="name"]' );

        push @{ $foreign_keys{$table} }, { me => $me_column, foreign => $column };
    }

    my @index_column_nodes = $node->findnodes( './/value[@struct-name="db.mysql.Index"]' );
    for my $index_column_node ( @index_column_nodes ) {
        my $type = $index_column_node->findvalue( './/value[@key="indexType"]' );

        next if $type ne 'PRIMARY';

        my @column_nodes   = $index_column_node->findnodes( './/link[@key="referencedColumn"]' );
        my @column_names = map{
            my $id = $_->textContent;
            $node->findvalue( './/value[@id="' . $id . '"]/value[@key="name"]' );
        }@column_nodes;

        $self->_set_primary_key( \@column_names );
    }

    $self->_set_foreign_keys( \%foreign_keys );
}

sub get_datatype {
    my $self = shift;

    return $self->parser->get_datatype( @_ );
}

sub _foreign_data {
    my $self = shift;
    my %ids  = @_;

    return if !$ids{table_id} || !$ids{column_id};

    my ($foreign_table_node) = $self->node->parentNode->findnodes(
        'value[@struct-name="db.mysql.Table" and @id="' . $ids{table_id} . '"]'
    );

    my $foreign_table_name   = $foreign_table_node->findvalue( 'value[@key="name"]' );
    my $foreign_column_name  = $foreign_table_node->findvalue(
        './/value[@id="' . $ids{column_id} . '"]/value[@key="name"]'
    );

    return { table => $foreign_table_name, column => $foreign_column_name };
}

1;
