###########################################################
# A Perl package for showing/modifying JPEG (meta)data.   #
# Copyright (C) 2004 Stefano Bettelli                     #
# See the COPYING and LICENSE files for license terms.    #
###########################################################
package Image::MetaData::JPEG;
use Image::MetaData::JPEG::Tables;
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
    # remove the marked segments from the file
    my $segments = $this->{segments};
    @$segments = grep { $_->{name} ne "deleteme" } @$segments;
}

###########################################################
# This method is a generalisation of the method with the  #
# same name in the Segment class. First, all Exif APP1    #
# segment are retrieved (if none is present, the undefi-  #
# ned value is returned). Then, get_Exif_data is called   #
# on each of these segments, passing the argument ($type) #
# through. The results are then merged in a single hash.  #
# For further details, see Segment::get_Exif_data() and   #
# JPEG::retrieve_app1_Exif_segment().                     #
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
    # define the hash reference to be returned at the end
    my $result = {};
    # collect all results in a single hash
    for (@segment_results) {
	while (my ($dir, $hashref) = each %$_) {
	    # create a hash if $dir is new
	    $$result{$dir} = {} unless exists $$result{$dir};
	    # push new data related to this $dir
	    my $global_hashref = $$result{$dir};
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

###########################################################
# This method inspects a segments, and returns "undef" if #
# it is not an APP1 segment or if its structure is not    #
# Exif like. Otherwise, it returns "ok".                  #
###########################################################
sub is_app1_Exif {
    my ($this) = @_;
    # return undef if this segment is not APP1
    return undef unless $this->{name} eq 'APP1';
    # return undef if it is not Exif like
    my $identifier = $this->search_record('Identifier')->get_value();
    return undef unless $identifier && $identifier eq $APP1_EXIF_TAG;
    # return ok
    return "ok";
}

###########################################################
# This method returns a reference to a hash containing    #
# the "names" and referencies of the IFD directories or   #
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
    # the %IFD_dirs hash is filled with (key,value) pairs where "key" is
    # the name of an IFD directory or subdirectory (including a special
    # "ROOT" directory containing some tags and the links to IFD0 and
    # IFD1) and "value" is an array reference linking to the dir.
    sub get_subdirs {
	map { $_[1]."@".$_->{key} => $_->get_value(),
	      get_subdirs($_->get_value(), $_[1]."@".$_->{key}) }
	grep { $_->{type} == $REFERENCE } @{$_[0]}; }
    return { $rootname => $this->{records},
	     get_subdirs($this->{records}, $rootname) };
}

###########################################################
# This method returns the IPTC subdir record reference for#
# the current app13 segment. If the subdirectory is not   #
# there, it is first created and initialised. The routine #
# can fail (return undef) only if the segment isn't app13.#
# If the subdirectory is created, the segment is updated. #
###########################################################
#sub provide_my_subdirectory {
#    my ($this) = @_;
#    # don't try to mess up non-APP13 segments!
#    return undef unless $this->{name} eq 'APP13';
#    # be positive, call retrieve first
#    my $subdir = $this->retrieve_IPTC_subdirectory();
#    # return this value, if it is not undef
#    return $subdir if defined $subdir;
#    # create the IPTC subdir in the main record dir of this segment
#    $subdir = $this->provide_subdirectory($IPTC_subdir_name);
#    # initialise the subdirectory with 'RecordVersion'. I don't
#    # know why the standard says "4" here, but you always find "2".
#    $this->store_record($subdir, 0, $UNDEF, \ "\000\002", 2);
#    # obviously, update the segment
#    $this->update();
#    # return the subdirectory reference
#    return $subdir;
#}

###########################################################
# This method returns a reference to a hash containing a  #
# named (the tag) hash references. Each sub-hash contains #
# a copy of all Exif tags/values present in a particular  #
# IFD (sub)directory (including a special root directory  #
# containing some tags and the links to IFD0 and IFD1).   #
# $type selects the output format:                        #
# NUMERIC -> native numeric tags                          #
# TEXTUAL -> translated text tags (default)               #
#=========================================================#
# If a numerical Exif tag is not known, a custom textual  #
# tag is created with "Unknown_tag_" followed by the nu-  #
# merical value (solves problem with non-standard tags).  #
###########################################################
sub get_Exif_data {
    my ($this, $type) = @_;
    # the name of the root Exif directory (see later)
    my $rootname = "APP1";
    # set the default type, if it is undefined
    $type = 'TEXTUAL' unless defined $type;
    # reject unknown types
    return undef unless $type =~ /^NUMERIC$|^TEXTUAL$/;
    # first, create a hash filled with (key,value) pairs where "key" is
    # the name of an IFD directory or subdirectory (including a special
    # root directory containing some tags and the links to IFD0 and
    # IFD1) and "value" is an array reference linking to the dir.
    my $IFD_dirs = $this->retrieve_Exif_subdirectories($rootname);
    # second, each element of the hash must have its value (previously,
    # a reference to an IFD subdirectory) replaced by a reference to an
    # hash containing the tag/value pairs of that subdirectory (not
    # including the REFERENCE records, of course!)
    %$IFD_dirs = map { my %pairs = map { $_->{key} => $_->{values} }
		      grep { $_->{type} != $REFERENCE } @{$$IFD_dirs{$_}};
		      $_ => \ %pairs } keys %$IFD_dirs;
    # up to now, all keys are numeric (exception made for keys in the
    # "ROOT" directory, for which there is no numeric counterpart).
    # If $type is 'TEXTUAL', they must be translated.
    if ($type eq "TEXTUAL") {
	while (my ($name, $ref) = each %$IFD_dirs) {
	    # entries in the root directory are only textual
	    next if $name eq $rootname;
	    # select the appropriate numeric-to-textual
	    # conversion table by looking at the $name
	    my $table = \ %JPEG_RECORD_NAME;
	    $table = $$table{$_} for split /@/, $name;
	    # run the translation (create a name also for unkwnon tags)
	    %$ref = map { (exists $$table{$_} ? $$table{$_} :
			   "Unknown_tag_$_") => $$ref{$_} } keys %$ref; }}
    # return the reference to the hash containing all data
    return $IFD_dirs;
}

###########################################################
# This method accepts IPTC data in various formats and    #
# updates the IPTC subdirectory in the segment. The type  #
# of the first argument selects the conversion process:   #
# . hash with native numeric tags            --> NUMERIC  #
# . hash with translated text tags (default) --> TEXTUAL  #
# The $action argument can be 'ADD' or 'REPLACE', and it  #
# discriminates weather the passed data must be added to  #
# or must replace the current datasets in the IPTC subdir.#
# At the end, the segment data area is updated. The hash  #
# pointed to by the hash reference argument is modified.  #
###########################################################
#sub set_Exif_data {
#    my ($this, $data, $action) = @_;
#    # return immediately if $data is undefined
#    return unless defined $data;
#    # set the default action, if it is undefined
#    $action = 'REPLACE' unless defined $action;
#    # complain about undefined actions
#    die "Unknown action $action" unless $action =~ /^REPLACE$|^ADD$/;
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
#}

# successful package load
1;
