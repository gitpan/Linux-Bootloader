use ExtUtils::MakeMaker;
use strict;

my %opts = (
            'NAME'          => "Linux::Bootloader",
            'AUTHOR'        => "OSDL Engineering <eng\@osdl.org>",
            'ABSTRACT_FROM' => "lib/Linux/Bootloader.pm",
            'VERSION'       => '1.0',
            'EXE_FILES'     => [ qw( 
                                     scripts/boottool
                                     scripts/linux_install
                                     scripts/linux_mkinitrd
                                     scripts/linux_release_tag
                                     ) ],
            'PREREQ_PM'     => {
                'Pod::Usage'     => 0,
                'Getopt::Long'   => 0,
            },
);

WriteMakefile( %opts )

# vi:set ai ts=4 sw=4 expandtab:
