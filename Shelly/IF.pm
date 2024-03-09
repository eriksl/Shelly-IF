use strict;
use warnings;
use feature "signatures";

use LWP::UserAgent;
use JSON::Parse;

package Shelly::IF;

use constant { model_plug_s => "plug-s", model_plug_plus_s => "plug-plus-s", model_pm_mini => "pm-mini" };

sub _set_error($self, $error)
{
	$self->{"_error"} = sprintf("Shelly:IF: %s", $error);
	return($self);
}

sub get_error($self)
{
	return($self->{"_error"});
}

sub _json($self, $json_string)
{
	$json_string =~ s/:null/:"NULL"/og;
	$json_string =~ s/:false/:"FALSE"/og;
	$json_string =~ s/:true/:"TRUE"/og;

	eval { JSON::Parse::assert_valid_json($json_string); };

	if($@)
	{
		$self->_set_error(sprintf("_json: %s". join(" ", $@)));
		return(undef);
	}

	return(JSON::Parse::parse_json($json_string));
}

sub _get_json($self, $suburl)
{
	my($ua, $req, $res, $url);

	$url = sprintf("http://%s/%s", $self->{"_host"}, $suburl);
	$ua = LWP::UserAgent->new(timeout => 0.5);
	$req = HTTP::Request->new("GET" => $url);
	$res = $ua->request($req);

	if(!$res->is_success)
	{
		$self->_set_error(sprintf("_get_json %s: %s", $res->status_line, $res->decoded_content));
		return(undef);
	}

	return($self->_json($res->decoded_content));
}

sub update($self)
{
	my($data);

	if(!defined($self->{"_generation"}))
	{
		$self->_set_error("unknown device");
		return(0);
	}

	if($self->{"_generation"} == 1)
	{
		return(0) if(!defined($data = $self->_get_json("status")));
		$self->{"_timestamp"} =		$data->{"meters"}[0]{"timestamp"};
		$self->{"_temperature"} =	$data->{"temperature"};
		$self->{"_power"} =			$data->{"meters"}[0]{"power"};
		$self->{"_voltage"} =		230;
		$self->{"_current"} =		$self->{"_power"} / $self->{"_voltage"};
	}
	elsif($self->{"_generation"} == 2)
	{
		return(0) if(!defined($data = $self->_get_json("rpc/Shelly.GetStatus")));
		$data = $data->{$self->{"_output"}};
		$self->{"_timestamp"} =		$data->{"aenergy"}{"minute_ts"};
		$self->{"_temperature"} =	$data->{"temperature"}{"tC"};
		$self->{"_power"} =			$data->{"apower"};
		$self->{"_voltage"} =		$data->{"voltage"};
		$self->{"_current"} =		$data->{"current"};

		$self->{"_temperature"} = 0 if(!defined($self->{"_temperature"}));
	}
	else
	{
		$self->_set_error("unknown device");
		return(0);
	}

	return(1);
}

sub new($class, $host)
{
	my($self) =
	{
		"_host" => $host,
	};
	my($data);

	bless($self, $class);

	return($self) if(!defined($data = $self->_get_json("shelly")));

	if(exists($data->{"type"}) && defined($data->{"type"}))
	{
		$self->{"_generation"} = 1;
		$self->{"_type"} = $data->{"type"};
	}

	if(exists($data->{"app"}) && defined($data->{"app"}))
	{
		$self->{"_generation"} = 2;
		$self->{"_type"} = $data->{"app"};
	}

	if(!defined($self->{"_generation"}))
	{
		$self->_set_error("unknown device");
		return($self);
	}

	if($self->{"_generation"} == 1)
	{
		return($self) if(!defined($data = $self->_get_json("settings")));
		$self->{"_output_name"} = $data->{"relays"}[0]{"name"};
		$self->{"_typestring"} = "Plug-S";
	}
	elsif($self->{"_generation"} == 2)
	{
		return($self) if(!defined($data = $self->_get_json("rpc/Shelly.GetConfig")));

		if(exists($data->{"switch:0"}))
		{
			$self->{"_output"} =		"switch:0";
			$self->{"_typestring"} =	"Plug-Plus-S";
		}

		if(exists($data->{"pm1:0"}))
		{
			$self->{"_output"} =		"pm1:0";
			$self->{"_typestring"} =	"Plus-PM-Mini";
		}

		$self->{"_output_name"} = $data->{$self->{"_output"}}{"name"};
	}
	else
	{
		$self->_set_error("unknown device");
		return($self);
	}

	$self->update();

	return($self);
}

sub get_type($self)
{
	return($self->{"_type"});
}

sub get_type_string($self)
{
	return($self->{"_typestring"});
}

sub get_timestamp($self)
{
	return($self->{"_timestamp"});
}

sub get_time_string($self)
{
	my($dt);

	if($self->{"_generation"} == 1)
	{
		$dt = DateTime->from_epoch("epoch" => $self->get_timestamp(), time_zone => "GMT");
	}
	else
	{
		$dt = DateTime->from_epoch("epoch" => $self->get_timestamp(), time_zone => "Europe/Amsterdam");
	}

	return(sprintf("%s %s", $dt->ymd, $dt->hms));
}

sub get_power($self)
{
	return($self->{"_power"});
}

sub get_voltage($self)
{
	return($self->{"_voltage"});
}

sub get_current($self)
{
	return($self->{"_current"});
}

sub get_temperature($self)
{
	return($self->{"_temperature"});
}

sub get_output($self)
{
	return($self->{"_output_name"});
}

sub dump_header($self)
{
	return(sprintf("%-16s %-13s %-16s %8s %8s %7s %11s %s", "host", "type", "output", "power", "voltage", "current", "temperature", "time"));
}

sub dump($self)
{
	return(sprintf("%-16s %-13s %-16s %8.1f %8.1f %7.1f %11.1f %s",
			$self->{"_host"},
			$self->get_type_string(),
			$self->get_output(),
			$self->get_power(),
			$self->get_voltage(),
			$self->get_current(),
			$self->get_temperature(),
			$self->get_time_string()));
}

1;
