###########################################################
# A Perl package for showing/modifying JPEG (meta)data.   #
# Copyright (C) 2004 Stefano Bettelli                     #
# See the COPYING and LICENSE files for license terms.    #
###########################################################
package Image::MetaData::JPEG;
use Image::MetaData::JPEG::Tables qw(:Endianness :TagsAPP1);
use Image::MetaData::JPEG::Segment;
no  integer;
use strict;
use warnings;

###########################################################
# This method finds the $index-th Exif APP1 segment in    #
# the file, and returns its reference. If $index is       #
# undefined, it defaults to zero (i.e., first segment).   #
# If no such segment exists, it returns undef. If $index  #
# is (-1), the routine returns the number of available    #
# Exif APP1 segments (which is >= 0).                     #
###########################################################
sub retrieve_app1_Exif_segment {
    my ($this, $index) = @_;
    # prepare the segment reference to be returned
    my $chosen_segment = undef;
    # $index defaults to zero if undefined
    $index = 0 unless defined $index;
    # get the references of all APP1 segments
    my @references = $this->get_segments('APP1$');
    # filter out those without Exif information
    @references = grep { $_->is_app1_Exif() } @references;
    # if $index is -1, return the size of @references
    return scalar @references if $index == -1;
    # return the $index-th such segment, or undef if absent
    return exists $references[$index] ? $references[$index] : undef;
}

###########################################################
# This method forces an Exif APP1 segment to be present   #
# in the file, and returns its reference. The algorithm   #
# is the following: 1) if at least one segment with these #
# properties is already present, the first one is retur-  #
# ned; 2) if [1] fails, an APP1 segment is added and      #
# initialised with an Exif structure.                     #
###########################################################
sub provide_app1_Exif_segment {
    my ($this) = @_;
    # get the references of all APP1 segments
    my @app1_refs = $this->get_segments('APP1$');
    # filter out those without Exif information
    my @Exif_refs = grep { $_->is_app1_Exif() } @app1_refs;
    # if @Exif_refs is not empty, return the first segment
    return $Exif_refs[0] if @Exif_refs;
    # if we are still here, an Exif APP1 segment must be created
    # and initialised (contrary to the IPTC case, an existing APP1
    # segment, presumably XPM, cannot be "adapted"). We write here
    # a minimal Exif segment with no data at all (in big endian).
    my $minimal_exif = $APP1_EXIF_TAG . $BIG_ENDIAN
	. pack "nNnN", $APP1_TIFF_SIG, 8, 0, 0;
    my $Exif = new Image::MetaData::JPEG::Segment('APP1', \ $minimal_exif);
    # choose a position for the new segment. I don't want to use
    # the standard routine for this, because the APP1 segment 
    # should be at the beginning. So, I put it in position 1
    # (or 2 if this is occupied by an APP0 segment).
    my @app0s = $this->get_segments('APP0$', "INDEXES");
    my $position = (@app0s && $app0s[0] == 1) ? 2 : 1;
    # get the list of segments in the file
    my $segments = $this->{segments};
    # actually insert the segment, then call the update method
    splice @$segments, $position, 0, $Exif;
    # return a reference to the new segment
    return $Exif;
}

###########################################################
# This method eliminates the $index-th Exif APP1 segment  #
# from the JPEG file segment list. If $index is (-1), all #
# Exif APP1 segments are affected at once.                #
###########################################################
sub remove_app1_Exif_info {
    my ($this, $index) = @_;
    # this is the list of segments to be purged (initially empty)
    my %deleteme = ();
    # call the selection routine and save the segment reference
    my $segment = $this->retrieve_app1_Exif_segment($index);
    # if $segment is really a non-null segment reference, mark it
    # for deletion; otherwise, it is the number of segments to be
    # deleted (this happens if $index is -1). In this case, the
    # whole procedure is repeated for every index.
    $segment->{name} = "deleteme" if ref $segment;
    if ($index == -1) { $this->retrieve_app1_Exif_segment($_)
			    ->{name} = "deleteme" for 0..($segment-1); }
    # remove marked segments from the file
    my $segments = $this->{segments};
    @$segments = grep { $_->{name} ne "deleteme" } @$segments;
}

