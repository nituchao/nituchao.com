#!/bin/sh

hugo
echo "============================\n"
echo "成功生成网站\n"
git add .
git commit -s -m 'update post'
git push origin master
echo "成功发布网站\n"
echo "============================\n"
