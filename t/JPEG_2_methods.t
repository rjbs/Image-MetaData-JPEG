use Test::More;
use strict;
use warnings;
use Image::MetaData::JPEG;

my $cname  = 'Image::MetaData::JPEG';
my $tphoto = 't/test_photo.jpg';
my $tdata  = 't/test_photo.desc';
my $cphoto = 't/test_photo_copy.jpg';
my $ref    = '\[REFERENCE\].*-->.*$';
my ($lines, $image, $image_2, @desc, @desc_2, $h1, $h2, $status);

#=======================================
diag "Testing JPEG object generic methods";
plan tests => 16;
#=======================================

#########################
ok( -e $tdata, "Metadata file exists" );
open(ZZ, $tdata); $lines = my @a = <ZZ>; close(ZZ);

#########################
$image = $cname->new($tphoto);
@desc  = map { s/$ref//; $_ } split /\n/, $image->get_description();
is( @desc, $lines, "Description from file" );

#########################
open(ZZ, $tdata); @desc_2 = map { chomp; s/$ref//; $_ } <ZZ>; close(ZZ);
is_deeply( \@desc, \@desc_2, "Detailed description check");

#########################
open(my $handle, "<", $tphoto);
read($handle, my $buffer, -s $tphoto); close($handle);
$image_2 = new $cname(\ $buffer);
@desc_2 = map { s/$ref//; $_ } split /\n/, $image_2->get_description();
is( @desc_2, $lines, "Description from reference" );

#########################
$h1 = shift @desc; $h2 = shift @desc_2;
isnt( $h1, $h2, "Descriptions differing (header)" );

#########################
is_deeply( \@desc, \@desc_2, "The two descriptions are the same" );

#########################
is( $image->get_segments("^S"), 3, "Segments beginning with S" );

#########################
is_deeply( [$image->get_segments("^S", "INDEXES")], [0, 5, 7],
	   "Segments through their indexes" );

#########################
is_deeply( [$image->get_dimensions()], [2160, 1440], "Image dimensions" );

#########################
is( $image->find_new_app_segment_position(), 5, "New APPx position" );

#########################
ok( $image->save($cphoto), "Exit status of save()" );
unlink $cphoto;

#########################
$image = $cname->new($tphoto, "COM");
ok( $image->save($cphoto), "Exit status of save() (2)" );
unlink $cphoto;

#########################
is_deeply( [$image->get_dimensions()], [0, 0],
	   "No dimensions without SOF segment" );

#########################
$image = $cname->new($tphoto, 'APP1$', "FASTREADONLY");
ok( ! $image->save($cphoto), "Do not save incomplete files" );
unlink $cphoto;

#########################
is( $image->get_segments(), 1, "Number of APP1 segments");

#########################
is( $image->find_new_app_segment_position(), 0,
    "find_new_app_segment_position not fooled by only 1 segment" );

### Local Variables: ***
### mode:perl ***
### End: ***
