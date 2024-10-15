package DB;
use strict;
use warnings;
use DBI;

sub new {
    my ($class) = @_;
    my $db = DBI->connect("dbi:Pg:dbname=oxe_banking;host=localhost", "postgres", "", { RaiseError => 1, AutoCommit => 1 });
    bless { db => $db }, $class;
}

sub db {
    my $self = shift;
    return $self->{db};
}

1;
