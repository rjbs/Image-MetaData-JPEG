use Test::More;
use strict;
use warnings;
use Image::MetaData::JPEG;
use Image::MetaData::JPEG::Tables qw(:TagsAPP13);

my $cname  = 'Image::MetaData::JPEG';
my $tphoto = 't/test_photo.jpg';
my $shop   = "PHOTOSHOP";
my $iptc   = "IPTC";
my ($image, $seg1, $seg2, $hash, $num, $segs, $fh, $desc1, $desc2);

#=======================================
diag "Testing APP13 IPTC basic routines";
plan tests => 43;
#=======================================

#########################
{open $fh, $0; is( (grep { /set_app13_data/ } <$fh>), 1, "No setters here" );}

#########################
$image = $cname->new($tphoto);
is( $image->get_segments('APP13'), 1, "Number of APP13 segments" );

#########################
is( $image->retrieve_app13_segment(-1, $shop), 1, "Number, alternatively" );

#########################
is( $image->retrieve_app13_segment(-1, $iptc), 1, "... again, alternatively" );

#########################
is( $image->retrieve_app13_segment(1, $shop), undef, "Out-of-bound index" );

#########################
$seg1 = $image->retrieve_app13_segment(0, $shop);
$seg1->{name} = "APP11"; # a trick to mask the segment name
$seg2 = $image->provide_app13_segment($shop);
$seg1->{name} = "APP13"; # we have two APP13 segs now
is( $image->retrieve_app13_segment(-1, $shop), 2, "2 Photoshop segments now" );

#########################
is( $image->retrieve_app13_segment(-1, $iptc), 1, "... but only one is IPTC" );

#########################
is( $image->retrieve_app13_segment(1, $shop), $seg2,
    "You can ask for the 2nd Photoshop segment" );

#########################
is( $image->retrieve_app13_segment(1, $iptc), undef,
    "... but not for the 2nd IPTC segment" );

#########################
$image->remove_app13_info(0, $shop);
is( $image->retrieve_app13_segment(-1, $shop), 1, "First Photoshop deleted" );

#########################
$seg1 = $image->retrieve_app13_segment(0, $shop);
$seg2 = $image->retrieve_app13_segment(0, $iptc);
isnt( $seg1, $seg2, "Now \$index = 0 depends on \$what" );

#########################
$image->remove_app13_info(0, $shop);
$seg1 = $image->retrieve_app13_segment(0, $shop);
is( $seg1, undef, "We can erase Photoshop info from index = 0" );

#########################
$seg1 = $image->retrieve_app13_segment(0, $iptc);
is( $seg1, $seg2, "... without touching the other segment" );

#########################
$image->remove_app13_info(0, $shop);
$seg1 = $image->retrieve_app13_segment(0, $iptc);
is( $seg1, $seg2, "... even if we repeat remove_app13_info" );

#########################
$image->remove_app13_info(0, $iptc);
$seg1 = $image->retrieve_app13_segment(0, $iptc);
is( $seg1, undef, "Now also the other segment is gone");

#########################
$seg1 = $image->provide_app13_segment($shop);
isnt( $seg1, undef, "provide_app13_segment creates a segment" );

#########################
$seg1 = $image->retrieve_app13_segment(0, $iptc);
is( $seg1, undef, "... but it does not insert too much information" );

#########################
eval { $image->retrieve_app13_segment(0, "iPtC") };
isnt( $@, '', "A wrong \$what hurts in retrieve_app13_segment" );

#########################
eval { $image->provide_app13_segment("Fotoshop") };
isnt( $@, '', "It hurts also in provide_app13_segment" );

#########################
$seg1 = $image->provide_app13_segment($iptc);
$hash = $seg1->get_app13_data(undef, $shop);
is( scalar keys %$hash, 0, "No non-IPTC record created by provide_..." );

#########################
$hash = $seg1->get_app13_data('NUMERIC', $iptc);
is( scalar keys %$hash, 1, "But one IPTC record is there" );

