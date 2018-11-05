#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use XML::Simple;
use Cwd;
use File::Basename;
use File::Copy;
use lib '/home/cbh/home/script/perl';

use CbhXml qw(read_xml_file write_xml_file run_tree mv_file flush_write_waiting);
my @master_struct;
my @exclusions = ("dv", "sites");
my @fexclusions = (".jpg\$");
my @strippers = ("mp4", "mpeg", "mpg",
              "flv","wmv","avi",
  '\.$');
sub gen_it {
  my ($filen, $local_filen, $dir_file_desc) = @_;

  my $file_details = $$dir_file_desc{$local_filen};
  
  my ($filename,$path) = fileparse($filen);
 
  foreach (@exclusions) {
      if ($path =~ /$_/) {
          return
      }
  }
  foreach (@fexclusions) {
      if ($filename =~ /$_/) {
          return
      }
  }
  $path =~ s/(.*\/cat\/[\w_]+\/).*/$1/;
  $path = lc($path);
  my $mfilename = lc($filename);
  foreach (@strippers) {
      $mfilename =~ s/$_//g;
  }
  $mfilename =~ s/[^a-zA-Z]/ /g;  # We're only interested in the words.
  $mfilename =~ s/[_]/ /g;
  $mfilename =~ s/\s\w\s/ /g;
  $mfilename =~ s/\s+/ /g;
  $mfilename =~ s/\s\w?$//g;
  my %entry = ("class"=>$path,"sentence"=>$mfilename);
  push(@master_struct, \%entry);
  #push(@master_struct, $filename);
  #if (defined $$file_details{"tags"}) {
  #  print("$local_filen has tags:");
  #  my $tags = @$file_details{"tags"};
  #  #print Dumper @$tags;
  #  my $comma = "";
  #  foreach (@$tags){
  #    print "$comma$_";
  #    $comma = ","
  #  }
  #  #rint Dumper $$file_details{"tags"};
  #  print ("\n")
  #}
      #push(@file_list, $filen)
}

sub proc_dir {
  my ($dir) = @_;
  my $xml_fn = "$dir/.md5_list.xml";

  # Read in our XML description
  my $dir_file_desc = read_xml_file($xml_fn);

  # Run through the tree and update dir_file_desc accordingly
  my $file_count = run_tree($dir,     # dir handle and directory to process
                            $dir_file_desc,# description hash to update
                            \&proc_dir,    # funcrion to run on each found directory
                            \&zero_func,    # function to run when we find a zero length file
			    \&gen_it,      # Function to run on other files
			    );
}
sub zero_func {
  my ($filen, $local_filen, $dir_file_desc) = @_;
}


sub proc_main {
  # This is a map from file name to the file description structure
  my %file_map;
  my ($dir) = @_;
  my $cwd = getcwd;
  print "Processing Argument $dir, $cwd\n";
  if ($dir =~ /^\//) {
    print "$dir is an absolute path\n";
  } elsif ($dir eq "." ) {
    print "$dir is $cwd\n";
    $dir = $cwd;
  } else {
    print "$dir needs a relative path\n";
    $dir = "$cwd/$dir";
    print "Modified path to $dir\n";
  }
  # For the supplied directory
  # generate the map to the file descriptors
  &proc_dir($dir)
}

use JSON;
use List::Util 'shuffle';

foreach my $argy (@ARGV) {
  &proc_main($argy);

  @master_struct = shuffle(@master_struct);
  my $msl = scalar @master_struct;

  if ($msl <2) {
     print("Not enough to create a training set", $msl);
     exit
  }
  my $td_len = int($msl/2);
  my $cd_len =  $msl-$td_len;

  my @test_array = splice @master_struct, 0, $td_len;
  if ((scalar @master_struct) != $cd_len) {
    printf ("Splice error %d, %d", scalar @master_struct, $cd_len);
    exit
  }
  my @cd_array = @master_struct;
  my $tdf = "training_data.json";
  my $cdf = "check_data.json";
  if ((scalar @test_array) >0) {
    open my $tfh, ">", $tdf;
    print $tfh JSON->new->utf8->pretty(1)->encode(\@test_array);
    close $tfh;
  } else {
      print "No test data produced"
  }
  if ((scalar @cd_array) >0) {
    open my $cfh, ">", $cdf;
    print $cfh JSON->new->utf8->pretty(1)->encode(\@cd_array);
    close $cfh;
  } else {
      print "No check data produced"
  }
}

