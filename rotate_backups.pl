#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use Getopt::Std;

my $bdir = "/media/pi_backup";
my %year_hash;
my $newest_year = 0;
# we want to keep all the ones in the most recent month
# We want to keep the oldest in the previous months
# we want to keep the oldest of each year

sub interpret {
  my ($fn) = @_;
  if ($fn =~ /(\d\d\d\d)_(\d\d)_(\d\d)\.tgz/) {
    my $year = $1;
    my $month = $2;
    my $date = $3;
    return ($year, $month, $date);
  }
  return (0,0,0);
}

sub pdir {
# The trick here is to return list of files we think need moving up the directory tree
  my ($dir) = @_;
  opendir(my $dh, $dir) or die "No DIR found: $dir\n";
  while (my $fn =  readdir ($dh)) {
    my ($year, $month, $date) = &interpret($fn);
    if ($year > $newest_year) {
      $newest_year = $year;
    }
    if ($year > 0) {
      print "File found $fn\n";
      my $month_hash_ref;
      my $date_hash_ref;
      if (exists $year_hash{$year}) {
        $month_hash_ref = $year_hash{$year}
      } else {
        my %month_hash;
        $month_hash_ref = \%month_hash;
      }
      if (exists $$month_hash_ref{$month}) {
        $date_hash_ref = $$month_hash_ref{$month};
      } else {
        my %date_hash;
        $date_hash_ref = \%date_hash;
      }
      $$date_hash_ref{$date} = "$dir/$fn";
      $$month_hash_ref{$month} = $date_hash_ref;
      $year_hash{$year} = $month_hash_ref;
    }    
  }
}
sub find_oldest_date {
  my $oldest_date = 999999;
  my ($date_hash_ref) = @_;
  foreach my $key (keys %$date_hash_ref) {
    if ($key < $oldest_date) {
      $oldest_date = $key;
    }
  }
  return $oldest_date;
}
sub find_new_old_month {
  my $newest_month = 0;
  my $oldest_month = 999999;
  my ($month_hash_ref) = @_;
  foreach my $key (keys %$month_hash_ref) {
    if ($key > $newest_month) {
      $newest_month = $key;
    }
    if ($key <  $oldest_month) {
      $oldest_month = $key;
    }
  }
  return ($newest_month, $oldest_month);
}

my %opts;
getopts('d', \%opts);
if (exists $opts{'d'}) {
  print "Will delete files\n"
}
&pdir($bdir);
my @to_delete;
print Dumper \%year_hash;
foreach my $year (keys %year_hash) {
  print "Looking at year: $year\n";
  my $month_hash_ref = $year_hash{$year};
  if ($year == $newest_year) {
    my ($newest_month, $oldest_month) = &find_new_old_month($month_hash_ref);
    foreach my $month (keys %$month_hash_ref) {
        # keep oldest date from every month
        my $date_hash_ref = $$month_hash_ref{$month};
        my $oldest_date = &find_oldest_date($date_hash_ref);
    
        foreach my $date (keys %$date_hash_ref) {
          #$fn = "$bdir/$year\_$month\_$date.tgz";
          my $fn = $$date_hash_ref{$date};
          if ($month == $newest_month || $date == $oldest_date) {
            print "Save $fn\n";
          } else {
            print "Delete $fn\n";          
            push @to_delete, $fn;
          }
        }
    }
  } else {
    my ($newest_month, $oldest_month) = &find_new_old_month($month_hash_ref);
    foreach my $month (keys %$month_hash_ref) {
      my $date_hash_ref = $$month_hash_ref{$month};
      my $oldest_date = &find_oldest_date($date_hash_ref);
      foreach my $date (keys %$date_hash_ref) {
        #$fn = "$bdir/$year\_$month\_$date.tgz";
        my $fn = $$date_hash_ref{$date};
        if ($month == $oldest_month && $date == $oldest_date) {
          print "Save $fn\n";
        } else {
          print "Delete $fn\n";
          push @to_delete, $fn;
        }
      }
    }
  }
}
#print Dumper %year_hash;
print Dumper \@to_delete;
if (exists $opts{'d'}) {
  unlink @to_delete;
}
