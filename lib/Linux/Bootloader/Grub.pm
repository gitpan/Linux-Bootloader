package Linux::Bootloader::Grub;

=head1 NAME

Linux::Bootloader::Grub - Parse and modify GRUB configuration files.

=head1 SYNOPSIS

	use Linux::Bootloader;
	use Linux::Bootloader::Grub;

	$bootloader = Linux::Bootloader::Grub->new();
        my $config_file='/boot/grub/menu.lst';

        $bootloader->read($config_file);

	# add a kernel	
	$bootloader->add(%hash)

	# remove a kernel
	$bootloader->remove(2)

	# print config info
	$bootloader->print_info('all')

	# set new default
	$bootloader->set_default(1)

        $bootloader->write($config_file);


=head1 DESCRIPTION

This module provides functions for working with GRUB configuration files.

	Adding a kernel:
	- add kernel at start, end, or any index position.
	- kernel path and title are required.
	- root, kernel args, initrd, savedefault are optional.
	- any options not specified are copied from default.
	- remove any conflicting kernels first if force is specified.
	
	Removing a kernel:
	- remove by index position
	- or by title/label


=head1 FUNCTIONS

Also see L<Linux::Bootloader> for functions available from the base class.

=head2 new()

	Creates a new Linux::Bootloader::Grub object.

=head2 _info()

	Parse config into array of hashes.
	Takes: nothing.
	Returns: undef on error.

=head2 set_default()

	Set new default kernel.
	Takes: integer.
	Returns: undef on error.

=head2 add()

	Add new kernel to config.
	Takes: hash.
	Returns: undef on error.

=head2 update()

        Update args of an existing kernel entry.
        Takes: hash.
        Returns: undef on error.

=cut

use strict;
use warnings;
use Linux::Bootloader

@Linux::Bootloader::Grub::ISA = qw(Linux::Bootloader);
use base 'Linux::Bootloader';


use vars qw( $VERSION );
our $VERSION = '0.0';


sub new {
    my $class = shift;
    my $self = bless({}, $class);
    #my $self = fields::new($class);

    $self->{'config'}   = [];
    $self->{'debug'}    = 0;

    $self->SUPER::new();

    return $self;
}


### GRUB functions ###

# Parse config into array of hashes

