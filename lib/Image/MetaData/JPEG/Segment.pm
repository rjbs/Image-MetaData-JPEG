###########################################################
# A Perl package for showing/modifying JPEG (meta)data.   #
# Copyright (C) 2004 Stefano Bettelli                     #
# See the COPYING and LICENSE files for license terms.    #
###########################################################
package Image::MetaData::JPEG::Segment;
use Image::MetaData::JPEG::Tables;
use Image::MetaData::JPEG::Record;
no  integer;
use strict;
use warnings;

###########################################################
# Load other parts for this package. In order to avoid    #
# that this file becomes too large, only general interest #
# methods are written here.                               #
###########################################################
BEGIN {
    require "Image/MetaData/JPEG/Segment_parsers.pl"; # parser methods
    require "Image/MetaData/JPEG/Segment_dumpers.pl"; # dumper methods
}

###########################################################
# Constructor for a JPEG segment header. It accepts the   #
# segment type (a multicharacter string, not the marker), #
# a reference to a raw data buffer and a parse flag. The  #
# raw buffer is saved internally through its reference    #
# (no copy is done). If the parse flag does not match     #
# "NOPARSE", those segments which can be parsed have      #
# their key-value pairs extracted into the 'records' list #
# as JPEG::Record objects.                                #
#=========================================================#
# All segments start with four bytes with a common format:#
#                                                         #
#  2 bytes  segment marker (0xff..)                       #
#  2 bytes  length (including this value)                 #
#                                                         #
# The marker is a two byte value, whose first byte is al- #
# ways 0xff. The value of the second byte defines the     #
# segment type. It is assumed that the buffer which is    #
# passed to this constructor DOES NOT contain these four  #
# bytes; in fact, the segment type can be deduced by its  #
# symbolic name (first argument), and the buffer size can #
# be calculated with the length() function. This simpli-  #
# fies a lot of repetitive code, but it must be kept in   #
# mind when the file is written back to the filesystem.   #
#=========================================================#
# The private variable $this->{endianness} contains the   #
# current endianness, i.e. the endianness to be used for  #
# reading the next values while parsing the data area.    #
# Its significant is therefore only transient, and it is  #
# set to undef at the end of the constructor.             #
#=========================================================#
# The variable $this->{error} is normally "undef". If,    #
# however, an error occurred during the parsing stage in  #
# the constructor, this variable is set to an error mes-  #
# sage. The rationale is that a segment with errors can   #
# be inspected (partially, of course, because parsing did #
# not terminate correctly) but not modified (that is, the #
# update method, which overwrites the area pointed to by  #
# $this->{dataref}, must be inhibited): it can only be    #
# rewritten to disk as it is.                             #
###########################################################
sub new {
    my ($pkg, $name, $dataref, $flag) = @_;
    my $this = bless {
	name       => $name,
	dataref    => defined $dataref ? $dataref : \ "",
	records    => [],
	error      => undef,
	endianness => undef,
    }, $pkg;
    # parse the segment (pass the $flag)
    $this->parse($flag);
    # return a reference to the constructed object
    return $this;
}

###########################################################
# This method parses or reparses the current segment. It  #
# only dispatches the flow to specific subroutines based  #
# on the segment name. The error flag is reset to undef   #
# before parse_*, so that, at the end, it reflects only   #
# errors occurred during this parse session. If the $flag #
# argument is set to "NOPARSE", this method simulates an  #
# error and refuses to proceed further. The parsed data   #
# array "@records" is flushed when entering this routine. #
#=========================================================#
# Segment parsing is enclosed in an eval block, so that   #
# errors are not fatal (they work as trapped exceptions,  #
# and the die-string is converted into a message).        #
#=========================================================#
# See also the notes in the constructor about the private #
# var. $this->{endianness} and the use of $this->{error}. #
###########################################################
sub parse {
    my ($this, $flag) = @_;
    # reset the error flag and set endianness to big endian
    $this->{error}      = undef; 
    $this->{endianness} = $BIG_ENDIAN;
    # clear the data parsed so far
    $this->{records}    = [];
    # call the specific parse routines inside an eval block,
    # so that errors are not fatal...
    eval {
	# if $flag matches "NOPARSE", we don't need to parse
	# the segment. This can be done by generating an error
	die "Not parsed due to user request" if $flag && $flag =~ /NOPARSE/;
	# parse all informative tags
	$this->parse_com()   if $this->{name} eq 'COM';   # User comments
	$this->parse_app0()  if $this->{name} eq 'APP0';  # JFIF
	$this->parse_app1()  if $this->{name} eq 'APP1';  # Exif or XMP
	$this->parse_app2()  if $this->{name} eq 'APP2';  # FPXR or ICC_Prof
	$this->parse_app3()  if $this->{name} eq 'APP3';  # Additonal metadata
	$this->parse_unknown() if $this->{name} eq 'APP4';  # HPSC
	$this->parse_unknown() if $this->{name} =~ /APP(5|6|7|8|9|10|11|15)/;
	$this->parse_app12() if $this->{name} eq 'APP12'; # PreExif ascii meta
	$this->parse_app13() if $this->{name} eq 'APP13'; # IPTC and Photoshop
	$this->parse_app14() if $this->{name} eq 'APP14'; # Adobe tags
	# parse all JPEG image tags (SOI, EOI and RST* are trivial)
	$this->parse_dqt()   if $this->{name} eq 'DQT';
	$this->parse_dht()   if $this->{name} eq 'DHT';
	$this->parse_dac()   if $this->{name} eq 'DAC';
	$this->parse_sof()   if $this->{name} =~ /^SOF|DHP/;
	$this->parse_sos()   if $this->{name} eq 'SOS';
	$this->parse_dnl()   if $this->{name} eq 'DNL';
	$this->parse_dri()   if $this->{name} eq 'DRI';
	$this->parse_exp()   if $this->{name} eq 'EXP';
    };
    # parsing was ok if no error was catched by the eval.
    # Update the "error" member here to reflect this fact.
    $this->{error} = $@;
    # reset the default endianness to undef
    $this->{endianness} = undef;
}

