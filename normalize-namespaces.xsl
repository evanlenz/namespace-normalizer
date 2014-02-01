<!-- This stylesheet performs an identity transformation,
     except that it also changes the namespace declarations
     in the result such that they all appear on the document
     element, while preserving all the same effective element
     and attribute node names througout the document.
-->
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:my="http://lenzconsulting.com/namespace-normalizer"
  exclude-result-prefixes="xs my">

  <!-- Set to true to print debugging info -->
  <xsl:param name="DEBUG" select="false()"/>

  <!-- The first namespace node for each unique namespace URI -->
  <xsl:variable name="unique-uri-namespace-nodes"
                select="for $uri in distinct-values(//namespace::*[not(name() eq 'xml')])
                        return (//namespace::*[. eq $uri])[1]"/>


  <!-- These candidate bindings disallow default declarations
       for namespaces that need a prefix, but they don't yet
       prevent duplicate prefixes; that comes later. -->
  <xsl:variable name="candidate-bindings">
    <xsl:for-each select="$unique-uri-namespace-nodes">
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
  </xsl:variable>


  <!-- Create the final list of bindings, preventing the duplication of prefixes. -->
  <xsl:variable name="final-bindings">
    <xsl:apply-templates mode="remove-duplicates" select="$candidate-bindings/binding"/>
  </xsl:variable>

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
  <xsl:variable name="new-namespace-nodes" as="item()*">
    <xsl:for-each select="$final-bindings/binding">
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
  </xsl:variable>

  <!-- Optionally output a DEBUG message -->
  <xsl:template match="/">
    <xsl:if test="$DEBUG">
      <xsl:call-template name="do-xsl-message-diagnostics"/>
    </xsl:if>
    <xsl:apply-templates/>
  </xsl:template>

  <!-- Give every element the same namespace nodes (the ones we've decided on above) -->
  <xsl:template match="*">
    <xsl:element name="{my:new-qname(.)}" namespace="{namespace-uri()}">
      <xsl:copy-of select="$new-namespace-nodes"/>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Replicate attributes -->
  <xsl:template match="@*">
    <xsl:attribute name="{my:new-qname(.)}" namespace="{namespace-uri()}" select="."/>
  </xsl:template>

  <!-- Do a simple copy of the other nodes -->
  <xsl:template match="text() | comment() | processing-instruction()">
    <xsl:copy/>
  </xsl:template>

  <!-- Get the lexical QName based on the bindings we've chosen -->
  <xsl:function name="my:new-qname">
    <xsl:param name="node"/>
    <xsl:variable name="prefix" select="$new-namespace-nodes[. eq namespace-uri($node)]/name(.)"/>
    <xsl:variable name="maybe-colon" select="if ($prefix) then ':' else ''"/>
    <xsl:sequence select="concat($prefix, $maybe-colon, local-name($node))"/>
  </xsl:function>

  <!-- Print out some diagnostics to show what's going on beneath the covers. -->
  <xsl:template name="do-xsl-message-diagnostics">
    <xsl:message>
      <diagnostics xml:space="preserve">
        <diagnostic name="candidate-bindings">
          <xsl:copy-of select="$candidate-bindings"/>
        </diagnostic>
        <diagnostic name="final-bindings">
          <xsl:copy-of select="$final-bindings"/>
        </diagnostic>
      </diagnostics>
    </xsl:message>
  </xsl:template>

</xsl:stylesheet>
