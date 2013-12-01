package loadxs;
use Dancer ':syntax';
use Novel::Robot;
use Tiezi::Robot;
use Encode;
use Data::Dumper;
$|=1;

our $VERSION  = '0.1';

get '/' => sub {
    my $data = { token => 1 };
    template 'index', $data;
};

post '/book_to_html' => sub {
    my $Novel = new Novel::Robot();
    $Novel->set_packer( 'HTML');

    my $index_url = param('url');
    $Novel->set_parser($index_url);

    my $data = $Novel->get_book($index_url, { write_scalar => 1 });

    set content_type => ' text/html';
    decode('utf8', $$data);
};

post '/book_to_txt' => sub {
    my $Novel = new Novel::Robot();
    $Novel->set_packer( 'TXT');

    my $index_url = param('url');
    $Novel->set_parser($index_url);

    my $data = $Novel->get_book($index_url, { write_scalar => 1 });

    my ($file) = $$data =~ m#^\s*(.+?)\n#s;
    $file =~ s/\s*《/-/;
    $file =~ s/》\s*//;

    $$data = decode('utf8', $$data);

    send_file(
        $data,
        content_type => 'text/plain',
        filename     => "$file.txt",
    );
};


post '/book_to_wp' => sub {
    my $wp_opt = {
        base_url => param('wordpress'),
        usr      => param('user') ,
        passwd   => param('passwd') ,

    };

    $wp_opt->{tag} = [ split /\s*,\s*/, param('tag') ] if ( param('tag') );
    $wp_opt->{category} = [ split /\s*,\s*/, param('category') ]
      if ( param('category') );

    my $Novel = new Novel::Robot();
    $Novel->set_packer( 'WordPress');

    my $index_url = param('url');
    $Novel->set_parser($index_url);

    my $id = param('id');
    $wp_opt->{chapter_ids} = $Novel->split_id_list($id) if($id);
    my $data = $Novel->get_book($index_url, $wp_opt);
    redirect $$data;
};

get '/tiezi' => sub {
    template 'tiezi';
};

sub read_tiezi_option {
    my @fields =
      qw/with_toc only_poster min_word_num max_page_num max_floor_num/;
    my %opt;
    for my $f (@fields) {
        $opt{$f} = param($f) // undef;
    }
    return \%opt;
}

post '/tiezi_to_html' => sub {
    my $index_url = param('url');

    my $Tiezi = Tiezi::Robot->new();
    $Tiezi->set_parser($index_url);
    $Tiezi->set_packer('HTML');

    my @fields =
      qw/with_toc only_poster min_word_num max_page_num max_floor_num/;
    my %opt;
    for my $f (@fields) {
        $opt{$f} = param($f) // undef;
    }

    $opt{write_scalar} = 1;


    my $data = $Tiezi->get_tiezi( $index_url, \%opt );

    set content_type => 'text/html';
    decode('utf8', $$data);
};

post '/tiezi_to_txt' => sub {
    my $Tiezi = Tiezi::Robot->new();
    $Tiezi->set_packer('TXT');

    my $index_url = param('url');
    $Tiezi->set_parser($index_url);

    my $opt= read_tiezi_option();
    $opt->{write_scalar} = 1;

    my $data = $Tiezi->get_tiezi($index_url, $opt);

    my ($file) = $$data =~ m#^\s*(.+?)\n#s;
    $file =~ s/\s*《/-/;
    $file =~ s/》\s*//;

    $$data = decode('utf8', $$data);

    send_file(
        $data,
        content_type => 'text/plain',
        filename     => "$file.txt",
    );
};

true;
