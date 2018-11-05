package CbhXml;
use Exporter qw(import);
use IO::File;
use File::Copy;
use File::Slurp;
use Encode qw(encode decode);

use Data::Dumper;
our @EXPORT_OK = qw(read_xml_text read_xml_file write_xml_text write_xml_file run_tree mv_file flush_write_waiting);
use XML::Simple;


sub read_xml_text {
  my ($text) = @_;
  my %empty;
  my $tref = \%empty;
  my $ref = eval {XMLin($text, "ForceArray"=>1, "KeyAttr"=>"fname")};
  if ($@) {
    print "Invalid XML, don't read it in; $text\n"
  } else {
    if (exists $$ref{"anon"}) {
      $tref =  $$ref{"anon"};
    } elsif (exists $$ref{"fr"}) {
      $tref =  $$ref{"fr"};
    }

    if (ref($tref) eq "HASH" ) {
    } else {
      #my %empty;
      $tref = \%empty;
    }
    #print Dumper $tref;
  }
  return $tref
}


sub read_xml_file {
  my ($file) = @_;
  my $tref;
  my %empty;
  $tref = \%empty;
  if (-e $file) {
    my $txt = read_file($file, binmode => ':utf8');
    $tref = read_xml_text($txt)
  }
  return $tref
}
sub write_xml_text {
  my ($xml_list) = @_;
  my $xs = XML::Simple->new(Rootname => 'dr');
  my $xml_txt = $xs->XMLout({fr => $xml_list}, "KeyAttr"=>"fname");

  #print "Generatin xml, from\n";
  #print Dumper $xml_list;
  #print "\nXml:\n";
  #print Dumper $xml_txt . "\n";
  return encode('UTF-8',$xml_txt);
}
sub write_xml_file {
  my ($file_name, $xml_list) = @_;
  my $xmlf = $file_name;
  my $fh;
  for (my $create_attempt = 10; $create_attempt>0; $create_attempt--) {
    open ($fh, '>', $xmlf);
    if ($! =~/Permission/) {
      print "Permission problem on $xmlf, attempt $create_attempt\n";
      if ($create_attempt==1) {die "Too many create attempts for $xmlf\n";}
      #my $perm = (stat $fh)[2] & 07777;
      #chmod($perm | 0600, $fh);
      close $fh;
      chmod (0644, $xmlf);
      #sleep 1;
      next;
    } elsif ($! eq "" or $! =~ /Inappropriate ioctl for device/) {
      #print "Opened  $xmlf, $!\n";
      last;
    } else {
     #die "Can't open '$xmlf': $!";
    }
  }
  my $xml_txt = write_xml_text($xml_list);
  #print  $xml_txt ;
  print $fh $xml_txt or die "WHY?\n$xmlf\n";
  close $fh;
}

sub run_tree {
  my ($dir, $dir_file_desc, $pdir_func, $zero_func, $gen_func,$cfg_map) = @_;
  opendir(my $dh, $dir) or die "No DIR found: $dir\n";

  my $file_count = 0;
  while (readdir $dh) {
    $file_count++;
    my $filen = "$dir/$_";
    my $local_filen = $_;
    #print "Looking at file $_, $filen\n";
    if ($_ =~ /^\./) {
      #print "Hidden file/directory $filen\n";
      if ($_ =~ /\.md5_list\.xml/ ) {
        # our xml file does not count towards determining if this is an empty directory
        $file_count--;
      }
    } elsif (-d $filen) {
      #it's a directory
      #print "Going into directory $filen\n";
      if ($filen =~ /^vic$/) {} else {
        &$pdir_func($filen,$local_filen,$dir_file_desc,$cfg_map,$dir);

	      # It's possible that we delete this directory
	      if (-e $filen) {} else {
          # If it has been deleted
          $file_count--;
	      }
      }
    } elsif (-z $filen) {
      # delete any zero length files
      &$zero_func($filen,$local_filen,$dir_file_desc,"",$dir);
      $file_count--;
    } else {
      #print "Rinning on $filen,$local_filen,$dir\n";
      #die "Nil hash" if $dir_file_desc eq "";
      &$gen_func($filen,$local_filen,$dir_file_desc,"",$dir);
    }
  }
  closedir $dh;
  return $file_count;
}

my $cached_dirname = "-1";
my $cached_xml;
my $write_xml_waiting = "";
my $write_xml;
sub mv_file {
  use File::Basename;
  my ($old_filename, $new_filename) = @_;
  print "move $old_filename to $new_filename\n";
  move($old_filename, $new_filename);
  my $old_fn = fileparse($old_filename);
  my $new_fn = fileparse($new_filename);
  my $old_filename_dir = dirname($old_filename);
  my $new_filename_dir = dirname($new_filename);
  #print "Old file $old_filename lives in directory $old_filename_dir\n";
  #print "Old file $new_filename lives in directory $new_filename_dir\n";
  my $old_xml_fn;
  my $old_hash;
  $old_xml_fn = "$old_filename_dir/.md5_list.xml";
  if ($cached_dirname == $old_filename_dir) {
    $old_hash = $cached_xml;

  } else {
    flush_write_waiting();
    $cached_dirname = $old_filename_dir;
    $old_hash = read_xml_file($old_xml_fn);
    $cached_xml = $old_hash;
  }
  my $old_file_params;
  if (exists $$old_hash{$old_fn}) {
    $old_file_params = $$old_hash{$old_fn};
  } else {
    #die "$old_filename doesn't have a checksum\n";
  }

  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
      $atime,$mtime,$ctime,$blksize,$blocks)
      = stat($new_filename);

  # The checksum and tags shouldn't change
  $$old_file_params{"mtime"} = $mtime;
  $$old_file_params{"fname"} = $new_fn;
  $$old_file_params{"size"}  = $size;


  my $new_xml_fn = "$new_filename_dir/.md5_list.xml";
  my $new_hash;
  if ($new_xml_fn eq $old_xml_fn) {
    $new_hash = $old_hash;
    delete($$new_hash{$old_fn});
    $cached_xml = $new_hash;
  } else {
    $new_hash = read_xml_file($new_xml_fn);
  }
  $$new_hash{$new_fn} = $old_file_params;
  #print "Updated details\n";
  #print Dumper $new_hash;
  # Now write it out
  if ($write_xml_waiting ne $new_xml_fn) {
    flush_write_waiting();
  }
  $write_xml_waiting = $new_xml_fn;
  $write_xml = $new_hash;
  #write_xml_file($new_xml_fn,$new_hash);

}
sub flush_write_waiting {
  if ($write_xml_waiting ne "") {
    write_xml_file($write_xml_waiting,$write_xml);
  }
  $write_xml_waiting = "";
}






1;
