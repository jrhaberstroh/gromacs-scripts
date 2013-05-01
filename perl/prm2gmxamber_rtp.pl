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
	c2a => C5,
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
);




open(DATA, "<BCHL.tpg") || die "Coudln't open file";

my $mode = 'none';
my $number_of_atoms = 0;
while (<DATA>)
{
	my $line = trim($_);
	my $first = substr($line, 0, 1);
	@A = split (/ +/,$line);
	
	my $signal = 0;
	if ($#A + 1 > 0){
		if ($A[0] eq 'RESIDUE'){
			print "[ "."\U$A[1]"." ]\n";
			$signal = 1;
		}
		elsif ($A[0] eq 'atoms'){
			$mode = 'atoms';
			print " [ atoms ]\n";
			$signal = 1;
		}
		elsif ($A[0] eq 'bonds'){
			$mode = 'bonds';
			print " [ bonds ]\n";
			$signal = 1;
		}
	
		elsif ($A[0] eq 'imphd'){
			$mode = 'impropers';
			print " [ impropers ]\n";
			$signal = 1;
		}

		elsif ($A[0] eq '#'){
			$signal = 1;
		}
		elsif ($A[0] eq 'end'){
			$signal = 1;
		}
		elsif ($A[0] eq 'termatom'){
			$signal = 1;
		}
		elsif ($A[0] eq ''){ 
			$signal = 1;
		}
		elsif ($A[0] eq 'group'){
			$signal = 1;
		}
		elsif ($A[0] eq 'RESIDUE_END'){
			$mode = none;
			$signal = 1;
		}
	}
	if ($signal == 0){
		$reformatted_line = "                                                                           ";
		if ($mode eq 'atoms'){
			$replace_position = 0;
			$replace_length = 0;
			$reformatted_line = insertleft($reformatted_line, 6, "\U$A[0]");
				
			if (exists $twoletter{$A[1]}){
				$reformatted_line = insertleft($reformatted_line, 12, $twoletter{$A[1]});
			}
			else{
				$reformatted_line = insertleft($reformatted_line, 12, "\U$A[1]");
			}
			$reformatted_line = insertleft($reformatted_line, 31, $A[2]);
			$reformatted_line = insertleft($reformatted_line, 36, "0");
			print $reformatted_line . "\n";
		}
		if ($mode eq 'bonds'){
			for ($count = 0 ; $count < ($#A + 1)/2 ; $count++){
				$reformatted_line = "                                                                           ";
				for ($atomct = 0 ; $atomct < 2 ; $atomct++){
					if ($atomct == 0){
						$reformatted_line = insertleft($reformatted_line, 6, "\U$A[$count * 2 + $atomct]");
					}
					if ($atomct == 1){
						$reformatted_line = insertleft($reformatted_line, 12, "\U$A[$count * 2 + $atomct]");
					}
				}
				print $reformatted_line . "\n";
			}
		}
		if ($mode eq 'impropers'){
			$reformatted_line = insertleft($reformatted_line, 6, $A[0]);
			$reformatted_line = insertleft($reformatted_line,12, $A[1]);
			$reformatted_line = insertleft($reformatted_line,18, $A[2]);
			$reformatted_line = insertleft($reformatted_line,24, $A[3]);

			print $reformatted_line . "\n";
		}


	}
}


close(DATA);