###########################################################
# This method is a generalisation of the method with the  #
# same name in the Segment class. First, all Exif APP1    #
# segment are retrieved (if none is present, undefined is #
# returned). Then, get_Exif_data is called on each of     #
# these segments, passing the arguments through. The      #
# results are then merged in a single structure.          #
# For further details, see Segment::get_Exif_data() and   #
# JPEG::retrieve_app1_Exif_segment().                     #
# ------------------------------------------------------- #
# This method takes into account the different formats    #
# returned by the lower level get_Exif_data.              #
###########################################################
sub get_Exif_data {
    my $this = shift;
    # get the number of interesting segments
    my $number = $this->retrieve_app1_Exif_segment(-1);
    # return undef if no APP1 Exif segment is present
    return undef if $number == 0;
    # get references to all Exif APP1 segments and call
    # get_Exif_data on each segment, do not store failed
    # attempts, e.g. if @_ is invalid.
    my @segment_results = grep { defined $_ }  
    map { $_->get_Exif_data(@_) }
    map { $this->retrieve_app1_Exif_segment($_) } (0..$number-1);
    # return undef if there are no results ...
    return undef unless @segment_results;
    # declare the object to be returned and initialise it with
    # the first object found in @segment_results
    my $result = shift @segment_results;
    # merge in all the rest
    for (@segment_results) {
	# scalar values are simply concatenated ...
	unless (ref $_) { $result .= $_; next; }
	# (references to) arrays are appended ...
	if (ref $_ eq 'ARRAY') { push @$result, @$_; next; }
	# if we are still here it is a hash reference; if it points
	# to a flat hash (values are scalars) then we merge with slices
	unless (ref ((values %$_)[0])) {$$result{keys %$_} = values %$_; next;}
	# if we are still here, it is a diabolic two level hash
	while (my ($dir, $hashref) = each %$_) {
	    # create a hash if $dir is new
	    $$result{$dir} = {} unless exists $$result{$dir};
	    # push new data related to this $dir
	    while (my ($tag, $arrayref) = each %$hashref) {
		# create an array if $tag is new
		$$result{$dir}{$tag} = [] unless exists $$result{$dir}{$tag};
		# push new data related to this $tag
		my $global_arrayref = $$result{$dir}{$tag};
		push @$global_arrayref, @$arrayref; } } }
    # return the translated content of the segments
    return $result;
}

###########################################################
# This method is an interface to the method with the same #
# name in the Segment class. First, the first Exif APP1   #
# segment is retrieved (if there is no such segment, one  #
# is created and initialised). Then the set_Exif_data is  #
# called on this segment passing the arguments through.   #
# For further details, see Segment::set_Exif_data() and   #
# JPEG::provide_app1_Exif_segment().                      #
###########################################################
sub set_Exif_data {
    my $this = shift;
    # get the first Exif APP1 segment in the current JPEG file
    # (if there is no such segment, initialise one; therefore,
    # this call cannot fail [mhh ...]).
    my $segment = $this->provide_app1_Exif_segment();
    # pass the arguments through to the Segment method
    return $segment->set_Exif_data(@_);
}

###########################################################
# The following routines best fit as Segment methods.     #
###########################################################
package Image::MetaData::JPEG::Segment;
use Image::MetaData::JPEG::Tables qw(:Lookups);

###########################################################
# This method inspects a segments, and returns "undef" if #
# it is not an APP1 segment or if its structure is not    #
# Exif like. Otherwise, it returns "ok".                  #
###########################################################
sub is_app1_Exif {
    my ($this) = @_;
    # return undef if this segment is not APP1
    return undef unless $this->{name} eq 'APP1';
    # return undef if there is no 'Identifier' in this segment
    return undef unless $this->search_record('Identifier');
    # return undef if it is not Exif like
    my $identifier = $this->search_record('Identifier')->get_value();
    return undef unless $identifier && $identifier eq $APP1_EXIF_TAG;
    # return ok
    return "ok";
}

