create table if not exists users (
        userid integer primary key autoincrement,
        name string not null,
        author string not null,
        password string not null,
        email string not null
        );
create table if not exists entries (
        id integer primary key autoincrement,
        title string not null,
        text string not null,
        author string not null,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );
create table if not exists filenames (
        id integer primary key,
        filename string not null
        );
