use Test::More;
use strict;
use warnings;
use Image::MetaData::JPEG;
use Image::MetaData::JPEG::Tables qw(:Lookups);

my $cname  = 'Image::MetaData::JPEG';
my $tphoto = 't/test_photo.jpg';
my $tdata  = 't/test_photo.desc';
my ($image, $image2, $seg, $hash, $hash2, $d1, $d2, $ref);
my $uc = sub { my $s = "\376\377";
               $s .= "\000$_" for split(/ */,$_[0]);
               $s .= "\000\000"; };
my $val = sub { my $nn = JPEG_lookup('APP1@IFD0@SubIFD', $_[0]);
		$nn = JPEG_lookup('APP1@IFD0', $_[0]) unless defined $nn;
		return $nn; };

my $IMAGE_data = {
    'YCbCrPositioning'                =>  2,
    'YCbCrCoefficients'               => [1, 14, 34, 45, 65, 12],
    'YCbCrSubSampling'                => [2, 2],
    &$val('ReferenceBlackWhite')      => [7, 32, 5, 64, 18, 13, 0,0,0,0,0,0],
    &$val('PrimaryChromaticities')    => [(10..21)],
    &$val('Copyright')                => 'GPL',
    'Software'                        => $cname,
    'DateTime'                        => ['1996:07:12 14:36:55'],
    'WhitePoint'                      => [12, 16, 8, 16],
    &$val('WhiteBalance')             => [1],
    &$val('GainControl')              => ['3'],
    &$val('DeviceSettingDescription') => "abcd".&$uc("ciao").&$uc("µ¿ÃÐëø"),
    &$val('ImageUniqueID')            => ['123789cd90ffa890' . "\000" x 17],
    '_OwnerName'                      =>  "Owner's Name: Stefano Bettelli\000",
    '_MoireFilter'                    =>  'Moire Filter: OFF',
    'FileSource'                      => ['3'],
    'SceneType'                       =>  1,
    # there are two CFAPattern's !!!
    &$val('CFAPattern')               =>  "\000\003\000\003342623342",
    'ExposureMode'                    => [ 2 ],
    &$val('RelatedSoundFile')         => ['ALB12_a5.DXf'],
    &$val('FocalPlaneResolutionUnit') =>  3,
    &$val('SubjectLocation')          => [13, 19],
    &$val('SensingMethod')            =>  '7',
    'SubSecTime'                      =>  "133     \000",
    'FlashpixVersion'                 => ['0100'],
    'ColorSpace'                      =>  65535,
    'PixelXDimension'                 => [222],
    &$val('LightSource')              =>  17,
    &$val('Flash')                    => [79],
    &$val('SubjectArea')              => [10, 20, 30],
    &$val('MakerNote')                =>  '13@'."\023\133_ ..\377\000ab-_",
    &$val('UserComment')              => ["Unicode\000asdfgh"],
    'ExifVersion'                     => '0220',
    'DateTimeOriginal'                => ['1996:07:12 14:36:55'],
    'CompressedBitsPerPixel'          => [79, 64],
    'MeteringMode'                    =>  6,
    &$val('ExposureTime')             => [12, 55],
    &$val('ExposureProgram')          => [7],
    &$val('SpectralSensitivity')      =>  'a lot',
    &$val('ISOSpeedRatings')          => [1, 2, 3, 4],
    &$val('XResolution')              => [31000, 65536],
    &$val('YResolution')              => [1, 72],
    &$val('ResolutionUnit')           =>  3,
    'PhotometricInterpretation'       =>  2,
    'PlanarConfiguration'             =>  2,
    'Model'                           => 'Kodak DX3900',
    'Orientation'                     => [4],
    'TransferFunction'                => [(1..768)],
    &$val('Make')                     => 'Cooperativa Elettronica Reggiana',
    &$val('Artist')                   => 'Stefano Bettelli',
    &$val('ImageDescription')         => 'spiaggia di Marina Romea',
};

