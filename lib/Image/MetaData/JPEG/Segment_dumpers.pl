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
# GENERAL NOTICE: in general, all methods in this file    #
# correspond to methods in Segment_parsers.pl, i.e. each  #
# dump_* method corresponds to parse_* (with the same *,  #
# I mean :-). See these methods for further details. Only #
# non-trivial comments will be added here.                # 
###########################################################



###########################################################
# Dumping a comment block is very easy, because it con-   #
# tains only one plain ASCII record.                      #
###########################################################
sub dump_com {
    my ($this) = @_;
    # write the only record into the data area
    $this->set_data($this->search_record('Comment')->get_value(), "OVERWRITE");
}

###########################################################
# Entry point for dumping an APP1 segment. It decides     #
# between Exif APP1 and XMP and then dispatches to the    #
# correct subroutine (the identifier is not yet written). #
###########################################################
sub dump_app1 {
    my ($this) = @_;
    # get a reference to the segment record list
    my $records = $this->{records};
    # the first record can tell us the segment type
    my $first = $this->search_record("FIRST_RECORD");
    # If the first record is an 'Identifier' and it contains
    # the EXIF tag, this is a standard Exif segment
    return $this->dump_app1_exif() if ($first->{key} eq 'Identifier' &&
				       $first->get() eq $APP1_EXIF_TAG);
    # If the first record is a 'Namespace', this is an Adobe XMP segment
    die "Dumping XMP APP1" if $first->{key} eq 'Namespace';
    # Otherwise, we have a problem
    die "APP1 segment dump not possible";
}

###########################################################
# This method dumps an Exif APP1 segment. Basically, it   #
# dumps the identifier, the two IFDs and the thumbnail.   #
###########################################################
sub dump_app1_exif {
    my ($this) = @_;
    # dump the identifier and the TIFF header. Note that the offset
    # returned by dump_TIFF_header is the current position in the newly
    # written data area AFTER the identifier (i.e., the base is the base
    # of the TIFF header), so it does not start from zero but from the
    # value of $ifd0_link. Be aware that its meaning is slightly
    # different from $offset in the parser.
    my ($header, $offset, $endianness) = $this->dump_TIFF_header();
    $this->set_data($header, "OVERWRITE");
    # set the current endianness to what we have found.
    # Remember to reset it at the end of the method!!!
    my $old_endianness = $this->{endianness};
    $this->{endianness} = $endianness;
    # dump all the records of the 0th IFD, and update $offset to
    # point after the end of the current data area (with respect
    # to the TIFF header base). This must be done even if the IFD
    # itself is empty (in order to find the next one).
    $offset += $this->set_data($this->dump_ifd('IFD0', $offset));
    # same thing with the 1st IFD. We don't have to worry if this
    # IFD is not there, because dump_ifd tests for this case.
    $offset += $this->set_data($this->dump_ifd('IFD1', $offset));
    # if there is thumbnail data in the main directory of this
    # segment, it is time to dump it. Use the reference, because
    # this can be quite large (some tens of kilobytes ....)
    if (my $th_record = $this->search_record('ThumbnailData')) {
	(undef, undef, undef, my $tdataref) = $th_record->get();
	$this->set_data($tdataref); }
    # reset the current endianness to its old value
    $this->{endianness} = $old_endianness;
}

###########################################################
# This method reconstructs a TIFF header (including the   #
# prepended identifier) and returns a list with all the   #
# relevant values. Nothing is written to the data area.   #
###########################################################
sub dump_TIFF_header {
    my ($this) = @_;
    # retrieve the identifier, endianness, and signature. It is not
    # worth setting the temporary segment endianness here, do it later.
    my $identifier = $this->search_record('Identifier')->get();
    my $endianness = $this->search_record('Endianness')->get();
    my $signature  = $this->search_record('Signature' )->get($endianness);
    # the offset of the 0th IFD must in principle be recalculated,
    # although chances are that it corresponds to the value of the
    # 'IFD0_Pointer' record (which should be 8).
    my $ifd0_len  = (length $endianness) + (length $signature) + 4;
    # create a string with the identifier and the TIFF header
    my $ifd0_link = pack $endianness eq $BIG_ENDIAN ? "N" : "V", $ifd0_len;
    my $header = $identifier . $endianness . $signature . $ifd0_link;
    # return all relevant values in a list
    return ($header, $ifd0_len, $endianness);
}

