#!/usr/bin/perl -s
#############################################################################
#
# AMRVAC PreProcessor (Based on vacpp.pl by Gabor Toth) 
#
# Translates the dimension independent notation to Fortran 90 by expanding
# the Loop Annotation SYntax (LASY). Also translates COMMON, INCLUDE:
#
# Usage: make file.f                           # Called by the Makefile
#        vacpp.pl -d=23 -p=rho -               # Interactive
#        vacpp.pl file.t > file.f              # Translation
#        vacpp.pl -maxlen=72 file.t > file.f   # Limit line length
#############################################################################
use Cwd;

if (!($d && $p)){
    print STDERR <<HELPMSG ;

vacpp.pl -d=NdimNdir -p=PHYSICS [-phi=Idirphi] [-z=Idirz] [-eos=typeeos] [-nf=Nfluids] [-ndust=Ndust] [-cp=mpienv]\
    file.t > file.f

Examples:

vacpp.pl -d=22 -phi=3 -z=2 -p=mhd file.t > file.f
HELPMSG
exit}

$AMRVAC_DIR=$ENV{AMRVAC_DIR};

my $cwd = getcwd();
# Include dirs for header files:
@INC={"$CWD","$AMRVAC_DIR/$p"};

# Default maximum length for lines unless set by eg. "vacpp.pl -maxlen=72 ..."
$maxlen=78 unless $maxlen;

# For interactive use accept -d=12 flag
$d=~/([123])([123])/ || die "Incorrect -d flag value\n";
$ndim=$1; $ndir=$2;
if ($phi){
    $phi=~/\d/ || die "Incorrect -phi flag value\n";
}else{ $phi=3;}
if ($z){
    $z=~/(\d)/ || die "Incorrect -z flag value\n";
}else{ $z=2;}

$nf=0 unless $nf;
$nd=0 unless $nd;
$cp=openmpi unless $cp;
$eos=default unless $eos;

&definepatterns;
&includeheader;
&definevars;

