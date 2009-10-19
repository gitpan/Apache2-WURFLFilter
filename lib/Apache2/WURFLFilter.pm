#file:Apache2/WURFLFilter.pm; 
#-------------------------------- 

#
# Created by Idel Fuschini 
# Date: 18/10/09
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
  $VERSION= "2.07";
  my %Capability;
  my %Array_fb;
  my %Array_id;
  my %Array_fullua_id;
  my %Array_DDRcapability;

  my %Cache_ua;
  my %Cache_id;
  

  my $mobileversionurl="none";
  my $fullbrowserurl="none";
  my $querystring="false";
  my $showdefaultvariable="false";
  my $wurflnetdownload="false";
  my $downloadwurflurl="false";
  my $loadwebpatch="false";
  my $patchwurflnetdownload="false"; 
  my $patchwurflurl="";
  my $redirecttranscoder="true";
  my $redirecttranscoderurl="none";
  my $listall="false";
  my $cookiecachesystem="false";
  my $WURFLVersion="unknown";  
  print "provao\n";
  $Capability{'resolution_width'}="resolution_width";  
  $Capability{'max_image_width'}="max_image_width";
  $Capability{'max_image_height'}="max_image_width";  
  $Capability{'is_wireless_device'}="is_wireless_device";
  $Capability{'device_claims_web_support'}="device_claims_web_support";
  $Capability{'xhtml_support_level'}="xhtml_support_level";
  $Capability{'html_wi_imode_ compact_generic'}="html_wi_imode_ compact_generic";
  $Capability{'is_transcoder'}="is_transcoder";
  $Cache_id{'device_not_found'}="id=device_not_found&device=false&device_claims_web_support=true&is_wireless_device=false";
  
  #
  # Check if MOBILE_HOME is setting in apache httpd.conf file for example:
  # PerlSetEnv MOBILE_HOME <apache_directory>/MobileFilter
  #
   
  printLog("WURFLFilter Version $VERSION");
  if ($ENV{MOBILE_HOME}) {
	  &loadConfigFile("$ENV{MOBILE_HOME}/wurfl.xml");
  } else {
	  printLog("MOBILE_HOME not exist.	Please set the variable MOBILE_HOME into httpd.conf");
	  ModPerl::Util::exit();
  }

