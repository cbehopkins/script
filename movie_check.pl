#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Digest::MD5;
#use String::Approx 'adist';
use String::ShellQuote;
use Image::ValidJpeg;

use XML::Simple;
use Cwd;
use lib '/home/cbh/home/script/perl';
use CbhXml qw(read_xml_file write_xml_file run_tree mv_file flush_write_waiting);


my @mov_list = ("wmv","mpg", "avi", "flv", "mp4");
sub ismov  {
  my ($fn) = @_;
  foreach (@mov_list) {
    if ($fn =~ /$_$/) {
    return 1
    }
  }
  return 0
}

my @files_to_delete;
my $delete;
my $immediate;
my $out_file;
my $lfile;
my $move_it;
my $result = GetOptions ( "delete" => \$delete, 
                          "immediate"=>\$immediate,
                          "out=s"=>\$out_file,
                          "log=s"=>\$lfile,
                          "mv=i"=>\$move_it
                        );
my $LOGFILE;



sub run_cmd {
  my ($lcmd, $largs) = @_;
  foreach (@$largs) {
    $lcmd = "$lcmd $_ ";
  }
  #print "Running command:$lcmd\n";
  my @lresult = `$lcmd 2>&1`;
  my $rc = $?>>8;
  return (\@lresult, $rc);
}

sub run_mcheck {
  my ($fname) = @_;
  my $cmd = "avconv";
  $fname = "\"$fname\"";
  my @args = qq( -v error -i $fname -f null - );
  my ($rr, $rc) = &run_cmd($cmd, \@args);

  if ($rc != 0) {
    print $LOGFILE "Error with $fname\n" or die "Can't write to log\n";
    print $LOGFILE "Error Code:$rc\nText:\n" or die "Can't write to log\n";
    print $LOGFILE @$rr or die "Can't write to log\n";
    return 0;
  }
  if ($rr ne "") {
    if (ref($rr) eq 'ARRAY') {
      my $len = scalar @$rr;
      #print ("Of length:", $len, "\n");
      if ($len == 0) {
        return 1;
      }
      print $LOGFILE "Error with $fname\n"  or die "Can't write to log\n";
      print $LOGFILE @$rr;
    } else {
      my $rt = ref($rr);
      print $LOGFILE "Error with $fname\n"  or die "Can't write to log\n";
      print $LOGFILE "Error type is:$rt\n";
    }
    return 0;
  }
  return 1;

}
# This is run on each file once
sub gen_it {
  my ($filen, $local_filen, $dir_file_desc, $cfg_map,$dir) = @_;
  if (!(ismov($local_filen))) {
    return
  }
  my $start_time = time();
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
      $atime,$mtime,$ctime,$blksize,$blocks)
        = stat($filen);
  my $checksum;
  #print "Looking for $local_filen\n";
  if (defined $$dir_file_desc{$local_filen}) {
    my $bob = $$dir_file_desc{$local_filen};
    # file has a definition
    if (defined $$bob{"analysed"}) {
      #print "Looking at file struct for:$local_filen\n";
      return;
    } else {
      print "Running Analysis of:$local_filen\n";
    }
  } else {
    my %file_details = (
                        "fname"=>$local_filen,
                        );
    $$dir_file_desc{$local_filen} = \%file_details;
  }
  my $r = run_mcheck($filen);
  if ($r != 1) {
    print "Result Error for:$filen\n";
  } else {
    $$dir_file_desc{$local_filen}{"analysed"} = 1;
  }
  # Since it takes so long to run
  my $diff = time() - $start_time;
  if ($diff > 10) {
    #my ($nsec, $nmin, $nhour, $nmday, $nmon, $nyear, $nwday, $nyday, $nisdst) = localtime(time());
    #my ($ssec, $smin, $shour, $smday, $smon, $syear, $swday, $syday, $sisdst) = localtime($start_time);
    #my ($dsec, $dmin, $dhour, $dmday, $dmon, $dyear, $dwday, $dyday, $disdst) = localtime($diff);
    #$dhour--; # I think the dst is causing us to have to do this, maybe??
    #print "Time is now $nhour:$nmin:$nsec\n";
    #print "Writing out xml as start time was $shour:$smin:$ssec and diff is $dhour:$dmin:$dsec $diff\n";
    my $xml_fn = "$dir/.md5_list.xml";
    write_xml_file($xml_fn,$dir_file_desc); 
  }
} #end gen_it
sub zero_func {
  my ($filen, $local_filen, $dir_file_desc, $cfg_map,$dir) = @_;
}


#######################################
# Process directories
#######################################
# Get a checksum of each file and then compare checksums
# Chances are if they are the same checksum they are the same file

sub proc_dir {
  my ($dir) = @_;
  my $xml_fn = "$dir/.md5_list.xml";

  # Read in our XML description
  my $dir_file_desc = read_xml_file($xml_fn);

  # Run through the tree and update dir_file_desc accordingly
  my $file_count = run_tree($dir,     # dir handle and directory to process
                            $dir_file_desc,# description hash to update
                            \&proc_dir,    # funcrion to run on each found directory
                            \&zero_func,   # function to run when we find a zero length file
			                      \&gen_it,      # Function to run on other files
			    );

  if ($file_count ==2) {
    print "This directory, $dir, is empty\n";
  } else {
    write_xml_file($xml_fn,$dir_file_desc);
  }
}


sub nil_func {}
sub proc_main {
    
    my ($dir) = @_;
    &proc_dir($dir);

}

my $log_fname = "./movie_check.log";
open($LOGFILE, "> $log_fname") or die "Can't open $log_fname, $!\n";

foreach my $argy (@ARGV) {
  print "Running proc_dir on $argy\n";
  proc_main($argy);
}

close($LOGFILE);
