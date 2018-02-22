defmodule Tanx.Game.Updater do

  #### Public API

  def start_link(game, arena, opts \\ []) do
    interval = Keyword.get(opts, :interval, 0.02)
    time_config = Keyword.get(opts, :time_config, nil)
    GenServer.start_link(__MODULE__, {game, arena, interval, time_config})
  end


  #### GenServer callbacks

  use GenServer

  defmodule InternalData do
    defstruct(
      decomposed_walls: []
    )
  end

  defmodule State do
    defstruct(
      game: nil,
      arena: nil,
      internal: nil,
      interval: nil,
      time_config: nil,
      last: 0.0
    )
  end

  def init({game, arena, interval, time_config}) do
    internal = %InternalData{
      decomposed_walls: Enum.map(arena.walls, &Tanx.Game.Walls.decompose_wall/1)
    }
    state = %State{
      game: game,
      arena: arena,
      internal: internal,
      interval: interval,
      time_config: time_config,
      last: Tanx.Util.SystemTime.get(time_config)
    }
    {:ok, state, next_tick_timeout(state)}
  end

  def handle_cast(:update, state) do
    state = perform_update(state)
    {:noreply, state, next_tick_timeout(state)}
  end

  def handle_info(:timeout, state) do
    state = perform_update(state)
    {:noreply, state, next_tick_timeout(state)}
  end

  def handle_info(request, state), do: super(request, state)


  #### Logic

  defp perform_update(state) do
    commands = GenServer.call(state.game, :get_commands)
    cur = Tanx.Util.SystemTime.get(state.time_config)
    {arena, internal, events} =
      Enum.reduce(commands, {state.arena, state.internal, []}, fn cmd, {a, p, e} ->
        {a, p, de} = Tanx.Game.CommandHandler.handle(cmd, a, p, cur)
        {a, p, e ++ de}
      end)
    {arena, internal, de} =
      Tanx.Game.Periodic.update(arena, internal, cur - state.last)
    GenServer.call(state.game, {:update, cur, arena, events ++ de})
    %State{state | arena: arena, internal: internal, last: cur}
  end

  defp next_tick_timeout(state) do
    if state.interval == nil do
      :infinity
    else
      timeout_secs = max(state.last + state.interval - Tanx.Util.SystemTime.get(state.time_config), 0.0)
      trunc(timeout_secs * 1000)
    end
  end

end
