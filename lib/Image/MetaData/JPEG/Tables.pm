###########################################################
# A Perl package for showing/modifying JPEG (meta)data.   #
# Copyright (C) 2004 Stefano Bettelli                     #
# See the COPYING and LICENSE files for license terms.    #
###########################################################
package Image::MetaData::JPEG::Tables;
use Exporter;
use strict;
no  integer;

#============================================================================#
#============================================================================#
#============================================================================#
# This section defines the attitude of this module to export; no variable or #
# method is exported by default. Everything is exportable via %EXPORT_TAGS.  #
#----------------------------------------------------------------------------#
our @ISA         = qw(Exporter);                                             #
our @EXPORT      = qw();                                                     #
our @EXPORT_OK   = qw();                                                     #
our %EXPORT_TAGS =                                                           #
    (RecordTypes => [qw($NIBBLES $BYTE $ASCII $SHORT $LONG $RATIONAL),       #
		     qw($SBYTE $UNDEF $SSHORT $SLONG $SRATIONAL $FLOAT),     #
		     qw($DOUBLE $REFERENCE)],                                #
     RecordProps => [qw(@JPEG_RECORD_TYPE_NAME @JPEG_RECORD_TYPE_LENGTH),    #
		     qw(@JPEG_RECORD_TYPE_CATEGORY @JPEG_RECORD_TYPE_SIGN)], #
     Endianness  => [qw($BIG_ENDIAN $LITTLE_ENDIAN)],                        #
     JPEGgrammar => [qw($JPEG_PUNCTUATION %JPEG_MARKER)],                    #
     TagsAPP0    => [qw($APP0_JFIF_TAG $APP0_JFXX_TAG $APP0_JFXX_JPG),       #
		     qw($APP0_JFXX_1B $APP0_JFXX_3B $APP0_JFXX_PAL)],        #
     TagsAPP1    => [qw($APP1_EXIF_TAG $APP1_XMP_TAG $APP1_TIFF_SIG),        #
		     qw($APP1_TH_JPEG $APP1_TH_TIFF $APP1_TH_TYPE),          #
		     qw($THJPEG_OFFSET $THJPEG_LENGTH),                      #
		     qw($THTIFF_OFFSET $THTIFF_LENGTH),                      #
		     qw(%HASH_GPS_GENERAL %IFD_SUBDIRS)],                    #
     TagsAPP2    => [qw($APP2_FPXR_TAG $APP2_ICC_TAG)],                      #
     TagsAPP3    => [qw($APP3_EXIF_TAG %IFD_SUBDIRS)],                       #
     TagsAPP13   => [qw($APP13_PHOTOSHOP_IPTC $APP13_PHOTOSHOP_IDENTIFIER),  #
		     qw($APP13_PHOTOSHOP_TYPE $APP13_IPTC_TAGMARKER),        #
		     qw(%HASH_IPTC_GENERAL)],                                #
     TagsAPP14   => [qw($APP14_PHOTOSHOP_IDENTIFIER)],                       #
     Lookups     => [qw(&JPEG_lookup)], );                                   #
#----------------------------------------------------------------------------#
Exporter::export_ok_tags                                                     #
    qw(RecordTypes RecordProps Endianness JPEGgrammar),                      #
    qw(TagsAPP0 TagsAPP1 TagsAPP2 TagsAPP3 TagsAPP13 TagsAPP14 Lookups);     #
#============================================================================#
#============================================================================#
#============================================================================#
# Constants for the grammar of a JPEG files. You can find here everything    #
# about segment markers as well as the JPEG puncutation mark.                # 
#----------------------------------------------------------------------------#
our $JPEG_PUNCTUATION = 0xff; # constant prefixed to every JPEG marker       #
our %JPEG_MARKER =            # non-repetitive JPEG markers                  #
    (TEM => 0x01,  # for TEMporary private use in arithmetic coding          #
     DHT => 0xc4,  # Define Huffman Table(s)                                 #
     JPG => 0xc8,  # reserved for JPEG extensions                            #
     DAC => 0xcc,  # Define Arithmetic Coding Conditioning(s)                #
     SOI => 0xd8,  # Start Of Image                                          #
     EOI => 0xd9,  # End Of Image                                            #
     SOS => 0xda,  # Start Of Scan                                           #
     DQT => 0xdb,  # Define Quantization Table(s)                            #
     DNL => 0xdc,  # Define Number of Lines                                  #
     DRI => 0xdd,  # Define Restart Interval                                 #
     DHP => 0xde,  # Define Hierarchical Progression                         #
     EXP => 0xdf,  # EXPand reference component(s)                           #
     COM => 0xfe); # COMment block                                           #
#----------------------------------------------------------------------------#
# markers 0x02 --> 0xbf are REServed for future uses                         #
for (0x02..0xbf) { $JPEG_MARKER{sprintf "res%02x", $_} = $_; }               #
# some markers in 0xc0 --> 0xcf correspond to Start-Of-Frame typologies      #
for (0xc0..0xc3, 0xc5..0xc7, 0xc9..0xcb,                                     #
     0xcd..0xcf) { $JPEG_MARKER{sprintf "SOF_%d", $_ - 0xc0} = $_; }         #
