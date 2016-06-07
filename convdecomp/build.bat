@echo off
del *.class
del compgeom\*.class
javac compgeom\*.java -source 1.3
javac *.java
java %1