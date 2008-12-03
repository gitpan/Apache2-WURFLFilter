#file:Apache2/WURFLFilter.pm; 
#-------------------------------- 

#
# Created by Idel Fuschini 
# Date: 21/11/08
# Site: http://www.idelfuschini.it
# Mail: ifuschini@cpan.org


package Apache2::WURFLFilter; 
  
  use strict; 
  use warnings; 
  
  use Apache2::Filter (); 
  use Apache2::RequestRec ();
  use Apache2::RequestUtil ();
  use Apache2::SubRequest ();
  use Apache2::Log;
  use CGI::Cookie ();
  use Text::LevenshteinXS qw(distance);
  use APR::Table (); 
  use LWP::Simple;
  use Image::Resize;
  use Apache2::Const -compile => qw(OK REDIRECT DECLINED);
  #
  # Define the global environment
  # 

  use vars qw($VERSION);
  $VERSION= 0.5;
  my %Capability;
  my %Array_fb;
  my %Array_id;
  my %Array_DDRcapability;
  my %XHTMLUrl;
  my %WMLUrl;
  my %ImageType;
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
  
  
  
  $ImageType{'png'}="png";
  $ImageType{'gif'}="gif";
  $ImageType{'jpg'}="jpg";
  $ImageType{'jpeg'}="jpeg";
  $Capability{'resolution_width'}="resolution_width";
  $Capability{'is_wireless_device'}="is_wireless_device";
  $Capability{'device_claims_web_support'}="device_claims_web_support";
  $Capability{'xhtml_support_level'}="xhtml_support_level";
  #
  # Check if MOBILE_HOME is setting in apache httpd.conf file for example:
  # PerlSetEnv MOBILE_HOME <apache_directory>/MobileFilter
  #
   printLog("WURFLFilter Version $VERSION");
  if ($ENV{MOBILE_HOME}) {
	  &loadConfigFile("$ENV{MOBILE_HOME}/WURFLFilterConfig.xml","$ENV{MOBILE_HOME}/wurfl.xml");
  } else {
	  printLog("MOBILE_HOME not exist.	Please set the variable MOBILE_HOME into httpd.conf");
	  ModPerl::Util::exit();
  }

