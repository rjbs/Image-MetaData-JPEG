###########################################################
# A Perl package for showing/modifying JPEG (meta)data.   #
# Copyright (C) 2004,2005 Stefano Bettelli                #
# See the COPYING and LICENSE files for license terms.    #
###########################################################
package Image::MetaData::JPEG;
use Image::MetaData::JPEG::Tables qw(:Lookups :TagsAPP13);
use Image::MetaData::JPEG::Segment;
no  integer;
use strict;
use warnings;

###########################################################
# This method returns a reference to the $index-th (the   #
# first, if $index is undefined) Photoshop-like APP13     #
# segment which contains information matching the $what   #
# argument ($what can be only 'IPTC' or 'PHOTOSHOP', the  #
# former being the default). If $index is undefined, it   #
# defaults to zero (i.e., first segment). If the required #
# segment does not exist, undef is returned. If $index is #
# (-1), this method returns the number of available       #
# suitable APP13 segments (which is >= 0). If $what is    #
# invalid, an exception is thrown. Beware!, the meaning   #
# of $index is influenced by the value of $what.          #
###########################################################
sub retrieve_app13_segment {
    my ($this, $index, $what) = @_;
    # $index defaults to zero if undefined
    $index = 0 unless defined $index;
    # select all segments compatible with $what
    my @references = grep { $_->is_app13_ok($what) } $this->get_segments();
    # if $index is -1, return the size of @references
    return scalar @references if $index == -1;
    # return the $index-th such segment, or undef if absent
    return exists $references[$index] ? $references[$index] : undef;
}

###########################################################
# This method forces an appropriate Photoshop-like APP13  #
# segment to be present in the file, and returns its      #
# reference. If at least one segment matching $what is    #
# already present, the first one is returned. Otherwise,  #
# the first Photoshop-like APP13 is adapted by inserting  #
# an appropriate subdirectory record (update() is called  #
# automatically). If not such segment exists, it is first #
# created and inserted. $what defaults to 'IPTC' if unde- #
# fined. If $what is invalid, an exception is thrown.     #
###########################################################
sub provide_app13_segment {
    my ($this, $what) = @_;
    # get the list of segments selected by $what
    my @what_refs = grep { $_->is_app13_ok($what) } $this->get_segments();
    # if the list is not empty, return the first element
    return $what_refs[0] if @what_refs;
    # get the list of Photoshop-like segments (this only looks
    # for the Photoshop identifier, special case of $what = undef);
    # then extract the first element.
    my @refs = grep { $_->is_app13_ok(undef) } $this->get_segments();
    my $app13_segment = @refs ? $refs[0] : undef;
    # if no segment is found, we surely need to generate a new
    # one, and store it in an appropriate position in the file;
    # remember that at least the Photoshop string must be there
    unless ($app13_segment) {
	$app13_segment = new Image::MetaData::JPEG::Segment
	    ('APP13', \ "$$APP13_PHOTOSHOP_IDS[0]");
	# insert it into the list of JPEG segments
	# (the position is chosen automatically)
	$this->insert_segments($app13_segment); }
    # ok, we must adapt the Photoshop-like segment (automatic update())
    $app13_segment->provide_app13_subdir($what);
    # return the modified segment
    return $app13_segment;
}

