#file:Apache2/WURFLFilter.pm; 
#-------------------------------- 

#
# Created by Idel Fuschini 
# Date: 20/05/09
# Site: http://www.idelfuschini.it
# Mail: idel.fuschini@gmail.com


package Apache2::WURFLFilter; 
  
  use strict; 
  use warnings; 
  
  use Apache2::RequestRec ();
  use Apache2::RequestUtil ();
  use Apache2::SubRequest ();
  use Apache2::Log;
  use Apache2::Filter (); 
  use Text::LevenshteinXS qw(distance);
  use APR::Table (); 
  use LWP::Simple;
  use Apache2::Const -compile => qw(OK REDIRECT DECLINED);
  use IO::Uncompress::Unzip qw(unzip $UnzipError) ;
  use File::Copy;
  use constant BUFF_LEN => 1024;

  #
  # Define the global environment
  # 

  use vars qw($VERSION);
  $VERSION= "2.02";
  my %Capability;
  my %Array_fb;
  my %Array_id;
  my %Array_fullua_id;
  my %Array_DDRcapability;

  my %XHTMLUrl;
  my %WMLUrl;
  my %CHTMLUrl;
  my %cacheArray;
  my %cacheArray2;
  my %cacheArray_toview;
  my %ImageType;
  

  my $mobileversionurl="none";
  my $fullbrowserurl="none";
  my $querystring="false";
  my $showdefaultvariable="false";
  my $wurflnetdownload="false";
  my $downloadwurflurl="false";
  my $convertimage="false";
  my $resizeimagedirectory="";
  my $downloadzipfile="true";
  my $convertonlyimages="false"; 
  my $repasshanlder=0;
  my $globalpassvariable="";
  my $log4wurfl="";
  my $loadwebpatch="false";
  my $dirwebpatch="";
  my $patchwurflnetdownload="false"; 
  my $patchwurflurl="";
  my $redirecttranscoder="true";
  my $redirecttranscoderurl="none";
  my $detectaccuracy="false";
  my $listall="false";
  $ImageType{'png'}="png";
  $ImageType{'gif'}="gif";
  $ImageType{'jpg'}="jpg";
  $ImageType{'jpeg'}="jpeg";

  $Capability{'resolution_width'}="resolution_width";  
  $Capability{'max_image_width'}="max_image_width";
  $Capability{'max_image_height'}="max_image_width";  
  $Capability{'is_wireless_device'}="is_wireless_device";
  $Capability{'device_claims_web_support'}="device_claims_web_support";
  $Capability{'xhtml_support_level'}="xhtml_support_level";
  $Capability{'html_wi_imode_ compact_generic'}="html_wi_imode_ compact_generic";
  $Capability{'is_transcoder'}="is_transcoder";
  
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
	     my $dummy;
	      	#The filter
	      	printLog("Start read configuration from httpd.conf");
	      	 if ($ENV{MobileVersionUrl}) {
				$mobileversionurl=$ENV{MobileVersionUrl};
				printLog("MobileVersionUrl is: $mobileversionurl");
			 }	
	      	 if ($ENV{FullBrowserUrl}) {
				$fullbrowserurl=$ENV{FullBrowserUrl};
				printLog("FullBrowserUrl is: $fullbrowserurl");
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
	      	 if ($ENV{Log4WurflNoDeviceDetect}) {
				$log4wurfl=$ENV{Log4WurflNoDeviceDetect};
				printLog("Log4WurflNoDeviceDetect is: $log4wurfl");
			 }	
	      	 if ($ENV{CapabilityList}) {
				my @dummycapability = split(/,/, $ENV{CapabilityList});
				foreach $dummy (@dummycapability) {
				      if ($dummy eq "all") {
				         $listall="true";
				      }
				      $Capability{$dummy}=$dummy;
				      printLog("Capability is: $dummy");
				}
			 }	
	             
	      	 if ($ENV{LoadWebPatch}) {
				$loadwebpatch=$ENV{LoadWebPatch};
				printLog("LoadWebPatch is: $loadwebpatch");
			 }	
	      	 if ($ENV{DirWebPatch}) {
				$dirwebpatch=$ENV{DirWebPatch};
				printLog("DirWebpatch is: $dirwebpatch");
			 }	
	      	 if ($ENV{PatchWurflNetDownload}) {
				$patchwurflnetdownload=$ENV{PatchWurflNetDownload};
				printLog("PatchWurflNetDownload is: $patchwurflnetdownload");
			 }	
	      	 if ($ENV{PatchWurflUrl}) {
				$patchwurflurl=$ENV{PatchWurflUrl};
				printLog("PatchWurflUrl is: $patchwurflurl");
			 }	
	      	 if ($ENV{RedirectTranscoder}) {
				$redirecttranscoder=$ENV{RedirectTranscoder};
				printLog("RedirectTranscoder is: $redirecttranscoder");
			 }	
	      	 if ($ENV{RedirectTranscoderUrl}) {
				$redirecttranscoderurl=$ENV{RedirectTranscoderUrl};
				printLog("RedirectTranscoderUrl is: $redirecttranscoderurl");
			 }	
			 if ($ENV{DetectAccuracy}) {
				$detectaccuracy=$ENV{DetectAccuracy};
				printLog("DetectAccuracy is: $detectaccuracy");
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
		#
		# Start for web_patch_wurfl (full browser)
		#
		if ($loadwebpatch eq 'true') {
			if ($patchwurflnetdownload eq "true") {
				printLog("Start downloading patch WURFL.xml from $patchwurflurl");
				my $content = get ($patchwurflurl);
				printLog("Finish downloading  WURFL.xml");
				if ($content eq "") {
					printLog("Couldn't get patch $patchwurflurl.");
					ModPerl::Util::exit();
				}
				my @rows = split(/\n/, $content);
				my $row;
				my $count=0;
				foreach $row (@rows){
					$r_id=parseWURFLFile($row,$r_id);
				}
	         } else {
				$file2=$dirwebpatch;
				if (-e "$file2") {
						printLog("Start loading Web Patch File of WURFL");
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
		}
		my $arrLen = scalar %Array_fb;
		($arrLen,$dummy)= split(/\//, $arrLen);
		if ($arrLen == 0) {
		     printLog("Error the file probably is not a wurfl file, control the url or path");
		     printLog("Control also if the file is compress file, and DownloadZipFile parameter is seted false");
		     ModPerl::Util::exit();
		}
        printLog("This version of WURFL have $arrLen UserAgent");
        printLog("End loading  WURFL.xml");
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
	        if (index($record,'user_agent') > 0 ) {
	           $ua=substr($record,index($record,'user_agent') + 12,index($record,'"',index($record,'user_agent')+ 13)- index($record,'user_agent') - 12);
	        }	        
	        if (index($record,'id') > 0 ) {
	           $id=substr($record,index($record,'id') + 4,index($record,'"',index($record,'id')+ 5)- index($record,'id') - 4);	           
	        }	        
	        if (index($record,'fall_back') > 0 ) {
	           $fb=substr($record,index($record,'fall_back') + 11,index($record,'"',index($record,'fall_back')+ 12)- index($record,'fall_back') - 11);	           
	        }
	        if (($fb) && ($id)) {	     	   
					$Array_fb{"$id"}=$fb;
				 }
				 if (($ua) && ($id)) {
				         my %ParseUA=GetMultipleUa($ua);
				         my $pair;
				         my $arrUaLen = scalar %ParseUA;
				         my $contaUA=0;
				         my $Array_fullua_id=$ua;
				         foreach $pair (reverse sort { $a <=> $b }  keys %ParseUA) {
						 			my $dummy=$ParseUA{$pair};
						            $Array_id{$dummy}=$id;
				                $contaUA=$contaUA-1;
						 }
				 }
		 }
		 if ($record =~ /\<capability/o) { 
			($null,$name,$null2,$value,$null3,$fb)=split(/\"/, $record);
			if ($listall eq "true") {
				$Capability{$name}=$name;
			}
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
	my $message="nok";
	if ($info ne $globalpassvariable) {
		 if (open(LOGFILE, ">>$log4wurfl")){
		     print LOGFILE "$data - $info\n";
		  close LOGFILE;
		  $message="ok";
		 } 
    }
    $globalpassvariable=$info;
    return $message;

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

sub handler {
      my $f = shift;
      my $capability2;
      my $variabile="";
      my  $user_agent=$f->headers_in->{'User-Agent'}|| '';
      my $query_string=$f->args;
      my $uri = $f->uri();
      my ($content_type) = $uri =~ /\.(\w+)$/;
      my @fileArray = split(/\//, $uri);
      my $file=$fileArray[-1];
      my $docroot = $f->document_root();
      my $id="";
      my $method="";
      my $location="none";
      my $width_toSearch;
      my $type_redirect="internal";
      my $return_value;
	  my $dummy="";
	  my $variabile2="";
	  my %ArrayCapFound;
	  my $controlCookie;
	  my $query_img="";
	  $ArrayCapFound{is_transcoder}='false';
      my %ArrayQuery;
      my $var;
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
		  if ($ArrayQuery{amf}) {
					$user_agent=$ArrayQuery{amf};
		  }
		  
	
	
		if (index($user_agent,'UP.Link') >0 ) {
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
										 
										 my $upper2=uc($string_tofound);
										 $f->subprocess_env("AMF_$upper2" => $ArrayCapFound{$string_tofound});
								   }
								   $id=$ArrayCapFound{id};								   
								   $f->pnotes('width' => $ArrayCapFound{max_image_width}); 
								   $f->pnotes('height' => $ArrayCapFound{max_image_height});
								} else {
									#
									# I'm here only for new device
									#
								if ($cacheArray{$user_agent}) {
								  $id=$cacheArray{$user_agent};
								} else {
									if ($user_agent) {
										$id=IdentifyUAMethod($user_agent,2);
										$method="IdentifyUAMethod($id),$user_agent";
									}
									$cacheArray{$user_agent}=$id;
								}
					if ($id ne "") {								
								%ArrayCapFound=FallBack($id);         
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
									my $upper=uc($capability2);
									$f->subprocess_env("AMF_$upper" => $ArrayCapFound{$capability2});
								 }
								 $variabile2="id=$id&$variabile2";
								 $f->log->warn("cookie=amf=$ArrayCapFound{max_image_width}|$ArrayCapFound{max_image_height}");
								$f->pnotes('width' => $ArrayCapFound{max_image_width}); 
								$f->pnotes('height' => $ArrayCapFound{max_image_height});
								$f->subprocess_env("AMF_ID" => $id);
								$cacheArray2{$user_agent}=$variabile2;
					} else {
							$variabile="device=false";            
							if (printNotFound("$user_agent") eq "nok") {
							   $f->log->warn("Can't open:$log4wurfl");
							}
							$f->log->warn("Device not found:$user_agent");
						$ArrayCapFound{'device_claims_web_support'}= 'true';
						$ArrayCapFound{'is_wireless_device'}='false';
						$cacheArray2{$user_agent}="$variabile&device_claims_web_support=true&is_wireless_device=false";
						$cacheArray{$user_agent}="device_not_found";
						$method="";
					}
					}
					if ($method) {
						$f->log->debug("New id found - $method -->$variabile");
						$f->log->warn("New id found - $method");
					}
	
					
		#
		# Start redirect for mobile site
		#
		if ($fullbrowserurl ne 'none' && $ArrayCapFound{'device_claims_web_support'} eq 'true' && $ArrayCapFound{'is_wireless_device'} eq 'false') {
						$location=$fullbrowserurl;      		
		} else {
		   if ($mobileversionurl && 'none') {
						$location=$mobileversionurl;
		   }
		}
		if ($ArrayCapFound{'is_transcoder'}) {
							if ($redirecttranscoderurl ne 'none' && $redirecttranscoder eq 'true' && $ArrayCapFound{'is_transcoder'} eq 'true') {
								$location=$redirecttranscoderurl;
							}
		}
		if ($location ne "none") {
						   if (substr($location,0,5) eq "http:") {
						  $f->log->debug("Redirect: $location");
						  $f->headers_out->set(Location => $location);
						  $f->status(Apache2::Const::REDIRECT); 
						  $return_value=Apache2::Const::REDIRECT;
					   } else {
						  $f->log->debug("InternalRedirect: $location");
						  $f->internal_redirect($location);
					   }
		} else {
		 $f->subprocess_env("AMF_VER" => $VERSION);
		 $return_value=Apache2::Const::DECLINED;
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
  my $near_toFind=100;
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
  if ($id_find eq "" && $detectaccuracy eq "true") {    
			foreach $ua_toMatch (%Array_fullua_id) {
				$dummy=$UserAgent;
				$near_toMatch=distance($dummy,$ua_toMatch);     
				 if ($near_toMatch < $near_toFind) {
					$near_toFind=$near_toMatch;
					$id_find=$Array_fullua_id{$ua_toMatch};
				 }
			}
			if ($near_toFind > $precision) {
					$id_find="";
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

Apache2::WURFLFilter - is a Apache Mobile Filter that give any information about the capabilities of the devices as environment variable


=head1 COREQUISITES

CGI
Apache2
Text::LevenshteinXS

=head1 DESCRIPTION

This module is the final solution to manage WURFL information. WURFLFIlter identify the device and give you the value of all capabilities that stored into WURFL.xml

For more details: http://www.idelfuschini.it/it/apache-mobile-filter-v2x.html

NOTE: this software need wurfl.xml you can download it directly from this site: http://wurfl.sourceforge.net or you canset the filter to download it directly.


=cut
