#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use POSIX qw/strftime/;
use FindBin;
use Encode;
use Encode::Locale;



use Config::Simple;

my %cnf;
Config::Simple->import_from("$FindBin::RealBin/novel.ini", \%cnf);
$cnf{$_} = decode(locale => $cnf{$_}) for keys(%cnf);

#my $h;
#$h = "mail.myebookserver.com";
#our $MAIL_S = " -S '-f kindle\@myebookserver.com' -h $h";
#our $MAIL_S = q[ -S "-f kindle@myebookserver.com -o tls=no"];
#our $MAIL_S = q[ -S "-vv -f someusr\@qq.com -s smtp.qq.com:587 -o tls=yes -xu someusr -xp xxxxxxxxxxxxxxxx"];

my ($url, $mail, @args) = @ARGV;
$mail ||= $cnf{"mailbox.default_recv"};
$args[0] ||='';

if(-f $url){
    #system(qq[ansible $h -m copy -a 'src=$url dest=/tmp/']);
    my $msg = defined $args[1] ? "$args[0]-$args[1]" : "$url";
    #my $cmd = qq[sendEmail -u "$msg" -m "$msg" -o "message-charset=utf-8" -a "$url" -t "$mail" $MAIL_S];
    #system(qq[ansible $h -m shell -a '$cmd']);
    #system(qq[ansible $h -m shell -a 'rm $url']);
    my $cmd = qq[$cnf{"bin.send_email"} -vv -u "$msg" -m "$msg" -o "message-charset=utf-8" -a "$url" -t "$mail" -f $cnf{"mailbox.default_send"} -o tls=no];
    system($cmd);
}else{
    if($url!~/http/){
    print $cnf{"bin.customsearch_novel"} , " $url\n";
        $url=`$cnf{"bin.customsearch_novel"} $url`;
    print $url, "\n";
        chomp($url);
    }
    system(qq[$cnf{"bin.run_novel"} -u "$url" -T azw3 -t "$mail" -G '$args[0]' $cnf{"cmd.mail"}]) if($url=~/http/);
}
