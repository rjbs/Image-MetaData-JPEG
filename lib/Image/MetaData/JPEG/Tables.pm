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
# This section defines the export policy of this module; no variable or      #
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
     Endianness  => [qw($NATIVE_ENDIANNESS $BIG_ENDIAN $LITTLE_ENDIAN)],     #
     JPEGgrammar => [qw($JPEG_PUNCTUATION %JPEG_MARKER)],                    #
     TagsAPP0    => [qw($APP0_JFIF_TAG $APP0_JFXX_TAG $APP0_JFXX_JPG),       #
		     qw($APP0_JFXX_1B $APP0_JFXX_3B $APP0_JFXX_PAL)],        #
     TagsAPP1    => [qw($APP1_EXIF_TAG $APP1_XMP_TAG $APP1_TIFF_SIG),        #
		     qw($APP1_TH_JPEG $APP1_TH_TIFF $APP1_TH_TYPE),          #
		     qw($THJPEG_OFFSET $THJPEG_LENGTH $HASH_MAKERNOTES),     #
		     qw($THTIFF_OFFSET $THTIFF_LENGTH %IFD_SUBDIRS) ],       #
     TagsAPP2    => [qw($APP2_FPXR_TAG $APP2_ICC_TAG)],                      #
     TagsAPP3    => [qw($APP3_EXIF_TAG %IFD_SUBDIRS)],                       #
     TagsAPP13   => [qw($APP13_PHOTOSHOP_IPTC $APP13_PHOTOSHOP_IDENTIFIER),  #
		     qw($APP13_PHOTOSHOP_TYPE $APP13_IPTC_TAGMARKER),        #
		     qw($APP13_PHOTOSHOP_DIRNAME $APP13_IPTC_DIRNAME)],      #
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
# Functions for generating arrays (arg0=hashref, arg1=index) or references   #
# to lookup tables [hashes] (arg0=hashref,arg1=index) from hashes; it is     #
# assumed that the general hash they work on has array references as values. #
#----------------------------------------------------------------------------#
sub generate_lookup { my %a=map { $_ => $_[0]{$_}[$_[1]] } keys %{$_[0]}; \%a};
sub generate_array  { map { $_[0]{$_}[$_[1]] } (0..(-1+scalar keys %{$_[0]}))};
#============================================================================#
#============================================================================#
#============================================================================#
# Various lists for JPEG record names, lengths, categories and signs; see    #
# Image::MetaData::JPEG::Record class for further details. The general hash  #
# is private to this file, the other arrays are exported if so requested.    #
#----------------------------------------------------------------------------#
# I gave up trying to calculate the length of a reference. This is probably  #
# allocation dependent ... I use 0 here, meaning the length is variable.     #
#----------------------------------------------------------------------------#
my $RECORD_TYPE_GENERAL =                                                    #
{(our $NIBBLES   =  0) => [ 'NIBBLES'   , 1, 'I', 'N' ],                     #
 (our $BYTE      =  1) => [ 'BYTE'      , 1, 'I', 'N' ],                     #
 (our $ASCII     =  2) => [ 'ASCII'     , 0, 'S', 'N' ],                     #
 (our $SHORT     =  3) => [ 'SHORT'     , 2, 'I', 'N' ],                     #
 (our $LONG      =  4) => [ 'LONG'      , 4, 'I', 'N' ],                     #
 (our $RATIONAL  =  5) => [ 'RATIONAL'  , 8, 'R', 'N' ],                     #
 (our $SBYTE     =  6) => [ 'SBYTE'     , 1, 'I', 'Y' ],                     #
 (our $UNDEF     =  7) => [ 'UNDEF'     , 0, 'S', 'N' ],                     #
 (our $SSHORT    =  8) => [ 'SSHORT'    , 2, 'I', 'Y' ],                     #
 (our $SLONG     =  9) => [ 'SLONG'     , 4, 'I', 'Y' ],                     #
 (our $SRATIONAL = 10) => [ 'SRATIONAL' , 8, 'R', 'Y' ],                     #
 (our $FLOAT     = 11) => [ 'FLOAT'     , 4, 'F', 'N' ],                     #
 (our $DOUBLE    = 12) => [ 'DOUBLE'    , 8, 'F', 'N' ],                     #
 (our $REFERENCE = 13) => [ 'REFERENCE' , 0, 'p', 'N' ],    };               #
#----------------------------------------------------------------------------#
our @JPEG_RECORD_TYPE_NAME     = generate_array($RECORD_TYPE_GENERAL, 0);    #
our @JPEG_RECORD_TYPE_LENGTH   = generate_array($RECORD_TYPE_GENERAL, 1);    #
our @JPEG_RECORD_TYPE_CATEGORY = generate_array($RECORD_TYPE_GENERAL, 2);    #
our @JPEG_RECORD_TYPE_SIGN     = generate_array($RECORD_TYPE_GENERAL, 3);    #
#============================================================================#
#============================================================================#
#============================================================================#
# The following three tags are related to endianness. The endianness of the  #
# current machine is detected every time with a simple procedure.            #
#----------------------------------------------------------------------------#
my ($__short, $__byte1, $__byte2) = unpack "SCC", "\111\333" x 2;            #
our $BIG_ENDIAN			= 'MM';                                      #
our $LITTLE_ENDIAN		= 'II';                                      #
our $NATIVE_ENDIANNESS = $__byte2 + ($__byte1<<8) == $__short ? $BIG_ENDIAN  #
    : $__byte1 + ($__byte2<<8) == $__short ? $LITTLE_ENDIAN : undef;         #
#----------------------------------------------------------------------------#
# various interesting constants which are not tags (mostly record values);   #
#----------------------------------------------------------------------------#
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
our $APP13_PHOTOSHOP_DIRNAME    = 'Photoshop_RECORDS';                       #
our $APP13_IPTC_TAGMARKER	= 0x1c;                                      #
our $APP13_IPTC_DIRNAME         = 'IPTC_RECORDS';                            #
our $APP14_PHOTOSHOP_IDENTIFIER	= 'Adobe';                                   #
#============================================================================#
#============================================================================#
#============================================================================#
# The following lines contain a list of general-purpose regular expressions, #
# which are used by the IFD, GPS ... and other sections. The only reason for #
# them being here is to avoid to do errors more than once ...                #
#----------------------------------------------------------------------------#
my $re_integer = '\d+';                       # a generic integer number     #
my $re_signed  = join('', '-?', $re_integer); # a generic signed integer num #
my $re_float   = '[+-]?\d+(|.\d+)';           # a generic floating point     #
my $re_Cstring = '.*\000';                    # a null-terminated string     #
my $re_year    = '(19|20)\d\d';               # YYYY (from 1900 only ...)    #
my $re_month   = '(0\d|1[0-2])';              # MM (month in 1-12)           #
my $re_day     = '(0[1-9]|[12]\d|3[01])';     # DD (day in 1-31)             #
my $re_hour    = '([01]\d|2[0-3])';           # HH (hour in 0-23)            #
my $re_minute  = '[0-5]\d';                   # MM (minute in 0-59)          #
my $re_second  = $re_minute;                  # SS (seconds like minutes)    #
my $re_zone    = join('',  $re_hour, $re_minute);             # HHMM         #
my $re_date    = join('',  $re_year, $re_month,  $re_day);    # YYYYMMDD     #
my $re_time    = join('',  $re_hour, $re_minute, $re_second); # HHMMSS       #
my $re_date_cl = join(':', $re_year, $re_month,  $re_day);    # YYYY:MM:DD   #
my $re_time_cl = join(':', $re_hour, $re_minute, $re_second); # HH:MM:SS     #
#============================================================================#
#============================================================================#
#============================================================================#
# Root level records for an Exif APP1 segment; we could avoid writing them   #
# down here, but this makes syntax checks easier. Also, mandatory tags are   #
# here just for reference, since I think they are already present, hence     #
# never used. See the tables for IFD0 and IFD1 for further details.          #
#--- Mandatory records for IFD0 and IFD1 (not calculated) -------------------#
my $HASH_APP1_ROOT_MANDATORY = {'Identifier'  => $APP1_EXIF_TAG,             #
				'Endianness'  => $BIG_ENDIAN,                #
				'Signature'   => $APP1_TIFF_SIG, };          #
#--- Legal records' list ----------------------------------------------------#
my $HASH_APP1_ROOT_GENERAL =                                                 #
{'Identifier'    => ['Idx-1', $ASCII, 6,     $APP1_EXIF_TAG, 'B'          ], #
 'Endianness'    => ['Idx-2', $UNDEF, 2,   "($BIG_ENDIAN|$LITTLE_ENDIAN)" ], #
 'Signature'     => ['Idx-3', $SHORT, 1,     $APP1_TIFF_SIG, 'B'          ], #
 'ThumbnailData' => ['Idx-4', $UNDEF, undef, '.*',           'T'       ], }; #
#============================================================================#
#============================================================================#
#============================================================================#
# Most tags in the following three lists are the same for IFD0 and IFD1,     #
# only the support level changes (some of them, indeed, must be present in   #
# both directories). See the relevant sections in the Image::MetaData::JPEG  #
# module perldoc page for further details on the %$HASH_APP1_IFD01_* hashes: #
#  MAIN       --> "Canonical Exif 2.2 and TIFF 6.0 tags for IFD0 and IFD1";  #
#  ADDITIONAL --> "Additional TIFF 6.0 tags not in Exif 2.2 for IFD0";       #
#  COMPANIES  --> "Exif tags assigned to companies for IFD0 and IFD1".       #
#----------------------------------------------------------------------------#
# The meaning of pseudo-regular-expressions is the following:                #
# - 'calculated': these tags must not be set by the final user (they are     #
#     created, if necessary, by the module itself [this is more reliable]).  #
# - 'obsoleted': this means that the corresponding tag is no more allowed.   #
# Some tags do not have a fixed type (for instance, they can be $SHORT or    #
# $LONG): in these cases, the most general type was chosen. Remember that    #
# some tags in the main hash table are mandatory.                            #
#----------------------------------------------------------------------------#
# Hash keys are numeric tags, here written in hexadecimal base.              #
# Fields: 0 -> name, 1 -> type, 2 -> count, 3 -> matching regular expression #
# 4 -> (optional) this tag can be set only together with the thumbnail       #
#----------------------------------------------------------------------------#
my $IFD_integer  = $re_integer;              # a generic integer number      #
my $IFD_signed   = $re_signed;               # a generic signed integer num  #
my $IFD_float    = $re_float;                # a generic floating point      #
my $IFD_Cstring  = $re_Cstring;              # a null-terminated string      #
my $IFD_dt_full  = $re_date_cl.' '.$re_time_cl; # YYYY:MM:DD HH:MM:SS        #
my $IFD_datetime = '('.$IFD_dt_full.'|    :  :     :  :  |\s{19})\000';      #
#--- Special screen rules for IFD0 and IFD1 ---------------------------------#
# a YCbCrSubSampling tag indicates the ratio of chrominance components. Its  #
# value can be only [2,1] (for YCbCr 4:2:2) or [2,2] (for YCbCr 4:2:0).      #
my $SSR_YCCsampl = sub { die unless $_[0] == 2 && $_[1] =~ /1|2/; };         #
#--- Mandatory records for IFD0 and IFD1 (not calculated) -------------------#
my $HASH_APP1_IFD01_MANDATORY = {'XResolution'               => [1, 72],     #
				 'YResolution'               => [1, 72],     #
				 'ResolutionUnit'            =>  2, };       #
my $HASH_APP1_IFD0_MANDATORY  = {%$HASH_APP1_IFD01_MANDATORY,                #
				 'YCbCrPositioning'          =>  1, };       #
my $HASH_APP1_IFD1_MANDATORY  = {%$HASH_APP1_IFD01_MANDATORY,                #
				 'YCbCrSubSampling'          => [2, 1],      #
				 'PhotometricInterpretation' =>  2,          #
				 'PlanarConfiguration'       =>  1, };       #
#--- Legal records' list ----------------------------------------------------#
my $HASH_APP1_IFD01_MAIN =                                                   #
{0x0100 => ['ImageWidth',                 $LONG,      1, $IFD_integer, 'T'], #
 0x0101 => ['ImageLength',                $LONG,      1, $IFD_integer, 'T'], #
 0x0102 => ['BitsPerSample',              $SHORT,     3, '8',          'T'], #
 0x0103 => ['Compression',                $SHORT,     1, '[16]',       'T'], #
 0x0106 => ['PhotometricInterpretation',  $SHORT,     1, '[26]',          ], #
 0x010e => ['ImageDescription',           $ASCII, undef, $IFD_Cstring     ], #
 0x010f => ['Make',                       $ASCII, undef, $IFD_Cstring     ], #
 0x0110 => ['Model',                      $ASCII, undef, $IFD_Cstring     ], #
 0x0111 => ['StripOffsets',               $LONG,  undef, 'calculated'     ], #
 0x0112 => ['Orientation',                $SHORT,     1, '[1-8]'          ], #
 0x0115 => ['SamplesPerPixel',            $SHORT,     1, '3',          'T'], #
 0x0116 => ['RowsPerStrip',               $LONG,      1, $IFD_integer, 'T'], #
 0x0117 => ['StripByteCounts',            $LONG,  undef, $IFD_integer, 'T'], #
 0x011a => ['XResolution',                $RATIONAL,  1, $IFD_integer     ], #
 0x011b => ['YResolution',                $RATIONAL,  1, $IFD_integer     ], #
 0x011c => ['PlanarConfiguration',        $SHORT,     1, '[12]'           ], #
 0x0128 => ['ResolutionUnit',             $SHORT,     1, '[23]'           ], #
 0x012d => ['TransferFunction',           $SHORT,   768, $IFD_integer     ], #
 0x0131 => ['Software',                   $ASCII, undef, $IFD_Cstring     ], #
 0x0132 => ['DateTime',                   $ASCII,    20, $IFD_datetime    ], #
 0x013b => ['Artist',                     $ASCII, undef, $IFD_Cstring     ], #
 0x013e => ['WhitePoint',                 $RATIONAL,  2, $IFD_integer     ], #
 0x013f => ['PrimaryChromaticities',      $RATIONAL,  6, $IFD_integer     ], #
 0x0201 => ['JPEGInterchangeFormat',      $LONG,      1, 'calculated'     ], #
 0x0202 => ['JPEGInterchangeFormatLength',$LONG,      1, $IFD_integer, 'T'], #
 0x0211 => ['YCbCrCoefficients',          $RATIONAL,  3, $IFD_integer     ], #
 0x0212 => ['YCbCrSubSampling',           $SHORT,     2, $SSR_YCCsampl    ], #
 0x0213 => ['YCbCrPositioning',           $SHORT,     1, '[12]'           ], #
 0x0214 => ['ReferenceBlackWhite',        $RATIONAL,  6, $IFD_integer     ], #
 0x8298 => ['Copyright',                  $ASCII, undef, $IFD_Cstring     ], #
 0x8769 => ['ExifOffset',                 $LONG,      1, 'calculated'     ], #
 0x8825 => ['GPSInfo',                    $LONG,      1, 'calculated'  ], }; #
