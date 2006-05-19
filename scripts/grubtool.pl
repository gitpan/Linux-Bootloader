#!/usr/bin/perl -w
#
# Modify bootloader config

use strict;
use Getopt::Long;

my %params;

GetOptions( 
  \%params,
  "bootloader=s",
  "config_file=s",
  "add-kernel=s",
  "remove-kernel=s",
  "title=s",
  "args=s",
  "initrd=s",
  "root=s",
  "savedefault=s",
  "position=s",
  "info=s",
  "make-default",
  "help",
  );

 
if (!(%params) || defined $params{help}) {
  &usage
}

$params{bootloader}="grub";
$params{config_file}='/boot/grub/menu.lst';

if (defined $params{'add-kernel'}) {
  &add(%params)
} elsif (defined $params{'remove-kernel'}) {
  &remove($params{config_file}, $params{'remove-kernel'})
} elsif (defined $params{info}) { 
  &print_info($params{config_file}, $params{info}) 
}


# Print usage info

sub usage {
  print "Usage: $0 \
    --add=<kernel path> --title=<kernel title> --args=<kernel args>
                        --initrd=<initrd path> --make-default
			--position=<position #|start|end>
    --remove=<position #>
    --info=<position #|default>
    --help
    --default\n";
  exit 1;
}




### GRUB functions ###

# Read grub config file into array
# Takes config_file as string, returns array

sub read {
  my $config_file=shift;
  my @config;
  print "Reading grub $config_file.\n";
  open(CONFIG, "$config_file") || die "Can't open $config_file.\n";
  @config=<CONFIG>;
  close(CONFIG);
  return @config;
}


# Parse grub config into array of hashes
# Takes config as array ptr, returns array of hashes

