#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use XML::Simple;
use Cwd;
use File::Basename;
use File::Copy;

my @tags_to_find;
my @tag_actions;
my @itags_to_find;
my @itag_actions;
#########################################
# Rules are more specific rules go first!
#########################################
sub pdir {
  # The trick here is to return list of files we think need moving up the directory tree
  my ($dir) = @_;	
  opendir(my $dh, $dir) or die "No DIR found: $dir\n";
  my @file_list;
  my $file_count = 0;
  my $dir_count = 0;
  my $dir_name;
  while (readdir $dh) {
    my $filen = "$dir/$_";
    if ($_ =~ /^\./) {
      #print "Hidden file/directory $filen\n";
    } elsif (-d $filen) {
      if (($filen eq ".") or ($filen eq "..")) {
      } else {
        $dir_count++;
        $dir_name = $filen;
      }
    } else {
      $file_count++;

    }
  }
  closedir $dh;

  if ($dir_count==1 && ($file_count==0)) {
   # We are a candidate for moving files down to the directory below us
    my $ref_fl =  pdir($dir_name);
    return $ref_fl;
  } else {
    opendir($dh, $dir) or die "No DIR found: $dir\n";
    while (readdir $dh) {
      my $filen = "$dir/$_";
      #print "Looking at file $_, $filen\n";
      if ($_ =~ /^\./) {
        #print "Hidden file/directory $filen\n";
      } elsif (-d $filen) {
        #it's a directory
        #print "Going into directory $filen\n";
        my $fl_ref = &pdir($filen);
        foreach (@$fl_ref) {
          my ($filename,$path) = fileparse($_);
          $path =~ s/(.*)\//$1/;
          if ($path ne $filen) {
            print "Sparse Move $filename, to $filen, $path\n";
            my $ret_c;
            $ret_c = move($_, $filen);
            if ($ret_c == 0) {
              die "Move of $_ to $filen failed because $!\n";
            }
          }
        }
      } else {
        # files just count as files
        push(@file_list, $filen)
      }
    }
    closedir $dh;
    return \@file_list;
  }
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
  &pdir($dir)
}

foreach my $argy (@ARGV) {
  &proc_main($argy);
}

