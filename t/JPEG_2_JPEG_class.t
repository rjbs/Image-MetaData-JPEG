use Test::More;
use strict;
use warnings;
use Image::MetaData::JPEG;
use Image::MetaData::JPEG::Segment;

my $tphoto = 't/test_photo.jpg';
my $tdata  = 't/test_photo.desc';
my $cphoto = 't/test_photo_copy.jpg';
my $ref    = '\[REFERENCE\].*-->.*$';
my $trim = sub { $_[0] =~ s/at.*//; chomp $_[0]; $_[0] };
my ($lines, $image, $image_2, $error, $handle, $buffer, $bufferref,
    @desc, @desc_2, $seg, $h1, $h2, $status, $num, $num2, @segs1, @segs2);

#=======================================
diag "Testing [Image::MetaData::JPEG]";
plan tests => 47;
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
ok( ! $image, 'Fail OK: ' . &$trim($::cname->Error()) );

#########################
$image = $::cname->new(\ '');
ok( ! $image, 'Fail OK: ' . &$trim($::cname->Error()) );

#########################
$image = $::cname->new($tphoto);
ok( $image, "Plain constructor" );

#########################
isa_ok( $image, $::cname );

#########################
open($handle, "<", $tphoto); binmode($handle); # for Windows
read($handle, $buffer, -s $tphoto); close($handle);
$bufferref = \ $buffer;
$image_2 = $::cname->new($bufferref);
ok( $image_2, "Constructor with reference" );

#########################
$_->{parent} = $image for @{$image_2->{segments}}; # hack for parental link
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

#########################
ok( -e $tdata, "Metadata file exists" );
open(ZZ, $tdata); $lines = my @a = <ZZ>; close(ZZ);

#########################
$image = $::cname->new($tphoto);
@desc  = map { s/$ref//; $_ } split /\n/, $image->get_description();
is( @desc, $lines, "Description from file" );

#########################
open(ZZ, $tdata); @desc_2 = map { chomp; s/$ref//; $_ } <ZZ>; close(ZZ);
is_deeply( \@desc, \@desc_2, "Detailed description check");

#########################
open($handle, "<", $tphoto); binmode($handle); # for Windows
read($handle, $buffer, -s $tphoto); close($handle);
$image_2 = $::cname->new($bufferref);
@desc_2 = map { s/$ref//; $_ } split /\n/, $image_2->get_description();
is( @desc_2, $lines, "Description from reference" );

#########################
$h1 = shift @desc; $h2 = shift @desc_2;
isnt( $h1, $h2, "Descriptions differing (header)" );

#########################
is_deeply( \@desc, \@desc_2, "The two descriptions are the same" );

#########################
$num = scalar grep { /^\s*\d+B <.*>\s*$/ } @desc;
"dddxx" =~ /dddxx/; # test stupid Perl behaviour with m//
is( scalar $image->get_segments(), $num, "Get all segments (undef string)" );

#########################
"dddxx" =~ /dddxx/; # test stupid Perl behaviour with m//
is( scalar $image->get_segments(""), $num, "Get all segments (empty string)" );

#########################
is( $image->get_segments("^S"), 3, "Segments beginning with S" );

#########################
is_deeply( [$image->get_segments("^S", "INDEXES")], [0, 7, 10],
	   "Segments through their indexes" );

#########################
is_deeply( [$image->get_dimensions()], [432, 288], "Image dimensions" );

#########################
is( $image->find_new_app_segment_position(), 7, "New APPx position" );

#########################
ok( $image->save($cphoto), "Exit status of save()" );
unlink $cphoto;

#########################
ok( eval { $image->save($bufferref); }, "Image saved to memory" );

#########################
$image_2 = $::cname->new($bufferref);
isa_ok( $image_2, $::cname );

#########################
$_->{parent} = $image for @{$image_2->{segments}}; # parental link hack
is_deeply( $image->{segments}, $image_2->{segments},
	   "From-disk and in-memory compare equal" );

#########################
$image = $::cname->new($tphoto, 'COM');
ok( $image->save($bufferref), "Exit status of save() (2)" );

#########################
is_deeply( [$image->get_dimensions()], [0, 0],
	   "No dimensions without SOF segment" );

#########################
$image = $::cname->new($tphoto, 'APP1$', "FASTREADONLY");
ok( ! $image->save($bufferref), "Do not save incomplete files" );

#########################
is( $image->get_segments(), 1, "Number of APP1 segments");

#########################
is( $image->find_new_app_segment_position(), 0,
    "find_new_app_segment_position not fooled by only 1 segment" );

#########################
$image = $::cname->new($tphoto);
$num  = scalar $image->get_segments();
$num2 = scalar $image->get_segments('^(APP\d{1,2}|COM)$');
$image->drop_segments('METADATA');
is( scalar $image->get_segments(), $num - $num2, "All metadata erased" );

#########################
is( scalar $image->get_segments('^(APP\d{1,2}|COM)$'), 0,
    "... infact, they are no more there" );

#########################
eval { $image->drop_segments() };
isnt( $@, '', "drop_segments' regex cannot be undefined" );

#########################
eval { $image->drop_segments('') };
isnt( $@, '', "drop_segments' regex cannot be an empty string" );

#########################
$image = $::cname->new($tphoto);
$num  = scalar $image->get_segments();
$num2 = scalar $image->get_segments('^COM$');
$image->drop_segments('COM');
is( scalar $image->get_segments(), $num - $num2, "All comments erased" );

#########################
$image = $::cname->new($tphoto);
$num  = scalar $image->get_segments();
$num2 = scalar $image->get_segments('^APP\d{1,2}$');
$image->drop_segments('APP\d{1,2}');
is( scalar $image->get_segments(), $num - $num2, "All APP segments erased" );

#########################
@segs1 = $image->get_segments();
eval { $image->insert_segments() };
is( $@, '', "insert_segments without a segment does not fail" );

#########################
@segs2 = $image->get_segments();
is_deeply( \ @segs1, \ @segs2, "... but segments are not changed" );

#########################
$seg = new Image::MetaData::JPEG::Segment($image, 'COM', \ 'dummy');
eval { $image->insert_segments($seg, 0) };
isnt( $@, '', "... pos=0 fails miserably" );

#########################
eval { $image->insert_segments($seg, scalar $image->get_segments()) };
isnt( $@, '', "... pos=last also" );

#########################
@segs2 = $image->get_segments();
is_deeply( \ @segs1, \ @segs2, "... segments still unchanged" );

#########################
$image->insert_segments($seg, 3);
@segs1 = $image->get_segments();
splice @segs2, 3, 0, $seg;
is_deeply( \ @segs1, \ @segs2, "inserting a segment with pos=3" );

#########################
splice @segs2, $image->find_new_app_segment_position(), 0, $seg;
$image->insert_segments($seg);
@segs1 = $image->get_segments();
is_deeply( \ @segs1, \ @segs2, "... now with automatic positioning" );

#########################
$image->insert_segments([$seg, $seg], 9);
@segs1 = $image->get_segments();
splice @segs2, 9, 0, $seg, $seg;
is_deeply( \ @segs1, \ @segs2, "inserting more than one segment" );

#########################
$image->insert_segments([$seg, $seg], 1, 3);
@segs1 = $image->get_segments();
splice @segs2, 1, 3, $seg, $seg;
is_deeply( \ @segs1, \ @segs2, "overwriting instead of inserting" );

### Local Variables: ***
### mode:perl ***
### End: ***