foreach $file (@ARGV) {
   &processfile($file, 'fh00');
}
#============================================================================
sub includeheader{
   # Define special characters for the PreProcessor

   # include the headerfile from the build dir:
   eval{
       ### try block
       require "$cwd/../definitions.h";
   };
}
#============================================================================
sub processfile {
   local($filename, $input) = @_;
   $input++;
   open($input, $filename) || die"Can't open $filename: $!\n";
   while (<$input>) {
      # PRINT EMPTY AND COMMENT LINES AS THEY ARE
      if(/^$/ || /^ *![^S]/ && not /^ *!\$[^S]/){print; next}
      # HIDE QUOTED TEXT FROM TRANSLATION
      $_=&quotation($_);
      # PRINT TRAILING COMMENTS (commented out to protect !F77_ etc....)
      #if(s/ *(!.*)//){$comment=&unquote($1); /^ */; print "$&$comment\n"}
      # COLLECT CONTINUATION LINES, except for !$OMP comments
      if(not /^ *!\$[^S]/){ next if &contline }
      # REPLACE TABS BY SPACES
      if(/\t/){
	  print STDERR "Warning: TABs are replaced by SPACEs\n" unless 
                                                               $tabwarn++;
          1 while s/\t+/' ' x (length($&)*8 - length($`)%8)/e;
      }
      # EXPAND THE LINE
      &processline($input);
      # PROCESS FILES INCLUDED BY "INCLUDE:filename"
      if (/INCLUDE:(.*)/) {&processfile("$AMRVAC_DIR/src/$1",$input);next}
      # PRINT THE LINE FORMATTED ACCORDING TO MAXLEN
      &printline if $_;
   }
   # Print common declarations collected from "COMMON,..." lines
   for $_ (values(%common)){&printline}; undef %common;
}
#===========================================================================
sub contline{
    # Join continuation lines into a single line. Uses global $contline
    if(/[^A-Z]\& *$/){$contline.=$_}
    else             {$_=$contline.$_;s/([^A-Z])\& *\n */$1/g;$contline=""}
}
#============================================================================
sub processline{
   local($input)=@_;
   # ATTACH A NUL-SEPARATOR CHARACTER TO THE BEGINNING OF LINE FOR LEFTMATCH
   $_=$spc.$_;
   # DO SUBSTITUTIONS FOR BLOCKS "{....}"
   while(/$ope/){
      &block($input);
      #print "Block:$_";
   }
   # DO SUBSTITUTION FOR EXPRESSIONS "...^pattern..."
   while(/$pat/){
       &expression;
      #print "Expr:$_";
   }
   # REMOVE NUL-SEPARATOR CHARACTERS
   s/$spc//g; 
   # REPLACE BREAK CHARACTERS BY NEWLINES AND INDENTATION
   if(/\\/){/^ */; $indent=$&; s/\\/\n$indent/g};
   # PROCESS "COMMON, ..." DECLARATIONS
   if(/^ *COMMON,/){&common};
}
#============================================================================
sub definepatterns{

   $ope='{'; $clo='}'; $bar='\|'; 
   $pre='#'; $ifdef='IFDEF'; $ifndef='IFNDEF';
   $pat='\^'; $patid='[A-Z]'; $patchr='[A-Z&%]'; $uni='%';
   $brk='\\'; $sep='[,\+\-\*/:; ]'; $spc='~';
   $rbound=" ,;~)\n"; $lbound=" ,;~(\n";

   $nsubdefault=$ndim;
   # Define number of substitutes and subtitute strings for patterns
   # E.g. ^D -> 1,2 is defined by &patdef('D',2,'1','2','3')
   &patdef('ND'	,1	,$ndim			);
   &patdef('NC'	,1	,$ndir			);
   &patdef('NFL',1	,$nf			);
   &patdef('PHI',1	,$phi			);
   &patdef('Z'	,1	,$z			);
   if($phi>0){$pphi=$phi}else{$pphi=1};
   if($z>0){$zz=$z}else{$zz=1};
   &patdef('PPHI',1	,$pphi			);
   &patdef('ZZ'	,1	,$zz			);

   &patdef('DE'	,$ndim-1,2	,3		);
   &patdef('DE&',$ndim-1			);
   &patdef('DE%',$ndim-1,'^%2'	,'^%3'		);
   &patdef('DM&',$ndim-1			);
   &patdef('DM'	,$ndim-1,1	,2		);
   &patdef('DMB',$ndim-1,$ndim-1,$ndim-2        ); 
   &patdef('SE'	,$ndim-1,'^LIM2:','^LIM3:'	);
   &patdef('TE'	,$ndim-1,'^LLIM2:','^LLIM3:'	);

#  Dust specific patterns:
   &patdef('NDS',1	,$ndust			);
   &patdef('DS',$ndust,1  ,2  ,3  ,4,5,6,7,8,9,10);
   &patdef('DS&',$ndust);

   &patdef('FL'	,$nf	,1, 2	,3	,4,5,6,7,8,9,10);
   &patdef('FL&'	,$nf			       );
   &patdef('FL%',$nf	,'^%2'	,'^%3'	,'^%4','^%5','^%6','^%7','^%8','^%9','^%10');
   &patdef('FLLOOP',$nf       			);
   &patdef('TD'  ,$ndim  ,1      ,2      ,3      );
   &patdef('D'	,$ndim	,1	,2	,3	);
   &patdef('D&'	,$ndim				);
   &patdef('DLOOP',$ndim       			); 
   &patdef('DB'	,$ndim	,$ndim	,$ndim-1,$ndim-2);
   &patdef('DD'	,$ndim	,'^D' 	,'^D'	,'^D'	);
   &patdef('DDD'	,$ndim	,'^DD' 	,'^DD'	,'^DD'	);
   &patdef('DDB',$ndim  ,'^DB'  ,'^DB'  ,'^DB'  );
   &patdef('DD&',$ndim	,'^D&'	,'^D&'	,'^D&'	);
   &patdef('DDLOOP',$ndim,'^DLOOP','^DLOOP','^DLOOP');
   &patdef('D%'	,$ndim	,'^%1'	,'^%2'	,'^%3'	);
   &patdef('DL'	,$ndim	,'^LIM1','^LIM2','^LIM3');
   &patdef('S'	,$ndim	,'^LIM1:','^LIM2:','^LIM3:');
   &patdef('T'	,$ndim	,'^LLIM1:','^LLIM2:','^LLIM3:');
   &patdef('DLB',$ndim	,'^LIM'.$ndim,'^LIM'.($ndim-1),'^LIM'.($ndim-2));

   &patdef('CE'	,$ndir-1,2	,3		);
   &patdef('CE&',$ndir-1			);
   &patdef('CELOOP',$ndir-1			);

   &patdef('C'	,$ndir	,1	,2	,3	);
   &patdef('C&'	,$ndir				);
   &patdef('CLOOP',$ndir       			);
   &patdef('CC'	,$ndir	,'^C'	,'^C'	,'^C'	);

   &patdef('LIM'	,2	,'min'	,'max'	);
   &patdef('LLIM'	,2	,'lo'	,'hi'	);
   &patdef('L'		,2	,'min^D','max^D');
   &patdef('LL'		,2	,'lo^D'	,'hi^D');
   &patdef('LSUB'	,2	,'+'	,'-'	);
   &patdef('LADD'	,2	,'-'	,'+'	);
   &patdef('LT'		,2	,'>'	,'<'	);

   &patdef('IFONEFLUID'	,$nf==0			);
   &patdef('IFMLTFLUID'	,$nf>0			);
   &patdef('IFTOFLUID'	,$nf>1			);
   &patdef('IFTRFLUID'	,$nf>2			);
   &patdef('IFFRFLUID'	,$nf>3			);
   &patdef('IFFVFLUID'	,$nf>4			); 
   &patdef('IFSIFLUID'	,$nf>5			);
   &patdef('IFSEFLUID'	,$nf>6			);
   &patdef('IFHEFLUID'	,$nf>7			);
   &patdef('IFNIFLUID'	,$nf>8			);
   &patdef('IFTEFLUID'	,$nf==10		);

   &patdef('IFONED'	,$ndim==1		);
   &patdef('IFTWOD'	,$ndim==2		);
   &patdef('IFTHREED'	,$ndim==3		);
   &patdef('IFONEC'     ,$ndir==1               );
   &patdef('IFTWOC'	,$ndir==2		);
   &patdef('IFTHREEC'	,$ndir==3		);
   &patdef('NOONED'	,$ndim!=1		);
   &patdef('NOONEC'     ,$ndir!=1               );
   &patdef('IFPHI'      ,$phi>0			);
   &patdef('IFZ'        ,$z>0			);
   &patdef('IFMHD'      ,$p eq mhd              );
   &patdef('IFSRMHD'    ,$p eq srmhd		);
#   &patdef('IFSRMHDGLM' ,$p eq srmhdglm         );
   &patdef('IFSRHD'     ,$p eq srhd		);
   &patdef('IFSRHDEOS'  ,$p eq srhdeos		);
   &patdef('IFSRMHDEOS' ,$p eq srmhdeos		);
#   &patdef('IFSRMHDGLMEOS' ,$p eq srmhdglmeos   );
#   &patdef('IFGLM'      ,$p eq mhdglm || $p eq srmhdglm || $p eq srmhdglmeos);
   &patdef('IFEOS'      ,$p eq srhdeos || $p eq srmhdeos || $p eq srmhdglmeos );
   &patdef('IFNOEOS'    ,$p ne srmhdeos && $p ne srmhdglmeos && $p ne srhdeos);
   &patdef('IFMHDPHYS'  ,$p eq mhd || $p eq mhdglm || $p eq srmhd || $p eq rmhd || $p eq srmhdglm || $p eq srmhdeos || $p eq srmhdglmeos);
   &patdef('IFHDPHYS'  ,$p eq hd ||  $p eq srhd ||  $p eq srhdeos || $p eq srhdeoscooling);
   &patdef('IFRELMHDPHYS'  , $p eq srmhd || $p eq rmhd || $p eq srmhdglm || $p eq srmhdeos || $p eq srmhdglmeos);
   &patdef('IFRELHDPHYS'  ,  $p eq srhd ||  $p eq srhdeos || $p eq srhdeoscooling);
   &patdef('IFREL'      ,$p eq srhd || $p eq srhdeos || $p eq srmhd || $p eq srmhdglm || $p eq srmhdeos || $p eq srmhdglmeos || $p eq srhdeoscooling|| $p eq srhdcooling || $p eq grhd);
   &patdef('IFREL'  , $p eq srmhd || $p eq rmhd || $p eq srmhdglm || $p eq srmhdeos || $p eq srmhdglmeos);
  &patdef('IFCLA'      ,$p eq hdadiab || $p eq hd || $p eq mhd || $p eq mhdglm || $p eq mhdadiab);
   &patdef('IFRESSRMHD' ,$p eq ressrmhd         );
   &patdef('IFMPT'      ,$cp eq mpt             );
   &patdef('IFNOMPT'    ,$cp ne mpt             );
   &patdef('IFGR'       ,$p eq grhd ||$p eq grhdeos || $p eq grmhd  || $p eq grmhdeos || $p eq grmhdglm || $p eq grmhdglmeos            );
  &patdef('IFNOGR'       ,$p ne grhd && $p ne grhdeos && $p ne grmhd  && $p ne grmhdeos && $p ne grmhdglm && $p ne grmhdglmeos            );
}
#============================================================================
sub definevars{
  # Build array of defined vars from definitions.h:
  %defvars = ();
  open (definitions, '../definitions.h');
  while (<definitions>) {
    chomp;
    if($_=~/^#define\s*(\S*)\s*(\S*)/){$var=$1;$value=$2;};
    $defvars{uc $var} = $value;
  }
  close (definitions); 
  # Attach the definitions from command line:
# EOS:
  $defvars{uc $eos}=1;
  if ($eos ne iso){$defvars{ENERGY}=1;}
  if ($eos eq default){$defvars{GAMMA}=1;}

# Tracers:
   if ($nf>0){$defvars{TRACER}=$nf;}

# Dust:
   if ($ndust>0){$defvars{DUST}=$ndust;}

# Dimensionality:
   if ($ndim==1){$defvars{D1}=1;}
   if ($ndim==2){$defvars{D2}=1;}
   if ($ndim==3){$defvars{D3}=1;}

# Components:
   if ($ndir==1){$defvars{C1}=1;}
   if ($ndir==2){$defvars{C2}=1;}
   if ($ndir==3){$defvars{C3}=1;}


# Remove incompatible definitions:
#   if ($p ne mhd && $p ne srmhd && $p ne srmhdiso && $p ne srmhdeos){delete $defvars{GLM};}
  }
#============================================================================
sub patdef{
   # Put pattern definitions into global %sub and %nsub associative arrays
   local($pattern,$nsub,@substitute)=@_; local($isub);
   for($isub=0;$isub<=$#substitute;$isub++){
       $sub{$pattern,$isub+1}="$substitute[$isub]";
   }
   $nsub{$pattern}=$nsub;  
}
#============================================================================
sub block{
   # Find block opening by $ope and closed by matching $clo, and substitute
   local($input)=@_;
   local($rightpos,$leftpos,$line,$nline);
   $leftpos=index($_,$ope);
   $level=0;
   $rightpos=&rightmatch($leftpos,$ope,$clo,$clo);
   #TST print "Leftpos:$leftpos,Rightpos:$rightpos\n";
   # If no match, ie $rightpos>=length($_), read at most 2000 more lines
   while($rightpos>=length($_) && $nline<2000 && ($line=<$input>)){
       $_.=&unquote($line); $nline++;
       $rightpos=&rightmatch($rightpos-1,$ope,$clo,$clo);
       #TST print "Line:$_ Rightpos:$rightpos\n";
   }
   die"$ope without matching $clo within 2000 lines" if $rightpos>=length($_);
   &substitute($leftpos,$rightpos);
}
#============================================================================
sub expression{
   # Find expression surrounding a bounded pattern and do substitution
   local($patpos,$rightpos,$leftpos);
   $patpos=index($_,'^');
   $leftpos = &leftmatch($patpos,'(',')',$lbound);
   $rightpos=&rightmatch($patpos,'(',')',$rbound);
   &substitute($leftpos,$rightpos);
}
#============================================================================
sub rightmatch{
   local($p,$lparen,$rparen,$bound)=@_; local($i,$c);
   for($i=$p+1;$i<length($_);$i++){
      $c=substr($_,$i,1); 
      last unless ($level!=0 || index($bound,$c)<0);
      $level++ if $c eq $lparen;
      $level-- if $c eq $rparen;
   }
   $i;
}
#============================================================================
sub leftmatch{
   local($p,$lparen,$rparen,$bound)=@_; local($i,$c,$level);
   for($i=$p-1;$i>0;$i--){
      $c=substr($_,$i,1); 
      last unless ($level!=0 || index($bound,$c)<0);
      $level++ if $c eq $rparen;
      $level-- if $c eq $lparen;
   }
   $i;
}
#============================================================================
sub substitute{
   #Substitute patterns of the same ID as of the first pattern
   local($leftpos,$rightpos)=@_;
   local($head,$lchr,$expr,$rchr,$tail);
   local($id,$nsub,$expa,$result);

   $head=substr($_,0,$leftpos);
   $lchr=substr($_,$leftpos,1);
   $expr=substr($_,$leftpos+1,$rightpos-$leftpos-1);
   $rchr=substr($_,$rightpos,1);
   $tail=substr($_,$rightpos+1);
   $symbol=substr($_,$leftpos+1,1);

   if($symbol==$pre){
     if($expr=~/^$pre\s*$ifdef\s*(\S*)\s.*/){
       $var=$1;
       if (exists $defvars{$var}){
	 $expr=~ s/$pre\s*$ifdef\s*$var(.*)/$1/;
	 $lchr='' if $lchr eq $ope || ($nsub==0 && $lchr eq $separator);
#	 $rchr=';' if $rchr eq $clo && $separator eq ";";
	 $rchr='' if $rchr eq $clo;
	 $_=$head.$lchr.$expr.$rchr.$tail;
#	        print 'var is gold, expression :',$expr,'end expr', 'var: ',$var, ' _: ',$_;
	 return;
       }
       else{
#	 print "var is silver, expression :", $expr,'end expr';
	 $lchr='' if $lchr eq $ope || ($nsub==0 && $lchr eq $separator);
#	 $rchr=';' if $rchr eq $clo && $separator eq ";";
	 $rchr='' if $rchr eq $clo;
	 $_=$head.$lchr.$rchr.$tail;
	 return;
       }
     }
     if($expr=~/^$pre\s*$ifndef\s*(\S*)\s.*/){
       $var=$1;
       if (not exists $defvars{$var}){
#	 print $var, ' not defined';
	 $expr=~ s/$pre\s*$ifndef\s*$var(.*)/$1/;
	 $lchr='' if $lchr eq $ope || ($nsub==0 && $lchr eq $separator);
#	 $rchr=';' if $rchr eq $clo && $separator eq ";";
	 $rchr='' if $rchr eq $clo;
	 $_=$head.$lchr.$expr.$rchr.$tail;
#	        print 'var is gold, expression :',$expr,'end expr', 'var :',$var;
	 return;
       }
       else{
#	 print "var is silver, expression :", $expr,'end expr';
	 $lchr='' if $lchr eq $ope || ($nsub==0 && $lchr eq $separator);
#	 $rchr=';' if $rchr eq $clo && $separator eq ";";
	 $rchr='' if $rchr eq $clo;
	 $_=$head.$lchr.$rchr.$tail;
	 return;
       }
     }
   }
   #Determine separator
   if($rchr eq ";")                 {$separator=";"}
   elsif($expr=~s/$bar([^$bar]*)$//){$separator="$spc$1$spc"}
   elsif($expr=~s/\\$//)            {$separator="$spc$brk$spc"}
   elsif($expr=~s/$sep$//)          {$separator="$&"}
   else                             {$separator=","};

   # Determine number of substitutions and ID
   if($expr=~/$pat($patid)($patchr*)/){$id=$1;$nsub=$nsub{"$1$2"};}
   else{$nsub=$nsubdefault}
   # Do the substitutions
   for($isub=1;$isub<=$nsub;$isub++){
     $expa=$expr;
     # If there is a unitvector pattern ^%N choose preceeding or subsequent
     # part depending on N==$isub or not.
     $expa=~s/$pat$uni$isub.*// || $expa=~s/.*$pat$uni.//;
     # Substitute patterns with $pat$id to their $isub-th substitute
     $expa=~s/$pat($id$patchr*)/$sub{$1,$isub}/g;
     $result.=$separator if $isub>1;
     $result.=$expa;
   }


   $lchr='' if $lchr eq $ope || ($nsub==0 && $lchr eq $separator);
   $rchr=';' if $rchr eq $clo && $separator eq ";";
   $rchr='' if $rchr eq $clo;
   $_=$head.$lchr.$result.$rchr.$tail;
}
#============================================================================
sub common{
    # Process lines of the form "COMMON, type:: var1(dim1),var2,..."
    # Store %common declarations with the name of the four first character
    # of the type and form the variable declaration type:: var1,var2,...
#opedit:
#    /^ *COMMON, *(....)[^:]*:: */; $name=$1; $varlist=$';
    /^ *COMMON, *(....)[^:]*:: */; $name=$1; $varlist=$';
    $varlist =~ s/\([^)]*\)//g;
    if($common{$name}){$common{$name}=~s/\n$/,$varlist/
    }else{             $common{$name}="COMMON /$name/ $varlist"}
    # Eliminate "COMMON," and the dimensions in parentheses
#    s/^ *COMMON, *//; s/\([^)]*\)//g;
#opedit:
    s/^ *COMMON, *//;
}
#============================================================================
sub printline{
    local($line,$comment); $sss="   ";

    # PRINT FORMATTED OUTPUT LINE BY LINE
    while(s/(.*)\n//){
       $line=$1;
       # PUT TRAILING COMMENTS INTO $comment
       if($line=~s/ *!.*//){
           $comment=&unquote($&);
           # If line is longer than $maxlen, try reducing length of comment
           if(length("$line$comment")>$maxlen){$comment=~s/ *! */ !/}
       }else{$comment=""};
       # Print full line
       $line=&unquote(&format90($line));
       # CORRECT REFERENCES TO INCLUDE FILES
       if($line=~/^ *include 'vac/){
          $line=~s/include 'vacdef\.\w+'/include 'vacdef.f'/;
          $line=~s/include 'vacpar\.\w+'/include 'vacpar.f'/;
          $line=~s/include 'vacusrpar\.\w+'/include 'vacusrpar.f'/;
       }
       print $line,"$comment\n";
    }
}
#===========================================================================
sub format90 {
   local($line)=@_;

   # If line is not too long return
   return($line) if length($line)<=$maxlen;

   # opedit: I don't want you to break concat symbols
   return($line) if ($line =~ /\/\//);

   # opedit: I don't want you to break print symbols
   return($line) if ($line =~ /print*/);

   # BREAK LONG LINES INTO CONTINUATION LINES AND/OR REDUCE INDENTATION
   local($bestlen,$goodlen,$len,$maxindent,$indent,$indentnow,$c,$answer);

   # Determine line indentation. If too much, reduce it to maximum.
   $maxindent=int(0.6*$maxlen);
   $line=~s/^( {0,$maxindent}) */$1/; $indent=$1;

   # We are happy if the length of the line is between $goodlen and $maxlen
   $goodlen=$maxlen-20;

   # Start breaking line
   while(length($line)>$maxlen){
       # Check for semicolon
       if(($len=rindex($line,';',$maxlen-1))>=0){
          $answer.=substr($line,0,$len)."\n";
          $line=substr($line,$len+1); $line=~s/^ */$indent/;
          next;
       }
       # Find best breakpoint after indentation but before $maxlen-2
       $line=~/^ */; 
       $bestlen=$indentnow=length($&);
       foreach $c ('=>','<=','+','-','/','**','*','.or.','.and.','>','<','==','=',
                   ',',' ','(',')'){
          if(($len=rindex($line,$c,$maxlen-length($c)))>=0){
             $len+=length($c) if ($c eq ',' || $c eq ' ' || $c eq ')');
             $bestlen=$len if $len>$bestlen;
             last if $bestlen>$goodlen;
          }
       }
       if($bestlen>$indentnow){
          # Collect broken parts in $answer and break the continuation further
          $answer.=substr($line,0,$bestlen)."&\n";
          $line="$indent$sss".substr($line,$bestlen);
       }else{
          # No break was found. Remove indentation if there is any or die.
          $line=~s/^ +// || die "Couldn't break line:".&unquote($line) 
       }
   }
   $answer.=$line;
}
#===========================================================================
sub quotation{
   # Hide quoted strings by converting them from 0-127 to 128-255 ASCII.
   # Only matched quotation marks ( ' and " ) count.
   local($line)=@_; local($head,$q);

   # From left to right invert quoted text into $head. The rest is in $line.
   while($line=~/(['"])/){
      $head.=$`; $q=$1; $line=$';
      # Check for matching quotation mark. If found, convert quoted part.
      if($line=~/$q/){$q="$q$`$q"; $line=$'; $q=~tr/\x00-\x7f/\x80-\xff/;}
      $head.=$q;
   }
   # return result
   $head.$line;
   
}
#===========================================================================
sub unquote{
    # Uncover hidden quotations by deleting 8-th bit.
    local($line)=@_;
    $line=~tr/\x80-\xff/\x00-\x7f/;
    $line;
}
