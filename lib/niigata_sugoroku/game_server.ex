defmodule NiigataSugoroku.GameServer do
  use GenServer

  # 新潟県すごろくのマス目定義（最初はシンプルにテキストと座標）
  @board [
    %{id: 0, name: "スタート：新潟駅", event: "旅の始まり！", x: 65, y: 35},
    %{id: 1, name: "万代シテイ", event: "バスセンターのカレーを食べた（+1マス進む）", effect: 1, x: 63, y: 33},
    %{id: 2, name: "弥彦神社", event: "お参りしてパワー充電", x: 52, y: 45},
    %{id: 3, name: "燕三条", event: "金属加工の技に感動！", x: 56, y: 48},
    %{id: 4, name: "長岡（花火）", event: "フェニックス花火に感動！1回休み", skip: true, x: 50, y: 58},
    %{id: 5, name: "魚沼", event: "コシヒカリの新米を食べて元気100倍（+2マス）", effect: 2, x: 55, y: 72},
    %{id: 6, name: "越後湯沢", event: "温泉でリラックス", x: 52, y: 82},
    %{id: 7, name: "十日町", event: "へぎそばを堪能", x: 43, y: 73},
    %{id: 8, name: "上越（高田城）", event: "夜桜が綺麗！", x: 25, y: 78},
    %{id: 9, name: "糸魚川", event: "ヒスイを探して足止め（-1マス戻る）", effect: -1, x: 12, y: 85},
    %{id: 10, name: "親不知", event: "断崖絶壁を慎重に進む", x: 8, y: 88},
    %{id: 11, name: "佐渡汽船フェリー", event: "ジェットフォイルで一気に佐渡へ！", x: 40, y: 25},
    %{id: 12, name: "佐渡金山", event: "小判を見つけた！", x: 32, y: 18},
    %{id: 13, name: "トキの森公園", event: "トキの飛翔を見た！", x: 36, y: 22},
    %{id: 14, name: "ゴール：朱鷺メッセ展望室", event: "新潟県制覇おめでとう！", x: 66, y: 31}
  ]

  @topic "sugoroku_game"

  # --- Client API ---
  def start_link(_opts) do
    # クラスタ全体で一意になるように :global で登録
    GenServer.start_link(__MODULE__, %{}, name: {:global, __MODULE__})
  end

  def get_state do
    GenServer.call({:global, __MODULE__}, :get_state)
  end

  def join_game(player_name) do
    GenServer.call({:global, __MODULE__}, {:join, player_name})
  end

  def roll_dice(player_name) do
    GenServer.call({:global, __MODULE__}, {:roll_dice, player_name})
  end

  def reset_game do
    GenServer.call({:global, __MODULE__}, :reset)
  end

  def board_data, do: @board

  # --- Server Callbacks ---
  @impl true
  def init(_) do
    {:ok, initial_state()}
  end

  defp initial_state do
    %{
      players: [],        # [%{name: "Alice", pos: 0, color: "#e63946", skip: false}, ...]
      turn_index: 0,
      last_dice: nil,
      log: ["参加者を待っています..."],
      winner: nil
    }
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:join, name}, _from, state) do
    if Enum.any?(state.players, &(&1.name == name)) or length(state.players) >= 4 do
      {:reply, {:error, "参加済みか満員です"}, state}
    else
      colors = ["#e63946", "#2a9d8f", "#e9c46a", "#457b9d"]
      color = Enum.at(colors, length(state.players))
      new_player = %{name: name, pos: 0, color: color, skip: false}
      new_state = %{state |
        players: state.players ++ [new_player],
        log: ["#{name} が参加しました！ (#{node()})" | state.log]
      }
      broadcast(new_state)
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:roll_dice, player_name}, _from, state) do
    current_player = Enum.at(state.players, state.turn_index)

    cond do
      state.winner != nil ->
        {:reply, {:error, "ゲームは終了しています"}, state}
      current_player == nil or current_player.name != player_name ->
        {:reply, {:error, "あなたのターンではありません"}, state}
      true ->
        new_state = process_turn(state, current_player)
        broadcast(new_state)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    new_state = initial_state()
    broadcast(new_state)
    {:reply, :ok, new_state}
  end

  defp process_turn(state, player) do
    max_pos = length(@board) - 1

    if player.skip do
      updated_players = List.replace_at(state.players, state.turn_index, %{player | skip: false})
      next_turn = rem(state.turn_index + 1, length(state.players))
      %{state |
        players: updated_players,
        turn_index: next_turn,
        log: ["#{player.name} は1回休みです。" | state.log]
      }
    else
      dice = Enum.random(1..6)
      raw_pos = min(player.pos + dice, max_pos)
      square = Enum.at(@board, raw_pos)

      # マスの効果（進む・戻る）を適用
      effect = Map.get(square, :effect, 0)
      final_pos = max(0, min(raw_pos + effect, max_pos))
      final_square = Enum.at(@board, final_pos)
      skip_next = Map.get(final_square, :skip, false)

      updated_player = %{player | pos: final_pos, skip: skip_next}
      updated_players = List.replace_at(state.players, state.turn_index, updated_player)

      winner = if final_pos == max_pos, do: player.name, else: nil
      next_turn = rem(state.turn_index + 1, length(state.players))

      msg = "#{player.name} がサイコロで「#{dice}」を出した！ → #{square.name} (#{square.event})"
      msg = if winner, do: "🎉 #{player.name} がゴールしました！優勝！", else: msg

      %{state |
        players: updated_players,
        turn_index: next_turn,
        last_dice: dice,
        winner: winner,
        log: [msg | Enum.take(state.log, 9)]
      }
    end
  end

  defp broadcast(state) do
    # 全ノードのLiveViewプロセスへブロードキャスト
    Phoenix.PubSub.broadcast(NiigataSugoroku.PubSub, @topic, {:game_updated, state})
  end
end
