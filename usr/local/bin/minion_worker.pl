#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use Encode::Locale;
use Encode;
use JSON;
use Capture::Tiny ':all';
use Digest::MD5 qw(md5_hex);
use FindBin;
use Minion;
use Env;
use Config::Simple;


$| = 1;
$ENV{MOJO_PUBSUB_EXPERIMENTAL} =1;


my %cnf;
Config::Simple->import_from("$HOME/.novel/config.ini", \%cnf);
$cnf{$_} = decode(locale => $cnf{$_}) for keys(%cnf);

our $minion = Minion->new(mysql => qq[mysql://$cnf{"db.usr"}:$cnf{"db.pwd"}\@$cnf{"db.host"}/minion]);
 
$minion->add_task( get_novel => \&get_novel_cmd );
$minion->add_task( get_lofter => \&get_lofter_cmd );

#$minion->perform_jobs;
#
my $worker = $minion->worker;
$worker->status->{jobs} = 3;
$worker->run;
#
1;

sub get_lofter_cmd {
my ($job, $task) = @_;
$task = encode( "utf8", $task );
my $r = decode_json( $task );

  print "$r->{w}, $r->{b}\n";
  my ( $c, $stderr ) = capture {
    system( qq[$cnf{"bin.run_novel"} -s lofter -w "$r->{w}" -b "$r->{b}" -t $r->{t} -T "$r->{T}" $cnf{"cmd.gmail"}] );
  };
  if (exists $r->{update} and $r->{update} eq 'on' ) {
    my ( $last_id ) = $c =~ m#last_item_num: (\d+)\n#s;
    $last_id ||= 0;
    my $note = md5_hex( encode( 'utf8', qq[lofter-$r->{w}-$r->{b}-$r->{m}] ) );


    my $sql = qq[insert into novel.update_novel(site,writer,book,last_item_num,mail,note,type,task) values(? , ? , ?, ?, ?, ?, ?, ?)] ;
    $minion->backend->mysql->db->query($sql, 'lofter', $r->{w}, $r->{b}, $last_id, $r->{m},$note, $r->{T}, $task);
  }

}

sub get_novel_cmd {
  my ( $job, $task ) = @_;
$task = encode( "utf8", $task );
my $r = decode_json( $task );

if($r->{u}!~/^http/){
    my $u = `$FindBin::RealBin/get_customsearch_novel.pl '$r->{u}'`;
    chomp($u);
    print "get_customsearch_novel: $u\n";
    $r->{u}=$u;
}

  my $cmd = qq[$cnf{"bin.run_novel"} ];
  $cmd .= join( " ", map { qq[ -$_ "$r->{$_}"] } grep { $r->{$_} } qw/u T t/ );

  $r->{$_} //='' for qw/min_item_num max_item_num min_page_num max_page_num/;
  $r->{i} = ( $r->{min_item_num} or $r->{max_item_num} ) ? "$r->{min_item_num}-$r->{max_item_num}" : '';
  $r->{j} = ( $r->{min_page_num} or $r->{max_page_num} ) ? "$r->{min_page_num}-$r->{max_page_num}" : '';
  $cmd .= join(" ", map { qq[ -$_ "$r->{$_}" ] } grep { $r->{$_} } qw/i p/); 
  $cmd .= join(" ", map { qq[ --$_ "$r->{$_}" ] } grep { $r->{$_} } qw/with_toc only_poster min_content_word_num grep_content filter_content/); 

  if ( $r->{t} ) {
    $cmd .= qq[ $cnf{"cmd.gmail"} ];
  } else {
    system(qq[mkdir -p '$cnf{"site.web_path"}']);
    $cmd .= qq[ -o $cnf{"site.web_path"} ];
  }
  print "$cmd\n";
  #$cmd = encode(locale => $cmd);

  system($cmd);
  #system(qq[/usr/bin/rsync -vazu --delete  -L $WEB_PATH/ root\@$WEB_S:$WEB_PATH] );

  if ( exists $r->{update} and $r->{update} eq 'on' ) {
    my $c = `/usr/local/bin/get_novel.pl -u "$r->{u}" -D 1`;
    chomp( $c );
    my @d = split /,/, $c;
    my ( $n ) = $d[-1];
    $n ||= 0;
    my $note = md5_hex( encode( 'utf8', qq[$r->{u}-$r->{t}] ) );

    my $sql = qq[insert into novel.update_novel(url,last_item_num,mail,note,writer,book,type, task) values(?, ?, ?, ?, ?,?, ?, ?)];
    print $sql,"\n";
    $minion->backend->mysql->db->query($sql, $r->{u}, $n, $r->{t},$note,$d[0],$d[1],$r->{T},$task);
  }
} ## end sub get_novel_cmd
