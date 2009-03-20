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
  use IO::Uncompress::Unzip qw(unzip $UnzipError) ;
  use File::Copy;
  use constant BUFF_LEN => 1024;

  #
  # Define the global environment
  # 

  use vars qw($VERSION);
  $VERSION= "1.5";
  my %Capability;
  my %Array_fb;
  my %Array_id;
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
  my $xml_config="false";
  
  $ImageType{'png'}="png";
  $ImageType{'gif'}="gif";
  $ImageType{'jpg'}="jpg";
  $ImageType{'jpeg'}="jpeg";
  $Capability{'resolution_width'}="resolution_width";  
  $Capability{'max_image_width'}="max_image_width";
  $Capability{'is_wireless_device'}="is_wireless_device";
  $Capability{'device_claims_web_support'}="device_claims_web_support";
  $Capability{'xhtml_support_level'}="xhtml_support_level";
  $Capability{'html_wi_imode_ compact_generic'}="html_wi_imode_ compact_generic";
  #
  # Check if MOBILE_HOME is setting in apache httpd.conf file for example:
  # PerlSetEnv MOBILE_HOME <apache_directory>/MobileFilter
  #
  if ($ENV{XML_CONFIG}) {
     $xml_config=$ENV{XML_CONFIG};
  } 
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
	     my $dummy;
	     if ($xml_config eq 'true') {
			 if (-e "$file") {
				 printLog("Start loading  WURFLMobile.config");
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
							printLog("XHTMLUrl is: width=$val and URL=$capability");
						 }				
						 if ($_ =~ /\<WMLUrl/o) {
							$capability=extValueTag('WMLUrl',$_);
							($null,$val,$null2)=split(/\"/, $_);
							$WMLUrl{$val}=$capability;	
							printLog("WMLUrl is: width=$val and URL=$capability");
						 }				
						 if ($_ =~ /\<CHTMLUrl/o) {
							$capability=extValueTag('CHTMLUrl',$_);
							($null,$val,$null2)=split(/\"/, $_);
							$CHTMLUrl{$val}=$capability;
							printLog("CHTMLUrl is: width=$val and URL=$capability");
						 }				
						
						 if ($_ =~ /\<FullBrowserUrl\>/o) {
							$fullbrowserurl=extValueTag('FullBrowserUrl',$_);
						 }			
						 if ($_ =~ /\<CookieSet\>/o) {
							$cookieset=extValueTag('CookieSet',$_);
							printLog("CookieSet is:           $cookieset");
						 }			
						 if ($_ =~ /\<PassQueryStringSet\>/o) {
							$querystring=extValueTag('PassQueryStringSet',$_);
							printLog("PassQueryStringSet is : $querystring");
						 }			
						 if ($_ =~ /\<ShowDefaultVariable\>/o) {
							$showdefaultvariable=extValueTag('ShowDefaultVariable',$_);
							printLog("ShowDefaultVariable is: $showdefaultvariable");
						 }			
						 if ($_ =~ /\<WurflNetDownload\>/o) {
							$wurflnetdownload=extValueTag('WurflNetDownload',$_);
							printLog("WurflNetDownload is:    $wurflnetdownload");
							
						 }			
						 if ($_ =~ /\<DownloadWurflURL\>/o) {
							$downloadwurflurl=extValueTag('DownloadWurflURL',$_);
						 }			
						 if ($_ =~ /\<DownloadZipFile\>/o) {
							$downloadzipfile=extValueTag('DownloadZipFile',$_);
							printLog("DownloadZipFile is:     $downloadzipfile");
						 }
						 if ($_ =~ /\<ConvertImage\>/o) {
							$convertimage=extValueTag('ConvertImage',$_);
							printLog("ConvertImage is :       $convertimage");
						 }			
						 if ($_ =~ /\<ResizeImageDirectory\>/o) {
							$resizeimagedirectory=extValueTag('ResizeImageDirectory',$_);
						 }			
						 if ($_ =~ /\<WebAppConvertImages\>/o) {
							$virtualdirectoryimages=extValueTag('WebAppConvertImages',$_);
							printLog("WebAppConvertImages is: $virtualdirectoryimages");
						 }	
						 
						 if ($_ =~ /\<WebAppDirectory\>/o) {
							$virtualdirectory=extValueTag('WebAppDirectory',$_);
						 }			
						 if ($_ =~ /\<ConvertOnlyImages\>/o) {
							$convertonlyimages=extValueTag('ConvertOnlyImages',$_);
							printLog("ConvertOnlyImages is:   $convertonlyimages");
						 }	
						 if ($_ =~ /\<Log4WurflNoDeviceDetect\>/o) {
							$log4wurfl=extValueTag('Log4WurflNoDeviceDetect',$_);
						 }	
	
						 
	
				 }				
				 
			 } else {
			   printLog("File $file not found");
			   ModPerl::Util::exit();
			  }
			  close IN;
	      } else {
	      	#The filter
	      	printLog("Start read configuration from httpd.conf");
	      	 if ($ENV{MobileVersionUrl}) {
				$mobileversionurl=$ENV{MobileVersionUrl};
				printLog("MobileVersionUrl is: $mobileversionurl");
			 }	
	      	 if ($ENV{IntelliSwitch}) {
				$intelliswitch=$ENV{IntelliSwitch};
				printLog("IntelliSwitch is: $intelliswitch");
			 }	
	      	 if ($ENV{FullBrowserUrl}) {
				$fullbrowserurl=$ENV{FullBrowserUrl};
				printLog("FullBrowserUrl is: $fullbrowserurl");
			 }	
	      	 if ($ENV{CookieSet}) {
				$cookieset=$ENV{CookieSet};
				printLog("CookieSet is: $cookieset");
			 }	
	      	 if ($ENV{PassQueryStringSet}) {
				$querystring=$ENV{PassQueryStringSet};
				printLog("PassQueryStringSet is: $querystring");
			 }	
	      	 if ($ENV{ShowDefaultVariable}) {
				$showdefaultvariable=$ENV{ShowDefaultVariable};
				printLog("ShowDefaultVariable is: $showdefaultvariable");
			 }	
	      	 if ($ENV{WurflNetDownload}) {
				$wurflnetdownload=$ENV{WurflNetDownload};
				printLog("WurflNetDownload is: $wurflnetdownload");
			 }	
	      	 if ($ENV{DownloadWurflURL}) {
				$downloadwurflurl=$ENV{DownloadWurflURL};
				printLog("DownloadWurflURL is: $downloadwurflurl");
			 }	
	      	 if ($ENV{DownloadZipFile}) {
				$downloadzipfile=$ENV{DownloadZipFile};
				printLog("DownloadZipFile is: $downloadzipfile");
			 }	
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
	      	 if ($ENV{WebAppDirectory}) {
				$virtualdirectory=$ENV{WebAppDirectory};
				printLog("WebAppDirectory is: $virtualdirectory");
			 }	
	      	 if ($ENV{ConvertOnlyImages}) {
				$convertonlyimages=$ENV{ConvertOnlyImages};
				printLog("ConvertOnlyImages is: $convertonlyimages");
			 }	
	      	 if ($ENV{Log4WurflNoDeviceDetect}) {
				$log4wurfl=$ENV{Log4WurflNoDeviceDetect};
				printLog("Log4WurflNoDeviceDetect is: $log4wurfl");
			 }	
	      	 if ($ENV{CapabilityList}) {
				my @dummycapability = split(/,/, $ENV{CapabilityList});
				foreach $dummy (@dummycapability) {
				      $Capability{$dummy}=$dummy;
				      printLog("Capability is: $dummy");
				}
			 }	
	      	 if ($ENV{XHTMLUrl}) {
				my @dummyxurl = split(/,/, $ENV{XHTMLUrl});
				foreach $dummy (@dummyxurl) {
				      ($val, $capability)=split(/\|/, $dummy);
				      $XHTMLUrl{$val}=$capability;
				      printLog("XHTMLUrl is: width=$val and URL=$capability");
				}
			 }	
	      	 if ($ENV{CHTMLUrl}) {
				my @dummycurl = split(/,/, $ENV{CHTMLUrl});
				foreach $dummy (@dummycurl) {
				      ($val, $capability)=split(/\|/, $dummy);
				      $CHTMLUrl{$val}=$capability;
				      printLog("CHTMLUrl is: width=$val and URL=$capability");
				}
			 }	
	      	 if ($ENV{WMLUrl}) {
				my @dummywurl = split(/,/, $ENV{WMLUrl});
				foreach $dummy (@dummywurl) {
				      ($val, $capability)=split(/\|/, $dummy);
				      $WMLUrl{$val}=$capability;
				      printLog("WMLUrl is: width=$val and URL=$capability");
				}
			 }	             

	      }
          if ($log4wurfl eq "") {
   		     printLog("The parameter Log4WurflNoDeviceDetect must be defined into WURFLMobile.config");
		     ModPerl::Util::exit();
	      }
	      
	    printLog("Finish loading  parameter");
	    printLog("----------------------------------");
	    if ($wurflnetdownload eq "true") {
	        printLog("Start downloading  WURFL.xml from $downloadwurflurl");
	        my $content = get ($downloadwurflurl);
	        printLog("Finish downloading  WURFL.xml");
	        if ($content eq "") {
   		        printLog("Couldn't get $downloadwurflurl.");
		   		ModPerl::Util::exit();
	        }
	        
	        if ($downloadzipfile eq 'true') {
	              printLog("Uncompress File start");
				  my @dummypairs = split(/\//, $downloadwurflurl);
				  my ($ext_zip) = $downloadwurflurl =~ /\.(\w+)$/;
				  my $filezip=$dummypairs[-1];
				  my $tmp_dir=$ENV{MOBILE_HOME};
				  $filezip="$tmp_dir/$filezip";
				  if ($ext_zip eq 'zip') {
					  if (open(FH, ">$filezip")) {
						  print FH $content;
					  close FH;
					  } else {
					      ModPerl::Util::exit();
					      printLog("Error open file:$filezip");
					  }
				  } else {
					  printLog ("The file compress you try to download it's not a zip format");
					  ModPerl::Util::exit();
				  }
				  my $output="$tmp_dir/tmp_wurfl.xml";
				  unzip $filezip => $output 
						or die "unzip failed: $UnzipError\n";
					if (open (IN,"$output")) {
					while (<IN>) {
					     $r_id=parseWURFLFile($_,$r_id);
					}
					close IN;			  
					} else {
					     printLog("Error open file:$output");
					     ModPerl::Util::exit();
					}
			} else {
				my @rows = split(/\n/, $content);
				my $row;
				my $count=0;
				foreach $row (@rows){
					$r_id=parseWURFLFile($row,$r_id);
				}
			}
	    } else {
			if (-e "$file2") {
					printLog("Start loading  WURFL.xml");
					if (open (IN,"$file2")) {
						while (<IN>) {
							 $r_id=parseWURFLFile($_,$r_id);
							 
						}
						close IN;
					} else {
					    printLog("Error open file:$file2");
					    ModPerl::Util::exit();
					}
			} else {
			  printLog("File $file2 not found");
			  ModPerl::Util::exit();
			}
		}
		close IN;
		my $arrLen = scalar %Array_id;
		($arrLen,$dummy)= split(/\//, $arrLen);
		if ($arrLen == 0) {
		     printLog("Error the file probably is not a wurfl file, control the url or path");
		     printLog("Control also if the file is compress file, and DownloadZipFile parameter is seted false");
		     ModPerl::Util::exit();
		}
        printLog("This version of WURFL have $arrLen UserAgent");
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
		 my $name="";
		 if ($val) {
		    $id="$val";
		 } 
	      if ($record =~ /\<device/o) {
			($null,$id,$null2,$ua,$null3,$fb)=split(/\"/, $record);
				 if (($fb) && ($id)) {	     	   
					$Array_fb{"$id"}=$fb;
				 }
				 if (($ua) && ($id)) {
				         my %ParseUA=GetMultipleUa($ua);
				         my $pair;
				         foreach $pair (reverse sort { $a <=> $b }  keys %ParseUA) {
						 		my $dummy=$ParseUA{$pair};
						        $Array_id{$dummy}=$id;
						 }
				 }
		 }
		 if ($record =~ /\<capability/o) { 
			($null,$name,$null2,$value,$null3,$fb)=split(/\"/, $record);
			if (($id) && ($Capability{$name}) && ($name) && ($value)) {
			   $Array_DDRcapability{"$val|$name"}=$value;
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
sub printNotFound {
	my ($info) = @_;
	my $data=Data();
	if ($info ne $globalpassvariable) {
		 if (open(LOGFILE, ">>$log4wurfl")){
		     print LOGFILE "$data - $info\n";
		  close LOGFILE;
		} else {
		  ModPerl::Util::exit();
		}
    }
    $globalpassvariable=$info;

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
      my $variabile="";
      my  $user_agent=$f->r->headers_in->{'User-Agent'};
      my $uri = $f->r->uri();
      my ($content_type) = $uri =~ /\.(\w+)$/;
      my @fileArray = split(/\//, $uri);
      my $file=$fileArray[-1];
      my $docroot = $f->r->document_root();
      my $id="";
      my $method="";
      my $cookie = $f->r->headers_in->{Cookie} || '';       
      my $location;
      my $width_toSearch;
      my $type_redirect="internal";
      my $return_value;
	  my $dummy;
	  my $variabile2="";
      my ($controlCookie,%ArrayCapFound)=existCookie($cookie);
      $repasshanlder=$repasshanlder + 1;
      if ($content_type) {
        $dummy="";
      } else {
         $content_type="-----";
      }
	  if ($controlCookie eq "") {       
		  	if (index($user_agent,'UP.Link') >0 ) {
			 	$user_agent=substr($user_agent,0,index($user_agent,'UP.Link'));
		  	}
		  	if (index($user_agent,'UP.Browser') >0 ) {
			 	$user_agent=substr($user_agent,0,index($user_agent,'UP.Link'));
		  	}
		  	if ($cacheArray2{$user_agent}) {
       	        #
       	        # I'm here only for old device
       	        #
       	       my @pairs = split(/&/, $cacheArray2{$user_agent});
       	       my $param_tofound;
       	       my $string_tofound;
       	       foreach $param_tofound (@pairs) {      	       
       	             ($string_tofound,$dummy)=split(/=/, $param_tofound);
       	             $ArrayCapFound{$string_tofound}=$dummy;
       	             
       	       }
       	       $variabile=$cacheArray_toview{$user_agent};
       	    } else {
       	        #
       	        # I'm here only for new device
       	        #
            if ($cacheArray{$user_agent}) {
              $id=$cacheArray{$user_agent};
            } else {
				if ($user_agent) {
					$id=IdentifyUAMethod($user_agent,3);
					$method="IdentifyUAMethod($id),$user_agent";
				}
            	$cacheArray{$user_agent}=$id;
            }
         
       	if ($id ne "") {

      	        
          	    %ArrayCapFound=FallBack($id);         
				if ($ImageType{$content_type}) {
					  $dummy="";
				} else {
					my $count=0;
					my $count2=0;
					foreach $capability2 (sort keys %ArrayCapFound) {
						my $visible=0;
						if ($count2==0) {
							$variabile2="$capability2=$ArrayCapFound{$capability2}";
							$count2=1;
						} else {
							$variabile2="$variabile2&$capability2=$ArrayCapFound{$capability2}";
						} 						
						if ($showdefaultvariable eq "false" && $capability2 eq 'xhtml_support_level') {
						   $visible=1;      	           
						}
						if ($showdefaultvariable eq "false" && $capability2 eq 'is_wireless_device') {
						   $visible=1;      	           
						}
						if ($showdefaultvariable eq "false" && $capability2 eq 'device_claims_web_support') {
						   $visible=1;
						}
						if ($showdefaultvariable eq "false" && $capability2 eq 'max_image_width') {
						   $visible=1;
						}
						if ($visible == 0) {
							if ($count==0) {
							   $count=1;
								$variabile="$capability2=$ArrayCapFound{$capability2}";
							} else {
								$variabile="$variabile&$capability2=$ArrayCapFound{$capability2}";
							}
						}
					 }

					
					$cacheArray2{$user_agent}=$variabile2;
					$cacheArray_toview{$user_agent}=$variabile;
			   }
      	} else {
            $variabile="device=false";

            $s->warn("Device not found:$user_agent");
            printNotFound("$user_agent");
            $ArrayCapFound{'device_claims_web_support'}= 'true';
            $ArrayCapFound{'is_wireless_device'}='false';
            $cacheArray2{$user_agent}="$variabile&device_claims_web_support=true&is_wireless_device=false";
			$cacheArray_toview{$user_agent}=$variabile;
			$cacheArray{$user_agent}="device_not_found";
			$method="";
		}
		}
        if ($method) {
			$s->warn("New id found - $method -->$variabile");
		} 
      } else {
         $variabile=$controlCookie;
         $ArrayCapFound{'device_claims_web_support'}='false';
         $s->warn("USING CACHE:$variabile");
      }

      	unless ($f->ctx) {
      	  if ($ImageType{$content_type}) { 
      	     $dummy="";
      	  } else {
			   if ($ArrayCapFound{'device_claims_web_support'} eq 'false') {
				   if ($controlCookie eq "" && $cookieset eq "true" ) {
					   $s->warn("Cookie: $variabile");
					   $f->r->err_headers_out->set ('Set-Cookie' => "wurfl=$variabile");
				   }
				   $f->ctx(1);
			   }
       	   }
          
      	}


	  if ($ImageType{$content_type}) {
	          my $imageToConvert;
	          my $imagefile="";
	          if ($convertimage eq "true" && $variabile ne "device=false") {
				  my $width=$ArrayCapFound{'max_image_width'};
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
						  my $gd = $image->resize($ArrayCapFound{'max_image_width'}, 250);
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
			  
	  } else {
				#
				# verify if the device is fullbrowser 
				#
				my $add_parameter="";
				$return_value=Apache2::Const::DECLINED;
				if ($querystring eq "true") {
					$add_parameter="\?$variabile";
				}
				if ($ArrayCapFound{'device_claims_web_support'} eq 'true' && $ArrayCapFound{'is_wireless_device'} eq 'false') {
					$location=$fullbrowserurl;      		
				} else {
					 if ($intelliswitch eq "false") {
						 $location="$mobileversionurl$add_parameter";
						 my $key="wurfl";
						 my $val="$variabile";
						 $f->r->subprocess_env->set($key => $val);

					 } else {
						 if ($variabile ne "device=false") {
								 if ($ArrayCapFound{'xhtml_support_level'} ne "-1") {
									  foreach $width_toSearch (sort keys %XHTMLUrl) {
										 if ($width_toSearch <= $ArrayCapFound{'resolution_width'}) {
											 $location=$XHTMLUrl{$width_toSearch};
											 $location="$location/$add_parameter";
										 }
									  }
								 } else {
									  foreach $width_toSearch (sort keys %WMLUrl) {
										 if ($width_toSearch <= $ArrayCapFound{'resolution_width'}) {
											 $location=$WMLUrl{$width_toSearch};
											 $location="$location/$add_parameter";
										 }
									  }
								 }
								 if ($ArrayCapFound{'html_wi_imode_ compact_generic'} eq "true") {
									  foreach $width_toSearch (sort keys %CHTMLUrl) {
										 if ($width_toSearch <= $ArrayCapFound{'resolution_width'}) {
											 $location=$CHTMLUrl{$width_toSearch};
											 $location="$location/$add_parameter";
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
				if ($convertonlyimages ne 'true') {
				   if (substr($location,0,5) eq "http:") {
				      $s->warn("Redirect: $location");
                      $f->r->headers_out->set(Location => $location);                      
                      $f->r->status(Apache2::Const::REDIRECT);
                   } else {
                      $s->warn("InternalRedirect: $location");
                   	  $f->r->internal_redirect($location);
                   }
                }
                
	  }

	  
      return $return_value;
      
} 
sub IdentifyUAMethod {
  my ($UserAgent,$precision) = @_;
  my $ind=0;
  my %ArrayPM;
  my $pair;
  my $pair2;
  my $id_find="";
  my $dummy;
  my $ua_toMatch;
  my $near_toFind;
  my $near_toMatch;
  my %ArrayUAType=GetMultipleUa($UserAgent);  
  foreach $pair (reverse sort { $a <=> $b }  keys %ArrayUAType)
  {
      my $dummy=$ArrayUAType{$pair};
      if ($Array_id{$dummy}) {
         if ($id_find) {
           my $dummy2="";
         } else {
           $id_find=$Array_id{$dummy};
         }
      }
  }
  if ($id_find eq "") {
    foreach $pair (reverse sort { $a <=> $b }  keys %ArrayUAType) {
		if ($id_find eq "" && $ArrayPM{$pair} ne "") {
			foreach $ua_toMatch (%Array_id) {
				$dummy=$ArrayUAType{$pair};
				$near_toMatch=distance($dummy,$ua_toMatch);     
				 if ($near_toMatch < $near_toFind) {
					$near_toFind=$near_toMatch;
					$id_find=$Array_id{$ua_toMatch};
				 }
			}
			if ($near_toFind > $precision) {
				$id_find="";
			}
		}
  	}
  }
  return $id_find;
}
sub GetMultipleUa {
  my ($UserAgent) = @_;
  my %ArrayPM;
  my $pair;
  my $ind=0;
  my $pairs3;
  my %ArrayUAparse;
  
  my @pairs = split(/\ /, $UserAgent);
  foreach $pair (@pairs)
  { 
     if ($ind==0) {
	     if ($pair =~ /\//o) {     	
	     	my @pairs2 = split(/\//, $pair);
    	  	foreach $pairs3 (@pairs2) {
			     if ($ind==0) {
			       $ind=$ind+1;
			       $ArrayUAparse{$ind}=$pairs3;
		 	     } else {
		 	       $ind=$ind+1;
		    	   $ArrayUAparse{$ind}="$ArrayUAparse{$ind-1}\/$pairs3";
		    	 }
     	 	}
     	} else {
	      $ind=$ind+1;
     	  $ArrayUAparse{$ind}="$pair";
     	}
     } else {
        if ($pair =~ /\//o) {
          my $ind2=0;
          my @pairs2 = split(/\//, $pair);
          foreach $pairs3 (@pairs2) {
			     if ($ind2==0) {
			       $ind=$ind+1;
			       $ind2=1;
			       $ArrayUAparse{$ind}="$ArrayUAparse{$ind-1} $pairs3";
		 	     } else {
		 	       $ind=$ind+1;
		    	   $ArrayUAparse{$ind}="$ArrayUAparse{$ind-1}\/$pairs3";
		    	 }             
          }
		} else {
	    	$ind=$ind+1;
     		$ArrayUAparse{$ind}="$ArrayUAparse{$ind-1} $pair";
     	}
     }
  }
  return %ArrayUAparse;

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
Another feature I have implemented is the resize on the fly of the images, so if the wap/web developer want to adapted the images for the mobile device now it's possible. 

For more details: http://www.idelfuschini.it/en/apache-mobile-filter.html

NOTE: this software need wurfl.xml you can download it directly from this site: http://wurfl.sourceforge.net or you canset the filter to download it directly.


=cut
