<?xml version="1.0" encoding="UTF-8"?>
<!-- Copyright (c) 2012 DeltaXML Ltd.  All rights reserved. -->

<!--
  This filter is intended to remove all nested 'ignore change' markup.
  
  Note: The original semantics of the ignore change processing was to ignore nested changes. The current
  semantics essentially applies the nested changes in a bottom up fashion. This filter enables the
  original semantics to be kept, by removing the nested ignored changes that were previously ignored.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
  version="2.0">
  
  <!-- 
    Default copy template
  -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>

  <!--
    Remove nested ignore change marker attribute (@deltaxml:ignore-changes)
  -->
  <xsl:template match="*[exists(@deltaxml:ignore-changes) and exists(ancestor::*/@deltaxml:ignore-changes)]">
    <xsl:copy>
      <xsl:apply-templates select="@* except @deltaxml:ignore-changes, node()" />
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