#----------------------------------------------------------------------------#
my $HASH_APP1_IFD01_ADDITIONAL =                                             #
{0x00fe => ['NewSubfileType',             $LONG,      1, $IFD_integer ],     #
 0x00ff => ['SubFileType',                $SHORT,     1, $IFD_integer ],     #
 0x0107 => ['Thresholding',               $SHORT,     1, $IFD_integer ],     #
 0x0108 => ['CellWidth',                  $SHORT,     1, $IFD_integer ],     #
 0x0109 => ['CellLength',                 $SHORT,     1, $IFD_integer ],     #
 0x010a => ['FillOrder',                  $SHORT,     1, $IFD_integer ],     #
 0x010d => ['DocumentName',               $ASCII, undef, $IFD_Cstring ],     #
 0x0118 => ['MinSampleValue',             $SHORT, undef, $IFD_integer ],     #
 0x0119 => ['MaxSampleValue',             $SHORT, undef, $IFD_integer ],     #
 0x011d => ['PageName',                   $ASCII, undef, $IFD_Cstring ],     #
 0x011e => ['XPosition',                  $RATIONAL,  1, $IFD_integer ],     #
 0x011f => ['YPosition',                  $RATIONAL,  1, $IFD_integer ],     #
 0x0120 => ['FreeOffsets',                $LONG,  undef, $IFD_integer ],     #
 0x0121 => ['FreeByteCounts',             $LONG,  undef, $IFD_integer ],     #
 0x0122 => ['GrayResponseUnit',           $SHORT,     1, $IFD_integer ],     #
 0x0123 => ['GrayResponseCurve',          $SHORT, undef, $IFD_integer ],     #
 0x0124 => ['T4Options',                  $LONG,      1, $IFD_integer ],     #
 0x0125 => ['T6Options',                  $LONG,      1, $IFD_integer ],     #
 0x0129 => ['PageNumber',                 $SHORT,     2, $IFD_integer ],     #
 0x012c => ['ColorResponseUnit',          $SHORT,     1, 'invalid'    ],     #
 0x013c => ['HostComputer',               $ASCII, undef, $IFD_Cstring ],     #
 0x013d => ['Predictor',                  $SHORT,     1, $IFD_integer ],     #
 0x0140 => ['Colormap',                   $SHORT, undef, $IFD_integer ],     #
 0x0141 => ['HalftoneHints',              $SHORT,     2, $IFD_integer ],     #
 0x0142 => ['TileWidth',                  $LONG,      1, $IFD_integer ],     #
 0x0143 => ['TileLength',                 $LONG,      1, $IFD_integer ],     #
 0x0144 => ['TileOffsets',                $LONG,  undef, $IFD_integer ],     #
 0x0145 => ['TileByteCounts',             $LONG,  undef, $IFD_integer ],     #
 0x0146 => ['BadFaxLines',                $LONG,      1, $IFD_integer ],     #
 0x0147 => ['CleanFaxData',               $SHORT,     1, $IFD_integer ],     #
 0x0148 => ['ConsecutiveBadFaxLines',     $LONG,      1, $IFD_integer ],     #
 0x014a => ['SubIFD',                     $LONG,  undef, $IFD_integer ],     #
 0x014c => ['InkSet',                     $SHORT,     1, $IFD_integer ],     #
 0x014d => ['InkNames',                   $ASCII, undef, $IFD_Cstring ],     #
 0x014e => ['NumberOfInks',               $SHORT,     1, $IFD_integer ],     #
 0x0150 => ['DotRange',                   $SHORT, undef, $IFD_integer ],     #
 0x0151 => ['TargetPrinter',              $ASCII, undef, $IFD_Cstring ],     #
 0x0152 => ['ExtraSamples',               $SHORT, undef, $IFD_integer ],     #
 0x0153 => ['SampleFormats',              $SHORT, undef, $IFD_integer ],     #
 0x0154 => ['SMinSampleValue',            $UNDEF, undef, '.*'         ],     #
 0x0155 => ['SMaxSampleValue',            $UNDEF, undef, '.*'         ],     #
 0x0156 => ['TransferRange',              $SHORT,     6, $IFD_integer ],     #
 0x0157 => ['ClipPath',                   $BYTE,  undef, $IFD_integer ],     #
 0x0158 => ['XClipPathUnits',             $DOUBLE,    1, $IFD_float   ],     #
 0x0159 => ['YClipPathUnits',             $DOUBLE,    1, $IFD_float   ],     #
 0x015a => ['Indexed',                    $SHORT,     1, $IFD_integer ],     #
 0x015b => ['JPEGTables',                 undef,  undef, 'invalid'    ],     #
 0x015f => ['OPIProxy',                   $SHORT,     1, $IFD_integer ],     #
 0x0200 => ['JPEGProc',                   $SHORT,     1, 'invalid'    ],     #
 0x0203 => ['JPEGRestartInterval',        $SHORT,     1, 'invalid'    ],     #
 0x0205 => ['JPEGLosslessPredictors',     $SHORT, undef, 'invalid'    ],     #
 0x0206 => ['JPEGPointTransforms',        $SHORT, undef, 'invalid'    ],     #
 0x0207 => ['JPEGQTables',                $LONG,  undef, 'invalid'    ],     #
 0x0208 => ['JPEGDCTables',               $LONG,  undef, 'invalid'    ],     #
 0x0209 => ['JPEGACTables',               $LONG,  undef, 'invalid'    ],     #
 0x02bc => ['XML_Packet',                 $BYTE,  undef, $IFD_integer ], };  #
#----------------------------------------------------------------------------#
# The following company-related fields are marked as invalid because they    #
# are present also in the SubIFD section (with different numerical values)   #
# and I don't want the two entries to collide when setting IMAGE_DATA:       #
# 'FlashEnergy', 'SpatialFrequencyResponse', FocalPlane[XY]Resolution',      #
# 'FocalPlaneResolutionUnit', 'ExposureIndex', 'SensingMethod', 'CFAPattern' #
#----------------------------------------------------------------------------#
my $HASH_APP1_IFD01_COMPANIES =                                              #
{0x800d => ['ImageID',                    $ASCII, undef, $IFD_Cstring ],     #
 0x80b9 => ['RefPts',                     undef,  undef, 'invalid'    ],     #
 0x80ba => ['RegionTackPoint',            undef,  undef, 'invalid'    ],     #
 0x80bb => ['RegionWarpCorners',          undef,  undef, 'invalid'    ],     #
 0x80bc => ['RegionAffine',               undef,  undef, 'invalid'    ],     #
 0x80e3 => ['Matteing',                   $SHORT,     1, 'obsoleted'  ],     #
 0x80e4 => ['DataType',                   $SHORT,     1, 'obsoleted'  ],     #
 0x80e5 => ['ImageDepth',                 $LONG,      1, $IFD_integer ],     #
 0x80e6 => ['TileDepth',                  $LONG,      1, $IFD_integer ],     #
 0x8214 => ['ImageFullWidth',             $LONG,      1, $IFD_integer ],     #
 0x8215 => ['ImageFullLength',            $LONG,      1, $IFD_integer ],     #
 0x8216 => ['TextureFormat',              $ASCII, undef, $IFD_Cstring ],     #
 0x8217 => ['WrapModes',                  $ASCII, undef, $IFD_Cstring ],     #
 0x8218 => ['FovCot',                     $FLOAT,     1, $IFD_float   ],     #
 0x8219 => ['MatrixWorldToScreen',        $FLOAT,    16, $IFD_float   ],     #
 0x821a => ['MatrixWorldToCamera',        $FLOAT,    16, $IFD_float   ],     #
 0x827d => ['WriterSerialNumber',         undef,  undef, 'invalid'    ],     #
 0x828d => ['CFARepeatPatternDim',        $SHORT,     2, $IFD_integer ],     #
 0x828e => ['CFAPattern',                 $BYTE,  undef, 'invalid'    ],     #
 0x828f => ['BatteryLevel',               $ASCII, undef, $IFD_Cstring ],     #
 0x830e => ['ModelPixelScaleTag',         $DOUBLE,    3, $IFD_float   ],     #
 0x83bb => ['IPTC/NAA',                   $ASCII, undef, $IFD_Cstring ],     #
 0x8480 => ['IntergraphMatrixTag',        $DOUBLE,   16, 'obsoleted'  ],     #
 0x8482 => ['ModelTiepointTag',           $DOUBLE,undef, $IFD_float   ],     #
 0x84e0 => ['Site',                       $ASCII, undef, $IFD_Cstring ],     #
 0x84e1 => ['ColorSequence',              $ASCII, undef, $IFD_Cstring ],     #
 0x84e2 => ['IT8Header',                  $ASCII, undef, $IFD_Cstring ],     #
 0x84e3 => ['RasterPadding',              $SHORT,     1, $IFD_integer ],     #
 0x84e4 => ['BitsPerRunLength',           $SHORT,     1, $IFD_integer ],     #
 0x84e5 => ['BitsPerExtendedRunLength',   $SHORT,     1, $IFD_integer ],     #
 0x84e6 => ['ColorTable',                 $BYTE,  undef, $IFD_integer ],     #
 0x84e7 => ['ImageColorIndicator',        $BYTE,      1, $IFD_integer ],     #
 0x84e8 => ['BackgroundColorIndicator',   $BYTE,      1, $IFD_integer ],     #
 0x84e9 => ['ImageColorValue',            $BYTE,      1, $IFD_integer ],     #
 0x84ea => ['BackgroundColorValue',       $BYTE,      1, $IFD_integer ],     #
 0x84eb => ['PixelIntensityRange',        $BYTE,      2, $IFD_integer ],     #
 0x84ec => ['TransparencyIndicator',      $BYTE,      1, $IFD_integer ],     #
 0x84ed => ['ColorCharacterization',      $ASCII, undef, $IFD_Cstring ],     #
 0x84ee => ['HCUsage',                    $LONG,      1, $IFD_integer ],     #
 0x84ef => ['TrapIndicator',              $BYTE,      1, $IFD_integer ],     #
 0x84f0 => ['CMYKEquivalent',             $SHORT, undef, $IFD_integer ],     #
 0x84f1 => ['Reserved_TIFF_IT_1',         undef,  undef, 'invalid'    ],     #
 0x84f2 => ['Reserved_TIFF_IT_2',         undef,  undef, 'invalid'    ],     #
 0x84f3 => ['Reserved_TIFF_IT_3',         undef,  undef, 'invalid'    ],     #
 0x85b8 => ['FrameCount',                 $LONG,      1, $IFD_integer ],     #
 0x85d8 => ['ModelTransformationTag',     $DOUBLE,   16, $IFD_float   ],     #
 0x8649 => ['PhotoshopImageResources',    $BYTE,  undef, $IFD_integer ],     #
 0x8773 => ['ICCProfile',                 undef,  undef, 'invalid'    ],     #
 0x87af => ['GeoKeyDirectoryTag',         $SHORT, undef, $IFD_integer ],     #
 0x87b0 => ['GeoDoubleParamsTag',         $DOUBLE,undef, $IFD_float   ],     #
 0x87b1 => ['GeoAsciiParamsTag',          $ASCII, undef, $IFD_Cstring ],     #
 0x87be => ['JBIG_Options',               undef,  undef, 'invalid'    ],     #
 0x8829 => ['Interlace',                  $SHORT,     1, $IFD_integer ],     #
 0x882a => ['TimeZoneOffset',             $SSHORT,undef, $IFD_signed  ],     #
 0x882b => ['SelfTimerMode',              $SHORT,     1, $IFD_integer ],     #
 0x885c => ['FaxRecvParams',              $LONG,      1, $IFD_integer ],     #
 0x885d => ['FaxSubAddress',              $ASCII, undef, $IFD_Cstring ],     #
 0x885e => ['FaxRecvTime',                $LONG,      1, $IFD_integer ],     #
 0x8871 => ['FedExEDR',                   undef,  undef, 'invalid'    ],     #
 0x920b => ['FlashEnergy',               $RATIONAL,undef,'invalid'    ],     #
 0x920c => ['SpatialFrequencyResponse',   undef,  undef, 'invalid'    ],     #
 0x920d => ['Noise',                      undef,  undef, 'invalid'    ],     #
 0x920e => ['FocalPlaneXResolution',      $RATIONAL,  1, 'invalid'    ],     #
 0x920f => ['FocalPlaneYResolution',      $RATIONAL,  1, 'invalid'    ],     #
 0x9210 => ['FocalPlaneResolutionUnit',   $SHORT,     1, 'invalid'    ],     #
 0x9211 => ['ImageNumber',                $LONG,      1, $IFD_integer ],     #
 0x9212 => ['SecurityClassification',     $ASCII, undef, $IFD_Cstring ],     #
 0x9213 => ['ImageHistory',               $ASCII, undef, $IFD_Cstring ],     #
 0x9215 => ['ExposureIndex',             $RATIONAL,undef,'invalid'    ],     #
 0x9216 => ['TIFF/EPStandardID',          $BYTE,      4, $IFD_integer ],     #
 0x9217 => ['SensingMethod',              $SHORT,     1, 'invalid'    ],     #
 0x923f => ['StoNits',                    $DOUBLE,    1, $IFD_float   ],     #
 0x935c => ['ImageSourceData',            undef,  undef, 'invalid'    ],     #
 0xc4a5 => ['PrintIM_Data',               undef,  undef, 'invalid'    ],     #
 0xc44f => ['PhotoshopAnnotations',       undef,  undef, 'invalid'    ],     #
 0xffff => ['DCSHueShiftValues',          undef,  undef, 'invalid'    ], };  #
#----------------------------------------------------------------------------#
my $HASH_APP1_IFD01_GENERAL = {};                                            #
@$HASH_APP1_IFD01_GENERAL{keys %$_} =                                        #
    values %$_ for ($HASH_APP1_IFD01_MAIN,                                   #
		    $HASH_APP1_IFD01_ADDITIONAL,                             #
		    $HASH_APP1_IFD01_COMPANIES);                             #
#============================================================================#
#============================================================================#
#============================================================================#
# See the "Exif tags for the 0th IFD Exif private subdirectory" section in   #
# the Image::MetaData::JPEG module perldoc page for further details (private #
# EXIF region in IFD0, also known as SubIFD).                                #
#----------------------------------------------------------------------------#
# Hash keys are numeric tags, here written in hexadecimal base.              #
# Fields: 0 -> name, 1 -> type, 2 -> count, 3 -> matching regular            #
# Mandatory records: ExifVersion, ComponentsConfiguration, FlashpixVersion,  #
#                    ColorSpace, PixelXDimension and PixelYDimension.        #
#----------------------------------------------------------------------------#
my $IFD_subsecs  = '\d*\s*\000';                    # a fraction of a second #
my $IFD_Ustring  = '(ASCII\000{3}|JIS\000{5}|Unicode\000|\000{8}).*';        #
my $IFD_DOSfile  = '\w{8}\.\w{3}\000';              # a DOS filename (8+3)   #
my $IFD_lightsrc = '([0-49]|1[0-57-9]|2[0-4]|255)'; # possible light sources #
my $IFD_flash    = '([01579]|1[356]|2[459]|3[12]|6[59]|7[1379]|89|9[35])';   #
my $IFD_hexstr   = '[0-9a-fA-F]+\000+';             # hexadecimal ASCII str  #
my $IFD_Exifver  = '0(100|110|200|210|220|221)';    # known Exif versions    #
my $IFD_setdesc  = '.{4}(\376\377(.{2})*\000\000)*'; # for DeviceSettingDesc.#
my $IFD_compconf = '(\004\005\006|\001\002\003)\000';# for ComponentsConfig. #
#--- Special screen rules ---------------------------------------------------#
# a SubjectArea tag indicates the location and area of the main subject. The #
# tag can contain 2, 3 or 4 integer numbers (see Exif 2.2 for their meaning) #
my $SSR_subjectarea = sub { die if scalar @_ < 2 || scalar @_ > 4;           #
			    die if grep { ! /^\d+$/ } @_; };                 #
# a CFAPattern tag indicates a color filter array. The first four bytes are  #
# two shorts giving the horizontal (m) and vertical (n) repeat pixel units.  #
# Then, m x n bytes follow, with the actual filter values (in the range 0-6).#
my $SSR_cfapattern  = sub { my ($x, $y) = unpack 'nn', $_[0];                #
			    die if length $_[0] != 4+$x*$y;                  #
			    die if $_[0] !~ /^.{4}[0-6]*$/; };               #
#--- Mandatory records ------------------------------------------------------#
my $gdim = sub {$_[1]->{parent}?($_[1]->{parent}->get_dimensions())[$_[0]]:0};
my $HASH_APP1_SUBIFD_MANDATORY = {'ExifVersion'     => '0220',               #
 			  'ComponentsConfiguration' => "\001\002\003\000",   #
				  'FlashpixVersion' => '0100',               #
				  'ColorSpace'      => 1,                    #
				  'PixelXDimension' => sub {&$gdim(0,@_)},   #
				  'PixelYDimension' => sub {&$gdim(1,@_)} }; #
