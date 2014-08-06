DO LANGUAGE plpgsql $proc$
BEGIN
execute format($$alter database %I 
        set search_path to '$user',
        'public','pgtap'
        $$, current_database()
);
END
$proc$;

\echo "Check database config settings"

select datname as db ,setconfig as config 
from pg_database db 
join pg_db_role_setting s on db.oid = s.setdatabase  
where datname = current_database();

