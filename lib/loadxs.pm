package loadxs;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Novel::Robot;
use Tiezi::Robot;
use JSON;
use FindBin;
use POSIX qw/strftime/;
use Encode;
use Cwd;
use Data::Dumper;

our $VERSION  = '0.1';
our $TEMP_DIR = '/tmp';

set serializer => 'JSON';

our $Novel = new Novel::Robot();
our $Tiezi = Tiezi::Robot->new();

get '/' => sub {
    my $data = { token => 1 };
    template 'index', $data;
};

post '/book_to_html' => sub {
    my $index_url = param('url');

    my $ts_rand = generate_temp_public_dir();
    my $tmpdir  = "$TEMP_DIR/$ts_rand";
    mkdir($tmpdir);

    `cd $tmpdir ; novel_to_html.pl "$index_url"`;

    my $data = `cat $tmpdir/*.html`;

    `rm -rf $tmpdir`;

    set content_type => ' text/html';
    decode( 'utf8', $data );

};

post '/book_to_txt' => sub {
    my $index_url = param('url');

    my $ts_rand = generate_temp_public_dir();
    my $tmpdir  = "$TEMP_DIR/$ts_rand";
    mkdir($tmpdir);

    `cd $tmpdir ; novel_to_txt.pl "$index_url"`;

    my $data = decode( 'utf8', `cat $tmpdir/*.txt` );
    `rm -rf $tmpdir`;

    my ($file) = $data =~ m#^\s*(.+?)\n#s;
    $file =~ s/\s*《/-/;
    $file =~ s/》\s*//;

    send_file(
        \$data,
        content_type => ' text/plain',
        filename     => "$file.txt",
    );

};

post '/book_to_wp' => sub {

    my $wp_info = {};

    #my $wp_info = get_wordpress_user_passwd($wp);

    my $wp_opt = {
        base_url => param('wordpress'),
        usr      => param('user') || $wp_info->{user},
        passwd   => param('passwd') || $wp_info->{passwd},

    };
    $wp_opt->{tag} = [ split /\s*,\s*/, param('tag') ] if ( param('tag') );
    $wp_opt->{category} = [ split /\s*,\s*/, param('category') ]
      if ( param('category') );
    $Novel->set_packer( 'WordPress', $wp_opt );

    my $index_url = param('url');
    $Novel->set_parser($index_url);

    my $id = param('id');

    if ($id) {
        my $index_ref = $Novel->get_index_ref($index_url);

        my $chap_ids = split_chapter_ids($id);
        print "$_\n" for @$chap_ids;

        for my $i (@$chap_ids) {
            my $u = $index_ref->{chapter_info}[ $i - 1 ]{url};
            my $chap_ref = $Novel->get_chapter_ref( $u, $i );

            $Novel->{packer}->open_packer($chap_ref);
            $Novel->{packer}->format_chapter( {}, $chap_ref, $i );
            $Novel->{packer}->close_packer($chap_ref);
        }

    }
    else {
        $Novel->get_book($index_url);
    }

    redirect $wp_opt->{base_url};
};

get '/tiezi' => sub {
    template 'tiezi';
};

post '/tiezi_to_html' => sub {
    my $index_url = param('url');

    $Tiezi->set_parser($index_url);
    $Tiezi->set_packer('HTML');

    my @fields =
      qw/with_toc only_poster min_word_num max_page_num max_floor_num/;
    my %opt;
    for my $f (@fields) {
        $opt{$f} = param($f) // undef;
    }

    my $src_dir = getcwd;
    my $ts_rand = generate_temp_public_dir();
    my $tmpdir  = "$TEMP_DIR/$ts_rand";
    mkdir($tmpdir);

    chdir($tmpdir);
    $Tiezi->get_tiezi( $index_url, \%opt );
    my $data = `cat $tmpdir/*.html`;
    chdir($src_dir);
    `rm -rf $tmpdir`;

    set content_type => ' text/html';
    decode( 'utf8', $data );
};

true;

sub get_wordpress_user_passwd {
    my ($url) = @_;
    my $sth = database->prepare(
        'select user,passwd from wordpress_user_passwd where url = ?',
    );
    $sth->execute($url);
    $sth->fetchrow_hashref;
} ## end sub get_wordpress_user_passwd

sub generate_temp_public_dir {
    my $timestamp = strftime "%Y%m%d%H%M%S", localtime;
    my $rand = int( rand(9999999999) );
    return "$timestamp-$rand";
}

sub split_chapter_ids {
    my ($id) = @_;

    my @id_list = split ',', $id;

    my @chap_ids;
    for my $i (@id_list) {
        my ( $s, $e ) = split '-', $i;
        $e ||= $s;
        push @chap_ids, ( $s .. $e );
    }

    return \@chap_ids;
}
