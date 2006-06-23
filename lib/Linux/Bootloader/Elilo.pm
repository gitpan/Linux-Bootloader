package Linux::Bootloader::Elilo;

=head1 NAME

Linux::Bootloader::Elilo - Parse and modify ELILO configuration files.

=head1 SYNOPSIS

	use Linux::Bootloader;
	use Linux::Bootloader::Elilo;
	
	my $bootloader = Linux::Bootloader::Elilo->new();
	my $config_file='/etc/elilo.conf';

	$bootloader->read($config_file)

	# add a kernel	
	$bootloader->add(%hash)

	# remove a kernel
	$bootloader->remove(2)

	# set new default
	$bootloader->set_default(1)

	$bootloader->write($config_file)


=head1 DESCRIPTION

This module provides functions for working with ELILO configuration files.

	Adding a kernel:
	- add kernel at start, end, or any index position.
	- kernel path and title are required.
	- root, kernel args, initrd are optional.
	- any options not specified are copied from default.
	- remove any conflicting kernels if force is specified.
	
	Removing a kernel:
	- remove by index position
	- or by title/label


=head1 FUNCTIONS

Also see L<Linux::Bootloader> for functions available from the base class.

=head2 new()

	Creates a new Linux::Bootloader::Elilo object.

=head2 install()

        Attempts to install bootloader.
        Takes: nothing.
        Returns: undef on error.

=cut


use strict;
use warnings;
use Linux::Bootloader

@Linux::Bootloader::Elilo::ISA = qw(Linux::Bootloader);
use base 'Linux::Bootloader';


use vars qw( $VERSION );
our $VERSION = '1.1';


sub new {
    my $class = shift;
    my $self = bless({}, $class);

    $self->{'config'}   = [];
    $self->{'debug'}    = 0;

    $self->SUPER::new();

    return $self;
}


### ELILO functions ###


# Run command to install bootloader

sub install {
  my $self=shift;

  system("elilo");
  if ($? != 0) { 
    warn ("ERROR:  Failed to run elilo.\n") && return undef; 
  }
  return 1;
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

