use Test::More;
use strict;
use warnings;

my ($record, $data, $result, $mykey, $key, $type, $count, $dataref, @v, @w);
my $trim = sub { (my $file = $::cname) =~ s/::/\//g;
		 $_[0] =~ s/ at .*$file.*//; chomp $_[0]; $_[0] };

#=======================================
diag "Testing JPEG segment record objects";
plan tests => 60;
#=======================================

BEGIN { $::pkgname = 'Image::MetaData::JPEG';
	$::cname   = "${main::pkgname}::Record";
	use_ok $::cname; }
BEGIN { use_ok "${main::pkgname}::Tables", qw(:RecordTypes :Endianness); }

#########################
$data  = "an average string"; 
$mykey = 'Test';
$record = $::cname->new($mykey, $ASCII, \$data, length $data);
ok( $record, "ASCII ctor" );

#########################
isa_ok( $record, $::cname, "Class is $::cname" );

#########################
ok($::cname->new(0x3456, $ASCII, \$data, length $data), "with numeric tag" );

#########################
is($::cname->new(0x3456, $ASCII), undef, "survives to undef data" );

#########################
$record = $::cname->new($mykey, $ASCII, \$data, length $data);
$result = $record->get_value();
is( $data, $result, "rereading ASCII data" );

#########################
$result = scalar $record->get();
is( $data, $result, "... test of get" );

#########################
($key, $type, $count, $dataref) = $record->get();
is_deeply( [$mykey,$type,$dataref],
	   [$key,$ASCII,\$data], "... test of get (list)" );

#########################
$record = $::cname->new($mykey, $UNDEF, \$data, length $data);
$result = $record->get_value();
is( $data, $result, "rereading UNDEF variables" );

#########################
$data = \ $mykey;
$record = $::cname->new($mykey, $REFERENCE, \$data);
$result = $record->get_value();
is( $data, $result, "rereading REFERENCE variables" );

#########################
ok( ref $data, "... it is really a reference" );

#########################
is( $$data, $mykey, "... its value is correct" );

#########################
$data = "\171\072"; # 0111.1001.0011.1010 = 7.9.3.10 = 7.9.3.a
$record = $::cname->new($mykey, $NIBBLES, \$data, 2);
$result = $record->get_value(); # 7+9+3+10 = 29
is( $result, 29, "rereading nibbles");
is( $record->get_value(0),  7, "... 1st value" );
is( $record->get_value(1),  9, "... 2nd value" );
is( $record->get_value(2),  3, "... 3rd value" );
is( $record->get_value(3), 10, "... 4th value" );

#########################
$result = $record->get();
is( $result, $data, "... as binary data" );

#########################
$data = pack "CCC", 92, 191, 49; # 0x5cbf31
$record = $::cname->new($mykey, $BYTE, \$data, 3);
$result = $record->get_value(); # 92+191+49 = 332
is( $result, 332, "rereading unsigned chars");

#########################
$result = $record->get();
is( length $result, length $data, "... as binary data (length)" );
is( $result, $data, "... as binary data (content)" );

#########################
$record = $::cname->new($mykey, $SBYTE, \$data, 3);
$result = $record->get_value(); # 92+(-65)+49 = 76
is( $result, 76, "rereading signed chars" );

#########################
$result = $record->get();
is( length $result, length $data, "... as binary data (length)");
is( $result, $data, "... as binary data (content)" );

#########################
$data = pack "nnn", 134, 42000, 32191; # 0x0086a4107dbf
$record = $::cname->new($mykey, $SHORT, \$data, 3);
$result = $record->get_value(); # 134+42000+32191 = 74325
is( $result, 74325, "rereading unsigned shorts" );

#########################
$result = $record->get($BIG_ENDIAN);
is( $result, $data, "... as binary data" );

#########################
$record = $::cname->new($mykey, $SHORT, \$data, 3, $LITTLE_ENDIAN);
$result = $record->get_value(); # 34304+4260+49021 = 87585
is( $result, 87585, "... using little endian" );

#########################
$result = $record->get($LITTLE_ENDIAN);
is( $result, $data, "... repacking as little endian" );

#########################
$record = $::cname->new($mykey, $SHORT, \$data, 3, $BIG_ENDIAN);
$result = $record->get($LITTLE_ENDIAN);
is( $result, (pack "vvv",unpack "nnn",$data), "... little endian paranoia" );

#########################
$record = $::cname->new($mykey, $SSHORT, \$data, 3);
$result = $record->get_value(); # 134+(-23536)+32191 = 8789
is( $result, 8789, "rereading signed shorts" );

#########################
$result = $record->get();
is( $result, $data, "... as binary data" );

#########################
$record = $::cname->new($mykey, $SSHORT, \$data, 3, $LITTLE_ENDIAN);
$result = $record->get_value(); # (-31232)+4260+(-16515) = -43487
is( $result, -43487, "... using little endian" );

#########################
$result = $record->get($LITTLE_ENDIAN);
is( $result, $data, "... repacking as little endian" );

#########################
$result = $record->get($BIG_ENDIAN);
is( $result, (pack "vvv", unpack "nnn", $data), "... big endian paranoia" );

#########################
@v = (2720118940, 3778117118, 407087547, 3339718614);
$data = pack "NNNN", @v; # 0x a221b89c.e1317dfe.1843a9bb.c7100fd6
$record = $::cname->new($mykey, $LONG, \$data, 4);
$result = $record->get_value();
is( $result, ($v[0]+$v[1]+$v[2]+$v[3]), "rereading unsigned longs" );
is( $record->get_value(0), $v[0], "... 1st value" );
is( $record->get_value(1), $v[1], "... 2nd value" );
is( $record->get_value(2), $v[2], "... 3rd value" );
is( $record->get_value(3), $v[3], "... 4th value" );

#########################
$result = $record->get();
is( $result, $data, "... as binary data" );

#########################
@w = map { unpack "V", (pack "N",$_) } @v;
$record = $::cname->new($mykey, $LONG, \$data, 4, $LITTLE_ENDIAN);
$result = $record->get_value();
is( $result, ($w[0]+$w[1]+$w[2]+$w[3]), "... using little endian" );
is( $record->get_value(0), $w[0], "... 1st value" );
is( $record->get_value(1), $w[1], "... 2nd value" );
is( $record->get_value(2), $w[2], "... 3rd value" );
is( $record->get_value(3), $w[3], "... 4th value" );

#########################
@v = map { ($_ >= 2**31) ? $_ -= 2**32 : $_ } @v;
$record = $::cname->new($mykey, $SLONG, \$data, 4);
$result = $record->get_value();
is( $result, ($v[0]+$v[1]+$v[2]+$v[3]), "rereading signed longs" );

#########################
$result = $record->get();
is( $result, $data, "... as binary data" );

#########################
@w = map { unpack "V", (pack "N",$_) } @v;
$record = $::cname->new($mykey, $LONG, \$data, 4, $LITTLE_ENDIAN);
$result = $record->get_value();
is( $result, ($w[0]+$w[1]+$w[2]+$w[3]), "... using little endian" );

#########################
$result = $record->get($LITTLE_ENDIAN);
is( $result, $data, "... repacking as little endian" );

#########################
$result = $record->get($BIG_ENDIAN);
is( $result, (pack "VVVV", unpack "NNNN", $data), "... big endian paranoia" );

#########################
@v = (2720118940, 3778117118, 407087547, 3339718614);
$data = pack "NNNN", @v;
$record = $::cname->new($mykey, $RATIONAL, \$data, 2);
$result = $record->get_value();
is( $result, ($v[0]+$v[1]+$v[2]+$v[3]), "rereading unsigned rationals" );

#########################
$result = $record->get();
is( $result, $data, "... as binary data" );

#########################
@w = map { ($_ >= 2**31) ? $_ -= 2**32 : $_ }
     map { unpack "V", (pack "N",$_) } @v;
$record = $::cname->new($mykey, $SRATIONAL, \$data, 2, $LITTLE_ENDIAN);
$result = $record->get_value();
is( $result, ($w[0]+$w[1]+$w[2]+$w[3]), "... with little endian and sign" );

#########################
$result = $record->get($LITTLE_ENDIAN);
is( $result, $data, "... as binary data" );

#########################
eval { $::cname->new($mykey, $SRATIONAL, \$data, 3) };
ok( $@, "Fail OK: " . &$trim($@) );

#########################
eval { $::cname->new($mykey, $SRATIONAL, \$data, 5) };
ok( $@, "Fail OK: " . &$trim($@) );

#########################
eval { $::cname->new($mykey, $FLOAT, \$data, 4) };
ok( $@, "Fail OK: " . &$trim($@) );

#########################
eval { $::cname->new($mykey, $DOUBLE, \$data, 2) };
ok( $@, "Fail OK: " . &$trim($@) );

#########################
eval { $::cname->new($mykey, $UNDEF, \$data, 199) };
ok( $@, "Fail OK: " . &$trim($@) );

#########################
$record = $::cname->new($mykey, $UNDEF, \$data, length $data);
is( $data, scalar $record->get(), "Variable-length size specified" );

#########################
$record = $::cname->new($mykey, $UNDEF, \$data);
is( $data, scalar $record->get(), "Variable-length size unspecified" );

### Local Variables: ***
### mode:perl ***
### End: ***
