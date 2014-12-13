#!/usr/bin/perl

use warnings;
use LWP::Simple;
use XML::XPath;
use Digest::SHA qw(hmac_sha256_base64);
require LWP::UserAgent;


my $fileno = 1;
while ($fileno < 10)							## With the processing speeds I experinced, doing 10 files per night was about right.	
{
	step1();												## Run query, download XML file				
	$oclcfile = "oclcnos".$fileno.".txt";				## Name the output file
	step2($oclcfile);						## Extract the OCLC numbers, save in the output file
	$oclcdeletes = "oclcdeletes".$fileno.".txt";			## Name the delete log
	step3($oclcfile, $oclcdeletes);					## Send deletes to Metadata API, log the responses in the delete log
	
$fileno = $fileno + 1;
}
	

exit;

##################################
# subroutines
##################################


#########################################################################
# Name: Step1
# -----------------------------------------------------------------------
# Process:
#          1.  Get the XML records for our holdings in WorldCat.
#          2.  Save the files.
#########################################################################

sub step1
{
my $start = 1;
   while ($start < 10000){
	my $url = 'http://www.worldcat.org/webservices/catalog/search/sru?query=	## Base URL for Search API query
			srw.kw+any+"the"+or+srw.kw+any+"a"+or+srw.kw+any+"and"		## Use common 3 or 4 letter combinations as the keyword part of the search
			+and+srw.dt+any+"bks"						## Limited by material type
			+and+srw.li+any+"mno"						## Records with our holdings symbol (MNO) attached -- insert your holding symbol here
			&maximumRecords=100						## You can return up to 100 records in each call
			&startRecord='.$start.'						## You can page through all 10,000 records returned by the query
			&servicelevel=full						## Service level "full" required for the limiters
			&wskey=[insert your WSKey here]';				## Your OCLC Web Services Key (WSKey)


	my $content = get $url;								## URL to get data from
	die "Couldn't get $url" unless defined $content;				## In case there are issues with your query

	my $filename = "C:/worldcat_holdings_project/worldcat_".$start.".xml";		## Filename for XML files to be downloaded.  Each 100 record set will be saved with its 												## own file (worldcat_1.xml, worldcat_101.xml, etc.)
	open my $fh, ">", $filename or die("Could not open file. $!");
	
	print $fh $content;
	close $fh;

   $start = $start + 100;
}

print "Step 1 complete!\n";
}


#########################################################################
# Name: Step2
# -----------------------------------------------------------------------
# Process:
#          Extract OCLC Numbers
#########################################################################


sub step2
{
my $start = 1;
  while ($start < 10000){
	my $file = "C:/worldcat_holdings_project/worldcat_".$start.".xml";		## Grab the first XML file
	my $xp = XML::XPath->new(filename=>$file);					## Use XPath ...
	my $nodeset = $xp->find('//controlfield[@tag="001"]');				## ... to find and extract the 001

	my $filename = "C:/worldcat_holdings_project/".$oclcfile;			## Create a file to save the OCLC numbers in
	open my $fh, ">>", $filename or die("Could not open file. $!");

	my @oclcnos;
	if (my @nodelist = $nodeset->get_nodelist)	{
		@oclcnos = map($_->string_value, @nodelist);
		local $" = "\n";
		print $fh "@oclcnos\n";															## Print each OCLC number to the text file
	   } else {
		print $fh "Sorry, no matches!";											## If XPath couldn't find the node for the OCLC number
	   }

	close $fh;
	
   $start = $start + 100;
}

print "Step 2 complete! ".$oclcfile." created\n";

}  ## end step2


#########################################################################
# Name: Step3
# -----------------------------------------------------------------------
# Process:
#          Delete the holdings
#########################################################################


sub step3
{
## Set the variables for your HTTP Request

my $key = '[insert your WSKey]';					## Your Web Services Key
my $secret = '[insert your Secret key]';				## Your secret key from OCLC
my $oclcurl = 'www.oclc.org';
my $httpmethod = 'DELETE';								## For removing OCLC holdings
my $port = '443';
my $path = '/wskey';                                                                                             

open (FILE, "C:/worldcat_holdings_project/".$oclcfile) or die("Unable to open file"); ## Open the text file of OCLC numbers created in step 2

my $filename = 'C:/worldcat_holdings_project/'.$oclcdeletes;		## Create a file to log the results of each HTTP request
open my $fh, ">>", $filename or die("Could not open file. $!");

my(@fcont) = <FILE>;				## Load OCLC numbers into an array
close FILE;									## Close the file now that we have it loaded into memory

my $ua = LWP::UserAgent->new;		##Use LWP::UserAgent Perl class to send the web requests
$ua->timeout(10);


foreach $line (@fcont) {
	chomp($line);
	$oclcnum = $line;								## Read in each OCLC number as variable $oclcnum
my $nonce = int(rand(1000000));		## Set the nonce for the authentication string
my $timestamp = time;							## Grab the time for the authentication string

## Create the search string
my $search = 'cascade=0' . "\n" . 'classificationScheme=LibraryOfCongress' . "\n" . 'inst=1581' . "\n" . 'oclcNumber=' . $oclcnum;

## Create the request header
my $string = $key . "\n" . $timestamp . "\n" . $nonce . "\n" . "\n" .$httpmethod . "\n" . $oclcurl . "\n" . $port . "\n" . $path . "\n" . $search . "\n";

$encodedstring = hmac_sha256_base64($string, $secret);	##Hash the authentication string in SHA-256

while (length($encodedstring) % 4) {
                $encodedstring .= '=';
        }


## Set the request
my $authheader = 'http://www.worldcat.org/wskey/v2/hmac/v1 clientId="[insert your OCLC client ID here]", timestamp="' . $timestamp . '", nonce="' . $nonce . '", signature="' . $encodedstring . '", principalID="[insert your OCLC principal ID here]", principalIDNS="[insert your OCLC IDNS here]"';

## And send it!
my $response = $ua->delete('https://worldcat.org/ih/data?classificationScheme=LibraryOfCongress&inst=[insert your OCLC institution ID here]&oclcNumber=' . $oclcnum . '&cascade=0', 'Authorization' => $authheader);

 
 
print $fh $oclcnum . ' : ' . $response->status_line( ) . "\n";		##Log the OCLC number and response from the HTTP request
	
}
print "Step 3 complete! Check ".$oclcdeletes."\n";
}  ## end step3
