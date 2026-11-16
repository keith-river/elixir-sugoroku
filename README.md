# README.md

---

# Elixer分散すごろく新潟 (Niigata Sugoroku)

Elixir / Phoenix LiveView を用いたマルチプレイ対応の分散型すごろくゲームです。複数のノード（Linux / WSL等）をErlang分散クラスタで結び、リアルタイムでゲーム盤面を同期して遊ぶことができます。

## 動作環境
- Elixir 1.18+ / Erlang/OTP 27
- Phoenix 1.7+ / Bandit

---

## 起動方法（分散マルチプレイ）

ゲームを遊ぶには、**ホストノード（GameServer）**を1台立ち上げ、そのあとに**クライアントノード**を接続します。

### 1. ホストノード（GameServer）の起動
ゲームの状態管理を行うマスターノードです（例としてIP `192.168.1.11` のマシンで実行）。

```bash
HOST_NODE=true iex \
  --name node1@127.0.0.1 \
  --cookie niigata_secret \
  --erl "-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9105" \
  -S mix phx.server
```

- ホストノードからゲーム参加する手順：
Webブラウザでアクセス: 

``` http://localhost:4000 (またはマシンのIP) ```

---

### 2. クライアントノードの起動と接続
別の端末やWindows (WSL) から参加するクライアント側での起動手順です。

```bash
PORT=4001 iex \
  --name node2@127.0.0.1 \
  --cookie niigata_secret \
  --erl "-kernel inet_dist_listen_min 9106 inet_dist_listen_max 9110" \
  -S mix phx.server
```

(※別PCや別ネットワークから接続する場合は、127.0.0.1 の部分をお使いのホストのIPアドレスに変更してください)

- ホストへの接続（IExプロンプト上での実行）
起動したIExプロンプトで、ホストノードに対して接続コマンドを実行します。

```Elixir
Node.connect(:"node1@192.168.1.11")
```


- クライアントからゲーム参加する手順：
Webブラウザでアクセス: 
```
http://localhost:4001 から参加できます。
```

## 3. 物理的に異なるPC間での分散マルチプレイ構築手順

ローカルネットワーク（LAN）上の異なる物理マシン間でElixirノードを接続し、分散クラスタを構築する手順です。

### お互いのIPアドレスを調べる
両方のPCが同じローカルネットワークに接続されていることを確認し、それぞれのIPアドレスを調べます。

- **Linuxホスト側の場合:**
  ```bash
  ip a

  hostname -I
  ```

```
*(例: `192.168.10.117`)*

* **Windows (WSL) クライアント側の場合:**
Windows側のPowerShellで確認します。

```powershell
ipconfig

```

*(またはWSL内から `hostname -I`)*

### ネットワーク疎通確認（ping）

お互いのマシン間でパケットが通るか確認します。

```bash
ping <相手のIPアドレス>

```
*Verification:* パケットロスが `0%` で応答があることを確認します。

### ノードの起動（IPアドレスとポートの明示）

分散ノードを起動する際は、`localhost` ではなく**自身の実際のLAN内IPアドレス**をノード名に含め、Erlangの分散通信用ポート範囲を指定して起動します。

#### ■ ホスト側（Linuxなど）の起動

```bash
HOST_NODE=true iex \
  --name node1@192.168.10.117 \
  --cookie niigata_secret \
  --erl "-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9105" \
  -S mix phx.server

```

#### ■ クライアント側（Windows/WSLなど）の起動

```bash
PORT=4000 iex \
  --name node_client@192.168.10.150 \
  --cookie niigata_secret \
  --erl "-kernel inet_dist_listen_min 9106 inet_dist_listen_max 9110" \
  -S mix phx.server

```

###  クラスタの接続確認

クライアント側のIExプロンプトから、ホスト側のノードへ接続コマンドを実行します。

```elixir
Node.connect(:"node1@192.168.10.117")

```

*Verification:*

1. コマンドの返り値として `true` が返ることを確認します。
2. 続けて以下を実行し、接続先ノードが表示されることを確認します。

```elixir
Node.list()

```

*(期待される出力: `[:node1@192.168.10.117]`)*



### 3. ネットワーク・ファイアウォール設定に関する注意

Erlangの分散通信には、EPMD (4369) および指定したポート範囲 (9100〜9110) のTCPポートが必要です。

Windows (WSL) から別マシンのLinuxに接続する場合、Windows側のファイアウォール（受信規則）で該当ポートの許可が必要になります。


```
# PhoenixのWebアクセス用ポート

New-NetFirewallRule -DisplayName "Elixir Client Web 4000" -Direction Inbound -Protocol TCP -LocalPort 4000 -Action Allow

# Erlangノード間通信用ポート（クライアント側で使う範囲）

New-NetFirewallRule -DisplayName "Elixir Client Cluster 9106-9110" -Direction Inbound -Protocol TCP -LocalPort 9106-9110 -Action Allow

```

```dos
netsh interface portproxy add v4tov4 listenport=4000 listenaddress=0.0.0.0 connectport=4000 connectaddress=WSLのIPアドレス
```




---- 


# NiigataSugoroku

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
