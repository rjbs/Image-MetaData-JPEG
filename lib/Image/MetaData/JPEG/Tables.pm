###########################################################
# A Perl package for showing/modifying JPEG (meta)data.   #
# Copyright (C) 2004 Stefano Bettelli                     #
# See the COPYING and LICENSE files for license terms.    #
###########################################################
package Image::MetaData::JPEG::Tables;
require Exporter;
no integer;
@ISA = qw(Exporter);
@EXPORT = qw($JPEG_PUNCTUATION %JPEG_MARKER $BIG_ENDIAN $LITTLE_ENDIAN
	     @JPEG_RECORD_TYPE_NAME $NIBBLES $BYTE $ASCII
	     $SHORT $LONG $RATIONAL $SBYTE $UNDEF $SSHORT
	     $SLONG $SRATIONAL $FLOAT $DOUBLE $REFERENCE
	     $APP0_JFIF_TAG $APP0_JFXX_TAG $APP0_JFXX_JPG
	     $APP0_JFXX_1B $APP0_JFXX_3B $APP0_JFXX_PAL %IFD_SUBDIRS
	     $APP1_EXIF_TAG $APP1_XMP_TAG $APP1_TIFF_SIG $APP1_TH_JPEG
	     $APP2_FPXR_TAG $APP2_ICC_TAG $APP3_EXIF_TAG $APP1_TH_TYPE
	     $APP1_TH_TIFF $APP1_THTIFF_OFFSET $APP1_THTIFF_LENGTH
	     $APP1_THJPEG_OFFSET $APP1_THJPEG_LENGTH $APP1_IFD1_THUMB_LENGTH 
	     $APP13_PHOTOSHOP_IPTC $APP13_PHOTOSHOP_IDENTIFIER
	     $APP13_PHOTOSHOP_TYPE $APP13_IPTC_TAGMARKER
	     $APP14_PHOTOSHOP_IDENTIFIER
	     %JPEG_RECORD_NAME %HASH_IPTC_GENERAL
	     );

# this constant is prefixed to every JPEG marker
$JPEG_PUNCTUATION = 0xff;

# non-repetitive JPEG markers
%JPEG_MARKER = 
    (TEM => 0x01, # for TEMporary private use in arithmetic coding
     DHT => 0xc4, # Define Huffman Table(s)
     JPG => 0xc8, # reserved for JPEG extensions
     DAC => 0xcc, # Define Arithmetic Coding Conditioning(s)
     SOI => 0xd8, # Start Of Image
     EOI => 0xd9, # End Of Image
     SOS => 0xda, # Start Of Scan
     DQT => 0xdb, # Define Quantization Table(s)
     DNL => 0xdc, # Define Number of Lines
     DRI => 0xdd, # Define Restart Interval
     DHP => 0xde, # Define Hierarchical Progression
     EXP => 0xdf, # EXPand reference component(s)
     COM => 0xfe, # COMment block
     );

# markers 0x02 --> 0xbf are REServed for future uses
for (0x02..0xbf) { $JPEG_MARKER{sprintf "res%02x", $_} = $_; }
# some markers in 0xc0 --> 0xcf correspond to Start-Of-Frame typologies
for (0xc0..0xc3, 0xc5..0xc7, 0xc9..0xcb, 
     0xcd..0xcf) { $JPEG_MARKER{sprintf "SOF_%d", $_ - 0xc0} = $_; }
# markers 0xd0 --> 0xd7 correspond to ReSTart with module 8 count
for (0xd0..0xd7) { $JPEG_MARKER{sprintf "RST%d", $_ - 0xd0} = $_; }
# markers 0xe0 --> 0xef are the APPlication markers
for (0xe0..0xef) { $JPEG_MARKER{sprintf "APP%d", $_ - 0xe0} = $_; }
# markers 0xf0 --> 0xfd are reserved for JPEG extensions
for (0xf0..0xfd) { $JPEG_MARKER{sprintf "JPG%d", $_ - 0xf0} = $_; }

# symbolic constants for the record type names
@JPEG_RECORD_TYPE_NAME = qw(NIBBLES   BYTE  ASCII  SHORT   LONG
			    RATIONAL  SBYTE UNDEF  SSHORT  SLONG
			    SRATIONAL FLOAT DOUBLE REFERENCE);
