package loadxs;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Novel::Robot;
use JSON;
use FindBin;
use POSIX qw/strftime/;
use Encode;

our $VERSION = '0.1';
our $TEMP_DIR = '/tmp';

set serializer => 'JSON';

our $Robot = new Novel::Robot();

get '/' => sub {
    my $data = { token => 1 };
    template 'index', $data;
};

post '/book_to_html' => sub {
    my $index_url  = param('url');

    my $ts_rand = generate_temp_public_dir();
    my $tmpdir = "$TEMP_DIR/$ts_rand";
    mkdir($tmpdir);

    `cd $tmpdir ; novel_to_html.pl "$index_url"`;
    
    my $data = `cat $tmpdir/*.html`;

    `rm -rf $tmpdir`;
    
    set content_type => ' text/html'; 
    decode('utf8', $data); 

};

post '/book_to_txt' => sub {
    my $index_url  = param('url');

    my $ts_rand = generate_temp_public_dir();
    my $tmpdir = "$TEMP_DIR/$ts_rand";
    mkdir($tmpdir);

    `cd $tmpdir ; novel_to_txt.pl "$index_url"`;
    
    my $data = decode('utf8', `cat $tmpdir/*.txt`);
    `rm -rf $tmpdir`;

    my ($file) = $data=~m#^\s*(.+?)\n#s;
    $file=~s/\s*《/-/;
    $file=~s/》\s*//;

    send_file(
        \$data, 
    content_type => ' text/plain', 
    filename => "$file.txt", 
); 

};


post '/book_to_wp' => sub {

    my $wp_info = {};
    #my $wp_info = get_wordpress_user_passwd($wp);

    my $wp_opt = {
            base_url => param('wordpress'),
            usr => param('user')   || $wp_info->{user},
            passwd => param('passwd')   || $wp_info->{passwd}, 

        };
    $wp_opt->{tag}  = [ split /\s*,\s*/, param('tag') ] if(param('tag'));
    $wp_opt->{category}  = [ split /\s*,\s*/, param('category') ] if(param('category'));
    $Robot->set_packer('WordPress', $wp_opt);

    my $index_url  = param('url');
    $Robot->set_parser($index_url);
    $Robot->get_book($index_url);

    redirect $wp_opt->{base_url};
};

#any '/chapter_to_wp' => sub {
    #my $wp_info = {};
    ##my $wp_info = get_wordpress_user_passwd($wp);
    #my $wp_opt = {
            #base_url => param('wordpress'),
            #usr => param('user')   || $wp_info->{user},
            #passwd => param('passwd')   || $wp_info->{passwd}, 

        #};
    #$wp_opt->{category}  = param('categories') if(param('categories'));
    #$Robot->set_packer('WordPress', $wp_opt);

    #my $chap_url  = param('url');
    #$Robot->set_parser($chap_url);
    #my $id        = param('id') || 0;

    #my $chap_ref = $Robot->get_chapter_ref( $chap_url, $id );
    #$Robot->{packer}->open_packer($chap_ref);
    #$Robot->{packer}->format_chapter( $chap_ref, $id );
    #$Robot->{packer}->close_packer($chap_ref);

    #'finish';
#};

true;

sub get_wordpress_user_passwd {
    my ($url) = @_;
    my $sth = database->prepare( 'select user,passwd from wordpress_user_passwd where url = ?', );
    $sth->execute($url);
    $sth->fetchrow_hashref;
} ## end sub get_wordpress_user_passwd

sub generate_temp_public_dir {
    my $timestamp = strftime "%Y%m%d%H%M%S", localtime; 
    my $rand = int(rand(9999999999));
    return "$timestamp-$rand";
}

