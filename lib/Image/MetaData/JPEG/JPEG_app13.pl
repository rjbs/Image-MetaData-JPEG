###########################################################
# A Perl package for showing/modifying JPEG (meta)data.   #
# Copyright (C) 2004 Stefano Bettelli                     #
# See the COPYING and LICENSE files for license terms.    #
###########################################################
package Image::MetaData::JPEG;
use Image::MetaData::JPEG::Tables qw(:Lookups :TagsAPP13);
use Image::MetaData::JPEG::Segment;
no  integer;
use strict;
use warnings;

###########################################################
# $IPTC_subdir_name is the name of the IPTC subdirectory  #
# record in the main record directory of an APP13 segment.#
# The two hashes are fast lookup tables for numeric to    #
# textual and back tag translations.                      #
###########################################################
my $IPTC_subdir_name = 'IPTC_RECORD_2';
my %IPTC_tags        = %{JPEG_lookup('APP13', $IPTC_subdir_name)};
my %IPTC_names       = reverse %IPTC_tags;

###########################################################
# This method finds the $index-th APP13 segment WITH IPTC #
# information in the file, and returns its reference. If  #
# $index is undefined, it defaults to zero (i.e., first   #
# segment). If no such segment exists, it returns undef.  #
# If $index is (-1), the routine returns the number of    #
# available APP13 IPTC segments (which is >= 0).          #
###########################################################
sub retrieve_app13_IPTC_segment {
    my ($this, $index) = @_;
    # prepare the segment reference to be returned
    my $chosen_segment = undef;
    # $index defaults to zero if undefined
    $index = 0 unless defined $index;
    # get the references of all APP13 segments
    my @references = $this->get_segments('APP13');
    # filter out those without IPTC information
    @references = grep { $_->is_app13_IPTC() } @references;
    # if $index is -1, return the size of @references
    return scalar @references if $index == -1;
    # return the $index-th such segment, or undef if absent
    return exists $references[$index] ? $references[$index] : undef;
}

###########################################################
# This method forces an APP13 segment with IPTC info to   #
# be present in the file, and returns its reference. The  #
# algorithm is the following: 1) if at least one segment  #
# with these properties is already present, the first one #
# is returned; 2) if [1] fails, but at least one APP13    #
# segment exists, an IPTC subdirectory is created and     #
# initialised inside it (+ update), and the segment refe- #
# rence is returned; 3) if also [2] fails, an APP13 seg-  #
# ment is added and initialised, and [2] is applied.      #
###########################################################
sub provide_app13_IPTC_segment {
    my ($this) = @_;
    # get the references of all APP13 segments
    my @app13_refs = $this->get_segments('APP13');
    # filter out those without IPTC information
    my @IPTC_refs = grep { $_->is_app13_IPTC() } @app13_refs;
    # if @IPTC_refs is not empty, return the first segment
    return $IPTC_refs[0] if @IPTC_refs;
    # if it is empty, get a reference to the first segment
    # in @app13_refs (undef, if even this is empty)
    my $app13 = @app13_refs ? $app13_refs[0] : undef;
    # if $app13 is defined, skip the following lines, where
    # an APP13 segment is built, initialised and stored in
    # an appropriate position in the file
    unless (defined $app13) {
	# remember that at least the Photoshop string must be there
	$app13 = new Image::MetaData::JPEG::Segment
	    ('APP13', \ "$APP13_PHOTOSHOP_IDENTIFIER");
	# choose a position for the new segment
	my $position = $this->find_new_app_segment_position();
	# get the list of segments in the file
	my $segments = $this->{segments};
	# actually insert the segment
	splice @$segments, $position, 0, $app13; }
    # now, $app13 is a valid APP13 segment reference, and there
    # is no IPTC subdirectory inside it. Provide it. Then return.
    $app13->provide_IPTC_subdirectory();
    return $app13;
}

