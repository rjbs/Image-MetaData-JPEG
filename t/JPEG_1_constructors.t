use Test::More;
use strict;
use warnings;

my $tphoto = 't/test_photo.jpg';
my ($image, $image_2, $error);
my $trim = sub { $_[0] =~ s/at.*//; chomp $_[0]; $_[0] };

#=======================================
diag "Testing JPEG object constructors";
plan tests => 10;
#=======================================

#########################
BEGIN { $::cname  = 'Image::MetaData::JPEG'; use_ok $::cname; }

#########################
ok( -s $tphoto, "Test photo exists" );

#########################
$image = $::cname->new("'Invalid'");
ok( ! $image, &$trim($::cname->Error()) );

#########################
$image = $::cname->new(undef);
ok( ! $image, &$trim($::cname->Error()) );

#########################
$image = $::cname->new($tphoto);
ok( $image, "Plain constructor" );

#########################
isa_ok( $image, $::cname, "Constructed object" );

#########################
open(my $handle, "<", $tphoto); binmode($handle); # for Windows
read($handle, my $buffer, -s $tphoto); close($handle);
$image_2 = new $::cname(\ $buffer);
ok( $image_2, "Constructor with reference" );

#########################
is_deeply( $image->{segments}, $image_2->{segments},
	   "The two objects coincide" );

#########################
$error = $::cname->Error();
is( $error, undef, "Ctor error unset (default)" );

#########################
$image = new $::cname($tphoto, "COM|SOF");
ok( $image, "Restricted constructor" );

#########################
$image = new $::cname($tphoto, "COM|SOF", "FASTREADONLY");
ok( $image, "Fast constructor" );

### Local Variables: ***
### mode:perl ***
### End: ***