###########################################################
# This method removes all traces of IPTC/non-IPTC infor-  #
# mation (depending on $what) from the $index-th APP13    #
# Photoshop-style Segment. If, after this, the segment is #
# empty, it is eliminated from the list of segments in    #
# the file. If $index is (-1), all segments are affected  #
# at once. If $what is invalid an exception is thrown.    #
# The meaning of $index depends on $what.                 #
###########################################################
sub remove_app13_info {
    my ($this, $index, $what) = @_;
    # this is the list of segments to be purged (initially empty)
    my @purgeme = ();
    # call the selection routine and store the segment reference
    push @purgeme, $this->retrieve_app13_segment($index, $what);
    # if $index is -1, retrieve_... returned the number of
    # segments to be purged, not a segment reference! In this
    # case, the selection routine is repeated with every index.
    @purgeme = map { $this->retrieve_app13_segment($_, $what)
		     } (0..($purgeme[$#purgeme]-1)) if $index == -1;
    # for each segment in the purge list, apply the purge routine
    # (but don't be fooled by undefined references, i.e. invalid
    # indexes). If only one record remains in the segment (presumably
    # the Identifier), the segment is marked for a later deletion.
    for (@purgeme) {
	next unless defined $_;
	$_->remove_app13_info($what);
	$_->{name} = 'deleteme' if scalar @{$_->{records}} <= 1; }
    # remove the marked segments from the file
    $this->drop_segments('deleteme');
}

###########################################################
# This method is an interface to the method with the same #
# name in the Segment class. To begin with, the first     #
# suitable APP13 segment is retrieved (if there is no     #
# such segment, undef is returned). Then, get_app13_data  #
# is called on this segment, passing all the arguments    #
# through. If $what is invalid an exception is thrown     #
# out. For further details, have a look at                #
# Segment::get_app13_data() and retrieve_app13_segment(). #
###########################################################
sub get_app13_data {
    my ($this, $type, $what) = @_;
    # get the first suitable APP13 segment in the current JPEG
    # file (this returns undef if no segment is present).
    my $segment = $this->retrieve_app13_segment(undef, $what);
    # return undef if no segment is present
    return undef unless defined $segment;
    # pass all arguments to the Segment method
    return $segment->get_app13_data($type, $what);
}

###########################################################
# This method is an interface to the method with the same #
# name in the Segment class. To begin with, the first     #
# suitable APP13 segment is retrieved (if there is no     #
# such segment, one is created and initialised). Then the #
# set_app13_data is called on this segment passing the    #
# arguments through. For further details, have a look at  #
# Segment::set_app13_data() and provide_app13_segment().  #
###########################################################
sub set_app13_data {
    my ($this, $data, $action, $what) = @_;
    # get the first suitable APP13 segment in the current JPEG file
    # (if there is no such segment, initialise one; therefore, this
    # call cannot fail unless $what is invalid [mhh ...]).
    my $segment = $this->provide_app13_segment($what);
    # pass all arguments to the Segment method
    return $segment->set_app13_data($data, $action, $what);
}

###########################################################
# The following routines best fit as Segment methods.     #
###########################################################
package Image::MetaData::JPEG::Segment;

###########################################################
# These helper functions have a single argument. They fix #
# it to some standard value, if it is undefined, then     #
# they check that its value is a legal string and throw   #
# an exception out if not so.                             #
# ------------------------------------------------------- #
# sanitise: 0=this, 1=var, 2=name, 3=regex(1st is default)#
###########################################################
sub sanitise_what   { sanitise(@_, 'what'  , 'IPTC|PHOTOSHOP'    ) };
sub sanitise_type   { sanitise(@_, 'type'  , 'TEXTUAL|NUMERIC'   ) };
sub sanitise_action { sanitise(@_, 'action', 'REPLACE|ADD|UPDATE') };
sub sanitise { ($_[1] = $_[3]) =~ s/^([^\|]*)\|.*$/$1/ unless defined $_[1];
	       ($_[1] =~/^($_[3])$/) ?1: $_[0]->die("Unknown '$_[2]': $_[1]")};
sub subdir_name { return $APP13_IPTC_DIRNAME      if $_[0] eq 'IPTC';
		  return $APP13_PHOTOSHOP_DIRNAME if $_[0] eq 'PHOTOSHOP'; };

###########################################################
# This method inspects a segments, and return "ok" if the #
# segment shows the required features, undef otherwise.   #
# The features are selected by the value of $what:        #
# 1) ($what is undefined) the segment is an APP13 segment #
#    and it contains the correct 'Identifier' record.     #
# 2) ($what eq 'PHOTOSHOP') matches 1) and contains an    #
#    $APP13_PHOTOSHOP_DIRNAME subdirectory.               #
# 3) ($what eq 'IPTC') matches 1) and contains an         #
#    $APP13_IPTC_DIRNAME subdirectory.                    #
# 4) (everything else) the routine dies.                  #
###########################################################
sub is_app13_ok {
    my ($this, $what) = @_;
    # intercept and die on unknown $what's (don't set a default!)
    $this->sanitise_what(my $temp_what = $what);
     # return undef if this segment is not APP13
    return undef unless $this->{name} eq 'APP13';
    # return undef if there is no 'Identifier' or it is not Photoshop
    my $id = $this->search_record_value('Identifier');
    return undef unless $id && grep { /^$id$/ } @$APP13_PHOTOSHOP_IDS;
    # if $what is undefined we are happy
    return 'ok' unless defined $what;
    # return "ok" if $what is defined and the appropriate subdir is there
    return 'ok' if defined $this->search_record(subdir_name($what));
    # fallback
    return undef;
}

###########################################################
# This method returns the IPTC or PHOTOSHOP subdir record #
# reference for the current APP13 Photoshop-like segment  #
# (undef is returned if it is not present).               #
###########################################################
sub retrieve_app13_subdir {
    my ($this, $what) = @_;
    # die on unknown $what's (default --> 'IPTC' if undefined)
    $this->sanitise_what($what);
    # return immediately if the segment is not suitable
    return undef unless $this->is_app13_ok($what);
    # return the IPTC subdirectory reference
    return $this->search_record_value(subdir_name($what));
}

###########################################################
# This method returns the IPTC or PHOTOSHOP subdir record #
# reference for the current Photoshop-style APP13 segment.#
# If the subdirectory is not there, it is first created   #
# and initialised. The routine can fail (returning undef) #
# only if the segment isn't a Photoshop-style segment.    #
# If the subdirectory is created, the segment is updated. #
###########################################################
sub provide_app13_subdir {
    my ($this, $what) = @_;
    # die on unknown $what's (default --> 'IPTC' if undefined)
    $this->sanitise_what($what);
    # don't try to mess up non-APP13 segments!
    return undef unless $this->is_app13_ok(undef);
    # be positive, call retrieve first
    my $subdir = $this->retrieve_app13_subdir($what);
    # return this value, if it is not undef
    return $subdir if defined $subdir;
    # create the appropriate subdir in the main record dir of this segment
    $subdir = $this->provide_subdirectory(subdir_name($what));
    # if $what is 'IPTC', initialise the subdir with 'RecordVersion'.
    # I don't know why the standard says 4 here, but you always find 2.
    $this->store_record($subdir,0, $UNDEF, \ "\000\002", 2) if $what eq 'IPTC';
    # obviously, update the segment
    $this->update();
    # return the subdirectory reference
    return $subdir;
}

###########################################################
# This method removes all traces of IPTC/non-IPTC infor-  #
# mation (depending on $what) from the $index-th APP13    #
# Photoshop-style Segment. This routine cannot fail,      #
# unless $what is invalid. The segment gets updated if    #
# the modification is made.                               #
###########################################################
sub remove_app13_info {
    my ($this, $what) = @_;
    # die on unknown $what's (default --> 'IPTC' if undefined)
    $this->sanitise_what($what);
    # return if there is nothing to erase
    return unless $this->is_app13_ok($what);
    # these approach is simple and crude
    @{$this->{records}} =
	grep { $_->{key} ne subdir_name($what) } @{$this->{records}};
    # update the data area of the segment
    $this->update();
}

###########################################################
# This method returns a reference to a hash containing a  #
# copy of the list of Photoshop or IPTC records (selected #
# by $what) in the current segment, if present, undef     #
# otherwise. Each hash element is a (key, arrayref) pair, #
# where 'key' is a Photoshop or IPTC tag and 'arrayref'   #
# points to an array with the record values. The $type    #
# argument selects the output format:                     #
#  - NUMERIC: hash with native numeric keys               #
#  - TEXTUAL: hash with translated textual keys (default) #
# If $type or $what is invalid, an exception is thrown.   #
# If a numerical key (tag) is not known, a custom textual #
# key is created with 'Unknown_tag_' followed by the nu-  #
# merical value (solves problem with non-standard tags).  #
# ------------------------------------------------------- #
# Since an IPTC tag can be repeateable, @$arrayref can    #
# actually contain more than one value. Moreover, if      #
# $what is PHOTOSHOP, resource block names are appended   #
# (so, the @$arrayref length is always even in this case, #
# and almost always equal to two).                        #
# ------------------------------------------------------- #
# Note that there is no check at all on the validity of   #
# the Photoshop/IPTC record values: their format is not   #
# checked and one or multiple values can be attached to   #
# a single key independently of its repeatability. This   #
# is, in some sense, consistent with the fact that also   #
# "unknown" tags are included in the output.              #
###########################################################
sub get_app13_data {
    my ($this, $type, $what) = @_;
    # die on unknown $type's (default --> 'TEXTUAL' if undefined)
    $this->sanitise_type($type);
    # die on unknown $what's (default --> 'IPTC' if undefined)
    $this->sanitise_what($what);
    # retrieve the appropriate records list
    my $records = $this->retrieve_app13_subdir($what);
    # return undef if the directory is not present
    return undef unless $records;
    # this is the data hash to be filled
    my $data = {};
    # create a hash, where the keys are the numeric keys of @$records
    # and the values are references to (initially empty) arrays.
    $$data{$_} = [] for map { $_->{key} } @$records;
    # These arrays are then filled with the record values,
    # accumulated according to the tag.
    push @{$$data{$_->{key}}}, $_->get_value() for @$records;
    # if $what is 'PHOTOSHOP', append the "extra" values for each
    # record, according to the tag (this is undef, mostly).
    if ($what eq 'PHOTOSHOP') {
	push @{$$data{$_->{key}}}, $_->{extra} for @$records; }
    # if the type is textual, the tags must be translated;
    # if there is no positive match from JPEG_lookup, create a tag
    # carrying 'Unknown_tag_' followed by the key numerical value.
    %$data = map { my $match = JPEG_lookup('APP13', subdir_name($what),$_);
		   (defined $match ? $match : "Unknown_tag_$_")
		       => $$data{$_} } keys %$data if $type eq 'TEXTUAL';
    # return the magic scalar
    return $data;
}

###########################################################
# This method accepts Photoshop data in various formats   #
# and updates the content of a Photoshop-style APP13      #
# segment. The key type of each entry in the input %$data #
# hash can be numeric or textual, independently of the    #
# others (the same key can appear in both forms, the      #
# corresponding values will be put together). The value   #
# of each entry can be an array reference or a scalar     #
# (you can use this as a shortcut for value arrays with   #
# only one value). The $action argument can be:           #
# - ADD : new records are added and nothing is deleted;   #
#      however, if you try to add a non-repeatable record #
#      which is already present, the newly supplied value #
#      replaces the pre-existing value.                   #
# - UPDATE : new records replace those characterised by   #
#      the same tags, but the others are preserved. This  #
#      makes it possible to modify repeatable records.    #
# - REPLACE : [default] all records in the relevant       #
#      subdir are deleted before inserting the new ones.  #
# The return value is a reference to a hash containing    #
# the rejected key-values entries. The entries of %$data  #
# are not modified.                                       #
# ------------------------------------------------------- #
# If $what is 'IPTC' and, after implementing the changes  #
# required by $action, the 'RecordVersion' record is      #
# still undefined, it is added (with version = 2).        #
# If $what is 'PHOTOSHOP', UPDATE is a synonim of 'ADD',  #
# and the second value is used as data block name.        #
# ------------------------------------------------------- #
# At the end, the segment data area is updated. An entry  #
# in the %$data hash may be rejected for various reasons: #
#  - the tag is undefined or not known;                   #
#  - the entry value is undef or points to an empty array;#
#     [IPTC only]:                                        #
#  - the non-repeatable property is violated;             #
#  - the tag is marked as invalid;                        #
#  - a value is undefined;                                #
#  - the length of a value is invalid;                    #
#  - a value does not match its mandatory regular expr.   #
###########################################################
sub set_app13_data {
    my ($this, $data, $action, $what) = @_;
    # die on unknown $action's (default --> 'REPLACE' if undefined)
    $this->sanitise_action($action);
    # die on unknown $what's (default --> 'IPTC' if undefined)
    $this->sanitise_what($what);
    # return immediately if $data is not a hash reference
    return unless ref $data eq 'HASH';
    # collapse UPDATE into ADD if $what is PHOTOSHOP
    $action = 'ADD' if $what eq 'PHOTOSHOP' && $action eq 'UPDATE';
    # prepare two hash references and initialise them to anonymous empty
    # hashes; they are going to contain accepted and rejected data
    my $data_accepted = {}; my $data_rejected = {};
    # Populate both $data_accepted and $data_rejected. Force the
    # keys of all accepted entries to be numeric. Also, force an
    # ordering on %$data; this is necessary because the same key
    # can be present twice, in numeric and textual form, and we want
    # the corresponding value merging to be stable (numeric goes first)
    for (sort keys %$data) {
	# get copies, do not manipulate original data!
	my ($tag, $value) = ($_, $$data{$_});
	# accept both array references and plain scalars
	$value = (ref $value) ?  [ @$value ] : [ $value ];
	# if $tag is not numeric, try a textual to numeric
	# translation; (but don't set it to an undefined value yet)
	if (defined $tag && $tag !~ /^\d*$/) {
	    my $value = JPEG_lookup('APP13', subdir_name($what), $tag);
	    $tag = $value if defined $value; }
	# get a reference to the correct repository: an entry is
	# accepted if it passes the value_is_OK test, rejected otherwise.
	my $repository = value_is_OK($tag, $value, $what) ?
	    $data_accepted : $data_rejected;
	# add data to the repository (do not overwrite!)
	$$repository{$tag} = [ ] unless exists $$repository{$tag};
	push @{$$repository{$tag}}, @$value; }
    # if $action is not 'REPLACE', old records need to be merged in;
    # take a copy of all current records if necessary
    my $oldrecs = $action eq 'REPLACE' ? {} :
	$this->get_app13_data('NUMERIC', $what);
    # loop over all entries in the %$oldrecs hash and insert them into the
    # new hash if necessary (the "old hash" is of course empty if $action
    # corresponds to 'REPLACE', so we are dealing with 'ADD' or 'UPDATE' here).
    while (my ($tag, $oldarrayref) = each %$oldrecs) {
	# a pre-existing tag must always remain, prepare a slot. 
	$$data_accepted{$tag} = [] unless exists $$data_accepted{$tag};
	# if the tag is already covered by the new values and the
	# $action is 'UPDATE' or $what is 'PHOTOSHOP', do nothing
	# (I am assuming that 'PHOTOSHOP' is non-repeatable)
	my $newarrayref = $$data_accepted{$tag};
	next if @$newarrayref && ($action eq 'UPDATE' || $what eq 'PHOTOSHOP');
	# ... otherwise (i.e., if $action is 'ADD' or $action is 'UPDATE'
	# but the tag is not overwritten by new values) insert the old
	# values at the beginning of the value array.
	unshift @$newarrayref, @$oldarrayref; }
    # get and clear the appropriate records directory
    my $dirref = $this->provide_app13_subdir($what);
    @$dirref = ();
    ############ PHOTOSHOP records ##################
    if ($what eq 'PHOTOSHOP') {
	# do not accept the IPTC/NAA tag: it must be set with $what eq 'IPTC'
	$$data_rejected{$APP13_PHOTOSHOP_IPTC} =
	    scalar delete $$data_accepted{$APP13_PHOTOSHOP_IPTC}
	if exists $$data_accepted{$APP13_PHOTOSHOP_IPTC};
	# this is quite simple; for each key, create a resource data
	# block with the first value. If there is a second value,
	# set "extra"; sort the Records on the numeric key
	for my $key (sort {$a<=>$b} keys %$data_accepted) {
	    my $arrayref = $$data_accepted{$key};
	    # resource data block value (the Record obj. is in @$dirref)
	    my $vref = \ $$arrayref[0];
	    $this->store_record($dirref, $key, $UNDEF, $vref, length $$vref);
	    # resource data block extra (the Record obj. is in @$dirref)
	    $this->search_record('LAST_RECORD', $dirref)->{extra} =
		$$arrayref[1] if exists $$arrayref[1]; } }
    ############ IPTC records #######################
    if ($what eq 'IPTC') {
	# the previous merging could have assigned more than one value to
	# non-repeatable records (for $action equal to 'ADD'). Solve this
	# problem, retaining only the last value in this case.
	shift_non_repeatables($data_accepted);
	# be sure that the 'RecordVersion' record (dataset 0) is present;
	# insert, if necessary (with version = 2) ?
	$$data_accepted{0} = [ "\000\002" ]
	    unless exists $$data_accepted{0} && @{$$data_accepted{0}};
	# now all keys are surely valid and numeric. For each element
	# in the hash, create one or more Records corresponding to a
	# dataset and insert them into the appropriate subdirectory
	# sort the Records on the numeric key
	for my $key (sort {$a<=>$b} keys %$data_accepted) {
	    # each element of the array in a hash
	    # element creates a new Record
	    $this->store_record($dirref, $key, $ASCII, \ $_, length $_)
		for @{$$data_accepted{$key}}; } }
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
	my $constraints = JPEG_lookup('APP13@__syntax_IPTC', $tag);
	# skip unknown tags (this shouldn't happen) and repeatable records
	next unless $constraints && $$constraints[1] eq 'N';
	# retain only the last element of this non-repeatable record
	$$hashref{$tag} = [ $$arrayref[$#$arrayref] ] if @$arrayref != 1;
    }
}

###########################################################
# This function return true if a given value fits a given #
# IPTC tags, false otherwise. The input arguments are a   #
# numeric tag and an array reference, as usual. + $what   #
###########################################################
sub value_is_OK {
    my ($tag, $arrayref, $what) = @_;
    # $tag must be defined
    return undef unless defined $tag;
    # $tag must be a numeric value
    return undef unless $tag =~ /^\d*$/;
    # $arrayref must be an array reference
    return undef unless ref $arrayref && ref $arrayref eq 'ARRAY';
    # the referenced array must contain at least one element
    return undef unless @$arrayref;
    # if the tag is not known, it is not acceptable
    return undef unless JPEG_lookup('APP13', subdir_name($what), $tag);
    # it $what is 'PHOTOSHOP', the number of values can be 1 or 2
    return undef if $what eq 'PHOTOSHOP' && scalar @$arrayref > 2;
    # .... moreover, the first value cannot be undefined
    return undef if $what eq 'PHOTOSHOP' && ! defined $$arrayref[0];
    # the following tests apply only to IPTC data
    return 1 unless $what eq 'IPTC';
    # from now on, we study the content of the IPTC syntax hash
    my $constraints = JPEG_lookup('APP13@__syntax_IPTC', $tag);
    # if the tag is non-repeatable, accept exactly one element
    return undef if $$constraints[1] eq 'N' && @$arrayref != 1;
    # get the mandatory "regular expression" for this tag
    my $regex = $$constraints[4];
    # if $regex matches 'invalid', inhibit this tag
    return undef if $regex =~ /invalid/;
    # run the following tests on all values
    for (@$arrayref) {
	# each value must be defined
	return undef unless defined $_;
	# each value length must fit the appropriate range
	return undef if (length $_ < $$constraints[2] || 
			 length $_ > $$constraints[3] );
	# each value must match the mandatory regular expression;
	# but, if $regex matches 'binary', everything is permitted
	return undef unless /$regex/ || $regex =~ /binary/; }
    # all tests were successful! return success
    return 1;
}

# successful package load
1;
