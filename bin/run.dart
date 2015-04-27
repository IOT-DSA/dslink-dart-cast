import "dart:async";

import "package:dslink/client.dart";
import "package:dslink/responder.dart";
import "package:google_cast/cast.dart";
import "package:upnp/upnp.dart";

LinkProvider link;
DeviceDiscoverer discoverer = new DeviceDiscoverer();

main(List<String> args) async {
  link = new LinkProvider(args, "Cast-", command: "run", defaultNodes: {
    "Last_Device_Scan": {
      r"$name": "Last Device Scan",
      r"$type": "int",
      "?value": 0
    }
  }, profiles: {});

  if (link.link == null) return;

  link.connect();

  rootNode = link.provider.getNode("/");

  new Timer.periodic(new Duration(seconds: 30), (_) async {
    await updateDevices();
  });

  new Timer.periodic(new Duration(seconds: 10), (_) async {
    await updateStatus();
  });

  await updateDevices();
  await updateStatus();
}

List<DiscoveredDevice> devices;

SimpleNode rootNode;

updateStatus() async {
  for (var k in clients.keys) {
    CastJSONMessage status = await clients[k].getReceiverChannel().sendRequest({
      "type": "GET_STATUS"
    });

    (rootNode.getChild(k).getChild("Status") as SimpleNode).updateValue(status.json);
  }

  (rootNode.getChild("Last_Device_Scan") as SimpleNode).updateValue(new DateTime.now().millisecondsSinceEpoch);
}

updateDevices() async {
  List<DiscoveredDevice> devices = await discoverer.discoverDevices(type: CommonDevices.CHROMECAST);
  var toRemove = rootNode.children.keys.where((n) => !devices.any((d) => d.uuid != n)).toList();
  toRemove.forEach((it) => rootNode.removeChild(it));
  for (var device in devices) {
    if (rootNode.children.keys.contains(device.uuid)) {
      continue;
    }

    print("Discovered Device: ${device.uuid}");

    var host = Uri.parse(device.location).host;
    CastClient client = clients[device.uuid] = new CastClient(host);
    await client.connect();
    link.provider.addNode("/${device.uuid}", {
      "Launch": {
        r"$is": "launch",
        r"$invokable": "write",
        r"$params": [
          {
            "name": "app",
            "type": "strin  g"
          }
        ]
      },
      "Status": {
        r"$type": "map",
        r"?value": {}
      }
    });
  }
}

class LaunchNode extends SimpleNode {
  LaunchNode(String path) : super(path);

  @override
  Object onInvoke(Map<String, dynamic> params) {
    var uuid = path.split("/")[1];
    if (params["app"] == null) return {};
    CastChannel channel = clients[uuid].getReceiverChannel();
    channel.sendRequest({
      "type": "LAUNCH",
      "appId": params["app"]
    });
    return {};
  }
}

Map<String, CastClient> clients = {};
