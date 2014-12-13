#!/usr/bin/perl
use warnings;
use Digest::SHA qw(hmac_sha256_base64);
require LWP::UserAgent;

my $key = '[insert your WSKey here]';				##Your WSKey from OCLC
my $secret = '[insert your secret key here]'; 		##Your secret key from OCLC
my $oclcurl = 'www.oclc.org';
my $httpmethod = 'POST';
my $port = '443';
my $path = '/wskey';                                                                                             



open (FILE, "C:/worldcat_holdings_project/oclcnos_to_add.txt") or die("Unable to open file");	##open the text file you have exported from your local system of OCLC numbers to set holdings on

my $filename = 'C:/worldcat_holdings_project/oclc_add_log.txt'; 		##Log file for responses
open my $fh, ">>", $filename or die("Could not open file. $!");

my $ua = LWP::UserAgent->new;
$ua->timeout(10);


while (my $line = <FILE>) {
	chomp($line);
	$oclcnum = $line;			##Read in each OCLC number as variable $oclcnum
my $nonce = int(rand(1000000));		##Set nonce for authentication string
my $timestamp = time;							##Set current time for authentication string
## Create the search string
my $search = 'cascade=0' . "\n" . 'classificationScheme=LibraryOfCongress' . "\n" . 'inst=1581' . "\n" . 'oclcNumber=' . $oclcnum;
## Create the request header
my $string = $key . "\n" . $timestamp . "\n" . $nonce . "\n" . "\n" .$httpmethod . "\n" . $oclcurl . "\n" . $port . "\n" . $path . "\n" . $search . "\n";

$encodedstring = hmac_sha256_base64($string, $secret);			##Hash the authentication string in SHA-256

while (length($encodedstring) % 4) {
                $encodedstring .= '=';
        }


## Set the request
my $authheader = 'http://www.worldcat.org/wskey/v2/hmac/v1 clientId="[insert OCLC client ID here]", timestamp="' . $timestamp . '", nonce="' . $nonce . '", signature="' . $encodedstring . '", principalID="[insert OCLC principal ID here]", principalIDNS="[insert OCLC principal IDNS here]a"';
## And send it!
my $response = $ua->post('https://worldcat.org/ih/data?classificationScheme=LibraryOfCongress&inst=[insert OCLC institution number here]&oclcNumber=' . $oclcnum . '&cascade=0', 'Authorization' => $authheader);

 
 
print $fh $oclcnum . ' : ' . $response->status_line( ) . "\n";	##Log OCLC number and response
	
}
    
