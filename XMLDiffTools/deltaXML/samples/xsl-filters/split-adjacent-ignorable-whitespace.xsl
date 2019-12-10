<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="#all"
  xmlns:preserve="http://www.deltaxml.com/ns/preserve" 
  xmlns:er="http://www.deltaxml.com/ns/entity-references"
  xmlns:fn="urn:deltaxml.com.internal.function"
  version="2.0">
  
  <xsl:output indent="no"/>
  
  <!-- 
       Purpose: XSLT filter that processes preserve:ignorable whitespace elements. Where these have
       a deltaV2=A=B attribute and are immediately followed by an element with a deltaV2=A or deltaV2=B,
       the preserve:ignorable element should be split into separate A and B parts that surround the
       deleted 'real' element
    
    before:
    <preserve:ignorable deltaxml:deltaV2="A=B">
    </preserve:ignorable>
    <p deltaxml:deltaV2="A" deltaxml:mixed-content="true" id="a">ff9aacab-79f7-47b2-aadc-52192fe21225</p>
    <p deltaxml:deltaV2="B" deltaxml:mixed-content="true" id="d">987c7701-ec0e-4eef-8cd0-59b3fdd9e6b1</p>
      
    after:
    <preserve:ignorable deltaxml:deltaV2="A">
    </preserve:ignorable>
    <p deltaxml:deltaV2="A" deltaxml:mixed-content="true" id="a">ff9aacab-79f7-47b2-aadc-52192fe21225</p>
    <preserve:ignorable deltaxml:deltaV2="B">
    </preserve:ignorable>
    <p deltaxml:deltaV2="B" deltaxml:mixed-content="true" id="d">987c7701-ec0e-4eef-8cd0-59b3fdd9e6b1</p>
  -->
  
  <xsl:template match="/*">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates select="node()[1]"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="node()">
    <xsl:param name="ignorable-copy" as="element()?"/>
    <xsl:variable name="following-node-dv2" as="xs:string?" select="following-sibling::node()[1]/@deltaxml:deltaV2"/>
    <xsl:variable name="following-node-dv2-2" as="xs:string?" select="following-sibling::node()[2]/@deltaxml:deltaV2"/>
    
    <xsl:variable name="next-ignorable-copy" as="element()?">
      <xsl:if test="self::preserve:ignorable[@deltaxml:deltaV2='A=B'] and string-length($following-node-dv2) eq 1 and string-length($following-node-dv2-2) eq 1 and $following-node-dv2 ne $following-node-dv2-2">
        <xsl:copy>
          <xsl:copy-of select="@* except @deltaxml:deltaV2"/>
          <xsl:attribute name="deltaxml:deltaV2" select="if($following-node-dv2 eq 'A') then 'B' else 'A'"/>
          <xsl:sequence select="node()"/>
        </xsl:copy>
      </xsl:if>
    </xsl:variable>
    
    <xsl:choose>
      <xsl:when test="$next-ignorable-copy">
        <xsl:copy copy-namespaces="no">
          <xsl:copy-of select="@* except @deltaxml:deltaV2"/>
          <xsl:attribute name="deltaxml:deltaV2" select="$following-node-dv2"/>
          <xsl:sequence select="node()"/>
        </xsl:copy>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy copy-namespaces="no">
          <xsl:copy-of select="@*"/>
          <xsl:apply-templates select="./node()[1]"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
    
    <xsl:sequence select="$ignorable-copy"/>

    <xsl:apply-templates select="following-sibling::node()[1]">
      <xsl:with-param name="ignorable-copy" select="$next-ignorable-copy"/>
    </xsl:apply-templates>
    
  </xsl:template>
  
</xsl:stylesheet>