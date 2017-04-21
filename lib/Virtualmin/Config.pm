package Virtualmin::Config;
# ABSTRACT: Configure a system for use by Virtualmin
use strict;
use warnings;
no warnings qw(once); # We've got some globals that effect Webmin behavior
use 5.010_001; # Version shipped with CentOS 6. Nothing older.
use Module::Load;
use Term::ANSIColor qw(:constants);
use Term::Spinner::Color;

# globals
our (%gconfig, %uconfig, %miniserv, %uminiserv);
our ($root_directory, $config_directory);
our ($trust_unknown_referers, $no_acl_check, $error_must_die, $file_cache);

sub new {
  my ($class, %args) = @_;
  my $self = {};

  $self->{bundle} = $args{bundle};
  $self->{include} = $args{include};
  $self->{exclude} = $args{exclude};
	# Guesstimate our terminal size.
	#my ($lines, $cols) = `stty size`=~/(\d+)\s+(\d+)/?($1,$2):(25,80);
	#unless ($cols <= 80) { $cols = 80 };

	return bless $self, $class;
}

# Gathered plugins are processed
sub run {
	my $self = shift;

	$|=1; # No line buffering.

	# TODO This should really just be "use Webmin::Core"
	$no_acl_check++;

	$error_must_die = 1;

	my @plugins = $self->_gather_plugins();
	@plugins = $self->_order_plugins(@plugins);
	for (@plugins) {
		my $pkg = "Virtualmin::Config::Plugin::$_";
		load $pkg || die "Loading Plugin failed: $_";
		my $plugin = $pkg->new();
		$plugin->actions();
	}
  return 1;
}

# Merges the selected bundle, with any extra includes, and removes excludes
sub _gather_plugins {
	my $self = shift;
  my @plugins;

  # If bundle specified, load it up.
  if ($self->{bundle}) {
    my $pkg = "Virtualmin::Config::$self->{bundle}";
	  load $pkg;
    my $bundle = $pkg->new();
    # Ask the bundle for a list of plugins
    @plugins = $bundle->plugins();
  }

	# Check with the command arguments
	if ( ref($self->{include}) eq 'ARRAY' || ref($self->{include}) eq 'STRING' ) {
		for my $include ($self->{'include'}) {
			push (@plugins, $include) unless ( map { grep( /^$include$/, @{$_} ) } @plugins);
		}
	}

	# Check for excluded plugins
	if ( ref($self->{exclude}) eq 'ARRAY' || ref($self->{exclude}) eq 'STRING' ) {
		for my $exclude ($self->{'exclude'}) {
			my @dix = reverse(grep { $plugins[$_] eq $exclude } 0..$#plugins);
			for (@dix) {
				splice(@plugins, $_, 1);
			}
		}
	}

	return @plugins;
}

# Take the gathered list of plugins and sort them to resolve deps
sub _order_plugins {
	my ($self, @plugins) = @_;
	my %plugin_details; # Will hold an array of hashes containing name/depends
	# Load up @plugin_details with name and dependency list
  if (ref($plugins[0]) eq 'ARRAY') { # XXX Why is this so stupid?
    @plugins = map{@$_} @plugins; # Flatten the array of refs into list.
  }
	for my $plugin_name (@plugins) {
		my $pkg = "Virtualmin::Config::Plugin::$plugin_name";
		load $pkg;
		my $plugin = $pkg->new();
		$plugin_details{$plugin->{'name'}} = $plugin->{'depends'} // [];
	}
	return _topo_sort(%plugin_details);
}

# Topological sort on dependencies
sub _topo_sort {
	my (%deps) = @_;

	my %ba;
	while ( my ( $before, $afters_aref ) = each %deps ) {
		unless ( @{$afters_aref} ) {
			$ba{$before} = {};
		}
		for my $after ( @{ $afters_aref } ) {
			$ba{$before}{$after} = 1 if $before ne $after;
			$ba{$after} ||= {};
		}
	}
	my @rv;
	while ( my @afters = sort grep { ! %{ $ba{$_} } } keys %ba ) {
		push @rv, @afters;
		delete @ba{@afters};
		delete @{$_}{@afters} for values %ba;
	}

	return _uniq(@rv);
}

# uniq so we don't have to import List::MoreUtils
sub _uniq {
  my %seen;
  return grep { !$seen{$_}++ } @_;
}

1;

__END__

=pod

=encoding utf8

=for html <a href="https://travis-ci.org/virtualmin/Virtualmin-Config">
<img src="https://travis-ci.org/virtualmin/Virtualmin-Config.svg?branch=master">
</a>&nbsp;
<a href='https://coveralls.io/github/virtualmin/Virtualmin-Config?branch=master'>
<img src='https://coveralls.io/repos/github/virtualmin/Virtualmin-Config/badge.svg?branch=master'
alt='Coverage Status' /></a>


=head1 NAME

Virtualmin::Config - A collection of plugins to initialize the configuration
of sevrices that Virtualmin manages, and a command line tool called init-system
to run them.

=head1 SYNOPSIS

    my $bundle = Virtualmin::Config->new(bundle	=> 'LAMP');
    $bundle->run();

You can also call it with specific plugins, rather than a whole bundle of
plugins.

    my $plugin = Virtualmin::Config->new(include => 'Apache');
    $plugin->run();

Adding new features to the installer, or modifying installer features, should
be done by creating new plugins or by adding to existing ones.

=head1 DESCRIPTION

This is a mini-framework for configuring elements of a Virtualmin system. It
uses Webmin as a library to abstract common configuration tasks, provides a
friendly status indicator, and makes it easy to pick and choose the kind of
configuration you want (should you choose to go that route). The Virtualmin
install script chooses either the LAMP (with Apache) or LEMP (with nginx)
bundle, and performs the configuration for the whole stack.

It includes plugins for all of the common tasks in a Virtualmin system, such
as Apache, MySQL/MariaDB, Postfix, SpamAssassin, etc.

=head1 ATTRIBUTES

=over

=item bundle

Selects the plugin bundle to be installed. A bundle is a list of plugins
configured in a C<Virtualmin::Config::*> class.

=item include

One or more additional plugins to include in the C<run()>. This can be
used alongside C<bundle> or by itself. Dependencies will also be run, and
there is no way to disable dependencies (because they're depended on!).

=item exclude

One or more plugins to remove from the selected C<bundle>. Plugins that are
needed to resolve dependencies will be re-added automatically.

=back

=head1 METHODS

=over

=item run

This method figures out which plugins to run (based on the C<bundle>,
C<include>, and C<exclude> attributes.

=back

=head1 LICENSE AND COPYRIGHT

Licensed under the GPLv3. Copyright 2017 Virtualmin, Inc. <joe@virtualmin.com>
