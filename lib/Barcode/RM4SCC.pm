package Barcode::RM4SCC;
use strict;

use constant DEFAULT_QUIET => 8;
# From examining real barcodes the bars seem to be 1 unit wide,
# followed by 1 unit of space. The track is 2 units high. The ascender
# is 4 to 4.5 units high and the descender is 4 units high.
# To get whole numbers and to make the image a more sensible size I use 2 pixels for 1 unit
use constant H_ASCENDER => 9;
use constant H_TRACK => 4;
use constant H_DESCENDER => 8;
use constant W_BAR => 2;

use vars qw($VERSION %CHARSET %CODEDCHARSET $START $STOP %BITLUT @CHECKLUT);
($VERSION) = ('$Revision: 1.5 $' =~ /([\d\.]+)/ );

# the character-to-symbol mapping in a relatively readable form
%CHARSET = (
	"0" => "--||",
	"1" => "-.'|",
	"2" => "-.|'",
	"3" => ".-'|",
	"4" => ".-|'",
	"5" => "..''",
	"6" => "-'.|",
	"7" => "-|-|",
	"8" => "-|.'",
	"9" => ".'-|",
	"A" => ".'.'",
	"B" => ".|-'",
	"C" => "-'|.",
	"D" => "-|'.",
	"E" => "-||-",
	"F" => ".''.",
	"G" => ".'|-",
	"H" => ".|'-",
	"I" => "'-.|",
	"J" => "'.-|",
	"K" => "'..'",
	"L" => "|--|",
	"M" => "|-.'",
	"N" => "|.-'",
	"O" => "'-|.",
	"P" => "'.'.",
	"Q" => "'.|-",
	"R" => "|-'.",
	"S" => "|-|-",
	"T" => "|.'-",
	"U" => "''..",
	"V" => "'|-.",
	"W" => "'|.-",
	"X" => "|'-.",
	"Y" => "|'.-",
	"Z" => "||--",
);

# other static data
$START = "'";
$STOP = "|";
%BITLUT = (
	"-" => 0,
	"." => 1,
	"'" => 2,
	"|" => 3,
);
@CHECKLUT = (
	[ qw(Z U V W X Y) ],
	[ qw(5 0 1 2 3 4) ],
	[ qw(B 6 7 8 9 A) ],
	[ qw(H C D E F G) ],
	[ qw(N I J K L M) ],
	[ qw(T O P Q R S) ],
);


_initialize();

### PUBLIC INTERFACE #####################################

sub new {
	my ($class, %options) = @_;
	
	my $str = $options{'String'};
	die "You must supply a string to make the barcode from using the 'String' constructor option" unless (defined($str) && length($str));
	my $cleanstr = _sanitize($str);
	die "The supplied string '$str' contained no allowable characters" unless (defined($cleanstr) && length($cleanstr));
	my $self = {
		string => $str,
		cleanstring => $cleanstr,
		checkchar => _checksum($cleanstr),
		nochecksum => ($options{'NoChecksum'} || 0),
		nostartbit => ($options{'NoStartbit'} || 0),
		nostopbit => ($options{'NoStopbit'} || 0),
	};
	DUMP($self);
	return bless $self, $class;
}

sub barcode {
	my $self = shift;
	my $pattern = '';
	unless ($self->{'nostartbit'}) { $pattern .= $BITLUT{$START}; }
	foreach my $c (split '', $self->{'cleanstring'}) {
		my $bars = $CODEDCHARSET{$c} || die "Internal Error: Cannot find symbol for character '$c'";
		$pattern .= join('', @$bars);
	}
	unless ($self->{'nochecksum'}) {
		my $bars = $CODEDCHARSET{$self->{'checkchar'}} || die "Internal Error: Cannot find symbol for character '$self->{'checkchar'}'";
		$pattern .= join('', @$bars);
	}
	unless ($self->{'nostopbit'}) { $pattern .= $BITLUT{$STOP}; }
	
	return $pattern;
}