# markers 0xd0 --> 0xd7 correspond to ReSTart with module 8 count            #
for (0xd0..0xd7) { $JPEG_MARKER{sprintf "RST%d", $_ - 0xd0} = $_; }          #
# markers 0xe0 --> 0xef are the APPlication markers                          #
for (0xe0..0xef) { $JPEG_MARKER{sprintf "APP%d", $_ - 0xe0} = $_; }          #
# markers 0xf0 --> 0xfd are reserved for JPEG extensions                     #
for (0xf0..0xfd) { $JPEG_MARKER{sprintf "JPG%d", $_ - 0xf0} = $_; }          #
#============================================================================#
#============================================================================#
#============================================================================#
# Functions for generating lookup tables [hashes] (arg0=hashref,arg1=index)  #
# or arrays (arg0=hashref, arg1=index) from hashes; it is assumed that the   #
# general hash they work on has array references as values.                  #
# -------------------------------------------------------------------------- #
sub generate_lookup { map { $_ => $_[0]{$_}[$_[1]] } keys %{$_[0]} };        #
sub generate_array  { map { $_[0]{$_}[$_[1]] } (0..(-1+scalar keys %{$_[0]}))};
#============================================================================#
#============================================================================#
#============================================================================#
# Various lists for JPEG record names, lengths, categories and signs; see    #
# Image::MetaData::JPEG::Record class for further details. The general hash  #
# is private to this file, the other arrays are exported if so requested.    #
# -------------------------------------------------------------------------- #
# I gave up trying to calculate the length of a reference. This is probably  #
# allocation dependent ... I use 0 here, meaning the length is variable.     #
#============================================================================#
my %RECORD_TYPE_GENERAL =                                                    #
    ((our $NIBBLES   =  0) => [ 'NIBBLES'   , 1, 'I', 'N' ],                 #
     (our $BYTE      =  1) => [ 'BYTE'      , 1, 'I', 'N' ],                 #
     (our $ASCII     =  2) => [ 'ASCII'     , 0, 'S', 'N' ],                 #
     (our $SHORT     =  3) => [ 'SHORT'     , 2, 'I', 'N' ],                 #
     (our $LONG      =  4) => [ 'LONG'      , 4, 'I', 'N' ],                 #
     (our $RATIONAL  =  5) => [ 'RATIONAL'  , 8, 'R', 'N' ],                 #
     (our $SBYTE     =  6) => [ 'SBYTE'     , 1, 'I', 'Y' ],                 #
     (our $UNDEF     =  7) => [ 'UNDEF'     , 0, 'S', 'N' ],                 #
     (our $SSHORT    =  8) => [ 'SSHORT'    , 2, 'I', 'Y' ],                 #
     (our $SLONG     =  9) => [ 'SLONG'     , 4, 'I', 'Y' ],                 #
     (our $SRATIONAL = 10) => [ 'SRATIONAL' , 8, 'R', 'Y' ],                 #
     (our $FLOAT     = 11) => [ 'FLOAT'     , 4, 'F', 'N' ],                 #
     (our $DOUBLE    = 12) => [ 'DOUBLE'    , 8, 'F', 'N' ],                 #
     (our $REFERENCE = 13) => [ 'REFERENCE' , 0, 'p', 'N' ],    );           #
#----------------------------------------------------------------------------#
our @JPEG_RECORD_TYPE_NAME     = generate_array(\ %RECORD_TYPE_GENERAL, 0);  #
our @JPEG_RECORD_TYPE_LENGTH   = generate_array(\ %RECORD_TYPE_GENERAL, 1);  #
our @JPEG_RECORD_TYPE_CATEGORY = generate_array(\ %RECORD_TYPE_GENERAL, 2);  #
our @JPEG_RECORD_TYPE_SIGN     = generate_array(\ %RECORD_TYPE_GENERAL, 3);  #
#============================================================================#
#============================================================================#
#============================================================================#
# various interesting constants which are not tags (mostly record values)    #
#============================================================================#
our $BIG_ENDIAN			= 'MM';                                      #
our $LITTLE_ENDIAN		= 'II';                                      #
our $APP0_JFIF_TAG		= "JFIF\000";                                #
our $APP0_JFXX_TAG		= "JFXX\000";                                #
our $APP0_JFXX_JPG		= 0x10;                                      #
our $APP0_JFXX_1B		= 0x11;                                      #
our $APP0_JFXX_3B		= 0x13;                                      #
our $APP0_JFXX_PAL		= 768;                                       #
our $APP1_EXIF_TAG		= "Exif\000\000";                            #
our $APP1_XMP_TAG		= "http://ns.adobe.com/xap/1.0/\000";        #
our $APP1_TIFF_SIG		= 42;                                        #
our $APP1_TH_TIFF		= 1;                                         #
our $APP1_TH_JPEG		= 6;                                         #
our $APP2_FPXR_TAG		= "FPXR\000";                                #
our $APP2_ICC_TAG		= "ICC_PROFILE\000";                         #
our $APP3_EXIF_TAG		= "Meta\000\000";                            #
our $APP13_PHOTOSHOP_IDENTIFIER	= "Photoshop 3.0\000";                       #
our $APP13_PHOTOSHOP_TYPE	= '8BIM';                                    #
our $APP13_PHOTOSHOP_IPTC	= 0x0404;                                    #
our $APP13_IPTC_TAGMARKER	= 0x1c;                                      #
our $APP14_PHOTOSHOP_IDENTIFIER	= 'Adobe';                                   #
#----------------------------------------------------------------------------#

