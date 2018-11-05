package CbhTag;
use Exporter qw(import);
use strict;
use warnings;


use Getopt::Long;
use Data::Dumper;
use XML::Simple;
use Cwd;
use lib '/home/cbh/home/script/perl';
use CbhXml qw(read_xml_file write_xml_file run_tree mv_file flush_write_waiting);
our @EXPORT_OK = qw(atag_dir mtag_dir check_tags new_tg new_action );

sub zero_func {
  my ($filen, $local_filen, $dir_file_desc) = @_;
}
sub create_default {
  my ($filen, $local_filen, $dir_file_desc) = @_;

  my $dd = $$dir_file_desc{$local_filen};
  #print Dumper $dd;
  if (defined $dd) {
    # Nothing to do
    # Entry already exists
    return 
  }
  #print "Adding filename $local_filen\n";
  my %file_desc;
  $$dir_file_desc{$local_filen} = \%file_desc;
}



sub mtag_dir {
  my ($dir,$ld,$file_map) = @_;
  
  my $xml_fn = "$dir/.md5_list.xml";
  my $xml_fn_new = "$dir/.md5_list_new.xml";

  # Read in our XML description
  my $dir_file_desc = read_xml_file($xml_fn);

  # Run through the tree and update dir_file_desc accordingly
  my $file_count = run_tree($dir,     # dir handle and directory to process
                            $file_map,# description hash to update
                            \&mtag_dir,    # funcrion to run on each found directory
                            \&zero_func,    # function to run when we find a zero length file
                            \&create_default,      # Function to run on other files
                            );

  foreach my $fn (keys %$dir_file_desc) {
    #print "Creating an entry for $fn\n";
    my $file_details = $$dir_file_desc{$fn};
    my $new_fn = "$dir/$fn";
    $$file_map{$new_fn} = $file_details;
  }
}


sub get_tags {
  my ($filen,$file_map) = @_;
  if (exists $$file_map{$filen}) {
    my $file_desc = $$file_map{$filen};
    my $tag_array = $$file_desc{"tags"};
    if (defined $tag_array) {
      if (ref($tag_array) ne "ARRAY") {
        print Dumper $file_desc;
        my $ref_type = ref($tag_array);
        die "Invalid tag_array, $ref_type, $filen\n";
      }
    }
    return $tag_array;
  } else {
    print Dumper $file_map;
    die "$filen not a valid file\n";
  }
}
sub guess_filename {
  my ($new_filename) = @_;

  my $name_increment = 0;
  while (-e $new_filename) {
    print "$new_filename exists already\n";
    if ($new_filename =~ /^(.*?)(\(\d+\))?(\.\w+)$/) {
      $new_filename = "$1($name_increment)$3";
      print "Let's try calling it $new_filename\n";
      $name_increment++;
    } else {
      die "Can't process filename format";
    }
  }
  return $new_filename;
}
use File::Basename;
use File::Path qw( make_path );
sub match_action {
  # When we get a match then
  # move the file
  my ($fn, $dest,$cat_dir) = @_;

  if (!-d $cat_dir) {
    print ("Making $cat_dir\n");
    make_path $cat_dir or die "Failed to make $cat_dir\n";
  }
  if (!-d "$cat_dir$dest") {
    print ("Making $cat_dir$dest\n");
    my $dtm = "$cat_dir$dest";
    make_path $dtm or die "Failed to make $cat_dir$dest\n";
  }

  my($filename, $dirs, $suffix) = fileparse($fn);
  my $new_filename = guess_filename("$cat_dir$dest$filename$suffix");
  print "----\nfile $fn, move to $dest\n$new_filename\n";
  mv_file($fn, $new_filename);
  flush_write_waiting();
}

sub search_tag_lists {
  my ($fn, $tg_list, $tag_action, $hash,$cat_dir) = @_;

  for(my $i=0;$i<@$tg_list; $i++) {
    my $tg_list = @$tg_list[$i];
    #print "Searching for this tag list\n" . Dumper $tg_list;
    if (search_tag_list($tg_list,$hash,$fn)) {
      my $dest = @$tag_action[$i];
      match_action($fn,$dest,$cat_dir);
      return 1;
    }
  }
  return 0;
}

sub search_tag_list {
  my ($tgs_to_fnd, $hash,$fn) = @_;


  # This sub is given a list of tags to search for
  # and returns 1 if it finds them all
  # 0 otherwise
  my $all_found = 1;
  foreach my $tag (@$tgs_to_fnd) {
    if (exists $$hash{$tag}) {
      #print "Tag found in file $fn\n";
    } else {
      $all_found = 0;
    }
  }
  return $all_found
}
sub new_tg {
  return \@_;
}
sub new_action {
  my ($fn) = @_;
  if ($fn =~ /.*\/\s/) {
  } else {
    #ensure there is a training /
    $fn = "$fn/";
  }
  return $fn;
}


