use Test::More;
use strict;
use warnings;
use Image::MetaData::JPEG;

my $cname  = 'Image::MetaData::JPEG';
my $tphoto = 't/test_photo.jpg';
my $tdata  = 't/test_photo.desc';
my $cphoto = 't/test_photo_copy.jpg';
my ($image, $seg1, $seg2, $hash, $hash2);

#=======================================
diag "Testing APP1 Exif data routines";
plan tests => 7;
#=======================================

#########################
$image = $cname->new($tphoto);
is( $image->get_segments('APP1$'), 1, "Number of APP1 segments" );

#########################
is( $image->retrieve_app1_Exif_segment(-1), 1, "Number, alternatively" );

#########################
is( $image->retrieve_app1_Exif_segment(1), undef, "Out-of-bound index" );

#########################
$seg1 = $image->retrieve_app1_Exif_segment(0);
$seg2 = $image->provide_app1_Exif_segment();
is_deeply( $seg1, $seg2, "Get segment in two ways" );

#########################
$hash = $seg1->get_Exif_data("TEXTUAL");
is( scalar keys %$hash, 5, "there are five subdirs" );

#########################
%$hash = map { ($_ =~ /APP1/) ? ($_ => $$hash{$_}) : undef } keys %$hash;
is( scalar keys %$hash, 5, "they all begin with \"APP1\"" );

#########################
$hash2 = $image->get_Exif_data("TEXTUAL");
is_deeply( $hash, $hash2, "both get_Exif_data agree" );

#use Data::Dumper;
#print Dumper($hash);

#while (my ($d, $h) = each %$hash2) { 
#    while (my ($t, $a) = each %$h) {
#	printf "%-25s\t%-25s\t-> ", $d, $t;
#	s/([\000-\037\177-\377])/sprintf "\\%02x",ord($1)/ge,
#	$_ = (length $_ > 30) ? (substr($_,0,30) . " ... ") : $_,
#	printf "%-5s", $_ for @$a; print "\n"; } }

#########################
#$ref = $seg1->search_record($IPTCdir)->get_value();
#$num = scalar @$ref; --$num;
#$hash = $seg1->get_IPTC_data("NUMERIC");
#is( keys %$hash, $num, "Num elements from numeric get" );

#########################
#is( exists $$hash{0} ? 1 : undef, undef, "No Record Version" );

#########################
#is( (grep {/^[0-9]*$/} keys %$hash), $num, "All tags are numeric" );

#########################
#$hash = $seg1->get_IPTC_data("TEXTUAL");
#is( keys %$hash, $num, "Num elements from textual get" );

#########################
#is( (grep {!/^[0-9]*$/} keys %$hash), $num, "All tags are textual" );

#########################
#%{$hashtot} = %{$hash};
#push @{$$hashtot{$_}}, @{$$ht{$_}} for keys %$ht;
#$seg1->set_IPTC_data({%$ht}, "ADD");
#$hash = $seg1->get_IPTC_data("TEXTUAL");
#is_deeply( $hash, $hashtot, "Adding records textually" );

#########################
#$seg1->set_IPTC_data({%$ht}, "REPLACE");
#$hash = $seg1->get_IPTC_data("TEXTUAL");
#is_deeply( $hash, $ht, "Replacing instead of adding" );

#########################
#$hash = $seg1->get_IPTC_data("NUMERIC");
#$seg1->set_IPTC_data({%$hn}, "ADD");
#$hashtot = $hash;
#push @{$$hashtot{$_}}, @{$$hn{$_}} for keys %$hn;
#$hash = $seg1->get_IPTC_data("NUMERIC");
#is_deeply( $hash, $hashtot, "Adding records numerically" );

#########################
#$seg1->set_IPTC_data({%$hn}, "REPLACE");
#$hash = $seg1->get_IPTC_data("NUMERIC");
#is_deeply( $hash, $hn, "Replacing records numerically" );

#########################
#$hash = $image->get_IPTC_data("NUMERIC");
#is_deeply( $hash, $hn, "High level get IPTC data (numeric)" );

#########################
#$hashtot = $seg1->get_IPTC_data("TEXTUAL");
#push @{$$hashtot{$_}}, @{$$ht{$_}} for keys %$ht;
#$image->set_IPTC_data({%$ht}, "ADD");
#$hash = $image->get_IPTC_data("TEXTUAL");
#is_deeply( $hash, $hashtot, "High level set/get (textual)" );

#########################
#$image->remove_app13_IPTC_info(-1);
#$num = $image->retrieve_app13_IPTC_segment(-1);
#is( $num, 0, "Removing IPTC information" );

#########################
#$num = $image->get_segments('APP13');
#is( $num, 1, "... but not the APP13 segment" );

#########################
#$segs = $image->{segments};
#@$segs = grep { $_->{name} !~ /APP13/ } @$segs;
#is( $image->get_segments("APP13"), 0, "Segment removal" );

#########################
#$image->set_IPTC_data({%$ht}, "ADD");
#$hash = $image->get_IPTC_data("TEXTUAL");
#is_deeply( $hash, {%$ht}, "Forcing an IPTC segment (high level)" );

#########################
#$image->remove_app13_IPTC_info(0);
#$num = $image->retrieve_app13_IPTC_segment(-1);
#is( $num, 0, "Removing IPTC information with index" );

#########################
#$num = $image->get_segments('APP13');
#is( $num, 0, "... this time, a real segment removal" );

#########################
#@$segs = grep { $_->{name} !~ /APP13/ } @$segs;
#$image->set_IPTC_data({%$hn}, "REPLACE");
#$hash = $image->get_IPTC_data("NUMERIC");
#is_deeply( $hash, {%$hn}, "Same, but with replace and numerically" );

#########################
#@$segs = grep { $_->{name} !~ /APP13/ } @$segs;
#$seg1 = $image->retrieve_app13_IPTC_segment(0);
#is( $seg1, undef, "retrieve not forcing a segment" );

#########################
#$seg2 = $image->provide_app13_IPTC_segment();
#isnt( $seg2, undef, "provide forcing a segment" );

#########################
#$seg2->set_IPTC_data({%$ht}, "REPLACE");
#$hashtot = $seg2->get_IPTC_data("NUMERIC");
#$seg2->set_IPTC_data({%$hn}, "ADD");
#push @{$$hashtot{$_}}, @{$$hn{$_}} for keys %$hn;
#$image->save($cphoto);
#$image = $cname->new($cphoto, "APP13", "FASTREADONLY");
#unlink $cphoto;
#isnt( $image, undef, "File written and re-read");

#########################
#$hash = $image->get_IPTC_data("NUMERIC");
#isnt( $hash, undef, "There is an APP13 segment" );

#########################
#is_deeply( $hash, $hashtot, "Re-read data is ok" );

#########################
#$hash = $image->get_IPTC_data("NUMERICAL");
#is( $hash, undef, "No segment with wrong label" );

#########################
#eval { $image->set_IPTC_data(undef) };
#is( $@, '', "No error with undefined argument in set" );

#########################
#$hash = $image->get_IPTC_data("ILLEGAL");
#is( $hash, undef, "No action with illegal type in get" );

### Local Variables: ***
### mode:perl ***
### End: ***