###########################################################
# This method returns a reference to a hash containing    #
# the "names" and references of the IFD directories or    #
# subdirectories currently present in the APP1 segment,   #
# including a special root directory containing some tags #
# and the links to IFD0 and IFD1. So, the hash has always #
# at least one entry; the routine can "fail" (returning   #
# undef) only if the segment is not an Exif APP1 segment. #
# The only argument is the name of the root directory.    #
###########################################################
sub retrieve_Exif_subdirectories {
    my ($this, $rootname) = @_;
    # return immediately if this is not an Exif APP1 segment
    return undef unless $this->is_app1_Exif();
    # This seemingly complicated private function takes two
    # arguments, an array reference ($_[0]) and a string ($_[1]).
    # The array reference must contain Record objects; Records
    # of type $REFERENCE are singled out and postprocessed.
    # Postprocessing implies returning a hash entry with the
    # key built out of the passed string and the Record key,
    # and the value copied from the Record value, followed by
    # all hash entries built in this way after inspection of
    # the subdirectory pointed to by the Record
    sub get_subdirs {
	map { $_[1]."@".$_->{key} => $_->get_value(),
	      get_subdirs($_->get_value(), $_[1]."@".$_->{key}) }
	grep { $_->{type} == $REFERENCE } @{$_[0]}; }
    # the return hash is filled with (key,value) pairs where "key" is
    # the name of an IFD directory or subdirectory (including a special
    # "ROOT" directory containing some tags and the links to IFD0 and
    # IFD1) and "value" is an array reference linking to the dir.
    return { $rootname => $this->{records},
	     get_subdirs($this->{records}, $rootname) };
}

###########################################################
# This method accepts two arguments ($what and $type) and #
# returns the content of the APP1 segment packed in vari- #
# ous formats. All Exif records are natively identified   #
# by numeric tags (keys), which can be "translated" into  #
# a human-readable form by using the Exif standard docs;  #
# only a few fields in the Exif APP1 preamble (they are   #
# not Exif records) are always identified by this module  #
# by means of textual tags. The $type argument selects    #
# the output format for the record keys (tags):           #
#  - NUMERIC: record tags are native numeric keys         #
#  - TEXTUAL: record tags are human-readable (default)    #
# Of course, record values are never translated. If a     #
# numeric Exif tag is not known, a custom textual key is  #
# created with "Unknown_tag_" followed by the numerical   #
# value (this solves problems with non-standard tags).    #
# ------------------------------------------------------- #
# The subset of Exif tags returned by this method is      #
# determined by the value of $what, which can be one of:  #
# 'ALL'(default), 'IMAGE_DATA', 'THUMB_DATA', 'GPS_DATA', #
# 'INTEROP_DATA' or 'THUMBNAIL'. Setting $what equal to   #
# 'ALL' returns a data dump very close to the Exif APP1   #
# segment structure; the returned value is a reference to #
# a hash of hashes: each element of the root-level hash   #
# is a pair ($name, $hashref), where $hashref points to a #
# second-level hash containing a copy of all Exif records #
# present in the $name IFD (sub)directory. The root-level #
# hash includes a special root directory (named 'APP1')   #
# containing some non Exif parameters.                    #
# Setting $what equal to '*_DATA' returns a reference to  #
# a flat hash, corresponding to one or more IFD (sub)dirs:#
#  - IMAGE_DATA     IFD0 + IFD0@SubIFD  (primary image)   #
#  - THUMB_DATA     IFD1                (thumbnail image) #
#  - GPS_DATA       IFD0@GPS            (GPS data)        #
#  - INTEROP_DATA   IFD0@SubIFD@Interop (interoperabilty) #
# Last, setting $what to 'THUMBNAIL' returns a reference  #
# to a copy of the actual Exif thumbnail image (this is   #
# not included in the set returned by 'THUMB_DATA').      #
# ------------------------------------------------------- #
# Note that the Exif record values' format is not checked #
# to be valid according to the Exif standard. This is, in #
# some sense, consistent with the fact that also "unknown"#
# tags are included in the output.                        #
###########################################################
sub get_Exif_data {
    my ($this, $what, $type) = @_;
    # refuse to work unless you are an Exif APP1 segment
    return undef unless $this->is_app1_Exif();
    # the name of the root Exif directory (see later)
    my $rootname = "APP1";
    # set the default section and type, if undefined
    $what = 'ALL'     unless defined $what;
    $type = 'TEXTUAL' unless defined $type;
    # $what equal to 'THUMBNAIL' is special: it returns a copy of the
    # thumbnail data area (this can be a self-contained JPEG picture
    # or an uncompressed picture needing more parameters from IFD1)
    if ($what eq 'THUMBNAIL') {
	my $trec = $this->search_record('ThumbnailData');
	return $trec ? \ $trec->get_value() : undef; }
    # reject unknown sections and types ('THUMBNAIL' already dealt with)
    return undef unless $type =~ /^NUMERIC$|^TEXTUAL$/ &&
	$what =~ /ALL|(IMAGE|THUMB|GPS|INTEROP)_DATA/;	
    # create a hash filled with (key, ref) pairs where "key" is the name
    # of an IFD directory or subdirectory (including a special root
    # directory containing some tags and the links to IFD0 and IFD1) and
    # "ref" is an array reference linking to the dir.
    my $IFD_refs = $this->retrieve_Exif_subdirectories($rootname);
    # This hash defines which IFD (sub)directories are relevant by
    # means of regexps (the keys must correspond to the legal $what's).
    my %regexps = ( 'ALL'          => $rootname . '.*',
		    'IMAGE_DATA'   => $rootname . '@IFD0(|@SubIFD)',
		    'GPS_DATA'     => $rootname . '@IFD0@GPS',
		    'INTEROP_DATA' => $rootname . '@IFD0@SubIFD@Interop',
		    'THUMB_DATA'   => $rootname . '@IFD1' );
    # create a hash filled with (key, ref) pairs where "key" is the name
    # of an IFD directory or subdirectory, as before, compatible with $what,
    # and "ref" is a reference to a hash containing the tag/value pairs of
    # that subdirectory (not including the REFERENCE records, of course!).
    my $IFD_dirs = {};
    while (my ($dir, $rec_ref) = each %$IFD_refs) {
	# forget about subdirectories not selected by $what;
	next unless $dir =~ /^$regexps{$what}$/;
	# map the record list reference to a full hash containing
	# the subdirectory records as (tag => values) pairs.
	my %pairs = map { $_->{key} => $_->{values} }
	            grep { $_->{type} != $REFERENCE } @$rec_ref;
	$$IFD_dirs{$dir} = \ %pairs; }
    # up to now, all record keys (tags) are numeric (exception made
    # for keys in the "ROOT" directory, for which there is no numeric
    # counterpart). If $type is 'TEXTUAL', they must be translated.
    if ($type eq "TEXTUAL") {
	while (my ($name, $ref) = each %$IFD_dirs) {
	    # entries in the root directory are only textual
	    next if $name eq $rootname;
	    # select the appropriate numeric-to-textual
	    # conversion table by looking at the $name
	    my $table = JPEG_lookup(split /@/, $name);
	    # run the translation (create a name also for unkwnon tags)
	    %$ref = map { (exists $$table{$_} ? $$table{$_} :
			   "Unknown_tag_$_") => $$ref{$_} } keys %$ref; }}
    # if $what is not 'ALL', the final hash must be flattened, because this
    # is simpler for the end user. If $what is 'ALL', one cannot do this
    # because there might be repeated or homonymous tags.
    if ($what ne 'ALL') { my %flat = ();
			  @flat{keys %$_} = values %$_ for values %$IFD_dirs;
			  $IFD_dirs = \ %flat; }
    # return the reference to the hash containing all data
    return $IFD_dirs;
}

