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
まず， ```//lib/patch_panel.rb``` 内に以下の記述を追加した．

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