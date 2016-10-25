#課題
```
パッチパネルに機能を追加しよう。

授業で説明したパッチの追加と削除以外に、以下の機能をパッチパネルに追加してください。

１. ポートのミラーリング
２. パッチとポートミラーリングの一覧
それぞれ patch_panel のサブコマンドとして実装してください。
```

#解答
```/lib/patch_panel.rb``` と ```/bin/patch_panel``` を編集していく．

##１. ポートのミラーリング
まず， ```/lib/patch_panel.rb``` 内に以下の記述を追加した．

```
  desc 'Creates a mirror'
  arg_name 'dpid port mirror_port'
  command :create_mirror do |c|
    c.desc 'Location to find socket files'
    c.flag [:S, :socket_dir], default_value: Trema::DEFAULT_SOCKET_DIR
    c.action do |_global_options, options, args|
      dpid = args[0].hex
      port = args[1].to_i
      mirror_port = args[2].to_i
      Trema.trema_process('PatchPanel', options[:socket_dir]).controller.
        create_mirroring(dpid, port, mirror_port)
    end
  end
```

ここでは，```create_mirror``` という，ミラーリングを行うためのサブコマンドを実装している．  
基本的には同ファイル内の他のサブコマンドの実装を参考にしながら記述した．ターミナル上での第二引数でミラーリングされるポート番号を，第三引数でミラーリングを行うポート番号をそれぞれ指定する．これらを第一引数で指定した```dpid``` と共に，後に説明するミラーリングを行うための ```create_mirroring``` メソッドに引数として与える．  
  
次に， ```/lib/patch_panel.rb``` に，以下に示す2つのメソッド ``` create_mirroring```と ```create_mirror_flow_entries``` を実装した．

```
def create_mirroring(dpid, port, mirror_port)
    @mirroring[dpid] << [port,mirror_port]
    create_mirror_flow_entries dpid,port,mirror_port
  end
```

```
  def create_mirror_flow_entries(dpid, port, mirror)
    port_pair = nil
    @patch[dpid].each do |port_a, port_b|
      if port_a == port then
        port_pair = port_b
      elsif port_b == port then
        port_pair = port_a
      end
    end

    send_flow_mod_delete(dpid, match: Match.new(in_port: port))
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_pair)) if ! port_pair.nil?
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port),
                      actions: [SendOutPort.new(port_pair), SendOutPort.new(mirror),])
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_pair),
                      actions: [SendOutPort.new(port), SendOutPort.new(mirror),]) if ! port_pair.nil?
  end
```

```create_mirroring``` メソッドでは，サブコマンド ```create_mirror``` で指定された引数から，ミラーリングされるポートの番号とミラーリングを行うポートの番号を受け取る．次に，事前に定義された空のハッシュである ```@mirroring[]``` に，これらのポート番号の組をdpidをキーとして格納する．そして，```create_mirror_flow_entries``` メソッドに対してdpidと上述の2つのポート番号を引数として与えて呼び出す．  

```create_mirror_flow_entries``` メソッドでは，ミラーリングの処理について記述した．まず， ```port``` で指定されたミラーリングをされるポート，すなわちモニターポートについて，そのモニターポートとパッチで繋がっている他方のポートを ```port_pair``` という変数で定義し，それがどのポートであるか捜索する処理を行っている．この処理は，ミラーリングを行う際に必要である，モニターポート宛にパケットを送信している送信元のポートを特定するために行う．  
```port``` と ```port_pair``` の組を特定したら，次に ```send_flow_mod_delete``` メソッドでこれらのポート宛について既に登録されているflow modの削除を行う．  
最後に，```send_flow_mod_add``` メソッドで ```port``` と ```port_pair``` にそれぞれPacket Inしてきたパケットを ```mirror``` に対しても同様に送信するように設定している．

##２. パッチとポートミラーリングの一覧
ここでは，パッチに接続されているポートの組と，ミラーリングされているポートとミラーリングを行っているポートの組を端末上に出力する処理の実装について記述する．  
まず，```/lib/patch_panel.rb``` に以下のメソッドを追加した．

```
  def print_port(dpid)
    array = Array.new()
    array << @patch
    array << @mirroring
    return array
  end
```

この ```print_port``` メソッドでは，ハッシュ ```@patch``` と ```@mirroring```にそれぞれ格納されたパッチに接続されたポートの組とミラーリングの組を，```array``` に格納する処理を行う．返り値として値が格納された ```array``` を，次に説明する ```/bin/patch_panel``` 内のサブコマンド ```print``` を実現する部分に返す．  
次に ```/bin/patch_panel``` に，それぞれの組の一覧をプリントするために以下の内容を追加した．

```
  desc 'Print patch and mirror port.'
  arg_name 'dpid'
  command :print do |c|
    c.desc 'Location to find socket files'
    c.flag [:S, :socket_dir], default_value: Trema::DEFAULT_SOCKET_DIR
    c.action do |_global_options, options, args|
      dpid = args[0].hex
      array = Trema.trema_process('PatchPanel', options[:socket_dir]).controller.
        print_port(dpid)

      @patch = array[0]
      @mirroring = array[1]

      @patch[dpid].each do |port_a, port_b|
        print("Patch： port",port_a, " <-> port", port_b, "\n")
      end
      @mirroring[dpid].each do |port, mirror|
        print("Mirroring：port",mirror, " mirrors port", port, "\n")
      end
    end
  end
```

ここでは，前述の ```print_port``` メソッドから返り値として受け取った ```array[]``` の値から，パッチに接続されているポートの組とミラーリングの組を端末上に出力するサブコマンド ```print``` を実装している．

#動作確認
ここでは，実装した機能が正しく動作するかについて確認を行う．
```１. ミラーリング，２. パッチとポートミラーリングの一覧表示``` を正しく行うことができるか確認するために，以下の手順で実行した．

```
1. host1とhost2をパッチで接続
2. host3においてhost1をミラーリング
3. host1とhost2間でパケットの送受信
4. host1, host2の状態の確認
5. host3においてhost1, host2間での送受信がミラーリングされているか確認
6. 一覧を表示
```

また，```patch_panel.conf``` において，今回ミラーリングを行う```host3```が自分宛て以外のパケットを受信できるよう，```promisc```を以下のように設定した．

```
vhost ('host3') { 
ip '192.168.0.3'
promisc true
}
```

上記手順での実行結果を以下に示す．

```
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-tomok0823$ ./bin/patch_panel create 0xabc 1 2
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-tomok0823$ ./bin/patch_panel create_mirror 0xabc 1 3
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-tomok0823$ ./bin/trema send_packets --source host1 --dest host2
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-tomok0823$ ./bin/trema send_packets --source host2 --dest host1
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-tomok0823$ ./bin/trema show_stats host1
Packets sent:
  192.168.0.1 -> 192.168.0.2 = 1 packet
Packets received:
  192.168.0.2 -> 192.168.0.1 = 1 packet
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-tomok0823$ ./bin/trema show_stats host2
Packets sent:
  192.168.0.2 -> 192.168.0.1 = 1 packet
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-tomok0823$ ./bin/trema show_stats host3
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
  192.168.0.2 -> 192.168.0.1 = 1 packet
ensyuu2@ensyuu2-VirtualBox:~/patch-panel-tomok0823$ ./bin/patch_panel print 0xabc
Patch： port1 <-> port2
Mirroring：port3 mirrors port1
```

上記の通り，今回実装した機能がそれぞれ正しく動作していることを確認できた．