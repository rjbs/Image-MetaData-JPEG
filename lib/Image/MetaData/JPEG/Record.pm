###########################################################
# A Perl package for showing/modifying JPEG (meta)data.   #
# Copyright (C) 2004 Stefano Bettelli                     #
# See the COPYING and LICENSE files for license terms.    #
###########################################################
package Image::MetaData::JPEG::Record;
use Image::MetaData::JPEG::Tables;
no  integer;
use strict;
use warnings;

###########################################################
# Various lists for JPEG record lengths, categories and   #
# signs; see the constructor in this package and the list #
# named @JPEG_RECORD_TYPE_NAMES for further details.      #
# ======================================================= #
# I give up trying to calculate the length of a reference.#
# This is probably allocation dependent ... I use 0 here, #
# which means "no expectation" (see the Record ctor).     #
###########################################################
my @JPEG_RECORD_TYPE_LENGTH   =   (1,1,1,2,4,8,1,1,2,4,8,4,8,0);
my @JPEG_RECORD_TYPE_CATEGORY = qw(I I S I I R I S I I R F F p);
my @JPEG_RECORD_TYPE_SIGN     = qw(N N N N N N Y N Y Y Y N N N);
 
###########################################################
# Constructor for a generic key - value pair for storing  #
# properties to be found in JPEG segments. The key is     #
# either a numeric value (whose exact meaning depends on  #
# the segment type, and can be found by means of lookup   #
# tables), or a descriptive string. The value is to be    #
# found in the scalar pointed to by the data reference,   #
# and it comes togheter with a value type; the meaning    #
# of the value type is taken by the APP1 type table, but  #
# this standard can be used also for the other segments   #
# (but it is not stored in the file on disk, exception    #
# made for some APP segments). The enddianness must be    #
# given for numeric properties with more than 1 byte.     #
#=========================================================#
# The "value" can indeed be a sequence of values. This    #
# field is therefore a list, which, most of the time,     #
# has a single element. Although the type lenght for      #
# non-numeric records is 1, these records are always      #
# stored internally as a single scalar (thus, one token). #
#=========================================================#
# Types are as follows:                                   #
#  0  NIBBLES    two 4-bit unsigned integers (private)    #
#  1  BYTE       An 8-bit unsigned integer                #
#  2  ASCII      An 8-bit byte for 7-bit ASCII strings    #
#  3  SHORT      A 16-bit unsigned integer                #
#  4  LONG       A 32-bit unsigned integer                #
#  5  RATIONAL   Two LONGs (numerator and denominator)    #
#  6  SBYTE      An 8-bit signed integer                  #
#  7  UNDEFINED  A 8-bit byte which can take any value    #
#  8  SSHORT     A 16-bit signed integer                  #
#  9  SLONG      A 32-bit signed integer (2's complem.)   #
# 10  SRATIONAL  Two SLONGs (numerator and denominator)   #
# 11  FLOAT      A 32-bit float (a single float)          #
# 12  DOUBLE     A 64-bit float (a double float)          #
# 13  REFERENCE  A Perl list reference (internal)         #
#=========================================================#
# Added a new field, "extra", which can be used to store  #
# additional information one does not know where to put.  #
# (The need originated from APP13 record descriptions).   #
###########################################################
sub new {
    my ($pkg, $akey, $atype, $dataref, $count, $endian) = @_;
    my $this  = bless {
	key     => $akey,
	type    => $atype,
	values  => [],
	extra   => undef,
    }, $pkg;
    # return immediately with undef if $dataref is not a reference
    return undef unless ref $dataref;
    # use big endian as default endianness
    $endian = $BIG_ENDIAN unless defined $endian;
    # get the actual length of the $$dataref scalar
    my $current  = length($$dataref);
    # estimate the right length of $data for numeric types
    # (remember that some types can return "no expectation", i.e. 0).
    my $expected = $pkg->get_size($atype, $count);
    # Throw an error if the supplied memory area is incorrectly
    # sized (the test never fails for string-like records, and is
    # not performed when $expected is 0 [i.e., no expectation])
    die "Incorrect size for $pkg (expected $expected, found $current)"
	if ($current != $expected) && $expected;
    # get a reference to the internal value list
    my $tokens = $this->{values};
    # read the type length (used only for integers and rationals)
    my $tlength = $JPEG_RECORD_TYPE_LENGTH[$this->{type}];
    # References, strings and undefined data can be immediately saved
    # (1 token). All integer types can be treated toghether, and
    # rationals can be treated as integer (halving the type length!).
    my $cat = $this->get_category();
    push @$tokens, $$dataref                                   if $cat =~/S|p/;
    push @$tokens, $this->decode($tlength  ,$dataref, $endian) if $cat eq 'I';
    push @$tokens, $this->decode($tlength/2,$dataref, $endian) if $cat eq 'R';
    die "Floating point not implemented. FIX ME!"              if $cat eq 'F';
    # die if the token list is empty (debug)
    die "Empty token list!" if @$tokens == 0;
    # return the blessed reference
    return $this;
}

