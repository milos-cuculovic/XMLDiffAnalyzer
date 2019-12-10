<?xml version="1.0" encoding="UTF-8"?>
<!-- Copyright (c) 2002-2015 DeltaXML Ltd. All rights reserved -->
<!-- $Id$ -->
<!--
This stylesheet converts a delta file, produced by deltaXML programs,
into HTML that can be displayed in a browser. Two scrollable XML text views
are shown side-by-side. With the 'A' document on the left and the 'B' 
document on the right.

1. The XML text views are indented using CSS
2. A test is made on each element to determine if it contains mixed content
3. Elements are shown as blocks if they are not within mixed content
4. Elements are shown inline if they are within mixed content
5. Block elements may be folded/unfolded
6. Converts DeltaXML's lexical preservation elements to XML syntax
7. Preserves whitespace for comments, processing instructions 
8. Observes xml:space="preserve" attributes
9. Analyses indentation to calculate if whitespace should be preserved for text nodes
10. Light-red/light-green background colors highlight elements that contain changes
11. Red/green background colors show deletes/adds respectively
12. XML numeric character references (e.g. &#160;) are converted to characters by the XML parser
13. Whitespace not reported by standard XML parsers is currently not preserved
14. Initially, all unchanged block elements are folded
15. Toolbar buttons provide fold/unfold for all block elements
16. The current change is highlighted in both xml text views
17. Toolbar buttons or the Up/Down cursor keys select previous/next change
18. The node path is show below the toolbar for the current change item
19. DeltaV2.1 formatting-element changes are shown and highlighted for the A and B documents

-->

<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:saxon="http://saxon.sf.net/"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:dxa="http://www.deltaxml.com/ns/non-namespaced-attribute"
  xmlns:fn="urn:deltaxml.com.internal.function"
  xmlns:dxx="http://www.deltaxml.com/ns/xml-namespaced-attribute"
  xmlns:preserve="http://www.deltaxml.com/ns/preserve" 
  xmlns:er="http://www.deltaxml.com/ns/entity-references"
  xmlns:pi="http://www.deltaxml.com/ns/processing-instructions">
  
  <xsl:output method="html" indent="no" media-type="text/html"  
    exclude-result-prefixes="#all"/>

  <!-- 
    To use a character-map, use the xsl:output declaration below instead.
    This currently only works with DocumentComparator or DCP. 
  -->
  <!--
  <xsl:output method="html" indent="no" media-type="text/html"  
    exclude-result-prefixes="#all" use-character-maps="invalidHTML"/>
  
  <xsl:character-map name="invalidHTML">
    <xsl:output-character character="&#145;" string="&amp;#145;"/>
    <xsl:output-character character="&#146;" string="&amp;#146;"/>
    <xsl:output-character character="&#147;" string="&amp;#147;"/>
    <xsl:output-character character="&#148;" string="&amp;#148;"/>
    <xsl:output-character character="&#150;" string="&amp;#150;"/>
    <xsl:output-character character="&#151;" string="&amp;#151;"/>
    <xsl:output-character character="&#153;" string="&amp;#153;"/>
  </xsl:character-map>
  -->
  
  <!-- apply CSS whitespace-preservation to text with less indentation than that of the parent element -->
  <xsl:param name="smart-whitespace-normalization" select="'true'"/>
  <!-- when smart-whitespace-normalization is set, then do not render whitespace-only changes in mixed-content
       (assuming them to be changes in formatting) still include 'greyed-out' items in differences list  -->
  <xsl:param name="supress-formatting-only-changes" select="'true'"/>
  <!-- if true, all namespaces in rendering are declared in-situ - otherwise, only root element namespaces are declared -->
  <xsl:param name="add-all-namespace-declarations" select="'false'"/>
  <!-- Childlessodes smaller than this number of characters are not foldable -->
  <xsl:param name="no-fold-size" select="50"/>
  <!-- Threshold at which each attribute is rendered on a a new line -->
  <xsl:param name="newline-att-size" select="80"/>
  

  <!-- do not display unchanged subtrees - helps minimize file size -->
  <xsl:param name="minimize-unchanged-display" select="'false'"/>
  <!-- show text in the node-path bar in the header of the diffreport -->
  <xsl:param name="header" select="'&#160;'"/>
  
  <!-- /////// Parameters that are no longer used: ///////////// -->
  <!-- When set to 'no' key-information for modified elements is not shown,
       it is shown when set to 'yes' -->
  <xsl:param name="display-keys" select="'yes'"/>
    
  <!-- this param contains xpaths to attributes that should remain visible even
       when the element's attributes are folded -->
  <xsl:param name="sticky-atts"/>
  <!-- this param is used to determine whether unchhaned elements should be initially collapsed -->
  <xsl:param name="collapseUnchanged" select="'yes'"/>
  <!-- //////////////////////////////////////////////////////// -->
  
  <xsl:variable name="has-content-model" as="xs:boolean" select="exists(/*/@preserve:grammar)"/>
  <xsl:variable name="newline-att-size-int" as="xs:integer" select="xs:integer($newline-att-size)"/>
  <xsl:variable name="no-fold-size-int" as="xs:integer" select="xs:integer($no-fold-size)"/>
  
  <xsl:variable name="reserved-namespaces" as="xs:string*" 
    select="('http://www.deltaxml.com/ns/non-namespaced-attribute',
    'http://www.deltaxml.com/ns/xml-namespaced-attribute',
    'http://www.deltaxml.com/ns/well-formed-delta-v1',
    'http://www.deltaxml.com/ns/preserve')"/>
   
  <!-- if the document element is immediately followed by a text node this is assumed to be for formatting/indenting the xml -->
  <xsl:variable name="is-indented" as="xs:boolean" select="true()"/>
  
  <xsl:variable name="b-smart-whitespace-normalization" as="xs:boolean"
    select="fn:toBool($smart-whitespace-normalization)"/>
  <xsl:variable name="b-supress-formatting-only-changes" as="xs:boolean"
    select="fn:toBool($supress-formatting-only-changes)"/>
  <xsl:variable name="b-add-all-namespace-declarations" as="xs:boolean"
    select="fn:toBool($add-all-namespace-declarations)"/>
  <xsl:variable name="b-minimize-unchanged-display" as="xs:boolean"
    select="fn:toBool($minimize-unchanged-display)"/>
  
  <xsl:variable name="root-space-preserved" as="xs:boolean" select="exists(/*[@preserve:space eq 'preserve'])"/>
  
  
  <xsl:function name="fn:toBool" as="xs:boolean">
    <xsl:param name="text"/>
    <xsl:sequence select="$text=('yes','true','1')"/>
  </xsl:function>
     
  <!-- 
    store unique id for each changed element - in document order
    only create a single id for:
    text change (A and B)
    attribute-value change (A and B)
  -->   
  <xsl:variable name="toc-numbers" as="xs:string*">
    <xsl:for-each 
      select="//*[(
      self::deltaxml:text[empty(preceding-sibling::*) and not(fn:hide-change(., exists(parent::*[@deltaxml:mixed-content, @preserve:mixed-content])))] 
      or self::deltaxml:attributeValue[empty(preceding-sibling::*) and not(parent::dxx:base)]
      or (exists(parent::preserve:entity-group) and empty(preceding-sibling::*))
      ) 
      or (not(self::deltaxml:* or parent::deltaxml:* or parent::preserve:entity-group) and @deltaxml:deltaV2 = ('A', 'B'))]
      [let $isFe := exists((@deltaxml:deltaTag,@deltaxml:deltaTagStart,@deltaxml:deltaTagMiddle,@deltaxml:deltaTagEnd))
      return not($isFe) or ($isFe and exists(text()))]">
      <xsl:sequence select="generate-id(current())"/>
    </xsl:for-each>    
  </xsl:variable>
  
  <!-- use $toc-numbers to find change position -->
  <xsl:function name="fn:tocmap" as="xs:string">
    <xsl:param name="element" as="element()"/>
    <xsl:variable name="adjustElement" as="xs:boolean" 
                  select="exists($element[(self::deltaxml:text,self::deltaxml:attributeValue) and preceding-sibling::*])
                  or exists($element[parent::preserve:entity-group and preceding-sibling::*])"/>
    <xsl:variable name="pfx" as="xs:string" select="if ($adjustElement) then 'r' else ''"/>
    <xsl:variable name="gen-id" select="generate-id(if ($adjustElement) then $element/preceding-sibling::* else $element)"/>
    <xsl:variable name="index-in-sequence"
      select="index-of($toc-numbers, $gen-id)[1]" as="xs:integer?"
    />
    <!-- all elements should have a corresponding change position - but just in case substitue 'n': -->
    <xsl:sequence select="if (exists($index-in-sequence)) then concat($pfx, string($index-in-sequence)) else 'n'"/>
  </xsl:function>
      
  <xsl:template match="/">
   <html>
    <head>
      <title>DeltaXML DiffReport</title>
