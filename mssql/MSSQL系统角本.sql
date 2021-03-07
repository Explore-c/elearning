SET STATISTICS IO ON
SET STATISTICS TIME ON
SET SHOWPLAN_ALL ON

dbo.SP_LOCKINFO 0,1
dbo.SP_LOCKINFO 1,1

--�鿴SQLִ��ʱ��
SET STATISTICS PROFILE ON
SET STATISTICS IO ON
SET STATISTICS TIME ON
GO
select * from TC_ExamPaperResultDetail where ResultID>1220 and ResultID<10000
GO
SET STATISTICS PROFILE OFF
SET STATISTICS IO OFF
SET STATISTICS TIME OFF

select name from master.dbo.sysdatabases
SELECT table_name FROM information_schema.tables
select name from dbo.sysobjects where xtype='U'

-- ��EMAIL
msdb.dbo.sp_send_dbmail
	@recipients='cexo255@163.com',
	@body=N'���ǲ����ʼ�',
	@subject=N'���ǲ����ʼ�����',
	@body_format='HTML'

-- CPU��ʹ��״��
select top 50 total_worker_time/1000 as [�ܺ�CPUʱ��(MS)],
	execution_count [ִ�д���],
	qs.total_worker_time/qs.execution_count/1000 as [ƽ����CPUʱ��(MS)],
	SUBSTRING(
		qt.text,
		qs.statement_start_offset/2+1, (
			case when qs.statement_end_offset=-1 then datalength(qt.text)
			else qs.statement_end_offset end - qs.statement_start_offset
		)/2 + 1
	) as [ʹ��CPU�﷨],
	qt.text [�����﷨],
	qt.dbid, dbname = DB_NAME(qt.dbid),
	qt.objectid, OBJECT_NAME(qt.objectid, qt.dbid) ObjectName
from sys.dm_exec_query_stats qs cross apply sys.dm_exec_sql_text(qs.sql_handle) as qt
where DB_NAME(qt.dbid) is not null and DB_NAME(qt.dbid)!=N'msdb'
order by total_worker_time/execution_count desc

-- ��ʾ�����뱻���������״��ϵ
select t1.resource_type as [��Դ��������],
	DB_NAME(resource_database_id) as [���ݿ���],
	t1.resource_associated_entity_id as [�����Ķ���],
	t1.request_mode as [�ȴ����������������],
	t1.request_session_id as [�ȴ���SID],
	t2.wait_duration_ms as [�ȴ�ʱ��],(
		select text
		from sys.dm_exec_requests as r cross apply sys.dm_exec_sql_text(r.sql_handle)
		where r.session_id=t1.request_session_id
	) as [�ȴ���Ҫִ�е�������],(
		select SUBSTRING(qt.text, r.statement_start_offset/2+1, (
			case when r.statement_end_offset=-1 then DATALENGTH(qt.text)
			else r.statement_end_offset end - r.statement_start_offset
		)/2+1)
		from sys.dm_exec_requests as r cross apply sys.dm_exec_sql_text(r.sql_handle) as qt
		where r.session_id=t1.request_session_id
	) as [�ȴ�����Ҫִ�е��﷨]
from sys.dm_tran_locks as t1, sys.dm_os_waiting_tasks as t2
where t1.lock_owner_address=t2.resource_address

-- �۲�Ӳ��I/O
select DB_NAME(i.database_id) db,
	name,
	physical_name,
	io_stall [�û��ȴ��ļ����I/O����ʱ��(MS)],
	io_type [I/OҪ�������],
	io_pending_ms_ticks [����I/O�ڶ���(Pending queue)�ȴ�����ʱ��]
from sys.dm_io_virtual_file_stats(null, null) i
join sys.dm_io_pending_io_requests as p on i.file_handle=p.io_handle
join sys.master_files m on m.database_id=i.database_id and m.file_id=i.file_id

-- ��ѯ������I/O��Դ��SQL�﷨
select total_logical_reads/execution_count as [ƽ���߼���ȡ����],
	total_logical_writes/execution_count as [ƽ���߼�д�����],
	total_physical_reads/execution_count as [ƽ�������ȡ����],
	execution_count as [ִ�д���],
	SUBSTRING(qt.text, r.statement_start_offset/2 + 1, (
		case when r.statement_end_offset = -1 then DATALENGTH(qt.text)
		else r.statement_end_offset end - r.statement_start_offset
	)/2 + 1) as [ִ���﷨]
from sys.dm_exec_query_stats as r cross apply sys.dm_exec_sql_text(r.sql_handle) as qt
order by (total_logical_reads+total_logical_writes) desc

--SQL���ִ��ʱ��
SELECT
      total_cpu_time,
      total_execution_count,
      number_of_statements,
      s2.text
      --(SELECT SUBSTRING(s2.text, statement_start_offset / 2, ((CASE WHEN statement_end_offset = -1 THEN (LEN(CONVERT(NVARCHAR(MAX), s2.text)) * 2) ELSE statement_end_offset END) - statement_start_offset) / 2) ) AS query_text
FROM
      (SELECT TOP 100
            SUM(qs.total_worker_time) AS total_cpu_time,
            SUM(qs.execution_count) AS total_execution_count,
            COUNT(*) AS  number_of_statements,
            qs.sql_handle --,
            --MIN(statement_start_offset) AS statement_start_offset,
            --MAX(statement_end_offset) AS statement_end_offset
      FROM
            sys.dm_exec_query_stats AS qs
      GROUP BY qs.sql_handle
      ORDER BY SUM(qs.total_worker_time) DESC) AS stats
      CROSS APPLY sys.dm_exec_sql_text(stats.sql_handle) AS s2

--CPU ƽ��ռ������ߵ�ǰ 50 �� SQL ��䡣
SELECT TOP 50
total_worker_time/execution_count AS [Avg CPU Time],
(SELECT SUBSTRING(text,statement_start_offset/2,(CASE WHEN statement_end_offset = -1 then LEN(CONVERT(nvarchar(max), text)) * 2 ELSE statement_end_offset end -statement_start_offset)/2) FROM sys.dm_exec_sql_text(sql_handle)) AS query_text, *
FROM sys.dm_exec_query_stats
ORDER BY [Avg CPU Time] DESC

--���ܴ���û�������ı�
SELECT name FROM sys.tables
EXCEPT
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE CONSTRAINT_TYPE = 'PRIMARY KEY'

--���ܴ�������յ��ֶ�
select TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, COLUMN_DEFAULT
from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME in (select name from sysobjects where type = 'U')
and IS_NULLABLE='YES'

--��Ƭ
SELECT  DB_NAME(ps.database_id) AS '���ݿ���', OBJECT_NAME(ps.OBJECT_ID) AS '����',
        b.name as '������', ps.index_id as '����ID', fill_factor as '�������',
        ps.avg_fragmentation_in_percent as '��Ƭ��'
FROM    sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) AS ps
        INNER JOIN sys.indexes AS b ON ps.OBJECT_ID = b.OBJECT_ID AND ps.index_id = b.index_id
--WHERE   ps.database_id = DB_ID('Traingo.LMS_test')
ORDER BY ps.avg_fragmentation_in_percent DESC
-- >30�ؽ�����
SELECT  'alter index all on ' + OBJECT_NAME(ps.OBJECT_ID) + ' rebuild;', ps.avg_fragmentation_in_percent
FROM    sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) AS ps
        INNER JOIN sys.indexes AS b ON ps.OBJECT_ID = b.OBJECT_ID AND ps.index_id = b.index_id
