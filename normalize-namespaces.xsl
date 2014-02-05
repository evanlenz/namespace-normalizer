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

  <!-- This function can be called from importing code -->
  <xsl:function name="nn:normalize">
    <xsl:param name="doc" as="document-node()"/>
    <!-- print a DEBUG message, if applicable -->
    <xsl:if test="$DEBUG">
      <xsl:message>
        <xsl:copy-of select="nn:diagnostics($doc)"/>
      </xsl:message>
    </xsl:if>
    <!-- Apply the new namespace nodes -->
    <xsl:apply-templates mode="normalize-namespaces" select="$doc">
      <xsl:with-param name="ns-nodes" select="nn:new-namespace-nodes($doc)" tunnel="yes"/>
    </xsl:apply-templates>
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
    <xsl:param name="doc" as="document-node()"/>
    <xsl:document>
      <xsl:for-each select="nn:unique-uri-namespace-nodes($doc)">
        <binding>
          <uri>
            <xsl:value-of select="."/>
          </uri>

          <!-- is this a default namespace? -->
          <xsl:variable name="is-default" select="not(name(.))"/>

          <!-- must the URI have a prefix? -->
          <xsl:variable name="needs-prefix"
                        select="//*[not(namespace-uri())] or //@*[namespace-uri() eq current()]"/>
          <xsl:choose>

            <!-- do we need to add a prefix? -->
            <xsl:when test="$is-default and $needs-prefix">

              <!-- is there an existing prefix we can use? -->
              <xsl:variable name="alternate-prefix-candidate" select="(//namespace::*[. eq current()][name()])[1]"/>
              <xsl:choose>
                <xsl:when test="$alternate-prefix-candidate">
                  <!-- Then use it! -->
                  <prefix>
                    <xsl:value-of select="name($alternate-prefix-candidate)"/>
                  </prefix>
                </xsl:when>
                <xsl:otherwise>
                  <!-- Leave a note to ourselves that we need to generate a new prefix -->
                  <generate-prefix/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:when>

            <!-- otherwise, we can use the existing (possibly empty) prefix as is -->
            <xsl:otherwise>
              <prefix>
                <xsl:value-of select="name()"/>
              </prefix>
            </xsl:otherwise>
          </xsl:choose>
        </binding>
      </xsl:for-each>
    </xsl:document>
  </xsl:function>


  <!-- Create the final list of bindings, preventing the duplication of prefixes. -->
  <xsl:function name="nn:final-bindings" as="element(binding)*">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:apply-templates mode="remove-duplicates" select="nn:candidate-bindings-doc($doc)/binding"/>
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
    <xsl:param name="doc" as="document-node()"/>
    <xsl:for-each select="nn:final-bindings($doc)">
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
    <xsl:variable name="prefix" select="$ns-nodes[. eq namespace-uri($node)]/name(.)"/>
    <xsl:variable name="maybe-colon" select="if ($prefix) then ':' else ''"/>
    <xsl:sequence select="concat($prefix, $maybe-colon, local-name($node))"/>
  </xsl:function>

  <!-- Print out some diagnostics to show what's going on beneath the covers. -->
  <xsl:function name="nn:diagnostics">
    <xsl:param name="doc" as="document-node()"/>
    <diagnostics>
      <diagnostic name="candidate-bindings-doc">
        <xsl:copy-of select="nn:candidate-bindings-doc($doc)"/>
      </diagnostic>
      <diagnostic name="final-bindings">
        <xsl:copy-of select="nn:final-bindings($doc)"/>
      </diagnostic>
    </diagnostics>
  </xsl:function>

</xsl:stylesheet>
