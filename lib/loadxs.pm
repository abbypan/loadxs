package loadxs;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Novel::Robot;
use JSON;
#use Encode;

our $VERSION = '0.1';

set serializer => 'JSON';

our $Robot = new Novel::Robot();

get '/' => sub {
    my $data = { token => 1 };
    template 'index', $data;
};

post '/book_to_wp' => sub {

    my $wp_info = {};
    #my $wp_info = get_wordpress_user_passwd($wp);
    my $wp_opt = {
            base_url => param('wordpress'),
            usr => param('user')   || $wp_info->{user},
            passwd => param('passwd')   || $wp_info->{passwd}, 

        };
    $wp_opt->{category}  = param('categories') if(param('categories'));
    $Robot->set_packer('WordPress', $wp_opt);

    my $index_url  = param('url');
    $Robot->set_parser($index_url);
    $Robot->get_book($index_url);

    my @result_data;
    template 'book_to_wp', { chap => \@result_data };

};

any '/chapter_to_wp' => sub {
    my $wp_info = {};
    #my $wp_info = get_wordpress_user_passwd($wp);
    my $wp_opt = {
            base_url => param('wordpress'),
            usr => param('user')   || $wp_info->{user},
            passwd => param('passwd')   || $wp_info->{passwd}, 

        };
    $wp_opt->{category}  = param('categories') if(param('categories'));
    $Robot->set_packer('WordPress', $wp_opt);

    my $chap_url  = param('url');
    $Robot->set_parser($chap_url);
    my $id        = param('id') || 0;

    my $chap_ref = $Robot->get_chapter_ref( $chap_url, $id );
    $Robot->{packer}->open_packer($chap_ref);
    $Robot->{packer}->format_chapter( $chap_ref, $id );
    $Robot->{packer}->close_packer($chap_ref);

    'finish';
};

true;

sub get_wordpress_user_passwd {
    my ($url) = @_;
    my $sth = database->prepare( 'select user,passwd from wordpress_user_passwd where url = ?', );
    $sth->execute($url);
    $sth->fetchrow_hashref;
} ## end sub get_wordpress_user_passwd
