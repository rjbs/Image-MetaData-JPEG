###########################################################
# A Perl package for showing/modifying JPEG (meta)data.   #
# Copyright (C) 2004 Stefano Bettelli                     #
# See the COPYING and LICENSE files for license terms.    #
###########################################################
#use 5.008;
package Image::MetaData::JPEG;
use Image::MetaData::JPEG::Tables;
use Image::MetaData::JPEG::Segment;
no  integer;
use strict;
use warnings;

our $VERSION = '0.10';

###########################################################
# Load other parts for this package. In order to avoid    #
# that this file becomes too large, only general interest #
# methods are written here.                               #
###########################################################
BEGIN {
    require "Image/MetaData/JPEG/JPEG_various.pl";
    require "Image/MetaData/JPEG/JPEG_comments.pl";
    require "Image/MetaData/JPEG/JPEG_exif.pl";
    require "Image/MetaData/JPEG/JPEG_app13.pl";
}

###########################################################
# Constructor for a JPEG file structure object, accepting #
# a "JPEG stream". It parses the file stream and stores   #
# its sections internally. An optional parameter can ex-  #
# clude parsing and even storing for some segments. The   #
# stream can be specified in two ways:                    #
# - [a scalar] interpreted as a file name to be opened;   #
# - [a scalar reference] interpreted as a pointer to an   #
#   in-memory buffer containing a JPEG stream;            #
# ------------------------------------------------------- #
# There is now a second argument, $regex. This string is  #
# matched against segment names, and only those segments  #
# with a positive match are parsed. This allows for some  #
# speed-up if you just need partial information. For      #
# instance, if you just want to manipulate the comments,  #
# you could use $regex equal to "COM". If $regex is unde- #
# fined, all segments are matched.                        #
# ------------------------------------------------------- #
# There is now a third optional argument, $options. If it #
# matches the string "FASTREADONLY", only those segments  #
# matching $regex are actually stored; also, everything   #
# which is found after a Start Of Scan is completely      #
# neglected. This allows for very large speed-ups, but,   #
# obviously, you cannot rebuild the file afterwards, so   #
# this is only for getting information fast (e.g., when   #
# doing a directory scan).                                #
# ------------------------------------------------------- #
# If an unrecoverable error occurs during the execution   #
# of the constructor, the undefined value is returned     #
# instead of the object reference, and a meaningful error #
# message is set up (read it with Error()).               #
###########################################################
sub new {
    my ($pkg, $file_input, $regex, $options) = @_;
    my $this = bless {
	filename      => undef, # private
	handle        => undef, # private
	read_only     => undef, # private
	segments      => [],
    }, $pkg;
    # remember to unset the ctor error message 
    $pkg->SetError(undef);
    # set the read-only flag if $options matches FASTREADONLY
    $this->{read_only} = $options =~ m/FASTREADONLY/ if $options;
    # execute the following subroutines in an eval block so that
    # errors can be treated without shutting down the caller.
    my $status = eval { $this->open_input($file_input); 
			$this->parse_segments($regex);     };
    # close the file handle, if open
    close_input();
    # If an error was found (and it triggered a die call)
    # we must set the appropriate error variable here
    $pkg->SetError($@) unless $status;
    # return the object reference (undef if an error occurred)
    return $this->Error() ? undef : $this;
}

###########################################################
# This block declares a private variable containing a     #
# meaningful error message for problems during the class  #
# constructor. The two following methods allow reading    #
# and setting the value of this variable.                 #
###########################################################
{ my $ctor_error_message = undef;
  sub Error    { return $ctor_error_message || undef; }
  sub SetError { $ctor_error_message = $_[1]; }
}

###########################################################
# This method writes the data area of each segment in the #
# current object to a disk file. If the filename is undef,#
# it defaults to the file originally used to create this  #
# JPEG structure object. This method returns "true" (1)   #
# if it works, "false" (undef) otherwise. This call fails #
# if the "read_only" member is set.                       #
# ------------------------------------------------------- #
# Remember that if you make changes to any segment, you   #
# should call update() for that particular segment before #
# calling this method, otherwise the changes remain confi-#
# ned to the internal structures of the segment (update() #
# dumps them into the data area). Note that "high level"  #
# methods, like those in the JPEG_<segment name>.pl files,#
# are supposed to call update() on their own.             #
###########################################################
sub save {
    my ($this, $filename) = @_;
    # fail immediately if "read_only" is set
    return undef if $this->{read_only};
    # if $filename is undefined, it defaults to the original name
    $filename = $this->{filename} unless defined $filename;
    # Open an IO handler for output on a file named $filename.
    # Use an indirect handler, which is closed authomatically
    # when it goes out of scope (so, no need to call close()).
    # If open fails, it return false and sets the special
    # variable $! to reflect the system error.
    open(my $out, ">", $filename) || return undef;
    # For each segment in the segment list, write the content of
    # the data area (including the preamble when needed) to the
    # disk file. Save the results of each output for later testing.
    my $segments = $this->{segments};
    my @results = map { $_->output_segment_data($out) } @$segments;
    # return undef if any print failed, true otherwise
    return (scalar grep { ! $_ } @results) ? undef : 1;
}

###########################################################
# This method takes care to open a file handle pointing   #
# to the JPEG object specified by $file_input. If the     #
# "file name" is a scalar reference instead, it is saved  #
# in the "handle" member (and it must be treated accor-   #
# dingly in the following). Nothing is actually read now; #
# if opening fails, the routine dies with a message.      #
###########################################################
sub open_input {
    my ($this, $file_input) = @_;
    # protect against undefined values
    die "Undefined input" unless defined $file_input;
    # scalar references: save the reference in $this->{handle}
    # and save a self-explicatory string as file name
    if (ref $file_input) {
	$this->{handle}   = $file_input;
	$this->{filename} = "[in-memory JPEG stream]"; }
    # real file: we need to open the file and complain if this is
    # not possible (legacy systems might need an explicity binary
    # open); then, the file name of the original file is saved.
    else {
	open($this->{handle}, "<", $file_input) ||
	    die "Open error on $file_input: $!";
	binmode($this->{handle});
	$this->{filename} = $file_input; }
}

###########################################################
# This method is the counterpart of "open". Actually, it  #
# does something only for real files (because in-memory   #
# scalars do not need being closed ....).                 #
###########################################################
sub close_input {
    my ($this) = @_;
    return if ref $this->{handle} ne 'GLOB';
    close $this->{handle}
    if ref $this->{handle} && defined fileno $this->{handle};
}

###########################################################
# This method returns a portion of the input file (speci- #
# fied by $offset and $length). It is necessary to mask   #
# how data reading is actually implemented. As usual, it  #
# dies on errors (but this is trapped in the constructor).#
# This method returns a scalar reference; if $offset is   #
# just "LENGTH", the input length is returned instead.    #
# A length <= 0 is ignored (ref to empty string).         #
###########################################################
sub get_data {
    my ($this, $offset, $length) = @_;
    # a shorter name for the file handle
    my $handle = $this->{handle};
    # understand if this is a file or a scalar reference
    my $is_file = ref $handle eq "GLOB";
    # if the first argument is just the string "LENGTH",
    # return the input length instead
    return ($is_file ? -s $handle : length $$handle) if $offset eq "LENGTH";
    # this is the buffer to be returned at the end
    my $data = "";
    # if length is <= zero return a reference to an empty string
    return \ $data if $length <= 0;
    # if we are dealing with a real file, we need to seek to the
    # requested position, then read the appropriate amount of data
    # (and throw an error if reading failed).
    if ($is_file) {
	seek($handle, $offset, 0) ||
	    die "Error while seeking in  $this->{filename}";
	my $read = read $handle, $data, $length;
	die "Read error in  $this->{filename}"
	    if ! defined $read || $read < $length; }
    # otherwise, we are dealing with a scalar reference, and
    # everything is much simpler (this can't fail, right?)
    else { $data = substr $$handle, $offset, $length; }
    # return a reference to read data
    return \ $data;
}

###########################################################
# This method searches for segments in the input JPEG.    #
# When a segment is found, the corresponding data area is #
# read and used to create a segment object (the ctor of   #
# this object takes care to decode the relevant data).    #
# The object is then inserted into the "segments" hash,   #
# with a code-related key. Raw (compressed) image data    #
# are stored in "fake" segments, just for simplicity.     #
# ------------------------------------------------------- #
# There is now an argument, set equal to the second argu- #
# ment of the constructor. If it is defined, only match-  #
# ing segments are parsed. Also, if read_only is set,     #
# only "interesting" segments are saved and everything    #
# after the Start Of Scan is neglected.                   # 
#=========================================================#
# Structure of a generic segment:                         #
# 2 bytes  segment marker (the first byte is always 0xff) #
# 2 bytes  segment_length (it doesn't include the marker) #
#               .... data (segment_length - 2 bytes)      #
#=========================================================#
# The segment length (2 bytes) has a "Motorola" (big end- #
# ian) endianness (byte alignement), that is it starts    #
# with the most significant digit. Note that the segment  #
# length marker counts its own length (i.e., after it     #
# there are only segment_length-2 bytes).                 #
#=========================================================#
# Some segments do not have data after them (not even the #
# length field, they are pure markers): SOI, EOI and the  #
# RST? restart segments. Scans (started by a SOS segment) #
# are followed by compressed data, with possibly inter-   #
# leaved RST segments: raw data must be searched with a   #
# dedicated routine because they are not envelopped.      #
#=========================================================#
# Ref: "Digital compression and coding of continuous-tone #
#       still images: requirements and guidelines",       #
#      CCITT, 09/1992, sec. B.1.1.4, pag. 33.             #
###########################################################
sub parse_segments {
    my ($this, $regex) = @_;
    # prepare another hash to reverse the JPEG markers lookup
    my %JPEG_MARKER_BY_CODE = reverse %JPEG_MARKER;
    # prepare a reference pointing to the "segments" list
    my $segments = $this->{segments};
    # an offset in the input object, and a variable with its size
    my $offset = 0;
    my $isize  = $this->get_data("LENGTH");
    # loop on input data and find all of its segment
    while ($offset < $isize) {
	# search for the next JPEG marker, giving the segment type
	(my $marker, $offset) = $this->get_next_marker($offset);
	# Die on unknown markers
	die sprintf "Unknown marker found: 0x%02x (offset $offset)", $marker
	    unless exists $JPEG_MARKER_BY_CODE{$marker};
	# save the current offset (beginning of data)
	my $start = $offset;
	# calculate the name of the marker
	my $name = $JPEG_MARKER_BY_CODE{$marker};
	# determine the parse flag
	my $flag = ($regex && $name !~ /$regex/) ? "NOPARSE" : undef;
	# SOI, EOI and ReSTart are dataless segments
	my $length = 0; goto DECODE_LENGTH_END if $name =~ /^RST|EOI|SOI/;
      DECODE_LENGTH_START:
	# decode the length of this application block (2 bytes).
	# This is always in big endian ("Motorola") style, that
	# is the first byte is the most significant one.
	$length = unpack "n", ${$this->get_data($offset, 2)};
	# the segment length includes the two aforementioned
	# bytes, so the length must be at least two
	die "JPEG segment too small" if $length < 2;
      DECODE_LENGTH_END:
	# pass the data to a segment object and store it, unless
	# the "read_only" member is set and $flag is "NOPARSE".
	# (don't pass $flag to dataless segments, it is just silly).
	push @$segments, new Image::MetaData::JPEG::Segment
	    ($name, $this->get_data($start + 2, $length - 2),
	     $length ? $flag : undef) unless $this->{read_only} && $flag;
	# update offset
	$offset += $length;
	# When you find a SOS marker or a RST marker there is a special
	# treatement; if "read_only" is set, we neglect the rest of the
	# input. Otherwise, we need a special routine
	if ($name =~ /SOS|^RST/) {
	    $offset = $isize, next if $this->{read_only};
	    $offset = $this->parse_ecs($offset); }
      DECODE_PAST_EOI_GARBAGE:
	# Try to intercept underground data stored after the EOI segment;
	# I have found images which store multiple reduced versions of
	# itself after the EOI segment, as well as undocumented binary
	# and ascii data. Save them in a pseudo-segment, so that they
	# can be restored (take "read_only" into account).
	if ($name eq "EOI" && $offset < $isize) {
	    my $len = $isize - $offset;
	    push @$segments, new Image::MetaData::JPEG::Segment
		("Post-EOI data", $this->get_data($offset, $len))
		unless $this->{read_only};
	    $offset += $len;
	}
    }
}

###########################################################
# This method searches for the next JPEG marker in the    #
# stream being parsed. A marker is always assigned a two  #
# byte code: an 0xff byte followed by a byte which is not #
# 0x00 nor 0xff. Any marker may optionally be preceeded   #
# by any number of fill bytes (padding of the previous    #
# segment, I suppose), set to 0xff. Most markers start    #
# marker segments containing a related group of parame-   #
# ters; some markers stand alone. The return value is a   #
# list containing the numeric value of the second marker  #
# byte and an offset pointing just after it.              #
#=========================================================#
# Ref: "Digital compression and coding of continuous-tone #
#       still images: requirements and guidelines",       #
#      CCITT, 09/1992, sec. B.1.1.2, pag. 31.             #
#=========================================================#
sub get_next_marker {
    my ($this, $offset) = @_;
    my $punctuation = chr $JPEG_PUNCTUATION;
    # it is assumed that we are at the beginning of
    # a new segment, so the next byte must be 0xff.
    my $marker_byte = ${$this->get_data($offset++, 1)};
    die sprintf("Unknown punctuation (0x%02x) at offset 0x%x",
		ord($marker_byte), $offset) if $marker_byte ne $punctuation;
    # next byte can be either the marker type or a padding
    # byte equal to 0xff (skip it if it's a padding byte)
    $marker_byte = ${$this->get_data($offset++, 1)}
    while $marker_byte eq $punctuation;
    # return the marker we have found (no check on its validity),
    # as well as the offset to the next byte in the JPEG stream
    return (ord($marker_byte), $offset);
}

