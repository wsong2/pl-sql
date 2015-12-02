-- l_raw := UTL_RAW.CONVERT(UTL_RAW.CAST_TO_RAW(p_string), 'American_America.AL32UTF8', 'American_America.AL16UTF16');

-- rawbuf position(5:25) raw
-- update txttst set textn = utl_i18n.raw_to_nchar(rawbuf, 'utf8');
-- update txttst set text1 = utl_i18n.raw_to_char(rawbuf);

--dbms_pipe.pack_message	(p_message);
--l_result := dbms_pipe.send_message ( l_pipe_id ); -- 'pipe_id'

declare
  l_message       varchar2(300);
  l_result        pls_integer;
begin
  l_result := dbms_pipe.receive_message('pipd_id');
  dbms_pipe.unpack_message(l_message);
  dbms_output.put_line(l_message);
end;
/
