use Test::More;
use strict;
use warnings;

my $soi   = "\377\330";
my $eoi   = "\377\331";
my $sos   = "\377\332";
my $com   = "\377\376";
my $len   = "\000\010";
my $first = "\001";
my $last  = "\077";
my $esel  = "\111";
my $forged_sos = "${first}\011${esel}\277\321${last}";
my $name  = "fancydir";
my $data  = "xyz";
my ($segment, $record, $handle, $mem, $result, $dirrec);
my $trim = sub { (my $file = $::cname) =~ s/::/\//g;
		 $_[0] =~ s/ at .*$file.*//; chomp $_[0]; $_[0] };
sub reset_mem { close $handle if $handle; open($handle, '>', \$mem); }

#=======================================
diag "Testing [Image::MetaData::JPEG::Segment]";
plan tests => 53;
#=======================================

BEGIN { $::pkgname = 'Image::MetaData::JPEG';
	$::cname   = "${main::pkgname}::Segment";
	use_ok $::cname; }
BEGIN { use_ok "${main::pkgname}::Tables", qw(:RecordTypes :TagsAPP0); }

#########################
$segment = $::cname->new(undef, 'APP1', \ $forged_sos);
ok( $segment, "APP1 segment created" );

#########################
isa_ok( $segment, $::cname );

#########################
ok( $segment->{error}, "... with error flag set" );

#########################
eval { $segment->update() };
isnt( $@, '', "a faulty segment cannot be updated" );

#########################
eval { $::cname->new('COM', undef) };
isnt( $@, '', "Error OK: " . &$trim($@));

#########################
eval { $::cname->new(undef, 'COM', undef) };
is( $@, '', "ctor survives to undef data" );

#########################
$segment = $::cname->new(undef, 'COM', \ $forged_sos);
ok( $segment, "Comment segment created" );

#########################
ok( ! $segment->{error}, "... with error flag unset" );

#########################
ok( exists $segment->{records}, "the 'records' container exists" );

#########################
ok( exists $segment->{name}, "the 'name' member exists" );

#########################
$record = $segment->search_record('Comment');
ok( $record, "'Comment' record found" );

#########################
isa_ok( $record, "${main::pkgname}::Record" );

#########################
$segment = $::cname->new(undef, 'SOS', \ $forged_sos);
ok( $segment, "Forged SOS segment created" );
# This is the structure of the segment:
# [           ScanComponents]<......> = [     BYTE]  1
# [        ComponentSelector]<......> = [     BYTE]  1
# [          EntropySelector]<......> = [  NIBBLES]  0 0
# [   SpectralSelectionStart]<......> = [     BYTE]  0
# [     SpectralSelectionEnd]<......> = [     BYTE]  63
# [ SuccessiveAp...tPosition]<......> = [  NIBBLES]  0 0

#########################
ok( ! $segment->{error}, "... with error flag unset" );

#########################
is( scalar $segment->search_record('EntropySelector')->get(), $esel,
    "search_record with tag works" );

#########################
is( scalar $segment->search_record('FIRST_RECORD')->get(), $first,
    "search_record with 'FIRST_RECORD' works" );

#########################
is( scalar $segment->search_record('LAST_RECORD')->get(),  $last,
    "search_record with 'LAST_RECORD' works" );

#########################
$result = $segment->search_record();
is( $result, undef, "search_record() without args gives undef" );

#########################
eval { $segment->update() };
isnt( $@, '', "you cannot 'update' this yet" );

#########################
$segment->reparse_as('COM');
ok( ! $segment->{error}, "a SOS can be reparsed as a COM" );

#########################
$segment->reparse_as('APP2');
ok( $segment->{error}, "... but not as an APP2" );

#########################
$segment->reparse_as('SOS');
reset_mem(); $result = $segment->output_segment_data($handle);
ok( $result, "output_segment_data does not fail" );

#########################
is( $mem, "${sos}${len}${forged_sos}",
    "... and its return value is correct" );

#########################
isnt( $segment->get_description(), undef, "get_description gives non-undef" );

#########################
$segment = $::cname->new(undef, 'APP1', \ $forged_sos, 'NOPARSE');
ok( ! $segment->{error}, "NOPARSE actually avoids parsing" );

#########################
eval { $segment->update() };
isnt( $@, '', "... but then you cannot update" );

#########################
$segment = $::cname->new(undef, 'COM');
reset_mem(); $result = $segment->output_segment_data($handle);
is( $mem, "$com\000\002", "output_segment_data works with empty comments" );

#########################
$segment->search_record('Comment')->set_value('*' x 2**16);
eval { $segment->update() };
is( $@, '', "an empty segment can be modified and updated" );

#########################
$segment = $::cname->new(undef, 'COM', \ '');
$segment->search_record('Comment')->set_value('*' x 2**16);
eval { $segment->update() };
is( $@, '', "an empty segment can be modified and updated (2)" );

#########################
eval { reset_mem(); $segment->output_segment_data($handle) };
isnt( $@, '', "size check works in forged comment" );

#########################
$segment = $::cname->new(undef, 'ECS', \ $forged_sos);
reset_mem(); $segment->output_segment_data($handle);
is( $mem, $forged_sos, "Raw output for raw data" );

#########################
$segment = $::cname->new(undef, 'Post-EOI', \ $forged_sos);
reset_mem(); $segment->output_segment_data($handle);
is( $mem, $forged_sos, "Raw output for Post-EOI data" );

#########################
$segment = $::cname->new(undef, 'SOI');
reset_mem(); $segment->output_segment_data($handle);
is( $mem, $soi, "Correct output for SOI" );

#########################
$segment = $::cname->new(undef, 'EOI');
reset_mem(); $segment->output_segment_data($handle);
is( $mem, $eoi, "Correct output for EOI" );

#########################
$segment->provide_subdirectory($name);
$dirrec = $segment->search_record($name);
isnt( $dirrec, undef, "'$name' creation ok" );

#########################
is_deeply( $dirrec->get_value(), [], "... it is an empty array" );

#########################
$dirrec = $segment->search_record_value($name);
$segment->provide_subdirectory($name.$name, $dirrec);
$dirrec = $segment->search_record_value($name.$name, $dirrec);
is_deeply( $dirrec, [], "'$name$name' creation ok" );

#########################
$dirrec = $segment->search_record($name.$name);
is( $dirrec, undef, "... it is not in the root dir" );

#########################
$dirrec = $segment->search_record_value($name);
$segment->provide_subdirectory($name, $dirrec);
$dirrec = $segment->search_record_value($name.'@'.$name);
is_deeply( $dirrec, [], "'$name\@$name' creation ok" );

#########################
$result = $segment->search_record_value($name, $name);
is_deeply( $dirrec, $result, "... search_record alternative syntax OK" );

#########################
$record = $segment->create_record('uno', $ASCII, \ $data);
is( $record->get_value(), $data, "create_record ok [ref]" );

#########################
$segment = $::cname->new(undef, 'COM', \ $data);
$record = $segment->create_record('uno', $ASCII, 0, length $data);
is( $record->get_value(), $data, "create_record ok [offset]" );

#########################
$result = $segment->read_record($ASCII, \ $data);
is( $result, $data, "read_record   ok [ref]" );

#########################
$result = $segment->read_record($ASCII, 0, length $data);
is( $result, $data, "read_record   ok [offset]" );

#########################
$dirrec = $segment->provide_subdirectory($name);
$result = $segment->store_record($dirrec, 'due', $ASCII, 0, length $data);
is( $result->get_value(), $data, "store_record  ok [ref]" );

#########################
$segment->store_record($dirrec, 'tre', $ASCII, \ $data);
$result = $segment->search_record_value('tre', $dirrec);
is( $result, $data, "store_record  ok [offset]" );

#########################
$segment = $::cname->new(undef, 'APP0', \ ($APP0_JFXX_TAG . chr($APP0_JFXX_1B).
				    "\100\040". 'x' x ($APP0_JFXX_PAL+2048)) );
is( $segment->{error}, undef, "The faboulous 1B-JFXX APP0 segment" );

######################### Patent-covered, impossible-to-find segments
$segment = $::cname->new(undef, 'DAC', \ "\012\345\274\333");
is( $segment->{error}, undef, "A fake DAC segment" );

#########################
$segment = $::cname->new(undef, 'DAC', \ "\012\345\274");
isnt( $segment->{error}, undef, "An invalid DAC segment" );

#########################
$segment = $::cname->new(undef, 'EXP', \ "\345");
is( $segment->{error}, undef, "A fake EXP segment" );

#########################
$segment = $::cname->new(undef, 'EXP', \ "\012\345");
isnt( $segment->{error}, undef, "An invalid EXP segment" );

#########################
$segment = $::cname->new(undef, 'DNL', \ "\012\345");
is( $segment->{error}, undef, "A fake DNL segment" );

#########################
$segment = $::cname->new(undef, 'DNL', \ "\012\345\274");
isnt( $segment->{error}, undef, "An invalid DNL segment" );

### Local Variables: ***
### mode:perl ***
### End: ***