#--- Legal records' list ----------------------------------------------------#
my $HASH_APP1_SUBIFD_GENERAL =                                               #
{0x829a => ['ExposureTime',               $RATIONAL,  1, $IFD_integer    ],  #
 0x829d => ['FNumber',                    $RATIONAL,  1, $IFD_integer    ],  #
 0x8822 => ['ExposureProgram',            $SHORT,     1, '[0-8]'         ],  #
 0x8824 => ['SpectralSensitivity',        $ASCII, undef, $IFD_Cstring    ],  #
 0x8827 => ['ISOSpeedRatings',            $SHORT, undef, $IFD_integer    ],  #
 0x8828 => ['OECF',                       $UNDEF, undef, '.*'            ],  #
 0x9000 => ['ExifVersion',                $UNDEF,     4, $IFD_Exifver    ],  #
 0x9003 => ['DateTimeOriginal',           $ASCII,    20, $IFD_datetime   ],  #
 0x9004 => ['DateTimeDigitized',          $ASCII,    20, $IFD_datetime   ],  #
 0x9101 => ['ComponentsConfiguration',    $UNDEF,     4, $IFD_compconf   ],  #
 0x9102 => ['CompressedBitsPerPixel',     $RATIONAL,  1, $IFD_integer    ],  #
 0x9201 => ['ShutterSpeedValue',          $SRATIONAL, 1, $IFD_signed     ],  #
 0x9202 => ['ApertureValue',              $RATIONAL,  1, $IFD_integer    ],  #
 0x9203 => ['BrightnessValue',            $SRATIONAL, 1, $IFD_signed     ],  #
 0x9204 => ['ExposureBiasValue',          $SRATIONAL, 1, $IFD_signed     ],  #
 0x9205 => ['MaxApertureValue',           $RATIONAL,  1, $IFD_integer    ],  #
 0x9206 => ['SubjectDistance',            $RATIONAL,  1, $IFD_integer    ],  #
 0x9207 => ['MeteringMode',               $SHORT,     1, '([0-6]|255)'   ],  #
 0x9208 => ['LightSource',                $SHORT,     1, $IFD_lightsrc   ],  #
 0x9209 => ['Flash',                      $SHORT,     1, $IFD_flash      ],  #
 0x920a => ['FocalLength',                $RATIONAL,  1, $IFD_integer    ],  #
 0x9214 => ['SubjectArea',                $SHORT, undef, $SSR_subjectarea],  #
 0x927c => ['MakerNote',                  $UNDEF, undef, '.*'            ],  #
 0x9286 => ['UserComment',                $UNDEF, undef, $IFD_Ustring    ],  #
 0x9290 => ['SubSecTime',                 $ASCII, undef, $IFD_subsecs    ],  #
 0x9291 => ['SubSecTimeOriginal',         $ASCII, undef, $IFD_subsecs    ],  #
 0x9292 => ['SubSecTimeDigitized',        $ASCII, undef, $IFD_subsecs    ],  #
 0xa000 => ['FlashpixVersion',            $UNDEF,     4, '0100'          ],  #
 0xa001 => ['ColorSpace',                 $SHORT,     1, '(1|65535)'     ],  #
 0xa002 => ['PixelXDimension',            $LONG,      1, $IFD_integer    ],  #
 0xa003 => ['PixelYDimension',            $LONG,      1, $IFD_integer    ],  #
 0xa004 => ['RelatedSoundFile',           $ASCII,    13, $IFD_DOSfile    ],  #
 0xa005 => ['InteroperabilityOffset',     $LONG,      1, 'calculated'    ],  #
 0xa20b => ['FlashEnergy',                $RATIONAL,  1, $IFD_integer    ],  #
 0xa20c => ['SpatialFrequencyResponse',   $UNDEF, undef, '.*'            ],  #
 0xa20e => ['FocalPlaneXResolution',      $RATIONAL,  1, $IFD_integer    ],  #
 0xa20f => ['FocalPlaneYResolution',      $RATIONAL,  1, $IFD_integer    ],  #
 0xa210 => ['FocalPlaneResolutionUnit',   $SHORT,     1, '[23]'          ],  #
 0xa214 => ['SubjectLocation',            $SHORT,     2, $IFD_integer    ],  #
 0xa215 => ['ExposureIndex',              $RATIONAL,  1, $IFD_integer    ],  #
 0xa217 => ['SensingMethod',              $SHORT,     1, '[1-578]'       ],  #
 0xa300 => ['FileSource',                 $UNDEF,     1, '\003'          ],  #
 0xa301 => ['SceneType',                  $UNDEF,     1, '\001'          ],  #
 0xa302 => ['CFAPattern',                 $UNDEF, undef, $SSR_cfapattern ],  #
 0xa401 => ['CustomRendered',             $SHORT,     1, '[01]'          ],  #
 0xa402 => ['ExposureMode',               $SHORT,     1, '[012]'         ],  #
 0xa403 => ['WhiteBalance',               $SHORT,     1, '[01]'          ],  #
 0xa404 => ['DigitalZoomRatio',           $RATIONAL,  1, $IFD_integer    ],  #
 0xa405 => ['FocalLengthIn35mmFilm',      $SHORT,     1, $IFD_integer    ],  #
 0xa406 => ['SceneCaptureType',           $SHORT,     1, '[0-3]'         ],  #
 0xa407 => ['GainControl',                $SHORT,     1, '[0-4]'         ],  #
 0xa408 => ['Contrast',                   $SHORT,     1, '[0-2]'         ],  #
 0xa409 => ['Saturation',                 $SHORT,     1, '[0-2]'         ],  #
 0xa40a => ['Sharpness',                  $SHORT,     1, '[0-2]'         ],  #
 0xa40b => ['DeviceSettingDescription',   $UNDEF, undef, $IFD_setdesc    ],  #
 0xa40c => ['SubjectDistanceRange',       $SHORT,     1, '[0-3]'         ],  #
 0xa420 => ['ImageUniqueID',              $ASCII,    33, $IFD_hexstr     ],  #
# --- From Photoshop >= 7.0 treatment of raw camera files (undocumented) --- #
 0xfde8 => ['_OwnerName',     $ASCII, undef, "Owner'".'s Name: .*\000'   ],  #
 0xfde9 => ['_SerialNumber',  $ASCII, undef, 'Serial Number: .*\000'     ],  #
 0xfdea => ['_Lens',          $ASCII, undef, 'Lens: .*\000'              ],  #
 0xfe4c => ['_RawFile',       $ASCII, undef, 'Raw File: .*\000'          ],  #
 0xfe4d => ['_Converter',     $ASCII, undef, 'Converter: .*\000'         ],  #
 0xfe4e => ['_WhiteBalance',  $ASCII, undef, 'White Balance: .*\000'     ],  #
 0xfe51 => ['_Exposure',      $ASCII, undef, 'Exposure: .*\000'          ],  #
 0xfe52 => ['_Shadows',       $ASCII, undef, 'Shadows: .*\000'           ],  #
 0xfe53 => ['_Brightness',    $ASCII, undef, 'Brightness: .*\000'        ],  #
 0xfe54 => ['_Contrast',      $ASCII, undef, 'Contrast: .*\000'          ],  #
 0xfe55 => ['_Saturation',    $ASCII, undef, 'Saturation: .*\000'        ],  #
 0xfe56 => ['_Sharpness',     $ASCII, undef, 'Sharpness: .*\000'         ],  #
 0xfe57 => ['_Smoothness',    $ASCII, undef, 'Smoothness: .*\000'        ],  #
 0xfe58 => ['_MoireFilter',   $ASCII, undef, 'Moire Filter: .*\000'   ], };  #
#============================================================================#
#============================================================================#
#============================================================================#
# See the "EXIF tags for the 0th IFD Interoperability subdirectory" section  #
# in the Image::MetaData::JPEG module perldoc page for further details.      #
# Mandatory records: InteroperabilityIndex and InteroperabilityVersion       #
#----------------------------------------------------------------------------#
# Hash keys are numeric tags, here written in hexadecimal base.              #
# Fields: 0 -> name, 1 -> type, 2 -> count, 3 -> matching regular            #
#--- Mandatory records ------------------------------------------------------#
my $HASH_INTEROP_MANDATORY = {'InteroperabilityVersion' => '0100',           #
			      'InteroperabilityIndex'   => 'R98'  };         #
#--- Legal records' list ----------------------------------------------------#
my $HASH_INTEROP_GENERAL =                                                   #
{0x0001 => ['InteroperabilityIndex',      $ASCII,     4, 'R98\000'     ],    #
 0x0002 => ['InteroperabilityVersion',    $UNDEF,     4, '[0-9]{4}'    ],    #
 0x1000 => ['RelatedImageFileFormat',     $ASCII, undef, $IFD_Cstring  ],    #
 0x1001 => ['RelatedImageWidth',          $LONG,      1, '[0-9]*'      ],    #
 0x1002 => ['RelatedImageLength',         $LONG,      1, '[0-9]*'      ], }; #
#============================================================================#
#============================================================================#
#============================================================================#
# See the "EXIF tags for the 0th IFD GPS subdirectory" section in the        #
# Image::MetaData::JPEG module perldoc page for further details on GPS data. #
# Mandatory records: only GPSVersionID                                       #
#----------------------------------------------------------------------------#
# Hash keys are numeric tags, here written in hexadecimal base.              #
# Fields: 0 -> name, 1 -> type, 2 -> count, 3 -> matching regular            #
#----------------------------------------------------------------------------#
my $GPS_re_Cstring   = $re_Cstring;            # a null terminated string    #
my $GPS_re_date      = $re_date_cl . '\000';   # YYYY:MM:DD null terminated  #
my $GPS_re_number    = $re_integer;            # a generic integer number    #
my $GPS_re_NS        = '[NS]\000';             # latitude reference          #
my $GPS_re_EW        = '[EW]\000';             # longitude reference         #
my $GPS_re_spdsref   = '[KMN]\000';            # speed or distance reference #
my $GPS_re_direref   = '[TM]\000';             # directin reference          #
my $GPS_re_string    = '[AJU\000].*';          # GPS "undefined" strings     #
#--- Special screen rules ---------------------------------------------------#
# a direction is a rational number in [0.00, 359.99] (we should also test    #
# explicitely that the numerator and the denominator are not negative).      #
my $SSR_direction  = sub { die if grep { $_ < 0 } @_;                        #
			   my $dire = $_[0]/$_[1]; die if $dire >= 360;      #
			   die unless $dire =~ /^\d+(\.\d{1,2})?$/; };       #
# a "triplet" corresponds to three rationals for units, minutes (< 60) and   #
# seconds (< 60). The 1st argument must be a limit on units (helper rule).   #
my $SSR_triplet    = sub { my $limit = shift; die if grep { $_ < 0 } @_;     #
			   my ($dd,$mm,$ss) = map {$_[$_]/$_[1+$_]} (0,2,4); #
			   die unless $mm < 60 && $ss < 60 && $dd <= $limit; #
			   die unless ($dd + $mm /60 + $ss/360) <= $limit;}; #
# a latitude or a longitude is stored as a sequence of three rationals nums  #
# (degrees, minutes and seconds) with degrees <= 90 (see $SSR_triplet).      #
my $SSR_latlong    = sub { &$SSR_triplet(90, @_); };                         #
# a time stamp is stored as three rationals (hours, minutes and seconds); in #
# this case hours must be <= 24 (see $SSR_triplet for further details).      #
my $SSR_stupidtime = sub { &$SSR_triplet(24, @_); };                         #
#--- Mandatory records ------------------------------------------------------#
my $HASH_GPS_MANDATORY = {'GPSVersionID' => [2,2,0,0]};                      #
#--- Legal records' list ----------------------------------------------------#
my $HASH_GPS_GENERAL =                                                       #
{0x00 => ['GPSVersionID',                 $BYTE,      4, '.'             ],  #
 0x01 => ['GPSLatitudeRef',               $ASCII,     2, $GPS_re_NS      ],  #
 0x02 => ['GPSLatitude',                  $RATIONAL,  3, $SSR_latlong    ],  #
 0x03 => ['GPSLongitudeRef',              $ASCII,     2, $GPS_re_EW      ],  #
 0x04 => ['GPSLongitude',                 $RATIONAL,  3, $SSR_latlong    ],  #
 0x05 => ['GPSAltitudeRef',               $BYTE,      1, '[01]'          ],  #
 0x06 => ['GPSAltitude',                  $RATIONAL,  1, $GPS_re_number  ],  #
 0x07 => ['GPSTimeStamp',                 $RATIONAL,  3, $SSR_stupidtime ],  #
 0x08 => ['GPSSatellites',                $ASCII, undef, $GPS_re_Cstring ],  #
 0x09 => ['GPSStatus',                    $ASCII,     2, '[AV]\000'      ],  #
 0x0a => ['GPSMeasureMode',               $ASCII,     2, '[23]\000'      ],  #
 0x0b => ['GPSDOP',                       $RATIONAL,  1, $GPS_re_number  ],  #
 0x0c => ['GPSSpeedRef',                  $ASCII,     2, $GPS_re_spdsref ],  #
 0x0d => ['GPSSpeed',                     $RATIONAL,  1, $GPS_re_number  ],  #
 0x0e => ['GPSTrackRef',                  $ASCII,     2, $GPS_re_direref ],  #
 0x0f => ['GPSTrack',                     $RATIONAL,  1, $SSR_direction  ],  #
 0x10 => ['GPSImgDirectionRef',           $ASCII,     2, $GPS_re_direref ],  #
 0x11 => ['GPSImgDirection',              $RATIONAL,  1, $SSR_direction  ],  #
 0x12 => ['GPSMapDatum',                  $ASCII, undef, $GPS_re_Cstring ],  #
 0x13 => ['GPSDestLatitudeRef',           $ASCII,     2, $GPS_re_NS      ],  #
 0x14 => ['GPSDestLatitude',              $RATIONAL,  3, $SSR_latlong    ],  #
 0x15 => ['GPSDestLongitudeRef',          $ASCII,     2, $GPS_re_EW      ],  #
 0x16 => ['GPSDestLongitude',             $RATIONAL,  3, $SSR_latlong    ],  #
 0x17 => ['GPSDestBearingRef',            $ASCII,     2, $GPS_re_direref ],  #
 0x18 => ['GPSDestBearing',               $RATIONAL,  1, $SSR_direction  ],  #
 0x19 => ['GPSDestDistanceRef',           $ASCII,     2, $GPS_re_spdsref ],  #
 0x1a => ['GPSDestDistance',              $RATIONAL,  1, $GPS_re_number  ],  #
 0x1b => ['GPSProcessingMethod',          $UNDEF, undef, $GPS_re_string  ],  #
 0x1c => ['GPSAreaInformation',           $UNDEF, undef, $GPS_re_string  ],  #
 0x1d => ['GPSDateStamp',                 $ASCII,    11, $GPS_re_date    ],  #
 0x1e => ['GPSDifferential',              $SHORT,     1, '[01]'         ],}; #
#============================================================================#

# Tags used for ICC data in APP2 (they are 4 bytes strings, so
# I prefer to write the string and then convert it).
sub str2hex { my $z = 0; ($z *= 256) += $_ for unpack "CCCC", $_[0]; $z; }
my $HASH_APP2_ICC =
{str2hex('A2B0') => 'AT0B0Tag', 
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
 str2hex('view') => 'ViewingConditions', };

# Tags used by the 0-th IFD of an APP3 segment (reference ... ?)
my $HASH_APP3_IFD =
{0xc350 => 'FilmProductCode',
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
 0xc36f => 'BordersIFD', };     # pointer to an IFD

my $HASH_APP3_SPECIAL =
{0x0000 => 'APP3_SpecialIFD_tag_0',
 0x0001 => 'APP3_SpecialIFD_tag_1',
 0x0002 => 'APP3_SpecialIFD_tag_2', };

my $HASH_APP3_BORDERS =
{0x0000 => 'APP3_BordersIFD_tag_0',
 0x0001 => 'APP3_BordersIFD_tag_1',
 0x0002 => 'APP3_BordersIFD_tag_2',
 0x0003 => 'APP3_BordersIFD_tag_3',
 0x0004 => 'APP3_BordersIFD_tag_4',
 0x0008 => 'APP3_BordersIFD_tag_8', };