# Tags used by the 0th and 1st IFD. The tags are the same, only the
# support level changes (that for the 1st IFD is indicated if different)
#   0: tags from TIFF 6.0 specs not in Exif 2.2
#   1: extensions to TIFF 6.0 specs not in Exif 2.2
#   2: TIFF 6.0 tags for document storage and retrival not in Exif 2.2
#   3: TIFF 6.0 tags for tiled images
#   4: TIFF 6.0 tags for CMYK images
#   5: TIFF 6.0 tags for data sample formats
#   6: TIFF 6.0 tags for JPEGs (but real JPEGs use segments!)
#   A: tags relating to image data structure (Exif 2.2 and TIFF 6.0)
#   B: tags relating to recording offset (Exif 2.2 and TIFF 6.0)
#   C: tags relating to image data characteristics (Exif 2.2 and TIFF 6.0)
#   C: other tags <see also A,B,C> (Exif 2.2 and TIFF 6.0)
#   D: pointers to other IFDs (EXIF 2.2)
#   x: tags registered to companies
our %HASH_APP1_IFD =
    (0x00fe => 'NewSubfileType',              # 0
     0x00ff => 'SubFileType',                 # 0
     0x0100 => 'ImageWidth',                  # A (JPEG marker)
     0x0101 => 'ImageLength',                 # A (JPEG marker)
     0x0102 => 'BitsPerSample',               # A (JPEG marker)
     0x0103 => 'Compression',                 # A (JPEG marker)  mandatory
     0x0106 => 'PhotometricInterpretation',   # A (not JPEG)
     0x0107 => 'Thresholding',                # 0
     0x0108 => 'CellWidth',                   # 0
     0x0109 => 'CellLength',                  # 0 
     0x010a => 'FillOrder',                   # 0
     0x010d => 'DocumentName',                # 2
     0x010e => 'ImageDescription',            # C recommended    optional
     0x010f => 'Make',                        # C recommended    optional
     0x0110 => 'Model',                       # C recommended    optional
     0x0111 => 'StripOffsets',                # B (not JPEG)
     0x0112 => 'Orientation',                 # A recommended
     0x0115 => 'SamplesPerPixel',             # A (JPEG marker)
     0x0116 => 'RowsPerStrip',                # B (not JPEG)
     0x0117 => 'StripByteCounts',             # B (not JPEG)
     0x0118 => 'MinSampleValue',              # 0
     0x0119 => 'MaxSampleValue',              # 0
     0x011a => 'XResolution',                 # A mandatory
     0x011b => 'YResolution',                 # A mandatory
     0x011c => 'PlanarConfiguration',         # A (JPEG marker)
     0x011d => 'PageName',                    # 2
     0x011e => 'XPosition',                   # 2
     0x011f => 'YPosition',                   # 2
     0x0120 => 'FreeOffsets',                 # 0
     0x0121 => 'FreeByteCounts',              # 0
     0x0122 => 'GrayResponseUnit',            # 0
     0x0123 => 'GrayResponseCurve',           # 0
     0x0124 => 'T4Options',                   # 1 (group 3 options)
     0x0125 => 'T6Options',                   # 1 (group 4 options)
     0x0128 => 'ResolutionUnit',              # A mandatory
     0x0129 => 'PageNumber',                  # 2
     0x012c => 'ColorResponseUnit',           # obsoleted in TIFF 6.0
     0x012d => 'TransferFunction',            # C recommended    optional
     0x0131 => 'Software',                    # C optional
     0x0132 => 'DateTime',                    # C recommended    optional
     0x013b => 'Artist',                      # C optional
     0x013c => 'HostComputer',                # 0
     0x013d => 'Predictor',                   # TIFF 6.0 differencing predictor
     0x013e => 'WhitePoint',                  # C optional
     0x013f => 'PrimaryChromaticities',       # C optional
     0x0140 => 'Colormap',                    # 0
     0x0141 => 'HalftoneHints',               # TIFF 6.0 half tone hints
     0x0142 => 'TileWidth',                   # 3
     0x0143 => 'TileLength',                  # 3
     0x0144 => 'TileOffsets',                 # 3
     0x0145 => 'TileByteCounts',              # 3
     0x0146 => 'BadFaxLines',                 # x
     0x0147 => 'CleanFaxData',                # x
     0x0148 => 'ConsecutiveBadFaxLines',      # x
     0x014a => 'SubIFD',                      # x (subimage descr. support ?)
     0x014c => 'InkSet',                      # 4
     0x014d => 'InkNames',                    # 4
     0x014e => 'NumberOfInks',                # 4
     0x0150 => 'DotRange',                    # 4
     0x0151 => 'TargetPrinter',               # 4
     0x0152 => 'ExtraSamples',                # TIFF 6.0 assoc. alpha handling
     0x0153 => 'SampleFormats',               # 5
     0x0154 => 'SMinSampleValue',             # 5
     0x0155 => 'SMaxSampleValue',             # 5
     0x0156 => 'TransferRange',               # TIFF 6.0 RGB Image colorimetry
     0x0157 => 'ClipPath',                    # [Adobe TIFF technote 2]
     0x0158 => 'XYClipPathUnits',             # [Adobe TIFF technote 2]
     0x0159 => 'Indexed',                     # [Adobe TIFF technote 3]
     0x015b => 'JPEGTables',                  # update (1995) for JPEG-in-TIFF
     0x015f => 'OPIProxy',                    # [Adobe TIFF technote (OPI)]
     0x0200 => 'JPEGProc',                    # 6 (obsoleted by JPEGTables)
     0x0201 => 'JPEGInterchangeFormat',       # B (not JPEG)     mandatory
     0x0202 => 'JPEGInterchangeFormatLength', # B (not JPEG)     mandatory
     0x0203 => 'JPEGRestartInterval',         # 6 (obsoleted by JPEGTables)
     0x0205 => 'JPEGLosslessPredictors',      # 6 (obsoleted by JPEGTables)
     0x0206 => 'JPEGPointTransforms',         # 6 (obsoleted by JPEGTables)
     0x0207 => 'JPEGQTables',                 # 6 (obsoleted by JPEGTables)
     0x0208 => 'JPEGDCTables',                # 6 (obsoleted by JPEGTables)
     0x0209 => 'JPEGACTables',                # 6 (obsoleted by JPEGTables)
     0x0211 => 'YCbCrCoefficients',           # C optional
     0x0212 => 'YCbCrSubSampling',            # A (in JPEG marker)
     0x0213 => 'YCbCrPositioning',            # A mandatory
     0x0214 => 'ReferenceBlackWhite',         # C optional
     0x02bc => 'XML_Packet',                  # [Adobe XMP technote 9-14-02]
     0x800d => 'OPIImageID',                  # [Adobe TIFF technote (OPI)]
     0x80b9 => 'RefPts',                      # x [Island Graphics]
     0x80ba => 'RegionTackPoint',             # x [Island Graphics]
     0x80bb => 'RegionWarpCorners',           # x [Island Graphics]
     0x80bc => 'RegionAffine',                # x [Island Graphics]
     0x80e3 => 'Matteing',                    # x [SGI], obs. by ExtraSamples
     0x80e4 => 'DataType',                    # x [SGI], obs. by SampleFormat
     0x80e5 => 'ImageDepth',                  # x [SGI] (z dimension)
     0x80e6 => 'TileDepth',                   # x [SGI] (subvolume tiling)
     0x8214 => 'ImageFullWidth',              # x [Pixar]
     0x8215 => 'ImageFullLength',             # x [Pixar]
     0x8216 => 'TextureFormat',               # x [Pixar]
     0x8217 => 'WrapModes',                   # x [Pixar]
     0x8218 => 'FovCot',                      # x [Pixar]
     0x8219 => 'MatrixWorldToScreen',         # x [Pixar]
     0x821a => 'MatrixWorldToCamera',         # x [Pixar]
     0x827d => 'WriterSerialNumber',          # x [Eastman Kodak]
     0x8298 => 'Copyright',                   # C optional
     0x83bb => 'RichTIFF_IPTC',               # from RichTIFF specification
     0x84e0 => 'IT8Site',                     # x [ANSI IT8 TIFF/IT]
     0x84e1 => 'IT8ColorSequence',            # x [ANSI IT8 TIFF/IT]
     0x84e2 => 'IT8Header',                   # x [ANSI IT8 TIFF/IT]
     0x84e3 => 'IT8RasterPadding',            # x [ANSI IT8 TIFF/IT]
     0x84e4 => 'IT8BitsPerRunLength',         # x [ANSI IT8 TIFF/IT]
     0x84e5 => 'IT8BitsPerExtendedRunLength', # x [ANSI IT8 TIFF/IT]
     0x84e6 => 'IT8ColorTable',               # x [ANSI IT8 TIFF/IT]
     0x84e7 => 'IT8ImageColorIndicator',      # x [ANSI IT8 TIFF/IT]
     0x84e8 => 'IT8BKG_ColorIndicator',       # x [ANSI IT8 TIFF/IT]
     0x84e9 => 'IT8ImageColorValue',          # x [ANSI IT8 TIFF/IT]
     0x84ea => 'IT8BKG_ColorValue',           # x [ANSI IT8 TIFF/IT]
     0x84eb => 'IT8PixelIntensityRange',      # x [ANSI IT8 TIFF/IT]
     0x84ec => 'IT8TransparencyIndicator',    # x [ANSI IT8 TIFF/IT]
     0x84ed => 'IT8ColorCharacterization',    # x [ANSI IT8 TIFF/IT]
     0x84ee => 'IT8HC_Usage',                 # x [ANSI IT8 TIFF/IT]
     0x84ef => 'IT8TrapIndicator',            # x [ANSI IT8 TIFF/IT]
     0x84f0 => 'IT8CMYK_Equivalent',          # x [ANSI IT8 TIFF/IT]
     0x85b8 => 'FrameCount',                  # x [Texas Instruments]
     0x8649 => 'Photoshop',                   # x [Adobe] for Photoshop
     0x8769 => 'ExifOffset',                  # D mandatory     optional(?)
     0x8773 => 'ICC_Profile',                 # x [Adobe ?]
     0x87be => 'JBIG_Options',                # x [Pixel Magic]
     0x8825 => 'GPSInfo',                     # D optional              (?)
     0x885c => 'FaxRecvParams',               # x [SGI]
     0x885d => 'FaxSubAddress',               # x [SGI]
     0x885e => 'FaxRecvTime',                 # x [SGI]
     0x8871 => 'FedExEDR',                    # x [FedEx]
     0x923f => 'StoNits',                     # x [SGI]
     0xc4a5 => 'PrintIM_Data',                # Epson PIM tag (ref. ?)
     0xffff => 'DCS_HueShiftValues',          # x [Eastman Kodak]
     );

