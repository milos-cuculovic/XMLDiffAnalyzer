<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                version="2.0">
  
  <!-- Enable or disable extra whitespace on output -->
  <xsl:output method="xml" indent="no" />

  <!-- strip-space can be omitted if a single space in place of whitespace nodes is needed -->
  <!--<xsl:strip-space elements="*"/>-->
  
  <xsl:template match="node() | @*">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- flatten the span elements but keep the style information with the start marker -->
  <xsl:template match="*[@deltaxml:format='true']" mode="#all">
    <xsl:element name="deltaxml:format-start" namespace="http://www.deltaxml.com/ns/well-formed-delta-v1">
      <xsl:element name="deltaxml:element" namespace="http://www.deltaxml.com/ns/well-formed-delta-v1">
        <xsl:copy>
          <xsl:apply-templates select="@* except @deltaxml:format"/>
        </xsl:copy>
      </xsl:element>
    </xsl:element>
    <xsl:apply-templates select="node()"/>
    <xsl:if test="count(node())=0">
      <xsl:element name="deltaxml:empty" namespace="http://www.deltaxml.com/ns/well-formed-delta-v1"/>
    </xsl:if>
    <xsl:element name="deltaxml:format-end" namespace="http://www.deltaxml.com/ns/well-formed-delta-v1"/>
  </xsl:template>
</xsl:stylesheet>
