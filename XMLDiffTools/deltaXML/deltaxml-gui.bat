@ECHO OFF
REM Batch file to run Java GUI on Windows
REM It will attempt to load the correct bitness SWT JAR,
REM and report if the SWT JAR does not match the running JVM.

SET PRODUCT_FACTORY="com.deltaxml.core.framework.CoreProductFactory"
SET PRODUCT_NAME="DeltaXML XML Compare"
SET PRODUCT_VERSION="10.3.0"
FOR /F %%i IN ('dir /B deltaxml-???.???.???.jar') DO SET JAR_NAME=%%i
FOR /F %%i IN ('dir /B deltaxml-gui-???.???.???.jar') DO SET GUI_JAR_NAME=%%i


REM We must assign all variables before the IF ELSE block as variables are fixed within a block.
IF DEFINED JAVA_HOME SET JAVAHOMECMD=%JAVA_HOME:"=%
SET JAVA_BIN_PATH=%JAVAHOMECMD%\bin\java
SET JAVA_BIN_PATH_FIXED=%JAVA_BIN_PATH:"=%
SET JAVACMD=%JAVA_BIN_PATH_FIXED%

IF DEFINED JAVA_HOME (
IF ["%JAVAHOMECMD%"]==[""] (
ECHO Using 'java' as Java command
SET JAVACMD="java"
) ELSE (
ECHO "Using %JAVA_BIN_PATH_FIXED% as Java command"
)
)
IF NOT DEFINED JAVA_HOME (
ECHO Using 'java' as Java command
SET JAVACMD="java"
)

FOR /F %%i IN ('"%JAVACMD%" -cp %GUI_JAR_NAME% com.deltaxml.gui.JavaEnvironmentDetails') DO SET SWT_NAME=%%i

SET SWT_JAR="swt-lib\%SWT_NAME%.jar"

IF EXIST "swt.jar" (
  SET SWT_JAR=swt.jar
  ) ELSE (
  IF NOT EXIST %SWT_JAR% (
    @ECHO ON
    ECHO No SWT jar found for required environment. Please download the correct SWT binary from:
    ECHO    http://archive.eclipse.org/eclipse/downloads/drops/R-3.7-201106131736/
    ECHO it should match: %SWT_NAME% and be saved to %SWT_JAR%.
    EXIT /B 2;
  )
)

SET CLASSPATH=.;"%GUI_JAR_NAME%";"%JAR_NAME%";xercesImpl.jar;saxon9pe.jar;icu4j.jar;resolver.jar;puremvc-java-1.0.jar;%SWT_JAR%

"%JAVACMD%" -cp %CLASSPATH% -Dfile.encoding=UTF-8 -Dcom.deltaxml.framework.factory=%PRODUCT_FACTORY% -Dcom.deltaxml.gui.appName=%PRODUCT_NAME% -Dcom.deltaxml.gui.appVersion=%PRODUCT_VERSION% com.deltaxml.gui.SwtGuiFacade

REM Tidy up all variables created
SET PRODUCT_FACTORY=
SET PRODUCT_NAME=
SET PRODUCT_VERSION=
SET JAVAHOMECMD=
SET JAVA_BIN_PATH=
SET JAVA_BIN_PATH_FIXED=
SET JAVACMD=
SET SWT_NAME=
SET SWT_JAR=
SET CLASSPATH=
