# -*- mode: Perl -*-

# Data::Compare - compare perl data structures
# Author: Fabien Tassin <fta@sofaraway.org>
# updated by David Cantrell <david@cantrell.org.uk>
# Copyright 1999-2001 Fabien Tassin <fta@sofaraway.org>
# portions Copyright 2003, 2004 David Cantrell

package Data::Compare;

use strict;
use vars qw(@ISA @EXPORT $VERSION $DEBUG);
use Exporter;
use File::Find::Rule;
use Carp;

@ISA     = qw(Exporter);
@EXPORT  = qw(Compare);
$VERSION = 0.07;
$DEBUG   = 0;

my %handler;

register_plugins();

# finds and registers plugins
sub register_plugins {
    foreach my $file (
        File::Find::Rule
            ->file()
            ->name('*.pm')
            ->in(
	        map { "$_/Data/Compare/Plugins" }
	        grep { -d "$_/Data/Compare/Plugins" }
	        @INC
	    )
    ) {
        # all of this just to avoid loading the same plugin twice and
	# generating a pile of warnings. Grargh!
        $file =~ s!.*(Data/Compare/Plugins/.*)\.pm$!$1!;
	$file =~ s!/!::!g;
	# ignore badly named example from earlier version, oops
	next if($file eq 'Data::Compare::Plugins::Scalar-Properties');
        my $requires = eval "require $file";
	next if($requires eq '1'); # already loaded this plugin?

	# not an arrayref? bail
        if(ref($requires) ne 'ARRAY') {
            warn("$file isn't a valid Data::Compare plugin (didn't return arrayref)\n");
	    return;
        }
	# coerce into arrayref of arrayrefs if necessary
	if(ref((@{$requires})[0]) ne 'ARRAY') { $requires = [$requires] }

        # register all the handlers
        foreach my $require (@{$requires}) {
            my($handler, $type1, $type2, $cruft) = reverse @{$require};
	    $type2 = $type1 unless(defined($type2));
	    ($type1, $type2) = sort($type1, $type2);
	    if(!defined($type1) || ref($type1) ne '' || !defined($type2) || ref($type2) ne '') {
	        warn("$file isn't a valid Data::Compare plugin (invalid type)\n");
	    } elsif(defined($cruft)) {
	        warn("$file isn't a valid Data::Compare plugin (extra data)\n");
	    } elsif(ref($handler) ne 'CODE') {
	        warn("$file isn't a valid Data::Compare plugin (no coderef)\n");
	    } else {
                $handler{$type1}{$type2} = $handler;
	    }
        }
    }
}

sub Compare ($$);

sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  bless $self, $class;
  $self->{'x'} = shift;
  $self->{'y'} = shift;
  return $self;
}

sub Cmp ($;$$) {
  my $self = shift;

  croak "Usage: DataCompareObj->Cmp(x, y)" unless $#_ == 1 || $#_ == -1;
  my $x = shift || $self->{'x'};
  my $y = shift || $self->{'y'};

  return Compare($x, $y);
}