sub info {
  my $configRef=shift;
  my @config=@$configRef;
  my @sections;
  my $index;
  @config=grep(!/^#|^\n/, @config);
  $index=0;
  foreach (@config) {
    if ($_ =~ /^\s*default\s+(.*)/i) { 
      $sections[$index]{'default'} = $1; 
    } elsif ($_ =~ /^\s*timeout\s+(.*)/i) { 
      $sections[$index]{'timeout'} = $1; 
    } elsif ($_ =~ /^\s*fallback\s+(.*)/i) { 
      $sections[$index]{'fallback'} = $1; 
    } elsif ($_ =~ /^\s*title\s+(.*)/i) { 
      $index++; $sections[$index]{'title'} = $1;
    } elsif ($_ =~ /^\s*kernel\s+(\S+)\s+(.*)\n/i) { 
      $sections[$index]{'kernel'} = $1; 
      $sections[$index]{'args'} = $2; 
    } elsif ($_ =~ /^\s*root\s+(.*)/i) { 
      $sections[$index]{'root'} = $1; 
    } elsif ($_ =~ /^\s*initrd\s+(.*)/i) { 
      $sections[$index]{'initrd'} = $1;
    } elsif ($_ =~ /^\s*savedefault\s+(.*)/i) { 
      $sections[$index]{'savedefault'} = $1; 
    }
  }

  # sometimes config doesn't have a default, so goes to first
  if (!(defined $sections[0]{'default'})) { 
    $sections[0]{'default'} = '0'; 
  }

  # return array of hashes
  return @sections;
}


# Determine current default kernel
# Takes config as array ptr, returns string

sub get_default {
  my $configRef=shift;
  my @config=@$configRef;
  my @sections=info(\@config);
  my $default=$sections[0]{'default'};

  my @default_config;
  if ($default =~ /saved/i) { 
    open(DEFAULT_FILE, '/boot/grub/default') || die "no default file.\n";
    @default_config = <DEFAULT_FILE>;
    close(DEFAULT_FILE);
    $default_config[0] =~ /^(\d)/;
    $default = $1;
  }
  return ($default);
}


# Set new default kernel
# Takes new default as string and config as array ptr, returns array

sub set_default {
  my $newdefault=shift;
  my $configRef=shift;
  my @config=@$configRef;
 
  foreach my $index (0..$#config) {
    if ($config[$index] =~ /^\s*default/i) { 
      $config[$index] = "default $newdefault	# set by $0\n"; 
      last;
    } elsif ($config[$index] =~ /^\s*default\ssaved/i) {
      my @default_config;
      my $default_config_file='/boot/grub/default';
      open(DEFAULT_FILE, $default_config_file) || die "no default file.\n";
      @default_config = <DEFAULT_FILE>;
      close(DEFAULT_FILE);
      $default_config[0] = "$newdefault\n";
      &write($default_config_file, \@default_config);
      last;
    }
  }
  return @config;
}


# Print info from grub config
# Takes config_file as string, returns nothing

sub print_info {
  my $config_file=shift;
  my $info=shift;
  my @config=&read($config_file);
  my @sections=&info(\@config);

  my ($index,$start,$end);
  if ($info =~ /default/i) { 
    $start=$end=&get_default(\@config) 
  } elsif ($info =~ /all/i) { 
    $start=0; $end=$#sections-1 
  } elsif ($info =~ /\d+/) { 
    $start=$end=$info 
  }
  if ($start < -1 || $end > $#sections-1) { 
    die "No kernels with that index.\n";
  }

  for $index ($start..$end) {
    print "\nindex: $index\n";
    $index++;
    foreach (keys(%{$sections[$index]})) {
      print "$_: $sections[$index]{$_}\n";
    }
  }
}


# Write new config
# Takes config_file as string and config as array ptr, returns nothing

sub write {
  my $config_file=shift;
  my $configRef=shift;
  my @config=@$configRef;
  print "Writing grub $config_file.\n";

  #system("cp","$config_file","$config_file.bak.$0");
  #if ($? != 0) { die "Cannot backup $config_file.\n"; }
  #open(CONFIG, ">$config_file") || die "Can't open config file.\n";
  #print CONFIG join("",@config);
  print join("",@config);
  #close(CONFIG);
}


# Add new kernel to grub config
# Takes hash, returns nothing

sub add {
  my %param=@_;

  if (!(-e "$param{'add-kernel'}")) { 
    die "can't find $param{'add-kernel'}!\n"; 
  }

  my @config=&read($param{config_file});
  my $default=&get_default(\@config);
  my @sections=&info(\@config);

  $default++;
  if (!(defined $param{args})) { 
    $param{args}=$sections[$default]{'args'} 
  }
  if (!(defined $param{root})) { 
    $param{root}=$sections[$default]{'root'} 
  }
  if (!(defined $param{savedefault})) { 
    $param{savedefault}=$sections[$default]{'savedefault'} 
  }

  # use default entry to determine if path (/boot) should be removed
  if ($sections[$default]{'kernel'} !~ /^\/boot/) {
    $param{'add-kernel'} =~ s/^\/boot//;
    $param{'initrd'} =~ s/^\/boot//;
  }

  my @newkernel;
  push (@newkernel, "title\t$param{title}\n", "\troot\t$param{root}\n", "\tkernel\t$param{'add-kernel'} $param{args}\n");
  if (defined $param{initrd}) { 
    push(@newkernel, "\tinitrd\t$param{initrd}\n") 
  }
  if (defined $param{savedefault}) { 
    push(@newkernel, "\tsavedefault\t$param{savedefault}\n") 
  }
  push (@newkernel, "\n");

  if ($param{position} !~ /end|\d+/) { 
    $param{position}=0 
  }

  my @newconfig;
  if ($param{position}=~/end/ || $param{position} >= $#sections) { 
    $param{position}=$#sections;
    push (@newconfig,@config);
    if ($newconfig[$#newconfig] =~ /\S/) { 
      push (@newconfig, "\n"); 
    }
    push (@newconfig,@newkernel);
  } else {
    my $index=0;
    foreach (@config) {
      if ($_ =~ /^\s*title/i) { 
        if ($index==$param{position}) { 
          push (@newconfig, @newkernel); 
        }
        $index++;
      }
      push (@newconfig, $_);
    }
  }
  if (defined $param{'make-default'}) { 
    @newconfig = &set_default($param{position}, \@newconfig);
  }
  &write($param{config_file}, \@newconfig);
}


# Remove kernel from grub config
# Takes config_file and position as strings, returns nothing

sub remove {
  my $config_file=shift;
  my $position=shift;
  my @newconfig;
  my @config=&read($config_file);

  print "Removing kernel $position.\n";

  if ($position < 0) {
    die "Enter a position >= 0.\n";
  }

  my $index=-1;
  foreach (@config) {
    if ($_ =~ /^\s*title/i) { 
      $index++ 
    }
    if ($index != $position) { 
      push (@newconfig, $_) 
    }
  }
  &write($config_file, \@newconfig);
}
