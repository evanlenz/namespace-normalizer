<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:nn="http://lenzconsulting.com/namespace-normalizer"
  exclude-result-prefixes="xs nn">

  <xsl:import href="../normalize-namespaces.xsl"/>

  <xsl:variable name="ns-prefs" as="element(ns)*">
    <ns prefix="x"   uri="default3"/>
    <ns prefix="foo" uri="another"/>
  </xsl:variable>

  <xsl:template match="/">
    <xsl:copy-of select="nn:normalize(., $ns-prefs, true())"/>
  </xsl:template>

</xsl:stylesheet>
