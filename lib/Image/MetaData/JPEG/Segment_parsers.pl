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
# This routine is a generic segment parsers, which saves  #
# the first 30 bytes of the segment in a record, then     #
# generates an error to inhibit update(). In this way,    #
# the segment must be rewritten to disk unchanged, but    #
# the nature of the segment is at least hinted by the     #
# initial bytes (just for debugging ...).                 #
###########################################################
sub parse_unknown {
    my ($this) = @_;
    # save the first 30 bytes and translate non-printing characters
    my $bytes = 30;
    $this->store_record("First $bytes bytes ...", $ASCII, 0, $bytes);
    # generate an error
    die "Unknown segment type $this->{name}";
}

###########################################################
# This method parses a COM segment. This is very simple   #
# since it is just one string.                            #
###########################################################
sub parse_com {
    my ($this) = @_;
    # save the whole comment as a single value
    $this->store_record('Comment', $ASCII, 0, $this->size());
}

###########################################################
# This method parses an APP0 segment. APP0 segments are   #
# written by older cameras adopting the JFIF (JPEG File   #
# Interchange Format) for storing images. JFIF uses the   #
# APP0 application segment for inserting configuration    #
# data and a thumbnail image. The format is as follows:   #
#---------------------------------------------------------#
#  5 bytes  identifier ('JFIF\000' = 0x4a46494600)        #
#  1 byte   major version (e.g. 0x01)                     #
#  1 byte   minor version (e.g. 0x01 or 0x02)             #
#  1 byte   units (0: densities give aspect ratio         #
#                  1: density values are dots per inch    #
#                  2: density values are dots per cm)     #
#  2 bytes  Xdensity (Horizontal pixel density)           #
#  2 bytes  Ydensity (Vertical pixel density)             #
#  1 byte   Xthumbnail (Thumbnail horizontal pixel count) #
#  1 byte   Ythumbnail (Thumbnail vertical pixel count)   #
# 3n bytes  (RGB)n, packed (24-bit) RGB values for the    #
#           thumbnail pixels, n = Xthumbnail * Ythumbnail #
#---------------------------------------------------------#
# There is also an "extended" version of JFIF (only pos-  #
# sible for JFIF versions 1.02 and above). In this case   #
# the identifier is not 'JFIF' but 'JFXX'. The syntax in  #
# this case is modified as follows:                       #
#---------------------------------------------------------#
#  5 bytes  identifier ('JFXX\000' = 0x4a46585800)        #
#  1 byte   extension  (0x10 Thumbnail coded using JPEG   #
#                       0x11 Thumbnail using 1 byte/pixel #
#                       0x13 Thumbnail using 3 bytes/pixel#
#---------------------------------------------------------#
# The remainder of the segment varies with the extension. #
#---------------------------------------------------------#
# Thumbnail coded using JPEG: the compressed thumbnail    #
# immediately follows the extension code in the extension #
# data field and the length must be included in the JFIF  #
# extension APP0 marker length field. The extension data  #
# field conforms to the syntax for a JPEG file (SOI ....  #
# SOF ... EOI); however, no 'JFIF' or 'JFXX' marker seg-  #
# ments shall be present.                                 #
#---------------------------------------------------------#
# Thumbnail stored using one byte per pixel: this must    #
# include a thumbnail and a colour palette as follows:    #
#  1 byte   Xthumbnail (Thumbnail horizontal pixel count) #
#  1 byte   Ythumbnail (Thumbnail vertical pixel count)   #
# 768 bytes palette (24-bit RGB pixel values for the      #
#                    colour palette. These values define  #
#                    the colors represented by each value #
#                    of an 8-bit binary encoding (0-255)) #
# n bytes   pixels  (8-bit values for the thumbnail       #
#                    pixels: n = Xthumbnail * Ythumbnail) #
#---------------------------------------------------------#
# Thumbnail stored using three bytes per pixel: in this   #
# case there is no colour palette:                        #
#  1 byte   Xthumbnail (Thumbnail horizontal pixel count) #
#  1 byte   Ythumbnail (Thumbnail vertical pixel count)   #
# 3n bytes  pixels (24-bit RGB values for the thumbnail   #
#                   pixels, n = Xthumbnail * Ythumbnail)  #
#---------------------------------------------------------#
# Ref: http://www.dcs.ed.ac.uk/home/mxr/gfx/2d/JPEG.txt   #
###########################################################
sub parse_app0 {
    my ($this) = @_;
    my $offset = 0;
    my $thumb_x_dim = 0; my $thumb_y_dim = 0;
    # first, decode the identifier. It can be simple
    # (JFIF), or extended (JFXX). We need five bytes
    my $identifier = $this->store_record
	('Identifier', $ASCII, $offset, length $APP0_JFIF_TAG)->get_value();
    # go to the relevant decoding routine depending on it
    goto APP0_simple   if $identifier eq $APP0_JFIF_TAG;
    goto APP0_extended if $identifier eq $APP0_JFXX_TAG;
    # if we are still here, let us die of an unknown identifier
    die "Unknown identifier ($identifier)";
  APP0_simple:
    # as far as I know, in a JFIF APP0 there are always the following
    # seven fields, even if the thumbnail is absent. This means that
    # at least 14 bytes (including the initial identifier) must be there.
    # Do a test size and then read the fields.
    $this->test_size($offset + 9);
    $this->store_record('MajorVersion', $BYTE , $offset);
    $this->store_record('MinorVersion', $BYTE , $offset);
    $this->store_record('Units'       , $BYTE , $offset);
    $this->store_record('XDensity'    , $SHORT, $offset);
    $this->store_record('YDensity'    , $SHORT, $offset);
    $thumb_x_dim =$this->store_record('XThumbnail',$BYTE,$offset)->get_value();
    $thumb_y_dim =$this->store_record('YThumbnail',$BYTE,$offset)->get_value();
    # now calculate the size of the thumbnail data area. This
    # is three times the product of the two previous dimensions.
    my $thumb_size = 3 * $thumb_x_dim * $thumb_y_dim;
    # issue an error if the thumbnail data area is not there
    $this->test_size($offset + $thumb_size, "corrupted thumbnail");
    # if size is positive, get the packed thumbnail as unknown
    $this->store_record('ThumbnailData', $UNDEF, $offset, $thumb_size) 
	if $thumb_size > 0;
    goto APP0_END;
  APP0_extended:
    # so this is an extended JFIF (JFXX). Get the extension code
    my $ext_code = $this->store_record
	('ExtensionCode', $BYTE, $offset)->get_value();
    # now, depending on it, go to another parsing segment
    goto APP0_ext_jpeg   if  $ext_code == $APP0_JFXX_JPG;
    goto APP0_ext_bytes  if ($ext_code == $APP0_JFXX_1B ||
			     $ext_code == $APP0_JFXX_3B);
    # if we are still here, die of unknown extension code
    die "Unknown extension code ($ext_code)";
  APP0_ext_jpeg:
    # in this case, the rest of the data area is a jpeg image
    # which we save as undefined data in a single field. We don't
    # dare to check the syntax of these data and go to the end.
    $this->store_record('JPEGThumbnail',$UNDEF,$offset,$this->size()-$offset);
    goto APP0_END;
  APP0_ext_bytes:
    # for the other two extensions, we first make sure that there
    # are two other bytes, then we read the thumbnail size
    $this->test_size($offset + 2, "no thumbnail dimensions");
    $thumb_x_dim =$this->store_record('XThumbnail',$BYTE,$offset)->get_value();
    $thumb_y_dim =$this->store_record('YThumbnail',$BYTE,$offset)->get_value();
    # now calculate the number of pixels in the thumbnail data area.
    # This is the product of the two previous dimensions.
    my $thumb_pixels = $thumb_x_dim * $thumb_y_dim;
    # now, the two extensions take different routes ...
    goto APP0_ext_1byte  if $ext_code eq $APP0_JFXX_1B;
    goto APP0_ext_3bytes if $ext_code eq $APP0_JFXX_3B;
  APP0_ext_1byte:
    # in this case, there must be 768 bytes for the palette, followed
    # by $thumb_pixels for the thumbnail. Issue an error otherwise
    $this->test_size($offset + $APP0_JFXX_PAL + $thumb_pixels,
		     "Incorrect thumbnail data size in JFXX 0x10");
    # store the colour palette and the thumbnail as
    # undefined data and we have finished.
    $this->store_record('ColorPalette'  , $UNDEF, $offset, $APP0_JFXX_PAL);
    $this->store_record('1ByteThumbnail', $UNDEF, $offset, $thumb_pixels);
    goto APP0_END;
  APP0_ext_3bytes:
    # in this case, there must be 3 * $thumb_pixels
    # for the thumbnail data. Issue an error otherwise
    $this->test_size($offset + 3 * $thumb_pixels,
		     "Incorrect thumbnail data size in JFXX 0x13");
    # store the thumbnail as undefined data and we have finished.
    $this->store_record('3BytesThumbnail', $UNDEF, $offset, 3 * $thumb_pixels);
    goto APP0_END;
  APP0_END:
    # check that there are no spurious data in the segment
    $this->test_size(-$offset, "unknown data at segment end");
}

