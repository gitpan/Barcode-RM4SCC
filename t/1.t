# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

use Test::More tests => 22;
BEGIN { use_ok('Barcode::RM4SCC') };

#debugging hooks
sub TRACE {}
sub DUMP {}
#use Tracing;
#deep_import Tracing 'print';

#########################

ok($Barcode::RM4SCC::VERSION, "Has version number $Barcode::RM4SCC::VERSION");

### Test the _sanitize routine
$rv = Barcode::RM4SCC::_sanitize("0123456789abcdefghijklmnopqrstuvwxyz");
ok($rv eq '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', "sanitize: got '$rv' expected 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ");

$rv = Barcode::RM4SCC::_sanitize("hello world");
ok($rv eq 'HELLOWORLD', "sanitize: got '$rv' expected HELLOWORLD");

$rv = Barcode::RM4SCC::_sanitize("2112.34_5:6");
ok($rv eq '21123456', "sanitize: got '$rv' expected 21123456");


### Test the _checksum routine
my $rv = Barcode::RM4SCC::_checksum("hello world");
ok($rv eq 'V', "checksum: got '$rv' expected V");

$rv = Barcode::RM4SCC::_checksum("aAaaAaa");
ok($rv eq 'A', "checksum: got '$rv' expected A");

$rv = Barcode::RM4SCC::_checksum("TomSawyer");
ok($rv eq 'O', "checksum: got '$rv' expected O");


### Test the object interface
my $obj;

eval { $obj = new Barcode::RM4SCC(); };
$rv = $@;
chomp($rv);
ok(length($rv), "Constructor error trapped: $rv");


$obj = new Barcode::RM4SCC( String => 'helloworld' );
ok(ref($obj), "object created");
$rv = $obj->barcode;
ok($rv eq '2132003303003300320312310203130213003032123013', "barcode: got '$rv' expected 2132003303003300320312310203130213003032123013");


$obj = new Barcode::RM4SCC( String => 'helloworld', NoStartbit => 1 );
ok(ref($obj), "object created");
$rv = $obj->barcode;
ok($rv eq '132003303003300320312310203130213003032123013', "barcode: got '$rv' expected 132003303003300320312310203130213003032123013");


$obj = new Barcode::RM4SCC( String => 'helloworld', NoStopbit => 1 );
ok(ref($obj), "object created");
$rv = $obj->barcode;
ok($rv eq '213200330300330032031231020313021300303212301', "barcode: got '$rv' expected 213200330300330032031231020313021300303212301");


$obj = new Barcode::RM4SCC( String => 'helloworld', NoChecksum => 1 );
ok(ref($obj), "object created");
$rv = $obj->barcode;
ok($rv eq '213200330300330032031231020313021300303213', "barcode: got '$rv' expected 213200330300330032031231020313021300303213");


$obj = new Barcode::RM4SCC( String => 'WC1E6XY' );
ok(ref($obj), "object created");
$rv = $obj->barcode;
ok($rv eq '2231002310123033002133201321002313', "barcode: got '$rv' expected 2231002310123033002133201321002313");



SKIP: {
	my $have_GD = 0;
	my $err;
	eval "require GD;";
	$err = $@;
	$err =~ s/[\n\r]/ /g;
	TRACE($err);
	if ($err) {
		TRACE("Cannot load GD: $err");
	} elsif ($GD::VERSION) {
		TRACE("Loaded $GD::VERSION");
		$have_GD = 1;
	} else {
		warn "No apparent error loading GD, but no \$GD::VERSION - assuming GD is not present";
	}
	skip "GD doesn't appear to be installed, won't generate barcode image", 3 unless $have_GD;


	$obj = new Barcode::RM4SCC(
		String => 'W1A 1AA 6Y',
	);
	my $gd = $obj->plot(
		WithText => 1,
#		QuietZone => 3,
#		BarColour => [255, 0, 128],
#		BGColour => [230, 240, 250],
#		BGTransparent => 0,
	);
	ok(ref($gd), "plot returns GD object");
	
	my ($fn, $data);
	if ($gd->can('png')) {
		$fn = '1.png';
		$data = $gd->png;
	} else {
		$fn = '1.gif';
		$data = $gd->gif;
	}
	ok(length($data), "image rendering returns something");
	
	open(IMG, ">$fn") || die "Cannot write image to '$fn': $!";
	binmode(IMG);
	print IMG $data;
	close(IMG);

	my $s = -s $fn;
	ok(($s > 10), "output image file $fn exists with size $s");
};
