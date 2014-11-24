#!/usr/bin/perl
use Novel::Robot;
use HTTP::Tiny;
use SimpleR::Reshape;
use SimpleDBI::mysql;
use Encode;
use Data::Dumper;
use utf8;

our $SERVER = 'http://xxx.xxx.com/novel_robot';
our $MYSQL = SimpleDBI::mysql->new(
    db     => 'somedb',
    host   => '127.0.0.1',
    usr    => 'someusr',
    passwd => 'somepw',
);

my $data = $MYSQL->query_db('select url,novel_id,mail from push_to_kindle', 
    result_type => 'arrayref', 
);

for my $r (@$data){
    my ($url, $id, $mail)=@$r;
    $r = [ upload_novel_to_kpw($url, $id, $mail) ];
    $MYSQL->{dbh}->do(qq{update push_to_kindle set novel_id=$r->[1],note='$r->[3]' where url='$r->[0]' and mail='$r->[2]'});
}

sub upload_novel_to_kpw {
    my ($url, $id, $mail) = @_;
    print "check $url, $id, $mail\n";

    my $xs = Novel::Robot->new(site => $url);
    my $parser = $xs->{parser};
    my $r = $parser->get_index_ref($url);
    my $list = $r->{chapter_list};

    my ($min, $max);
    for my $i ( 0 .. $#$list){
        my $x = $list->[$i];
        my $j = $i+1;
        $j = $x->{id} if($x->{id});

        next if($j<=$id);
        $min = $j if(!$min);
        $max = $j;
    }

    return ($url, $id, $mail) unless($min and $max);

    send_to_kindle({ 
            mail =>$mail, 
            url =>$url,  
            min=>$min, 
            max =>$max,
        });
    return ($url, $max, $mail, "$r->{writer} $r->{book}");
}

sub send_to_kindle {
    my ($r) = @_;
    print "send to kindle: $r->{url}, $r->{min}, $r->{max}\n";
    my $http = HTTP::Tiny->new();
    my $response = $http->post_form($SERVER, {
            url => $r->{url}, 
            mail => $r->{mail}, 
            min_tiezi_page=>$r->{min}, 
            max_tiezi_page =>$r->{max},
            type =>'mobi',
        });
    my $c =$response->{content}; 
    print "$c\n";
    return;
}
