<?xml version="1.0" encoding="iso-8859-1"?>
<!-- Copyright (c) 2000-2010 DeltaXML Ltd. All rights reserved -->
<!-- $Id$ -->
<!--
    This stylesheet demonstrates how deltaxml:ordered and deltaxml:key
    attributes can be added to an XML Schema document.

    Using this stylesheet to process XML Schema files before they are
    compared with DeltaXML will enable XML Schema files to be
    compare intelligently when, for example, the order of element
    definitions is different in the two files.

    See https://docs.deltaxml.com/xml-compare/latest/comparing-xml-schema-2133845.html
    for a paper describing this.  This code is offered as an example
    and may not be correct for handling all XML Schema files.
-->

<!-- Define the xsd and deltaxml: namespace and prefixes for the stylesheet -->
<xsl:stylesheet version="1.0"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
   xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1">

  <!-- Enable or disable extra whitespace on output -->
  <xsl:output method="xml" indent="no" />

  <xsl:template match="node() | @*">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- Handle specific element types here -->

  <!-- Add deltaxml:ordered="false" to unordered elements -->
  <xsl:template match="xsd:all | xsd:attributeGroup | xsd:choice | 
                xsd:complexType |
                xsd:element | xsd:extension | xsd:redefine | xsd:restriction 
                | xsd:schema |
                xsd:union | xsd:unique">
    <xsl:copy>
      <xsl:attribute name="deltaxml:ordered">false</xsl:attribute>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- For elements that can only appear once but are within an 
       unordered element, add deltaxml:key="single" attribute -->
  <xsl:template match="xsd:all/xsd:annotation | 
                xsd:attributeGroup/xsd:annotation |
                xsd:attributeGroup/xsd:anyAttribute | xsd:choice/xsd:annotation |
                xsd:complexType/xsd:annotation  | xsd:complexType/xsd:simpleContent |
                xsd:complexType/xsd:complexContent  |
                xsd:complexType/xsd:sequence |
                xsd:complexType/xsd:group  | xsd:complexType/xsd:anyAttribute |
                xsd:element/xsd:annotation | xsd:element/xsd:simpleType |
                xsd:extension/xsd:all |
                xsd:extension/xsd:sequence |
                xsd:extension/xsd:group | xsd:extension/xsd:anyAttribute |
                xsd:restriction/xsd:annotation |
                xsd:restriction/xsd:sequence |
                xsd:restriction/xsd:group | xsd:restriction/xsd:simpleType |
                xsd:restriction/xsd:anyAttribute | xsd:union/xsd:annotation |
                xsd:unique/xsd:annotation | xsd:unique/xsd:selector">
    <xsl:copy>
      <!-- add a deltaxml:key="single" attribute, then copy all other attributes -->
      <xsl:attribute name="deltaxml:key">single</xsl:attribute>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xsd:complexType/xsd:all | xsd:complexType/xsd:choice  |
                xsd:element/xsd:complexType | xsd:extension/xsd:choice |
                xsd:restriction/xsd:all | xsd:restriction/xsd:choice">
    <xsl:copy>
      <xsl:attribute name="deltaxml:ordered">false</xsl:attribute>
      <xsl:attribute name="deltaxml:key">single</xsl:attribute>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- For elements within an unordered element, add keys as appropriate -->
  <xsl:template match="xsd:attributeGroup/xsd:attribute |
                xsd:choice/xsd:group |
                xsd:complexType/xsd:attribute |
                xsd:extension/xsd:attribute |
                xsd:restriction/xsd:attribute">
    <xsl:copy>
      <xsl:choose>
        <xsl:when test="@name">
          <xsl:attribute name="deltaxml:key"><xsl:value-of select="@name"/></xsl:attribute>
        </xsl:when>
        <xsl:when test="@ref">
          <xsl:attribute name="deltaxml:key"><xsl:value-of select="@ref"/></xsl:attribute>
        </xsl:when>
      </xsl:choose>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="xsd:all/xsd:element |
                xsd:attributeGroup/xsd:attributeGroup | xsd:choice/xsd:element |
                xsd:complexType/xsd:attributeGroup | xsd:extension/xsd:attributeGroup |
                xsd:restriction/xsd:attributeGroup ">
    <xsl:copy>
      <xsl:attribute name="deltaxml:ordered">false</xsl:attribute>
      <xsl:choose>
        <xsl:when test="@name">
          <xsl:attribute name="deltaxml:key"><xsl:value-of select="@name"/></xsl:attribute>
        </xsl:when>
        <xsl:when test="@ref">
          <xsl:attribute name="deltaxml:key"><xsl:value-of select="@ref"/></xsl:attribute>
        </xsl:when>
      </xsl:choose>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>



  <xsl:template match="xsd:choice/xsd:any |
                xsd:choice/xsd:sequence ">
    <xsl:copy>
      <xsl:if test="@id">
        <xsl:attribute name="deltaxml:key"><xsl:value-of select="@id"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xsd:choice/xsd:choice">
    <xsl:copy>
      <xsl:attribute name="deltaxml:ordered">false</xsl:attribute>
      <xsl:if test="@id">
        <xsl:attribute name="deltaxml:key"><xsl:value-of select="@id"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>


  <xsl:template match="xsd:element/xsd:key |
                xsd:element/xsd:keyref |
                xsd:redefine/xsd:simpleType |
                xsd:redefine/xsd:group |
                xsd:schema/xsd:attribute |
                xsd:schema/xsd:group | xsd:schema/xsd:notation |
                xsd:schema/xsd:simpleType | xsd:union/xsd:simpleType ">
    <xsl:copy>
      <xsl:if test="@name">
        <xsl:attribute name="deltaxml:key"><xsl:value-of select="@name"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xsd:element/xsd:unique |
                xsd:redefine/xsd:complexType | xsd:redefine/xsd:attributeGroup |
                xsd:schema/xsd:complexType | xsd:schema/xsd:element |
                xsd:schema/xsd:attributeGroup">
    <xsl:copy>
      <xsl:attribute name="deltaxml:ordered">false</xsl:attribute>
      <xsl:if test="@name">
        <xsl:attribute name="deltaxml:key"><xsl:value-of select="@name"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>


  <xsl:template match="xsd:schema/xsd:import">
    <xsl:copy>
      <xsl:if test="@namespace">
        <xsl:attribute name="deltaxml:key"><xsl:value-of select="@namespace"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xsd:schema/xsd:include">
    <xsl:copy>
      <xsl:if test="@schemaLocation">
        <xsl:attribute name="deltaxml:key"><xsl:value-of select="@schemaLocation"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="xsd:schema/xsd:redefine">
    <xsl:copy>
      <xsl:attribute name="deltaxml:ordered">false</xsl:attribute>
      <xsl:if test="@schemaLocation">
        <xsl:attribute name="deltaxml:key"><xsl:value-of select="@schemaLocation"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  

  <xsl:template match="xsd:unique/xsd:field">
    <xsl:copy>
      <xsl:if test="@xpath">
        <xsl:attribute name="deltaxml:key"><xsl:value-of select="@xpath"/></xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>
