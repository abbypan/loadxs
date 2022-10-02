#!/usr/bin/perl
use utf8;
use Encode;
use Encode::Locale;
use JSON;
use Data::Dumper;
use FindBin;
use Config::Simple;

my %cnf;
Config::Simple->import_from("$FindBin::RealBin/novel.ini", \%cnf);
$cnf{$_} = decode(locale => $cnf{$_}) for keys(%cnf);

my $base_url = qq[https://www.googleapis.com/customsearch/v1?cx=$cnf{"cse.cx"}&key=$cnf{"cse.key"}&num=10&q=];

my ( $query ) =  @ARGV;

$query = decode(locale=>$query);
my $query_full=qq[《$query》正文 $cnf{"cse.words"}];
print $query_full, "\n";
my $query_s = uc( unpack( "H*", encode( "utf8", $query_full ) ) );
$query_s =~ s/(..)/%$1/g;

my @final;
my $i=1;
while($i<31){
my $url = $base_url.$query_s."&start=$i";

#print $url,"\n";
my $c=`/usr/bin/curl -s '$url'`;
#print $c, "\n";
my $r = decode_json $c;
my @url_list = grep { /http/ and ! m#//m.# and /^\S+$/ } map { $_->{htmlFormattedUrl} } @{$r->{items}};
#print Dumper(\@url_list);

for my $u (@url_list){
    my $info =decode(locale => `$cnf{"bin.get_novel"} -u '$u' -D 1`);
    next unless($info=~/$query/);
    my ($writer, $book, $x, $num) = split /,/, $info;
    push @final, [$writer, $book, $u, $num];
}

$i+=10;
}

my @sort_final = sort { $b->[3] <=> $a->[3] } @final;
print $sort_final[1][2], "\n";