sub plot {	
	my ($self, %options) = @_;

	eval {
		require GD;
		import GD;
	};
	if ($@) {
		my $err = $@;
		$err =~ s/[\r\n]/ /g;
		die "Cannot plot() barcodes: Unable to load the GD graphics library: $err\n";
	}

	my $pattern = $self->barcode;
	my $nbars = length($pattern);
	my $quiet = DEFAULT_QUIET;
	if (defined $options{'QuietZone'}) {
		$quiet = $options{'QuietZone'};
	}
	my $main_w = 2 * W_BAR * $nbars;
	my $main_h = H_ASCENDER + H_TRACK + H_DESCENDER + ($options{'WithText'} ? 14 : 0);
	
	my $gd = GD::Image->new(2*$quiet+$main_w, 2*$quiet+$main_h);
	my $bgcolourdef = $options{'BGColour'} || [255, 255, 255];
	my $fgcolourdef = $options{'BarColour'} || [0, 0, 0];
	
	my $bg_col = $gd->colorAllocate( @$bgcolourdef );
	my $fg_col = $gd->colorAllocate( @$fgcolourdef );
	if ($options{'BGTransparent'}) {
		$gd->transparent($bg_col);
	}

	for my $i (0..$nbars-1) {
		my $x = $quiet + ($i * 2 * W_BAR);
		my $bar = substr($pattern, $i, 1);
		my ($top, $bottom) = (0, 0);
		if ($bar & 1) {
			$bottom = H_ASCENDER + H_TRACK + H_DESCENDER - 1; # remove 1 because pixel numbering is zero-based
		} else {
			$bottom = H_ASCENDER + H_TRACK - 1;
		}
		if ($bar & 2) {
			$top = 0;
		} else {
			$top = H_ASCENDER;
		}
		$gd->filledRectangle($x, $quiet+$top, $x+W_BAR-1, $quiet+$bottom, $fg_col);
	}
	
	if ($options{'WithText'}) {
		$gd->string(gdSmallFont(), $quiet, 2*$quiet+H_ASCENDER+H_TRACK+H_DESCENDER, $self->{'cleanstring'}, $fg_col);
	}
	
	return $gd;
}

### PRIVATE ROUTINES #####################################

# given a string of data, strip out anything not in the character set and correct case
sub _sanitize {
	my $str = uc(shift);
	my $set = join '', keys %CHARSET;
	$str =~ s/[^$set]//g;
	return $str;
}

# given a string of data, return the check character
sub _checksum {
	my $str = _sanitize(shift);
	die "You must supply a string to get the checksum of" unless (length $str);
	my @chars = split '', $str;
	
	my ($lowertotal, $uppertotal) = (0, 0);
	foreach my $c (@chars) {
		TRACE("_checksum: adding '$c'");
		my $bars = $CODEDCHARSET{$c} || die "Internal Error: Cannot find symbol for character '$c'";
		my ($l_lower, $l_upper) = (0, 0);

		if ($bars->[0] & 1) { $l_lower += 4; }
		if ($bars->[1] & 1) { $l_lower += 2; }
		if ($bars->[2] & 1) { $l_lower += 1; }
		if ($bars->[0] & 2) { $l_upper += 4; }
		if ($bars->[1] & 2) { $l_upper += 2; }
		if ($bars->[2] & 2) { $l_upper += 1; }

		TRACE("_checksum: Char: lower $l_lower upper $l_upper");
		$lowertotal += ($l_lower % 6);
		$uppertotal += ($l_upper % 6);
	}
	$lowertotal %= 6;
	$uppertotal %= 6;
	TRACE("_checksum: Total: lower $lowertotal upper $uppertotal");
	
	my $checkchar = $CHECKLUT[$uppertotal][$lowertotal];
	TRACE("_checksum: Result '$checkchar'");
	return $checkchar;
}

