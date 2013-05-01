#!/usr/bin/perl

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
# Left trim function to remove leading whitespace
sub ltrim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	return $string;
}
# Right trim function to remove trailing whitespace
sub rtrim($)
{
	my $string = shift;
	$string =~ s/\s+$//;
	return $string;
}

sub insertleft(@){
	my ($string,$pos,$instext) = @_;
	substr($string, $pos-length($instext),length($instext), $instext);
	return $string;
}


#Nomenclature for the modifications is somewhat arbitrary; the purpose is to select two-letters with the appropriate first letter,
# but names which are not already taken in Gromacs ffAmber03
%twoletter = (
	cab => CD,
	cbb => CE,
	cnb => CF,
	cpb => CG,
	cqb => CH,
	crb => CI,
	csb => CJ,
	ccs => CL,
	cqq => CO,
	c2k => CP,
	c2a => C5, #was CS, but fear of overlap with Cs
	c2e => CU,
	cq2 => CX,
	ct1 => C1,
	ct2 => C2,
	ct3 => C3,

	nmh => NM,
	mgc => MC,
	ha0 => HQ,
	o2c => OC,
	o1c => O1,

	rb => Rb,
	br => Br,
	cl => Cl,
	na => Na,
	cs => Cs,
	li => Li,
	zn => Zn,
);

%mass2num = (
	"1.008" => 1,
	"6.940" => 3,
	"12.010" => 6,
	"12.011" => 6,
	"14.010"=> 7,
	"15.999" => 8,
	"16.000" => 8,
	"19.000" => 9,
	"22.990" => 11,
	"24.305" => 12,
	"30.970" => 15,
	'32.060' => 16,
	'35.450' => 17,
	"39.100" => 19,
	"55.847" => 26,
	"85.470" => 37,
	"126.900" => 53,
	"131.000" => 54,
	"132.910" => 55,
);



open(DATA, "<BCHL.prm") || die "Coudln't open file";

my $mode = 'none';
my $number_of_atoms = 0;
while (<DATA>)
{
	my $line = trim($_);
	my $first = substr($line, 0, 1);
	@A = split (/ +/,$line);
	
	my $error = 0;
	if ($first eq '#'){
		if ($mode eq 'NONBONDED MIXRULE'){
			print ';'.$line . "\n";
		}
	}
	elsif ($#A +1 <= 2){
		if($line eq 'END'){
			#print "WE JUST GOT THE END SIGNAL, BUDDY\n";
		}
		elsif($line eq 'BOND'){
			$mode = 'BOND';
			$number_of_atoms = 2;
		}
		elsif($line eq 'BENDINGS'){
			$mode = 'BENDINGS';
			$number_of_atoms = 3;	
		}
		elsif($line eq 'TORSION PROPER'){
			$mode = 'TORSION PROPER';
			$number_of_atoms = 4;
		}
		elsif($line eq 'TORSION IMPROPER'){
			$mode = 'TORSION IMPROPER';
			$number_of_atoms = 4;
		}
		elsif($line eq 'NONBONDED MIXRULE'){
			$mode = 'NONBONDED MIXRULE';
			$number_of_atoms = 1;
			print "[ atomtypes ]\n; name    at.num  mass  charge  ptype  sigma   epsilon\n";
		}
		else{
			print "malformed: $line";
			$error = 1;
		}
	}
	else{
		$reformatted_line = "                                                                                            ";
		$skip_line = 0;
		for ($count = 0 ; $count < $number_of_atoms ; $count++){
			if (length($A[$count]) == 3){
				if (not exists $twoletter{$A[$count]}){
					#print length($A[$count]) . " $A[$count] is hashless\n";
					$skip_line = 1;
				}
			}
		}
			
		if (not $skip_line){	
			if ($mode eq 'NONBONDED MIXRULE'){
				if (exists $twoletter{$A[0]}){
					substr($reformatted_line, 0, 2, $twoletter{$A[0]});
				}
				else{
					substr($reformatted_line, 0, length($A[0]), "\U$A[0]");
				}
				$reformatted_line = insertleft($reformatted_line, 14, $mass2num{$A[5]});
				$reformatted_line = insertleft($reformatted_line, 25, $A[5]);
				$reformatted_line = insertleft($reformatted_line, 35, $A[3]);
				$reformatted_line = insertleft($reformatted_line, 38, "A");
				$reformatted_line = insertleft($reformatted_line, 52, sprintf("%e", $A[1] * 1.44996 * 1.22462 / 10)); 
					# converting from rmin to sigma, Angstroms to nm, (with 1.44996 as the ghetto calibration between iodines)
				$reformatted_line = insertleft($reformatted_line, 65, sprintf("%e", $A[2] * 4.182));
					# converting from kcal/mol to kJ/mol
				print trim($reformatted_line)."\n";
			}
		}
	}

	if ($error){
		#print "Malformed line\n";
	}
}

close(DATA);
