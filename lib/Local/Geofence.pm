#!/Users/brian/bin/perl

package Local::Geofence;

use v5.36;

use Mojo::File;
use Mojo::DOM;
use Mojo::Util qw( dumper );

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

sub debug (@m) {
	return unless $ENV{DEBUG};
	say STDERR @m;
	}

sub extract_fences_from_kml ( $class, @files ) {
	my @fences;

	FILE: foreach my $file ( @files ) {
		unless( -e $file ) {
			warn "File <$file> does not exist. Skipping\n";
			next FILE;
			}

		my $data = Mojo::File->new($file)->slurp;
		my $dom = Mojo::DOM->new( $data );

		my $placemark = $dom->at( 'kml Document Placemark' );

		my $name = $placemark->at( 'name' )->text;
		my @coordinates =
			map { [ split /,/ ] }
			split /\s+/,
			$placemark->at( 'coordinates' )->text =~ s/\A\s+|\s+\z//gr
			;

		pop @coordinates if(
			$coordinates[0][0] eq $coordinates[-1][0]
				&&
			$coordinates[0][1] eq $coordinates[-1][1]
			);

		push @fences, $class->new(
			file => $file,
			name => $name,
			vertices => \@coordinates,
			);
		}

	return @fences;
	}

sub new ($class, %args) {
	my( $name, $vertices ) = @args{ qw(name vertices) };
	my @vertices = $vertices->@*;

	my @edges = map {
		[ map { [ $_->@[0,1] ] } @vertices[$_, $_+1] ]
		} (-1 .. $#vertices - 1);

	foreach my $edge ( @edges ) {
		my( $x0, $y0 => $x1, $y1 ) = map { $_->@* } $edge->@*;
		my $slope = ( $y1 - $y0 ) / ( $x1 - $x0 );
		my $intercept = $y0 - $slope * $x0;
		push $edge->@*, $slope, $intercept;
		}

	my %hash = ( file => $args{file}, name => $name, edges => \@edges );
	bless \%hash, $class;
	}

sub all_x ( $self ) { map { $_->[0][0], $_->[1][0] } $self->edges->@* }
sub all_y ( $self ) { map { $_->[0][1], $_->[1][1] } $self->edges->@* }

sub edges ( $self ) { $self->{edges} }

sub lowest_x  ( $self ) { $self->{lowest_x}  //= ( sort { $a <=> $b } $self->all_x )[ 0] }
sub lowest_y  ( $self ) { $self->{lowest_y}  //= ( sort { $a <=> $b } $self->all_y )[ 0] }
sub highest_x ( $self ) { $self->{highest_x} //= ( sort { $a <=> $b } $self->all_x )[-1] }
sub highest_y ( $self ) { $self->{highest_y} //= ( sort { $a <=> $b } $self->all_y )[-1] }

sub bounding_box ( $self, $x, $y ) {
	$self->{bounding_box} //= [
		[ $self->lowest_x, $self->lowest_y ],
		[ $self->highest_x, $self->highest_y ],
		];
	}

sub in_bounding_box ( $self, $x, $y ) {
	$x >= $self->lowest_x && $x <= $self->highest_x
		&&
	$y >= $self->lowest_y && $y <= $self->highest_y
	}

sub is_inside ( $self, $x, $y ) {
	my $left_nodes = 0;

	debug "Threshold Y: $y";

	EDGE: foreach my $edge ( $self->edges->@* ) {
		my( $ix, $iy ) = $edge->[0]->@*;
		my( $jx, $jy ) = $edge->[1]->@*;
		my( $slope, $intercept ) = $edge->@[2,3];

		# is the edge across the Y? If not, this edge isn't important to us
		debug "Line from $ix, $iy -> $jx, $jy";
		my $crosses = ( ( $iy <= $y ) && ( $jy >= $y ) ) || ( ( $jy <= $y ) && ( $iy >= $y ) );
		if( $crosses ) {
			debug "Threshold crossed";
		} else { next EDGE };

		next unless $crosses;

		# now to see if the X coordinate of the edge at the threshold Y is on the right or left
		my $on_the_left = eval {
			my $xp = ( $y - $intercept ) / $slope;
			debug "XP: $xp";
			debug "$xp <\n$x ?";
			$xp < $x;
			};
		no warnings 'uninitialized';
		next EDGE unless $on_the_left;
		debug "XP is on the left";
		$left_nodes++;
		}

	debug "left nodes is $left_nodes";
	return $left_nodes % 2;
	}

sub fraction_inside ( $self, $points ) {
	my $inside = 0;
	foreach my $point ( $points->@* ) {
		$inside++ if $self->is_inside( $point->@{qw(lon lat)} );
		}
	return 0 if $inside == 0;
	return $inside / @$points;
	}

sub file ($self) { $self->{file} }

sub name ($self) { $self->{name} }

sub name_is ($self, $name) { $self->{name} eq $name }

__PACKAGE__;

__END__
	<Placemark>
		<name>Green-Wood</name>
		<styleUrl>#msn_ylw-pushpin</styleUrl>
		<Polygon>
			<tessellate>1</tessellate>
			<outerBoundaryIs>
				<LinearRing>
					<coordinates>
						-73.98853015107304,40.65912357390551,0 -73.9899752419263,40.65765899281438,0 -73.99197049830485,40.65865282076899,0 -73.99291220895745,40.65810683264586,0 -73.99502841317025,40.65937710925851,0 -74.00199969256586,40.65280667202174,0 -73.99769270644609,40.65037133879553,0 -73.99821494957048,40.64977256279803,0 -73.98910711610608,40.64436036820816,0 -73.9804822367404,40.64780048611922,0 -73.98174497987107,40.65538771402627,0 -73.98853015107304,40.65912357390551,0
					</coordinates>
				</LinearRing>
			</outerBoundaryIs>
		</Polygon>
	</Placemark>


__END__
# http://alienryderflex.com/polygon/

# https://www.codeproject.com/Articles/62482/A-Simple-Geo-Fencing-Using-Polygon-Method

bool pointInPolygon() {

  int   i, j=polyCorners-1 ;
  bool  oddNodes=NO      ;

  for (i=0; i<polyCorners; i++) {
    if (polyY[i]<y && polyY[j]>=y ||  polyY[j]<y && polyY[i]>=y) {
      if (polyX[i]+(y-polyY[i])/(polyY[j]-polyY[i])*(polyX[j]-polyX[i])<x) {
        oddNodes=!oddNodes;
      }
    }
    j=i;
  }

  return oddNodes; }

public bool FindPoint(double X, double Y)
{
            int sides = this.Count() - 1;
            int j = sides - 1;
            bool pointStatus = false;
            for (int i = 0; i < sides; i++)
            {
                if (myPts[i].Y < Y && myPts[j].Y >= Y ||
			myPts[j].Y < Y && myPts[i].Y >= Y)
                {
                    if (myPts[i].X + (Y - myPts[i].Y) /
			(myPts[j].Y - myPts[i].Y) * (myPts[j].X - myPts[i].X) < X)
                    {
                        pointStatus = !pointStatus ;
                    }
                }
                j = i;
            }
            return pointStatus;
}
