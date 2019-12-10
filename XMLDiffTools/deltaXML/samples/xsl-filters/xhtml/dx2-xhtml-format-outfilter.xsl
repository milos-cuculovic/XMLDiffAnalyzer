<?xml version="1.0" encoding="UTF-8"?>
<!-- Copyright (c) 2010-2014 DeltaXML Ltd.  All rights reserved. -->
<!-- 
  This filter is used to reconstruct the spans that were flattened in the infilter.
 
  The imported filter makes use of the xsl:iterate instruction which is a new feature of XSLT 3.0.  Although XSLT 3.0 is
  a W3C working draft, this instruction has been available in Saxon for many years under the guise of saxon:iterate.
  
  In order to make use of this filter in a pipeline some configuration may be necessary in user created or modified DXP
  files or when using the cores9api package.
  
  In a DXP file set a transformerAttribute at the end, for example:
  
  <comparatorPipeline>
    ...
    <transformerAttributes>
      <stringAttribute name="http://saxon.sf.net/feature/xsltVersion" literalValue="3.0"/>
    </transformerAttributes>
  </comparatorPipeline>
  
  The corresponding configuration in Java code would be:
  
  PipelinedComparatorS9 pcs9= new PipelinedComparatorS9();
  pcs9.setTransformerConfigurationOption("http://saxon.sf.net/feature/xsltVersion", "3.0");

 -->
 <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                 xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                 xmlns:dxa="http://www.deltaxml.com/ns/non-namespaced-attribute"
                 xmlns:dxx="http://www.deltaxml.com/ns/xml-namespaced-attribute"
                 xmlns:xhtml="http://www.w3.org/1999/xhtml"
                 xmlns="http://www.w3.org/1999/xhtml"
                 version="3.0">
   
  <xsl:import href="dx2-format-outfilter.xsl"/>
  <xsl:output method="xml" indent="no" omit-xml-declaration="yes" />

  <!-- when we're dealing with xhtml we want to display changes to
  formatting with the Javascript buttons at the top, hence need
  both types of formatting when their is a conflict.  We use xhtml spans
  to identify the data to be selected by the buttons.  The class
  information will be supplied by a subsequence filter. -->

  <xsl:template match="*[deltaxml:format-start][@deltaxml:deltaV2='A!=B']">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <span class="delete_version" deltaxml:deltaV2="A">
        <xsl:call-template name="group">
          <xsl:with-param name="sequence" select="node()[not(self::deltaxml:format-start[@deltaxml:deltaV2='B'] or self::deltaxml:format-end[@deltaxml:deltaV2='B'] or self::deltaxml:element)]"/>
          <xsl:with-param name="version" select="'A'"/>
        </xsl:call-template>
      </span>
      <span class="add_version" deltaxml:deltaV2="B">
        <xsl:call-template name="group">
          <xsl:with-param name="sequence" select="node()[not(self::deltaxml:format-start[@deltaxml:deltaV2='A'] or self::deltaxml:format-end[@deltaxml:deltaV2='A'] or self::deltaxml:element)]"/>
          <xsl:with-param name="version" select="'B'"/>
        </xsl:call-template>
      </span>
      <span class="modify_version" deltaxml:deltaV2="A!=B">
        <xsl:call-template name="group">
          <xsl:with-param name="sequence" select="node()[not(self::deltaxml:format-start[@deltaxml:deltaV2='A'] or self::deltaxml:format-end[@deltaxml:deltaV2='A'] or self::deltaxml:element)]"/>
          <xsl:with-param name="version" select="'B'"/>
        </xsl:call-template>
      </span>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>