<!--      <toc-element>
      <xsl:sequence select="$toc-number-elements"/>
      </toc-element>-->
      <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
      <style type="text/css">
  .main {
    top: 62px;
    left: 0px;
    bottom: 0px;
    position: fixed;
    right: 0px;
  }
    .container {
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .container > div {
      flex: 1;
    }
    .horizontalpane {
      height: 100%;
      overflow-y: scroll;
      white-space: nowrap;
    }
    div.horizontalpane.leftpane {
      border-right-style:double;
      border-right-color: #cacaca;
    }
    /* original start */
    body {
              margin: 0px 0px 0px 0px;
    }
        body * {
              font-family: 'Open Sans',helvetica,sans-serif;
        }
        p {
              font-size: 0.9em;
        }
        /* place a border around the delta file and indent on left to allow for +/- button */ 
        /* scrollbar fixes added for IE9 - also scrollintoview changed from 118 to 40 */
        div#deltafile { 
          padding: 5px 5px 5px 0px;
          background-color: white;
          /* overflow-y: auto; */
          scroll-behavior: smoooth;
        }
          div#deltabar {
              background-color: #545f6d;
              border-bottom-style: solid;
              border-width: 1px;
              border-color: #c0c7da;
              color: #c0c7da;
              position: fixed;
              overflow: none;
              top: 0px;
              left: 0px;
              height: 34px;
              width: 100%;
              padding-left: 10px;
              padding-top: 3px;
          }
          #deltabar2 {
              background-color: #343f4d;
              border-width: 1px;
              border-top-style: solid;
              border-color: #a0a7ba;
              color: #a0a7ba;
              position: fixed;
              overflow: none;
              top: 37px;
              left: 0px;
              height: 22px;
              width: 100%;
              padding-top: 0px;
              padding-bottom: 2px;
          }
          #deltabar2 div {
            height: 100%;
          }
          #deltabar2 span {
            font-size: 13px;
            vertical-align: middle;
            padding-left: 5px;
          }
          span.step:after {
            content: "\25b8";
            color: #c0c7da;
          }
          .path-attr {
            color: #ce90ce;
          }
        #deltabar button {
          width: 70px;
          height: 30px;
          font-size: 20px;
          background-color:transparent;
          border-style: solid;
          border-color: #c0c7da;
          color: #c0c7da;
          font-weight: bold;
          border-width: 2px;
          margin-bottom: 5px;
          padding: 0px;
          float: left;
        }
        #deltabar span {
          margin-bottom: 7px;
        }
        #deltabar #button-left {
          border-top-left-radius: 5px;
          border-bottom-left-radius: 5px;
        }
        #deltabar #button-right {
          border-top-right-radius: 5px;
          border-bottom-right-radius: 5px;
          border-left-width: 0px;
        }
        #deltabar button.left:before {
        content: "\2191";
        }
        #deltabar button.right:before {
        content: "\2193";
        }
        #deltabar #button-collapse:before {
        content: "\2196";
        }
        #deltabar #button-expand:before {
        content: "\2198";
        }
        #deltabar #button-switch:before {
        content: "\21CB";
        }
        #deltabar #button-switch {
          line-height: 3px;
          padding-bottom: 4px;
        }
        #deltabar #button-collapse, 
        #deltabar #button-switch, 
        #deltabar #button-expand {
          border-radius: 5px;
          margin-right:0px;
        }
        
        #deltabar > button:hover {
          background-color: #647cab;
        }
        
        #deltabar > button:focus {
          /* prevent button glow */
          outline-color: transparent;
          outline-style: none;
        }       
        #toc-count, #toc-total {
        font-size: 13px;
        margin-top: 7px;
        display: block;
        float: left;
        width: 50px;
        
        }
        #toc-count {
        text-align: right;
        padding-right: 5px;
        }
               
        #deltabar .bar-delta, 
        #deltabar .bar-deltaxml {
          margin-top: 2px;
          display: block;
          float: left; 
          font-size: 20px;
        }
        #deltabar .bar-name {
          margin-top: 2px;
          display: block;
          margin-right: 18px;
          float: left; 
          font-size: 20px;
        }
        #deltabar .bar-delta {
          color:white;
          font-weight: lighter;
          
        }
        #deltabar .bar-deltaxml {
          color: #96c11e;
          margin-right: 8px;
          font-weight: bolder;
          
        }
        #deltabar span.foldlabel {
                display: block;
                float: left;
                margin-left: 5px;
                margin-right: 20px;
                margin-top: 7px;
                font-size: 13px;
        }
        
        span.comment {
          color: black; 
        }
        span.path-special {
          color: #a595ff;
        }
        span[class=expanded] > div[cHot="yes"] {
          border-width: 1px;
          border-top-style: solid;
          border-bottom-style: solid;
          border-right-style: none;
          border-color: red;
          border-top-left-radius: 0px;
          border-bottom-left-radius: 0px;
        }
        
        span[class=expanded] > div {
          border-style: dotted;
          border-top-left-radius: 15px;
          border-bottom-left-radius: 15px;
          border-width:1px;
          border-left-color: #acacac;
          border-right-color: transparent;
          border-bottom-color: transparent;
          border-top-color: transparent;
          padding-left: 5px;
        }       
        div.normal-delta span.modify, 
        div.normal-delta span.modify-PCDATA {
          color: blue; 
          font-style: italic;
        }
        
        .xml-declaration span {
          color: #707070;
        }
        
        span.modify, span.unchanged {
          /* cursor: default; */
        }
        
        /* styling for different data types */
        div.normal-delta div.delete, 
        div.normal-delta span.delete, 
        div.normal-delta span.old-PCDATA {
          color: red;
          text-decoration: line-through;
          font-style: normal;
        }
        
        div.normal-delta div.add, 
        div.normal-delta span.add, 
        div.normal-delta span.new-PCDATA {
          color: green;
          text-decoration: underline;
          font-style: normal;
        }
        
        div.normal-delta div.unchanged, 
        div.normal-delta span.unchanged, 
        div.normal-delta span[data-comment]{ 
          color: grey;  
          font-style: normal;
        }

        div.anchor-parent {
        display: block;
        }
        div.anchor-parent div.anchor-parent, div.anchor-parent div.anchor-parent span:not([data-newline-att])  {
        width:97%;
        }
        div.anchor-parent div.anchor-parent > span:not([data-preserve-space]):not([data-preserve-space-wrap]) {
        white-space: normal;
        }
        
        span[data-minimized] {
          background-color: #cacaca;
        }
        
        span[data-newline-att],  
        span[data-newline-att] + span:not([id=compact-span]) {
          display: block; 
          margin-left: 20px;
        }
        span.modify > span > span > span[data-newline-att] {
          display: inline;
        }

        div.rightpane div.alternate-delta div.anchor-parent > span.modify {
          background:#e5ffef;
        }

        div.leftpane div.alternate-delta div.anchor-parent > span.modify {
          background:#ffecec;
        }
        
        /* ----- START styling for different data types --------- */
        div.leftpane div.alternate-delta div.delete, 
        div.leftpane div.alternate-delta span.delete, 
        div.leftpane div.alternate-delta span.delete *, 
        div.leftpane div.alternate-delta span.old-PCDATA {
          background-color: #ffcbcb;
          font-style: normal;
          /*revert-i*/
        }

        div.rightpane div.alternate-delta div.delete[id], 
        div.rightpane div.alternate-delta span.delete[id]:not([data-newline-att]), 
        div.rightpane div.alternate-delta span.delete[id]:not([data-newline-att]) *, 
        div.rightpane div.alternate-delta span.old-PCDATA {
          background-color: #efefef;
          font-style: normal;
          display: none;
        }
        div.rightpane div.alternate-delta div div.anchor-parent + span.delete[id]:not([data-newline-att]) {
          display: inline;
        }
        div.rightpane div.alternate-delta span.delete[data-newline-att],
        div.leftpane div.alternate-delta span.add[data-newline-att] {
          display: block;
          background-color: #efefef;
          color: transparent!important;
        }
        div.rightpane div.alternate-delta span.delete[data-newline-att] *,
        div.leftpane div.alternate-delta span.add[data-newline-att] * {
          display: inline;
          color: transparent!important;
        }
        div.rightpane div.alternate-delta span[data-newline-att] > span.delete[id] {
        display: block;
        float: right;
        background-color: transparent;
        color: transparent;
        width: 0px;
        overflow: hidden;
        }
        div.leftpane div.alternate-delta span[data-newline-att] > span.add[id] {
        display: block;
        float: right;
        background-color: transparent;
        color: transparent;
        width: 0px;
        overflow: hidden;
        }
        div.rightpane div.alternate-delta div.anchor-parent > div.delete, 
        div.rightpane div.alternate-delta div.anchor-parent > span.delete, 
        div.rightpane div.alternate-delta div.anchor-parent > span.old-PCDATA {
          display: block;
          /* temp: need to ensure block-level element space is preserved */
        }

        div.rightpane div.alternate-delta div.add, 
        div.rightpane div.alternate-delta span.add, 
        div.rightpane div.alternate-delta span.add *, 
        div.rightpane div.alternate-delta span.new-PCDATA {
          background-color: #bbffbb;
          font-style: normal;
        }

        div.leftpane div.alternate-delta div.add[id], 
        div.leftpane div.alternate-delta span.add[id]:not([data-newline-att]), 
        div.leftpane div.alternate-delta span.add[id]:not([data-newline-att]) *, 
        div.leftpane div.alternate-delta span.new-PCDATA {
          background-color: #efefef;
          font-style: normal;
          display: none; 
        }
        div.leftpane div.alternate-delta div div.anchor-parent + span.add[id]:not([data-newline-att]) {
          display: inline;
        }
        
        span[data-preserve-space-wrap] div {
          display: inline;
        }

        div.leftpane div#deltafile.alternate-delta *[data-preserve-space-wrap]  div.add, 
        div.leftpane div#deltafile.alternate-delta *[data-preserve-space-wrap] span.add:not([data-is-attr-val]):not([data-att-unchanged]), 
        div.leftpane div#deltafile.alternate-delta *[data-preserve-space-wrap] span.add:not([data-is-attr-val]):not([data-att-unchanged]) *, 
        div.leftpane div#deltafile.alternate-delta *[data-preserve-space-wrap] span.new-PCDATA {
          background-color: #efefef;
          font-style: normal;
          color: transparent;
          display: inline;
          border-left: none;
          border-right: none;
          padding-left: 0px;
          padding-right: 0px;
        }
        
        div.rightpane div#deltafile.alternate-delta *[data-preserve-space-wrap]  div.delete, 
        div.rightpane div#deltafile.alternate-delta *[data-preserve-space-wrap] span.delete:not([data-is-attr-val]):not([data-att-unchanged]), 
        div.rightpane div#deltafile.alternate-delta *[data-preserve-space-wrap] span.delete:not([data-is-attr-val]):not([data-att-unchanged]) *, 
        div.rightpane div#deltafile.alternate-delta *[data-preserve-space-wrap] span.old-PCDATA {
          background-color: #efefef;
          font-style: normal;
          color: transparent;
          display: inline;
          border-left: none;
          border-right: none;
          padding-left: 0px;
          padding-right: 0px;
        }

        div.leftpane div.alternate-delta div.anchor-parent > div.add, 
        div.leftpane div.alternate-delta div.anchor-parent > span.add, 
        div.leftpane div.alternate-delta div.anchor-parent > span.add span, 
        div.leftpane div.alternate-delta div.anchor-parent > span.new-PCDATA {
          background-color: #efefef;
          color: transparent!important;
          font-style: normal;
          display: inline;
        }
        div.leftpane div.alternate-delta div.anchor-parent > span.add span:not(.collapsed) div {
          display: block;
        }

        div.rightpane div.alternate-delta div.anchor-parent > div.delete, 
        div.rightpane div.alternate-delta div.anchor-parent > span.delete, 
        div.rightpane div.alternate-delta div.anchor-parent > span.delete span, 
        div.rightpane div.alternate-delta div.anchor-parent > span.old-PCDATA {
          background-color: #efefef;
          color: transparent!important;
          font-style: normal;
          display: inline;
        }
        div.rightpane div.alternate-delta div.anchor-parent > span.delete span[data-newline-att]        
        {
        display: block;
        }
        div.leftpane div.alternate-delta div.anchor-parent > span.add span[data-newline-att]        
        {
        display: block;
        }

        div.rightpane div.alternate-delta div.anchor-parent > span.delete span:not(.collapsed) div {
          display: block;
        }

        div.alternate-delta span.modify, 
        div.alternate-delta span.modify-PCDATA,
        div.alternate-delta div.anchor-parent > span.delete,
        div.alternate-delta div.anchor-parent > span.add {
          color: #0000e0!important;
        }

        div.alternate-delta div.unchanged, 
        div.alternate-delta span.unchanged{ 
          color: #707070;
        }
        div#rightpane > div.alternate-delta span[data-x-deltatagstart=A] > span[data-att-unchanged],
        div#rightpane > div.alternate-delta span[data-x-deltatag=A] > span[data-att-unchanged],
        div#leftpane > div.alternate-delta span[data-x-deltatagstart=B] > span[data-att-unchanged],
        div#leftpane > div.alternate-delta span[data-x-deltatag=B] > span[data-att-unchanged] { 
          color: transparent;
        }

        div.alternate-delta span[data-is-attr-full].delete, 
        div.alternate-delta span[data-is-attr-full].add {
          color: #0000e0!important;
        }
        
        div.alternate-delta span[data-is-attr-full].delete > span, 
        div.alternate-delta span[data-is-attr-full].add > span,
        div.alternate-delta span[data-entity-name] {
          color: rebeccapurple!important;
        }
        
        div.alternate-delta span[data-att-value] {
          color: #de00de;
        }
        div#rightpane > div.alternate-delta span[data-x-deltatagstart=A] > span > span[data-att-value],
        div#rightpane > div.alternate-delta span[data-x-deltatag=A] > span > span[data-att-value],
        div#leftpane > div.alternate-delta span[data-x-deltatagstart=B] > span > span[data-att-value],
        div#leftpane > div.alternate-delta span[data-x-deltatag=B] > span > span[data-att-value] {
          color: transparent;
        }
        
        span#compact-span {
          overflow: hidden;
			    transition: max-height 500ms;
        }
        
        div.alternate-delta span#compact-span, 
        div.alternate-delta span[data-text-change], 
        div.alternate-delta span[data-cdata], 
        div.alternate-delta span[data-is-attr-val] {
          color: rebeccapurple; /* temp */
        }
        
        div.alternate-delta span#compact-span span[data-mixed-change],
        div.alternate-delta span#compact-span span[data-mixed-change] {
          color: #0000e0;
        }

        div.alternate-delta span[data-comment], 
        div.alternate-delta span#compact-span[data-comment] {
          color: green;
        }
        
        div.alternate-delta span[data-pi] {
          color: brown;
        }
        
        /* ----- EMD styling for different data types --------- */
        
        span[data-comment], 
        span[data-pi], 
        span[data-cdata], 
        span[data-preserve-space] {
          white-space: pre;
        }
        span[data-mixed-change] > span[data-comment], 
        span[data-mixed-change] > span[data-pi], 
        span[data-mixed-change] > span[data-cdata], 
        span[data-mixed-change] > span[data-preserve-space] {
          white-space: nowrap;
        }
        span[data-newline-att],  span[data-newline-att] + span:not([id=compact-span]) {
        white-space: pre;
        }
        span[data-att-value], span[data-is-attr-val] {
          overflow: visible;
        }
        span[data-newline-att] {
          overflow: hidden;
          width: max-content;
          /* contain float elements propertly */
        }
        span[data-preserve-space-wrap]:not([data-mixed-change]),
        div[cHot=yes] span[data-preserve-space-wrap]:not([data-mixed-change]) {
        white-space: pre;
        }
        
        span.collapse, span.expand {
            border-style: solid;
            border-color: #acacac;
        }
        span.add, span.delete {
            cursor: default;
        }
        /* ------------- formatting elements start ---------- */

        /* ------------- */
        div.alternate-delta span[data-tag-start][data-x-deltaTagEnd="A,B"] {
          display: none;
        }
        div.alternate-delta span[data-close][data-x-deltaTagStart="A,B"] {
          display: none;
        }
        div.alternate-delta span[data-tag-start][data-x-deltaTagMiddle]:not([data-x-deltaTagStart]):not([data-x-deltaTag]),
        div.alternate-delta span[data-tag-close][data-x-deltaTagMiddle]:not([data-x-deltaTagEnd]):not([data-x-deltaTag]) {
        display: none;
        }
        div.alternate-delta span[data-tag-close][data-x-deltaTagStart="A,B"] {
          display: none;
        }
        /* style for folding formatting element tags that are added or deleted  */
        div.rightpane div.alternate-delta div.anchor-parent > span > span[data-tag-close=yes][data-x-deltaTag=A]:not([data-x-deltaTagEnd]), 
        div.rightpane div.alternate-delta div.anchor-parent > span > span[data-tag-close=yes][data-x-deltaTagEnd=A]:not([data-x-deltaTag]) {
          
          border: none;
          border-radius: 10px;
          background:#efefef;
          color: transparent;
          display: inline;
          /*revert*/
          
        }
        div.rightpane div.alternate-delta div.anchor-parent > span > span[data-tag-start=yes][data-x-deltaTag=A]:not([data-x-deltaTagStart]), 
        div.rightpane div.alternate-delta div.anchor-parent > span > span[data-tag-start=yes][data-x-deltaTagStart=A]:not([data-x-deltaTag]) {
          
          border: none;
          border-radius: 10px;
          background: #efefef;
          color: transparent;
          display: inline;
          /*revert*/
          
        }
        /*--*/
        div.leftpane div.alternate-delta div.anchor-parent > span > span[data-tag-close=yes][data-x-deltaTag=B]:not([data-x-deltaTagEnd]), 
        div.leftpane div.alternate-delta div.anchor-parent > span > span[data-tag-close=yes][data-x-deltaTagEnd=B]:not([data-x-deltaTag]) {
          
          border: none;
          border-radius: 10px;
          background: #efefef;
          color: transparent;
          display: inline;
          /*revert*/
          
        }
        div.leftpane div.alternate-delta div.anchor-parent > span > span[data-tag-start=yes][data-x-deltaTag=B]:not([data-x-deltaTagStart]), 
        div.leftpane div.alternate-delta div.anchor-parent > span > span[data-tag-start=yes][data-x-deltaTagStart=B]:not([data-x-deltaTag]) {
          
          border: none;
          border-radius: 10px;
          background: #efefef;
          color: transparent;
          display: inline;
          /*revert*/
          
        }
        div.leftpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTagStart=A]:not([data-x-deltaTag]):not([data-x-deltaTagEnd]),
        div.leftpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTagStart=B]:not([data-x-deltaTag]):not([data-x-deltaTagEnd])  {
          display: none;
        }
        div.leftpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTagEnd=A]:not([data-x-deltaTag]):not([data-x-deltaTagStart]),
        div.leftpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTagEnd=B]:not([data-x-deltaTag]):not([data-x-deltaTagStart])  {
          display: none;
        }
        div.rightpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTagStart=B]:not([data-x-deltaTag]):not([data-x-deltaTagEnd]),
        div.rightpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTagStart=A]:not([data-x-deltaTag]):not([data-x-deltaTagEnd]) {
          display: none;
        }
        div.rightpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTagEnd=B]:not([data-x-deltaTag]):not([data-x-deltaTagStart]),
        div.rightpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTagEnd=A]:not([data-x-deltaTag]):not([data-x-deltaTagStart]) {
          background: blue;
          display: none;
        }
       /* -- */

        div.rightpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTag=A]:not([data-x-deltaTagEnd=B]), 
        div.rightpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTagEnd=A]:not([data-x-deltaTag=B]) {
          display: none;
        }

        div.rightpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTag=A]:not([data-x-deltaTagStart=B]), 
        div.rightpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTagStart=A]:not([data-x-deltaTag=B]) {
          display: none;
        }

        div.leftpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTag=B]:not([data-x-deltaTagEnd=A]), 
        div.leftpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTagEnd=B]:not([data-x-deltaTag=A]) {
          display: none;
        }
        div.leftpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTag=B]:not([data-x-deltaTagStart=A]), 
        div.leftpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTagStart=B]:not([data-x-deltaTag=A]) {
          display: none;
        }

        div.leftpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTag=A], 
        div.leftpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTagEnd=A] {
          /* background-color: yellow; */
          border-style: solid;
          border-left-width: 0px;
          border-right-width: 2px;
          border-top-width: 0px;
          border-bottom-width: 0px;
          border-radius: 10px;
          border-color: blue;
          background: #ffcbcb;
        }
        div.leftpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTag=A], 
        div.leftpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTagStart=A] {
          border-style: solid;
          border-left-width: 2px;
          border-right-width: 0px;
          border-top-width: 0px;
          border-bottom-width: 0px;
          border-radius: 10px;
          border-color: blue;
          background:#ffcbcb;
        }

        div.rightpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTag=B], 
        div.rightpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTagEnd=B] {
          border-style: solid;
          border-left-width: 0px;
          border-right-width: 2px;
          border-top-width: 0px;
          border-bottom-width: 0px;
          border-radius: 10px;
          border-color:  blue;
          background: #bbffbb;
          /*revert-i*/
        }

        div.rightpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTag=B], 
        div.rightpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTagStart=B] {
          border-style: solid;
          border-left-width: 2px;
          border-right-width: 0px;
          border-top-width: 0px;
          border-bottom-width: 0px;
          border-radius: 10px;
          border-color:  blue;
          background: #bbffbb;
          /*revert-i*/
        }
        /* why doesn't this work on left-hand side? */
        div.leftpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTag][data-x-deltaTagStart], 
        div.leftpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTagStart="A,B"] {
          border-style: solid;
          border-left-width: 2px;
          border-right-width: 0px;
          border-top-width: 0px;
          border-bottom-width: 0px;
          border-radius: 10px;
          border-color:  blue;
          background: transparent;
          /*revert-i*/
        }
        div.leftpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTag][data-x-deltaTagEnd], 
        div.leftpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTagEnd="A,B"] {
          border-style: solid;
          border-left-width: 0px;
          border-right-width: 2px;
          border-top-width: 0px;
          border-bottom-width: 0px;
          border-radius: 10px;
          border-color:  blue;
          background: transparent;
          /*revert-i*/
        }
        div.rightpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTag][data-x-deltaTagStart], 
        div.rightpane div.alternate-delta span[data-tag-start=yes][data-x-deltaTagStart="A,B"] {
          border-style: solid;
          border-left-width: 2px;
          border-right-width: 0px;
          border-top-width: 0px;
          border-bottom-width: 0px;
          border-radius: 10px;
          border-color:  blue;
          background: transparent;
          /*revert-i*/
          color: #0000e0;
        }
        div.rightpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTag][data-x-deltaTagEnd], 
        div.rightpane div.alternate-delta span[data-tag-close=yes][data-x-deltaTagEnd="A,B"] {
          border-style: solid;
          border-left-width: 0px;
          border-right-width: 2px;
          border-top-width: 0px;
          border-bottom-width: 0px;
          border-radius: 10px;
          border-color:  blue;
          background: transparent;
          /*revert-i*/
          color: #0000e0;
        }
        /* ------------- formatting elements end ---------- */
        a[title=expand][data-hide] {
                background-image: none;
        }
        /* image of arrow with gray outline pointing horizontally to the right */
        a.fold[title=expand], span.expand {
            background-image: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAJCAIAAAB1z3HJAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41LjEwMPRyoQAAAFBJREFUGFdVjTEKQDEIQ3v13qC7u3iRXsJZKFTd3P0d+ilmCY+QpM05IyJ/NUQkIjN7vPcGABG5fOzkYwxmvny01uq9X3b3l6tq6Zf98p/5AerCcfUnqooCAAAAAElFTkSuQmCC);
            background-repeat: no-repeat;
            background-position: center;
            background-position-x: 4px;
        }
        /* image of black arrow pointing diagonally down and to the right */
        a.fold[title=collapse], span.collapse {
            background-image: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAYAAAAGCAIAAABvrngfAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAadEVYdFNvZnR3YXJlAFBhaW50Lk5FVCB2My41LjEwMPRyoQAAADhJREFUGFdj+I8E9u/f39HRgRDau3evtra2mpoaVAjCj4iIgArB+ZGRkSAhZD5UCGgekIKDtrY2APtVOYsmBInQAAAAAElFTkSuQmCC);
            background-repeat: no-repeat;
            background-position: center;
        }

        /* styling and positioning for image elements representing +/- buttons */
        a.fold { 
          position: relative;
          top: 5px; /* added to align the button with the element */
          float: left;
          color: black;
          font-family: monospace;
          font-weight: bold;
          font-style: normal;
          font-size: small;
          width: 10px;
          height: 10px;
          text-align: center;
          line-height: 11px;
          margin-left: -20px
        }
        a.fold {
          cursor: default;
        }
        /* gives 'pressed button' effect */
        /*
        a.fold:active {
          border-style: inset;
        }
        */
        
        /* hides collapsed(folded children) and hidden(unchanged atts/children) */
        .collapsed { 
          display:none!important; 
        }
        p.difftitle {
                padding: 2px 0px 2px 0px;
                margin: 0px;
                width: 100%;
                text-align: center;
                line-height: 25px;               
                color: #b0b7c0;
                font-size: 16px;
                background-color: #3B4654;
        }
        div.anchor-parent div.anchor-parent{
          margin-left: 20px;
          /* width: max-content; */
        }
        /* provides vertical spacing between lines */
        div#deltafile span {
          line-height: 1.5em;
          font-size: 13px;
          font-family: 'Source Code Pro', Consolas, 'Lucida Console', Menlo, monospace;
        }
        #deltafile .add[hot=yes],
        #deltafile .delete[hot=yes],
        #deltafile .anchor-parent[hot=yes] {
        background-color:#ffffaf;
        border-color:#a0a0a0;
        }
        div.leftpane #deltafile span.add[hot=yes]:not([data-newline-att]),
        div.rightpane #deltafile  span.delete[hot=yes]:not([data-newline-att]) {
        display: inline;
        padding: 0px;
        color: red;
        background: #ffffaf;
        }
        div.leftpane #deltafile span.add[hot=yes]::after,
        div.rightpane #deltafile  span.delete[hot=yes]::after {
          content: '\2038'; /*caret*/
        }

        #deltafile .add[hot=yes] *:not([data-x-deltaTagStart]):not([data-x-deltaTagEnd]),
        #deltafile .delete[hot=yes] *:not([data-x-deltaTagStart]):not([data-x-deltaTagEnd]), 
        #deltafile .anchor-parent[hot=yes] *:not([data-x-deltaTagStart]):not([data-x-deltaTagEnd]) {
          background-color:#ffffaf;
        }
        #deltafile .add, #deltafile .delete {
          border-style:solid;
          border-width: 1px;
          border-color: transparent;
        }
        #deltafile .anchor-parent > .add, #deltafile .anchor-parent > .delete {
          border-top-left-radius: 15px;
          border-bottom-left-radius: 15px;
        }
    /* original end */
    </style>
    <script type="text/javascript">
    var tocTotalInt = 0;
    var rpDiv;
    var lpDiv;
    var lpDivHasFocus = false;
      
       window.onload=initListeners;
        function initListeners(params) {
          lpDiv = document.getElementById('leftpane');
          lpDiv.addEventListener('mouseenter', handleLpEnter);
          lpDiv.addEventListener('mouseleave', handleLpLeave);
          lpDiv.addEventListener('scroll', handleLpScroll, false);
          rpDiv = document.getElementById('rightpane');
          rpDiv.addEventListener('scroll', handleRpScroll, false);
          var docViewDiv = document.getElementById('dxcontainer');
          docViewDiv.addEventListener('click', handleDocViewClick, false);
          docViewDiv.addEventListener('transitionend', handleTransitionEnd, false);
          var leftButton = document.getElementById("button-left");
          leftButton.addEventListener('click', handleLeftClick, false);
          var rightButton = document.getElementById("button-right");
          rightButton.addEventListener('click', handleRightClick, false);
          
          
          var collapseButton = document.getElementById("button-collapse");
          collapseButton.addEventListener('click', handleCollapseClick, false);
          var expandButton = document.getElementById("button-expand");
          expandButton.addEventListener('click', handleExpandClick, false);
          var tocTotal = document.getElementById("toc-total");
          tocTotalInt = parseInt(tocTotal.innerText);
          document.addEventListener('keydown', onKeyDown, false);
          document.addEventListener('keyup', onKeyUp, false);
          window.addEventListener('resize', handleResize);
          actualResizeHandler();
        }
        // space-bar is used as ctrl-key - to prevent
        // conflict with browser behaviour
        var ctrlKeyDown= false;
        var isExpandedAnchor= false;
        
        var onKeyDown = function (e) {
          var k = e.keyCode;
          console.log("k " + k);
          if (k == 37 || k == 38) {
            handleLeftClick(e);
            e.preventDefault();
          } else if (k == 39 || k == 40) {
            handleRightClick(e);
            e.preventDefault();
          } else if (k == 32) {
            ctrlKeyDown= true;
          }
        }
        var onKeyUp = function (e) {
          //console.log("keyup");
          if (e.keyCode == 32) {
            ctrlKeyDown= false;
          }
        }
        function animateElementHeight(docViewElement) {
    			if (docViewElement.className == "expanded") {
    				// collapse the view
    				docViewElement.style.maxHeight = (window.innerHeight + "px");
    				setTimeout(
    					function() {
    			           docViewElement.className="collapsed";
    					   docViewElement.style.maxHeight = "0px";
    					}, 10);
    			}
    			else {
    				// paritally expand the view for css animation
    				docViewElement.className = "partExpanded";
    				docViewElement.style.maxHeight = (window.innerHeight + "px");
    			}
              evt.preventDefault();
        }

    var anchors= new Map();

    // for each leval add an array of sibling anchors
    function populateAnchors(e, level) {
      if (e.nodeType === Node.ELEMENT_NODE) {
        if (e.nodeName == "DIV" &amp;&amp; e.className == "anchor-parent") {
          var c= e.firstChild;
          if ((c.className == "fold" || c.className == "single-fold") &amp;&amp; c.getAttribute("title") === "collapse") {
            var s= c.nextSibling;           
            if (s.className == "modify") { 
              var numArray= anchors.get(level);
              if (!numArray) {
                numArray= [e];
                anchors.set(level, numArray);
              } else {
                numArray.push(e);
              }
            }           
          }
        }
      }
      e=e.firstChild;
      isFirst= true;
      while (e) {
        populateAnchors(e, level + 1);
        e= e.nextSibling;
      }
    }

    function setHeightOfAnchors() {
      var keys= anchors.keys();
      var sKeys= Array.from(keys).reverse();
      var sKeysLen= sKeys.length;
      for (var i = 0; i &lt; sKeysLen; i++) {
        var key= sKeys[i];
        var anchorArray= anchors.get(key);
        var anchorLen= anchorArray.length;
        for (var a = 0; a &lt; anchorLen; a++) {
          var e= anchorArray[a];
          var c= e.firstChild;
          var otherC= document.getElementById(c.id + "-rp");
          if (otherC) {
            var otherE= otherC.parentElement;
            var eHeight= getHeightAsNumber(e);            
            var otherEHeight= getHeightAsNumber(otherE);

            if (eHeight > otherEHeight) {
              otherE.style.height= eHeight;
            } else if (otherEHeight > eHeight) {
              e.style.height= otherEHeight;
            }
          }
        }
      }
    }
   function resetHeightOfAnchors() {
      var keys= anchors.keys();
      var sKeys= Array.from(keys).reverse();
      var sKeysLen= sKeys.length;
      for (var i = 0; i &lt; sKeysLen; i++) {
        var key= sKeys[i];
        var anchorArray= anchors.get(key);
        var anchorLen= anchorArray.length;

        for (var a = 0; a &lt; anchorLen; a++) {
          var e= anchorArray[a];
          var c= e.firstChild;
          var otherE;
          var otherC= document.getElementById(c.id + "-rp");
          if (otherC) {
            otherE= otherC.parentElement;
          }
          resetHeightAttribute(e);
          resetHeightAttribute(otherE);
        }
      }
    }
    function resetHeightAttribute(e) {
      if (e) {
          e.style.height= "auto";
      }
    }
    function getHeightAsNumber(e) {
      var height= window.getComputedStyle(e).getPropertyValue("height");
      height= height.substr(0, height.length -2);
      return Number(height);
    }
    function resizePanes() {
        var leftHeight= window.getComputedStyle(lpDiv).getPropertyValue("height");
        var rightHeight= window.getComputedStyle(rpDiv).getPropertyValue("height");
        if (leftHeight > rightHeight) {
          rpDiv.style.height= leftHeight;
        } else if (rightHeight > leftHeight) {
          lpDiv.style.height= rightHeight;
        }
    }

		 // fully expand the view
	   function handleTransitionEnd(evt) {
  			var targetElement = evt.target;
  			if (targetElement.className == "partExpanded") {
  			  targetElement.style.maxHeight = "100%";
  			  targetElement.className = "expanded";
  			}

     }
        var currentFileElement;
        var otherCurrentFileElement;
        var currentTocIndex = 0;
        
        
        function handleRpScroll(evt) {
        if (!lpDivHasFocus &amp;&amp; !ctrlKeyDown) {
            lpDiv.scrollTop = this.scrollTop;
            lpDiv.scrollLeft = this.scrollLeft;
          }
        }
        function handleLpScroll(evt) {
        if (lpDivHasFocus &amp;&amp; !ctrlKeyDown) {
            rpDiv.scrollTop = this.scrollTop;
            rpDiv.scrollLeft = this.scrollLeft;
          }
        }
        function handleLpEnter(evt) {
          lpDivHasFocus = true;
        }
        function handleLpLeave(evt) {
          lpDivHasFocus = false;
        }
        
        function handleDocViewClick(evt) {
          var docViewElement = evt.target;
          var docViewId = docViewElement.id;
          evt.preventDefault();
          // ignore selection of fold arrows as these have their own handler
          if (docViewElement.className == "fold") {
          
          } else {
            while (!docViewId || docViewId.indexOf("xc_") !== 0) {
              docViewElement = docViewElement.parentNode;
              if (!docViewElement) {
                break;
              }
              docViewId = docViewElement.id;
            }
            if (!docViewElement) {
              var firstChild = evt.target.firstElementChild;
              if (firstChild) {
                docViewElement = firstChild;
                docViewId = docViewElement.id;
                while (!docViewId || docViewId.indexOf("xc_") !== 0) {
                  docViewElement = docViewElement.nextSibling;
                  if (!docViewElement) {
                    break;
                  }
                  docViewId = docViewElement.id;
                }
              }
            
            }
            if (!docViewElement) {
              docViewElement = evt.target;
              if (docViewElement.hasAttribute('data-att-unchanged')) {
                docViewElement = docViewElement.parentNode;
              } else if (docViewElement.hasAttribute('data-att-value')) {
                docViewElement = docViewElement.parentNode.parentNode;
              }
              docViewId = docViewElement.id;
              while (!docViewId || docViewId.indexOf("xc_") !== 0) {
                docViewElement = docViewElement.nextSibling;
                if (!docViewElement) {
                  break;
                }
                docViewId = docViewElement.id;
              }
            
            }
            
            if (docViewId) { 
            
              var viewIndex = docViewId.startsWith("xc_r")? parseInt(docViewId.substring(4)) : parseInt(docViewId.substring(3));
              disableWScroll = true;
              selectTocElementByIndex(viewIndex);
              disableWScroll = false;
            } else {
              var targetElement = evt.target;
              if (targetElement.className == "unchanged" || targetElement.className == "modify") {
                var targetParent = targetElement.parentElement;
                var foldElement = targetParent.firstElementChild;
                if (foldElement.className == "fold") {
                  fold(foldElement);
                }
              }
            }
          }
        }
        
        function selectTocElementByIndex(index) {
          var newFileId = "xc_" + index;
          var newFileElement = document.getElementById(newFileId);
          if (currentFileElement) {
            currentFileElement.setAttribute("hot", "no");
          }
          if (otherCurrentFileElement) {
            otherCurrentFileElement.setAttribute("hot", "no");
          }
          currentFileElement = newFileElement;
          if (newFileElement) {
            newFileElement.setAttribute("hot", "yes");         
            
            var otherPaneFileId = "xc_r" + index;
            var otherPaneFileElement = document.getElementById(otherPaneFileId);
            var otherExists = Boolean(otherPaneFileElement);
            if (otherExists) {
              otherPaneFileElement.setAttribute("hot", "yes");
            } else {
              otherPaneFileId = "c_" + index;
              otherPaneFileElement = document.getElementById(otherPaneFileId);
              var otherExists2 = Boolean(otherPaneFileElement);
              if (otherExists2){
                 otherPaneFileElement.setAttribute("hot", "yes");
              }
            }            
            otherCurrentFileElement = otherPaneFileElement;
            
            var containerElementA= getContainerElement(newFileElement);
            var containerElementB= getContainerElement(otherPaneFileElement);
            
            highlightContainerElement(containerElementA, containerElementB);
            
            isExpandedAnchor= false;
            
            expandFileElement(newFileElement);
            expandAnchor(containerElementA);
            
            expandFileElement(otherPaneFileElement);
            expandAnchor(containerElementB);

            if (isExpandedAnchor) {
              actualResizeHandler();
            }

            var scrollTop= lpDiv.scrollTop;
            var scrollLeft= lpDiv.scrollLeft;

            var viewElement= newFileElement;

            showInWindow(viewElement);

            if (lpDiv.scrollTop != scrollTop || lpDiv.scrollLeft != scrollLeft) {
              rpDiv.scrollTop = lpDiv.scrollTop;
              rpDiv.scrollLeft = lpDiv.scrollLeft;
            } else {
              lpDiv.scrollTop = rpDiv.scrollTop;
              lpDiv.scrollLeft = rpDiv.scrollLeft;
            }

          } else {
            console.log("newFileElement not found - index: " + index);
          }
          
          var tocCount = document.getElementById('toc-count');
          currentTocIndex = parseInt(index);
          if (Number.isNaN(currentTocIndex)) {
            currentTocIndex = 0;
            tocCount.innerText = "# of ";  
          } else {
            tocCount.innerText = index + " of ";  
          }            
          
          return false;
        }
        
        var prevContainerElementA = null;
        var prevContainerElementB = null;
        
        function getContainerElement(contextElement) {
        var containerElementA;
        if (contextElement.className == "anchor-parent") {
        containerElementA = contextElement;
        } else {
        // get anchor-parent
        containerElementA = contextElement.parentElement.parentElement; 
        
        var xx = 0;
        while (xx &lt; 10 &amp;&amp; containerElementA &amp;&amp; containerElementA.className != "anchor-parent") {
        xx++;
        containerElementA = containerElementA.parentElement;            
        }                  
        }
        return containerElementA;
        }
        
        function highlightContainerElement(containerElementA, containerElementB) {          
        if (containerElementA.id != 'is-root-element-left') {       
          containerElementA.setAttribute("cHot", "yes");
          containerElementB.setAttribute("cHot", "yes");
        }
        if (prevContainerElementA &amp;&amp; !(prevContainerElementA == containerElementA || prevContainerElementA == containerElementB)) {
        prevContainerElementA.setAttribute("cHot", "no");
        }
        if (prevContainerElementB &amp;&amp; !(prevContainerElementB == containerElementA || prevContainerElementB == containerElementB)) {
        prevContainerElementB.setAttribute("cHot", "no");
        }
        prevContainerElementA = containerElementA;
        prevContainerElementB = containerElementB;
        }
        
        function addToPath(pathItems, value) {
            if (value) {
              var parts = value.split(/\s/);
              pathItems[pathItems.length] = parts[0];
            }
        }
        
        function addNameToPath(pathItems, value) {
            if (value) {
              pathItems[pathItems.length] = value;
            }
        }
        
        function expandFileElement(fileElement) {
          var compactSpan;
          var isFullElement = fileElement.className == "anchor-parent";
          var isAttrFull = fileElement.hasAttribute("data-is-attr-full");
          var isAttribute = (fileElement.hasAttribute("data-is-attr-val") || isAttrFull);
          var isMixedContent = fileElement.hasAttribute("data-mixed-change");
          
          if (!fileElement) {
            return;
          }
          
          var pathItems = [];

          if (isMixedContent &amp;&amp; fileElement.hasChildNodes()) {
            var childNode = fileElement.childNodes[0];
            if (childNode.nodeType == 3) {
              addToPath(pathItems, childNode.nodeValue);
            }
          }

          if (isAttribute) {
            var sibling;
            var allSiblings;
            if (isAttrFull) {
              allSiblings = getChildElements(fileElement.parentNode);
            } else {
              allSiblings = getChildElements(fileElement.parentNode.parentNode);
            }
            var attName;
            if (isAttrFull &amp;&amp; fileElement.hasChildNodes()) {
              attName = fileElement.childNodes[0].nodeValue;
            } else {
              var pSibling = fileElement.previousSibling;
              while (pSibling.nodeType != 3) {
                pSibling = pSibling.previousSibling;
              }
              attName = pSibling.nodeValue;
            }
            for (var i= 0; i &lt; allSiblings.length; i++) {
              sibling = allSiblings[i];           
              if (sibling.id == "compact-span") {
                break;
              }
            }
            compactSpan = sibling;
            // check if element-name and att-name are in same text node
            if (attName.indexOf("&lt;") > -1) {
                var names = attName.split(/\s/);
                addNameToPath(pathItems, names[1]);           
            } else {
                addNameToPath(pathItems, attName);
            }            
          } else if (isFullElement) {
            var anchorChild = fileElement.getElementsByTagName("span")[0];
            var possCompactSpans = getChildElements(anchorChild);
            for (var x = 0; x &lt; possCompactSpans.length; x++) {
                compactSpan = possCompactSpans[x];
                if (compactSpan.id == "compact-span") {
                    break;
                }
            }
            if (!compactSpan) {
              compactSpan = fileElement.parentElement;
              addToPath(pathItems, anchorChild.childNodes[0].nodeValue);              
            }
          } else {
            compactSpan = fileElement.parentElement;
          }
                    
          while (!grandParentClassNameEquals(compactSpan, "anchor-parent")) {            
            var parentValue = compactSpan.parentElement.childNodes[0].nodeValue;
            addToPath(pathItems, parentValue);
            compactSpan = getGrandParent(compactSpan);
          }

          expandCompactSpan(compactSpan, pathItems);
          displayPath(pathItems);  
        }

        function getGrandParent(curentNode) {
            try {
               return curentNode.parentElement.parentElement;
            } catch(e) {
                // do nothing
            }
        } 
        
        function grandParentClassNameEquals(curentNode, nameTest) {
            try {
               return curentNode.parentElement.parentElement.className == nameTest;
            } catch(e) {
                // do nothing
            }
        }

        function displayPath(pathItems) {
          var fwdPathItems = pathItems.reverse();
          var target = document.getElementById("node-path");
          target.innerHTML = "";
          var pathLength = fwdPathItems.length;
          for (var i = 0; i &lt; pathLength; i++) {
            createPathElement(fwdPathItems[i], target, i + 1 == pathLength);
          }
        }

        function endsWith(str, suffix) {
          return str.indexOf(suffix, str.length - suffix.length) !== -1;
        }

        function createPathElement(pathItem, target, isLast) {
          var span = document.createElement("SPAN");
          var nodeName = "";
          if (pathItem) {
            nodeName = pathItem.replace(/[/&lt;>=\"]/g, '');
          }
          var t = document.createTextNode(nodeName);
          span.appendChild(t);
          target.appendChild(span);

          if (!isLast || !pathItem) {
            var s = document.createElement("SPAN");
            s.className = "step";
            target.appendChild(s);
          } else {
            var char1 = nodeName.substring(0,1);
            if(endsWith(pathItem, '"')) {
              span.className = "path-attr";
            } else if (char1 == '?' || char1 == '!') {
              span.className = "path-special";
            }
          }
        }
        
        function expandCompactSpan(compactSpan, pathItems) {
          if (compactSpan) {
            addToPath(pathItems, compactSpan.parentNode.childNodes[0].nodeValue);
            var anchorParent = compactSpan.parentNode.parentNode;
            if (anchorParent) {
              if (anchorParent.id == "compact-span") {
                  expandCompactSpan(anchorParent, pathItems);
              } else if (anchorParent.className == "anchor-parent") {
                compactSpan.className = "expanded";
                var expandedComment = compactSpan.nextSibling;
                if (isCommentSpan(expandedComment)) {
                  expandedComment.className = "collapsed";
                }
                var anchor= anchorParent.getElementsByTagName("a")[0];
                if (anchor) {
                  if (anchor.title === "expand") {
                    anchor.title = "collapse";
                    isExpandedAnchor= true;
                  }
                }
                expandCompactSpan(anchorParent.parentNode, pathItems);
              }
            }
          }
        }
        
        function isCommentSpan(inElement) {
            if (inElement) {
                var childEl = inElement.firstElementChild;
                if (childEl) {
                    return childEl.className == "comment";
                } else {
                    return false;
                }
            } else {
                return false;
            }
        }
        
        function handleLeftClick(evt) {
          if (currentTocIndex > 1) {
                currentTocIndex--;
                selectTocElementByIndex(currentTocIndex);
          }
        }
        
        function handleRightClick(evt) {
          if (currentTocIndex &lt; tocTotalInt) {
              currentTocIndex++;
              selectTocElementByIndex(currentTocIndex);   
          }
        }
        
        function handleCollapseClick(evt) {
           foldall(true);
        }
        
        function handleExpandClick(evt) {
           expandAll();
        }

    var resizeTimeout;
    function handleResize() {
      // ignore resize events as long as an actualResizeHandler execution is in the queue
      if ( !resizeTimeout ) {
        resizeTimeout = setTimeout(function() {
          resizeTimeout = null;
          actualResizeHandler();
      
        // The actualResizeHandler will execute at a rate determied by last argument
        }, 250);
      }
    }

    function actualResizeHandler() {
      // reset heights a first time with old anchors
      resetHeightOfAnchors();
      anchors= new Map();
      populateAnchors(lpDiv, 0);
      // reset heights a second time with new anchors
      resetHeightOfAnchors();
      setHeightOfAnchors();
      resizePanes();     
    }
                
        function expandAll() {         
          expandAnchor(document.getElementById('is-root-element-left'));
          expandAnchor(document.getElementById('is-root-element-right'));
          actualResizeHandler();
        }
        
        function expandAnchor(anchorParent) {
          if (anchorParent.firstElementChild.title === "expand") {
            anchorParent.firstElementChild.title = "collapse";
            isExpandedAnchor= true;
          }
          var anchorAndSiblings = getChildElements(anchorParent);
          var tagWrapper = anchorAndSiblings[1];
          var wrapperSpans = getChildElements(tagWrapper);
          var spans = getSpans(wrapperSpans);
          var compactSpan = spans.compactSpan;
          if (compactSpan) {
            var commentSpanWrapper = spans.commentSpan;
            compactSpan.className = "expanded";
            var divChildren = getChildElements(compactSpan);
            
            expandDivChildren(divChildren);
            
            if (commentSpanWrapper) {
              var commentSpan = commentSpanWrapper.firstElementChild;
              if (commentSpan) {
                if (commentSpan.className == "comment") {
                  commentSpanWrapper.className = "collapsed";
                }
              }
            }
          }
        } 

        function expandDivChildren(divChildren) {
            for (var i=0; i &lt; divChildren.length; i++) {
              var div = divChildren[i];
              if (div.nodeName == "DIV") {
                expandAnchor(div);
              } else {
                var childSpans = div.getElementsByTagName("SPAN");
                if (childSpans) {
                  for (var csCount= 0; csCount &lt; childSpans.length; csCount++) {
                    var childOfSpan = childSpans[csCount];
                    if (childOfSpan.id == "compact-span") {
                      var newDivChildren = childOfSpan.getElementsByTagName("DIV");
                      for (var x= 0; x &lt; newDivChildren.length; x++) {
                        expandAnchor(newDivChildren[x]);
                      }
                    }

                  }
                }
            }
          } 
        }  

        
        function getSpans(inElements) {
          var spans = { compactSpan: null, commentSpan: null};
          if (inElements) {
            for (var i=0; i &lt; inElements.length; i++) {
              var el = inElements[i];
              if (el.id == "compact-span") {
                spans.compactSpan = el;
                spans.commentSpan = inElements[i + 1];
                break;
              }
            } 
          }
          return spans;
        }
                    
        function getChildElements (inElement) {
          if (inElement) {
            return inElement.children;
          }
        }
        
        var disableWScroll = false;
        var setDisableScroll = function (val) {
            disableWScroll = val;
        }
        
        var showInWindow = function (viewElement) {
          if (!disableWScroll &amp;&amp; !isInViewport(viewElement)) {
            viewElement.scrollIntoView(true);
          }
        }

      function showRect(el) {
      var rect = el.getBoundingClientRect();
      var winWidth= (window.innerWidth/2);
      var note= document.getElementById("node-path");
      note.innerHTML= "&lt;span>id " + el.id + " rect.left " + Math.round(rect.left) +  " rect.right " + Math.round(rect.right) + 
        " rect.top " + rect.top + "&lt;/span>" + "&lt;span>winWidth " + Math.round(winWidth) +
          " pane: " + el.getAttribute('data-pane') + "&lt;/span>";
      }
        
        function isInViewport(el) {
          // showRect(el);
          var isLeft= el.getAttribute('data-pane') == 'left';
          var rect = el.getBoundingClientRect();
          var winWidth= (window.innerWidth/2);
          if (isLeft) {
          return (
            rect.top >= 62 &amp;&amp;
            rect.left >= 0 &amp;&amp;
            rect.bottom &lt;= (window.innerHeight) &amp;&amp; 
            rect.right &lt;= (winWidth)
          );
          } else { return (
            rect.top >= 62 &amp;&amp;
            rect.left >= winWidth &amp;&amp;
            rect.bottom &lt;= (window.innerHeight) &amp;&amp; 
            rect.right &lt;= (winWidth * 2)  
            );          
          }
        }
        
        function fold(obj, noSyncWithOtherPane) {
          //switch anchor text between '+' and '-'
          obj.innerHTML= (obj.innerHTML == '-') ? ' ' : ' ';
          //switch anchor title between 'expand' and 'collapse'
          obj.title= (obj.title == 'collapse') ? 'expand' : 'collapse';
          var isCollapsed= (obj.title == 'expand');
          
          obj.parentElement.style.height= "";
           
          
          //the next two lines get all 'span' siblings of the a tag that was 
          //clicked and then pick the first one. This is the one whose children
          //must be hidden. We also don't select text nodes this way.
          var siblings= obj.parentNode.getElementsByTagName('span');
          var tmp= siblings[0];
          
          //go through all children of the node selected and test their className
          //if 'expanded' or 'collapsed', switch, otherwise ignore it
          for (i=0; i != tmp.childNodes.length; i++)
          {
          var name= new String(tmp.childNodes[i].className);
          if (name == 'expanded' || name == 'collapsed') {
          tmp.childNodes[i].className = (tmp.childNodes[i].className == 'expanded') ? 'collapsed' : 'expanded';
          } else {
          //no change to the name if it isn't one of 'expanded' or 'collapsed'
          }
          }
          if (!noSyncWithOtherPane) {
            var existingId = obj.id;
            var idLength = existingId.length;
            var newId;
            if (existingId.endsWith('-rp')) {
              newId = existingId.substring(0, idLength - 3);
            } else {
            newId = existingId + "-rp";
            }
            
            var otherPaneObj = document.getElementById(newId);
            fold(otherPaneObj, true);
          } else {
            actualResizeHandler();
          }
        }
        function forcefold(obj) {
          //switch anchor title between 'expand' and 'collapse'
          obj.title= 'expand';
  
          //the next two lines get all 'span' siblings of the a tag that was 
          //clicked and then pick the first one. This is the one whose children
          //must be hidden. We also don't select text nodes this way.
          var siblings= obj.parentNode.getElementsByTagName('span');
          var tmp= siblings[0];
          
          //go through all children of the node selected and test their className
          //if 'expanded' or 'collapsed', switch, otherwise ignore it
          for (var i=0; i != tmp.childNodes.length; i++)
          {
            var tmpChildNode = tmp.childNodes[i];
            var name= new String(tmpChildNode.className);
            if (name == 'expanded' || name == 'collapsed') {
              var isWrapperForComment = false;
              if (tmpChildNode.nodeType == 1) {
                var firstChild = tmpChildNode.firstElementChild;
                if (firstChild) {
                  isWrapperForComment = firstChild.className == "comment";
                }
              }
              if (isWrapperForComment) {
                 tmpChildNode.className = 'expanded'; // show the '...' comment child 
              } else {
                 tmpChildNode.className = 'collapsed'; 
              }
            } else {
              //no change to the name if it isn't one of 'expanded' or 'collapsed'
            }
          }
        }
        function foldall(collapse) {
        
          //now get all anchor tags and fold them
          var anchorsL= document.getElementById('leftpane').getElementsByTagName("a");
          foldAnchors(anchorsL);
          var anchorsR= document.getElementById('rightpane').getElementsByTagName("a");
          foldAnchors(anchorsR);
          actualResizeHandler();
        }
        
        function foldAnchors(anchors) {
          var isFirst = true;
          for (var i=0; i != anchors.length; i++) {          
            if (anchors[i].className == 'fold') {
              if (isFirst) {
                isFirst = false;
              } else {
                var anchorObj = anchors[i];
                forcefold(anchorObj);
              }
            }
          }
        }
      </script>

    <link href="http://fonts.googleapis.com/css?family=Ubuntu:400,500|Source+Code+Pro:400,700|Open+Sans:400,400italic,600" rel="stylesheet" type="text/css"/>
    </head>
    <body>
      <div id="deltabar">
        <span class="bar-delta">DELTA</span><span class="bar-deltaxml">XML</span>
        <span class="bar-name">DiffReport</span>
        <button id="button-collapse" class="middle" title="Collapse Tree"></button>
        <span class="foldlabel">Fold</span>
        <button id="button-expand" class="middle" title="Expand Tree"></button>
        <span class="foldlabel">Expand</span>
        <button id="button-left" class="left" title="Previous Change"></button><button title="Next Change" id="button-right" class="right"></button><span id="toc-count"># of </span>
        <span id="toc-total"><xsl:value-of select="count($toc-numbers)"/></span></div>
        <div id="deltabar2"><div id="node-path"><span><xsl:value-of select="$header"/></span></div></div>
        <div class="main">
          <div id="dxcontainer" class="container">
            <xsl:variable name="temp-tree" as="node()*">
              <xsl:call-template name="add-main-part"/>
            </xsl:variable>
            <div id="leftpane" class="horizontalpane leftpane">
              <xsl:apply-templates select="$temp-tree" mode="left-pane"/>
            </div>
            <div id="rightpane" class="horizontalpane rightpane">
              <xsl:apply-templates select="$temp-tree" mode="right-pane"/>
            </div>
          </div>
        </div>
    </body>
   </html>
  </xsl:template>
  
  <!-- swap order of add/delete atts to allow css float -->
  <xsl:template match="span[@data-newline-att][span[@class eq 'delete'] and span[@class eq 'add']]" mode="left-pane">
    <xsl:variable name="nodes" as="node()*" select="node()"/>
    <xsl:copy>
      <xsl:apply-templates mode="#current" select="@*"/>
      <xsl:attribute name="data-pane" select="'left'"/>
      <xsl:apply-templates select="node()[1]"/>
      <xsl:apply-templates mode="#current" select="node()[3]"/>
      <xsl:apply-templates mode="#current" select="node()[2]"/>
      <xsl:apply-templates select="node()[position() gt 3]"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="@*" mode="right-pane left-pane">
    <xsl:copy select="."/>
  </xsl:template>
  
  <xsl:template match="*" mode="right-pane">
    <xsl:copy>
      <xsl:if test="@class = ('delete','add')">
        <xsl:attribute name="data-pane" select="'right'"/>
      </xsl:if>
      <xsl:apply-templates mode="#current" select="@*, node()"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*" mode="left-pane">
    <xsl:copy>
      <xsl:if test="@class = ('delete','add')">
        <xsl:attribute name="data-pane" select="'left'"/>
      </xsl:if>
      <xsl:apply-templates mode="#current" select="@*, node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- make the id of folding elements unique in the right pane -->
  <xsl:template match="a[@class = ('fold', 'single-fold')]" mode="right-pane">
    <xsl:copy>
      <xsl:attribute name="id" select="concat(@id, '-rp')"/>
      <xsl:apply-templates select="@* except @id, node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[@data-preserve-space-wrap]" mode="right-pane">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:if test="@id = ('delete','add')">
        <xsl:attribute name="data-pane" select="'right'"/>
      </xsl:if>
      <xsl:apply-templates select="node()" mode="#current">
        <xsl:with-param name="preserve-space" select="true()" tunnel="yes"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[@data-preserve-space-wrap]" mode="left-pane">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:if test="@id = ('delete','add')">
        <xsl:attribute name="data-pane" select="'left'"/>
      </xsl:if>
      <xsl:apply-templates select="node()" mode="#current">
        <xsl:with-param name="preserve-space" select="true()" tunnel="yes"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[exists((@data-text-change,@data-mixed-change, @data-is-attr-full)) and empty(@data-newline-att) and @class eq 'delete']" mode="right-pane">
    <xsl:param name="preserve-space" as="xs:boolean" select="false()" tunnel="yes"/>
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:attribute name="data-pane" select="'right'"/>
      <xsl:choose>
        <xsl:when test="$preserve-space and not(contains(., '&#10;'))"/>
        <xsl:when test="$preserve-space">
          <xsl:value-of select="replace(., '[^\n]+', '')"/>
        </xsl:when>
        <!-- don't keep deleted text in right-pane -->
      </xsl:choose>

    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[exists((@data-text-change,@data-mixed-change, @data-is-attr-full)) and empty(@data-newline-att) and @class eq 'add']" mode="left-pane">
    <xsl:param name="preserve-space" as="xs:boolean" select="false()" tunnel="yes"/>
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:attribute name="data-pane" select="'left'"/>
      <xsl:choose>
        <xsl:when test="$preserve-space and not(contains(., '&#10;'))"/> 
        <xsl:when test="$preserve-space">
          <xsl:value-of select="replace(., '[^\n]+', '')"/>
        </xsl:when>
        <!-- don't keep added text in left-pane -->
      </xsl:choose>
      
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[@data-entity-ref]" mode="right-pane">
    <xsl:param name="preserve-space" as="xs:boolean" select="false()" tunnel="yes"/>
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:choose>
        <xsl:when test="$preserve-space and ../@class eq 'delete' and not(contains(., '&#10;'))"/>
        <xsl:when test="$preserve-space and ../@class eq 'delete'">
          <xsl:value-of select="replace(., '[^\n]+', '')"/>
        </xsl:when>  
        <xsl:otherwise>
          <xsl:copy-of select="text()"/>
        </xsl:otherwise>
      </xsl:choose>
      
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[@data-entity-ref]" mode="left-pane">
    <xsl:param name="preserve-space" as="xs:boolean" select="false()" tunnel="yes"/>
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:choose>
        <xsl:when test="$preserve-space and ../@class eq 'add' and not(contains(., '&#10;'))"/>
        <xsl:when test="$preserve-space and ../@class eq 'add'">
          <xsl:value-of select="replace(., '[^\n]+', '')"/>
        </xsl:when>  
        <xsl:otherwise>
          <xsl:copy-of select="text()"/>
        </xsl:otherwise>
      </xsl:choose>
      
    </xsl:copy>
  </xsl:template>
  
  
  <xsl:template match="span[exists(@id) and @class eq 'add'] | div[@class eq 'anchor-parent'][exists(@id) and span[@class eq 'add']]" mode="right-pane">
    <xsl:copy>
      <!-- add 'x'extra prefix char to added parts on first run (for right pane) -->
      <xsl:attribute name="id" select="concat('x', @id)"/>
      <xsl:attribute name="data-pane" select="'right'"/>
      <xsl:apply-templates select="@* except @id, node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="span[exists(@id) and @class eq 'delete'] | div[@class eq 'anchor-parent'][exists(@id) and span[@class eq 'delete']]" mode="left-pane">
    <xsl:copy>
      <!-- add 'x'extra prefix char to deleted parts on first run (for left pane) -->
      <xsl:attribute name="id" select="concat('x', @id)"/>
      <xsl:attribute name="data-pane" select="'left'"/>
      <xsl:apply-templates select="@* except @id, node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="@id[. eq 'is-root-element-left']" mode="right-pane">
    <xsl:attribute name="id" select="'is-root-element-right'"/>
  </xsl:template>
  
  <xsl:template name="add-main-part">
    <div id="deltafile" class="alternate-delta">
      <div class="anchor-parent">
        <xsl:apply-templates select="*/preserve:xmldecl|*/preserve:pi-and-comment[@region eq 'BEFORE_DTD']" mode="prolog"/>
        <xsl:apply-templates select="*/preserve:doctype" mode="prolog"/>
        <xsl:apply-templates select="*/preserve:pi-and-comment[@region eq 'AFTER_DTD']" mode="prolog"/>
        <xsl:apply-templates>
          <xsl:with-param name="top-level" select="true()"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="*/preserve:xmldecl|*/preserve:pi-and-comment[@region eq 'AFTER_BODY']" mode="epilog"/>
      </div>
    </div>    
  </xsl:template>
  
  <xsl:function name="fn:test-if-unfoldable" as="xs:boolean">
    <xsl:param name="e" as="element()"/>
    <xsl:sequence  select="if ($no-fold-size-int lt 1 or $e[self::preserve:*] or $e[self::pi:*] or $e[self::er:*]) then false()
      else 
      empty($e/*[not(self::deltaxml:textGroup) and not(self::deltaxml:attributes)]) 
      and string-length(string-join($e/text(),'')) lt $no-fold-size-int"/>  
  </xsl:function>
     
  <!-- Output elements -->
  <xsl:template match="element()" mode="#default doctype">
    <xsl:param name="top-level" select="false()" as="xs:boolean"/>
    <xsl:param name="parent-is-mixed" select="false()" as="xs:boolean"/>
    <xsl:param name="namespace-data" as="xs:string*" select="()"></xsl:param>
    <xsl:variable name="is-root-element" select="if ($top-level) then not(self::preserve:*) else false()"/>
    <xsl:variable name="nearest-delta">
      <xsl:value-of select="ancestor-or-self::*[@deltaxml:deltaV2][1]/@deltaxml:deltaV2"/>
    </xsl:variable>
    <xsl:variable name="preserve-space-in-element" select="fn:preserve-space-in-element(.)"/>
    <xsl:variable name="is-non-foldable-node" as="xs:boolean" 
      select="not($preserve-space-in-element or @xml:space[. eq 'preserve']) and fn:test-if-unfoldable(.)"/>
    <xsl:variable name="isNormalOrFormattingStartElement" as="xs:boolean" 
      select="if (exists((@deltaxml:deltaTagMiddle,@deltaxml:deltaTagEnd))) then
                         exists((@deltaxml:deltaTagStart,@deltaxml:deltaTag)) else true()"/>
    <xsl:variable name="delta-value">
      <xsl:choose>
        <xsl:when test="$nearest-delta='A'">
          <xsl:value-of select="'delete'"/>
        </xsl:when>
        <xsl:when test="$nearest-delta='B'">
          <xsl:value-of select="'add'"/>
        </xsl:when>
        <xsl:when test="$nearest-delta='A=B'">
          <xsl:value-of select="'unchanged'"/>
        </xsl:when>
        <xsl:when test="$nearest-delta='A!=B'">
          <xsl:value-of select="'modify'"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="'unchanged'"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="not($parent-is-mixed) 
        and not(self::preserve:cdata or self::er:*) 
        and $isNormalOrFormattingStartElement">
        <div class="anchor-parent">
          <xsl:if test="@deltaxml:deltaV2 = ('A', 'B')">
            <xsl:attribute name="id" select="fn:createIdValue(., $delta-value)"/>
          </xsl:if>
          <xsl:if test="$is-root-element">
            <xsl:attribute name="id" select="'is-root-element-left'"/>
          </xsl:if>
          <xsl:if test="node() and not(self::preserve:comment 
            or self::preserve:internalParsedGeneralEntityDecl or self::preserve:elementDecl
            or self::preserve:cdata or self::er:*
            or self::preserve:internalParsedParameterEntityDecl
            or self::preserve:attributeDecl)">
            <a class="{if ($is-non-foldable-node) then 'single-fold' else 'fold'}" 
              onclick="{if ($is-non-foldable-node) then '' else 'fold(this)'}"
              title="{if (ancestor-or-self::*[@deltaxml:deltaV2][1]/@deltaxml:deltaV2='A=B' 
              or self::preserve:doctype) then
              'expand' 
              else 'collapse'}">
              <xsl:attribute name="id" select="generate-id(.)"/>             
              <xsl:text> </xsl:text>
            </a>
          </xsl:if>         
          
          <xsl:call-template name="add-element-span">
            <xsl:with-param name="parent-is-mixed" select="$parent-is-mixed"/>
            <xsl:with-param name="delta-value" select="$delta-value"/>
            <xsl:with-param name="namespace-data" select="$namespace-data" as="xs:string*"/>
            <xsl:with-param name="is-non-foldable-node" select="$is-non-foldable-node"/>
            <xsl:with-param name="preserve-space-in-element" select="$preserve-space-in-element"/>
          </xsl:call-template>
        </div>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="add-element-span">
          <xsl:with-param name="parent-is-mixed" select="$parent-is-mixed"/>
          <xsl:with-param name="delta-value" select="$delta-value"/>
          <xsl:with-param name="namespace-data" select="$namespace-data" as="xs:string*"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:template>
  
  <!-- if an element contains only a space-char only text node
       with more than one char - assume this is for padding    
  -->
  <xsl:function name="fn:is-whitespace-padding-element" as="xs:boolean">
    <xsl:param name="element"/>
    <xsl:choose>
      <xsl:when test="exists($element/(*))">
        <xsl:sequence select="false()"/>
      </xsl:when>
      <xsl:when test="$element/text()">
        <xsl:sequence select="string-length($element) gt 1 and matches($element, '^( )+$')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="false()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:template name="add-element-span">
    <xsl:param name="parent-is-mixed" as="xs:boolean"/>
    <xsl:param name="delta-value" as="xs:string"/>
    <xsl:param name="namespace-data" as="xs:string*" select="()"/>
    <xsl:param name="is-non-foldable-node" as="xs:boolean" select="false()"/>
    <xsl:param name="preserve-space-in-element" as="xs:boolean" select="false()"/>
    <!-- TODO: check formatting-element for anchor-parent -->
    <xsl:variable name="new-parent-is-mixed" select="
      if (exists(@deltaxml:indent-mixed-content)) then false()
      else if ($root-space-preserved) then fn:check-if-mixed-root-preserved(.)
      else if($has-content-model) then exists(@preserve:mixed-content) else fn:check-if-mixed(.)"/>
    
    <xsl:variable name="is-change" select="@deltaxml:deltaV2 = ('A', 'B')" as="xs:boolean"/>
    
    <!-- get up to 3 string values for A+B, all A-only, all B-only -->
    <xsl:variable name="raw-comment" as="xs:string+">
      <xsl:choose>  
        <xsl:when test="self::preserve:comment">
          <xsl:sequence select="if (empty(*)) then .
            else (
            string-join(text(),''), 
            string-join(deltaxml:textGroup/deltaxml:text[@deltaxml:deltaV2 eq 'A']/text(),''),
            string-join(deltaxml:textGroup/deltaxml:text[@deltaxml:deltaV2 eq 'B']/text(),'')
            )"/>
        </xsl:when>
        <xsl:otherwise><xsl:sequence select="''"/></xsl:otherwise>
      </xsl:choose>      
    </xsl:variable>

    <xsl:variable name="single-line-comment" select="not(some $x in $raw-comment satisfies contains($x, '&#10;'))"/>

    <xsl:if test="self::preserve:comment">
      <a class="{if ($single-line-comment or $parent-is-mixed) then 'single-fold' else 'fold'}">
        <xsl:choose>
          <xsl:when test="$single-line-comment">
            <xsl:attribute name="data-hide" select="'yes'"/>                 
          </xsl:when>
          <xsl:otherwise>
            <xsl:attribute name="onclick" select="'fold(this)'"/>
            <xsl:attribute name="id" select="generate-id(.)"/>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:choose>
          <xsl:when test="ancestor-or-self::*[@deltaxml:deltaV2][1]/@deltaxml:deltaV2='A=B'">
            <xsl:attribute name="title"><xsl:text>expand</xsl:text></xsl:attribute>
            <xsl:text> </xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:attribute name="title"><xsl:text>collapse</xsl:text></xsl:attribute>
            <xsl:text> </xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </a>
    </xsl:if>
    
    <xsl:variable name="delta-tags" as="attribute()*" select="@deltaxml:*[starts-with(local-name(.), 'deltaTag')]"/>
    
    <span class="{$delta-value}">
      <xsl:attribute name="data-x-fe" select="if ($delta-tags = 'A,B' or ($delta-tags = 'A' and $delta-tags = 'B')) then 'AB' else $delta-tags[1]"/>
      <xsl:for-each select="$delta-tags">
        <xsl:attribute name="{concat('data-x-', local-name(.))}" select="."/>
      </xsl:for-each>
      <xsl:if test="$is-change and $parent-is-mixed">
        <xsl:attribute name="id" select="fn:createIdValue(., $delta-value)"/>
        <xsl:attribute name="data-mixed-change" select="''"/>
      </xsl:if>     
      
      <xsl:variable name="add-space-preserve-class" as="xs:boolean">
        <xsl:choose>
          <!-- if there's no indentation in source or smart-whitespace-normalization is set false
               then add attribute to ensure CSS rule prevents HTML's default normalization on rendering        
          -->
          <xsl:when test="@xml:space[. eq 'preserve'] or (exists(parent::*) and @preserve:space[. eq 'preserve']) or exists(preserve:cdata)">
            <xsl:sequence select="true()"/>
          </xsl:when>
          <xsl:when test="not($is-indented) or not($b-smart-whitespace-normalization) or fn:is-whitespace-padding-element(.)">
            <xsl:sequence select="true()"/>
          </xsl:when>
          <xsl:when test="
            ($b-smart-whitespace-normalization
            and not($parent-is-mixed) 
            and $preserve-space-in-element)">
              <xsl:sequence select="true()"/>           
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="false()"/>           
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      
      <xsl:if test="$add-space-preserve-class">
        <xsl:attribute name="data-preserve-space-wrap" select="''"/>               
      </xsl:if>
      
      <xsl:choose>
        <xsl:when test="self::er:*">
          <xsl:if test="@deltaxml:deltaV2 = ('A', 'B')">
            <xsl:attribute name="id" select="fn:createIdValue(., $delta-value)"/>
          </xsl:if>
          <span data-entity-ref="">
            <xsl:variable name="prefix" select="if(parent::preserve:doctype) then '%' else '&amp;'"/>
            <xsl:value-of select="concat($prefix,local-name(),';')"/>
          </span>
        </xsl:when>
        <xsl:when test="self::preserve:cdata">
          <xsl:if test="@deltaxml:deltaV2 = ('A', 'B')">
            <xsl:attribute name="id" select="fn:createIdValue(. , $delta-value)"/>
          </xsl:if>
          <xsl:text>&lt;![CDATA[</xsl:text>
          <span data-cdata="">
            <xsl:apply-templates mode="unescaped-element-content"/>
          </span>
          <xsl:text>]]&gt;</xsl:text>         
        </xsl:when>
        <xsl:when test="self::preserve:doctype">
          <xsl:text>&lt;!DOCTYPE </xsl:text>
          <xsl:call-template name="handle-doctype-attributes"/>
          <xsl:text> [</xsl:text>
          <span  id="compact-span" data-pi="" class="collapsed">
            <xsl:apply-templates select="node() except deltaxml:attributes">
              <xsl:with-param name="parent-is-mixed" select="$new-parent-is-mixed"/>
            </xsl:apply-templates>
          </span>
          <span class="expanded">
            <xsl:if test="exists(preserve:*)">
              <span class="comment" data-comment=""><xsl:sequence select="'...'"/></span>
            </xsl:if>
          </span>
          <xsl:text>]&gt;</xsl:text>
        </xsl:when>
        <xsl:when test="self::preserve:elementDecl">
          <xsl:text>&lt;!ELEMENT </xsl:text>
          <span data-entity-name=""><xsl:value-of select="concat(@name, ' ')"/></span>
          
          <xsl:choose>
            <xsl:when test="@model">
              <span  id="compact-span" data-pi="" class="expanded">
                <xsl:value-of select="@model"/>
              </span>
            </xsl:when>
            <xsl:when test="deltaxml:attributes/dxa:model">
              <span  id="compact-span" data-pi="" class="expanded">
              <xsl:for-each select="deltaxml:attributes/dxa:model/*">
                <span class="{fn:getModType(.)}">
                  <xsl:attribute name="id" select="fn:createIdValue(., fn:getModType(.))"/>
                  <xsl:value-of select="."/>
                </span>
              </xsl:for-each>
              </span>
            </xsl:when>
          </xsl:choose>
          
          <xsl:text>&gt;</xsl:text>          
        </xsl:when>
        <xsl:when test="self::preserve:attributeDecl">
          <xsl:text>&lt;!ATTLIST </xsl:text>
          <span data-entity-name=""><xsl:value-of select="concat(@eName, ' ')"/></span>
          <span data-entity-name=""><xsl:value-of select="concat(@name, ' ')"/></span>          
          
          <xsl:choose>
            <xsl:when test="@type">
              <span  id="compact-span" data-pi="" class="expanded">
                <xsl:value-of select="@type"/>
              </span>
            </xsl:when>
            <xsl:when test="deltaxml:attributes/dxa:type">
              <span  id="compact-span" data-pi="" class="expanded">
                <xsl:for-each select="deltaxml:attributes/dxa:type/*">
                  <span class="{fn:getModType(.)}">
                    <xsl:attribute name="id" select="fn:createIdValue(., fn:getModType(.))"/>
                    <xsl:value-of select="."/>
                  </span>
                </xsl:for-each>
              </span>
            </xsl:when>
          </xsl:choose>
          
          <xsl:for-each select="@type|deltaxml:attributes/dxa:type">
            <xsl:text> </xsl:text>
          </xsl:for-each>         
          
          <xsl:choose>
            <xsl:when test="@mode">
              <span  id="compact-span" data-pi="" class="expanded">
                <xsl:value-of select="@mode"/>
              </span>
            </xsl:when>
            <xsl:when test="deltaxml:attributes/dxa:mode">
              <span  id="compact-span" data-pi="" class="expanded">
                <xsl:for-each select="deltaxml:attributes/dxa:mode/*">
                  <span class="{fn:getModType(.)}">
                    <xsl:attribute name="id" select="fn:createIdValue(., fn:getModType(.))"/>
                    <xsl:value-of select="."/>
                  </span>
                </xsl:for-each>
              </span>
            </xsl:when>
          </xsl:choose>
          
          <xsl:for-each select="@mode|deltaxml:attributes/dxa:mode">
            <xsl:text> </xsl:text>
          </xsl:for-each>         
          
          <xsl:choose>
            <xsl:when test="@value">
              <span  id="compact-span" data-pi="" class="expanded">
                <xsl:value-of select="concat('&quot;', fn:unescape-entity-references(@value), '&quot;')"/>
              </span>
            </xsl:when>
            <xsl:when test="deltaxml:attributes/dxa:value">
              <span  id="compact-span" data-pi="" class="expanded">
                <xsl:for-each select="deltaxml:attributes/dxa:value/*">
                  <span class="{fn:getModType(.)}">
                    <xsl:attribute name="id" select="fn:createIdValue(., fn:getModType(.))"/>
                    <xsl:value-of select="concat('&quot;', fn:unescape-entity-references(current()), '&quot;')"/>
                  </span>
                </xsl:for-each>
              </span>
            </xsl:when>
          </xsl:choose>
          
          <xsl:text>&gt;</xsl:text>          
        </xsl:when>
        <xsl:when test="self::preserve:internalParsedGeneralEntityDecl or self::preserve:internalParsedParameterEntityDecl">
          <xsl:text>&lt;!ENTITY </xsl:text>
          <xsl:sequence select="if(self::preserve:internalParsedParameterEntityDecl) then '% ' else ''"/>
          <span data-entity-name=""><xsl:value-of select="@name"/></span>
          <xsl:text> </xsl:text>
          
          <xsl:choose>
            <xsl:when test="@value">
              <span  id="compact-span" data-pi="" class="expanded">
                <xsl:value-of select="concat('&quot;', fn:unescape-entity-references(@value), '&quot;')"/>
              </span>
            </xsl:when>
            <xsl:when test="deltaxml:attributes/dxa:value">
              <span  id="compact-span" data-pi="" class="expanded">
                <xsl:for-each select="deltaxml:attributes/dxa:value/*">
                  <span class="{fn:getModType(.)}">
                    <xsl:attribute name="id" select="fn:createIdValue(., fn:getModType(.))"/>
                    <xsl:value-of select="concat('&quot;', fn:unescape-entity-references(current()), '&quot;')"/>
                  </span>
                </xsl:for-each>
              </span>
            </xsl:when>
          </xsl:choose>
          
          <xsl:text>&gt;</xsl:text>
        </xsl:when>
        <!-- Note: an external parsed general entity of the form:
          <!ENTITY name PUBLIC "publicx_ID" "URI">
          does not currently pass through the SAX parser stage of Core.
          Thus preserve:externalParsedGeneralEntityDecl is not currently encountered
        -->
        <xsl:when test="self::preserve:unparsedEntityDecl or self::preserve:externalParsedGeneralEntityDecl 
          or self::preserve:externalParsedParameterEntityDecl">
          <xsl:text>&lt;!ENTITY </xsl:text>
          <xsl:sequence select="if(self::preserve:externalParsedParameterEntityDecl) then '% ' else ''"/>
          <xsl:call-template name="handle-doctype-attributes"/>
          <xsl:text>&gt;</xsl:text>
        </xsl:when>
        
        <xsl:when test="self::preserve:comment">
          <xsl:variable name="trim-amount" as="xs:integer+" select="fn:calc-trim-amount(.)"/>
          <xsl:variable name="has-changes" as="xs:boolean" select="exists(*)"/>

          <xsl:variable name="partial-block" select="if($single-line-comment) then '' else if ($has-changes) then '...' else 
            concat(tokenize($raw-comment[1],'\n')[1], '...')"/>
          
          <xsl:text>&lt;!--</xsl:text>         
          <span  id="compact-span" data-comment="">
            <xsl:sequence select="fn:add-compact-attr($parent-is-mixed or $single-line-comment, $delta-value)"/>
            
            <xsl:choose>
              <xsl:when test="$single-line-comment">
                <xsl:apply-templates select="node()" mode="unescaped-element-content"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:apply-templates select="node()" mode="within-comment-element">
                  <xsl:with-param name="trim-amount" select="$trim-amount" tunnel="yes"/>
                  <xsl:with-param name="has-a-and-b" select="if(empty(@deltaxml:deltaV2)) then false() 
                    else string-length(@deltaxml:deltaV2) gt 1" tunnel="yes"/>
                </xsl:apply-templates>
              </xsl:otherwise>
            </xsl:choose>
            
          </span>
          <span>
            <xsl:sequence select="fn:add-comment-attr($parent-is-mixed, $delta-value)"/>
            <xsl:if test="not($parent-is-mixed or $single-line-comment)">
              <span class="comment" data-comment=""><xsl:sequence select="$partial-block"/></span>
            </xsl:if>
          </span>
          <xsl:text>--&gt;</xsl:text>
          
        </xsl:when>
        <xsl:when test="self::pi:*">
          <xsl:text>&lt;?</xsl:text>
          <xsl:value-of select="if(text()) then concat(local-name(), ' ') else local-name()"/>
          <span  id="compact-span" data-pi="">
            <xsl:sequence select="fn:add-compact-attr($parent-is-mixed, $delta-value)"/>
            <xsl:apply-templates select="node() except deltaxml:attributes" mode="unescaped-element-content">
              <xsl:with-param name="parent-is-mixed" select="$new-parent-is-mixed"/>
            </xsl:apply-templates>
          </span>
          <span>
            <xsl:sequence select="fn:add-comment-attr($parent-is-mixed, $delta-value)"/>
            <xsl:if test="not($parent-is-mixed) and exists(node())">
              <span class="comment" data-comment=""><xsl:sequence select="'...'"/></span>
            </xsl:if>
          </span>
          <xsl:text>?&gt;</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="new-xmlns" select="fn:get-xmlns(.)" as="xs:string*"/>
          <xsl:variable name="element-name" select="name(.)"/>
          <xsl:variable name="element-pfx" as="xs:string?" select="prefix-from-QName(resolve-QName($element-name, .))"/>
          <xsl:variable name="adjusted-name" select="$element-name"/>
          <xsl:variable name="has-content" as="xs:boolean" 
            select="exists(node()[not(self::deltaxml:attributes)])"/>
          
          <xsl:variable name="element-start-tag-nodes" as="node()*">
            <xsl:for-each select="$delta-tags">
              <xsl:attribute name="{concat('data-x-', local-name(.))}" select="."/>
            </xsl:for-each>
            <xsl:text>&lt;</xsl:text>
            <xsl:value-of select="$adjusted-name"/>
            <xsl:if test="$b-add-all-namespace-declarations or empty(parent::*)">
              <xsl:value-of select="fn:add-xmlns-declarations($namespace-data, $new-xmlns)"/>
            </xsl:if>
            <xsl:variable name="att-count-exceded" as="xs:boolean" 
              select="($newline-att-size-int gt -1 and 
              fn:measure-attributes(.) gt $newline-att-size-int)"/>
            
            <xsl:apply-templates select="@* except @deltaxml:* | deltaxml:attributes">
              <xsl:with-param name="att-count-exceded" select="$att-count-exceded"/>
            </xsl:apply-templates>
            <xsl:if test="$has-content">&gt;</xsl:if> 
          </xsl:variable>
          
          <xsl:choose>
            <xsl:when test="empty($delta-tags)">
              <xsl:sequence select="$element-start-tag-nodes"/>
            </xsl:when>            
            <xsl:otherwise>
              <span data-tag-start="yes">
                <xsl:sequence select="$element-start-tag-nodes"/>
              </span>
            </xsl:otherwise>
          </xsl:choose>

            <xsl:choose>
              <xsl:when test="node()">
             
                <xsl:choose>
                  <xsl:when test="$delta-value eq 'unchanged' and $b-minimize-unchanged-display 
                    and *[not(self::preserve:*)] and *[not(self::deltaxml:*)] and *[not(self::er:*)]">
                    <span id="compact-span" class="expanded" data-minimized="yes">()</span>
                  </xsl:when>
                  <xsl:otherwise>
                    <span  id="compact-span">
                      <xsl:sequence select="fn:add-compact-attr($parent-is-mixed or $is-non-foldable-node, $delta-value)"/>
                      <xsl:apply-templates select="node() except deltaxml:attributes">
                        <xsl:with-param name="parent-is-mixed" select="$new-parent-is-mixed"/>
                        <xsl:with-param name="namespace-data" select="$new-xmlns" as="xs:string*"/>
                      </xsl:apply-templates>
                    </span>
                    <span>
                      <xsl:sequence select="fn:add-comment-attr($parent-is-mixed, $delta-value)"/>
                      <xsl:if test="not($parent-is-mixed or $is-non-foldable-node)">
                        <span class="comment">...</span>
                      </xsl:if>
                    </span>
                  </xsl:otherwise>
                </xsl:choose>
                <xsl:choose>
                  <xsl:when test="empty($delta-tags)">
                    <xsl:value-of select="if($has-content) then concat('&lt;/', name(.), '&gt;') else '/&gt;'"/>                        
                  </xsl:when>
                  <xsl:otherwise>
                    <span data-tag-close="yes">
                      <xsl:attribute name="data-x-fe" select="if ($delta-tags = 'A,B' or ($delta-tags = 'A' and $delta-tags = 'B')) then 'AB' else $delta-tags[1]"/>
                      <xsl:for-each select="$delta-tags">
                        <xsl:attribute name="{concat('data-x-', local-name(.))}" select="."/>
                      </xsl:for-each>
                      <xsl:value-of select="if($has-content) then concat('&lt;/', name(.), '&gt;') else '/&gt;'"/>                
                    </span>
                  </xsl:otherwise>
                </xsl:choose>
                
              </xsl:when>
              <xsl:otherwise>/&gt;</xsl:otherwise>
            </xsl:choose>

        </xsl:otherwise>
      </xsl:choose>     
    </span>
  </xsl:template> 
  
  <xsl:template name="handle-doctype-attributes">
    <!-- name must be the same for the comparison to work -->
    <xsl:variable name="deltaType" as="xs:string" select="if (@deltaxml:deltaV2 eq 'A') then 'delete' else 'add'"/>
    <span data-entity-name=""><xsl:value-of select="@name"/></span>       
    
    <xsl:choose>
      <xsl:when test="@publicId">
        <xsl:text> PUBLIC </xsl:text>
        <span data-pi=""><xsl:value-of select="concat('&quot;', @publicId, '&quot; ')"/></span>
      </xsl:when>
      <xsl:when test="deltaxml:attributes/dxa:publicId">
        <xsl:text> PUBLIC </xsl:text>
        <xsl:for-each select="deltaxml:attributes/dxa:publicId/*">
          <span class="{$deltaType}">
            <xsl:attribute name="id" select="fn:createIdValue(., $deltaType)"/>
            <xsl:value-of select="concat('&quot;',., '&quot;')"/>
          </span>       
        </xsl:for-each>
      </xsl:when>
    </xsl:choose>
    
    <xsl:variable name="is-publicid-empty" as="xs:boolean"
      select="empty(@publicId) and empty(deltaxml:attributes/dxa:publicId)"/>
    <xsl:if test="not($is-publicid-empty) and not(empty(@systemId) and empty(deltaxml:attributes/dxa:systemId))">
      <br/>
    </xsl:if>
    
    <xsl:choose>
      <xsl:when test="@systemId">
        <xsl:sequence select="if ($is-publicid-empty) then ' SYSTEM 'else ()"/>
        <span data-pi=""><xsl:value-of select="concat('&quot;', @systemId, '&quot; ')"/></span>
      </xsl:when>
      <xsl:when test="deltaxml:attributes/dxa:systemId">
        <xsl:sequence select="if ($is-publicid-empty) then ' SYSTEM 'else ()"/>
        <span  id="compact-span" data-pi="" class="expanded">
          <xsl:for-each select="deltaxml:attributes/dxa:systemId/*">
            <span class="{$deltaType}">
              <xsl:attribute name="id" select="fn:createIdValue(., $deltaType)"/>
              <xsl:value-of select="concat('&quot;', ., '&quot; ')"/>
            </span>       
          </xsl:for-each>
        </span>
      </xsl:when>
    </xsl:choose>
    
    <xsl:choose>
      <xsl:when test="@notationName">
        <xsl:text> NDATA </xsl:text>
        <span data-pi=""><xsl:value-of select="@notationName"/></span>
      </xsl:when>
      <xsl:when test="deltaxml:attributes/dxa:notationName">
        <xsl:sequence select="if ($is-publicid-empty) then ' NDATA 'else ()"/>
        <span  id="compact-span" data-pi="" class="expanded">
          <xsl:for-each select="deltaxml:attributes/dxa:notationName/*">
            <span class="{$deltaType}">
              <xsl:attribute name="id" select="fn:createIdValue(., $deltaType)"/>
              <xsl:value-of select="."/>
            </span>       
          </xsl:for-each>
        </span>
      </xsl:when>
    </xsl:choose>
    
  </xsl:template>
  
  <xsl:function name="fn:getModType" as="xs:string">
    <xsl:param name="el" as="element()"/>
    <xsl:sequence select="if ($el/@deltaxml:deltaV2 eq 'A') then 'delete' else 'add'"/>
  </xsl:function>
  
  <xsl:function name="fn:createIdValue" as="xs:string">
    <xsl:param name="element" as="element()"/>
    <xsl:param name="deltaType" as="xs:string"/>
    <!-- this makes 'adds' for the initial left-pane non-visible when selected (hot) by user - later removed by the right-pane mode -->
    <xsl:variable name="non-visible-prefix" as="xs:string" select="if ($deltaType eq 'add') then 'X' else ''"/>
    <xsl:sequence select="concat('c_', fn:tocmap($element))"/>
  </xsl:function>
  
  <xsl:template match="text()" mode="#default">
    <xsl:value-of select="fn:escape-element-text(.)"/>
  </xsl:template>
  
  <xsl:template match="text()" mode="unescaped-element-content">
    <xsl:value-of select="."/>
  </xsl:template>
  
  <!-- trim original leading whitespace for multi-line comments -->
  <xsl:template match="text()" mode="within-comment-element">
    <!-- trim-amout for: a+b, a-only, b-only -->
    <xsl:param name="trim-amount" as="xs:integer+" tunnel="yes"/>
    <xsl:param name="has-a-and-b" as="xs:boolean" tunnel="yes" />
    <xsl:variable name="parent" as="element()" select="parent::*"/>
    
    <xsl:variable name="is-first-text" as="xs:boolean"
      select="if (parent::deltaxml:text) then
      (empty($parent/preceding-sibling::*) and empty($parent/parent::*/preceding-sibling::node()))
      else empty(preceding-sibling::node())"/>
    <xsl:variable name="is-last-text" as="xs:boolean"
      select="if (parent::deltaxml:text) then
      (empty($parent/following-sibling::*) and empty($parent/parent::*/following-sibling::node()))
      else empty(following-sibling::node())"/>
    
    <xsl:variable name="delta" select="../@deltaxml:deltaV2"/>

    <xsl:variable name="real-trim" as="xs:integer" select="if (count($trim-amount) eq 1) then $trim-amount 
      else if ($delta eq 'A') then 
      $trim-amount[2]     
      else $trim-amount[last()]"/>

    <xsl:variable name="lines" as="xs:string*" select="tokenize(., '\n')"/>
    <xsl:variable name="stripped-first-line" select="replace($lines[1], '^\s+','')"/>
   
    <xsl:variable name="is-first-line-empty" as="xs:boolean" select="string-length($stripped-first-line) eq 0"/>
    <xsl:variable name="is-last-line-empty" as="xs:boolean" select="string-length(replace($lines[last()], '^\s+','')) eq 0"/>
    <!-- to find min don't measure padding on first line -->
    <xsl:variable name="line-count" as="xs:integer" select="count($lines)"/>


    <!-- comment padding is 5 because of the space char normally inserted before the start of comment text (as here) -->
    <xsl:variable name="min-padding" as="xs:integer" select="5"/>
    <xsl:variable name="padding" as="xs:string" select="string-join(('&#10;', for $x in 1 to $min-padding return '&#160;'), '')"/>
    <xsl:variable name="first-line" select="$lines[1]"/>
    
    <!-- trim off any trailing spaces on last line -->
    <xsl:sequence select="string-join((

      for $x in 1 to $line-count
       return
       if ($x eq 1 and $is-first-text) then $first-line
       else if ($x eq $line-count and $is-last-text and $is-last-line-empty) then '&#10;'
       else if ($x eq 1) then if(not($is-first-line-empty)) then $stripped-first-line else $first-line
       else if ($x ne $line-count) then 
       concat($padding, substring($lines[$x], $real-trim + 1))
       else replace(concat($padding, substring($lines[$x], $real-trim + 1)), '\s+$','')

      ), '')"/>
  </xsl:template>
  
  <xsl:template match="deltaxml:attributes">
    <xsl:param name="att-count-exceded" as="xs:boolean" select="false()"/>
    <xsl:variable name="has-unchanged-atts" select="exists(parent::*/@*)"/>
    <!-- the order of changed attributes is not preserved by comparator, so prioritise common att names -->
    <xsl:variable name="name-priority-order" as="element()*" 
      select="(dxa:name, dxa:id, dxa:class, dxa:property, dxa:key)"/>
    <xsl:variable name="unordered-atts" as="element()*" select="*"/>
    <xsl:variable name="reordered-atts" as="element()*" 
      select="$name-priority-order, (* except $name-priority-order)"/>
    <xsl:for-each select="$unordered-atts">
      <xsl:variable name="att-name" select="deltaxml:attribute-name(.)"/>
      <xsl:choose>
        <xsl:when test="self::dxx:base"/>
        <xsl:when test="@deltaxml:deltaV2 eq 'A!=B'">
          <xsl:variable name="att-valueA" select="fn:format-att-value($att-name, deltaxml:attributeValue[@deltaxml:deltaV2='A'])"/>
          <xsl:variable name="att-valueB" select="fn:format-att-value($att-name, deltaxml:attributeValue[@deltaxml:deltaV2='B'])"/>
          <xsl:variable name="att-value-has-formatting" as="xs:boolean" 
            select="fn:is-formatted($att-valueA) or fn:is-formatted($att-valueB)"/>
          <xsl:variable name="is-newline-att" as="xs:boolean" 
            select="$att-count-exceded or
            ($newline-att-size-int gt 0 and (string-length(.) gt $newline-att-size-int)
            or $att-value-has-formatting)"/>
          <xsl:value-of select="if($is-newline-att) then '' else ' '"/>
          <span>
            <xsl:if test="$is-newline-att">
              <xsl:attribute name="data-newline-att"/>
            </xsl:if>
            <xsl:value-of select="$att-name"/><xsl:text>="</xsl:text>
            <xsl:for-each select="deltaxml:attributeValue[@deltaxml:deltaV2='A']">
              <span data-is-attr-val="" id="{fn:createIdValue(., 'delete')}" class="delete"><xsl:value-of select="$att-valueA"/></span>
            </xsl:for-each>
            <xsl:for-each select="deltaxml:attributeValue[@deltaxml:deltaV2='B']">
              <xsl:variable name="att-value-prefix" 
                select="if (false()) (: ($is-newline-att) :) then
                concat('&#10;',fn:padding-for-att-value($att-name))
                else ''"/>
              <span data-is-attr-val=""  id="{fn:createIdValue(., 'add')}" class="add"><xsl:value-of select="string-join(($att-value-prefix, $att-valueB),'')"/></span>
            </xsl:for-each>
            <xsl:text>"</xsl:text> 
          </span>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="deltaType" as="xs:string" select="if(@deltaxml:deltaV2 eq 'A') then 'delete' else 'add'"/>
          <xsl:for-each select="deltaxml:attributeValue">
            <xsl:variable name="att-value" select="fn:format-att-value($att-name, .)"/>
            <xsl:variable name="is-newline-att" as="xs:boolean" 
              select="$att-count-exceded or 
              ($newline-att-size-int gt 0 and (string-length(.) gt $newline-att-size-int) 
              or contains($att-value, '&#10;'))"/>
            <xsl:value-of select="if($is-newline-att) then '' else ' '"/>
          <span data-is-attr-full="" id="{fn:createIdValue(., $deltaType)}" class="{$deltaType}">
            <xsl:if test="$is-newline-att">
              <xsl:attribute name="data-newline-att"/>
            </xsl:if>
            <xsl:value-of select="$att-name"/><xsl:text>="</xsl:text><span data-diff-att-value=""><xsl:value-of select="$att-value"/></span><xsl:text>"</xsl:text></span>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
   
  <xsl:template match="deltaxml:textGroup" mode="#default within-comment-element unescaped-element-content">
    <xsl:param name="parent-is-mixed" as="xs:boolean" select="false()"/>
    <xsl:apply-templates select="*" mode="#current">
      <xsl:with-param name="parent-is-mixed" select="$parent-is-mixed"/>
      <xsl:with-param name="modifyA" as="element()?" select="if (count(deltaxml:text) eq 2) then deltaxml:text[1] else ()"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="deltaxml:text[@deltaxml:deltaV2=('A','B')]" mode="#default">
    <xsl:param name="parent-is-mixed" select="false()"/>
    <!-- use this to allow simultaneous higlighting in both panes of modified text: -->
    <xsl:param name="modifyA" as="element()?"/>
      
    <xsl:if test="not(fn:hide-change(., $parent-is-mixed))">
      <xsl:variable name="delta-value" as="xs:string" select="if(@deltaxml:deltaV2 eq 'A') then 'delete' else 'add'"/>
      <span 
        class="{$delta-value}" 
        id="{fn:createIdValue(., $delta-value)}" data-text-change="">
          <xsl:value-of select="fn:escape-element-text(.)"/>
      </span>
    </xsl:if>
  </xsl:template>
    
  <xsl:template match="deltaxml:text[@deltaxml:deltaV2=('A','B')]" 
    mode=" unescaped-element-content within-comment-element">
    <xsl:param name="parent-is-mixed" select="false()"/>
    <xsl:variable name="delta-value" as="xs:string" select="if(@deltaxml:deltaV2 eq 'A') then 'delete' else 'add'"/>
    <xsl:if test="not(fn:hide-change(., $parent-is-mixed))">
      <span 
        class="{$delta-value}" 
        id="{fn:createIdValue(., $delta-value)}" data-text-change="">
        <xsl:value-of select="."/>
      </span>
    </xsl:if>
  </xsl:template>
  
  <xsl:function name="fn:hide-change" as="xs:boolean">
    <xsl:param name="context" as="element()"/>
    <xsl:param name="parent-is-mixed" as="xs:boolean"/>
    <xsl:for-each select="$context">
      <xsl:variable name="stripped-line" select="replace(., '^\s+','')"/>
      <xsl:sequence 
        select="
        not($root-space-preserved)
        and $b-smart-whitespace-normalization
        and $b-supress-formatting-only-changes
        and (exists(../../*[not(self::deltaxml:*)]))
        and not($parent-is-mixed) 
        and not(parent::*/parent::preserve:*)
        and string-length($stripped-line) eq 0"/>
    </xsl:for-each>
  </xsl:function>
  
  <xsl:template match="@preserve:*"/>
  
  <xsl:template match="@*">
    <xsl:param name="att-count-exceded" as="xs:boolean" select="false()"/>
    <xsl:variable name="deltaV2" as="xs:string?" select="ancestor::*[@deltaxml:deltaV2][1]/@deltaxml:deltaV2"/>
    <xsl:variable name="class" as="xs:string?">
    <xsl:choose>
      <xsl:when test="$deltaV2 eq 'B'">
        <xsl:sequence select="'add'"/>
      </xsl:when>
      <xsl:when test="empty($deltaV2) or $deltaV2=('A=B','A!=B')">
        <xsl:sequence select="'unchanged'"/>
      </xsl:when>
      <xsl:when test="$deltaV2 eq 'A'">
        <xsl:sequence select="'delete'"/>
      </xsl:when>
    </xsl:choose>
    </xsl:variable>
    <span class="{$class}" data-att-unchanged="">
      <xsl:variable name="att-value" select="fn:format-att-value(concat(name(),'+'), .)"/>
      <xsl:variable name="is-newline-att" as="xs:boolean"
        select="$att-count-exceded or
        ($newline-att-size gt 0 and (string-length(.) gt $newline-att-size)
        or fn:is-formatted($att-value))"/>
      <xsl:if test="$is-newline-att">
        <xsl:attribute name="data-newline-att" select="''"/>
      </xsl:if>
      <xsl:value-of select="if($is-newline-att) then '' else ' '"/>     
      <xsl:value-of select="name()"/>="<span data-att-value=""><xsl:value-of select="$att-value"/></span>"</span>
  </xsl:template>
  
  <xsl:function name="fn:format-att-value" as="xs:string">
    <xsl:param name="att-name" as="xs:string"/>
    <xsl:param name="text" as="xs:string"/>

    <xsl:variable name="escaped-text" select="fn:escape-attribute-text($text)"/>
    <xsl:choose>
      <xsl:when test="$newline-att-size gt 0">

        <xsl:sequence select="replace($escaped-text, '\s{4,}', concat('&#10;', fn:padding-for-att-value($att-name)))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$escaped-text"/>
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:function>
  
  <xsl:function name="fn:escape-attribute-text" as="xs:string">
    <xsl:param name="text"/>
    <xsl:variable name="codepoints" as="xs:integer*" select="string-to-codepoints($text)"/>
    <xsl:variable name="count" as="xs:integer" select="count($codepoints)"/>
    <xsl:sequence
      select="string-join(for $n in $codepoints return
      if ($n eq 34) then '&amp;quot;'
      else if ($n eq 38) then '&amp;amp;'
      else if ($n eq 60) then '&amp;lt;'
      else if ($n eq 160) then '&amp;#160;'
      else codepoints-to-string($n)
      ,'')"/>
  </xsl:function>
  
  <xsl:function name="fn:escape-element-text" as="xs:string">
    <xsl:param name="text"/>
    <xsl:variable name="codepoints" as="xs:integer*" select="string-to-codepoints($text)"/>
    <xsl:variable name="count" as="xs:integer" select="count($codepoints)"/>
    <xsl:sequence
      select="string-join(for $n in $codepoints return
      if ($n eq 38) then '&amp;amp;'
      else if ($n eq 60) then '&amp;lt;'
      else if ($n eq 160) then '&amp;#160;'
      else codepoints-to-string($n)
      ,'')"/>
  </xsl:function>
  
  <xsl:function name="fn:padding-for-att-value" as="xs:string">
    <xsl:param name="att-name"/>
    <xsl:sequence select="string-join(for $x in 1 to string-length($att-name) + 2 return '&#160;', '')"/>
  </xsl:function>
  
  <xsl:function name="fn:is-formatted" as="xs:boolean">
    <xsl:param name="att-value" as="xs:string"/>
    <xsl:sequence select="contains($att-value, '&#10;')"/>
  </xsl:function>
  
  <!-- ///////////////// lexical preservation ///////////// -->
  
  <xsl:template match="preserve:pi-and-comment" mode="#default"/>
  <xsl:template match="preserve:doctype" mode="#default"/>
  
  <xsl:template match="preserve:doctype" mode="prolog">
    <xsl:apply-templates select="." mode="doctype"/>
  </xsl:template>
  
  <xsl:template match="preserve:pi-and-comment" mode="prolog epilog">
     <xsl:apply-templates/>
  </xsl:template>
      
    
  <xsl:template match="preserve:entity-group" mode="#all">
     <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="preserve:xmldecl" mode="#default"/>
  
  <!-- rRmove xmldecl as the information will already have been passed to the Serializer -->
  <xsl:template match="preserve:xmldecl" mode="prolog">
    <div class="xml-declaration"><span>&lt;?xml version="<xsl:call-template name="add-xmldecl-data"/> ?&gt;</span></div>
  </xsl:template>
  
  <xsl:template name="add-xmldecl-data">
    <xsl:if test="@xml-version">
      <span data-att-value="yes"><xsl:value-of select="@xml-version"/></span>" <xsl:text/>
    </xsl:if>
    <xsl:if test="@encoding">
      <span> encoding="<span data-att-value="yes"><xsl:value-of select="@encoding"/></span>"</span>
    </xsl:if>
  </xsl:template>
  
  <!-- ///////////////// functions ///////////// -->
    
  <xsl:function name="fn:measure-attributes" as="xs:integer">
    <xsl:param name="element" as="element()"/>

    <xsl:for-each select="$element">
      <xsl:variable name="unchanged-atts" as="attribute()*" select="@* except (@preserve:*, @deltaxml:*)"/>
      <xsl:variable name="unchanged-atts-sum" as="xs:integer" 
        select="sum(((for $a in $unchanged-atts return (string-length($a) + string-length(name($a))) + 4), 0))"/>
      <xsl:variable name="changed-atts" as="element()*" select="deltaxml:attributes/*"/>
      <xsl:variable name="changed-atts-sum" as="xs:integer" 
        select="sum(((for $a in $changed-atts return string-length(name($a)) + (string-length(string-join($a/*,''))) + 4), 0))"/>
      <xsl:sequence select="sum(($changed-atts-sum, $unchanged-atts-sum))"/>
    </xsl:for-each>
  </xsl:function>
  
  <xsl:function name="fn:add-compact-attr" as="attribute()">
    <xsl:param name="always-show" as="xs:boolean"/>
    <xsl:param name="delta-value"/>
    <xsl:attribute name="class">
      <xsl:choose>
        <xsl:when test="$delta-value eq 'unchanged' and not($always-show)">
          <xsl:value-of select="'collapsed'"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="'expanded'"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
  </xsl:function>
  
  <xsl:function name="fn:add-comment-attr" as="attribute()">
    <xsl:param name="parent-is-mixed"/>
    <xsl:param name="delta-value"/>
    <xsl:attribute name="class">
      <xsl:choose>
        <xsl:when test="$delta-value='unchanged' or $parent-is-mixed">
          <xsl:value-of select="'expanded'"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="'collapsed'"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
  </xsl:function>
  
  <!-- assumption is that element is indented and not within mixed content -->
  <xsl:function name="fn:preserve-space-in-element" as="xs:boolean">
    <xsl:param name="element" as="element()"/>
    <xsl:for-each select="$element">
      <xsl:variable name="preceding-text" 
        select="(preceding-sibling::text()|preceding-sibling::deltaxml:textGroup/deltaxml:text[1]/text())[1]" as="node()?"/>
      <xsl:choose>
        <xsl:when test="empty(parent::*) and @preserve:space eq 'preserve'">
          <xsl:sequence select="false()"/>
        </xsl:when>
        <xsl:when test="exists($preceding-text)">
          <xsl:variable name="preceding-lines" as="xs:string*" select="tokenize($preceding-text, '\n')"/>
          <xsl:variable name="parent-indent-size" as="xs:integer" select="string-length($preceding-lines[last()])" />
          <xsl:variable name="lines" as="xs:string*" select="tokenize(text()[1], '\n')"/>
          <!-- ignore first line as it has no indentation -->
          <xsl:variable name="line" as="xs:string?" select="$lines[2]"/>
          <xsl:choose>
            <!-- check for case where '&lt' is represented as <er:lt/> in code snippets -->
            <xsl:when test="exists($line) and not(matches($line, '^\s*$') and not(node()[2][self::er:lt]))">
              <xsl:variable name="trimmed-line" as="xs:string" select="replace($line, '^\s+','')"/>
              <xsl:variable name="child-indent-size" select="string-length($line) - string-length($trimmed-line)"/>
              <xsl:sequence select="$child-indent-size lt $parent-indent-size"/>
            </xsl:when>
            <xsl:otherwise><xsl:sequence select="false()"/></xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise><xsl:sequence select="false()"/></xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:function>
  
  <!-- 
  calculate the max amount of chars that can be trimmed in a preserve:comment
  element - dont count first line or any other lines that have no text content
  - text-items must be in the order a+b, a-only, b-only
  -->
  <xsl:function name="fn:calc-trim-amount" as="xs:integer+">
    <xsl:param name="container" as="element()"/>
    <xsl:variable name="both" as="text()*" select="$container/text()"/>
    <xsl:variable name="both-and-a" as="text()*" select="$container/text() | $container//deltaxml:text[@deltaxml:deltaV2 eq 'A']/text()"/>
    <xsl:variable name="both-and-b" as="text()*" select="$container/text() | $container//deltaxml:text[@deltaxml:deltaV2 eq 'B']/text()"/>
    <xsl:variable name="text-items" as="xs:string*" select="string-join($both,''), string-join($both-and-a,''), string-join($both-and-b,'')"/>
    <xsl:for-each select="$text-items">
      <xsl:variable name="aggregated-text" as="xs:string" select="."/>
      <xsl:variable name="lines" select="tokenize($aggregated-text, '\n')"/>
      <xsl:variable name="stripped-lines" as="xs:string*" select="for $x in $lines return replace($x, '^\s+','') "/>
      <!-- to find min don't measure padding on first line -->
      <xsl:variable name="line-count" select="count($lines)"/>
      <xsl:variable name="spacebefore-lines" as="xs:integer*" 
        select="for $x in 2 to $line-count return 
        if (string-length($stripped-lines[$x]) eq 0) then () else string-length($lines[$x]) - string-length($stripped-lines[$x])"/>
      <xsl:sequence select="(min($spacebefore-lines),0)[1]"/>
    </xsl:for-each>
    
  </xsl:function>  
  
  <!-- In the dx2 format attributes are stored as elements and these
  elements have the same namespace as the corresponding attribute,
  with 2 exceptions, when the attribute wasn't in a namespace or
  was in the xml: namespace for example xml:space or xml:id.
  This function gets the appropriate name for display -->
  <xsl:function name="deltaxml:attribute-name" as="xs:string">
    <xsl:param name="attribute-node" as="element()"/>
    <xsl:value-of select="if ($attribute-node[self::dxa:*])
      then local-name($attribute-node) 
      else if ($attribute-node[self::dxx:*]) 
      then concat('xml:', local-name($attribute-node)) 
      else 
      name($attribute-node)"/>
  </xsl:function>
  
  <xsl:function name="fn:add-xmlns-declarations" as="xs:string*">
    <xsl:param name="current-xmlns" as="xs:string*"/>
    <xsl:param name="new-xmlns" as="xs:string*"/>
    <xsl:variable name="new" 
      select="for $x in $new-xmlns return
      if($x = $current-xmlns or substring-after($x, '?') = $reserved-namespaces) then () else $x"/>
    <xsl:sequence select="for $x in $new return
      if (substring-before($x, '?') eq '') then
      concat(' xmlns=&quot;', substring-after($x, '?'), '&quot;')
      else 
      concat(' xmlns:', substring-before($x, '?'), '=&quot;', substring-after($x, '?'), '&quot;')"/>
  </xsl:function>
  
  
  <xsl:function name="fn:get-xmlns" as="xs:string*">
    <xsl:param name="c"/>
    <xsl:variable name="xmlns-prefixes" select="in-scope-prefixes($c)[not(. = ('xml','deltaxml'))]" as="xs:string*"/>
    <xsl:sequence 
      select="for $pfx in $xmlns-prefixes 
      return concat($pfx, '?', namespace-uri-for-prefix($pfx, $c))"/>
  </xsl:function>
    
  <xsl:function name="fn:unescape-entity-references" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:variable name="processed-matches" as="xs:string*">
      <!-- TODO: regex should ideally be more robust to handle !! escaping -->
      <xsl:analyze-string select="$text" regex="!\((.*?)!\)">
        <xsl:matching-substring>
          <xsl:variable name="val" select="regex-group(1)"/>
          <xsl:variable name="resolved-val"
            select="if(starts-with($val, '*')) then
            if ($val eq '*lt') then '&lt;'
            else if ($val eq '*gt') then '&gt;'
            else if ($val eq '*quot') then '&quot;'
            else if ($val eq '*apos') then '&apos;&apos;'
            else if ($val eq '*amp;') then '&amp;'
            else ''
            else concat('&amp;', $val,';')"/>
          <xsl:sequence select="$resolved-val"/>
        </xsl:matching-substring>
        <xsl:non-matching-substring>
          <xsl:sequence select="replace(current(), '!!', '!')"/>
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:variable>
    <xsl:sequence select="string-join($processed-matches, '')"/>
  </xsl:function>
  
  <xsl:function name="fn:calcTocString" as="xs:string">
    <xsl:param name="context" as="item()"/>
    <xsl:variable name="prefix" select="if($context/parent::preserve:doctype) then '%' else '&amp;'"/>
    <xsl:variable name="entity-symbol" select="concat($prefix,local-name($context),';')"/>
    <xsl:variable name="stringVal" select="if($context/self::er:*) then $entity-symbol else normalize-space($context)"/>
    <xsl:choose>
      <xsl:when test="$context instance of element()">
        <xsl:sequence select="if(string-length($stringVal) eq 0) then ''' ''' else $stringVal"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$stringVal"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="fn:check-if-mixed" as="xs:boolean">
    <xsl:param name="context" as="element()"/>
    <xsl:variable name="text" as="xs:string" select="string-join($context/text(),'')"/>
    <xsl:variable name="whitespace-only" as="xs:boolean" select="not(exists($context/er:*)) and matches($text, '^\s*$')"/>
    <!-- assume single space char is a separator and not used for formatting -->
    <xsl:variable name="is-minimal-ws" as="xs:boolean" select="every $ws-node in $context/text() satisfies $ws-node eq ' '"/>
    
    <xsl:variable name="result" as="xs:boolean" 
      select="if(empty($context/text())) then false()
      else if(empty($context/*)) then false()  
      else if($whitespace-only) then ($is-minimal-ws) else true()"/>       
    <xsl:sequence select="$result"/>
  </xsl:function>
  
  <xsl:function name="fn:check-if-mixed-root-preserved" as="xs:boolean">
    <xsl:param name="context" as="element()"/>
    <xsl:variable name="text" as="xs:string" select="string-join($context/text(),'')"/>
    <xsl:variable name="whitespace-only" as="xs:boolean" select="not(exists($context/er:*)) and matches($text, '^\s*$')"/>
    <!-- assume single space char is a separator and not used for formatting -->
    
    <xsl:variable name="result" as="xs:boolean" 
      select="if(empty($context/text())) then false()
      else if(empty($context/*)) then false()  
      else if($whitespace-only) then false() else true()"/>       
    <xsl:sequence select="$result"/>
  </xsl:function>

</xsl:stylesheet>