###########################################################
# This method re-executes the parsing of a segment after  #
# changing the segment nature (well, its name). This is   #
# very handy if you have a JPEG file with a correct appli-#
# cation segment exception made for its name. I used it   #
# the first time for a file having an ICC_profile segment #
# (usually in APP2) stored as APP13. Note that the name   #
# of the segment is permanently changed, so, if the file  #
# is rewritten to disk, it will be "correct".             #
###########################################################
sub reparse_as {
    my ($this, $new_name) = @_;
    # change the nature of this segment by overwriting its name
    $this->{name} = $new_name;
    # re-execute the parsing
    $this->parse();
}

###########################################################
# This method is the entry point for dumping the data     #
# structures stored in the records into the private data  #
# area. This method needs to be called before rewriting a #
# file to the disk, if any record was changed/added/elimi-#
# nated. The routine dispatches to more specific methods. #
# ------------------------------------------------------- #
# Segments with errors cannot be updated (this is a secu- #
# rity measure, do not update what you do not understand) #
###########################################################
sub update {
    my ($this) = @_;
    # if the segment was not correctly parsed, warn and return
    return warn "A segment with errors cannot be modified" if $this->{error};
    # call a more specific routine
    return $this->dump_com()   if $this->{name} eq 'COM';
    return $this->dump_app1()  if $this->{name} eq 'APP1';
    return $this->dump_app13() if $this->{name} eq 'APP13';
    # the other segments are still unhandled (SOI, EOI and RST* are trivial)
    warn "Updating $this->{name} not yet implemented";
}

###########################################################
# This method outputs the current segment data area into  #
# a file handle. The segment "preamble" is prepended, ex- #
# ception made for raw data (scans). The preamble always  #
# includes the 0xff byte followed by the segment marker.  #
# Segments which can accept real data also require a      #
# two-byte data count. The return value is the error      #
# status of the print calls.                              #
# ------------------------------------------------------- #
# If the segment size is too large, a warning is printed  #
# and 0 is returned (this can make the file invalid);     #
# this is however just for debugging, I hope ....         #
#=========================================================#
# Note that the data area of a segment can be void and,   #
# nonetheless, the segment might require a segment length #
# word (e.g., a "" comment). In practise, the only seg-   #
# ments not needing the length word are SOI, EOI and RST*.#
###########################################################
sub output_segment_data {
    my ($this, $out) = @_;
    # collect the name of the segment and the length of the data area
    my $name     = $this->{name};
    my $length   = $this->size();
    # the segment lenght must be written to a two bytes field (including
    # the two bytes themselves). So, the maximum value of $length is
    # 2^16 - 3. Check and issue a warning in case it is larger. Do not
    # run the check for raw data or past-the-end data.
    my $max_length = 2**16 - 3;
    if ($length > $max_length && $name !~ /ECS|Post-EOI/) {
	warn sprintf "Segment %s too large (len=%d, max=%d), skipping ...",
	$this->{name}, $length, $max_length; return 0; }
    # prepare the segment header (skip for raw data segments)
    my $preamble = ( $name =~ /ECS|Post-EOI/ ? "" :
		     pack("CC", $JPEG_PUNCTUATION, $JPEG_MARKER{$name}) );
    # prepare the length word (skip for segments not needing it)
    $preamble .= pack("n", 2 + $length) unless $name =~ /SOI|EOI|RST|ECS/;
    # output the preamble and the data buffer (return the status)
    return print {$out} $preamble, $this->data(0, $length);
}

