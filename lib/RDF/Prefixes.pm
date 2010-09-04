package RDF::Prefixes;

use 5.008;
use common::sense;

use Carp qw[];

our $VERSION = '0.001';
our ($r_nameStartChar, $r_nameChar, $r_prefix);

BEGIN
{
	$r_nameStartChar = qr'[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{00010000}-\x{000EFFFF}]';
	$r_nameChar      = qr'${r_nameStartChar}|[-_0-9\x{b7}\x{0300}-\x{036f}\x{203F}-\x{2040}]';
	$r_prefix        = qr'${r_nameStartChar}${r_nameChar}*';
}

sub new
{
	my ($class, $suggested) = @_;
	$suggested ||= {};
	my $self = {};
		
	foreach my $s (reverse sort keys %$suggested)
	{
		if ($s =~ /^[a-z0-9][a-z0-9_\.]*$/i)
		{
			$self->{suggested}{ $suggested->{$s} } = $s;
		}
		else
		{
			Carp::carp "Ignored suggestion $s => " . $suggested->{$s};
		}
	}
	
	return bless $self, $class;
}

sub get_prefix
{
	my ($self, $url) = @_;
	my $pp = $self->_practical_prefix($url);
	$self->hashref->{ $pp } = $url;
	return $pp;
}

sub preview_prefix
{
	return _practical_prefix(@_);
}

sub get_qname
{
	my ($self, $url) = @_;
	
	my ($p, $s) = $self->_split_qname($url);
	return undef unless defined $p and defined $s;
	
	return $self->get_prefix($p) . ':' . $s;
}

sub preview_qname
{
	my ($self, $url) = @_;
	
	my ($p, $s) = $self->_split_qname($url);
	return undef unless defined $p and defined $s;
	
	return $self->preview_prefix($p) . ':' .  $s;
}

sub get_curie
{
	my ($self, $url) = @_;
	
	my ($p, $s) = $self->_split_qname($url);
	
	return $self->get_prefix($url) . ':'
		unless defined $p and defined $s;
	
	return $self->get_prefix($p) . ':' .  $s;
}

sub preview_curie
{
	my ($self, $url) = @_;
	
	my ($p, $s) = $self->_split_qname($url);
	
	return $self->preview_prefix($url) . ':'
		unless defined $p and defined $s;
	
	return $self->preview_prefix($p) . ':' . $s;
}

sub hashref
{
	my ($self) = @_;
	$self->{used} ||= {};
	return $self->{used};
}

sub rdfa
{
	my ($self) = @_;
	my $rv;
	foreach my $prefix (sort keys %{ $self->hashref })
	{
		$rv .= sprintf("%s: %s ",
			$prefix,
			$self->hashref->{$prefix});
	}
	return substr($rv, 0, (length $rv) - 1);
}

sub sparql
{
	my ($self) = @_;
	my $rv;
	foreach my $prefix (sort keys %{ $self->hashref })
	{
		$rv .= sprintf("PREFIX %s: <%s>\n",
			$prefix,
			$self->hashref->{$prefix});
	}
	return $rv;
}

sub turtle
{
	my ($self) = @_;
	my $rv;
	foreach my $prefix (sort keys %{ $self->hashref })
	{
		$rv .= sprintf("\@prefix %s: <%s> .\n",
			$prefix,
			$self->hashref->{$prefix});
	}
	return $rv;
}

sub xmlns
{
	my ($self) = @_;
	my $rv;
	foreach my $prefix (sort keys %{ $self->hashref })
	{
		$rv .= sprintf(" xmlns:%s=\"%s\"",
			$prefix,
			$self->hashref->{$prefix});
	}
	return $rv;
}

sub _split_qname
{
	my ($self, $uri) = @_;
        
	my $nameStartChar  = qr<([A-Za-z_]|[\x{C0}-\x{D6}]|[\x{D8}-\x{D8}]|[\x{F8}-\x{F8}]|[\x{200C}-\x{200C}]|[\x{37F}-\x{1FFF}][\x{200C}-\x{200C}]|[\x{2070}-\x{2070}]|[\x{2C00}-\x{2C00}]|[\x{3001}-\x{3001}]|[\x{F900}-\x{F900}]|[\x{FDF0}-\x{FDF0}]|[\x{10000}-\x{10000}])>;
	my $nameChar       = qr<$nameStartChar|-|[.]|[0-9]|\x{B7}|[\x{0300}-\x{036F}]|[\x{203F}-\x{2040}]>;
	my $lnre           = qr<((${nameStartChar})($nameChar)*)>;
	
   if ($uri =~ m/${lnre}$/)
	{
		my $ln  = $1;
		my $ns  = substr($uri, 0, length($uri)-length($ln));
		return ($ns, $ln);
	}
	
	return;
}

