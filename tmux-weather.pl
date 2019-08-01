#!/usr/bin/env perl

use v5.14;
use utf8::all;
use JSON::MaybeXS;
use LWP::Simple;
use Path::Tiny;
use Try::Tiny;
use Scalar::Util qw(looks_like_number);

# Icons to use for various weather conditions
# See: https://openweathermap.org/weather-conditions

my %status_map = (
    '01d' => '🌞',
    '02d' => '⛅',
    '03d' => '☁️',
    '04d' => '🌥️',
    '09d' => '🌦️',
    '10d' => '🌧️',
    '11d' => '⛈️',
    '13d' => '❄️',
    '50d' => '🌁',
    '01n' => '🌛',
    '02n' => '☁️',
    '03n' => '☁️',
    '04n' => '☁️',
    '09n' => '🌧️',
    '10n' => '🌧️',
    '11n' => '🌩️',
    '13n' => '❄️',
    '50n' => '🌫️',
    '---' => '---',
);

# Location of configuration and cache files
my $cache_path  = "$ENV{'HOME'}/.cache/openweathermap/cache.json";
my $config_path = "$ENV{'HOME'}/.config/openweathermap/config.json";

&main();
exit;

# Load configuration file

sub get_config {
    die "Configuration file does not exist." unless -e -w -r $config_path;
    my $config_file = path( $config_path )->slurp;

    my $config_data;
    try {
        $config_data = decode_json( $config_file );
    }
    catch {
        die "The configuration file must be in JSON format";
    };

    my %config;
    for my $key ( qw(OW_API_KEY OW_CITY_ID OW_UNITS OW_DISPLAY_FORMAT) ) {
        $config{$key} = $config_data->{$key} // $ENV{$key}
            // die "The $key configuration parameter is missing";
    }

    return \%config;
}

# Loads cached weather data

sub open_cache {

    # Open the cache. Create it if it doesn't exist
    my $cache_file = path( $cache_path )->touchpath->slurp;

    my $cache_data;
    try {
        $cache_data = decode_json( $cache_file );
    }
    catch {
        return {};
    };
}

# Saves last downloaded weather data to disk

sub update_cache {
    path( $cache_path )->spew( encode_json( shift ) );
}

# Downloads the latest weather info. from OpenWeatherMap.org (OWM)

sub get_weather_data {
    my $config = shift;

    # Load cached weather data
    my $cache = open_cache();

    # Make sure that we're adhering to Open Weather Map API's terms of use
    # by downloading data once every 10+ minutes

    return $cache
        if ( looks_like_number( $cache->{'timestamp'} )
        && ( time - $cache->{'timestamp'} ) < 660 );

    my $api_url =
        "http://api.openweathermap.org/data/2.5/weather?id=$config->{'OW_CITY_ID'}&units=$config->{'OW_UNITS'}&appid=$config->{'OW_API_KEY'}";

    # Just in case we're unable to download weather data
    my %weather_data = ( status_code => '---', temperature => '', );

    my $content = get( $api_url )         or return \%weather_data;
    my $json    = decode_json( $content ) or die "$!";

    $weather_data{'status_code'} = $json->{'weather'}->[0]->{'icon'};
    $weather_data{'temperature'} = int( $json->{'main'}->{'temp'} );
    $weather_data{'timestamp'}   = time;

    update_cache( \%weather_data );

    return \%weather_data;
}

sub display_weather {
    my ( $config, $weather_data ) = @_;

    say [
        "$status_map{$weather_data->{'status_code'}} $weather_data->{'temperature'}°F",
        "$weather_data->{'temperature'}°F $status_map{$weather_data->{'status_code'}}",
        "$weather_data->{'temperature'}$status_map{$weather_data->{'status_code'}}",
        "$status_map{$weather_data->{'status_code'}}$weather_data->{'temperature'}",
        "$weather_data->{'temperature'}°$status_map{$weather_data->{'status_code'}}",
        "$status_map{$weather_data->{'status_code'}}°$weather_data->{'temperature'}",
    ]->[$config->{'OW_DISPLAY_FORMAT'}];
}

sub main {

    # Load configuration file
    my $config = get_config();

    display_weather( $config, get_weather_data( $config ) );
}