###########################################################
# This method eliminates all traces of IPTC information   #
# from the $index-th APP13 IPTC segment. If, after this,  #
# the segment is empty, it is eliminated from the list of #
# segments in the file. If $index is (-1), all APP13 IPTC #
# segments are affected at once.                          #
###########################################################
sub remove_app13_IPTC_info {
    my ($this, $index) = @_;
    # this is the list of segments to be purged (initially empty)
    my @purgeme = ();
    # call the selection routine and save the segment reference
    my $segment = $this->retrieve_app13_IPTC_segment($index);
    # if $segment is really a non-null segment reference, push it into
    # the purge list; otherwise, it is the number of segments to be
    # purged (this happens if $index is -1). In this case, the selection
    # routine is repeated with every index, and the results are pushed
    # in the @purgeme list
    push @purgeme, $segment if ref $segment;
    @purgeme = map { $this->retrieve_app13_IPTC_segment($_)
		     } (0..($segment-1)) if $index == -1;
    # for each segment in the purge list, apply the purge routine.
    # If only one record remains in the segment (presumably the
    # identifier), the segment is marked for deletion at a later stage
    for (@purgeme) { $_->remove_IPTC_subdirectory();
		     $_->{name} = "deleteme" if scalar @{$_->{records}} <= 1; }
    # remove the marked segments from the file
    my $segments = $this->{segments};
    @$segments = grep { $_->{name} ne "deleteme" } @$segments;
}

###########################################################
# This method is a generalisation of the method with the  #
# same name in the Segment class. First, all IPTC APP13   #
# segment are retrieved (if none is present, the undefi-  #
# ned value is returned). Then, get_IPTC_data is called   #
# on each of these segments, passing the argument ($type) #
# through. The results are then merged in a single hash.  #
# For further details, see Segment::get_IPTC_data() and   #
# JPEG::retrieve_app13_IPTC_segment().                    #
###########################################################
sub get_IPTC_data {
    my $this = shift;
    # get the number of interesting segments
    my $number = $this->retrieve_app13_IPTC_segment(-1);
    # return undef if no APP13 IPTC segment is present
    return undef if $number == 0;
    # get references to all IPTC APP13 segments and call
    # get_IPTC_data on each segment, do not store failed
    # attempts, e.g. if @_ is invalid.
    my @segment_results = grep { defined $_ }  
    map { $_->get_IPTC_data(@_) }
    map { $this->retrieve_app13_IPTC_segment($_) } (0..$number-1);
    # return undef if there are no results ...
    return undef unless @segment_results;
    # define the hash reference to be returned at the end
    my $result = {};
    # collect all results in a single hash
    for (@segment_results) {
	while (my ($tag, $arrayref) = each %$_) {
	    # create an array if the tag is new
	    $$result{$tag} = [] unless exists $$result{$tag};
	    # push new data related to this tag
	    my $global_arrayref = $$result{$tag};
	    push @$global_arrayref, @$arrayref; } }
    # return the translated content of the segments
    return $result;
}

###########################################################
# This method is an interface to the method with the same #
# name in the Segment class. First, the first IPTC APP13  #
# segment is retrieved (if there is no such segment, one  #
# is created and initialised). Then the set_IPTC_data is  #
# called on this segment passing the arguments through.   #
# For further details, see Segment::set_IPTC_data() and   #
# JPEG::provide_app13_IPTC_segment().                     #
###########################################################
sub set_IPTC_data {
    my $this = shift;
    # get the first IPTC APP13 segment in the current JPEG file
    # (if there is no such segment, initialise one; therefore,
    # this call cannot fail [mhh ...]).
    my $segment = $this->provide_app13_IPTC_segment();
    # pass the arguments through to the Segment method
    return $segment->set_IPTC_data(@_);
}

###########################################################
# The following routines best fit as Segment methods.     #
###########################################################
package Image::MetaData::JPEG::Segment;

###########################################################
# This method inspects a segments, and returns "undef" if #
# it is not an APP13 segment or it does not contain an    #
# IPTC subdirectory. Otherwise, it returns "ok".          #
###########################################################
sub is_app13_IPTC {
    my ($this) = @_;
    # return undef if this segment is not APP13
    return undef unless $this->{name} eq 'APP13';
    # return undef if it does not contain an IPTC subdir
    return undef unless defined $this->search_record($IPTC_subdir_name);
    # return ok
    return "ok";
}

