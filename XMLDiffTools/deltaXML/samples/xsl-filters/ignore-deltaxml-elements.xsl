<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                exclude-result-prefixes="#all"
                version="2.0">
  
  <xsl:param name="deltaxml-element-names" as="xs:string*" select="()"/>
  <xsl:variable name="deltaxmlns" select="'http://www.deltaxml.com/ns/well-formed-delta-v1'"/>
  <xsl:variable name="deltaxml-qnames" as="xs:QName*"
    select="for $a in $deltaxml-element-names return QName($deltaxmlns, $a)"/>

  
  <!-- identity transform for all nodes except elements -->
  <xsl:template match="comment() | processing-instruction() | text() | @*">
    <xsl:copy-of select="."/>
  </xsl:template>
  
  <!-- identity transform for all elements - unless matches deltaxml element names list -->
  <xsl:template match="*">
    <xsl:if test="not(node-name(.) = $deltaxml-qnames)">
      <xsl:copy>
        <xsl:apply-templates select="@*, node()"/>
      </xsl:copy>   
    </xsl:if>    
  </xsl:template>
  
</xsl:stylesheet>
