###########################################################
# A Perl package for showing/modifying JPEG (meta)data.   #
# Copyright (C) 2004 Stefano Bettelli                     #
# See the COPYING and LICENSE files for license terms.    #
###########################################################
package Image::MetaData::JPEG;
use Image::MetaData::JPEG::Segment;
no  integer;
use strict;
use warnings;

###########################################################
# This method is for display/debug pourpouse. It returns  #
# a string describing the details of the structure of the #
# JPEG file linked to the current object. It can ask      #
# details to sub-objects.                                 #
###########################################################
sub get_description {
    my ($this) = @_;
    # prepare the string to be returned and store
    # a bar and the associated filename
    my $description = "Original JPEG file: $this->{filename}\n";
    # Print the image size
    $description .= sprintf "(%dx%d)\n", $this->get_dimensions();
    # Loop over all segments (use the order of the array)
    my $segments = $this->{segments};
    $description .= $_->get_description() foreach (@$segments);
    # return the string which was cooked up
    return $description;
}

###########################################################
# This method returns the image size from two specific    #
# record values in the SOF segment. The return value is   #
# (x-dimension, y- dimension). If there is no SOF segment #
# (or more than one), the return value is (0,0). In this  #
# case one should investigate, because this is not normal.#
#=========================================================#
# Ref: .... ?                                             #
###########################################################
sub get_dimensions {
    my ($this) = @_;
    # find the start of frame segments
    my @sofs = $this->get_segments("SOF");
    # if there is more than one such segment, there is something
    # wrong. In this case it is better to return (0,0) and debug.
    return (0,0) if (scalar @sofs) != 1;
    # same if there is an error in the segment
    my $segment = $sofs[0];
    return (0,0) if $segment->{error};
    # if the segment is OK, retrieve the x and y dimension from
    # two specific records: 'MaxSamplesPerLine' and 'MaxLineNumber'
    return ( $segment->search_record('MaxSamplesPerLine')->get_value(),
	     $segment->search_record('MaxLineNumber')->get_value() );
}

###########################################################
# This method returns a reference to a hash with the con- #
# tent of the APP0 segments (a plain translation of the   #
# segment content). Segments with errors are excluded.    #
# Note that some keys may be overwritten by the values of #
# the last segment, and that an empty hash means that no  #
# valid APP0 segment is present. See Segment::parse_app0  #
# for further details.                                    #
#=========================================================#
#     JFIF          JFXX          JFXX          JFXX      #
#               (RGB 1 byte)  (RGB 3 bytes)    (JPEG)     #
#   Identifier   Identifier    Identifier    Identifier   #
#  MajorVersion ExtensionCode ExtensionCode ExtensionCode #
#  MinorVersion  XThumbnail    XThumbnail   JPEGThumbnail #
#     Units      YThumbnail    YThumbnail                 #
#    XDensity   ColorPalette 3BytesThumbnail              #
#    YDensity  1ByteThumbnail                             #
#   XThumbnail                                            #
#   YThumbnail                                            #
#  ThumbnailData                                          #
###########################################################
sub get_app0_data {
    my ($this) = @_;
    # prepare the hash to be returned at the end
    my %data = ();
    # find the APP0 segments
    my @app0s = $this->get_segments("APP0");
    # fill the hash with the records in the APP0 segments,
    # excluding segments with errors
    for my $segment (@app0s) {
	next if $segment->{error};
	my $records = $segment->{records};
	do { $data{$_->{key}} = $_->get_value() } for @$records; }
    # return a reference to a filled hash
    return \ %data;
}

# successful package load
1;
