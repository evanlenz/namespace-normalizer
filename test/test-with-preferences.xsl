<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:nn="http://lenzconsulting.com/namespace-normalizer"
  exclude-result-prefixes="xs nn">

  <xsl:import href="../normalize-namespaces.xsl"/>

  <xsl:variable name="ns-prefs" as="element(ns)*">
    <ns prefix=""    uri="reserved"/>
    <ns prefix="x"   uri="default3"/>
    <ns prefix="ns2" uri="already_taken"/>
    <ns prefix="foo" uri="another"/>
  </xsl:variable>

  <xsl:variable name="ns-prefs2" as="element(ns)*">
    <ns prefix=""    uri="default1"/>
  </xsl:variable>

  <xsl:template match="/">
    <results>
      <!-- Allow use of reserved prefixes -->
      <xsl:copy-of select="nn:normalize(., $ns-prefs, false())"/>
      <!-- Disallow use of reserved prefixes -->
      <xsl:copy-of select="nn:normalize(., $ns-prefs, true())"/>

      <!-- Force given default namespace -->
      <xsl:copy-of select="nn:normalize(document('input_with_unqualified.xml'), $ns-prefs2, true())"/>
    </results>
  </xsl:template>

</xsl:stylesheet>
