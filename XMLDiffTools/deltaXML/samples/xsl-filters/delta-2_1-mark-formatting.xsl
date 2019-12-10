<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                exclude-result-prefixes="#all"
                version="2.0">
  
  <xsl:param name="formatting-element-names" as="xs:string*" select="()"/>
  
  <!-- identity transform -->
  <xsl:template match="node() | @*" mode="#all">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- mark bold elements as text formatting elements -->
  <xsl:template match="*">
    <xsl:choose>
      <xsl:when test="local-name(.) = $formatting-element-names">
        <xsl:copy>
          <xsl:attribute name="deltaxml:format" select="'true'"/>
          <xsl:apply-templates select="@*, node()"/>
        </xsl:copy>
      </xsl:when>
      <xsl:otherwise>
          <xsl:copy>
            <xsl:apply-templates select="@*, node()"/>
          </xsl:copy>       
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
</xsl:stylesheet>
