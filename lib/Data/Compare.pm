# -*- mode: Perl -*-

# Data::Compare - compare perl data structures
# Author: Fabien Tassin <fta@sofaraway.org>
# updated by David Cantrell <david@cantrell.org.uk>
# Copyright 1999-2001 Fabien Tassin <fta@sofaraway.org>
# portions Copyright 2003 David Cantrell

package Data::Compare;

use strict;
use vars qw(@ISA @EXPORT $VERSION $DEBUG);
use Exporter;
use Carp;

@ISA     = qw(Exporter);
@EXPORT  = qw(Compare);
$VERSION = 0.05;
$DEBUG   = 0;

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

  Compare($x, $y);
}

# Compare a S::P and a scalar
sub sp_scalar_compare {
    my($scalar, $sp) = @_;
    ($scalar, $sp) = ($sp, $scalar) if(ref($scalar));
    return sp_sp_compare($scalar, $sp) if(ref($scalar));
    return 1 if($scalar eq $sp);
    0;
}

# Compare two S::Ps
sub sp_sp_compare {
    my($sp1, $sp2) = @_;
    return 0 unless($sp1 eq $sp2);
    return 0 unless(Compare([sort $sp1->get_props()], [sort $sp2->get_props()]));
    return 0 if(
        grep { !Compare(eval "\$sp1->$_()", eval "\$sp2->$_()") } $sp1->get_props()
    );
    1;
}

sub Compare ($$) {
  croak "Usage: Data::Compare::Compare(x, y)\n" unless $#_ == 1;
  my $x = shift;
  my $y = shift;

  my $refx = ref $x;
  my $refy = ref $y;

  if($refx eq 'Scalar::Properties' || $refy eq 'Scalar::Properties') {
    # at least one S::P
    return sp_scalar_compare($x, $y);
  }
  elsif(!$refx && !$refy) { # both are scalars
    return $x eq $y if defined $x && defined $y; # both are defined
    !(defined $x || defined $y);
  }
  elsif ($refx ne $refy) { # not the same type
    0;
  }
  elsif ($x == $y) { # exactly the same reference
    1;
  }
  elsif ($refx eq 'SCALAR' || $refx eq 'REF') {
    Compare($$x, $$y);
  }
  elsif ($refx eq 'ARRAY') {
    if ($#$x == $#$y) { # same length
      my $i = -1;
      for (@$x) {
	$i++;
	return 0 unless Compare($$x[$i], $$y[$i]);
      }
      1;
    }
    else {
      0;
    }
  }
  elsif ($refx eq 'HASH') {
    return 0 unless scalar keys %$x == scalar keys %$y;
    for (keys %$x) {
      next unless defined $$x{$_} || defined $$y{$_};
      return 0 unless defined $$y{$_} && Compare($$x{$_}, $$y{$_});
    }
    1;
  }
  elsif($refx eq 'Regexp') {
    Compare($x.'', $y.'');
  }
  elsif ($refx eq 'CODE') {
    0;
  }
  elsif ($refx eq 'GLOB') {
    0;
  }
  else { # a package name (object blessed)
    my ($type) = "$x" =~ m/^$refx=(\S+)\(/;
    if ($type eq 'HASH') {
      my %x = %$x;
      my %y = %$y;
      Compare(\%x, \%y);
    }
    elsif ($type eq 'ARRAY') {
      my @x = @$x;
      my @y = @$y;
      Compare(\@x, \@y);
    }
    elsif ($type eq 'SCALAR' || $type eq 'REF') {
      my $x = $$x;
      my $y = $$y;
      Compare($x, $y);
    }
    elsif ($type eq 'GLOB') {
      0;
    }
    elsif ($type eq 'CODE') {
      0;
    }
    else {
      croak "Can't handle $type type.";
    }
  }
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

If you compare
a scalar and a Scalar::Properties, then they will be considered the same
if the two values are the same, regardless of the presence of properties.
If you compare two Scalar::Properties objects, then they will only be
considered the same if the values and the properties match.

=item Compiled regular expressions, eg qr/foo/

These are stringified before comparison, so the following will match:

    $r = qr/abc/i;
    $s = qr/abc/i;
    Compare($r, $s);

and the following won't, despite them matching *exactly* the same text:

    $r = qr/abc/i;
    $s = qr/[aA][bB][cC]/i;
    Compare($r, $s);

Sorry, that's the best we can do.

=item CODE and GLOB references

These are assumed not to match unless the references are identical - ie,
both are references to the same thing.

=back 4

=head1 AUTHOR

Fabien Tassin        fta@sofaraway.org

Copyright (c) 1999-2001 Fabien Tassin. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

Portions copyright 2003 David Cantrell david@cantrell.org.uk

Seeing that Fabien seems to have disappeared, David Cantrell has become
a co-maintainer so he can apply needed patches.  The licence, of course,
remains the same, and all communications about this module should be
CCed to Fabien in case he ever returns and wants his baby back.

=head1 SEE ALSO

perl(1), perlref(1)

=cut
