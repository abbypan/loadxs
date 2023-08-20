#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use DBI;
use Encode;
use Encode::Locale;
use Capture::Tiny ':all';
use FindBin;
use Config::Simple;
use Env;

my %cnf;
Config::Simple->import_from("$HOME/.novel/config.ini", \%cnf);
$cnf{$_} = decode(locale => $cnf{$_}) for keys(%cnf);

## config {{
my $dbh = DBI->connect(qq[DBI:mysql:database=novel;host=$cnf{"db.host"}],
    $cnf{"db.usr"}, $cnf{"db.pwd"}, 
    { 'RaiseError' => 1, PrintError => 1, mysql_enable_utf8=> 1 }, 
);
 
my $dbh2 = DBI->connect("DBI:mysql:database=novel;host=$cnf{'db.host'}",
    $cnf{'db.usr'}, $cnf{'db.pwd'}, 
                       { 'RaiseError' => 1, PrintError => 1, mysql_enable_utf8=> 1 }, 
);
## }}
                   

my $sth = $dbh->prepare("select url,last_item_num,mail,site,writer,book,type,task from update_novel");
    
$sth->execute();
while (my $r = $sth->fetchrow_hashref()) {
    my $id = $r->{last_item_num} // 0;
    $id++;


  my $cmd=$cnf{"bin.run_novel"};
  if ( $r->{url} ) {
    $cmd .= qq[ -u "$r->{url}"];
    $cmd.=" -b '$r->{book}（追文）' " if($r->{book});
  } else {
    $cmd .= qq[ -s "$r->{site}" -w "$r->{writer}" -b "$r->{book}"];
  }

  $cmd.= qq[ -t $r->{type} -v 0 -i $id- ];

  if($r->{mail}){
      $cmd .= qq[-T "$r->{mail}"  $cnf{"cmd.gmail"}];
  }else{
      $cmd .= qq[-o '$cnf{"site.web_path"}'];
  }

  print encode(locale => $cmd), "\n";

  my ($stdout, $stderr, $exit) = capture {
      #    system( $cmd, @args );
      system($cmd);
  };

  my $c = "$stdout\n$stderr\n$exit\n";
  print "system cmd out:\n$c\n";
  my ( $last_id ) = $c =~ m#last_item_num:\s+(\d+)\n#s;
  next unless ( $last_id );
  print "find last_item_num: $last_id, pre id + 1: $id\n";
  next unless($last_id>=$id);

my $do_cmd ; 
  if ( $r->{url} ) {
    $c = decode( locale => $c );
    ( $r->{writer}, $r->{book} ) = $c =~ m#send ebook : (.+?)\s*《(.+?)》#s unless ( $r->{writer} =~ /\S/ and $r->{book} =~ /\S/ );
    
    $do_cmd=qq{update update_novel set last_item_num=$last_id,writer='$r->{writer}',book='$r->{book}' where url='$r->{url}' and mail='$r->{mail}'} ;
} else {
    $do_cmd=qq{update update_novel set last_item_num=$last_id where site='$r->{site}' and writer='$r->{writer}' and book='$r->{book}' and mail='$r->{mail}'} ;
  }
print encode(locale =>$do_cmd),"\n";
$dbh2->do($do_cmd);
  print "\n";
}
$sth->finish();
