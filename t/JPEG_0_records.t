use Test::More;
use strict;
use warnings;

my ($record, $data, $result, $mykey, $key, $type, $count, $dataref, @v, @w);
my $trim = sub { (my $file = $::cname) =~ s/::/\//g;
		 $_[0] =~ s/ at .*$file.*//; chomp $_[0]; $_[0] };
my @messages = ( "1st value", "2nd value" , "3rd value", "4th value" );
# this stuff is needed for testing floating point numbers
sub vsum      { my $s = 0; $s += $_ for @_; $s }
sub pack_ieee { my $v = pack $_[0], $_[1]; $_[2] ? \(scalar reverse $v) : \$v};
sub test_ieee { my $e = shift; my $i = ref $_[0] ? undef : shift;
		abs(($_[0]->get_value($i)-$_[1])/$_[1]) < 2**(-$e) ? 1:undef };
sub pack_float { pack_ieee('f', @_) };
sub test_float { test_ieee( 23, @_) };
sub pack_double{ pack_ieee('d', @_) };
sub test_double{ test_ieee( 52, @_) };

#=======================================
diag "Testing [Image::MetaData::JPEG::Record]";
plan tests => 131;
#=======================================

BEGIN { $::pkgname = 'Image::MetaData::JPEG';
	$::cname   = "${main::pkgname}::Record";
	use_ok $::cname; }
BEGIN { use_ok "${main::pkgname}::Tables", qw(:RecordTypes :Endianness); }

#########################
my $native = $NATIVE_ENDIANNESS;
my $not_native = ($native eq $BIG_ENDIAN ? $LITTLE_ENDIAN : $BIG_ENDIAN);
isnt( $native, undef, "Endianness detected: $native" );

#########################
$data  = "an average string"; 
$mykey = 'Test';
$record = $::cname->new($mykey, $ASCII, \$data, length $data);
ok( $record, "ASCII ctor" );

#########################
isa_ok( $record, $::cname );

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
@v = ( 7, 9, 3, 10 );
$data = pack "CC", map { 16*$v[$_] + $v[1+$_] } (0,2);
$record = $::cname->new($mykey, $NIBBLES, \$data, 2);
is( $record->get_value(), vsum(@v), "rereading nibbles");
is( $record->get_value($_), $v[$_], "... ".$messages[$_] ) for (0..$#v);

#########################
$result = $record->get();
is( $result, $data, "... as binary data" );

#########################
@v = ( 92, 191, 49 );
$data = pack "C" x @v, @v;
$record = $::cname->new($mykey, $BYTE, \$data, scalar @v);
is( $record->get_value(), vsum(@v), "rereading unsigned chars");

#########################
$result = $record->get();
is( length $result, length $data, "... as binary data (length)" );
is( $result, $data, "... as binary data (content)" );

#########################
@v = map { ($_ >= 2**7) ? ($_ - 2**8) : $_ } @v;
$record = $::cname->new($mykey, $SBYTE, \$data, scalar @v);
$result = $record->get_value();
is( $record->get_value(), vsum(@v), "rereading signed chars" );

#########################
$result = $record->get();
is( length $result, length $data, "... as binary data (length)");
is( $result, $data, "... as binary data (content)" );

#########################
@v = ( 134, 42000, 32191 );
$data = pack "n" x @v, @v;
$record = $::cname->new($mykey, $SHORT, \$data, scalar @v);
is( $record->get_value(), vsum(@v), "rereading unsigned shorts" );

#########################
$result = $record->get($BIG_ENDIAN);
is( $result, $data, "... as binary data" );

#########################
@v = ( 34304, 4260, 49021 );
$data = pack "v" x @v, @v;
$record = $::cname->new($mykey, $SHORT, \$data, scalar @v, $LITTLE_ENDIAN);
is( $record->get_value(), vsum(@v), "... using little endian" );

#########################
$result = $record->get($LITTLE_ENDIAN);
is( $result, $data, "... repacking as little endian" );

#########################
$record = $::cname->new($mykey, $SHORT, \$data, scalar @v, $BIG_ENDIAN);
$result = $record->get($LITTLE_ENDIAN);
is( $result, (pack "vvv",unpack "nnn",$data), "... little endian paranoia" );

#########################
$data = pack "n" x @v, @v;                        # repack trick ...
@v = map { ($_ >= 2**15) ? ($_ - 2**16) : $_ } @v; # ... continued
$record = $::cname->new($mykey, $SSHORT, \$data, scalar @v);
is( $record->get_value(), vsum(@v), "rereading signed shorts" );

#########################
$result = $record->get();
is( $result, $data, "... as binary data" );

#########################
$data = pack "v" x @v, @v;                        # repack trick ...
@v = map { ($_ >= 2**15) ? ($_ - 2**16) : $_ } @v; # ... continued
$record = $::cname->new($mykey, $SSHORT, \$data, scalar @v, $LITTLE_ENDIAN);
is( $record->get_value(), vsum(@v), "... using little endian" );

#########################
$result = $record->get($LITTLE_ENDIAN);
is( $result, $data, "... repacking as little endian" );

#########################
$result = $record->get($BIG_ENDIAN);
is( $result, (pack "vvv", unpack "nnn", $data), "... big endian paranoia" );

#########################
@v = (2720118940, 3778117118, 407087547, 3339718614);
$data = pack "N" x @v, @v;
$record = $::cname->new($mykey, $LONG, \$data, scalar @v);
is( $record->get_value(), vsum(@v), "rereading unsigned longs" );
is( $record->get_value($_), $v[$_], "... ".$messages[$_] ) for (0..$#v);

#########################
$result = $record->get();
is( $result, $data, "... as binary data" );

#########################
@w = map { unpack "V", (pack "N",$_) } @v;
$record = $::cname->new($mykey, $LONG, \$data, scalar @w, $LITTLE_ENDIAN);
$result = $record->get_value();
is( $record->get_value(), vsum(@w), "... using little endian" );
is( $record->get_value($_), $w[$_], "... ".$messages[$_] ) for (0..$#w);

#########################
@v = map { ($_ >= 2**31) ? $_ -= 2**32 : $_ } @v;
$record = $::cname->new($mykey, $SLONG, \$data, scalar @v);
is( $record->get_value(), vsum(@v), "rereading signed longs" );

#########################
$result = $record->get();
is( $result, $data, "... as binary data" );

#########################
@w = map { unpack "V", (pack "N",$_) } @v;
$record = $::cname->new($mykey, $LONG, \$data, scalar @w, $LITTLE_ENDIAN);
is( $record->get_value(), vsum(@w), "... using little endian" );

#########################
$result = $record->get($LITTLE_ENDIAN);
is( $result, $data, "... repacking as little endian" );

#########################
$result = $record->get($BIG_ENDIAN);
is( $result, (pack "VVVV", unpack "NNNN", $data), "... big endian paranoia" );

#########################
@v = (2720118940, 3778117118, 407087547, 3339718614);
$data = pack "N" x @v, @v;
$record = $::cname->new($mykey, $RATIONAL, \$data, @v/2);
is( $record->get_value(), vsum(@v), "rereading unsigned rationals" );

#########################
$result = $record->get();
is( $result, $data, "... as binary data" );

#########################
@w = map { ($_ >= 2**31) ? ($_ - 2**32) : $_ }
     map { unpack "V", (pack "N",$_) } @v;
$record = $::cname->new($mykey, $SRATIONAL, \$data, @w/2, $LITTLE_ENDIAN);
is( $record->get_value(), vsum(@w), "... with little endian and sign" );

#########################
$result = $record->get($LITTLE_ENDIAN);
is( $result, $data, "... as binary data" );

#########################
@v = ( 2**31, 3791912960 );
$data = pack "V" x @v, @v;
$record = $::cname->new($mykey, $RATIONAL, \$data, @v/2, $LITTLE_ENDIAN);
($result = $record->get_description([])) =~ s/.*RATIONAL\](.*)/$1/;
unlike( $result, qr/-/, "No negative sign in unsigned rational" );

#########################
$record = $::cname->new($mykey, $SRATIONAL, \$data, @v/2, $LITTLE_ENDIAN);
($result = $record->get_description([])) =~ s/.*RATIONAL\](.*)/$1/;
like( $result, qr/-/, "Negative sign in signed rational" );

#########################
eval { $::cname->new($mykey, $SRATIONAL, \$data, 1 + @v/2) };
ok( $@, "Fail OK: " . &$trim($@) );

#########################
@v = (17.385601);
$data = pack_float($v[0]);
$record = $::cname->new($mykey, $FLOAT, $data, 1, $native);
ok( test_float($record, $v[0]), "Positive float (native order)" );

#########################
$result = $record->get($native);
is( $result, $$data, "... as binary data" );

#########################
@v = (-55.173856);
$data = pack_float($v[0]);
$record = $::cname->new($mykey, $FLOAT, $data, 1, $native);
ok( test_float($record, $v[0]), "Negative float (native order)" );

#########################
$result = $record->get($native);
is( $result, $$data, "... as binary data" );

#########################
@v = (70.1317386);
$data = pack_float($v[0], 1);
$record = $::cname->new($mykey, $FLOAT, $data, 1, $not_native);
ok( test_float($record, $v[0]), "Positive float (reversed order)" );

#########################
$result = $record->get($not_native);
is( $result, $$data, "... as binary data" );

#########################
@v = (-75.555174);
$data = pack_float($v[0], 1);
$record = $::cname->new($mykey, $FLOAT, $data, 1, $not_native);
ok( test_float($record, $v[0]), "Negative float (reversed order)" );

#########################
$result = $record->get($not_native);
is( $result, $$data, "... as binary data" );

#########################
@v = ( -18945.63, 16.354, -0.000001345, 1E+4 );
$data = join '', map { ${pack_float($_)} } @v;
$record = $::cname->new($mykey, $FLOAT, \ $data, scalar @v, $native);
ok( test_float($record, vsum(@v)), "rereading floats (native order)" );
ok( test_float($_, $record, $v[$_]), "... ".$messages[$_] ) for (0..$#v);

#########################
$result = $record->get($native);
is( $result, $data, "... as binary data" );

#########################
$data = join '', map { ${pack_float($_, 1)} } @v;
$record = $::cname->new($mykey, $FLOAT, \ $data, scalar @v, $not_native);
ok( test_float($record, vsum(@v)), "rereading floats (reversed order)" );
ok( test_float($_, $record, $v[$_]), "... ".$messages[$_] ) for (0..$#v);

#########################
$result = $record->get($not_native);
is( $result, $data, "... as binary data" );

#########################
$data = join '', map { ${pack_float($_)} } @v;
$record = $::cname->new($mykey, $FLOAT, \ $data, scalar @v, $native);
$data = join '', map { ${pack_float($_, 1)} } @v;
$result = $record->get($not_native);
is( $result, $data, "Exchanging endianness" );

#########################
@w = ( '+1', '-1', '2**32', '2', '0.5', '2**(-126)',
       '(2-2**(-23))*2**127', '-2**(-127)', '-2**(-149)' );
@v = map { eval } @w;
$data = join '', map { ${pack_float($_, 1)} } @v;
$record = $::cname->new($mykey, $FLOAT, \ $data, scalar @v, $not_native);
ok( test_float($_, $record, $v[$_]), "(float) accepting $w[$_]" ) for (0..$#v);

#########################
$result = $record->get($not_native);
is( $result, $data, "(float) all tested as binary data" );

#########################
$data = join '', pack 'C*', map { hex } '7FC000007F800000FF800000' =~ /../g;
@w = ('nan', 'inf', '-inf');
$record = $::cname->new($mykey, $FLOAT, \$data, scalar @w, $BIG_ENDIAN);
is( $record->get_value($_), $w[$_], "(float) ".$w[$_]." OK" ) for (0..$#w);

#########################
$result = $record->get($BIG_ENDIAN);
is( $result, $data, "(float) ... also as binary data" );

#########################
@v = (17.38560104370137);
$data = pack_double($v[0]);
$record = $::cname->new($mykey, $DOUBLE, $data, 1, $native);
ok( test_double($record, $v[0]), "Positive double (native order)" );

#########################
$result = $record->get($native);
is( $result, $$data, "... as binary data" );

#########################
@v = (-55.17385601043755);
$data = pack_double($v[0]);
$record = $::cname->new($mykey, $DOUBLE, $data, 1, $native);
ok( test_double($record, $v[0]), "Negative double (native order)" );

#########################
$result = $record->get($native);
is( $result, $$data, "... as binary data" );

#########################
@v = (70.13173856010437013);
$data = pack_double($v[0], 1);
$record = $::cname->new($mykey, $DOUBLE, $data, 1, $not_native);
ok( test_double($record, $v[0]), "Positive double (reversed order)" );

#########################
$result = $record->get($not_native);
is( $result, $$data, "... as binary data" );

#########################
@v = (-75.55517385601043755);
$data = pack_double($v[0], 1);
$record = $::cname->new($mykey, $DOUBLE, $data, 1, $not_native);
ok( test_double($record, $v[0]), "Negative double (reversed order)" );

#########################
$result = $record->get($not_native);
is( $result, $$data, "... as binary data" );

#########################
@v = ( -189456325.134323, 16.3542345235432,
       -0.0000013452345234534, 1.5435363456356E+4 );
$data = join '', map { ${pack_double($_)} } @v;
$record = $::cname->new($mykey, $DOUBLE, \ $data, scalar @v, $native);
ok( test_double($record, vsum(@v)), "rereading doubles (native order)" );
ok( test_double($_, $record, $v[$_]), "... ".$messages[$_] ) for (0..$#v);

#########################
$result = $record->get($native);
is( $result, $data, "... as binary data" );

#########################
$data = join '', map { ${pack_double($_, 1)} } @v;
$record = $::cname->new($mykey, $DOUBLE, \ $data, scalar @v, $not_native);
ok( test_double($record, vsum(@v)), "rereading doubles (reversed order)" );
ok( test_double($_, $record, $v[$_]), "... ".$messages[$_] ) for (0..$#v);

#########################
$result = $record->get($not_native);
is( $result, $data, "... as binary data" );

#########################
$data = join '', map { ${pack_double($_)} } @v;
$record = $::cname->new($mykey, $DOUBLE, \ $data, scalar @v, $native);
$data = join '', map { ${pack_double($_, 1)} } @v;
$result = $record->get($not_native);
is( $result, $data, "Exchanging endianness" );

#########################
@w = ( '+1', '-1', '2**32', '2**48', '2', '0.5', '2**(-1022)',
       '(2-2**(-52))*2**1023', '-2**(-1023)', '-2**(-1074)' );
@v = map { eval } @w;
$data = join '', map { ${pack_double($_, 1)} } @v;
$record = $::cname->new($mykey, $DOUBLE, \ $data, scalar @v, $not_native);
ok( test_double($_,$record, $v[$_]),"(double) accepting $w[$_]" ) for (0..$#v);

#########################
$result = $record->get($not_native);
is( $result, $data, "(double) all tested as binary data" );

#########################
my $zz = '0' x 12;
$data = join '', pack 'C*', map { hex } "7FF8${zz}7FF0${zz}FFF0${zz}" =~ /../g;
@w = ('nan', 'inf', '-inf');
$record = $::cname->new($mykey, $DOUBLE, \$data, scalar @w, $BIG_ENDIAN);
is( $record->get_value($_), $w[$_], "(double) ".$w[$_]." OK" ) for (0..$#w);

#########################
$result = $record->get($BIG_ENDIAN);
is( $result, $data, "(double) ... also as binary data" );

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