my $cannotbeset = {
    'ImageWidth'                      => 640,
    'ImageLength'                     => 480,
    'BitsPerSample'                   => [8, 8, 8],
    'Compression'                     => 6,
    'FNumber'                         => [3, -1],
    'ColorSpace'                      => 9,
    'ColorSpace'                      => 'xxx',
    'ExifVersion'                     => '9999',
    'DateTimeOriginal'                => '1994:23:23 12:14:61',
    'ComponentsConfiguration'         => '4650',
    'BrightnessValue'                 => [-4],
    'LightSource'                     => 16,
    'Flash'                           => 26,
    'StripOffsets'                    => [(1..10)],
    'SamplesPerPixel'                 => 3,
    'RowsPerStrip'                    => 5,
    'StripByteCounts'                 => [(5..50)],
    'JPEGInterchangeFormat'           => 600,
    'JPEGInterchangeFormatLength'     => 3420,
    'ExifOffset'                      => 848,
    'GPSInfo'                         => 1264,
    'SubjectArea'                     => 26,
    'UserComment'                     => 'zzz',
    'SubSecTime'                      => '130ms',
    'RelatedSoundFile'                => 'FILE.DAT',
    'InteroperabilityOffset'          => 'calculated',
};

#=======================================
diag "Testing APP1 Exif data routines (IMAGE_DATA & ROOT_DATA)";
plan tests => 30;
#=======================================

#########################
$image = $cname->new($tphoto, '^APP1$');
$hash = $image->set_Exif_data($IMAGE_data, 'IMAGE_DATA', 'ADD');
is_deeply( $hash, {}, "all test IMAGE records ADDed" );

#########################
$hash = $image->set_Exif_data($cannotbeset, 'IMAGE_DATA', 'ADD');
is( scalar keys %$hash, scalar keys %$cannotbeset,
    "all forbidden records are rejected" );

#########################
$hash = $image->set_Exif_data($IMAGE_data, 'IMAGE_DATA', 'REPLACE');
is_deeply( $hash, {}, "REPLACing in the image works" );

#########################
$hash = $image->set_Exif_data($cannotbeset, 'IMAGE_DATA', 'REPLACE');
is( scalar keys %$hash, scalar keys %$cannotbeset,
    "all forbidden records rejected when replacing" );

#########################
$image->set_Exif_data({}, 'IMAGE_DATA', 'REPLACE');
$hash = $image->get_Exif_data('IMAGE_DATA', 'TEXTUAL');
is_deeply( $$hash{'XResolution'}, [1,72], "Automatic IFD0 XResolution works" );

#########################
is_deeply( $$hash{'YCbCrPositioning'}, [1], "... also YCbCrPositioning" );

#########################
$hash = $image->get_Exif_data('IMAGE_DATA', 'TEXTUAL');
is_deeply($$hash{'ExifVersion'},['0220'],"Automatic SubIFD ExifVersion works");

#########################
is_deeply( $$hash{'ColorSpace'}, [1], "... also ColorSpace" );

#########################
is_deeply( [${$$hash{'PixelXDimension'}}[0], ${$$hash{'PixelYDimension'}}[0]],
	   [$image->get_dimensions()], "... also picture dimensions" );

#########################
$seg = $image->retrieve_app1_Exif_segment();
$seg->set_Exif_data($IMAGE_data, 'IMAGE_DATA', 'REPLACE');
$hash =  $seg->get_Exif_data('IMAGE_DATA', 'NUMERIC');
$image->set_Exif_data($IMAGE_data, 'IMAGE_DATA', 'ADD');
$hash2 = $image->get_Exif_data('IMAGE_DATA', 'NUMERIC');
is_deeply( $hash, $hash2, "adding through image/segment coincide" );

#########################
$image->remove_app1_Exif_info(-1);
$hash = $image->set_Exif_data($IMAGE_data, 'IMAGE_DATA', 'ADD');
is_deeply( $hash, {}, "adding without the Exif segment" );

#########################
$ref = \ "dummy";
$image->save($ref);
$image2 = $cname->new($ref, '^APP1$');
$_->{parent} = $image for @{$image2->{segments}}; # parental link hack
is_deeply( $image2->{segments}, $image->{segments}, "Write and reread works");

