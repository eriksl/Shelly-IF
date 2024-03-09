#!/usr/bin/perl -w

use Shelly::IF qw(data);
use Getopt::Long;
use Data::Dumper;
use DateTime;
use POSIX qw(sleep);

use constant { usage_string => "usage: shellyif.pl [-w|--watch] [-h|-?|--help] <host> [<host>]\n    watch = repeat endlessly\n" };

my($option_help) = 0;
my($option_watch) = 0;

my($getopt) = Getopt::Long::Parser->new("config" => [ "gnu_getopt", "no_ignore_case" ]);
$result = $getopt->getoptions("w|watch" => \$option_watch, "h|?|help"  => \$option_help);

die(usage_string) if(!$result || $option_help);
die(usage_string) if(scalar(@ARGV) eq 0);

my($error, $host, $host2);
my($shellyif, %shellyif);
my($total_power, $total_current);

STDOUT->autoflush(1);

while(defined($host = shift(@ARGV)))
{
	$shellyif = new Shelly::IF($host);
	$error = $shellyif->get_error();
	die($error) if(defined($error));

	$host2 = $host;
	$shellyif{$host} = $shellyif;
}

if($option_watch && (scalar(keys(%shellyif)) > 1))
{
	for(;;)
	{
		printf("%s\n", $shellyif->dump_header());
		$total_power = 0;
		$total_current = 0;

		for $host (sort(keys(%shellyif)))
		{
			$shellyif = $shellyif{$host};
			printf("%s\n", $shellyif->dump());
			$total_power += $shellyif->get_power();
			$total_current += $shellyif->get_current();
		}

		if(scalar(keys(%shellyif)) > 1)
		{
			printf("%-16s %-13s %-16s %8.1f %8s %7.1f\n",
				"TOTAL",
				"",
				"",
				$total_power,
				"",
				$total_current);
		}

		sleep(1);

		for $host (sort(keys(%shellyif)))
		{
			$shellyif = $shellyif{$host};
			die($shellyif->get_error()) if(!$shellyif->update());
		}
	}

	exit(0);
}

if($option_watch)
{
	$shellyif = $shellyif{$host2};

	printf("%s\n", $shellyif->dump_header());

	for(;;)
	{
		printf("%s\r", $shellyif->dump());
		sleep(1);
		die($shellyif->get_error()) if(!$shellyif->update());
	}

	exit(0);
}

$shellyif = $shellyif{$host2};
printf("%s\n", $shellyif->dump_header());

for $host (sort(keys(%shellyif)))
{
	$shellyif = $shellyif{$host};
	$total_power += $shellyif->get_power();
	$total_current += $shellyif->get_current();
	printf("%s\n", $shellyif->dump());
}

if(scalar(keys(%shellyif)) > 1)
{
	printf("%-16s %-13s %-16s %8.1f %8s %7.1f\n",
		"TOTAL",
		"",
		"",
		$total_power,
		"",
		$total_current);
}
