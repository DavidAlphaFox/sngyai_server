%%%==============================================================================
%%% Author      :f
%%% Created     :2012-6-19
%%% Description :定时服务模块
%%% 每分/秒/时轮询
%%%    %{{daily, {every, {3, sec}, {between, {0, am}, {11, 59, pm}}}}, {io,format, ["E~n"]}},
%%%    %{{daily, {every, {10, min}, {between, {0, am}, {11, 59, pm}}}}, {gen_server,cast,[mod_goods_state, {'is_time_up'}]}},
%%%    %{{daily, {every, {1, hr}, {between, {0, am}, {11, 59, pm}}}},{lib_assist_skill, is_time_up,[]}},
%%% 每天轮询

%%% 每周定时
%%%    %{{weekly,tue, {3,00,pm}},{lib_assart_meteorite,start_meteorite_activity,[]}},
%%%    %{{weekly, sun, {0,15,am}},{lib_multiple_exp_time, reset_has_get_multiple_exp_time_ets, []}},
%%%    %{{weekly, sat, {3,00,pm}},{lib_assart_meteorite,start_meteorite_activity,[]}},


%%% 注意时间安排,时间安排要排开,但是重要的,敏感的东西要放到0点整执行,次之可以往前或者往后1分钟
%%% 比如一些不太敏感的排行信息,可以往前或者往后十几分钟甚至几十分钟,任务按照执行频率和时间先后放置
%%% 好查看任务密度
%%%==============================================================================
-module(mod_crone).
-behaviour(gen_server).

%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------
-include("common.hrl").

-define(SERVER, ?MODULE).



%%--------------------------------------------------------------------
%% Export
%%--------------------------------------------------------------------
%% 启动接口
-export([start_link/0]).

%% gen_server 回调处理
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3, get_task_list/0]).


%%--------------------------------------------------------------------
%% Server functions
%%--------------------------------------------------------------------

%% 别忘记注释,根据启动方式不同选择不同的参数
%% 启动crone模块
start_link() ->
    Result = gen_server:start_link({local, ?SERVER}, ?MODULE, [], ?Public_Service_Options),
    Result.



%% --------------------------------------------------------------------
%% Callback functions
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
%% 模块初始化回调
init([]) ->
    process_flag(trap_exit, true),
    put(tag, ?MODULE),

    % [Step 2 ] Add your task to crone, ex: Tasks=[Schedule_Demo_Task],
    Tasks = [],
    [spawn_link(crone, loop_task0, [T]) || T <- Tasks],
    {ok, Tasks}.

get_task_list() ->
    gen_server:call(?MODULE, get_state).


%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_call(get_state,_From, State) ->
    {reply, State, State};

handle_call(Info,_From, State) ->
    try
        do_call(Info,_From, State)
    catch
        _:Reason ->
            Stacktrace = erlang:get_stacktrace(),
            ?Error(crone_logger, "mod_crone handle_call is Info:~p, Reason:~p, Trace:~p, State:~p",[Info, Reason, Stacktrace, State]),
            ?T("*****Error mod_crone handle_call info: ~p,~n reason:~p,~n stacktrace:~p", [Info, Reason, Stacktrace]),
            {reply, ok, State}
    end.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast(Info, State) ->
	try
		do_cast(Info, State)
	catch
		_:Reason ->
            Stacktrace = erlang:get_stacktrace(),
            ?Error(crone_logger, "mod_crone handle_cast is Info:~p, Reason:~p, Trace:~p, State:~p",[Info, Reason, Stacktrace, State]),
            ?T("*****Error mod_crone handle_cast info: ~p,~n reason:~p,~n stacktrace:~p", [Info, Reason, Stacktrace]),
			{noreply, State}
	end.
%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info(Info, State) ->
	try
		do_info(Info, State)
	catch
		_:Reason ->
            Stacktrace = erlang:get_stacktrace(),
            ?Error(crone_logger, "mod_crone handle_info is Info:~p, Reason:~p, Trace:~p, State:~p",[Info, Reason, Stacktrace, State]),
            ?T("*****Error mod_crone handle_info info: ~p,~n reason:~p,~n stacktrace:~p", [Info, Reason, Stacktrace]),
			{noreply, State}
	end.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(Reason, State) ->
	try
		do_terminate(Reason, State)
	catch
		_:Reason ->
            Stacktrace = erlang:get_stacktrace(),
            ?Error(crone_logger, "mod_crone do_terminate is Reason:~p, Trace:~p, State:~p",[Reason, Stacktrace, State]),
            ?T("*****Error mod_crone do_terminate ~n reason:~p,~n stacktrace:~p", [Reason, Stacktrace]),
			ok
	end.
%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------------------------------------------------------------
%%										内部Handler
%% --------------------------------------------------------------------------------------------------------------------------

%%---------------------do_call----------------------------------------
%% 别忘记完整注释哦亲

%% 通配call处理
%% Info:消息
%% _From:消息来自
%% State:当前进程状态
%% 返回值:ok
do_call(Info, _From, State) ->
	?Error(crone_logger, "crone_logger call is not match:~p",[Info]),
    {reply, ok, State}.


%%--------------------do_cast-----------------------------------------
%% 别忘记完整注释哦亲

%% 通配cast处理
%% Info:消息
%% State:当前进程状态
%% 返回值:不使用
do_cast(Info, State) ->
    ?Error(crone_logger, "crone_logger cast is not match:~p",[Info]),
    {noreply, State}.

%%--------------------do_info------------------------------------------
%% 别忘记完整注释哦亲

%% 通配info处理
%% Info:消息
%% State:当前进程状态
%% 返回值:不使用
do_info(Info, State) ->
	?Error(crone_logger, "crone_logger info is not match:~p",[Info]),
    {noreply, State}.

%%---------------------do_terminate-------------------------------------

%% 通配进程销毁处理
%% State:当前进程状态
%% 返回值:ok
do_terminate(Reason, State) ->
    %?T("do_terminate"),

	case Reason =:= normal orelse Reason =:= shutdown of
        true ->
            skip;
        false ->
            ?Error(crone_logger, "crone_logger terminate reason: ~p, state:~p" , [Reason, State])
    end,
    %别忘记进程销毁需要做的数据清理哦
    ok.

%% --------------------------------------------------------------------------------------------------------------------------
%% 其他方法
%% --------------------------------------------------------------------------------------------------------------------------


