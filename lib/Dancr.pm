package Dancr;

our $VERSION = '0.1';

use Dancer2;
use DBI;
use File::Spec;
use File::Slurp;
use Dancer2::Plugin::Auth::Tiny;
use Dancer2::Plugin::Passphrase;
use Dancer2::Plugin::Feed;
use POSIX qw/strftime/;

set 'public_dir' => '/home/snigdha/Dancr/public';
set 'upload_dir' => '/uploadsFolder/';
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
    my $dbh = DBI->connect("dbi:SQLite:dbname=".setting('database'))
        or die $DBI::errstr;
    return $dbh;
}

sub init_db {
    my $schema = read_file('./schema.sql');
    my @sqls = split(/;/, $schema);
    my $db = connect_db();
    foreach $a (@sqls){
        $db->do($a) or die $db->errstr;
    }
}

hook before_template => sub {
    my $tokens = shift;
    $tokens->{'css_url'} = request->base . 'css/style.css';
    $tokens->{'login_url'} = uri_for('/login');
    $tokens->{'register_url'} = uri_for('/register');
    $tokens->{'logout_url'} = uri_for('/logout');
    $tokens->{'feed_url'} = uri_for('/feed');
};

get '/' => needs login => sub {
    if ( not session('logged_in') ){
        #needed to maintain session state
    }

    my $db = connect_db();
    my $sql = 'select id, title, text, username from entries order by id desc';
    my $sth = $db->prepare($sql) or die $db->errstr;
    $sth->execute or die $sth->errstr;
    $sql = 'select id,filename from filenames order by id desc';
    my $filenames = $db->prepare($sql) or die $db->errstr;
    $filenames->execute or die $sth->errstr;

    template 'show_entries.tt', {
        'msg'              => get_flash(),
        'add_entry_url'    => uri_for('/add'),
        'edit_entry_url'   => uri_for('/edit'),
        'delete_entry_url' => uri_for('/delete'),
        'entries'          => $sth->fetchall_hashref('id'),
        'filenames'        => $filenames->fetchall_hashref('id'),
        'uname'            => session('user')
    };
};

post '/add' => needs login => sub {

    my $db  = connect_db();
    my $upload = request->upload('file');
    my $fname;

    my $sql = 'insert into entries (title, text, username, timestamp) values (?, ?, ?, ?)';
    my $sth = $db->prepare($sql) or die $db->errstr;
    my $date = strftime('%Y-%m-%d %T',localtime);
    $sth->execute(params->{'title'}, params->{'text'}, session('user'), $date) or die $sth->errstr;
    if($upload){
        $fname = setting('upload_dir').$upload->filename;
        $upload->copy_to(setting('public_dir').$fname);

        $sql = "select id from entries where username =? and title =? and text=?";
        my @row = $db->selectrow_array($sql,undef,session('user'),params->{'title'},params->{'text'});

        $sql = 'insert into filenames (id, filename) values (?, ?)';
        $sth = $db->prepare($sql) or die $db->errstr;
        $sth->execute($row[0], $fname) or die $sth->errstr;
    }
    set_flash('New entry posted!');
    redirect '/';
};

any ['get' ,'post'] => '/edit' => needs login =>  sub {
    session('user'); #without this line tiny auth redirects to login page again and again
    my $db  = connect_db();
    my $sql = "SELECT title, text, username FROM entries WHERE id=?";
    my $sth = $db->prepare($sql) or die $db->errstr;
    $sth->execute(params->{'rowid'});
    my @row = $sth->fetchrow_array();

    if ( $row[2] ne session('user')) {
        set_flash('Unauthorized access');
        redirect '/';
    }

    template 'edit.tt', {
        'title_value'      => $row[0],
        'text_value'       => $row[1],
        'rowid'            => params->{'rowid'},
        'update_entry_url' => uri_for('/update'),
    };
};

post '/update' => needs login => sub{
    my $db  = connect_db();
    my $sql = 'update entries set title=?, text=? where id=?';
    my $sth = $db->prepare($sql) or die $db->errstr;
    $sth->execute(params->{'title'}, params->{'text'}, params->{'rowid'}) or die $sth->errstr;
    my @row = $sth->fetchrow_array();
   

    set_flash('Entry updated!');
    redirect '/';
};

post '/delete' => needs login => sub{
    my $db  = connect_db();
    my $sql = "SELECT username FROM entries WHERE id=?";
    my @row = $db->selectrow_array($sql,undef,params->{'rowid'});
    
    if ( $row[0] ne session('user')) {
        set_flash('Unauthorized access');
        redirect '/';
    }

    $sql = "select filename from filenames where id=?";
    @row = $db->selectrow_array($sql,undef,params->{'rowid'});
    my $fname = setting('public_dir').$row[0];
    unlink $fname;
    $sql = 'delete from entries where id=?';
    my $sth = $db->prepare($sql) or die $db->errstr;
    $sth->execute(params->{'rowid'}) or die $sth->errstr;
    $sql = 'delete from filenames where id=?';
    $sth = $db->prepare($sql) or die $db->errstr;
    $sth->execute(params->{'rowid'}) or die $sth->errstr;
    set_flash('Entry deleted!');
    redirect '/';
};

any ['get', 'post'] => '/login' => sub {
    my $err;

    if ( request->method() eq "POST" ) {
        # process form input
        my $db  = connect_db();
        my $sql = 'select username,password from users where author=?';
        my @ans = $db->selectrow_array($sql, undef, params->{'username'});
        my ($user,$pwd) = @ans;
        if (params->{'username'} ne $user){
            $err = 'Invalid username';
        }
        elsif(not passphrase(params->{'password'})->matches($pwd)) {
            $err = 'Invalid password';
        }
        else {
            session 'user' => params->{'username'};
            session 'logged_in' => true;
            set_flash('You are logged in.');
            return redirect params->{return_url} || '/';
            #return redirect '/';
        }
    }
    # display login form
    template 'login.tt', {
        'err' => $err,
        'return_url' => params->{return_url}
    };
};

any ['get', 'post'] => '/register' => sub {
    if ( request->method() eq "POST" ) {
        my $db = connect_db();
        my $password = passphrase( params->{'pwd'} )->generate;
        my $sql = 'insert into users (name, username, password, email) values (?, ?, ?, ?)';
        my $sth = $db->prepare($sql) or die $db->errstr;
        $sth->execute(params->{'name'}, params->{'user'}, $password->rfc2307, params->{'email'}) or die $sth->errstr;

        set_flash('New user registered');
        redirect '/login';
    }

    # display register form
    template 'register.tt';
};

get '/logout' => needs login => sub {
    app->destroy_session;
    set_flash('You are logged out.');
    redirect '/';
};

sub _articles {
    my $db = connect_db();
    my $sql = 'SELECT * FROM entries ORDER BY timestamp DESC LIMIT 5';
    my $sth = $db->prepare($sql) or die $db->errstr;
    $sth->execute() or die $DBI::errstr;
    my @ans = ();
    while(my $article= $sth->fetchrow_hashref())
    {
        push @ans, $article;
    }
    return \@ans;
}

get '/feed' => sub {
    my $feed;
    my $articles = _articles();
    $feed = create_atom_feed(
            title   => 'Dancer Blog Feed',
            entries => $articles,
        );
    return $feed;
};

init_db();
start();
true;