sub _info {
  my $self=shift;

  return undef unless $self->_check_config();

  my @config=@{$self->{config}};
  @config=grep(!/^#|^\n/, @config);

  my %matches = ( default => '^\s*default\s+(\S+)',
		  timeout => '^\s*timeout\s+(\S+)',
		  fallback => '^\s*fallback\s+(\S+)',
		  kernel => '^\s*kernel\s+(\S+)',
		  root 	=> '^\s*kernel\s+\S+\s+root=(\S+)',
		  args 	=> '^\s*kernel\s+\S+\s+root=\S+\s+(.*)\n',
		  boot 	=> '^\s*root\s+(.*)',
		  initrd => '^\s*initrd\s+(.*)',
		  savedefault => '^\s*savedefault\s+(.*)',
		);

  my @sections;
  my $index=0;
  foreach (@config) {
      if ($_ =~ /^\s*title\s+(.*)/i) {
        $index++;
        $sections[$index]{title} = $1;
      }
      foreach my $key (keys %matches) {
        if ($_ =~ /$matches{$key}/i) {
          $sections[$index]{$key} = $1;
        }
      }
  }

  # sometimes config doesn't have a default, so goes to first
  if (!(defined $sections[0]{'default'})) { 
    $sections[0]{'default'} = '0'; 

  # if default is 'saved', read from grub default file
  } elsif ($sections[0]{'default'} =~ m/^saved$/i) {
    open(DEFAULT_FILE, '/boot/grub/default')
      || warn ("ERROR:  cannot read grub default file.\n") && return undef;
    my @default_config = <DEFAULT_FILE>;
    close(DEFAULT_FILE);
    $default_config[0] =~ /^(\d+)/;
    $sections[0]{'default'} = $1;
  }

  # return array of hashes
  return @sections;
}


# Set new default kernel

sub set_default {
  my $self=shift;
  my $newdefault=shift;

  return undef unless defined $newdefault;
  return undef unless $self->_check_config();

  my @config=@{$self->{config}};
  my @sections=$self->_info();

  # if not a number, do title lookup
  if ($newdefault !~ /^\d+$/) {
    $newdefault = $self->_lookup($newdefault);
  }

  my $kcount = $#sections-1;
  if ((!defined $newdefault) || ($newdefault < 0) || ($newdefault > $kcount)) {
    warn "ERROR:  Enter a default between 0 and $kcount.\n";
    return undef;
  }

  foreach my $index (0..$#config) {
    if ($config[$index] =~ /^\s*default\s+\d+/i) { 
      $config[$index] = "default $newdefault	# set by $0\n"; 
      last;
    } elsif ($config[$index] =~ /^\s*default\ssaved/i) {
      my @default_config;
      my $default_config_file='/boot/grub/default';

      open(DEFAULT_FILE, $default_config_file) 
        || warn ("ERROR:  cannot open default file.\n") && return undef;
      @default_config = <DEFAULT_FILE>;
      close(DEFAULT_FILE);

      $default_config[0] = "$newdefault\n";

      open(DEFAULT_FILE, ">$default_config_file") 
        || warn ("ERROR:  cannot open default file.\n") && return undef;
      print DEFAULT_FILE join("",@default_config);
      close(DEFAULT_FILE);
      last;
    }
  }
  @{$self->{config}} = @config;
}


# Add new kernel to config

sub add {
  my $self=shift;
  my %param=@_;

  print ("Adding kernel.\n") if $self->debug()>1;

  if (!defined $param{'add-kernel'} || !defined $param{'title'}) { 
    warn "ERROR:  kernel path (--add-kernel), title (--title) required.\n";
    return undef; 
  } elsif (!(-f "$param{'add-kernel'}")) { 
    warn "ERROR:  kernel $param{'add-kernel'} not found!\n";
    return undef; 
  } elsif (defined $param{'initrd'} && !(-f "$param{'initrd'}")) { 
    warn "ERROR:  initrd $param{'initrd'} not found!\n";
    return undef; 
  }

  return undef unless $self->_check_config();

  my @sections=$self->_info();

  # check if title already exists
  if (defined $self->_lookup($param{title})) {
    warn ("WARNING:  Title already exists.\n");
    if (defined $param{force}) {
      $self->remove($param{title});
    } else {
      return undef;
    }
  }

  my @config = @{$self->{config}};
  @sections=$self->_info();

  # Use default kernel to fill in missing info
  my $default=$self->get_default();
  $default++;

  foreach my $p ('args', 'root', 'boot', 'savedefault') {
    if (! defined $param{$p}) {
      $param{$p} = $sections[$default]{$p};
    }
  }

  # use default entry to determine if path (/boot) should be removed
  if ($sections[$default]{'kernel'} !~ /^\/boot/) {
    $param{'add-kernel'} =~ s/^\/boot//;
    $param{'initrd'} =~ s/^\/boot// unless !defined $param{'initrd'};
  }

  my @newkernel;
  push(@newkernel, "title\t$param{title}\n") if defined $param{title};
  push(@newkernel, "\troot $param{boot}\n") if defined $param{boot};

  my $line;
  $line = "\tkernel $param{'add-kernel'}" if defined $param{'add-kernel'};
  $line = $line . " root=$param{root}" if defined $param{root};
  $line = $line . " $param{args}" if defined $param{args};
  push(@newkernel, "$line\n");

  push(@newkernel, "\tinitrd $param{initrd}\n") if defined $param{initrd};
  push(@newkernel, "\tsavedefault $param{savedefault}\n") if defined $param{savedefault};
  push(@newkernel, "\n");

  if (!defined $param{position} || $param{position} !~ /end|\d+/) { 
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

  @{$self->{config}} = @newconfig;

  if (defined $param{'make-default'} || defined $param{'boot-once'}) { 
    $self->set_default($param{position});
  }
  print "Added: $param{'title'}.\n";
}


# Update kernel args

sub update {
  my $self=shift;
  my %params=@_;

  print ("Updating kernel.\n") if $self->debug()>1;

  if (!defined $params{'update-kernel'} || (!defined $params{'args'} && !defined $params{'remove-args'})) { 
    warn "ERROR:  kernel position or title (--update-kernel) and args (--args or --remove-args) required.\n";
    return undef; 
  }

  return undef unless $self->_check_config();

  my @config = @{$self->{config}};
  my @sections=$self->_info();

  # if not a number, do title lookup
  if ($params{'update-kernel'} !~ /^\d+$/) {
    $params{'update-kernel'} = $self->_lookup($params{'update-kernel'});
  }

  my $kcount = $#sections-1;
  if ($params{'update-kernel'} !~ /^\d+$/ || $params{'update-kernel'} < 0 || $params{'update-kernel'} > $kcount) {
    warn "ERROR:  Enter a default between 0 and $kcount.\n";
    return undef;
  }

  my $index=-1;
  foreach (@config) {
    if ($_ =~ /^\s*title/i) {
      $index++;
    }
    if ($index==$params{'update-kernel'}) {
      if ($_ =~ /(^\s*kernel\s+\S+\s+)(.*)\n/i) {
        my $kernel = $1;
        my $args = $2;
        $args =~ s/\s+$params{'remove-args'}\=*\S*//ig if defined $params{'remove-args'};
        $args = $args . " ". $params{'args'} if defined $params{'args'};
        if ($_ eq $kernel . $args . "\n") {
          warn "WARNING:  No change made to args.\n";
          return undef;
        } else {
          $_ = $kernel . $args . "\n";
        }
        next;
      }
    }
  }
  @{$self->{config}} = @config;
}


# Run command to install bootloader

sub install {
  my $self=shift;
  my $device;

  warn "Re-installing grub is currently unsupported.\n";
  warn "If you really need to re-install grub, use 'grub-install <device>'.\n";
  return undef;

  #system("grub-install $device");
  #if ($? != 0) {
  #  warn ("ERROR:  Failed to run grub-install.\n") && return undef;
  #}
  #return 1;
}


1;
__END__


=head1 AUTHOR

Open Source Development Labs, Engineering Department <eng@osdl.org>

=head1 COPYRIGHT

Copyright (C) 2006 Open Source Development Labs
All Rights Reserved.

This script is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Linux::Bootloader>

=end

