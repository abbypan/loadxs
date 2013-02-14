package loadxs;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Novel::Robot;
use WordPress::XMLRPC;
use JSON;
use Encode;

our $VERSION = '0.1';

set serializer => 'JSON';

our $Robot = new Novel::Robot();

get '/' => sub {
    my $data = { token => 1 };
    template 'index', $data;
};

any '/index_data' => sub {
    my $url = param('url');
    get_index_data($url);
};

any '/chapter_data' => sub {
    my $url = param('url');
    my $id = param('id') || undef;
    get_chapter_data( $url, $id );
};

post '/book_to_wp' => sub {

    my $wp      = param('wordpress');
    my $wp_info = {};
    #my $wp_info = get_wordpress_user_passwd($wp);

    my $wp_user   = param('user')   || $wp_info->{user};
    my $wp_passwd = param('passwd') || $wp_info->{passwd};
    my $wp_robot = init_wordpress_robot( $wp, $wp_user, $wp_passwd );

    my $categories = param('categories') ? [ split ',', param('categories') ] : [];

    my $index_url  = param('url');
    my $index_data = get_index_data($index_url);

    my @result_data;
    for my $id ( 1 .. $index_data->{chapter_num} ) {
        my ($chap_url) = $index_data->{chapter_urls}[$id];
        next unless ($chap_url);
        my $chap_data = get_chapter_data( $chap_url, $id );
        $chap_data->{categories} = $categories;
        for ( 1 .. 3 ) {
            my $blog_id = post_chapter_to_wordpress( $wp_robot, $chap_data );
            last if ($blog_id);
            push @result_data, { id => $id, chapter => $chap_data->{chapter}, url => "$wp?p=$blog_id"};
        }
    } ## end for my $id ( 1 .. $index_data...)

    template 'book_to_wp', { chap => \@result_data };
};

any '/chapter_to_wp' => sub {
    my $wp        = param('wordpress');
    my $wp_info = {};
    #my $wp_info = get_wordpress_user_passwd($wp);
    my $wp_user   = param('user') || $wp_info->{user};
    my $wp_passwd = param('passwd') || $wp_info->{passwd};
    my $wp_robot  = init_wordpress_robot( $wp, $wp_user, $wp_passwd );

    my $chap_url  = param('url');
    my $id        = param('id') || 0;
    my $chap_data = get_chapter_data( $chap_url, $id );

    $chap_data->{categories} = param('categories') ? [ split ',', param('categories') ] : [];

    my $id = post_chapter_to_wordpress( $wp_robot, $chap_data );
    ( my $wp_url = $wp ) =~ s#/$##;
    "$wp_url/?p=$id";
};

true;

sub get_index_data {
    my ($url) = @_;

    $Robot->set_site_by_url($url);
    my $index_ref = $Robot->get_index_ref($url);
} ## end sub get_index_data

sub get_chapter_data {
    my ( $url, $id ) = @_;
    $Robot->set_site_by_url($url);
    my $chapter_ref = $Robot->get_chapter_ref($url);
    $chapter_ref->{id} = $id || 0;
    $chapter_ref;
} ## end sub get_chapter_data

sub post_chapter_to_wordpress {

    my ( $o, $d ) = @_;

    $d->{title} = qq[$d->{writer} 《$d->{book}》$d->{id} : $d->{chapter}];
    $d->{content} =
        qq[<p>来自：<a href="$d->{chapter_url}">$d->{chapter_url}</a></p><p></p>$d->{content}];
    $d->{content} .= qq[<div id="writer_say">$d->{writer_say}</div>] if ( $d->{writer_say} );

    my %form = (
        title       => $d->{title},
        description => $d->{content},
        mt_keywords => [ $d->{writer}, $d->{book} ],
        categories  => $d->{categories},
    );

    my $j      = encode_json \%form;
    my $j_utf8 = encode( 'utf-8', $j );
    my $f      = decode_json($j_utf8);

    my $flag = $o->newPost( $f, 1 );
} ## end sub post_chapter_to_wordpress

sub get_wordpress_user_passwd {
    my ($url) = @_;
    my $sth = database->prepare( 'select user,passwd from wordpress_user_passwd where url = ?', );
    $sth->execute($url);
    $sth->fetchrow_hashref;
} ## end sub get_wordpress_user_passwd

sub init_wordpress_robot {
    my ( $site, $user, $passwd ) = @_;
    $site =~ s#(?<!\.php)/?$#/xmlrpc.php#;
    my $o = WordPress::XMLRPC->new(
        {   username => $user,
            password => $passwd,
            proxy    => $site,
        }
    );
    return $o;
} ## end sub init_wordpress_robot