sub loadConfigFile {
	     my ($file,$file2) = @_;
		 my $null="";
		 my $null2="";
		 my $null3="";
         my $val;
	     my $capability;
	     my $r_id;
		 if (-e "$file") {
			 printLog("Loading  WURFLMobile.config");
			 open (IN, "$file");
				 while (<IN>) {
					 if ($_ =~ /\<capability\>/o) {
						$capability=extValueTag('capability',$_);
						$Capability{$capability}=$capability;			  
					 }
					 if ($_ =~ /\<MobileVersionUrl\>/o) {
						$mobileversionurl=extValueTag('MobileVersionUrl',$_);
					 }			
					 if ($_ =~ /\<IntelliSwitch\>/o) {
						$intelliswitch=extValueTag('IntelliSwitch',$_);
					 }
					 if ($_ =~ /\<XHTMLUrl/o) {
						$capability=extValueTag('XHTMLUrl',$_);
						($null,$val,$null2)=split(/\"/, $_);
						$XHTMLUrl{$val}=$capability;				   
					 }				
					 if ($_ =~ /\<WMLUrl/o) {
						$capability=extValueTag('WMLUrl',$_);
						($null,$val,$null2)=split(/\"/, $_);
						$WMLUrl{$val}=$capability;				   
					 }				
					
					 if ($_ =~ /\<FullBrowserUrl\>/o) {
						$fullbrowserurl=extValueTag('FullBrowserUrl',$_);
					 }			
					 if ($_ =~ /\<CookieSet\>/o) {
						$cookieset=extValueTag('CookieSet',$_);
					 }			
					 if ($_ =~ /\<PassQueryStringSet\>/o) {
						$querystring=extValueTag('PassQueryStringSet',$_);
					 }			
					 if ($_ =~ /\<ShowDefaultVariable\>/o) {
						$showdefaultvariable=extValueTag('ShowDefaultVariable',$_);
					 }			
					 if ($_ =~ /\<WurflNetDownload\>/o) {
						$wurflnetdownload=extValueTag('WurflNetDownload',$_);
					 }			
					 if ($_ =~ /\<DownloadWurflURL\>/o) {
						$downloadwurflurl=extValueTag('DownloadWurflURL',$_);
					 }			
					 if ($_ =~ /\<ConvertImage\>/o) {
						$convertimage=extValueTag('ConvertImage',$_);
					 }			
					 if ($_ =~ /\<ResizeImageDirectory\>/o) {
						$resizeimagedirectory=extValueTag('ResizeImageDirectory',$_);
					 }			


			 }				
			 
		 } else {
		   printLog("File $file not found");
		   ModPerl::Util::exit();
	      }
	      close IN;
	    if ($wurflnetdownload eq "true") {
	        printLog("Start downloading  WURFL.xml from $downloadwurflurl");
	        my $content = get $downloadwurflurl;
	        printLog("Finish downloading  WURFL.xml");
	        if ($content eq "") {
   		        printLog("Couldn't get $downloadwurflurl. Errore:$content");
		   		ModPerl::Util::exit();
	        }
            my @rows = split(/\n/, $content);
            my $row;
            my $count=0;
            foreach $row (@rows){
                $r_id=parseWURFLFile($row,$r_id);
            }
	    } else {
			if (-e "$file2") {
					printLog("Start loading  WURFL.xml");
					open (IN,"$file2");
					while (<IN>) {
					     $r_id=parseWURFLFile($_,$r_id);
					     
					}
					close IN;
			} else {
			  printLog("File $file2 not found");
			  ModPerl::Util::exit();
			}
		}
		close IN;
        printLog("End loading  WURFL.xml");
}
sub internalParseTag {
         my ($tag, $parameter) = @_;
         $tag=substr($tag, index($tag,'<'),index($tag,'>'));
         
         
         
}
sub parseWURFLFile {
         my ($record,$val) = @_;
		 my $null="";
		 my $null2="";
		 my $null3="";
		 my $ua="";
		 my $fb="";
		 my $value="";
		 my $id;
		 if ($val) {
		    $id="$val";
		 } else {
		    $id="";
		 }
		 my $name="";
	      if ($record =~ /\<device/o) {
			($null,$id,$null2,$ua,$null3,$fb)=split(/\"/, $record);
			 if ($id) {
				 if ($fb) {	     	   
					$Array_fb{"$id"}=$fb;
				 }
				 if ($ua) {
					 if ($id) {	     	   
						 $Array_id{"$ua"}=$id;
					 }
				 }
			 }
		 }
		 if ($record =~ /\<capability/o) { 
			    #print "eccomi $val\n";
			($null,$name,$null2,$value,$null3,$fb)=split(/\"/, $record);
			if ($id) {
                if ($Capability{$name}) {			
					if ($name) {
						if ($value) {
							$Array_DDRcapability{"$val|$name"}=$value;
						}
					}
				}
			}
		 }
		 return $id;

}
sub extValueTag {
   my ($tag,$string) = @_;
   my $a_tag="\<$tag";
   my $b_tag="\<\/$tag\>";
   my $finish=index($string,"\>") + 1;
   my $x=$finish;
   my $y=index($string,$b_tag);
   my $return_tag=substr($string,$x,$y - $x);
  
   return $return_tag;
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

sub FallBack {
  my ($idToFind) = @_;
  my $dummy_id;
  my $dummy;
  my $dummy2;
  my $LOOP;
  my %ArrayCapFoundToPass;
  my $capability;
   foreach $capability (sort keys %Capability) {
        $dummy_id=$idToFind;
        $LOOP=0;
   		while ($LOOP==0) {   		    
   		    $dummy="$dummy_id|$capability";
        	if ($Array_DDRcapability{$dummy}) {        	  
        	   $LOOP=1;
        	   $dummy2="$dummy_id|$capability";
        	   $ArrayCapFoundToPass{$capability}=$Array_DDRcapability{$dummy2};
        	} else {
	        	  $dummy_id=$Array_fb{$dummy_id};        
	        	  if ($dummy_id eq "root") {
	        	    $LOOP=1;
	        	  }
        	}   
   		}
   		
}
   return %ArrayCapFoundToPass;

}

sub FirstMethod {
  my ($UserAgent) = @_;
  my $ind=0;
  my %ArrayPM;
  my $pair;
  my $pair2;
  my $id_find="";
  
  my @pairs = split(/\ /, $UserAgent);
  $ArrayPM{0}="";
  foreach $pair (@pairs)
  {
       
       if ($ind == 0) {
            $ArrayPM{$ind}=$pair;
	          $ind=$ind+1;
       } else {
         my @pairs2 = split(/\//, $pair);
         my $count=0;
         if ($pair =~ /\//o) {
	         foreach $pair2 (@pairs2)
    	     {
        	   if ($count == 0) {
            	$ArrayPM{$ind}="$ArrayPM{$ind-1} $pair2";
     	    	$ind=$ind+1;
        	   } else {
            	$ArrayPM{$ind}="$ArrayPM{$ind-1}/$pair2";
     	    	$ind=$ind+1;
     	   	 	}
     	       $count=$count+1;
         	 }
         } else {
	         $ArrayPM{$ind}="$ArrayPM{$ind-1} $pair";
	         	          $ind=$ind+1;

	      }
	   }
	  
  }
  
  foreach $pair (reverse sort keys %ArrayPM)
  {
      my $dummy=$ArrayPM{$pair};
      if ($Array_id{$dummy}) {
         if ($id_find) {
           my $dummy2="";
         } else {
          $id_find=$Array_id{$dummy};
         }
      }
  }
  return $id_find;
}
sub SecondMethod {
  my ($UserAgent) = @_;
  my $id_find="";
  my $near_toFind=1000;
  my $ua_toMatch;
  my $near_toMatch; 
  
  foreach $ua_toMatch (%Array_id)
  {
        $near_toMatch=distance($UserAgent,$ua_toMatch);     
        if ($near_toMatch < $near_toFind) {
           $near_toFind=$near_toMatch;
           $id_find=$Array_id{$ua_toMatch};
        }
  }
  if ($near_toFind > 3) {
     $id_find="";
  }
  return $id_find;
}
sub existCookie {
    my %ArrayCapFoundToPass;
    my ($cookie_search) = @_;
    my $param_tofound;
    my $string_tofound;
    my $dummy;
    my $response="";
    my @pairs = split(/;/, $cookie_search);
    my $name;
    my $value;
    foreach $param_tofound (@pairs) {
       ($string_tofound,$dummy)=split(/=/, $param_tofound);
       $ArrayCapFoundToPass{$string_tofound}=$dummy;
       if ($string_tofound eq "wurfl") {
         $response=$param_tofound;
            my @pairs=split(/\&/, substr($param_tofound,length('wurfl=')));
            my $redifine;
            foreach $redifine (@pairs) {
                ($name,$value)=split(/=/, $redifine);
                $ArrayCapFoundToPass{$name}=$value;
            }
       }
    }   
    return ($response,%ArrayCapFoundToPass);
}
sub handler    { 
      my $f = shift;
      my $capability2;
      my $s = $f->r->server;
      my $variabile="wurfl=";
      my  $user_agent=$f->r->headers_in->{'User-Agent'};
      my $uri = $f->r->uri();
      my ($content_type) = $uri =~ /\.(\w+)$/;
      my @fileArray = split(/\//, $uri);
      my $file=$fileArray[-1];
      my $docroot = $f->r->document_root();
	  $s->warn("$uri --> $file <--");
      my $id="";
      my $method="";
      my $cookie = $f->r->headers_in->{Cookie} || '';
      
      my $location;
      my $width_toSearch;
      my $type_redirect="internal";
      my $return_value;
	  my %ArrayCapFound;
	  my $dummy;
      my ($controlCookie,%ArrayCapFoundToPass)=existCookie($cookie); 
      if ($controlCookie eq "") {
      	if (index($user_agent,'UP.Link') >0 ) {
      	   $user_agent=substr($user_agent,0,index($user_agent,'UP.Link'));
      	}
      	if ($user_agent) {
     	 	$id=FirstMethod($user_agent);
      		$method="FirstMethod($id),$user_agent";
      	}
      	if ($id eq "") {
       	 $id=SecondMethod($user_agent);
      		$method="SecondMethod($id),$user_agent";
      	}
       	if ($id ne "") {
           %ArrayCapFound=FallBack($id);
            if ($ImageType{$content_type}) {
				  $dummy="";
            } else {
				my $count=0;
				foreach $capability2 (sort keys %ArrayCapFound) {
					my $visible=0;
					if ($showdefaultvariable eq "false" & $capability2 eq 'xhtml_support_level') {
					   $visible=1;      	           
					}
					if ($showdefaultvariable eq "false" & $capability2 eq 'is_wireless_device') {
					   $visible=1;      	           
					}
					if ($showdefaultvariable eq "false" & $capability2 eq 'device_claims_web_support') {
					   $visible=1;
					}
					if ($visible == 0) {
						if ($count==0) {
						   $count=1;
							$variabile="wurfl=$capability2=$ArrayCapFound{$capability2}";
						} else {
							$variabile="$variabile&$capability2=$ArrayCapFound{$capability2}";
						}
					}
				 }
         	 }
          	 $s->warn("$method -->$variabile");
      	} else {
            $variabile="wurfl=device=false";
            $s->warn("Device not found:$user_agent");
	  	}

      } else {
         $variabile=$controlCookie;         
         $s->warn("USING CACHE:$variabile");
      }
      
      	unless ($f->ctx) { 
       	   if ($controlCookie eq "" && $cookieset eq "true") {
       	       $f->r->err_headers_out->set ('Set-Cookie' => $variabile);
       	   }
       	   $f->ctx(1);
          
      	}

	  if ($ImageType{$content_type}) {
	          if ($convertimage eq "true") {
				  my $width=$ArrayCapFound{'resolution_width'};
				  my $imagefile="$resizeimagedirectory/$width.$file";
				  #
				  # control if image exist
				  #
				  if ( -e "$docroot$imagefile") {
					$dummy="";
				  } else { 
					  my $image = Image::Resize->new("$docroot$uri");
					  my $gd = $image->resize($ArrayCapFound{'resolution_width'}, 250);
					  open(FH, ">$docroot$imagefile");
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
				  }
				  $f->r->headers_out->set(Location => $imagefile);
				  $f->r->status(Apache2::Const::REDIRECT);
              }
			  $return_value=Apache2::Const::DECLINED;
	  } else {
				#
				# verify if the device is fullbrowser 
				#
				my $add_parameter="";
				if ($querystring eq "true") {
					$add_parameter=substr($variabile,6,length($variabile));
					$add_parameter="\?$add_parameter";
				}
				$s->warn("$querystring");
				if ($ArrayCapFound{'device_claims_web_support'} eq 'true' && $ArrayCapFound{'is_wireless_device'} eq 'false') {
					$location=$fullbrowserurl;      		
				} else {
					 if ($intelliswitch eq "false") {
						 $location="$mobileversionurl$add_parameter";
					 } else {
						 if ($variabile ne "wurfl=device=false") {
								 if ($ArrayCapFound{'xhtml_support_level'} ne "-1") {
									  foreach $width_toSearch (sort keys %XHTMLUrl) {
										 if ($width_toSearch <= $ArrayCapFound{'resolution_width'}) {
											 $location=$XHTMLUrl{$width_toSearch};
											 $location="$location$add_parameter";
										 }
									  }
								 } else {
									  foreach $width_toSearch (sort keys %WMLUrl) {
										 if ($width_toSearch <= $ArrayCapFound{'resolution_width'}) {
											 $location=$WMLUrl{$width_toSearch};
											 $location="$location$add_parameter";
										 }
									  }
								 }
						 } else {
							 $location=$fullbrowserurl;
							 $type_redirect="ext";
							 $s->warn("Strange UA:$user_agent");
						 }
					 }
				}
                $f->r->headers_out->set(Location => $location);
                $f->r->status(Apache2::Const::REDIRECT);
                $return_value=Apache2::Const::DECLINED;
	  }
      return $return_value;
      
} 
  1; 
=head1 NAME

Apache2::WURFLFilter - is a Apache Mobile Filter that manage content (text & image) to the correct mobile device


=head1 COREQUISITES

CGI
Apache2

=head1 DESCRIPTION

This module The idea is to give to anybody the possibility to create mobile solution, it's not important if you know programming language just what you need to know is a little bit of html and if it's necessary wml.
So I thought it was  to make something simply that can identify a browser and redirect it the correct url (for mobile or pc).

If you are a  programmer and you want to develop a simple mobile solution you can use this module to pass few Wurfl Capabilities information to your application. In this case it's not important with which technology you want to develop your site and you don't need to implement new methods to how recognise the devices.

For more details: http://www.idelfuschini.it/

NOTE: this software need wurfl.xml from this site: http://wurfl.sourceforge.net


=cut
