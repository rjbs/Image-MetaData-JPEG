use Test::More;
use strict;
use warnings;
use Image::MetaData::JPEG;

my $cname  = 'Image::MetaData::JPEG';
my $tphoto = 't/test_photo.jpg';
my $tdata  = 't/test_photo.desc';
my $cphoto = 't/test_photo_copy.jpg';
my $IPTCdir = "IPTC_RECORD_2";
my ($image, $seg1, $seg2, $hash, $hash2, $hashtot, $ref, $num, $segs, $recver);

my $ht = { ObjectName           => [ "prova" ],
	   ByLine               => [ "ciao" ],
	   Keywords             => [ "donald", "duck" ],
	   ActionAdvised        => [ "02" ],
	   SupplementalCategory => ["arte", "scienza", "sport"] };
my $hn = { 55 => [ "19890207" ], 65 => [ 2 ],
	   80 => [ "d3", "d4" ], 15 => [ "b" ] };
my $ver = "\000\002";
my $nkey = 'singola';

#=======================================
diag "Testing APP13 IPTC data routines";
plan tests => 46;
#=======================================

#########################
$image = $cname->new($tphoto);
is( $image->get_segments('APP13'), 1, "Number of APP13 segments" );

#########################
is( $image->retrieve_app13_IPTC_segment(-1), 1, "Number, alternatively" );

#########################
is( $image->retrieve_app13_IPTC_segment(1), undef, "Out-of-bound index" );

#########################
$seg1 = $image->retrieve_app13_IPTC_segment(0);
$seg2 = $image->provide_app13_IPTC_segment();
is_deeply( $seg1, $seg2, "Get segment in two ways" );

#########################
$ref = $seg1->search_record($IPTCdir)->get_value();
$num = scalar @$ref;
$hash = $seg1->get_IPTC_data('NUMERIC');
is( keys %$hash, $num, "Num elements from numeric get" );

#########################
is( exists $$hash{0} ? 1 : undef, 1, "Record Version exists" );

#########################
is( (grep {/^[0-9]*$/} keys %$hash), $num, "All tags are numeric" );

#########################
$hash = $seg1->get_IPTC_data('TEXTUAL');
is( keys %$hash, $num, "Num elements from textual get" );

#########################
is( (grep {!/^[0-9]*$/} keys %$hash), $num, "All tags are textual" );

