#file:Apache2/ImageRenderFilter.pm; 
#-------------------------------- 

#
# Created by Idel Fuschini 
# Date: 12/05/09
# Site: http://www.idelfuschini.it
# Mail: idel.fuschini@gmail.com



package Apache2::ImageRenderFilter; 
  
  use strict; 
  use warnings; 
  
  use Apache2::RequestRec ();
  use Apache2::RequestUtil ();
  use Apache2::SubRequest ();
  use Apache2::Log;
  use Apache2::Filter (); 
  use APR::Table (); 
  use LWP::Simple;
  use Image::Resize;
  use Apache2::Const -compile => qw(OK REDIRECT DECLINED);
  use IO::Uncompress::Unzip qw(unzip $UnzipError) ;
  use File::Copy;
  use constant BUFF_LEN => 1024;
  use CGI::Cookie ();


  #
  # Define the global environment
  # 

  use vars qw($VERSION);
  $VERSION= "2.01";
  my %Capability;
  my %Array_fb;
  my %Array_id;
  my %Array_fullua_id;
  my %Array_DDRcapability;

  my %XHTMLUrl;
  my %WMLUrl;
  my %CHTMLUrl;
  my %ImageType;
  my %cacheArray;
  my %cacheArray2;
  my %cacheArray_toview;
  

  my $intelliswitch="false";
  my $mobileversionurl;
  my $fullbrowserurl;
  my $cookieset="true";
  my $querystring="false";
  my $showdefaultvariable="false";
  my $wurflnetdownload="false";
  my $downloadwurflurl="false";
  my $convertimage="false";
  my $resizeimagedirectory="";
  my $downloadzipfile="true";
  my $virtualdirectoryimages="false";
  my $virtualdirectory="";
  my $convertonlyimages="false"; 
  my $repasshanlder=0;
  my $globalpassvariable="";
  my $log4wurfl="";
  my $loadwebpatch="false";
  my $dirwebpatch="";
  my $patchwurflnetdownload="false"; 
  my $patchwurflurl="";
  my $redirecttranscoder="true";
  my $redirecttranscoderurl="";
  my $detectaccuracy="false";
  my $listall="false";
  
  $ImageType{'png'}="png";
  $ImageType{'gif'}="gif";
  $ImageType{'jpg'}="jpg";
  $ImageType{'jpeg'}="jpeg";
  
  #
  # Check if MOBILE_HOME is setting in apache httpd.conf file for example:
  # PerlSetEnv MOBILE_HOME <apache_directory>/MobileFilter
  #
  printLog("---------------------------------------------------------------------------"); 
  printLog("ImageRenderFilter Version $VERSION");
  if ($ENV{MOBILE_HOME}) {
	  &loadConfigFile("$ENV{MOBILE_HOME}/WURFLFilterConfig.xml","$ENV{MOBILE_HOME}/wurfl.xml");
  } else {
	  printLog("MOBILE_HOME not exist.	Please set the variable MOBILE_HOME into httpd.conf");
	  ModPerl::Util::exit();
  }
sub Data {
    my $_sec;
	my $_min;
	my $_hour;
	my $_mday;
	my $_day;
	my $_mon;
	my $_year;
	my $_wday;
	my $_yday;
	my $_isdst;
	my $_data;
	($_sec,$_min,$_hour,$_mday,$_mon,$_year,$_wday,$_yday,$_isdst) = localtime(time);
	$_mon=$_mon+1;
	$_year=substr($_year,1);
	$_mon=&correct_number($_mon);
	$_mday=&correct_number($_mday);
	$_hour=&correct_number($_hour);
	$_min=&correct_number($_min);
	$_sec=&correct_number($_sec);
	$_data="$_mday/$_mon/$_year - $_hour:$_min:$_sec";
        return $_data;
}
sub correct_number {
  my ($number) = @_;
  if ($number < 10) {
      $number="0$number";
  } 
  return $number;
}
sub printLog {
	my ($info) = @_;
	my $data=Data();
	print "$data - $info\n";
}
sub loadConfigFile {
	     my ($file,$file2) = @_;
		 my $null="";
		 my $null2="";
		 my $null3="";
         my $val;
	     my $capability;
	     my $r_id;
	     my $dummy;
	      	#The filter
	      	printLog("Start read configuration from httpd.conf");
	      	 if ($ENV{ConvertImage}) {
				$convertimage=$ENV{ConvertImage};
				printLog("ConvertImage is: $convertimage");
			 }	
	      	 if ($ENV{ResizeImageDirectory}) {
				$resizeimagedirectory=$ENV{ResizeImageDirectory};
				printLog("ResizeImageDirectory is: $resizeimagedirectory");
			 }	
	      	 if ($ENV{WebAppConvertImages}) {
				$virtualdirectoryimages=$ENV{WebAppConvertImages};
				printLog("WebAppConvertImages is: $virtualdirectoryimages");
			 }	
	      	 if ($ENV{ConvertOnlyImages}) {
				$convertonlyimages=$ENV{ConvertOnlyImages};
				printLog("ConvertOnlyImages is: $convertonlyimages");
			 }	

	      
	    printLog("Finish loading  parameter");
}
sub readCookie {
    my ($cookie_search) = @_;
    my $param_tofound;
    my $string_tofound;
    my $value;
    my $width="0";
    my $height="0";
    my @pairs = split(/;/, $cookie_search);
    my $name;
    my $value;
    foreach $param_tofound (@pairs) {
       ($string_tofound,$value)=split(/=/, $param_tofound);
       if ($string_tofound eq "amf") {
         ($width,$height)=split(/\|/, $value);;
       }
    }   
    return ($width,$height);
}


