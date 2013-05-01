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
	c2a => C5, #Changed from CS for concern of overlap with Cs
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
		if (not $mode eq 'NONBONDED MIXRULE'){
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
			print "[ bondtypes ]\n; i    j  func       b0          kb\n";
		}
		elsif($line eq 'BENDINGS'){
			$mode = 'BENDINGS';
			$number_of_atoms = 3;	
			print "\n\n\n[ angletypes ]\n;  i    j    k  func       th0       cth\n";
		}
		elsif($line eq 'TORSION PROPER'){
			$mode = 'TORSION PROPER';
			$number_of_atoms = 4;
			print "\n\n\n[ dihedraltypes ]\n;i  j   k  l     func      phase      kd      pn\n";
		}
		elsif($line eq 'TORSION IMPROPER'){
			$mode = 'TORSION IMPROPER';
			$number_of_atoms = 4;
			print "\n\n\n[ dihedraltypes ]\n;i  j   k  l\n";
		}
		elsif($line eq 'NONBONDED MIXRULE'){
			$mode = 'NONBONDED MIXRULE';
			$number_of_atoms = 1;
		}
		else{
			print "malformed: $line";
			$error = 1;
		}
	}
	else{
		$reformatted_line = "                                                                           ";
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
			if ($mode eq 'BOND'){
				$replace_position = 0;
				$replace_length = 0;
				for ($count = 0 ; $count < $number_of_atoms ; $count++){
					if ($count == 0){
						$replace_position = 2;
						$replace_length = 2;
					}
					if ($count == 1){
						$replace_position = 5;
						$replace_length = 2;
					}
							
					if (length($A[$count]) == 3){
						substr($reformatted_line, $replace_position, $replace_length, $twoletter{$A[$count]});
					}
					else{
						substr($reformatted_line, $replace_position, $replace_length, "\U$A[$count]");
					}
				}
				
				$replace_position = 17;	
				substr($reformatted_line, $replace_position-1,1, "1");
				$reformatted_line = insertleft($reformatted_line, $replace_position+11, $A[3]/10);
				$reformatted_line = insertleft($reformatted_line, $replace_position+22, $A[2]*418.4);
				print $reformatted_line . "\n";

			}
			if ($mode eq 'BENDINGS'){
				$replace_position = 0;
				$replace_length = 0;
				for ($count = 0 ; $count < $number_of_atoms ; $count++){
					if ($count == 0){
						$replace_position = 0;
						$replace_length = 2;
					}
					if ($count == 1){
						$replace_position = 4;
						$replace_length = 2;
					}
					if ($count == 2){
						$replace_position = 8; 
						$replace_length = 2;
					}
							
					if (length($A[$count]) == 3){
						substr($reformatted_line, $replace_position, $replace_length, $twoletter{$A[$count]});
					}
					else{
						substr($reformatted_line, $replace_position, $replace_length, "\U$A[$count]");
					}
				}
				
				$replace_position = 22;	
				substr($reformatted_line, $replace_position-1,1, "1");
				$reformatted_line = insertleft($reformatted_line, $replace_position+10, $A[4]);
				$reformatted_line = insertleft($reformatted_line, $replace_position+21, $A[3]*4.184);
				print $reformatted_line . "\n";


			}
			if ($mode eq 'TORSION PROPER'){
				$replace_position = 0;
				$replace_length = 0;
				for ($count = 0 ; $count < $number_of_atoms ; $count++){
					if ($count == 0){
						$replace_position = 0;
						$replace_length = 2;
					}
					if ($count == 1){
						$replace_position = 4;
						$replace_length = 2;
					}
					if ($count == 2){
						$replace_position = 8; 
						$replace_length = 2;
					}
					if ($count == 3){
						$replace_position = 12; 
						$replace_length = 2;
					}	
					if (length($A[$count]) == 3){
						substr($reformatted_line, $replace_position, $replace_length, $twoletter{$A[$count]});
					}
					else{
						substr($reformatted_line, $replace_position, $replace_length, "\U$A[$count]");
					}
				}
				
				$replace_position = 22;	

				$base_angle = $A[6];
				$force_const = $A[4];
				if ($A[6] eq ''){
					if ($force_const < 0){
						$base_angle = '0.0';
						$force_const = -$force_const;
					}
					else{
						$base_angle = '180.0';
					}
				}
				substr($reformatted_line, $replace_position-1,1, "9");
				$reformatted_line = insertleft($reformatted_line, $replace_position+12, $base_angle);
				$reformatted_line = insertleft($reformatted_line, $replace_position+24, $force_const*4.184);
				$reformatted_line = insertleft($reformatted_line, $replace_position+30, $A[5]);
				print $reformatted_line . "\n";


			}
			if ($mode eq 'TORSION IMPROPER'){
				$replace_position = 0;
				$replace_length = 0;
				for ($count = 0 ; $count < $number_of_atoms ; $count++){
					if ($count == 0){
						$replace_position = 1;
						$replace_length = 2;
					}
					if ($count == 1){
						$replace_position = 5;
						$replace_length = 2;
					}
					if ($count == 2){
						$replace_position = 9; 
						$replace_length = 2;
					}
					if ($count == 3){
						$replace_position = 13; 
						$replace_length = 2;
					}	
					if (length($A[$count]) == 3){
						substr($reformatted_line, $replace_position, $replace_length, $twoletter{$A[$count]});
					}
					else{
						substr($reformatted_line, $replace_position, $replace_length, "\U$A[$count]");
					}
				}
				
				$replace_position = 20;	
				substr($reformatted_line, $replace_position-1,1, "4");
				$reformatted_line = insertleft($reformatted_line, $replace_position+10, $A[6]);
				$reformatted_line = insertleft($reformatted_line, $replace_position+23, $A[4]*4.184);
				$reformatted_line = insertleft($reformatted_line, $replace_position+29, $A[5]);
				print $reformatted_line . "\n";
			}
			if ($mode eq 'NONBONDED MIXRULE'){
				# skip these in the .itp file
			}
		}
	}

	if ($error){
		#print "Malformed line\n";
	}
}

close(DATA);