#============================================================================#
#============================================================================#
#============================================================================#
# See the "VALID TAGS FOR IPTC DATA" section in the Image::MetaData::JPEG    #
# module perldoc page for further details on IPTC data.                      #
#----------------------------------------------------------------------------#
# Hash keys are numeric tags, here written in decimal base.                  #
# Fields: 0 -> Tag name, 1 -> repeatability ('N' means non-repeatable),      #
#         2,3 -> min and max length, 4 -> regular expression to match.       #
#----------------------------------------------------------------------------#
my $IPTC_re_word = '^[^\000-\040\177]*$';                   # words          #
my $IPTC_re_line = '^[^\000-\037\177]*$';                   # words + spaces #
my $IPTC_re_para = '^[^\000-\011\013\014\016-\037\177]*$';  # line + CR + LF #
my $IPTC_re_date = $re_date;                                # CCYYMMDD       #
my $IPTC_re_dura = $re_time;                                # HHMMSS         #
my $IPTC_re_time = $IPTC_re_dura . '[\+-]' . $re_zone;      # HHMMSS+/-HHMM  #
my $vchr         = '\040-\051\053-\071\073-\076\100-\176';  # (SubjectRef.)  #
my $IPTC_re_sure='['.$vchr.']{1,32}?:[01]\d{7}?(:['.$vchr.'\s]{0,64}?){3}?'; #
#--- Legal records' list ----------------------------------------------------#
my $HASH_IPTC_GENERAL =                                                      #
{0   => ['RecordVersion',               'N', 2,  2, 'binary'              ], #
 3   => ['ObjectTypeReference',         'N', 3, 67, '\d{2}?:[\w\s]{0,64}?'], #
 4   => ['ObjectAttributeReference',    ' ', 4, 68, '\d{3}?:[\w\s]{0,64}?'], #
 5   => ['ObjectName',                  'N', 1, 64, $IPTC_re_line         ], #
 7   => ['EditStatus',                  'N', 1, 64, $IPTC_re_line         ], #
 8   => ['EditorialUpdate',             'N', 2,  2, '01'                  ], #
 10  => ['Urgency',                     'N', 1,  1, '[1-8]'               ], #
 12  => ['SubjectReference',            ' ',13,236, $IPTC_re_sure         ], #
 15  => ['Category',                    'N', 1,  3, '[a-zA-Z]{1,3}?'      ], #
 20  => ['SupplementalCategory',        ' ', 1, 32, $IPTC_re_line         ], #
 22  => ['FixtureIdentifier',           'N', 1, 32, $IPTC_re_word         ], #
 25  => ['Keywords',                    ' ', 1, 64, $IPTC_re_line         ], #
 26  => ['ContentLocationCode',         ' ', 3,  3, '[A-Z]{3}?'           ], #
 27  => ['ContentLocationName',         ' ', 1, 64, $IPTC_re_line         ], #
 30  => ['ReleaseDate',                 'N', 8,  8, $IPTC_re_date         ], #
 35  => ['ReleaseTime',                 'N',11, 11, $IPTC_re_time         ], #
 37  => ['ExpirationDate',              'N', 8,  8, $IPTC_re_date         ], #
 38  => ['ExpirationTime',              'N',11, 11, $IPTC_re_time         ], #
 40  => ['SpecialInstructions',         'N', 1,256, $IPTC_re_line         ], #
 42  => ['ActionAdvised',               'N', 2,  2, '0[1-4]'              ], #
 45  => ['ReferenceService',            ' ',10, 10, 'invalid'             ], #
 47  => ['ReferenceDate',               ' ', 8,  8, 'invalid'             ], #
 50  => ['ReferenceNumber',             ' ', 8,  8, 'invalid'             ], #
 55  => ['DateCreated',                 'N', 8,  8, $IPTC_re_date         ], #
 60  => ['TimeCreated',                 'N',11, 11, $IPTC_re_time         ], #
 62  => ['DigitalCreationDate',         'N', 8,  8, $IPTC_re_date         ], #
 63  => ['DigitalCreationTime',         'N',11, 11, $IPTC_re_time         ], #
 65  => ['OriginatingProgram',          'N', 1, 32, $IPTC_re_line         ], #
 70  => ['ProgramVersion',              'N', 1, 10, $IPTC_re_line         ], #
 75  => ['ObjectCycle',                 'N', 1,  1, '[apb]'               ], #
 80  => ['ByLine',                      ' ', 1, 32, $IPTC_re_line         ], #
 85  => ['ByLineTitle',                 ' ', 1, 32, $IPTC_re_line         ], #
 90  => ['City',                        'N', 1, 32, $IPTC_re_line         ], #
 92  => ['SubLocation',                 'N', 1, 32, $IPTC_re_line         ], #
 95  => ['Province/State',              'N', 1, 32, $IPTC_re_line         ], #
 100 => ['Country/PrimaryLocationCode', 'N', 3,  3, '[A-Z]{3}?'           ], #
 101 => ['Country/PrimaryLocationName', 'N', 1, 64, $IPTC_re_line         ], #
 103 => ['OriginalTransmissionReference','N',1, 32, $IPTC_re_line         ], #
 105 => ['Headline',                    'N', 1,256, $IPTC_re_line         ], #
 110 => ['Credit',                      'N', 1, 32, $IPTC_re_line         ], #
 115 => ['Source',                      'N', 1, 32, $IPTC_re_line         ], #
 116 => ['CopyrightNotice',             'N', 1,128, $IPTC_re_line         ], #
 118 => ['Contact',                     ' ', 1,128, $IPTC_re_line         ], #
 120 => ['Caption/Abstract',            'N', 1,2000,$IPTC_re_para         ], #
 122 => ['Writer/Editor',               ' ', 1, 32, $IPTC_re_line         ], #
 125 => ['RasterizedCaption',           'N',7360,7360,'binary'            ], #
 130 => ['ImageType',                   'N', 2,  2,'[0-49][WYMCKRGBTFLPS]'], #
 131 => ['ImageOrientation',            'N', 1,  1, '[PLS]'               ], #
 135 => ['LanguageIdentifier',          'N', 2,  3, '[a-zA-Z]{2,3}?'      ], #
 150 => ['AudioType',                   'N', 2,  2, '[012][ACMQRSTVW]'    ], #
 151 => ['AudioSamplingRate',           'N', 6,  6, '\d{6}?'              ], #
 152 => ['AudioSamplingResolution',     'N', 2,  2, '\d{2}?'              ], #
 153 => ['AudioDuration',               'N', 6,  6, $IPTC_re_dura         ], #
 154 => ['AudioOutcue',                 'N', 1, 64, $IPTC_re_line         ], #
 200 => ['ObjDataPreviewFileFormat',    'N', 2,  2, 'invalid,binary'      ], #
 201 => ['ObjDataPreviewFileFormatVer', 'N', 2,  2, 'invalid,binary'      ], #
 202 => ['ObjDataPreviewData',          'N', 1,256000,'invalid,binary'  ],}; #
#============================================================================#
#============================================================================#
#============================================================================#
# Esoteric tags for a Photoshop APP13 segment (not IPTC data);               #
# see the "VALID TAGS FOR PHOTOSHOP-STYLE APP13 DATA" section in the         #
# Image::MetaData::JPEG module perldoc page for further details.             #
# [tags 0x07d0 --> 0x0bb6 are reserved for path information]                 #
#----------------------------------------------------------------------------#
# Hash keys are numeric tags, here written in hexadecimal base.              #
# Fields: 0 -> Tag name (syntax is not yet checked, but this could change).  #
#----------------------------------------------------------------------------#
my $HASH_PHOTOSHOP_GENERAL =                                                 #
{0x03e8 => ['Photoshop2Info',                    ],                          #
 0x03e9 => ['MacintoshPrintInfo',                ],                          #
 0x03eb => ['Photoshop2ColorTable',              ],                          #
 0x03ed => ['ResolutionInfo',                    ],                          #
 0x03ee => ['AlphaChannelsNames',                ],                          #
 0x03ef => ['DisplayInfo',                       ],                          #
 0x03f0 => ['PStringCaption',                    ],                          #
 0x03f1 => ['BorderInformation',                 ],                          #
 0x03f2 => ['BackgroundColor',                   ],                          #
 0x03f3 => ['PrintFlags',                        ],                          #
 0x03f4 => ['BWHalftoningInfo',                  ],                          #
 0x03f5 => ['ColorHalftoningInfo',               ],                          #
 0x03f6 => ['DuotoneHalftoningInfo',             ],                          #
 0x03f7 => ['BWTransferFunc',                    ],                          #
 0x03f8 => ['ColorTransferFuncs',                ],                          #
 0x03f9 => ['DuotoneTransferFuncs',              ],                          #
 0x03fa => ['DuotoneImageInfo',                  ],                          #
 0x03fb => ['EffectiveBW',                       ],                          #
 0x03fc => ['ObsoletePhotoshopTag1',             ],                          #
 0x03fd => ['EPSOptions',                        ],                          #
 0x03fe => ['QuickMaskInfo',                     ],                          #
 0x03ff => ['ObsoletePhotoshopTag2',             ],                          #
 0x0400 => ['LayerStateInfo',                    ],                          #
 0x0401 => ['WorkingPathInfo',                   ],                          #
 0x0402 => ['LayersGroupInfo',                   ],                          #
 0x0403 => ['ObsoletePhotoshopTag3',             ],                          #
 0x0404 => ['IPTC/NAA',                          ],                          #
 0x0405 => ['RawImageMode',                      ],                          #
 0x0406 => ['JPEGQuality',                       ],                          #
 0x0408 => ['GridGuidesInfo',                    ],                          #
 0x0409 => ['ThumbnailResource',                 ],                          #
 0x040a => ['CopyrightFlag',                     ],                          #
 0x040b => ['URL',                               ],                          #
 0x040c => ['ThumbnailResource2',                ],                          #
 0x040d => ['GlobalAngle',                       ],                          #
 0x040e => ['ColorSamplersResource',             ],                          #
 0x040f => ['ICCProfile',                        ],                          #
 0x0410 => ['Watermark',                         ],                          #
 0x0411 => ['ICCUntagged',                       ],                          #
 0x0412 => ['EffectsVisible',                    ],                          #
 0x0413 => ['SpotHalftone',                      ],                          #
 0x0414 => ['IDsBaseValue',                      ],                          #
 0x0415 => ['UnicodeAlphaNames',                 ],                          #
 0x0416 => ['IndexedColourTableCount',           ],                          #
 0x0417 => ['TransparentIndex',                  ],                          #
 0x0419 => ['GlobalAltitude',                    ],                          #
 0x041a => ['Slices',                            ],                          #
 0x041b => ['WorkflowURL',                       ],                          #
 0x041c => ['JumpToXPEP',                        ],                          #
 0x041d => ['AlphaIdentifiers',                  ],                          #
 0x041e => ['URLList',                           ],                          #
 0x0421 => ['VersionInfo',                       ],                          #
 0x0bb7 => ['ClippingPathName',                  ],                          #
 0x2710 => ['PrintFlagsInfo',                    ], };                       #
#----------------------------------------------------------------------------#
for (0x07d0..0x0bb6) {                                                       #
    $$HASH_PHOTOSHOP_GENERAL{$_} = [sprintf "PathInfo_%3x", $_]; }           #