# Tags used for ICC data in APP2 (they are 4 bytes strings, so
# I prefer to write the string and then convert it).
sub str2hex { my $z = 0; ($z *= 256) += $_ for unpack "CCCC", $_[0]; $z; }
our %HASH_APP2_ICC =
    (str2hex('A2B0') => 'AT0B0Tag', 
     str2hex('A2B1') => 'AToB1Tag',
     str2hex('A2B2') => 'AToB2Tag',
     str2hex('bXYZ') => 'BlueMatrixColumn',
     str2hex('bTRC') => 'BlueTRC',
     str2hex('B2A0') => 'BToA0Tag',
     str2hex('B2A1') => 'BToA1Tag',
     str2hex('B2A2') => 'BToA2Tag',
     str2hex('calt') => 'CalibrationDateTime',
     str2hex('targ') => 'CharTarget',
     str2hex('chad') => 'ChromaticAdaptation',
     str2hex('chrm') => 'Chromaticity',
     str2hex('clro') => 'ColorantOrder',
     str2hex('clrt') => 'ColorantTable',
     str2hex('cprt') => 'Copyright',
     str2hex('dmnd') => 'DeviceMfgDesc',
     str2hex('dmdd') => 'DeviceModelDesc',
     str2hex('gamt') => 'Gamut',
     str2hex('kTRC') => 'GrayTRC',
     str2hex('gXYZ') => 'GreenMatrixColumn',
     str2hex('gTRC') => 'GreenTRC',
     str2hex('lumi') => 'Luminance',
     str2hex('meas') => 'Measurement',
     str2hex('bkpt') => 'MediaBlackPoint',
     str2hex('wtpt') => 'MediaWhitePoint',
     str2hex('ncl2') => 'NamedColor2',
     str2hex('resp') => 'OutputResponse',
     str2hex('pre0') => 'Preview0',
     str2hex('pre1') => 'Preview1',
     str2hex('pre2') => 'Preview2',
     str2hex('desc') => 'ProfileDescription',
     str2hex('pseq') => 'ProfileSequenceDesc',
     str2hex('rXYZ') => 'RedMatrixColumn',
     str2hex('rTRC') => 'RedTRC',
     str2hex('tech') => 'Technology',
     str2hex('vued') => 'ViewingCondDesc',
     str2hex('view') => 'ViewingConditions',
     );

# Tags used by the 0-th IFD of an APP3 segment (reference ... ?)
our %HASH_APP3_IFD =
    (0xc350 => 'FilmProductCode',
     0xc351 => 'ImageSource',
     0xc352 => 'PrintArea',
     0xc353 => 'CameraOwner',
     0xc354 => 'CameraSerialNumber',
     0xc355 => 'GroupCaption',
     0xc356 => 'DealerID',
     0xc357 => 'OrderID',
     0xc358 => 'BagNumber',
     0xc359 => 'ScanFrameSeqNumber',
     0xc35a => 'FilmCategory',
     0xc35b => 'FilmGenCode',
     0xc35c => 'ScanSoftware',
     0xc35d => 'FilmSize',
     0xc35e => 'SBARGBShifts',
     0xc35f => 'SBAInputColor',
     0xc360 => 'SBAInputBitDepth',
     0xc361 => 'SBAExposureRec',
     0xc362 => 'UserSBARGBShifts',
     0xc363 => 'ImageRotationStatus',
     0xc364 => 'RollGUID',
     0xc365 => 'APP3Version',
     0xc36e => 'SpecialEffectsIFD', # pointer to an IFD
     0xc36f => 'BordersIFD',        # pointer to an IFD
     );