###########################################################
# This method is the entry point for setting Exif data in #
# the current APP1 segment. It makes some basic checks on #
# the arguments, then calls a specific routine from its   #
# pool (read there for further details). The arguments    #
# are: $data (a hash reference, with new records to be    #
# written), $what (a scalar, selecting the concerned por- #
# tion of the Exif APP1 segment) and $action (a scalar    #
# specifying the requested action). Valid values are:     #
#    $what   --> GPS_DATA | .... to be finished           #
#    $action --> ADD | REPLACE                            #
# The behaviour of $action is similar to that for IPTC    #
# data. The only checks performed here are: the segment   #
# must be of the appropriate type, $data must be a hash   #
# reference, $action and $what must be valid. Moreover,   #
# this method sets the default ($action == 'REPLACE').    #
# ------------------------------------------------------- #
# The return value is always a hash reference; in general #
# it contains rejected records. If an error occurs in a   #
# very early stage of the setter, this reference contains #
# a single entry with key='ERROR' and value set to some   #
# meaningful error message. So, a reference to an empty   #
# hash means that everything was OK.                      #
###########################################################
sub set_Exif_data {
    my ($this, $data, $what, $action) = @_;
    # refuse to work unless you are an Exif APP1 segment
    return {'ERROR'=>'Not an Exif APP1 segment'} unless $this->is_app1_Exif();
    # return immediately if $data is undefined
    return {'ERROR'=>'Undefined data reference'} unless defined $data;
    # $data must be a hash reference
    return {'ERROR'=>'\$data not a hash reference'} unless ref $data eq 'HASH';
    # set the default action, if undefined
    $action = 'REPLACE' unless defined $action;
    # refuse to work for unkwnon actions
    return {'ERROR'=>"Unknown action $action"} unless $action =~ /ADD|REPLACE/;
    # call the appropriate specialiased method
    return $this->set_Exif_data_GPS_DATA($data,$action) if $what eq 'GPS_DATA';
    # fallback: complain about undefined sections
    return {'ERROR'=>"Unknown section $what"};
}

