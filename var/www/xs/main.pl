#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use JSON;
use Mojo::Template;
use Mojolicious::Lite;
use Mojolicious::Static;
use POSIX qw/strftime/;
use Encode;

plugin Minion => {mysql => 'mysql://mydbusr:mydbpwd@localhost/minion'};

## config {{
our $BARE_PWD = 'mypwd';
## }}

my $static = app->static();
push @{ $static->paths }, "$FindBin::RealBin/static";

get '/' => sub {
  my $self = shift;
  $self->render( template => 'index', format => 'html', handler => 'ep' );
};

post '/get_lofter' => sub {
  my $self = shift;
  my %s = check_param( $self, [qw/w b m update/], $BARE_PWD );
  return unless ( %s );
  if ( !$s{w} or !$s{b} ) {
    $self->render( text => 'arg error' );
  }

  my $text = add_novel_task( \%s );
  $self->minion->enqueue(get_lofter =>[$text]);
  $self->render( text => "<pre>$text</pre>" );
};

post '/get_novel' => sub {
  my $self = shift;

  my @fields = qw/u T t
    with_toc only_poster min_content_word_num grep_content filter_content
    min_page_num max_page_num
    min_item_num max_item_num
    update
    /;
  my %opt = check_param( $self, \@fields, $BARE_PWD );
  return unless ( %opt );
  if ( !$opt{url} ) {
    $self->render( text => 'arg error' );
  }

  my $text = add_novel_task( \%opt );
  $self->minion->enqueue(get_novel =>[$text]);
  $self->render( text => "<pre>$text</pre>" );

};

############start sub {

sub add_novel_task {
  my ( $task ) = @_;
  my $task_info = decode( "utf8", encode_json( $task ) );
  return $task_info;
}

sub check_param {
  my ( $self, $field_list, $check_pwd ) = @_;

  if ( defined( $check_pwd ) ) {
    my $pwd = $self->param( 'pwd' );
    return unless ( $pwd eq $check_pwd );
  }

  my %x;
  for my $f ( @$field_list ) {
    my $v = $self->param( $f ) // '';
    next unless ( $v and $v !~ /[{}\[\]\(\);'"<>|]/ );
    $x{$f} = $v;
  }
  return %x;
}

# }

app->start;

__DATA__

@@ index.html.ep
<html>
<head>
<meta http-equiv=Content-Type content="text/html;charset=utf-8">
<link rel="stylesheet" href="css/style.css" />
<title>小说</title>
</head>
<body>
    <center><h1>小说</h1></center>

<div class="form" id="novel">
<div class="form_title">下载</div>
<form method="POST" action="/get_novel" target="_blank">
URL<input name="u" size="70" value="" />，密码<input name="pwd" value="" />
目标格式&nbsp;&nbsp; <select name="T">
<option value="mobi" selected="selected">mobi</option>
<option value="html">html</option>
<option value="txt">txt</option>
<option value="epub">epub</option>
</select>
<br />
推送邮箱<input name="t" size="70" value="" />
, <input type="checkbox" name="only_poster">只看楼主，<input type="checkbox" name="with_toc" value="1" checked>生成目录
<br />
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;页码 <input name="min_page_num" size="3"/>-<input name="max_page_num" size="3"/>，章节/楼层 <input name="min_item_num" size="3"/>-<input name="max_item_num" size="3"/>，每楼最少<input name="min_content_word_num" size="3"/>字，<input type="checkbox" name="update">自动追文
<br />
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;提取<input name="grep_content" size="30" value="" />，过滤<input name="filter_content" size="30" value="" />
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type="submit" value="执行" />
</form>
<p> 说明：推送kindle的来源邮箱需要在亚马逊设置为信任来源</p>
<p> 说明：多个目标推送邮箱以英文逗号隔开，例如 xxx@yy.com,aaa@bb.com</p>
<p> 说明：如果不指定推送邮箱，则根据指定目标格式，下载到<a href="http://web.myebookserver.com/ebook">ebook</a>目录</p>
</div>

<div class="form" id="novel">
<div class="form_title">网易lofter</div>
<form method="POST" action="/get_lofter" target="_blank">
<p>专栏ID<input name="w" size="20" value="" />.lofter.com, 密码<input name="pwd" value="" /></p>
<p>关键词<input name="b" size="30" value="" />，<input type="checkbox" name="update">自动追文</p>
<p>目标邮箱<input name="m" size="30" value="" /></p>
<p><input type="submit" value="推送" /></p>
</form>
</div>

</body>
</html>
