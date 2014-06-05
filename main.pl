#!/usr/bin/perl
use Mojolicious::Lite;
use Mojolicious::Static;
use Mojo::Template;

use Encode;
use Encode::Locale;
use File::Temp qw/tempfile /;
use File::Slurp;
use Novel::Robot;

## DEFAULT {{
use FindBin;
our $STATIC_PATH = "$FindBin::RealBin/static";
our $MUSIC_PATH  = "$FindBin::RealBin/../baidu_music/baidu_music.pl";
our $MUSIC_BIN   = qq[export LC_ALL=zh_CN.UTF-8 && sudo perl $MUSIC_PATH ];
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

post '/novel_robot' => sub {
    my $self = shift;
    my $url  = $self->param('url');
    my $type = $self->param('type');

    my @fields = qw/with_toc
      only_poster
      min_tiezi_page max_tiezi_page
      max_tiezi_floor_num
      min_floor_word_num
      mail
      /;
    my %opt;

    for my $f (@fields) {
        $opt{$f} = $self->param($f) // undef;
    }

    my $err = qr/['"<>|]/;
    my $err_flag = grep  { /$err/ } ($url,$type, values(%opt));
    if($err_flag){
        $self->render( text => 'arg error' );
    }

    $opt{min_chapter_num} = $opt{min_tiezi_page};
    $opt{max_chapter_num} = $opt{max_tiezi_page};

    my $xs = Novel::Robot->new(
        site => $url,
        type => ( $type=~/^(web|mobi)$/) ? 'html' : $type,
    );

    my $html = 'fail';
    my ( $data, $inf ) = $xs->get_item( $url, %opt, output_scalar => 1, );
    $data ||= \$html;

    if ( $opt{mail} ) {
        my $res = send_mobi_mail( $data, $inf, %opt ) || '*** fail ***';
        $self->render( text =>
              "$inf->{writer}  $inf->{title} => $opt{mail}\n
              <br><pre>$res</pre>" );
    }elsif($type eq 'mobi'){
        my $bin = send_mobi( $data, $inf) || '';
        my $file =
          encode( "utf8",
            format_filename("$inf->{writer}-$inf->{book}.mobi") );
        $self->res->headers->content_type("application/octet-stream");
        $self->res->headers->content_disposition(
            qq[attachment;filename="$file"]);
        $self->render( data => $bin, format => "mobi" );
    }
    elsif ( $type eq 'web' ) {
        $self->render( text => $$data );
    }
    else {
        my $format = $type eq 'jekyll' ? 'md' : $type;
        my $file =
          encode( "utf8",
            format_filename("$inf->{writer}-$inf->{book}.$format") );
        $self->res->headers->content_disposition(
            qq[attachment;filename="$file"]);
        $self->render( text => $$data, format => $format );
    }
};

sub make_mobi {
    my ($h , $r ) = @_;
    $r->{title} ||= $r->{book};


    my  $f_html = "/tmp/kindle-".int(rand(9999999999)).".html";
    open my $fh, '>:utf8', $f_html;
    print $fh $$h;
    close $fh;

    my %conv = (
        'authors'            => $r->{writer},
        'title'              => $r->{title},
        'chapter-mark'       => "none",
        'page-breaks-before' => "/",
        'max-toc-links'      => 0,
    );
    my $conv_str = join( " ", map { qq[--$_ "$conv{$_}"] } keys(%conv) );

    my  $f_mobi = "/tmp/kindle-".int(rand(9999999999)).".mobi";
    my $cmd = encode("utf8", qq[export LC_ALL=zh_CN.UTF-8 && ebook-convert "$f_html" "$f_mobi" $conv_str]);
    `$cmd`;
    unlink($f_html);
    return $f_mobi;
}

sub send_mobi {
#
    my ( $h, $r) = @_;
    my $f_mobi = make_mobi($h, $r);
    my $bin = read_file($f_mobi,  binmode => ':raw' );
    unlink($f_mobi);
    return $bin;
}

sub send_mobi_mail {
    my ( $h, $r, %opt ) = @_;

    my $res;
    $res.="html content length : ".length($$h)."<br><br>";

    my $f_mobi = make_mobi($h, $r);

    my $s_cmd =
qq[export LC_ALL=zh_CN.UTF-8 && sendemail -vv -f 'kindle\@idouzi.tk' -t '$opt{mail}' -a $f_mobi -u '$r->{writer} $r->{title}' -m '$r->{url}'];

    $s_cmd = encode( "utf8", $s_cmd );
    $res .= `$s_cmd`;

    unlink($f_mobi);

    return decode("utf8", $res);
}

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

    #$cmd = encode( locale => $cmd );
    return $cmd;
}

sub get_music_data {
    my ( $self, $cmd ) = @_;
    my ( $fh, $filename ) = tempfile( 'music-XXXXXXXXXX', TMPDIR => 1 );

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
