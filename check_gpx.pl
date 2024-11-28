#!/Users/brian/bin/perl

use v5.36;
use Mojo::Util qw(dumper);

use lib qw(lib);
use Local::Geofence;

sub debug (@m) {
	return unless $ENV{DEBUG};
	say STDERR @m;
	}

my @fences = Local::Geofence->extract_fences_from_kml( glob("fences/us/*/*.kml") );
say STDERR "There are " . @fences . " fences";

foreach my $file (@ARGV) {
	say '=' x 50, "\n", $file;

	my $file = Mojo::File->new($file);
	my $contents = $file->slurp;
	my $points = Mojo::DOM->new( $contents )->xml(1)->find( 'trkpt' )->each( \&extract_coordinates )->to_array;
	say STDERR "\tThere are " . @$points . " points";

	my @contains;
	foreach my $fence ( @fences ) {
		my $fraction = $fence->fraction_inside( $points );
		#printf "\t%s: %.2f\n", $fence->name, $fraction;
		push @contains, [ $fence, $fraction ] if $fraction > 0.10;
		}

	foreach my $tuple ( sort { $b->[1] <=> $a->[1] } @contains ) {
		my( $fence, $fraction ) = $tuple->@*;
		printf "\ttrack %.2f contained in <%s> from <%s>\n", $fraction, $fence->name, $fence->file;
		}

	if( @contains == 0 ) {
		say "\tno geofence contains this track";
		}
	}

sub extract_coordinates {
	my $node = $_;
	my( $lat, $lon ) = map { $node->attr( $_ ) } qw(lat lon);
	return { lat => $lat, lon => $lon };
	}
