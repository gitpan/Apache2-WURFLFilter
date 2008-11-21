use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
  print << 'EOT1';
  
Mobile Apcache Filter (ifuschini@cpan.org)

EOT1
WriteMakefile(
    NAME		=> 'Apache2::WURFLFilter',
    VERSION_FROM	=> 'lib/Apache2/WURFLFilter.pm',
    DISTNAME	=> "Apache2-WURFLFilter",
    dist		=> {COMPRESS => 'gzip', SUFFIX => 'gz'},
    PREREQ_PM    => {
                     'Apache2::Filter'      => 0,
                     'Apache2::RequestRec'      => 0,
                     'Apache2::RequestUtil' => 0,
                     'CGI::Cookie'      => 0, 
                     'Text::LevenshteinXS'  => 0, 
                     'APR::Table'        => 0, 
                     'Apache2::Const'        => 0, 
                     'LWP::Simple'        => 0 
                     },
    AUTHOR     	=> 'Idel Fuschini (ifuschini@cpan.org)' 
   
);
