use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'loadxs',
    AUTHOR              => q{Abby Pan <abbypan@gmail.com>},
    VERSION_FROM        => 'lib/loadxs.pm',
    ABSTRACT            => 'LOAD NOVEL TO WORDPRESS',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
      'Test::More' => 0,
      'YAML'       => 0,
      'Dancer'     => 0,
      'Plack' => 0, 
      'Novel::Robot' => 0,
      'HTML::ElementTable' => 0, 
      'Dancer::Plugin::Database' => 0, 
      'JSON' => 0, 
      'DBI'=>0, 
      'DBD::mysql'=> 0, 
      'WordPress::XMLRPC'=>0, 
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'loadxs-*' },
);
