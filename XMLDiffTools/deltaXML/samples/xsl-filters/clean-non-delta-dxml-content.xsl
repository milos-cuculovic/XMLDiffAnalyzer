<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                xmlns:format="http://www.deltaxml.com/ns/formatting"
                exclude-result-prefixes="#all"
                version="3.0">
  
  <xsl:param name="keep-format-markers" as="xs:boolean" select="false()"/>
  
  
  <!-- identity transform -->
  <xsl:mode on-no-match="shallow-copy"/>
  
  <!-- at the root element, ensure that any deltaxml namespaces are declared -->
  <xsl:template match="/*">
    <xsl:copy>
      <xsl:namespace name="deltaxml" select="'http://www.deltaxml.com/ns/well-formed-delta-v1'"/>
      <xsl:namespace name="dxx" select="'http://www.deltaxml.com/ns/xml-namespaced-attribute'"/>
      <xsl:namespace name="dxa" select="'http://www.deltaxml.com/ns/non-namespaced-attribute'"/>
      <xsl:apply-templates select="@*, node()"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="@deltaxml:deltaV2 |
                       @deltaxml:deltaTag |
                       @deltaxml:deltaTagStart | 
                       @deltaxml:deltaTagMiddle |
                       @deltaxml:deltaTagEnd |
                       @deltaxml:version |
                       @deltaxml:content-type |
                       deltaxml:attributes/@deltaxml:ordered |
                       @deltaxml:move-id |
                       @deltaxml:move-idref |
                       @deltaxml:wordDelta">
    <xsl:copy/>
  </xsl:template>
  
  <xsl:template match="@deltaxml:format">
    <xsl:if test="$keep-format-markers">
      <xsl:copy/>
    </xsl:if>
  </xsl:template>
  
  <!-- remove any deltaxml attributes not in the list above -->
  <xsl:template match="@deltaxml:* | @format:exists"/>

  
</xsl:stylesheet>