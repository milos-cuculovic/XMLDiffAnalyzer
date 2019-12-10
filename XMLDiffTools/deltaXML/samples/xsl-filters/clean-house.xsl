<?xml version="1.0" encoding="iso-8859-1"?>
<!-- Copyright (c) 2003-2010 DeltaXML Ltd. All rights reserved -->
<!-- $Id$ -->
<!-- 
     This stylesheet removes all deltaxml elements and attributes
     produced by the XMLComparator, XMLCombiner and 2 way-merge XSL
     script.  As it removes all deltaxml attributes care should be
     taken over deltaxml:ordered and deltaxml:key attributes which are
     typically inserted prior to comparison 
  -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
  xmlns:dxwarn2="http://www.deltaxml.com/ns/warning-for-2-way-merge"
  exclude-result-prefixes="deltaxml dxwarn2">


  <xsl:output method="xml" indent="no" />

  <xsl:template match="/|@*|comment()|processing-instruction()">
    <xsl:copy>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <!-- The identity transform (using xsl:copy, as per section 7 of the
       xslt 1.0 spec) copies all namespace nodes from the source
       element to the result element.  Rather than use xsl:copy we
       need to explicitly create the element and do a controlled copy
       of the namespace nodes.  See the namespaces section of the XSLT
       FAQ: http://www.dpawson.co.uk/xsl/sect2/N5536.html and in
       particular Q37 and A40, and XSLT 2nd Ed. (Michael Kay) page 82.
       There doesn't seem to be a way of refering to the namespace
       nodes in the input tree using the xmlns: prefix definitions at
       the top of this file, instead we can access either the prefixes
       or the namespace URL used in the input tree -->

  <!-- copy elements, but remove DeltaXML namespace declarations -->
  <xsl:template match="*">
    <xsl:element name="{name()}" namespace="{namespace-uri()}">
      <xsl:copy-of select="namespace::*[string() != 'http://www.deltaxml.com/ns/well-formed-delta-v1']
                                       [string() != 'http://www.deltaxml.com/ns/warning-for-2-way-merge']
                                       [string() != 'http://www.deltaxml.com/ns/non-namespaced-attribute']
                                       [string() != 'http://www.deltaxml.com/ns/xml-namespaced-attribute']"/>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <!-- strip DeltaXML attributes -->
  <xsl:template match="@deltaxml:* | @dxwarn2:*"/>

  <!-- strip DeltaXML elements -->
  <xsl:template match="deltaxml:* | dxwarn2:*"/>

</xsl:stylesheet>
