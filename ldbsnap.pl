#!/usr/bin/perl
# --------------------------------------------------------------------
# ldbsnap.pl
#
# $Id: ldbsnap.pl,v 1.9 2019/02/07 04:18:55 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a GET SNAPSHOT FOR ALL DATABASES command
#
# Usage:
#   ldbsnap.pl  database  [parameter]
#
# $Name:  $
#
# ChangeLog:
# $Log: ldbsnap.pl,v $
# Revision 1.9  2019/02/07 04:18:55  db2admin
# remove timeAdd from the use list as the module is no longer provided
#
# Revision 1.8  2019/01/25 03:12:41  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
# Revision 1.7  2018/10/21 21:01:50  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.6  2018/10/18 22:58:51  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.5  2018/10/17 01:07:53  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.4  2017/04/24 02:13:34  db2admin
# ensure database is upper case
#
# Revision 1.3  2014/05/25 22:26:54  db2admin
# correct the allocation of windows include directory
#
# Revision 1.2  2011/11/16 00:52:54  db2admin
# make database name comparison case insensitive
#
# Revision 1.1  2011/11/15 23:21:48  db2admin
# Initial revision
#
# --------------------------------------------------------------------

my $ID = '$Id: ldbsnap.pl,v 1.9 2019/02/07 04:18:55 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

# Global Variables

my $debugLevel = 0;
my $machine;   # machine we are running on
my $OS;        # OS running on
my $scriptDir; # directory the script ois running out of
my $tmp ;
my $machine_info;
my @mach_info;
my $logDir;
my $dirSep;
my $tempDir;

BEGIN {
  if ( $^O eq "MSWin32") {
    $machine = `hostname`;
    $OS = "Windows";
    $scriptDir = 'c:\udbdba\scripts';
    my $tmp = rindex($0,'\\');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
    $logDir = 'logs\\';
    $tmp = rindex($0,'\\');
    $dirSep = '\\';
    $tempDir = 'c:\temp\\';
  }
  else {
    $machine = `uname -n`;
    $machine_info = `uname -a`;
    @mach_info = split(/\s+/,$machine_info);
    $OS = $mach_info[0] . " " . $mach_info[2];
    $scriptDir = "scripts";
    my $tmp = rindex($0,'/');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
    $logDir = `cd; pwd`;
    chomp $logDir;
    $logDir .= '/logs/';
    $dirSep = '/';
    $tempDir = '/var/tmp/';
  }
}
use lib "$scriptDir";
use commonFunctions qw(trim ltrim rtrim commonVersion getOpt myDate $getOpt_web $getOpt_optName $getOpt_min_match $getOpt_optValue getOpt_form @myDate_ReturnDesc $cF_debugLevel  $getOpt_calledBy $parmSeparators processDirectory $maxDepth $fileCnt $dirCnt localDateTime displayMinutes timeDiff  timeAdj convertToTimestamp getCurrentTimestamp);

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print STDERR "\n$_[0]\n\n";
    }
  }

  print STDERR "Usage: $0 -?hs [-d <database>] [-p <search parm>] [-V <search string>] [-f <filename> [-x|X]] [-v[v]]

       Script to format the output of a GET SNAPSHOT FOR ALL DATABASES command

       Version $Version Last Changed on $Changed (UTC)

       -h or -?         : This help message
       -s               : Silent mode
       -d               : database to list
       -D               : show detail
       -p               : parameter to list (default: All) [case insensitive]
       -V               : search string anywhere (in either parm, desc or value)
       -f               : Input comparison file
       -x               : only print out differing values from the comparison file
       -X               : only print out differing values from the comparison file (use file values for the commands)
       -v               : set debug level

       This script formats the output of a GET SNAPSHOT FOR ALL DATABASES command

       NOTE: -x only has an effect if -g is specified
             -X only has an effect if -f and -g are specified
     \n";
}

# Set default values for variables

$silent = "No";
$printRep = "Yes";
$PARMName = "All";
$database = "All";
$compFile = "";
$debugLevel = 0;
$onlyDiff = "No";
$useFile = "No";
$search = "All";
$showDetail = "No";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsf:vxXDd:V:p:";

