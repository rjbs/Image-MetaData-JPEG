use Test::More;
use strict;
use warnings;
use Image::MetaData::JPEG;
use Image::MetaData::JPEG::Tables qw(:RecordTypes);

my $cname  = 'Image::MetaData::JPEG';
my $tphoto = 't/test_photo.jpg';
my $tdata  = 't/test_photo.desc';
my $cphoto = 't/test_photo_copy.jpg';
my ($image, $thumbimage, $seg1, $seg2, $hash, $hash2, $records,
    %realcounts, %counts, $count, $data, $data2, @lines);

#=======================================
diag "Testing APP1 Exif data routines";
plan tests => 36;
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
$hash = $seg1->get_Exif_data('All', 'TEXTUAL');
is( $hash, undef, "get_Exif_data with wrong \$what returns undef" );

#########################
$hash = $seg1->get_Exif_data('ALL', 'TExTUAL');
is( $hash, undef, "get_Exif_data with wrong \$type returns undef" );

#########################
$hash = $seg1->get_Exif_data('ALL', 'TEXTUAL');
is( scalar keys %$hash, 6, "there are five subdirs" );

#########################
%$hash = map { ($_ =~ /APP1/) ? ($_ => $$hash{$_}) : undef } keys %$hash;
is( scalar keys %$hash, 6, "they all begin with \"APP1\"" );

#########################
$hash2 = $image->get_Exif_data('ALL', 'TEXTUAL');
is_deeply( $hash, $hash2, "the two forms of get_Exif_data agree" );

#########################
$realcounts{'APP1'} = grep { $_->{type} != $REFERENCE } @{$seg1->{records}};
$records = $seg1->search_record('IFD0')->get_value();
$realcounts{'APP1@IFD0'} = grep { $_->{type} != $REFERENCE } @$records;
$records = $seg1->search_record('GPS', $records)->get_value();
$realcounts{'APP1@IFD0@GPS'} = grep { $_->{type} != $REFERENCE } @$records;
$records = $seg1->search_record('IFD0')->get_value();
$records = $seg1->search_record('SubIFD', $records)->get_value();
$realcounts{'APP1@IFD0@SubIFD'} = grep { $_->{type} != $REFERENCE } @$records;
$records = $seg1->search_record('Interop', $records)->get_value();
$realcounts{'APP1@IFD0@SubIFD@Interop'}=grep {$_->{type}!=$REFERENCE} @$records;
$records = $seg1->search_record('IFD1')->get_value();
$realcounts{'APP1@IFD1'} = grep { $_->{type} != $REFERENCE } @$records;
%counts = map { $_ => (scalar keys %{$$hash{$_}}) } keys %$hash;
is_deeply( \ %counts , \ %realcounts, "(sub)IFD record counts OK ..." );

#########################
$hash = $seg1->get_Exif_data('ALL', 'NUMERIC');
%counts = map { $_ => (scalar keys %{$$hash{$_}}) } keys %$hash;
is_deeply( \ %counts , \ %realcounts, "... also without textual translation" );

#########################
$hash2 = $image->get_Exif_data('ALL', 'NUMERIC');
is_deeply( $hash, $hash2, "... Structure and Segment method coincide" );

#########################
$hash = $seg1->get_Exif_data('GPS_DATA');
$count = keys %$hash;
is_deeply( $count , $realcounts{'APP1@IFD0@GPS'}, "count OK for GPS_DATA" );

#########################
$hash2 = $image->get_Exif_data('GPS_DATA');
is_deeply( $hash, $hash2, "... Structure and Segment method coincide" );

#########################
$hash = $seg1->get_Exif_data('INTEROP_DATA');
$count = keys %$hash;
is_deeply( $count , $realcounts{'APP1@IFD0@SubIFD@Interop'},
	   "count OK for INTEROP_DATA" );

#########################
$hash2 = $image->get_Exif_data('INTEROP_DATA');
is_deeply( $hash, $hash2, "... Structure and Segment method coincide" );

#########################
$hash = $seg1->get_Exif_data('IMAGE_DATA');
$count = keys %$hash;
is_deeply( $count , $realcounts{'APP1@IFD0'} + $realcounts{'APP1@IFD0@SubIFD'},
	   "count OK for IMAGE_DATA" );

#########################
$hash2 = $image->get_Exif_data('IMAGE_DATA');
is_deeply( $hash, $hash2, "... Structure and Segment method coincide" );

#########################
$hash = $seg1->get_Exif_data('THUMB_DATA');
$count = keys %$hash;
is_deeply( $count , $realcounts{'APP1@IFD1'}, "count OK for THUMB_DATA" );

#########################
$hash2 = $image->get_Exif_data('THUMB_DATA');
is_deeply( $hash, $hash2, "... Structure and Segment method coincide" );

#########################
is( $$hash{'Compression'}[0], 6, "The test file contains a JPEG thumbnail" );

#########################
cmp_ok( $$hash{'JPEGInterchangeFormatLength'}[0], '>', 0,
	"declared size not null" );

#########################
$data = $seg1->get_Exif_data('THUMBNAIL');
isnt( $data, undef, "thumbnail data is present" );

#########################
$data2 = $image->get_Exif_data('THUMBNAIL');
is_deeply( $data, $data2, "... Structure and Segment method coincide" );

#########################
open(ZZ, $tdata); @lines = grep { /ThumbnailData/ } <ZZ>; close(ZZ);
$lines[0] =~ s/.*\(([\d]*) more values\).*/$1/;
is( length $$data, 8 + $lines[0], "thumbnail data size from description OK" );

#########################
is( length $$data, $$hash{'JPEGInterchangeFormatLength'}[0],
    "thumbnail data size from IFD1 data OK" );

#########################
$thumbimage = $cname->new($data);
ok( $thumbimage, "This thumbnail is a valid JPEG file" );

#########################
is( scalar $thumbimage->get_segments(), 7, "number of thumbnail segments OK" );

#########################
$image->remove_app1_Exif_info(-1);
is( $image->get_segments('APP1$'), 0, "Deleting Exif APP1 segments works" );

#########################
$seg1 = $image->provide_app1_Exif_segment();
$data = $seg1->get_Exif_data('THUMBNAIL');
is( $data, undef, "Absence of thumbnail correctly detected" );

#########################
$hash = $seg1->get_Exif_data('THUMB_DATA');
is_deeply( $hash, {}, "Absence of thumbnail data is correctly detected" );

#########################
$hash = $seg1->get_Exif_data('IMAGE_DATA');
is_deeply( $hash, {}, "Absence of primary image data is correctly detected" );

#########################
$hash = $seg1->get_Exif_data('GPS_DATA');
is_deeply( $hash, {}, "Absence of GPS data is correctly detected" );

#########################
$hash = $seg1->get_Exif_data('INTEROP_DATA');
is_deeply( $hash, {}, "Absence of interop. data is correctly detected" );

#########################
$hash = $seg1->get_Exif_data('ALL');
is( scalar keys %$hash, 2, "'ALL' on a bare Exif segment is not empty" );

#########################
%realcounts = ();
$realcounts{'APP1'} = grep { $_->{type} != $REFERENCE } @{$seg1->{records}};
$records = $seg1->search_record('IFD0')->get_value();
$realcounts{'APP1@IFD0'} = grep { $_->{type} != $REFERENCE } @$records;
%counts = map { $_ => (scalar keys %{$$hash{$_}}) } keys %$hash;
is_deeply( \ %counts , \ %realcounts, "Again, (sub)IFD record counts OK ..." );

### Local Variables: ***
### mode:perl ***
### End: ***