#########################
ok( exists $$hash{0}, "... and it is 'RecordVersion'" );

#########################
$image = $cname->new($tphoto); # reset
$seg1 = $image->retrieve_app13_segment(0, $shop);
$seg2 = $image->provide_app13_segment($shop);
is_deeply( $seg1, $seg2, "Get IPTC segment in two ways [Photoshop]" );

#########################
$seg1 = $image->retrieve_app13_segment(0, $iptc);
$seg2 = $image->provide_app13_segment($iptc);
is_deeply( $seg1, $seg2, "Get IPTC segment in two ways [IPTC]" );

#########################
$num = scalar @{$seg1->search_record_value($APP13_PHOTOSHOP_DIRNAME)};
$hash = $seg1->get_app13_data('NUMERIC', $shop);
is( scalar keys %$hash, $num, "Num elements from numeric get [Photoshop]" );

#########################
is( (grep {/^[0-9]*$/} keys %$hash), $num, "... all tags are numeric" );

#########################
$hash = $seg1->get_app13_data('TEXTUAL', $shop);
is( scalar keys %$hash, $num, "... num elements from textual get" );

#########################
is( (grep {!/^[0-9]*$/} keys %$hash), $num, "... all tags are textual" );

#########################
$num = scalar @{$seg1->search_record_value($APP13_IPTC_DIRNAME)};
$hash = $seg1->get_app13_data('NUMERIC', $iptc);
is( keys %$hash, $num, "Num elements from numeric get [IPTC]" );

#########################
is( exists $$hash{0} ? 1 : undef, 1, "Record Version exists" );

#########################
is( (grep {/^[0-9]*$/} keys %$hash), $num, "... all tags are numeric" );

#########################
$hash = $seg1->get_app13_data('TEXTUAL', $iptc);
is( scalar keys %$hash, $num, "... num elements from textual get" );

#########################
is( (grep {!/^[0-9]*$/} keys %$hash), $num, "... all tags are textual" );

#########################
$image->remove_app13_info(-1, $iptc);
$num = $image->retrieve_app13_segment(-1, $iptc);
is( $num, 0, "Removing IPTC information" );

#########################
$num = $image->get_segments('APP13');
is( $num, 1, "... but not the APP13 segment" );

#########################
$image->remove_app13_info(0, $shop);
$num = $image->retrieve_app13_segment(-1, $shop);
is( $num, 0, "Removing Photoshop info with index" );

#########################
$num = $image->get_segments('APP13');
is( $num, 0, "... this time, a real segment removal" );

#########################
$seg1 = $image->retrieve_app13_segment(0, $iptc);
is( $seg1, undef, "Retrieve not forcing a segment" );

#########################
$seg1 = $image->provide_app13_segment($iptc);
isnt( $seg1, undef, "Provide forcing a segment" );

#########################
eval { $hash = $image->get_app13_data('NUMERICAL', $iptc) };
isnt( $@, undef, "get_app13_data fails with wrong label" );

#########################
eval { $hash = $image->get_app13_data('ILLEGAL', $iptc); };
isnt( $@, undef, "get_app13_data fails with illegal type" );

#########################
$image = $cname->new($tphoto);
$seg1  = $image->retrieve_app13_segment(0, $iptc);
$desc1 = $seg1->get_description();
$hash  = $seg1->get_app13_data('NUMERIC', $iptc);
$_ = 17 for values %$hash;
$desc2 = $seg1->get_description();
is( $desc1, $desc2, "get_app13_data [IPTC] returns a copy of actual data" );

#########################
$seg1  = $image->retrieve_app13_segment(0, $shop);
$desc1 = $seg1->get_description();
$hash  = $seg1->get_app13_data('NUMERIC', $shop);
$_ = 27 for values %$hash;
$desc2 = $seg1->get_description();
is( $desc1, $desc2, "get_app13_data [PHOTOSHOP] behaves the same way" );

### Local Variables: ***
### mode:perl ***
### End: ***
