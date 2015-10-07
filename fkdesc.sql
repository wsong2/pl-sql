set serveroutput on format wrapped
set feedback off
set verify off

DECLARE	--- Rev1.0
	TYPE HTINTKC30 IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(30);
	TYPE TABVC30   IS TABLE OF VARCHAR2(30);
	
	ht_names 	HTINTKC30;
	
	tbl_names		TABVC30;
	tbl_constraints	TABVC30;
	tbl_names_2		TABVC30; 
	
	p_name	VARCHAR2(30) := UPPER('&1');
	n_level	PLS_INTEGER := 0;
BEGIN
	IF INSTR(p_name, '*') > 0 THEN
		p_name := REPLACE(p_name, '*', '%');
	END IF;
	
	IF INSTR(p_name, '%') > 0 THEN
		
		IF INSTR(p_name, '_') > 0 THEN
			p_name := REPLACE(p_name, '_', '@_'); --escape '@';
		END IF;
		
		FOR c IN (
			SELECT 	C1.table_name
				,  	lower(C1.constraint_name) Constraint
				, (	select 	C2.table_name
					from 	all_constraints C2
					where 	C2.constraint_type = 'P' and C2.constraint_name = C1.r_constraint_name
				) 	Parent
			FROM    all_constraints C1
			WHERE   C1.constraint_type = 'R' AND C1.table_name like p_name	escape '@' -- has FK
			ORDER BY 3
		) LOOP
			DBMS_OUTPUT.put_line(RPAD(c.table_name, 30) || RPAD(c.Constraint, 13) || RPAD(c.Parent, 30));	
		END LOOP;
	
	ELSE

		tbl_names := TABVC30();
		tbl_names.extend(1);
		tbl_names(1) := p_name;
		ht_names(p_name) := 0;
	
		FOR n IN 1..ht_names.COUNT LOOP
			p_name := tbl_names(n);
			SELECT 	lower(F.constraint_name)
				,(	select 	P.table_name
					from 	all_constraints P
					where 	P.constraint_type = 'P' and P.constraint_name = F.r_constraint_name )
			BULK COLLECT INTO
					tbl_constraints
				, 	tbl_names_2
			FROM    all_constraints F
			WHERE   F.constraint_type = 'R' AND F.table_name = p_name
			ORDER BY 2;
	
			n_level := ht_names(p_name);
			IF tbl_constraints.COUNT > 0 THEN
				DBMS_OUTPUT.put_line(RPAD(' ', n_level) || p_name || ':');
			END IF;
		
			n_level := n_level + 2;
			FOR i IN 1..tbl_constraints.COUNT LOOP
				p_name := tbl_names_2(i);
				DBMS_OUTPUT.put_line(RPAD(' ', n_level) || RPAD(tbl_constraints(i), 12) || '~~ ' || p_name);
				IF NOT ht_names.EXISTS(p_name) THEN
					tbl_names.extend(1);
					tbl_names(tbl_names.COUNT) := p_name;
					ht_names(p_name) := n_level;
				END IF;
			END LOOP;
		END LOOP;
		
	END IF;
	
EXCEPTION
    WHEN OTHERS THEN    
        DBMS_OUTPUT.put_line (SQLERRM);
END;
/

exit