sub _initialize {
	my %duplicates;
	foreach my $k (sort keys %CHARSET) {
		my $v = $CHARSET{$k};
		
		# check the main data tables
		unless ($v =~ m/^[\.\-\'\|]{4}$/) {
			die "Internal Error: Character '$k' does not have a valid definition - '$v' is of the wrong format";
		}
		die "Internal Error: Character '$k' duplicates the symbol definition of '$duplicates{$v}'" if $duplicates{$v};
		$duplicates{$v} = $k;
		
		# encode the data in a binary form
		my @bars;
		foreach my $c (split '', $v) {
			push @bars, $BITLUT{$c};
		}
		$CODEDCHARSET{$k} = \@bars;
	}
}

# These are debugging hooks
sub TRACE {}
sub DUMP {}

1;

=head1 NAME

Barcode::RM4SCC - Generate Royal Mail 4 State Customer Code (RM4SCC) barcodes and barcode data

=head1 SYNOPSIS

	use Barcode::RM4SCC;
	my $obj = new Barcode::RM4SCC( String => 'WC1E6XY' );
	my $pattern = $obj->barcode;

If you have GD installed you can:

	my $gdObj = $obj->plot;
	# or specify some options:
	# my $gdObj = $obj->plot( WithText => 1, QuietZone => 10);
	my $image = $gdObj->png;

and, for example, save the image to a file:

	open(IMG, ">$aFilename") || die "Cannot open $aFilename: $!";
	binmode(IMG);
	print IMG $image;
	close(IMG);

=head1 ABSTRACT

Generate Royal Mail 4 State Customer Code (RM4SCC) barcode data, and images

=head1 DESCRIPTION

This module generates the sequence of bars required to encode a particular string
as a Royal Mail 4 State Customer Code (RM4SCC) - a kind of height-modulated barcode
used for automated postal sorting in the United Kingdom. If you have GD installed
you can generate a bitmap image of the barcode, but GD is not required to use the rest
of this module.

Data to be encoded may contain only uppercase letters and numbers. This module
will ignore invalid characters.
The checksum character is generated automatically for you, as are the start and stop bits.

You may notice that this module is not a subclass of GD::Barcode. I did want to
integrate this module as much as possible with existing barcode modules, but it seems
that GD::Barcode won't handle height-modulated barcodes such as this one. However,
I have tried to keep the interface roughly similar.

=head1 WARNING

This module has been written in good faith using information from the web.
However, this may not match the actual specification for the RM4SCC so
you should be very careful before using this module because it may get things
wrong - and that may incur delays or even extra charges!

Having said that, the output I<does> seem to match other sources of RM4SCC barcodes
when I have compared them.
If you do find errors or bugs please report them. See my area on CPAN for contact details.

I am not connected with the Royal Mail. To the best of my knowledge they don't know
about this module, and hence there is no approval or endorsement from them.

=head1 NOTES

If you intend to use the barcode image, according to references that I read
there should be 20 to 24 bars per 25.4mm (1 inch), which means that the image should be printed
at a resolution of 80 to 96 pixels per inch. A quiet zone of 2mm should exist around the
barcode and this is why the plot() method generates space around the barcode by default.

=head1 METHODS

=over 4

=item new( %options )

Class method. Given a hash of options, return a new object. See L</OPTIONS>.
This method will die if an object cannot be created - e.g. if a mandatory option is omitted.

=item barcode()

Return a barcode pattern as a string. The string is a sequence of the digits 0, 1, 2 and 3. The first
character represents the leftmost bar, and the final character represents the rightmost bar.
Digit 0 means that the bar has no ascender or descender, just the "track". Digit 1 means
there is a descender. Digit 2 means there is an ascender. Digit 3 means there is both an ascender and
descender.

=item plot()

Creates and returns a GD object with the barcode image. This method dies if GD cannot be loaded.
You may supply options to this routine to affect how the image is drawn - see L</OPTIONS>.
You may then call methods on that GD object, e.g. to render the image data.

=back

=head1 OPTIONS

These are the options to new():

=over 4

=item String

Required. The string for which you want to generate a barcode. Any invalid characters will be stripped,
and the letters will be made uppercase, before use.

=item NoChecksum

If true, do not include a checksum character in the barcode. In general there should be a checksum, so don't use this option
unless you really know what you're doing.

=item NoStartbit

If true, do not include the start bit bar in the barcode. In general you do want a start bit, so don't use this option
unless you really know what you're doing.

=item NoStopbit

If true, do not include the stop bit bar in the barcode. In general you do want a stop bit, so don't use this option
unless you really know what you're doing.

=back

These are the options to plot():

=over 4

=item WithText

If true, the input string (after being uppercased and stripped of invalid characters) will be added to the barcode

=item QuietZone

The size of the "quiet zone" around the image, in pixels. By default this is 8, because that
exceeds 2mm when the image is printed from 80 to 96 pixels per inch (see L</DESCRIPTION>).

=item BarColour

By default the bars are black. If you really must change the colour set this option to be an
array reference of red, green and blue values, each from 0 to 255.

=item BGColour

By default the background is white. If you really must change the colour set this option to be an
array reference of red, green and blue values, each from 0 to 255.

=item BGTransparent

By default the image is fully opaque. If this is true then we use the GD object's
transparent() method to make the background transparent.

=back

=head1 SEE ALSO

Information from these URLs was used while writing this module:

=over 4

=item *

http://www.dlsoft.com/dlHelps/helps/dbcnet/rm4scc.htm

=item *

http://www.morovia.com/education/symbology/royalmail.asp

=back

Those websites are not connected with me or this module.

=head1 AUTHOR

P Kent

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by P Kent

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