###########################################################
# This method is the specialised setter for GPS data. It  #
# takes a hash reference $data and an action $action. The #
# elements of $data which can be converted to valid GPS   #
# records are inserted in the GPS subIFD, the others are  #
# returned. Note that GPS records are non-repeatable in   #
# nature, so there is no need for an 'UPDATE' action in   #
# addition to 'ADD' (they both would overwrite an old     #
# record if it has the same tag as a new record); $action #
# equal to 'REPLACE', on the other hand, clears the GPS   #
# record list before the insertions. GPS records' tags    #
# can be give textually or numerically.                   #
# ------------------------------------------------------- #
# This method creates a GPS record subdirectory if it is  #
# not present, so you can call it also on GPS-less files. #
# A GPSVersionID is forced, if it is not present at the   #
# end of the process, because it is mandatory. Records    #
# are rewritten to the GPS subdirectory in increasing     #
# (numerical) tag order. Note that there are some record  #
# intercorrelations which are still neglected here.       #
# ------------------------------------------------------- #
# GPS data are quite easy since none of them can appear   #
# twice, and the syntax is quite clear. First, the tags   #
# are checked for validity and converted to numeric form. #
# Records with undefined values are rejected. Then, the   #
# specifications for each given tag are read from a       #
# helper table: values are matched against a regular      #
# expression (or a surrogate). Then a Record object is    #
# forged and evaluated to see if it is valid and it       #
# corresponds to the user will. If all these checks are   #
# OK, the GPS record is finally inserted.                 #
###########################################################
sub set_Exif_data_GPS_DATA {
    my ($this, $data, $action) = @_;
    # prepare two hashes for rejected and accepted records
    my $data_rejected = {}; my $data_accepted = {};
    # ask the IFD0 record list where is the GPS record list
    my $ifd0_list = $this->search_record('IFD0')->get_value();
    my $gps_ref = $this->search_record('GPS', $ifd0_list);
    # if it does not exist, create it; since version 10.f, we do not
    # need to store a GPS offset record too (its value would in any
    # case be wrong, it will be calculated automatically at update time).
    # we need however to set the "extra" field of this REFERENCE record,
    # in order to mimick the case when it is parsed directly from a file.
    if (! $gps_ref) {
	my $rec = new Image::MetaData::JPEG::Record('GPS', $REFERENCE, \ []);
	$rec->{extra} = 'GPSInfo'; push @$ifd0_list, $rec; }
    # get the GPS directory reference
    my $gps_ref_record = $this->search_record('GPS', $ifd0_list);
    # get the empty record list, to be filled
    my $record_list = $gps_ref_record->get_value();
    # For $action equal to 'ADD', we read the old records and insert
    # them in the $data_accepted hash (they will be overwritten by user
    # supplied data if necessary). If $action is 'REPLACE' we completely
    # forget about the past.
    unless ($action =~ 'REPLACE') { 
	$$data_accepted{$_->{'key'}} = $_ for @$record_list; }
    # now, clear the GPS record list (dangerous?)
    @$record_list = ();
    # loop over entries in $data and decide whether to accept them or not
    while (my ($key, $value) = each %$data) {
	# do a key lookup and save the result
	my $key_lookup = JPEG_lookup('APP1', 'IFD0', 'GPS', $key);
	# translate textual tags to numbers if possible
	$key = $key_lookup if $key_lookup && $key !~ /^\d*$/;
	# I have never been optimist ...
	$$data_rejected{$key} = $value;
	# reject unknown keys
	next unless $key_lookup;
	# of course, check that $value is defined
	next unless defined $value;
	# if value is a scalar, transform it into a single-valued array
	$value = [ $value ] unless ref $value;
	# $value must now be an array reference
	next unless ref $value eq 'ARRAY';
	# get all mandatory properties of this record
	my ($name, $type, $count, $regex) = @{$HASH_GPS_GENERAL{$key}};
	# if $type is $ASCII and $$value[0] is not null terminated,
	# we are going to add the null character for the lazy user
	$$value[0].="\000" if $type==$ASCII && @$value && $$value[0]!~/\000$/;
	# a latitude or a longitude is stored as a sequence of three
	# rationals (degrees, minutes and seconds), i.e., six unsigned
	# integers; Also the time stamp is stored as three rationals
	# (why?); in this case the test is the same but 90 is replaced by 24.
	if ($regex =~ /latlong|stupidtime/) {
	    my @v = @$value; next unless eval
	    { die if grep { $_ < 0 } @v;
	      my ($dd, $mm, $ss) = ($v[0]/$v[1], $v[2]/$v[3], $v[4]/$v[5]);
	      my $limit = ($regex =~ /stupidtime/) ? 24 : 90;
	      die unless $mm < 60 && $ss < 60 && $dd <= $limit;
	      die unless ($dd + $mm /60 + $ss/360) <= $limit; }; }
	# a direction is a rational number in [0.00, 359.99]
	elsif ($regex =~ /direction/) {
	    next unless eval {
		die if grep { $_ < 0 } @$value;
		my $dire = $$value[0]/$$value[1]; die if $dire >= 360;
		die unless $dire =~ /^\d+(\.\d{1,2})?$/; }; }
	# now check real regular expressions (if the record is
	# multi-valued, the same $regex must match all the elements).
	else { next unless scalar @$value == grep { $_ =~ /^$regex$/} @$value;}
	# now we are going to play with the internals of the Record
	# class (so, this part is very prone to errors), but it is
	# necessary if we want the user input to be intuitive;
	my $rec = new Image::MetaData::JPEG::Record($key, $ASCII, \ "");
	# fix the type andd value list of the record and let's hope
	$rec->{type}   = $type;
	$rec->{values} = $value;
	# try to get back the record properties; since I suspect
	# that this can fail (because the value list was arbitrarily
	# transplanted) this inquiry is executed in an eval, and the
	# result is tested. If the eval fails, we give up
	my ($a_key, $a_type, $a_count, $a_dataref) = eval { $rec->get() };
	next if $@;
	# if the record is miraculously alive, let us check that the
	# returned properties are as requested; otherwise give up (when
	# $count is undefined, we do not need to check it [variable])
	next unless $type == $a_type && (! $count || $count == $a_count);
	# well, it seems that the record is OK, so my pessimism
	# was not justified. Let us change the record status
	delete $$data_rejected{$key};
	$$data_accepted{$key} = $rec;
    }
    # supply the mandatory GPS version if not present (use v.2.2)
    my $version_key = 0;
    unless (exists $$data_accepted{$version_key}) {
	my ($name, $type, $count, $regex) = @{$HASH_GPS_GENERAL{$version_key}};
	$$data_accepted{$version_key} = new Image::MetaData::JPEG::Record
	    ($version_key, $type, \ "\002\002\000\000", $count); }
    # now, take all data from $data_accepted and write the corresponding
    # records to the GPS record list (in increasing numeric key order)
    push @$record_list, $$data_accepted{$_}
    for sort {$a <=> $b} keys %$data_accepted;
    # remember to commit these changes to the data area
    $this->update();
    # that's it, return the reference to the rejected data hash
    return $data_rejected;
}

