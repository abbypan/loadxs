#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use POSIX qw/strftime/;
use FindBin;
use Encode;
use Encode::Locale;
use Config::Simple;
use Env;

my %cnf;
Config::Simple->import_from("$HOME/.novel/config.ini", \%cnf);
$cnf{$_} = decode(locale => $cnf{$_}) for keys(%cnf);

my ($url, $mail, @args) = @ARGV;
$mail ||= $cnf{"mailbox.default_recv"};
$args[0] ||='';

if(-f $url){
    #system(qq[ansible $h -m copy -a 'src=$url dest=/tmp/']);
    my $msg = defined $args[1] ? "$args[0]-$args[1]" : "$url";
    #system(qq[ansible $h -m shell -a '$cmd']);
    #system(qq[ansible $h -m shell -a 'rm $url']);
    
    my $cmd = qq[$cnf{"bin.send_email"} -m "$msg" -f "$url" -T "$mail"  $cnf{"cmd.gmail"} ];
    system($cmd);
}else{
    if($url!~/http/){
    print $cnf{"bin.customsearch_novel"} , " $url\n";
        $url=`$cnf{"bin.customsearch_novel"} $url`;
    print $url, "\n";
        chomp($url);
    }
    system(qq[$cnf{"bin.run_novel"} -u "$url" -t $cnf{"ebook.type"} -T "$mail" $args[0] $cnf{"cmd.gmail"}]) if($url=~/http/);
}