sub Compare ($$) {
  croak "Usage: Data::Compare::Compare(x, y)\n" unless $#_ == 1;
  my $x = shift;
  my $y = shift;

  my $refx = ref $x;
  my $refy = ref $y;

  if(exists($handler{$refx}) && exists($handler{$refx}{$refy})) {
      return &{$handler{$refx}{$refy}}($x, $y);
  } elsif(exists($handler{$refy}) && exists($handler{$refy}{$refx})) {
      return &{$handler{$refy}{$refx}}($x, $y);
  }

  if(!$refx && !$refy) { # both are scalars
    return $x eq $y if defined $x && defined $y; # both are defined
    return !(defined $x || defined $y);
  }
  elsif ($refx ne $refy) { # not the same type
    return 0;
  }
  elsif ($x == $y) { # exactly the same reference
    return 1;
  }
  elsif ($refx eq 'SCALAR' || $refx eq 'REF') {
    return Compare($$x, $$y);
  }
  elsif ($refx eq 'ARRAY') {
    if ($#$x == $#$y) { # same length
      my $i = -1;
      for (@$x) {
	$i++;
	return 0 unless Compare($$x[$i], $$y[$i]);
      }
      return 1;
    }
    else {
      return 0;
    }
  }
  elsif ($refx eq 'HASH') {
    return 0 unless scalar keys %$x == scalar keys %$y;
    for (keys %$x) {
      next unless defined $$x{$_} || defined $$y{$_};
      return 0 unless defined $$y{$_} && Compare($$x{$_}, $$y{$_});
    }
    return 1;
  }
  elsif($refx eq 'Regexp') {
    return Compare($x.'', $y.'');
  }
  elsif ($refx eq 'CODE') {
    return 0;
  }
  elsif ($refx eq 'GLOB') {
    return 0;
  }
  else { # a package name (object blessed)
    my ($type) = "$x" =~ m/^$refx=(\S+)\(/;
    if ($type eq 'HASH') {
      my %x = %$x;
      my %y = %$y;
      return Compare(\%x, \%y);
    }
    elsif ($type eq 'ARRAY') {
      my @x = @$x;
      my @y = @$y;
      return Compare(\@x, \@y);
    }
    elsif ($type eq 'SCALAR' || $type eq 'REF') {
      my $x = $$x;
      my $y = $$y;
      return Compare($x, $y);
    }
    elsif ($type eq 'GLOB') {
      return 0;
    }
    elsif ($type eq 'CODE') {
      return 0;
    }
    else {
      croak "Can't handle $type type.";
    }
  }
}

sub plugins {
    return { map { (($_ eq '') ? '[scalar]' : $_, [map { $_ eq '' ? '[scalar]' : $_ } keys %{$handler{$_}}]) } keys %handler };
}

sub plugins_printable {
    my $r = "The following comparisons are available through plugins\n\n";
    foreach my $key (sort keys %handler) {
        foreach(sort keys %{$handler{$key}}) {
            $r .= join(":\t", map { $_ eq '' ? '[scalar]' : $_ } ($key, $_))."\n";
	}
    }
    return $r;
}

1;

=head1 NAME

Data::Compare - compare perl data structures

=head1 SYNOPSIS

    use Data::Compare;

    my $h = { 'foo' => [ 'bar', 'baz' ], 'FOO' => [ 'one', 'two' ] };
    my @a1 = ('one', 'two');
    my @a2 = ('bar', 'baz');
    my %v = ( 'FOO', \@a1, 'foo', \@a2 );

    # simple procedural interface
    print 'structures of $h and \%v are ',
      Compare($h, \%v) ? "" : "not ", "identical.\n";

    # OO usage
    my $c = new Data::Compare($h, \%v);
    print 'structures of $h and \%v are ',
      $c->Cmp ? "" : "not ", "identical.\n";
    # or
    my $c = new Data::Compare;
    print 'structures of $h and \%v are ',
      $c->Cmp($h, \%v) ? "" : "not ", "identical.\n";

=head1 DESCRIPTION

Compare two perl data structures recursively. Returns 0 if the
structures differ, else returns 1.

A few data types are treated as special cases:

=over 4

=item Scalar::Properties objects

This has been moved into a plugin, although functionality remains the
same as with the previous version.  Full documentation is in
L<Data::Compare::Plugins::Scalar::Properties>.

=item Compiled regular expressions, eg qr/foo/

These are stringified before comparison, so the following will match:

    $r = qr/abc/i;
    $s = qr/abc/i;
    Compare($r, $s);

and the following won't, despite them matching *exactly* the same text:

    $r = qr/abc/i;
    $s = qr/[aA][bB][cC]/;
    Compare($r, $s);

Sorry, that's the best we can do.

=item CODE and GLOB references

These are assumed not to match unless the references are identical - ie,
both are references to the same thing.

=back 4

=head1 PLUGINS

The module takes plug-ins so you can provide specialised routines for
comparing your own objects and data-types.  For details see
L<Data::Compare::Plugins>.

A couple of functions are provided to examine what goodies have been
made available through plugins:

=over 4

=item plugins

Returns a structure (a hash ref) describing all the comparisons made
available through plugins.
This function is *not* exported, so should be called as Data::Compare::plugins().
It takes no parameters.

=item plugins_printable

Returns formatted text

=back

=head1 BUGS

Plugin support is not quite finished (see the TODO file for details) but
is usable.  The missing bits are bells and whistles rather than core
functionality.

=head1 AUTHOR

Fabien Tassin        fta@sofaraway.org

Copyright (c) 1999-2001 Fabien Tassin. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

Seeing that Fabien seems to have disappeared, David Cantrell has become
a co-maintainer so he can apply needed patches.  The licence, of course,
remains the same, and all communications about this module should be
CCed to Fabien in case he ever returns and wants his baby back.

Portions, including plugins, copyright 2003-2004 David Cantrell
david@cantrell.org.uk

=head1 SEE ALSO

perl(1), perlref(1)

=cut
