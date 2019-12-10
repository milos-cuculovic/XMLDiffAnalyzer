#!/bin/bash

# If this script is not working on linux please see the notes in the file:
#   docs/notes/deltaxml-gui-linux-notes.txt

cd "$(dirname "$(readlink $0)")"

PRODUCT_FACTORY="com.deltaxml.core.framework.CoreProductFactory";
PRODUCT_NAME="DeltaXML XML Compare";
PRODUCT_VERSION="10.1.2";
JAR_NAME=$(find deltaxml-*.jar -type f -not -name '*rest*' -not -name '*gui*')
JAR_GUI_NAME=$(find deltaxml-gui*.jar -type f)

SWT_NAME=$(java -cp $JAR_GUI_NAME com.deltaxml.gui.JavaEnvironmentDetails)

JAVA_EXIT_CODE=$?;

if [ -f "swt.jar" ] ; then
  SWT_JAR="swt.jar";
else
  if [ "${JAVA_EXIT_CODE}" -ne "0" ] ; then
    echo "We have been unable to work out which version of the SWT Jar you require to run deltaxml-gui. Java reports:";
    echo $SWT_NAME;
    echo "Please download the required version of SWT for your platform from:";
    echo "   http://archive.eclipse.org/eclipse/downloads/drops/R-3.7-201106131736/";
    echo "and copy the included 'swt.jar' to your DeltaXML install directory (i.e. where this script lives)";
    exit 1;
  fi

  SWT_JAR="swt-lib/$SWT_NAME.jar";

  if [ ! -f $SWT_JAR ] ; then
    echo "No SWT jar found for required environment. Please download the correct SWT binary from:";
    echo "   http://archive.eclipse.org/eclipse/downloads/drops/R-3.7-201106131736/";
    echo "it should match: $SWT_NAME and be saved to $SWT_JAR.";
    exit 2;
  fi
fi

if [[ $SWT_NAME == *macosx* ]] ; then
  EXTRA_OPTIONS="-XstartOnFirstThread";
fi

CLASSPATH=.:$JAR_GUI_NAME:$JAR_NAME:xercesImpl.jar:saxon9pe.jar:icu4j.jar:resolver.jar:puremvc-java-1.0.jar:$SWT_JAR;

java $EXTRA_OPTIONS\
     -cp $CLASSPATH\
     -Dfile.encoding=UTF-8 \
     -Dcom.deltaxml.framework.factory="$PRODUCT_FACTORY" \
     -Dcom.deltaxml.gui.appName="$PRODUCT_NAME" \
     -Dcom.deltaxml.gui.appVersion="$PRODUCT_VERSION" \
     com.deltaxml.gui.SwtGuiFacade