# Tags used by the private EXIF region in IFD0
# (this is also known as SubIFD, or Exif private tags)
#   a: tags relating to version (EXIF 2.2)
#   b: tags relating to image data characteristics (EXIF 2.2)
#   c: tags relating to image configuration (EXIF 2.2)
#   d: tags relating to user information (EXIF 2.2)
#   e: tags relating to related file information (EXIF 2.2)
#   f: tags relating to date and time (EXIF 2.2)
#   g: tags relating to picture taking conditions (EXIF 2.2) !
#   h: other tags <see also a,b,c,d,e,f,g> (EXIF 2.2)
our %HASH_APP1_SUBIFD =
    (#0x8290 => '?? CameraInfoIFD', # pointer to an IFD
     0x829a => 'ExposureTime',                # g recommended
     0x829d => 'FNumber',                     # g optional
     0x8822 => 'ExposureProgram',             # g optional
     0x8824 => 'SpectralSensitivity',         # g optional
     0x8827 => 'ISOSpeedRatings',             # g optional
     0x8828 => 'OECF',                        # g optional
     0x8829 => 'Interlace',                   # SHORT, 1, TIFF/EP
     0x882a => 'TimeZoneOffset',              # SSHORT, 1or2, TIFF/EP
     0x882b => 'SelfTimerMode',               # SHORT, 1, TIFF/EP
     0x9000 => 'ExifVersion',                 # a mandatory
     0x9003 => 'DateTimeOriginal',            # f optional
     0x9004 => 'DateTimeDigitized',           # f optional
     0x9101 => 'ComponentsConfiguration',     # c mandatory
     0x9102 => 'CompressedBitsPerPixel',      # c optional
     0x9201 => 'ShutterSpeedValue',           # g optional
     0x9202 => 'ApertureValue',               # g optional
     0x9203 => 'BrightnessValue',             # g optional
     0x9204 => 'ExposureBiasValue',           # g optional
     0x9205 => 'MaxApertureValue',            # g optional
     0x9206 => 'SubjectDistance',             # g optional
     0x9207 => 'MeteringMode',                # g optional
     0x9208 => 'LightSource',                 # g optional
     0x9209 => 'Flash',                       # g recommended
     0x920a => 'FocalLength',                 # g optional
     0x920b => 'FlashEnergy',                 # RATIONAL, 1or2, TIFF/EP
     0x920c => 'SpatialFrequencyResponse',    # UNDEFINED, N, TIFF/EP
     0x920d => 'Noise',                       # UNDEFINED, N, TIFF/EP
     0x920e => 'FocalPlaneXResolution',       # RATIONAL, 1, TIFF/EP
     0x920f => 'FocalPlaneYResolution',       # RATIONAL, 1, TIFF/EP
     0x9210 => 'FocalPlaneResolutionUnit',    # SHORT, 1, TIFF/EP
     0x9211 => 'ImageNumber',                 # LONG, 1, TIFF/EP
     0x9212 => 'SecurityClassification',      # ASCII, N, TIFF/EP
     0x9213 => 'ImageHistory',                # ASCII, N, TIFF/EP
     0x9214 => 'SubjectArea',                 # g optional, SubjLoc in TIFF/EP
     0x9215 => 'ExposureIndex',               # RATIONAL, 1or2, TIFF/EP
     0x9216 => 'TIFF/EPStandardID',           # BYTE, 4, TIFF/EP
     0x9217 => 'SensingMethod',               # SHORT, 1, TIFF/EP
     0x927c => 'MakerNote',                   # d optional
     0x9286 => 'UserComment',                 # d optional
     0x9290 => 'SubSecTime',                  # f optional
     0x9291 => 'SubSecTimeOriginal',          # f optional
     0x9292 => 'SubSecTimeDigitized',         # f optional
     0xa000 => 'FlashPixVersion',             # a mandatory
     0xa001 => 'ColorSpace',                  # b mandatory
     0xa002 => 'PixelXDimension',             # c mandatory
     0xa003 => 'PixelYDimension',             # c mandatory
     0xa004 => 'RelatedSoundFile',            # e optional
     0xa005 => 'InteroperabilityOffset',      # D optional
     0xa20b => 'FlashEnergy',                 # g optional
     0xa20c => 'SpatialFrequencyResponse',    # g optional
     0xa20e => 'FocalPlaneXResolution',       # g optional
     0xa20f => 'FocalPlaneYResolution',       # g optional
     0xa210 => 'FocalPlaneResolutionUnit',    # g optional
     0xa214 => 'SubjectLocation',             # g optional
     0xa215 => 'ExposureIndex',               # g optional
     0xa217 => 'SensingMethod',               # g optional
     0xa300 => 'FileSource',                  # g optional
     0xa301 => 'SceneType',                   # g optional
     0xa302 => 'CFAPattern',                  # g optional
     0xa401 => 'CustomRendered',              # g optional
     0xa402 => 'ExposureMode',                # g recommended
     0xa403 => 'WhiteBalance',                # g recommended
     0xa404 => 'DigitalZoomRatio',            # g optional
     0xa405 => 'FocalLengthIn35mmFilm',       # g optional
     0xa406 => 'SceneCaptureType',            # g recommended
     0xa407 => 'GainControl',                 # g optional
     0xa408 => 'Contrast',                    # g optional
     0xa409 => 'Saturation',                  # g optional
     0xa40a => 'Sharpness',                   # g optional
     0xa40b => 'DeviceSettingDescription',    # g optional
     0xa40c => 'SubjectDistanceRange',        # g optional
     0xa420 => 'ImageUniqueID',               # h optional
     #0xa500 => '.. ????',
     #0xfde8 => "?? OwnerName",
     #0xfde9 => "?? SerialNumber",
     #0xfdea => "?? Lens",
     #0xfe4c => "?? RawFile",
     #0xfe4d => "?? Converter",
     #0xfe4e => "?? WhiteBalance",
     #0xfe51 => "?? Exposure",
     #0xfe52 => "?? Shadows",
     #0xfe53 => "?? Brightness",
     #0xfe54 => "?? Contrast",
     #0xfe55 => "?? Saturation",
     #0xfe56 => "?? Sharpness",
     #0xfe57 => "?? Smoothness",
     #0xfe58 => "?? MoireFilter",
     );

# Tags to be used in the Interoperability IFD (optional)
our %HASH_APP1_INTEROP =
    (0x0001 => 'InteroperabilityIndex',       # "R98"(main)or "THM"(thumb.)
     0x0002 => 'InteroperabilityVersion',     # "0100" means 1.00
     0x1000 => 'RelatedImageFileFormat',      # e.g. "Exif JPEG Ver. 2.1"
     0x1001 => 'RelatedImageWidth',           # image X dimension
     0x1002 => 'RelatedImageLength',          # image Y dimension
     );

# Special tags for OLYMPUS Maker Notes.
our %HASH_APP1_MKN_OLYMPUS =
    (0x0100 => 'JPEG_Thumbnail',
     0x0200 => 'SpecialMode',
     0x0201 => 'CompressionMode',
     0x0202 => 'MacroMode',
     #0x0203 => '.. ???',
     0x0204 => 'DigitalZoom',
     #0x0205 => '.. ???',
     #0x0206 => '.. ???',
     0x0207 => 'FirmwareVersion',
     0x0208 => 'PictureInfo', # ASCII formatted data (like APP12)
     0x0209 => 'CameraID',
     0x020b => 'ImageWidth',
     0x020c => 'ImageHeight',
     #0x0300 => '.. ???',
     #0x0301 => '.. ???',
     #0x0302 => '.. ???',
     #0x0303 => '.. ???',
     #0x0304 => '.. ???',
     0x0f00 => 'Data',           # Unknown
     );

