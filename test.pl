#!/Users/brian/bin/perl

use v5.36;
use Mojo::Util qw(dumper);

use lib qw(lib);
use Local::Geofence;

sub debug (@m) {
	return unless $ENV{DEBUG};
	say STDERR @m;
	}

my $outside = <<~"HERE";
	40.6574697,-73.975247
	40.6532831,-73.9749614
	40.7428629,-73.9581349
	40.7175181,-74.0216681
	40.7428629,-73.9581349
	40.7175181,-74.0216681
	HERE
my @outside =
	map { [ (split /,/)[1,0] ] }
	split /\R/, $outside;

my $inside = <<~"HERE";
	40.6601843,-73.9675408
	40.6688489,-73.9712412
	40.6525282,-73.9705162
	40.6545378,-73.9675625
	40.6622843,-73.9754983
	40.6602101,-73.9750228
	HERE
my @inside =
	map { [ (split /,/)[1,0] ] }
	split /\R/, $inside;

my @fences = Local::Geofence->extract_fences_from_kml( glob("fences/us/ny/*.kml") );


my( $fence ) = grep { $_->name_is( 'Prospect Park' ) } @fences;

say "---- These should be inside Prospect Park";
foreach my $p ( @inside ) {
	debug "-" x 30;
	my $inside = $fence->is_inside( $p->@* );
	say "@$p -> $inside";
	}

say "---- These should be outside Prospect Park";
foreach my $p ( @outside ) {
	debug "-" x 30;
	my $inside = $fence->is_inside( $p->@* );
	say "@$p -> $inside";
	}


foreach my $point ( @inside, @outside ) {
	say "POINT: @$point";
	foreach my $fence ( @fences ) {
		my $in = $fence->is_inside( $point->@* );
		say "\t", ($in ? "is in " : "is not in "), $fence->name;
		}
	}