###########################################################
# This method parses an APP1 segment. Such an application #
# segment can host a great deal of metadata, in at least  #
# two formats (see specialised routines for more details):#
#   1) Exif JPEG files use APP1 so that they do not con-  #
#      flict with JFIF metadata (which use APP0);         #
#   2) Adobe, in order to be more standard compliant than #
#      others, uses APP1 for its XMP metadata format.     #
# This method decides among the various formats and then  #
# calls a more specialised method. An error is issued if  #
# the metadata format is not recognised.                  #
#=========================================================#
# Ref: "Exchangeable image file format for digital still  #
#      cameras: Exif Version 2.2", JEITA CP-3451, Apr2002 #
#    Japan Electronic Industry Development Assoc. (JEIDA) #
# and  "XMP, Adding Intelligence to Media", XMP specifi-  #
#      cation, Adobe System Inc., January 2004.           #
###########################################################
sub parse_app1 {
    my ($this) = @_;
    # If the data area begins with "Exif\000\000" it is an Exif section
    return $this->parse_app1_exif()
	if $this->data(0, length $APP1_EXIF_TAG) eq $APP1_EXIF_TAG;
    # If it begins with "http://ns.adobe.com/xap/1.0/", it is Adobe XMP
    return $this->parse_app1_xmp()
	if $this->data(0, length $APP1_XMP_TAG) eq $APP1_XMP_TAG;
    # if the segment type is unknown, generate an error
    die "Incorrect identifier (" . $this->data(0,6) . ")";
}

###########################################################
# This method parses a standard (Exif) APP1 segment. Such #
# an application segment is used by Exif JPEG files to    #
# store metadata, so that they do not conflict with those #
# of the JFIF format (which uses the APP0 segment).       #
# The structure of an Exif APP1 segment is as follows:    #
#---------------------------------------------------------#
#  6 bytes  identifier ('Exif\000\000' = 0x457869660000)  #
#  2 bytes  TIFF header endianness ('II' or 'MM')         #
#  2 bytes  TIFF header signature (a fixed value = 42)    #
#  4 bytes  TIFF header: offset of 0th IFD                #
# ...IFD... 0th IFD (main image)                          #
# ...IFD... SubIFD (EXIF private tags) linked by IFD0     #
# ...IFD... Interoperability IFD, linked by SubIFD        #
# ...IFD... GPS IFD (optional) linked by IFD0             #
# ...IFD... 1st IFD (thumbnail) linked by IFD0            #
# ...IFD... Thumbnail image (0xffd8.....ffd9)             #
#=========================================================#
# The offset of the 0th IFD in the TIFF header, as well   #
# as IFD links in the IFDs, is given with respect to the  #
# beginning of the TIFF header (i.e. the address of the   #
# 'MM' or 'II' pair). This means that if the 0th IFD be-  #
# gins (as usual) immediately after the end of the TIFF   #
# header, the offset value is 8.                          #
#=========================================================#
# An Exif file can contain a thumbnail, usually located   #
# next to the 1st IFD. There are 3 possible formats: JPEG #
# (only this is compressed), RGB TIFF, and YCbCr TIFF. It #
# seems that JPEG and 160x120 pixels are recommended for  #
# Exif ver. 2.1 or higher (mandatory for DCF files).      #
# Since the segment size for APP1 is recorded in 2 bytes, #
# the thumbnail are limited to 64KB minus something.      #
#---------------------------------------------------------#
# A JPEG thumbnail is selected by Compression(0x0103) = 6.#
# In this case, one can get the thumbnail offset from the #
# JPEGInterchangeFormat(0x0201) tag, and the thumbnail    #
# length from the JPEGInterchangeFormatLength(0x0202) tag.#
#---------------------------------------------------------#
# An uncompressed (TIFF image) thumbnail is selected by   #
# Compression(0x0103) = 1. The thumbnail offset and size  #
# are to be read from StripOffset(0x0111) and (the sum of)#
# StripByteCounts(0x0117). For uncompressed thumbnails,   #
# PhotometricInterpretation(0x0106) = 2 means RGB format, #
# while = 6 means YCbCr format.                           #
#=========================================================#
# Ref: http://park2.wakwak.com/                           #
#             ~tsuruzoh/Computer/Digicams/exif-e.html     #
# and "Exchangeable image file format for digital still   #
#      cameras: Exif Version 2.2", JEITA CP-3451, Apr2002 #
#   Japan Electronic Industry Development Assoc. (JEIDA)  #
###########################################################
sub parse_app1_exif {
    my ($this) = @_;
    # decode the identifier and the TIFF header. The correct
    # identifier for an APP1 segment is 'Exif\000\000'. Remember
    # to convert the ifd0 offset with the TIFF header base.
    my ($offset, $tiff_base, $ifd0_link, $endianness) =
	$this->parse_TIFF_header($APP1_EXIF_TAG);
    # set the current endianness to what we have found.
    # Remember to reset it at the end of the method!!!
    $this->{endianness} = $endianness;
    # parse all records in the 0th IFD. Inside it, there might be a link
    # to the EXIF private tag block (SubIFD), which contains all you want
    # to know about how the shot was shot. Perversely enough, the SubIFD
    # can nest two other IFDs, namely the "Interoperabiliy IFD" and the
    # "MakerNote IFD". Decoding the Maker Note is likely to fail, because
    # most vendors do not publish their MakerNote format. However, if the
    # note is decoded, the findings are written in a new subdirectory (I
    # think it is still wiser not to delete the unparsed MakerNote record).
    my $ifd1_link = $this->parse_ifd('IFD0', $ifd0_link, $tiff_base, \$offset);
    # same thing for the 1st IFD. In this case the test is not
    # on $ifd1_link being defined, but on it being zero or not.
    if ($ifd1_link != 0) {
	$this->parse_ifd('IFD1', $ifd1_link, $tiff_base, \$offset, 1);
	# look for the compression tag (thumbnail type record)
	my $ifd1_dir = $this->provide_subdirectory('IFD1');
	my $th_type_record = $this->search_record($APP1_TH_TYPE, $ifd1_dir);
	# if there is no thumbnail, stop searching
	goto END_THUMBNAIL unless defined $th_type_record;
	# otherwise, look at the thumbnail type. This should be either
	# TIFF or JPEG. Die if the type is not known
	my $th_type = $th_type_record->get_value();
	die "Unknown thumbnail type in $this->{name} ($th_type)"
	    if $th_type != $APP1_TH_TIFF && $th_type != $APP1_TH_JPEG;
	# calculate the thumbnail location and size
	my ($thumb_link, $thumb_size) = map {
	    my $rec = $this->search_record($_, $ifd1_dir);
	    $rec ? $rec->get_value() : undef } $th_type == $APP1_TH_TIFF
		? ($APP1_THTIFF_OFFSET, $APP1_THTIFF_LENGTH) 
		: ($APP1_THJPEG_OFFSET, $APP1_THJPEG_LENGTH);
	# Some pictures declare they have a thumbnail, but there is
	# no thumbnail link for it (maybe this is due to some program
	# which strips the thumbnail out without completely removing
	# the 1st IFD). Treat this case as if $th_type was undefined.
	goto END_THUMBNAIL unless defined $thumb_link;
	# point the current offset to the thumbnail
	$offset = $tiff_base + $thumb_link;
	# sometimes, we have broken pictures with an actual size which
	# is shorter than $th_jpeg_size; nonetheless, the thumbnail is
	# often valid, so this case deserves only a warning if the
	# difference is not too large (currently, 1 byte); but the
	# $thumb_size variable must be updated.
	my $remaining = $this->size() - $offset;
	if ($thumb_size > $remaining) {
	    die "Large mismatch in predicted/actual ($thumb_size/$remaining)",
	    " thumbnail size in APP1" if $thumb_size - $remaining > 1;
	    warn "Predicted thumbnail size ($thumb_size) larger than "
		. "available data size ($remaining). Correcting ...\n";
	    $thumb_size = $remaining;
	}
	# store the thumbnail (if present)
	$this->store_record('ThumbnailData', $UNDEF, $offset, $thumb_size) 
	    if $thumb_size > 0;
      END_THUMBNAIL:
    }
    # reset the current endianness to big endian
    $this->{endianness} = $BIG_ENDIAN;
    # paranoia
    $offset = $this->size();
}

