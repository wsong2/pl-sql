set heading off 
set pause off
set linesize 1000
set pagesize 0
set feedback off
set verify off
set define !

define l_pkg = PKG_NAME

PROMPT CREATE OR REPLACE
SELECT rtrim(text) FROM all_source WHERE owner = 'OWNERNAME' and name = '!l_pkg' and type = 'PACKAGE' ORDER BY line;

PROMPT /
PROMPT show err
PROMPT

PROMPT CREATE OR REPLACE
SELECT rtrim(text) FROM all_source WHERE owner = 'OWNERNAME' and name = '!l_pkg' and type = 'PACKAGE BODY' ORDER BY line;
PROMPT
PROMPT /
PROMPT show err
PROMPT exit

exit
