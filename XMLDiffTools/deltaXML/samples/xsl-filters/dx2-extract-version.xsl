<?xml version="1.0" encoding="UTF-8"?>
<!-- $Id$ -->
<!-- Copyright (c) 2007-2008 DeltaXML Ltd. All rights reserved -->
<!--
    This stylesheet extracts a specified single document from a deltaV2 full-context delta file.
    The styesheet will process a changes-only delta but the result may not be useful.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
    xmlns:xs="http://www.w3.org/2001/XMLSchema">
    
    <xsl:import href="dx2-extract-version-moded.xsl"/>
  
    <xsl:output method="xml" indent="no" version="1.0"/>
    
    <!-- this param sets the version we want to extract, e.g. 'A' or 'B' -->
    <xsl:param name="version-to-extract" select="'A'"></xsl:param>
  
    <xsl:template match="/" mode="#default">
      <xsl:choose>
        <xsl:when test="$version-to-extract='A'">
          <xsl:apply-templates select="/" mode="A"/>
        </xsl:when>
        <xsl:when test="$version-to-extract='B'">
          <xsl:apply-templates select="/" mode="B"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message terminate="yes">Invalid version-to-extract parameter.</xsl:message>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>
    
</xsl:stylesheet>