sub loadConfigFile {
	my ($fileWurfl) = @_;
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
	      	 if ($ENV{RedirectTranscoderUrl}) {
				$redirecttranscoderurl=$ENV{RedirectTranscoderUrl};
				$redirecttranscoder="true";
				printLog("RedirectTranscoderUrl is: $redirecttranscoderurl");
			 }	
	
	      	 if ($ENV{WurflNetDownload}) {
				$wurflnetdownload=$ENV{WurflNetDownload};
				printLog("WurflNetDownload is: $wurflnetdownload");
			 }	
	      	 if ($ENV{DownloadWurflURL}) {
				$downloadwurflurl=$ENV{DownloadWurflURL};
				printLog("DownloadWurflURL is: $downloadwurflurl");
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
	      	 if ($ENV{PatchWurflNetDownload}) {
				$patchwurflnetdownload=$ENV{PatchWurflNetDownload};
				printLog("PatchWurflNetDownload is: $patchwurflnetdownload");
			 }	
	      	 if ($ENV{PatchWurflUrl}) {
				$patchwurflurl=$ENV{PatchWurflUrl};
				printLog("PatchWurflUrl is: $patchwurflurl");
			 }	

			 if ($ENV{CookieCacheSystem}) {
				$cookiecachesystem=$ENV{CookieCacheSystem};
				printLog("CookieCacheSystem is: $cookiecachesystem");
			 }	
	    printLog("Finish loading  parameter");
	    printLog("----------------------------------");
	    if ($wurflnetdownload eq "true") {
	        printLog("Start process downloading  WURFL.xml from $downloadwurflurl");
	        my $data = Data();
	        printLog ("Test the  URL");
	        my ($content_type, $document_length, $modified_time, $expires, $server) = head($downloadwurflurl);
	        if ($content_type eq "") {
   		        printLog("Couldn't get $downloadwurflurl.");
		   		ModPerl::Util::exit();
	        } else {
	            printLog("The URL is correct");
	            printLog("The size of document wurf file: $document_length bytes");	       
	        }
	        
	        if ($content_type eq 'application/zip') {
	              printLog("The file is a zip file.");
	              printLog ("Start downloading");
				  my @dummypairs = split(/\//, $downloadwurflurl);
				  my ($ext_zip) = $downloadwurflurl =~ /\.(\w+)$/;
				  my $filezip=$dummypairs[-1];
				  my $tmp_dir=$ENV{MOBILE_HOME};
				  $filezip="$tmp_dir/$filezip";
				  my $status = getstore ($downloadwurflurl,$filezip);
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
				printLog("The file is a xml file.");
			    my $content = get ($downloadwurflurl);
				my @rows = split(/\n/, $content);
				my $row;
				my $count=0;
				foreach $row (@rows){
					$r_id=parseWURFLFile($row,$r_id);
				}
			}
			printLog("Finish downloading WURFL from $downloadwurflurl");

	    } else {
			if (-e "$fileWurfl") {
					printLog("Start loading  WURFL.xml");
					if (open (IN,"$fileWurfl")) {
						while (<IN>) {
							 $r_id=parseWURFLFile($_,$r_id);
							 
						}
						close IN;
					} else {
					    printLog("Error open file:$fileWurfl");
					    ModPerl::Util::exit();
					}
			} else {
			  printLog("File $fileWurfl not found");
			  ModPerl::Util::exit();
			}
		}
		close IN;
		#
		# Start for web_patch_wurfl (full browser)
		#
		if ($loadwebpatch eq 'true') {
			if ($patchwurflnetdownload eq "true") {
				printLog("Start downloading patch WURFL from $patchwurflurl");
			    my ($content_type, $document_length, $modified_time, $expires, $server) = head($patchwurflurl);
		        if ($content_type eq "") {
	   		        printLog("Couldn't get $patchwurflurl.");
			   		ModPerl::Util::exit();
		        } else {
		            printLog("The URL for download patch WURFL is correct");
		            printLog("The size of document is: $document_length bytes");	       
		        }
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
				my $filePatch="$ENV{MOBILE_HOME}/web_browsers_patch.xml";
				if (-e "$filePatch") {
						printLog("Start loading Web Patch File of WURFL");
						if (open (IN,"$filePatch")) {
							while (<IN>) {
								 $r_id=parseWURFLFile($_,$r_id);
								 
							}
							close IN;
						} else {
							printLog("Error open file:$filePatch");
							ModPerl::Util::exit();
						}
				} else {
				  printLog("File patch $filePatch not found");
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
        printLog("WURFL version: $WURFLVersion");
        printLog("This version of WURFL has $arrLen UserAgent");
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
		 if ($record =~ /\<ver/o) {
		     $WURFLVersion=extValueTag("ver",$record);
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
  foreach $pair (reverse sort { $a <=> $b }  keys	 %ArrayUAType)
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
sub readCookie {
    my ($cookie_search) = @_;
    my $param_tofound;
    my $string_tofound;
    my $value="";
    my $id_return="";
    my @pairs = split(/;/, $cookie_search);
    my $name;
    foreach $param_tofound (@pairs) {
       ($string_tofound,$value)=split(/=/, $param_tofound);
       if ($string_tofound eq "amf") {
           $id_return=$value;
       }
    }   
    return $id_return;
}
sub handler {
      my $f = shift;
      
      my $capability2;
      my $variabile="";
      my $user_agent=$f->headers_in->{'User-Agent'}|| '';
      my $x_user_agent=$f->headers_in->{'X-Device-User-Agent'}|| '';
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
      if ($x_user_agent) {
         $f->log->warn("Warn probably transcoder: $x_user_agent");
         $user_agent=$x_user_agent;
      }
      ## uncomment this code for pass the useragent in query string (JUST for demo)
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
      my $cookie = $f->headers_in->{Cookie} || '';
      $id=readCookie($cookie);
      if ($Cache_ua{$user_agent}) {
          #
          # cookie is not empty so I try to read in memory cache on my httpd cache
          #
          $id=$Cache_ua{$user_agent};
          if ($Cache_id{$id}) {
				#
				# I'm here only for old device
				#
				my @pairs = split(/&/, $Cache_id{$id});
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
		  }
      } else {
              if ($id eq "") { 
				  if ($user_agent) {
							$id=IdentifyUAMethod($user_agent,2);
							$method="IdentifyUAMethod($id),$user_agent";
							$Cache_ua{$user_agent}=$id;
				  }
              }                        
		      if ($id ne "") {
		          #
		          # cookie is not empty so I try to read in memory cache on my httpd cache
		          #
		          if ($Cache_id{$id}) {
						#
						# I'm here only for old device looking in cache
						#
						my @pairs = split(/&/, $Cache_id{$id});
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
						$f->pnotes('width' => $ArrayCapFound{max_image_width}); 
						$f->pnotes('height' => $ArrayCapFound{max_image_height});
						$f->subprocess_env("AMF_ID" => $id);
						$Cache_id{$id}=$variabile2;
						$Cache_ua{$user_agent}=$id;
						if ($cookiecachesystem eq "true") {
							$f->err_headers_out->set('Set-Cookie' => "amf=$id; path=/;");	
						}		  			  
				  }
	           
	      	 } else {
	      	     #
	      	     # unknown device 
	      	     #
				 $f->log->warn("Device not found:$user_agent");
				 $Cache_ua{$user_agent}="device_not_found";
				 if ($cookiecachesystem eq "true") {
							$f->err_headers_out->set('Set-Cookie' => "amf=device_not_found; path=/;");	
				  }		  			  
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
		 $f->subprocess_env("AMF_WURFLVER" => $WURFLVersion);
		 
		 $return_value=Apache2::Const::DECLINED;
		}

    return $return_value;

}
1; 
__END__
	
=head1 NAME

Apache2::WURFLFilter - The module detects the mobile device and passes the WURFL capabilities on to the other web application as environment variables

=head1 SYNOPSYS

The configuration of V2.x of B<"Apache Mobile Filter"> is very simple thane V1.x, I have deprecated the intelliswitch method because I think that the filter is faster.

Add this parameter into httpd.conf file:

=over 4

=item C<PerlSetEnv CapabilityList max_image_width,j2me_midp_2_0> *


=item C<PerlSetEnv WurflNetDownload true>***

=item C<PerlSetEnv DownloadWurflURL http://downloads.sourceforge.net/wurfl/wurfl-latest.zip>****

=item C<PerlSetEnv DownloadZipFile false>

=item C<PerlSetEnv ResizeImageDirectory /transform>

=item C<PerlSetEnv LoadWebPatch true>

=item C<PerlSetEnv PatchWurflNetDownload true>

=item C<PerlSetEnv PatchWurflUrl http://wurfl.sourceforge.net/web_browsers_patch.xml>

=item C<PerlSetEnv MobileVersionUrl /cgi-bin/perl.html> ** (default is "none" that mean the filter pass through)

=item C<PerlSetEnv FullBrowserUrl http://www.google.com> ** (default is "none" that mean the filter pass through)

=item C<PerlSetEnv RedirectTranscoderUrl /transcoderpage.html> (default is "none" that mean the filter pass through)

=item C<PerlSetEnv CookieCacheSystem true> (default is false, but for production mode is suggested to set in true) 

=item C<PerlModule Apache2::WURFLFilter>

=item C<PerlTransHandler +Apache2::WURFLFilter>

=back

* the field separator of each capability you want to consider in your mobile site is ",". Important you now can set ALL (default value) if you want that the filter managed all wurfl capabilities

**if you put a relative url (for example "/path") the filter done an internal redirect, if you put a url redirect with protocol (for example "http:") the filter done a classic redirect

***if this parameter is fault the filter try to read  the wurfl.xml file from MOBILE_HOME path

***if you want to download directly the last version of WURFL.xml you can set the url parameter to http://downloads.sourceforge.net/wurfl/wurfl-latest.zip

****if you put to true value you can detect a little bit more device, but for strange UA the method take  a lot of time 


=head1 DESCRIPTION

For this configuration you need to set this parameter

=over 4	

=item C<ConvertImage> (boolean): activate/deactivate the adaptation of images to the device

=item C<ResizeImageDirectory>: where the new images are saved for cache system, remember this directory must be into docroot directory and also must be writeble from the server

=item C<WurflNetDownload> (boolean): if you want to download WURFL xml directly from WURFL site or from an intranet URL (good to have only single point of Wurfl access), default is set to false

=item C<DownloadWurflURL>: the url of WURFL DB to download**

=item C<CapabilityList> : is the capability value you want to pass to you site

=item C<MobileVersionUrl>: is the URL address of mobile version site *

=item C<FullBrowserUrl>: is the URL address of PC version site *

=item C<RedirectTranscoderURL>: the URL where you want to redirect the transcoder*

=item C<LoadWebPatch> (boolean): if you want to use a wurfl patch file

=item C<PatchWurflNetDownload>(boolean): if you want download the patch file

=item C<PatchWurflUrl>: the URL of the patch file (is readed ony if PatchWurflNet is setted with true)

=back

*if you put a relative url (for example "/path") the filter done an internal redirect, if you put a url redirect with protocol (for example "http:") the filter done a classic redirect. If the parameter is not set the filter is a passthrough 

**if you want to download directly the last version of WURFL.xml you can set the url parameter to http://downloads.sourceforge.net/wurfl/wurfl-latest.zip

*** for more info about transcoder problem go to http://wurfl.sourceforge.net

=head1 SEE ALSO

For more details: http://www.idelfuschini.it/apache-mobile-filter-v2x.html

Mobile Demo page of the filter: http://apachemobilefilter.nogoogle.it (thanks Ivan alias sigmund)

Demo page of the filter: http://apachemobilefilter.nogoogle.it/php_test.php (thanks Ivan alias sigmund)

=head1 AUTHOR

Idel Fuschini (idel.fuschini [at] gmail [dot] com)

=cut
