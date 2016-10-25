# Software patch-panel.
class PatchPanel < Trema::Controller
  def start(_args)
    @patch = Hash.new {|h,k| h[k] = []  }
    @mirroring = Hash.new {|h,k| h[k] = []  }
    logger.info 'PatchPanel started.'
  end

  def switch_ready(dpid)
    @patch[dpid].each do |port_a, port_b|
      delete_flow_entries dpid, port_a, port_b
      add_flow_entries dpid, port_a, port_b
    end
  end

  def create_patch(dpid, port_a, port_b)
    add_flow_entries dpid, port_a, port_b
    @patch[dpid] << [port_a, port_b].sort
  end

  def delete_patch(dpid, port_a, port_b)
    return "No such patch\n" if @patch[dpid].delete([port_a, port_b].sort).nil?
    delete_flow_entries dpid, port_a, port_b
    return ""
  end

  def create_mirroring(dpid, port, mirror_port)
    @mirroring[dpid] << [port,mirror_port]
    create_mirror_flow_entries dpid,port,mirror_port
  end

  def print_port(dpid)
    array = Array.new()
    array << @patch
    array << @mirroring
    return array
  end

  private

  def add_flow_entries(dpid, port_a, port_b)
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_a),
                      actions: SendOutPort.new(port_b))
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_b),
                      actions: SendOutPort.new(port_a))
  end

  def delete_flow_entries(dpid, port_a, port_b)
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_a))
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_b))
  end

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
end
