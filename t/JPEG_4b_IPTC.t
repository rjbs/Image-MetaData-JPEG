use Test::More;
use strict;
use warnings;
use Image::MetaData::JPEG;

my $cname  = 'Image::MetaData::JPEG';
my $tphoto = 't/test_photo.jpg';
my ($image, $hash, $bighash);

#=======================================
diag "Testing APP13 IPTC format checker";
plan tests => 19;
#=======================================

#########################
$image = $cname->new($tphoto);
$hash = $image->set_IPTC_data({ 80 => "ciao" }); # ByLine
is( scalar keys %$hash, 0, "regular tag" );

#########################
$hash = $image->set_IPTC_data({ 1 => "ciao" });
is( scalar keys %$hash, 1, "unkwnon numeric tag" );

#########################
$hash = $image->set_IPTC_data({ -3 => "ciao" });
is( scalar keys %$hash, 1, "negative tag" );

#########################
$hash = $image->set_IPTC_data({ 313 => "ciao" });
is( scalar keys %$hash, 1, "tag larger than 255" );

#########################
$hash = $image->set_IPTC_data({ "XYZ" => "ciao" });
is( scalar keys %$hash, 1, "unkwnon textual tag" );

#########################
$hash = $image->set_IPTC_data({ 80 => [] });
is( scalar keys %$hash, 1, "value array with zero elements" );

#########################
$hash = $image->set_IPTC_data({ 90 => ["Milano", "Roma"] }); # City
is( scalar keys %$hash, 1, "non repeateable tag (1)" );

#########################
$hash = $image->set_IPTC_data({ 90 => "Roma" });
is( scalar keys %$hash, 0, "non repeateable tag (2)" );

#########################
$hash = $image->set_IPTC_data({ 45 => "ciao" }); # RefereceService
is( scalar keys %$hash, 1, "invalid tag" );

#########################
$hash = $image->set_IPTC_data({ 125 => "\001\377\013" }); # RasterizedCaption
is( scalar keys %$hash, 0, "binary tag" );

#########################
$hash = $image->set_IPTC_data({ 135 => 'I' }); # LanguageIdentifier
is( scalar keys %$hash, 1, "length too small" );

#########################
$hash = $image->set_IPTC_data({ 135 => "IT" });
is( scalar keys %$hash, 0, "length OK (1)" );

#########################
$hash = $image->set_IPTC_data({ 135 => "ITA" });
is( scalar keys %$hash, 0, "length OK (2)" );

#########################
$hash = $image->set_IPTC_data({ 135 => "ITAL" });
is( scalar keys %$hash, 1, "length too large" );

#########################
$hash = $image->set_IPTC_data({ 3 => "ciao:ate" }); # ObjectTypeReference
is( scalar keys %$hash, 1, "invalid regex (1)" );

#########################
$hash = $image->set_IPTC_data({ 3 => "riga\nacapo" }); # ObjectName
is( scalar keys %$hash, 1, "invalid regex (2)" );

#########################
$hash = $image->set_IPTC_data({ 10 => 9 }); # Urgency
is( scalar keys %$hash, 1, "invalid regex (3)" );

#########################
$hash = $image->set_IPTC_data({ 120 => "uno\fdue" }); # Caption/Abstract
is( scalar keys %$hash, 1, "form feed not allowed in 'paragraph'" );

#########################
$bighash = {
    'RecordVersion'               => "\000\002",
    'ObjectTypeReference'         => "23:ciao a te",
    'ObjectAttributeReference'    => "234:ciao a te",
    'ObjectName'                  => "nome",
    'EditorialUpdate'             => "01",
    'Urgency'                     => 3,
    'SubjectReference'            => "IPTC:12345678:alpha:beta:gamma",
    'Category'                    => "ao",
    'SupplementalCategory'        => [ "alci", "daini", "capri oli" ],
    'FixtureIdentifier'           => "paperino",
    'ContentLocationCode'         => "ABC",
    'ReleaseDate'                 => "12341230",
    'ReleaseTime'                 => "130612+0100",
    'ActionAdvised'               => "03",
    'ObjectCycle'                 => 'p',
    'Country/PrimaryLocationCode' => "ITA",
    'Caption/Abstract'            => "line 1\nline 2\n\rline 3",
    'RasterizedCaption'           => "\013\000\001\135\377\254",
    'ImageType'                   => "9R",
    'ImageOrientation'            => 'L',
    'LanguageIdentifier'          => "it",
    'AudioType'                   => "1M",
    'AudioSamplingRate'           => 928346,
    'AudioSamplingResolution'     => 20,
    'AudioDuration'               => 121325 };
$hash = $image->set_IPTC_data($bighash);
is( scalar keys %$hash, 0, "a group of valid tags" );

### Local Variables: ***
### mode:perl ***
### End: ***