###########################################################
# This method ....
###########################################################
#sub set_Exif_data_THUMBNAIL {
#    my ($this, $data) = @_;
    # $data must be a reference to a scalar
#    return undef unless ref $data eq 'SCALAR';
    # JPEG thumbnails can be either JPEG images or uncompressed
    # data in one of three formats. It is important to try to
    # understand the type of passed data. 
#    my $type = undef;
    # if it is a JPEG picture, it can be parsed by this module.
    # Well, this is not really a proof that it is a valid JPEG image,
    # but for the time being it will do the job.
#    if (my $image = new Image::MetaData::JPEG($data)) {
#	my $segments = $image->{segments};
	# JPEG thumbnails cannot contain application or comment segments,
	# as well as restart markers (but this isn't detected yet!)
#	return undef if scalar grep { $_->{name} =~ 'APP|COM|RST' } @$segments;
	# since we are satisfied that it is a JPEG thumbnail, we set $type
#	$type = 'JPEG';
	# JPEGInterchangeFormat
	# JPEGInterchangeFormatLength
#    }

#}

    # Baseline TIFF Rev.6.0 RGB Full Color Images

    # TIFF Rev.6.0 Extensions YCbCr Images
    # -----> all tags for RGB data
    # -----> YCbCrCoefficients
    # -----> YCbCrSubsampling
    # -----> YCbCrPositioning


    # 'Compression' deve essere calcolato!!!


