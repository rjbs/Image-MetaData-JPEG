use Test::More;
use strict;
use warnings;
use Image::MetaData::JPEG;
use Image::MetaData::JPEG::Tables qw(:Lookups);

my $cname  = 'Image::MetaData::JPEG';
my $tphoto = 't/test_photo.jpg';
my $tthumb = 't/test_thumbnail.jpg';
my $tdata  = 't/test_photo.desc';
my ($image, $image2, $dataref, $dataref2, $hash, $hash2,
    $thumb, $result, $name);
my $val = sub { return JPEG_lookup('APP1@IFD0', $_[0]) }; # IFD0/1 indifferent

#=======================================
diag "Testing APP1 Exif data routines (thumbnail)";
plan tests => 26;
#=======================================

#########################
$image = $cname->new($tphoto, '^APP1$');
$hash = $image->get_Exif_data('ALL', 'TEXTUAL');
isnt( $image->retrieve_app1_Exif_segment(), undef,
      "The Exif segment is there, hi!" );

#########################
$dataref = $image->get_Exif_data('THUMBNAIL');
isnt( $dataref, undef, "Thumbnail data found" );

#########################
is( ref $dataref, 'SCALAR', "... as a reference to a scalar" );

#########################
$thumb = $cname->new($dataref);
ok( $thumb, "It is a valid JPEG image" );

#########################
$thumb = $cname->new($tthumb, '');
ok( $thumb, "JPEG Thumbnail read from disk" );

#########################
$thumb->save($dataref);
$thumb = $cname->new($dataref);
ok( $thumb, "JPEG Thumbnail 'saved' in memory" );

#########################
$result = $image->set_Exif_data($dataref, 'THUMBNAIL');
is_deeply( $result, {}, "Set new JPEG thumbnail (1): no error" );

#########################
$dataref2 = \ 'dummy';
$image->save($dataref2);
$image = $cname->new($dataref2, '^APP1$');
$dataref2 = $image->get_Exif_data('THUMBNAIL');
is_deeply( $dataref, $dataref2, "... it containes the new data block" );

#########################
$hash2 = $image->get_Exif_data('THUMB_DATA', 'TEXTUAL');
$name = 'JPEGInterchangeFormatLength';
ok( exists $$hash2{$name}, "Thumbnail length exists" );

#########################
is( $$hash2{$name}[0], length $$dataref,"... and is correct");

#########################
$hash2 = $image->get_Exif_data('ALL', 'TEXTUAL');
delete $$hash{'APP1'};             delete $$hash2{'APP1'};
delete $$hash{'APP1@IFD1'}{$name}; delete $$hash2{'APP1@IFD1'}{$name};
is_deeply( $hash, $hash2, "All other tags unchanged" );

#########################
$hash2 = $image->set_Exif_data(undef, 'THUMBNAIL');
ok( exists $$hash2{'ERROR'}, "Fail OK: " . $$hash2{'ERROR'} );

#########################
$image->set_Exif_data(\ '', 'THUMBNAIL');
$dataref2 = $image->get_Exif_data('THUMBNAIL');
is( $$dataref2, '', "Thumbnail removed with empty value" );

#########################
$dataref2 = $image->get_Exif_data('THUMB_DATA', 'TEXTUAL');
ok( ! exists $$dataref2{$_}, "No $_ tag" ) for
    ('Compression', 'JPEGInterchangeFormat', 'JPEGInterchangeFormatLength');

#########################
$result = $image->set_Exif_data($dataref, 'THUMBNAIL');
is_deeply( $result, {}, "Set new JPEG thumbnail (2): no error" );

#########################
$dataref2 = $image->get_Exif_data('THUMBNAIL');
is_deeply( $dataref, $dataref2, "... the data block is again there" );

#########################
$hash = $image->get_Exif_data('THUMB_DATA', 'TEXTUAL');
ok( exists $$hash{'Compression'}, "The Compression record exists" );

#########################
is_deeply( $$hash{'Compression'}, [6], "... and its value is six" );

#########################
ok( exists $$hash{$name}, "The $name record exists" );

#########################
is_deeply( $$hash{$name}, [length $$dataref], "... and matches thumb. size" );

#########################
$image->remove_app1_Exif_info();
$image->set_Exif_data($dataref, 'THUMBNAIL');
$dataref2 = $image->get_Exif_data('THUMBNAIL');
is_deeply( $dataref, $dataref2, "Thumbnail inserted without an APP1 segment" );

#########################
$hash = $image->get_Exif_data('IMAGE_DATA');
is_deeply( $hash, {}, "... no main-image related records" );

#########################
$hash = $image->get_Exif_data('THUMB_DATA');
is( scalar keys %$hash, 3, "... but 3 thumbnail related records" );

#########################
$result = $image->set_Exif_data(\ "\012\034\156\167", 'THUMBNAIL');
isnt( scalar keys %$result, 0, $$result{'Error'} );

### Local Variables: ***
### mode:perl ***
### End: ***
