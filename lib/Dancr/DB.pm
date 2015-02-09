package Dancr::DB;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use strict;
use warnings;
require Exporter;
use File::Spec;
use File::Slurp;
use Exporter qw(import);
our @EXPORT_OK = qw(connect_db init_db);

our $VERSION = '0.1';

use DBI;
    sub connect_db {
       my $dbh = DBI->connect("dbi:SQLite:dbname=dancr.db") or
               die $DBI::errstr;
 
       return $dbh;
}
 
sub init_db {
       my $db = connect_db();
       my $schema = read_file('./schema.sql');
       $db->do($schema) or die $db->errstr;
}

1;
