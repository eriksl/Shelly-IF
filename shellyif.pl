#!/usr/bin/perl -w

use Shelly::IF qw(data);
use Getopt::Long;
use Data::Dumper;
use DateTime;
use POSIX qw(sleep);

Getopt::Long::Configure("gnu_getopt");
Getopt::Long::Configure("no_ignore_case");

use constant { usage_string => "usage: shellyif.pl [-w|--watch] [-h|-?|--help] <host>\n    watch = repeat endlessly\n" };

my($option_help) = 0;
my($option_watch) = 0;

my($result) = GetOptions
(
	"w|watch"	=> \$option_watch,
	"h|?|help"  => \$option_help,
);

die(usage_string) if(!$result || $option_help);
die(usage_string) if(scalar(@ARGV) eq 0);

my($error);
my($shellyif);

STDOUT->autoflush(1);

$shellyif = new Shelly::IF($ARGV[0]);
$error = $shellyif->get_error();
die($error) if(defined($error));

printf("%s\n", $shellyif->dump_header());

if($option_watch)
{
	for(;;)
	{
		printf("%s\r", $shellyif->dump(1));
		sleep(1);
		die($shellyif->get_error()) if(!$shellyif->update());
	}
}
else
{
	printf("%s\n", $shellyif->dump(1));
}