###########################################################
# This method returns the IPTC subdir record reference    #
# for the current APP13 segment (undef if not present).   #
###########################################################
sub retrieve_IPTC_subdirectory {
    my ($this) = @_;
    # return immediately if this is not an APP13 segment
    # containing IPTC information
    return undef unless $this->is_app13_IPTC();
    # return the IPTC subdirectory reference
    return $this->search_record($IPTC_subdir_name)->get_value();
}

###########################################################
# This method returns the IPTC subdir record reference for#
# the current APP13 segment. If the subdirectory is not   #
# there, it is first created and initialised. The routine #
# can fail (return undef) only if the segment isn't APP13.#
# If the subdirectory is created, the segment is updated. #
###########################################################
sub provide_IPTC_subdirectory {
    my ($this) = @_;
    # don't try to mess up non-APP13 segments!
    return undef unless $this->{name} eq 'APP13';
    # be positive, call retrieve first
    my $subdir = $this->retrieve_IPTC_subdirectory();
    # return this value, if it is not undef
    return $subdir if defined $subdir;
    # create the IPTC subdir in the main record dir of this segment
    $subdir = $this->provide_subdirectory($IPTC_subdir_name);
    # initialise the subdirectory with 'RecordVersion'. I don't
    # know why the standard says "4" here, but you always find "2".
    $this->store_record($subdir, 0, $UNDEF, \ "\000\002", 2);
    # obviously, update the segment
    $this->update();
    # return the subdirectory reference
    return $subdir;
}

###########################################################
# This method deletes all IPTC information from an APP13  #
# segment. This routine cannot fail (ha, ha ...). If the  #
# modification is actually made, the segment is updated.  #
###########################################################
sub remove_IPTC_subdirectory {
    my ($this) = @_;
    # return if there is nothing to erase
    return unless defined $this->is_app13_IPTC();
    # get a reference to the record list of the APP13 segment
    my $records = $this->{records};
    # this is simple and crude
    @$records = grep { $_->{key} ne $IPTC_subdir_name } @$records;
    # update the data area of the segment
    $this->update();
}

###########################################################
# This method returns a reference to a hash containing a  #
# copy of the list of IPTC records in the current segment,#
# if present, undef otherwise. Each hash element is a     #
# (key, arrayref) pair, where 'key' is an IPTC tag and    #
# 'arrayref' points to an array with the record values    #
# (since an IPTC tag can be repeateable, this array can   #
# actually contain more than one value). The $type argu-  #
# ment selects the output format:                         #
#  - NUMERIC: hash with native numeric keys               #
#  - TEXTUAL: hash with translated textual keys (default) #
# If a numerical IPTC key is not known, a custom textual  #
# key is created with "Unknown_tag_" followed by the nu-  #
# merical value (solves problem with non-standard tags).  #
# ------------------------------------------------------- #
# Note that there is no check at all on the validity of   #
# the IPTC record values: their format is not checked and #
# one or multiple values can be attached to a single key  #
# independently of the IPTC repeatability. This is, in    #
# some sense, consistent with the fact that also "unknown"#
# tags are included in the output.                        #
###########################################################
sub get_IPTC_data {
    my ($this, $type) = @_;
    # set the default type, if it is undefined
    $type = 'TEXTUAL' unless defined $type;
    # reject unknown types
    return undef unless $type =~ /^NUMERIC$|^TEXTUAL$/;
    # get the reference to the IPTC subdirectory (don't force)
    my $IPTC_array = $this->retrieve_IPTC_subdirectory();
    # return undef if the directory is not present
    return undef unless $IPTC_array;
    # create a hash, where the keys are the numeric keys of
    # @$IPTC_array and the values are array references. The arrays
    # pointed to by these references are then filled with the record
    # values, accumulating these values according to the tag.
    my %IPTC_data = map { $_->{key} => [] } @$IPTC_array;
    push @{$IPTC_data{$_->{key}}}, $_->get_value() for @$IPTC_array;
    # if the type is textual, the tags must be translated; if there
    # is no entry  in %IPTC_tags with key equal to $_, create a tag
    # carrying "Unknown_tag_" followed by the key numerical value.
    %IPTC_data = map {
	(exists $IPTC_tags{$_} ? $IPTC_tags{$_} : "Unknown_tag_$_")
	    => $IPTC_data{$_} } keys %IPTC_data if $type eq 'TEXTUAL';
    # return the magic scalar
    return \ %IPTC_data;
}

