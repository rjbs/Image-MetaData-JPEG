use Test::More;
use strict;
use warnings;
use Image::MetaData::JPEG;
use Image::MetaData::JPEG::Tables;

my $cname  = 'Image::MetaData::JPEG';
my $tphoto = 't/test_photo.jpg';
my $tdata  = 't/test_photo.desc';
my $cphoto = 't/test_photo_copy.jpg';
my ($image, $image2, $seg, $hash, $lat, $track, $str, $d1, $d2);

my $GPS_data = {
    'GPSLatitudeRef'  => "N\000",
    'GPSLatitude'     => [ 80, 1, 30, 1, 12, 1 ],
    'GPSLongitudeRef' => "W\000",
    'GPSLongitude'    => [ 15, 1, 49, 1, 50, 1 ],
    0x05              => 1, # 'GPSAltitude'
    0x06              => [ 2000, 100 ],
    0x07              => [12, 1, 13, 1, 0, 1],
    0x08              => "I really don't know",
    'GPSStatus'       => 'A',
    'GPSMeasureMode'  => '2',
    'GPSDOP'          => [ 125, 7 ],
    'GPSSpeedRef'     => 'K',
    0x0d              => [ 30000, 13 ],
    0x0e              => 'M',
    0x0f              => [ 125, 2 ],
    0x10              => 'T',
    'GPSImgDirection' => [ 12, 1 ],
    'GPSMapDatum'     => "Again, I don't know\000",
    'GPSDestLatitudeRef' => 'N',
    'GPSDestLatitude' => [ 118, 2, 3000, 100, 0, 1 ],
    0x15              => 'W',
    0x16              => [ 15, 3, 49, 3, 50, 3 ],
    0x17              => 'T',
    0x18              => [ 13940, 1000 ],
    'GPSDestDistanceRef' => 'M',
    'GPSDestDistance' => [ 49, 1 ],
    'GPSProcessingMethod' => "Jundefined string\000",
    'GPSAreaInformation' => "\000xyz\00uh",
    'GPSDateStamp'    => "1999:12:31",
    'GPSDifferential' => 0 };

#=======================================
diag "Testing APP1 Exif data routines (GPS - set)";
plan tests => 38;
#=======================================

#########################
$image = $cname->new($tphoto);
$seg   = $image->retrieve_app1_Exif_segment(0);
isnt( $seg, undef, "The Exif segment is there, hi!" );

#########################
$hash = $seg->set_Exif_data($GPS_data, 'GPL_DATA', 'REPLACE');
ok( exists $$hash{'ERROR'}, $$hash{'ERROR'} );

#########################
$hash = $seg->set_Exif_data($GPS_data, 'GPS_DATA', 'SPEAK');
ok( exists $$hash{'ERROR'}, $$hash{'ERROR'} );

#########################
$hash = $seg->set_Exif_data($GPS_data, 'GPS_DATA', 'ADD');
is_deeply( $hash, {}, "all test GPS records ADDed" );

#########################
$hash = $seg->get_Exif_data('GPS_DATA', 'TEXTUAL');
is_deeply( $$hash{'GPSAltitude'}, $$GPS_data{6}, "numeric keys work" );

#########################
$hash = $seg->get_Exif_data('GPS_DATA', 'TEXTUAL');
is_deeply( $$hash{'GPSLongitude'}, $$GPS_data{'GPSLongitude'},
	   "textual keys too" );

#########################
$hash = $seg->set_Exif_data($GPS_data, 'GPS_DATA', 'REPLACE');
is_deeply( $hash, {}, "also REPLACing works" );

#########################
$hash = $seg->get_Exif_data('GPS_DATA', 'TEXTUAL');
is_deeply( $$hash{'GPSVersionID'}, [2, 2, 0, 0], "VersionID replaced" );

#########################
$hash = $image->set_Exif_data($GPS_data, 'GPS_DATA', 'ADD');
is_deeply( $hash, {}, "adding through image object" );

#########################
$image->remove_app1_Exif_info(-1);
$image->provide_app1_Exif_segment();
$hash = $image->set_Exif_data($GPS_data, 'GPS_DATA', 'ADD');
is_deeply( $hash, {}, "adding without the GPS dir" );

#########################
$image->save($cphoto);
$image2 = new Image::MetaData::JPEG($cphoto);
unlink $cphoto;
is_deeply( $image2->{segments}, $image->{segments}, "Write and reread works");

#########################
$d1 =  $image->get_description();
$d2 = $image2->get_description();
$d1 =~ s/(.*REFERENCE.*-->).*/$1/g; $d1 =~ s/Original.*//g;
$d2 =~ s/(.*REFERENCE.*-->).*/$1/g; $d2 =~ s/Original.*//g;
is( $d1, $d2, "Descriptions after write/read cycle are coincident" );

#########################
$image = $cname->new($tphoto);
$hash = $image->set_Exif_data({'GPSLatitudeRef' =>"W\000"}, 'GPS_DATA', 'ADD');
ok( exists $$hash{1}, "Malformed LatitudeRef rejected" );

#########################
$hash = $image->set_Exif_data({'GPSLatitudeRef' => 'N'}, 'GPS_DATA', 'ADD');
is_deeply( $hash, {}, "Non-null-terminated ASCII strings are patched" );

#########################
$lat = [12, 1, 7, 1, 77, 1];
$hash = $image->set_Exif_data({'GPSLatitude' => $lat}, 'GPS_DATA', 'ADD');
ok( exists $$hash{2}, "Malformed Latitude rejected" );

