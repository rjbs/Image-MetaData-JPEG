use Test::More;
use strict;
use warnings;

my @docfiles = ( "lib/Image/MetaData/JPEG.pod" );
my $checker_module = "Pod::Checker";

#=======================================
diag "Checking documentation syntax with $checker_module";
eval "require $checker_module";
if ($@) { plan skip_all => "You don't have the $checker_module module"; }
else    { plan tests => scalar @docfiles; }
#=======================================

for my $filename (@docfiles) {
    my $output = undef;
    open(my $fh, '>', \$output);
    my $checker = new $checker_module ( -warnings => 10 );
    $checker->parse_from_file($filename, \*$fh);
    is( $output, undef, "Checking $filename" );

    # print index
    my %c; open FH, $filename;
    print "====== Index of $filename ======\n";
    while (<FH>) {
	next unless /=head(.)\s(.*)$/;
	++$c{$1}; @c{1+$1..100} = ();
	printf "%*s %s\n", 5*$1, join(".",@c{1..$1}), $2; }
}

#cover -delete
#HARNESS_PERL_SWITCHES=-MDevel::Cover make test
#cover

### Local Variables: ***
### mode:perl ***
### End: ***