###########################################################
# Syntactic sugar for a type test. The two arguments are  #
# $this and the numeric type.                             #
###########################################################
sub is { return $_[1] == $_[0]{type}; }

###########################################################
# This method returns a character describing the category #
# which the type of the current record belongs to.        #
# There are currently only five categories:               #
# references  : 'p' -> Perl references (internal)         #
# integer     : 'I' -> NIBBLES, (S)BYTE, (S)SHORT,(S)LONG #
# string-like : 'S' -> ASCII, UNDEF                       #
# fractional  : 'R' -> RATIONAL, SRATIONAL                #
# float.-point: 'F' -> FLOAT, DOUBLE                      #
# The method is sufficiently clear to use $_[0] instead   #
# of $this (is it a speedup ?)                            #
###########################################################
sub get_category { return $JPEG_RECORD_TYPE_CATEGORY[$_[0]{type}]; }

###########################################################
# This method returns 'Y' or 'N' depending on the record  #
# type being a signed integer or not (i.e. beign SBYTE,   #
# SSHORT, SLONG or SRATIONAL). The method is sufficiently #
# clear to use $_[0] instead of $this (is it a speedup ?) #
###########################################################
sub is_signed { return $JPEG_RECORD_TYPE_SIGN[$_[0]{type}]; }

###########################################################
# This method calculates a record memory footprint; it    #
# needs the record type and the record count. This method #
# is class static (it can be called without an underlying #
# object), so it cannot use $this. $count defaults to 1.  #
# Remember that a type length of zero means that size     #
# should not be tested (this comes from TYPE_LENGHT = 0). #
###########################################################
sub get_size {
    my ($self, $type, $count) = @_;
    # if count is unspecified, set it to 1
    $count = 1 unless defined $count;
    # die if the type is unknown
    die "Unknown record type ($type)"
	if $type < 0 || $type > $#JPEG_RECORD_TYPE_LENGTH;
    # return the type length times $count
    return $JPEG_RECORD_TYPE_LENGTH[$type] * $count;
}

###########################################################
# This method returns a particular value in the value     #
# list, its index being the only argument. If the index   #
# is undefined (not supplied), the sum of all values is   #
# returned. The index is checked for out-of-bound errors. #
#=========================================================#
# For string-like records, "sum"->"concatenation".        #
###########################################################
sub get_value {
    my ($this, $index) = @_;
    my $values = $this->{values};
    # access a single value if an index is defined or
    # there is only one value (follow to sum otherwise)
    goto VALUE_INDEX if defined $index || @$values == 1;
  VALUE_SUM:
    return ($this->get_category() eq 'S') ?
	# perform concatenation for string-like values
	join "", @$values :
	# perform addition for numeric values
	eval (join "+", @$values);
  VALUE_INDEX:
    $index = 0 unless defined $index;
    my $last_index = $#$values;
    die "Out-of-bound record index ($index > $last_index)" 
	if $index > $last_index;
    return $$values[$index];
}

###########################################################
# This method sets a particular value in the value list.  #
# If the index is undefined (not supplied), the first     #
# (0th) value is set. The index is check for out-of-bound #
# errors. This method is dangerous: call only internally. #
###########################################################
sub set_value {
    my ($this, $new_value, $index) = @_;
    my $values = $this->{values};
    # set the first value if index is defined
    $index = 0 unless defined $index;
    # check out-of-bound condition
    my $last_index = $#$values;
    die "Out-of-bound record index ($index > $last_index)" 
	if $index > $last_index;
    # set the value
    $$values[$index] = $new_value;
}

###########################################################
# These private functions take signed/unsigned integers   #
# and return their unsigned/signed version (the type      #
# length in bytes must also be specified. $_[0] is the    #
# original value, $_[1] is the type length. $msb[$n] is   #
# an unsigned integer with the 8*$n-th bit turned up.     #
# There is also a function for converting binary data as  #
# a string into a big-endian number (iteratively) and a   #
# function for interchanging bytes with nibble pairs.     #
###########################################################
{ my @msb = map { 2**(8*$_ - 1) } 0..20;
  sub to_signed   { ($_[0] >= $msb[$_[1]]) ? ($_[0] - 2*$msb[$_[1]]) : $_[0] }
  sub to_unsigned { ($_[0] < 0) ? ($_[0] + 2*$msb[$_[1]]) : $_[0] }
  sub to_number   { my $v=0; for (unpack "C*", $_[0]) { ($v<<=8) += $_; } $v }
  sub to_nibbles  { map { chr(vec($_[0], $_, 4)) } reverse (0..1) }
  sub to_byte     { my $b="x"; vec($b,$_^1,4) = ord($_[$_]) for (0..1) ; $b }
}