#============================================================================#
# See the "EXIF tags for the 0th IFD GPS directory" section in the           #
# Image::MetaData::JPEG module perldoc page for further details on GPS data. #
# -------------------------------------------------------------------------- #
# Hash keys are numeric tags, here written in hexadecimal base.              #
# Fields: 0 -> Tag name, 2 -> type, 3 -> count (0 means arbitrary count),    #
#         4 -> regular expression to match                                   #
#============================================================================#
my $GPS_re_NS        = '(N|S)\000';            # latitude reference
my $GPS_re_EW        = '(E|W)\000';            # longitude reference
my $GPS_re_spdsref   = '(K|M|N)\000';          # speed or distance reference
my $GPS_re_direref   = '(T|M)\000';            # directin reference
my $GPS_re_Cstring   = '.*\000';               # a null terminated string
my $GPS_re_string    = '[AJU\000].*';          # GPS "undefined" strings
my $GPS_re_date      = '(19|2\d)\d{2}:(0\d|1[0-2]):([0-2]\d|3[01])\000';
my $GPS_re_number    = '\d+';                  # a generic number
##############################################################################
our %HASH_GPS_GENERAL =
    (0x00 => ['GPSVersionID',        $BYTE,      4, '.'               ],
     0x01 => ['GPSLatitudeRef',      $ASCII,     2, $GPS_re_NS        ],
     0x02 => ['GPSLatitude',         $RATIONAL,  3, 'latlong'         ],
     0x03 => ['GPSLongitudeRef',     $ASCII,     2, $GPS_re_EW        ],
     0x04 => ['GPSLongitude',        $RATIONAL,  3, 'latlong'         ],
     0x05 => ['GPSAltitudeRef',      $BYTE,      1, '0|1'             ],
     0x06 => ['GPSAltitude',         $RATIONAL,  1, '.*'              ],
     0x07 => ['GPSTimeStamp',        $RATIONAL,  3, 'stupidtime'      ],
     0x08 => ['GPSSatellites',       $ASCII, undef, '.*\000'          ],
     0x09 => ['GPSStatus',           $ASCII,     2, 'A|V'             ],
     0x0a => ['GPSMeasureMode',      $ASCII,     2, '2|3'             ],
     0x0b => ['GPSDOP',              $RATIONAL,  1, $GPS_re_number    ],
     0x0c => ['GPSSpeedRef',         $ASCII,     2, $GPS_re_spdsref   ],
     0x0d => ['GPSSpeed',            $RATIONAL,  1, $GPS_re_number    ],
     0x0e => ['GPSTrackRef',         $ASCII,     2, $GPS_re_direref   ],
     0x0f => ['GPSTrack',            $RATIONAL,  1, 'direction'       ],
     0x10 => ['GPSImgDirectionRef',  $ASCII,     2, $GPS_re_direref   ],
     0x11 => ['GPSImgDirection',     $RATIONAL,  1, 'direction'       ],
     0x12 => ['GPSMapDatum',         $ASCII, undef, $GPS_re_Cstring   ],
     0x13 => ['GPSDestLatitudeRef',  $ASCII,     2, $GPS_re_NS        ],
     0x14 => ['GPSDestLatitude',     $RATIONAL,  3, 'latlong'         ],
     0x15 => ['GPSDestLongitudeRef', $ASCII,     2, $GPS_re_EW        ],
     0x16 => ['GPSDestLongitude',    $RATIONAL,  3, 'latlong'         ],
     0x17 => ['GPSDestBearingRef',   $ASCII,     2, $GPS_re_direref   ],
     0x18 => ['GPSDestBearing',      $RATIONAL,  1, 'direction'       ],
     0x19 => ['GPSDestDistanceRef',  $ASCII,     2, $GPS_re_spdsref   ],
     0x1a => ['GPSDestDistance',     $RATIONAL,  1, $GPS_re_number    ],
     0x1b => ['GPSProcessingMethod', $UNDEF, undef, $GPS_re_string    ],
     0x1c => ['GPSAreaInformation',  $UNDEF, undef, $GPS_re_string    ],
     0x1d => ['GPSDateStamp',        $ASCII,    11, $GPS_re_date      ],
     0x1e => ['GPSDifferential',     $SHORT,     1, '0|1'             ],
     );

our %HASH_APP3_SPECIAL =
    (0x0000 => 'Unknown 0',
     0x0001 => 'Unknown 1',
     0x0002 => 'Unknown 2',
     );

our %HASH_APP3_BORDERS =
    (0x0000 => 'Unknown 0',
     0x0001 => 'Unknown 1',
     0x0002 => 'Unknown 2',
     0x0003 => 'Unknown 3',
     0x0004 => 'Unknown 4',
     0x0008 => 'Unknown 8',
     );

