package Virtualmin::Config::Plugin::Extra;
# Some extra functions that don't really fit into any other plugins
use strict;
use warnings;
no warnings qw(once);
use parent 'Virtualmin::Config::Plugin';

our $config_directory;
our (%gconfig, %miniserv);

sub new {
  my $class = shift;
  # inherit from Plugin
  my $self = $class->SUPER::new(
    name    => 'Extra',
    depends => ['Virtualmin', 'Webmin'] );

  return $self;
}

# actions method performs whatever configuration is needed for this
# plugin. XXX Needs to make a backup so changes can be reverted.
sub actions {
  my $self = shift;

  use Cwd;
  my $cwd = getcwd();
  my $root = $self->root();
  chdir($root);
  $0 = "$root/init-system.pl";
  push(@INC, $root);
  eval 'use WebminCore'; ## no critic
  init_config();

  $self->spin();
  # Attempt to sync clock
  if (&has_command("ntpdate-debian")) {
  	system("ntpdate-debian >/dev/null 2>&1 </dev/null &");
  }
  foreign_require("webmin", "webmin-lib.pl");
	webmin::build_installed_modules(1);

  # Turn on caching for downloads by Virtualmin
  if (!$gconfig{'cache_size'}) {
  	$gconfig{'cache_size'} = 50*1024*1024;
  	$gconfig{'cache_mods'} = "virtual-server";
  	write_file("$config_directory/config", \%gconfig);
  }

  $self->done(1); # OK!
}

1;