###########################################################
# This method decodes a sequence of 8n-bit integers, and  #
# correctly takes into account signedness and endianness. #
# The data size must be validated in advance: in this     #
# routine it must be a multiple of the type size ($n).    #
#=========================================================#
# NIBBLES are treated apart. A "nibble record" is indeed  #
# a pair of 4-bit values, so the type length is 1, but    #
# each element must enter two values into @tokens. They   #
# are always big-endian and unsigned.                     #
#=========================================================#
# Don't use shift operators, which are a bit too tricky.. #
###########################################################
sub decode {
    my ($this, $n, $dataref, $endian) = @_;
    # safety check on endianness
    die "Unknown endianness" unless $endian =~ /$BIG_ENDIAN|$LITTLE_ENDIAN/o;
    # prepare the list of raw tokens
    my @tokens = unpack "a$n" x (length($$dataref)/$n), $$dataref;
    # correct the tokens for endianness if necessary
    @tokens = map { scalar reverse } @tokens if $endian eq $LITTLE_ENDIAN;
    # rework the raw token list for nibbles.
    @tokens = map { to_nibbles($_) } @tokens if $this->is($NIBBLES);
    # convert to 1-byte digits and concatenate them (assuming big-endian)
    @tokens = map { to_number($_) } @tokens;
    # correction for signedness.
    @tokens = map { to_signed($_, $n) } @tokens if $this->is_signed() eq 'Y';
    # return the token list
    return @tokens;
}

###########################################################
# This method encodes the content of $this->{values} into #
# a sequence of 8n-bit integers, correctly taking into    #
# account signedness and endianness. The return value is  #
# a reference to the encoded scalar. See decode() for     #
# further details (however here more fields can be read). #
###########################################################
sub encode {
    my ($this, $n, $endian) = @_;
    # safety check on endianness
    die "Unknown endianness" if ! $endian =~ /$BIG_ENDIAN|$LITTLE_ENDIAN/o;
    # copy the value list (the original should not be touched)
    my @tokens = @{$this->{values}};
    # correction for signedness; $msb is an $n-byte integer
    # with the most significant bit turned up.
    @tokens = map { to_unsigned($_, $n) } @tokens if $this->is_signed() eq 'Y';
    # convert the number into 1-byte digits (assuming big-endian)
    @tokens = map { my $enc = ""; vec($enc, 0, 8*$n) = $_; $enc } @tokens;
    # reconstruct the raw token list for nibbles.
    @tokens = map { to_byte($tokens[2*$_], $tokens[2*$_+1]) } 0..(@tokens)/2-1
	if $this->is($NIBBLES);
    # correct the tokens for endianness if necessary
    @tokens = map { scalar reverse } @tokens if $endian eq $LITTLE_ENDIAN;
    # reconstruct a string from the list of raw tokens
    my $data = pack "a$n" x (scalar @tokens), @tokens;
    # return a reference to the reconstructed string
    return \ $data;
}

###########################################################
# This method returns the content of the record: in list  #
# context it returns (key, type, count, data_reference).  #
# The reference points to a packed scalar, ready to be    #
# written to disk. In scalar context, it returns "data",  #
# i.e. the dereferentiated data_reference. This is tricky #
# (but handy for other routines). The endianness argument #
# defaults to $BIG_ENDIAN. See ctor for further details.  #
###########################################################
sub get {
    my ($this, $endian) = @_;
    # use big endian as default endianness
    $endian = $BIG_ENDIAN unless defined $endian;
    # get the record key, its type and a reference
    # to the internal value list
    my $key    = $this->{key};
    my $type   = $this->{type};
    my $tokens = $this->{values};
    # read the type length (only used for integers and rationals)
    my $tlength = $JPEG_RECORD_TYPE_LENGTH[$type];
    # References, strings and undefined data contain a single token
    # (to be taken a reference at). All integer types can be treated
    # toghether, and rationals can be treated as integer (halving the
    # type length!). Floating points still to be coded.
    my $cat = $this->get_category(); my $dataref = undef;
    $dataref = \ $$tokens[0]                      if $cat =~/S|p/;
    $dataref = $this->encode($tlength  , $endian) if $cat eq 'I';
    $dataref = $this->encode($tlength/2, $endian) if $cat eq 'R';
    die "Floating point not implemented. FIX ME!" if $cat eq 'F';
    # calculate the "count" (1 for references, strings, undefined)
    my $count = ($cat =~/S|p/) ? 1 : (length($$dataref) / $tlength);
    # return the result, depending on the context
    wantarray ? ($key, $type, $count, $dataref) : $$dataref;
}