###########################################################
# This method accepts IPTC data in various formats and    #
# updates the IPTC subdirectory in the segment. The key   #
# type of each entry in the input %$data hash can be      #
# numeric or textual, independently of the others (the    #
# same key can appear in both forms, the corresponding    #
# values will be put together). The value of each entry   #
# can be an array reference or a scalar (you can use this #
# as a shortcut for value arrays with only one value).    #
# The $action argument can be: (default = REPLACE)        #
# - ADD : new records are added and nothing is deleted;   #
#      however, if you try to add a non-repeatable record #
#      which is already present, the newly supplied value #
#      replaces the pre-existing value.                   #
# - UPDATE : new records replace those characterised by   #
#      the same tags, but the others are preserved. This  #
#      makes it possible to modify repeatable records.    #
# - REPLACE : all records present in the IPTC subdirecto- #
#      ry are deleted before inserting the new ones.      #
# If, after implementing the changes required by $action, #
# the 'RecordVersion' record (dataset 0) is still unde-   #
# fined, it is added (with version = 2). The return value #
# is a reference to a hash containing the rejected key-   #
# values entries. The entries of %$data are not modified. #
# ------------------------------------------------------- #
# At the end, the segment data area is updated. An entry  #
# in the %$data hash can be rejected for various reasons: #
#  - the tag is textual or numeric and it is not known;   #
#  - the tag is numeric and not in the range 0-255;       #
#  - the entry value is an empty array;                   #
#  - the non-repeatable property is violated;             #
#  - the tag is marked as invalid;                        #
#  - the length of a value is invalid;                    #
#  - a value does not match its mandatory regular expr.   #
###########################################################
sub set_IPTC_data {
    my ($this, $data, $action) = @_;
    # return immediately if $data is not a hash reference
    return unless ref $data eq 'HASH';
    # set the default action, if it is undefined
    $action = 'REPLACE' unless defined $action;
    # complain about unknown actions
    die "Unknown action $action" unless $action =~ /ADD|UPDATE|REPLACE/;
    # prepare two hash references and initialise them to anonymous empty
    # hashes; they are going to contain accepted and rejected data
    my $data_accepted = {}; my $data_rejected = {};
    # populate both $data_accepted and $data_rejected. First, all entries
    # are accepted, exception made for those with unknown textual keys.
    # Also, all accepted entries have their keys forced to numeric form.
    for (keys %$data) {
	# get copies, do not manipulate original data!
	my ($tag, $value) = ($_, $$data{$_});
	# accept both array references and plain scalars
	$value = (ref $value) ?  [ @$value ] : [ $value ];
	# textual to numeric translation, if textual and known
	$tag = $IPTC_names{$tag} if exists $IPTC_names{$tag};
	# get a reference to the correct repository: an entry is accepted
	# if keys are numeric and known to the %IPTC_tags hash and if they
	# pass the value_is_OK test; rejected otherwise.
	my $repository = 
	    ( $tag =~ /^[0-9]*$/ && exists $IPTC_tags{$tag} &&
	      value_is_OK($tag, $value) ) ? $data_accepted : $data_rejected;
	# add data to the repository (do not overwrite!)
	$$repository{$tag} = [ ] unless exists $$repository{$tag};
	push @{$$repository{$tag}}, @$value; }
    # if $action is not 'REPLACE', old records need to be merged in;
    # take a copy of all current records if necessary
    my $oldrecs = $action =~ /REPLACE/ ? {} : $this->get_IPTC_data('NUMERIC');
    # loop over all entries in the %$oldrecs hash and insert them into the
    # new hash if necessary (the "old hash" is of course empty if $action
    # corresponds to 'REPLACE', so we are dealing with 'ADD' or 'UPDATE' here).
    while (my ($tag, $oldarrayref) = each %$oldrecs) {
	# a pre-existing tag must always remain, prepare a slot. 
	$$data_accepted{$tag} = [] unless exists $$data_accepted{$tag};
	# if the tag is already covered by the new values and the
	# requested action is 'UPDATE', do nothing ....
	my $newarrayref = $$data_accepted{$tag};
	next if @$newarrayref && $action =~ /UPDATE/;
	# ... otherwise (i.e., if $action is 'ADD' or $action is 'UPDATE'
	# but the tag is not overwritten by new values) insert the old
	# values at the beginning of the value array.
	unshift @$newarrayref, @$oldarrayref; }
    # the previous merging could have assigned more than one value to
    # non-repeatable records (for $action equal to 'ADD'). Solve this
    # problem, retaining only the last value in this case.
    shift_non_repeatables($data_accepted);
    # be sure that the 'RecordVersion' record (dataset 0) is present;
    # insert, if necessary (with version = 2) ?
    $$data_accepted{0} = [ "\000\002" ]
	unless exists $$data_accepted{0} && @{$$data_accepted{0}};
    # get and clear the IPTC subdirectory
    my $dirref = $this->provide_IPTC_subdirectory();
    @$dirref = ();
    # now all keys are surely valid and numeric. For each element
    # in the hash, create one or more Records corresponding to a
    # dataset and insert them into the appropriate subdirectory
    map { my $key = $_; map {
	# each element of the array in a hash element creates a new Record
	$this->store_record($dirref, $key, $ASCII, \ $_, length $_); }
	  # sort the Records on the numeric key
	  @{$$data_accepted{$_}} } sort { $a <=> $b } keys %$data_accepted;
    # remember to commit these changes to the data area
    $this->update();
    # return the reference of rejected tags/values
    return $data_rejected;
}

