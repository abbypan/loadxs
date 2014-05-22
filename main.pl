use Mojolicious::Lite;
use Mojolicious::Static;
use Mojo::Template;

use Encode;
use Encode::Locale;
use File::Temp qw/tempfile/;
use lib '../Novel-Robot-Parser/lib';
use Novel::Robot;
use Tiezi::Robot;

## DEFAULT {{
use FindBin;
our $STATIC_PATH = "$FindBin::RealBin/static";
our $MUSIC_PATH  = "$FindBin::RealBin/../baidu_music/baidu_music.pl";
our $MUSIC_BIN   = qq[export LC_ALL=zh_CN.UTF-8 && sudo perl $MUSIC_PATH ];
#$MUSIC_BIN = qq[export LC_ALL=zh_CN.UTF-8 && sudo perl ../baidu_music/baidu_music.pl ];
#$MUSIC_BIN = qq[perl ../baidu_music/baidu_music.pl ];
## }}

## {{static
my $static = app->static();
push @{ $static->paths }, $STATIC_PATH;

#}

## {{小说，帖子

get '/' => sub {
    my $self = shift;
    $self->render_static('view/index.html');
};

post '/get_book' => sub {
    my $self = shift;
    my $url  = $self->param('url');
    my $type = $self->param('type');

    my $xs = Novel::Robot->new(
        site => $url,
        type => $type eq 'web' ? 'html' : $type,
    );

    my $html = 'fail';
    my ( $data, $inf ) = $xs->get_book(
        $url,
        output_scalar => 1,
        with_toc      => $self->param('with_toc'),
    );
    $data ||= \$html;

    if ( $type eq 'web' ) {
        $self->render( text => $$data );
    }
    else {
        my $format = $type eq 'markdown' ? 'md' : $type;
        my $file =
          encode( "utf8",
            format_filename("$inf->{writer}-$inf->{book}.$format") );
        $self->res->headers->content_disposition(
            qq[attachment;filename="$file"]);
        $self->render( text => $$data, format => $format );
    }
};

post '/get_tiezi' => sub {
    my $self = shift;
    my $url  = $self->param('url');
    my $type = $self->param('type');

    my @fields =
      qw/with_toc only_poster min_word_num max_page_num max_floor_num/;
    my %opt;
    for my $f (@fields) {
        $opt{$f} = $self->param($f) // undef;
    }

    my $tz = Tiezi::Robot->new(
        site => $url,
        type => $type eq 'web' ? 'html' : $type,
    );

    my ( $data, $inf ) = $tz->get_tiezi(
        $url,
        output_scalar => 1,
        %opt,
    );

    if ( $type eq 'web' ) {
        $self->render( text => $$data );
    }
    else {
        my $format = $type;
        my $file   = encode( "utf8",
            format_filename("$inf->{topic}{name}-$inf->{topic}{title}.$format")
        );
        $self->res->headers->content_disposition(
            qq[attachment;filename="$file"]);
        $self->render( text => $$data, format => $format );
    }
};

## }}
## {{

post '/get_music' => sub {
    my $self = shift;
    my $key  = $self->param('key');
    my %opt  = read_music_option($self);

    my $cmd = format_music_cmd( $self, $key, %opt );
    my $data = get_music_data( $self, $cmd );
    format_music_list( $self, $data, %opt );
};

sub read_music_option {
    my ($self) = @_;
    my %opt = (
        type    => $self->param('type')    || 'xspf',
        level   => $self->param('level')   || 0,
        format  => $self->param('format')  || '',
        charset => $self->param('charset') || 'utf8',
        page    => $self->param('page')    || 1,
    );
}

sub format_music_cmd {
    my ( $self, $key, %opt ) = @_;
    my $cmd;
    if ( $key =~ m#^http://# ) {
        $key =~ s/\?.*//;
        my ( $af, $id ) =
          $key =~ m{^\Qhttp://music.baidu.com/\E(album|film)/(\d+)$};
        return unless ($id);
        $cmd .= qq[-a "$key"];
    }
    else {
        $key =~ s/['"\\\/<>]//gs;
        $cmd .= qq[-q "$key" -i "$opt{page}"];
    }
    return unless ($cmd);
    $cmd =
      qq[$MUSIC_BIN $cmd  -t "$opt{type}" -l "$opt{level}" -f "$opt{format}"];
    $cmd = encode( locale => $cmd );
    return $cmd;
}

sub get_music_data {
    my ( $self, $cmd )      = @_;
    my ( $fh,   $filename ) = tempfile();

    $cmd .= " -o $filename";
    `$cmd`;

    my $data;
    {
        local $/ = undef;
        $data = <$fh>;
    }
    $data = decode( utf8 => $data );
    return $data;
}

sub format_music_list {
    my ( $self, $data, %opt ) = @_;

    if ( $opt{type} eq 'online' ) {
        my $mt = Mojo::Template->new( encoding => 'UTF-8' );
        my $output =
          $mt->render_file( "$STATIC_PATH/view/music_online.mt", $data );
        $self->render( text => $output );
    }
    elsif ( $opt{type} eq 'html' ) {
        $self->render( text => $data );
    }
    else {
        my $file = encode(
            "utf8",
            format_filename(
                "music-" . int( rand(99999999999) ) . "." . $opt{type}
            )
        );
        $self->res->headers->content_type("text/plain; charset=$opt{charset}");
        $self->res->headers->content_disposition(
            qq[attachment;filename="$file"]);
        $self->render( text => $data, format => $opt{type} );
    }
}
## }}

sub format_filename {
    my ($f) = @_;
    $f =~ s/^\s+|\s+$//g;
    $f =~ s/[\/\\\| ]/-/g;
    return $f;
}

app->start;
__DATA__
