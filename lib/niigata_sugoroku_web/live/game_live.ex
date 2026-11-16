defmodule NiigataSugorokuWeb.GameLive do
  use NiigataSugorokuWeb, :live_view
  alias NiigataSugoroku.GameServer

  @topic "sugoroku_game"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(NiigataSugoroku.PubSub, @topic)
    end

    game_state = safe_get_state()

    {:ok,
     assign(socket,
       game: game_state,
       board: GameServer.board_data(),
       my_name: nil,
       input_name: "",
       nodes: [node() | Node.list()],
       error_msg: nil
     )}
  end

  defp safe_get_state do
    try do
      GameServer.get_state()
    catch
      :exit, _ -> nil
    end
  end

  @impl true
  def handle_event("join", %{"name" => name}, socket) do
    name = String.trim(name)
    if name != "" do
      case GameServer.join_game(name) do
        :ok -> {:noreply, assign(socket, my_name: name, error_msg: nil)}
        {:error, reason} -> {:noreply, assign(socket, error_msg: reason)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("roll", _params, socket) do
    case GameServer.roll_dice(socket.assigns.my_name) do
      :ok -> {:noreply, assign(socket, error_msg: nil)}
      {:error, reason} -> {:noreply, assign(socket, error_msg: reason)}
    end
  end

  @impl true
  def handle_event("reset", _params, socket) do
    GameServer.reset_game()
    {:noreply, assign(socket, my_name: nil, error_msg: nil)}
  end

  @impl true
  def handle_info({:game_updated, new_game_state}, socket) do
    {:noreply, assign(socket, game: new_game_state, nodes: [node() | Node.list()])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto p-4 font-sans">
      <div class="flex justify-between items-center mb-4 border-b pb-2">
        <h1 class="text-2xl font-bold text-emerald-800">🌾 新潟県分散すごろく</h1>
        <div class="text-xs text-gray-500">
          接続ノード: <%= Enum.join(@nodes, ", ") %>
        </div>
      </div>

      <%= if is_nil(@game) do %>
        <div class="p-6 bg-red-100 text-red-800 rounded">
          ホストノード（GameServer）が見つかりません。CUIから `Node.connect/1` でホストに接続してください。
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <!-- 左側：操作パネル＆ログ -->
          <div class="space-y-4">
            <%= if is_nil(@my_name) do %>
              <form phx-submit="join" class="p-4 bg-white shadow rounded space-y-3 border">
                <label class="block font-bold">プレイヤー名を入力して参加</label>
                <input type="text" name="name" value={@input_name} placeholder="例: ケンシロウ"
                       class="w-full border p-2 rounded" required />
                <button type="submit" class="w-full bg-emerald-600 text-white py-2 rounded font-bold hover:bg-emerald-700">
                  ゲームに参加
                </button>
              </form>
            <% else %>
              <div class="p-4 bg-emerald-50 border border-emerald-200 rounded">
                <p class="text-sm">あなたの名前: <span class="font-bold text-lg"><%= @my_name %></span></p>
                <% current_player = Enum.at(@game.players, @game.turn_index) %>
                <div class="mt-3">
                  <%= if @game.winner do %>
                    <div class="text-xl font-bold text-amber-600 mb-2">🏆 優勝: <%= @game.winner %></div>
                    <button phx-click="reset" class="w-full bg-gray-600 text-white py-2 rounded">最初からやり直す</button>
                  <% else %>
                    <%= if current_player && current_player.name == @my_name do %>
                      <button phx-click="roll" class="w-full bg-amber-500 text-white py-3 rounded-lg text-xl font-bold shadow hover:bg-amber-600 animate-bounce">
                        🎲 サイコロを振る！
                      </button>
                    <% else %>
                      <p class="text-gray-600 font-semibold">
                        ⏳ <%= if current_player, do: "#{current_player.name} のターンです...", else: "待機中..." %>
                      </p>
                    <% end %>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= if @error_msg do %>
              <div class="p-2 bg-red-100 text-red-700 text-sm rounded"><%= @error_msg %></div>
            <% end %>

            <!-- プレイヤー一覧 -->
            <div class="p-4 bg-white shadow rounded border">
              <h2 class="font-bold mb-2 border-b pb-1">参加者一覧 (<%= length(@game.players) %>/4人)</h2>
              <ul class="space-y-2">
                <%= for {p, idx} <- Enum.with_index(@game.players) do %>
                  <li class={"flex items-center justify-between p-1 rounded #{if idx == @game.turn_index, do: "bg-amber-100 font-bold"}"}>
                    <span class="flex items-center gap-2">
                      <span class="w-4 h-4 rounded-full inline-block" style={"background-color: #{p.color}"}></span>
                      <%= p.name %>
                    </span>
                    <span class="text-xs text-gray-600">
                      <%= Enum.at(@board, p.pos).name %>
                    </span>
                  </li>
                <% end %>
              </ul>
            </div>

            <!-- 実況ログ -->
            <div class="p-4 bg-gray-900 text-green-400 rounded text-xs h-48 overflow-y-auto font-mono">
              <%= for line <- @game.log do %>
                <div class="mb-1">> <%= line %></div>
              <% end %>
            </div>
          </div>

          <!-- 右側：新潟県デフォルメ盤面 (SVG) -->
          <div class="md:col-span-2 bg-sky-100 rounded-xl shadow-inner border-2 border-sky-300 relative overflow-hidden" style="min-height: 520px;">
            <svg viewBox="0 0 100 100" class="w-full h-full">
              <!-- 新潟県（本州側）の超デフォルメシルエット -->
              <polygon points="5,92 15,75 35,70 48,45 62,25 78,10 85,15 72,40 62,65 55,88 30,85"
                       fill="#a7f3d0" stroke="#059669" stroke-width="0.8" />
              <!-- 佐渡島のデフォルメシルエット（S字型） -->
              <polygon points="28,15 42,12 45,18 36,22 43,27 33,30 26,23"
                       fill="#a7f3d0" stroke="#059669" stroke-width="0.8" />

              <!-- マス同士を結ぶルート線 -->
              <polyline points={Enum.map_join(@board, " ", fn sq -> "#{sq.x},#{sq.y}" end)}
                        fill="none" stroke="#f59e0b" stroke-width="0.8" stroke-dasharray="1.5,1" />

              <!-- 各マスの描画 -->
              <%= for sq <- @board do %>
                <g>
                  <circle cx={sq.x} cy={sq.y} r="2.2" fill="white" stroke="#d97706" stroke-width="0.6" />
                  <text x={sq.x} y={sq.y - 3} font-size="2.3" text-anchor="middle" fill="#1f2937" font-weight="bold">
                    <%= sq.id %>.<%= String.split(sq.name, "：") |> List.last() %>
                  </text>
                </g>
              <% end %>

              <!-- プレイヤーのコマの描画（同じマスに重ならないよう少しずつずらす） -->
              <%= for {p, idx} <- Enum.with_index(@game.players) do %>
                <% sq = Enum.at(@board, p.pos) %>
                <% offset_x = (idx - 1.5) * 1.2 %>
                <circle cx={sq.x + offset_x} cy={sq.y + 1.5} r="1.8"
                        fill={p.color} stroke="white" stroke-width="0.5" />
              <% end %>
            </svg>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