#########################
$seg1->set_IPTC_data({'ObjectName' => 'newname'}, 'ADD');
$seg1->set_IPTC_data({'ObjectName' => 'newname2'}, 'ADD');
$hash = $seg1->get_IPTC_data('TEXTUAL');
$ref = $$hash{'ObjectName'};
is( $#$ref, 0, "Non-repeatable constraint is enforced" );

#########################
is( $$ref[0], 'newname2', "Correct precedence for nonrepeatables" );

#########################
%{$hashtot} = %{$seg1->get_IPTC_data('TEXTUAL')};
push @{$$hashtot{$_}}, @{$$ht{$_}} for keys %$ht;
$$hashtot{'ObjectName'} = $$ht{'ObjectName'}; # fix non-repeatable
$seg1->set_IPTC_data($ht, 'ADD');
$hash = $seg1->get_IPTC_data('TEXTUAL');
is_deeply( $hash, $hashtot, "Adding records textually" );

#########################
$seg1->set_IPTC_data({'Keywords' => $nkey}, 'UPDATE');
$hash = $seg1->get_IPTC_data('TEXTUAL');
is_deeply( $$hash{'Keywords'}, [ $nkey ], "UPDATE addresses user tags ..." );

#########################
is_deeply( $$hash{'SupplementalCategory'}, $$hashtot{'SupplementalCategory'},
	   "... without touching the others" );

#########################
$seg1->set_IPTC_data($ht, 'REPLACE');
$hash = $seg1->get_IPTC_data('TEXTUAL');
$recver = delete $$hash{'RecordVersion'};
is_deeply( $hash, $ht, "Replacing instead of adding" );

#########################
is( $$recver[0], $ver, "Record version is OK" );

#########################
$hash = $seg1->get_IPTC_data('NUMERIC');
$seg1->set_IPTC_data($hn, 'ADD');
$hashtot = $hash;
push @{$$hashtot{$_}}, @{$$hn{$_}} for keys %$hn;
$hash = $seg1->get_IPTC_data('NUMERIC');
is_deeply( $hash, $hashtot, "Adding records numerically" );

#########################
$seg1->set_IPTC_data($hn, 'REPLACE');
$hash = $seg1->get_IPTC_data('NUMERIC');
$recver = delete $$hash{0};
is_deeply( $hash, $hn, "Replacing records numerically" );

#########################
is( $$recver[0], $ver, "Record version added automatically" );

#########################
$hash = $image->get_IPTC_data('NUMERIC');
$recver = delete $$hash{0};
is_deeply( $hash, $hn, "High level get IPTC data (numeric)" );

#########################
$hashtot = $seg1->get_IPTC_data('TEXTUAL');
push @{$$hashtot{$_}}, @{$$ht{$_}} for keys %$ht;
$image->set_IPTC_data($ht, 'ADD');
$hash = $image->get_IPTC_data('TEXTUAL');
is_deeply( $hash, $hashtot, "High level set/get (textual)" );

#########################
$image->remove_app13_IPTC_info(-1);
$num = $image->retrieve_app13_IPTC_segment(-1);
is( $num, 0, "Removing IPTC information" );

#########################
$num = $image->get_segments('APP13');
is( $num, 1, "... but not the APP13 segment" );

#########################
$segs = $image->{segments};
@$segs = grep { $_->{name} !~ /APP13/ } @$segs;
is( $image->get_segments('APP13'), 0, "Segment removal" );

#########################
$image->set_IPTC_data($ht, 'ADD');
$hash = $image->get_IPTC_data('TEXTUAL');
$recver = delete $$hash{'RecordVersion'};
is_deeply( $hash, {%$ht}, "Forcing an IPTC segment (high level)" );

#########################
$image->remove_app13_IPTC_info(0);
$num = $image->retrieve_app13_IPTC_segment(-1);
is( $num, 0, "Removing IPTC information with index" );

#########################
$num = $image->get_segments('APP13');
is( $num, 0, "... this time, a real segment removal" );

#########################
@$segs = grep { $_->{name} !~ /APP13/ } @$segs;
$image->set_IPTC_data($hn, 'REPLACE');
$hash = $image->get_IPTC_data('NUMERIC');
$recver = delete $$hash{0};
is_deeply( $hash, {%$hn}, "Same, but with replace and numerically" );

#########################
$recver = [ "\123\156" ];
$image->set_IPTC_data({'RecordVersion' => $recver}, 'ADD');
$hash = $image->get_IPTC_data('TEXTUAL');
is_deeply( $$hash{'RecordVersion'}, $recver, "Record version can be changed" );

#########################
@$segs = grep { $_->{name} !~ /APP13/ } @$segs;
$seg1 = $image->retrieve_app13_IPTC_segment(0);
is( $seg1, undef, "Retrieve not forcing a segment" );

#########################
$seg2 = $image->provide_app13_IPTC_segment();
isnt( $seg2, undef, "Provide forcing a segment" );

#########################
$seg2->set_IPTC_data($ht, 'REPLACE');
$hashtot = $seg2->get_IPTC_data('NUMERIC');
$seg2->set_IPTC_data($hn, 'ADD');
push @{$$hashtot{$_}}, @{$$hn{$_}} for keys %$hn;
$image->save($cphoto);
$image = $cname->new($cphoto, 'APP13', 'FASTREADONLY');
unlink $cphoto;
isnt( $image, undef, "File written and re-read");

#########################
$hash = $image->get_IPTC_data('NUMERIC');
isnt( $hash, undef, "There is an APP13 segment" );

#########################
is_deeply( $hash, $hashtot, "Re-read data is ok" );

#########################
$hash = $image->get_IPTC_data('NUMERICAL');
is( $hash, undef, "No segment with wrong label" );

#########################
eval { $image->set_IPTC_data(undef) };
is( $@, '', "No error with undefined argument in set" );

#########################
$hash = $image->get_IPTC_data('ILLEGAL');
is( $hash, undef, "No action with illegal type in get" );

#########################
$hashtot = undef;
$$hashtot{$_} = [ @{$$hn{$_}} ] for keys %$hn;
$$hashtot{$_} = [ @{$$ht{$_}} ] for keys %$ht;
$image->set_IPTC_data($hashtot, 'REPLACE');
$hash = $image->get_IPTC_data('NUMERIC');
$image->set_IPTC_data($ht, 'REPLACE');
$hashtot = $image->get_IPTC_data('NUMERIC');
for (keys %$hn) { if (! exists $$hashtot{$_}) { $$hashtot{$_} = $$hn{$_} }
		  else { push @{$$hashtot{$_}}, @{$$hn{$_}} }; }
is_deeply( $hash, $hashtot, "Set with mixed type tags" );

#########################
$seg1 = $image->retrieve_app13_IPTC_segment(0);
$seg1->{name} = 'trick';
$image->provide_app13_IPTC_segment();
$seg1->{name} = 'APP13';
is( $image->retrieve_app13_IPTC_segment(-1), 2, "Two APP13 segments now" );

#########################
$seg1 = $image->retrieve_app13_IPTC_segment(0);
$seg2 = $image->retrieve_app13_IPTC_segment(1);
$seg1->set_IPTC_data($ht, 'REPLACE');
$seg2->set_IPTC_data($hn, 'REPLACE');
$hash = $image->get_IPTC_data();
%$hashtot = %{$seg1->get_IPTC_data()};
$hash2 = $seg2->get_IPTC_data();
while (my ($tag, $aref) = each %$hash2) {
    $$hashtot{$tag} = [] unless exists $$hashtot{$tag};
    $ref = $$hashtot{$tag}; push @$ref, @$aref; }
is_deeply( $hash, $hashtot, "Run get_IPTC_data with two segments" );

#########################
$image->remove_app13_IPTC_info(0);
is( $image->retrieve_app13_IPTC_segment(-1), 1, "First segment eliminated" );

#########################
$$ht{'An invalid tag'} = [ 'ciao', 34 ];
$$ht{'Zibaldone'} = [ 'ariciao' ];
$hash = $image->set_IPTC_data($ht, 'ADD');
is( scalar keys %$hash, 2, "Two invalid textual entries rejected" );

#########################
$$hn{99} = [ 'pippero' ];
$$hn{-1} = [ 'paperopoli' ];
$hash = $image->set_IPTC_data($hn, 'ADD');
is( scalar keys %$hash, 2, "Two invalid numeric entries rejected" );

#########################
$hash = $image->set_IPTC_data({'RecordVersion' => [ "ab", "cd" ] }, 'UPDATE');
is( scalar keys %$hash, 1, "Updating illegally fails" );

#########################
$hash  = $image->get_IPTC_data('TEXTUAL');
$hash2 = $image->set_IPTC_data({'RecordVersion' => 'ab'}, 'UPDATE');
is( scalar keys %$hash2, 0, "Updating record version work ..." );

#########################
$hash2 = $image->get_IPTC_data('TEXTUAL');
$$hash{'RecordVersion'} = [ 'ab' ];
is_deeply( $hash, $hash2, "... without touching the other tags" );

### Local Variables: ***
### mode:perl ***
### End: ***
