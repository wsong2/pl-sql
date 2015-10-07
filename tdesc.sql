set serveroutput on FORMAT WRAPPED
set feedback off
set verify off

DECLARE	--- Rev1.2
	TYPE TABVC30  IS TABLE OF VARCHAR2(30);
	TYPE TABVC255 IS TABLE OF VARCHAR2(255);
	TYPE TABINT IS TABLE OF PLS_INTEGER;

    p_name 		VARCHAR2(30) := UPPER('&1');
	tab_names	TABVC30;
	tab_types	TABVC255;
	tab_PKs		TABVC30;
	tab_IDs		TABINT;
	
	l_constraint_name 	VARCHAR2(30);
BEGIN
	IF INSTR(p_name, '*') > 0 THEN
		p_name := REPLACE(p_name, '*', '%');
	END IF;
	
	IF INSTR(p_name, '%') > 0 THEN
		IF INSTR(p_name, '_') > 0 THEN
			SELECT	table_name BULK COLLECT INTO tab_names
			FROM	all_tab_columns
			WHERE	table_name like REPLACE(p_name, '_', '@_') escape '@' --
			GROUP BY table_name;			
		ELSE
			SELECT	table_name BULK COLLECT INTO tab_names
			FROM	all_tab_columns
			WHERE	table_name like p_name
			GROUP BY table_name;
		END IF;
		
		IF tab_names.COUNT <> 1 THEN
			IF tab_names.COUNT = 0 THEN
				DBMS_OUTPUT.put_line('No table name matching ' || p_name);
			ELSIF tab_names.COUNT > 50 THEN
				DBMS_OUTPUT.put_line('Two many matched names for ' || p_name);
			ELSE
				DBMS_OUTPUT.put_line('[Tables]');
				FOR i IN 1..tab_names.COUNT LOOP
					DBMS_OUTPUT.put_line(' ' || tab_names(i));
				END LOOP;			
			END IF;
			RETURN;
		END IF;
		
		p_name := tab_names(1);		
	END IF;
	
	SELECT	MAX(constraint_name) INTO l_constraint_name
	FROM	all_constraints
	WHERE	constraint_type = 'P' AND table_name = p_name AND rownum=1;
	
	WITH
		tc AS (
			SELECT 	column_name
				,	max(column_id) column_id
				,	CASE MAX(data_type)
					WHEN 'CHAR' THEN MAX(data_type) || '(' || MAX(data_length) || ')'
					WHEN 'VARCHAR2' THEN MAX(data_type) || '(' || MAX(data_length) || ')'
					WHEN 'NVARCHAR2' THEN MAX(data_type) || '(' || (MAX(data_length)/2) || ')'
					WHEN 'NUMBER' THEN MAX(data_type) || '(' || MAX(data_precision) || ')'
					ELSE MAX(data_type) END  col_type
				,	CASE MAX(nullable) WHEN 'N' THEN 'NOT NULL' ELSE ' ' END col_nullable
			FROM all_tab_columns
			WHERE table_name = p_name
			GROUP BY column_name
		),
		pk AS (
			SELECT 	column_name, position
			FROM  all_cons_columns
			WHERE table_name = p_name AND constraint_name = l_constraint_name
		)
	SELECT 	tc.column_name
		,	tc.column_id
		, 	tc.col_type
		,	CASE WHEN pk.column_name IS NULL THEN tc.col_nullable ELSE 'PK' END
	BULK COLLECT INTO
			tab_names
		, 	tab_IDs
		,	tab_types
		,	tab_PKs
	FROM tc LEFT JOIN pk ON tc.column_name = pk.column_name
	ORDER BY NVL(pk.position, 30000), tc.column_name;

	DBMS_OUTPUT.put_line('[' || p_name || '] ' || LPAD(' @', 57-LENGTH(p_name), '-') );
    FOR i IN 1..tab_names.COUNT LOOP
		DBMS_OUTPUT.put_line(' ' || 
			RPAD(tab_names(i), 31) ||
			RPAD(tab_types(i), 15) ||
			RPAD(tab_PKs(i), 9) || 
			LPAD(tab_IDs(i), 4)
		);
    END LOOP;
	DBMS_OUTPUT.put_line(LPAD(tab_names.COUNT, 60));
	
EXCEPTION
    WHEN OTHERS THEN    
        DBMS_OUTPUT.put_line (SQLERRM);
END;
/

exit

