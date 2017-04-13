package Virtualmin::Config::Plugin::AWStats;
use strict;
use warnings;
no warnings qw(once);
use parent 'Virtualmin::Config::Plugin';

our $config_directory;
our (%gconfig, %miniserv);

sub new {
  my $class = shift;
  # inherit from Plugin
  my $self = $class->SUPER::new(name => 'AWStats');

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
  foreign_require("cron");
	my @jobs = &cron::list_cron_jobs();
	my @dis = grep { $_->{'command'} =~ /\/usr\/share\/awstats\/tools\/(update|buildstatic).sh/ && $_->{'active'} } @jobs;
	if (@dis) {
		foreach my $job (@dis) {
			$job->{'active'} = 0;
			&cron::change_cron_job($job);
		}
  }

  $self->done(1); # OK!
}

1;