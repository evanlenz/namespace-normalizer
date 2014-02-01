Namespace normalizer
====================

This XSLT 2.0 stylesheet performs an identity transform
on the input, except that namespace declarations are rewritten
such that they all appear on the document element (at the top),
while preserving the expanded names of all elements and attributes
throughout the document.

For example:

BEFORE:

    <foo xmlns="default1">
      <abc:bar xmlns="default2andfoo" xmlns:abc="default1">
        <bat xmlns:foo="default2andfoo" foo:bar="value">
          <bang xmlns="default3">
            <abc:hi xmlns:xyz="unused-uri"/>
          </bang>
        </bat>
      </abc:bar>
    </foo>

AFTER:

    <foo xmlns="default1" xmlns:bar="default2andfoo" xmlns:ns1="default3" xmlns:xyz="unused-uri">
      <bar>
        <bat bar:bar="value">
          <ns1:bang>
            <hi />
          </ns1:bang>
        </bat>
      </bar>
    </foo>

For more background and detailed considerations on this, as well as
an XSLT 1.0 version of this script, see
[Namespace normalizer](http://lenzconsulting.com/namespace-normalizer/).