$getOpt_optName = "";
$getOpt_optValue = "";

while ( getOpt($getOpt_opt) ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s") )  {
   $silent = "Yes";
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Database $getOpt_optValue will be listed\n";
   }
   $database = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "D"))  {
   $showDetail = "Yes";
   if ( $silent ne "Yes") {
     print "Detail will be shown\n";
   }
 }
 elsif (($getOpt_optName eq "x"))  {
   if ( $silent ne "Yes") {
     print "Only entries containing different comparison values will be displayed\n";
   }
   $onlyDiff = "Yes";
 }
 elsif (($getOpt_optName eq "X"))  {
   if ( $silent ne "Yes") {
     print "The update commands will use the values from the file\n";
   }
   $useFile = "Yes";
   $onlyDiff = "Yes";
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "Comparison file will be $getOpt_optValue\n";
   }
   $compFile = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "p"))  {
   if ( $silent ne "Yes") {
     print "Only entries containing $getOpt_optValue will be displayed\n";
   }
   $PARMName = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "V"))  {
   if ( $silent ne "Yes") {
     print "Entries containing $getOpt_optValue anywhere will be displayed\n";
   }
   $search = uc($getOpt_optValue);
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $database eq "All") {
     if ( $silent ne "Yes") {
       print "Database $getOpt_optValue will be listed\n";
     }
     $database = uc($getOpt_optValue);
   }
   elsif ( $PARMName eq "All") {
     if ( $silent ne "Yes") {
       print "Only entries containing $getOpt_optValue will be displayed\n";
     }
     $PARMName = uc($getOpt_optValue);
   }
   else {
     usage ("Parameter $getOpt_optValue is unknown");
     exit;
   }
 }
}

# ----------------------------------------------------
# -- End of Parameter Section
# ----------------------------------------------------

chomp $machine;
@ShortDay = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
$minute = substr("0" . $minute, length($minute)-1,2);
$second = substr("0" . $second, length($second)-1,2);
$month = substr("0" . $month, length($month)-1,2);
$day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
$Now = "$year.$month.$day $hour:$minute:$second";
$NowDayName = "$year/$month/$day ($ShortDay[$dayOfWeek])";
$NowTS = "$year-$month-$day-$hour.$minute.$second";
$YYYYMMDD = "$year$month$day";

if ($silent ne "Yes") {
  if ($database eq "All") {
    print "All databases will be displayed\n";
  }
}

if ($silent ne "Yes") {
  if ($PARMName eq "All") {
    print "All parameters will be displayed\n";
  }
}