sub check_tags {
  my ($file_map, $tags_to_find, $tag_actions, $cat_dir) = @_;
  my %keys_to_delete;
  foreach my $fn (keys %$file_map) {
    #print "Checking tags for file $fn\n";
    my $tag_ref = get_tags($fn, $file_map);
    my %tmp_hash;
    foreach my $tag (@$tag_ref) {
      $tmp_hash{$tag} = 1;
    }
    # Search to see if it matches all of the tags supplied
    # and if it does, do the action
    if (search_tag_lists($fn, $tags_to_find, $tag_actions, \%tmp_hash,$cat_dir)) {
      # Mark the key as needing deleting from the hash
      $keys_to_delete{$fn} = 1
    }
  }
  foreach my $fn (keys %keys_to_delete) {
    #print "We should delete $fn from the map";
    delete($$file_map{$fn});
  }
}


sub tag_map {

  # Tag Map maps from one lot of tags to another (if needed)
  # If the tag is not specified in the tag map then nothing happens
  # also a tag may be mentioned several times, this tidies that up
  my ($cfg_map,@in_tags) = @_;
  my %current_tags;
  my @out_tags;
  my $tag_remap = $$cfg_map{"rmap"};
  foreach my $tg (@in_tags) {
    if (exists $$tag_remap{$tg}) {
      $tg = $$tag_remap{$tg};
    }
    $current_tags{$tg} = 1;
  }
  @out_tags = keys %current_tags;
  return @out_tags;
}

sub generate_tags {
  # This sub should accept a file name
  # and look at this and generate tags automatically.
  my ($filename,$dir, $tags,$cfg_map) = @_;
  #print "Generating tags for $dir/$filename\n";
  my $default_dtag = $$cfg_map{"dtag"};
  my $default_ftag = $$cfg_map{"ftag"};
  #print "cfg_map is:\n" . Dumper $cfg_map;
  #print "Dtag is:\n" . Dumper $default_dtag;
  #print "Ftag is:\n" . Dumper $default_ftag;

  $dir =~ s/.*\/home\/dtp\///;
  #print "Interesting dir is $dir\n";
  if ($dir =~ /cat/) {
    #print "This has been categorised\n";
    $dir =~ s/cat\///;

    foreach my $dt (@$default_dtag) {
      if ($dir =~ /$dt/i) {
        #print "Match against $dt\n";
        push(@$tags, $dt)
      }
    }
  }

  foreach my $ft (@$default_ftag) {
    if ($filename =~ /$ft/i) {
      push(@$tags, $ft)
    }
  }
  my @tags_after = tag_map($cfg_map,@$tags);

  return \@tags_after;
}

sub atag_dir {
  my ($dir,$ld,$df,$cfg_map) = @_;

  my $xml_fn = "$dir/.md5_list.xml";
  my $xml_fn_new = "$dir/.md5_list_new.xml";

  # Read in our XML description
  my $dir_file_desc = read_xml_file($xml_fn);

  # Run through the tree and update dir_file_desc accordingly
  my $file_count = run_tree($dir,     # dir handle and directory to process
                            $dir_file_desc,# description hash to update
                            \&atag_dir,    # funcrion to run on each found directory
                            \&zero_func,    # function to run when we find a zero length file
                            \&create_default,      # Function to run on other files
                            $cfg_map
                            );
  #print "Working with directory $dir\n:" . Dumper $cfg_map;
  #print "DFD is " . Dumper $dir_file_desc;



  # Now we create a new structure based on the one we read in
  # generating tags as we go
  foreach my $fn (keys %$dir_file_desc) {
    #print "Creating an entry for $fn\n";
    my $file_details = $$dir_file_desc{$fn};
    $$file_details{"fname"} = $fn;
    my @tags;
    if (ref( $$file_details{"tags"}) eq "ARRAY") {
      my $array_ref = @$file_details{"tags"};
      push(@tags,@$array_ref);
    }


    $$file_details{"tags"} = generate_tags($fn, $dir, \@tags,$cfg_map);
  }

  # Now write it out
  #print "\n\nWriting out\n\n" . Dumper $dir_file_desc;
  write_xml_file($xml_fn,$dir_file_desc)
} # end atag_dir





1;
