%%%-----------------------------------
%%% @Module  : server_app
%%% @Created : 2011.02.22 
%%% @Description: 游戏服务器应用启动
%%%-----------------------------------
-module(server_app).

-behaviour(application).


-include("common.hrl").
-include("record.hrl").

-export([start/2, stop/1]).

%% 启动应用程序回调方法
start(normal, []) ->
  %% 启动游戏服务的根监控进程
  {ok, SupPid} = server_sup:start_link(),

  %% log4erl配置
  log4erl:conf("ebin/log4erl"),

  %初始化配置文件
  ok = lib_config:init_ensure_config(),
  %% 启动db服务监控进程及db服务进程
  ok = server_sup:start_child_supervisor(server_sup_db),
  ok = server_sup_db:start_db_conn(), %初始化db连接

  %% 启动系统服务监控进程
  ok = server_sup:start_child_supervisor(server_sup_sys),
  ok = server_sup_sys:start_service(),

  %% ssl 启动
  ok = ssl:start(),
  ok = apns:start(),
  apns:connect(
    ?APNS_NAME,
    fun t_apns:handle_apns_error/2,
    fun t_apns:handle_apns_delete_subscription/1
  ),

  %%输出
  io:format("server_app started"),
  {ok, SupPid}.


%% 应用程序停止回调方法
stop(_State) ->
  server_sup_sys:stop_service(),
  void.