WHERE   ps.avg_fragmentation_in_percent > 30
ORDER BY ps.avg_fragmentation_in_percent DESC

create procedure [dbo].[clearDBFragmentation](@dbname varchar(100)) as
begin
  declare @@execSql nvarchar(max), @@execSql2 nvarchar(max)

  set @@execSql = '
    use [' + @dbname + '];
    select table_schema + ''.'' + object_name(ps.object_id) ����, round(ps.avg_fragmentation_in_percent, 0) ��Ƭ��, b.name as ������
    from sys.dm_db_index_physical_stats(db_id(), null, null, null, null) as ps 
    inner join sys.indexes as b on ps.OBJECT_ID = b.OBJECT_ID and ps.index_id = b.index_id 
    inner join information_schema.tables as c on c.table_name=object_name(ps.object_id)
    where ps.avg_fragmentation_in_percent > 50
    order by ps.avg_fragmentation_in_percent desc'
  exec(@@execSql);

  set @@execSql = '
    use [' + @dbname + '];
    (select @execSql2=stuff((
      select distinct ''alter index all on '' + table_schema + ''.'' + object_name(ps.object_id) + '' rebuild;'' 
      from sys.dm_db_index_physical_stats(db_id(), null, null, null, null) as ps 
      inner join sys.indexes as b on ps.OBJECT_ID = b.OBJECT_ID and ps.index_id = b.index_id 
      inner join information_schema.tables as c on c.table_name=object_name(ps.object_id)
      where ps.avg_fragmentation_in_percent > 50
    FOR xml path('''')) , 1 , 0 , ''''))'
  exec sp_executesql @@execSql, N'@execSql2 nvarchar(max) out', @@execSql2 out
  if @@execSql2 is not null begin
    set @@execSql = 'use [' + @dbname + '];' + @@execSql2
    exec(@@execSql);
    print @dbname + '=>' + ltrim(str(@@error)) + '=>' + @@execSql
  end
end
create procedure [dbo].[clearAllDBFragmentation] as
begin
  declare @@dbname varchar(200)
  declare @@dbs int, @@i int
  if object_id(N'tempdb..#all_databases',N'U') is null begin
    create table #all_databases([id] [INT] identity(1,1) not null, [dbname] varchar(255) not null);
  end

  truncate table #all_databases
  insert into #all_databases(dbname)
  select name from master.dbo.sysdatabases where name not in ('master', 'model', 'msdb', 'tempdb')

  set @@dbs = (select max(id) from #all_databases)
  set @@i=1
  while @@i<=@@dbs
  begin
    set @@dbname = (select dbname from #all_databases where id=@@i)
    print @@dbname
    exec clearDBFragmentation @@dbname
    set @@i=@@i+1
  end
end
exec clearAllDBFragmentation


--�ؽ�����
--avg_fragmentation_in_percent >5% and <=30%�� ����������ALTER INDEX REORGANIZE����
ALTER INDEX ALL ON Employee REORGANIZE
--avg_fragmentation_in_percent >30%�� �ؽ�������ALTER INDEX REBUILD����
ALTER INDEX ALL ON Employee REBUILD
-- partition=all with (FILLFACTOR = 80, ONLINE = OFF, DATA_COMPRESSION = PAGE )
-- WITH (FILLFACTOR = 60, SORT_IN_TEMPDB = ON,STATISTICS_NORECOMPUTE = ON);
dbcc showconfig('LMS_RewardIntegralLog')
dbcc dbreindex('LMS_RewardIntegralLog', '', 80)
dbcc indexdefrag('LMS_RewardIntegralLog', '', 80)
dbcc cleantable('LMS_RewardIntegralLog', '')

--ȱʧ����
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT TOP 20
  ROUND(s.avg_total_user_cost * s.avg_user_impact * (s.user_seeks + s.user_scans),0) AS [Total Cost]
  , d.[statement] AS [Table Name]
  , equality_columns
  , inequality_columns
  , included_columns
FROM sys.dm_db_missing_index_groups g INNER JOIN sys.dm_db_missing_index_group_stats s ON s.group_handle = g.index_group_handle
  INNER JOIN sys.dm_db_missing_index_details d ON d.index_handle = g.index_handle
ORDER BY [Total Cost] DESC

--û���õ�����
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT
  DB_NAME() AS DatabaseName
  , SCHEMA_NAME(o.Schema_ID) AS SchemaName
  , OBJECT_NAME(s.[object_id]) AS TableName
  , i.name AS IndexName
  , s.user_updates
  , s.system_seeks + s.system_scans + s.system_lookups AS [System usage]
  INTO #TempUnusedIndexes
FROM sys.dm_db_index_usage_stats s INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
  INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE 1=2

--���¼����
SELECT A.NAME ,B.ROWS FROM sysobjects A JOIN sysindexes B ON A.id = B.id WHERE A.xtype = 'U' AND B.indid IN(0,1) ORDER BY B.ROWS DESC
--���¼����2
create table #tb(���� sysname,��¼�� int ,�����ռ� varchar(10),ʹ�ÿռ� varchar(10),����ʹ�ÿռ� varchar(10),δ�ÿռ� varchar(10))
truncate table #tb
insert into #tb exec sp_MSForEachTable 'EXEC sp_spaceused ''?'''
select * from #tb order by ��¼�� desc
select * from #tb order by cast(replace(ʹ�ÿռ�,'KB','') as int) desc


--�鿴���ݿ��С
Exec master.dbo.xp_fixeddrives -- ʣ��ռ�
Exec sp_spaceused
dbcc sqlperf(logspace) with no_infomsgs
select name, convert(float,size) * (8192.0/1024.0)/1024. from dbo.sysfiles
insert into dbo.DbLogSize execute('dbcc sqlperf(logspace) with no_infomsgs')

SELECT DB_NAME(database_id) AS DatabaseName, Name AS Logical_Name, (size*8)/1024 SizeMB, Physical_Name
FROM sys.master_files where DB_NAME(database_id) not in ('master', 'model', 'msdb', 'tempdb')
  and right(Physical_Name, 4)='.ldf'
order by SizeMB desc

����LOG
create procedure [dbo].[clearDBLog](@dbname varchar(100)) as
begin
  declare @@execSql varchar(max)
  set @@execSql = '
    select db_name(database_id) ���ݿ�, Name �߼��ļ�, (size*8)/1024 ��СM, Physical_Name �����ļ�
    from sys.master_files where DB_NAME(database_id) = ''' + @dbname + ''''
  exec(@@execSql)
  set @@execSql = '
    alter database [' + @dbname + '] set recovery simple with no_wait;
    alter database [' + @dbname + '] set recovery simple;
    dbcc shrinkdatabase([' + @dbname + '], 1, truncateonly);
    alter database [' + @dbname + '] set recovery full with no_wait;
    alter database [' + @dbname + '] set recovery full;'
  exec(@@execSql)
  print @dbname + '=>' + ltrim(str(@@error))
  if @@error<>0 begin
    set @@execSql = '
      alter database [' + @dbname + '] set recovery full with no_wait;
      alter database [' + @dbname + '] set recovery full;'
    exec(@@execSql)
  end
end
exec clearDBLog 'Traingo.LY_test'
create procedure [dbo].[clearAllDBLog] as
begin
  declare @@dbname varchar(200)
  declare @@dbs int, @@i int
  if object_id(N'tempdb..#all_databases',N'U') is null begin
    create table #all_databases([id] [INT] identity(1,1) not null, [dbname] varchar(255) not null);
  end

  truncate table #all_databases
  insert into #all_databases(dbname)
  select distinct DB_NAME(database_id)
  from sys.master_files where DB_NAME(database_id) not in ('master', 'model', 'msdb', 'tempdb')
  and right(Physical_Name, 4)='.ldf' and size>1024*1024/8

  set @@dbs = (select max(id) from #all_databases)
  set @@i=1
  while @@i<=@@dbs
  begin
    set @@dbname = (select dbname from #all_databases where id=@@i)
    --select @@dbname
    exec clearDBLog @@dbname
    set @@i=@@i+1
  end
end
exec clearAllDBLog

--��ʾ�����ҳ��������/���±���� DMV ��ѯ��
select * from sys.dm_exec_query_optimizer_info
where
      counter = 'optimizations'
      or counter = 'elapsed time'

--��ʾ�����±����ǰ 25 ���洢���̡�plan_generation_num ָʾ�ò�ѯ�����±���Ĵ�����
select top 25
      sql_text.text,
      sql_handle,
      plan_generation_num,
      execution_count,
      dbid,
      objectid
from sys.dm_exec_query_stats a
      cross apply sys.dm_exec_sql_text(sql_handle) as sql_text
where plan_generation_num > 1
order by plan_generation_num desc

--��ʾ�ĸ���ѯռ�������� CPU �ۼ�ʹ���ʡ�
SELECT
    highest_cpu_queries.plan_handle,
    highest_cpu_queries.total_worker_time,
    q.dbid,
    q.objectid,
    q.number,
    q.encrypted,
    q.[text]
from
    (select top 50
        qs.plan_handle,
        qs.total_worker_time
    from
        sys.dm_exec_query_stats qs
    order by qs.total_worker_time desc) as highest_cpu_queries
    cross apply sys.dm_exec_sql_text(plan_handle) as q
order by highest_cpu_queries.total_worker_time desc

--��ʾһЩ����ռ�ô��� CPU ʹ���ʵ������������ ��%Hash Match%������%Sort%�������ҳ����ɶ���
select *
from
      sys.dm_exec_cached_plans
      cross apply sys.dm_exec_query_plan(plan_handle)
where
      cast(query_plan as nvarchar(max)) like '%Sort%'
      or cast(query_plan as nvarchar(max)) like '%Hash Match%'


�ڴ�ƿ��
��ʼ�ڴ�ѹ�����͵���֮ǰ����ȷ�������� SQL Server �еĸ߼�ѡ����ȶ� master ���ݿ��������²�ѯ�����ô�ѡ�
sp_configure 'show advanced options'
go
sp_configure 'show advanced options', 1
go
reconfigure
go
�����������²�ѯ�Լ���ڴ��������ѡ�
sp_configure 'awe_enabled'
go
sp_configure 'min server memory'
go
sp_configure 'max server memory'
go
sp_configure 'min memory per query'
go
sp_configure 'query wait'
go
��������� DMV ��ѯ�Բ鿴 CPU���ƻ������ڴ�ͻ������Ϣ��
select
	cpu_count,
	hyperthread_ratio,
	scheduler_count,
	physical_memory_in_bytes / 1024 / 1024 as physical_memory_mb,
	virtual_memory_in_bytes / 1024 / 1024 as virtual_memory_mb,
	bpool_committed * 8 / 1024 as bpool_committed_mb,
	bpool_commit_target * 8 / 1024 as bpool_target_mb,
	bpool_visible * 8 / 1024 as bpool_visible_mb
from sys.dm_os_sys_info

I/O ƿ��
��������ȴ�ͳ����Ϣ��ȷ�� I/O ƿ������������� DMV ��ѯ�Բ��� I/O �����ȴ�ͳ����Ϣ��
select wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms, wait_time_ms / waiting_tasks_count
from sys.dm_os_wait_stats
where wait_type like 'PAGEIOLATCH%'  and waiting_tasks_count > 0
order by wait_type

��� waiting_task_counts �� wait_time_ms �������������������仯�������ȷ������ I/O ���⡣��ȡ SQL Server ƽ������ʱ���ܼ���������Ҫ DMV ��ѯ����Ļ��߷ǳ���Ҫ��
��Щ wait_types ����ָʾ���� I/O ��ϵͳ�Ƿ�����ƿ����
ʹ������ DMV ��ѯ�����ҵ�ǰ����� I/O �����붨��ִ�д˲�ѯ�Լ�� I/O ��ϵͳ������״���������� I/O ƿ�����漰��������̡�
select
	database_id,
	file_id,
	io_stall,
	io_pending_ms_ticks,
	scheduler_address
from  sys.dm_io_virtual_file_stats(NULL, NULL)t1,
	sys.dm_io_pending_io_requests as t2
where t1.file_handle = t2.io_handle

����������£��ò�ѯͨ���������κ����ݡ�����˲�ѯ����һЩ�У�����Ҫ��һ�����顣
��������ִ������� DMV ��ѯ�Բ��� I/O ��ز�ѯ��
select top 5 (total_logical_reads/execution_count) as avg_logical_reads,
	(total_logical_writes/execution_count) as avg_logical_writes,
	(total_physical_reads/execution_count) as avg_physical_reads,
	Execution_count, statement_start_offset, p.query_plan, q.text
from sys.dm_exec_query_stats
	cross apply sys.dm_exec_query_plan(plan_handle) p
	cross apply sys.dm_exec_sql_text(plan_handle) as q
order by (total_logical_reads + total_logical_writes)/execution_count Desc

����� DMV ��ѯ�����ڲ�����Щ������/�������ɵ� I/O ��ࡣ������ʾ�� DMV ��ѯ�����ڲ��ҿ�������� I/O ��ǰ������󡣵�����Щ��ѯ�����ϵͳ���ܡ�
select top 5
    (total_logical_reads/execution_count) as avg_logical_reads,
    (total_logical_writes/execution_count) as avg_logical_writes,
    (total_physical_reads/execution_count) as avg_phys_reads,
     Execution_count,
    statement_start_offset as stmt_start_offset,
    sql_handle,
    plan_handle
from sys.dm_exec_query_stats
order by  (total_logical_reads + total_logical_writes) Desc
����
��������Ĳ�ѯ��ȷ�������ĻỰ��
select blocking_session_id, wait_duration_ms, session_id
from sys.dm_os_waiting_tasks
where blocking_session_id is not null
ʹ�ô˵��ÿ��ҳ� blocking_session_id �����ص� SQL�����磬��� blocking_session_id �� 87�������д˲�ѯ�ɻ����Ӧ�� SQL��
dbcc INPUTBUFFER(87)
����Ĳ�ѯ��ʾ SQL �ȴ�������ǰ 10 ���ȴ�����Դ��
select top 10 *
from sys.dm_os_wait_stats
--where wait_type not in ('CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK','SLEEP_SYSTEMTASK','WAITFOR')
order by wait_time_ms desc
��Ҫ�ҳ��ĸ� spid ����������һ�� spid���������ݿ��д������´洢���̣�Ȼ��ִ�иô洢���̡��˴洢���̻ᱨ���������������� sp_who ���ҳ� @spid��@spid �ǿ�ѡ������
create proc dbo.sp_block (@spid bigint=NULL)
as
select
    t1.resource_type,
    'database'=db_name(resource_database_id),
    'blk object' = t1.resource_associated_entity_id,
    t1.request_mode,
    t1.request_session_id,
    t2.blocking_session_id
from
    sys.dm_tran_locks as t1,
    sys.dm_os_waiting_tasks as t2
where
    t1.lock_owner_address = t2.resource_address and
    t1.request_session_id = isnull(@spid,t1.request_session_id)
������ʹ�ô˴洢���̵�ʾ����
exec sp_block
exec sp_block @spid = 7

--�鿴������������������
CREATE PROC [dbo].[SP_LOCKINFO](
@KILL_LOCK_SPID BIT = 1,                --�Ƿ�ɱ�������Ľ���,1 ɱ��, 0 ����ʾ
@SHOW_SPID_IF_NOLOCK BIT = 1
) AS           --���û�������Ľ���,�Ƿ���ʾ����������Ϣ,1 ��ʾ,0 ����ʾ

SET NOCOUNT ON
DECLARE @COUNT     INT,
        @S         NVARCHAR(1000),
        @I         INT

SELECT ID=IDENTITY(INT,1,1),
       ��־,
       ����ID=SPID,
       �߳�ID=KPID,
       �����ID=BLOCKED,
       ���ݿ�ID=DBID,
       ���ݿ���=DB_NAME(DBID),
       �û�ID=UID,
       �û���=LOGINAME,
       �ۼ�CPUʱ��=CPU,
       ��½ʱ��=LOGIN_TIME,��������=OPEN_TRAN,
       ����״̬=STATUS,
       ����վ��=HOSTNAME,
       Ӧ�ó�����=PROGRAM_NAME,
       ����վ����ID=HOSTPROCESS,
       ����=NT_DOMAIN,
       ������ַ=NET_ADDRESS

INTO #T FROM(
        SELECT ��־='�����Ľ���',
                SPID,KPID,A.BLOCKED,DBID,UID,LOGINAME,CPU,LOGIN_TIME,OPEN_TRAN,
                STATUS,HOSTNAME,PROGRAM_NAME,HOSTPROCESS,NT_DOMAIN,NET_ADDRESS,
                S1=A.SPID,S2=0
                FROM MASTER..SYSPROCESSES A JOIN (
                SELECT BLOCKED FROM MASTER..SYSPROCESSES GROUP BY BLOCKED
                )B ON A.SPID=B.BLOCKED WHERE A.BLOCKED=0
        UNION ALL
        SELECT '|_����Ʒ_>',
                SPID,KPID,BLOCKED,DBID,UID,LOGINAME,CPU,LOGIN_TIME,OPEN_TRAN,
                STATUS,HOSTNAME,PROGRAM_NAME,HOSTPROCESS,NT_DOMAIN,NET_ADDRESS,
                S1=BLOCKED,S2=1
        FROM MASTER..SYSPROCESSES A WHERE BLOCKED<>0
)A ORDER BY S1,S2

SELECT @COUNT=@@ROWCOUNT,@I=1

IF @COUNT=0 AND @SHOW_SPID_IF_NOLOCK=1
BEGIN
        INSERT #T
        SELECT ��־='�����Ľ���',
                SPID,KPID,BLOCKED,DBID,DB_NAME(DBID),UID,LOGINAME,CPU,LOGIN_TIME,
                OPEN_TRAN,STATUS,HOSTNAME,PROGRAM_NAME,HOSTPROCESS,NT_DOMAIN,NET_ADDRESS
        FROM MASTER..SYSPROCESSES
        SET @COUNT=@@ROWCOUNT
END

IF @COUNT>0
BEGIN
        CREATE TABLE #T1(ID INT IDENTITY(1,1),A NVARCHAR(30),B INT,EVENTINFO NVARCHAR(4000))
        IF @KILL_LOCK_SPID=1
              BEGIN
                     DECLARE @SPID VARCHAR(10),@��־ VARCHAR(10)
                     WHILE @I<=@COUNT
                     BEGIN
                            SELECT @SPID=����ID,@��־=��־ FROM #T WHERE ID=@I
                            INSERT #T1 EXEC('DBCC INPUTBUFFER('+@SPID+')')
                            IF @@ROWCOUNT=0 INSERT #T1(A) VALUES(NULL)
                            IF @��־='�����Ľ���' EXEC('KILL '+@SPID)
                            SET @I=@I+1
                     END
              END
        ELSE
                WHILE @I<=@COUNT
                BEGIN
                        SELECT @S='DBCC INPUTBUFFER('+CAST(����ID AS VARCHAR)+')' FROM #T WHERE ID=@I
                        INSERT #T1 EXEC(@S)
                        IF @@ROWCOUNT=0 INSERT #T1(A) VALUES(NULL)
                        SET @I=@I+1
                END
        SELECT ���̵�SQL���=B.EVENTINFO,A.*
        FROM #T A JOIN #T1 B ON A.ID=B.ID
        where ����״̬<>'sleeping' and B.EVENTINFO is not null
        ORDER BY ���̵�SQL��� desc
END


EXEC sp_MSForEachDB 'USE [?];
INSERT INTO #TempUnusedIndexes
SELECT TOP 20
	DB_NAME() AS DatabaseName
	, SCHEMA_NAME(o.Schema_ID) AS SchemaName
	, OBJECT_NAME(s.[object_id]) AS TableName
	, i.name AS IndexName
	, s.user_updates
	, s.system_seeks + s.system_scans + s.system_lookups AS [System usage]
FROM sys.dm_db_index_usage_stats s INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
	INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE s.database_id = DB_ID()
	AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0
	AND s.user_seeks = 0 AND s.user_scans = 0 AND s.user_lookups = 0 AND i.name IS NOT NULL
ORDER BY s.user_updates DESC'
SELECT TOP 20 * FROM #TempUnusedIndexes ORDER BY [user_updates] DESC
DROP TABLE #TempUnusedIndexes


�鿴���ӵ�ǰ���ݿ��SPID���ӵ���
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT DB_NAME(resource_database_id) AS DatabaseName
	, request_session_id
	, resource_type
	, CASE WHEN resource_type = 'OBJECT' THEN OBJECT_NAME(resource_associated_entity_id)
		WHEN resource_type IN ('KEY', 'PAGE', 'RID') THEN (
			SELECT OBJECT_NAME(OBJECT_ID)
			FROM sys.partitions p
			WHERE p.hobt_id = l.resource_associated_entity_id)
		END AS resource_type_name
	, request_status
	, request_mode
FROM sys.dm_tran_locks l
WHERE request_session_id !=@@spid
ORDER BY request_session_id
�����鿴�������������where��������

�鿴û�ر�����Ŀ���Session
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT es.session_id, es.login_name, es.host_name, est.text
  , cn.last_read, cn.last_write, es.program_name
FROM sys.dm_exec_sessions es
INNER JOIN sys.dm_tran_session_transactions st ON es.session_id = st.session_id
INNER JOIN sys.dm_exec_connections cn ON es.session_id = cn.session_id
CROSS APPLY sys.dm_exec_sql_text(cn.most_recent_sql_handle) est
LEFT OUTER JOIN sys.dm_exec_requests er ON st.session_id = er.session_id AND er.session_id IS NULL

�鿴���������������ǵĵȴ�ʱ��
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT
  Waits.wait_duration_ms / 1000 AS WaitInSeconds
  , Blocking.session_id as BlockingSessionId
  , DB_NAME(Blocked.database_id) AS DatabaseName
  , Sess.login_name AS BlockingUser
  , Sess.host_name AS BlockingLocation
  , BlockingSQL.text AS BlockingSQL
  , Blocked.session_id AS BlockedSessionId
  , BlockedSess.login_name AS BlockedUser
  , BlockedSess.host_name AS BlockedLocation
  , BlockedSQL.text AS BlockedSQL
  , SUBSTRING (BlockedSQL.text, (BlockedReq.statement_start_offset/2) + 1,
    ((CASE WHEN BlockedReq.statement_end_offset = -1
      THEN LEN(CONVERT(NVARCHAR(MAX), BlockedSQL.text)) * 2
      ELSE BlockedReq.statement_end_offset
      END - BlockedReq.statement_start_offset)/2) + 1)
                    AS [Blocked Individual Query]
  , Waits.wait_type
FROM sys.dm_exec_connections AS Blocking
INNER JOIN sys.dm_exec_requests AS Blocked ON Blocking.session_id = Blocked.blocking_session_id
INNER JOIN sys.dm_exec_sessions Sess ON Blocking.session_id = sess.session_id
INNER JOIN sys.dm_tran_session_transactions st ON Blocking.session_id = st.session_id
LEFT OUTER JOIN sys.dm_exec_requests er ON st.session_id = er.session_id AND er.session_id IS NULL
INNER JOIN sys.dm_os_waiting_tasks AS Waits ON Blocked.session_id = Waits.session_id
CROSS APPLY sys.dm_exec_sql_text(Blocking.most_recent_sql_handle) AS BlockingSQL
INNER JOIN sys.dm_exec_requests AS BlockedReq ON Waits.session_id = BlockedReq.session_id
INNER JOIN sys.dm_exec_sessions AS BlockedSess ON Waits.session_id = BlockedSess.session_id
CROSS APPLY sys.dm_exec_sql_text(Blocked.sql_handle) AS BlockedSQL
ORDER BY WaitInSeconds

�鿴����30��ȴ��Ĳ�ѯ
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT
	Waits.wait_duration_ms / 1000 AS WaitInSeconds
	, Blocking.session_id as BlockingSessionId
	, Sess.login_name AS BlockingUser
	, Sess.host_name AS BlockingLocation
	, BlockingSQL.text AS BlockingSQL
	, Blocked.session_id AS BlockedSessionId
	, BlockedSess.login_name AS BlockedUser
	, BlockedSess.host_name AS BlockedLocation
	, BlockedSQL.text AS BlockedSQL
	, DB_NAME(Blocked.database_id) AS DatabaseName
FROM sys.dm_exec_connections AS Blocking
INNER JOIN sys.dm_exec_requests AS Blocked ON Blocking.session_id = Blocked.blocking_session_id
INNER JOIN sys.dm_exec_sessions Sess ON Blocking.session_id = sess.session_id
INNER JOIN sys.dm_tran_session_transactions st ON Blocking.session_id = st.session_id
LEFT OUTER JOIN sys.dm_exec_requests er ON st.session_id = er.session_id AND er.session_id IS NULL
INNER JOIN sys.dm_os_waiting_tasks AS Waits ON Blocked.session_id = Waits.session_id
CROSS APPLY sys.dm_exec_sql_text(Blocking.most_recent_sql_handle) AS BlockingSQL
INNER JOIN sys.dm_exec_requests AS BlockedReq ON Waits.session_id = BlockedReq.session_id
INNER JOIN sys.dm_exec_sessions AS BlockedSess ON Waits.session_id = BlockedSess.session_id
CROSS APPLY sys.dm_exec_sql_text(Blocked.sql_handle) AS BlockedSQL
WHERE Waits.wait_duration_ms > 30000
ORDER BY WaitInSeconds

buffer�л���ÿ�����ݿ���ռ��buffer
SET TRAN ISOLATION LEVEL READ UNCOMMITTED
SELECT
    ISNULL(DB_NAME(database_id), 'ResourceDb') AS DatabaseName
    , CAST(COUNT(row_count) * 8.0 / (1024.0) AS DECIMAL(28,2)) AS [Size (MB)]
FROM sys.dm_os_buffer_descriptors
GROUP BY database_id
ORDER BY DatabaseName

��ǰ���ݿ���ÿ������ռ����Ĵ�С��ҳ��
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT
     OBJECT_NAME(p.[object_id]) AS [TableName]
     , (COUNT(*) * 8) / 1024   AS [Buffer size(MB)]
     , ISNULL(i.name, '-- HEAP --') AS ObjectName
     ,  COUNT(*) AS NumberOf8KPages
FROM sys.allocation_units AS a
INNER JOIN sys.dm_os_buffer_descriptors AS b ON a.allocation_unit_id = b.allocation_unit_id
INNER JOIN sys.partitions AS p
INNER JOIN sys.indexes i ON p.index_id = i.index_id AND p.[object_id] = i.[object_id] ON a.container_id = p.hobt_id
WHERE b.database_id = DB_ID() AND p.[object_id] > 100
GROUP BY p.[object_id], i.name
ORDER BY NumberOf8KPages DESC

���ݿ⼶��ȴ���IO
SET TRAN ISOLATION LEVEL READ UNCOMMITTED
SELECT DB_NAME(database_id) AS [DatabaseName]
	, SUM(CAST(io_stall / 1000.0 AS DECIMAL(20,2))) AS [IO stall (secs)]
	, SUM(CAST(num_of_bytes_read / 1024.0 / 1024.0 AS DECIMAL(20,2))) AS [IO read (MB)]
	, SUM(CAST(num_of_bytes_written / 1024.0 / 1024.0  AS DECIMAL(20,2))) AS [IO written (MB)]
	, SUM(CAST((num_of_bytes_read + num_of_bytes_written) / 1024.0 / 1024.0 AS DECIMAL(20,2))) AS [TotalIO (MB)]
FROM sys.dm_io_virtual_file_stats(NULL, NULL)
GROUP BY database_id
ORDER BY [IO stall (secs)] DESC

���ļ��鿴IO���
SET TRAN ISOLATION LEVEL READ UNCOMMITTED
SELECT DB_NAME(database_id) AS [DatabaseName]
	, file_id
	, SUM(CAST(io_stall / 1000.0 AS DECIMAL(20,2))) AS [IO stall (secs)]
	, SUM(CAST(num_of_bytes_read / 1024.0 / 1024.0 AS DECIMAL(20,2))) AS [IO read (MB)]
	, SUM(CAST(num_of_bytes_written / 1024.0 / 1024.0  AS DECIMAL(20,2))) AS [IO written (MB)]
	, SUM(CAST((num_of_bytes_read + num_of_bytes_written) / 1024.0 / 1024.0 AS DECIMAL(20,2))) AS [TotalIO (MB)]
FROM sys.dm_io_virtual_file_stats(NULL, NULL)
GROUP BY database_id, file_id
ORDER BY [IO stall (secs)] DESC

�鿴������Ĳ�ѯ�ƻ�
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT TOP 20
    st.text AS [SQL]
    , cp.cacheobjtype
    , cp.objtype
    , COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT))+'*', 'Resource') AS [DatabaseName]
    , cp.usecounts AS [Plan usage]
    , qp.query_plan
FROM sys.dm_exec_cached_plans cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
OUTER APPLY sys.dm_exec_plan_attributes(cp.plan_handle) pa
WHERE pa.attribute = 'dbid' AND st.text LIKE '%�����ǲ�ѯ������������%'
���Ը��ݲ�ѯ�ֶ������ݹؼ��ֲ鿴����Ĳ�ѯ�ƻ���

�鿴ĳһ��ѯ�����ʹ�ò�ѯ�ƻ���
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT TOP 20
	SUBSTRING (qt.text,(qs.statement_start_offset/2) + 1,
	((CASE WHEN qs.statement_end_offset = -1
		THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
		ELSE qs.statement_end_offset
	END - qs.statement_start_offset)/2) + 1) AS [Individual Query]
	, qt.text AS [Parent Query]
	, DB_NAME(qt.dbid) AS DatabaseName
	, qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE SUBSTRING (qt.text,(qs.statement_start_offset/2) + 1,
  ((CASE WHEN qs.statement_end_offset = -1
    THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
    ELSE qs.statement_end_offset
    END - qs.statement_start_offset)/2) + 1)
LIKE '%ָ����ѯ�������ֶ�%'

�鿴���ݿ����ܵ�������ǰ20����ѯ�Լ����ǵ�ִ�мƻ�
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT TOP 20
	CAST(qs.total_elapsed_time / 1000000.0 AS DECIMAL(28, 2)) AS [Total Duration (s)]
	, CAST(qs.total_worker_time * 100.0 / qs.total_elapsed_time AS DECIMAL(28, 2)) AS [% CPU]
	, CAST((qs.total_elapsed_time - qs.total_worker_time)* 100.0 / qs.total_elapsed_time AS DECIMAL(28, 2)) AS [% Waiting]
	, qs.execution_count
	, CAST(qs.total_elapsed_time / 1000000.0 / qs.execution_count AS DECIMAL(28, 2)) AS [Average Duration (s)]
	, SUBSTRING (qt.text,(qs.statement_start_offset/2) + 1,
	((CASE WHEN qs.statement_end_offset = -1
	  THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
	  ELSE qs.statement_end_offset
	  END - qs.statement_start_offset)/2) + 1) AS [Individual Query
	, qt.text AS [Parent Query]
	, DB_NAME(qt.dbid) AS DatabaseName
	, qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE qs.total_elapsed_time > 0
ORDER BY qs.total_elapsed_time DESC

�鿴���ݿ����ĸ���ѯ��ķ���Դ��������������

������ʱ�����ǰ20����ѯ�Լ����ǵ�ִ�мƻ�
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT TOP 20
	CAST((qs.total_elapsed_time - qs.total_worker_time) /  1000000.0 AS DECIMAL(28,2)) AS [Total time blocked (s)]
	, CAST(qs.total_worker_time * 100.0 / qs.total_elapsed_time AS DECIMAL(28,2)) AS [% CPU]
	, CAST((qs.total_elapsed_time - qs.total_worker_time)* 100.0 / qs.total_elapsed_time AS DECIMAL(28, 2)) AS [% Waiting]
	, qs.execution_count
	, CAST((qs.total_elapsed_time  - qs.total_worker_time) / 1000000.0  / qs.execution_count AS DECIMAL(28, 2)) AS [Blocking average (s)]
	, SUBSTRING (qt.text,(qs.statement_start_offset/2) + 1,
	((CASE WHEN qs.statement_end_offset = -1
	THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
	ELSE qs.statement_end_offset
	END - qs.statement_start_offset)/2) + 1) AS [Individual Query]
	, qt.text AS [Parent Query]
	, DB_NAME(qt.dbid) AS DatabaseName
	, qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE qs.total_elapsed_time > 0
ORDER BY [Total time blocked (s)] DESC
�ҳ������ѯҲ�����ݿ���ŵı���Ʒ

��ķ�CPU��ǰ20����ѯ�Լ����ǵ�ִ�мƻ�
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT TOP 20
	CAST((qs.total_worker_time) / 1000000.0 AS DECIMAL(28,2)) AS [Total CPU time (s)]
	, CAST(qs.total_worker_time * 100.0 / qs.total_elapsed_time AS DECIMAL(28,2)) AS [% CPU]
	, CAST((qs.total_elapsed_time - qs.total_worker_time)* 100.0 / qs.total_elapsed_time AS DECIMAL(28, 2)) AS [% Waiting]
	, qs.execution_count
	, CAST((qs.total_worker_time) / 1000000.0 / qs.execution_count AS DECIMAL(28, 2)) AS [CPU time average (s)]
	, SUBSTRING (qt.text,(qs.statement_start_offset/2) + 1,
	((CASE WHEN qs.statement_end_offset = -1
	  THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
	  ELSE qs.statement_end_offset
	  END - qs.statement_start_offset)/2) + 1) AS [Individual Query]
	, qt.text AS [Parent Query]
	, DB_NAME(qt.dbid) AS DatabaseName
	, qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE qs.total_elapsed_time > 0
ORDER BY [Total CPU time (s)] DESC


��ռIO��ǰ20����ѯ�Լ����ǵ�ִ�мƻ�
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT TOP 20
	[Total IO] = (qs.total_logical_reads + qs.total_logical_writes)
	, [Average IO] = (qs.total_logical_reads + qs.total_logical_writes) / qs.execution_count
	, qs.execution_count
	, SUBSTRING (qt.text,(qs.statement_start_offset/2) + 1,
	((CASE WHEN qs.statement_end_offset = -1
	THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
	ELSE qs.statement_end_offset
	END - qs.statement_start_offset)/2) + 1) AS [Individual Query]
	, qt.text AS [Parent Query]
	, DB_NAME(qt.dbid) AS DatabaseName
	, qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY [Total IO] DESC

�ܰ����ҳ�ռIO�Ĳ�ѯ
���ұ�ִ�д������Ĳ�ѯ�Լ����ǵ�ִ�мƻ�
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT TOP 20
    qs.execution_count
    , SUBSTRING (qt.text,(qs.statement_start_offset/2) + 1,
    ((CASE WHEN qs.statement_end_offset = -1
      THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2
      ELSE qs.statement_end_offset
      END - qs.statement_start_offset)/2) + 1) AS [Individual Query]
    , qt.text AS [Parent Query]
    , DB_NAME(qt.dbid) AS DatabaseName
    , qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.execution_count DESC;
��������õ����Ĳ�ѯ������ض��Ż���

�ض������������ʱ��
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT DISTINCT TOP 20
    qs.last_execution_time
    , qt.text AS [Parent Query]
    , DB_NAME(qt.dbid) AS DatabaseName
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
WHERE qt.text LIKE '%�ض����Ĳ���%'
ORDER BY qs.last_execution_time DESC

�鿴��Щ���������£�ȴ���ٱ�ʹ�õ�����
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT
    DB_NAME() AS DatabaseName
    , SCHEMA_NAME(o.Schema_ID) AS SchemaName
    , OBJECT_NAME(s.[object_id]) AS TableName
    , i.name AS IndexName
    , s.user_updates
    , s.system_seeks + s.system_scans + s.system_lookups AS [System usage]
	INTO #TempUnusedIndexes
FROM   sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE 1=2

EXEC sp_MSForEachDB 'USE [?];
INSERT INTO #TempUnusedIndexes
SELECT TOP 20
    DB_NAME() AS DatabaseName
    , SCHEMA_NAME(o.Schema_ID) AS SchemaName
    , OBJECT_NAME(s.[object_id]) AS TableName
    , i.name AS IndexName
    , s.user_updates
    , s.system_seeks + s.system_scans + s.system_lookups AS [System usage]
FROM   sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE s.database_id = DB_ID()
	AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0
	AND s.user_seeks = 0 AND s.user_scans = 0  AND s.user_lookups = 0
	AND i.name IS NOT NULL
ORDER BY s.user_updates DESC'
SELECT TOP 20 * FROM #TempUnusedIndexes ORDER BY [user_updates] DESC
DROP TABLE #TempUnusedIndexes
��������Ӧ�ñ�Drop��


���ά�����۵�����
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT
    DB_NAME() AS DatabaseName
    , SCHEMA_NAME(o.Schema_ID) AS SchemaName
    , OBJECT_NAME(s.[object_id]) AS TableName
    , i.name AS IndexName
    , (s.user_updates ) AS [update usage]
    , (s.user_seeks + s.user_scans + s.user_lookups) AS [Retrieval usage]
    , (s.user_updates) -
      (s.user_seeks + s.user_scans + s.user_lookups) AS [Maintenance cost]
    , s.system_seeks + s.system_scans + s.system_lookups AS [System usage]
    , s.last_user_seek
    , s.last_user_scan
    , s.last_user_lookup
INTO #TempMaintenanceCost
FROM   sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON  s.[object_id] = i.[object_id]
    AND s.index_id = i.index_id
INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE 1=2
EXEC sp_MSForEachDB 'USE [?];
INSERT INTO #TempMaintenanceCost
SELECT TOP 20
    DB_NAME() AS DatabaseName
    , SCHEMA_NAME(o.Schema_ID) AS SchemaName
    , OBJECT_NAME(s.[object_id]) AS TableName
    , i.name AS IndexName
    , (s.user_updates ) AS [update usage]
    , (s.user_seeks + s.user_scans + s.user_lookups) AS [Retrieval usage]
    , (s.user_updates) - (s.user_seeks + user_scans + s.user_lookups) AS [Maintenance cost]
    , s.system_seeks + s.system_scans + s.system_lookups AS [System usage]
    , s.last_user_seek
    , s.last_user_scan
    , s.last_user_lookup
FROM   sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id]
    AND s.index_id = i.index_id
INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE s.database_id = DB_ID()
    AND i.name IS NOT NULL
    AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0
    AND (s.user_seeks + s.user_scans + s.user_lookups) > 0
ORDER BY [Maintenance cost] DESC'
SELECT top 20 * FROM #TempMaintenanceCost ORDER BY [Maintenance cost] DESC
DROP TABLE #TempMaintenanceCost
Maintenance cost�ߵ�Ӧ�ñ�Drop��

ʹ��Ƶ��������
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT
    DB_NAME() AS DatabaseName
    , SCHEMA_NAME(o.Schema_ID) AS SchemaName
    , OBJECT_NAME(s.[object_id]) AS TableName
    , i.name AS IndexName
    , (s.user_seeks + s.user_scans + s.user_lookups) AS [Usage]
    , s.user_updates
    , i.fill_factor
INTO #TempUsage
FROM sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id]
    AND s.index_id = i.index_id
INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE 1=2
EXEC sp_MSForEachDB 'USE [?];
INSERT INTO #TempUsage
SELECT TOP 20
    DB_NAME() AS DatabaseName
    , SCHEMA_NAME(o.Schema_ID) AS SchemaName
    , OBJECT_NAME(s.[object_id]) AS TableName
    , i.name AS IndexName
    , (s.user_seeks + s.user_scans + s.user_lookups) AS [Usage]
    , s.user_updates
    , i.fill_factor
FROM   sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE s.database_id = DB_ID()
    AND i.name IS NOT NULL
    AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0
ORDER BY [Usage] DESC'
SELECT TOP 20 * FROM #TempUsage ORDER BY [Usage] DESC
DROP TABLE #TempUsage
����������Ҫ����ע�⣬��Ҫ���Ż���ʱ��ɵ�

��Ƭ��������
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT
    DB_NAME() AS DatbaseName
    , SCHEMA_NAME(o.Schema_ID) AS SchemaName
    , OBJECT_NAME(s.[object_id]) AS TableName
    , i.name AS IndexName
    , ROUND(s.avg_fragmentation_in_percent,2) AS [Fragmentation %]
INTO #TempFragmentation
FROM sys.dm_db_index_physical_stats(db_id(),null, null, null, null) s
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE 1=2
EXEC sp_MSForEachDB 'USE [?];
INSERT INTO #TempFragmentation
SELECT TOP 20
    DB_NAME() AS DatbaseName
    , SCHEMA_NAME(o.Schema_ID) AS SchemaName
    , OBJECT_NAME(s.[object_id]) AS TableName
    , i.name AS IndexName
    , ROUND(s.avg_fragmentation_in_percent,2) AS [Fragmentation %]
FROM sys.dm_db_index_physical_stats(db_id(),null, null, null, null) s
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE s.database_id = DB_ID()
  AND i.name IS NOT NULL
  AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0
ORDER BY [Fragmentation %] DESC'
SELECT top 20 * FROM #TempFragmentation ORDER BY [Fragmentation %] DESC
DROP TABLE #TempFragmentation
����������ҪRebuild,����������������ݿ�����

���ϴ�SQL Server�������ҳ���ȫû��ʹ�õ�����
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT
    DB_NAME() AS DatbaseName
    , SCHEMA_NAME(O.Schema_ID) AS SchemaName
    , OBJECT_NAME(I.object_id) AS TableName
    , I.name AS IndexName
INTO #TempNeverUsedIndexes
FROM sys.indexes I INNER JOIN sys.objects O ON I.object_id = O.object_id
WHERE 1=2
EXEC sp_MSForEachDB 'USE [?];
INSERT INTO #TempNeverUsedIndexes
SELECT
    DB_NAME() AS DatbaseName
    , SCHEMA_NAME(O.Schema_ID) AS SchemaName
    , OBJECT_NAME(I.object_id) AS TableName
    , I.NAME AS IndexName
FROM sys.indexes I INNER JOIN sys.objects O ON I.object_id = O.object_id
LEFT OUTER JOIN sys.dm_db_index_usage_stats S ON S.object_id = I.object_id
	AND I.index_id = S.index_id
	AND DATABASE_ID = DB_ID()
WHERE OBJECTPROPERTY(O.object_id,''IsMsShipped'') = 0
	AND I.name IS NOT NULL
	AND S.object_id IS NULL'
SELECT * FROM #TempNeverUsedIndexes
ORDER BY DatbaseName, SchemaName, TableName, IndexName
DROP TABLE #TempNeverUsedIndexes
��������Ӧ��С�ĶԴ�������һ�Ŷ��ۣ�Ҫ����ʲôԭ������������

�鿴����ͳ�Ƶ������Ϣ
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT
    ss.name AS SchemaName
    , st.name AS TableName
    , s.name AS IndexName
    , STATS_DATE(s.id,s.indid) AS 'Statistics Last Updated'
    , s.rowcnt AS 'Row Count'
    , s.rowmodctr AS 'Number Of Changes'
    , CAST((CAST(s.rowmodctr AS DECIMAL(28,8))/CAST(s.rowcnt AS DECIMAL(28,2)) * 100.0) AS DECIMAL(28,2)) AS '% Rows Changed'
FROM sys.sysindexes s
INNER JOIN sys.tables st ON st.[object_id] = s.[id]
INNER JOIN sys.schemas ss ON ss.[schema_id] = st.[schema_id]
WHERE s.id > 100 AND s.indid > 0 AND s.rowcnt >= 500
ORDER BY SchemaName, TableName, IndexName
��Ϊ��ѯ�ƻ��Ǹ���ͳ����Ϣ���ģ�������ѡ��ͬ��ȡ����ͳ����Ϣ�����Ը���ͳ����Ϣ���µĶ�ѿ��Կ������ݿ�Ĵ���״����20%���Զ����¶��ڴ����˵�ǳ�����

SELECT TOP 20
DB_NAME() AS DatbaseName
, SCHEMA_NAME(o.Schema_ID) AS SchemaName
, OBJECT_NAME(s.[object_id]) AS TableName
, i.name AS IndexName
, ROUND(s.avg_fragmentation_in_percent,2) AS [Fragmentation %]
FROM sys.dm_db_index_physical_stats(db_id(),null, null, null, null) s
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id]
AND s.index_id = i.index_id
INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE s.database_id = DB_ID()
AND i.name IS NOT NULL
AND OBJECTPROPERTY(s.[object_id],  'IsMsShipped' ) = 0
ORDER BY [Fragmentation %] DESC

wait type��ѯ1��
SELECT TOP 20
wait_type ,
max_wait_time_ms wait_time_ms ,
signal_wait_time_ms ,
wait_time_ms - signal_wait_time_ms AS resource_wait_time_ms ,
100.0 * wait_time_ms / SUM(wait_time_ms) OVER ( )
AS percent_total_waits ,
100.0 * signal_wait_time_ms / SUM(signal_wait_time_ms) OVER ( )
AS percent_total_signal_waits ,
100.0 * ( wait_time_ms - signal_wait_time_ms )
/ SUM(wait_time_ms) OVER ( ) AS percent_total_resource_waits
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0 -- remove zero wait_time
AND wait_type NOT IN -- filter out additional irrelevant waits
( 'SLEEP_TASK', 'BROKER_TASK_STOP', 'BROKER_TO_FLUSH',
'SQLTRACE_BUFFER_FLUSH','CLR_AUTO_EVENT', 'CLR_MANUAL_EVENT',
'LAZYWRITER_SLEEP', 'SLEEP_SYSTEMTASK', 'SLEEP_BPOOL_FLUSH',
'BROKER_EVENTHANDLER', 'XE_DISPATCHER_WAIT', 'FT_IFTSHC_MUTEX',
'CHECKPOINT_QUEUE', 'FT_IFTS_SCHEDULER_IDLE_WAIT',
'BROKER_TRANSMITTER', 'FT_IFTSHC_MUTEX', 'KSOURCE_WAKEUP',
'LAZYWRITER_SLEEP', 'LOGMGR_QUEUE', 'ONDEMAND_TASK_QUEUE',
'REQUEST_FOR_DEADLOCK_SEARCH', 'XE_TIMER_EVENT', 'BAD_PAGE_PROCESS',
'DBMIRROR_EVENTS_QUEUE', 'BROKER_RECEIVE_WAITFOR',
'PREEMPTIVE_OS_GETPROCADDRESS', 'PREEMPTIVE_OS_AUTHENTICATIONOPS',
'WAITFOR', 'DISPATCHER_QUEUE_SEMAPHORE', 'XE_DISPATCHER_JOIN',
'RESOURCE_QUEUE' )
ORDER BY wait_time_ms DESC

Unused��ѯ2��
SELECT TOP 20
DB_NAME() AS DatabaseName
, SCHEMA_NAME(o.Schema_ID) AS SchemaName
, OBJECT_NAME(s.[object_id]) AS TableName
, i.name AS IndexName
, s.user_updates
, s.system_seeks + s.system_scans + s.system_lookups
AS [System usage]
FROM sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id]
AND s.index_id = i.index_id
INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE s.database_id = DB_ID()
AND OBJECTPROPERTY(s.[object_id], 'IsMsShipped') = 0
AND s.user_seeks = 0
AND s.user_scans = 0
AND s.user_lookups = 0
AND i.name IS NOT NULL
ORDER BY s.user_updates DESC

Maintenance��ѯ3��
SELECT TOP 20
DB_NAME() AS DatabaseName
, SCHEMA_NAME(o.Schema_ID) AS SchemaName
, OBJECT_NAME(s.[object_id]) AS TableName
, i.name AS IndexName
, (s.user_updates ) AS [update usage]
, (s.user_seeks + s.user_scans + s.user_lookups)
AS [Retrieval usage]
, (s.user_updates) -
(s.user_seeks + user_scans +
s.user_lookups) AS [Maintenance cost]
, s.system_seeks + s.system_scans + s.system_lookups AS [System usage]
, s.last_user_seek
, s.last_user_scan
, s.last_user_lookup
FROM sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id]
AND s.index_id = i.index_id
INNER JOIN sys.objects o ON i.object_id = O.object_id
WHERE s.database_id = DB_ID()
AND i.name IS NOT NULL
AND OBJECTPROPERTY(s.[object_id], 'IsMsShipped') = 0
AND (s.user_seeks + s.user_scans + s.user_lookups) > 0
ORDER BY [Maintenance cost] DESC

