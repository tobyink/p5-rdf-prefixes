use Test::More tests => 10;
use RDF::Prefixes;
use utf8;

foreach ((
	['http://purl.org/dc/terms/'    => undef,     '/ cannot be qnamed'],
	['http://purl.org/dc/terms/tØt' => 'dc:tØt',  'interesting char'],
	['http://purl.org/dc/terms/Øt'  => 'dc:Øt',   'interesting char at start'],
	['http://purl.org/tøt/foo'      => 'tøt:foo', 'interesting char in prefix'],
	['http://purl.org/øt/foo'       => 'øt:foo',  'interesting char at start of prefix'],
	['http://purl.org/tØt/foo'      => 'tøt:foo', 'interesting char in prefix, lowercased'],
	['http://purl.org/Øt/foo'       => 'øt:foo',  'interesting char at start of prefix, lowercased'],
	['http://example.com/τωβυ#ινκστερ' => 'τωβυ:ινκστερ', 'some Greek letters'],
	['http://example.com/Τωβυ#Ινκστερ' => 'τωβυ:Ινκστερ', 'some Greek letters, lowercased'],
	['http://example.com/トビー#インケ'  => 'トビー:インケ',  'some katakana'],
))
{
	is(
		RDF::Prefixes->new->get_qname($_->[0]),
		$_->[1],
		($_->[2] // $_->[1]),
	);
}