###########################################################
# This method reads in a compressed (entropy coded) data  #
# segment (ECS) and saves it as a "pseudo" segment. The   #
# argument is the current offset in the in-memory JPEG    #
# stream, the result is the updated offset. These pseudo  #
# segments can be found after a Start-Of-Scan segment,    #
# and, if restart is enabled, they can be interleaved     #
# with restart segments (RST). Indeed, an ECS is not a    #
# real segment, because it does not start with a marker   #
# and its length is not known a priori. However, it is    #
# easy to detect its end since a regular marker cannot    #
# appear inside it. In practice, data in an ECS are coded #
# in such a way that a 0xff byte can only be followed by  #
# 0x00 (invalid marker) or 0xff (padding).                #
#=========================================================#
# WARNING: when restart is enabled, usually the file con- #
# tains a lot of ECS and RST. In order not to be too slow #
# we keep the restart marker embedded in row data here.   #
#=========================================================#
# Ref: "Digital compression and coding of continuous-tone #
#       still images: requirements and guidelines",       #
#      CCITT, 09/1992, sec. B.1.1.5, pag. 33.             #
###########################################################
sub parse_ecs {
    my ($this, $offset) = @_;
    # A title for a raw data block ("ECS" must be there)
    my $ecs_name = "ECS (Raw data)";
    # transform the JPEG punctuation value into a string
    my $punctuation = chr $JPEG_PUNCTUATION;
    # create a string containing the character which can follow a
    # punctuations mark without causing the ECS to be considered
    # terminated. This string must contain at least the null byte and
    # the punctuation mark itself. But, for efficiency reasons, we are
    # going to include also the restart markers here.
    my $skipstring = $punctuation . chr 0x00;
    $skipstring .= chr $_ for ($JPEG_MARKER{RST0} .. $JPEG_MARKER{RST7});
    # read in everything till the end of the input
    my $length = $this->get_data("LENGTH");
    my $buffer = $this->get_data($offset, $length - $offset);
    # find the next 0xff byte not followed by a character of $skipstring
    # from $offset on. It is better to use pos() instead of taking a
    # substring of $$buffer, because this copy takes a lot of space. In
    # order to honour the position set by pos(), it is necessary to use
    # "g" in scalar context. My benchmarks say this is almost as fast as C.
    pos($$buffer) = 0; scalar $$buffer =~ /$punctuation[^$skipstring]/g;
    # trim the $buffer at the byte before the punctuation mark; the
    # position of the last match can be accessed through pos()
    die "ECS parsing failed" unless pos($$buffer);
    substr($$buffer, pos($$buffer) - 2) = "";
    # push a pseudo segment among the regular ones
    my $segments = $this->{segments};
    push @$segments, new Image::MetaData::JPEG::Segment($ecs_name, $buffer);
    # return the updated offset
    return $offset + length $$buffer;
}

###########################################################
# This method creates a list containing the references    #
# (or their indexes in the segment references list, if    #
# the second argument is "INDEXES") of those segments     #
# whose name matches a given regular expression.          #
# The output can be invalid after adding/removing any     #
# segment. If $regex is undefined, returns all indexes.   #
###########################################################
sub get_segments {
    my ($this, $regex, $do_indexes) = @_;
    # fix the regular expression to "" if undefined
    $regex = "" unless defined $regex;
    # get the list of segment references in this file
    my $segments = $this->{segments};
    # return the list of matched segments
    return (defined $do_indexes && $do_indexes eq "INDEXES") ?
	grep { $$segments[$_]->{name} =~ /$regex/ } 0..$#$segments :
	grep { $_->{name} =~ /$regex/ } @$segments;
}

###########################################################
# This method finds a position for a new application or   #
# comment segment to be placed in the file. If a DHP seg- #
# ment is present, it returns its position; otherwise, it #
# tries the same with SOF segments; otherwise, it selects #
# the position immediately after the last application or  #
# comment segment. If even this fails, it returns the     #
# position immediately after the SOI segment (i.e., 1).   #
###########################################################
sub find_new_app_segment_position {
    my ($this) = @_;
    # just in order to avoid a warning for half-read files
    # with an incomplete set of segments, let us make sure
    # that no position is past the segment array end
    my $safe = sub { my $l = $this->get_segments()-1; ($l<$_[0])?$l:$_[0] };
    # get the indexes of the DHP segments; if this list
    # is not void, return its position
    return &$safe($_) for $this->get_segments("DHP", "INDEXES");
    # same thing with SOF segments
    return &$safe($_) for $this->get_segments("SOF", "INDEXES");
    # otherwise, get the indexes of all application and comment
    # segments, and return the position after the last one.
    return &$safe(1+$_) for reverse $this->get_segments("APP|COM", "INDEXES");
    # if even this fails, try after start-of-image (just in order
    # to avoid a warning for half-read files with not even two
    # segments (they cannot be saved), return 0 if necessary)
    return &$safe(1);
}

# successful package load
1;