###########################################################
# This method parses a TIFF header, which can be found,   #
# for instance, in APP1 and APP3 segments. It also parses #
# the segment identifier, which is a 6 bytes string pre-  #
# pended to the TIFF header. The structure is as follows: #
#---------------------------------------------------------#
#  6 bytes  identifier (usually null terminated)          #
#  2 bytes  TIFF header endianness ('II' or 'MM')         #
#  2 bytes  TIFF header signature (a fixed value = 42)    #
#  4 bytes  TIFF header: offset of 0th IFD                #
#=========================================================#
# The returned values are: the updated offset (i.e. the   #
# number 14), the offset of the TIFF header start, the    #
# offset of the 0-th IFD with respect to the TIFF header  #
# start, and the endianness.                              #
#=========================================================#
# The first two bytes of the TIFF header give the byte    #
# alignement (endianness): either 0x4949='II' for "Intel" #
# type alignement (small endian) or 0x4d4d='MM' for "Mo-  #
# torola" type alignement (big endian). An EXIF block is  #
# the only part of a JPEG file whose endianness is not    #
# fixed to big endian (sigh!)                             #
#=========================================================#
# and "Exchangeable image file format for digital still   #
#      cameras: Exif Version 2.2", JEITA CP-3451, Apr2002 #
#   Japan Electronic Industry Development Assoc. (JEIDA)  #
###########################################################
sub parse_TIFF_header {
    my ($this, $good_identifier) = @_;
    my $offset = 0;
    # at least 8 bytes for the TIFF header + identifier length
    $this->test_size(8 + length $good_identifier, "TIFF header too small");
    # decode the identifier (get its length from $good_identifier)
    my $identifier = $this->store_record
	('Identifier', $ASCII, $offset, length $good_identifier)->get_value();
    # die if it is not correct
    die "Incorrect identifier ($identifier)"if $identifier ne $good_identifier;
    # save the current offset for later use (TIFF header starts here)
    my $tiff_base = $offset;
    # decode the endianness (either 'II' or 'MM',
    # 2 bytes); die if it is unknown
    my $endianness = $this->store_record
	('Endianness', $ASCII, $offset, 2)->get_value();
    die "Unknown endianness ($endianness)"
	if $endianness ne $BIG_ENDIAN && $endianness ne $LITTLE_ENDIAN;
    # if it is not unknown, set the current endianness
    $this->{endianness} = $endianness;
    # decode the signature (42, i.e. 0x002a), die if it is unknown
    my $signature = $this->store_record
	('Signature', $SHORT,$offset)->get_value();
    die "Incorrect signature ($signature)" if $signature != $APP1_TIFF_SIG;
    # decode the offset of the 0th IFD: this is usually 8,
    # but we are not going to assume it. 
    my $ifd0_link = $this->store_record
	('IFD0_Pointer', $LONG, $offset)->get_value();
    # reset the current endianness to big endian
    $this->{endianness} = $BIG_ENDIAN;
    # return all relevant values in a list
    return ($offset, $tiff_base, $ifd0_link, $endianness);
}

###########################################################
# This method parses an IFD block, like those found in    #
# the APP1 or APP3 segments. The arguments are: the name  #
# of the block, the block offset with respect to the TIFF #
# header base, the value of the TIFF header base and a    #
# reference to the current offset in block's data (the    #
# TIFF base is necessary because some records in the IFD  #
# must be interpreted as offsets relative to it). An op-  #
# tional boolean flag produces a warning if set to true   #
# while the next_link pointer is non-zero. This method    #
# returns the next_link pointer, and updates the current  #
# offset in the object's data area.                       #
# ======================================================= #
# The block name is indeed a '@' separated list of names, #
# which are to be interpreted in sequence; for instance   #
# "IFD0@SubIFD" means that in $this->{records} there is a #
# REFERENCE record with key "IFD" and value $dirref; then #
# in $$dirref there is a REFERENCE record with key equal  #
# to "SubIFD" and so on ...                               #
# --------------------------------------------------------#
# After the execution of this routine, a new REFERENCE    #
# record will be present, whose value is a reference to   #
# a list of all the entries in the IFD. If $link is unde- #
# fined, this routine returns immediately (in this way    #
# you do not need to test $link before). No next_link are #
# tolerated in the underlying subdirectories.             #
#---------------------------------------------------------#
# structure of an IFD:                                    #
#     2  bytes    Number n of Interoperability arrays     #
#    12n bytes    the n arrays (12 bytes each)            #
#     4  bytes    link to next IFD (can be zero)          #
#   .......       additional data area                    #
###########################################################
sub parse_ifd {
    my ($this, $dirnames, $link, $tiff_base, $offset_ref, $no_next) = @_;
    # if $link is undefined, return immediately
    return unless defined $link;
    # this IFD starts at position $link with respect to the TIFF header
    # base. If this is not the current position, $offset must be updated
    $$offset_ref = $tiff_base + $link;
    # the first two bytes give the number of Interoperability arrays.
    # Don't insert this value into the record list, just read it.
    my $ifd_records = $this->read_record($SHORT, $$offset_ref);
    # create/retrieve the appropriate record list and save its
    # reference. The list is specified by a '@' separated list
    # of dir names in $dirnames (to be interpreted in sequence)
    my $dirref = undef; $dirref =
	$this->provide_subdirectory($_, $dirref) for(split /@/, $dirnames);
    # parse all the records in the IFD; additional data might
    # be referenced through pointers relative to the tiff header
    # base. This populates the $$dirref list with IFD records.
    $$offset_ref = $this->parse_interop
	($$offset_ref, $tiff_base, $dirref) for (1..$ifd_records);
    # I used to complain in case no entry was present in this
    # IFD (c'est louche!), but it turned out this is of no use
    #### warn "No entries found in $dirnames" unless (@$dirref);
    # after the IFD records there can be a link to the next
    # IFD; this is an unsigned long, i.e. 4 bytes. If there
    # is no next IFD, these bytes are 0x00000000.
    my $next_ifd_link = $this->read_record($LONG, $$offset_ref);
    # take care of possible subdirectories. For each numeric tag
    # among the keys of the %IFD_SUBDIRS hash, look for a corresponding
    # record and, if present, parse the subdirectory
    for (keys %IFD_SUBDIRS) {
	# don't parse if there is no such subdirectory
	next unless defined (my $record = $this->search_record($_, $dirref));
	# get the location of this secondary IFD and parse it
	$this->parse_ifd($IFD_SUBDIRS{$_}, $record->get_value(),
			 $tiff_base, $offset_ref, 1); }
    # if $no_next is true and we have a non-zero "next link", complain
    warn "Warning: \"next link\" != 0 ($next_ifd_link) in $dirnames\n"
	if $no_next && $next_ifd_link; 
    # return the next IFD link
    return $next_ifd_link;
}

###########################################################
# This method parses an IFD Interoperability array.       #
#=========================================================#
# Each Interoperability array consists of four elements:  #
#     bytes 0-1   Tag          (a unique 2-byte number)   #
#     bytes 2-3   Type         (one out of 12 types)      #
#     bytes 4-7   Count        (the number of values)     #
#     bytes 8-11  Value Offset (value or offset)          #
#                                                         #
# Types are the same as for the Record class. The "value  #
# offset" records the offset from the TIFF header where   #
# the value is recorded. It contains the actual value if  #
# it is not larger than 4 bytes (32 bits). If the value   #
# is shorter than 4 bytes, it is recorded in the lower    #
# end of the 4-byte area (smaller offsets).               #
#=========================================================#
# The routine returns the offset value increased by the   #
# number of bytes which were read (i.e. $offset + 12).    #
###########################################################
sub parse_interop {
    my ($this, $offset, $tiff_base, $dirref) = @_;
    # the data area must be at least 12 bytes wide
    $this->test_size(12, "initial bytes check");
    # read the content of the first three fields
    # (without inserting them in any record list!)
    my $tag   = $this->read_record($SHORT, $offset);
    my $type  = $this->read_record($SHORT, $offset);
    my $count = $this->read_record($LONG , $offset);
    # ask the record class to calculate the number of bytes necessary
    # to store the value (the type size times the number of items).
    # This should always be a meaningful number, not zero.
    my $size = Image::MetaData::JPEG::Record->get_size($type, $count);
    # prepare a string with the content of the last four bytes in
    # the Interoperability array (or with its low address part if
    # $size is smaller than four); then, update the offset (always +4)
    my $field = $this->data($offset, $size <= 4 ? $size : 4);
    $offset += 4;
    # Insert the Interoperability array value into its sub-directory
    $this->store_record($dirref, $tag, $type, $size > 4 ?
			# if $size is larger than four, use the last four bytes
			# of the Interoperability array as an offset relative
			# to $tiff_base, and read the true value.
			\$this->data($tiff_base + 
				     $this->read_record($LONG, \$field), $size)
			# if $size is less or equal to four, the data can be
			# read directly in the last four bytes (if it is even
			# shorter, the low address bytes are to be taken).
			: \$field, $count);
    # return the updated $offset
    return $offset;
}

########
sub parse_makernote {
    return;
    my ($this, $dirnames, $makernote, $tiff_base, $offset_ref) = @_;

    my @IFD_LIKE_MAKERNOTES = ( "OLYMP\000\001\000",
				"FUJIFILM\014\000\000\000" );

    for (@IFD_LIKE_MAKERNOTES) {
	next unless $makernote =~ $_;
	$dirnames .= "_OLYMPUS";

	my $link = index $this->data(0, $this->size()), $makernote;
	$link += (length $_) - 2;
	print "LINK $link\n";

	eval { $this->parse_ifd($dirnames, $link, $tiff_base, $offset_ref);};
	$this->create_record('MakerNoteError', $ASCII, \$@, length $@) if $@;
    }

}

