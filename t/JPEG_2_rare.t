use Test::More;
use strict;
use warnings;

my $tphoto = 't/test_photo.jpg';
my $tdata  = 't/test_photo.desc';
my $tfrank = 't/test_frankenstein.jpg';
my $trim = sub { join '\n', map { s/^.*\"(.*)\".*$/$1/; $_ }
		 grep { /0:/ } split '\n', $_[0] };
my ($image, @segs, $seg, $hash, $num, $rec, $problem, $data);
# this is for trapping an error:
sub trap_error { local $SIG{'__'.$_[0].'__'} = sub { $problem = shift; };
		 $problem = undef; eval $_[1]; }

#=======================================
diag "Testing JPEG segments seldom used methods";
plan tests => 30;
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
{ local $SIG{'__WARN__'} = sub { $problem = shift; };
  $problem = undef; $image = $::cname->new($tfrank); }
isnt( $image, undef, "Frankenstein file read" );

#########################
ok( $problem, "Warnings generated during file read" );

#########################
ok( $problem =~ /thumbnail size/, "Thumbnail size mismatch caught" );

#########################
$num = scalar $image->get_segments();
is( $num, 66, "Number of segments is correct" );

#########################
$num = scalar grep { $_->{error} } $image->get_segments();
is( $num, 0, "No segment shows an error condition" );

#########################
@segs = $image->get_segments('APP13');
$num = grep { /2\.5/ } map { $_->search_record_value('Identifier') } @segs;
is( $num, 1, "Prehistoric APP13 identifier found" );

#########################
$seg = $::sname->new('APP0', \ "JFXX\001");
isnt( $seg->{error}, undef, "An APP0 segment with an invalid identifier" );

#########################
$seg = $::sname->new('APP1', undef, 'NOPARSE');
$seg->store_record('Namespace', 1, \ "\000");
eval { $seg->update() };
isnt( $@, '', "XPM APP1 segments not updatable yet" );

#########################
$seg = $::sname->new('APP1', undef, 'NOPARSE');
$seg->store_record('Unknown', 1, \ "\000");
eval { $seg->update() };
isnt( $@, '', "Dump of APP1 segment with unknown format catched" );

#########################
$seg = $::sname->new('APP1', undef, 'NOPARSE');
eval { $seg->update() };
isnt( $@, '', "Dump of APP1 segment with no records catched" );

#########################
$seg = $::sname->new('APP2', \ "${APP2_FPXR_TAG}\000\003");
$rec = $seg->search_record('Unknown');
isnt( $rec, undef, "An APP2 FPXR segment with a reserved type" );

#########################
$seg = $::sname->new('APP2', \ "${APP2_FPXR_TAG}\000\004");
isnt( $seg->{error}, undef, "An APP2 FPXR segment with an invalid type" );

#########################
{ local $SIG{'__WARN__'} = sub { $problem = shift; };
  $problem = undef; $num = $image->find_new_app_segment_position(); }
ok( $problem, "Generation of warning reports works" );

#########################
{ local $SIG{'__WARN__'} = sub {$problem = shift; };
  eval '$'."$::cname".'::show_warnings = undef';
  $problem = undef; $num = $image->find_new_app_segment_position();
  eval '$'."$::cname".'::show_warnings = 1'; }
ok( ! $problem, "Generation of warnings can be inhibited" );

#########################
{ local $SIG{'__DIE__'} = sub { $problem = shift; };
  $problem = undef; eval {$image->drop_segments(undef)}; }
ok( $problem, "Generation of error reports works" );

#########################
{ local $SIG{'__DIE__'} = sub { $problem = shift; };
  eval '$'."$::cname".'::show_warnings = undef';
  $problem = undef; eval {$image->drop_segments(undef)};
  eval '$'."$::cname".'::show_warnings = 1'; }
ok( $problem, "Generation of errors cannot be inhibited" );

#########################
$data = "\377\330\377\376\000\010commento\377\331"; # COM lenght should be 10
trap_error('WARN', '$::cname->new(\ $data)');
like( $problem, qr/Skipping/, "Forgiving a few bytes before next marker" );

#########################
$data = "\377\330\377\376\000\010commento" . "x"x100; # too much garbage
trap_error('DIE', '$::cname->new(\ $data)');
like( $problem, qr/Unknown punctuat/, "Too much garbage cannot be forgiven" );

#########################
$data = "\377\330\377\376\000\010commento"; # no next marker
trap_error('DIE', '$::cname->new(\ $data)');
like( $problem, qr/marker not found/, "Error on next marker not found" );

#########################
$data = "\377\330\377\376\000\010com"; # not enough data
trap_error('DIE', '$::cname->new(\ $data)');
like( $problem, qr/data not found/, "Error on segment too short" );

### Local Variables: ***
### mode:perl ***
### End: ***