sub enum { for my $j (0..$#_) { ${$_[$j]} = $j; } }
&enum(@JPEG_RECORD_TYPE_NAME);

# various interesting constants --------------------
$BIG_ENDIAN			= 'MM';
$LITTLE_ENDIAN			= 'II';
$APP0_JFIF_TAG			= "JFIF\000";
$APP0_JFXX_TAG			= "JFXX\000";
$APP0_JFXX_JPG			= 0x10;
$APP0_JFXX_1B			= 0x11;
$APP0_JFXX_3B			= 0x13;
$APP0_JFXX_PAL			= 768;
$APP3_EXIF_TAG			= "Meta\000\000";
$APP2_FPXR_TAG			= "FPXR\000";
$APP1_EXIF_TAG			= "Exif\000\000";
$APP2_ICC_TAG			= "ICC_PROFILE\000";
$APP1_XMP_TAG			= "http://ns.adobe.com/xap/1.0/\000";
$APP1_TIFF_SIG			= 42;
$APP1_TH_TYPE			= 0x0103;
$APP1_TH_TIFF			= 1;
$APP1_TH_JPEG			= 6;
$APP1_THTIFF_OFFSET		= 0x0111;
$APP1_THTIFF_LENGTH		= 0x0117;
$APP1_THJPEG_OFFSET		= 0x0201;
$APP1_THJPEG_LENGTH		= 0x0202;
$JPG_TH				= 'JPEGInterchangeFormat';
$APP3_IFD0_SPECIAL_TAG		= 0xc36e;
$APP3_IFD0_BORDERS_TAG		= 0xc36f;
$APP1_IFD0_SUBIFD_TAG		= 0x8769;
$APP1_IFD0_GPSINFO_TAG		= 0x8825;
$APP1_SubIFD_MAKERNOTE		= 0x927c;
$APP1_SubIFD_INTEROP_TAG	= 0xa005;
$APP13_PHOTOSHOP_IDENTIFIER	= "Photoshop 3.0\000";
$APP13_PHOTOSHOP_TYPE		= '8BIM';
$APP13_PHOTOSHOP_IPTC		= 0x0404;
$APP13_IPTC_TAGMARKER		= 0x1c;
$APP14_PHOTOSHOP_IDENTIFIER	= 'Adobe';

# complications due to APP1 structure
%IFD_SUBDIRS =
    ($APP1_IFD0_GPSINFO_TAG   => 'IFD0@GPS',
     $APP1_IFD0_SUBIFD_TAG    => 'IFD0@SubIFD',
     $APP1_SubIFD_INTEROP_TAG => 'IFD0@SubIFD@Interop',
#     $APP1_SubIFD_MAKERNOTE   => 'IFD0@SubIFD@MakerNote',
     $APP3_IFD0_SPECIAL_TAG   => 'IFD0@Special',
     $APP3_IFD0_BORDERS_TAG   => 'IFD0@Borders',
     );

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
%HASH_APP1_IFD =
    (0x00fe => 'NewSubfileType',              # 0
     0x00ff => 'SubFileType',                 # 0
     0x0100 => 'ImageWidth',                  # A (JPEG marker)
     0x0101 => 'ImageLength',                 # A (JPEG marker)
     0x0102 => 'BitsPerSample',               # A (JPEG marker)
     $APP1_TH_TYPE => 'Compression',          # A (JPEG marker)  mandatory
     0x0106 => 'PhotometricInterpretation',   # A (not JPEG)
     0x0107 => 'Thresholding',                # 0
     0x0108 => 'CellWidth',                   # 0
     0x0109 => 'CellLength',                  # 0 
     0x010a => 'FillOrder',                   # 0
     0x010d => 'DocumentName',                # 2
     0x010e => 'ImageDescription',            # C recommended    optional
     0x010f => 'Make',                        # C recommended    optional
     0x0110 => 'Model',                       # C recommended    optional
     $APP1_THTIFF_OFFSET => 'StripOffsets',   # B (not JPEG)
     0x0112 => 'Orientation',                 # A recommended
     0x0115 => 'SamplesPerPixel',             # A (JPEG marker)
     0x0116 => 'RowsPerStrip',                # B (not JPEG)
     $APP1_THTIFF_LENGTH => 'StripByteCounts',# B (not JPEG)
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
     $APP1_THJPEG_OFFSET => $JPG_TH,          # B (not JPEG)     mandatory
     $APP1_THJPEG_LENGTH => "${JPG_TH}Length",# B (not JPEG)     mandatory
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
     $APP1_IFD0_SUBIFD_TAG => 'ExifOffset',   # D mandatory     optional(?)
     0x8773 => 'ICC_Profile',                 # x [Adobe ?]
     0x87be => 'JBIG_Options',                # x [Pixel Magic]
     $APP1_IFD0_GPSINFO_TAG => 'GPSInfo',     # D optional              (?)
     0x885c => 'FaxRecvParams',               # x [SGI]
     0x885d => 'FaxSubAddress',               # x [SGI]
     0x885e => 'FaxRecvTime',                 # x [SGI]
     0x8871 => 'FedExEDR',                    # x [FedEx]
     0x923f => 'StoNits',                     # x [SGI]
     0xc4a5 => 'PrintIM_Data',                # Epson PIM tag (ref. ?)
     0xffff => 'DCS_HueShiftValues',          # x [Eastman Kodak]
     SubIFD => \%HASH_APP1_SUBIFD,            # Exif private tags
     GPS    => \%HASH_APP1_GPS,               # GPS tags
     );

# Tags used for ICC data in APP2 (they are 4 bytes strings, so
# I prefer to write the string and then convert it).
sub str2hex { my $z = 0; ($z *= 256) += $_ for unpack "CCCC", $_[0]; $z; }
%HASH_APP2_ICC =
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
%HASH_APP3_IFD =
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
     $APP3_IFD0_SPECIAL_TAG => 'SpecialEffectsIFD', # pointer to an IFD
     $APP3_IFD0_BORDERS_TAG => 'BordersIFD',        # pointer to an IFD
     Special => \%HASH_APP3_SPECIAL,                # Special effect tags
     Borders => \%HASH_APP3_BORDERS,                # Border tags
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
%HASH_APP1_SUBIFD =
    (#0x00ff => '?? SubfileType', # 2nd and/or 3rd subfile for RichTIFF
     #0x010d => '?? DocumentName',
     #0x010f => '?? Make',
     #0x0110 => '?? Model',
     #0x0131 => '?? Software',
     #0x013b => '?? Artist',
     #0x013d => '?? Predictor',
     #0x0142 => '?? TileWidth',
     #0x0143 => '?? TileLength',
     #0x0144 => '?? TileOffsets',
     #0x0145 => '?? TileByteCounts',
     #0x014a => '?? SubIFDs',
     #0x015b => '?? JPEGTables',
     0x828d => 'CFARepeatPatternDim',         # unknown (Image::TIFF)
     0x828e => 'CFAPattern',                  # unknown (Image::TIFF)
     0x828f => 'BatteryLevel',                # unknown (Image::TIFF)
     #0x8290 => '?? CameraInfoIFD', # pointer to an IFD
     0x829a => 'ExposureTime',                # g recommended
     0x829d => 'FNumber',                     # g optional
     #0x8568 => '?? IPTC/NAA', # Kodak
     0x8822 => 'ExposureProgram',             # g optional
     0x8824 => 'SpectralSensitivity',         # g optional
     0x8827 => 'ISOSpeedRatings',             # g optional
     0x8828 => 'OECF',                        # g optional
     #0x8829 => '?? Interlace',
     #0x882a => '?? TimeZoneOffset',
     #0x882b => '?? SelfTimerMode',
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
     #0x920d => '?? Noise',
     #0x9211 => '?? ImageNumber',
     #0x9212 => '?? SecurityClassification',
     #0x9213 => '?? ImageHistory',
     0x9214 => 'SubjectArea',                 # g optional
     #0x9216 => '?? TIFF/EPStandardID',
     $APP1_SubIFD_MAKERNOTE => 'MakerNote',   # d optional
     0x9286 => 'UserComment',                 # d optional
     0x9290 => 'SubSecTime',                  # f optional
     0x9291 => 'SubSecTimeOriginal',          # f optional
     0x9292 => 'SubSecTimeDigitized',         # f optional
     0xa000 => 'FlashPixVersion',             # a mandatory
     0xa001 => 'ColorSpace',                  # b mandatory
     0xa002 => 'PixelXDimension',             # c mandatory
     0xa003 => 'PixelYDimension',             # c mandatory
     0xa004 => 'RelatedSoundFile',            # e optional
     $APP1_SubIFD_INTEROP_TAG => 
               'InteroperabilityOffset',      # D optional
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
     Interop => \%HASH_APP1_INTEROP,          # Interoperability tags
     MakerNote_OLYMPUS => \%HASH_APP1_MKN_OLYMPUS,
     );

# Tags to be used in the Interoperability IFD (optional)
%HASH_APP1_INTEROP =
    (0x0001 => 'InteroperabilityIndex',       # "R98"(main)or "THM"(thumb.)
     0x0002 => 'InteroperabilityVersion',     # "0100" means 1.00
     0x1000 => 'RelatedImageFileFormat',      # e.g. "Exif JPEG Ver. 2.1"
     0x1001 => 'RelatedImageWidth',           # image X dimension
     0x1002 => 'RelatedImageLength',          # image Y dimension
     );

# Special tags for OLYMPUS Maker Notes.
%HASH_APP1_MKN_OLYMPUS =
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

# Tags used for GPS attributes
%HASH_APP1_GPS =
    (0x00 => 'Versionid',
     0x01 => 'LatitudeRef',
     0x02 => 'Latitude',
     0x03 => 'LongitudeRef',
     0x04 => 'Longitude',
     0x05 => 'AltitudeRef',
     0x06 => 'Altitude',
     0x07 => 'TimeStamp',
     0x08 => 'Satellites',
     0x09 => 'Status',
     0x0a => 'MeasureMode',
     0x0b => 'DOP',
     0x0c => 'SpeedRef',
     0x0d => 'Speed',
     0x0e => 'TrackRef',
     0x0f => 'Track',
     0x10 => 'ImgDirectionRef',
     0x11 => 'ImgDirection',
     0x12 => 'MapDatum',
     0x13 => 'DestLatitudeRef',
     0x14 => 'DestLatitude',
     0x15 => 'DestLongitudeRef',
     0x16 => 'DestLongitude',
     0x17 => 'DestBearingRef',
     0x18 => 'DestBearing',
     0x19 => 'DestDistanceRef',
     0x1a => 'DestDistance',
     0x1b => 'ProcessingMethod',
     0x1c => 'AreaInformation',
     0x1d => 'DateStamp',
     0x1e => 'Differential',
     );

%HASH_APP3_SPECIAL =
    (0x0000 => 'Unknown 0',
     0x0001 => 'Unknown 1',
     0x0002 => 'Unknown 2',
     );

%HASH_APP3_BORDERS =
    (0x0000 => 'Unknown 0',
     0x0001 => 'Unknown 1',
     0x0002 => 'Unknown 2',
     0x0003 => 'Unknown 3',
     0x0004 => 'Unknown 4',
     0x0008 => 'Unknown 8',
     );

# This hash specifies a lot of data about IPTC tags in JPEG files.
# Hash keys are numeric tags, here written in decimal base. Fields:
# 0 -> Tag name, 1 -> repeatability ('N' means non-repeatable)
# 2,3 -> min and max length in bytes, 4 -> regular expression to match
my $IPTC_re_word = '[^\000-\040\177]*';
my $IPTC_re_line = '[^\000-\037\177]*'; # words + spaces
my $IPTC_re_para = '[^\000-\011\013\014\016-\037\177]*'; # line + CR + LF
my $IPTC_re_date = '[0-2]\d\d\d(0\d|1[0-2])([0-2]\d|3[01])'; # CCYYMMDD
my $IPTC_re_HHMM = '([01]\d|2[0-3])[0-5]\d'; # HHMM
my $IPTC_re_dura = $IPTC_re_HHMM.'[0-5]\d'; # HHMMSS
my $IPTC_re_time = $IPTC_re_dura.'[\+-]'.$IPTC_re_HHMM; # HHMMSS+/-HHMM
my $vchar        = '\040-\051\053-\071\073-\076\100-\176';
my $IPTC_re_sure ='['.$vchar.']{1,32}?:[01]\d{7}?(:['.$vchar.'\s]{0,64}?){3}?';
%HASH_IPTC_GENERAL =
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
     #231 => '??? SummaryString',
     #232 => '??? EXIF_Info',
     #240 => '??? Unknown',
     );

# This record contains datasets (2:xx) with editorial information
%HASH_IPTC_RECORD_2 = map { my $arrayref = $HASH_IPTC_GENERAL{$_};
			    $_ => $$arrayref[0] } keys %HASH_IPTC_GENERAL;

# esoteric tags for a Photoshop APP13 segment (not IPTC data)
%HASH_PHOTOSHOP_TAGS =
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
     #0x0425 => '.. ????',
     #0x0426 => '.. ????',
     #0x0428 => '.. ????',
     0x0bb7 => 'ClippingPathName',
     0x2710 => 'PrintFlagsInfo',
     );
# tags 0x07d0 --> 0x0bb6 are reserved for path information
for (0x07d0..0x0bb6) { $HASH_PHOTOSHOP_TAGS{sprintf "PathInfo_%3x", $_} = $_; }

# this is the main database for tag --> tagname translation
# (records with a textual tag are not listed here)
%JPEG_RECORD_NAME = 
    (APP1  => {IFD0           => \%HASH_APP1_IFD,    # main image
	       IFD1           => \%HASH_APP1_IFD, }, # thumbnail
     APP2  => {TagTable       => \%HASH_APP2_ICC, }, # ICC data
     APP3  => {IFD0           => \%HASH_APP3_IFD, }, # main image
     APP13 => {IPTC_RECORD_2  => \%HASH_IPTC_RECORD_2,
	       %HASH_PHOTOSHOP_TAGS },
     );

# successful package load
1;
