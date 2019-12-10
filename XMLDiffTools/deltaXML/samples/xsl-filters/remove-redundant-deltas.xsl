<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                version="3.0">

  <xsl:mode on-no-match="shallow-copy"/>
  
  <xsl:template match="*[not(ancestor-or-self::deltaxml:*)][@deltaxml:deltaV2='A'][ancestor::*[@deltaxml:deltaV2='A']]">
    <xsl:copy>
      <xsl:apply-templates select="@* except @deltaxml:deltaV2, node()"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[not(ancestor-or-self::deltaxml:*)][@deltaxml:deltaV2='B'][ancestor::*[@deltaxml:deltaV2='B']]">
    <xsl:copy>
      <xsl:apply-templates select="@* except @deltaxml:deltaV2, node()"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[not(ancestor-or-self::deltaxml:*)][@deltaxml:deltaV2='A=B'][ancestor::*[@deltaxml:deltaV2='A=B']]">
    <xsl:copy>
      <xsl:apply-templates select="@* except @deltaxml:deltaV2, node()"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="deltaxml:textGroup[@deltaxml:deltaV2='A'][ancestor::*[@deltaxml:deltaV2='A']]">
    <xsl:copy-of select="deltaxml:text/text()"/>
  </xsl:template>
  
  <xsl:template match="deltaxml:textGroup[@deltaxml:deltaV2='B'][ancestor::*[@deltaxml:deltaV2='B']]">
    <xsl:copy-of select="deltaxml:text/text()"/>
  </xsl:template>
  
</xsl:stylesheet>