###########################################################
# This method shows the content of the segment. It prints #
# a header, then inspects the directory recursively.      #
###########################################################
sub get_description {
    my ($this) = @_;
    # prepare a few preliminary variables
    my $amarker = $JPEG_MARKER{$this->{name}};
    chomp(my $anerror = $this->{error});
    # prepare a header for this segment (was Segment_Banner)
    my $description = sprintf("%7dB ", $this->size()) .
	($amarker ? sprintf "<0x%02x %5s>", $amarker, $this->{name} :
	 sprintf "<%10s>", $this->{name} ) .
	 ($anerror ? " {Error: $anerror}" : "") . "\n";
    # a list for successive keys for numeric tag descriptions
    my $names = [ $this->{name} ];
    # show all the records we have in our structures (recursively)
    $description .= $this->show_directory($this->{records}, $names);
}

###########################################################
# This method shows the content of a record directory in  #
# a segment; the first argument is a record list refe-    #
# rence; the second argument is a list to a list of names #
# used to resolve numeric tags. A string is returned.     #
###########################################################
sub show_directory {
    my ($this, $records, $names) = @_;
    # prepare the string to be returned at the end
    my $description = "";
    # an initially empty list for remembering sub-dirs
    my @subdirs = ();
    # show all records in this directory
    foreach (@$records) {
	# show the record content
	$description .= $_->get_description($names);
	# if this is a subdir, remember its reference
	push @subdirs, $_ if $_->get_category() eq 'p';
    }
    # for every subdir we found, recurse
    foreach (@subdirs) {
	# get the directory name and reference
	my ($dir_name, $directory) = ($_->{key}, $_->get_value());
	# update the $names list
	push @$names, $dir_name;
	# print a sub-header for this directory
	$description .= Directory_Banner($names, scalar @$directory);
	# show the sub directory
	$description .= $this->show_directory($directory, $names);
	# pop the last dir name from @$names
	pop @$names;
    }
    # return the string we cooked up
    return $description;
}

###########################################################
# This helper function returns a string to be used as a   #
# generic header for a segment directory.                 #
###########################################################
sub Directory_Banner {
    my ($names, $alength) = @_; my $buffer = "";
    $buffer = join " --> ", @$names;
    return sprintf "%s%s %s %s (%2d records)\n",
    " \t" x (scalar @$names), "*" x 10, $buffer, "*" x 10, $alength;
}

###########################################################
# This helper method is used to test a size condition,    #
# i.e. that there is enough data (or exactly some amount  #
# of data) in the data buffer. If the test fails, it dies #
###########################################################
sub test_size {
    my ($this, $required, $message) = @_;
    # positive $require: test not greater
    return if $required >= 0 && $this->size() >= $required;
    # negative $require: test equality (on -$required)
    return if $required <  0 && $this->size() == (- $required);
    # if test fails, call die and hope it is intercepted
    my $precise = ""; $message = defined $message ? "($message)" : "";
    $required *= -1, $precise = "exactly " if $required < 0;
    die sprintf "Size mismatch in segment %s %s:"
	. " required %s%dB, found %dB.", $this->{name},
	$message, $precise, $required, $this->size();
}

###########################################################
# This is a helper method returning the size in bytes of  #
# the data area, i.e. that pointed to by $this->{dataref} #
###########################################################
sub size { return length ${$_[0]{dataref}}; }

###########################################################
# This helper method returns a substring of the data area #
# (the arguments are offset and length).                  #
###########################################################
sub data { substr(${$_[0]{dataref}}, $_[1], $_[2]); }

###########################################################
# This helper method writes into the segment data area,   #
# thus hiding the details of how the data area itself is  #
# implemented. Its first argument is a scalar or a scalar #
# reference, which (or whose content) is appended to the  #
# current buffer. If the second argument is 'OVERWRITE',  #
# well ... guess it. The return value is the length of    #
# the appended string.                                    #
###########################################################
sub set_data {
    my ($this, $addenda, $action) = @_;
    # get a reference to the current data area
    my $dataref = $this->{dataref};
    # get a reference to new data (remember that the
    # first argument can be a scalar or a scalar reference)
    my $addref = (ref $addenda) ? $addenda : \$addenda;
    # clear the current buffer if so requested
    $$dataref = "" if defined $action && $action eq 'OVERWRITE';
    # append the new data through the ref
    $$dataref .= $$addref;
    # return the amount of appended data
    return length $$addref;
}