#============================================================================#
# See the "VALID TAGS FOR IPTC DATA" section in the Image::MetaData::JPEG    #
# module perldoc page for further details on IPTC data.                      #
# -------------------------------------------------------------------------- #
# Hash keys are numeric tags, here written in decimal base.                  #
# Fields: 0 -> Tag name, 1 -> repeatability ('N' means non-repeatable),      #
#         2,3 -> min and max length, 4 -> regular expression to match.       #
#============================================================================#
my $IPTC_re_word = '^[^\000-\040\177]*$';                    # words
my $IPTC_re_line = '^[^\000-\037\177]*$';                    # words + spaces
my $IPTC_re_para = '^[^\000-\011\013\014\016-\037\177]*$';   # line + CR + LF
my $IPTC_re_date = '[0-2]\d\d\d(0\d|1[0-2])([0-2]\d|3[01])'; # CCYYMMDD
my $IPTC_re_HHMM = '([01]\d|2[0-3])[0-5]\d';                 # HHMM
my $IPTC_re_dura = $IPTC_re_HHMM.'[0-5]\d';                  # HHMMSS
my $IPTC_re_time = $IPTC_re_dura.'[\+-]'.$IPTC_re_HHMM;      # HHMMSS+/-HHMM
my $vchar        = '\040-\051\053-\071\073-\076\100-\176';   # (SubjectRef.)
my $IPTC_re_sure ='['.$vchar.']{1,32}?:[01]\d{7}?(:['.$vchar.'\s]{0,64}?){3}?';
##############################################################################
our %HASH_IPTC_GENERAL =
    (0   => ['RecordVersion',             'N', 2,  2, 'binary'               ],
     3   => ['ObjectTypeReference',       'N', 3, 67, '\d{2}?:[\w\s]{0,64}?' ],
     4   => ['ObjectAttributeReference',  ' ', 4, 68, '\d{3}?:[\w\s]{0,64}?' ],
     5   => ['ObjectName',                'N', 1, 64, $IPTC_re_line          ],
     7   => ['EditStatus',                'N', 1, 64, $IPTC_re_line          ],
     8   => ['EditorialUpdate',           'N', 2,  2, '01'                   ],
     10  => ['Urgency',                   'N', 1,  1, '[1-8]'                ],
     12  => ['SubjectReference',          ' ',13,236, $IPTC_re_sure          ],
     15  => ['Category',                  'N', 1,  3, '[a-zA-Z]{1,3}?'       ],
     20  => ['SupplementalCategory',      ' ', 1, 32, $IPTC_re_line          ],
     22  => ['FixtureIdentifier',         'N', 1, 32, $IPTC_re_word          ],
     25  => ['Keywords',                  ' ', 1, 64, $IPTC_re_line          ],
     26  => ['ContentLocationCode',       ' ', 3,  3, '[A-Z]{3}?'            ],
     27  => ['ContentLocationName',       ' ', 1, 64, $IPTC_re_line          ],
     30  => ['ReleaseDate',               'N', 8,  8, $IPTC_re_date          ],
     35  => ['ReleaseTime',               'N',11, 11, $IPTC_re_time          ],
     37  => ['ExpirationDate',            'N', 8,  8, $IPTC_re_date          ],
     38  => ['ExpirationTime',            'N',11, 11, $IPTC_re_time          ],
     40  => ['SpecialInstructions',       'N', 1,256, $IPTC_re_line          ],
     42  => ['ActionAdvised',             'N', 2,  2, '0[1-4]'               ],
     45  => ['ReferenceService',          ' ',10, 10, 'invalid'              ],
     47  => ['ReferenceDate',             ' ', 8,  8, 'invalid'              ],
     50  => ['ReferenceNumber',           ' ', 8,  8, 'invalid'              ],
     55  => ['DateCreated',               'N', 8,  8, $IPTC_re_date          ],
     60  => ['TimeCreated',               'N',11, 11, $IPTC_re_time          ],
     62  => ['DigitalCreationDate',       'N', 8,  8, $IPTC_re_date          ],
     63  => ['DigitalCreationTime',       'N',11, 11, $IPTC_re_time          ],
     65  => ['OriginatingProgram',        'N', 1, 32, $IPTC_re_line          ],
     70  => ['ProgramVersion',            'N', 1, 10, $IPTC_re_line          ],
     75  => ['ObjectCycle',               'N', 1,  1, 'a|p|b'                ],
     80  => ['ByLine',                    ' ', 1, 32, $IPTC_re_line          ],
     85  => ['ByLineTitle',               ' ', 1, 32, $IPTC_re_line          ],
     90  => ['City',                      'N', 1, 32, $IPTC_re_line          ],
     92  => ['SubLocation',               'N', 1, 32, $IPTC_re_line          ],
     95  => ['Province/State',            'N', 1, 32, $IPTC_re_line          ],
     100 => ['Country/PrimaryLocationCode', 'N', 3,3, '[A-Z]{3}?'            ],
     101 => ['Country/PrimaryLocationName', 'N', 1,64,$IPTC_re_line          ],
     103 => ['OriginalTransmissionReference','N',1,32,$IPTC_re_line          ],
     105 => ['Headline',                  'N', 1,256, $IPTC_re_line          ],
     110 => ['Credit',                    'N', 1, 32, $IPTC_re_line          ],
     115 => ['Source',                    'N', 1, 32, $IPTC_re_line          ],
     116 => ['CopyrightNotice',           'N', 1,128, $IPTC_re_line          ],
     118 => ['Contact',                   ' ', 1,128, $IPTC_re_line          ],
     120 => ['Caption/Abstract',          'N', 1,2000,$IPTC_re_para          ],
     122 => ['Writer/Editor',             ' ', 1, 32, $IPTC_re_line          ],
     125 => ['RasterizedCaption',         'N', 7360, 7360, 'binary'          ],
     130 => ['ImageType',                 'N', 2,  2, '[0-49][WYMCKRGBTFLPS]'],
     131 => ['ImageOrientation',          'N', 1,  1, 'P|L|S'                ],
     135 => ['LanguageIdentifier',        'N', 2,  3, '[a-zA-Z]{2,3}?'       ],
     150 => ['AudioType',                 'N', 2,  2, '[012][ACMQRSTVW]'     ],
     151 => ['AudioSamplingRate',         'N', 6,  6, '\d{6}?'               ],
     152 => ['AudioSamplingResolution',   'N', 2,  2, '\d{2}?'               ],
     153 => ['AudioDuration',             'N', 6,  6, $IPTC_re_dura          ],
     154 => ['AudioOutcue',               'N', 1, 64, $IPTC_re_line          ],
     200 => ['ObjDataPreviewFileFormat',  'N', 2,  2, 'invalid,binary'       ],
     201 => ['ObjDataPreviewFileFormatVer','N',2,  2, 'invalid,binary'       ],
     202 => ['ObjDataPreviewData',        'N', 1,256000,'invalid,binary'     ],
     );

# esoteric tags for a Photoshop APP13 segment (not IPTC data)
our %HASH_PHOTOSHOP_TAGS =
    (0x03e9 => 'MacintoshPrintInfo',         # Photoshop 4.0
     0x03ed => 'ResolutionInfo',
     0x03ee => 'AlphaChannelsNames',
     0x03ef => 'DisplayInfo',
     0x03f0 => 'PStringCaption',
     0x03f1 => 'BorderInformation',
     0x03f2 => 'BackgroundColor',
     0x03f3 => 'PrintFlags',
     0x03f4 => 'BW_HalftoningInfo',
     0x03f5 => 'ColorHalftoningInfo',
     0x03f6 => 'DuotoneHalftoningInfo',
     0x03f7 => 'BW_TransferFunc',
     0x03f8 => 'ColorTransferFuncs',
     0x03f9 => 'DuotoneTransferFuncs',
     0x03fa => 'DuotoneImageInfo',
     0x03fb => 'EffectiveBW',
     0x03fe => 'QuickMaskInfo',
     0x0400 => 'LayerStateInfo',
     0x0401 => 'WorkingPath',
     0x0402 => 'LayersGroupInfo',
     0x0404 => 'IPTC/NAA',
     0x0405 => 'RawImageMode',
     0x0406 => 'JPEG_Quality',
     0x0408 => 'GridGuidesInfo',
     0x0409 => 'ThumbnailResource',
     0x040a => 'CopyrightFlag',
     0x040b => 'URL',
     0x040c => 'ThumbnailResource2',
     0x040d => 'GlobalAngle',
     0x040e => 'ColorSamplersResource',
     0x040f => 'ICC_Profile',
     0x0410 => 'Watermark',
     0x0411 => 'ICC_Untagged',
     0x0412 => 'EffectsVisible',
     0x0413 => 'SpotHalftone',
     0x0414 => 'IDsBaseValue',
     0x0415 => 'UnicodeAlphaNames',
     0x0416 => 'IndexedColourTableCount',
     0x0417 => 'TransparentIndex',
     0x0419 => 'GlobalAltitude',
     0x041a => 'Slices',
     0x041b => 'WorkflowURL',
     0x041c => 'JumpToXPEP',
     0x041d => 'AlphaIdentifiers',
     0x041e => 'URL_List',
     0x0421 => 'VersionInfo',
     0x0bb7 => 'ClippingPathName',
     0x2710 => 'PrintFlagsInfo',
     );
# tags 0x07d0 --> 0x0bb6 are reserved for path information
for (0x07d0..0x0bb6) { $HASH_PHOTOSHOP_TAGS{$_} = sprintf "PathInfo_%3x", $_; }

# lookup tables for properties' names from previously defined general tables
our %HASH_IPTC_RECORD_2 = generate_lookup(\ %HASH_IPTC_GENERAL, 0);
our %HASH_APP1_GPS      = generate_lookup(\ %HASH_GPS_GENERAL , 0);

# some other lookup bifurcations
$HASH_APP1_IFD{SubIFD}  = \%HASH_APP1_SUBIFD;     # Exif private tags
$HASH_APP1_IFD{GPS}     = \%HASH_APP1_GPS;        # GPS tags
$HASH_APP3_IFD{Special} = \%HASH_APP3_SPECIAL;    # Special effect tags
$HASH_APP3_IFD{Borders} = \%HASH_APP3_BORDERS;    # Border tags
$HASH_APP1_SUBIFD{Interop} = \%HASH_APP1_INTEROP; # Interoperability tags
$HASH_APP1_SUBIFD{MakerNote_OLYMPUS} = \%HASH_APP1_MKN_OLYMPUS;

# this is the main database for tag --> tagname translation
# (records with a textual tag are not listed here)
my %JPEG_RECORD_NAME = 
    (APP1  => {IFD0           => \%HASH_APP1_IFD,    # main image
	       IFD1           => \%HASH_APP1_IFD, }, # thumbnail
     APP2  => {TagTable       => \%HASH_APP2_ICC, }, # ICC data
     APP3  => {IFD0           => \%HASH_APP3_IFD, }, # main image
     APP13 => {IPTC_RECORD_2  => \%HASH_IPTC_RECORD_2,
	       %HASH_PHOTOSHOP_TAGS },
     );

###########################################################
# This helper function returns record data from the       #
# %JPEG_RECORD_NAME hash. The argument list is a list of  #
# keys for exploring the variuous hash levels; e.g., if   #
# the list is ('APP1', 'IFD0', 'GPS', 0x1e), the selected #
# value is $JPEG_RECORD_NAME{APP1}{IFD0}{GPS}{0x1e}, i.e. #
# the textual name of the GPS record with key = 0x1e in   #
# the IFD0 in the APP1 segment. If, at some point during  #
# the search, an argument fails (it is not a valid key)   #
# or it is not defined, the search is interrupted, and    #
# undef is returned. Note also that the return value can  #
# be a string or a hash reference, depending on the hash  #
# search depth. If the key lookup for the last argument   #
# fails, a reverse lookup is run (i.e., the key corres-   #
# ponding to the value equal to the last user argument is #
# searched). If even this lookup fails, undef is returned.#
########################################################### 
sub JPEG_lookup {
    # all searches start from here
    my $lookup = \ %JPEG_RECORD_NAME;
    # extract and save the last argument for special treatment
    my $last = pop;
    # refuse to work with $last undefined
    return unless $last;
    # consume the list of "normal" arguments: they must be successive
    # keys for navigation in a multi-level hash. Interrupt the search
    # as soon as an argument is undefined or $lookup is not a hash ref
    for (@_) {
	# return undef as soon as an argument is undefined
	return undef unless $_;
	# go one level deeper in the hash exploration
	$lookup = $$lookup{$_};
	# return undef if $lookup is no more a hash reference
	return undef unless ref $lookup eq 'HASH'; }
    # $lookup is a hash reference now. Return the value
    # corresponding to $last (used as a key) if it exists.
    return $$lookup{$last} if exists $$lookup{$last};
    # if we are still here, scan the hash looking for a value equal to
    # $last, and return its key. Avoid each %$lookup, since we could
    # exit the loop before the end and I don't want to reset the
    # iterator in that stupid manner.
    for (keys %$lookup) { return $_ if $$lookup{$_} eq $last; }
    # if we are still here, we have lost
    return undef;
};

# complications due to APP1/APP3 structure
our %IFD_SUBDIRS =
    (JPEG_lookup('APP1','IFD0','GPSInfo')            => 'IFD0@GPS',
     JPEG_lookup('APP1','IFD0','ExifOffset')         => 'IFD0@SubIFD',
     JPEG_lookup('APP1','IFD0','SubIFD','InteroperabilityOffset')
                                                     => 'IFD0@SubIFD@Interop',
#    JPEG_lookup('APP1','IFD0','SubIFD','MakerNote') =>'IFD0@SubIFD@MakerNote',
     JPEG_lookup('APP3','IFD0','BordersIFD')         => 'IFD0@Borders',
     JPEG_lookup('APP3','IFD0','SpecialEffectsIFD')  => 'IFD0@Special',
     );

# parameters which must be initialised with JPEG_lookup
our $APP1_TH_TYPE  = JPEG_lookup('APP1','IFD1','Compression');
our $THJPEG_OFFSET = JPEG_lookup('APP1','IFD1','JPEGInterchangeFormat');
our $THJPEG_LENGTH = JPEG_lookup('APP1','IFD1','JPEGInterchangeFormatLength');
our $THTIFF_OFFSET = JPEG_lookup('APP1','IFD1','StripOffsets');
our $THTIFF_LENGTH = JPEG_lookup('APP1','IFD1','StripOffsets');

# successful package load
1;