###########################################################
# This function "corrects" a hash of IPTC records violat- #
# ing some non-repeatable constraint. If a non-repeatable #
# record is found with multiple values, only the last one #
# is retained.                                            #
###########################################################
sub shift_non_repeatables {
    my ($hashref) = @_;
    # loop over all elements in the hash
    while (my ($tag, $arrayref) = each %$hashref) {
	# get the constraints of this record
	my $constraints = $HASH_IPTC_GENERAL{$tag};
	# skip unknown tags (this shouldn't happen) and repeatable records
	next unless $constraints && $$constraints[1] eq 'N';
	# retain only the last element of this non-repeatable record
	$$hashref{$tag} = [ $$arrayref[$#$arrayref] ] if @$arrayref != 1;
    }
}

###########################################################
# This function return true if a given value fits a given #
# IPTC tags, false otherwise. The input arguments are a   #
# numeric tag and an array reference, as usual.           #
###########################################################
sub value_is_OK {
    my ($tag, $arrayref) = @_;
    # $tag must be a numeric value in 0-255
    return undef unless $tag =~ /^\d*$/ && $tag < 256;
    # $arrayref must be an array reference
    return undef unless ref $arrayref && ref $arrayref eq 'ARRAY';
    # the referenced array must contain at least one element
    return undef unless @$arrayref;
    # if the tag is not known, everything is acceptable ...
    return 1 unless exists $IPTC_tags{$tag};
    # from now on, we study the content of $HASH_IPTC_GENERAL
    my $constraints = $HASH_IPTC_GENERAL{$tag};
    # if the tag is non-repeatable, accept exactly one element
    return undef if $$constraints[1] eq 'N' && @$arrayref != 1;
    # get the mandatory "regular expression" for this tag
    my $regex = $$constraints[4];
    # if $regex matches "invalid", inhibit this tag
    return undef if $regex =~ /invalid/;
    # if $regex matches "binary", everything is permitted
    return 1 if $regex =~ /binary/;
    # run the following tests on all values
    for (@$arrayref) {
	# each value length must fit the appropriate range
	return undef if (length $_ < $$constraints[2] || 
			 length $_ > $$constraints[3] );
	# each value must match the mandatory regular expression
	return undef unless /$regex/; }
    # all tests were successful! return success
    return 1;
}

# successful package load
1;