###########################################################
# This method returns the first record, with a key equal  #
# to a given string, in the record directory specified    #
# by the record list reference $records; if the second    #
# argument is not defined, it defaults as usual to        #
# $this->{records}. If successful, the method returns a   #
# reference to the record itself.                         #
# ======================================================= #
# If $key is exactly "FIRST_RECORD" / "LAST_RECORD", the  #
# first/last record in the appropriate list is returned.  #
###########################################################
sub search_record {
    my ($this, $key, $records) = @_;
    # fix the record list reference if undefined
    $records = $this->{records} unless defined $records;
    # reserved key "FIRST_RECORD" returns the first record
    return $$records[0] if $key eq "FIRST_RECORD";
    # reserved key "LAST_RECORD" returns the last record
    return $$records[$#$records] if $key eq "LAST_RECORD";
    # scan the list and return a reference to the first matching record
    foreach (@$records) { return $_ if $_->{key} eq $key; }
    # return "undefined" if the search was unsuccessful
    return undef;
}

###########################################################
# This method looks for a REFERENCE record representing a #
# subdirectory, in a given record list. The two arguments #
# are the name of the subdirectory (a string) and a refe- #
# rence to a record list; if the second argument is not   #
# defined, it defaults to $this->{records}.               #
###########################################################
sub provide_subdirectory {
    my ($this, $dirname, $records) = @_;
    # if the record list reference is undefined, fix it
    $records = $this->{records} unless defined $records;
    # search and return the subdirectory reference (create if absent)
    my $dirref = $this->search_record($dirname, $records) ||
	$this->store_record($records, $dirname, $REFERENCE, \ []);
    return $dirref->get_value();
}

###########################################################
# This method creates a (possibly multi-valued) JPEG seg- #
# ment record from a data buffer or from the segment data #
# area, and it is the lowest level record-related method, #
# the only one actually calling the JPEG::Record ctor.    #
# It needs the record identifier, the value type, [a sca- #
# lar reference to read data from] or [the offset of the  #
# memory to read in the data area], and an optional value #
# count (if unspecified, it is set to 1 by the ctor).     #
# A reference to the record is returned at the end .      #
#=========================================================#
# If a scalar reference is passed, no check is performed  #
# on the size of the referenced scalar, because it is as- #
# sumed that this is dealt with in the caller routine.    #
# The correct endianness is read from the value of the    #
# current endianness, which is a private object member.   #
###########################################################
sub create_record {
    my ($this, $identifier, $type, $dataref, $count) = @_;
    # if the third argument is an offset, we need to convert it
    unless (ref $dataref) {
	# the data reference is indeed an offset
	my $offset = $dataref;
	# buffer length is calculated by the Record class
	# (we are assuming here that we never try to read from
	# memory something with variable size, e.g. references).
	my $length = Image::MetaData::JPEG::Record->get_size($type, $count);
	# replace the third argument with a scalar reference
	$dataref = \ $this->data($offset, $length);
	# update the offset through its alias (dangerous)
	# but don't complain if we have a read-only offset
	eval { $_[3] += $length; };
    }
    # call the record constructor and return its value (a reference)
    return new Image::MetaData::JPEG::Record
	($identifier, $type, $dataref, $count, $this->{endianness});
}

###########################################################
# This method is a wrapper for create_record returning    #
# the parsed value and NOT storing the record internally  #
# (for this reason we can set $identifier = 0). So, the   #
# arguments are: type, data reference, count. The data    #
# reference can be replaced by an offset, used to access  #
# the internal segment data buffer. If the offset is an   #
# lvalue, it is updated to point after the memory just    #
# read. The count can be undefined (it defaults to 1).    #
###########################################################
sub read_record {
    # @_ = (this, type, dataref/offset, count)
    my $this = shift;
    # invoke create_record: the first argument (the identifier)
    # is dummy, for the others we can use @_. Return the value
    return $this->create_record(0, @_)->get_value();
}

###########################################################
# This method creates a generic JPEG segment record just  #
# like read_record, stores it in the "records" list, and  #
# returns a reference to the newly created record. If the #
# offset is an lvalue, it is updated to point after the   #
# memory just read. See read_record for further details.  #
#=========================================================#
# A list reference can be prepended to the argument list; #
# in this case it is used instead of $this->{records}.    #
###########################################################
sub store_record {
    # @_ = (this, [record list,] identifier, type, dataref/offset, count)
    my $this = shift;
    # get a reference to the record list; but if next argument
    # is a reference, use it instead (and take it out of @_)
    my $records = $this->{records};
    $records = shift if ref $_[0];
    # create a new record and insert it into the record
    # list; we can use @_ for all the arguments.
    push @$records, $this->create_record(@_);
    # return a reference to the last record
    return $$records[$#$records];
}

# successful package load
1;
