#!/bin/sh

rm -rf web
mkdir web

for i in *.h
do 
	webcpp $i web/$i.html -h -l
done

for i in *.cpp
do 
	webcpp $i web/$i.html -h -l
done

mv web ~/Desktop/eclipse/workspace/kismac/gtdriver/src
