use Test::More;
use strict;
use warnings;

my $tphoto = 't/test_photo.jpg';
my $tdata  = 't/test_photo.desc';
my $tfrank = 't/test_frankenstein.jpg';
my $trim = sub { $_[0] =~ s/at .*//; chomp $_[0]; $_[0] };
my ($image, @segs, $seg, $hash, $num, $rec, @warnings);

#=======================================
diag "Testing JPEG segments seldom used methods";
plan tests => 21;
#=======================================

#########################
BEGIN { $::cname  = 'Image::MetaData::JPEG'; use_ok $::cname; }
BEGIN { $::sname  = $::cname . '::Segment' ; use_ok $::sname; }
BEGIN { use_ok $::cname . '::Tables', qw(:TagsAPP2); }

#########################
$image = $::cname->new($tphoto);
@segs = $image->get_segments('APP1');
isnt( scalar @segs, 0, "An APP1 segment is there" );

#########################
$seg = $segs[0];
isnt( $seg, undef, "Its reference is not undefined" );

#########################
$seg->reparse_as('COM');
is( $seg->{error}, undef, "All segments can be reparsed as comments" );

#########################
$seg->reparse_as('APP13');
isnt( $seg->{error}, undef, &$trim($seg->{error}) );

#########################
$seg->reparse_as('DQT');
isnt( $seg->{error}, undef, &$trim($seg->{error}) );

#########################
$seg->reparse_as('xxxx'); # this should trigger parse_unknown()
isnt( $seg->{error}, undef, &$trim($seg->{error}) );

#########################
$seg->reparse_as('APP1');
is( $seg->{error}, undef, "... the mistreated APP1 can return APP1" );

#########################
$hash = $image->get_app0_data();
is( ref $hash, 'HASH', "get_app0_data returns a hash reference" );

#########################
isnt( scalar keys %$hash, 0, "There is APP0 data out there" );

#########################
$num = scalar grep { ! ref $_ } values %$hash;
is( $num, scalar keys %$hash, "All values are scalars" );

#########################
@warnings = ();
{ local $SIG{'__WARN__'} = sub { push @warnings, shift; };
  $image = $::cname->new($tfrank); }
isnt( $image, undef, "Frankenstein file read" );

#########################
isnt( scalar @warnings, 0, "Warnings generated during file read" );

#########################
is( scalar (grep {/thumbnail size/} @warnings), 1,
    "Thumbnail size mismatch caught" );

#########################
$num = scalar $image->get_segments();
is( $num, 65, "Number of segments is correct" );

#########################
$num = scalar grep { $_->{error} } $image->get_segments();
is( $num, 0, "No segment shows an error condition" );

#########################
$seg = $::sname->new(undef, 'APP0', \ "JFXX\001");
isnt( $seg->{error}, undef, "An APP0 segment with an invalid identifier" );

#########################
$seg = $::sname->new(undef, 'APP1', undef, 'NOPARSE');
$seg->store_record('Namespace', 1, \ "\000");
eval { $seg->update() };
isnt( $@, '', "XPM APP1 segments not updatable yet" );

#########################
$seg = $::sname->new(undef, 'APP1', undef, 'NOPARSE');
$seg->store_record('Unknown', 1, \ "\000");
eval { $seg->update() };
isnt( $@, '', "Dump of APP1 segment with unknown format catched" );

#########################
$seg = $::sname->new(undef, 'APP1', undef, 'NOPARSE');
eval { $seg->update() };
isnt( $@, '', "Dump of APP1 segment with no records catched" );

#########################
$seg = $::sname->new(undef, 'APP2', \ "${APP2_FPXR_TAG}\000\003");
$rec = $seg->search_record('Unknown');
isnt( $rec, undef, "An APP2 FPXR segment with a reserved type" );

#########################
$seg = $::sname->new(undef, 'APP2', \ "${APP2_FPXR_TAG}\000\004");
isnt( $seg->{error}, undef, "An APP2 FPXR segment with an invalid type" );

### Local Variables: ***
### mode:perl ***
### End: ***