sub handler    {
      my $f = shift;
      my $capability2;
      my $s = $f->r->server;
      my $variabile="";
      my $query_string=$f->r->args;
      my $uri = $f->r->uri();
      my ($content_type) = $uri =~ /\.(\w+)$/;
      my @fileArray = split(/\//, $uri);
      my $file=$fileArray[-1];
      my $docroot = $f->r->document_root();
      my $id="";
      my $method="";     
      my $location;
      my $width_toSearch;
      my $type_redirect="internal";
      my $return_value;
	  my $dummy="";
	  my $variabile2="";
	  my %ArrayCapFound;
	  my $controlCookie;
	  my $query_img="";
      my %ArrayQuery;
      my $var;
      my $cookie = $f->r->headers_in->{Cookie} || '';
      my ($width,$height)=readCookie($cookie);
      $repasshanlder=$repasshanlder + 1;
 	  #
 	  # Reading value of query string 
 	  #
 	  if ($query_string) {
		  my @vars = split(/&/, $query_string); 	  
		  foreach $var (sort @vars){
				   if ($var) {
						my ($v,$i) = split(/=/, $var);
						$v =~ tr/+/ /;
						$v =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
						$i =~ tr/+/ /;
						$i =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
						$i =~ s/<!--(.|\n)*-->//g;
						$ArrayQuery{$v}=$i;
					}
		  }
 	  }      
      if ($content_type) {
        $dummy="";
      } else {
         $content_type="-----";
      }
	  if ($ImageType{$content_type}) {
	          my $imageToConvert;
	          my $imagefile="";
	          if ($convertimage eq "true" && $variabile ne "device=false") {
				  if ($ArrayQuery{height}) {
				       if ( $ArrayQuery{height} =~ /^-?\d/) {
				       		$height=$ArrayQuery{height};
				       }
				  }
				  if ($ArrayQuery{width}) {
				       if ( $ArrayQuery{width} =~ /^-?\d/) {
				       		$width=$ArrayQuery{width};
				       }
				  }

				  if ($ArrayQuery{dim}) {
				       if ( $ArrayQuery{dim} =~ /^-?\d/) {
				       		$width=$ArrayQuery{dim} * $width / 100;
				       }
				  }
       $s->warn("($width,$height)");


				  $imagefile="$resizeimagedirectory/$width.$file";
				  #
				  # control if image exist
				  #
				 
				  if ($virtualdirectoryimages eq 'true') {
				     $imageToConvert="$virtualdirectory$uri";
				  } else {
				     $imageToConvert="$docroot$uri";
				  }
				  $return_value=Apache2::Const::DECLINED;
				  if ( -e "$imageToConvert") {
					  if ( -e "$docroot$imagefile") {
						$dummy="";
					  } else { 
						  my $image = Image::Resize->new("$imageToConvert");
						  my $gd = $image->resize($width, $height);
						  if (open(FH, ">$docroot$imagefile")) {
							if ($content_type eq "gif") {
								print FH $gd->gif();
							}
							if ($content_type eq "jpg") {
								print FH $gd->jpeg();
							}
							if ($content_type eq "png") {
								print FH $gd->png();
							}
						  close(FH);
						  } else {
					         $s->err("Can not create $docroot$imagefile");
					      }
					  }
					  $f->r->internal_redirect($imagefile);
					  $return_value=Apache2::Const::DECLINED;	  	
				  }
              } else {
                 if ( -e "$resizeimagedirectory/$file") {
						$dummy="";
				  } else {
						  if ($virtualdirectoryimages eq 'true') {
							 $imageToConvert="$virtualdirectory$uri";
						  } else {
							 $imageToConvert="$docroot$uri";
						  }			  
                  		copy($imageToConvert, "$docroot$resizeimagedirectory");
                  }
				  
                  $f->r->internal_redirect("$resizeimagedirectory/$file");
                  $return_value=Apache2::Const::OK;	
              }			  
	  }
      return $return_value;
      
} 

  1; 
=head1 NAME

Apache2::ImageRenderFilter - is a Apache Mobile Filter that manage image to the correct mobile device


=head1 COREQUISITES

CGI
Apache2
Image::Resize;


=head1 DESCRIPTION

This module have the scope to manage with Apache2::WURFLFilter module the images for mobile devices. 

For more details: http://www.idelfuschini.it/apache-mobile-filter-v2x.html

NOTE: this software need wurfl.xml you can download it directly from this site: http://wurfl.sourceforge.net or you canset the filter to download it directly.


=cut