if ( $compFile ne "" ) {
  ################################################################
  # This code is not written yet - still the same as ldbcfg.pl  ##
  ################################################################
  # load up comparison file
  if (! open(COMPF, "<$compFile") ) { die "Unable to open $compFile for input \n $!\n"; }
  while (<COMPF>) {

    if ( $debugLevel > 0 ) { print ">> $_";}

    if ( $_ =~ /Database Manager Configuration/ ) { 
      die "File $compFile is a Database Manager Configuration file.\nA Database Configuration file is required\n\n";
    }

    $COMPF_input = $_;
    @COMPF_dbcfginfo = split(/=/);
    @COMPF_wordinfo = split(/\s+/);

    $COMPF_PRMNAME = "";
    if ( /\(([^\(]*)\) =/ ) {
      $COMPF_PRMNAME = $1;
      $validPARM{$COMPF_PRMNAME} = 1;
    }
    if ( ($COMPF_PRMNAME eq "") && ( defined($COMPF_dbcfginfo[0])) ) {
      $COMPF_PRMNAME = trim($COMPF_dbcfginfo[0]);
    }
    
    if ( $debugLevel > 0 ) { print "COMPF ParmName is $COMPF_PRMNAME\n"; }

    if ($COMPF_PRMNAME ne "") {
      chomp  $COMPF_dbcfginfo[1];
      if ( $COMPF_dbcfginfo[1] =~ /AUTOMATIC\(/ ) { # dont keep the current value
        if ( $debugLevel > 0 ) { print "COMPF_dbcfginfo[1] set to AUTOMATIC\n"; }
        $COMPF_dbcfginfo[1] = "AUTOMATIC";
      }
      $compDBCFG{$COMPF_PRMNAME} = $COMPF_dbcfginfo[1];
      if ( $debugLevel > 0 ) { print "Parameter $COMPF_PRMNAME has been loaded with parm $COMPF_dbcfginfo[1]\n"; }
    }
  }
  close COMPF;
}

if (! open(STDCMD, ">getdbcfgcmd.bat") ) {
  die "Unable to open a file to hold the commands to run $!\n"; 
} 

print STDCMD "db2 get snapshot for all databases\n";

close STDCMD;

$pos = "";
if ($OS ne "Windows") {
  $t = `chmod a+x getdbcfgcmd.bat`;
  $pos = "./";
}

if (! open (GETDBCMDPIPE,"${pos}getdbcfgcmd.bat |"))  {
        die "Can't run getdbcfgcmd.bat! $!\n";
    }

$maxData = 0;
$printRep = "No";
if ( $database eq "All" ) {
  $printRep = "Yes";
}

while (<GETDBCMDPIPE>) {
    # parse the db2 get db cfg output

    $input = $_;
    chomp $_;
    @dbcfginfo = split(/=/);
    @wordinfo = split(/\s+/);

    $PRMNAME = "";
    if ( /\(([^\(]*)\) =/ ) {
      $PRMNAME = $1;
    }
    if ( ($PRMNAME eq "") && ( defined($dbcfginfo[0])) ) {
      $PRMNAME = trim($dbcfginfo[0]);
    }

    if ( $debugLevel > 0 ) { print "Parm Name $PRMNAME is being processed\n"; }

    $compValue = "";
    if ( defined ( $compDBCFG{$PRMNAME} ) ) { # if the entry exists in the comparison file
      if ( $debugLevel > 1 ) { print "Comparison value exists and is $compDBCFG{$PRMNAME}\n"; }
      $compValue = $compDBCFG{$PRMNAME};
    }
    if ( $debugLevel > 1 ) { print "Lookup for parameter '$PRMNAME' has finished\n"; }

    if ( $input =~ /Database name/ ) {
      $DBName = trim($dbcfginfo[1]);
      chomp $DBName;
      if ( $DBName ne "" ) {
        if ( ($database eq "All" ) || ( $database eq uc($DBName) ) ) {
          $printRep = "Yes";
          print ">>>>>> Processing for database $DBName\n";
        }
        else {
          $printRep = "No";
        }
      }
    }

    $display = "Yes";
    if ( ($PARMName ne "All") && ( uc($dbcfginfo[0]) !~ /$PARMName/ ) ) { # search parm not found
      $display = "No";
    }
    elsif ( ($search ne "All") && ( uc($input) !~ /$search/ ) ) {     # search parm not found
      $display = "No";
    }

    if ( $display eq "Yes" ) {

      if ( $debugLevel > 1 ) { print "Parm Name $PRMNAME has been selected for processing\n"; }

      chomp  $dbcfginfo[1];
      $prmval = $dbcfginfo[1];
      if ( $dbcfginfo[1] =~ /AUTOMATIC\(/ ) {
        if ( $debugLevel > 1 ) { print "AUTO Check : $dbcfginfo[1] contains AUTO\n"; }
        $prmval = "AUTOMATIC";
      }
      if ( $debugLevel > 1 ) { print "$dbcfginfo[1] \>\> $prmval\n"; }

      if ( $debugLevel > 1 ) { print "Parm Name $dbcfginfo[0] has a value of $prmval\n"; }

      # Generate the report if it is required

      if ( $printRep eq "Yes" ) {
        if ( $PRMNAME ne "" ) {
          if ( $compFile ne "" ) {
            if ( $compValue ne  $prmval ) {
              print "$_  << File Value = $compDBCFG{$PRMNAME}\n";
            }
            else {
              print "$_ \n";
            }
          }
          else {
            print "$_ \n";
          }
        }      
        else {
          print "$_ \n";
        }
      }
    }
}

if ($OS eq "Windows" ) {
 `del getdbcfgcmd.bat`;
}
else {
 `rm getdbcfgcmd.bat`;
}
