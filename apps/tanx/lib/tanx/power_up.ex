defmodule Tanx.PowerUp do

  require Logger

  defmodule State do
    defstruct x: 0.0,
              y: 0.0,
              radius: 0.4,
              type: nil,
              created_at: nil
  end

  ############
  #Power_up API

  #Called by "Arena Objects" process.
  def start_link(x, y, type \\ nil) do
    GenServer.start_link(__MODULE__, { x, y, type})
  end

  def get_state(powerup) do
    GenServer.call(powerup, :get_state)
  end

  def collect(pid) do
    GenServer.call(pid, :collect)
  end

  #########################
  #GenServer Implementation

  use GenServer

  def init({x, y, type}) do

    type = if type == nil do
      pick_power_up_type()
    else
      type
    end

    {:ok, %Tanx.PowerUp.State{ x: x,
                                    y: y,
                                    type: type,
                                    created_at: Tanx.SystemTime.get(nil) }}
  end

  def handle_cast({:update, _last_time, _time, updater}, state) do
    updater |> Tanx.ArenaUpdater.send_update_reply(%Tanx.Updates.PowerUp{powerup: self(),
                                                        pos: {state.x, state.y},
                                                        radius: state.radius,
                                                        type: state.type,
                                                        created_at: state.created_at})
    {:noreply, state}
  end

  def handle_call(:collect, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def pick_power_up_type(powerups \\ nil) do
    list_of_types = [
      %Tanx.PowerUpTypes.BouncingMissile{},
      %Tanx.PowerUpTypes.HealthKit{}
    ]
    Enum.at(powerups || list_of_types,
            :rand.uniform(length(powerups || list_of_types)) - 1)
  end
end