###########################################################
# This is the core of the Exif APP1 dumping method. It    #
# takes care to dump a whole IFD, including a special     #
# treatement for tags holding an offset, which is now     #
# most probably invalid. No action is taken unless there  #
# is already a directory for this IFD in the structured   #
# data area of the segment.                               #
###########################################################
sub dump_ifd {
    my ($this, $dirnames, $offset) = @_;
    # retrieve the appropriate record list (specified by a '@' separated
    # list of dir names in $dirnames to be interpreted in sequence). Do
    # not create a directory if it is not there! (so, you cannot use
    # provide_subdirectory here). But we must return a valid reference.
    my $dirref = undef; for (split /@/, $dirnames) {
	return \ "" unless $dirref = $this->search_record($_, $dirref);
	return \ "" unless $dirref = $dirref->get_value(); }
    # retrieve the record list for this IFD, then eliminate the
    # REFERENCE records (added by the parser routine, they were
    # not in the JPEG file) and sort the remaining records with
    # respect to their tags (numeric). This is not, strictly
    # speaking mandatory, but the file looks more polished after
    # this. $short and $long are two useful format strings
    # correctly taking into account the IFD endianness. $format
    # is a format string for packing an Interoperability array
    my @records = sort { $a->{key} <=> $b->{key} }
                         grep { $_->{type} != $REFERENCE } @$dirref;
    my $short   = $this->{endianness} eq $BIG_ENDIAN ? 'n' : 'v';
    my $long    = $this->{endianness} eq $BIG_ENDIAN ? 'N' : 'V';
    my $format  = $short. $short . $long;
    # the IFD data area is to be initialised with two bytes specifying
    # the number of Interoperability arrays. Data not fitting an
    # Interop array will be saved in $extra; $remote should point 
    # to its beginning (from TIFF header base), so we must skip 12
    # bytes for each Interop. array, 2 bytes for the initial count
    # and 4 bytes for the "next IFD" link.
    my $ifd_content = pack $short, scalar @records;
    my $remote = $offset + 2 + 12 * (scalar @records) + 4;
    my $extra  = "";
    # managing the thumbnail is not trivial. We want to be sure that
    # its declared size corresponds to the reality and correct if
    # this is not the case (is this a stupid idea?)
    if ($dirnames eq 'IFD1' &&
	(my $th_record = $this->search_record('ThumbnailData'))) {
	(undef, undef, undef, my $tdataref) = $th_record->get();
	for ($APP1_THTIFF_LENGTH, $APP1_THJPEG_LENGTH) {
	    my $th_len = $this->search_record($_, $dirref);
	    $th_len->set_value(length $$tdataref) if $th_len; } }
    # the following tags can be found only in IFD1 in APP1, and concern
    # the thumbnail location. They must be dealt with in a special way.
    my %th_tags = ($APP1_THTIFF_OFFSET => undef, $APP1_THJPEG_OFFSET => undef);
    # loop on all selected records and dump them
    for my $record (@records) {
	# extract all necessary information about this
	# Interoperability array, with the correct endianness.
	my ($tag, $type, $count, $dataref) = $record->get($this->{endianness});
	# calculate the length of the array data, and correct $count
	# for string-like records (it had been set to 1 during the
	# parsing, it must be the data length in this case).
	my $length = length $$dataref;
	$count = $length if $record->get_category() eq 'S';
	# the interoperability array starts with tag, type and count;
	# additional data could be stored in another place.
	$ifd_content .= pack $format, $tag, $type, $count;
	# if this Interop array specifies the thumbnail location, it needs
	# a special treatment, since we cannot yet know where the thumbnail
	# will be located. Write a bogus offset now and overwrite it later.
	if (exists $th_tags{$tag}) {
	    $th_tags{$tag} = length $ifd_content;
	    $ifd_content .= "\000\000\000\000"; }
	# if this Interop array is known to correspond to a subdirectory
	# (thanks to %IFD_SUBDIRS), the subdirectory content is calculated
	# on the fly, and stored in this IFD's remote data area. Its offset
	# instead is saved at the end of the Interoperability array.
	elsif (exists $IFD_SUBDIRS{$tag}) {
	    $ifd_content .= pack $long, $remote;
	    my $subifd    = $this->dump_ifd($IFD_SUBDIRS{$tag}, $remote);
	    $extra  .= $$subifd;
	    $remote += length $$subifd; }
	# if the data length is not larger than four bytes, we are ok.
	# $$dataref is simply appended (with padding up to 4 bytes,
	# AFTER $$dataref, independently of the IFD endianness).
	elsif ($length <= 4) {
	    $ifd_content .= $$dataref;
	    $ifd_content .= "\000" x (4 - $length); }
	# if $$dataref is too big, it must be packed in the $extra
	# section, and its pointer appended here. Remember to update
	# $remote for the next record of this type.
	else {
	    $ifd_content .= pack $long, $remote;
	    $remote += $length;
	    $extra  .= $$dataref; }
    }
    # after the Interop. arrays there can be a link to the next IFD;
    # this takes 4 bytes (equal to 0 if there is no next IFD). We need
    # it really only at the end of IFD0 to point to IFD1 if present.
    my $need_next_link = $dirnames eq 'IFD0' && $this->search_record('IFD1');
    $ifd_content .= pack $long, ($need_next_link ? $remote : 0);
    # then, we save the remote data area
    $ifd_content .= $extra;
    # if the thumbnail offset tags were found during the scan, we
    # need to overwrite their values with a meaningful offset now.
    for (keys %th_tags) {
	next unless my $overwrite = $th_tags{$_};
	my $tag_record = $this->search_record($_, $dirref);
	$tag_record->set_value($remote);
	my $new_offset = $tag_record->get($this->{endianness});
	substr($ifd_content, $overwrite, length $new_offset) = $new_offset;
    }
    # return a reference to the scalar which holds the binary dump
    # of this IFD (to be saved in the caller routine, I think).
    return \$ifd_content;
}

