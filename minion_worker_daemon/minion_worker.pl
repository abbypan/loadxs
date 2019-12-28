#!/usr/bin/perl
use strict;
use warnings;

use utf8;

use Encode::Locale;
use Encode;
use JSON;
use Capture::Tiny ':all';
use Digest::MD5 qw(md5_hex);


$| = 1;

use Minion;

## config {{
my $h = "mail.myebookserver.com";
#our $MAIL_S = " -S '-f kindle\@myebookserver.com' -h $h";
our $MAIL_S = " -S '-f kindle\@myebookserver.com' ";
our $WEB_S = 'web.myebookserver.com';
our $WEB_PATH = '/var/www/html/ebook';
## }}
 
 our $minion = Minion->new(mysql => 'mysql://mydbusr:mydbpwd@localhost/minion');
#  
#  # Add tasks
$minion->add_task( get_novel => \&get_novel_cmd );

$minion->add_task(get_lofter => \&get_lofter_cmd);

#$minion->perform_jobs;

my $worker = $minion->worker;
$worker->status->{jobs} = 3;
$worker->run;


sub get_lofter_cmd {
my ($job, $task) = @_;
my $r = decode_json( encode( "utf8", $task ) );

  print "$r->{w}, $r->{b}\n";
  my ( $c, $stderr ) = capture {
    system( qq[/usr/local/bin/run_novel.pl -s lofter -w "$r->{w}" -b "$r->{b}" -T txt -t "$r->{m}" $MAIL_S] );
  };
  if (exists $r->{update} and $r->{update} eq 'on' ) {
    my ( $last_id ) = $c =~ m#last_floor_num: (\d+)\n#s;
    $last_id ||= 0;
    my $note = md5_hex( encode( 'utf8', qq[lofter-$r->{w}-$r->{b}-$r->{m}] ) );


    my $sql = qq[insert into novel.update_novel(site,writer,book,novel_id,mail,note) values('lofter', "$r->{w}", "$r->{b}", $last_id, "$r->{m}",'$note')] ;
    $minion->backend->mysql->db->query($sql);
  }

}

sub get_novel_cmd {
  my ( $job, $task ) = @_;
my $r = decode_json( encode( "utf8", $task ) );
  my $cmd = '/usr/local/bin/run_novel.pl ';
  $cmd .= join( " ", map { qq[ -$_ "$r->{$_}"] } grep { $r->{$_} } qw/u T t/ );
  $r->{i} = ( $r->{min_item_num} or $r->{max_item_num} ) ? "$r->{min_item_num}-$r->{max_item_num}" : '';
  $r->{p} = ( $r->{min_page_num} or $r->{max_page_num} ) ? "$r->{min_page_num}-$r->{max_page_num}" : '';
  $cmd .= " -G '";
  $cmd .= join(" ", map { qq[ -$_ "$r->{$_}" ] } grep { $r->{$_} } qw/i p/); 
  $cmd .= join(" ", map { qq[ --$_ "$r->{$_}" ] } grep { $r->{$_} } qw/with_toc only_poster min_content_word_num grep_content filter_content/); 
  $cmd .= " ' ";

  if ( $r->{t} ) {
    $cmd .= $MAIL_S;
  } else {
    $cmd .= qq[ -o $WEB_PATH/ ];
  }
  print "$cmd\n";
  system($cmd);
  system(qq[mkdir -p "$WEB_PATH"]);
  #system(qq[/usr/bin/rsync -vazu --delete  -L $WEB_PATH/ root\@$WEB_S:$WEB_PATH] );

  if ( exists $r->{update} and $r->{update} eq 'on' ) {
    my $c = `get_novel.pl -u "$r->{u}" -D 1`;
    chomp( $c );
    my @d = split /,/, $c;
    my ( $n ) = $d[-1];
    $n ||= 0;
    my $note = md5_hex( encode( 'utf8', qq[$r->{u}-$r->{t}] ) );

    my $sql = qq[insert into novel.update_novel(url,novel_id,mail,note,writer,book) values("$r->{u}", "$n", "$r->{t}",'$note','$d[0]','$d[1]')];
    $minion->backend->mysql->db->query($sql);
  }
} ## end sub get_novel_cmd
