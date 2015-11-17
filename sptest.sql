set serveroutput on FORMAT WRAPPED
set feedback off
set verify off

DECLARE	--- Rev0.5
	TYPE t_tableVC65  IS TABLE OF VARCHAR2(65);
	TYPE t_tableINT IS TABLE OF PLS_INTEGER;
	c_OWNER	VARCHAR2(10) := 'VISTAPACK';
	
    g_pkg 	VARCHAR2(30);
    g_prc 	VARCHAR2(30);
	g_num	PLS_INTEGER;
	
	g_obj_names		t_tableVC65;
	g_prc_names		t_tableVC65;
	
	g_arg_names		t_tableVC65;
	g_arg_types		t_tableVC65;
	g_arg_io_flags	t_tableVC65;
	g_params		t_tableVC65;
	g_subprog_ids	t_tableINT;
	
	g_cnt 	PLS_INTEGER;
	g_prev	VARCHAR2(30);
	g_max 	PLS_INTEGER := 0;
	g_lead	VARCHAR2(30) := '?';
	g_pfx	VARCHAR2(2);
	
	l_exception_20001 EXCEPTION;
    PRAGMA EXCEPTION_INIT(l_exception_20001, -20001);
	
	--
    PROCEDURE parse_arg (p_arg IN VARCHAR2) IS
		l_pat 	VARCHAR2(65);	-- 30+1+30+1+3; <pkg>.<sp>[#N]
		l_pos 	PLS_INTEGER;
    BEGIN
		l_pat := REPLACE(UPPER(p_arg), '*', '%');
		l_pos := INSTR(l_pat, '.');
		IF l_pos = 0 THEN
			raise_application_error(-20001, 'Argument format: <pkg>.<sp>[#N]');
		END IF;
		
		g_pkg := SUBSTR(l_pat, 1, l_pos-1);
		g_prc := SUBSTR(l_pat, l_pos+1);
		g_num := 0;
		l_pos := INSTR(g_prc, '#');
		IF l_pos > 0 THEN
			g_num := TO_NUMBER(SUBSTR(g_prc, l_pos+1), '99');
			g_prc := SUBSTR(g_prc, 1, l_pos-1);
		END IF;
    END parse_arg;
	
	--
    PROCEDURE get_proc_args_list (p_pkg IN VARCHAR2, p_prc IN VARCHAR2, p_id IN PLS_INTEGER) IS
    BEGIN
		SELECT 	argument_name
			,	DECODE(pls_type, 
					'VARCHAR2', 'VARCHAR2(' || CHAR_LENGTH || ')',
					NULL, NVL2(type_subname, type_name || '.' || type_subname, type_name),
					pls_type)
			--,	NVL(pls_type, NVL2(type_subname, type_name || '.' || type_subname, type_name))
			,	in_out
			,	NULL
		BULK COLLECT INTO g_arg_names, g_arg_types, g_arg_io_flags, g_params
		FROM all_arguments
		WHERE owner = c_OWNER AND data_level = 0
		  AND package_name = p_pkg AND object_name = p_prc AND subprogram_id = p_id
		ORDER BY sequence;
    END get_proc_args_list;

BEGIN
	parse_arg('&1');

	-----------------------
	-- Matching SP Names --
	-----------------------
	SELECT object_name, procedure_name, subprogram_id
	BULK COLLECT INTO g_obj_names, g_prc_names, g_subprog_ids
	FROM all_procedures
	WHERE owner=c_OWNER
	  AND object_name LIKE g_pkg
	  AND procedure_name like g_prc
	  AND subprogram_id = DECODE(g_num, 0, subprogram_id, g_num)
	ORDER BY 1, 2, 3;
	
	IF g_prc_names.COUNT < 1 THEN
		DBMS_OUTPUT.put_line(' ');
		DBMS_OUTPUT.put_line('No match');
		--- %end% ---
		RETURN;
	END IF;
	
	-- Different packages or Different procedures names
	g_cnt := g_prc_names.COUNT;
	IF g_obj_names(1) <> g_obj_names(g_cnt) OR g_prc_names(1) <> g_prc_names(g_cnt) THEN
		g_prev	:= '?';
		FOR i IN 1..LEAST(g_cnt, 50) LOOP
			IF g_obj_names(i) <> g_prev THEN
				DBMS_OUTPUT.put_line(g_obj_names(i));
				g_prev := g_obj_names(i);
			END IF;
			DBMS_OUTPUT.put_line('  ' || g_prc_names(i));
		END LOOP;
		IF g_cnt > 50 THEN
			DBMS_OUTPUT.put_line('...');
			DBMS_OUTPUT.put_line('Too many results');
		END IF;
		--- %end% ---
		RETURN;
	END IF;
		
	IF g_cnt > 1 THEN
		DBMS_OUTPUT.put_line('[' || g_obj_names(1) || '.' || g_prc_names(1) || ']' );
		FOR i IN 1..g_subprog_ids.COUNT LOOP
			get_proc_args_list (g_obj_names(1),  g_prc_names(1), g_subprog_ids(i));
			DBMS_OUTPUT.put_line('---- N.' || g_subprog_ids(i) || ' -- Len=' || g_arg_names.COUNT);
			FOR i IN 1..g_arg_names.COUNT LOOP
				DBMS_OUTPUT.put_line(
					RPAD(NVL(g_arg_names(i), 'r_val'), 30) || 
					RPAD(g_arg_types(i), 40) || ' ' || g_arg_io_flags(i));					
			END LOOP;
		END LOOP;
		--- %end% ---
		RETURN;
	END IF;

	get_proc_args_list (g_obj_names(1), g_prc_names(1), g_subprog_ids(1));
	
	---------------------
	-- Code Generation --
	---------------------
	
	-- Parameters and Max width
	FOR i IN 1..g_arg_names.COUNT LOOP
		IF g_arg_names(i) IS NULL THEN	-- Function: 1st in sequence order
			g_params(i) := 'r_val'; 
			g_max := 5;
		ELSIF g_arg_io_flags(i) = 'IN' THEN
			g_params(i) := LOWER(g_arg_names(i)); 			
		ELSE
			IF SUBSTR(g_arg_names(i), 1, 2) = 'P_' THEN
				g_params(i) := 'o_' || LOWER(SUBSTR(g_arg_names(i), 3));
			ELSE
				g_params(i) := 'o_' || LOWER(g_arg_names(i));
			END IF;
			IF LENGTH(g_params(i)) > g_max THEN
				g_max := LENGTH(g_params(i));
			END IF;		
		END IF;
	END LOOP;
		
	DBMS_OUTPUT.put_line( chr(10) ||
		'set serveroutput on FORMAT WRAPPED' || chr(10) ||
		'set feedback off' || chr(10) ||
		'set verify off' || chr(10) || chr(10) ||
		'DECLARE');
	FOR i IN 1..g_params.COUNT LOOP
		IF g_arg_io_flags(i) = 'OUT' OR g_arg_io_flags(i) = 'IN/OUT' THEN
			DBMS_OUTPUT.put_line('  ' || RPAD(g_params(i), g_max) || '  ' || g_arg_types(i) || ';');
			IF g_lead = '?' AND SUBSTR(g_arg_types(i), 1, 3) = 'TAB' THEN
				g_lead := g_params(i);
			END IF;
		END IF;
	END LOOP;
	
	DBMS_OUTPUT.put_line('BEGIN');
	FOR i IN 1..g_params.COUNT LOOP
		IF g_arg_io_flags(i) = 'IN/OUT' THEN
			DBMS_OUTPUT.put_line('  ' || g_params(i) || ' := ''TODO'';');
		END IF;
	END LOOP;
		
	DBMS_OUTPUT.put_line('  ' || g_obj_names(1) || '.' || g_prc_names(1) || '(');
	FOR i IN 1..g_arg_names.COUNT LOOP
		g_pfx := CASE i WHEN 1 THEN '  ' ELSE ', ' END;  
		IF g_arg_io_flags(i) = 'IN' THEN
			DBMS_OUTPUT.put_line('  ' || g_pfx || '''TODO'' -- ' || g_params(i));
		ELSE
			DBMS_OUTPUT.put_line('  ' || g_pfx || g_params(i));
		END IF;
	END LOOP;
	DBMS_OUTPUT.put_line('  );');
	
	FOR i IN 1..g_params.COUNT LOOP
		IF (g_arg_io_flags(i) = 'OUT' OR g_arg_io_flags(i) = 'IN/OUT') AND SUBSTR(g_arg_types(i), 1, 3) <> 'TAB' THEN
			DBMS_OUTPUT.put_line('  DBMS_OUTPUT.put_line(''' || g_params(i) || ': '' || ' || g_params(i) || ');');
		END IF;
	END LOOP;

	IF g_lead <> '?' THEN
		DBMS_OUTPUT.put_line('  FOR i IN 1..' || g_lead || '.COUNT LOOP');
		DBMS_OUTPUT.put_line('    DBMS_OUTPUT.put_line(''#'' || i);');
		FOR i IN 1..g_params.COUNT LOOP
			IF (g_arg_io_flags(i) = 'OUT' OR g_arg_io_flags(i) = 'IN/OUT') AND SUBSTR(g_arg_types(i), 1, 3) = 'TAB' THEN
				DBMS_OUTPUT.put_line('    DBMS_OUTPUT.put_line(''' || g_params(i) || ': '' || ' || g_params(i) || '(i));');
			END IF;
		END LOOP;
		DBMS_OUTPUT.put_line('  END LOOP;');
	END IF;
	
	DBMS_OUTPUT.put_line('EXCEPTION');
	DBMS_OUTPUT.put_line('  WHEN OTHERS THEN');
	DBMS_OUTPUT.put_line('    DBMS_OUTPUT.put_line(SQLERRM);');
	DBMS_OUTPUT.put_line('END;');
	DBMS_OUTPUT.put_line('/');
	DBMS_OUTPUT.put_line('exit');

EXCEPTION
    WHEN l_exception_20001 THEN    
        DBMS_OUTPUT.put_line ('[E.App] ' || SQLERRM);
    WHEN OTHERS THEN    
        DBMS_OUTPUT.put_line (SQLERRM);
END;
/

exit