missing��ѯ4��
SELECT TOP 20
ROUND(s.avg_total_user_cost *
s.avg_user_impact
* (s.user_seeks + s.user_scans),0)
AS [Total Cost]
, d.[statement] AS [Table Name]
, equality_columns
, inequality_columns
, included_columns
FROM sys.dm_db_missing_index_groups g
INNER JOIN sys.dm_db_missing_index_group_stats s
ON s.group_handle = g.index_group_handle
INNER JOIN sys.dm_db_missing_index_details d
ON d.index_handle = g.index_handle
ORDER BY [Total Cost] DESC

SELECT   a.id as [����Id],
      CASE WHEN a.colorder = 1 THEN d.name ELSE '' END AS [������],
      CASE WHEN a.colorder = 1 THEN isnull(f.value, '') ELSE '' END AS [��ע],
      a.colorder AS [�ֶ�˳���], a.name AS [�ֶ�����],
       CASE WHEN COLUMNPROPERTY(a.id,
      a.name, 'IsIdentity') = 1 THEN '��' ELSE '' END AS [�Ƿ��ʶ��],
      CASE WHEN EXISTS
          (SELECT 1
         FROM dbo.sysindexes si INNER JOIN
               dbo.sysindexkeys sik ON si.id = sik.id AND si.indid = sik.indid INNER JOIN
               dbo.syscolumns sc ON sc.id = sik.id AND sc.colid = sik.colid INNER JOIN
               dbo.sysobjects so ON so.name = si.name AND so.xtype = 'PK'
         WHERE sc.id = a.id AND sc.colid = a.colid) THEN '��' ELSE '' END AS [�Ƿ�����],
      b.name AS [�ֶ�����], a.length AS [�ֶγ���], COLUMNPROPERTY(a.id, a.name, 'PRECISION')
      AS [�ֶξ���], ISNULL(COLUMNPROPERTY(a.id, a.name, 'Scale'), 0) AS [�ֶ�С��λ��],
      CASE WHEN a.isnullable = 1 THEN '��' ELSE '' END AS [�Ƿ�����null], ISNULL(e.text, '')
      AS [�ֶ�Ĭ��ֵ], ISNULL(g.[value], '') AS [�ֶα�ע], d.crdate AS [���󴴽�ʱ��],
      CASE WHEN a.colorder = 1 THEN d.refdate ELSE NULL END AS [�����޸�ʱ��]
FROM dbo.syscolumns a LEFT OUTER JOIN
      dbo.systypes b ON a.xtype = b.xusertype INNER JOIN
      dbo.sysobjects d ON a.id = d.id AND d.xtype = 'U' AND
      d.status >= 0 LEFT OUTER JOIN
      dbo.syscomments e ON a.cdefault = e.id LEFT OUTER JOIN
      sys.extended_properties g ON a.id = g.major_id AND a.colid = g.minor_id AND
      g.name = 'MS_Description' LEFT OUTER JOIN
      sys.extended_properties f ON d.id = f.major_id AND f.minor_id = 0 AND
      f.name = 'MS_Description'
ORDER BY d.name, [�ֶ�˳���]