###########################################################
# This routine dumps the Adobe identifier and then enters #
# a loop on the resource data block dumper, till the end. #
# TODO: implement dumping of multiple blocks!!!!          #
###########################################################
sub dump_app13 {
    my ($this) = @_;
    # get a reference to the segment record list
    my $records = $this->{records};
    # the segment always starts with the Adobe identifier
    my $first = $this->search_record("FIRST_RECORD");
    die "Malformed APP13 segment (1)" if $first->{key} ne 'Identifier';
    $this->set_data(scalar $first->get(), "OVERWRITE");
    # dump all the remaining resource data block records
    $this->dump_resource_data_block($_)
	for grep { $_->{key} ne 'Identifier'; } @$records;
}

###########################################################
# TODO: implement dumping of multiple blocks!!!!          #
###########################################################
sub dump_resource_data_block {
    my ($this, $record) = @_;
    # dump the Adobe Photoshop identifier
    $this->set_data($APP13_PHOTOSHOP_TYPE);
    # dump the block identifier, which is either the numeric tag of
    # the record (as a 2-byte unsigned integer) for a generic record,
    # or $APP13_PHOTOSHOP_IPTC for IPTC data (in this case, the
    # record is a reference to a subdirectory).
    $this->set_data(pack "n", ($record->{type} == $REFERENCE) ?
		    $APP13_PHOTOSHOP_IPTC : $record->{key});
    # the block name is usually "\000"; if it is not trivial, it was
    # saved in the "extra" record field. Retrieve it, then calculate
    # its official length, then pad it so that storing the name length
    # (1 byte) + $name + padding takes an even number of bytes
    my $name = defined $record->{extra} ? $record->{extra} : "";
    my $name_length = length $name;
    my $padding = ($name_length % 2) == 0 ? "\000" : "";
    $this->set_data(pack("C", $name_length) . $name . $padding);
    # if we are dealing with an IPTC data block, retrieve the whole
    # encoded block as a single string with a separate routine.
    # Otherwise, $block is simply the record dump.
    my $data = ($record->{type} == $REFERENCE) ?
	$this->dump_IPTC_datasets($record) : $record->get();
    # the next four bytes encode the resource data size. Also in this
    # case the total size must be padded to an even number of bytes
    my $data_length = length $data;
    $data .= "\000" if ($data_length % 2) == 1;
    $this->set_data(pack("N", $data_length));
    $this->set_data($data);
}

###########################################################
# This method dumps all datasets from an APP13 IPTC re-   #
# cord into a string, which is returned at the end. The   #
# argument is the REFERENCE record pointing to the IPTC   #
# datasets. See parse_IPTC_dataset for details.           #
###########################################################
sub dump_IPTC_datasets {
    my ($this, $record) = @_;
    # prepare the scalar to be returned at the end
    my $block = "";
    # get the subdirectory reference (a reference to the record list)
    my $records = $record->get();
    # Each record is a sequence of variable length data sets. Each
    # dataset begins with a "tag marker" (its value is fixed) followed
    # by a "record number" (fixed to 2; here "record" means "IPTC record",
    # not our objects), followed by the dataset number, length and data.
    for (@$records) {
	my ($dnumber, $type, $count, $dataref) = $_->get();
	$block .= pack "CCCn", ($APP13_IPTC_TAGMARKER, 2,
				$dnumber, length $$dataref);
	$block .= $$dataref;
    }
    # return the encoded datasets
    return $block;
}

# successful package load
1;
