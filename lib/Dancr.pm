package Dancr;

our $VERSION = '0.1';

use Dancer2;
use DBI;
use File::Spec;
use File::Slurp;
use Template;
 
set 'database'     => File::Spec->catfile(File::Spec->tmpdir(), 'dancr.db');
set 'session'      => 'Simple';
set 'template'     => 'template_toolkit';
set 'logger'       => 'console';
set 'log'          => 'debug';
set 'show_errors'  => 1;
set 'startup_info' => 1;
set 'warnings'     => 1;
set 'layout'       => 'main';
 
my $flash;
 
sub set_flash {
       my $message = shift;
 
       $flash = $message;
}
 
sub get_flash {
 
       my $msg = $flash;
       $flash = "";
 
       return $msg;
}
 
sub connect_db {
       my $dbh = DBI->connect("dbi:SQLite:dbname=".setting('database')) or
               die $DBI::errstr;
       return $dbh;
}
 
sub init_db {
       my $db = connect_db();
       my $schema = read_file('./schema.sql');
       $db->do($schema) or die $db->errstr;
       print "Created table";
}
 
hook before_template => sub {
       my $tokens = shift;
       $tokens->{'css_url'} = request->base . 'css/style.css';
       $tokens->{'login_url'} = uri_for('/login');
       $tokens->{'register_url'} = uri_for('/register');
       $tokens->{'logout_url'} = uri_for('/logout');
};
 
get '/' => sub {
	if ( not session('logged_in') ){
		print "here\n";
	}
       my $db = connect_db();
       my $sql = 'select id, title, text from entries order by id desc';
       my $sth = $db->prepare($sql) or die $db->errstr;
       $sth->execute or die $sth->errstr;
       template 'show_entries.tt', {
               'msg' => get_flash(),
               'add_entry_url' => uri_for('/add'),
               'edit_entry_url' => uri_for('/edit'),
	             'delete_entry_url' => uri_for('/delete'),
               'entries' => $sth->fetchall_hashref('id'),
       };
};
 
post '/add' => sub {
	if ( not session('logged_in') ) {
               send_error("Not logged in", 401);
       }
 
       my $db = connect_db();
       my $sql = 'insert into entries (title, text, username) values (?, ?, ?)';
       my $sth = $db->prepare($sql) or die $db->errstr;
       $sth->execute(params->{'title'}, params->{'text'}, session('username')) or die $sth->errstr;
 
       set_flash('New entry posted!');
       redirect '/';
};

post '/edit' => sub {
        if ( not session('logged_in') ) {
               send_error("Not logged in", 401);
       }
 
       my $db = connect_db();
my $sql = "SELECT title, text FROM entries WHERE id=?";
my @row = $db->selectrow_array($sql,undef,params->{'rowid'});

       set_flash('Entry updated!');
      
       template 'edit.tt', {
	       'title_value' => $row[0],
		       'text_value' => $row[1],
		       'rowid'=>params->{'rowid'},
		       'update_entry_url'=>uri_for('/update'),
       };

};
 
post '/update' => sub{
	my $db = connect_db();
	my $sql = 'update entries set title=?, text=? where id=?';
	my $sth = $db->prepare($sql) or die $db->errstr;
	$sth->execute(params->{'title'}, params->{'text'}, params->{'rowid'}) or die $sth->errstr;
	set_flash('Entry updated!');
	redirect '/';
};

post '/delete' => sub{
	my $db = connect_db();
	my $sql = 'delete from entries where id=?';
	my $sth = $db->prepare($sql) or die $db->errstr;
	$sth->execute(params->{'rowid'}) or die $sth->errstr;
	set_flash('Entry deleted!');
	redirect '/';
};

any ['get', 'post'] => '/login' => sub {
       my $err;
 
       if ( request->method() eq "POST" ) {
               # process form input
               my $db = connect_db();
               my $sql = 'select username,password from users where username=?';
               my @ans = $db->selectrow_array($sql, undef, params->{'username'});
               my ($user,$pwd) = @ans;
               if (params->{'username'} ne $user){
                  $err = 'Invalid username';
               }
               elsif(params->{'password'} ne $pwd) {
                $err = 'Invalid password';
               }
               else {
                       session 'logged_in' => true;
                       session 'username' => params->{'username'};
                       set_flash('You are logged in.');
                       return redirect '/';
               }
       }
 
       # display login form
       template 'login.tt', {
               'err' => $err,
       };
 
};

any ['get', 'post'] => '/register' => sub {
	 if ( request->method() eq "POST" ) {
       my $db = connect_db();
       my $sql = 'insert into users (name, username, password, email) values (?, ?, ?, ?)';
       my $sth = $db->prepare($sql) or die $db->errstr;
       $sth->execute(params->{'name'}, params->{'user'}, params->{'pwd'}, params->{'email'}) or die $sth->errstr;
 
       set_flash('New user registered');
       redirect '/login';
     }
  #display register form
	
  template 'register.tt';
};

get '/logout' => sub {
       app->destroy_session;
       set_flash('You are logged out.');
       redirect '/';
};

init_db();

true;

