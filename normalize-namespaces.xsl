<!-- This stylesheet performs an identity transformation,
     except that it also changes the namespace declarations
     in the result such that they all appear on the document
     element, while preserving all the same effective element
     and attribute node names througout the document.
-->
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:nn="http://lenzconsulting.com/namespace-normalizer"
  exclude-result-prefixes="xs nn">

  <!-- Set to true to print debugging info -->
  <xsl:param name="DEBUG" select="false()"/>

  <!-- By default, namespace-normalize the input -->
  <xsl:template match="/">
    <xsl:copy-of select="nn:normalize(.)"/>
  </xsl:template>

  <!-- This is the main function of interest -->
  <xsl:function name="nn:normalize" as="document-node()">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:sequence select="nn:normalize($doc,())"/>
  </xsl:function>

  <!-- You can optionally supply a set of preferred prefix/URI mappings;
       the expected format of $ns-prefs is as follows:
       
       <ns prefix=""    uri="http://example.com"/>
       <ns prefix="foo" uri="http://example.com/ns"/>
       ...
       
  -->
  <xsl:function name="nn:normalize" as="document-node()">
    <xsl:param name="doc"      as="document-node()"/>
    <xsl:param name="ns-prefs" as="element(ns)*"/>
    <!-- print a DEBUG message, if applicable -->
    <xsl:if test="$DEBUG">
      <xsl:message>
        <xsl:copy-of select="nn:diagnostics($doc,$ns-prefs)"/>
      </xsl:message>
    </xsl:if>
    <!-- Apply the new namespace nodes -->
    <xsl:document>
      <xsl:apply-templates mode="normalize-namespaces" select="$doc">
        <xsl:with-param name="ns-nodes" select="nn:new-namespace-nodes($doc,$ns-prefs)" tunnel="yes"/>
      </xsl:apply-templates>
    </xsl:document>
  </xsl:function>


  <!-- The first namespace node for each unique namespace URI -->
  <xsl:function name="nn:unique-uri-namespace-nodes">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:sequence select="for $uri in distinct-values($doc//namespace::*[not(name() eq 'xml')])
                          return ($doc//namespace::*[. eq $uri])[1]"/>
  </xsl:function>


  <!-- These candidate bindings disallow default declarations
       for namespaces that need a prefix, but they don't yet
       prevent duplicate prefixes; that comes later. -->
  <xsl:function name="nn:candidate-bindings-doc" as="document-node()">
    <xsl:param name="doc"      as="document-node()"/>
    <xsl:param name="ns-prefs" as="element(ns)*"/>
    <xsl:document>
      <xsl:for-each select="nn:unique-uri-namespace-nodes($doc)">
        <!-- Process the pre-existing URIs (from the user-supplied list) first;
             that way, their prefixes will have precedence when removing duplicates. -->
        <xsl:sort select="if (. = $ns-prefs/@uri) then 'first' else 'last'"/>

        <!-- is this a default namespace? -->
        <xsl:variable name="is-default" select="not(name(.))"/>

        <!-- must the URI have a prefix? -->
        <!--
         If there are any unqualified element names
         then force default namespaces to use a prefix,
         because we want to guarantee that the only
         namespace declarations in our result will be
         attached to the root element.
        -->
        <xsl:variable name="cannot-be-default" select="//*[not(namespace-uri())]"/>

        <xsl:choose>
          <!-- do we need to force a non-empty prefix? -->
          <xsl:when test="$is-default and $cannot-be-default">
            <!-- is there an existing prefix from the document we can use? -->
            <xsl:variable name="prefix-from-document"
                          select="name((//namespace::*[. eq current()][name()])[1])"/>

            <xsl:copy-of select="nn:binding-with-nonempty-prefix(., $ns-prefs, $prefix-from-document)"/>
          </xsl:when>

          <!-- otherwise, we can use the existing (possibly empty) prefix -->
          <xsl:otherwise>
            <xsl:variable name="preferred-prefix"
                          select="nn:choose-prefix(., $ns-prefs, name(.), false())"/>
            <binding>
              <uri>
                <xsl:value-of select="."/>
              </uri>
              <prefix>
                <xsl:value-of select="$preferred-prefix"/>
              </prefix>
            </binding>

            <!-- Create an additional namespace node if needed specifically for qualified attributes -->
            <xsl:if test="not($preferred-prefix) and //@*[namespace-uri() eq current()]">
              <xsl:copy-of select="nn:binding-with-nonempty-prefix(., $ns-prefs, '')"/>
            </xsl:if>

          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:document>
  </xsl:function>

          <xsl:function name="nn:binding-with-nonempty-prefix" as="element(binding)">
            <xsl:param name="ns-node"/>
            <xsl:param name="ns-prefs"/>
            <xsl:param name="prefix-from-document"/>
            <binding>
              <uri>
                <xsl:value-of select="$ns-node"/>
              </uri>
              <xsl:variable name="preferred-prefix" select="nn:choose-prefix($ns-node, $ns-prefs, $prefix-from-document, true())"/>
              <xsl:choose>
                <xsl:when test="$preferred-prefix">
                  <!-- If a suitable prefix is found, use it! -->
                  <prefix>
                    <xsl:value-of select="$preferred-prefix"/>
                  </prefix>
                </xsl:when>
                <xsl:otherwise>
                  <!-- Otherwise, leave a note to ourselves that we need to generate a new prefix -->
                  <generate-prefix/>
                </xsl:otherwise>
              </xsl:choose>
            </binding>
          </xsl:function>

          <!-- Use the user-supplied preferred prefixes whenever possible -->
          <xsl:function name="nn:choose-prefix" as="xs:string">
            <xsl:param name="ns-node"/>
            <xsl:param name="ns-prefs"          as="element(ns)*"/>
            <xsl:param name="given-prefix"      as="xs:string"/>
            <xsl:param name="nonempty-required" as="xs:boolean"/>
            <!-- If the URI has a preferred prefix, then use it; otherwise, use the given prefix -->
            <xsl:choose>
              <xsl:when test="$ns-node = $ns-prefs/@uri">
                <!-- Use the preferred prefix, unless it's empty (default) and required to be non-empty. -->
                <xsl:variable name="preferred-prefix" select="$ns-prefs[@uri eq $ns-node][1]/@prefix/string(.)"/>
                <xsl:sequence select="if ($nonempty-required and not($preferred-prefix))
                                      then $given-prefix
                                      else $preferred-prefix"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:sequence select="$given-prefix"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:function>


  <!-- Create the final list of bindings, preventing the duplication of prefixes. -->
  <xsl:function name="nn:final-bindings-doc" as="document-node()">
    <xsl:param name="doc"      as="document-node()"/>
    <xsl:param name="ns-prefs" as="element(ns)*"/>
    <xsl:document>
      <xsl:apply-templates mode="remove-duplicates" select="nn:candidate-bindings-doc($doc,$ns-prefs)/binding"/>
    </xsl:document>
  </xsl:function>

          <!-- Generate a prefix if it's already being used -->
          <xsl:template mode="remove-duplicates" match="prefix[. = preceding::prefix]">
            <generate-prefix/>
          </xsl:template>

          <!-- By default, copy the bindings as is -->
          <xsl:template mode="remove-duplicates" match="@* | node()">
            <xsl:copy>
              <xsl:apply-templates mode="#current" select="@* | node()"/>
            </xsl:copy>
          </xsl:template>


  <!-- Generate a namespace node for each of the final bindings -->
  <xsl:function name="nn:new-namespace-nodes">
    <xsl:param name="doc"      as="document-node()"/>
    <xsl:param name="ns-prefs" as="element(ns)*"/>
    <xsl:for-each select="nn:final-bindings-doc($doc,$ns-prefs)/binding
                          [not(generate-prefix and uri = preceding-sibling::binding[generate-prefix]/uri)]">
                          <!-- If we end up with more than one <generate-prefix/> for the same URI, only process the first -->
      <xsl:variable name="prefix">
        <xsl:choose>
          <xsl:when test="generate-prefix">
            <!-- Generate in the form "ns1", "ns2", etc. -->
            <xsl:variable name="auto-prefix"
                          select="concat('ns',1+count(preceding::generate-prefix))"/>
            <xsl:variable name="already-taken" select="$auto-prefix = ../binding/prefix"/>

            <!-- But if the document already has "ns1", etc. then punt and call generate-id() -->
            <xsl:sequence select="if (not($already-taken))
                                  then $auto-prefix
                                  else generate-id(.)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="prefix"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:namespace name="{$prefix}" select="string(uri)"/>
    </xsl:for-each>
  </xsl:function>


  <!-- Give every element the same namespace nodes (the ones we've decided on above) -->
  <xsl:template match="*" mode="normalize-namespaces">
    <xsl:param name="ns-nodes" tunnel="yes"/>
    <xsl:element name="{nn:new-qname(.,$ns-nodes)}" namespace="{namespace-uri()}">
      <!-- strictly speaking, we only need to copy these to the document element, but oh well -->
      <xsl:copy-of select="$ns-nodes"/>
      <xsl:apply-templates mode="#current" select="@* | node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Replicate attributes -->
  <xsl:template match="@*" mode="normalize-namespaces">
    <xsl:param name="ns-nodes" tunnel="yes"/>
    <xsl:attribute name="{nn:new-qname(.,$ns-nodes)}" namespace="{namespace-uri()}" select="."/>
  </xsl:template>

  <!-- Do a simple copy of the other nodes -->
  <xsl:template match="text() | comment() | processing-instruction()" mode="normalize-namespaces">
    <xsl:copy/>
  </xsl:template>

  <!-- Get the lexical QName based on the bindings we've chosen -->
  <xsl:function name="nn:new-qname">
    <xsl:param name="node"/>
    <xsl:param name="ns-nodes"/>
    <xsl:variable name="prefix" select="$ns-nodes[. eq namespace-uri($node)]
                                                 [if ($node instance of element())
                                                  then 1       (: preferred prefix for elements comes first :)
                                                  else last()  (: but attributes *must* use a prefix (comes last) :)
                                                 ]
                                                 /name(.)"/>
    <xsl:variable name="maybe-colon" select="if ($prefix) then ':' else ''"/>
    <xsl:sequence select="concat($prefix, $maybe-colon, local-name($node))"/>
  </xsl:function>

  <!-- Print out some diagnostics to show what's going on beneath the covers. -->
  <xsl:function name="nn:diagnostics">
    <xsl:param name="doc"      as="document-node()"/>
    <xsl:param name="ns-prefs" as="element(ns)*"/>
    <diagnostics>
      <diagnostic name="candidate-bindings-doc">
        <xsl:copy-of select="nn:candidate-bindings-doc($doc,$ns-prefs)"/>
      </diagnostic>
      <diagnostic name="final-bindings-doc">
        <xsl:copy-of select="nn:final-bindings-doc($doc,$ns-prefs)"/>
      </diagnostic>
    </diagnostics>
  </xsl:function>

</xsl:stylesheet>