#============================================================================#
#============================================================================#
#============================================================================#
# Some scalar-valued hashes, which were once original databases, are now     #
# generated with "generate_lookup" from more general array-valued hashes     #
# (in practice, a single column is singled out from a multi-column table).   #
# %$HASH_APP1_IFD is built by merging the first column of 3 different hashes.#
#----------------------------------------------------------------------------#
my $HASH_PHOTOSHOP_TAGS  = generate_lookup($HASH_PHOTOSHOP_GENERAL     ,0);  #
my $HASH_IPTC_TAGS       = generate_lookup($HASH_IPTC_GENERAL          ,0);  #
my $HASH_APP1_ROOT       = generate_lookup($HASH_APP1_ROOT_GENERAL     ,0);  #
my $HASH_APP1_GPS        = generate_lookup($HASH_GPS_GENERAL           ,0);  #
my $HASH_APP1_INTEROP    = generate_lookup($HASH_INTEROP_GENERAL       ,0);  #
my $HASH_APP1_IFD        = generate_lookup($HASH_APP1_IFD01_GENERAL    ,0);  #
my $HASH_APP1_SUBIFD     = generate_lookup($HASH_APP1_SUBIFD_GENERAL   ,0);  #
#============================================================================#
#============================================================================#
#============================================================================#
# Some segments (APP1 and APP3 currently) have an IFD-like structure, i.e.   #
# they can have "subdirectories" pointed to by offset tags. These subdirs    #
# are bifurcation points for the lookup process, and are represented by      #
# hash references instead of plain strings (scalars).                        #
#----------------------------------------------------------------------------#
$$HASH_APP1_IFD{SubIFD}     = $HASH_APP1_SUBIFD;   # Exif private tags       #
$$HASH_APP1_IFD{GPS}        = $HASH_APP1_GPS;      # GPS tags                #
$$HASH_APP3_IFD{Special}    = $HASH_APP3_SPECIAL;  # Special effect tags     #
$$HASH_APP3_IFD{Borders}    = $HASH_APP3_BORDERS;  # Border tags             #
$$HASH_APP1_SUBIFD{Interop} = $HASH_APP1_INTEROP;  # Interoperability tags   #
#============================================================================#
#============================================================================#
#============================================================================#
# The following hash contains information concerning MakerNotes; each entry  #
# corresponds to an anonymous array, whose elements are: 0 -> the MakerNote  #
# signature, 1-> the Maker signature, 2-> endianness if fixed, 3-> where     #
# offsets are counted from, 4 -> a reference to a hash for tag translation.  #
# general: http://home.arcor.de/ahuggel/exiv2/makernote.html                 #
#          http://www.ozhiker.com/electronics/pjmt/jpeg_info/makernotes.html #
#----------------------------------------------------------------------------#
our $HASH_MAKERNOTES =                                                       #
{ # http://www.ozhiker.com/electronics/pjmt/jpeg_info/agfa_mn.html
  # Header: "AGFA \x00\x01", Standard TIFF IFD Data using Olympus Tags
  # All EXIF offsets are relative to the start of the TIFF header
  # at the beginning of the EXIF segment
  'Agfa'        => {'signature' => "^(AGFA \000\001)",
		    'maker'     => 'AGFA' },
  # http://www.burren.cx/david/canon.html: A50, EOS-D30 Canon's
  # MakerNote data is in IFD format, starting at offset 0. Some of
  # these tags and fields are only produced on cameras such as the EOS
  # D30, but (to current observation) all this is valid for all Canon
  # digicams (at least since the A50). If the tag is not found, or is
  # shorter than shown here, it simply means that data is not
  # supported by that camera.
  # personal tests) DIGITAL IXUS 300, PowerShot A10, A20, G2, S30, S40, S330
  # mynote: it seems they always use little endians
  'Canon'       => {'signature' => "^()",
		    'maker'     => 'Canon', 
		    'endianness'=> $LITTLE_ENDIAN },
  # park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html: QV2000, QV8000
  # personal tests) QV-3000EX, QV-4000, QV-2000UX, QV-8000SX
  # http://www.dicasoft.de/casiomn.htm
  # Type 1: no header, always uses Big-Endian
  # Type 2: "QVC\000\000\000" header, always uses Big-Endian
  'Casio_1'     => {'signature' => "^()[^Q]",
		    'maker'     => 'CASIO',
		    'endianness'=> $BIG_ENDIAN },
  'Casio_2'     => {'signature' => "^(QVC\000{3})",
		    'maker'     => 'CASIO',
		    'endianness'=> $BIG_ENDIAN },
  # http://www.ozhiker.com/electronics/pjmt/jpeg_info/epson_mn.html
  # Header: "EPSON\x00\x01\x00", Standard IFD Data using Olympus Tags
  # All EXIF offsets are relative to the start of the TIFF header at
  # the beginning of the EXIF segment
  'Epson'       => {'signature' => "^(EPSON\000\001\000)",
		    'maker'     => 'EPSON' },
  # Foveon is the same as Sigma, see Sigma
  'Foveon'      => {'signature' => "^(FOVEON\000{2}\001\000)",
		    'maker'     => 'FOVEON' },
  # http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html:
  #        Finepix1400, Finepix4700, FinePix4900Z, FinePix2400Zoom
  # personal tests) FinePix1400Zoom, FinePix6800ZOOM, FinePix40i
  # also http://www.ozhiker.com/electronics/pjmt/jpeg_info/fujifilm_mn.html
  # Fujifilm's Exif data uses Motorola align, but MakerNote ignores it and
  # uses Intel align. The other manufacturer's MakerNote counts the "offset
  # to data" from the first byte of TIFF header (same as the other IFD),
  # but Fujifilm counts it from the first byte of MakerNote itself (wisely)
  'Fujifilm'    => {'signature' => "^(FUJIFILM\014\000{3})",
		    'maker'     => 'FUJIFILM',
		    'endianness'=> $LITTLE_ENDIAN,
		    'mkntstart' => 1 },
  # Hewlett-Packard: do they have a MakerNote at all?
  'HPackard'    => {'signature' => "^(HP)",
		    'maker'     => 'Hewlett-Packard',
		    'ignore'    => 1 },
  # http://www.ozhiker.com/electronics/pjmt/jpeg_info/kyocera_mn.html
  # Kyocera / Contax Makernote Format Specification
  # header: 22 Bytes "KYOCERA            \x00\x00\x00"
  # IFD has no Next-IFD pointer at end of IFD, and Offsets are
  # relative to the start of the current IFD tag, not the TIFF header 
  'Kyocera'     =>  {'signature' => "^(KYOCERA {12}\000{3})",
		     'maker'     => 'KYOCERA',
		     'mkntstart' => 1,
		     'nonext'    => 1 },
  # I have a Kodak DX3900, this isn't IFD-like
  # header (16 bytes), binary data (908 bytes)
  # This works for DX4900 too
  'Kodak'       =>  {'signature' => "^(KDK INFO[a-zA-Z0-9]*  )",
		     'maker'     => 'KODAK',
		     'endianness'=> $BIG_ENDIAN,
		     'special'   => 1 },
  # http://www.dalibor.cz/minolta/makernote.htm
  # You can use this information freely in your projects but you have
  # to let me know about your project and send me an a test version.
  # header: no header
  # personal tests 1) DiMAGE X
  # personal tests 2) DiMAGE 7Hi, S404 (fails because of thumbnail at file end)
  # http://www.ozhiker.com/electronics/pjmt/jpeg_info/minolta_mn.html
  # says there are 4 more cases with unknown data (?) for Konica / Minolta
  # Type 1) begins with "MLY"
  # Type 2) begins with "KC"
  # Type 3) begins with "+M+M+M+M"
  # Type 4) begins with "MINOL"
  # personal tests) garbage in DiMAGE EX
  'Minolta_1'   => {'signature' => "^().{10}MLT0",
		    'maker'     => 'MINOLTA' },
  'Minolta_2'   => {'signature' => "^().{10}MLT0",
		    'maker'     => 'Minolta' },
  'Konica'      => {'signature' => '^((MLY|KC|(\+M){4})|\001\000{5}\004)',
		    'maker'     => '(Minolta|KONICA)',
		    'ignore'    => 1 },
  # park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html:
  # (with header) E700, E800, E900, E900S, E910, E950
  # (without header) E990, D1
  # (with header and TIFF) E5400, SQ, D2H, D70
  # Type 1: "Nikon\000\001\000", header, uses Type 1 tags
  # personal tests) E800, E900, E950
  # Type 2: no header, uses Type 3 tags [secondo me 2) e 3) hanno tags diff]
  # personal tests) E990, E995
  # Type 3: "Nikon\000\002\010\000\000" or "Nikon\000\002\000\000\000" header,
  #         this contains a second TIFF, which it refers to 
  # personal tests) D70, D100, D2H
  # http://www.tawbaware.com/990exif.htm
  # http://www.ozhiker.com/electronics/pjmt/jpeg_info/nikon_mn.html
  'Nikon_1'     => {'signature' => "^(Nikon\000\001\000)",
		    'maker'     => 'NIKON' },
  'Nikon_2'     => {'signature' => "^()[^N]",
		    'maker'     => 'NIKON' },
  'Nikon_3'     => {'signature' => "^(Nikon\000\002[\020\000]\000{2})",
		    'maker'     => 'NIKON',
		    'mkntTIFF'  => 1 },
  # park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html [C920Z,D450Z]   #
  # personal tests add 300-304, correct f00):
  # [C40Z,D40Z], [C960Z,D460Z], [C100,D370]
  # personal tests tags >= 0x1000 added by): E-10, E-20, E-20N, E-20P
  # see also http://www.ozhiker.com/electronics/pjmt/jpeg_info/olympus_mn.html
  'Olympus'     => {'signature' => "^(OLYMP\000[\001\002]\000)",
		    'maker'     => 'OLYMPUS' },
  # http://www.compton.nu/panasonic.html: DMC-FZ10.
  # Type 1) header: "Panasonic\x00\x00\x00"
  # NON-Standard TIFF IFD Data using Panasonic Tags. There is no
  # Next-IFD pointer after the IFD. Offsets are relative to the
  # start of the TIFF header at the beginning of the EXIF segment
  # personal tests) DMC-FZ15, DMC-FZ3
  # Type 2) blank or junk data after "MKED"
  'Panasonic_1' => {'signature' => "^(Panasonic\000{3})",
		    'maker'     => 'Panasonic',
		    'nonext'    => 1 },
  'Panasonic_2' => {'signature' => "^(MKED)",
		    'maker'     => 'Panasonic',
		    'nonext'    => 1,
		    'ignore'    => 1 },
  # http://www.ozhiker.com/electronics/pjmt/jpeg_info/pentax_mn.html
  # There are two types of Pentax / Asahi Makernote:
  # Type 1) no Next-IFD pointer at end of IFD, and Offsets are relative
  #         to the start of the current IFD tag, not the TIFF header
  # personal tests) Optio 330, 430
  # Type 2) header: "AOC\x00", NON-Standard TIFF IFD Data using Casio
  #         Type 2 Tags, IFD has no Next-IFD pointer at end of IFD, and
  #         Offsets are relative to the start of the current IFD tag
  # personal tests) Optio 230
  'Pentax_1'    => {'signature' => "^()[^A]",
		    'maker'     => 'Asahi',
		    'mkntstart' => 1,
		    'nonext'    => 1 },
  'Pentax_2'    => {'signature' => "^(AOC\000..)",
		    'maker'     => 'Asahi',
		    'mkntstart' => 1,
		    'nonext'    => 1 },
  # http://www.ozhiker.com/electronics/pjmt/jpeg_info/ricoh_mn.html
  # There are three types of Ricoh Makernote:
  # Type 1 (text beginning with "Rv" or "Rev")
  # personal tests) DC-3Z, RDC-5000, RDC-5300
  # Type 2 (blank field filled with 0x00 characters)
  # Type 3: header: "Ricoh" or "RICOH"
  # personal tests) Caplio RR30
  # always uses Motorola (Big-Endian) byte alignment
  'Ricoh_1'     => {'signature' => "^(Rv|Rev)",
		    'maker'     => 'RICOH',
		    'ignore'    => 1 },
  'Ricoh_2'     => {'signature' => "^(\000)",
		    'maker'     => 'RICOH',
		    'ignore'    => 1 },
  'Ricoh_3'     => {'signature' => "^((Ricoh|RICOH)\000{3})",
		    'maker'     => 'RICOH',
		    'endianness'=> $BIG_ENDIAN },
  # http://www.exif.org/makernotes/SanyoMakerNote.html: DSC-MZ2
  # personal tests) SR662, SR6, SX113
  'Sanyo'       => {'signature' => "^(SANYO\000\001\000)",
		    'maker'     => 'SANYO' },
  # http://www.x3f.info/technotes/FileDocs/MakerNoteDoc.html
  # The SIGMA or FOVEON MakerNote types are alike except for the
  # 8-byte ID string "SIGMA\0\0\0" or "FOVEON\0\0".
  # personal tests) SIGMA SD9, SD10
  'Sigma'       => {'signature' => "^(SIGMA\000{3}\001\000)",
		    'maker'     => 'SIGMA' },
  # http://www.ozhiker.com/electronics/pjmt/jpeg_info/sony_mn.html
  # header: "SONY CAM \x00\x00\x00" or "SONY DSC \x00\x00\x00"
  # There is no Next-IFD pointer at end of the IFD
  # Print Image Matching is the only currently known Sony Tag, 
  # so most often the MakerNote is note there at all
  # personal tests) Cybershot
  'Sony'        => {'signature' => "^(SONY (CAM|DSC) \000{3})",
		    'maker'     => 'SONY',
		    'nonext'    => 1 },
  # Toshiba: do they have a MakerNote at all?
  'Toshiba'     => {'signature' => "^()",
		    'maker'     => 'TOSHIBA',
		    'ignore'    => 1 },
};
#--- Special screen rules ---------------------------------------------------#
# an ISO setting record often consists of a pair of $SHORT numbers:          #
# the first number is always zero, the second one gives the ISO setting.     #
my $SSR_ISOsetting  = sub { die if $_[0] != 0; die if $_[1] !~ /\d*00/; };   #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Canon'}{'tags'} =                                         #
{ 0x0000 => ['Placeholder',        $SHORT, undef, '0'                     ], #
  0x0001 => ['CameraSettings',     $SHORT, undef, $IFD_integer            ], #
  0x0002 => [ undef,               $SHORT,     4, undef                   ], #
  0x0003 => [ undef,               $SHORT,     4, undef                   ], #
  0x0004 => ['ShotInfo',           $SHORT, undef, undef                   ], #
  0x0005 => [ undef,               $SHORT,     6, undef                   ], #
  0x0006 => ['ImageType',          $ASCII,    32, $IFD_Cstring            ], #
  0x0007 => ['FirmwareVersion',    $ASCII,    24, $IFD_Cstring            ], #
  0x0008 => ['ImageNumber',        $LONG,      1, $IFD_integer            ], #
  0x0009 => ['OwnerName',          $ASCII,    32, $IFD_Cstring            ], #
  0x000a => ['Settings-1D',        $SHORT, undef, undef                   ], #
  0x000c => ['CameraSerialNumber', $LONG,      1, $IFD_integer            ], #
  0x000d => [ undef,               $SHORT, undef, undef                   ], #
  0x000e => ['FileLength',         undef,  undef, undef                   ], #
  0x000f => ['CustomFunctions',    $SHORT, undef, undef                   ], #
  0x0010 => [ undef,               $LONG,      1, undef                   ], #
  0x0012 => ['PictureInfo',        undef,  undef, undef                   ], #
  0x0090 => ['CustomFunctions-1D', undef,  undef, undef                   ], #
  0x00a0 => ['Canon-A0Tag',        undef,  undef, undef                   ], #
  0x00b6 => ['PreviewImageInfo',   undef,  undef, undef                ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Casio_1'}{'tags'} =				             #
{ 0x0001 => ['RecordingMode',      $SHORT,     1, '[1-5]'                 ], #
  0x0002 => ['Quality',            $SHORT,     1, '[123]'                 ], #
  0x0003 => ['FocusingMode',       $SHORT,     1, '[2-57]'                ], #
  0x0004 => ['FlashMode',          $SHORT,     1, '[1-5]'                 ], #
  0x0005 => ['FlashIntensity',     $SHORT,     1, '1[135]'                ], #
  0x0006 => ['ObjectDistance',     $LONG,      1, $IFD_integer            ], #
  0x0007 => ['WhiteBalance',       $SHORT,     1, '([1-5]|129)'           ], #
  0x0008 => [ undef,               $SHORT,     1, '[1-4]'                 ], #
  0x0009 => [ undef,               $SHORT,     1, '[12]'                  ], #
  0x000a => ['DigitalZoom',        $LONG,      1, '(65536|65537|131072)'  ], #
  0x000b => ['Sharpness',          $SHORT,     1, '([012]|16)'            ], #
  0x000c => ['Contrast',           $SHORT,     1, '([012]|16)'            ], #
  0x000d => ['Saturation',         $SHORT,     1, '([012]|16)'            ], #
  0x000e => [ undef,               $SHORT,     1, '[0]'                   ], #
  0x000f => [ undef,               $SHORT,     1, $IFD_integer            ], #
  0x0010 => [ undef,               $SHORT,     1, '[01]'                  ], #
  0x0011 => [ undef,               $LONG,      1, $IFD_integer            ], #
  0x0012 => [ undef,               $SHORT,     1, '(16|18|24)'            ], #
  0x0013 => [ undef,               $SHORT,     1, '(6|1[567])'            ], #
  0x0014 => ['CCDSensitivity',     $SHORT,     1,'(64|80|100|125|244|250)'], #
  0x0015 => [ undef,               $ASCII, undef, $IFD_Cstring            ], #
  0x0016 => [ undef,               $SHORT,     1, '[1]'                   ], #
  0x0017 => [ undef,               $SHORT,     1, '[1]'                   ], #
  0x0018 => [ undef,               $SHORT,     1, '(13)'                  ], #
  0x0019 => ['WhiteBalance',       $SHORT,     1, '[0-5]'                 ], #
  0x001a => [ undef,               $UNDEF, undef, undef                   ], #
  0x001c => [ undef,               $SHORT,     1, '[5]'                   ], #
  0x001d => ['FocalLength',        $SHORT,     1, $IFD_integer            ], #
  0x001e => [ undef,               $SHORT,     1, '[1]'                   ], #
  0x0e00 => ['PrintIM_Data',       $UNDEF, undef, undef                ], }; # 
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Casio_2'}{'tags'} =				             #
{ 0x0002 => ['PreviewThumbDim',    $SHORT,     2, $IFD_integer            ], #
  0x0003 => ['PreviewThumbSize',   $LONG,      1, $IFD_integer            ], #
  0x0004 => ['PreviewThumbOffset', $LONG,      1, $IFD_integer            ], #
  0x0008 => ['QualityMode',        $SHORT,     1, '[12]'                  ], #
  0x0009 => ['ImageSize',          $SHORT,     1, '([045]|2[012]|36)'     ], #
  0x000d => ['FocusMode',          $SHORT,     1, '[01]'                  ], #
  0x0014 => ['CCDSensitivity',     $SHORT,     1, '[3469]'                ], #
  0x0019 => ['WhiteBalance',       $SHORT,     1, '[0-5]'                 ], #
  0x001d => ['FocalLength',        $SHORT,     1, $IFD_integer            ], #
  0x001f => ['Saturation',         $SHORT,     1, '[0-2]'                 ], #
  0x0020 => ['Contrast',           $SHORT,     1, '[0-2]'                 ], #
  0x0021 => ['Sharpness',          $SHORT,     1, '[0-2]'                 ], #
  0x0e00 => ['PrintIM_Data',       $UNDEF, undef, undef                   ], # 
  0x2000 => ['PreviewThumbnail',   $UNDEF, undef, '\377\330\377.*'        ], #
  0x2001 => [ undef,               $ASCII, undef, undef                   ], #
  0x2002 => [ undef,               $ASCII, undef, undef                   ], #
  0x2003 => [ undef,               $UNDEF, undef, undef                   ], #
  0x2011 => ['WhiteBalanceBias',   $SHORT,     2, undef                   ], #
  0x2012 => ['WhiteBalance',       $SHORT,     1, '(12|[014])'            ], #
  0x2013 => [ undef,               $SHORT,     1, undef                   ], #
  0x2021 => [ undef,               $SHORT,     4, '65535'                 ], #
  0x2022 => ['ObjectDistance',     $LONG,      1, $IFD_integer            ], #
  0x2023 => [ undef,               $SHORT,     1, undef                   ], #
  0x2031 => [ undef,               $UNDEF,     2, undef                   ], #
  0x2032 => [ undef,               $UNDEF,     2, undef                   ], #
  0x2033 => [ undef,               $SHORT,     1, undef                   ], #
  0x2034 => ['FlashDistance',      $SHORT,     1, $IFD_integer            ], #
  0x3000 => ['RecordMode',         $SHORT,     1, '[2]'                   ], #
  0x3001 => ['SelfTimer',          $SHORT,     1, '[1]'                   ], #
  0x3002 => ['Quality',            $SHORT,     1, '[23]'                  ], #
  0x3003 => ['FocusMode',          $SHORT,     1, '[136]'                 ], #
  0x3005 => [ undef,               $SHORT,     1, undef                   ], #
  0x3006 => ['TimeZone',           $ASCII, undef, $IFD_Cstring            ], #
  0x3007 => ['BestshotMode',       $SHORT,     1, '[01]'                  ], #
  0x3011 => [ undef,               $UNDEF,     2, undef                   ], #
  0x3012 => [ undef,               $UNDEF,     2, undef                   ], #
  0x3013 => [ undef,               $UNDEF,     1, undef                   ], #
  0x3014 => ['CCDSensitivity',     $SHORT,     1, '[0]'                   ], #
  0x3015 => ['ColourMode',         $SHORT,     1, '[0]'                   ], #
  0x3016 => ['Enhancement',        $SHORT,     1, '[0]'                   ], #
  0x3017 => ['Filter',             $SHORT,     1, '[0]'                   ], #
  0x3018 => [ undef,               $SHORT,     1, '[0]'                ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Fujifilm'}{'tags'} =                                      #
{ 0x0000 => ['Version',            $UNDEF,     4, '0130'                  ], #
  0x1000 => ['Quality',            $ASCII,     8, '(BASIC|NORMAL|FINE)'   ], #
  0x1001 => ['Sharpness',          $SHORT,     1, '[1-5]'                 ], #
  0x1002 => ['WhiteBalance',       $SHORT,     1, '(0|256|512|76[89]|770)'], #
  0x1003 => ['ColorSaturation',    $SHORT,     1, '(0|256|512)'           ], #
  0x1004 => ['ToneContrast',       $SHORT,     1, '(0|256|512)'           ], #
  0x1010 => ['FlashMode',          $SHORT,     1, '[0-3]'                 ], #
  0x1011 => ['FlashStrength',      $SRATIONAL, 1, $IFD_signed             ], #
  0x1020 => ['MacroMode',          $SHORT,     1, '[01]'                  ], #
  0x1021 => ['FocusMode',          $SHORT,     1, '[01]'                  ], #
  0x1030 => ['SlowSync',           $SHORT,     1, '[01]'                  ], #
  0x1031 => ['PictureMode',        $SHORT,     1, '([0-24-6]|256|512|768)'], #
  0x1032 => [ undef,               $SHORT,     1, undef                   ], #
  0x1100 => ['ContTake/Bracket',   $SHORT,     1, '[01]'                  ], #
  0x1200 => [ undef,               $SHORT,     1, undef                   ], #
  0x1300 => ['BlurWarning',        $SHORT,     1, '[01]'                  ], #
  0x1301 => ['Focuswarning',       $SHORT,     1, '[01]'                  ], #
  0x1302 => ['AutoExposureWarning',$SHORT,     1, '[01]'               ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Kodak'}{'tags'} =                                         #
{ 0x0001 => ['---0x0001',          $BYTE,      1, undef                   ], #
  0x0002 => ['Compression',        $BYTE,      1, '[12]'                  ], #
  0x0003 => ['BurstMode',          $BYTE,      1, '[01]'                  ], #
  0x0004 => ['MacroMode',          $BYTE,      1, '[01]'                  ], #
  0x0005 => ['PixelXDimension',    $SHORT,     1, '(2160|1800|1536|1080)' ], #
  0x0007 => ['PixelYDimension',    $SHORT,     1, '(1440|1200|1024|720)'  ], #
  0x0009 => ['Year',               $SHORT,     1, $re_year                ], #
  0x000a => ['Month',              $BYTE,      1, $re_month               ], #
  0x000b => ['Day',                $BYTE,      1, $re_day                 ], #
  0x000c => ['Hour',               $BYTE,      1, $re_hour                ], #
  0x000d => ['Minute',             $BYTE,      1, $re_minute              ], #
  0x000e => ['Second',             $BYTE,      1, $re_second              ], #
  0x000f => ['SubSecond',          $BYTE,      1, $re_integer             ], #
  0x0010 => ['---BurstMode_2',     $SHORT,     1, undef                   ], #
  0x0012 => ['---0x0012',          $BYTE,      1, undef                   ], #
  0x0013 => ['ShutterMode',        $BYTE,      1, '(0|32)'                ], #
  0x0014 => ['MeteringMode',       $BYTE,      1, '[012]'                 ], #
  0x0015 => ['BurstSequenceIndex', $BYTE,      1, '[0-8]'                 ], #
  0x0016 => ['FNumber',            $SHORT,     1, undef                   ], #
  0x0018 => ['ExposureTime',       $LONG,      1, $re_integer             ], #
  0x001c => ['ExposureBiasValue',  $SSHORT,    1, '(0|-?(5|10|15|20)00)'  ], #
  0x001e => ['---VariousModes_2',  $SHORT,     1, undef                   ], #
  0x0020 => ['---Distance_1',      $LONG,      1, undef                   ], #
  0x0024 => ['---Distance_2',      $LONG,      1, undef                   ], #
  0x0028 => ['---Distance_3',      $LONG,      1, undef                   ], #
  0x002c => ['---Distance_4',      $LONG,      1, undef                   ], #
  0x0030 => ['FocusMode',          $BYTE,      1, '[023]'                 ], #
  0x0031 => ['---0x0031',          $BYTE,      1, undef                   ], #
  0x0032 => ['---VariousModes_3',  $SHORT,     1, undef                   ], #
  0x0034 => ['PanoramaMode',       $SHORT,     1, '(0|65535)'             ], #
  0x0036 => ['SubjectDistance',    $SHORT,     1, $re_integer             ], #
  0x0038 => ['WhiteBalance',       $BYTE,      1, '[0-3]'                 ], #
  0x0039 => ['---0x0039',          $BYTE,      1, undef                   ], #
  0x003a => ['---0x003a',          $SHORT,     1, undef                   ], #
  0x003c => ['---0x003c',          $LONG,      1, undef                   ], #
  0x0040 => ['---0x0040',          $SHORT,     1, undef                   ], #
  0x0042 => ['---0x0042',          $SHORT,     1, undef                   ], #
  0x0044 => ['---0x0044',          $SHORT,     1, undef                   ], #
  0x0046 => ['---0x0046',          $SHORT,     1, undef                   ], #
  0x0048 => ['---0x0048',          $SHORT,     1, undef                   ], #
  0x004a => ['---0x004a',          $SHORT,     1, undef                   ], #
  0x004c => ['---0x004c',          $SHORT,     1, undef                   ], #
  0x004e => ['---0x004e',          $SHORT,     1, undef                   ], #
  0x0050 => ['---0x0050',          $SHORT,     1, undef                   ], #
  0x0052 => ['---0x0052',          $SHORT,     1, undef                   ], #
#  0x0052 => ['---0x0052',          $BYTE,      1, undef                   ], #
#  0x0053 => ['---0x0053',          $BYTE,      1, undef                   ], #
  0x0054 => ['FlashMode',          $BYTE,      1, '[0-3]'                 ], #
  0x0055 => ['FlashFired',         $BYTE,      1, '[01]'                  ], #
  0x0056 => ['ISOSpeedMode',       $SHORT,     1, '(0|[124]00)'           ], #
  0x0058 => ['---ISOSpeedExposureIndex', $SHORT,     1, undef             ], #
  0x005a => ['TotalZoomFactor',    $SHORT,     1, $re_integer             ], #
  0x005c => ['DateTimeStampMode',  $SHORT,     1, '[0-6]'                 ], #
  0x005e => ['ColourMode',         $SHORT,     1, '(1|2|32)'              ], #
  0x0060 => ['DigitalZoomFactor',  $SHORT,     1, $re_integer             ], #
  0x0062 => ['---0x0062',          $BYTE,      1, undef                   ], #
  0x0063 => ['Sharpness',          $BYTE,      1, '(0|1|255)'             ], #

  0x0064 => ['rest',               $UNDEF,   808, undef                   ], #

#  0x0064 => ['---0x0064',          $SHORT,     1, undef                   ], #
#  0x0066 => ['---0x0066',          $SHORT,     1, undef                   ], #
#  0x0068 => ['---0x0068',          $SHORT,     1, undef                   ], #
#  0x006a => ['---0x006a',          $SHORT,     1, undef                   ], #
#  0x006c => ['---0x006c',          $SHORT,     1, undef                   ], #
#  0x006e => ['---0x006e',          $SHORT,     1, undef                   ], #
#  0x0070 => ['---0x0070',          $SHORT,     1, undef                   ], #
#  0x0072 => ['---0x0072',          $SHORT,     1, undef                   ], #
#  0x0074 => ['---0x0074',          $SHORT,     1, undef                   ], #
#  0x0076 => ['---0x0076',          $SHORT,     1, undef                   ], #
#  0x0078 => ['---0x0078',          $SHORT,     1, undef                   ], #
#  0x007a => ['---0x007a',          $SHORT,     1, undef                   ], #
#  0x007c => ['---0x007c',          $SHORT,     1, undef                   ], #
#  0x007e => ['---0x007e',          $SHORT,     1, undef                   ], #
#  0x0080 => ['---0x0080',          $SHORT,     1, undef                   ], #
#  0x0082 => ['---0x0082',          $SHORT,     1, undef                   ], #
#  0x0084 => ['---0x0084',          $SHORT,     1, undef                   ], #
#  0x0086 => ['---0x0086',          $SHORT,     1, undef                   ], #
#  0x0088 => ['---0x0088',          $SHORT,     1, undef                   ], #
#  0x008a => ['---0x008a',          $SHORT,     1, undef                   ], #
#  0x008c => ['---0x008c',          $SHORT,     1, undef                   ], #
#  0x008e => ['---0x008e',          $SHORT,     1, undef                   ], #
#  0x0090 => ['---0x0090',          $SHORT,     1, undef                   ], #
#  0x0092 => ['---0x0092',          $SHORT,     1, undef                   ], #
#  0x0094 => ['---0x0094',          $SHORT,     1, undef                   ], #
#  0x0096 => ['---0x0096',          $SHORT,     1, undef                   ], #
#  0x0098 => ['---0x0098',          $SHORT,     1, undef                   ], #
#  0x009a => ['---0x009a',          $SHORT,     1, undef                   ], #
#  0x009c => ['rest',               $UNDEF,   752, undef                   ], #
};
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Kyocera'}{'tags'} =                                       #
{ 0x0001 => ['Thumbnail',          $UNDEF, undef, undef                   ], #
  0x0e00 => ['PrintIM_Data',       $UNDEF, undef, undef                ], }; # 
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Minolta_1'}{'tags'} =				     #
{ 0x0000 => ['MakerNoteVersion',   $UNDEF,     4, 'MLT0'                  ], #
  0x0200 => ['SpecialMode',        $LONG,      3, $IFD_integer            ], #
  0x0201 => ['Quality',            $SHORT,     3, undef                   ], #
  0x0202 => ['MacroMode',          $SHORT,     1, '[012]'                 ], #
  0x0203 => [ undef,               $SHORT,     1, undef                   ], #
  0x0204 => ['DigitalZoom',        $RATIONAL,  1, $IFD_integer            ], #
  0x020e => [ undef,               $SHORT,     1, undef                   ], #
  0x020f => [ undef,               $SHORT,     1, undef                   ], #
  0x0210 => [ undef,               $SHORT,     1, undef                   ], #
  0x0211 => [ undef,               $SHORT,     1, undef                   ], #
  0x0212 => [ undef,               $SHORT,     1, undef                   ], #
  0x0213 => [ undef,               $SHORT,     1, undef                   ], #
  0x0214 => [ undef,               $SHORT,     1, undef                   ], #
  0x0215 => [ undef,               $SHORT,     1, undef                   ], #
  0x0216 => [ undef,               $SHORT,     1, undef                   ], #
  0x0217 => [ undef,               $SHORT,     1, undef                   ], #
  0x0218 => [ undef,               $SHORT,     1, undef                   ], #
  0x0219 => [ undef,               $SHORT,     1, undef                   ], #
  0x021a => [ undef,               $SHORT,     1, undef                   ], #
  0x021b => [ undef,               $SHORT,     1, undef                   ], #
  0x021c => [ undef,               $SHORT,     1, undef                   ], #
  0x021d => ['ManualWhiteBalance', $SHORT,     1, undef                   ], #
  0x021e => [ undef,               $SHORT,     1, undef                   ], #
  0x021f => [ undef,               $SHORT,     1, undef                   ], #
  0x0e00 => ['PrintIM_Data',       $UNDEF, undef, undef                   ], # 
  0x0f00 => ['DataDump',           $UNDEF, undef, undef                ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Minolta_2'}{'tags'} =				     #
{ 0x0000 => ['MakerNoteVersion',   $UNDEF,     4, 'MLT0'                  ], #
  0x0001 => ['CameraSettingsOld',  $UNDEF, undef, '.*'                    ], #
  0x0003 => ['CameraSettingsNew',  $UNDEF, undef, '.*'                    ], #
  0x0010 => [ undef,               $UNDEF, undef, '.*'                    ], #
  0x0020 => [ undef,               $UNDEF, undef, '.*'                    ], #
  0x0040 => ['CompressedImageSize',$LONG,      1, $IFD_integer            ], #
  0x0081 => ['Thumbnail',          $UNDEF, undef, '.*'                    ], #
  0x0088 => ['ThumbnailOffset',    $LONG,      1, $IFD_integer            ], #
  0x0089 => ['ThumbnailLength',    $LONG,      1, $IFD_integer            ], #
  0x0100 => [ undef,               $LONG,      1, $IFD_integer            ], #
  0x0101 => ['ColourMode',         $LONG,      1, '[0-4]'                 ], #
  0x0102 => ['ImageQuality_1',     $LONG,      1, '[0-35]'                ], #
  0x0103 => ['ImageQuality_2',     $LONG,      1, '[0-35]'                ], #
  0x0e00 => ['PrintIM_Data',       $UNDEF, undef, undef                   ], # 
  0x0f00 => [ undef,               $UNDEF, undef, undef                ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Nikon_1'}{'tags'} =				             #
{ 0x0002 => [ undef,               $ASCII,     6, '(09\.41|08\.00)\000'   ], #
  0x0003 => ['Quality',            $SHORT,     1, '([1-9]|1[0-2])'        ], #
  0x0004 => ['ColorMode',          $SHORT,     1, '[12]'                  ], #
  0x0005 => ['ImageAdjustment',    $SHORT,     1, '[0-4]'                 ], #
  0x0006 => ['CCDSensitivity',     $SHORT,     1, '[0245]'                ], #
  0x0007 => ['WhiteBalance',       $SHORT,     1, '[0-6]'                 ], #
  0x0008 => ['Focus',              $RATIONAL,  1, $IFD_integer            ], #
  0x0009 => [ undef,               $ASCII,    20, $IFD_Cstring            ], #
  0x000a => ['DigitalZoom',        $RATIONAL,  1, $IFD_integer            ], #
  0x000b => ['Converter',          $SHORT,     1, '[01]'                  ], #
  0x0f00 => [ undef,               $LONG,  undef, $IFD_integer         ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Nikon_2'}{'tags'} =                                       #
{ 0x0001 => ['MakerNoteVersion',   $UNDEF,     4, '\000\001\000{2}'       ], #
  0x0002 => ['ISOSetting',         $SHORT,     2, $IFD_integer            ], #
  0x0003 => ['ColorMode',          $ASCII, undef, '(COLOR|B&W)\000'       ], #
  0x0004 => ['Quality',            $ASCII, undef,'(NORMAL|FINE|BASIC)\000'], #
  0x0005 => ['WhiteBalance',       $ASCII, undef,'(AUTO|WHITE PRESET)\000'], #
  0x0006 => ['ImageSharpening',    $ASCII, undef, '(AUTO|HIGH)\000'       ], #
  0x0007 => ['FocusMode',          $ASCII, undef, '(AF-S|AF-C)\000'       ], #
  0x0008 => ['FlashSetting',       $ASCII, undef, '(NORMAL|RED-EYE)\000'  ], #
  0x0009 => ['AutoFlashMode',      $ASCII, undef, $IFD_Cstring            ], #
  0x000a => [ undef,               $RATIONAL,  1, undef                   ], #
  0x000b => ['WhiteBalanceBias',   $SHORT,     2, undef                   ], #
  0x000c => ['WhiteBalanceRedBlue',$SHORT,     2, undef                   ], #
  0x000f => ['ISOSelection',       $ASCII, undef, '(MANUAL|AUTO)\000'     ], #
  0x0010 => ['DataDump',           $UNDEF,   174, undef                   ], #
  0x0011 => [ undef,               $LONG,      1, $IFD_integer            ], #
  0x0012 => ['FlashCompensation',  $SSHORT,    1, $IFD_signed             ], #
  0x0013 => ['ISOSpeedRequested',  $SHORT,     2, undef                   ], #
  0x0016 => ['PhotoCornerCoord',   $SHORT,     4, $IFD_integer            ], #
  0x0018 => ['FlashBracketComp',   $SSHORT,    1, $IFD_signed             ], #
  0x0019 => ['AEBracketComp',      $SHORT,     1, undef                   ], #
  0x0080 => ['ImageAdjustment',    $ASCII, undef, '(AUTO|NORMAL)\000'     ], #
  0x0081 => ['ToneContrast',       $ASCII, undef, $IFD_Cstring            ], #
  0x0082 => ['Adapter',            $ASCII, undef, '(OFF|WIDE ADAPTER)'    ], #
  0x0083 => ['LensType',           $ASCII, undef, $IFD_Cstring            ], #
  0x0084 => ['MaxAperture',        $ASCII, undef, $IFD_Cstring            ], #
  0x0085 => ['ManualFocusDistance',$RATIONAL,  1, $IFD_integer            ], #
  0x0086 => ['DigitalZoom',        $RATIONAL,  1, $IFD_integer            ], #
  0x0087 => ['FlashUsed',          $SHORT,     1, '[09]'                  ], #
  0x0088 => ['AFFocusPosition',    $UNDEF,    4,'[\000-\002][\000-\004]..'], #
  0x0089 => ['BracketShotMode',    $BYTE,      1, undef                   ], #
  0x008d => ['ColourMode',         $ASCII, undef, '(1a|2|3a)\000'         ], #
  0x008e => ['SceneMode',          $SHORT,     1, undef                   ], #
  0x008f => ['LightingType',       $ASCII, undef, $IFD_Cstring            ], #
  0x0092 => ['HueAdjustment',      $SHORT,     1, undef                   ], #
  0x0094 => ['Saturation',         $SSHORT,    1, '(-[1-3]|[0-2])'        ], #
  0x0095 => ['NoiseReduction',     $ASCII, undef, '(FPNR)\000'            ], #
  0x00a7 => ['ShutterReleases',    $SHORT,     1, $IFD_integer            ], #
  0x00a9 => ['ImageOptimisation',  $ASCII, undef, $IFD_Cstring            ], #
  0x00aa => ['Saturation',         $ASCII, undef, $IFD_Cstring            ], #
  0x00ab => ['DigitalVariProgram', $ASCII, undef, undef                   ], #
  0x0e00 => ['PrintIM_Data',       $UNDEF, undef, undef                   ], #
  0x0e10 => [ undef,               $LONG,      1, $IFD_integer         ], }; # 
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Nikon_3'}{'tags'} =                                       #
{ 0x0001 => ['MakerNoteVersion',   $UNDEF,     4, '0200'                  ], #
  0x0002 => ['ISOSetting',         $SHORT,     2, $SSR_ISOsetting,        ], #
  0x0004 => [ undef,               $ASCII, undef, undef                   ], #
  0x0005 => [ undef,               $ASCII, undef, undef                   ], #
  0x0006 => ['FocusMode',          $ASCII, undef, '(AF-S|AF-C)\000'       ], #
  0x0007 => [ undef,               $ASCII, undef, undef                   ], #
  0x0008 => [ undef,               $ASCII, undef, undef                   ], #
  0x0009 => [ undef,               $ASCII, undef, undef                   ], #
  0x000b => [ undef,               $SSHORT,    1, undef                   ], #
  0x000c => [ undef,               $RATIONAL,  4, $IFD_integer            ], #
  0x000d => [ undef,               $UNDEF,     4, undef                   ], #
  0x000e => [ undef,               $UNDEF,     4, undef                   ], #
  0x0011 => [ undef,               $LONG,      1, $IFD_integer            ], #
  0x0012 => [ undef,               $UNDEF,     4, undef                   ], #
  0x0013 => [ undef,               $SHORT,     2, $SSR_ISOsetting         ], #
  0x0016 => [ undef,               $SHORT,     4, $IFD_integer            ], #
  0x0017 => [ undef,               $UNDEF,     4, undef                   ], #
  0x0018 => [ undef,               $UNDEF,     4, undef                   ], #
  0x0019 => [ undef,               $SRATIONAL, 1, $IFD_integer            ], #
  0x0081 => [ undef,               $ASCII, undef, undef                   ], #
  0x0083 => [ undef,               $BYTE,      1, undef                   ], #
  0x0084 => [ undef,               $RATIONAL,  4, undef                   ], #
  0x0087 => [ undef,               $BYTE,      1, undef                   ], #
  0x0088 => [ undef,               $UNDEF,     4, undef                   ], #
  0x0089 => [ undef,               $BYTE,      1, undef                   ], #
  0x008a => [ undef,               $SHORT,     1, undef                   ], #
  0x008b => [ undef,               $UNDEF,     4, undef                   ], #
  0x008c => [ undef,               $UNDEF, undef, undef                   ], #
  0x008d => [ undef,               $ASCII, undef, undef                   ], #
  0x0090 => [ undef,               $ASCII, undef, undef                   ], #
  0x0091 => [ undef,               $UNDEF, undef, undef                   ], #
  0x0092 => [ undef,               $SSHORT,    1, undef                   ], #
  0x0095 => [ undef,               $ASCII, undef, undef                   ], #
  0x0097 => [ undef,               $UNDEF, undef, undef                   ], #
  0x0098 => [ undef,               $UNDEF, undef, undef                   ], #
  0x0099 => [ undef,               $SHORT,     2, undef                   ], #
  0x009a => [ undef,               $RATIONAL,  2, undef                   ], #
  0x00a0 => [ undef,               $ASCII, undef, undef                   ], #
  0x00a2 => [ undef,               $LONG,      1, undef                   ], #
  0x00a3 => [ undef,               $BYTE,      1, undef                   ], #
  0x00a5 => [ undef,               $LONG,      1, undef                   ], #
  0x00a6 => [ undef,               $LONG,      1, undef                   ], #
  0x00a7 => [ undef,               $LONG,      1, undef                   ], #
  0x00a8 => [ undef,               $UNDEF, undef, undef                   ], #
  0x00a9 => [ undef,               $ASCII, undef, undef                   ], #
  0x00aa => [ undef,               $ASCII, undef, undef                   ], #
  0x00ab => [ undef,               $ASCII, undef, undef                   ], #
  0x0e08 => [ undef,               $SHORT,     1, undef                   ], #
  0x0e09 => [ undef,               $ASCII, undef, undef                   ], #
  0x0e10 => [ undef,               $LONG,      1, undef                ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Olympus'}{'tags'} =                                       #
{ 0x0100 => ['JPEGThumbnail',      $UNDEF, undef, '\377\330\377.*'        ], #
  0x0200 => ['SpecialMode',        $LONG,      3, $IFD_integer            ], #
  0x0201 => ['JpegQuality',        $SHORT,     1, '[123]'                 ], #
  0x0202 => ['Macro',              $SHORT,     1, '[012]'                 ], #
  0x0203 => [ undef,               $SHORT,     1, undef                   ], #
  0x0204 => ['DigitalZoom',        $RATIONAL,  1, $IFD_integer            ], #
  0x0205 => [ undef,               $RATIONAL,  1, undef                   ], #
  0x0206 => [ undef,               $SSHORT,    6, undef                   ], #
  0x0207 => ['SoftwareRelease',    $ASCII,     5, '[A-Z0-9]*'             ], #
  0x0208 => ['PictureInfo',        $ASCII, undef, '[\040-\176]*'          ], #
  0x0209 => ['CameraID',           $UNDEF, undef, '.*'                    ], #
  0x0300 => [ undef,               $SHORT,     1, undef                   ], #
  0x0301 => [ undef,               $SHORT,     1, undef                   ], #
  0x0302 => [ undef,               $SHORT,     1, undef                   ], #
  0x0303 => [ undef,               $SHORT,     1, undef                   ], #
  0x0304 => [ undef,               $SHORT,     1, undef                   ], #
  0x0f00 => ['DataDump',           $UNDEF, undef, undef                   ], #
  0x1000 => [ undef,               $SRATIONAL, 1, undef                   ], #
  0x1001 => [ undef,               $SRATIONAL, 1, undef                   ], #
  0x1002 => [ undef,               $SRATIONAL, 1, undef                   ], #
  0x1003 => [ undef,               $SRATIONAL, 1, undef                   ], #
  0x1004 => ['FlashMode',          $SHORT,     1, undef                   ], #
  0x1005 => [ undef,               $SHORT,     2, undef                   ], #
  0x1006 => ['Bracket',            $SRATIONAL, 1, undef                   ], #
  0x1007 => [ undef,               $SSHORT,    1, undef                   ], #
  0x1008 => [ undef,               $SSHORT,    1, undef                   ], #
  0x1009 => [ undef,               $SHORT,     1, undef                   ], #
  0x100a => [ undef,               $SHORT,     1, undef                   ], #
  0x100b => ['FocusMode',          $SHORT,     1, undef                   ], #
  0x100c => ['FocusDistance',      $RATIONAL,  1, undef                   ], #
  0x100d => ['Zoom',               $SHORT,     1, undef                   ], #
  0x100e => ['MacroFocus',         $SHORT,     1, undef                   ], #
  0x100f => ['Sharpness',          $SHORT,     1, undef                   ], #
  0x1010 => [ undef,               $SHORT,     1, undef                   ], #
  0x1011 => ['ColourMatrix',       $SHORT,     9, undef                   ], #
  0x1012 => ['BlackLevel',         $SHORT,     4, undef                   ], #
  0x1013 => [ undef,               $SHORT,     1, undef                   ], #
  0x1014 => [ undef,               $SHORT,     1, undef                   ], #
  0x1015 => ['WhiteBalance',       $SHORT,     2, undef                   ], #
  0x1016 => [ undef,               $SHORT,     1, undef                   ], #
  0x1017 => ['RedBias',            $SHORT,     2, undef                   ], #
  0x1018 => ['BlueBias',           $SHORT,     2, undef                   ], #
  0x1019 => [ undef,               $SHORT,     1, undef                   ], #
  0x101a => ['SerialNumber',       $ASCII,    32, '[\040-\176].*\000*'    ], #
  0x101b => [ undef,               $LONG,      1, undef                   ], #
  0x101c => [ undef,               $LONG,      1, undef                   ], #
  0x101d => [ undef,               $LONG,      1, undef                   ], #
  0x101e => [ undef,               $LONG,      1, undef                   ], #
  0x101f => [ undef,               $LONG,      1, undef                   ], #
  0x1020 => [ undef,               $LONG,      1, undef                   ], #
  0x1021 => [ undef,               $LONG,      1, undef                   ], #
  0x1022 => [ undef,               $LONG,      1, undef                   ], #
  0x1023 => ['FlashBias',          $SRATIONAL, 1, undef                   ], #
  0x1024 => [ undef,               $SHORT,     1, undef                   ], #
  0x1025 => [ undef,               $SRATIONAL, 1, undef                   ], #
  0x1026 => [ undef,               $SHORT,     1, undef                   ], #
  0x1027 => [ undef,               $SHORT,     1, undef                   ], #
  0x1028 => [ undef,               $SHORT,     1, undef                   ], #
  0x1029 => ['Contrast',           $SHORT,     1, undef                   ], #
  0x102a => ['SharpnessFactor',    $SHORT,     1, undef                   ], #
  0x102b => ['ColourControl',      $SHORT,     6, undef                   ], #
  0x102c => ['ValidBits',          $SHORT,     2, undef                   ], #
  0x102d => ['CoringFilter',       $SHORT,     1, undef                   ], #
  0x102e => ['FinalWidth',         $LONG,      1, undef                   ], #
  0x102f => ['FinalHeight',        $LONG,      1, undef                   ], #
  0x1030 => [ undef,               $SHORT,     1, undef                   ], #
  0x1031 => [ undef,               $LONG,      8, undef                   ], #
  0x1032 => [ undef,               $SHORT,     1, undef                   ], #
  0x1033 => [ undef,               $LONG,    720, undef                   ], #
  0x1034 => ['CompressionRatio',   $RATIONAL,  1, undef                   ], #
  0x1035 => [ undef,               $LONG,      1, undef                   ], #
  0x1036 => [ undef,               $LONG,      1, undef                   ], #
  0x1037 => [ undef,               $LONG,      1, undef                   ], #
  0x1038 => [ undef,               $SHORT,     1, undef                   ], #
  0x1039 => [ undef,               $SHORT,     1, undef                   ], #
  0x103a => [ undef,               $SHORT,     1, undef                   ], #
  0x103b => [ undef,               $SHORT,     1, undef                   ], #
  0x103c => [ undef,               $SHORT,     1, undef                ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Panasonic_1'}{'tags'} =                                   #
{ 0x0001 => ['ImageQuality',       $SHORT,     1, '[23]'                  ], #
  0x0002 => ['FirmwareVersion',    $UNDEF,     4, '010\d'                 ], #
  0x0003 => ['WhiteBalance',       $SHORT,     1, '[1-58]'                ], #
  0x0007 => ['FocusMode',          $SHORT,     1, '[12]'                  ], #
  0x000f => ['SpotMode',           $BYTE,      2, undef                   ], #
  0x001a => ['ImageStabilizer',    $SHORT,     1, '[2-4]'                 ], #
  0x001c => ['MacroMode',          $SHORT,     1, '[129]'                 ], #
  0x001f => ['ShootingMode',       $SHORT,     1, '([2-9]|1[1389]|2[01])' ], #
  0x0020 => ['Audio',              $SHORT,     1, '[12]'                  ], #
  0x0021 => [ undef,               $UNDEF, undef, undef                   ], #
  0x0022 => [ undef,               $SHORT,     1, undef                   ], #
  0x0023 => ['WhiteBalanceAdjust', $SHORT,     1, $IFD_integer            ], #
  0x0024 => ['FlashBias',          $SHORT,     1, $IFD_integer            ], #
  0x0025 => [ undef,               $UNDEF,    16, undef                   ], #
  0x0026 => [ undef,               $UNDEF,     4, '0100'                  ], #
  0x0027 => [ undef,               $SHORT,     1, undef                   ], #
  0x0028 => ['ColourEffect',       $SHORT,     1, '[1-5]'                 ], #
  0x0029 => [ undef,               $LONG,      1, undef                   ], #
  0x002a => [ undef,               $SHORT,     1, undef                   ], #
  0x002b => [ undef,               $LONG,      1, undef                   ], #
  0x002c => ['Contrast',           $SHORT,     1, '[012]'                 ], #
  0x002d => ['NoiseReduction',     $SHORT,     1, '[012]'                 ], #
  0x002e => [ undef,               $SHORT,     1, undef                   ], #
  0x002f => [ undef,               $SHORT,     1, undef                   ], #
  0x0e00 => ['PrintIM_Data',       $UNDEF, undef, undef                   ], # 
  0x4449 => [ undef,               $UNDEF,   512, undef                ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Pentax_1'}{'tags'} =                                      #
{ 0x0001 => ['CaptureMode',        $SHORT,     1, '[0-4]'                 ], #
  0x0002 => ['QualityLevel',       $SHORT,     1, '[0-2]'                 ], #
  0x0003 => ['FocusMode',          $SHORT,     1, '[23]'                  ], #
  0x0004 => ['FlashMode',          $SHORT,     1, '[1246]'                ], #
  0x0005 => [ undef,               $SHORT,     1, undef                   ], #
  0x0006 => [ undef,               $LONG,      1, undef                   ], #
  0x0007 => ['WhiteBalance',       $SHORT,     1, '[0-5]'                 ], #
  0x0008 => [ undef,               $SHORT,     1, undef                   ], #
  0x0009 => [ undef,               $SHORT,     1, undef                   ], #
  0x000a => ['DigitalZoom',        $LONG,      1, $IFD_integer            ], #
  0x000b => ['Sharpness',          $SHORT,     1, '[012]'                 ], #
  0x000c => ['Contrast',           $SHORT,     1, '[012]'                 ], #
  0x000d => ['Saturation',         $SHORT,     1, '[012]'                 ], #
  0x000e => [ undef,               $SHORT,     1, undef                   ], #
  0x000f => [ undef,               $LONG,      1, undef                   ], #
  0x0010 => [ undef,               $SHORT,     1, undef                   ], #
  0x0011 => [ undef,               $LONG,      1, undef                   ], #
  0x0012 => [ undef,               $SHORT,     1, undef                   ], #
  0x0013 => [ undef,               $SHORT,     1, undef                   ], #
  0x0014 => ['ISOSpeed',           $SHORT,     1, '(10|16|100|200)'       ], #
  0x0015 => [ undef,               $SHORT,     1, undef                   ], #
  0x0017 => ['Colour',             $SHORT,     1, '[123]'                 ], #
  0x0018 => [ undef,               $LONG,      1, undef                   ], #
  0x0019 => [ undef,               $SHORT,     1, undef                   ], #
  0x0e00 => ['PrintIM_Data',       $UNDEF, undef, undef                   ], # 
  0x1000 => ['TimeZone',           $UNDEF,     4, undef                   ], #
  0x1001 => ['DaylightSavings',    $UNDEF,     4, undef                ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Pentax_2'}{'tags'} =                                      #
{ 0x0001 => [ undef,               $SHORT,     1, undef                   ], #
  0x0002 => [ undef,               $SHORT,     1, undef                   ], #
  0x0003 => [ undef,               $LONG,      1, undef                   ], #
  0x0004 => [ undef,               $LONG,      1, undef                   ], #
  0x0005 => [ undef,               $LONG,      1, undef                   ], #
  0x0006 => [ undef,               $UNDEF,     4, undef                   ], #
  0x0007 => [ undef,               $UNDEF,     3, undef                   ], #
  0x0008 => [ undef,               $SHORT,     1, undef                   ], #
  0x0009 => [ undef,               $SHORT,     1, undef                   ], #
  0x000a => [ undef,               $SHORT,     1, undef                   ], #
  0x000b => [ undef,               $SHORT,     1, undef                   ], #
  0x000c => [ undef,               $SHORT,     1, undef                   ], #
  0x000d => [ undef,               $SHORT,     1, undef                   ], #
  0x000e => [ undef,               $SHORT,     1, undef                   ], #
  0x000f => [ undef,               $SHORT,     1, undef                   ], #
  0x0010 => [ undef,               $SHORT,     1, undef                   ], #
  0x0011 => [ undef,               $SHORT,     1, undef                   ], #
  0x0012 => [ undef,               $LONG,      1, undef                   ], #
  0x0013 => [ undef,               $SHORT,     1, undef                   ], #
  0x0014 => [ undef,               $SHORT,     1, undef                   ], #
  0x0015 => [ undef,               $SHORT,     1, undef                   ], #
  0x0016 => [ undef,               $SHORT,     1, undef                   ], #
  0x0017 => [ undef,               $SHORT,     1, undef                   ], #
  0x0018 => [ undef,               $SHORT,     1, undef                   ], #
  0x0019 => [ undef,               $SHORT,     1, undef                   ], #
  0x001a => [ undef,               $SHORT,     1, undef                   ], #
  0x001b => [ undef,               $SHORT,     1, undef                   ], #
  0x001c => [ undef,               $SHORT,     1, undef                   ], #
  0x001d => [ undef,               $LONG,      1, undef                   ], #
  0x001e => [ undef,               $SHORT,     1, undef                   ], #
  0x001f => [ undef,               $SHORT,     1, undef                   ], #
  0x0020 => [ undef,               $SHORT,     1, undef                   ], #
  0x0021 => [ undef,               $SHORT,     1, undef                   ], #
  0x0022 => [ undef,               $SHORT,     1, undef                   ], #
  0x0023 => [ undef,               $SHORT,     1, undef                   ], #
  0x0024 => [ undef,               $SHORT,     1, undef                   ], #
  0x0025 => [ undef,               $SHORT,     1, undef                   ], #
  0x0026 => [ undef,               $SHORT,     1, undef                   ], #
  0x0027 => [ undef,               $UNDEF,     4, undef                   ], #
  0x0028 => [ undef,               $UNDEF,     4, undef                   ], #
  0x0029 => [ undef,               $LONG,      1, undef                ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Ricoh_3'}{'tags'} =                                       #
{ 0x0001 => ['DataType',           $ASCII, undef, undef                   ], #
  0x0002 => ['FirmwareVersion',    $ASCII, undef, 'Rev\d{4}'              ], #
  0x0003 => [ undef,               $LONG,      4, undef                   ], #
  0x0005 => [ undef,               $UNDEF, undef, undef                   ], #
  0x0006 => [ undef,               $UNDEF, undef, undef                   ], #
  0x0e00 => ['PrintIM_Data',       $UNDEF, undef, undef                   ], # 
  0x1001 => [ undef,               $UNDEF, undef, undef                   ], #
  0x1002 => [ undef,               $LONG,      1, undef                   ], #
  0x1003 => [ undef,               $LONG,      1, undef                   ], #
  0x2001 => ['CameraInfoIFD',      $UNDEF, undef,'\[Ricoh Camera Info\].*'] };
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Sanyo'}{'tags'} =                                         #
{ 0x0100 => ['JPEGThumbnail',      $UNDEF, undef, '\377\330\377.*'        ], #
  0x0200 => ['SpecialMode',        $LONG,      3, $IFD_integer            ], #
  0x0201 => ['JPEGQuality',        $SHORT,     1, '[\000-\007][\000-\002]'], #
  0x0202 => ['Macro',              $SHORT,     1, '[0-3]'                 ], #
  0x0203 => [ undef,               $SHORT,     1, '[0]'                   ], #
  0x0204 => ['DigitalZoom',        $RATIONAL,  1, $IFD_integer            ], #
  0x0207 => ['SoftwareRelease',    $ASCII, undef, $IFD_Cstring            ], #
  0x0208 => ['PictInfo',           $ASCII, undef, '[\040-\176]*'          ], #
  0x0209 => ['CameraID',           $UNDEF,    32, '.*'                    ], #
  0x020e => ['SequentShotMethod',  $SHORT,     1, '[0-3]'                 ], #
  0x020f => ['WideRange',          $SHORT,     1, '[01]'                  ], #
  0x0210 => ['ColourAdjustMode',   $SHORT,     1, $IFD_integer            ], #
  0x0213 => ['QuickShot',          $SHORT,     1, '[01]'                  ], #
  0x0214 => ['SelfTimer',          $SHORT,     1, '[01]'                  ], #
  0x0216 => ['VoiceMemo',          $SHORT,     1, '[01]'                  ], #
  0x0217 => ['RecShutterRelease',  $SHORT,     1, '[01]'                  ], #
  0x0218 => ['FlickerReduce',      $SHORT,     1, '[01]'                  ], #
  0x0219 => ['OpticalZoom',        $SHORT,     1, '[01]'                  ], #
  0x021b => ['DigitalZoom',        $SHORT,     1, '[01]'                  ], #
  0x021d => ['LightSourceSpecial', $SHORT,     1, '[01]'                  ], #
  0x021e => ['Resaved',            $SHORT,     1, '[01]'                  ], #
  0x021f => ['SceneSelect',        $SHORT,     1, '[0-5]'                 ], #
  0x0223 => ['ManualFocalDistance',$RATIONAL,  1, $IFD_integer            ], #
  0x0224 => ['SequentShotInterval',$SHORT,     1, '[0-3]'                 ], #
  0x0225 => ['FlashMode',          $SHORT,     1, '[0-3]'                 ], #
  0x0e00 => ['PrintIM_Data',       $UNDEF, undef, undef                   ], #
  0x0f00 => ['DataDump',           $LONG,  undef, undef                ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Sigma'}{'tags'} =                                         #
{ 0x0002 => ['CameraSerialNumber', $ASCII, undef, '\d*'                   ], #
  0x0003 => ['DriveMode',          $ASCII, undef, '(SINGLE|Burst)\000'    ], #
  0x0004 => ['ResolutionMode',     $ASCII, undef, '(HI|MED|LO)\000'       ], #
  0x0005 => ['AutofocusMode',      $ASCII, undef, '(AF-S|AF-C)\000'       ], #
  0x0006 => ['FocusSetting',       $ASCII, undef, '(AF|M)\000'            ], #
  0x0007 => ['WhiteBalance',       $ASCII, undef, '(Auto|Sunlight)\000'   ], #
  0x0008 => ['ExposureMode',       $ASCII,     2, '(P|A|S|M)\000'         ], #
  0x0009 => ['MeteringMode',       $ASCII,     2, '(A|C|8)\000'           ], #
  0x000a => ['FocalLengthRange',   $ASCII, undef, $IFD_Cstring            ], #
  0x000b => ['ColorSpace',         $ASCII, undef, '(sRGB)\000'            ], #
  0x000c => ['Exposure',           $ASCII,    10, 'Expo:[+-]0.\d\000'     ], #
  0x000d => ['Contrast',           $ASCII,    10, 'Cont:[+-]0.\d\000'     ], #
  0x000e => ['Shadow',             $ASCII,    10, 'Shad:[+-]0.\d\000'     ], #
  0x000f => ['Highlight',          $ASCII,    10, 'High:[+-]0.\d\000'     ], #
  0x0010 => ['Saturation',         $ASCII,    10, 'Satu:[+-]0.\d\000'     ], #
  0x0011 => ['Sharpness',          $ASCII,    10, 'Shar:[+-]0.\d\000'     ], #
  0x0012 => ['X3FillLight',        $ASCII,    10, 'Fill:[+-]0.\d\000'     ], #
  0x0014 => ['ColorAdjustment',    $ASCII,     9, 'CC:\d.[+-]\d.\000'     ], #
  0x0015 => ['AdjustmentMode',     $ASCII, undef, '(Custom|Auto) Se.*\000'], #
  0x0016 => ['Quality',            $ASCII, undef, 'Qual:\d\d\000'         ], #
  0x0017 => ['Firmware',           $ASCII, undef, '[\d\.]* Release\000'   ], #
  0x0018 => ['Software',           $ASCII, undef, 'SIGMA .* [\d\.]*\000'  ], #
  0x0019 => ['AutoBracket',        $ASCII, undef, $IFD_Cstring         ], }; #
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Sony'}{'tags'} =                                          #
{ 0x0e00 => ['PrintIM_Data',       $UNDEF, undef, undef                 ],}; # 
#----------------------------------------------------------------------------#
$$HASH_MAKERNOTES{'Foveon'}{'tags'} = $$HASH_MAKERNOTES{'Sigma'}{'tags'};    #
#----------------------------------------------------------------------------#
$$HASH_APP1_SUBIFD{'MakerNote_' . $_} =                                      #
    generate_lookup($$HASH_MAKERNOTES{$_}{tags} ,0)                          #
    for keys %$HASH_MAKERNOTES;                                              #
#============================================================================#
#============================================================================#
#============================================================================#
# The following hash is the database for the tag-to-tagname translation; of  #
# course, records with a textual tag are not listed here. The navigation     #
# through this structure is best done with the help of the JPEG_lookup       #
# function, so this hash is not exported (as it was some time ago).          #
#----------------------------------------------------------------------------#
my $JPEG_RECORD_NAME =                                                       #
{APP1  => {%$HASH_APP1_ROOT,                                   # APP1 root   #
	   IFD0                     => $HASH_APP1_IFD,         # main image  #
	   IFD1                     => $HASH_APP1_IFD, },      # thumbnail   #
 APP2  => {TagTable                 => $HASH_APP2_ICC, },      # ICC data    #
 APP3  => {IFD0                     => $HASH_APP3_IFD, },      # main image  #
 APP13 => {$APP13_IPTC_DIRNAME      => $HASH_IPTC_TAGS,        # PS:IPTC     #
	   $APP13_PHOTOSHOP_DIRNAME => $HASH_PHOTOSHOP_TAGS,   # PS:non-IPTC #
	   '__syntax_IPTC'          => $HASH_IPTC_GENERAL },}; # PS:IPTC syn #
#----------------------------------------------------------------------------#


###########################################################
# This helper function returns record data from the       #
# %$JPEG_RECORD_NAME hash. The arguments are first joined #
# with the '@' character, and then splitted on the same   #
# character to give a list of '@'-free strings (this al-  #
# lows for greater flexibility at call time); this list   #
# contains keys for exploring the %$JPEG_RECORD_NAME hash;#
# e.g., the arguments ('APP1', 'IFD0@GPS', 0x1e) select   #
# $JPEG_RECORD_NAME{APP1}{IFD0}{GPS}{0x1e}, i.e. the      #
# textual name of the GPS record with key = 0x1e in the   #
# IFD0 in the APP1 segment. If, at some point during the  #
# search, an argument fails (it is not a valid key) or it #
# is not defined, the search is interrupted, and undef is #
# returned. Note also that the return value could be a    #
# string as well as a hash reference, depending on the    #
# search depth. If the key lookup for the last argument   #
# fails, a reverse lookup is run (i.e., the key corres-   #
# ponding to the value equal to the last user argument is #
# searched). If even this lookup fails, undef is returned.#
########################################################### 
sub JPEG_lookup {
    # all searches start from here
    my $lookup = $JPEG_RECORD_NAME;
    # print a debugging message and return immediately unless
    # all arguments are scalars (i.e., references are not allowed)
    for (@_) { print "wrong argument(s) in JPEG_lookup call", return if ref; }
    # join all arguments with '@'
    my $keystring = join('@', @_);
    # split the resulting string on '@'
    my @keylist = split('@', $keystring);
    # extract and save the last argument for special treatment
    my $last = pop @keylist;
    # refuse to work with $last undefined
    return unless defined $last;
    # consume the list of "normal" arguments: they must be successive
    # keys for navigation in a multi-level hash. Interrupt the search
    # as soon as an argument is undefined or $lookup is not a hash ref
    for (@keylist) {
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

#============================================================================#
#============================================================================#
#============================================================================#
# This hash is needed to overcome some complications due to the APP1/APP3    #
# structure: some IFDs or sub-IFDs can contain offset tags (tags whose value #
# is an offset in the JPEG file), linking to nested structures, which are    #
# represented internally as sub-lists pointed to by $REFERENCE records; the  #
# sub-lists deserve in general a more significant name than the offset tag   #
# name. Each key in the following hash is a path to an IFD or one of its     #
# subdirectories; the corresponding value is a hash reference, with the      #
# pointed hash mapping offset tag numerical values to subdirectory names.    #
# (the [tag names] -> [tag numerical values] translation is done afterwards) #
#----------------------------------------------------------------------------#
# A sub hash must also own the '__syntax' and '__mandatory' keys, returning  #
# a reference to a hash of syntactical properties to be respected by data in #
# the corresponding IFD and a reference to a hash of mandatory records.      #
# These special entries are of course treated differently from the others ...#
#----------------------------------------------------------------------------#
# When the JPEG file is read, offset tag records are not stored; insted, we  #
# store a $REFERENCE record with the mapped name (and the name of the origi- #
# nating offset tag saved in the "extra" field). The following hash can then #
# be used in both directions to do data parsing/dumping.                     #
#----------------------------------------------------------------------------#
our %IFD_SUBDIRS =                                                           #
('APP1'             => {'__syntax'           => $HASH_APP1_ROOT_GENERAL,     #
			'__mandatory'        => $HASH_APP1_ROOT_MANDATORY }, #
 'APP1@IFD0'        => {'__syntax'           => $HASH_APP1_IFD01_GENERAL,    #
			'__mandatory'        => $HASH_APP1_IFD0_MANDATORY,   #
			'GPSInfo'            => 'GPS',                       #
			'ExifOffset'         => 'SubIFD'},                   #
 'APP1@IFD0@GPS'    => {'__syntax'           => $HASH_GPS_GENERAL,           #
			'__mandatory'        => $HASH_GPS_MANDATORY },       #
 'APP1@IFD0@SubIFD' => {'__syntax'           => $HASH_APP1_SUBIFD_GENERAL,   #
			'__mandatory'        => $HASH_APP1_SUBIFD_MANDATORY, #
			'InteroperabilityOffset' => 'Interop'},              #
 'APP1@IFD0@SubIFD@Interop' => {'__syntax'   => $HASH_INTEROP_GENERAL,       #
				'__mandatory'=> $HASH_INTEROP_MANDATORY },   #
 'APP1@IFD1'        => {'__syntax'           => $HASH_APP1_IFD01_GENERAL,    #
			'__mandatory'        => $HASH_APP1_IFD1_MANDATORY }, #
 'APP3@IFD0'        => {'BordersIFD'         => 'Borders',                   #
			'SpecialEffectsIFD'  => 'Special'}, );               #
#----------------------------------------------------------------------------#
while (my ($ifd_path, $ifd_hash) = each %IFD_SUBDIRS) {                      #
    my %h = map { $_ =~ /__syntax|__mandatory/ ? ($_ => $$ifd_hash{$_}) :    #
		      (JPEG_lookup($ifd_path, $_) => $$ifd_hash{$_})         #
		  } keys %$ifd_hash;                                         #
    $IFD_SUBDIRS{$ifd_path} = \ %h; }                                        #
#============================================================================#
#============================================================================#
#============================================================================#
# These parameters must be initialised with JPEG_lookup, because I don't     #
# want to have them written explicitely in more than one place.              #
#----------------------------------------------------------------------------#
our $APP1_TH_TYPE  = JPEG_lookup('APP1@IFD1@Compression');                   #
our $THJPEG_OFFSET = JPEG_lookup('APP1@IFD1@JPEGInterchangeFormat');         #
our $THJPEG_LENGTH = JPEG_lookup('APP1@IFD1@JPEGInterchangeFormatLength');   #
our $THTIFF_OFFSET = JPEG_lookup('APP1@IFD1@StripOffsets');                  #
our $THTIFF_LENGTH = JPEG_lookup('APP1@IFD1@StripByteCounts');               #
#----------------------------------------------------------------------------#



# successful package load
1;