#########################
$lat = [12, 0, 7, 0, 47, 0];
$hash = $image->set_Exif_data({'GPSLatitude' => $lat}, 'GPS_DATA', 'ADD');
ok( exists $$hash{2}, "... rejected again ..." );

#########################
$lat = [92, 1, 7, 1, 47, 1];
$hash = $image->set_Exif_data({'GPSLatitude' => $lat}, 'GPS_DATA', 'ADD');
ok( exists $$hash{2}, "... and again" );

#########################
$lat = [57, 1, 1400, 100, 0, 1];
$hash = $image->set_Exif_data({'GPSLatitude' => $lat}, 'GPS_DATA', 'ADD');
ok( ! exists $$hash{2}, "Atypical but valid latitude format accepted" );

#########################
$lat = [21, 3, 14, 7, 35, 11];
$hash = $image->set_Exif_data({'GPSLatitude' => $lat}, 'GPS_DATA', 'ADD');
ok( ! exists $$hash{2}, "... very atypical but valid (?) and accepted again" );

#########################
$lat = [89, 1, 5930, 100, 35, 1];
$hash = $image->set_Exif_data({'GPSLatitude' => $lat}, 'GPS_DATA', 'ADD');
ok( exists $$hash{2}, "... this, really, must be invalid" );

#########################
$lat = [57, 1, -1400, -100, 0, 1];
$hash = $image->set_Exif_data({'GPSLatitude' => $lat}, 'GPS_DATA', 'ADD');
ok( exists $$hash{2}, "... negative elements are invalid" );

#########################
$lat = [90, 1, 0, 100, 0, 1];
$hash = $image->set_Exif_data({'GPSLatitude' => $lat}, 'GPS_DATA', 'ADD');
ok( ! exists $$hash{2}, "You can write North Pole" );

#########################
$track = [3500, 10];
$hash = $image->set_Exif_data({'GPSTrack' => $track}, 'GPS_DATA', 'ADD');
ok( ! exists $$hash{15}, "GPS direction accepted" );

#########################
$track = [800, 2];
$hash = $image->set_Exif_data({'GPSTrack' => $track}, 'GPS_DATA', 'ADD');
ok( exists $$hash{15}, "... direction >= 360 is invalid" );

#########################
$track = [-3500, -10];
$hash = $image->set_Exif_data({'GPSTrack' => $track}, 'GPS_DATA', 'ADD');
ok( exists $$hash{15}, "... direction with negative rationals is invalid" );

#########################
$track = [35132, 1000];
$hash = $image->set_Exif_data({'GPSTrack' => $track}, 'GPS_DATA', 'ADD');
ok( exists $$hash{15}, "... direction with > 2 decimal digits is invalid" );

#########################
$track = [3513, 100];
$hash = $image->set_Exif_data({'GPSTrack' => $track}, 'GPS_DATA', 'ADD');
ok( ! exists $$hash{15}, "... but 2 decimal digits are OK" );

#########################
$str = "AAN ASCII string";
$hash = $image->set_Exif_data({'GPSAreaInformation'=>$str}, 'GPS_DATA', 'ADD');
ok( ! exists $$hash{28}, "GPS non-C strings start with an identifier" );

#########################
$str = "BAN ASCII string";
$hash = $image->set_Exif_data({'GPSAreaInformation'=>$str}, 'GPS_DATA', 'ADD');
ok( exists $$hash{28}, "... invalid identifiers are trapped" );

#########################
$str = "2002:07:13";
$hash = $image->set_Exif_data({'GPSDateStamp' => $str}, 'GPS_DATA', 'ADD');
ok( ! exists $$hash{29}, "Accepting dates in YYYY:MM:DD" );

#########################
$str = "1802:07:13";
$hash = $image->set_Exif_data({'GPSDateStamp' => $str}, 'GPS_DATA', 'ADD');
ok( exists $$hash{29}, "... not accepting a wrong year" );

#########################
$str = "2002:47:13";
$hash = $image->set_Exif_data({'GPSDateStamp' => $str}, 'GPS_DATA', 'ADD');
ok( exists $$hash{29}, "... not accepting a wrong month" );

#########################
$str = "2002:07:53";
$hash = $image->set_Exif_data({'GPSDateStamp' => $str}, 'GPS_DATA', 'ADD');
ok( exists $$hash{29}, "... not accepting a wrong day" );

#########################
$str = "2002:07:c3";
$hash = $image->set_Exif_data({'GPSDateStamp' => $str}, 'GPS_DATA', 'ADD');
ok( exists $$hash{29}, "... not accepting non numeric characters" );

#########################
$hash = $image->set_Exif_data({'GPSDifferential' => 1}, 'GPS_DATA', 'ADD');
ok( ! exists $$hash{30}, "byte field accepted" );

#########################
$hash = $image->set_Exif_data({'GPSDifferential' => 2}, 'GPS_DATA', 'ADD');
ok( exists $$hash{30}, "... but not with a wrong value" );

#########################
$hash = $image->set_Exif_data({9999 => 2}, 'GPS_DATA', 'ADD');
ok( exists $$hash{9999}, "unknown numeric tags are rejected" );

#########################
$hash = $image->set_Exif_data({'Pippero' => 2}, 'GPS_DATA', 'ADD');
ok( exists $$hash{'Pippero'}, "unknown textual tags are rejected" );

### Local Variables: ***
### mode:perl ***
### End: ***