#uncompressed chunky,
#uncompressed planar,
#uncompressed YCbCr
#JPEG compressed

#M (mandatory)
#R (recommended)
#O (optional)
#N (not_recorded)
#J (included in JPEG marker and so not recorded).

#     Hexadecimal code                count   IFD1 notes
#  class |  Tag name                 type |   |    |
#  |     |  |                           | |   |    |
#  A   100  ImageWidth                  I 1   MMMJ ***
#  A   101  ImageLength                 I 1   MMMJ ***
#  A   102  BitsPerSample               S 3   MMMJ ***
#  A   106  PhotometricInterpretation   S 1   MMMJ *** (2 or 6)
#  B   111  StripOffsets                I -   MMMN ***
#  A   115  SamplesPerPixel             S 1   MMMJ ***
#  B   116  RowsPerStrip                I 1   MMMN ***
#  B   117  StripByteCounts             I -   MMMN ***
#  A   11a  XResolution                 R 1   MMMM [72 default]
#  A   11b  YResolution                 R 1   MMMM [72 default]
#  A   11c  PlanarConfiguration         S 1   OMOJ *** (1 or 2)
#  A   128  ResolutionUnit              S 1   MMMM (2 or 3)
#  B   201  JPEGInterchangeFormat       L 1   NNNM calculated, in IFD1
#  B   202  JPEGInterchangeFormatLength L 1   NNNM calculated, in IFD1
#  C   211  YCbCrCoefficients           R 3   NNOO .
#  A   212  YCbCrSubSampling            S 2   NNMJ *** ([2,1] or [2,2])
#  A   213  YCbCrPositioning            S 1   NNOO (1 or 2)
##
#
#
#}



#    # the first possibility corresponds to $data being a hash
#    # reference, with the key corresponding to a dataset tag
#    # and the value to an array reference (the array contains
#    # the dataset values).
#    if (defined ref $data && ref $data eq 'HASH') {
#	# are we dealing with numeric or textual keys? Try to
#	# guess with a statistical approach on key regex matches.
#	my $hits = scalar map { $_ =~ /^[0-9]*$/ } keys %$data;
#	# if keys are believed to be textual, translate them
#	# to numeric keys. Filter out invalid dataset tags
#	%$data = map { ! exists $IPTC_names{$_} ? die "Invalid key $_" :
#			   $IPTC_names{$_} => $$data{$_} } keys %$data
#			   if $hits <= (scalar keys %$data) / 2;
#    }
#    # $data is a hash reference now, with numeric keys.
#    # Perform a last check on the validity of keys.
#    map { die "Invalid key $_" unless exists $IPTC_tags{$_} } keys %$data;
#    # if $action is 'REPLACE', all records need to be eliminated
#    # before pushing the new ones in.
#    my $dirref = $this->provide_IPTC_subdirectory();
#    @$dirref = () if $action eq 'REPLACE';
#    # now all keys are surely valid and numeric. For each element
#    # in the hash, create one or more Records corresponding to a
#    # dataset and insert it into the appropriate subdirectory
#    map { my $key = $_; map {
#	# each element of the array in a hash element creates a new Record
#	$this->store_record($dirref,$key,$ASCII,\$_,length $_); } @{$$data{$_}}
#	  # sort the Records on the numeric key
#      } sort { $a <=> $b } keys %$data;
#    # be sure that the first record is 'RecordVersion', i.e., dataset
#    # number zero. Create and insert, if necessary (with version = 2) ?
#    $this->store_record($dirref, 0, $UNDEF, \ "\000\002", 2),
#    unshift @$dirref, pop @$dirref unless @$dirref && $$dirref[0]->{key} == 0;
#    # remember to commit these changes to the data area
#    $this->update();


# successful package load
1;
