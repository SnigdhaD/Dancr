use strict;
use warnings;

use Test::More tests => 3;
use Cwd;

BEGIN { use_ok("Dancr::DB", qw(connect_db)); }

my $cwd = getcwd();
my $dancr_db = $cwd . "/dancr.db";

unlink $dancr_db if (-e $dancr_db);

my $db = connect_db();
ok($db, "Database connection created");

ok(-e $dancr_db, "Database file created ($dancr_db)");