###########################################################
# This method returns a string describing the content of  #
# the record. The argument is a reference to an array of  #
# names, which are to be used as successive keys in a     #
# general hash keeping translations of numeric tags.      #
# No argument is needed if the key is already non-numeric.#
###########################################################
sub get_description {
    my ($this, $names) = @_;
    my $maxlen = 25; my $string_reflen = 40;
    # assume that the key is a string (so, it is its own
    # description, and no numeric value is to be shown)
    my $descriptor = $this->{key};
    my $numerictag = undef;
    # however, if it is a number we need more work
    if ($descriptor =~ /^\d*$/) {
	# get the relevant hash for the description of this record
	my $section_hash = \%JPEG_RECORD_NAME;
	$section_hash = $$section_hash{$_} foreach (@$names);
	# fix the numeric tag
	$numerictag = $descriptor;
        # extract a description string; if there is no entry
	# in the hash for this key, replace the descriptor 
	# with a sort of error message.
	$descriptor = exists $$section_hash{$descriptor} ?
	    $$section_hash{$descriptor} : "?? Unknown record type ??";
    }
    # calculate an appropriate tabbing
    my $tabbing = " \t" x (scalar @$names);
    # prepare the description (don't make it exceed $maxlen characters)
    $descriptor = substr($descriptor, 0, $maxlen/2)
	. "..." . substr($descriptor, - $maxlen/2 + 3)
	if length($descriptor) > $maxlen;
    # initialise the string to be returned at the end
    my $description = sprintf "%s[%${maxlen}s]", $tabbing, $descriptor;
    # show also the numeric tag for this record (if present)
    $description .= defined $numerictag ?
	sprintf "<0x%04x>", $numerictag : "<......>";
    # show the tag type as a string
    $description .= sprintf " = [%9s] ", $JPEG_RECORD_TYPE_NAME[$this->{type}];
    # show the "extra" field if present
    $description .= "<$this->{extra}>" if defined $this->{extra};
    # prepare the list of objects to process; if we are dealing
    # with the undefined type, split the string into single bytes;
    my $tokens = $this->{values};
    $tokens = [ unpack "a1" x length($$tokens[0]), $$tokens[0] ] 
	if $this->is($UNDEF);
    # we want to write at most $max tokens in the value list
    my $max = 7; my $extra = $#$tokens - $max;
    my $token_limit = $extra > 0 ? $max : $#$tokens;
    # This routine reworks ASCII strings a bit before displaying them.
    # In particular it trims unreasonably long strings and replaces
    # non-printing characters with their hexadecimal representation. Note,
    # however, that "more characters" counts each control char as three.
    # Remember to copy the string to avoid side-effects!
    my $tt = sub { 
	(my $ss=$_[0])=~ s/([\000-\037\177-\377])/sprintf "\\%02x",ord($1)/ge;
	my $rr = length($ss) - $string_reflen;
	($rr <= 24) ? "\"$ss\"" : sprintf "\"%s\" (+ %5d more chars)",
	substr($ss,0,$string_reflen), $rr; };
    # integers, strings and floating points are written in sequence;
    # rationals must be written in pairs (use a flip-flop);
    # undefined values are written byte by byte.
    my $f = '/';
    foreach (@$tokens[0..$token_limit]) {
	# update the flip flop
	$f = $f eq ' ' ? '/' : ' ';
	# show something, depending on category and type
	my $category = $this->get_category();
	$description .= sprintf " --> %p", $_    if $category eq 'p';
	$description .= sprintf " %02x", ord($_) if $this->is($UNDEF);
	$description .= sprintf "%s", &$tt($_)   if $this->is($ASCII);
	$description .= sprintf " %d", $_        if $category eq 'I';
	$description .= sprintf " %f", $_        if $category eq 'F';
	$description .= sprintf "%s%d", $f,$_    if $category eq 'R';
    }
    # terminate the line; remember to put a warning note if there were
    # more than $max element to display, then return the description
    $description .= " ... ($extra more values)" if $extra > 0;
    $description .= "\n";
    # return the descriptive string
    return $description;
}

# successful package load
1;