###########################################################
# This method parses an APP1 XMP segment. Such an APP1    #
# segment was introduced by Adobe for recording an XMP    #
# packet in JPEG files (this is a particular XML block    #
# storing metadata information, similar to the Exif APP1  #
# block). The format is the following:                    #
#---------------------------------------------------------#
# 29 bytes  namespace ('http://ns.adobe.com/xap/1.0/\000')#
#  ....     XMP packet                                    #
#=========================================================#
# The advantage of the XMP format should be that it can   #
# be embedded in multiple file types, like JPEG, PNG, GIF,#
# HTML, PDF, PostScript, ecc... Only the envelop changes. #
# Being too lazy, I only parsed the XML tree here; let me #
# know if this is to be completed/reworked completely.    #
###########################################################
# Ref: "XMP, Adding Intelligence to Media", XMP specifi-  #
#      cation, Adobe System Inc., January 2004.           #
###########################################################
sub parse_app1_xmp {
    my ($this) = @_;
    my $offset = 0;
    # decode the identifier (it must be the Adobe
    # namespace); die if it is not correct
    my $identifier = $this->store_record
	('Namespace', $ASCII, $offset, 29)->get_value();
    die "Adobe APP1 with incorrect identifier ($identifier)"
	if $identifier ne $APP1_XMP_TAG;
    # get the remaining of the XMP packet
    my $xml_data = $this->read_record($ASCII, $offset, $this->size()-$offset);
    # pre-treatment: transform newlines into spaces and delete
    # sequences of spaces only between tag delimiters.
    $xml_data =~ tr/\n/ /;
    $xml_data =~ s/> *</></g;
    # define symbolically a few regular expression
    my $a_quotation = qr/[\'\"]/;
    my $noquotation = qr/[^\'\"]/;
    my $mkp_tag     = qr/[^\/> ]+/;
    my $mkp_generic = qr/<[^>]*>[^<]*/;
    my $mkp_comment = qr/<!-- .* -->/;
    my $mkp_option  = qr/ *([^ ]+=$a_quotation$noquotation*$a_quotation) */;
    my $mkp_special = qr/<\?($mkp_tag)($mkp_option*)\?>/;
    my $mkp_opening = qr/<($mkp_tag)( ?[^>]*)>(.*)/;
    my $mkp_closing = qr/<\/($mkp_tag)>/;
    # split the xml packet into single markups (<thingslikethis>). If
    # there is free text between two markups, attach it to the left one.
    my @all_markups = $xml_data =~ /$mkp_generic/g;
    # remove comments; I suppose that I am not removing information
    # here, but the Adobe XMP specs should be read more carefully ...
    @all_markups = grep {!/$mkp_comment/} @all_markups;
    # a few variables for the following foreach
    my @tag_tree = (); my @tag_prop = ();
    my $d_index  = 0;  my $s_index  = 0;
    my @dirstack = ( $this->{records} );
    # process all markups and insert the relevant data into the internal
    # record lists. Try to mimick the XML tree as much as possible.
    foreach(@all_markups) {
	#   # ====================
	if (/$mkp_special/) {
	    # special markups; these are markups of this form: <?tag options?>.
	    # They are not closed, so they do not enter the hierarchy. To 
	    # remember this, the string "SPECIAL-n:" is prepended, with n
	    # a progressive index. Options are marked by "OPT:"
	    my ($qtag, $options) = ("SPECIAL-" . ++$s_index . ":" . $1, $2);
	    my $special_ref = $this->provide_subdirectory($qtag);
	    foreach ($options =~ /$mkp_option/g) {
		my ($tag, $val) = split /=/;
		$this->store_record($special_ref, "OPT:$tag",
				    $ASCII, \$val, length $val); }
	    # ====================
	} elsif (/$mkp_opening/) {
	    # you get here while looking for opening markups which are not
	    # special. They need a closing markup, so the tree must be
	    # preserved (use @tag_tree and @tag_prop for this). There can
	    # be both options (prepend "OPT:") and a value. Since there 
	    # are multiple description markups, individualize them with
	    # a progressive index. Markups with a value do not have a
	    # sub-directory on their own.
	    my ($tag, $options, $value) = ($1, $2, $3);
	    $tag .= "[" . ++$d_index . "]" if $tag =~ /^rdf:Description$/;
	    my $needs_subdir = ($value eq '' ? 1 : undef);
	    push @tag_prop, ($needs_subdir ? "nested" : "inline");
	    push @tag_tree, $tag;
	    my $dirref = $dirstack[$#dirstack];
	    push @dirstack, $dirref=$this->provide_subdirectory($tag, $dirref)
		if $needs_subdir;
	    foreach($options =~ /$mkp_option/g) {
		my ($optag, $val) = split /=/;
		$optag = ($needs_subdir ? "OPT:$optag" : "IN-OPT:$optag");
		$this->store_record($dirref,$optag,$ASCII,\$val, length $val);
	    }
	    $this->store_record($dirref, $tag, $ASCII, \$value, length $value)
		if ($value);
	    # ====================
	} elsif (/$mkp_closing/) {
	    # this is for closing markups; there is a consistency test
	    # and some stacks are popped.
	    my $new_tag  = $1;
	    my $old_tag  = pop @tag_tree;
	    my $old_prop = pop @tag_prop;
	    $new_tag .= "[$d_index]" if $new_tag =~ /rdf:Description/;
	    die "Mismatched tags (open=$old_tag, close=$new_tag)"
		if $new_tag ne $old_tag;
	    pop @dirstack unless $old_prop =~ /inline/;
	}
    }
    # test that nothing was left out
    $this->test_size($offset);
}

###########################################################
# This is the entry point for parsing APP2 segments. Such #
# application segments can host at least two formats (see #
# the called subroutines for more details):               #
#   1) Flashpix conversion information ("FPXR").          # 
#   2) ICC profiles data.                                 #
# This method decides among the various formats and then  #
# calls a specific parser. An error is issued if the      #
# metadata format is not recognised.                      #
#=========================================================#
# Ref: "Exchangeable image file format for digital still  #
#      cameras: Exif Version 2.2", JEITA CP-3451, Apr2002 #
#    Jap.Electr.Industry Develop.Assoc. (JEIDA), pag. 65  #
###########################################################
sub parse_app2 {
    my ($this) = @_;
    # If the data area begins with "FPXR\000", it contains Flashpix data
    return $this->parse_app2_flashpix()
	if $this->data(0, length $APP2_FPXR_TAG) eq $APP2_FPXR_TAG;
    # If it starts with "ICC_PROFILE", well, guess it ....
    return $this->parse_app2_ICC_profiles()
	if $this->data(0, length $APP2_ICC_TAG) eq $APP2_ICC_TAG;
    # if the segment type is unknown, generate an error
    die "Incorrect identifier (" . $this->data(0, 6) . ")";
}

###########################################################
# This method parses an APP2 Flashpix extension segment,  #
# and is not really reliable, since I have only one exam- #
# ple and very badly written documentation. The FPXR      #
# structure, the worst I have ever seen, is as follows:   #
#---------------------------------------------------------#
#  5 bytes  identifier ("FPXR\000" = 0x4650585200)        #
#  1 byte   version (always zero?, it is a binary value)  #
#  1 byte   type (1=Cont. List, 2=Stream Data, 3=reserved)# 
#--- Contents List Segment -------------------------------#
#  2 bytes  Interoperability count (the list size ...)    #
#    ---------- multiple times -------------------------- #
#  4 bytes  Entity size (0xffffffff for a storage (?))    #
#     ...   Storage/Stream name (null termin., Unicode)   #
# 16 bytes  Entity class ID (for storages) (var. size ?)  #
#--- Stream Data Segment ---------------------------------#
#  2 bytes  index in the Contents List                    #
#  4 bytes  offset to the first byte in the stream (?)    #
#     ...   the actual data stream (to the end?)          #
#=========================================================#
# Ref: "Exchangeable image file format for digital still  #
#      cameras: Exif Version 2.2", JEITA CP-3451, Apr2002 #
#    Jap.Electr.Industry Develop.Assoc.(JEIDA), pag.65-67 #
###########################################################
sub parse_app2_flashpix {
    my ($this) = @_;
    my $offset = 0;
    # at least 7 bytes for the identifier, its version and its type
    $this->test_size(7, "FPXR header too small");
    # decode the identifier (get its length from $APP2_FPXR_TAG)
    my $identifier = $this->store_record
	('Identifier', $ASCII, $offset, length $APP2_FPXR_TAG)->get_value();
    # die if it is not correct
    die "Incorrect identifier ($identifier)" if $identifier ne $APP2_FPXR_TAG;
    # decode the version number (is this always zero?) and the data type
    $this->store_record('Version', $BYTE, $offset);
    my $type = $this->store_record('FPXR_type', $BYTE, $offset)->get_value();
    # data type equal to 1 means we are dealing with a Contents List
    # structure, listing the storages and streams for the Flashpix image.
    if ($type == 1) {
	# the first two bytes select the number of entries in the list
	my $count = $this->read_record($SHORT, $offset);
	for (1..$count) {
	    # create a separate subdir for each entry (stupid ?), then
	    # get the entity size and default value (the size refers to
	    # what we are going to find in future APP2 segments!).
	    my $subdir = $this->provide_subdirectory('Entity_' . $_);
	    my $size = $this->store_record($subdir, 'Size', $LONG, $offset);
	    $this->store_record($subdir, 'DefaultValue', $BYTE, $offset);
	    # the following entry is a Unicode string (16 bits --> 1 char)
	    # in little endian format. It terminates with a Unicode null
	    # char, i.e., "\000\000". Find its length, then store it. The
	    # string is invalid if it does not begin with Unicode "/".
	    my $pos=0; $pos+=2 while $this->data($offset+$pos,2) ne "\000\000";
	    die "Invalid Storage/Stream name (not beginning with /)"
		if $this->data($offset, 2) ne "/\000";
	    $this->store_record($subdir, 'Name', $ASCII, $offset, $pos+2);
	    # if $size is 0xffffffff, we are dealing with a Storage
	    # Interoperability Field; I don't know what this means, but
	    # at this point there should be an "Entity class ID" (16 bytes)
	    $this->store_record($subdir, 'Class_ID', $UNDEF, $offset, 16)
		if $size == 0xffffffff;
	} } 
    # data type equal to 2 means we are dealing with a Stream Data
    # segment (there can be more than one such segments).
    elsif ($type == 2) {
	$this->store_record('ContentsIndex', $SHORT, $offset);
	$this->store_record('StreamOffset', $LONG, $offset);
	$this->store_record('Data', $UNDEF, $offset, $this->size() - $offset);
    }
    # type 3 is reserved for the future (let me know ...)
    elsif ($type == 3) {
	$this->store_record('Unknown', $UNDEF, $offset,$this->size()-$offset);}
    # a type different from 1, 2 or 3 is not valid.
    else { die "Unknown FPXR type ($type)"; }
    # check that there are no spurious data in the segment
    $this->test_size(-$offset, "unknown data at segment end");
}

###########################################################
# This method parses an APP2 ICC_PROFILE segment. The     #
# profile is defined as a header followed by a tag table  #
# followed by a series of tagged elements. This routine   #
# parses the overall structure and the profile header,    #
# the other tags are read by parse_app2_ICC_tags(). The   #
# ICC segment structure is as follows:                    #
#---------------------------------------------------------#
#  5 bytes  identifier ("FPXR\000" = 0x4650585200)        #
#  1 byte   sequence number of the chunck (starting at 1) #
#  1 byte   total number of chunks                        #
#------- Profile header ----------------------------------#
#  4 bytes  profile size (this includes header and data)  #
#  4 bytes  CMM type signature                            #
#  4 bytes  profile version number                        #
#  4 bytes  profile/device class signature                #
#  4 bytes  color space signature                         #
#  4 bytes  profile connection space (PCS) signature      #
# 12 bytes  date and time this profile was created        #
#  4 bytes  profile file signature                        #
#  4 bytes  profile primary platform signature            #
#  4 bytes  flags for CMM profile options                 #
#  4 bytes  device manifacturer signature                 #
#  4 bytes  device model signature                        #
#  8 bytes  device attributes                             #
#  4 bytes  rendering intent                              #
# 12 bytes  XYZ values of the illuminant of the PCS       #
#  4 bytes  profile creator signature                     #
# 16 bytes  profile ID checksum                           #
# 28 bytes  reserved for future expansion (must be zero)  #
#------- Tag table ---------------------------------------#
# see parse_app2_ICC_tags()                               #
#=========================================================#
# Since ICC profile data can easily exceed 64KB, there is #
# a mechanism to divide the profile into smaller chunks.  #
# This is the sequence number; every chunk must show the  #
# same value for the total number of chunks.              #
#=========================================================#
# Ref: "Specification ICC.1:2003-09, File Format for Co-  #
#       lor Profiles (ver. 4.1.0)", Intern.Color Consort. #
###########################################################
sub parse_app2_ICC_profiles {
    my ($this) = @_;
    my $offset = 0;
    # get the length of the APP2 ICC identifier; then calculate
    # the profile header offset (there are two more bytes)
    my $id_size = length $APP2_ICC_TAG;
    my $header_base = $id_size + 2;
    # at least $header_base + 128 bytes (profile header) to start 
    $this->test_size($header_base + 128, "ICC profile header too small");
    # decode the identifier (get its length from $APP2_FPXR_TAG)
    my $identifier = $this->store_record
	('Identifier', $ASCII, $offset, $id_size)->get_value();
    # die if it is not correct
    die "Incorrect identifier ($identifier)" if $identifier ne $APP2_ICC_TAG;
    # read the sequence number and the total number of chunks
    $this->store_record('SequenceNumber', $BYTE, $offset);
    $this->store_record('TotalNumber',    $BYTE, $offset);
    # read the profile size and check with the real size
    # remember to include the (identifier + chunks) bytes
    my $size = $this->read_record($LONG, $offset);
    $this->test_size(-($size + $header_base), "Incorrect ICC data size");
    # prepare a subdirectory for the profile header
    my $sd = $this->provide_subdirectory("ProfileHeader");
    # read all other entries in the profile header
    $this->store_record($sd, 'CMM_TypeSignature',        $ASCII, $offset, 4 );
    $this->store_record($sd, 'ProfileVersionNumber',     $UNDEF, $offset, 4 );
    $this->store_record($sd, 'ClassSignature',           $ASCII, $offset, 4 );
    $this->store_record($sd, 'ColorSpaceSignature',      $ASCII, $offset, 4 );
    $this->store_record($sd, 'ConnectionSpaceSignature', $ASCII, $offset, 4 );
    $this->store_record($sd, 'Year',                     $SHORT, $offset    );
    $this->store_record($sd, 'Month',                    $SHORT, $offset    );
    $this->store_record($sd, 'Day',                      $SHORT, $offset    );
    $this->store_record($sd, 'Hour',                     $SHORT, $offset    );
    $this->store_record($sd, 'Minute',                   $SHORT, $offset    );
    $this->store_record($sd, 'Second',                   $SHORT, $offset    );
    $this->store_record($sd, 'ProfileFileSignature',     $ASCII, $offset, 4 );
    $this->store_record($sd, 'PrimaryPlatformSignature', $ASCII, $offset, 4 );
    $this->store_record($sd, 'CMM_ProfileFlags',         $LONG,  $offset    );
    $this->store_record($sd, 'DeviceManifactSignature',  $ASCII, $offset, 4 );
    $this->store_record($sd, 'DeviceModelSignature',     $ASCII, $offset, 4 );
    $this->store_record($sd, 'DeviceAttributes',         $UNDEF, $offset, 8 );
    $this->store_record($sd, 'RenderingIntent',          $LONG,  $offset    );
    $this->store_record($sd, 'XYZ_PCS_Illuminant',       $UNDEF, $offset, 12);
    $this->store_record($sd, 'ProfileCreatorSignature',  $ASCII, $offset, 4 );
    $this->store_record($sd, 'ProfileID_Checksum',       $UNDEF, $offset, 16);
    # the last 28 bytes in the profile header are reserved for
    # future use, and should contain only zero.
    my $reserved = $this->read_record($UNDEF, $offset, 28);
    die "Non-zero reserved bytes in profile header" if $reserved ne "\000"x28;
    # call another method knowing how to read the remaining tags
    # (it only needs to know the current offset and where is the
    # beginning of the profile header)
    return $this->parse_app2_ICC_tags($offset, $header_base);
}

###########################################################
# This method parses the tag table of an APP2 ICC_PROFILE #
# segment (it complements parse_app2_ICC_profiles()). See #
# that routine for more details. The arguments are the    #
# current offset in the segment data area and the start   #
# of the profile header with respect to the beginning of  #
# the segment data area. There are no checks on the over- #
# all size, since it is assumed that this was already     #
# controlled by the calling routine. The tag table        #
# structure is as follows:                                #
#---------------------------------------------------------#
#  4 bytes  tag count                                     #
#           ---------- multiple times ------------------- #
#  4 bytes  tag signature (a unique number)               #
#  4 bytes  tag offset from the profile header start      #
#  4 bytes  tag size                                      #
#------ Data area of a tag -------------------------------#
#  4 bytes  ICC tag type (an ASCII string)                #
#  4 bytes  reserved for the future ("\000\000\000\000")  #
#    ....   real data area (various encodings).           #
#---------------------------------------------------------#
# The first tag data area must immediately follow the tag #
# table. All tagged element data must be padded with      #
# nulls by no more than three pad bytes to reach a four   #
# bytes boundary. We only store the final part of the tag #
# data area in the record (the ICC type is saved in its   #
# extra field). See the code for more details.            #
#=========================================================#
# Ref: "Specification ICC.1:2003-09, File Format for Co-  #
#       lor Profiles (ver. 4.1.0)", Intern.Color Consort. #
###########################################################
sub parse_app2_ICC_tags {
    my ($this, $offset, $header_base) = @_;
    # read the number of tags in the tag table (don't store it)
    my $tags = $this->read_record($LONG, $offset);
    # prepare a subdirectory for the tag table
    my $tag_table = $this->provide_subdirectory("TagTable");
    # repeat the tag-reading algorithm $tags time
    for (1..$tags) {
	# the 12 bytes in the tag table entry contain the tag code
	# (which we are going to use as record key), the pointer to
	# the tag data with respect to the profile header beginning
	# and the size of this data area. Read and don't store.
	my $tag_code   = $this->read_record($LONG, $offset);
	my $tag_offset = $this->read_record($LONG, $offset);
	my $tag_size   = $this->read_record($LONG, $offset);
	# the first 8 bytes in the tag data area are special; the first
	# 4 bytes specify the "ICC type", the following 4 must be zero.
	# Read, check the condition, but don't store.
	my $tag_desc   = $this->data($header_base + $tag_offset    , 4);
	my $tag_pad    = $this->data($header_base + $tag_offset + 4, 4);
	die "Non-zero padding in ICC tag" if $tag_pad ne "\000\000\000\000";
	# adjust the tag size and offset to reflect the 8 bytes we read.
	# also adjust the offset by adding the profile header base
	$tag_size -= 8; $tag_offset += 8 + $header_base;
	# a few ICC tag types can be shown with something more
	# specific than the UNDEF type (which remains the default)
	my $tag_type = $UNDEF;
	$tag_type = $ASCII  if $tag_desc =~ /text|sig /;
	$tag_type = $BYTE   if $tag_desc =~ /ui08/;
	$tag_type = $SHORT  if $tag_desc =~ /ui16|dtim/;
	$tag_type = $LONG   if $tag_desc =~ /ui32|XYZ |view/;
	# depending on the tag type, calculate its length in bytes and
	# therefore the number of elements in the data area (the count).
	my $tag_length = Image::MetaData::JPEG::Record->get_size($tag_type, 1);
	my $tag_count  = $tag_size / $tag_length;
	# now, store the content of the tag data area (minus the first
	# 8 bytes) as a record of given key, type and count. Store the
	# record in the tag table subdirectory.
	$this->store_record($tag_table, $tag_code, $tag_type,
			    \ $this->data($tag_offset, $tag_size), $tag_count);
	# also store the ICC tag type in the record "extra" field
	$this->search_record("LAST_RECORD", $tag_table)->{extra} = $tag_desc;
    }
}

###########################################################
# This method parses an APP3 Exif segment, which is very  #
# similar to an APP1 Exif segment (infact, it is its      #
# extension with additional tags, see parse_app1_exif for #
# additional details). The structure is as follows:       #
#---------------------------------------------------------#
#  6 bytes  identifier ('Meta\000\000' = 0x4d6574610000)  #
#  2 bytes  TIFF header endianness ('II' or 'MM')         #
#  2 bytes  TIFF header signature (a fixed value = 42)    #
#  4 bytes  TIFF header: offset of 0th IFD                #
# ...IFD... 0th IFD (mandatory, I think)                  #
# ...IFD... Special effects IFD (optional) linked by IFD0 #
# ...IFD... Borders IFD (optional) linked by IFD0         #
#=========================================================#
# Ref: ... ???                                            #
###########################################################
sub parse_app3 {
    my ($this) = @_;
    # decode the identifier and the TIFF header. The correct
    # identifier for an APP3 segment is 'Meta\000\000'. Remember
    # to convert the ifd0 offset with the TIFF header base.
    my ($offset, $tiff_base, $ifd0_link, $endianness) =
	$this->parse_TIFF_header($APP3_EXIF_TAG);
    # set the current endianness to what we have found.
    # Remember to reset it at the end of the method!!!
    $this->{endianness} = $endianness;
    # parse all the records of the 0th IFD, as well as their subdirs
    $this->parse_ifd('IFD0', $ifd0_link, $tiff_base, \$offset, 1);
    # reset the current endianness to big endian
    $this->{endianness} = $BIG_ENDIAN;
    # paranoia
    $offset = $this->size();
}

###########################################################
# This method parses an APP12 segment; this segment was   #
# used around 1998 by at least Olympus, Agfa and Epson    #
# as a non standard replacement for EXIF. Information is  #
# semi-readeable (mainly ascii text), but the format is   #
# undocument (let me know if you have any documentation!) #
#=========================================================#
# From the few examples I was able to find, my interpre-  #
# tation of the APP12 format is the following:            #
#---------------------------------------------------------#
#  1 line         identification (maker info?)            #
#----- multiple times ------------------------------------#
#  1 line         group (a string in square brackets)     #
# multiple lines  records (key-value separated by '=')    #
#----- multiple times ------------------------------------#
#  characters     group (a string in square brackets)     #
#  characters     unintelligible data                     #
#=========================================================#
# Well, this description looks a mess, I know. It means   #
# that after the identification line, there is some plain #
# ascii information (divided in groups, each group starts #
# with a line like "[picture info]", each key-value pair  #
# span one line) followed by groups containing binary     #
# data (so that splitting on line ends does not work!).   #
# Line terminations are marked by '\r\n' = 0x0d0a.        #
#=========================================================#
# Ref: ... ???                                            #
###########################################################
sub parse_app12 {
    my ($this) = @_;
    # compile once and for all the following regular expression,
    # which captures a [groupname]; the name can contain alphanumeric
    # characters, underscores and spaces (this is a guess ...)
    my $groupname = qr/^\[([ \w]*)\]/;
    # search the string "[user]" in the data area; it seems to
    # separate the ascii data area from the binary data area.
    # If the string is not there ($limit = -1), convert this value
    # to the past-the-end character.
    my $limit = index $this->data(0, $this->size()), "[user]";
    $limit = $this->size() if $limit == -1;
    # get all segment data up to the $limit and split in lines
    # (each line is terminated by carriage-return + line-feed)
    my @lines = split /\r\n/, $this->data(0, $limit);
    # extract the first line out of @lines, because it must be
    # treated differently. It seems that this line contains some
    # null characters, but I don't want to split it further ...
    my $preamble = shift @lines;
    $this->store_record('MakerInfo', $ASCII, \ $preamble, length $preamble);
    # each group will be written to a different subdirectory
    my $dirref = undef;
    # for each line in the ascii data area, except the first ...
    for (@lines) {
	# if the line is like "[groupname]", extract the group name
	# from the square brackets and create a new subdirectory
	if (/^$groupname$/) { $dirref = $this->provide_subdirectory($1); } 
	# otherwise, split the line on "="; on the left we find the 
	# tag name, on the right the ascii value(s). Store, in the
	# appropriate subdirectory, a non-numeric record.
	else { my ($tag, $vals) = split /=/, $_;
	       $this->store_record($dirref,$tag,$ASCII,\$vals,length $vals); }
    }
    # it's time to take care of the binary data area. We can't rely
    # on line terminations here, so a different strategy is necessary.
    # First, the remainig of the data area is copied in a variable ...
    my $binary = $this->data($limit, $this->size() - $limit);
    # ... then this variable is slowly consumed
    while (0 != length $binary) {
	# match the [groupname] string. It must be at the beginning
	# of $$binary_ref, otherwise something is going wrong ...
	$binary =~ /$groupname/;
	die "Error while decoding binary data in $this->{name}" if $-[0] != 0;
	# the subgroup matches the groupname (without the square
	# brackets); assume the rest, up to the end, is the value
	my $tag = $1; 
	my $val = substr $binary, $+[0];
	# but if we find another [groupname],
	# we change our mind on where the value ends
	$val = substr($val, 0, $-[0]) if $val =~ /$groupname/;
	# take out the group name and the value from binary, then
	# save them in a non-numeric record as undefined bytes (add
	# 2 to the length sum, this counts the two square brackets)
	$binary = substr($binary, length($tag) + length($val) + 2);
	$this->store_record($tag, $UNDEF, \$val, length $val);
    }
}

###########################################################
# This method parses an APP13 segment, often used by pho- #
# to-manipulation programs to store IPTC (International   #
# Press Telecommunications Council) tags, although this   #
# isn't a formally defined standard (first adopted by     #
# Adobe). The structure of an APP13 segment is as follows #
#---------------------------------------------------------#
# 14 bytes  identifier = "Photoshop 3.0\000"              #
#   .....   sequence of Photoshop Image Resource blocks   #
#=========================================================#
# The sequence of resource blocks may require additional  #
# APP13 markers, whose order is always to be preserved.   #
# TODO: implement parsing of multiple blocks!!!!          #
#=========================================================#
# Ref: "Adobe Photoshop 6.0: File Formats Specifications",#
#      Adobe System Inc., ver.6.0, rel.2, November 2000.  #
# and  "\"Solo\" Image File Format. RichTIFF and its      #
#       replacement by \"Solo\" JFIF", version 2.0a,      #
#       Coatsworth Comm. Inc., Brampton, Ontario, Canada  #
###########################################################
sub parse_app13 {
    my ($this) = @_;
    my $offset = 0;
    # they say that this segment always starts with a specific
    # string from Adobe, namely "Photoshop 3.0\000". For the
    # time being, die if you find something else
    my $identifier = $this->store_record
	('Identifier', $ASCII, $offset, 14)->get_value();
    die "APP13 identif. not found "
	. "(expected='$APP13_PHOTOSHOP_IDENTIFIER', found '$identifier')" 
	if $identifier ne $APP13_PHOTOSHOP_IDENTIFIER;
    # not much to do now, except calling repeatedly a method for
    # parsing resource data blocks. The argument is the current
    # offset, and the output is the new offset after the block
    $offset = $this->parse_resource_data_block($offset)
	while ($offset < $this->size());
    # complain if we read a bit too much ...
    $this->test_size($offset, "parsed after segment end");
}

###########################################################
# This method parses an APP13 resource data block (TODO:  #
# blocks spanning multiple APP13s). Currently, it treates #
# in details IPTC (International Press Telecommunications #
# Council) blocks, and just lists the other tags (which   #
# are, however, in general, much simpler). The only argu- #
# ment is the current offset in the data area of this     #
# object. The output is the new offset after this block.  #
# The structure of a resource data block is:              #
#---------------------------------------------------------#
#  4 bytes  type (Photoshop always uses "8BIM")           #
#  2 bytes  unique identifier (e.g. "\004\004" for IPTC)  #
#  1 byte   length of resource data block name            #
#   ....    name (padded to make size even incl. length)  #
#  4 bytes  size of resource data (following data only)   #
#   ....    data (padded to make size even)               #
#=========================================================#
# Ref: "Adobe Photoshop 6.0: File Formats Specifications",#
#      Adobe System Inc., ver.6.0, rel.2, November 2000.  #
# and  "\"Solo\" Image File Format. RichTIFF and its      #
#       replacement by \"Solo\" JFIF", version 2.0a,      #
#       Coatsworth Comm. Inc., Brampton, Ontario, Canada  #
###########################################################
sub parse_resource_data_block {
    my ($this, $offset) = @_;
    # An "Adobe Phostoshop" block starts with the string "8BIM".
    # Does anybody know the meaning of this achronim?
    my $type = $this->read_record($ASCII, $offset, 4);
    die "APP13 resource type not found "
	. " (expected='$APP13_PHOTOSHOP_TYPE', found '$type')"
	if $type ne $APP13_PHOTOSHOP_TYPE;
    # then there is the block identifier
    my $identifier = $this->read_record($SHORT, $offset);
    # get the name length and the name. The length is the first byte.
    # The name can be padded so that length+name span an even number
    # of bytes. Usually the name is "", so we get "\000\000" here.
    my $name_length = $this->read_record($BYTE, $offset);
    my $name = $this->read_record($ASCII, $offset, $name_length);
    # read the padding byte if length was even
    $this->read_record($UNDEF, $offset, 1) if ($name_length % 2) == 0;
    # the next four bytes encode the resource data size. Also in this
    # case the total size must be padded to an even number of bytes
    my $data_length = $this->read_record($LONG, $offset);
    my $need_padding = ($data_length % 2) ? 1 : 0;
    # check that there is enough data for this block; obviously, this
    # break the case of a resource data block spanning multiple segments!
    $this->test_size($offset + $data_length + $need_padding,
		     "in IPTC resource data block");
    # calculate the absolute end of the resource data block
    my $boundary = $offset + $data_length;
    # currently, the IPTC block deserves as special treatment
    if ($identifier eq $APP13_PHOTOSHOP_IPTC) {
	# create the IPTC subdirectory reference
	$this->provide_subdirectory("IPTC_RECORD_2");
	# now, repeatedly read data from the data block, till and
	# amount of data equal to $data_length has been read; this
	# routine, as usual, returns the new working offset at the end.
	# The IPTC records are written in a separate subdirectory.
	$offset = $this->parse_IPTC_dataset($offset) while ($offset<$boundary);
    } else {
	# less interesting tags are mistreated ...
	$this->store_record($identifier, $UNDEF, $offset, $data_length);
    }
    # if $name is non-trivial, it (should) correspond to the resource
    # block description; in any case, it needs to be remembered (store
    # it in the "extra" field). (is this old-style or new-style?).
    $this->search_record("LAST_RECORD")->{extra} = $name if $name ne "\000";
    # pad, if you need padding ...
    ++$offset if $need_padding;
    # that's it, return the working offset
    return $offset;
}

###########################################################
# This method parses one dataset from an APP13 IPTC re-   #
# cord. The $offset argument is a pointer in the segment  #
# data area, which must be returned updated at the end of #
# the routine. An IPTC record is a sequence of datasets,  #
# which need not be in numerical order, unless otherwise  #
# specified. Each dataset consists of a unique tag and a  #
# data field. A standard tag is used when the data field  #
# size is less than 32768 bytes; otherwise, an extended   #
# tag is used. The structure of a dataset is:             #
#---------------------------------------------------------#
#  1 byte   tag marker (must be 0x1c)                     #
#  1 byte   record number (always 2 for 2:xx datasets)    #
#  1 byte   dataset number                                #
#  2 bytes  data length (< 32768 octets) or length of ... #
#  <....>   data length (> 32767 bytes only)              #
#   ....    data (its length is specified before)         #
#=========================================================#
# So, standard datasets have a 5 bytes tag; the last two  #
# bytes in the tag contain the data field length, the msb #
# being always 0. For extended datasets instead, these    #
# two bytes contain the length of the (following) data    #
# field length, the msb being always 1. The value of the  #
# msb thus distinguishes "standard" from "extended"; in   #
# digital photographies, I assume that the datasets which #
# are actually used (a subset of the standard) are always #
# standard; therefore, we are likely not to have the IPTC #
# record not spanning more than one APP13 segment.        #
#=========================================================#
# The record types defined by the IPTC-NAA standard are:  #
#                                                         #
# Object Envelop Record:    datasets in the range of 1:xx #
# Application Records:                  2:xx through 6:xx #
# Pre-ObjectData Descriptor Record:            7:xx       #
# ObjectData Record:                           8:xx       #
# Post-ObjectData Descriptor Record:           9:xx       #
#                                                         #
# The "pseudo"-standard by Adobe for APP13 IPTC data is   #
# restricted to the first application record (2:xx). (?)  #
#=========================================================#
# Ref: "IPTC-NAA: Information Interchange Model Version 4"#
#      Comité Internat. des Télécommunications de Presse. #
###########################################################
sub parse_IPTC_dataset {
    my ($this, $offset) = @_;
    # each record is a sequence of variable length data sets read the
    # first four fields (five bytes), and store them in local variables.
    my $marker  = $this->read_record($BYTE , $offset);
    my $rnumber = $this->read_record($BYTE , $offset);
    my $dataset = $this->read_record($BYTE , $offset);
    my $length  = $this->read_record($SHORT, $offset);
    # check that the tag marker is 0x1c as specified by the IPTC standard
    die "Invalid APP13 IPTC tag marker "
	. "(expected='$APP13_IPTC_TAGMARKER', found '$marker')"
	if $marker ne $APP13_IPTC_TAGMARKER;
    # check that the record number is 2 (for 2:xx datasets).
    # I think that this is the only relevant record for photos.
    die "IPTC record != 2 ($rnumber) found" if $rnumber != 2;
    # if $length has the msb set, then we are dealing with an
    # extended dataset. In this case, abort and debug
    die "IPTC extended datasets not yet supported" if $length & (0x01 << 15);
    # get the subdir reference (create it if it is not there)
    my $dirref = $this->provide_subdirectory("IPTC_RECORD_2");
    # push a new record reference in the correct subdir. Use the
    # dataset number as identifier, the rest is strightforward
    # (assume that the data type is always ASCII).
    $this->store_record($dirref, $dataset, $ASCII, $offset, $length);
    # return the update offset
    return $offset;
}

###########################################################
# This method parses a misterious Adobe APP14 segment.    #
# Adobe uses this segment to record information at the    #
# time of compression such as whether or not the sample   #
# values were blended and which color transform was       #
# performed upon the data. The format is the following:   #
#---------------------------------------------------------#
#  5 bytes  "Adobe" as identifier (non null-terminated)   #
#  2 bytes  DCTEncode/DCTDecode version number (0x65)     #
#  2 bytes  flags0                                        #
#  2 bytes  flags1                                        #
#  1 byte   transform code                                #
#=========================================================#
# Ref: "Supporting the DCT Filters in PostScript Level 2",#
#      Adobe Developer Support, Tech. note #5116, pag.27  #
###########################################################
sub parse_app14 {
    my ($this) = @_;
    my $offset = 0;
    # exactly 12 bytes, or die
    $this->test_size(12);
    # they say that this segment always starts with a specific
    # string from Adobe, namely "Adobe". For the time being,
    # die if you find something else
    my $identifier = $this->store_record
	('Identifier', $ASCII, $offset, 5)->get_value();
    die "APP14 identif. not found "
	. "(expected='$APP14_PHOTOSHOP_IDENTIFIER', found '$identifier')"
	if $identifier ne $APP14_PHOTOSHOP_IDENTIFIER;
    # the rest is trivial
    $this->store_record('DCT_TransfVersion' , $SHORT, $offset   );
    $this->store_record('Flags0'            , $UNDEF, $offset, 2);
    $this->store_record('Flags1'            , $UNDEF, $offset, 2);
    $this->store_record('TransformationCode', $BYTE,  $offset   );
}

###########################################################
# This method parses a Quantization Table (DQT) segment,  #
# which can specify one or more quantization tables. The  #
# structure is the following:                             #
#------ multiple times -----------------------------------#
#  4 bits   quantization table element precision          #
#  4 bits   quantization table destination identifier     #
# 64 times  quantization table elements                   #
#---------------------------------------------------------#
# Quantization table elements span either 1 or 2 bytes,   #
# depending on the precision (0 -> 1 byte, 1 -> 2 bytes). #
###########################################################
# Ref: "Digital compression and coding of continuous-tone #
#       still images: requirements and guidelines", CCITT #
#       recommendation T.81, 09/1992, pag. 39-40.         #
###########################################################
sub parse_dqt {
    my ($this) = @_;
    my $offset = 0;
    # there can be multiple quantization tables
    while ($offset < $this->size()) {
	# read a byte, containing the quantization table element
	# precision (first nibble) and the destination identifier.
	my $precision = $this->store_record
	    ('PrecisionAndIdentifier', $NIBBLES, $offset)->get_value(0);
        # Then decode the first four bits to get the size
	# of the table (64 bytes or 128 bytes).
	my $element_size = ($precision == 0) ? 1 : 2;
	my $table_size = $element_size * 64;
	# check that there is enough data
	$this->test_size($offset + $table_size);
	# read the table in (always 64 elements, but bytes or shorts)
	$this->store_record('QuantizationTable',
			    $element_size == 1 ? $BYTE : $SHORT, $offset, 64);
    }
}

###########################################################
# This method parses a Huffman table (DHT) segment, which #
# can specify one or more Huffman tables. The structure   #
# is the following:                                       #
#------ multiple times -----------------------------------#
#  4 bits   table class                                   #
#  4 bits   destination identifier                        #
# 16 bytes  number of Huffman codes of given length for   #
#           each of the 16 possible lengths.              #
#  .....    values associated with each Huffman code;     #
#           each value needs a byte, and the total number #
#           of values is the sum of the previous 16 bytes #
###########################################################
# Ref: "Digital compression and coding of continuous-tone #
#       still images: requirements and guidelines", CCITT #
#       recommendation T.81, 09/1992, pag. 40-41.         #
###########################################################
sub parse_dht {
    my ($this) = @_;
    my $offset = 0;
    my $huffman_codes = 16;
    # there can be multiple Huffman tables
    while ($offset < $this->size()) {
	# read a byte, containing the table class and destination
	$this->store_record('ClassAndIdentifier', $NIBBLES, $offset);
	# read the number of Huffman codes of length i
	# (i in 1..16) as a single multi-valued record,
	# then extract the sum of all these values
	my $huffman_size = $this->store_record
	    ('CodeLengths', $BYTE, $offset, $huffman_codes)->get_value();
	# extract of values associated with all Huffman codes
	# as a single multi-valued record
	$this->store_record('CodeData', $BYTE, $offset, $huffman_size);
    }
    # be sure there is no size mismatch
    $this->test_size($offset);
}

###########################################################
# This method parses an Arithmetic Coding table (DAC)     #
# segment, which can specify one or more arithmetic co-   #
# ding conditioning tables (replacing the default one set #
# up by the SOI segment). The structure is the following: #
#------ multiple times -----------------------------------#
#  4 bits   table class                                   #
#  4 bits   destination identifier                        #
#  1 byte   conditioning table value                      #
###########################################################
# Ref: "Digital compression and coding of continuous-tone #
#       still images: requirements and guidelines", CCITT #
#       recommendation T.81, 09/1992, sec.B.2.43, pag.42. #
###########################################################
sub parse_dac {
    my ($this) = @_;
    my $offset = 0;
    # there can be multiple Huffman tables
    while ($offset < $this->size()) {
	# read a byte, containing the table class and destination,
	# then another byte with the conditioning table value
	$this->store_record('ClassAndIdentifier'    , $NIBBLES, $offset);
	$this->store_record('ConditioningTableValue', $BYTE,    $offset);
    }
    # be sure there is no size mismatch
    $this->test_size($offset);
}

###########################################################
# This method parses an EXPansion segment (EXP), which    #
# specifies horizontal and vertical expansion parameters  #
# for the next frame. The structure is the following:     #
#------ multiple times -----------------------------------#
#  4 bits   horizontal expansion coefficient              #
#  4 bits   vertical expansion coefficient                #
###########################################################
# Ref: "Digital compression and coding of continuous-tone #
#       still images: requirements and guidelines", CCITT #
#       recommendation T.81, 09/1992, sec.B.3.3, pag.46.  #
###########################################################
sub parse_exp {
    my ($this) = @_;
    # this segments contains exactly one data byte
    $this->test_size(-1);
    # read a byte, containing both expansion coefficients
    $this->store_record('ExpansionCoefficients', $NIBBLES, 0);
}

###########################################################
# This method parses a Define Num of Lines (DNL) segment. #
# Such a segment provides a mechanism for defining or re- #
# defining the number of lines in the frame at the end of #
# the first scan. This marker segment is mandatory if the #
# number of lines specified in the frame header has the   #
# value zero. The structure is the following:             #
#---------------------------------------------------------#
#  2 bytes  number of lines in the frame.                 #
###########################################################
# Ref: "Digital compression and coding of continuous-tone #
#       still images: requirements and guidelines", CCITT #
#       recommendation T.81, 09/1992, sec.B.2.5, pag.45.  #
###########################################################
sub parse_dnl {
    my ($this) = @_;
    die "dnl";
    # exactly two bytes, plese
    $this->test_size(-2);
    # read the number of lines
    $this->store_record('NumberOfLines', $SHORT, 0);
}

###########################################################
# This method parses a Define Restart Interval (DRI) seg- #
# ment. There is only one parameter in this segment, and  #
# it specifies the number of MCU (minimum coding units)   #
# in the restart interval; a value equal to zero disables #
# the mechanism. The structure is the following:          #
#---------------------------------------------------------#
#  2 bytes  number of MCU in the restart interval.        #
###########################################################
# Ref: "Digital compression and coding of continuous-tone #
#       still images: requirements and guidelines", CCITT #
#       recommendation T.81, 09/1992, sec.B.2.4.4, pag.43.#
###########################################################
sub parse_dri {
    my ($this) = @_;
    # exactly two bytes, plese
    $this->test_size(-2);
    # read the number of MCU in the interval
    $this->store_record('NumMCU_inInterval', $SHORT, 0);
}

###########################################################
# This method parses a Start Of Frame (SOF) segment (but  #
# also a DHP segment, see note at the end). Such a seg-   #
# ment specifies the source image characteristics, the    #
# components in the frame, and the sampling factors for   #
# each components, and specifies the destinations from    #
# which the quantised tables to be used with each compo-  #
# nent are retrieved. The structure is:                   #
#---------------------------------------------------------#
#  1 byte   sample precision (in bits)                    #
#  2 bytes  maximum number of lines in source image       #
#  2 bytes  max. num. of samples per line in source image #
#  1 byte   number N of image components in frame         #
#------ N times ------------------------------------------#
#  1 byte   component identifier                          #
#  4 bits   horizontal sampling factor                    #
#  4 bits   vertical sampling factor                      #
#  1 byte   quantisation table destination selector       #
#=========================================================#
# A DHP segment defines the image components, size and    #
# sampling factors for the completed hierarchical sequence#
# of frames. It precedes the first frame, and its struc-  #
# ture is identical to the frame header syntax, except    #
# that the quantisation table destination selector is 0.  #
#=========================================================#
# The meaning of the different SOF segments is this:      #
#                                                         #
#   / Baseline \     (extended)   Progressive   Lossless  #
#   \  SOF_0   /     sequential                           #
#                                                         #
# (normal)             SOF_1         SOF_2        SOF_3   #
# Differential         SOF_5         SOF_6        SOF_7   #
# Arithmetic coding    SOF_9         SOF_A        SOF_B   #
# Diff., arithm.cod.   SOF_D         SOF_E        SOF_F   #
#=========================================================#
# Ref: "Digital compression and coding of continuous-tone #
#       still images: requirements and guidelines", CCITT #
#       recommendation T.81, 09/1992, sec.B.2.2, pag.35-36#
#       (DHP --> sec. B.3.2, pag. 46).                    #
###########################################################
sub parse_sof {
    my ($this) = @_;
    my $offset = 0;
    my $minimum_size = 6;
    # at least six bytes, plese
    $this->test_size($minimum_size);
    # read the first four values (the last value is
    # the number of image components in this frame)
    $this->store_record('SamplePrecision'  , $BYTE , $offset);
    $this->store_record('MaxLineNumber'    , $SHORT, $offset);
    $this->store_record('MaxSamplesPerLine', $SHORT, $offset);
    my $components = $this->store_record
	('ImageComponents', $BYTE , $offset)->get_value();
    # the number of image components allows us to calculate
    # the size of the remaining part of the segment
    $this->test_size($offset + 3*$components, "in component block");
    # scan all the frame component
    for (1..$components) {
	# three values per component
	$this->store_record('ComponentIdentifier'  , $BYTE   , $offset);
	$this->store_record('SamplingFactors'      , $NIBBLES, $offset);
	$this->store_record('QTDestinationSelector', $BYTE   , $offset);
    }
}

###########################################################
# This method parses the Start Of Scan (SOS) segment: it  #
# gives various scan-related parameters and introduces    #
# the JPEG raw data. The structure is the following:      #
#---------------------------------------------------------#
#  1 byte   number n of components in scan                #
#------------ n times ----------------------------------- #
#  1 byte   scan component selector                       #
#  4 bits   DC entropy coding table destination selector  #
#  4 bits   AC entropy coding table destination selector  #
#---------------------------------------------------------#
#  1 byte   start of spectral or prediction selection     #
#  1 byte   end of spectral selection                     #
#  2 nibbles Successive approximation bit position        #
###########################################################
# Ref: "Digital compression and coding of continuous-tone #
#       still images: requirements and guidelines", CCITT #
#       recommendation T.81, 09/1992, pag. 37-38.         #
###########################################################
sub parse_sos {
    my ($this) = @_;
    my $offset = 0;
    # read the number of components in the scan and calculate
    # the length of this segment; then, compare with what we
    # have in reality and produce an error if they differ
    my $components = $this->store_record
	('ScanComponents', $BYTE, $offset)->get_value();
    $this->test_size(-(1 + $components * 2 + 3));
    # Read two bytes for each component. The first byte is the
    # scan component selector (as numbered in the frame header);
    # the second byte contains the DC/AC entropy coding table
    # destination selector (a nibble each).
    for (1..$components) {
	$this->store_record('ComponentSelector', $BYTE,    $offset);
	$this->store_record('EntropySelector'  , $NIBBLES, $offset); }
    # the meaning of the last three bytes is the following:
    # 1) Start of spectral or prediction selection
    # 2) End of spectral selection
    # 3) Successive approximation bit position (2 nibbles)
    $this->store_record('SpectralSelectionStart'     , $BYTE,    $offset);
    $this->store_record('SpectralSelectionEnd'       , $BYTE,    $offset);
    $this->store_record('SuccessiveApproxBitPosition', $NIBBLES, $offset);
}

# successful package load
1;