#########################
$d1 =  $image->get_description();
$d2 = $image2->get_description();
$d1 =~ s/(.*REFERENCE.*-->).*/$1/g; $d1 =~ s/Original .*//g;
$d2 =~ s/(.*REFERENCE.*-->).*/$1/g; $d2 =~ s/Original .*//g;
is( $d1, $d2, "Descriptions after write/read cycle are coincident" );

#########################
$hash = $image->get_Exif_data('IFD1_DATA', 'NUMERIC');
is_deeply( $hash, {}, "... no records found in IFD1" );

#########################
$hash = $image->get_Exif_data('INTEROP_DATA', 'NUMERIC');
is_deeply( $hash, {}, "... no records found in INTEROP" );

#########################
$hash = $image->get_Exif_data('GPS_DATA', 'NUMERIC');
is_deeply( $hash, {}, "... no records found in GPS" );

#########################
$hash = $image->set_Exif_data({'Orientation' => 11}, 'IMAGE_DATA', 'ADD');
ok( exists $$hash{&$val('Orientation')}, "Invalid Orientation rejected" );

#########################
$hash = $image->set_Exif_data({'SceneType' => 4}, 'IMAGE_DATA', 'ADD');
ok( exists $$hash{&$val('SceneType')}, "Invalid SceneType rejected" );

#########################
$hash = $image->set_Exif_data({9999 => 2}, 'IMAGE_DATA', 'ADD');
ok( exists $$hash{9999}, "unknown numeric tags are rejected" );

#########################
$hash = $image->set_Exif_data({'Pippero' => 2}, 'IMAGE_DATA', 'ADD');
ok( exists $$hash{'Pippero'}, "unknown textual tags are rejected" );

#########################
$hash = $image->set_Exif_data({'Identifier'    => "Exif\000\000",
			       'ThumbnailData' => 'dfdfdf',
			       'Endianness'    => 'MM',
			       'Signature'     => 42 }, 'ROOT_DATA', 'ADD');
is( scalar keys %$hash, 3, "3 properties out of 4 rejected with ROOT_DATA" );

#########################
is_deeply([sort keys %$hash],[sort ('Identifier','ThumbnailData','Signature')],
	  "... only 'Endianness' was accepted" );

#########################
$hash = $image->set_Exif_data({'Endianness' => 'ZX'}, 'ROOT_DATA', 'ADD');
is( scalar keys %$hash, 1, "Malformed endianness rejected" );

#########################
$hash = $image->set_Exif_data({'Endianness' => 'II'}, 'ROOT_DATA', 'ADD');
is( scalar keys %$hash, 0, "... but legal endianness accepted" );

#########################
$d1 = $image->get_description();
like( $d1, qr/Endianness[^\n]*'II'/, "... tag read with get_description" );

#########################
$hash = $image->set_Exif_data({'Endianness' => 'II'}, 'ROOT_DATA', 'ADD');
$image->save($ref);
$d1 = $cname->new($ref, '^APP1$', 'FASTREADONLY')->get_description();
$hash = $image->set_Exif_data({'Endianness' => 'MM'}, 'ROOT_DATA', 'ADD');
$image->save($ref);
$d2 = $cname->new($ref, '^APP1$', 'FASTREADONLY')->get_description();
$d1 =~ s/(.*REFERENCE.*-->).*/$1/g; $d1 =~ s/Original .*//g;
$d2 =~ s/(.*REFERENCE.*-->).*/$1/g; $d2 =~ s/Original .*//g;
like( $d1, qr/Endianness[^\n]*'II'/, "Little-endianness correctly saved" );
like( $d2, qr/Endianness[^\n]*'MM'/, "... also big-endianness" );

#########################
unlike( $d2, qr/Endianness[^\n]*'II'/, "... incorrect match fails (II)" );
unlike( $d1, qr/Endianness[^\n]*'MM'/, "... incorrect match fails (MM)" );

#########################
$d1 =~ s/(.*Endianness.*UNDEF.).*/$1 REPLACED/g;
$d2 =~ s/(.*Endianness.*UNDEF.).*/$1 REPLACED/g;
is( $d1, $d2, "... descriptions are otherwise equivalent" );

### Local Variables: ***
### mode:perl ***
### End: ***