sub _perfect_prefix
{
	my ($self, $url) = @_;
	
	my $chosen = {
		'http://www.w3.org/1999/02/22-rdf-syntax-ns#' => 'rdf',
		'http://www.w3.org/2000/01/rdf-schema#'       => 'rdfs',
		'http://www.w3.org/2002/07/owl#'              => 'owl',
		'http://www.w3.org/2001/XMLSchema#'           => 'xsd',
		}->{$url};
	
	return $chosen if length $chosen;

	(my $extensionRemoved = $url) =~ /\.(owl|rdf|rdfx|rdfs|nt|ttl|turtle|xml)$/i;
	my @words = split /[^A-Za-z0-9\._-]/, $extensionRemoved;
	WORD: while (my $w = pop @words)
	{
		next unless length $w;
		next if $w =~ /^[0-9\.-]+$/; # looks like a date or version number
		next if $w =~ /^(terms|ns|vocab|vocabulary|rdf|rdfs|owl|schema)$/i; # too generic
		next unless $w =~ /^[a-z0-9][a-z0-9_\.]*$/i;
		
		$chosen = $w;
		last WORD;
	}
	
	return lc $chosen;
}

sub _practical_prefix
{
	my ($self, $url) = @_;

	while (my ($existing_prefix, $full) = each %{ $self->hashref })
	{
		return $existing_prefix if $full eq $url;
	}
	
	my $perfect = $self->{suggested}{$url}
		|| $self->_perfect_prefix($url)
		|| 'ns';
	return $perfect unless defined $self->hashref->{$perfect};
	
	my $i = 2;
	while (defined $self->hashref->{$perfect . $i})
	{
		$i++;
	}
	return $perfect . $i;
}

1;

__END__

=head1 NAME

RDF::Prefixes - simple way to turn URIs into QNames.

=head1 SYNOPSIS

 my $context = RDF::Prefixes->new;
 say $context->qname('http://purl.org/dc/terms/title');  # dc:title
 say $context->qname('http://example.net/rdf/dc#title'); # dc2:title
 say $context->turtle;  # @prefix dc: <http://purl.org/dc/terms/> .
                        # @prefix dc2: <http://example.net/rdf/dc#> .

=head1 DESCRIPTION

=head2 Constructor

=over 4

=item C<< new(\%suggestions) >>

Creates a new RDF prefix context.

Suggestions for prefix mappings may be given, but there's no guarantee
that they'll be used.

=back

=head2 Methods

=over 4

=item C<< get_prefix($uri) >>

Gets the prefix associated with a URI. e.g.
C<< get_prefix('http://purl.org/dc/terms/') >> might return 'dc'.

=item C<< get_qname($uri) >>

Gets a QName for a URI. e.g.
C<< get_prefix('http://purl.org/dc/terms/title') >> might return 'dc:title'.

Some URIs cannot be converted to QNames. In these cases, undef is returned.

=item C<< get_curie($uri) >>

As per C<get_qname>, but allows for more relaxed return values, suitable
for RDFa, Turtle or Notation 3, but not RDF/XML. Should never need to
return undef.

=item C<< preview_prefix($uri) >>,
C<< preview_qname($uri) >>,
C<< preview_curie($uri) >>

As per the "get" versions of these methods, but doesn't change the
context.

=item C<< hashref >>

Returns a hashref of prefix mappings used so far.

=item C<< rdfa >>

Return the same data as C<hashref>, but as a string suitable for
placing in an RDFa 1.1 prefix attribute.

=item C<< sparql >>

Return the same data as C<hashref>, but as a string suitable for
prefixing a SPARQL query.

=item C<< turtle >>

Return the same data as C<hashref>, but as a string suitable for
prefixing a Turtle or Notation 3 file.

=item C<< xmlns >>

Return the same data as C<hashref>, but as a string of xmlns
attributes, suitable for use with RDF/XML or RDFa.

=back

=head1 BUGS

Please report any bugs to L<http://rt.cpan.org/>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2010 Toby Inkster

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut